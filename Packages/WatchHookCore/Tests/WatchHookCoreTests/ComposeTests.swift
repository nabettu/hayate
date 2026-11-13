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
