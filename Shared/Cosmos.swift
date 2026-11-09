import SwiftUI

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
    static let card = Color.white.opacity(0.07)
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

/// アイコンと同じ形の紙飛行機。機首は右上 (約 -47°) を向く。
struct PaperPlane: View {
    /// 機首の向き (画面座標での角度、ラジアン)。回転させるときはこれとの差を回す。
    static let heading = atan2(-407.0, 380.0)

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

/// 送信中・送れた・送れなかったで、紙飛行機の飛び方を変える。
enum FlightPhase: Equatable {
    case idle
    /// 左下から飛んできて、まん中でふわふわ待つ。
    case sending(since: Date)
    /// 右上へ飛び去る。
    case sent(at: Date)
    /// 落ちていく。
    case failed(at: Date)
    /// 再送待ち: ゆっくり右下へ旋回して消える。
    case queued(at: Date)

    /// 飛んでくる動きが終わるまでの秒数。送信がこれより早く終わっても、飛んできてから飛び去らせる。
    static let arrival: TimeInterval = 0.75
    /// 結果の演出の長さ。
    static let exit: TimeInterval = 1.1
}

/// 紙飛行機を飛ばす舞台。上に重ねて使う (タップは下へ通す)。
struct FlightStage: View {
    var phase: FlightPhase
    var planeSize: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Pose {
        var point: CGPoint  // 0...1 の相対座標
        var angle: Double  // 進む向き (ラジアン)
        var opacity: Double
        var scale: Double
    }

    var body: some View {
        if phase == .idle {
            Color.clear.allowsHitTesting(false)
        } else {
            TimelineView(.animation) { timeline in
                let now = timeline.date
                GeometryReader { geo in
                    let size = geo.size
                    ZStack {
                        if !reduceMotion {
                            trail(now: now, size: size)
                            burst(now: now, size: size)
                        }
                        if let pose = pose(at: now) {
                            PaperPlane()
                                .frame(width: planeSize * pose.scale)
                                .rotationEffect(.radians(pose.angle - PaperPlane.heading))
                                .shadow(color: Cosmos.violet.opacity(0.8), radius: planeSize * 0.15)
                                .opacity(pose.opacity)
                                .position(x: pose.point.x * size.width, y: pose.point.y * size.height)
                        }
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    /// 通ってきた位置に、消えていく光の粒を置く。
    private func trail(now: Date, size: CGSize) -> some View {
        Canvas { ctx, _ in
            for k in 1...14 {
                let past = now.addingTimeInterval(-Double(k) * 0.035)
                guard let pose = pose(at: past), pose.opacity > 0.05 else { continue }
                let fade = (1 - Double(k) / 15) * pose.opacity
                let r = planeSize * 0.07 * (1 - Double(k) / 18)
                let c = CGPoint(x: pose.point.x * size.width, y: pose.point.y * size.height)
                let color = k % 3 == 0 ? Cosmos.star : Cosmos.lavender
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                         with: .color(color.opacity(fade)))
            }
        }
    }

    /// 送れたとき、飛び立った場所に星がはじける。
    @ViewBuilder private func burst(now: Date, size: CGSize) -> some View {
        if case .sent(let at) = phase {
            let p = min(max(now.timeIntervalSince(at) / 0.7, 0), 1)
            Canvas { ctx, _ in
                guard p < 1 else { return }
                let center = CGPoint(x: 0.5 * size.width, y: 0.5 * size.height)
                for i in 0..<8 {
                    let a = Double(i) / 8 * .pi * 2 + 0.3
                    let d = planeSize * (0.3 + 0.9 * easeOut(p))
                    let r = planeSize * 0.09 * (1 - p)
                    let pt = CGPoint(x: center.x + cos(a) * d, y: center.y + sin(a) * d)
                    ctx.fill(SparkleShape().path(in: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)),
                             with: .color(Cosmos.star.opacity(1 - p)))
                }
            }
        }
    }

    private func pose(at date: Date) -> Pose? {
        let center = CGPoint(x: 0.5, y: 0.5)
        switch phase {
        case .idle:
            return nil
        case .sending(let since):
            let t = date.timeIntervalSince(since)
            if t < 0 { return nil }
            if t < FlightPhase.arrival {
                // 左下の外から、少し弧を描いてまん中へ
                let p = easeOut(t / FlightPhase.arrival)
                let from = CGPoint(x: -0.25, y: 1.15), control = CGPoint(x: 0.1, y: 0.45)
                let pt = bezier(from, control, center, p)
                let d = bezierTangent(from, control, center, max(p, 0.02))
                return Pose(point: pt, angle: atan2(d.y, d.x), opacity: min(1, t / 0.15), scale: 0.7 + 0.3 * p)
            }
            return hover(at: t - FlightPhase.arrival)
        case .sent(let at):
            let t = max(0, date.timeIntervalSince(at))
            guard t < FlightPhase.exit else { return nil }
            let p = easeIn(t / FlightPhase.exit)
            let to = CGPoint(x: 1.35, y: -0.35)
            let pt = CGPoint(x: center.x + (to.x - center.x) * p, y: center.y + (to.y - center.y) * p)
            return Pose(point: pt, angle: PaperPlane.heading, opacity: 1 - max(0, p - 0.7) / 0.3, scale: 1 - 0.4 * p)
        case .queued(let at):
            let t = max(0, date.timeIntervalSince(at))
            guard t < FlightPhase.exit * 1.4 else { return nil }
            let p = easeInOut(t / (FlightPhase.exit * 1.4))
            let from = center, control = CGPoint(x: 0.95, y: 0.35), to = CGPoint(x: 1.3, y: 1.0)
            let d = bezierTangent(from, control, to, max(p, 0.02))
            return Pose(point: bezier(from, control, to, p), angle: atan2(d.y, d.x), opacity: 1 - p * 0.6, scale: 1 - 0.3 * p)
        case .failed(let at):
            let t = max(0, date.timeIntervalSince(at))
            guard t < FlightPhase.exit * 1.3 else { return nil }
            let p = t / (FlightPhase.exit * 1.3)
            // ゆらゆらしながら下へ落ちる
            let x = 0.5 + 0.08 * sin(p * .pi * 3)
            let y = 0.5 + 0.75 * easeIn(p)
            return Pose(point: CGPoint(x: x, y: y), angle: .pi / 2 + 0.6 * sin(p * .pi * 3),
                        opacity: 1 - p, scale: 1 - 0.2 * p)
        }
    }

    /// まん中でふわふわ漂う。
    private func hover(at t: TimeInterval) -> Pose {
        let bob = reduceMotion ? 0 : sin(t * 3.2) * 0.025
        return Pose(point: CGPoint(x: 0.5, y: 0.5 + bob), angle: PaperPlane.heading + sin(t * 3.2 + 1) * 0.08,
                    opacity: 1, scale: 1)
    }
}

// MARK: - 補間

private func easeOut(_ x: Double) -> Double { 1 - pow(1 - min(max(x, 0), 1), 3) }
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

/// 送信の演出の時間を合わせる。飛んでくる動きを見せきってから結果を出す。
@MainActor
func waitForArrival(since start: Date) async {
    let remaining = FlightPhase.arrival - Date.now.timeIntervalSince(start)
    if remaining > 0 { try? await Task.sleep(for: .seconds(remaining)) }
}
