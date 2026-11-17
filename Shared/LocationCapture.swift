import CoreLocation
import Foundation
import WatchHookCore

/// 入力した瞬間の場所を 1 回だけ取る (Apple Watch と iPhone の共通)。
/// 権限が無い・時間内に取れない・失敗したときは nil を返し、メモは場所なしで保存する (入力を止めない)。
/// 権限の確認 (初回は OS の問い合わせ) も含めて `timeout` で打ち切る。
@MainActor
final class LocationCapture: NSObject, CLLocationManagerDelegate {
    static let shared = LocationCapture()

    private let manager = CLLocationManager()
    private var pending: (id: Int, continuation: CheckedContinuation<MemoLocation?, Never>)?
    private var nextID = 0

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// 今いる場所。`timeout` を過ぎたら nil。前の要求がまだ残っていれば nil にして置き換える。
    func current(timeout: Duration = .seconds(5)) async -> MemoLocation? {
        nextID += 1
        let id = nextID
        return await withCheckedContinuation { continuation in
            finish(id: nil, value: nil)
            pending = (id, continuation)
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
            manager.requestLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            finish(id: nil, value: nil)
        }
    }

    /// 待っている要求を返す。`id` を指定したときは、その要求だけ返す (打ち切りの後に来た結果で次の要求を返さないため)。
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
                if self.pending != nil { self.manager.requestLocation() }
            case .denied, .restricted:
                self.finish(id: nil, value: nil)
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coordinate = locations.last?.coordinate
        Task { @MainActor in
            guard let c = coordinate else { return }
            self.finish(id: nil, value: MemoLocation(latitude: c.latitude, longitude: c.longitude))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finish(id: nil, value: nil) }
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
