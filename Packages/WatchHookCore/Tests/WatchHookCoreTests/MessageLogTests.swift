import Foundation
import Testing
@testable import WatchHookCore

@Suite("MessageLog")
struct MessageLogTests {
    func msg(_ text: String = "x", at t: TimeInterval = 0) -> OutgoingMessage {
        OutgoingMessage(text: text, createdAt: Date(timeIntervalSince1970: t), destinationID: UUID(), source: "t")
    }

    @Test func 送信結果で状態が変わる() {
        var log = MessageLog()
        let m = msg()
        log.enqueue(m, destinationName: "A")
        #expect(log.pending.map(\.message.id) == [m.id])

        log.apply(.retryableFailure(reason: "HTTP 500"), to: m.id)
        #expect(log.entries[0].status == .pending(attempts: 1, lastError: "HTTP 500"))
        #expect(log.pending.count == 1)

        log.apply(.sent(statusCode: 200), to: m.id)
        #expect(log.entries[0].status == .sent(statusCode: 200))
        #expect(log.pending.isEmpty)
    }

    @Test func 再送の上限を超えたら失敗にする() {
        var log = MessageLog(maxAttempts: 2)
        let m = msg()
        log.enqueue(m, destinationName: "A")
        log.apply(.retryableFailure(reason: "e1"), to: m.id)
        log.apply(.retryableFailure(reason: "e2"), to: m.id)
        #expect(log.entries[0].status == .failed(reason: "e2"))
        #expect(log.pending.isEmpty)
    }

    @Test func 適用した結果の状態を返す_履歴から消えても返る() {
        var log = MessageLog(capacity: 1)
        let old = msg("old", at: 0)
        log.enqueue(old, destinationName: "A") // pending のまま残る
        let m = msg("new", at: 1)
        log.enqueue(m, destinationName: "A")
        let status = log.apply(.sent(statusCode: 201), to: m.id)
        #expect(status == .sent(statusCode: 201))
        #expect(!log.entries.contains { $0.id == m.id })
    }

    @Test func キャンセルでは状態も再送回数も変えない() {
        var log = MessageLog()
        let m = msg()
        log.enqueue(m, destinationName: "A")
        log.apply(.retryableFailure(reason: "e"), to: m.id)
        log.apply(.cancelled, to: m.id)
        #expect(log.entries[0].status == .pending(attempts: 1, lastError: "e"))
    }

    @Test func 恒久的な失敗はすぐ失敗にする() {
        var log = MessageLog()
        let m = msg()
        log.enqueue(m, destinationName: "A")
        log.apply(.permanentFailure(reason: "HTTP 401"), to: m.id)
        #expect(log.entries[0].status == .failed(reason: "HTTP 401"))
    }

    @Test func 新しい順に並び_上限を超えた古い完了済みから消す_未送信は消さない() {
        var log = MessageLog(capacity: 2)
        let old = msg("old", at: 0)
        log.enqueue(old, destinationName: "A") // pending のまま
        let a = msg("a", at: 1)
        log.enqueue(a, destinationName: "A")
        log.apply(.sent(statusCode: 200), to: a.id)
        let b = msg("b", at: 2)
        log.enqueue(b, destinationName: "A")
        log.apply(.sent(statusCode: 200), to: b.id)

        #expect(log.entries.map(\.message.text) == ["b", "old"])
    }

    @Test func 失敗したものを再送待ちに戻せる() {
        var log = MessageLog()
        let m = msg()
        log.enqueue(m, destinationName: "A")
        log.apply(.permanentFailure(reason: "x"), to: m.id)
        log.retry(m.id)
        #expect(log.entries[0].status == .pending(attempts: 0, lastError: nil))
    }

    @Test func 送信済みのものは再送待ちに戻さない() {
        var log = MessageLog()
        let m = msg()
        log.enqueue(m, destinationName: "A")
        log.apply(.sent(statusCode: 200), to: m.id)
        log.retry(m.id)
        #expect(log.entries[0].status == .sent(statusCode: 200))
    }

