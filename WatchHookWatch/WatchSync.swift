import Foundation
import WatchConnectivity
import WatchHookCore

/// iPhone から届いた送り先の設定を時計の Keychain に保存する。送信は時計から直接行うので、送るときに iPhone は要らない。
final class WatchSync: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = WatchSync()

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// 設定がまだ無いとき、iPhone に取りに行く。
    func requestConfig() {
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else { return }
        session.sendMessage([SyncKeys.request: SyncKeys.config], replyHandler: { [weak self] reply in
            self?.apply(reply)
        }, errorHandler: nil)
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard activationState == .activated else { return }
        if !session.receivedApplicationContext.isEmpty {
            apply(session.receivedApplicationContext)
        } else {
            requestConfig()
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        apply(applicationContext)
    }

    private func apply(_ payload: [String: Any]) {
        guard let data = payload[SyncKeys.config] as? Data, let config = try? DestinationConfig.decode(data) else { return }
        Task { @MainActor in ConfigStore.shared.update(config, notify: false) }
    }
}
