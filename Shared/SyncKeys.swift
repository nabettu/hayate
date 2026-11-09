/// iPhone ↔ 時計の同期。applicationContext には版だけを置き (端末に残るため秘密を入れない)、
/// 設定の本体は時計からの sendMessage への返信で渡す (返信は残らない)。
enum SyncKeys {
    static let config = "config"
    static let request = "request"
    static let revision = "revision"
    static let epoch = "epoch"
}
