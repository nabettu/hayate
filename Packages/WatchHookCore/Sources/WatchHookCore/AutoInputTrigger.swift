/// Watch アプリを開いたときに、ボタンを押さなくても入力画面を自動で開くかを決める。
///
/// 起動したときと、裏 (background) から前面に戻ったとき (文字盤のコンプリケーション・アプリ一覧から開いたとき) に開く。
/// 手首を下げて上げただけ (inactive → active) では開かない。手首を上げるたびに入力が出ると煩わしいため。
public struct AutoInputTrigger: Sendable {
    /// SwiftUI の `ScenePhase` に対応する (Core は SwiftUI に依存しないので写しを持つ)。
    public enum Phase: Sendable {
        case active, inactive, background
    }

    /// 起動直後は裏から来たのと同じに扱う。
    private var cameFromBackground = true

    public init() {}

    /// 画面の状態が変わるたびに呼ぶ。入力画面を開くべきなら true。
    public mutating func update(_ phase: Phase) -> Bool {
        switch phase {
        case .background:
            cameFromBackground = true
            return false
        case .inactive:
            return false
        case .active:
            defer { cameFromBackground = false }
            return cameFromBackground
        }
    }
}
