import Foundation
import WatchConnectivity
import WatchHookCore

/// iPhone から届いた送り先の設定を時計の Keychain に保存し、時計で入力したメモを iPhone に渡す。
/// webhook は時計から直接送るので、送るときに iPhone は要らない。
final class WatchSync: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = WatchSync()

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// iPhone に設定の本体を取りに行く。届かなければ、次に前面に来たとき / つながったときにやり直す。
    func requestConfig() {
        guard Self.canRequest else { return }
        Task { @MainActor in
            Self.requestConfigNow(retrying: nil)
        }
    }

    private static var canRequest: Bool {
        WCSession.default.activationState == .activated && WCSession.default.isReachable
    }

    /// 要求番号を取ってすぐ送る。取り直しなら、まだ要るかを確かめるところから間を空けずに行う
    /// (別のタスクに回すと、その間に出た新しい要求の返信を古いものとして捨ててしまう)。
    @MainActor
    private static func requestConfigNow(retrying ticket: ConfigSyncStatus.Ticket?) {
        if let ticket, !ConfigStore.shared.shouldRetrySync(after: ticket) { return }
        guard canRequest else { return }
        send(session: WCSession.default, ticket: ConfigStore.shared.beginSyncRequest())
    }

    /// 返信のクロージャは WatchConnectivity のキューから呼ばれる。MainActor の中で作ると MainActor 所属とみなされ、
    /// 実行時の隔離チェックで落ちる (2026-11-09 にシミュレータで発生) ので、nonisolated の関数で作る。
    private nonisolated static func send(session: WCSession, ticket: ConfigSyncStatus.Ticket) {
        session.sendMessage([SyncKeys.request: SyncKeys.config], replyHandler: { @Sendable reply in
            let config = (reply[SyncKeys.config] as? Data).flatMap { try? DestinationConfig.decode($0) }
            Task { @MainActor in
                // 何度か取りに行ったとき、最後の要求への結果だけを使う。反映する直前 (MainActor の上) で確かめる
                guard let config else {
                    Self.handleFailure(String(localized: "iPhone から設定を受け取れませんでした"), ticket: ticket)
                    return
                }
                guard ConfigStore.shared.syncSucceeded(ticket) else { return }
                ConfigStore.shared.receive(config)
            }
        }, errorHandler: { @Sendable error in
            let message = String(localized: "iPhone から設定を受け取れませんでした: \(error.localizedDescription)")
            Task { @MainActor in
                Self.handleFailure(message, ticket: ticket)
            }
        })
    }

    /// 起動直後 (準備中) の失敗はエラーを出さずに、少し待って取り直す。
    /// 待っている間に別の要求を出した・前面に戻ったなら取り直さない (`ConfigSyncStatus.shouldRetry(after:)`)。
    @MainActor
    private static func handleFailure(_ message: String, ticket: ConfigSyncStatus.Ticket) {
        guard case .retry(let delay) = ConfigStore.shared.syncFailed(message, ticket) else { return }
        Task {
            try? await Task.sleep(for: delay)
            requestConfigNow(retrying: ticket)
        }
    }

    /// 起動した・前面に戻ったとき。つながりが落ち着くまでは取り寄せの失敗を画面に出さない。
    /// 成功か、取り直しても失敗したら準備完了になる。どちらにもならない (返事が来ない・つながらない) ときは打ち切る。
    @MainActor
    func beginStartup() {
        let generation = ConfigStore.shared.beginSyncStartup()
        Task {
            try? await Task.sleep(for: ConfigSyncStatus.startupLimit)
            ConfigStore.shared.endSyncStartup(generation: generation)
        }
    }

    // MARK: - メモ

    /// メモを iPhone に渡す。transferUserInfo は届くまで OS が持ち続け、iPhone のアプリが閉じていても次に起きたときに届く。
    /// `urgent` (入力した直後) なら、つながっていれば sendMessage でも送り、iPhone のアプリを裏で起こしてすぐ保存させる
    /// (リマインダーを早く作るため)。両方届いても iPhone は ID で 1 件にまとめる。
    func sendMemo(_ memo: Memo, urgent: Bool) {
        let session = WCSession.default
        guard WCSession.isSupported(), session.activationState == .activated,
              let data = try? JSONEncoder().encode(memo) else { return }
        // 同じメモの古い写しがまだ届いていなければ取り消す (最新の 1 通だけ届けばよい)
        if replaceQueuedCopies(of: memo, in: session) {
            session.transferUserInfo([SyncKeys.memo: data])
        }
        if urgent, session.isReachable {
            Self.sendNow(session: session, data: data)
        }
    }

    private nonisolated static func sendNow(session: WCSession, data: Data) {
        session.sendMessage([SyncKeys.memo: data], replyHandler: { @Sendable reply in
            guard let copy = (reply[SyncKeys.memo] as? Data).flatMap({ try? JSONDecoder().decode(Memo.self, from: $0) }) else { return }
            Task { await MemoDispatcher.shared.receiveFromPhone(copy) }
        }, errorHandler: { @Sendable _ in
            // transferUserInfo でも送っているので、ここでは何もしない
        })
    }

    /// iPhone に渡せていないメモを送り直す (前の transferUserInfo が残っていれば、それを最新に置き換える)。
    func resendWaitingMemos() {
        Task {
            for memo in await MemoDispatcher.shared.memosWaitingForPhone() {
                sendMemo(memo, urgent: false)
            }
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard activationState == .activated else { return }
        requestConfig()
        resendWaitingMemos()
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

    /// iPhone からの写し (受領の知らせ・リマインダーなどの結果) と、消したメモの知らせ。
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        if let copy = (userInfo[SyncKeys.memo] as? Data).flatMap({ try? JSONDecoder().decode(Memo.self, from: $0) }) {
            Task { await MemoDispatcher.shared.receiveFromPhone(copy) }
        }
        if let id = (userInfo[SyncKeys.deletedMemo] as? String).flatMap(UUID.init(uuidString:)) {
            Task { await MemoDispatcher.shared.receiveDeletion(id) }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        if session.isReachable {
            requestConfig()
            resendWaitingMemos()
        }
    }
}
