import Foundation
import WatchHookCore

/// 入力したメモを端末に保存し、連携 (webhook・リマインダー・Markdown) を送る。時計と iPhone で同じものを使う。
/// - メモはまず保存する。送れなくても内容は失わない (docs/FREE_OSS.md)
/// - 連携ごとに受け持つ端末 (`Delivery.owner`) が決まっていて、自分の分だけ送る。webhook は入力した端末から直接送る (docs/DESIGN.md)
/// - 時計のメモは iPhone に渡す (メモの正は iPhone)。リマインダー・Markdown は iPhone が受け取ったときに足して保存する
///
/// actor でも await の間は他の呼び出しが割り込めるので、送信中の連携の ID (`inFlight`) を持って二重送信を防ぎ、
/// 送る直前と結果を反映する直前に、その連携がまだ送信待ちかを確かめる。
actor MemoDispatcher {
    static let shared = MemoDispatcher()
    /// 一覧が変わったとき (画面の再読み込み用)。
    static let didChange = Notification.Name("MemoDispatcher.didChange")

    #if os(watchOS)
    static let role: DeviceRole = .watch
    /// 時計に残す件数 (送信待ち・iPhone に渡す前のものは上限を超えても残す)
    static let capacity: Int? = 50
    #else
    static let role: DeviceRole = .phone
    static let capacity: Int? = nil
    #endif

    private let sender: WebhookSender
    private let fileURL: URL
    private var log: MemoLog
    private var inFlight: Set<UUID> = []
    private var isFlushing = false
    private var flushRequested = false
    /// 一覧のファイルが読めなかった (I/O エラー・ロック中など)。読めるまで上書きしない (未送信を消さないため)。
    private var readFailed = false
    /// 直近の保存に失敗した。次の機会に書き直す。
    private var dirty = false

    init(sender: WebhookSender = WebhookSender(), directory: URL = MemoDispatcher.defaultDirectory) {
        self.sender = sender
        self.fileURL = directory.appending(path: "memo-log.json")
        switch Self.readLog(at: fileURL, legacyURL: directory.appending(path: "message-log.json")) {
        case .loaded(let saved):
            log = saved
        case .missing:
            log = MemoLog(owner: Self.role, capacity: Self.capacity)
        case .unreadable:
            log = MemoLog(owner: Self.role, capacity: Self.capacity)
            readFailed = true
        }
        #if os(iOS)
        // 前の版で時計の履歴を写していたファイル。メモは時計から全文が届くようになったので要らない
        try? FileManager.default.removeItem(at: directory.appending(path: "watch-history.json"))
        #endif
    }

    static var defaultDirectory: URL {
        let dir = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private enum ReadResult {
        case loaded(MemoLog)
        case missing
        case unreadable
    }

    /// 今の形式を読む。無ければ前の形式 (送り先 1 つへの送信の履歴) から移す。
    private static func readLog(at url: URL, legacyURL: URL) -> ReadResult {
        switch readJSON(MemoLog.self, at: url) {
        case .value(var saved):
            saved.owner = role
            saved.capacity = capacity
            return .loaded(saved)
        case .unreadable:
            return .unreadable
        case .missing:
            break
        }
        switch readJSON(MessageLog.self, at: legacyURL) {
        case .value(let legacy):
            let migrated = MemoLog(migrating: legacy, owner: role, capacity: capacity)
            // 移したものを書けてから前のファイルを消す (書けなければ次の起動でもう一度移す)
            guard let data = try? JSONEncoder().encode(migrated),
                  (try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])) != nil else {
                return .loaded(migrated)
            }
            try? FileManager.default.removeItem(at: legacyURL)
            return .loaded(migrated)
        case .unreadable:
            return .unreadable
        case .missing:
            return .missing
        }
    }

    private enum JSONRead<T> {
        case value(T)
        case missing
        case unreadable
    }

    private static func readJSON<T: Decodable>(_ type: T.Type, at url: URL) -> JSONRead<T> {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return .missing
        } catch {
            return .unreadable
        }
        guard let value = try? JSONDecoder().decode(T.self, from: data) else {
            // 形式が読めない (壊れた) ファイルは待っても直らない。消さずに脇へ退けて、空から始める
            let aside = url.deletingLastPathComponent().appending(path: "\(url.deletingPathExtension().lastPathComponent).corrupt-\(UUID().uuidString).json")
            do {
                try FileManager.default.moveItem(at: url, to: aside)
                return .missing
            } catch {
                return .unreadable
            }
        }
        return .value(value)
    }

    // MARK: - 読む

    var memos: [Memo] { log.memos }
    /// 今まさに通信している連携の ID (送信待ちと見分けて表示する)。
    var sendingIDs: Set<UUID> { inFlight }

    func memo(id: UUID) -> Memo? { log.memo(id: id) }

    // MARK: - 入力

    /// 入力を保存し、この端末が受け持つ連携を送って、送り終えた (または待ちになった) メモを返す。
    /// 保存できなければ nil (内容は失われるので、呼び出し側は入力を残して知らせる)。
    func record(text: String, source: String) async -> Memo? {
        // 設定を読めないとき (ロック中など) も、メモは保存する。送り先は無いものとして扱う (あとから送れる)
        let config = (try? ConfigStore.loadFromKeychain()) ?? .unsaved
        var deliveries = MemoPlanner.webhookDeliveries(text: text, config: config, owner: Self.role)
        #if os(iOS)
        deliveries += MemoPlanner.phoneDeliveries(text: text, settings: IntegrationStore.load())
        #endif
        let memo = Memo(text: text, source: source, origin: Self.role, deliveries: deliveries,
                        phoneSync: Self.role == .watch ? .waiting : nil)
        log.add(memo)
        guard persist() else {
            // 一度も書けていなければ、アプリが終われば消える。保存したとは言わない
            log.discard(memoID: memo.id)
            return nil
        }
        #if os(watchOS)
        WatchSync.shared.sendMemo(memo, urgent: true)
        #endif
        // 1 件目は並べて送る (時計では送り先の数だけ待たせない)
        let refs = memo.deliveries.filter { $0.owner == Self.role }.map { MemoLog.DeliveryRef(memoID: memo.id, deliveryID: $0.id) }
        await withTaskGroup(of: Void.self) { group in
            for ref in refs {
                group.addTask { await self.deliver(ref) }
            }
        }
        Task { await self.flush() }
        return log.memo(id: memo.id) ?? memo
    }

    // MARK: - 送る

    /// 送信待ちを古いものから 1 件ずつ送る。
    func flush() async {
        if isFlushing {
            flushRequested = true
            return
        }
        isFlushing = true
        defer { isFlushing = false }
        recoverIfNeeded()
        if dirty { persist() }
        repeat {
            flushRequested = false
            var tried: Set<UUID> = []
            while let ref = log.pendingDeliveries.first(where: { !tried.contains($0.deliveryID) && !inFlight.contains($0.deliveryID) }) {
                tried.insert(ref.deliveryID)
                let result = await deliver(ref)
                // 待つのをやめられた (キャンセル) / 設定を読めない: 送信待ちのまま次の機会に回す
                if result == .stop {
                    if flushRequested { Task { await self.flush() } }
                    return
                }
            }
        } while flushRequested
    }

    private enum DeliverResult { case delivered, skipped, stop }

    /// 1 件送って結果を反映する。
    @discardableResult
    private func deliver(_ ref: MemoLog.DeliveryRef) async -> DeliverResult {
        guard !inFlight.contains(ref.deliveryID), let memo = log.memo(id: ref.memoID),
              let delivery = log.delivery(ref), delivery.owner == Self.role, delivery.status.isPending else { return .skipped }
        inFlight.insert(ref.deliveryID)
        NotificationCenter.default.post(name: Self.didChange, object: nil)  // 「送信中」の表示を出す
        let outcome = await execute(delivery, of: memo)
        inFlight.remove(ref.deliveryID)
        guard let outcome else {
            NotificationCenter.default.post(name: Self.didChange, object: nil)
            return .stop
        }
        if case .cancelled = outcome {
            NotificationCenter.default.post(name: Self.didChange, object: nil)
            return .stop
        }
        // 送っている間に消された / 手動で状態が変わったものは上書きしない
        guard log.delivery(ref)?.status.isPending == true else {
            NotificationCenter.default.post(name: Self.didChange, object: nil)
            return .skipped
        }
        log.apply(outcome, memoID: ref.memoID, deliveryID: ref.deliveryID)
        persist()
        if let updated = log.memo(id: ref.memoID) { shareWithPeer(updated) }
        return .delivered
    }

    /// 連携の種類ごとに送る / 保存する。設定を読めない (ロック中など) ときは nil (送信待ちのまま)。
    private func execute(_ delivery: Delivery, of memo: Memo) async -> DeliveryOutcome? {
        switch delivery.target {
        case .webhook(let destinationID, _):
            // 送る直前の設定で組み立てる (URL・認証を直したら、送信待ちの分にも効く)
            guard let config = try? ConfigStore.loadFromKeychain() else { return nil }
            guard let destination = config.destination(id: destinationID) else {
                return .permanent(reason: String(localized: "送り先が削除されています"))
            }
            // 送信待ちのあいだに無効にした送り先へは送らない (メモ詳細から選んで送ったものは除く)
            guard destination.isEnabled || delivery.isManual else {
                return .permanent(reason: String(localized: "送り先が無効になっています"))
            }
            guard let message = memo.outgoingMessage(for: delivery) else { return .permanent(reason: "invalid") }
            return await sender.send(message, to: destination).deliveryOutcome
        case .reminder:
            #if os(iOS)
            return await ReminderWriter.save(title: delivery.text, memoID: memo.id, settings: IntegrationStore.load().reminder)
            #else
            return .permanent(reason: "unsupported")
            #endif
        case .markdown:
            #if os(iOS)
            return MarkdownWriter.append(text: memo.text, createdAt: memo.createdAt)
            #else
            return .permanent(reason: "unsupported")
            #endif
        }
    }

    /// 手動の再送 (自分が受け持つ、終わっていないものだけ)。
    func retry(memoID: UUID, deliveryID: UUID) async {
        guard recoverIfNeeded(), log.retry(memoID: memoID, deliveryID: deliveryID) else { return }
        persist()
        if let memo = log.memo(id: memoID) { shareWithPeer(memo) }
        await flush()
    }

    // MARK: - iPhone だけの操作

    #if os(iOS)
    /// 後から送る: 保存済みのメモを、登録済みの送り先へ (この iPhone から) 送る。
    func sendLater(memoID: UUID, destination: Destination) async {
        guard recoverIfNeeded(), let memo = log.memo(id: memoID) else { return }
        let delivery = Delivery(target: .webhook(destinationID: destination.id, name: destination.displayName),
                                owner: .phone, text: destination.wrap(memo.text), isManual: true)
        log.addDelivery(delivery, to: memoID)
        persist()
        if let updated = log.memo(id: memoID) { shareWithPeer(updated) }
        await deliver(MemoLog.DeliveryRef(memoID: memoID, deliveryID: delivery.id))
    }

    /// メモを消す。この iPhone の未送信は取り消し、時計にも知らせて時計の未送信も止める。
    /// 送信済みの webhook・作成済みのリマインダーには反映しない。送っている最中のものは止められない。
    @discardableResult
    func remove(memoID: UUID) -> Bool {
        guard recoverIfNeeded() else { return false }
        let before = log
        log.remove(memoID: memoID)
        guard persist() else {
            // 消せなかったら戻す。戻さないと、ディスクに残った送信待ちが次の起動で送られる
            log = before
            NotificationCenter.default.post(name: Self.didChange, object: nil)
            return false
        }
        PhoneSync.shared.sendDeletion(memoID)
        return true
    }

    /// 時計からメモが届いたとき。初めてなら iPhone が受け持つ連携 (リマインダー・Markdown) を足して保存する。
    /// 保存できたら、iPhone の写し (時計への受領の知らせ) を返す。保存できなければ nil (時計は送り直す)。
    func receiveFromWatch(_ remote: Memo) async -> Memo? {
        guard recoverIfNeeded() else { return nil }
        if log.isDeleted(remote.id) {
            // 時計がまだ持っていれば、もう一度消すよう知らせる
            PhoneSync.shared.sendDeletion(remote.id)
            return nil
        }
        let isNew = log.memo(id: remote.id) == nil
        let result = log.merge(remote, insertIfMissing: true)
        if isNew, result == .inserted, remote.wantsPhoneIntegrations {
            for d in MemoPlanner.phoneDeliveries(text: remote.text, settings: IntegrationStore.load()) {
                log.addDelivery(d, to: remote.id)
            }
        }
        if result != .unchanged, !persist() {
            // 書けなかった: 受け取らなかったことにして時計に送り直させる (受領を返さない)
            if isNew { log.discard(memoID: remote.id) }
            return nil
        }
        return log.memo(id: remote.id)
    }

    /// 1 件のメモの、この端末が受け持つ送信待ちだけを送る (時計からの受け取りで、溜まった分まで待たずに返事をするため)。
    func deliverPending(memoID: UUID) async {
        guard let memo = log.memo(id: memoID) else { return }
        for d in memo.deliveries where d.owner == Self.role && d.status.isPending {
            await deliver(MemoLog.DeliveryRef(memoID: memoID, deliveryID: d.id))
        }
    }
    #endif

    // MARK: - 時計だけの操作

    #if os(watchOS)
    /// iPhone から写しが届いたとき (受領の知らせを兼ねる)。iPhone が受け持つ連携の状態を合わせる。
    func receiveFromPhone(_ remote: Memo) {
        guard recoverIfNeeded() else { return }
        let result = log.merge(remote, insertIfMissing: false)
        let wasWaiting = log.memo(id: remote.id)?.phoneSync == .waiting
        log.markPhoneSynced(remote.id)
        if result == .updated || wasWaiting { persist() }
    }

    /// iPhone でメモを消したとき。時計の未送信も取り消して消す。
    func receiveDeletion(_ memoID: UUID) {
        guard recoverIfNeeded() else { return }
        log.remove(memoID: memoID)
        persist()
    }

    /// iPhone に渡せていないメモ (つながったとき・前面に来たときに送り直す)。
    func memosWaitingForPhone() -> [Memo] {
        log.memos.filter { $0.phoneSync == .waiting }
    }
    #endif

    /// 相手の端末へ写しを送る。時計はすべて、iPhone は時計で入力されたものだけ。
    private func shareWithPeer(_ memo: Memo) {
        #if os(watchOS)
        WatchSync.shared.sendMemo(memo, urgent: false)
        #else
        if memo.origin == .watch { PhoneSync.shared.sendMemo(memo) }
        #endif
    }

    // MARK: - 保存

    /// 起動時に一覧を読めなかったなら読み直し、手元で増えた分を足す。読めていれば true。
    @discardableResult
    private func recoverIfNeeded() -> Bool {
        guard readFailed else { return true }
        switch Self.readLog(at: fileURL, legacyURL: fileURL.deletingLastPathComponent().appending(path: "message-log.json")) {
        case .loaded(var saved):
            for memo in log.memos {
                if saved.memo(id: memo.id) == nil { saved.add(memo) } else { saved.merge(memo, insertIfMissing: false) }
            }
            log = saved
            readFailed = false
        case .missing:
            readFailed = false
        case .unreadable:
            return false
        }
        NotificationCenter.default.post(name: Self.didChange, object: nil)
        return true
    }

    @discardableResult
    private func persist() -> Bool {
        defer { NotificationCenter.default.post(name: Self.didChange, object: nil) }
        // 読めていない一覧で上書きすると未送信を消すので、読めるまで書かない
        guard recoverIfNeeded() else {
            dirty = true
            return false
        }
        guard let data = try? JSONEncoder().encode(log) else { return false }
        do {
            // 本文は他人に見せたくない内容のこともあるので、起動後の初回ロック解除までは読めないようにする
            try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            dirty = false
            return true
        } catch {
            dirty = true
            return false
        }
    }
}
