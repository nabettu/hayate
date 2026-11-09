import Foundation
import WatchConnectivity
import WatchHookCore

/// iPhone から届いた送り先の設定を時計の Keychain に保存する。送信は時計から直接行うので、送るときに iPhone は要らない。
final class WatchSync: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = WatchSync()

    private let lock = NSLock()
    private var gate = LatestRequestGate()

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// iPhone に設定の本体を取りに行く。届かなければ、次に前面に来たとき / つながったときにやり直す。
    func requestConfig() {
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else { return }
        let token = lock.withLock { gate.begin() }
        session.sendMessage([SyncKeys.request: SyncKeys.config], replyHandler: { [weak self] reply in
            // 何度か取りに行ったとき、最後の要求への返信だけを使う (遅れて届いた古い返信で巻き戻さない)
            guard let self, self.lock.withLock({ self.gate.isLatest(token) }) else { return }
            guard let data = reply[SyncKeys.config] as? Data, let config = try? DestinationConfig.decode(data) else {
                Task { @MainActor in ConfigStore.shared.setSyncError("iPhone から設定を受け取れませんでした") }
                return
            }
            Task { @MainActor in
                ConfigStore.shared.setSyncError(nil)
                ConfigStore.shared.receive(config)
            }
        }, errorHandler: { error in
            Task { @MainActor in
                ConfigStore.shared.setSyncError("iPhone から設定を受け取れませんでした: \(error.localizedDescription)")
            }
        })
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard activationState == .activated else { return }
        requestConfig()
    }

    /// iPhone で設定が変わった知らせ (版だけ)。手元より新しければ本体を取りに行く。
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let revision = applicationContext[SyncKeys.revision] as? Int,
              let epoch = (applicationContext[SyncKeys.epoch] as? String).flatMap(UUID.init(uuidString:)) else { return }
        Task { @MainActor in
            if DestinationConfig(revision: revision, epoch: epoch).isNewer(than: ConfigStore.shared.config) {
                self.requestConfig()
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        if session.isReachable { requestConfig() }
    }
}
