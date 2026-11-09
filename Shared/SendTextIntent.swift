import AppIntents
import Foundation
import WatchHookCore

/// 送り先をショートカット / Siri から選べるようにする。
struct DestinationEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "送り先"
    static let defaultQuery = DestinationQuery()

    var id: UUID
    var name: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct DestinationQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [DestinationEntity] {
        try ConfigStore.loadFromKeychain().destinations
            .filter { identifiers.contains($0.id) }
            .map { DestinationEntity(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [DestinationEntity] {
        try ConfigStore.loadFromKeychain().destinations.map { DestinationEntity(id: $0.id, name: $0.name) }
    }
}

/// 「Hey Siri、WatchHook で送って」→ Siri が聞き取ったテキストをそのまま送り先へ送る。
/// アプリの画面は開かない (時計でも iPhone でも裏で完結する)。
struct SendTextIntent: AppIntent {
    static let title: LocalizedStringResource = "テキストを送る"
    static let description = IntentDescription("話した内容を登録した送り先 (webhook) へ送ります。")
    static let openAppWhenRun = false

    @Parameter(title: "テキスト", requestValueDialog: "何を送りますか？")
    var text: String

    @Parameter(title: "送り先")
    var destination: DestinationEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$text) を \(\.$destination) へ送る")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let config = try? ConfigStore.loadFromKeychain() else {
            return .result(dialog: "設定を読み込めませんでした。iPhone / Apple Watch のロックを解除してからもう一度試してください。")
        }
        // 送り先を指定されたのに見つからないときは、既定の送り先へ回さない (意図しない相手に送らない)
        let target: Destination
        if let destination {
            guard let found = config.destination(id: destination.id) else {
                return .result(dialog: "送り先「\(destination.name)」が見つかりません。送っていません。")
            }
            target = found
        } else {
            guard let found = config.defaultDestination else {
                return .result(dialog: "送り先がありません。iPhone の WatchHook で登録してください。")
            }
            target = found
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .result(dialog: "テキストが空でした。")
        }
        #if os(watchOS)
        let source = "siri-watch"
        #else
        let source = "siri-phone"
        #endif
        let status = await MessageDispatcher.shared.send(text: trimmed, destination: target, source: source)
        switch status {
        case .sent:
            return .result(dialog: "\(target.name) に送りました。")
        case .pending:
            return .result(dialog: "今は送れませんでした。あとで送り直します。")
        case .failed(let reason):
            return .result(dialog: "送れませんでした。\(reason)")
        }
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
            shortTitle: "送る",
            systemImageName: "waveform"
        )
    }
}
