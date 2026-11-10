import Foundation
import WatchHookCore

/// 入力されたテキストを送り先へ送る。失敗したら履歴に再送待ちとして残し、次に開いたとき / 次に送れたときに送り直す。
/// 時計からも iPhone を経由せず直接送る (iPhone アプリが起動していなくても届くように)。
///
/// actor でも await の間は他の呼び出しが割り込めるので、二重送信を防ぐために送信中の ID (`inFlight`) を持ち、
/// 再送は 1 件ずつ「その時点の」履歴と設定を読み直してから送る。
actor MessageDispatcher {
    static let shared = MessageDispatcher()
    /// 履歴が変わったとき (画面の再読み込み用)。
    static let didChange = Notification.Name("MessageDispatcher.didChange")

    private let sender: WebhookSender
    private let fileURL: URL
    private var log: MessageLog
    private var inFlight: Set<UUID> = []
    private var isFlushing = false
    private var flushRequested = false
    /// 履歴ファイルが読めなかった (I/O エラー・ロック中など)。読めるまで上書きしない (未送信を消さないため)。
    private var readFailed = false
    /// 直近の保存に失敗した (手元の状態がディスクに書けていない)。次の機会に書き直す。
    private var dirty = false
    /// 一度でもディスクに書けた項目の ID。並行した別の送信の保存で書かれた分も含む。
    private var persistedIDs: Set<UUID> = []

    init(sender: WebhookSender = WebhookSender(), fileURL: URL = MessageDispatcher.defaultFileURL) {
        self.sender = sender
        self.fileURL = fileURL
        switch Self.readLog(at: fileURL) {
        case .loaded(let saved):
            log = saved
            persistedIDs = Set(saved.entries.map(\.id))
        case .missing:
            log = MessageLog()
        case .unreadable:
            log = MessageLog()
            readFailed = true
        }
    }

    private enum ReadResult {
        case loaded(MessageLog)
        case missing
        case unreadable
    }

    private static func readLog(at url: URL) -> ReadResult {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return .missing
        } catch {
            return .unreadable
        }
        guard let saved = try? JSONDecoder().decode(MessageLog.self, from: data) else {
            // 形式が読めない (壊れた) ファイルは待っても直らない。消さずに脇へ退けて、空から始める
            let aside = url.deletingLastPathComponent().appending(path: "message-log.corrupt-\(UUID().uuidString).json")
            do {
                try FileManager.default.moveItem(at: url, to: aside)
                return .missing
            } catch {
                // 退けられなければ上書きしない (手で戻せる元データを残す)
                return .unreadable
            }
        }
        return .loaded(saved)
    }

    static var defaultFileURL: URL {
        let dir = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "message-log.json")
    }

    /// 履歴。`isSending` は今まさに通信している項目 (再送待ちと見分けて表示する)。
    var entries: [MessageLogEntry] { log.entries }
    var sendingIDs: Set<UUID> { inFlight }

    /// 1 件送って、その結果を返す。溜まっている未送信の再送は待たない (裏で始める)。
    @discardableResult
    func send(text: String, destination: Destination, source: String) async -> MessageStatus {
        let message = OutgoingMessage(text: text, destinationID: destination.id, source: source)
        log.enqueue(message, destinationName: destination.displayName)
        inFlight.insert(message.id)
        persist()

        let result = await sender.send(message, to: destination)
        let status = log.apply(result, to: message.id) ?? Self.status(for: result)
        inFlight.remove(message.id)
        persist()

        if case .sent = result {
            Task { await self.flush() }
        }
        // 再送待ちを一度も端末に保存できていなければ、アプリが終われば消える。再送するとは言わない
        // (この呼び出しか、並行した別の送信の保存で一度でも書けていれば、次の flush で送り直される)
        if case .pending = status, !persistedIDs.contains(message.id) {
            // 表示と実際をそろえる: 再送待ちのまま残すと、あとで自動で送られて「送り直せません」と食い違う
            let reason = "端末に保存できなかったため、送り直せません"
            log.apply(.permanentFailure(reason: reason), to: message.id)
            return .failed(reason: reason)
        }
        return status
    }

    /// 再送待ちを 1 件ずつ送る。送る直前に、その項目がまだ再送待ちか・送り先がまだあるかを確かめる。
    func flush() async {
        if isFlushing {
            flushRequested = true
            return
        }
        isFlushing = true
        defer { isFlushing = false }
        // 起動時に読めなかった履歴の再送待ちも拾えるよう、列挙の前に読み直す
        recoverIfNeeded()
        // 前回書けなかった結果 (送信済みなど) を書き直す。書かないと次の起動で送り直してしまう
        if dirty { persist() }
        // お試し前・終了後は再送もしない (再送待ちは消さずに残し、購入したら送る)。
        // 再送は送る直前の送り先の設定で組み立て直すので、期限後に本文テンプレートを書き換えれば好きな内容を送れてしまうため
        guard await EntitlementStore.currentAccess().canSend else { return }
        repeat {
            flushRequested = false
            var tried: Set<UUID> = []
            while let entry = log.pending.first(where: { !tried.contains($0.id) && !inFlight.contains($0.id) }) {
                tried.insert(entry.id)
                // 設定を読めないとき (ロック中など) は「送り先が消えた」と決めつけず、再送待ちのまま次の機会に回す
                guard let config = try? ConfigStore.loadFromKeychain() else { return }
                guard let destination = config.destination(id: entry.message.destinationID) else {
                    log.apply(.permanentFailure(reason: "送り先が削除されています"), to: entry.id)
                    persist()
                    continue
                }
                inFlight.insert(entry.id)
                NotificationCenter.default.post(name: Self.didChange, object: nil)  // 「送信中」の表示を出す
                let result = await sender.send(entry.message, to: destination)
                inFlight.remove(entry.id)
                // 待つのをやめられたら、状態を変えずに再送をやめる (残りの再送回数を減らさない)。
                // ただ、その間に頼まれた別の再送 (手動の再送など) は取りこぼさないよう、キャンセルされていない別のタスクで続ける
                if case .cancelled = result {
                    NotificationCenter.default.post(name: Self.didChange, object: nil)
                    if flushRequested { Task { await self.flush() } }
                    return
                }
                // 送っている間に履歴から消された / 手動で状態が変わったものは上書きしない
                guard case .pending = log.status(of: entry.id) else { continue }
                log.apply(result, to: entry.id)
                persist()
            }
        } while flushRequested
    }

    /// 手動の再送。送れない状態 (お試し前・終了後) では何もしない (`flush` と同じ理由)。
    func retry(_ id: UUID) async {
        guard await EntitlementStore.currentAccess().canSend else { return }
        log.retry(id)
        persist()
        await flush()
    }

    /// 消せなかった (保存に失敗した) ら元に戻して false。戻さないと、ディスクに残った再送待ちが次の起動で送られる。
    /// 消せなかった (保存に失敗した) ら元に戻して false。戻さないと、ディスクに残った再送待ちが次の起動で送られる。
    @discardableResult
    func remove(_ id: UUID) -> Bool {
        // 読めていない履歴の上で消すと、復旧したときの状態とずれる。先に復旧させ、だめなら消さない
        guard recoverIfNeeded() else { return false }
        let before = log
        log.remove(id)
        if persist() { return true }
        log = before
        NotificationCenter.default.post(name: Self.didChange, object: nil)
        return false
    }

    /// 起動時に履歴を読めなかったなら読み直し、手元で増えた分を足す。読めていれば true。
    @discardableResult
    private func recoverIfNeeded() -> Bool {
        guard readFailed else { return true }
        switch Self.readLog(at: fileURL) {
        case .loaded(var saved):
            persistedIDs.formUnion(saved.entries.map(\.id))
            saved.merge(log)
            log = saved
            readFailed = false
        case .missing:
            readFailed = false
        case .unreadable:
            return false
        }
        publishHistory()
        NotificationCenter.default.post(name: Self.didChange, object: nil)
        return true
    }

    @discardableResult
    private func persist() -> Bool {
        defer { NotificationCenter.default.post(name: Self.didChange, object: nil) }
        // 読めていない履歴で上書きすると未送信を消すので、読めるまで書かない
        guard recoverIfNeeded() else {
            dirty = true
            return false
        }
        guard let data = try? JSONEncoder().encode(log) else { return false }
        do {
            // 本文は他人に見せたくない内容のこともあるので、起動後の初回ロック解除までは読めないようにする
            try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            dirty = false
            publishHistory()
            // 判定に使うのは履歴に残っている項目だけなので、それ以外は持たない (送るたびに増え続けないように)
            persistedIDs = Set(log.entries.map(\.id))
            return true
        } catch {
            // 失敗したときは削らない: 削除の取り消しなどで履歴に戻る項目の「書けた」記録を失わないため
            dirty = true
            return false
        }
    }

    /// 時計の履歴の写しを iPhone に送る (iPhone の履歴画面で見せるため)。iPhone では何もしない。
    func publishHistory() {
        #if os(watchOS)
        // 履歴を読めていないときに送ると、空の履歴で iPhone の写しを消してしまう。読めたとき (recoverIfNeeded) に送る
        guard !readFailed else { return }
        WatchSync.shared.pushHistory(HistorySnapshot(log: log, updatedAt: Date()))
        #endif
    }

    private static func status(for result: SendResult) -> MessageStatus {
        switch result {
        case .sent(let code): .sent(statusCode: code)
        case .retryableFailure(let r): .pending(attempts: 1, lastError: r)
        case .permanentFailure(let r): .failed(reason: r)
        case .cancelled: .pending(attempts: 0, lastError: nil)
        }
    }
}

extension MessageLogEntry {
    /// 通信中かどうかは状態ではなく `MessageDispatcher.sendingIDs` で見る (キャンセル後に「送信中」のまま残さない)。
    func label(sending: Set<UUID>) -> String {
        sending.contains(id) ? "送信中" : status.label
    }
}

extension MessageStatus {
    var label: String {
        switch self {
        case .sent: "送信済み"
        case .pending: "未送信"
        case .failed: "失敗"
        }
    }

    var detail: String? {
        switch self {
        case .sent(let code): "HTTP \(code)"
        case .pending(_, let error): error
        case .failed(let reason): reason
        }
    }
}
