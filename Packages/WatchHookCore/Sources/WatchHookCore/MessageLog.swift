import Foundation

public enum MessageStatus: Codable, Hashable, Sendable {
    case pending(attempts: Int, lastError: String?)
    case sent(statusCode: Int)
    case failed(reason: String)
}

public struct MessageLogEntry: Codable, Hashable, Identifiable, Sendable {
    public var message: OutgoingMessage
    public var destinationName: String
    public var status: MessageStatus
    public var id: UUID { message.id }
}

/// 送信の履歴と、未送信 (再送待ち) の一覧を兼ねる。新しい順。
/// 未送信のものは件数の上限を超えても消さない。
public struct MessageLog: Codable, Hashable, Sendable {
    public private(set) var entries: [MessageLogEntry] = []
    public var maxAttempts: Int
    public var capacity: Int

    public init(maxAttempts: Int = 5, capacity: Int = 50) {
        self.maxAttempts = maxAttempts
        self.capacity = capacity
    }

    public var pending: [MessageLogEntry] {
        entries.filter { if case .pending = $0.status { true } else { false } }
    }

    public mutating func enqueue(_ message: OutgoingMessage, destinationName: String) {
        entries.insert(MessageLogEntry(message: message, destinationName: destinationName, status: .pending(attempts: 0, lastError: nil)), at: 0)
        entries.sort { $0.message.createdAt > $1.message.createdAt }
        trim()
    }

    public mutating func apply(_ result: SendResult, to id: UUID) {
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return }
        switch result {
        case .sent(let code):
            entries[i].status = .sent(statusCode: code)
        case .permanentFailure(let reason):
            entries[i].status = .failed(reason: reason)
        case .retryableFailure(let reason):
            let attempts: Int
            if case .pending(let a, _) = entries[i].status { attempts = a + 1 } else { attempts = 1 }
            entries[i].status = attempts >= maxAttempts
                ? .failed(reason: reason)
                : .pending(attempts: attempts, lastError: reason)
        }
        trim()
    }

    /// 失敗したものを手動で送り直すとき。
    public mutating func retry(_ id: UUID) {
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[i].status = .pending(attempts: 0, lastError: nil)
    }

    public mutating func remove(_ id: UUID) {
        entries.removeAll { $0.id == id }
    }

    private mutating func trim() {
        while entries.count > capacity,
              let last = entries.lastIndex(where: { if case .pending = $0.status { false } else { true } }) {
            entries.remove(at: last)
        }
    }
}
