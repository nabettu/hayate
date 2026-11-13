import EventKit
import SwiftUI
import WatchHookCore

/// リマインダーの連携: オン / オフ、アクセスの許可、追加するリスト、合図の言葉。
struct ReminderSettingsView: View {
    @State private var integrations = IntegrationStore.shared
    @State private var status = EKEventStore.authorizationStatus(for: .reminder)
    @State private var lists: [EKCalendar] = []
    @State private var newKeyword = ""
    @State private var requestError: String?
    @Environment(\.scenePhase) private var scenePhase
    private let eventStore = EKEventStore()

    private var settings: IntegrationSettings.Reminder { integrations.settings.reminder }

    var body: some View {
        Form {
            Group {
                Section {
                    Toggle("リマインダーに追加する", isOn: Binding(
                        get: { settings.isEnabled },
                        set: { on in
                            integrations.update { $0.reminder.isEnabled = on }
                            if on, status != .fullAccess { Task { await requestAccess() } }
                        }
                    ))
                } footer: {
                    Text("合図の言葉で始めたメモを、合図を除いてリマインダーに追加します。例: 「リマインダー、牛乳を買う」→「牛乳を買う」")
                }

                if settings.isEnabled {
                    Section("アクセス") {
                        switch status {
                        case .fullAccess:
                            Label("許可されています", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                        case .notDetermined:
                            Button("リマインダーへのアクセスを許可する") { Task { await requestAccess() } }
                        default:
                            Label("許可されていません", systemImage: "xmark.circle.fill").foregroundStyle(.red)
                            Text("設定 App →「Hayate」→「リマインダー」で「フルアクセス」を選んでください。")
                                .font(.footnote).foregroundStyle(.secondary)
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                Link("設定 App を開く", destination: url)
                            }
                        }
                        if let requestError {
                            Text(requestError).font(.footnote).foregroundStyle(.red)
                        }
                    }

                    if status == .fullAccess {
                        Section("追加するリスト") {
                            Picker("リスト", selection: Binding(
                                get: { settings.listID ?? "" },
                                set: { id in
                                    let name = lists.first { $0.calendarIdentifier == id }?.title
                                    integrations.update {
                                        $0.reminder.listID = id.isEmpty ? nil : id
                                        $0.reminder.listName = name
                                    }
                                }
                            )) {
                                Text("選んでください").tag("")
                                ForEach(lists, id: \.calendarIdentifier) { list in
                                    Text(list.title).tag(list.calendarIdentifier)
                                }
                            }
                        }
                    }

                    Section {
                        ForEach(settings.keywords, id: \.self) { keyword in
                            Text(keyword)
                        }
                        .onDelete { offsets in
                            integrations.update { $0.reminder.keywords.remove(atOffsets: offsets) }
                        }
                        HStack {
                            TextField("合図の言葉を足す", text: $newKeyword)
                                .onSubmit(addKeyword)
                            Button("追加", action: addKeyword)
                                .disabled(newKeyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        Button("既定に戻す") {
                            integrations.update {
                                $0.reminder.keywords = ReminderTrigger.defaultKeywords(preferredLanguages: Locale.preferredLanguages)
                            }
                        }
                    } header: {
                        Text("合図の言葉")
                    } footer: {
                        Text("メモの最初がどれかに当てはまると、リマインダーに追加します。大文字・小文字や全角・半角の違いは気にしません。合図だけで本文が無いときは、メモにだけ残します。")
                    }
                }
            }
            .listRowBackground(Cosmos.card)
        }
        .navigationTitle("リマインダー")
        .navigationBarTitleDisplayMode(.inline)
        .cosmicListBackground()
        .task { reloadLists() }
        // 設定 App で許可して戻ってきたとき
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            eventStore.reset()  // 許可の前に作ったストアは、リストを読み直させる
            reloadLists()
        }
    }

    private func addKeyword() {
        let keyword = newKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return }
        integrations.update { s in
            if !s.reminder.keywords.contains(keyword) { s.reminder.keywords.append(keyword) }
        }
        newKeyword = ""
    }

    private func requestAccess() async {
        requestError = nil
        do {
            _ = try await eventStore.requestFullAccessToReminders()
        } catch {
            requestError = error.localizedDescription
        }
        status = EKEventStore.authorizationStatus(for: .reminder)
        reloadLists()
    }

    private func reloadLists() {
        status = EKEventStore.authorizationStatus(for: .reminder)
        guard status == .fullAccess else { return }
        lists = eventStore.calendars(for: .reminder).sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        // 何も選んでいなければ、既定のリストを選んでおく
        if settings.listID == nil, let list = eventStore.defaultCalendarForNewReminders() {
            integrations.update {
                $0.reminder.listID = list.calendarIdentifier
                $0.reminder.listName = list.title
            }
        } else if let id = settings.listID, let list = lists.first(where: { $0.calendarIdentifier == id }), list.title != settings.listName {
            // リマインダー App でリストの名前を変えたとき
            integrations.update { $0.reminder.listName = list.title }
        }
    }
}

/// Markdown ファイルへの追記: オン / オフ、保存先のフォルダ。
struct MarkdownSettingsView: View {
    @State private var integrations = IntegrationStore.shared
    @State private var picking = false
    @State private var error: String?

    private var settings: IntegrationSettings.Markdown { integrations.settings.markdown }

    var body: some View {
        Form {
            Group {
                Section {
                    Toggle("Markdown ファイルに追記する", isOn: Binding(
                        get: { settings.isEnabled },
                        set: { on in
                            integrations.update { $0.markdown.isEnabled = on }
                            if on, settings.folderName == nil { picking = true }
                        }
                    ))
                } footer: {
                    Text("すべてのメモを、選んだフォルダの日付ごとのファイル (例: 2026-11-13.md) に「- 10:15 内容」の形で追記します。")
                }

                if settings.isEnabled {
                    Section {
                        if let folder = settings.folderName {
                            Label(folder, systemImage: "folder")
                        }
                        Button(settings.folderName == nil ? String(localized: "フォルダを選ぶ") : String(localized: "フォルダを選び直す")) {
                            picking = true
                        }
                        if let error {
                            Text(error).font(.footnote).foregroundStyle(.red)
                        }
                    } header: {
                        Text("保存先のフォルダ")
                    } footer: {
                        Text("iCloud Drive の中の Obsidian の保管庫などを選べます。")
                    }
                }
            }
            .listRowBackground(Cosmos.card)
        }
        .navigationTitle("Markdown")
        .navigationBarTitleDisplayMode(.inline)
        .cosmicListBackground()
        .fileImporter(isPresented: $picking, allowedContentTypes: [.folder]) { result in
            switch result {
            case .success(let url):
                do {
                    try integrations.setMarkdownFolder(url)
                    error = nil
                } catch {
                    self.error = String(localized: "このフォルダは使えません: \(error.localizedDescription)")
                }
            case .failure(let e):
                error = e.localizedDescription
            }
            // フォルダを選ばずに閉じたら、オンのままにしない
            if integrations.settings.markdown.folderName == nil {
                integrations.update { $0.markdown.isEnabled = false }
            }
        }
    }
}
