/// 同じ要求を何度か出したとき、最後に出した要求への返信だけを受け入れる (遅れて届いた古い返信で巻き戻さない)。
public struct LatestRequestGate: Sendable {
    private var latest = 0

    public init() {}

    public mutating func begin() -> Int {
        latest += 1
        return latest
    }

    public func isLatest(_ token: Int) -> Bool {
        token == latest
    }
}
