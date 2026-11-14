/// 時計が iPhone から設定を取り寄せる状態と、画面にエラーを出すかどうか。
///
/// 起動直後 (と前面に戻った直後) は、時計と iPhone のつながりが落ち着く前で、取り寄せが失敗しやすい
/// (「つながっていない」→ すぐ「つながった」と揺れる)。失敗のたびにエラーを出すと、次の取り寄せが成功して
/// 消えるまでの一瞬だけ赤字が出る。そこで準備中はエラーを出さずに取り直し、準備が終わってから出す。
/// 準備が終わるのは、取り寄せが成功したとき・取り直しても失敗したとき・打ち切り (`startupLimit`) のとき。
///
/// 取り寄せは何度か出ることがある (つながった知らせ・前面に戻った・取り直し)。結果を受け入れるのは最後に出した要求だけで、
/// 前の準備期間 (前面に戻る前) に出した要求の結果では、今の準備期間を終えたり取り直しの回数を使ったりしない。
public struct ConfigSyncStatus: Equatable, Sendable {
    /// 準備中に失敗したときの、取り直すまでの待ち。使い切ったらエラーを出す
    public static let startupRetryDelays: [Duration] = [.seconds(1), .seconds(2)]
    /// 返事が来ない・つながらないままのときに準備中を打ち切るまでの長さ。取り直しを待ち切れる長さにする
    public static let startupLimit: Duration = .seconds(5)

    /// 1 回の取り寄せ。どの準備期間に出したかも持つ
    public struct Ticket: Equatable, Sendable {
        let request: Int
        let generation: Int
    }

    public enum FailureAction: Equatable, Sendable {
        /// エラーは出さずに、待ってから取り直す (`shouldRetry(after:)` で、その時点でもまだ要るかを確かめる)
        case retry(after: Duration)
        /// エラーを出す
        case show
        /// 古い要求の結果なので何もしない
        case ignore
    }

    public private(set) var isStarting = false
    private var generation = 0
    private var latestRequest = 0
    private var error: String?
    private var startupFailures = 0

    public init() {}

    /// 画面に出すエラー。準備中は出さない。
    public var visibleError: String? { isStarting ? nil : error }

    /// 起動した・前面に戻ったとき。打ち切りに使う世代を返す。
    @discardableResult
    public mutating func beginStartup() -> Int {
        generation += 1
        isStarting = true
        startupFailures = 0
        return generation
    }

    /// 打ち切り。`beginStartup` で受け取った世代のときだけ終える (前の起動の打ち切りで今の準備中を終えない)。
    public mutating func endStartup(generation: Int) {
        guard generation == self.generation else { return }
        isStarting = false
    }

    /// 取り寄せを出すとき。これより前に出した要求の結果は受け入れなくなる。
    public mutating func beginRequest() -> Ticket {
        latestRequest += 1
        return Ticket(request: latestRequest, generation: generation)
    }

    /// 最後に出した要求か。届いた設定を使ってよいかの判定にも使う (遅れて届いた古い返信で巻き戻さない)。
    public func isLatest(_ ticket: Ticket) -> Bool {
        ticket.request == latestRequest
    }

    /// 成功した。最新の要求でなければ何もせず false (届いた設定も使わない)。
    /// 前の準備期間の要求なら、設定は使ってよいが今の準備期間は終えない (この後の失敗を出さずに取り直すため)。
    @discardableResult
    public mutating func succeeded(_ ticket: Ticket) -> Bool {
        guard isLatest(ticket) else { return false }
        error = nil
        if ticket.generation == generation { isStarting = false }
        return true
    }

    public mutating func failed(_ message: String, _ ticket: Ticket) -> FailureAction {
        guard isLatest(ticket), ticket.generation == generation else { return .ignore }
        error = message
        guard isStarting, startupFailures < Self.startupRetryDelays.count else {
            isStarting = false
            return .show
        }
        let delay = Self.startupRetryDelays[startupFailures]
        startupFailures += 1
        return .retry(after: delay)
    }

    /// 予約した取り直しを、待った後に行うか。その間に別の要求を出した・前面に戻ったなら行わない
    /// (行うと、成功した後の余計な要求で赤字を出したり、返事待ちの要求の返信を古いものとして捨てたりする)。
    public func shouldRetry(after ticket: Ticket) -> Bool {
        isLatest(ticket) && ticket.generation == generation
    }
}
