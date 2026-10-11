import Foundation
import SwiftData

/// Dati di esempio per le anteprime di Xcode (database solo in memoria, mai su disco).
@MainActor
enum PreviewData {
    static let container: ModelContainer = {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        guard let container = try? ModelContainer(for: Goal.self, DayEntry.self, configurations: configuration) else {
            fatalError("Impossibile creare il database di anteprima")
        }
        populate(container.mainContext)
        return container
    }()

    static var sampleGoal: Goal {
        let descriptor = FetchDescriptor<Goal>(sortBy: [SortDescriptor(\.sortOrder)])
        guard let goal = try? container.mainContext.fetch(descriptor).first else {
            fatalError("Nessun obiettivo di anteprima")
        }
        return goal
    }

    private static func populate(_ context: ModelContext) {
        let today = DayKey.today()

        let kcal = Goal(name: "Meno di 1800 kcal", details: "Conto tutto, anche gli snack", emoji: "🥗", color: .orange, startDay: today.adding(days: -26), sortOrder: 0, kind: .numeric)
        kcal.numericTarget = 1800
        kcal.comparison = .atMost
        kcal.unit = "kcal"

        let gym = Goal(name: "Palestra", emoji: "🏋️", color: .teal, startDay: today.adding(days: -40), sortOrder: 1, kind: .weekly)
        gym.weeklyTarget = 3

        let phone = Goal(name: "Niente telefono dopo le 23", emoji: "📵", color: .purple, startDay: today.adding(days: -10), sortOrder: 2)
        let water = Goal(name: "2 litri d'acqua", emoji: "💧", color: .blue, startDay: today.adding(days: 3), sortOrder: 3)

        for goal in [kcal, gym, phone, water] {
            context.insert(goal)
        }

        // Stesso andamento dei mockup, contando a ritroso da oggi (valori in kcal).
        let values: [Double?] = [1650, 1720, 1580, 1790, 1700, nil, 2100, 1950, 1600, 1750, 1680, 1720, 1790, 1640, 2050, 1700, 1690, 1710, 1580, 1620, 1770, 1660, 1740, 1610, nil, 2200, 1690]
        for (offset, value) in values.enumerated() {
            guard let value else { continue }
            context.setValue(value, for: kcal, on: today.adding(days: -offset))
        }
        context.setStatus(.paused, for: kcal, on: today.adding(days: -24))
        context.setNote("Cena di compleanno", for: kcal, on: today.adding(days: -6))

        for offset in 1...40 where [0, 2, 4].contains(offset % 7) {
            context.setStatus(.done, for: gym, on: today.adding(days: -offset))
        }
        for offset in 1...3 {
            context.setStatus(.done, for: phone, on: today.adding(days: -offset))
        }
    }
}
