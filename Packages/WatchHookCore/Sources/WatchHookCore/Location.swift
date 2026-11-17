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

/// 本文に `{{location}}` が無いとき、ボタンで足す項目。送り先によって受け付ける項目が決まっているので、
/// 自動では足さず、押されたときだけ足す。足せない本文 (JSON のオブジェクトでない・同じ名前の項目がある・テキスト) は nil。
public enum LocationTemplate {
    static let key = "location"

    /// 本文に場所の差し込み (`{{location}}`・`{{ location }}`) があるか。
    public static func mentionsLocation(_ template: String) -> Bool {
        TemplateRenderer.placeholderNames(in: template).contains(key)
    }

    public static func adding(to template: String, encoding: BodyEncoding) -> String? {
        guard !mentionsLocation(template) else { return nil }
        switch encoding {
        case .json:
            guard let object = try? JSONSerialization.jsonObject(with: Data(template.utf8)) as? [String: Any],
                  object[key] == nil,
                  let close = template.lastIndex(of: "}") else { return nil }
            let inner = template[..<close]
            let last = inner.lastIndex(where: { !$0.isWhitespace })
            let isEmpty = object.isEmpty
            // 閉じ括弧の前の空白・改行はそのまま残し、最後の値の直後に足す
            let insertAt = isEmpty ? close : (last.map { template.index(after: $0) } ?? close)
            var result = template
            result.insert(contentsOf: (isEmpty ? "" : ",") + #""location":"{{location}}""#, at: insertAt)
            return result
        case .form:
            // 受け取る側と同じく、キーは + を空白に・%XX を戻してから比べる
            let names = template.split(separator: "&", omittingEmptySubsequences: false).map { item in
                let raw = item.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
                return raw.replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? raw
            }
            guard !names.contains(key) else { return nil }
            let field = "location={{location}}"
            return template.isEmpty ? field : template + "&" + field
        case .plain:
            return nil
        }
    }
}
