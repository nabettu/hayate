import Foundation
import Testing
@testable import WatchHookCore

struct DestinationDisplayNameTests {
    @Test func 名前があればそのまま出す() {
        let d = Destination(name: "家族の Slack", kind: .slack, url: "https://hooks.slack.com/services/T/B/secret", bodyTemplate: "")
        #expect(d.displayName == "家族の Slack")
    }

    @Test func 前後の空白は落とす() {
        let d = Destination(name: "  メモ  \n", kind: .custom, url: "https://example.com/hook", bodyTemplate: "")
        #expect(d.displayName == "メモ")
    }

    @Test func 名前が空なら_URL_のホストだけを出す() {
        // パスには Slack の webhook のように秘密が入ることがあるので出さない
        let d = Destination(name: "", kind: .slack, url: "https://hooks.slack.com/services/T/B/secret", bodyTemplate: "")
        #expect(d.displayName == "hooks.slack.com")
    }

    @Test func 名前が空白だけでも_URL_のホストを出す() {
        let d = Destination(name: "   ", kind: .custom, url: " https://example.com:8443/hook?token=x ", bodyTemplate: "")
        #expect(d.displayName == "example.com")
    }

    @Test(arguments: [
        (DestinationKind.custom, "Webhook"),
        (.slack, "Slack"),
        (.discord, "Discord"),
    ])
    func 名前も_URL_も無ければ種類の名前を出す(kind: DestinationKind, expected: String) {
        let d = Destination(name: "", kind: kind, url: "", bodyTemplate: "")
        #expect(d.displayName == expected)
    }

    @Test func 読めない_URL_なら種類の名前を出す() {
        let d = Destination(name: "", kind: .discord, url: "not a url", bodyTemplate: "")
        #expect(d.displayName == "Discord")
    }

    @Test func これまでの形式で保存された設定もそのまま読める() throws {
        // 名前の欄は最初からある。表示名の追加で保存形式は変えない
        let id = UUID()
        let json = """
        {"destinations":[{"id":"\(id.uuidString)","name":"","kind":"slack","url":"https://hooks.slack.com/services/x","method":"POST","headers":[],"bodyEncoding":"json","bodyTemplate":"{}"}],
         "defaultDestinationID":"\(id.uuidString)","revision":3,"epoch":"\(UUID().uuidString)"}
        """
        let config = try DestinationConfig.decode(Data(json.utf8))
        #expect(config.destinations.first?.displayName == "hooks.slack.com")
        let reencoded = try JSONSerialization.jsonObject(with: try config.encoded()) as? [String: Any]
        let first = (reencoded?["destinations"] as? [[String: Any]])?.first
        #expect(first?["displayName"] == nil)
        #expect(first?["name"] as? String == "")
    }
}
