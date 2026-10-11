import SwiftData
import SwiftUI

@main
struct BrainApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = AppModel.shared

    var body: some Scene {
        WindowGroup {
            TodayView()
                // Quando il database viene riaperto (modifiche dal widget) l'interfaccia riparte pulita.
                .id(model.generation)
                .environment(model)
                .tint(.brainTint)
                // Date e selettori sempre in italiano, qualunque sia la lingua del telefono.
                .environment(\.locale, Locale(identifier: "it_IT"))
        }
        .modelContainer(model.container)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.reloadIfChangedByWidget()
            }
        }
    }
}

/// Stato condiviso dell'app: il database aperto e i collegamenti in arrivo
/// da notifiche e widget.
@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    private(set) var container: ModelContainer
    /// Cambia quando il database viene riaperto: ricrea l'interfaccia.
    private(set) var generation = 0
    /// Obiettivo da aprire (da una notifica o dal widget).
    var pendingGoalID: UUID?

    private var lastSeenExternalChange: Double

    private init() {
        container = AppModel.openContainer()
        lastSeenExternalChange = SharedStore.lastExternalChange
    }

    /// Le modifiche fatte dal widget avvengono in un altro processo: per vederle
    /// l'app riapre il database quando torna in primo piano.
    func reloadIfChangedByWidget() {
        let latest = SharedStore.lastExternalChange
        guard latest > lastSeenExternalChange else { return }
        lastSeenExternalChange = latest
        container = AppModel.openContainer()
        generation += 1
    }

    private static func openContainer() -> ModelContainer {
        if let shared = try? SharedStore.makeContainer() {
            return shared
        }
        if let legacy = try? SharedStore.makeLegacyContainer() {
            return legacy
        }
        fatalError("Impossibile aprire il database di Brain")
    }
}
