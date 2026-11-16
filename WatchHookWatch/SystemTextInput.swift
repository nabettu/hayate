import SwiftUI
import WatchKit
import WatchHookCore

/// 標準の入力画面 (音声入力・スクリブル・キーボード) を、ボタンを押さずにコードから開く。
/// SwiftUI には `TextFieldLink` を外から開く手段が無いので、WatchKit の入力画面を使う。
enum SystemTextInput {
    /// 入力画面を開いて、入力した文字を返す。キャンセルしたとき・開けなかったときは nil。
    @MainActor static func present() async -> String? {
        let app = WKApplication.shared()
        guard let controller = app.visibleInterfaceController ?? app.rootInterfaceController else { return nil }
        return await withCheckedContinuation { continuation in
            controller.presentTextInputController(
                withSuggestions: nil, allowedInputMode: .plain,
                completion: completion(resuming: continuation))
        }
    }

    /// 完了ハンドラは nonisolated で作る (MainActor の中で作ると、OS のキューから呼ばれたときに Swift 6 の実行時チェックで落ちる)。
    private nonisolated static func completion(
        resuming continuation: CheckedContinuation<String?, Never>
    ) -> ([Any]?) -> Void {
        { results in continuation.resume(returning: results?.first as? String) }
    }
}

extension AutoInputTrigger.Phase {
    init(_ phase: ScenePhase) {
        switch phase {
        case .active: self = .active
        case .background: self = .background
        default: self = .inactive
        }
    }
}
