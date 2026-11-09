import Foundation
import Testing
@testable import WatchHookCore

/// 302 を返し、転送先へのアクセスを記録する偽のサーバー。
final class RedirectingProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestedPaths: [String] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let url = request.url!
        Self.requestedPaths.append(url.path)
        if url.path == "/hook" {
            let target = URL(string: "https://example.com/login")!
            let resp = HTTPURLResponse(url: url, statusCode: 302, httpVersion: nil, headerFields: ["Location": target.absoluteString])!
            client?.urlProtocol(self, wasRedirectedTo: URLRequest(url: target), redirectResponse: resp)
            // 転送を拒否されたら、302 の応答そのものを返す
            client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
            client?.urlProtocolDidFinishLoading(self)
        } else {
            let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}

@Suite("URLSessionTransport", .serialized)
struct TransportTests {
    @Test func リダイレクトに従わず失敗にする() async {
        RedirectingProtocol.requestedPaths = []
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [RedirectingProtocol.self]
        let transport = URLSessionTransport(session: URLSessionTransport.makeNoRedirectSession(configuration: config))
        var d = Destination.preset(.custom)
        d.url = "https://example.com/hook"
        let r = await WebhookSender(transport: transport).send(OutgoingMessage(text: "x", destinationID: d.id, source: "t"), to: d)
        #expect(r == .permanentFailure(reason: "HTTP 302"))
        #expect(RedirectingProtocol.requestedPaths == ["/hook"])
    }
}
