import Foundation
import Testing
@testable import WatchHookCore

struct StubTransport: HTTPTransport {
    var result: Result<Int, URLError>
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        switch result {
        case .success(let code):
            let resp = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!
            return (Data(), resp)
        case .failure(let error):
            throw error
        }
    }
}

@Suite("WebhookSender")
struct WebhookSenderTests {
    var destination: Destination {
        var d = Destination.preset(.custom)
        d.url = "https://example.com/hook"
        return d
    }
    let message = OutgoingMessage(text: "x", destinationID: UUID(), source: "test")

    @Test(arguments: [200, 201, 204])
    func 二百番台は成功(code: Int) async {
        let r = await WebhookSender(transport: StubTransport(result: .success(code)))
            .send(message, to: destination)
        #expect(r == .sent(statusCode: code))
    }

    @Test(arguments: [408, 429, 500, 503])
    func 再送で直る可能性のある失敗(code: Int) async {
        let r = await WebhookSender(transport: StubTransport(result: .success(code)))
            .send(message, to: destination)
        #expect(r == .retryableFailure(reason: "HTTP \(code)"))
    }

    @Test(arguments: [400, 401, 403, 404])
    func 再送しても直らない失敗(code: Int) async {
        let r = await WebhookSender(transport: StubTransport(result: .success(code)))
            .send(message, to: destination)
        #expect(r == .permanentFailure(reason: "HTTP \(code)"))
    }

    @Test func 通信エラーは再送対象() async {
        let r = await WebhookSender(transport: StubTransport(result: .failure(URLError(.notConnectedToInternet))))
            .send(message, to: destination)
        if case .retryableFailure = r {} else { Issue.record("got \(r)") }
    }

    @Test func 設定の誤りは再送しない() async {
        var d = destination
        d.url = "http://insecure.example"
        let r = await WebhookSender(transport: StubTransport(result: .success(200))).send(message, to: d)
        if case .permanentFailure = r {} else { Issue.record("got \(r)") }
    }
}
