import Foundation
import SwiftData
import WidgetKit

/// Dove vive il database e come lo aprono app e widget.
///
/// Il database sta nel contenitore condiviso dell'App Group, così il widget può leggerlo
/// e scriverci. Alla prima apertura della v2 l'app copia lì il database della v1.
/// Se l'App Group non è disponibile (es. firma non riuscita) l'app continua a usare
/// il percorso della v1: tutto funziona, tranne il widget.
enum SharedStore {
    static let schema = Schema([Goal.self, DayEntry.self])
    static let storeFileName = "Brain.store"
    private static let migrationFlag = "brain.migratedToSharedStore"
    private static let externalChangeKey = "brain.lastExternalChange"

    /// Identificativo dell'app senza il suffisso del widget, es. `it.mioprogetto.brain`.
    static var baseBundleIdentifier: String {
        let identifier = Bundle.main.bundleIdentifier ?? "it.mioprogetto.brain"
        for suffix in [".widget", ".tests", ".uitests"] where identifier.hasSuffix(suffix) {
            return String(identifier.dropLast(suffix.count))
        }
        return identifier
    }

    /// Deve coincidere con quello nei file `.entitlements`: `group.$(BRAIN_BUNDLE_BASE)`.
    static var appGroupIdentifier: String { "group." + baseBundleIdentifier }

    static var isRunningInExtension: Bool { Bundle.main.bundlePath.hasSuffix(".appex") }
    static var isUITesting: Bool { ProcessInfo.processInfo.arguments.contains("-uiTesting") }

    static var groupContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    static var groupDefaults: UserDefaults? { UserDefaults(suiteName: appGroupIdentifier) }

    /// Percorso del database della v1: `Application Support/default.store`.
    static var legacyStoreURL: URL {
        URL.applicationSupportDirectory.appending(path: "default.store")
    }

    static var storeURL: URL {
        if let group = groupContainerURL {
            return group.appending(path: storeFileName)
        }
        return legacyStoreURL
    }

    /// Apre il database. Nell'app esegue prima l'eventuale copia dalla v1.
    static func makeContainer() throws -> ModelContainer {
        if isUITesting {
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: memory)
        }
        if !isRunningInExtension {
            migrateLegacyStoreIfNeeded()
        }
        let configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    /// Database della v1 nel suo percorso originale (piano di riserva).
    static func makeLegacyContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, url: legacyStoreURL, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    /// Copia una sola volta il database della v1 nel contenitore condiviso.
    /// Il file originale resta dov'è, come copia di sicurezza.
    static func migrateLegacyStoreIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: migrationFlag), let group = groupContainerURL else { return }

        let fileManager = FileManager.default
        let legacyPath = legacyStoreURL.path(percentEncoded: false)
        guard fileManager.fileExists(atPath: legacyPath) else {
            defaults.set(true, forKey: migrationFlag)
            return
        }

        let targetPath = group.appending(path: storeFileName).path(percentEncoded: false)
        let suffixes = ["", "-wal", "-shm"]
        // Un database vuoto creato dal widget prima della migrazione viene sostituito.
        for suffix in suffixes {
            try? fileManager.removeItem(atPath: targetPath + suffix)
        }
        do {
            for suffix in suffixes where fileManager.fileExists(atPath: legacyPath + suffix) {
                try fileManager.copyItem(atPath: legacyPath + suffix, toPath: targetPath + suffix)
            }
            defaults.set(true, forKey: migrationFlag)
        } catch {
            // Si riproverà al prossimo avvio; intanto si parte dalla copia parziale rimossa.
            for suffix in suffixes {
                try? fileManager.removeItem(atPath: targetPath + suffix)
            }
        }
    }

    // MARK: Modifiche fatte dal widget

    /// Il widget ha scritto nel database: l'app lo rilegge quando torna in primo piano.
    static func markChangedByExtension() {
        groupDefaults?.set(Date().timeIntervalSince1970, forKey: externalChangeKey)
    }

    static var lastExternalChange: Double {
        groupDefaults?.double(forKey: externalChangeKey) ?? 0
    }
}

/// Avvisa widget e app quando i dati cambiano.
enum StoreChangeNotifier {
    static func didSave() {
        if SharedStore.isRunningInExtension {
            SharedStore.markChangedByExtension()
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
