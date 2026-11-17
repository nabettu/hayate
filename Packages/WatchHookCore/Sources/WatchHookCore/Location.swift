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
