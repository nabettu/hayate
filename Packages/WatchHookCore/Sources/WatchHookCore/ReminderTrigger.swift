import Foundation

/// 文頭の合図 (「リマインダー、牛乳を買う」の「リマインダー」) でリマインダーに振り分ける。
/// 合図は言語ごとに既定をいくつか持ち、利用者が設定で足したり外したりできる (docs/FREE_OSS.md)。
public enum ReminderTrigger {
    public enum Match: Equatable, Sendable {
        case none
        /// 合図を除いた本文
        case reminder(body: String)
        /// 合図だけで本文が無い (メモだけ残し、リマインダーは作らない)
        case emptyBody
    }

    /// 合図のあとの区切り。音声入力では「、」「。」や空白が入ったり入らなかったりする
    static let separators: Set<Character> = [" ", "\u{3000}", "\t", "\n", "、", "，", ",", "。", ".", "：", ":", "；", ";",
                                             "-", "–", "—", "!", "！", "?", "？", "،", "؛", "।", "·"]

    public static func match(_ text: String, keywords: [String]) -> Match {
        // 半角カナ・全角英数字などをそろえてから比べる (NFKC。「ﾘﾏｲﾝﾀﾞｰ」も「リマインダー」と同じに見る)。本文もそろえたものを使う
        let input = text.precomposedStringWithCompatibilityMapping.trimmingCharacters(in: .whitespacesAndNewlines)
        // 長い合図を先に見る (「Remind me to」を「Remind me」より先に)
        let candidates = keywords
            .map { $0.precomposedStringWithCompatibilityMapping.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted { $0.count > $1.count }
        for keyword in candidates {
            guard let range = input.range(of: keyword, options: [.anchored, .caseInsensitive, .diacriticInsensitive, .widthInsensitive]) else {
                continue
            }
            let rest = input[range.upperBound...]
            // 空白で語を区切る言語は、語の途中 (Reminders) で切らない。日本語・中国語・タイ語などは区切りが無くてもよい
            if let next = rest.first, !separators.contains(next), !next.isWhitespace, needsSeparator(after: keyword) {
                continue
            }
            let body = String(rest.drop { separators.contains($0) || $0.isWhitespace })
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return body.isEmpty ? .emptyBody : .reminder(body: body)
        }
        return .none
    }

    /// 語のあいだに空白を入れない文字 (かな・漢字・タイ文字など) で終わる合図は、区切りが無くても合図とみなす。
    static func needsSeparator(after keyword: String) -> Bool {
        guard let last = keyword.unicodeScalars.last else { return true }
        let noSpaceRanges: [ClosedRange<UInt32>] = [
            0x3040...0x30FF, // ひらがな・カタカナ (長音符を含む)
            0x31F0...0x31FF,
            0x3400...0x9FFF, // 漢字
            0xF900...0xFAFF,
            0xFF66...0xFF9F, // 半角カナ
            0x0E00...0x0E7F, // タイ文字
        ]
        return !noSpaceRanges.contains { $0.contains(last.value) }
    }

    /// 端末の言語の並び (`Locale.preferredLanguages`) から既定の合図を選ぶ。対応していなければ英語。
    public static func defaultKeywords(preferredLanguages: [String]) -> [String] {
        for identifier in preferredLanguages {
            if let key = tableKey(for: identifier), let keywords = defaultKeywordsByLanguage[key] { return keywords }
        }
        return defaultKeywordsByLanguage["en"]!
    }

    static func tableKey(for identifier: String) -> String? {
        let language = Locale.Language(identifier: identifier)
        guard let code = language.languageCode?.identifier else { return nil }
        switch code {
        case "zh":
            let script = language.script?.identifier
            let region = language.region?.identifier
            if script == "Hant" || (script == nil && ["TW", "HK", "MO"].contains(region)) { return "zh-Hant" }
            return "zh-Hans"
        case "pt":
            return language.region?.identifier == "BR" || language.region == nil ? "pt-BR" : "pt-PT"
        case "no", "nn", "nb":
            return "nb"
        default:
            return code
        }
    }

    /// アプリが対応する 45 言語 (scripts/l10n/locales.json) の既定の合図。
    /// 実機の音声入力で表記を確かめたのは日本語・英語だけ。ほかは訳のまま (問い合わせで直す)
    public static let defaultKeywordsByLanguage: [String: [String]] = [
        "ja": ["リマインダー", "リマインド", "やること", "ToDo"],
        "en": ["Reminder", "Remind me to", "Remind me", "To do", "Todo"],
        "ar": ["تذكير", "ذكرني بأن", "ذكرني"],
        "bn": ["রিমাইন্ডার", "মনে করিয়ে দাও"],
        "ca": ["Recordatori", "Recorda'm que", "Recorda'm"],
        "cs": ["Připomínka", "Připomeň mi"],
        "da": ["Påmindelse", "Mind mig om", "Husk"],
        "de": ["Erinnerung", "Erinnere mich an", "Erinnere mich"],
        "el": ["Υπενθύμιση", "Θύμισέ μου να", "Θύμισέ μου"],
        "es": ["Recordatorio", "Recuérdame que", "Recuérdame"],
        "fi": ["Muistutus", "Muistuta minua", "Muistuta"],
        "fr": ["Rappel", "Rappelle-moi de", "Rappelle-moi"],
        "gu": ["રિમાઇન્ડર", "યાદ કરાવો"],
        "he": ["תזכורת", "תזכיר לי"],
        "hi": ["रिमाइंडर", "याद दिलाना", "याद दिलाओ"],
        "hr": ["Podsjetnik", "Podsjeti me da", "Podsjeti me"],
        "hu": ["Emlékeztető", "Emlékeztess"],
        "id": ["Pengingat", "Ingatkan saya", "Ingatkan"],
        "it": ["Promemoria", "Ricordami di", "Ricordami"],
        "kn": ["ರಿಮೈಂಡರ್", "ಜ್ಞಾಪನೆ"],
        "ko": ["리마인더", "미리 알림"],
        "ml": ["റിമൈൻഡർ", "ഓർമ്മപ്പെടുത്തൽ"],
        "mr": ["रिमाइंडर", "आठवण करून दे"],
        "ms": ["Peringatan", "Ingatkan saya", "Ingatkan"],
        "nb": ["Påminnelse", "Minn meg på", "Husk"],
        "nl": ["Herinnering", "Herinner me aan", "Herinner me"],
        "or": ["ରିମାଇଣ୍ଡର", "ସ୍ମାରକ"],
        "pa": ["ਰਿਮਾਈਂਡਰ", "ਯਾਦ ਕਰਾਓ"],
        "pl": ["Przypomnienie", "Przypomnij mi"],
        "pt-BR": ["Lembrete", "Me lembre de", "Lembre-me de"],
        "pt-PT": ["Lembrete", "Lembra-me de", "Lembrar"],
        "ro": ["Memento", "Amintește-mi să", "Amintește-mi"],
        "ru": ["Напоминание", "Напомни мне", "Напомни"],
        "sk": ["Pripomienka", "Pripomeň mi"],
        "sl": ["Opomnik", "Opomni me"],
        "sv": ["Påminnelse", "Påminn mig om", "Påminn mig"],
        "ta": ["நினைவூட்டல்", "ரிமைண்டர்"],
        "te": ["రిమైండర్", "గుర్తు చేయి"],
        "th": ["เตือนความจำ", "รีไมนเดอร์"],
        "tr": ["Hatırlatıcı", "Hatırlat"],
        "uk": ["Нагадування", "Нагадай мені", "Нагадай"],
        "ur": ["یاد دہانی", "یاد دلاؤ"],
        "vi": ["Lời nhắc", "Nhắc tôi", "Nhắc nhở"],
        "zh-Hans": ["提醒事项", "提醒我", "提醒"],
        "zh-Hant": ["提醒事項", "提醒我", "提醒"],
    ]
}
