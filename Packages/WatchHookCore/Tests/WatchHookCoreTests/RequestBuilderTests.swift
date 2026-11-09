import Foundation
import Testing
@testable import WatchHookCore

@Suite("RequestBuilder")
struct RequestBuilderTests {
    let message = OutgoingMessage(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!,
        text: "テスト",
        createdAt: Date(timeIntervalSince1970: 0),
        destinationID: UUID(),
        source: "watch"
    )

    func customDestination() -> Destination {
        var d = Destination.preset(.custom)
        d.url = "https://example.com/hook"
        d.headers = [HeaderField(name: "Authorization", value: "Bearer secret", isSecret: true)]
        return d
    }

    @Test func URL_メソッド_ヘッダ_本文を組み立てる() throws {
        let req = try RequestBuilder.build(destination: customDestination(), message: message)
        #expect(req.url?.absoluteString == "https://example.com/hook")
        #expect(req.httpMethod == "POST")
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
        #expect(req.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(req.value(forHTTPHeaderField: "X-WatchHook-Message-Id") == "00000000-0000-0000-0000-0000000000AA")
        let body = try JSONSerialization.jsonObject(with: req.httpBody ?? Data()) as? [String: Any]
        #expect(body?["text"] as? String == "テスト")
    }

    @Test func httpのURLは拒否する() {
        var d = customDestination()
        d.url = "http://example.com/hook"
        #expect(throws: DestinationValidationError.insecureURL) {
            try RequestBuilder.build(destination: d, message: message)
        }
    }

    @Test func 壊れたURLは拒否する() {
        var d = customDestination()
        d.url = "not a url"
        #expect(throws: DestinationValidationError.invalidURL) {
            try RequestBuilder.build(destination: d, message: message)
        }
    }

    @Test func 本文が不正なJSONになるテンプレートは拒否する() {
        var d = customDestination()
        d.bodyTemplate = #"{"text": {{text}}}"#
        #expect(throws: DestinationValidationError.bodyIsNotJSON) {
            try RequestBuilder.build(destination: d, message: message)
        }
    }

    @Test func 禁止ヘッダや不正なヘッダ名は拒否する() {
        var d = customDestination()
        d.headers = [HeaderField(name: "Host", value: "evil.example")]
        #expect(throws: DestinationValidationError.forbiddenHeader("Host")) {
            try RequestBuilder.build(destination: d, message: message)
        }
        d.headers = [HeaderField(name: "Bad Name", value: "x")]
        #expect(throws: DestinationValidationError.invalidHeaderName("Bad Name")) {
            try RequestBuilder.build(destination: d, message: message)
        }
    }

    @Test func 名前が空のヘッダ行は無視する() throws {
        var d = customDestination()
        d.headers.append(HeaderField(name: "  ", value: ""))
        let req = try RequestBuilder.build(destination: d, message: message)
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
    }

    @Test func ヘッダ値の改行は拒否する() {
        var d = customDestination()
        d.headers = [HeaderField(name: "X-A", value: "a\r\nX-B: b")]
        #expect(throws: DestinationValidationError.invalidHeaderValue("X-A")) {
            try RequestBuilder.build(destination: d, message: message)
        }
    }

    @Test func Slackのプリセットはtextに入れる() throws {
        var d = Destination.preset(.slack)
        d.url = "https://hooks.slack.com/services/T/B/X"
        let req = try RequestBuilder.build(destination: d, message: message)
        let body = try JSONSerialization.jsonObject(with: req.httpBody ?? Data()) as? [String: Any]
        #expect(body?["text"] as? String == "テスト")
    }

    @Test func Discordのプリセットはcontentに入れる() throws {
        var d = Destination.preset(.discord)
        d.url = "https://discord.com/api/webhooks/1/abc"
        let req = try RequestBuilder.build(destination: d, message: message)
        let body = try JSONSerialization.jsonObject(with: req.httpBody ?? Data()) as? [String: Any]
        #expect(body?["content"] as? String == "テスト")
    }

    @Test func メッセージIDヘッダは上書きできない() {
        var d = customDestination()
        d.headers = [HeaderField(name: "x-watchhook-message-id", value: "fixed")]
        #expect(throws: DestinationValidationError.forbiddenHeader("x-watchhook-message-id")) {
            try RequestBuilder.build(destination: d, message: message)
        }
    }
}
