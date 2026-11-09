import Foundation
import WatchConnectivity
import WatchHookCore

/// iPhone → 時計へ送り先の設定を送る。applicationContext は最新の 1 件だけが届き、時計のアプリが閉じていても次に起きたときに受け取れる。
final class PhoneSync: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = PhoneSync()

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func push(_ config: DestinationConfig) {
        let session = WCSession.default
        guard WCSession.isSupported(), session.activationState == .activated, session.isPaired, session.isWatchAppInstalled,
              let data = try? config.encoded() else { return }
        try? session.updateApplicationContext([SyncKeys.config: data])
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard activationState == .activated else { return }
        Task { @MainActor in self.push(ConfigStore.shared.config) }
    }

    /// 時計が「設定をください」と言ってきたとき (初回インストール直後など)。
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard message[SyncKeys.request] as? String == SyncKeys.config else {
            replyHandler([:])
            return
        }
        let data = try? ConfigStore.loadFromKeychain().encoded()
        replyHandler(data.map { [SyncKeys.config: $0] } ?? [:])
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // 別の時計に切り替えたとき
        session.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in self.push(ConfigStore.shared.config) }
    }
}
