/// 時計が iPhone から設定を取り寄せる状態と、画面にエラーを出すかどうか。
///
/// 起動直後 (と前面に戻った直後) は、時計と iPhone のつながりが落ち着く前で、取り寄せが失敗しやすい
/// (「つながっていない」→ すぐ「つながった」と揺れる)。失敗のたびにエラーを出すと、次の取り寄せが成功して
/// 消えるまでの一瞬だけ赤字が出る。そこで準備中はエラーを出さずに取り直し、準備が終わってから出す。
/// 準備が終わるのは、取り寄せが成功したとき・取り直しても失敗したとき・打ち切り (`startupLimit`) のとき。
public struct ConfigSyncStatus: Equatable, Sendable {
    /// 準備中に失敗したときの、取り直すまでの待ち。使い切ったらエラーを出す
    public static let startupRetryDelays: [Duration] = [.seconds(1), .seconds(2)]
    /// 返事が来ない・つながらないままのときに準備中を打ち切るまでの長さ。取り直しを待ち切れる長さにする
    public static let startupLimit: Duration = .seconds(5)

    public enum FailureAction: Equatable, Sendable {
        /// エラーは出さずに、待ってから取り直す
        case retry(after: Duration)
        /// エラーを出す
        case show
    }

    public private(set) var isStarting = false
    private var generation = 0
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

    public mutating func succeeded() {
        error = nil
        isStarting = false
    }

    public mutating func failed(_ message: String) -> FailureAction {
        error = message
        guard isStarting, startupFailures < Self.startupRetryDelays.count else {
            isStarting = false
            return .show
        }
        let delay = Self.startupRetryDelays[startupFailures]
        startupFailures += 1
        return .retry(after: delay)
    }
}
