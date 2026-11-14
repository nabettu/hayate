import Testing
@testable import WatchHookCore

@Suite("ConfigSyncStatus")
struct ConfigSyncStatusTests {
    @Test func 起動直後の失敗はエラーを出さずに取り直す() {
        // 起動直後は時計と iPhone のつながりが落ち着く前で、取り寄せが失敗しやすい。ここで赤字を出すと一瞬出て消える
        var s = ConfigSyncStatus()
        s.beginStartup()
        #expect(s.isStarting)
        let t = s.beginRequest()
        let r1 = s.failed("届かない", t) == .retry(after: .seconds(1))
        #expect(r1)
        #expect(s.visibleError == nil)
        #expect(s.isStarting)
    }

    @Test func 取り直して成功したらエラーを出さずに準備完了() {
        var s = ConfigSyncStatus()
        s.beginStartup()
        _ = s.failed("届かない", s.beginRequest())
        let r2 = s.succeeded(s.beginRequest())
        #expect(r2)
        #expect(!s.isStarting)
        #expect(s.visibleError == nil)
    }

    @Test func 取り直しても失敗し続けたらエラーを出す() {
        var s = ConfigSyncStatus()
        s.beginStartup()
        let r3 = s.failed("e1", s.beginRequest()) == .retry(after: .seconds(1))
        #expect(r3)
        let r4 = s.failed("e2", s.beginRequest()) == .retry(after: .seconds(2))
        #expect(r4)
        #expect(s.visibleError == nil)
        let r5 = s.failed("e3", s.beginRequest())
        #expect(r5 == .show)
        #expect(!s.isStarting)
        #expect(s.visibleError == "e3")
    }

    @Test func 準備ができた後の失敗はすぐ出す() {
        var s = ConfigSyncStatus()
        s.beginStartup()
        s.succeeded(s.beginRequest())
        let r6 = s.failed("届かない", s.beginRequest())
        #expect(r6 == .show)
        #expect(s.visibleError == "届かない")
    }

    @Test func 成功したらエラーを消す() {
        var s = ConfigSyncStatus()
        s.beginStartup()
        s.succeeded(s.beginRequest())
        _ = s.failed("届かない", s.beginRequest())
        s.succeeded(s.beginRequest())
        #expect(s.visibleError == nil)
    }

    @Test func 打ち切りで準備完了にし_それまでの失敗を出す() {
        // 返事が来ない・つながらないままのときも、ずっと準備中にはしない
        var s = ConfigSyncStatus()
        let g = s.beginStartup()
        _ = s.failed("届かない", s.beginRequest())
        s.endStartup(generation: g)
        #expect(!s.isStarting)
        #expect(s.visibleError == "届かない")
    }

    @Test func 前の起動の打ち切りで今の準備中を終えない() {
        var s = ConfigSyncStatus()
        let old = s.beginStartup()
        s.succeeded(s.beginRequest())
        _ = s.beginStartup()  // 前面に戻ってきた
        s.endStartup(generation: old)
        #expect(s.isStarting)
    }

    @Test func 前面に戻ったら出ていたエラーを隠す() {
        var s = ConfigSyncStatus()
        s.beginStartup()
        s.succeeded(s.beginRequest())
        _ = s.failed("前の失敗", s.beginRequest())
        s.beginStartup()
        #expect(s.visibleError == nil)
    }

    @Test func 前面に戻ったら取り直しの回数を最初に戻す() {
        var s = ConfigSyncStatus()
        s.beginStartup()
        let r7 = s.failed("e1", s.beginRequest()) == .retry(after: .seconds(1))
        #expect(r7)
        let r8 = s.failed("e2", s.beginRequest()) == .retry(after: .seconds(2))
        #expect(r8)
        s.beginStartup()
        let r9 = s.failed("e3", s.beginRequest()) == .retry(after: .seconds(1))
        #expect(r9)
    }

    // MARK: - 古い取り寄せ・古い準備期間からの結果

    @Test func 最新でない要求の結果は無視する() {
        var s = ConfigSyncStatus()
        s.beginStartup()
        let old = s.beginRequest()
        let latest = s.beginRequest()
        #expect(!s.isLatest(old))
        #expect(s.isLatest(latest))
        let r10 = s.succeeded(old)
        #expect(!r10)
        #expect(s.isStarting)
        let r11 = s.failed("古い", old)
        #expect(r11 == .ignore)
        // 古い失敗で取り直しの回数を使わない
        let r12 = s.failed("e1", latest) == .retry(after: .seconds(1))
        #expect(r12)
    }

    @Test func 前の準備期間の要求の成功で今の準備中を終えない() {
        // 前面に戻ったときにつながっておらず新しい要求を出せないと、前の要求が最新のまま残る
        var s = ConfigSyncStatus()
        s.beginStartup()
        let t = s.beginRequest()
        s.beginStartup()  // 前面に戻ってきた (要求は出せなかった)
        let accepted = s.succeeded(t)
        #expect(accepted)  // 設定は受け取ってよい
        #expect(s.isStarting)  // が、今の準備期間は終えない
    }

    @Test func 前の準備期間の要求の失敗は今の取り直しの回数を使わない() {
        var s = ConfigSyncStatus()
        s.beginStartup()
        let t = s.beginRequest()
        s.beginStartup()
        let r13 = s.failed("古い", t)
        #expect(r13 == .ignore)
        #expect(s.visibleError == nil)
        let r14 = s.failed("e1", s.beginRequest()) == .retry(after: .seconds(1))
        #expect(r14)
    }

    @Test func 予約した取り直しは_その後に別の要求を出していたら行わない() {
        var s = ConfigSyncStatus()
        s.beginStartup()
        let t = s.beginRequest()
        _ = s.failed("届かない", t)
        #expect(s.shouldRetry(after: t))
        _ = s.beginRequest()  // つながった知らせなどで別に取りに行った
        #expect(!s.shouldRetry(after: t))
    }

    @Test func 予約した取り直しは_前面に戻った後は行わない() {
        var s = ConfigSyncStatus()
        s.beginStartup()
        let t = s.beginRequest()
        _ = s.failed("届かない", t)
        s.beginStartup()
        #expect(!s.shouldRetry(after: t))
    }
}