    @Test func 読み直した履歴に手元の新しい項目を足せる_同じIDは手元を優先() {
        var disk = MessageLog()
        let old = msg("old", at: 0)
        disk.enqueue(old, destinationName: "A")
        var memory = MessageLog()
        let new = msg("new", at: 1)
        memory.enqueue(new, destinationName: "A")
        memory.enqueue(old, destinationName: "A")
        memory.apply(.sent(statusCode: 200), to: old.id)

        disk.merge(memory)
        #expect(disk.entries.map(\.message.text) == ["new", "old"])
        #expect(disk.status(of: old.id) == .sent(statusCode: 200))
    }

    @Test func JSONで保存して戻せる() throws {
        var log = MessageLog()
        log.enqueue(msg(), destinationName: "A")
        let data = try JSONEncoder().encode(log)
        let back = try JSONDecoder().decode(MessageLog.self, from: data)
        #expect(back == log)
    }
}

@Suite("DestinationConfig")
struct DestinationConfigTests {
    @Test func 既定の送り先が消えたら先頭にする() {
        let a = Destination.preset(.slack)
        let b = Destination.preset(.discord)
        var c = DestinationConfig(destinations: [a, b], defaultDestinationID: b.id)
        #expect(c.defaultDestination?.id == b.id)
        c.destinations.removeAll { $0.id == b.id }
        #expect(c.defaultDestination?.id == a.id)
    }

    @Test func 版が大きい設定だけを新しいとみなす() {
        var older = DestinationConfig()
        older.revision = 3
        var newer = older
        newer.revision = 4
        #expect(newer.isNewer(than: older))
        #expect(!older.isNewer(than: newer))
        #expect(!older.isNewer(than: older))
    }

    @Test func iPhoneで作り直した設定は版が小さくても新しいとみなす() {
        var current = DestinationConfig()
        current.revision = 10
        var reinstalled = DestinationConfig()
        reinstalled.revision = 1
        #expect(reinstalled.isNewer(than: current))
    }

    @Test func 次の版は必ず増える() {
        var c = DestinationConfig()
        c.revision = 5
        let next = c.nextRevision()
        #expect(next.revision == 6)
        #expect(next.epoch == c.epoch)
    }

    @Test func 一度も保存していない設定は最初の保存で新しいepochを持つ() {
        let unsaved = DestinationConfig.unsaved
        #expect(DestinationConfig.unsaved == unsaved) // 何度読んでも同じ (返信の前後で巻き戻らない)
        let first = unsaved.nextRevision()
        #expect(first.epoch != DestinationConfig.unsavedEpoch)
        #expect(first.revision == 1)
        #expect(first.isNewer(than: unsaved))
        #expect(!unsaved.isNewer(than: unsaved))
    }

    @Test func 大きすぎる設定は保存前に弾く() {
        var d = Destination.preset(.custom)
        d.bodyTemplate = String(repeating: "a", count: DestinationConfig.maxEncodedBytes)
        let c = DestinationConfig(destinations: [d])
        #expect(throws: DestinationConfig.TooLarge.self) { try c.validateSize() }
        #expect(throws: Never.self) { try DestinationConfig(destinations: [.preset(.slack)]).validateSize() }
    }

    @Test func 古い要求への返信は捨てる() {
        var gate = LatestRequestGate()
        let first = gate.begin()
        let second = gate.begin()
        #expect(!gate.isLatest(first))
        #expect(gate.isLatest(second))
    }

    @Test func 空なら既定も無い() {
        #expect(DestinationConfig().defaultDestination == nil)
    }

    @Test func JSONで往復できる() throws {
        var d = Destination.preset(.custom)
        d.headers = [HeaderField(name: "Authorization", value: "Bearer x", isSecret: true)]
        let c = DestinationConfig(destinations: [d], defaultDestinationID: d.id)
        let back = try DestinationConfig.decode(c.encoded())
        #expect(back == c)
    }
}
