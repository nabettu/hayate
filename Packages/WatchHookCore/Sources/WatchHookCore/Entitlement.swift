import Foundation

/// App Store Connect に作る商品。設計と作り方は docs/BILLING.md。
public enum StoreProducts {
    /// 7 日間の無料お試し (価格 0 円の非消耗型)。App Review Guidelines 3.1.1 の形。参照名は「7-day Trial」にする
    public static let trialID = "com.nabettu.watchhook.trial7d"
    /// 買い切り (非消耗型)
    public static let unlockID = "com.nabettu.watchhook.unlock"
    public static let all = [trialID, unlockID]
    public static let trialDays = 7
}

/// StoreKit の取引から、判定に要るところだけを抜いたもの (StoreKit に依存せずにテストするため)。
public struct PurchaseRecord: Sendable, Equatable {
    public var productID: String
    /// お試しの開始日に使う。復元・再インストールでも変わらない日付 (`Transaction.originalPurchaseDate`)
    public var originalPurchaseDate: Date
    /// 返金・取り消し済み
    public var isRevoked: Bool

    public init(productID: String, originalPurchaseDate: Date, isRevoked: Bool = false) {
        self.productID = productID
        self.originalPurchaseDate = originalPurchaseDate
        self.isRevoked = isRevoked
    }
}

/// 購入の状態。秘密ではないので、iPhone → 時計の applicationContext にそのまま載せる。
public struct EntitlementSnapshot: Codable, Sendable, Equatable {
    public var unlocked: Bool
    public var trialStartedAt: Date?

    public init(unlocked: Bool, trialStartedAt: Date?) {
        self.unlocked = unlocked
        self.trialStartedAt = trialStartedAt
    }

    public init(records: [PurchaseRecord]) {
        let valid = records.filter { !$0.isRevoked }
        unlocked = valid.contains { $0.productID == StoreProducts.unlockID }
        trialStartedAt = valid.filter { $0.productID == StoreProducts.trialID }.map(\.originalPurchaseDate).min()
    }

    /// 時計の StoreKit と iPhone から届いた状態を合わせる。どちらかで買っていれば購入済み、お試しは早く始めた方。
    /// (時計の StoreKit に iPhone での購入が届くまでの間も使えるようにするため。合わせる相手は「iPhone の最新の状態」だけで、
    /// 過去に届いたものを積み上げないので、iPhone で返金されれば次の知らせで戻る)
    public func merging(_ other: EntitlementSnapshot?) -> EntitlementSnapshot {
        guard let other else { return self }
        let starts = [trialStartedAt, other.trialStartedAt].compactMap { $0 }
        return EntitlementSnapshot(unlocked: unlocked || other.unlocked, trialStartedAt: starts.min())
    }

    public func encoded() throws -> Data {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        return try e.encode(self)
    }

    public static func decode(_ data: Data) throws -> EntitlementSnapshot {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return try d.decode(EntitlementSnapshot.self, from: data)
    }
}

/// 今、送れるかどうか。
public enum AccessState: Sendable, Equatable {
    case unlocked
    case trial(endsAt: Date)
    case trialNotStarted
    case trialExpired(endedAt: Date)

    /// Apple Watch・Siri からの新しい送信をしてよいか。送り先の登録・テスト送信・履歴・溜まった分の再送は状態に関係なくできる
    public var canSend: Bool {
        switch self {
        case .unlocked, .trial: true
        case .trialNotStarted, .trialExpired: false
        }
    }

    /// お試し中の残り日数 (切り上げ)。お試し中でなければ nil。
    public func daysRemaining(now: Date) -> Int? {
        guard case .trial(let end) = self else { return nil }
        return max(1, Int((end.timeIntervalSince(now) / 86_400).rounded(.up)))
    }
}

public struct EntitlementPolicy: Sendable {
    public var trialDuration: TimeInterval

    public init(trialDuration: TimeInterval = TimeInterval(StoreProducts.trialDays) * 86_400) {
        self.trialDuration = trialDuration
    }

    /// 端末の時刻を戻すとお試しが延びるが、受け入れる (docs/BILLING.md の「意図した制限」)。
    public func state(for snapshot: EntitlementSnapshot, now: Date) -> AccessState {
        if snapshot.unlocked { return .unlocked }
        guard let start = snapshot.trialStartedAt else { return .trialNotStarted }
        let end = start.addingTimeInterval(trialDuration)
        return now < end ? .trial(endsAt: end) : .trialExpired(endedAt: end)
    }
}
