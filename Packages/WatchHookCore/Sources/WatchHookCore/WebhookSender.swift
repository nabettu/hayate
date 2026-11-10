import Foundation

public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// リダイレクトに従わない。従うと POST が GET に変わり、ログイン画面などの 200 を「届いた」と誤認するため。
/// 3xx はそのまま返し、送信失敗 (設定の誤り) として扱う。
final class RejectRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest) async -> URLRequest? {
        nil
    }
}

public struct URLSessionTransport: HTTPTransport {
    let session: URLSession

    static let noRedirectSession = makeNoRedirectSession(configuration: .ephemeral)

    static func makeNoRedirectSession(configuration: URLSessionConfiguration) -> URLSession {
        URLSession(configuration: configuration, delegate: RejectRedirects(), delegateQueue: nil)
    }

    public init(session: URLSession? = nil) {
        self.session = session ?? Self.noRedirectSession
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
    /// 呼び出し側が待つのをやめた。失敗ではないので状態も再送回数も変えない。
    case cancelled
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
        } catch let error as URLError where error.code == .cancelled {
            return .cancelled
        } catch is CancellationError {
            return .cancelled
        } catch let error as URLError {
            return .retryableFailure(reason: String(localized: "通信エラー (\(error.code.rawValue))", bundle: .module))
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
