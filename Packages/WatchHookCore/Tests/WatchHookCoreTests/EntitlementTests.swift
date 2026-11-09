import Foundation
import Testing
@testable import WatchHookCore

@Suite("Entitlement")
struct EntitlementTests {
    let day: TimeInterval = 86_400
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    func record(_ id: String, at date: Date, revoked: Bool = false) -> PurchaseRecord {
        PurchaseRecord(productID: id, originalPurchaseDate: date, isRevoked: revoked)
    }

    // MARK: - 購入記録 → 手元の状態

    @Test func 何も買っていなければお試し前() {
        let s = EntitlementSnapshot(records: [])
        #expect(s == EntitlementSnapshot(unlocked: false, trialStartedAt: nil))
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
            record(StoreProducts.trialID, at: t0),
            record(StoreProducts.unlockID, at: t0.addingTimeInterval(30 * day)),
        ])
        let state = EntitlementPolicy().state(for: s, now: t0.addingTimeInterval(365 * day))
        #expect(state == .unlocked)
        #expect(state.canSend)
    }

    @Test func 返金された購入は数えない() {
        let s = EntitlementSnapshot(records: [
            record(StoreProducts.unlockID, at: t0, revoked: true),
            record(StoreProducts.trialID, at: t0, revoked: true),
        ])
        #expect(s == EntitlementSnapshot(unlocked: false, trialStartedAt: nil, unlockRevoked: true))
    }

    @Test func 知らない商品は無視する() {
        let s = EntitlementSnapshot(records: [record("com.example.other", at: t0)])
        #expect(s == EntitlementSnapshot(unlocked: false, trialStartedAt: nil))
    }

    @Test func お試しの記録が複数あれば最初の日から数える() {
        let s = EntitlementSnapshot(records: [
            record(StoreProducts.trialID, at: t0.addingTimeInterval(3 * day)),
            record(StoreProducts.trialID, at: t0),
        ])
        #expect(s.trialStartedAt == t0)
    }

    @Test func 端末の時刻が購入日より前でもお試しの終わりは購入日から7日() {
        let s = EntitlementSnapshot(unlocked: false, trialStartedAt: t0)
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
        let watch = EntitlementSnapshot(unlocked: false, trialStartedAt: t0.addingTimeInterval(day))
        let phone = EntitlementSnapshot(unlocked: true, trialStartedAt: t0)
        #expect(watch.merging(phone) == EntitlementSnapshot(unlocked: true, trialStartedAt: t0))
        #expect(watch.merging(nil) == watch)
        let none = EntitlementSnapshot(unlocked: false, trialStartedAt: nil)
        #expect(none.merging(watch) == watch)
    }

    @Test func 時計で返金を確かめたらiPhoneから届いた古い購入済みより優先する() {
        let watch = EntitlementSnapshot(records: [record(StoreProducts.unlockID, at: t0, revoked: true)])
        #expect(watch.unlockRevoked)
        let staleHint = EntitlementSnapshot(unlocked: true, trialStartedAt: nil)
        #expect(watch.merging(staleHint).unlocked == false)
    }

    @Test func 返金のあと買い直していれば購入済み() {
        let s = EntitlementSnapshot(records: [
            record(StoreProducts.unlockID, at: t0, revoked: true),
            record(StoreProducts.unlockID, at: t0.addingTimeInterval(day)),
        ])
        #expect(s.unlocked)
        #expect(s.unlockRevoked == false)
    }

    @Test func 返金の項目が無い古い形も読める() throws {
        let old = Data(#"{"unlocked":true,"trialStartedAt":1800000000}"#.utf8)
        #expect(try EntitlementSnapshot.decode(old) == EntitlementSnapshot(unlocked: true, trialStartedAt: t0))
    }

    @Test func 送るときの形とのやり取りで値が変わらない() throws {
        let s = EntitlementSnapshot(unlocked: true, trialStartedAt: t0)
        #expect(try EntitlementSnapshot.decode(s.encoded()) == s)
        #expect(throws: (any Error).self) { try EntitlementSnapshot.decode(Data("x".utf8)) }
    }
}
