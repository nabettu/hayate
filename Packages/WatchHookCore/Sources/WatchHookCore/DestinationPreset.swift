import Foundation

/// 送り先を足すときのひな形。Slack・Discord 以外は自由な webhook (`.custom`) に URL・ヘッダ・本文を入れておくだけ。
/// `<...>` は利用者が埋めるところ (URL に残っていると保存できない)。
public enum DestinationPreset: String, CaseIterable, Identifiable, Sendable {
    case custom
    case slack
    case discord
    case googleChat
    case teams
    case telegram
    case ntfy
    case notion
    case todoist
    case homeAssistant
    case n8n
    case ifttt

    public var id: String { rawValue }

    /// 一覧に出す名前 (サービス名なので訳さない。自由な webhook だけ訳す)
    public var title: String {
        switch self {
        case .custom: String(localized: "Webhook (自由に設定)", bundle: .module)
        case .slack: "Slack"
        case .discord: "Discord"
        case .googleChat: "Google Chat"
        case .teams: "Microsoft Teams"
        case .telegram: "Telegram"
        case .ntfy: "ntfy"
        case .notion: "Notion"
        case .todoist: "Todoist"
        case .homeAssistant: "Home Assistant"
        case .n8n: "n8n"
        case .ifttt: "IFTTT"
        }
    }

    public func make() -> Destination {
        switch self {
        case .custom: return .preset(.custom)
        case .slack: return .preset(.slack)
        case .discord: return .preset(.discord)
        case .googleChat:
            return Destination(name: title, kind: .custom, bodyTemplate: #"{"text":"{{text}}"}"#)
        case .teams:
            // Teams の「Workflows」の webhook (Post to a channel when a webhook request is received) が受け取る Adaptive Card
            return Destination(name: title, kind: .custom, bodyTemplate: #"{"type":"message","attachments":[{"contentType":"application/vnd.microsoft.card.adaptive","content":{"type":"AdaptiveCard","$schema":"http://adaptivecards.io/schemas/adaptive-card.json","version":"1.4","body":[{"type":"TextBlock","text":"{{text}}","wrap":true}]}}]}"#)
        case .telegram:
            return Destination(name: title, kind: .custom, url: "https://api.telegram.org/bot<TOKEN>/sendMessage",
                               bodyTemplate: #"{"chat_id":"<CHAT_ID>","text":"{{text}}"}"#)
        case .ntfy:
            return Destination(name: title, kind: .custom, url: "https://ntfy.sh/<topic>", bodyEncoding: .plain, bodyTemplate: "{{text}}")
        case .notion:
            return Destination(name: title, kind: .custom, url: "https://api.notion.com/v1/pages",
                               headers: [HeaderField(name: "Authorization", value: "Bearer <TOKEN>", isSecret: true),
                                         HeaderField(name: "Notion-Version", value: "2022-06-28")],
                               bodyTemplate: #"{"parent":{"database_id":"<DATABASE_ID>"},"properties":{"Name":{"title":[{"text":{"content":"{{text}}"}}]}}}"#)
        case .todoist:
            // Quick Add: 「明日 15時」などの日時・#プロジェクトを Todoist 側で読む
            return Destination(name: title, kind: .custom, url: "https://api.todoist.com/api/v1/tasks/quick",
                               headers: [HeaderField(name: "Authorization", value: "Bearer <TOKEN>", isSecret: true)],
                               bodyTemplate: #"{"text":"{{text}}"}"#)
        case .homeAssistant:
            return Destination(name: title, kind: .custom, url: "https://<host>/api/webhook/<webhook_id>",
                               bodyTemplate: Destination.preset(.custom).bodyTemplate)
        case .n8n:
            return Destination(name: title, kind: .custom, url: "https://<host>/webhook/<path>",
                               bodyTemplate: Destination.preset(.custom).bodyTemplate)
        case .ifttt:
            return Destination(name: title, kind: .custom, url: "https://maker.ifttt.com/trigger/<event>/json/with/key/<key>",
                               bodyTemplate: Destination.preset(.custom).bodyTemplate)
        }
    }
}
