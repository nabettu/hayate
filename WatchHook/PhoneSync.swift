import Foundation
import Synchronization
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

    /// 時計へ送る。送れなかったら理由を返す (時計が無い・アプリ未インストールは失敗にしない)。
    @discardableResult
    func push(_ config: DestinationConfig) -> String? {
        let session = WCSession.default
        guard WCSession.isSupported(), session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else {
            return nil
        }
        do {
            // 認証ヘッダを含む本体は applicationContext に置かない (端末に保存され続けるため)。版だけ知らせ、時計が取りに来る
            try session.updateApplicationContext([SyncKeys.revision: config.revision, SyncKeys.epoch: config.epoch.uuidString])
            return nil
        } catch {
            return "Apple Watch へ設定を送れませんでした: \(error.localizedDescription)"
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard activationState == .activated else { return }
        Task { @MainActor in ConfigStore.shared.resync() }
        // アプリが閉じている間に届いていた時計の履歴
        receiveHistory(from: session.receivedApplicationContext)
    }

    /// 時計から履歴の写しが届いたとき。
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        receiveHistory(from: applicationContext)
    }

    /// 最後に受け取った時計の履歴の写し。デリゲートは 1 本のキューから順に呼ばれるので、ここには常に最新が入る。
    /// MainActor への受け渡しは Task ごとに順番が入れ替わりうるので、受け取った値ではなく、反映する時点の最新をここから読む
    /// (古い写しで上書きして、送信済みが未送信に戻ったり、消したものが戻ったりしないように)。
    private let latestHistory = Mutex<HistorySnapshot?>(nil)

    private func receiveHistory(from context: [String: Any]) {
        guard let data = context[SyncKeys.history] as? Data,
              let snapshot = try? HistorySnapshot.decode(data) else { return }
        latestHistory.withLock { $0 = snapshot }
        Task { @MainActor in
            guard let latest = self.latestHistory.withLock({ $0 }) else { return }
            WatchHistoryStore.shared.receive(latest)
        }
    }

    /// 時計が「設定をください」と言ってきたとき (初回インストール直後など)。
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard message[SyncKeys.request] as? String == SyncKeys.config else {
            replyHandler([:])
            return
        }
        let data = try? (try ConfigStore.loadFromKeychain()).encoded()
        replyHandler(data.map { [SyncKeys.config: $0] } ?? [:])
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // 別の時計に切り替えたとき
        session.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in ConfigStore.shared.resync() }
    }
}
