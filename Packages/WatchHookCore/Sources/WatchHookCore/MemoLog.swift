import Foundation

/// 端末に保存するメモの一覧 (新しい順) と、連携の送信待ち。時計と iPhone で同じものを使う。
/// 時計は件数に上限を付け (直近 50 件)、iPhone は全部持つ (メモの正は iPhone。docs/FREE_OSS.md)。
public struct MemoLog: Codable, Hashable, Sendable {
    public private(set) var memos: [Memo] = []
    /// 消したメモの ID と消した日時。遅れて届いた写しで戻さないため
    public private(set) var tombstones: [UUID: Date] = [:]
    /// この一覧を持つ端末。自分が受け持つ連携だけ送り、状態を変える
    public var owner: DeviceRole
    public var maxAttempts: Int
    /// nil なら上限なし
    public var capacity: Int?

    /// 墓標の上限。古いものから捨てる (遅れて届く写しは、ふつう数日のうちに届く)
    static let maxTombstones = 2000

    public init(owner: DeviceRole, maxAttempts: Int = 5, capacity: Int? = 50) {
        self.owner = owner
        self.maxAttempts = maxAttempts
        self.capacity = capacity
    }

    public struct DeliveryRef: Hashable, Sendable {
        public var memoID: UUID
        public var deliveryID: UUID

        public init(memoID: UUID, deliveryID: UUID) {
            self.memoID = memoID
            self.deliveryID = deliveryID
        }
    }

    /// 自分が受け持つ送信待ち。古いメモから。
    public var pendingDeliveries: [DeliveryRef] {
        memos.reversed().flatMap { memo in
            memo.deliveries
                .filter { $0.owner == owner && $0.status.isPending }
                .map { DeliveryRef(memoID: memo.id, deliveryID: $0.id) }
        }
    }

    public func memo(id: UUID) -> Memo? {
        memos.first { $0.id == id }
    }

    public func delivery(_ ref: DeliveryRef) -> Delivery? {
        memo(id: ref.memoID)?.deliveries.first { $0.id == ref.deliveryID }
    }

    public func isDeleted(_ id: UUID) -> Bool {
        tombstones[id] != nil
    }

    public mutating func add(_ memo: Memo) {
        guard !isDeleted(memo.id), self.memo(id: memo.id) == nil else { return }
        memos.append(memo)
        sortAndTrim()
    }

    /// 結果を反映し、反映後の状態を返す。自分が受け持たない連携・見つからない連携は変えずに nil。
    @discardableResult
    public mutating func apply(_ outcome: DeliveryOutcome, memoID: UUID, deliveryID: UUID) -> DeliveryStatus? {
        guard let (m, d) = index(memoID, deliveryID), memos[m].deliveries[d].owner == owner else { return nil }
        var delivery = memos[m].deliveries[d]
        switch outcome {
        case .cancelled:
            return delivery.status
        case .done(let detail):
            delivery.status = .done(detail: detail)
        case .permanent(let reason):
            delivery.status = .failed(reason: reason)
        case .retryable(let reason):
            let attempts: Int
            if case .pending(let a, _) = delivery.status { attempts = a + 1 } else { attempts = 1 }
            delivery.status = attempts >= maxAttempts ? .failed(reason: reason) : .pending(attempts: attempts, lastError: reason)
        }
        delivery.revision += 1
        memos[m].deliveries[d] = delivery
        sortAndTrim()
        return delivery.status
    }

    /// 手動で送り直す。自分が受け持ち、まだ終わっていないもの (待ち・失敗) だけ。送れたもの・取り消したものは戻さない。
    @discardableResult
    public mutating func retry(memoID: UUID, deliveryID: UUID) -> Bool {
        guard let (m, d) = index(memoID, deliveryID), memos[m].deliveries[d].owner == owner else { return false }
        switch memos[m].deliveries[d].status {
        case .done, .cancelled: return false
        case .pending, .failed: break
        }
        memos[m].deliveries[d].status = .pending(attempts: 0, lastError: nil)
        memos[m].deliveries[d].revision += 1
        return true
    }

    /// 後から送る (iPhone のメモ詳細から) など、既にあるメモに連携を足す。
    public mutating func addDelivery(_ delivery: Delivery, to memoID: UUID) {
        guard let m = memos.firstIndex(where: { $0.id == memoID }),
              !memos[m].deliveries.contains(where: { $0.id == delivery.id }) else { return }
        memos[m].deliveries.append(delivery)
    }

