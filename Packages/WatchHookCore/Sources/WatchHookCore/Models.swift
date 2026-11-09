import Foundation

/// 送り先に付ける HTTP ヘッダ 1 行。`isSecret` は画面で値を伏せるためのもので、保存先は他と同じ Keychain。
public struct HeaderField: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var value: String
    public var isSecret: Bool

    public init(id: UUID = UUID(), name: String, value: String, isSecret: Bool = false) {
        self.id = id
        self.name = name
        self.value = value
        self.isSecret = isSecret
    }
}

public enum DestinationKind: String, Codable, CaseIterable, Sendable {
    case custom
    case slack
    case discord
}

public enum HTTPMethod: String, Codable, CaseIterable, Sendable {
    case post = "POST"
    case put = "PUT"
}

/// 本文の形式。テンプレートの差し込み時のエスケープ方法と Content-Type を決める。
public enum BodyEncoding: String, Codable, CaseIterable, Sendable {
    case json
    case form
    case plain

    public var contentType: String {
        switch self {
        case .json: "application/json"
        case .form: "application/x-www-form-urlencoded"
        case .plain: "text/plain; charset=utf-8"
        }
    }
}

/// 音声入力したテキストの送り先 (webhook)。
public struct Destination: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var kind: DestinationKind
    public var url: String
    public var method: HTTPMethod
    public var headers: [HeaderField]
    public var bodyEncoding: BodyEncoding
    /// `{{text}}` `{{id}}` `{{sentAt}}` `{{source}}` を差し込める。
    public var bodyTemplate: String

    public init(
        id: UUID = UUID(),
        name: String,
        kind: DestinationKind,
        url: String = "",
        method: HTTPMethod = .post,
        headers: [HeaderField] = [],
        bodyEncoding: BodyEncoding = .json,
        bodyTemplate: String
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.url = url
        self.method = method
        self.headers = headers
        self.bodyEncoding = bodyEncoding
        self.bodyTemplate = bodyTemplate
    }

    public static func preset(_ kind: DestinationKind) -> Destination {
        switch kind {
        case .custom:
            Destination(
                name: "Webhook",
                kind: .custom,
                bodyTemplate: #"{"text":"{{text}}","id":"{{id}}","sentAt":"{{sentAt}}","source":"{{source}}"}"#
            )
        case .slack:
            Destination(name: "Slack", kind: .slack, bodyTemplate: #"{"text":"{{text}}"}"#)
        case .discord:
            Destination(name: "Discord", kind: .discord, bodyTemplate: #"{"content":"{{text}}"}"#)
        }
    }
}

/// 時計 / iPhone で入力された 1 件のテキスト。`id` は送り先での重複排除用に `X-WatchHook-Message-Id` で送る。
public struct OutgoingMessage: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var text: String
    public var createdAt: Date
    public var destinationID: UUID
    /// どこから送ったか (`watch` / `phone` / `siri` など)。
    public var source: String

    public init(id: UUID = UUID(), text: String, createdAt: Date = Date(), destinationID: UUID, source: String) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.destinationID = destinationID
        self.source = source
    }
}

/// iPhone で編集し、時計へ同期する設定一式。
public struct DestinationConfig: Codable, Hashable, Sendable {
    public var destinations: [Destination]
    public var defaultDestinationID: UUID?
    /// iPhone で保存した日時。時計は自分の持つものより新しい設定だけを受け入れる (遅れて届いた古い同期で巻き戻さない)。
    public var updatedAt: Date

    public init(destinations: [Destination] = [], defaultDestinationID: UUID? = nil, updatedAt: Date = .distantPast) {
        self.destinations = destinations
        self.defaultDestinationID = defaultDestinationID
        self.updatedAt = updatedAt
    }

    public func isNewer(than other: DestinationConfig) -> Bool {
        updatedAt > other.updatedAt
    }

    /// 既定に選んだ送り先。消されていたら先頭を返す。
    public var defaultDestination: Destination? {
        destinations.first { $0.id == defaultDestinationID } ?? destinations.first
    }

    public func destination(id: UUID) -> Destination? {
        destinations.first { $0.id == id }
    }

    public func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    public static func decode(_ data: Data) throws -> DestinationConfig {
        try JSONDecoder().decode(DestinationConfig.self, from: data)
    }
}
