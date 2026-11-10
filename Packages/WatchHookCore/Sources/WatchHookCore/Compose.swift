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

    /// 端末に覚えている選択を直すときの新しい値。直さなくてよければ nil。
    /// 送り先が空のときは直さない: 設定を読めなかった (ロック中など) ときも空になり、消えたのか読めないのか分からないため。
    /// ここで消すと、読めるようになっても元の選択に戻らない。
    public func correctedSelection(_ selectedID: String) -> String? {
        guard !destinations.isEmpty, let resolved = resolve(selectedID: selectedID) else { return nil }
        let value = resolved.id.uuidString
        return value == selectedID ? nil : value
    }
}
