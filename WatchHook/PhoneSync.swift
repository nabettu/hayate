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
    /// applicationContext は丸ごと置き換わるので、設定の版と購入の状態を毎回両方載せる。
    @MainActor
    @discardableResult
    func push(_ config: DestinationConfig) -> String? {
        let session = WCSession.default
        guard WCSession.isSupported(), session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else {
            return nil
        }
        do {
            // 認証ヘッダを含む本体は applicationContext に置かない (端末に保存され続けるため)。版だけ知らせ、時計が取りに来る
            var context: [String: Any] = [SyncKeys.revision: config.revision, SyncKeys.epoch: config.epoch.uuidString]
            if let entitlement = try? EntitlementStore.shared.local.encoded() {
                context[SyncKeys.entitlement] = entitlement
            }
            try session.updateApplicationContext(context)
            return nil
        } catch {
            return "Apple Watch へ設定を送れませんでした: \(error.localizedDescription)"
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard activationState == .activated else { return }
        Task { @MainActor in ConfigStore.shared.resync() }
        // アプリが閉じている間に届いていた時計の履歴。今ペアの時計からまだ届いていなければ、前の時計の写しを消す
        receiveHistory(from: session.receivedApplicationContext, clearIfMissing: true)
    }

    /// 時計から履歴の写しが届いたとき。
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        receiveHistory(from: applicationContext)
    }

    private enum HistoryUpdate: Sendable {
        case snapshot(HistorySnapshot)
        /// 時計が替わった・今の時計からまだ届いていない。前の時計の写しを残さない
        case cleared
    }

    /// 最後に受け取った時計の履歴の状態。デリゲートは 1 本のキューから順に呼ばれるので、ここには常に最新が入る。
    /// MainActor への受け渡しは Task ごとに順番が入れ替わりうるので、受け取った値ではなく、反映する時点の最新をここから読む
    /// (古い写しで上書きして、送信済みが未送信に戻ったり、消したものが戻ったりしないように)。
    private let latestHistory = Mutex<HistoryUpdate?>(nil)

    private func receiveHistory(from context: [String: Any], clearIfMissing: Bool = false) {
        guard let data = context[SyncKeys.history] as? Data else {
            if clearIfMissing { applyHistory(.cleared) }
            return
        }
        // 読めない写しは捨てる (手元の写しは消さない)
        guard let snapshot = try? HistorySnapshot.decode(data) else { return }
        applyHistory(.snapshot(snapshot))
    }

    private func applyHistory(_ update: HistoryUpdate) {
        latestHistory.withLock { $0 = update }
        Task { @MainActor in
            switch self.latestHistory.withLock({ $0 }) {
            case .snapshot(let latest): WatchHistoryStore.shared.receive(latest)
            case .cleared: WatchHistoryStore.shared.clear()
            case nil: break
            }
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
        // 別の時計に切り替えたとき。前の時計の履歴は見せない (新しい時計の分は activate のあとに届く)
        applyHistory(.cleared)
        session.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in ConfigStore.shared.resync() }
    }
}
