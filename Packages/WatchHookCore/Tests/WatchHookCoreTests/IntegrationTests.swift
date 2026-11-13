import Foundation
import Testing
@testable import WatchHookCore

@Suite("連携の組み立て")
struct IntegrationTests {
    func config(_ destinations: [Destination]) -> DestinationConfig {
        DestinationConfig(destinations: destinations)
    }

    @Test func 有効な送り先すべてに_時計が受け持つ連携を作る() {
        var a = Destination.preset(.slack)
        a.name = "A"
        a.textPrefix = "#memo "
        var b = Destination.preset(.discord)
        b.isEnabled = false
        let c = Destination.preset(.custom)
        let ds = MemoPlanner.webhookDeliveries(text: "牛乳", config: config([a, b, c]), owner: .watch)
        #expect(ds.map(\.target) == [.webhook(destinationID: a.id, name: "A"), .webhook(destinationID: c.id, name: c.displayName)])
        #expect(ds.allSatisfy { $0.owner == .watch })
        // 前後の文は送り先ごとに付ける (元の入力はメモに残る)
        #expect(ds[0].text == "#memo 牛乳")
        #expect(ds[1].text == "牛乳")
    }

    @Test func リマインダーは合図があるときだけ_合図を除いた本文で作る() {
        let settings = IntegrationSettings(reminder: .init(isEnabled: true, listID: "L1", listName: "買い物", keywords: ["リマインダー"]))
        let ds = MemoPlanner.phoneDeliveries(text: "リマインダー、牛乳を買う", settings: settings)
        #expect(ds.count == 1)
        #expect(ds[0].target == .reminder(listName: "買い物"))
        #expect(ds[0].text == "牛乳を買う")
        #expect(ds[0].owner == .phone)
        #expect(MemoPlanner.phoneDeliveries(text: "牛乳を買う", settings: settings).isEmpty)
        // 合図だけ: メモだけ残す
        #expect(MemoPlanner.phoneDeliveries(text: "リマインダー", settings: settings).isEmpty)
    }

    @Test func リマインダーは無効_リスト未選択なら作らない() {
        var settings = IntegrationSettings(reminder: .init(isEnabled: false, listID: "L1", listName: "x", keywords: ["リマインダー"]))
        #expect(MemoPlanner.phoneDeliveries(text: "リマインダー、a", settings: settings).isEmpty)
        settings.reminder = .init(isEnabled: true, listID: nil, listName: nil, keywords: ["リマインダー"])
        #expect(MemoPlanner.phoneDeliveries(text: "リマインダー、a", settings: settings).isEmpty)
    }

    @Test func Markdown_は有効ならすべてのメモを元の入力のまま() {
        let settings = IntegrationSettings(
            reminder: .init(isEnabled: true, listID: "L", listName: "L", keywords: ["リマインダー"]),
            markdown: .init(isEnabled: true, folderName: "Vault")
        )
        let ds = MemoPlanner.phoneDeliveries(text: "リマインダー、牛乳", settings: settings)
        #expect(ds.map(\.target) == [.reminder(listName: "L"), .markdown(folderName: "Vault")])
        #expect(ds[1].text == "リマインダー、牛乳")
        #expect(MemoPlanner.phoneDeliveries(text: "a", settings: IntegrationSettings(markdown: .init(isEnabled: true, folderName: nil))).isEmpty)
    }

    @Test func 設定は保存して読み直せる_古い保存にキーが無くても読める() throws {
        let s = IntegrationSettings(reminder: .init(isEnabled: true, listID: "L", listName: "N", keywords: ["a"]), markdown: .init(isEnabled: true, folderName: "F"))
        #expect(try JSONDecoder().decode(IntegrationSettings.self, from: JSONEncoder().encode(s)) == s)
        let empty = try JSONDecoder().decode(IntegrationSettings.self, from: Data("{}".utf8))
        #expect(empty.reminder.isEnabled == false)
        #expect(empty.markdown.isEnabled == false)
        #expect(empty.reminder.keywords.isEmpty == false)
    }
}

@Suite("Markdown への追記")
struct MarkdownJournalTests {
    var tokyo: TimeZone { TimeZone(identifier: "Asia/Tokyo")! }

    @Test func 日付ごとのファイル名() {
        let d = Date(timeIntervalSince1970: 1_763_000_000) // 2025-11-13 02:13 UTC = 11:13 JST
        #expect(MarkdownJournal.fileName(for: d, timeZone: tokyo) == "2025-11-13.md")
        #expect(MarkdownJournal.fileName(for: d, timeZone: TimeZone(identifier: "America/Los_Angeles")!) == "2025-11-12.md")
    }

    @Test func 一行の書式_改行は字下げして続ける() {
        let d = Date(timeIntervalSince1970: 1_763_000_000)
        #expect(MarkdownJournal.line(text: "牛乳を買う", date: d, timeZone: tokyo) == "- 11:13 牛乳を買う")
        #expect(MarkdownJournal.line(text: "a\nb\r\nc", date: d, timeZone: tokyo) == "- 11:13 a\n  b\n  c")
    }

    @Test func 追記は末尾の改行をそろえ_同じ行は二重に足さない() {
        #expect(MarkdownJournal.appending("- 10:00 a", to: "") == "- 10:00 a\n")
        #expect(MarkdownJournal.appending("- 10:00 a", to: "# 見出し") == "# 見出し\n- 10:00 a\n")
        #expect(MarkdownJournal.appending("- 10:00 b", to: "x\n") == "x\n- 10:00 b\n")
        #expect(MarkdownJournal.appending("- 10:00 a", to: "- 10:00 a\n") == nil)
        #expect(MarkdownJournal.appending("- 10:00 a", to: "- 10:00 ab\n") == "- 10:00 ab\n- 10:00 a\n")
    }

