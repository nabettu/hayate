import Foundation

/// メモを入力した端末 / 連携を受け持つ端末。
public enum DeviceRole: String, Codable, Hashable, Sendable {
    case watch
    case phone
}

/// 連携先。名前は作った時点のもの (あとで送り先の名前を変えても、履歴の表示は変わらない)。
public enum DeliveryTarget: Codable, Hashable, Sendable {
    case webhook(destinationID: UUID, name: String)
    case reminder(listName: String)
    case markdown(folderName: String)

    public var displayName: String {
        switch self {
        case .webhook(_, let name): name
        case .reminder(let list): String(localized: "リマインダー (\(list))", bundle: .module)
        case .markdown(let folder): String(localized: "Markdown (\(folder))", bundle: .module)
        }
    }
}

public enum DeliveryStatus: Codable, Hashable, Sendable {
    case pending(attempts: Int, lastError: String?)
    /// 送れた・保存できた。`detail` は「HTTP 200」など
    case done(detail: String?)
    case failed(reason: String)
    /// メモを消したので送るのをやめた
    case cancelled

    public var isPending: Bool {
        if case .pending = self { true } else { false }
    }

    public var isDone: Bool {
        if case .done = self { true } else { false }
    }
}

/// 1 つの連携先への送信 / 保存。
/// 状態を変えてよいのは `owner` の端末だけ。相手の端末には写しを送り、`revision` の大きいほうを正とする
/// (遅れて届いた古い写しで巻き戻さず、両方の端末が同じ連携を送ることもない)。
public struct Delivery: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var target: DeliveryTarget
    public var owner: DeviceRole
    /// 送る / 保存する文。webhook は送り先の前後の文を付けたもの、リマインダーは合図を除いたもの
    public var text: String
    public var status: DeliveryStatus
    public var revision: Int

    public init(id: UUID = UUID(), target: DeliveryTarget, owner: DeviceRole, text: String,
                status: DeliveryStatus = .pending(attempts: 0, lastError: nil), revision: Int = 0) {
        self.id = id
        self.target = target
        self.owner = owner
        self.text = text
        self.status = status
        self.revision = revision
    }
}

/// 時計で入力したメモを iPhone に渡せたか (時計の中だけの状態。相手には送らない)。
public enum PhoneSyncState: String, Codable, Hashable, Sendable {
    case waiting
    case delivered
}

/// 入力した 1 件。まず端末に保存し、連携は `deliveries` に別に持つ (送れなくても内容は失わない)。
/// 保存したあとに本文は変えない。
public struct Memo: Codable, Hashable, Identifiable, Sendable {
    /// webhook の `X-WatchHook-Message-Id` にも使う (同じメモの再送は同じ ID)
    public var id: UUID
    public var text: String
    public var createdAt: Date
    /// `watch` / `phone` / `siri-watch` / `siri-phone`
    public var source: String
    public var origin: DeviceRole
    public var deliveries: [Delivery]
    /// 時計のメモを iPhone に渡せたか (時計だけ。iPhone では nil)
    public var phoneSync: PhoneSyncState?
    /// iPhone が初めて受け取ったとき、リマインダー・Markdown の連携を足してよいか (前の形式から移した履歴は false)
    public var wantsPhoneIntegrations: Bool

    public init(id: UUID = UUID(), text: String, createdAt: Date = Date(), source: String, origin: DeviceRole,
                deliveries: [Delivery] = [], phoneSync: PhoneSyncState? = nil, wantsPhoneIntegrations: Bool = true) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.source = source
        self.origin = origin
        self.deliveries = deliveries
        self.phoneSync = phoneSync
        self.wantsPhoneIntegrations = wantsPhoneIntegrations
    }

    public enum Summary: Hashable, Sendable {
        /// 連携なし (メモとして保存しただけ)
        case memoOnly
        /// 送信待ち・iPhone に渡す前のものがある
        case waiting
        /// 失敗したものがある (待ちは無い)
        case someFailed
        case allDone
    }

    public var summary: Summary {
        if deliveries.contains(where: { $0.status.isPending }) || phoneSync == .waiting { return .waiting }
        if deliveries.isEmpty { return .memoOnly }
        if deliveries.contains(where: { if case .failed = $0.status { true } else { false } }) { return .someFailed }
        return .allDone
    }

    /// webhook へ送るときの中身。webhook 以外なら nil。
    public func outgoingMessage(for delivery: Delivery) -> OutgoingMessage? {
        guard case .webhook(let destinationID, _) = delivery.target else { return nil }
        return OutgoingMessage(id: id, text: delivery.text, createdAt: createdAt, destinationID: destinationID, source: source)
    }
}

/// 連携 1 件の結果。webhook の `SendResult` もこれに直して反映する。
public enum DeliveryOutcome: Equatable, Sendable {
    case done(detail: String?)
    /// あとで送り直す
    case retryable(reason: String)
    /// 送り直しても直らない
    case permanent(reason: String)
    /// 待つのをやめた。状態も回数も変えない
    case cancelled
}

extension SendResult {
    public var deliveryOutcome: DeliveryOutcome {
        switch self {
        case .sent(let code): .done(detail: "HTTP \(code)")
        case .retryableFailure(let r): .retryable(reason: r)
        case .permanentFailure(let r): .permanent(reason: r)
        case .cancelled: .cancelled
        }
    }
}
