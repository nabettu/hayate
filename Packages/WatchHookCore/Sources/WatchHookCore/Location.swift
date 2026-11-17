import Foundation

/// メモを入力したときの場所 (緯度・経度)。送り先が「場所を送る」にしているときだけ付く。
public struct MemoLocation: Codable, Hashable, Sendable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// `{{location}}` に入れる文字列 (「緯度,経度」。小数 6 桁は約 11cm)。
    public var text: String {
        String(format: "%.6f,%.6f", latitude, longitude)
    }
}

/// 入力のときに場所を取るかどうか。取るのは「場所を送る」送り先が有効にあるときだけ。
/// 時計で入力したメモは、時計の設定 (`watchAttachEnabled`) もオンのときだけ取る (時計は iPhone と別に選ぶ)。
public enum LocationPolicy {
    public static func shouldCapture(origin: DeviceRole, watchAttachEnabled: Bool, destinations: [Destination]) -> Bool {
        if origin == .watch && !watchAttachEnabled { return false }
        return destinations.contains { $0.isEnabled && $0.sendsLocation }
    }
}

/// 測位の結果を使ってよいか。古い測位 (要求より前のキャッシュ) と、精度が無効な測位は使わない。
public enum LocationFix {
    public static func isUsable(horizontalAccuracy: Double, timestamp: Date, requestedAt: Date) -> Bool {
        horizontalAccuracy >= 0 && timestamp >= requestedAt
    }
}

/// 「場所を送る」を切り替えたときの本文。オンにしても本文に `{{location}}` が無いと場所が送られないため、
/// JSON (オブジェクト) とフォームの本文には `location` の項目を自動で足し、オフにしたら足した形のものだけ外す。
public enum LocationTemplate {
    static let placeholder = "{{location}}"
    static let jsonField = #""location":"{{location}}""#
    static let formField = "location={{location}}"

    public static func adding(to template: String, encoding: BodyEncoding) -> String {
        guard !template.contains(placeholder) else { return template }
        switch encoding {
        case .json:
            guard let close = template.lastIndex(of: "}"),
                  template[template.index(after: close)...].allSatisfy(\.isWhitespace),
                  let open = template.firstIndex(where: { !$0.isWhitespace }), template[open] == "{" else { return template }
            let inner = template[template.index(after: open)..<close]
            let isEmpty = inner.allSatisfy(\.isWhitespace)
            // 閉じ括弧の前の空白・改行はそのまま残し、最後の値の直後に足す
            let insertAt = isEmpty ? close : (inner.lastIndex(where: { !$0.isWhitespace }).map { template.index(after: $0) } ?? close)
            var result = template
            result.insert(contentsOf: (isEmpty ? "" : ",") + jsonField, at: insertAt)
            return result
        case .form:
            return template.isEmpty ? formField : template + "&" + formField
        case .plain:
            return template
        }
    }

    public static func removing(from template: String, encoding: BodyEncoding) -> String {
        switch encoding {
        case .json:
            if let r = template.range(of: "," + jsonField) { return template.replacingCharacters(in: r, with: "") }
            if let r = template.range(of: jsonField), template.replacingCharacters(in: r, with: "").filter({ !$0.isWhitespace }) == "{}" {
                return template.replacingCharacters(in: r, with: "")
            }
            return template
        case .form:
            if template.hasSuffix("&" + formField) { return String(template.dropLast(formField.count + 1)) }
            return template == formField ? "" : template
        case .plain:
            return template
        }
    }
}
