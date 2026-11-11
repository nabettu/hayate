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
    /// `Transaction.id`。返金と購入を取引ごとに突き合わせるのに使う
    public var transactionID: UInt64
    public var productID: String
    /// お試しの開始日に使う。復元・再インストールでも変わらない日付 (`Transaction.originalPurchaseDate`)
    public var originalPurchaseDate: Date
    /// 返金・取り消し済み
    public var isRevoked: Bool

    public init(transactionID: UInt64, productID: String, originalPurchaseDate: Date, isRevoked: Bool = false) {
        self.transactionID = transactionID
        self.productID = productID
        self.originalPurchaseDate = originalPurchaseDate
        self.isRevoked = isRevoked
    }
}

/// 購入の状態。秘密ではないので、iPhone → 時計の applicationContext にそのまま載せる。
///
/// 買い切りとお試しは「有効と見た取引 ID」と「返金・取り消し済みと見た取引 ID」で持つ。iPhone と時計の StoreKit は反映の早さが違うので、
/// どちらか一方でも返金を確かめた取引は、もう一方が古い「有効」を持っていても数えない。
/// 返金のあと別の取引で買い直した分は、ID が違うので消えない。
public struct EntitlementSnapshot: Codable, Sendable, Equatable {
    public var unlockTransactionIDs: Set<UInt64>
    public var revokedTransactionIDs: Set<UInt64>
    /// お試しの取引 ID → 開始日
    public var trialStarts: [UInt64: Date]

    public var unlocked: Bool { !unlockTransactionIDs.subtracting(revokedTransactionIDs).isEmpty }

    /// 取り消されていないお試しのうち、最も早い開始日。
    public var trialStartedAt: Date? {
        trialStarts.filter { !revokedTransactionIDs.contains($0.key) }.values.min()
    }

    public init(unlockTransactionIDs: Set<UInt64> = [], revokedTransactionIDs: Set<UInt64> = [], trialStarts: [UInt64: Date] = [:]) {
        self.unlockTransactionIDs = unlockTransactionIDs
        self.revokedTransactionIDs = revokedTransactionIDs
        self.trialStarts = trialStarts
    }

    /// テスト・デバッグ用: 取引 ID を気にしないで作る。
    public init(unlockTransactionIDs: Set<UInt64> = [], trialStartedAt: Date?) {
        self.init(unlockTransactionIDs: unlockTransactionIDs, trialStarts: trialStartedAt.map { [0: $0] } ?? [:])
    }

    public init(records: [PurchaseRecord]) {
        let known = records.filter { StoreProducts.all.contains($0.productID) }
        // 同じ取引の有効な記録と返金済みの記録が両方あれば、返金を優先する
        let revoked = Set(known.filter(\.isRevoked).map(\.transactionID))
        let valid = known.filter { !$0.isRevoked && !revoked.contains($0.transactionID) }
        unlockTransactionIDs = Set(valid.filter { $0.productID == StoreProducts.unlockID }.map(\.transactionID))
        revokedTransactionIDs = revoked
        var starts: [UInt64: Date] = [:]
        for r in valid where r.productID == StoreProducts.trialID {
            starts[r.transactionID] = min(starts[r.transactionID] ?? r.originalPurchaseDate, r.originalPurchaseDate)
        }
        trialStarts = starts
    }

    private enum CodingKeys: String, CodingKey { case unlockTransactionIDs, revokedTransactionIDs, trialStarts }

    /// 項目が欠けていても読む (iPhone と時計でアプリの版がずれても止まらないように)。
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        unlockTransactionIDs = try c.decodeIfPresent(Set<UInt64>.self, forKey: .unlockTransactionIDs) ?? []
        revokedTransactionIDs = try c.decodeIfPresent(Set<UInt64>.self, forKey: .revokedTransactionIDs) ?? []
        trialStarts = try c.decodeIfPresent([UInt64: Date].self, forKey: .trialStarts) ?? [:]
    }

    /// 時計の StoreKit の状態に、iPhone から届いた状態を合わせる (時計の StoreKit に iPhone での購入が届くまでの間も使えるように)。
    /// 有効な取引も返金済みの取引も両方を足し、返金済みの取引は有効から外す。お試しは取り消されていないうち早く始めた方。
    /// 合わせる相手は「iPhone の最新の状態」だけで、過去に届いたものを積み上げない。
    public func merging(_ other: EntitlementSnapshot?) -> EntitlementSnapshot {
        guard let other else { return self }
        return EntitlementSnapshot(
            unlockTransactionIDs: unlockTransactionIDs.union(other.unlockTransactionIDs),
            revokedTransactionIDs: revokedTransactionIDs.union(other.revokedTransactionIDs),
            trialStarts: trialStarts.merging(other.trialStarts) { min($0, $1) }
        )
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

    /// お試し中の残り日数 (切り上げ、1〜お試しの日数)。お試し中でなければ nil。
    /// 画面の時刻 (TimelineView は分の始まりを渡す) や購入日 (Sandbox はサーバー時刻) が少しずれて、
    /// 開始より前の時刻で数えても日数を超えないよう頭打ちにする。`trialDuration` は `EntitlementPolicy` と揃える。
    public func daysRemaining(now: Date, trialDuration: TimeInterval = EntitlementPolicy.defaultTrialDuration) -> Int? {
        guard case .trial(let end) = self else { return nil }
        let days = Int((end.timeIntervalSince(now) / 86_400).rounded(.up))
        let cap = max(1, Int((trialDuration / 86_400).rounded(.up)))
        return min(cap, max(1, days))
    }
}

public struct EntitlementPolicy: Sendable {
    public var trialDuration: TimeInterval

    public static let defaultTrialDuration = TimeInterval(StoreProducts.trialDays) * 86_400

    public init(trialDuration: TimeInterval = defaultTrialDuration) {
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

/// 送り先の編集画面の「テスト送信」を許すか。
///
/// テスト送信の本文は固定の文だが、送り先の本文テンプレートを書き換えれば好きな内容を送れてしまう。
/// お試し前は設定を確かめる分だけ (回数を決めて) 許し、お試しが終わったあとは許さない。
public enum TestSendPolicy {
    public static let limitBeforeTrial = 5

    public static func allows(access: AccessState, usedBeforeTrial: Int) -> Bool {
        switch access {
        case .unlocked, .trial: true
        case .trialNotStarted: usedBeforeTrial < limitBeforeTrial
        case .trialExpired: false
        }
    }

    /// この送信をお試し前の回数に数えるか。
    public static func counts(access: AccessState) -> Bool {
        access == .trialNotStarted
    }
}
