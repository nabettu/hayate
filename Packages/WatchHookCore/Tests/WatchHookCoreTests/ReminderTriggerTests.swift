import Foundation
import Testing
@testable import WatchHookCore

@Suite("ReminderTrigger")
struct ReminderTriggerTests {
    let ja = ["リマインダー", "リマインド", "やること"]
    let en = ["Reminder", "Remind me to", "Remind me"]

    @Test(arguments: [
        "リマインダー、牛乳を買う",
        "リマインダー 牛乳を買う",
        "リマインダー　牛乳を買う",
        "リマインダー。牛乳を買う",
        "リマインダー：牛乳を買う",
        "リマインダー,牛乳を買う",
        "リマインダー牛乳を買う",
        "  リマインダー、 牛乳を買う  ",
        "ﾘﾏｲﾝﾀﾞｰ、牛乳を買う",
    ])
    func 日本語の合図は区切りの有無を問わない(text: String) {
        #expect(ReminderTrigger.match(text, keywords: ja) == .reminder(body: "牛乳を買う"))
    }

    @Test func 長い合図を先に見る() {
        #expect(ReminderTrigger.match("Remind me to buy milk", keywords: en) == .reminder(body: "buy milk"))
        #expect(ReminderTrigger.match("remind me, buy milk", keywords: en) == .reminder(body: "buy milk"))
        #expect(ReminderTrigger.match("REMINDER: buy milk", keywords: en) == .reminder(body: "buy milk"))
    }

    @Test func 空白で区切る言語は語の途中で切らない() {
        #expect(ReminderTrigger.match("Reminders are useful", keywords: en) == .none)
        #expect(ReminderTrigger.match("Remindful", keywords: en) == .none)
    }

    @Test func 文頭でなければ合図にしない() {
        #expect(ReminderTrigger.match("牛乳を買うリマインダー", keywords: ja) == .none)
        #expect(ReminderTrigger.match("今日のやること", keywords: ja) == .none)
    }

    @Test func 合図だけで本文が無い() {
        #expect(ReminderTrigger.match("リマインダー", keywords: ja) == .emptyBody)
        #expect(ReminderTrigger.match("リマインダー、", keywords: ja) == .emptyBody)
        #expect(ReminderTrigger.match("Reminder.", keywords: en) == .emptyBody)
    }

    @Test func 空の合図は無視する() {
        #expect(ReminderTrigger.match("牛乳", keywords: ["", "  "]) == .none)
    }

    @Test func 既定の合図は言語ごとにある() {
        #expect(ReminderTrigger.defaultKeywords(preferredLanguages: ["ja-JP"]).contains("リマインダー"))
        #expect(ReminderTrigger.defaultKeywords(preferredLanguages: ["en-US"]).contains("Reminder"))
        #expect(ReminderTrigger.defaultKeywords(preferredLanguages: ["zh-Hant-TW"]).contains("提醒事項"))
        #expect(ReminderTrigger.defaultKeywords(preferredLanguages: ["zh-HK"]).contains("提醒事項"))
        #expect(ReminderTrigger.defaultKeywords(preferredLanguages: ["zh-Hans-CN"]).contains("提醒事项"))
        #expect(ReminderTrigger.defaultKeywords(preferredLanguages: ["pt-BR"]).contains("Lembrete"))
        #expect(ReminderTrigger.defaultKeywords(preferredLanguages: ["pt-PT"]).contains("Lembrete"))
        #expect(ReminderTrigger.defaultKeywords(preferredLanguages: ["nb-NO"]).contains("Påminnelse"))
        #expect(ReminderTrigger.defaultKeywords(preferredLanguages: ["no"]).contains("Påminnelse"))
        // 対応していない言語は次の候補、それも無ければ英語
        #expect(ReminderTrigger.defaultKeywords(preferredLanguages: ["eo", "de-DE"]).contains("Erinnerung"))
        #expect(ReminderTrigger.defaultKeywords(preferredLanguages: ["eo"]) == ReminderTrigger.defaultKeywords(preferredLanguages: ["en"]))
    }

    @Test func アプリの全言語に既定の合図がある() throws {
        // scripts/l10n/locales.json の言語と同じ
        let languages = ["ja", "en", "ar", "bn", "ca", "cs", "da", "de", "el", "es", "fi", "fr", "gu", "he", "hi", "hr", "hu", "id",
                         "it", "kn", "ko", "ml", "mr", "ms", "nb", "nl", "or", "pa", "pl", "pt-BR", "pt-PT", "ro", "ru", "sk", "sl",
                         "sv", "ta", "te", "th", "tr", "uk", "ur", "vi", "zh-Hans", "zh-Hant"]
        #expect(languages.count == 45)
        for lang in languages {
            let keywords = try #require(ReminderTrigger.defaultKeywordsByLanguage[lang], "\(lang)")
            #expect(keywords.count >= 2, "\(lang)")
            #expect(keywords.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty }, "\(lang)")
        }
    }

    @Test func 既定の合図はその言語の文で動く() {
        #expect(ReminderTrigger.match("Erinnere mich an Milch kaufen", keywords: ReminderTrigger.defaultKeywords(preferredLanguages: ["de"])) == .reminder(body: "Milch kaufen"))
        #expect(ReminderTrigger.match("提醒我买牛奶", keywords: ReminderTrigger.defaultKeywords(preferredLanguages: ["zh-Hans"])) == .reminder(body: "买牛奶"))
        #expect(ReminderTrigger.match("Напомни мне купить молоко", keywords: ReminderTrigger.defaultKeywords(preferredLanguages: ["ru"])) == .reminder(body: "купить молоко"))
        #expect(ReminderTrigger.match("리마인더 우유 사기", keywords: ReminderTrigger.defaultKeywords(preferredLanguages: ["ko"])) == .reminder(body: "우유 사기"))
    }
}
