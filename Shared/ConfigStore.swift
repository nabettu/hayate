import Foundation
import Observation
import WatchHookCore

/// 送り先の設定の読み書き。iPhone では編集して時計へ送り、時計では iPhone から届いたものを保存する。
@MainActor
@Observable
final class ConfigStore {
    static let shared = ConfigStore()

    private(set) var config: DestinationConfig
    /// 保存したあとに呼ばれる (iPhone ではここで時計へ送る)。
    @ObservationIgnored var onChange: ((DestinationConfig) -> Void)?

    private nonisolated static let keychain = KeychainStore(service: "com.nabettu.watchhook", account: "destination-config")

    init() {
        config = Self.loadFromKeychain()
    }

    /// App Intent など、MainActor の外から最新の設定を読むとき。
    nonisolated static func loadFromKeychain() -> DestinationConfig {
        guard let data = keychain.load(), let c = try? DestinationConfig.decode(data) else {
            return DestinationConfig()
        }
        return c
    }

    func update(_ newValue: DestinationConfig, notify: Bool = true) {
        config = newValue
        if let data = try? newValue.encoded() {
            Self.keychain.save(data)
        }
        if notify { onChange?(newValue) }
    }

    func upsert(_ destination: Destination) {
        var c = config
        if let i = c.destinations.firstIndex(where: { $0.id == destination.id }) {
            c.destinations[i] = destination
        } else {
            c.destinations.append(destination)
            if c.defaultDestinationID == nil { c.defaultDestinationID = destination.id }
        }
        update(c)
    }

    func delete(_ id: UUID) {
        var c = config
        c.destinations.removeAll { $0.id == id }
        if c.defaultDestinationID == id { c.defaultDestinationID = c.destinations.first?.id }
        update(c)
    }

    func setDefault(_ id: UUID) {
        var c = config
        c.defaultDestinationID = id
        update(c)
    }
}
