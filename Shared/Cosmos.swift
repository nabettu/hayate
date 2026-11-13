import SwiftUI
import WatchHookCore

// MARK: - 背景

/// グラデーションの夜空 + またたく星。
struct CosmicBackground: View {
    var starCount = 46

    var body: some View {
        ZStack {
            Cosmos.background
            Starfield(count: starCount)
        }
        .ignoresSafeArea()
    }
}

/// 星をまたたかせる。位置は固定の乱数で決め、画面を開き直しても同じ星空にする。
/// 「視差効果を減らす」が有効なら止める。時計では電池のため更新を間引く。
struct Starfield: View {
    var count: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Star {
        var x: Double, y: Double, radius: Double, phase: Double, speed: Double, sparkle: Bool
    }

    private var stars: [Star] {
        var rng = SeededRandom(seed: 20261110)
        return (0..<count).map { i in
            Star(
                x: rng.next(), y: rng.next(),
                radius: 0.6 + rng.next() * 1.4,
                phase: rng.next() * .pi * 2,
                speed: 0.6 + rng.next() * 1.6,
                // 数個だけアイコンと同じ 4 つ角の星にする
                sparkle: i % 13 == 5
            )
        }
    }

    var body: some View {
        let stars = stars
        TimelineView(.animation(minimumInterval: Self.frameInterval, paused: reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                for s in stars {
                    let twinkle = reduceMotion ? 0.8 : 0.45 + 0.55 * (0.5 + 0.5 * sin(t * s.speed + s.phase))
                    let p = CGPoint(x: s.x * size.width, y: s.y * size.height)
                    if s.sparkle {
                        let r = (5 + s.radius * 3) * (0.8 + 0.2 * twinkle)
                        ctx.fill(SparkleShape().path(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                                 with: .color(Cosmos.star.opacity(twinkle)))
                    } else {
                        let r = s.radius
                        ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                                 with: .color(.white.opacity(0.85 * twinkle)))
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    #if os(watchOS)
    private static let frameInterval: Double = 1.0 / 12
    #else
    private static let frameInterval: Double = 1.0 / 30
    #endif
}

// MARK: - 送信の演出

/// 送信の演出の段階。
/// 1. 送り始め (`sending`): 画面の紙飛行機 (iPhone は見出しの絵、時計は送るボタン) から飛び立ち、右へ飛び去る
/// 2. 送れた (`sent`): 別の紙飛行機が画面の右下から左上へ横切る
///    送れなかった・再送待ちは 2 の演出をしない (見出しの紙飛行機が戻るだけ)
enum FlightPhase: Equatable {
    case idle
    case sending(since: Date)
    /// 飛び立った紙飛行機と軌跡が消えたあと、通信の結果を待っているあいだ。何も描かない (描画を止めて電池を使わない)。
    case waiting
    case sent(at: Date)

    /// 飛び立って画面の外へ出るまで。送信がこれより早く終わっても、飛び去ってから結果を出す。
    static let launch: TimeInterval = 0.7
    /// 飛び立った紙飛行機の軌跡まで消えきるまで (軌跡は 16 粒 × 0.03 秒遅れ)。
    static let launchSettled: TimeInterval = launch + 0.5
    /// 右下から左上へ横切る長さ。
    static let cross: TimeInterval = 1.25

    /// 結果の演出。送れなかった・再送待ちは演出なし (nil)。
    static func result(for status: MessageStatus, at date: Date = .now) -> FlightPhase? {
        if case .sent = status { .sent(at: date) } else { nil }
    }

    /// 結果の演出の長さ。
    var duration: TimeInterval {
        switch self {
        case .idle, .sending, .waiting: 0
        case .sent: Self.cross
        }
    }

    /// 舞台に紙飛行機を描いているか (飛び立つところ・成功して横切るところ)。
    var isFlying: Bool { self != .idle && self != .waiting }
}

/// 送信と演出の順番をそろえる。iPhone・時計・デバッグの「演出だけ見る」で共有する。
/// `onResult` は結果が出た時点 (横切る演出の始まり) で呼ぶ。
@MainActor
func playFlight(
    set: @escaping @MainActor (FlightPhase) -> Void,
    current: @escaping @MainActor () -> FlightPhase,
    onResult: (MessageStatus) -> Void,
    work: () async -> MessageStatus
) async {
    let start = Date.now
    let sending = FlightPhase.sending(since: start)
    set(sending)
    // 通信が長引いても、飛び立つ演出が消えたら描画を止める
    let settle = Task { @MainActor in
        try? await Task.sleep(for: .seconds(FlightPhase.launchSettled))
        if !Task.isCancelled, current() == sending { set(.waiting) }
    }
    let status = await work()
    settle.cancel()
    // 飛び立った紙飛行機が画面から出てから結果を出す
    let remaining = FlightPhase.launch - Date.now.timeIntervalSince(start)
    if remaining > 0 { try? await Task.sleep(for: .seconds(remaining)) }
    onResult(status)
    guard let phase = FlightPhase.result(for: status) else {
        set(.idle)
        return
    }
    set(phase)
    try? await Task.sleep(for: .seconds(phase.duration))
    // その間に次の送信が始まっていたら触らない
    if current() == phase { set(.idle) }
}

#if DEBUG
/// デバッグ用: 送らずに演出だけ見るときの結果。
enum FlightDemo: String, CaseIterable, Identifiable {
    case sent = "送れた"
    case failed = "失敗"
    case pending = "再送待ち"

    var id: String { rawValue }

    var status: MessageStatus {
        switch self {
        case .sent: .sent(statusCode: 200)
        case .failed: .failed(reason: "演出の確認 (送っていません)")
        case .pending: .pending(attempts: 1, lastError: "演出の確認 (送っていません)")
        }
    }

    /// 通信の待ちに見立てる時間。
    func work() async -> MessageStatus {
        try? await Task.sleep(for: .seconds(0.5))
        return status
    }
}
#endif

/// 紙飛行機を飛ばす舞台。画面全体に重ねて使う (タップは下へ通す)。
struct FlightStage: View {
    var phase: FlightPhase
    /// 横切る / 落ちる紙飛行機の幅。
    var planeSize: CGFloat
    /// 飛び立つ紙飛行機がいる場所 (global 座標)。iPhone は見出しの紙飛行機、時計は送るボタン。
    var launchFrame: CGRect
    /// 飛び立つ紙飛行機の幅。
    var launchWidth: CGFloat
    /// 時計: 送るボタンの中から現れる (はじめは見えない)。iPhone: 見出しの絵と入れ替わる (はじめから見える)。
    var launchFadesIn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 位置は画面のポイント。`point` は機体の中心線の中点、`angle` は中心線の向き。
    private struct Pose {
        var point: CGPoint
        var angle: Double
        var opacity: Double
        var width: Double
        /// 左向きに飛ぶときは絵を左右反転する (回しすぎて裏返ったように見えないように)。
        var mirrored = false
    }

    var body: some View {
        if !phase.isFlying {
            Color.clear.allowsHitTesting(false)
        } else {
            GeometryReader { geo in
                let stage = geo.frame(in: .global)
                let launch = launchFrame.offsetBy(dx: -stage.minX, dy: -stage.minY)
                TimelineView(.animation) { timeline in
                    let now = timeline.date
                    ZStack {
                        if !reduceMotion {
                            trail(now: now, size: geo.size, launch: launch)
                        }
                        if let pose = pose(at: now, size: geo.size, launch: launch) {
                            PaperPlane()
                                .frame(width: pose.width)
                                .scaleEffect(x: pose.mirrored ? -1 : 1, y: 1)
                                .rotationEffect(.radians(pose.angle - Self.heading(mirrored: pose.mirrored)))
                                .shadow(color: Cosmos.violet.opacity(0.8), radius: pose.width * 0.15)
                                .opacity(pose.opacity)
                                .position(frameCenter(of: pose))
                        }
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    /// 絵のままの中心線の向き。反転すると左右が入れ替わる。
    private static func heading(mirrored: Bool) -> Double {
        mirrored ? atan2(sin(PaperPlane.heading), -cos(PaperPlane.heading)) : PaperPlane.heading
    }

    /// 通ってきた位置に、消えていく光の粒を置く。粒は機体の中心線の後端から出す。
    private func trail(now: Date, size: CGSize, launch: CGRect) -> some View {
        Canvas { ctx, _ in
            for k in 1...16 {
                let past = now.addingTimeInterval(-Double(k) * 0.03)
                guard let pose = pose(at: past, size: size, launch: launch), pose.opacity > 0.05 else { continue }
                let fade = (1 - Double(k) / 17) * pose.opacity
                let r = pose.width * 0.06 * (1 - Double(k) / 20)
                let c = tailPoint(of: pose)
                let color = k % 3 == 0 ? Cosmos.star : Cosmos.lavender
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                         with: .color(color.opacity(fade)))
            }
        }
    }

    /// 機体の中心線の中点を `pose.point` に置いたときの、絵 (箱) の中心。
    private func frameCenter(of pose: Pose) -> CGPoint {
        let k = pose.width / 700
        let rot = pose.angle - Self.heading(mirrored: pose.mirrored)
        var m = PaperPlane.keelMidFromCenter
        if pose.mirrored { m.x = -m.x }
        let mx = (m.x * cos(rot) - m.y * sin(rot)) * k, my = (m.x * sin(rot) + m.y * cos(rot)) * k
        return CGPoint(x: pose.point.x - mx, y: pose.point.y - my)
    }

    /// 機体の中心線の後端 (軌跡の出どころ)。
    private func tailPoint(of pose: Pose) -> CGPoint {
        let half = PaperPlane.keelLength / 2 * pose.width / 700
        return CGPoint(x: pose.point.x - cos(pose.angle) * half, y: pose.point.y - sin(pose.angle) * half)
    }

    /// 飛び立つ紙飛行機の、はじめの中心線の中点 (置かれている絵とぴったり重ねる)。
    private func launchStart(_ launch: CGRect) -> CGPoint {
        let k = launchWidth / 700
        let m = PaperPlane.keelMidFromCenter
        return CGPoint(x: launch.midX + m.x * k, y: launch.midY + m.y * k)
    }

    private func pose(at date: Date, size: CGSize, launch: CGRect) -> Pose? {
        let w = size.width, h = size.height
        switch phase {
        case .idle, .waiting:
            return nil

        case .sending(let since):
            let t = date.timeIntervalSince(since)
            guard t >= 0 else { return nil }
            let from = launchStart(launch)
            if reduceMotion {
                // 動かさず、その場で消えるだけ
                guard t < 0.4 else { return nil }
                return Pose(point: from, angle: PaperPlane.heading, opacity: 1 - t / 0.4, width: launchWidth)
            }
            guard t < FlightPhase.launch else { return nil }
            let p = easeIn(t / FlightPhase.launch)
            // はじめは絵のままの向き (右上) に出て、右へ抜ける
            let to = CGPoint(x: w + launchWidth * 1.5, y: from.y - h * 0.06)
            let reach = (to.x - from.x) * 0.4
            let control = CGPoint(x: from.x + cos(PaperPlane.heading) * reach, y: from.y + sin(PaperPlane.heading) * reach)
            let d = bezierTangent(from, control, to, max(p, 0.001))
            let opacity = launchFadesIn ? min(1, t / 0.15) : 1
            return Pose(point: bezier(from, control, to, p), angle: atan2(d.y, d.x), opacity: opacity,
                        width: launchWidth * (1 + 0.2 * p))

        case .sent(let at):
            let t = date.timeIntervalSince(at)
            guard t >= 0, t < FlightPhase.cross, !reduceMotion else { return nil }
            let p = easeInOut(t / FlightPhase.cross) * 0.6 + (t / FlightPhase.cross) * 0.4
            // 右下の外から、ゆるく弧を描いて左上の外へ
            let from = CGPoint(x: w + planeSize, y: h * 0.9)
            let control = CGPoint(x: w * 0.42, y: h * 0.66)
            let to = CGPoint(x: -planeSize, y: h * 0.1)
            let d = bezierTangent(from, control, to, p)
            return Pose(point: bezier(from, control, to, p), angle: atan2(d.y, d.x), opacity: 1,
                        width: planeSize, mirrored: true)
        }
    }
}

// MARK: - 補間

private func easeIn(_ x: Double) -> Double { pow(min(max(x, 0), 1), 2.2) }
private func easeInOut(_ x: Double) -> Double {
    let x = min(max(x, 0), 1)
    return x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
}

private func bezier(_ a: CGPoint, _ c: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint {
    let u = 1 - t
    return CGPoint(x: u * u * a.x + 2 * u * t * c.x + t * t * b.x,
                   y: u * u * a.y + 2 * u * t * c.y + t * t * b.y)
}

private func bezierTangent(_ a: CGPoint, _ c: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint {
    CGPoint(x: 2 * (1 - t) * (c.x - a.x) + 2 * t * (b.x - c.x),
            y: 2 * (1 - t) * (c.y - a.y) + 2 * t * (b.y - c.y))
}

// MARK: - 部品

extension View {
    /// List / Form の地を消して夜空を敷く。
    func cosmicListBackground() -> some View {
        scrollContentBackground(.hidden)
            .background { CosmicBackground() }
    }

    /// 星空の上に置く、半透明のカード。
    func cosmicCard(cornerRadius: CGFloat = 20) -> some View {
        background(Cosmos.card, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).strokeBorder(Cosmos.cardStroke))
    }
}

/// 紫に光る、主ボタンの見た目。
struct GlowButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .frame(minHeight: 50)
            .frame(maxWidth: .infinity)
            .background(Cosmos.glow, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.25)))
            .shadow(color: Cosmos.violet.opacity(isEnabled ? 0.7 : 0), radius: configuration.isPressed ? 6 : 14)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? 1 : 0.45)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}
