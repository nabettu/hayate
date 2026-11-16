import Testing
@testable import WatchHookCore

@Suite("AutoInputTrigger")
struct AutoInputTriggerTests {
    @Test func 起動して前面に来たら開く() {
        var trigger = AutoInputTrigger()
        #expect(trigger.update(.inactive) == false)
        #expect(trigger.update(.active) == true)
    }

    @Test func 起動直後にいきなり前面でも開く() {
        var trigger = AutoInputTrigger()
        #expect(trigger.update(.active) == true)
    }

    @Test func 前面のまま同じ知らせが続いても開き直さない() {
        var trigger = AutoInputTrigger()
        _ = trigger.update(.active)
        #expect(trigger.update(.active) == false)
    }

    @Test func 手首を下げて上げただけなら開かない() {
        var trigger = AutoInputTrigger()
        _ = trigger.update(.active)
        #expect(trigger.update(.inactive) == false)
        #expect(trigger.update(.active) == false)
    }

    @Test func 裏へ回ってから戻ったら開く() {
        var trigger = AutoInputTrigger()
        _ = trigger.update(.active)
        #expect(trigger.update(.inactive) == false)
        #expect(trigger.update(.background) == false)
        #expect(trigger.update(.inactive) == false)
        #expect(trigger.update(.active) == true)
    }
}
