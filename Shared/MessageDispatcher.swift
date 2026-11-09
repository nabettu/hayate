import Foundation
import WatchHookCore

/// 入力されたテキストを送り先へ送る。失敗したら履歴に再送待ちとして残し、次に開いたとき / 次に送るときにまとめて送り直す。
/// 時計からも iPhone を経由せず直接送る (iPhone アプリが起動していなくても届くように)。
actor MessageDispatcher {
    static let shared = MessageDispatcher()

    private let sender: WebhookSender
    private let fileURL: URL
    private var log: MessageLog
    private var isFlushing = false

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

    /// 1 件送る。結果を返す (再送待ちになった場合も含む)。
    @discardableResult
    func send(text: String, destination: Destination, source: String) async -> MessageStatus {
        let message = OutgoingMessage(text: text, destinationID: destination.id, source: source)
        log.enqueue(message, destinationName: destination.name)
        persist()
        let result = await sender.send(message, to: destination)
        log.apply(result, to: message.id)
        persist()
        // ついでに溜まっている未送信も送る
        if case .sent = result { await flush() }
        return log.entries.first { $0.id == message.id }?.status ?? .failed(reason: "不明")
    }

    /// 再送待ちをまとめて送る。送り先が消されていたものは失敗にする。
    func flush() async {
        guard !isFlushing else { return }
        isFlushing = true
        defer { isFlushing = false }
        let config = ConfigStore.loadFromKeychain()
        for entry in log.pending {
            guard let destination = config.destination(id: entry.message.destinationID) else {
                log.apply(.permanentFailure(reason: "送り先が削除されています"), to: entry.id)
                continue
            }
            let result = await sender.send(entry.message, to: destination)
            log.apply(result, to: entry.id)
        }
        persist()
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

    private func persist() {
        guard let data = try? JSONEncoder().encode(log) else { return }
        // 本文は他人に見せたくない内容のこともあるので、ロック中は読めないようにする
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
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
