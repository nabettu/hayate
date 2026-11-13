import Foundation
import UIKit
import WatchConnectivity
import WatchHookCore

/// iPhone → 時計へ送り先の設定を送り、時計からメモを受け取る。
final class PhoneSync: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = PhoneSync()

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// 時計へ送る。送れなかったら理由を返す (時計が無い・アプリ未インストールは失敗にしない)。
    @MainActor
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
            return String(localized: "Apple Watch へ設定を送れませんでした: \(error.localizedDescription)")
        }
    }

    // MARK: - メモ

    /// 時計で入力したメモの写しを時計へ返す (リマインダーなどの結果を時計の画面に出すため)。
    func sendMemo(_ memo: Memo) {
        let session = WCSession.default
        guard WCSession.isSupported(), session.activationState == .activated, session.isWatchAppInstalled,
              let data = try? JSONEncoder().encode(memo) else { return }
        for transfer in session.outstandingUserInfoTransfers where transfer.isTransferring == false {
            if (transfer.userInfo[SyncKeys.memo] as? Data).flatMap({ try? JSONDecoder().decode(Memo.self, from: $0) })?.id == memo.id {
                transfer.cancel()
            }
        }
        session.transferUserInfo([SyncKeys.memo: data])
    }

    /// iPhone で消したメモを時計にも知らせる (時計の未送信を止めて消す)。
    func sendDeletion(_ memoID: UUID) {
        let session = WCSession.default
        guard WCSession.isSupported(), session.activationState == .activated, session.isWatchAppInstalled else { return }
        session.transferUserInfo([SyncKeys.deletedMemo: memoID.uuidString])
    }

    /// 時計から届いたメモを保存する。裏で起こされたときに途中で止められないよう、終わるまで時間をもらう。
    private static func receive(_ data: Data?) async -> Memo? {
        guard let remote = data.flatMap({ try? JSONDecoder().decode(Memo.self, from: $0) }) else { return nil }
        let task = await BackgroundTask.begin("receive-memo")
        defer { Task { @MainActor in task.end() } }
        guard let saved = await MemoDispatcher.shared.receiveFromWatch(remote) else { return nil }
        // このメモのリマインダー・Markdown を保存し終えてから返す (結果を早く時計に出すため)。溜まった分はそのあと
        await MemoDispatcher.shared.deliverPending(memoID: remote.id)
        Task { await MemoDispatcher.shared.flush() }
        return await MemoDispatcher.shared.memo(id: remote.id) ?? saved
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard activationState == .activated else { return }
        Task { @MainActor in ConfigStore.shared.resync() }
    }

    /// 時計からのメッセージ: 設定の取り寄せ / 入力した直後のメモ。
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        if message[SyncKeys.request] as? String == SyncKeys.config {
            let data = try? (try ConfigStore.loadFromKeychain()).encoded()
            replyHandler(data.map { [SyncKeys.config: $0] } ?? [:])
            return
        }
        if let data = message[SyncKeys.memo] as? Data {
            Self.replyWithMemo(data: data, replyHandler: replyHandler)
            return
        }
        replyHandler([:])
    }

    /// 返信のクロージャを MainActor の中で作らない (CLAUDE.md の「ハマりどころ」)。
    private nonisolated static func replyWithMemo(data: Data, replyHandler: @escaping ([String: Any]) -> Void) {
        let reply = UncheckedSendable(replyHandler)
        Task {
            let saved = await receive(data)
            // 保存できなかったら受領を返さない (時計は transferUserInfo で送り直す)
            reply.value((saved.flatMap { try? JSONEncoder().encode($0) }).map { [SyncKeys.memo: $0] } ?? [:])
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo[SyncKeys.memo] as? Data else { return }
        Task {
            // 受け取れたら写しを返す (時計の「iPhone に渡せた」と、リマインダーの結果)
            if let saved = await Self.receive(data) { self.sendMemo(saved) }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in ConfigStore.shared.resync() }
    }
}

/// 裏で起こされたときに、終わるまで iOS に時間をもらう。時間切れになったら自分で終える (終えないとアプリが止められる)。
@MainActor
final class BackgroundTask {
    private var id: UIBackgroundTaskIdentifier = .invalid

    static func begin(_ name: String) -> BackgroundTask {
        let task = BackgroundTask()
        task.id = UIApplication.shared.beginBackgroundTask(withName: name) { task.end() }
        return task
    }

    func end() {
        guard id != .invalid else { return }
        UIApplication.shared.endBackgroundTask(id)
        id = .invalid
    }
}

/// WatchConnectivity の返信クロージャを Task に渡すための包み (OS のキューから 1 回だけ呼ぶ)。
struct UncheckedSendable<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}
