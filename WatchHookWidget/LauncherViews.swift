import SwiftUI
import WidgetKit

// ウィジェットの見た目 (星空を飛ぶ紙飛行機)。
// Watch アプリのデバッグ用の見本 (WidgetGalleryView) からも使うので、@main のファイルと分けている。

/// WidgetKit の環境値を読んで、見た目に渡す。
struct LauncherView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        LauncherContent(family: family, fullColor: renderingMode == .fullColor)
    }
}

/// ファミリーと表示モードごとの中身。
/// `fullColor` が false のとき (文字盤が色合いを揃えるモード) は、白の濃淡で描き、
/// 強調したい部分 (紙飛行機・アプリ名) にだけ `widgetAccentable` を付けて文字盤の色を乗せる。
struct LauncherContent: View {
    var family: WidgetFamily
    var fullColor: Bool

    var body: some View {
        switch family {
        case .accessoryCorner:
            CornerLauncher(fullColor: fullColor)
                .widgetLabel {
                    Text("Hayate").foregroundStyle(fullColor ? Cosmos.lavender : .white)
                }
        case .accessoryRectangular:
            RectangularLauncher(fullColor: fullColor)
        case .accessoryInline:
            // インラインは文字と SF Symbols しか出ない
            Label("Hayate で話す", systemImage: "paperplane.fill")
        default:
            OrbitBadge(fullColor: fullColor)
        }
    }
}

// MARK: - 丸 (accessoryCircular と、長方形の左の印)

/// 夜空の円の中を、光の粒を引いて飛ぶ紙飛行機。左上にアイコンと同じ 4 つ角の星。
struct OrbitBadge: View {
    var fullColor: Bool

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                if fullColor {
                    Circle().fill(
                        RadialGradient(colors: [Cosmos.nebula, Cosmos.deep, Cosmos.night],
                                       center: UnitPoint(x: 0.68, y: 0.3), startRadius: 0, endRadius: s * 0.7)
                    )
                    WidgetStars(count: 9, seed: 7, sparkles: false)
                        .clipShape(Circle())
                } else {
                    AccessoryWidgetBackground().clipShape(Circle())
                }

                LaunchTrail(color: fullColor ? Cosmos.lavender : .white)

                PaperPlane(monochrome: !fullColor)
                    .frame(width: s * 0.54)
                    .shadow(color: fullColor ? Cosmos.violet.opacity(0.9) : .clear, radius: s * 0.06)
                    .position(x: s * 0.56, y: s * 0.44)
                    .widgetAccentable()

                SparkleShape()
                    .fill(fullColor ? Cosmos.star : .white)
                    .frame(width: s * 0.2, height: s * 0.2)
                    .position(x: s * 0.27, y: s * 0.27)
                    .widgetAccentable()

                if fullColor {
                    Circle()
                        .strokeBorder(
                            AngularGradient(colors: [Cosmos.lavender, Cosmos.violet.opacity(0.2), Cosmos.lavender],
                                            center: .center, angle: .degrees(-45)),
                            lineWidth: max(1, s * 0.03)
                        )
                }
            }
            .frame(width: s, height: s)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityLabel("Hayate")
    }
}

/// 左下から紙飛行機の後ろまで続く光の粒。円の大きさに合わせて描く。
private struct LaunchTrail: View {
    var color: Color

    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height)
            // 紙飛行機 (幅 0.54・中心 0.56, 0.44) の後端のすぐ後ろまで、ゆるい弧で
            let from = CGPoint(x: 0.12 * s, y: 0.84 * s)
            let control = CGPoint(x: 0.24 * s, y: 0.64 * s)
            let to = CGPoint(x: 0.44 * s, y: 0.62 * s)
            let n = 7
            for i in 0..<n {
                let t = Double(i) / Double(n - 1)
                let u = 1 - t
                let p = CGPoint(x: u * u * from.x + 2 * u * t * control.x + t * t * to.x,
                                y: u * u * from.y + 2 * u * t * control.y + t * t * to.y)
                let r = s * (0.012 + 0.022 * t)
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                         with: .color(color.opacity(0.25 + 0.6 * t)))
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 角 (accessoryCorner)

/// 文字盤の角は小さいので、光る紙飛行機と星だけ。名前は弧に沿った文字 (widgetLabel) で出す。
struct CornerLauncher: View {
    var fullColor: Bool

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                PaperPlane(monochrome: !fullColor)
                    .frame(width: s * 0.8)
                    .shadow(color: fullColor ? Cosmos.violet : .clear, radius: s * 0.08)
                    .widgetAccentable()
                SparkleShape()
                    .fill(fullColor ? Cosmos.star : .white)
                    .frame(width: s * 0.26, height: s * 0.26)
                    .position(x: s * 0.16, y: s * 0.16)
            }
            .frame(width: s, height: s)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityLabel("Hayate")
    }
}

// MARK: - 長方形 (accessoryRectangular。文字盤とスマートスタック)

struct RectangularLauncher: View {
    var fullColor: Bool

    var body: some View {
        HStack(spacing: 8) {
            OrbitBadge(fullColor: fullColor)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text("Hayate")
                        .font(.headline)
                        .foregroundStyle(fullColor ? AnyShapeStyle(Self.titleGradient) : AnyShapeStyle(.white))
                        .widgetAccentable()
                    SparkleShape()
                        .fill(fullColor ? Cosmos.star : .white.opacity(0.8))
                        .frame(width: 9, height: 9)
                }
                Text("タップして話す")
                    .font(.caption)
                    .foregroundStyle(fullColor ? Cosmos.lavender : .white.opacity(0.75))
                Text("声を星の向こうへ")
                    .font(.caption2)
                    .foregroundStyle(fullColor ? Cosmos.lavender.opacity(0.6) : .white.opacity(0.5))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
    }

    private static let titleGradient = LinearGradient(colors: [.white, Cosmos.lavender], startPoint: .leading, endPoint: .trailing)
}

// MARK: - 背景 (スマートスタックでだけ見える。文字盤では OS が外す)

/// 夜空のグラデーション + 右上の星雲の光 + 動かない星。
struct WidgetCosmicBackground: View {
    var body: some View {
        ZStack {
            Cosmos.background
            RadialGradient(colors: [Cosmos.violet.opacity(0.45), .clear],
                           center: UnitPoint(x: 0.9, y: 0.05), startRadius: 0, endRadius: 120)
            WidgetStars(count: 26, seed: 20261110, sparkles: false)
            // 4 つ角の星は文字に重ならない右上にだけ置く
            GeometryReader { geo in
                SparkleShape()
                    .fill(Cosmos.star.opacity(0.9))
                    .frame(width: 10, height: 10)
                    .position(x: geo.size.width - 14, y: 12)
            }
        }
    }
}

/// ウィジェット用の、またたかない星空 (ウィジェットは動かせない)。決まった乱数で毎回同じ並びにする。
struct WidgetStars: View {
    var count: Int
    var seed: UInt64
    /// 数個をアイコンと同じ 4 つ角の星にする。
    var sparkles: Bool

    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRandom(seed: seed)
            for i in 0..<count {
                let p = CGPoint(x: rng.next() * size.width, y: rng.next() * size.height)
                let radius = 0.4 + rng.next() * 0.9
                let alpha = 0.35 + rng.next() * 0.6
                if sparkles && i % 9 == 4 {
                    let r = 3 + radius * 2
                    ctx.fill(SparkleShape().path(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                             with: .color(Cosmos.star.opacity(alpha)))
                } else {
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)),
                             with: .color(.white.opacity(alpha)))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
