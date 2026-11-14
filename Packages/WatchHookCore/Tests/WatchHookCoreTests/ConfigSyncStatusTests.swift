import Testing
@testable import WatchHookCore

@Suite("ConfigSyncStatus")
struct ConfigSyncStatusTests {
    @Test func 起動直後の失敗はエラーを出さずに取り直す() {
        // 起動直後は時計と iPhone のつながりが落ち着く前で、取り寄せが失敗しやすい。ここで赤字を出すと一瞬出て消える
        var s = ConfigSyncStatus()
        s.beginStartup()
        #expect(s.isStarting)
        #expect(s.failed("届かない") == .retry(after: .seconds(1)))
        #expect(s.visibleError == nil)
        #expect(s.isStarting)
    }

    @Test func 取り直して成功したらエラーを出さずに準備完了() {
        var s = ConfigSyncStatus()
        s.beginStartup()
        _ = s.failed("届かない")
        s.succeeded()
        #expect(!s.isStarting)
        #expect(s.visibleError == nil)
    }

    @Test func 取り直しても失敗し続けたらエラーを出す() {
        var s = ConfigSyncStatus()
        s.beginStartup()
        #expect(s.failed("e1") == .retry(after: .seconds(1)))
        #expect(s.failed("e2") == .retry(after: .seconds(2)))
        #expect(s.visibleError == nil)
        #expect(s.failed("e3") == .show)
        #expect(!s.isStarting)
        #expect(s.visibleError == "e3")
    }

    @Test func 準備ができた後の失敗はすぐ出す() {
        var s = ConfigSyncStatus()
        s.beginStartup()
        s.succeeded()
        #expect(s.failed("届かない") == .show)
        #expect(s.visibleError == "届かない")
    }

    @Test func 成功したらエラーを消す() {
        var s = ConfigSyncStatus()
        s.beginStartup()
        s.succeeded()
        _ = s.failed("届かない")
        s.succeeded()
        #expect(s.visibleError == nil)
    }

    @Test func 打ち切りで準備完了にし_それまでの失敗を出す() {
        // 返事が来ない・つながらないままのときも、ずっと準備中にはしない
        var s = ConfigSyncStatus()
        let g = s.beginStartup()
        _ = s.failed("届かない")
        s.endStartup(generation: g)
        #expect(!s.isStarting)
        #expect(s.visibleError == "届かない")
    }

    @Test func 前の起動の打ち切りで今の準備中を終えない() {
        var s = ConfigSyncStatus()
        let old = s.beginStartup()
        s.succeeded()
        _ = s.beginStartup()  // 前面に戻ってきた
        s.endStartup(generation: old)
        #expect(s.isStarting)
    }

    @Test func 前面に戻ったら出ていたエラーを隠して取り直しの回数も戻す() {
        var s = ConfigSyncStatus()
        s.beginStartup()
        s.succeeded()
        _ = s.failed("前の失敗")
        s.beginStartup()
        #expect(s.visibleError == nil)
        #expect(s.failed("届かない") == .retry(after: .seconds(1)))
    }
}
