import Foundation
import Testing
@testable import WatchHookCore

@Suite("HistorySnapshot")
struct HistorySnapshotTests {
    func log(_ items: [(String, TimeInterval)]) -> MessageLog {
        var log = MessageLog()
        for (text, t) in items {
            log.enqueue(OutgoingMessage(text: text, createdAt: Date(timeIntervalSince1970: t), destinationID: UUID(), source: "watch"),
                        destinationName: "Slack")
        }
        return log
    }

    @Test func 往復しても中身が変わらない() throws {
        let l = log([("a", 1), ("b", 2)])
        let snap = HistorySnapshot(log: l, updatedAt: Date(timeIntervalSince1970: 10))
        let back = try HistorySnapshot.decode(try snap.encoded())
        #expect(back == snap)
        #expect(back.entries.map(\.message.text) == ["b", "a"])
    }

    @Test func 長い本文は切って送る() {
        let l = log([(String(repeating: "あ", count: 500), 1)])
        let snap = HistorySnapshot(log: l, updatedAt: .now, maxTextLength: 200)
        #expect(snap.entries[0].message.text.count == 201)  // 200 文字 + 「…」
        #expect(snap.entries[0].message.text.hasSuffix("…"))
    }

    @Test func 大きすぎるときは古いものから落として上限に収める() throws {
        let l = log((0..<50).map { (String(repeating: "x", count: 200), TimeInterval($0)) })
        let snap = HistorySnapshot(log: l, updatedAt: .now)
        let data = try snap.encoded(maxBytes: 4_000)
        #expect(data.count <= 4_000)
        let back = try HistorySnapshot.decode(data)
        #expect(!back.entries.isEmpty)
        #expect(back.entries.count < 50)
        // 新しいものが残る
        #expect(back.entries.first?.message.createdAt == Date(timeIntervalSince1970: 49))
    }
}

extension HistorySnapshotTests {
    @Test func 古い項目だけが大きいときも新しい項目は残す() throws {
        // 1 文字に結合文字を大量に付けると、文字数の上限を通っても符号化後は大きくなる
        let huge = "e" + String(repeating: "\u{0301}", count: 20_000)
        let l = log([(huge, 1), ("new", 2)])
        let data = try HistorySnapshot(log: l, updatedAt: .now).encoded(maxBytes: 4_000)
        let back = try HistorySnapshot.decode(data)
        #expect(back.entries.map(\.message.text) == ["new"])
    }
}

@Suite("CombinedHistory")
struct CombinedHistoryTests {
    func entry(_ text: String, at t: TimeInterval, id: UUID = UUID()) -> MessageLogEntry {
        MessageLogEntry(message: OutgoingMessage(id: id, text: text, createdAt: Date(timeIntervalSince1970: t), destinationID: UUID(), source: "s"),
                        destinationName: "A", status: .sent(statusCode: 200))
    }

    @Test func 両方の履歴を新しい順に並べ_どちらの端末のものか分かる() {
        let rows = CombinedHistory.rows(local: [entry("p2", at: 4), entry("p1", at: 1)], watch: [entry("w2", at: 3), entry("w1", at: 2)])
        #expect(rows.map(\.entry.message.text) == ["p2", "w2", "w1", "p1"])
        #expect(rows.map(\.origin) == [.thisDevice, .watch, .watch, .thisDevice])
    }

    @Test func 同じIDは手元のものを使う() {
        let id = UUID()
        var mine = entry("mine", at: 1, id: id)
        mine.status = .failed(reason: "x")
        let rows = CombinedHistory.rows(local: [mine], watch: [entry("theirs", at: 1, id: id)])
        #expect(rows.count == 1)
        #expect(rows[0].origin == .thisDevice)
        #expect(rows[0].entry.message.text == "mine")
    }

    @Test func 行のIDは端末をまたいでも重ならない() {
        let rows = CombinedHistory.rows(local: [entry("p", at: 1)], watch: [entry("w", at: 2)])
        #expect(Set(rows.map(\.id)).count == 2)
    }
}
