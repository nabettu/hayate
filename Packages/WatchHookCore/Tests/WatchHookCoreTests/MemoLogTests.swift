import Foundation
import Testing
@testable import WatchHookCore

@Suite("MemoLog")
struct MemoLogTests {
    let destA = UUID()
    let destB = UUID()

    func memo(_ text: String = "x", at t: TimeInterval = 0, origin: DeviceRole = .watch, deliveries: [Delivery] = []) -> Memo {
        Memo(text: text, createdAt: Date(timeIntervalSince1970: t), source: "t", origin: origin, deliveries: deliveries)
    }

    func webhook(_ dest: UUID, owner: DeviceRole = .watch, name: String = "A") -> Delivery {
        Delivery(target: .webhook(destinationID: dest, name: name), owner: owner, text: "x")
    }

    @Test func 連携の結果は連携ごとに持ち_一部の失敗が他を止めない() {
        var log = MemoLog(owner: .watch)
        let a = webhook(destA), b = webhook(destB, name: "B")
        let m = memo(deliveries: [a, b])
        log.add(m)
        #expect(log.pendingDeliveries.map(\.deliveryID) == [a.id, b.id])

        log.apply(.permanent(reason: "HTTP 404"), memoID: m.id, deliveryID: a.id)
        log.apply(.done(detail: "HTTP 200"), memoID: m.id, deliveryID: b.id)
        let saved = log.memo(id: m.id)!
        #expect(saved.deliveries[0].status == .failed(reason: "HTTP 404"))
        #expect(saved.deliveries[1].status == .done(detail: "HTTP 200"))
        #expect(log.pendingDeliveries.isEmpty)
    }

    @Test func 再送の上限を超えたら失敗にする() {
        var log = MemoLog(owner: .watch, maxAttempts: 2)
        let a = webhook(destA)
        let m = memo(deliveries: [a])
        log.add(m)
        log.apply(.retryable(reason: "e1"), memoID: m.id, deliveryID: a.id)
        #expect(log.memo(id: m.id)!.deliveries[0].status == .pending(attempts: 1, lastError: "e1"))
        log.apply(.retryable(reason: "e2"), memoID: m.id, deliveryID: a.id)
        #expect(log.memo(id: m.id)!.deliveries[0].status == .failed(reason: "e2"))
    }

    @Test func 状態を変えるたびに版が進み_キャンセルでは進まない() {
        var log = MemoLog(owner: .watch)
        let a = webhook(destA)
        let m = memo(deliveries: [a])
        log.add(m)
        log.apply(.cancelled, memoID: m.id, deliveryID: a.id)
        #expect(log.memo(id: m.id)!.deliveries[0].revision == 0)
        log.apply(.retryable(reason: "e"), memoID: m.id, deliveryID: a.id)
        #expect(log.memo(id: m.id)!.deliveries[0].revision == 1)
    }

    @Test func 自分が受け持たない連携は送らず_状態も変えない() {
        var log = MemoLog(owner: .watch)
        let mine = webhook(destA)
        let phones = Delivery(target: .reminder(listName: "買い物"), owner: .phone, text: "牛乳")
        let m = memo(deliveries: [mine, phones])
        log.add(m)
        #expect(log.pendingDeliveries.map(\.deliveryID) == [mine.id])
        log.apply(.done(detail: nil), memoID: m.id, deliveryID: phones.id)
        #expect(log.memo(id: m.id)!.deliveries[1].status == .pending(attempts: 0, lastError: nil))
        #expect(log.retry(memoID: m.id, deliveryID: phones.id) == false)
    }

    @Test func 再試行は未完了のものだけ() {
        var log = MemoLog(owner: .watch)
        let a = webhook(destA), b = webhook(destB)
        let m = memo(deliveries: [a, b])
        log.add(m)
        log.apply(.done(detail: "HTTP 200"), memoID: m.id, deliveryID: a.id)
        log.apply(.permanent(reason: "HTTP 400"), memoID: m.id, deliveryID: b.id)
        #expect(log.retry(memoID: m.id, deliveryID: a.id) == false)
        #expect(log.retry(memoID: m.id, deliveryID: b.id) == true)
        #expect(log.pendingDeliveries.map(\.deliveryID) == [b.id])
    }

    @Test func 古いものから送る() {
        var log = MemoLog(owner: .watch)
        let newer = memo("new", at: 10, deliveries: [webhook(destA)])
        let older = memo("old", at: 1, deliveries: [webhook(destA)])
        log.add(newer)
        log.add(older)
        #expect(log.memos.map(\.text) == ["new", "old"])
        #expect(log.pendingDeliveries.map(\.memoID) == [older.id, newer.id])
    }

    @Test func 件数の上限を超えたら古いものから消すが_未完了と未同期は残す() {
        var log = MemoLog(owner: .watch, capacity: 2)
        let pending = memo("pending", at: 0, deliveries: [webhook(destA)])
        log.add(pending)
        var unsynced = memo("unsynced", at: 1)
        unsynced.phoneSync = .waiting
        log.add(unsynced)
        log.add(memo("a", at: 2))
        log.add(memo("b", at: 3))
        log.add(memo("c", at: 4))
        // 新しい 2 件は残し、それより古いものは未完了・未同期だけ残す (新しく入れたものが消えることはない)
        #expect(log.memos.map(\.text) == ["c", "b", "unsynced", "pending"])
    }

