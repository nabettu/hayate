import SwiftUI
import WidgetKit

/// 文字盤のコンプリケーション / スマートスタックに置く、Hayate を開くだけのウィジェット。
/// 表示する中身は固定 (送り先の名前などは Keychain にあり、ウィジェットからは読まない)。
/// 見た目は LauncherViews.swift。背景の夜空はスマートスタックでだけ見え、文字盤では OS が外す。
@main
struct WatchHookWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WatchHookLauncher", provider: LauncherProvider()) { _ in
            LauncherView()
                .containerBackground(for: .widget) { WidgetCosmicBackground() }
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

#Preview(as: .accessoryRectangular) {
    WatchHookWidget()
} timeline: {
    LauncherEntry(date: .now)
}

#Preview(as: .accessoryCircular) {
    WatchHookWidget()
} timeline: {
    LauncherEntry(date: .now)
}
