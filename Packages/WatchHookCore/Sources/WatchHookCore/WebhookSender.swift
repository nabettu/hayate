import Foundation

public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionTransport: HTTPTransport {
    let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }
}

public enum SendResult: Equatable, Sendable {
    case sent(statusCode: Int)
    /// 通信エラー・408・429・5xx。あとで送り直す。
    case retryableFailure(reason: String)
    /// 設定の誤り・その他の 4xx。送り直しても直らない。
    case permanentFailure(reason: String)
}

public struct WebhookSender: Sendable {
    let transport: HTTPTransport

    public init(transport: HTTPTransport = URLSessionTransport()) {
        self.transport = transport
    }

    public func send(_ message: OutgoingMessage, to destination: Destination) async -> SendResult {
        let request: URLRequest
        do {
            request = try RequestBuilder.build(destination: destination, message: message)
        } catch {
            return .permanentFailure(reason: error.localizedDescription)
        }
        do {
            let (_, response) = try await transport.send(request)
            return Self.classify(statusCode: response.statusCode)
        } catch let error as URLError {
            return .retryableFailure(reason: "通信エラー (\(error.code.rawValue))")
        } catch {
            return .retryableFailure(reason: error.localizedDescription)
        }
    }

    static func classify(statusCode code: Int) -> SendResult {
        switch code {
        case 200..<300: .sent(statusCode: code)
        case 408, 429, 500..<600: .retryableFailure(reason: "HTTP \(code)")
        default: .permanentFailure(reason: "HTTP \(code)")
        }
    }
}