    /// 消す。自分が受け持つ未送信は取り消しにして、消したメモ (取り消し後) を返す。
    /// 送っている最中のものは止められないので、呼び出し側は結果が返ってきても反映しない (メモが見つからないので `apply` は nil)。
    @discardableResult
    public mutating func remove(memoID: UUID, at date: Date = Date()) -> Memo? {
        tombstones[memoID] = date
        trimTombstones()
        guard let m = memos.firstIndex(where: { $0.id == memoID }) else { return nil }
        var memo = memos.remove(at: m)
        for d in memo.deliveries.indices where memo.deliveries[d].owner == owner && memo.deliveries[d].status.isPending {
            memo.deliveries[d].status = .cancelled
            memo.deliveries[d].revision += 1
        }
        return memo
    }

    /// 保存しきれなかったメモを、消した記録 (墓標) を残さずに取り除く (あとで送り直されたら受け取れるように)。
    public mutating func discard(memoID: UUID) {
        memos.removeAll { $0.id == memoID }
    }

    public mutating func markPhoneSynced(_ memoID: UUID) {
        guard let m = memos.firstIndex(where: { $0.id == memoID }), memos[m].phoneSync == .waiting else { return }
        memos[m].phoneSync = .delivered
        sortAndTrim()
    }

    public enum MergeResult: Equatable, Sendable {
        case inserted
        case updated
        case unchanged
        /// 消したメモ・知らないメモ (足さない指定のとき)
        case ignored
    }

    /// 相手の端末から届いた写しを合わせる。連携ごとに版の大きいほうを取り、知らない連携は足す。
    /// 自分が受け持つ連携は自分の状態が正なので変えない。本文・端末だけの状態 (`phoneSync`) も変えない。
    @discardableResult
    public mutating func merge(_ remote: Memo, insertIfMissing: Bool) -> MergeResult {
        guard !isDeleted(remote.id) else { return .ignored }
        guard let m = memos.firstIndex(where: { $0.id == remote.id }) else {
            guard insertIfMissing else { return .ignored }
            var copy = remote
            copy.phoneSync = nil
            memos.append(copy)
            sortAndTrim()
            return .inserted
        }
        var changed = false
        for theirs in remote.deliveries {
            if let d = memos[m].deliveries.firstIndex(where: { $0.id == theirs.id }) {
                let mine = memos[m].deliveries[d]
                guard mine.owner != owner, theirs.revision > mine.revision else { continue }
                memos[m].deliveries[d] = theirs
                changed = true
            } else {
                memos[m].deliveries.append(theirs)
                changed = true
            }
        }
        if changed { sortAndTrim() }
        return changed ? .updated : .unchanged
    }

    private func index(_ memoID: UUID, _ deliveryID: UUID) -> (Int, Int)? {
        guard let m = memos.firstIndex(where: { $0.id == memoID }),
              let d = memos[m].deliveries.firstIndex(where: { $0.id == deliveryID }) else { return nil }
        return (m, d)
    }

    /// 新しい順に並べ、上限を超えた分を消す。新しい `capacity` 件は必ず残し、それより古いものは
    /// 自分が受け持つ送信待ちと、iPhone に渡せていないものだけ残す (新しく入れたものが消えることはない)。
    private mutating func sortAndTrim() {
        memos.sort { $0.createdAt > $1.createdAt }
        guard let capacity, memos.count > capacity else { return }
        let keepNewest = memos.prefix(capacity)
        let older = memos.dropFirst(capacity).filter { memo in
            memo.phoneSync == .waiting || memo.deliveries.contains { $0.owner == owner && $0.status.isPending }
        }
        memos = Array(keepNewest) + older
    }

    private mutating func trimTombstones() {
        guard tombstones.count > Self.maxTombstones else { return }
        let drop = tombstones.sorted { $0.value < $1.value }.prefix(tombstones.count - Self.maxTombstones)
        for (id, _) in drop { tombstones[id] = nil }
    }
}

extension MemoLog {
    /// 前の形式 (送り先 1 つへの送信の履歴) から移す。1 件を、連携 1 つのメモにする。
    /// リマインダー・Markdown は付けない (昔の入力を今から足さない)。時計の分は iPhone に渡し直す。
    public init(migrating legacy: MessageLog, owner: DeviceRole, capacity: Int? = 50) {
        self.init(owner: owner, capacity: capacity)
        for entry in legacy.entries {
            let status: DeliveryStatus = switch entry.status {
            case .sent(let code): .done(detail: "HTTP \(code)")
            case .pending(let attempts, let error): .pending(attempts: attempts, lastError: error)
            case .failed(let reason): .failed(reason: reason)
            }
            let delivery = Delivery(target: .webhook(destinationID: entry.message.destinationID, name: entry.destinationName),
                                    owner: owner, text: entry.message.text, status: status, revision: 1)
            memos.append(Memo(id: entry.message.id, text: entry.message.text, createdAt: entry.message.createdAt,
                              source: entry.message.source, origin: owner, deliveries: [delivery],
                              phoneSync: owner == .watch ? .waiting : nil, wantsPhoneIntegrations: false))
        }
        sortAndTrim()
    }
}
