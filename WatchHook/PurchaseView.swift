import StoreKit
import SwiftUI
import WatchHookCore

/// 購入画面。7 日間の無料お試し (0 円の非消耗型) と買い切り。
///
/// App Review Guidelines 3.1.1: お試しを始める前に「期間」「終わると使えなくなるもの」「続けて使うのに要る支払い」を
/// はっきり示す。ここの文言を変えるときはこの 3 つが残っているか確かめる (docs/BILLING.md)。
struct PurchaseView: View {
    @State private var store = EntitlementStore.shared
    @Environment(\.purchase) private var purchase
    @State private var busy = false

    var body: some View {
        // 画面を開いたままお試しの期限を過ぎても表示が変わるよう、1 分ごとに描き直す (時刻の経過は Observation では届かない)
        TimelineView(.everyMinute) { context in
            content(access: store.access(now: context.date), now: context.date)
        }
        .navigationTitle("購入")
        .task { await store.loadProducts() }
    }

    private func content(access: AccessState, now: Date) -> some View {
        List {
            Section {
                statusRow(access, now: now)
            }

            Section("料金") {
                Bullet("最初の \(StoreProducts.trialDays) 日間は無料で、すべての機能を使えます。お試しは無料の購入として始まり、終わっても自動で課金されません。")
                Bullet("お試しが終わると、Apple Watch・Siri・iPhone の「送る」タブから送れなくなります (送り先のテスト送信も)。送り先の登録と履歴の確認はそのまま使えます。")
                Bullet("続けて使うには、買い切りの購入 (\(unlockPrice)) が 1 回だけ必要です。月額の支払いや追加の請求はありません。")
                Bullet("同じ Apple ID なら、機種変更やアプリの入れ直しのあとも「購入を復元」で戻せます。")
            }

            Section {
                if access == .trialNotStarted {
                    // 3.1.1: お試しの前に、続けて使うのに要る支払い (買い切りの価格) を見せる。価格を読めるまで始めさせない
                    buyButton(StoreProducts.trialID, title: "\(StoreProducts.trialDays) 日間無料で試す", subtitle: "¥0・自動で課金されません",
                              requires: [StoreProducts.unlockID])
                }
                if access != .unlocked {
                    buyButton(StoreProducts.unlockID, title: "買い切りで購入する", subtitle: "\(unlockPrice)・1 回だけの支払い")
                }
                Button("購入を復元") {
                    Task {
                        busy = true
                        await store.restore()
                        busy = false
                    }
                }
                .disabled(busy)
            } footer: {
                if let message = store.message ?? store.productsError {
                    Text(message)
                }
            }
        }
    }

    private var unlockPrice: String {
        store.products[StoreProducts.unlockID]?.displayPrice ?? "価格を読み込み中"
    }

    @ViewBuilder private func statusRow(_ access: AccessState, now: Date) -> some View {
        switch access {
        case .unlocked:
            Label("購入済みです。ありがとうございます", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
        case .trial(let end):
            Label("無料お試し中: あと \(access.daysRemaining(now: now) ?? 0) 日 (\(end.formatted(date: .abbreviated, time: .shortened)) まで)", systemImage: "hourglass")
        case .trialNotStarted:
            Label("まだお試しを始めていません", systemImage: "gift")
        case .trialExpired:
            Label("無料お試しの期間が終わりました", systemImage: "lock.fill").foregroundStyle(.orange)
        }
    }

    private func buyButton(_ id: String, title: String, subtitle: String, requires: [String] = []) -> some View {
        Button {
            guard let product = store.products[id] else { return }
            Task {
                busy = true
                defer { busy = false }
                do {
                    await store.handle(try await purchase(product))
                } catch {
                    store.handle(error: error)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
        .disabled(busy || ([id] + requires).contains { store.products[$0] == nil })
    }
}

/// 送り先の一覧の上に出す、今の状態と購入画面への入口。
struct AccessBanner: View {
    @State private var store = EntitlementStore.shared

    var body: some View {
        TimelineView(.everyMinute) { context in
            let access = store.access(now: context.date)
            if access != .unlocked {
                NavigationLink {
                    PurchaseView()
                } label: {
                    label(access, now: context.date)
                }
            }
        }
    }

    @ViewBuilder private func label(_ access: AccessState, now: Date) -> some View {
        switch access {
        case .unlocked:
            EmptyView()
        case .trial:
            Label("無料お試し中: あと \(access.daysRemaining(now: now) ?? 0) 日", systemImage: "hourglass")
        case .trialNotStarted:
            Label("\(StoreProducts.trialDays) 日間の無料お試しを始める", systemImage: "gift").foregroundStyle(.tint)
        case .trialExpired:
            Label("お試し期間が終わりました。購入すると続けて使えます", systemImage: "lock.fill").foregroundStyle(.orange)
        }
    }
}

private struct Bullet: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Label { Text(text) } icon: { Image(systemName: "circle.fill").font(.system(size: 6)) }
            .font(.subheadline)
    }
}
