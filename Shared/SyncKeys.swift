/// iPhone ↔ 時計の同期。applicationContext には版だけを置き (端末に残るため秘密を入れない)、
/// 設定の本体は時計からの sendMessage への返信で渡す (返信は残らない)。
/// 逆向き (時計 → iPhone) の applicationContext には、時計の履歴の写しを置く (iPhone の履歴画面で見せるため)。
enum SyncKeys {
    static let config = "config"
    static let request = "request"
    static let revision = "revision"
    static let epoch = "epoch"
    /// 時計 → iPhone の applicationContext。時計の履歴の写し (`HistorySnapshot` の JSON)。
    static let history = "history"
}
