import CoreLocation
import Foundation
import WatchHookCore

/// 入力した瞬間の場所を 1 回だけ取る (Apple Watch と iPhone の共通)。
/// 権限が無い・時間内に取れない・失敗したときは nil を返し、メモは場所なしのまま残す (入力を止めない)。
/// 要求ごとに CLLocationManager を作り直す。前の要求の遅れた結果やエラーが次の要求に届かないようにするため。
@MainActor
enum LocationCapture {
    /// 今いる場所。`timeout` を過ぎたら nil。
    static func current(timeout: Duration = .seconds(5)) async -> MemoLocation? {
        let request = OneShotLocation()
        return await request.run(timeout: timeout)
    }

    /// 送り先で「場所を送る」をオンにしたときに、前面で権限を聞いておく。
    /// Siri は裏で動くため、権限の問い合わせは前面の画面からしかできない。
    static func prepareAuthorization() {
        // 許可の画面が出て答えが返るまで manager を生かしておく (途中で解放するとダイアログが出ない)
        if authManager.authorizationStatus == .notDetermined {
            authManager.requestWhenInUseAuthorization()
        }
    }

    private static let authManager = CLLocationManager()
}

/// 1 回の測位の要求。結果が出た・時間切れ・失敗のどれか 1 回だけ答えを返す。
@MainActor
private final class OneShotLocation: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<MemoLocation?, Never>?
    private var requestedAt = Date()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func run(timeout: Duration) async -> MemoLocation? {
        requestedAt = Date()
        return await withCheckedContinuation { cont in
            continuation = cont
            Task { @MainActor in
                try? await Task.sleep(for: timeout)
                self.finish(nil)
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
            finish(nil)
        }
    }

    private func finish(_ value: MemoLocation?) {
        guard let c = continuation else { return }
        continuation = nil
        manager.delegate = nil
        c.resume(returning: value)
    }

    // MARK: CLLocationManagerDelegate (メインスレッドで呼ばれる。値だけ取り出して MainActor に移す)

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                if self.continuation != nil { self.manager.requestLocation() }
            case .denied, .restricted:
                self.finish(nil)
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        let fix = (last.coordinate.latitude, last.coordinate.longitude, last.horizontalAccuracy, last.timestamp)
        Task { @MainActor in
            guard self.continuation != nil else { return }
            if LocationFix.isUsable(horizontalAccuracy: fix.2, timestamp: fix.3, requestedAt: self.requestedAt) {
                self.finish(MemoLocation(latitude: fix.0, longitude: fix.1))
            } else {
                // 古い測位 (要求より前のキャッシュ) だったので、もう一度測る。時間切れまで続く
                self.manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finish(nil) }
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
