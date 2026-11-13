import Foundation

/// 送る前のテキストの整え方。時計の音声入力・iPhone の入力欄・Siri で同じ規則にする。
public enum MessageText {
    /// 前後の空白と改行を落とす。中身が無ければ nil (送らない)。
    public static func normalized(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
