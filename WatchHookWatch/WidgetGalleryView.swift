#if DEBUG
import SwiftUI
import WidgetKit

/// デバッグ用: ウィジェットの見た目を Watch アプリの中に並べる見本。
/// シミュレータでは文字盤にウィジェットを置く操作をコマンドから出来ないので、見た目の確認はこれで撮る。
/// 起動引数 `-widgetGallery 1` (丸・角・インライン) / `2` (長方形) / `3` (長方形・色合わせ) で開く。
/// 大きさは 46mm の文字盤に近い値で、WidgetKit が実際に描いたものではない (角の弧の文字は下に横書きで出す)。
struct WidgetGalleryView: View {
    var page: Int

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch page {
            case 2: rectangles(fullColor: true)
            case 3: rectangles(fullColor: false)
            default: smallOnes
            }
        }
    }

    private var smallOnes: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                sample("丸") { OrbitBadge(fullColor: true).frame(width: 50, height: 50) }
                sample("丸・色合わせ") { OrbitBadge(fullColor: false).frame(width: 50, height: 50).foregroundStyle(.orange) }
            }
            HStack(spacing: 14) {
                sample("角 (Hayate)") { CornerLauncher(fullColor: true).frame(width: 34, height: 34) }
                sample("角・色合わせ") { CornerLauncher(fullColor: false).frame(width: 34, height: 34) }
            }
            Label("Hayate で送る", systemImage: "paperplane.fill").font(.footnote)
        }
    }

    private func rectangles(fullColor: Bool) -> some View {
        VStack(spacing: 6) {
            if fullColor {
                Text("スマートスタック").font(.caption2).foregroundStyle(.secondary)
                RectangularLauncher(fullColor: true)
                    .padding(.horizontal, 10)
                    .frame(width: 190, height: 80)
                    .background(WidgetCosmicBackground())
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            Text(fullColor ? "文字盤" : "文字盤・色合わせ").font(.caption2).foregroundStyle(.secondary)
            RectangularLauncher(fullColor: fullColor).frame(width: 180, height: 64)
        }
        .padding(.top, 24)
    }

    private func sample(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 3) {
            content()
            Text(title).font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }
}

#Preview { WidgetGalleryView(page: 1) }
#Preview { WidgetGalleryView(page: 2) }
#Preview { WidgetGalleryView(page: 3) }
#endif
