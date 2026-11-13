import SwiftUI
import WatchHookCore

/// 「連携」タブ: リマインダー・Markdown と、webhook の送り先。入力したメモは、オンにしたものすべてへ送る。
struct DestinationListView: View {
    @State private var store = ConfigStore.shared
    @State private var integrations = IntegrationStore.shared
    @State private var editing: Destination?

    var body: some View {
        NavigationStack {
            List {
                // エラーは送り先のカードと別の区切りにする (同じ区切りだと 1 枚のカードにくっつく)
                let errors = [store.saveError, store.syncError].compactMap { $0 }
                if !errors.isEmpty {
                    Section {
                        ForEach(errors, id: \.self) { message in
                            Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                        }
                    }
                    .listRowBackground(Cosmos.card)
                }
                Section {
                    NavigationLink { ReminderSettingsView() } label: {
                        IntegrationRow(symbol: "checklist", title: String(localized: "リマインダー"),
                                       detail: reminderDetail, isOn: integrations.settings.reminder.isEnabled)
                    }
                    NavigationLink { MarkdownSettingsView() } label: {
                        IntegrationRow(symbol: "doc.text", title: String(localized: "Markdown ファイル"),
                                       detail: markdownDetail, isOn: integrations.settings.markdown.isEnabled)
                    }
                } header: {
                    Text("iPhone に保存")
                }
                .listRowBackground(Cosmos.card)

                Section {
                    if store.config.destinations.isEmpty {
                        Text("右上の + から、Slack・Discord などの送り先を登録できます。")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    ForEach(store.config.destinations) { d in
                        HStack(spacing: 12) {
                            Button { editing = d } label: {
                                HStack(spacing: 12) {
                                    KindBadge(kind: d.kind)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(d.displayName).font(.headline)
                                        // URL のパスには秘密が入ることがある (Slack の webhook など) ので一覧には出さない
                                        Text(d.url.isEmpty ? String(localized: "\(d.kind.label) · URL 未設定") : d.kind.label)
                                            .font(.caption).foregroundStyle(Cosmos.lavender.opacity(0.7)).lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Toggle(isOn: Binding(get: { d.isEnabled }, set: { store.setEnabled(d.id, $0) })) {
                                Text("送る")
                            }
                            .labelsHidden()
                            .accessibilityLabel(Text("「\(d.displayName)」へ送る"))
                        }
                        .listRowBackground(Cosmos.card)
                    }
                    .onDelete { offsets in
                        // 消すたびに配列が縮むので、先に ID を確定させる
                        let ids = offsets.map { store.config.destinations[$0].id }
                        for id in ids { store.delete(id) }
                    }
                    .onMove { store.move(from: $0, to: $1) }
                } header: {
                    Text("送り先 (webhook)")
                } footer: {
                    Text("スイッチをオンにした送り先すべてへ、入力したメモを送ります。Apple Watch で入力したものは時計から直接送ります。")
                }
            }
            .navigationTitle("連携")
            .cosmicListBackground()
            .toolbar {
                Menu {
                    ForEach(DestinationPreset.allCases) { preset in
                        Button(preset.title) { editing = preset.make() }
                    }
                } label: {
                    Label("追加", systemImage: "plus")
                }
            }
            .sheet(item: $editing) { d in
                DestinationEditView(destination: d) { store.upsert($0) }
            }
        }
    }

    private var reminderDetail: String {
        let r = integrations.settings.reminder
        guard r.isEnabled else { return String(localized: "オフ") }
        guard let list = r.listName else { return String(localized: "リストを選んでください") }
        return String(localized: "「\(r.keywords.first ?? "")」で始めると「\(list)」に追加")
    }

    private var markdownDetail: String {
        let m = integrations.settings.markdown
        guard m.isEnabled else { return String(localized: "オフ") }
        guard let folder = m.folderName else { return String(localized: "フォルダを選んでください") }
        return String(localized: "「\(folder)」に日付ごとに追記")
    }
}

private struct IntegrationRow: View {
    let symbol: String
    let title: String
    let detail: String
    let isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Cosmos.glow, in: Circle())
                .opacity(isOn ? 1 : 0.45)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(Cosmos.lavender.opacity(0.7)).lineLimit(2)
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