    @Test func 複数行の項目は全体が一致したときだけ同じとみなす() {
        // 先頭の行だけ同じ別の項目が前にあっても、後ろに同じ項目があれば足さない
        let existing = "- 10:00 a\n  x\n- 10:00 a\n  b\n"
        #expect(MarkdownJournal.appending("- 10:00 a\n  b", to: existing) == nil)
        // 既にある複数行の項目の頭だけと一致する短いメモは、別のメモとして足す
        #expect(MarkdownJournal.appending("- 10:00 a", to: "- 10:00 a\n  b\n") == "- 10:00 a\n  b\n- 10:00 a\n")
        #expect(MarkdownJournal.appending("- 10:00 a\n  b", to: "- 10:00 a\n  b\n  c\n") == "- 10:00 a\n  b\n  c\n- 10:00 a\n  b\n")
        // 同じ単一行の項目の後ろに別の項目が続いていても、同じとみなす
        #expect(MarkdownJournal.appending("- 10:00 a", to: "- 10:00 a\n- 10:01 b\n") == nil)
    }
}

@Suite("送り先の設定の移行")
struct ConfigMigrationTests {
    @Test func 旧形式は既定の送り先だけ有効にする() throws {
        let a = UUID(), b = UUID()
        let json = """
        {"destinations":[
          {"id":"\(a.uuidString)","name":"A","kind":"slack","url":"https://x","method":"POST","headers":[],"bodyEncoding":"json","bodyTemplate":"{}"},
          {"id":"\(b.uuidString)","name":"B","kind":"discord","url":"https://y","method":"POST","headers":[],"bodyEncoding":"json","bodyTemplate":"{}"}
        ],"defaultDestinationID":"\(b.uuidString)","revision":3,"epoch":"\(UUID().uuidString)"}
        """
        let c = try DestinationConfig.decode(Data(json.utf8))
        #expect(c.destinations.map(\.isEnabled) == [false, true])
        #expect(c.enabledDestinations.map(\.id) == [b])
        #expect(c.revision == 3)
    }

    @Test func 旧形式で既定が無ければ先頭だけ有効にする() throws {
        let a = UUID(), b = UUID()
        let json = """
        {"destinations":[
          {"id":"\(a.uuidString)","name":"A","kind":"slack","url":"https://x","method":"POST","headers":[],"bodyEncoding":"json","bodyTemplate":"{}"},
          {"id":"\(b.uuidString)","name":"B","kind":"discord","url":"https://y","method":"POST","headers":[],"bodyEncoding":"json","bodyTemplate":"{}"}
        ],"revision":1,"epoch":"\(UUID().uuidString)"}
        """
        let c = try DestinationConfig.decode(Data(json.utf8))
        #expect(c.destinations.map(\.isEnabled) == [true, false])
    }

    @Test func 新形式は有効_無効をそのまま読む() throws {
        var a = Destination.preset(.slack)
        a.isEnabled = false
        let b = Destination.preset(.discord)
        let c = DestinationConfig(destinations: [a, b], revision: 2)
        let back = try DestinationConfig.decode(c.encoded())
        #expect(back.destinations.map(\.isEnabled) == [false, true])
        #expect(back == c)
    }
}

@Suite("送り先のプリセット")
struct DestinationPresetTests {
    @Test func どのプリセットも本文の形式に合ったテンプレートを持つ() throws {
        for preset in DestinationPreset.allCases {
            var d = preset.make()
            #expect(!d.name.isEmpty, "\(preset)")
            #expect(d.bodyTemplate.contains("{{text}}"), "\(preset)")
            // URL の <...> を埋めれば組み立てられる
            d.url = d.url.isEmpty ? "https://example.com/hook" : d.url.replacingOccurrences(of: "<", with: "x").replacingOccurrences(of: ">", with: "x")
            d.bodyTemplate = d.bodyTemplate.replacingOccurrences(of: "<", with: "x").replacingOccurrences(of: ">", with: "x")
            for i in d.headers.indices {
                d.headers[i].value = d.headers[i].value.replacingOccurrences(of: "<", with: "x").replacingOccurrences(of: ">", with: "x")
            }
            _ = try RequestBuilder.build(destination: d, message: OutgoingMessage(text: "a\"b", destinationID: d.id, source: "t"))
        }
    }

    @Test func 埋めるところが残っていると保存できない() {
        for preset in DestinationPreset.allCases {
            var d = preset.make()
            if d.url.isEmpty { d.url = "https://example.com/hook" }
            let hasPlaceholder = d.url.contains("<") || d.bodyTemplate.contains("<") || d.headers.contains { $0.value.contains("<") }
            if hasPlaceholder {
                #expect(throws: DestinationValidationError.unfilledPlaceholder, "\(preset)") { try RequestBuilder.validate(d) }
            } else {
                #expect(throws: Never.self, "\(preset)") { try RequestBuilder.validate(d) }
            }
        }
        // テンプレートに HTML などの <> を書くのは自由 (大文字と _ だけの <TOKEN> を埋める印とみなす)
        var d = Destination.preset(.custom)
        d.url = "https://example.com"
        d.bodyEncoding = .plain
        d.bodyTemplate = "<b>{{text}}</b>"
        #expect(throws: Never.self) { try RequestBuilder.validate(d) }
    }

    @Test func Slack_と_Discord_は今までの種類のまま() {
        #expect(DestinationPreset.slack.make().kind == .slack)
        #expect(DestinationPreset.discord.make().kind == .discord)
        #expect(DestinationPreset.ntfy.make().kind == .custom)
        #expect(DestinationPreset.ntfy.make().bodyEncoding == .plain)
    }
}
