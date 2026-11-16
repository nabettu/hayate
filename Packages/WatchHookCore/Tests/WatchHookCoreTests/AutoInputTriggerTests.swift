import Testing
@testable import WatchHookCore

@Suite("AutoInputTrigger")
struct AutoInputTriggerTests {
    /// 画面の状態を順に渡して、最後に開けるかを返す。
    private func opens(after phases: [AutoInputTrigger.Phase], busy: Bool = false) -> Bool {
        var trigger = AutoInputTrigger()
        for phase in phases { trigger.update(phase) }
        return trigger.take(busy: busy)
    }

    /// `#expect` の中では mutating を呼べないので、外で呼ぶ。
    private func take(_ trigger: inout AutoInputTrigger, busy: Bool) -> Bool {
        trigger.take(busy: busy)
    }

    @Test func 起動して前面に来たら開く() {
        #expect(opens(after: [.inactive, .active]))
    }

    @Test func 起動直後にいきなり前面でも開く() {
        #expect(opens(after: [.active]))
    }

    @Test func 前面に来る前は開かない() {
        #expect(!opens(after: [.inactive]))
    }

    @Test func 一度開いたら同じ前面のあいだは開き直さない() {
        var trigger = AutoInputTrigger()
        trigger.update(.active)
        #expect(take(&trigger, busy: false))
        trigger.update(.active)
        #expect(!take(&trigger, busy: false))
    }

    @Test func 手首を下げて上げただけなら開かない() {
        var trigger = AutoInputTrigger()
        trigger.update(.active)
        _ = trigger.take(busy: false)
        trigger.update(.inactive)
        trigger.update(.active)
        #expect(!take(&trigger, busy: false))
    }

    @Test func 裏へ回ってから戻ったら開く() {
        var trigger = AutoInputTrigger()
        trigger.update(.active)
        _ = trigger.take(busy: false)
        for phase: AutoInputTrigger.Phase in [.inactive, .background, .inactive, .active] { trigger.update(phase) }
        #expect(take(&trigger, busy: false))
    }

    @Test func 送信中や入力中に戻ったら_終わってから開く() {
        var trigger = AutoInputTrigger()
        trigger.update(.active)
        #expect(!take(&trigger, busy: true))
        #expect(take(&trigger, busy: false))
    }

    @Test func 待っているあいだに手首を下げたら_上げてから開く() {
        var trigger = AutoInputTrigger()
        trigger.update(.active)
        _ = trigger.take(busy: true)
        trigger.update(.inactive)
        #expect(!take(&trigger, busy: false))
        trigger.update(.active)
        #expect(take(&trigger, busy: false))
    }

    @Test func 開けなかったら_次に前面に来たとき開き直す() {
        var trigger = AutoInputTrigger()
        trigger.update(.active)
        #expect(take(&trigger, busy: false))
        trigger.couldNotOpen()
        trigger.update(.inactive)
        trigger.update(.active)
        #expect(take(&trigger, busy: false))
    }
}
