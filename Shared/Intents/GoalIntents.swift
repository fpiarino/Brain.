import AppIntents
import Foundation
import SwiftData

/// Azione dei pulsanti ✓ / ✗ del widget: registra la giornata di oggi senza aprire l'app.
/// Come nell'app, toccare di nuovo lo stesso pulsante riporta a "non registrato".
struct ToggleGoalStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Registra un obiettivo"

    @Parameter(title: "Obiettivo")
    var goalID: String

    @Parameter(title: "Stato")
    var statusRaw: Int

    init() {}

    init(goalID: UUID, status: DayStatus) {
        self.goalID = goalID.uuidString
        self.statusRaw = status.rawValue
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: goalID), let status = DayStatus(rawValue: statusRaw) else {
            return .result()
        }
        let container = try SharedStore.makeContainer()
        let context = ModelContext(container)
        if let goal = context.goal(withID: id) {
            context.toggle(status, for: goal, on: .today())
        }
        return .result()
    }
}
