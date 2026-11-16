import Foundation
import SwiftUI
import WatchKit
import WatchHookCore

/// 標準の入力画面 (音声入力・スクリブル・キーボード) を、ボタンを押さずにコードから開く。
/// SwiftUI には `TextFieldLink` を外から開く手段が無いので、WatchKit の入力画面を使う。
@MainActor enum SystemTextInput {
    enum Outcome {
        case entered(String)
        /// キャンセルした・閉じた
        case cancelled
        /// 入力画面を出せなかった (画面がまだ無い・すでに出している)
        case unavailable
    }

    /// 出している入力画面の結果の待ち。二重に出さないため・裏へ回ったときに閉じるために持つ。
    private static var waiting: Waiting?

    static var isPresented: Bool { waiting != nil }

    /// 入力画面を開いて、閉じるまで待つ。
    static func present() async -> Outcome {
        guard waiting == nil, let controller = currentController else { return .unavailable }
        let current = Waiting()
        waiting = current
        let text = await withCheckedContinuation { continuation in
            current.start(continuation)
            controller.presentTextInputController(
                withSuggestions: nil, allowedInputMode: .plain,
                completion: completion(resuming: current))
        }
        if waiting === current { waiting = nil }
        return text.map(Outcome.entered) ?? .cancelled
    }

    /// 出している入力画面を閉じる (裏へ回ったとき)。戻ったときに新しく開き直す。
    static func dismiss() {
        guard let current = waiting else { return }
        waiting = nil
        currentController?.dismissTextInputController()
        current.finish(nil)
    }

    private static var currentController: WKInterfaceController? {
        let app = WKApplication.shared()
        return app.visibleInterfaceController ?? app.rootInterfaceController
    }

    /// 完了ハンドラは nonisolated で作る (MainActor の中で作ると、OS のキューから呼ばれたときに Swift 6 の実行時チェックで落ちる)。
    private nonisolated static func completion(resuming waiting: Waiting) -> ([Any]?) -> Void {
        { results in waiting.finish(results?.first as? String) }
    }

    /// 結果を 1 回だけ返す (OS の完了ハンドラと `dismiss` のどちらが先でもよいように)。
    private final class Waiting: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<String?, Never>?

        func start(_ continuation: CheckedContinuation<String?, Never>) {
            lock.withLock { self.continuation = continuation }
        }

        func finish(_ text: String?) {
            let continuation: CheckedContinuation<String?, Never>? = lock.withLock {
                defer { self.continuation = nil }
                return self.continuation
            }
            continuation?.resume(returning: text)
        }
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
