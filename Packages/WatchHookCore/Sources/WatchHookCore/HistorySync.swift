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

    /// `maxBytes` に収まるよう、新しいものから残せるだけ残して符号化する。
    /// 項目ごとの大きさは偏りうる (古い 1 件だけが大きいなど) ので、件数の割合ではなく実際の大きさで二分探索する。
    public func encoded(maxBytes: Int) throws -> Data {
        let full = try encoded()
        if full.count <= maxBytes { return full }
        var copy = self
        func encode(keeping n: Int) throws -> Data {
            copy.entries = Array(entries.prefix(n))
            return try copy.encoded()
        }
        // 0 件なら必ず収まる前提。収まる最大の件数を探す
        var lo = 0, hi = entries.count - 1
        var best = try encode(keeping: 0)
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            let data = try encode(keeping: mid)
            if data.count <= maxBytes {
                lo = mid
                best = data
            } else {
                hi = mid - 1
            }
        }
        return best
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
