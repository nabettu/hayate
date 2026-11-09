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
