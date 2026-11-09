import Foundation

public enum DestinationValidationError: Error, Equatable, Sendable, LocalizedError {
    case invalidURL
    case insecureURL
    case forbiddenHeader(String)
    case invalidHeaderName(String)
    case invalidHeaderValue(String)
    case bodyIsNotJSON

    public var errorDescription: String? {
        switch self {
        case .invalidURL: "URL が正しくありません"
        case .insecureURL: "https の URL だけ使えます"
        case .forbiddenHeader(let n): "ヘッダ \(n) は指定できません"
        case .invalidHeaderName(let n): "ヘッダ名「\(n)」が正しくありません"
        case .invalidHeaderValue(let n): "ヘッダ \(n) の値に改行は入れられません"
        case .bodyIsNotJSON: "本文が JSON になりません (テンプレートを確認してください)"
        }
    }
}

public enum RequestBuilder {
    public static let timeout: TimeInterval = 20
    static let forbiddenHeaders: Set<String> = ["host", "content-length", "connection", "transfer-encoding"]
    static let tokenCharacters = CharacterSet(charactersIn: "!#$%&'*+-.^_`|~0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")

    /// 設定の誤りだけを確かめる (編集画面の保存時に使う)。
    public static func validate(_ destination: Destination) throws {
        _ = try build(destination: destination, message: OutgoingMessage(text: "validate", destinationID: destination.id, source: "validate"))
    }

    public static func build(destination: Destination, message: OutgoingMessage, now: Date = Date()) throws -> URLRequest {
        let trimmed = destination.url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), url.host?.isEmpty == false else {
            throw DestinationValidationError.invalidURL
        }
        guard scheme == "https" else {
            throw scheme == "http" ? DestinationValidationError.insecureURL : DestinationValidationError.invalidURL
        }

        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = destination.method.rawValue
        request.setValue(destination.bodyEncoding.contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("WatchHook/1", forHTTPHeaderField: "User-Agent")
        request.setValue(message.id.uuidString, forHTTPHeaderField: "X-WatchHook-Message-Id")

        for header in destination.headers {
            let name = header.name.trimmingCharacters(in: .whitespaces)
            if name.isEmpty { continue }
            guard name.unicodeScalars.allSatisfy(tokenCharacters.contains) else {
                throw DestinationValidationError.invalidHeaderName(name)
            }
            guard !forbiddenHeaders.contains(name.lowercased()) else {
                throw DestinationValidationError.forbiddenHeader(name)
            }
            // "\r\n" は Swift では 1 つの Character になるので、Character ではなく scalar で見る
            guard !header.value.unicodeScalars.contains(where: { $0 == "\r" || $0 == "\n" }) else {
                throw DestinationValidationError.invalidHeaderValue(name)
            }
            request.setValue(header.value, forHTTPHeaderField: name)
        }

        let body = TemplateRenderer.render(
            destination.bodyTemplate,
            context: TemplateContext(text: message.text, messageID: message.id, sentAt: now, source: message.source),
            encoding: destination.bodyEncoding
        )
        let data = Data(body.utf8)
        if destination.bodyEncoding == .json {
            guard (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) != nil else {
                throw DestinationValidationError.bodyIsNotJSON
            }
        }
        request.httpBody = data
        return request
    }
}
