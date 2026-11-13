import Foundation
import WatchHookCore

/// 入力した直後に画面に出す結果。メモは保存できたか、この端末から送った webhook は届いたか。
struct MemoFeedback: Equatable {
    /// 演出 (紙飛行機) と振動の分け方に使う
    var status: MessageStatus
    var title: String
    var detail: String?

    /// `memo` が nil なら保存できなかった。
    init(memo: Memo?, role: DeviceRole) {
        guard let memo else {
            status = .failed(reason: "")
            title = String(localized: "保存できませんでした")
            detail = String(localized: "端末に空きがあるか確かめて、もう一度入力してください")
            return
        }
        // 入力した端末から送る webhook だけを見る (リマインダーなどは iPhone が受け取ってから)
        let mine = memo.deliveries.filter { $0.owner == role }
        let failed = mine.compactMap { d -> (String, String)? in
            if case .failed(let reason) = d.status { (d.target.displayName, reason) } else { nil }
        }
        let pending = mine.filter { $0.status.isPending }
        if let first = failed.first {
            status = .failed(reason: first.1)
            title = String(localized: "保存しました。「\(first.0)」に送れませんでした")
            detail = first.1
        } else if !pending.isEmpty {
            status = .pending(attempts: 1, lastError: nil)
            title = String(localized: "保存しました。送れなかった分はあとで送り直します")
            detail = nil
        } else {
            status = .sent(statusCode: 200)
            title = mine.isEmpty ? String(localized: "メモに保存しました") : String(localized: "保存して送りました")
            detail = nil
        }
    }

    #if DEBUG
    init(demo status: MessageStatus) {
        self.status = status
        switch status {
        case .sent: title = String(localized: "保存して送りました")
        case .pending: title = String(localized: "保存しました。送れなかった分はあとで送り直します")
        case .failed(let r): title = r
        }
        detail = nil
    }
    #endif
}

extension DeliveryStatus {
    /// 一覧に出す短い状態。
    func label(isSending: Bool) -> String {
        if isSending { return String(localized: "送信中…") }
        switch self {
        case .pending(let attempts, _):
            return attempts == 0 ? String(localized: "送信待ち") : String(localized: "あとで送り直します")
        case .done: return String(localized: "完了")
        case .failed: return String(localized: "失敗")
        case .cancelled: return String(localized: "取り消し")
        }
    }

    var reason: String? {
        switch self {
        case .pending(_, let e): e
        case .failed(let r): r
        case .done(let d): d
        case .cancelled: nil
        }
    }
}

extension Memo.Summary {
    var label: String {
        switch self {
        case .memoOnly: String(localized: "メモ")
        case .waiting: String(localized: "送信待ち")
        case .someFailed: String(localized: "送れなかったものがあります")
        case .allDone: String(localized: "送信済み")
        }
    }

    var symbol: String {
        switch self {
        case .memoOnly: "note.text"
        case .waiting: "clock.arrow.circlepath"
        case .someFailed: "exclamationmark.circle.fill"
        case .allDone: "checkmark.circle.fill"
        }
    }
}
