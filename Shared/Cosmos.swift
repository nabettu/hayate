import SwiftUI
import WatchHookCore

/// アプリアイコン (星空を飛ぶ紙飛行機) に合わせた色と部品。iPhone と Apple Watch で共有する。
enum Cosmos {
    /// 背景のグラデーション (アイコンの左上 → 右下)。
    static let night = Color(red: 0x0C / 255, green: 0x10 / 255, blue: 0x24 / 255)
    static let deep = Color(red: 0x1C / 255, green: 0x12 / 255, blue: 0x44 / 255)
    static let nebula = Color(red: 0x2E / 255, green: 0x11 / 255, blue: 0x62 / 255)
    /// 紙飛行機の折り目。
    static let violet = Color(red: 0x8B / 255, green: 0x5C / 255, blue: 0xF6 / 255)
    /// 紙飛行機の下の翼。アプリ全体のアクセント色。
    static let lavender = Color(red: 0xC4 / 255, green: 0xB5 / 255, blue: 0xFD / 255)
    /// 左上の 4 つ角の星。
    static let star = Color(red: 0xFD / 255, green: 0xE6 / 255, blue: 0x8A / 255)
    /// 星空の上に置くカードの地。
    /// 星が文字に重ならないよう、ほぼ不透明にする (夜空より少し明るい紫)。
    static let card = Color(red: 0x22 / 255, green: 0x1B / 255, blue: 0x48 / 255).opacity(0.96)
    static let cardStroke = Color.white.opacity(0.12)

    static var background: LinearGradient { LinearGradient(colors: [night, deep, nebula], startPoint: .topLeading, endPoint: .bottomTrailing) }
    static var glow: LinearGradient { LinearGradient(colors: [violet, lavender], startPoint: .bottomLeading, endPoint: .topTrailing) }
}

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

/// 同じ星空を毎回描くための決まった乱数 (SplitMix64)。
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    /// 0..<1
    mutating func next() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return Double(z >> 11) / Double(1 << 53)
    }
}

/// アイコン左上の、4 つ角が内側に反った星。
struct SparkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let top = CGPoint(x: rect.midX, y: rect.minY), right = CGPoint(x: rect.maxX, y: rect.midY)
        let bottom = CGPoint(x: rect.midX, y: rect.maxY), left = CGPoint(x: rect.minX, y: rect.midY)
        var p = Path()
        p.move(to: top)
        p.addQuadCurve(to: right, control: c)
        p.addQuadCurve(to: bottom, control: c)
        p.addQuadCurve(to: left, control: c)
        p.addQuadCurve(to: top, control: c)
        p.closeSubpath()
        return p
    }
}

// MARK: - 紙飛行機

/// アイコンと同じ形の紙飛行機。機首は右上 (約 -49°) を向く。
struct PaperPlane: View {
    /// 機体の中心線 (竜骨: 機首 → 紫の折り目の後端) の端。座標は下の 700×620 の箱。
    static let nose = CGPoint(x: 690, y: 8)
    static let tail = CGPoint(x: 236, y: 532)
    /// 中心線の向き (画面座標での角度、ラジアン)。回転させるときはこれとの差を回す。
    static let heading = atan2(nose.y - tail.y, nose.x - tail.x)
    static let keelLength = hypot(nose.x - tail.x, nose.y - tail.y)
    /// 箱の中心から見た、中心線の中点の位置。
    static let keelMidFromCenter = CGPoint(x: (nose.x + tail.x) / 2 - 350, y: (nose.y + tail.y) / 2 - 310)

    var body: some View {
        ZStack {
            PlanePart(points: [(690, 8), (318, 440), (400, 615)]).fill(Cosmos.lavender)
            PlanePart(points: [(690, 8), (300, 418), (236, 532), (330, 432)]).fill(Cosmos.violet)
            PlanePart(points: [(690, 8), (5, 278), (310, 415)]).fill(.white)
        }
        .aspectRatio(700.0 / 620.0, contentMode: .fit)
        .accessibilityHidden(true)
    }

