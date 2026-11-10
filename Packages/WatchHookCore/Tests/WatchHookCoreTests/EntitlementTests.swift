import Foundation
import Testing
@testable import WatchHookCore

@Suite("Entitlement")
struct EntitlementTests {
    let day: TimeInterval = 86_400
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    func record(_ product: String, id: UInt64 = 1, at date: Date, revoked: Bool = false) -> PurchaseRecord {
        PurchaseRecord(transactionID: id, productID: product, originalPurchaseDate: date, isRevoked: revoked)
    }

    let none = EntitlementSnapshot(trialStartedAt: nil)

    // MARK: - 購入記録 → 手元の状態

    @Test func 何も買っていなければお試し前() {
        let s = EntitlementSnapshot(records: [])
        #expect(s == none)
        #expect(EntitlementPolicy().state(for: s, now: t0) == .trialNotStarted)
    }

    @Test func お試しの購入日から7日間は送れる() {
        let s = EntitlementSnapshot(records: [record(StoreProducts.trialID, at: t0)])
        let policy = EntitlementPolicy()
        let end = t0.addingTimeInterval(7 * day)
        #expect(policy.state(for: s, now: t0) == .trial(endsAt: end))
        #expect(policy.state(for: s, now: end.addingTimeInterval(-1)) == .trial(endsAt: end))
        #expect(policy.state(for: s, now: end) == .trialExpired(endedAt: end))
        #expect(policy.state(for: s, now: end).canSend == false)
        #expect(policy.state(for: s, now: t0).canSend)
    }

    @Test func 買い切りを買えばお試しの期限に関係なく送れる() {
        let s = EntitlementSnapshot(records: [
            record(StoreProducts.trialID, id: 1, at: t0),
            record(StoreProducts.unlockID, id: 2, at: t0.addingTimeInterval(30 * day)),
        ])
        let state = EntitlementPolicy().state(for: s, now: t0.addingTimeInterval(365 * day))
        #expect(state == .unlocked)
        #expect(state.canSend)
    }

    @Test func 返金された購入は数えない() {
        let s = EntitlementSnapshot(records: [
            record(StoreProducts.unlockID, id: 1, at: t0, revoked: true),
            record(StoreProducts.trialID, id: 2, at: t0, revoked: true),
        ])
        #expect(s.unlocked == false)
        #expect(s.trialStartedAt == nil)
        #expect(s.revokedTransactionIDs == [1, 2])
    }

    @Test func 同じ取引の有効な記録と返金済みの記録が両方あれば返金を優先する() {
        // currentEntitlements を読んだあと、latest(for:) を読むまでの間に返金が届いたとき
        let s = EntitlementSnapshot(records: [
            record(StoreProducts.unlockID, id: 7, at: t0),
            record(StoreProducts.unlockID, id: 7, at: t0, revoked: true),
        ])
        #expect(s.unlocked == false)
    }

    @Test func 知らない商品は無視する() {
        let s = EntitlementSnapshot(records: [record("com.example.other", at: t0)])
        #expect(s == none)
    }

    @Test func お試しの記録が複数あれば最初の日から数える() {
        let s = EntitlementSnapshot(records: [
            record(StoreProducts.trialID, id: 1, at: t0.addingTimeInterval(3 * day)),
            record(StoreProducts.trialID, id: 2, at: t0),
        ])
        #expect(s.trialStartedAt == t0)
    }

    @Test func 端末の時刻が購入日より前でもお試しの終わりは購入日から7日() {
        let s = EntitlementSnapshot(trialStartedAt: t0)
        let end = t0.addingTimeInterval(7 * day)
        #expect(EntitlementPolicy().state(for: s, now: t0.addingTimeInterval(-day)) == .trial(endsAt: end))
    }

    // MARK: - 残り日数

    @Test func 残り日数は切り上げる() {
        let end = t0.addingTimeInterval(7 * day)
        let state = AccessState.trial(endsAt: end)
        #expect(state.daysRemaining(now: t0) == 7)
        #expect(state.daysRemaining(now: t0.addingTimeInterval(1)) == 7)
        #expect(state.daysRemaining(now: end.addingTimeInterval(-1)) == 1)
        #expect(AccessState.unlocked.daysRemaining(now: t0) == nil)
    }

    // MARK: - iPhone から届いた状態との合わせ方

