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

    init(sender: WebhookSender = WebhookSender(), fileURL: URL = MessageDispatcher.defaultFileURL) {
        self.sender = sender
        self.fileURL = fileURL
        if let data = try? Data(contentsOf: fileURL), let saved = try? JSONDecoder().decode(MessageLog.self, from: data) {
            log = saved
        } else {
            log = MessageLog()
        }
    }

    static var defaultFileURL: URL {
        let dir = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "message-log.json")
    }

    var entries: [MessageLogEntry] { log.entries }

    /// 1 件送って、その結果を返す。溜まっている未送信の再送は待たない (裏で始める)。
    @discardableResult
    func send(text: String, destination: Destination, source: String) async -> MessageStatus {
        let message = OutgoingMessage(text: text, destinationID: destination.id, source: source)
        log.enqueue(message, destinationName: destination.name)
        inFlight.insert(message.id)
        let queued = persist()

        let result = await sender.send(message, to: destination)
        let status = log.apply(result, to: message.id) ?? Self.status(for: result)
        inFlight.remove(message.id)
        let saved = persist()

        if case .sent = result {
            Task { await self.flush() }
        }
        // 再送待ちにしたのに端末に保存できていなければ、アプリが終われば消える。再送するとは言わない
        if case .pending = status, !(queued && saved) {
            return .failed(reason: "端末に保存できなかったため、送り直せません")
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
        repeat {
            flushRequested = false
            var tried: Set<UUID> = []
            while let entry = log.pending.first(where: { !tried.contains($0.id) && !inFlight.contains($0.id) }) {
                tried.insert(entry.id)
                guard let destination = ConfigStore.loadFromKeychain().destination(id: entry.message.destinationID) else {
                    log.apply(.permanentFailure(reason: "送り先が削除されています"), to: entry.id)
                    persist()
                    continue
                }
                inFlight.insert(entry.id)
                let result = await sender.send(entry.message, to: destination)
                inFlight.remove(entry.id)
                // 送っている間に履歴から消された / 手動で状態が変わったものは上書きしない
                guard case .pending = log.status(of: entry.id) else { continue }
                log.apply(result, to: entry.id)
                persist()
            }
        } while flushRequested
    }

    func retry(_ id: UUID) async {
        log.retry(id)
        persist()
        await flush()
    }

    func remove(_ id: UUID) {
        log.remove(id)
        persist()
    }

    @discardableResult
    private func persist() -> Bool {
        defer { NotificationCenter.default.post(name: Self.didChange, object: nil) }
        guard let data = try? JSONEncoder().encode(log) else { return false }
        do {
            // 本文は他人に見せたくない内容のこともあるので、起動後の初回ロック解除までは読めないようにする
            try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return true
        } catch {
            return false
        }
    }

    private static func status(for result: SendResult) -> MessageStatus {
        switch result {
        case .sent(let code): .sent(statusCode: code)
        case .retryableFailure(let r): .pending(attempts: 1, lastError: r)
        case .permanentFailure(let r): .failed(reason: r)
        }
    }
}

extension MessageStatus {
    var label: String {
        switch self {
        case .sent: "送信済み"
        case .pending(let attempts, _): attempts == 0 ? "送信中" : "再送待ち"
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
