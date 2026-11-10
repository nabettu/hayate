import SwiftUI

// 色・紙飛行機・星の形。iPhone・Apple Watch・ウィジェットで共有する。
// ウィジェットの拡張にも入れるので、WatchHookCore に頼らない (import しない)。

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
    /// 白の濃淡だけで描く。文字盤が色を付ける (色合いを揃える) 表示モード用。
    var monochrome = false

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
            PlanePart(points: [(690, 8), (318, 440), (400, 615)]).fill(monochrome ? .white.opacity(0.7) : Cosmos.lavender)
            PlanePart(points: [(690, 8), (300, 418), (236, 532), (330, 432)]).fill(monochrome ? .white.opacity(0.45) : Cosmos.violet)
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
