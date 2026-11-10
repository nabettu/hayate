import Foundation
import Testing
@testable import WatchHookCore

/// 送り先ごとに、話した内容の前後へ付ける文 (例: 前に「#買い物 」)。
struct DestinationAffixTests {
    @Test func 前後の文を付ける() {
        var d = Destination(name: "買い物", kind: .slack, bodyTemplate: "")
        d.textPrefix = "#買い物 "
        d.textSuffix = " (Watch から)"
        #expect(d.wrap("牛乳") == "#買い物 牛乳 (Watch から)")
    }

    @Test func 空なら話した内容のまま() {
        let d = Destination(name: "", kind: .custom, bodyTemplate: "")
        #expect(d.wrap("牛乳") == "牛乳")
    }

    @Test func 空白や改行は書いたとおりに付ける() {
        // 区切りを入れるかは利用者が決める (勝手に空白を足さない)
        var d = Destination(name: "", kind: .custom, bodyTemplate: "")
        d.textPrefix = "メモ:\n"
        #expect(d.wrap("牛乳") == "メモ:\n牛乳")
    }

    @Test func 前後の文が無い形式で保存された設定も読める() throws {
        let id = UUID()
        let json = """
        {"destinations":[{"id":"\(id.uuidString)","name":"x","kind":"slack","url":"https://hooks.slack.com/services/x","method":"POST","headers":[],"bodyEncoding":"json","bodyTemplate":"{}"}],
         "defaultDestinationID":"\(id.uuidString)","revision":3,"epoch":"\(UUID().uuidString)"}
        """
        let config = try DestinationConfig.decode(Data(json.utf8))
        #expect(config.destinations.first?.textPrefix == "")
        #expect(config.destinations.first?.textSuffix == "")
    }

    @Test func 前後の文は保存して読み直しても残る() throws {
        var d = Destination(name: "x", kind: .discord, bodyTemplate: "{}")
        d.textPrefix = "【メモ】"
        d.textSuffix = "!"
        let back = try JSONDecoder().decode(Destination.self, from: JSONEncoder().encode(d))
        #expect(back == d)
    }
}
