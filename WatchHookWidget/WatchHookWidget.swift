import SwiftUI
import WidgetKit

/// 文字盤のコンプリケーション / スマートスタックに置く、Hayate を開くだけのウィジェット。
/// 表示する中身は固定 (送り先の名前などは Keychain にあり、ウィジェットからは読まない)。
@main
struct WatchHookWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WatchHookLauncher", provider: LauncherProvider()) { _ in
            LauncherView()
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Hayate")
        .description("タップして Hayate を開き、話して送ります。")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}

struct LauncherEntry: TimelineEntry {
    let date: Date
}

struct LauncherProvider: TimelineProvider {
    func placeholder(in context: Context) -> LauncherEntry { LauncherEntry(date: .now) }

    func getSnapshot(in context: Context, completion: @escaping (LauncherEntry) -> Void) {
        completion(LauncherEntry(date: .now))
    }

    /// 中身が変わらないので 1 件だけ置き、更新しない。
    func getTimeline(in context: Context, completion: @escaping (Timeline<LauncherEntry>) -> Void) {
        completion(Timeline(entries: [LauncherEntry(date: .now)], policy: .never))
    }
}

struct LauncherView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCorner:
            Image(systemName: "paperplane.fill")
                .font(.title3)
                .widgetLabel("話す")
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "paperplane.fill")
                    .font(.title2)
                    .widgetAccentable()
                VStack(alignment: .leading, spacing: 0) {
                    Text("Hayate").font(.headline).widgetAccentable()
                    Text("タップして話す").font(.caption)
                }
                Spacer(minLength: 0)
            }
        case .accessoryInline:
            Label("Hayate で話す", systemImage: "paperplane.fill")
        default:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "paperplane.fill")
                    .font(.title3)
                    .widgetAccentable()
            }
        }
    }
}

#Preview(as: .accessoryRectangular) {
    WatchHookWidget()
} timeline: {
    LauncherEntry(date: .now)
}
