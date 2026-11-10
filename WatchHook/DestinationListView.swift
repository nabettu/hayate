import SwiftUI
import WatchHookCore

struct DestinationListView: View {
    @State private var store = ConfigStore.shared
    @State private var editing: Destination?

    var body: some View {
        NavigationStack {
            List {
                ForEach([store.saveError, store.syncError].compactMap { $0 }, id: \.self) { message in
                    Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                }
                if store.config.destinations.isEmpty {
                    ContentUnavailableView(
                        "送り先がありません",
                        systemImage: "paperplane",
                        description: Text("右上の + から、話した内容を送る webhook を登録してください。")
                    )
                }
                ForEach(store.config.destinations) { d in
                    Button { editing = d } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(d.displayName).font(.headline)
                                // URL のパスには秘密が入ることがある (Slack の webhook など) ので一覧には出さない
                                Text(d.url.isEmpty ? "\(d.kind.label) · URL 未設定" : d.kind.label)
                                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            if store.config.defaultDestination?.id == d.id {
                                Label("既定", systemImage: "star.fill").labelStyle(.iconOnly).foregroundStyle(.yellow)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                    .swipeActions(edge: .leading) {
                        Button("既定にする") { store.setDefault(d.id) }.tint(.yellow)
                    }
                }
                .onDelete { offsets in
                    // 消すたびに配列が縮むので、先に ID を確定させる
                    let ids = offsets.map { store.config.destinations[$0].id }
                    for id in ids { store.delete(id) }
                }
            }
            .navigationTitle("送り先")
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
