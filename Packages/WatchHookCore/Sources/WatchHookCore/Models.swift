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

    /// 画面に出す種類の名前。
    public var label: String {
        switch self {
        case .custom: "Webhook"
        case .slack: "Slack"
        case .discord: "Discord"
        }
    }
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
    /// 話した内容の前後に付ける文 (例: 前に「#買い物 」)。Slack・Discord のように本文が決まった送り先でも使える。
    /// 空白や改行は書いたとおりに付ける。送る時点で付け、履歴・再送も付けた文のまま
    public var textPrefix: String = ""
    public var textSuffix: String = ""

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

    /// 話した内容に前後の文を付ける。
    public func wrap(_ text: String) -> String {
        textPrefix + text + textSuffix
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, kind, url, method, headers, bodyEncoding, bodyTemplate, textPrefix, textSuffix
    }

    /// 前後の文が入る前に保存された設定 (キーが無い) も読めるようにする
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        kind = try c.decode(DestinationKind.self, forKey: .kind)
        url = try c.decode(String.self, forKey: .url)
        method = try c.decode(HTTPMethod.self, forKey: .method)
        headers = try c.decode([HeaderField].self, forKey: .headers)
        bodyEncoding = try c.decode(BodyEncoding.self, forKey: .bodyEncoding)
        bodyTemplate = try c.decode(String.self, forKey: .bodyTemplate)
        textPrefix = try c.decodeIfPresent(String.self, forKey: .textPrefix) ?? ""
        textSuffix = try c.decodeIfPresent(String.self, forKey: .textSuffix) ?? ""
    }

    /// 画面 (iPhone・時計・Siri・履歴) に出す名前。名前が空なら URL のホスト、それも無ければ種類の名前。
    /// URL のパスやクエリには Slack の webhook のように秘密が入ることがあるので、ホストより先は出さない。
    public var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if let host = URL(string: url.trimmingCharacters(in: .whitespacesAndNewlines))?.host, !host.isEmpty {
            return host
        }
        return kind.label
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
    /// 保存のたびに 1 増える版。時計は自分の持つものより新しい設定だけを受け入れる (遅れて届いた古い同期で巻き戻さない)。
    /// 端末の時刻は戻ることがあるので日時では比べない。
    public var revision: Int
    /// iPhone で設定を作り直した (アプリを入れ直した) ときに変わる ID。版が 0 からやり直しになっても受け入れるため。
    public var epoch: UUID

    public init(destinations: [Destination] = [], defaultDestinationID: UUID? = nil, revision: Int = 0, epoch: UUID = UUID()) {
        self.destinations = destinations
        self.defaultDestinationID = defaultDestinationID
        self.revision = revision
        self.epoch = epoch
    }

    public func isNewer(than other: DestinationConfig) -> Bool {
        epoch != other.epoch || revision > other.revision
    }

    /// 一度も保存していない設定の epoch。毎回同じ値にして、空の設定どうしを「新しい」と取り違えない。
    public static let unsavedEpoch = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    /// まだ何も保存していないときの設定。
    public static var unsaved: DestinationConfig { DestinationConfig(epoch: unsavedEpoch) }

    /// 版を 1 つ進める。初めての保存なら epoch を新しく作る (入れ直した iPhone の設定を時計が受け入れられるように)。
    public func nextRevision() -> DestinationConfig {
        var c = self
        c.revision += 1
        if c.epoch == Self.unsavedEpoch { c.epoch = UUID() }
        return c
    }

    /// WatchConnectivity のメッセージに収まる大きさ (上限は公開されていないので余裕を持たせる)。
    public static let maxEncodedBytes = 48_000

    public struct TooLarge: Error, LocalizedError {
        public var errorDescription: String? { "設定が大きすぎて Apple Watch へ送れません。本文テンプレートやヘッダを減らしてください" }
    }

    public func validateSize() throws {
        guard try encoded().count <= Self.maxEncodedBytes else { throw TooLarge() }
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
