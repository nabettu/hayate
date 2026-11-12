import SwiftUI
import WatchHookCore

struct DestinationListView: View {
    @State private var store = ConfigStore.shared
    @State private var editing: Destination?

    var body: some View {
        NavigationStack {
            List {
                // お試しの状態・エラーは送り先のカードと別の区切りにする (同じ区切りだと 1 枚のカードにくっつく)
                Section {
                    AccessBanner()
                    ForEach([store.saveError, store.syncError].compactMap { $0 }, id: \.self) { message in
                        Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                    }
                }
                .listRowBackground(Cosmos.card)
                if store.config.destinations.isEmpty {
                    ContentUnavailableView(
                        "送り先がありません",
                        systemImage: "scope",
                        description: Text("右上の + から、話した内容を送る webhook を登録してください。")
                    )
                    .listRowBackground(Color.clear)
                }
                ForEach(store.config.destinations) { d in
                    Button { editing = d } label: {
                        HStack(spacing: 12) {
                            KindBadge(kind: d.kind)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(d.displayName).font(.headline)
                                // URL のパスには秘密が入ることがある (Slack の webhook など) ので一覧には出さない
                                Text(d.url.isEmpty ? String(localized: "\(d.kind.label) · URL 未設定") : d.kind.label)
                                    .font(.caption).foregroundStyle(Cosmos.lavender.opacity(0.7)).lineLimit(1)
                            }
                            Spacer()
                            if store.config.defaultDestination?.id == d.id {
                                Image(systemName: "sparkle")
                                    .foregroundStyle(Cosmos.star)
                                    .shadow(color: Cosmos.star.opacity(0.8), radius: 6)
                                    .accessibilityLabel("既定")
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                    .listRowBackground(Cosmos.card)
                    .swipeActions(edge: .leading) {
                        Button("既定にする") { store.setDefault(d.id) }.tint(Cosmos.violet)
                    }
                }
                .onDelete { offsets in
                    // 消すたびに配列が縮むので、先に ID を確定させる
                    let ids = offsets.map { store.config.destinations[$0].id }
                    for id in ids { store.delete(id) }
                }
            }
            .navigationTitle("送り先")
            .cosmicListBackground()
            .toolbar {
                Menu {
                    Button("Webhook (自由に設定)") { editing = .preset(.custom) }
                    Button("Slack") { editing = .preset(.slack) }
                    Button("Discord") { editing = .preset(.discord) }
                } label: {
                    Label("追加", systemImage: "plus")
                }
            }
            .sheet(item: $editing) { d in
                DestinationEditView(destination: d) { store.upsert($0) }
            }
        }
    }
}

/// 送り先の種類を表す丸いバッジ。
private struct KindBadge: View {
    let kind: DestinationKind

    var body: some View {
        Image(systemName: symbol)
            .font(.subheadline.bold())
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(Cosmos.glow, in: Circle())
            .shadow(color: Cosmos.violet.opacity(0.6), radius: 6)
            .accessibilityHidden(true)
    }

    private var symbol: String {
        switch kind {
        case .slack: "number"
        case .discord: "bubble.left.and.bubble.right.fill"
        case .custom: "curlybraces"
        }
    }
}
