import CoreLocation
import Foundation
import WatchHookCore

/// 入力した瞬間の場所を 1 回だけ取る (Apple Watch と iPhone の共通)。
/// 権限が無い・時間内に取れない・失敗したときは nil を返し、メモは場所なしのまま残す (入力を止めない)。
/// 要求より前の測位 (キャッシュ) や精度の無い測位は使わない (`LocationFix`)。
@MainActor
final class LocationCapture: NSObject, CLLocationManagerDelegate {
    static let shared = LocationCapture()

    private struct Request {
        let id: Int
        let requestedAt: Date
        let continuation: CheckedContinuation<MemoLocation?, Never>
    }

    private let manager = CLLocationManager()
    private var pending: Request?
    private var nextID = 0
    /// `requestLocation()` の結果がまだ返っていない (返っていないあいだ、もう一度頼んでも無視される)
    private var isMeasuring = false

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// 送り先で「場所を送る」をオンにしたときに、前面で権限を聞いておく。
    /// Siri は裏で動くため、権限の問い合わせは前面の画面からしかできない。
    func prepareAuthorization() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    /// 今いる場所。`timeout` を過ぎたら nil。別の要求が待っているあいだは測らず nil
    /// (測位を途中で取り消せず、遅れて届いた結果やエラーを次の要求に付けないため)。
    func current(timeout: Duration = .seconds(5)) async -> MemoLocation? {
        if pending != nil { return nil }
        nextID += 1
        let id = nextID
        return await withCheckedContinuation { continuation in
            pending = Request(id: id, requestedAt: Date(), continuation: continuation)
            Task { @MainActor in
                try? await Task.sleep(for: timeout)
                self.finish(id: id, value: nil)
            }
            start()
        }
    }

    private func start() {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if !isMeasuring {
                isMeasuring = true
                manager.requestLocation()
            }
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            finish(id: nil, value: nil)
        }
    }

    /// 待っている要求を返す。`id` を指定したときは、その要求だけ返す (打ち切りの後の要求を取り違えないため)。
    private func finish(id: Int?, value: MemoLocation?) {
        guard let p = pending, id == nil || p.id == id else { return }
        pending = nil
        p.continuation.resume(returning: value)
    }

    // MARK: CLLocationManagerDelegate (メインスレッドで呼ばれる。値だけ取り出して MainActor に移す)

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                if self.pending != nil { self.start() }
            case .denied, .restricted:
                self.finish(id: nil, value: nil)
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        let fix = (last.coordinate.latitude, last.coordinate.longitude, last.horizontalAccuracy, last.timestamp)
        Task { @MainActor in
            self.isMeasuring = false
            guard let p = self.pending else { return }
            if LocationFix.isUsable(horizontalAccuracy: fix.2, timestamp: fix.3, requestedAt: p.requestedAt) {
                self.finish(id: nil, value: MemoLocation(latitude: fix.0, longitude: fix.1))
            } else {
                // 古い測位だった。待ち時間のあいだはもう一度測る
                self.start()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.isMeasuring = false
            self.finish(id: nil, value: nil)
        }
    }
}

/// 時計で入力したメモに場所を付けるか (時計だけの設定。iPhone と同期しない)。
enum WatchLocationSetting {
    private static let key = "watchAttachLocation"

    static var isOn: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
