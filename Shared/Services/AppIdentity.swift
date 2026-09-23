import Foundation

/// Brand + storage identity for Be Ummati.
enum AppIdentity {
    static let brand = "Be Ummati"
    static let userAgent = "BeUmmati/1.0"
    static let storagePrefix = "beummati."
    static let legacyStoragePrefix = "nur."
    private static let migratedFlag = "beummati.storageMigrated.fromNur.v1"

    /// One-time copy of all `nur.*` UserDefaults keys → `beummati.*` so progress survives the rename.
    static func migrateStorageIfNeeded() {
        let d = UserDefaults.standard
        guard !d.bool(forKey: migratedFlag) else { return }
        for (key, value) in d.dictionaryRepresentation() {
            guard key.hasPrefix(legacyStoragePrefix) else { continue }
            let newKey = storagePrefix + key.dropFirst(legacyStoragePrefix.count)
            if d.object(forKey: newKey) == nil {
                d.set(value, forKey: newKey)
            }
        }
        d.set(true, forKey: migratedFlag)
    }
}