    /// アイコン (1024 四方) の機体部分 700×620 の座標で書いた多角形。
    private struct PlanePart: Shape {
        var points: [(Double, Double)]

        func path(in rect: CGRect) -> Path {
            let sx = rect.width / 700, sy = rect.height / 620
            var p = Path()
            for (i, (x, y)) in points.enumerated() {
                let pt = CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
            return p
        }
    }
}

// MARK: - 送信の演出

/// 送信の演出の段階。
/// 1. 送り始め (`sending`): 画面の紙飛行機 (iPhone は見出しの絵、時計は話すボタン) から飛び立ち、右へ飛び去る
/// 2. 送れた (`sent`): 別の紙飛行機が画面の右下から左上へ横切る
///    送れなかった (`failed`): 右上から戻ってきて、くるくる落ちる
///    再送待ちは 2 の演出をしない (見出しの紙飛行機が戻るだけ)
enum FlightPhase: Equatable {
    case idle
    case sending(since: Date)
    case sent(at: Date)
    case failed(at: Date)

    /// 飛び立って画面の外へ出るまで。送信がこれより早く終わっても、飛び去ってから結果を出す。
    static let launch: TimeInterval = 0.7
    /// 右下から左上へ横切る長さ。
    static let cross: TimeInterval = 1.25
    /// 落ちていく長さ。
    static let fall: TimeInterval = 1.5

    /// 結果の演出。再送待ちは演出なし (nil)。
    static func result(for status: MessageStatus, at date: Date = .now) -> FlightPhase? {
        switch status {
        case .sent: .sent(at: date)
        case .failed: .failed(at: date)
        case .pending: nil
        }
    }

    /// 結果の演出の長さ。
    var duration: TimeInterval {
        switch self {
        case .idle, .sending: 0
        case .sent: Self.cross
        case .failed: Self.fall
        }
    }
}

/// 送信と演出の順番をそろえる。iPhone・時計・デバッグの「演出だけ見る」で共有する。
/// `onResult` は結果が出た時点 (横切る演出の始まり) で呼ぶ。
@MainActor
func playFlight(
    set: (FlightPhase) -> Void,
    current: () -> FlightPhase,
    onResult: (MessageStatus) -> Void,
    work: () async -> MessageStatus
) async {
    let start = Date.now
    set(.sending(since: start))
    let status = await work()
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
    /// 飛び立つ紙飛行機がいる場所 (global 座標)。iPhone は見出しの紙飛行機、時計は話すボタン。
    var launchFrame: CGRect
    /// 飛び立つ紙飛行機の幅。
    var launchWidth: CGFloat
    /// 時計: 話すボタンの中から現れる (はじめは見えない)。iPhone: 見出しの絵と入れ替わる (はじめから見える)。
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
        if phase == .idle {
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
        case .idle:
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

        case .failed(let at):
            let t = date.timeIntervalSince(at)
            guard t >= 0, t < FlightPhase.fall, !reduceMotion else { return nil }
            let p = t / FlightPhase.fall
            // 右上 (飛び去った方) から戻ってきて、ゆらゆら落ちる
            let from = CGPoint(x: w + planeSize * 0.6, y: h * 0.16)
            let control = CGPoint(x: w * 0.6, y: h * 0.14)
            let to = CGPoint(x: w * 0.5, y: h + planeSize)
            let q = easeIn(p)
            let d = bezierTangent(from, control, to, max(q, 0.001))
            let wobble = sin(p * .pi * 4) * 0.5 * p
            return Pose(point: bezier(from, control, to, q), angle: atan2(d.y, d.x) + wobble,
                        opacity: p < 0.6 ? 1 : 1 - (p - 0.6) / 0.4, width: planeSize * 0.8, mirrored: true)
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
