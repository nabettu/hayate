import Foundation
import Testing
@testable import WatchHookCore

@Suite("MessageText")
struct MessageTextTests {
    @Test func 前後の空白と改行を落とす() {
        #expect(MessageText.normalized("  こんにちは\n\n") == "こんにちは")
    }

    @Test func 途中の改行は残す() {
        #expect(MessageText.normalized("1行目\n2行目") == "1行目\n2行目")
    }

    @Test func 空白だけなら送らない() {
        #expect(MessageText.normalized(" \n\t ") == nil)
        #expect(MessageText.normalized("") == nil)
    }
}

@Suite("DestinationConfig.resolve")
struct ResolveDestinationTests {
    let a = Destination(name: "A", kind: .custom, url: "https://a.example", bodyTemplate: "")
    let b = Destination(name: "B", kind: .custom, url: "https://b.example", bodyTemplate: "")

    @Test func 選んだ送り先があればそれを使う() {
        let config = DestinationConfig(destinations: [a, b], defaultDestinationID: a.id)
        #expect(config.resolve(selectedID: b.id.uuidString)?.id == b.id)
    }

    @Test func 選んだ送り先が消えていたら既定に戻す() {
        let config = DestinationConfig(destinations: [a, b], defaultDestinationID: b.id)
        #expect(config.resolve(selectedID: UUID().uuidString)?.id == b.id)
    }

    @Test func 未選択なら既定を使う() {
        let config = DestinationConfig(destinations: [a, b], defaultDestinationID: b.id)
        #expect(config.resolve(selectedID: "")?.id == b.id)
    }

    @Test func 送り先が無ければnil() {
        #expect(DestinationConfig().resolve(selectedID: "") == nil)
    }
}

@Suite("DestinationConfig.correctedSelection")
struct CorrectedSelectionTests {
    let a = Destination(name: "A", kind: .custom, url: "https://a.example", bodyTemplate: "")
    let b = Destination(name: "B", kind: .custom, url: "https://b.example", bodyTemplate: "")

    @Test func 選んだ送り先が残っていれば直さない() {
        let config = DestinationConfig(destinations: [a, b], defaultDestinationID: a.id)
        #expect(config.correctedSelection(b.id.uuidString) == nil)
    }

    @Test func 選んだ送り先が消えていたら既定に直す() {
        let config = DestinationConfig(destinations: [a, b], defaultDestinationID: b.id)
        #expect(config.correctedSelection(UUID().uuidString) == b.id.uuidString)
    }

    @Test func 未選択なら既定を入れる() {
        let config = DestinationConfig(destinations: [a, b], defaultDestinationID: a.id)
        #expect(config.correctedSelection("") == a.id.uuidString)
    }

    /// 設定を読めなかった (ロック中など) ときも空になる。消えたのか読めないのか分からないので、覚えている選択を消さない
    @Test func 送り先が空なら選択を触らない() {
        #expect(DestinationConfig().correctedSelection(a.id.uuidString) == nil)
        #expect(DestinationConfig.unsaved.correctedSelection(a.id.uuidString) == nil)
    }
}
