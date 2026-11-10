import Foundation
import Observation
import OSLog
import StoreKit
import WatchHookCore

private let storeLogger = Logger(subsystem: "com.nabettu.watchhook", category: "store")

/// 購入の状態 (7 日間お試し + 買い切り)。判定は WatchHookCore の `EntitlementPolicy`、ここは StoreKit とつなぐだけ。
///
/// - iPhone: StoreKit で購入・復元し、状態が変わったら時計へ知らせる (`onChange`)
/// - 時計: 自分の StoreKit と、iPhone から届いた最新の状態 (`hint`) を合わせて判定する。
///   時計の StoreKit に iPhone での購入が届くまでの間も使えるようにするため
@MainActor
@Observable
final class EntitlementStore {
    static let shared = EntitlementStore()

    /// この端末の StoreKit から読んだ状態。
    private(set) var local = EntitlementSnapshot(trialStartedAt: nil)
    /// iPhone から届いた状態 (時計だけ)。
    private(set) var hint: EntitlementSnapshot? = EntitlementStore.storedHint()
    private(set) var products: [String: Product] = [:]
    private(set) var productsError: String?
    private(set) var message: String?
    /// iPhone で、手元の状態が変わったとき (時計へ送る)。
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    /// refresh が重なったとき (起動・前面化・購入・Transaction.updates)、最後に始めたものの結果だけを使う。
    /// await の間に割り込まれ、先に始めた古い読み取りが後から終わって最新の状態を上書きしないように
    @ObservationIgnored private var refreshGate = LatestRequestGate()

    var snapshot: EntitlementSnapshot { local.merging(hint) }

    func access(now: Date = .now) -> AccessState {
        EntitlementPolicy().state(for: snapshot, now: now)
    }

    /// 起動時に 1 回。取りこぼした取引 (別の端末での購入・承認待ちだった購入・返金) を受け取るため、Transaction.updates を聞き続ける。
    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task.detached {
            for await result in Transaction.updates {
                if case .verified(let t) = result { await t.finish() }
                await EntitlementStore.shared.refresh()
            }
        }
        Task { await refresh() }
    }

    func refresh() async {
        let token = refreshGate.begin()
        let latest = await Self.loadLocal()
        guard refreshGate.isLatest(token), latest != local else { return }
        local = latest
        onChange?()
    }

    // MARK: - App Intent など MainActor の外から

    /// Siri から送るときの判定。画面を開かずに呼ばれるので、毎回 StoreKit から読み直す。
    /// 時刻は読み終えてから取る (読んでいる間に期限を過ぎたら送らない)。
    nonisolated static func currentAccess() async -> AccessState {
        let s = await loadLocal().merging(storedHint())
        return EntitlementPolicy().state(for: s, now: .now)
    }

    nonisolated static func loadLocal() async -> EntitlementSnapshot {
        #if DEBUG
        if let debug = debugOverride() { return debug }
        #endif
        var records: [PurchaseRecord] = []
        for await result in Transaction.currentEntitlements {
            // 署名を確かめられないものは数えない
            guard case .verified(let t) = result else { continue }
            records.append(PurchaseRecord(
                transactionID: t.originalID,
                productID: t.productID,
                originalPurchaseDate: t.originalPurchaseDate,
                isRevoked: t.revocationDate != nil
            ))
        }
        // currentEntitlements には返金済みが出てこない。もう一方の端末が持っている古い「購入済み」を打ち消せるよう、
        // 買い切りの最新の取引が取り消されているかも見る。取引は originalID (端末・復元をまたいで同じ) で突き合わせる
        if case .verified(let t)? = await Transaction.latest(for: StoreProducts.unlockID), t.revocationDate != nil {
            records.append(PurchaseRecord(
                transactionID: t.originalID, productID: t.productID, originalPurchaseDate: t.originalPurchaseDate, isRevoked: true
            ))
        }
        return EntitlementSnapshot(records: records)
    }

    // MARK: - iPhone から届いた状態 (時計)

    private nonisolated static let hintKey = "entitlementHint"

    /// 秘密ではないので UserDefaults に置く (Siri から裏で読むため、再起動しても残す)。
    nonisolated static func storedHint() -> EntitlementSnapshot? {
        UserDefaults.standard.data(forKey: hintKey).flatMap { try? EntitlementSnapshot.decode($0) }
    }

    /// iPhone の最新の状態で置き換える (積み上げない: iPhone で返金されたら戻すため)。
    func receiveHint(_ s: EntitlementSnapshot) {
        guard s != hint else { return }
        hint = s
        if let data = try? s.encoded() { UserDefaults.standard.set(data, forKey: Self.hintKey) }
    }

    // MARK: - 購入 (iPhone)

    func loadProducts() async {
        do {
            let list = try await Product.products(for: StoreProducts.all)
            products = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
            productsError = list.count == StoreProducts.all.count ? nil : "商品の情報を読み込めませんでした"
        } catch {
            storeLogger.error("products failed: \(String(describing: error), privacy: .public)")
            productsError = "商品の情報を読み込めませんでした。通信できる状態でもう一度開いてください"
        }
    }

    /// `@Environment(\.purchase)` で買った結果を受け取る。
    func handle(_ result: Product.PurchaseResult) async {
        switch result {
        case .success(.verified(let t)):
            await t.finish()
            message = nil
        case .success(.unverified):
            message = "購入を確認できませんでした。「購入を復元」を試してください"
        case .pending:
            message = "購入の承認待ちです。承認されると自動で使えるようになります"
        case .userCancelled:
            message = nil
        @unknown default:
            message = nil
        }
        await refresh()
    }

    func handle(error: any Error) {
        storeLogger.error("purchase failed: \(String(describing: error), privacy: .public)")
        message = "購入できませんでした: \(error.localizedDescription)"
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refresh()
            message = snapshot.unlocked || snapshot.trialStartedAt != nil ? "購入を復元しました" : "復元できる購入はありませんでした"
        } catch StoreKitError.userCancelled {
            message = nil
        } catch {
            message = "復元できませんでした: \(error.localizedDescription)"
        }
    }

    #if DEBUG
    /// シミュレータで画面を確かめるとき、StoreKit を通さずに状態を決める (起動引数 `-WatchHookDebugAccess none|trial|expired|unlocked`)。
    /// simctl から起動すると StoreKit の設定ファイル (StoreKit/WatchHook.storekit) が効かないため。
    private nonisolated static func debugOverride() -> EntitlementSnapshot? {
        let day: TimeInterval = 86_400
        switch UserDefaults.standard.string(forKey: "WatchHookDebugAccess") {
        case "none": return EntitlementSnapshot(trialStartedAt: nil)
        case "trial": return EntitlementSnapshot(trialStartedAt: .now.addingTimeInterval(-2 * day))
        case "expired": return EntitlementSnapshot(trialStartedAt: .now.addingTimeInterval(-8 * day))
        case "unlocked": return EntitlementSnapshot(unlockTransactionIDs: [0], trialStartedAt: nil)
        default: return nil
        }
    }
    #endif
}

extension AccessState {
    /// 送れないときに Siri・時計で出す文。
    var blockedMessage: String? {
        switch self {
        case .unlocked, .trial: nil
        case .trialNotStarted: "iPhone の WatchHook で、7 日間の無料お試しを始めるか購入してください。"
        case .trialExpired: "無料お試しの 7 日間が終わりました。iPhone の WatchHook で購入すると続けて使えます。"
        }
    }
}
