import Foundation

/// 時計の履歴を iPhone に見せるための写し。時計 → iPhone へ WatchConnectivity の applicationContext で送る
/// (最新の 1 件だけが届けばよく、iPhone のアプリが閉じていても次に起きたときに受け取れる)。
/// applicationContext の大きさには上限があるので、本文は切り、それでも大きければ古いものから落とす。
public struct HistorySnapshot: Codable, Hashable, Sendable {
    public var entries: [MessageLogEntry]
    public var updatedAt: Date

    public static let defaultMaxTextLength = 200
    /// applicationContext に載せる上限の目安。OS の上限より十分小さくしておく。
    public static let defaultMaxBytes = 48_000

    public init(log: MessageLog, updatedAt: Date, maxTextLength: Int = HistorySnapshot.defaultMaxTextLength) {
        self.updatedAt = updatedAt
        self.entries = log.entries.map { entry in
            var e = entry
            if e.message.text.count > maxTextLength {
                e.message.text = String(e.message.text.prefix(maxTextLength)) + "…"
            }
            return e
        }
    }

    public func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    /// `maxBytes` に収まるまで古いもの (末尾) から落として符号化する。
    public func encoded(maxBytes: Int) throws -> Data {
        var copy = self
        var data = try copy.encoded()
        while data.count > maxBytes, !copy.entries.isEmpty {
            // 1 件ずつ落とすと 50 件で 50 回符号化するので、超えた割合に応じてまとめて落とす (最低 1 件)
            let ratio = Double(maxBytes) / Double(data.count)
            let keep = min(copy.entries.count - 1, Int(Double(copy.entries.count) * ratio))
            copy.entries = Array(copy.entries.prefix(max(0, keep)))
            data = try copy.encoded()
        }
        return data
    }

    public static func decode(_ data: Data) throws -> HistorySnapshot {
        try JSONDecoder().decode(HistorySnapshot.self, from: data)
    }
}

/// iPhone の履歴画面に出す、手元と時計の履歴を合わせた一覧。
public enum CombinedHistory {
    public enum Origin: String, Hashable, Sendable {
        case thisDevice
        case watch
    }

    public struct Row: Hashable, Identifiable, Sendable {
        public var entry: MessageLogEntry
        public var origin: Origin
        public var id: String { "\(origin.rawValue)-\(entry.id.uuidString)" }
    }

    /// 新しい順。同じメッセージ ID が両方にあれば手元のものを使う (手元なら再送・削除ができるため)。
    public static func rows(local: [MessageLogEntry], watch: [MessageLogEntry]) -> [Row] {
        let localIDs = Set(local.map(\.id))
        let rows = local.map { Row(entry: $0, origin: .thisDevice) }
            + watch.filter { !localIDs.contains($0.id) }.map { Row(entry: $0, origin: .watch) }
        return rows.sorted { $0.entry.message.createdAt > $1.entry.message.createdAt }
    }
}
