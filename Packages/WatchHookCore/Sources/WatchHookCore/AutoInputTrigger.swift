/// Watch アプリを開いたときに、ボタンを押さなくても入力画面を自動で開くかを決める。
///
/// 起動したときと、裏 (background) から前面に戻ったとき (文字盤のコンプリケーション・アプリ一覧から開いたとき) に開く。
/// 手首を下げて上げただけ (inactive → active) では開かない。手首を上げるたびに入力が出ると煩わしいため。
/// 送信中・入力中に戻ったときは、終わるまで待ってから開く。
public struct AutoInputTrigger: Sendable {
    /// SwiftUI の `ScenePhase` に対応する (Core は SwiftUI に依存しないので写しを持つ)。
    public enum Phase: Sendable {
        case active, inactive, background
    }

    /// 開くのを待っている (起動直後は裏から来たのと同じに扱う)。
    private var pending = true
    private var isActive = false

    public init() {}

    /// 画面の状態が変わるたびに呼ぶ。
    public mutating func update(_ phase: Phase) {
        isActive = phase == .active
        if phase == .background { pending = true }
    }

    /// 今開くべきなら true を返し、待ちを消す。`busy` (送信中・入力画面を出している) のあいだは待ちを残して false。
    public mutating func take(busy: Bool) -> Bool {
        guard pending, isActive, !busy else { return false }
        pending = false
        return true
    }

    /// 「メモ」ボタンで入力画面を開いたとき。待っていた自動の入力は、これで済んだことにする。
    public mutating func openedByHand() {
        pending = false
    }

    /// `take` で開こうとしたが、入力画面を出せなかったとき。次に前面に来たときにまた開く。
    public mutating func couldNotOpen() {
        pending = true
    }
}
