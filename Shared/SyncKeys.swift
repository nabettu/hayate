/// iPhone ↔ 時計の同期。applicationContext には版だけを置き (端末に残るため秘密を入れない)、
/// 設定の本体は時計からの sendMessage への返信で渡す (返信は残らない)。
/// メモは時計 → iPhone へ全文を送り (メモの正は iPhone)、iPhone は時計で入力したメモの写しを返す (受領の知らせを兼ねる)。
enum SyncKeys {
    static let config = "config"
    static let request = "request"
    static let revision = "revision"
    static let epoch = "epoch"
    /// メモ 1 件 (`Memo` の JSON)。sendMessage・その返信・transferUserInfo で使う
    static let memo = "memo"
    /// iPhone で消したメモの ID (UUID の文字列)
    static let deletedMemo = "deletedMemo"
}