    @Test func 上限なしなら消さない() {
        var log = MemoLog(owner: .phone, capacity: nil)
        for i in 0..<300 { log.add(memo("\(i)", at: TimeInterval(i))) }
        #expect(log.memos.count == 300)
    }

    @Test func 削除すると墓標が残り_遅れて届いた写しで戻らない() {
        var log = MemoLog(owner: .phone, capacity: nil)
        let m = memo(deliveries: [webhook(destA)])
        log.add(m)
        #expect(log.remove(memoID: m.id) != nil)
        #expect(log.memo(id: m.id) == nil)
        #expect(log.isDeleted(m.id))
        #expect(log.merge(m, insertIfMissing: true) == .ignored)
        #expect(log.memo(id: m.id) == nil)
    }

    @Test func マージは連携ごとに版の新しいほうを取り_知らない連携は足す() {
        // iPhone 側の写し
        var phone = MemoLog(owner: .phone, capacity: nil)
        let a = webhook(destA)
        var m = memo(deliveries: [a])
        #expect(phone.merge(m, insertIfMissing: true) == .inserted)

        // 時計で送れた (版 1)
        m.deliveries[0].status = .done(detail: "HTTP 200")
        m.deliveries[0].revision = 1
        #expect(phone.merge(m, insertIfMissing: true) == .updated)
        #expect(phone.memo(id: m.id)!.deliveries[0].status == .done(detail: "HTTP 200"))

        // 古い写し (版 0) が遅れて届いても戻らない
        var stale = m
        stale.deliveries[0].status = .pending(attempts: 0, lastError: nil)
        stale.deliveries[0].revision = 0
        #expect(phone.merge(stale, insertIfMissing: true) == .unchanged)
        #expect(phone.memo(id: m.id)!.deliveries[0].status == .done(detail: "HTTP 200"))

        // iPhone が足した連携を時計が受け取る
        var watch = MemoLog(owner: .watch)
        watch.add(m)
        let reminder = Delivery(target: .reminder(listName: "L"), owner: .phone, text: "牛乳")
        phone.addDelivery(reminder, to: m.id)
        #expect(watch.merge(phone.memo(id: m.id)!, insertIfMissing: false) == .updated)
        #expect(watch.memo(id: m.id)!.deliveries.map(\.id) == [a.id, reminder.id])
    }

    @Test func 自分が受け持つ連携は相手の写しで上書きしない() {
        var watch = MemoLog(owner: .watch)
        let a = webhook(destA)
        let m = memo(deliveries: [a])
        watch.add(m)
        var remote = m
        remote.deliveries[0].status = .done(detail: "fake")
        remote.deliveries[0].revision = 99
        #expect(watch.merge(remote, insertIfMissing: false) == .unchanged)
        #expect(watch.memo(id: m.id)!.deliveries[0].status == .pending(attempts: 0, lastError: nil))
    }

    @Test func 知らないメモは_insertIfMissing_のときだけ足す() {
        var watch = MemoLog(owner: .watch)
        let m = memo()
        #expect(watch.merge(m, insertIfMissing: false) == .ignored)
        #expect(watch.memos.isEmpty)
    }

    @Test func 端末だけの状態_phoneSync_はマージで変えない() {
        var watch = MemoLog(owner: .watch)
        var m = memo()
        m.phoneSync = .waiting
        watch.add(m)
        var remote = m
        remote.phoneSync = nil
        _ = watch.merge(remote, insertIfMissing: false)
        #expect(watch.memo(id: m.id)!.phoneSync == .waiting)
        watch.markPhoneSynced(m.id)
        #expect(watch.memo(id: m.id)!.phoneSync == .delivered)
    }

    @Test func 保存しきれなかったメモは墓標を残さず取り除く() {
        var log = MemoLog(owner: .phone, capacity: nil)
        let m = memo()
        log.add(m)
        log.discard(memoID: m.id)
        #expect(log.memo(id: m.id) == nil)
        #expect(!log.isDeleted(m.id))
        #expect(log.merge(m, insertIfMissing: true) == .inserted)
    }

    @Test func 削除で自分の未送信を取り消す() {
        var log = MemoLog(owner: .phone, capacity: nil)
        let a = webhook(destA, owner: .phone)
        let m = memo(origin: .phone, deliveries: [a])
        log.add(m)
        let removed = log.remove(memoID: m.id)
        #expect(removed?.deliveries[0].status == .cancelled)
        #expect(log.pendingDeliveries.isEmpty)
    }

