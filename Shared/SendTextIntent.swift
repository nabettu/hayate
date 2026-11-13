import AppIntents
import Foundation
import WatchHookCore

/// 「Hey Siri、Hayate でメモして」→ Siri が聞き取ったテキストをメモに保存し、有効にした送り先へ送る。
/// アプリの画面は開かない (時計でも iPhone でも裏で完結する)。
struct SendTextIntent: AppIntent {
    static let title: LocalizedStringResource = "メモする"
    static let description = IntentDescription("話した内容をメモに保存し、有効にした送り先 (webhook) へ送ります。")
    static let openAppWhenRun = false

    @Parameter(title: "テキスト", requestValueDialog: "何をメモしますか？")
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$text) をメモする")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // 設定を読めないまま保存すると、送り先へ送らずにメモだけ残ってしまう
        guard (try? ConfigStore.loadFromKeychain()) != nil else {
            return .result(dialog: "設定を読み込めませんでした。iPhone / Apple Watch のロックを解除してからもう一度試してください。")
        }
        guard let trimmed = MessageText.normalized(text) else {
            return .result(dialog: "テキストが空でした。")
        }
        #if os(watchOS)
        let source = "siri-watch"
        let role = DeviceRole.watch
        #else
        let source = "siri-phone"
        let role = DeviceRole.phone
        #endif
        let feedback = MemoFeedback(memo: await MemoDispatcher.shared.record(text: trimmed, source: source), role: role)
        if let detail = feedback.detail {
            return .result(dialog: "\(feedback.title) \(detail)")
        }
        return .result(dialog: "\(feedback.title)")
    }
}

struct WatchHookShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SendTextIntent(),
            phrases: [
                "\(.applicationName)で送って",
                "\(.applicationName)で送る",
                "\(.applicationName)に送って",
            ],
            shortTitle: "メモする",
            systemImageName: "waveform"
        )
    }
}
