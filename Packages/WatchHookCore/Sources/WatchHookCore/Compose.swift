import Foundation

/// 送る前のテキストの整え方。時計の音声入力・iPhone の入力欄・Siri で同じ規則にする。
public enum MessageText {
    /// 前後の空白と改行を落とす。中身が無ければ nil (送らない)。
    public static func normalized(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension DestinationConfig {
    /// 端末の中で選んでいる送り先 (`selectedID` は UUID の文字列。未選択は空)。
    /// 選んだものが消えていたら既定の送り先に戻す (表示と実際の送り先をずらさない)。
    public func resolve(selectedID: String) -> Destination? {
        UUID(uuidString: selectedID).flatMap { destination(id: $0) } ?? defaultDestination
    }
}