    @Test func 合わせると購入済みとお試し開始日の早い方が残る() {
        let watch = EntitlementSnapshot(trialStartedAt: t0.addingTimeInterval(day))
        let phone = EntitlementSnapshot(unlockTransactionIDs: [5], trialStartedAt: t0)
        let merged = watch.merging(phone)
        #expect(merged.unlocked)
        #expect(merged.trialStartedAt == t0)
        #expect(watch.merging(nil) == watch)
        #expect(none.merging(watch) == watch)
    }

    @Test func 時計で返金を確かめたらiPhoneから届いた古い購入済みより優先する() {
        let watch = EntitlementSnapshot(records: [record(StoreProducts.unlockID, id: 5, at: t0, revoked: true)])
        let staleHint = EntitlementSnapshot(unlockTransactionIDs: [5], trialStartedAt: nil)
        #expect(watch.merging(staleHint).unlocked == false)
    }

    @Test func iPhoneで返金を確かめたら時計の古い購入済みより優先する() {
        let staleWatch = EntitlementSnapshot(records: [record(StoreProducts.unlockID, id: 5, at: t0)])
        let phone = EntitlementSnapshot(records: [record(StoreProducts.unlockID, id: 5, at: t0, revoked: true)])
        #expect(staleWatch.merging(phone).unlocked == false)
    }

    @Test func 返金のあと買い直していれば購入済み() {
        let s = EntitlementSnapshot(records: [
            record(StoreProducts.unlockID, id: 5, at: t0, revoked: true),
            record(StoreProducts.unlockID, id: 6, at: t0.addingTimeInterval(day)),
        ])
        #expect(s.unlocked)
        // 片方の端末が古い返金だけを知っていても、別の取引で買い直した分は消さない
        let other = EntitlementSnapshot(records: [record(StoreProducts.unlockID, id: 5, at: t0, revoked: true)])
        #expect(other.merging(s).unlocked)
    }

    @Test func もう一方の端末で取り消されたお試しは数えない() {
        let staleWatch = EntitlementSnapshot(records: [record(StoreProducts.trialID, id: 3, at: t0)])
        let phone = EntitlementSnapshot(records: [record(StoreProducts.trialID, id: 3, at: t0, revoked: true)])
        #expect(staleWatch.merging(phone).trialStartedAt == nil)
        #expect(phone.merging(staleWatch).trialStartedAt == nil)
    }

    @Test func 項目が欠けた形も読める() throws {
        let old = Data(#"{}"#.utf8)
        #expect(try EntitlementSnapshot.decode(old) == none)
    }

    @Test func 送るときの形とのやり取りで値が変わらない() throws {
        let s = EntitlementSnapshot(records: [
            record(StoreProducts.unlockID, id: 1, at: t0),
            record(StoreProducts.unlockID, id: 2, at: t0, revoked: true),
            record(StoreProducts.trialID, id: 3, at: t0),
        ])
        #expect(try EntitlementSnapshot.decode(s.encoded()) == s)
        #expect(throws: (any Error).self) { try EntitlementSnapshot.decode(Data("x".utf8)) }
    }
}

@Suite("TestSendPolicy")
struct TestSendPolicyTests {
    let end = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func お試し中と購入済みは回数に関係なくテスト送信できる() {
        #expect(TestSendPolicy.allows(access: .unlocked, usedBeforeTrial: 100))
        #expect(TestSendPolicy.allows(access: .trial(endsAt: end), usedBeforeTrial: 100))
        #expect(TestSendPolicy.counts(access: .unlocked) == false)
        #expect(TestSendPolicy.counts(access: .trial(endsAt: end)) == false)
    }

    @Test func お試し前は決まった回数までテスト送信できる() {
        let limit = TestSendPolicy.limitBeforeTrial
        #expect(limit == 5)
        #expect(TestSendPolicy.allows(access: .trialNotStarted, usedBeforeTrial: limit - 1))
        #expect(TestSendPolicy.allows(access: .trialNotStarted, usedBeforeTrial: limit) == false)
        #expect(TestSendPolicy.counts(access: .trialNotStarted))
    }

    @Test func お試しが終わったらテスト送信もできない() {
        #expect(TestSendPolicy.allows(access: .trialExpired(endedAt: end), usedBeforeTrial: 0) == false)
    }
}
