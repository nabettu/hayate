import Foundation

/// iPhone の中だけで持つ連携の設定 (リマインダー・Markdown)。時計は持たない (振り分けは iPhone が受け取ったときに決める)。
public struct IntegrationSettings: Codable, Hashable, Sendable {
    public struct Reminder: Codable, Hashable, Sendable {
        public var isEnabled: Bool
        /// 保存先のリスト (`EKCalendar.calendarIdentifier`)
        public var listID: String?
        public var listName: String?
        public var keywords: [String]

        public init(isEnabled: Bool = false, listID: String? = nil, listName: String? = nil,
                    keywords: [String] = ReminderTrigger.defaultKeywords(preferredLanguages: Locale.preferredLanguages)) {
            self.isEnabled = isEnabled
            self.listID = listID
            self.listName = listName
            self.keywords = keywords
        }

        private enum CodingKeys: String, CodingKey { case isEnabled, listID, listName, keywords }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.init(
                isEnabled: try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false,
                listID: try c.decodeIfPresent(String.self, forKey: .listID),
                listName: try c.decodeIfPresent(String.self, forKey: .listName),
                keywords: try c.decodeIfPresent([String].self, forKey: .keywords)
                    ?? ReminderTrigger.defaultKeywords(preferredLanguages: Locale.preferredLanguages)
            )
        }
    }

    public struct Markdown: Codable, Hashable, Sendable {
        public var isEnabled: Bool
        /// 選んだフォルダの名前 (表示用)。フォルダそのものは security-scoped bookmark で別に持つ
        public var folderName: String?

        public init(isEnabled: Bool = false, folderName: String? = nil) {
            self.isEnabled = isEnabled
            self.folderName = folderName
        }

        private enum CodingKeys: String, CodingKey { case isEnabled, folderName }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
            folderName = try c.decodeIfPresent(String.self, forKey: .folderName)
        }
    }

    public var reminder: Reminder
    public var markdown: Markdown

    public init(reminder: Reminder = Reminder(), markdown: Markdown = Markdown()) {
        self.reminder = reminder
        self.markdown = markdown
    }

    private enum CodingKeys: String, CodingKey { case reminder, markdown }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        reminder = try c.decodeIfPresent(Reminder.self, forKey: .reminder) ?? Reminder()
        markdown = try c.decodeIfPresent(Markdown.self, forKey: .markdown) ?? Markdown()
    }
}

/// 入力したメモに付ける連携を決める。
public enum MemoPlanner {
    /// 有効な送り先すべてへの webhook。入力した端末が受け持つ (時計から直接送る。docs/DESIGN.md)
    public static func webhookDeliveries(text: String, config: DestinationConfig, owner: DeviceRole) -> [Delivery] {
        config.enabledDestinations.map {
            Delivery(target: .webhook(destinationID: $0.id, name: $0.displayName), owner: owner, text: $0.wrap(text))
        }
    }

    /// iPhone が受け持つリマインダー・Markdown。iPhone で入力したとき・時計のメモを初めて受け取ったときに足す。
    public static func phoneDeliveries(text: String, settings: IntegrationSettings) -> [Delivery] {
        var result: [Delivery] = []
        let r = settings.reminder
        if r.isEnabled, r.listID != nil, case .reminder(let body) = ReminderTrigger.match(text, keywords: r.keywords) {
            result.append(Delivery(target: .reminder(listName: r.listName ?? ""), owner: .phone, text: body))
        }
        let md = settings.markdown
        if md.isEnabled, let folder = md.folderName {
            result.append(Delivery(target: .markdown(folderName: folder), owner: .phone, text: text))
        }
        return result
    }
}

/// 選んだフォルダの日付ごとの Markdown (Obsidian のデイリーノートと同じ `YYYY-MM-DD.md`) に 1 件 1 行で足す。
public enum MarkdownJournal {
    static func formatter(_ format: String, timeZone: TimeZone) -> DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = format
        return f
    }

    public static func fileName(for date: Date, timeZone: TimeZone = .current) -> String {
        formatter("yyyy-MM-dd", timeZone: timeZone).string(from: date) + ".md"
    }

    /// `- HH:mm 本文`。本文の改行は字下げして同じ項目に続ける。
    public static func line(text: String, date: Date, timeZone: TimeZone = .current) -> String {
        let time = formatter("HH:mm", timeZone: timeZone).string(from: date)
        let body = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .joined(separator: "\n  ")
        return "- \(time) \(body)"
    }

    /// 足したあとのファイルの中身。同じ行が既にあれば nil (送り直しで二重に足さない)。
    public static func appending(_ line: String, to existing: String) -> String? {
        let lines = existing.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        let first = line.components(separatedBy: "\n")
        // 複数行の項目は、続きの行まで一致したときだけ「同じ」とみなす
        if let start = lines.indices.first(where: { lines[$0] == first[0] }),
           lines.count >= start + first.count, Array(lines[start..<start + first.count]) == first {
            return nil
        }
        var text = existing
        if !text.isEmpty, !text.hasSuffix("\n") { text += "\n" }
        return text + line + "\n"
    }
}