    @Test func 状態のまとめ() {
        var m = memo()
        #expect(m.summary == .memoOnly)
        m.deliveries = [webhook(destA)]
        #expect(m.summary == .waiting)
        m.deliveries[0].status = .failed(reason: "x")
        #expect(m.summary == .someFailed)
        m.deliveries[0].status = .done(detail: nil)
        #expect(m.summary == .allDone)
        m.deliveries[0].status = .cancelled
        #expect(m.summary == .allDone)
        m.deliveries = [webhook(destA)]
        m.phoneSync = .waiting
        m.deliveries[0].status = .done(detail: nil)
        #expect(m.summary == .waiting)
    }

    @Test func 古い履歴_MessageLog_から移す() throws {
        var legacy = MessageLog()
        let dest = UUID()
        let msg = OutgoingMessage(text: "old", createdAt: Date(timeIntervalSince1970: 5), destinationID: dest, source: "watch")
        legacy.enqueue(msg, destinationName: "Slack")
        legacy.apply(.sent(statusCode: 200), to: msg.id)
        let failed = OutgoingMessage(text: "bad", createdAt: Date(timeIntervalSince1970: 6), destinationID: dest, source: "watch")
        legacy.enqueue(failed, destinationName: "Slack")
        legacy.apply(.retryableFailure(reason: "e"), to: failed.id)

        let log = MemoLog(migrating: legacy, owner: .watch)
        #expect(log.memos.count == 2)
        let old = try #require(log.memo(id: msg.id))
        #expect(old.text == "old")
        #expect(old.wantsPhoneIntegrations == false)
        #expect(old.phoneSync == .waiting)
        #expect(old.deliveries.count == 1)
        #expect(old.deliveries[0].target == .webhook(destinationID: dest, name: "Slack"))
        #expect(old.deliveries[0].status == .done(detail: "HTTP 200"))
        #expect(log.memo(id: failed.id)!.deliveries[0].status == .pending(attempts: 1, lastError: "e"))
    }

    @Test func 保存した形式を読み直せる() throws {
        var log = MemoLog(owner: .watch)
        log.add(memo(deliveries: [webhook(destA), Delivery(target: .markdown(folderName: "Vault"), owner: .phone, text: "x")]))
        _ = log.remove(memoID: UUID())
        let data = try JSONEncoder().encode(log)
        let back = try JSONDecoder().decode(MemoLog.self, from: data)
        #expect(back == log)
    }

    @Test func 送信用のメッセージはメモの_ID_を使う() {
        let a = webhook(destA)
        let m = memo(deliveries: [a])
        let out = m.outgoingMessage(for: a)
        #expect(out?.id == m.id)
        #expect(out?.destinationID == destA)
        #expect(out?.text == a.text)
        #expect(m.outgoingMessage(for: Delivery(target: .reminder(listName: "L"), owner: .phone, text: "x")) == nil)
    }
}

@Suite("後から送る印")
struct ManualDeliveryTests {
    @Test func 後から送ったものは印が付き_写しを経ても残る() throws {
        let d = Delivery(target: .webhook(destinationID: UUID(), name: "A"), owner: .phone, text: "a", isManual: true)
        #expect(d.isManual)
        let back = try JSONDecoder().decode(Delivery.self, from: JSONEncoder().encode(d))
        #expect(back.isManual)
        #expect(Delivery(target: .reminder(listName: "L"), owner: .phone, text: "a").isManual == false)
    }

    @Test func 印の無い前の形式も読める() throws {
        let d = Delivery(target: .webhook(destinationID: UUID(), name: "A"), owner: .watch, text: "a")
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(d)) as! [String: Any]
        json["manual"] = nil
        let back = try JSONDecoder().decode(Delivery.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(back.isManual == false)
        #expect(back.id == d.id)
    }
}

@Suite("写しの新旧")
struct MemoCopyTests {
    func memo(_ deliveries: [Delivery]) -> Memo {
        Memo(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, text: "a", source: "t", origin: .watch, deliveries: deliveries)
    }

    @Test func どの連携も版が同じか新しければ_古い写しの代わりになる() {
        let a = Delivery(target: .reminder(listName: "L"), owner: .phone, text: "a", revision: 1)
        var a2 = a
        a2.revision = 2
        let b = Delivery(target: .markdown(folderName: "F"), owner: .phone, text: "a", revision: 1)
        #expect(memo([a2, b]).covers(memo([a, b])))
        #expect(memo([a, b]).covers(memo([a, b])))
        #expect(!memo([a, b]).covers(memo([a2, b])))
        // 知らない連携がある写しの代わりにはならない
        #expect(!memo([a2]).covers(memo([a, b])))
        #expect(memo([a2, b]).covers(memo([a])))
    }

    @Test func 入力した時点のタイムゾーンを持ち_前の形式は今のものを使う() throws {
        let m = Memo(text: "a", source: "t", origin: .phone, timeZoneID: "Asia/Tokyo")
        #expect(m.timeZone.identifier == "Asia/Tokyo")
        let back = try JSONDecoder().decode(Memo.self, from: JSONEncoder().encode(m))
        #expect(back.timeZone.identifier == "Asia/Tokyo")
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(m)) as! [String: Any]
        json["timeZoneID"] = nil
        let old = try JSONDecoder().decode(Memo.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(old.timeZone == .current)
    }
}
