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

    /// iPhone に設定の本体を取りに行く。届かなければ、次に前面に来たとき / つながったときにやり直す。
    func requestConfig() {
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else { return }
        Task { @MainActor in
            Self.send(session: session, token: RequestGate.gate.begin())
        }
    }

    /// 返信のクロージャは WatchConnectivity のキューから呼ばれる。MainActor の中で作ると MainActor 所属とみなされ、
    /// 実行時の隔離チェックで落ちる (2026-11-09 にシミュレータで発生) ので、nonisolated の関数で作る。
    private nonisolated static func send(session: WCSession, token: Int) {
        session.sendMessage([SyncKeys.request: SyncKeys.config], replyHandler: { @Sendable reply in
            let config = (reply[SyncKeys.config] as? Data).flatMap { try? DestinationConfig.decode($0) }
            Task { @MainActor in
                // 何度か取りに行ったとき、最後の要求への結果だけを使う。反映する直前 (MainActor の上) で確かめる
                guard RequestGate.gate.isLatest(token) else { return }
                guard let config else {
                    ConfigStore.shared.setSyncError("iPhone から設定を受け取れませんでした")
                    return
                }
                ConfigStore.shared.setSyncError(nil)
                ConfigStore.shared.receive(config)
            }
        }, errorHandler: { @Sendable error in
            let message = "iPhone から設定を受け取れませんでした: \(error.localizedDescription)"
            Task { @MainActor in
                guard RequestGate.gate.isLatest(token) else { return }
                ConfigStore.shared.setSyncError(message)
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

/// 設定の取り寄せの世代。MainActor だけで触る。
@MainActor
private enum RequestGate {
    static var gate = LatestRequestGate()
}
