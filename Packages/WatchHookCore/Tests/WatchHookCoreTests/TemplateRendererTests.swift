import Foundation
import Testing
@testable import WatchHookCore

@Suite("TemplateRenderer")
struct TemplateRendererTests {
    let context = TemplateContext(
        text: "こんにちは",
        messageID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        sentAt: Date(timeIntervalSince1970: 0),
        source: "watch"
    )

    @Test func JSONでは本文をエスケープして埋め込む() throws {
        var ctx = context
        ctx.text = "He said \"hi\"\n\\ end"
        let out = TemplateRenderer.render(#"{"text":"{{text}}"}"#, context: ctx, encoding: .json)
        let obj = try JSONSerialization.jsonObject(with: Data(out.utf8)) as? [String: String]
        #expect(obj?["text"] == "He said \"hi\"\n\\ end")
    }

    @Test func JSONでは制御文字もエスケープする() throws {
        var ctx = context
        ctx.text = "a\u{0001}b\tc"
        let out = TemplateRenderer.render(#"{"t":"{{text}}"}"#, context: ctx, encoding: .json)
        let obj = try JSONSerialization.jsonObject(with: Data(out.utf8)) as? [String: String]
        #expect(obj?["t"] == "a\u{0001}b\tc")
    }

    @Test func 全てのプレースホルダを置き換える() {
        let out = TemplateRenderer.render(
            "{{text}}|{{id}}|{{sentAt}}|{{source}}",
            context: context,
            encoding: .plain
        )
        #expect(out == "こんにちは|00000000-0000-0000-0000-000000000001|1970-01-01T00:00:00Z|watch")
    }

    @Test func 本文の中のプレースホルダ風の文字列は再展開しない() {
        var ctx = context
        ctx.text = "{{id}}"
        let out = TemplateRenderer.render("{{text}}", context: ctx, encoding: .plain)
        #expect(out == "{{id}}")
    }

    @Test func フォームではパーセントエンコードする() {
        var ctx = context
        ctx.text = "a b&c=d"
        let out = TemplateRenderer.render("text={{text}}", context: ctx, encoding: .form)
        #expect(out == "text=a%20b%26c%3Dd")
    }

    @Test func 未知のプレースホルダはそのまま残す() {
        let out = TemplateRenderer.render("{{unknown}}", context: context, encoding: .plain)
        #expect(out == "{{unknown}}")
    }
}
