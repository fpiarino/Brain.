import Foundation
import HealthKit
import SwiftData

/// Legge da Apple Salute (solo lettura) i totali giornalieri per gli obiettivi numerici collegati.
///
/// - Un valore inserito a mano o una pausa non vengono mai sovrascritti.
/// - Il valore di oggi è parziale: lo stato del giorno si decide a giornata finita
///   (tranne le soglie "almeno", che diventano "fatto" appena raggiunte).
/// - Se il permesso non è stato dato, iOS restituisce semplicemente zero dati.
@MainActor
enum HealthSync {
    private static let store = HKHealthStore()
    /// Quanti giorni indietro rileggere a ogni sincronizzazione.
    private static let lookbackDays = 60

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    static func quantityType(for metric: HealthMetric) -> HKQuantityType {
        switch metric {
        case .steps: HKQuantityType(.stepCount)
        case .activeEnergy: HKQuantityType(.activeEnergyBurned)
        case .dietaryEnergy: HKQuantityType(.dietaryEnergyConsumed)
        case .exerciseMinutes: HKQuantityType(.appleExerciseTime)
        }
    }

    static func unit(for metric: HealthMetric) -> HKUnit {
        switch metric {
        case .steps: .count()
        case .activeEnergy, .dietaryEnergy: .kilocalorie()
        case .exerciseMinutes: .minute()
        }
    }

    /// Chiede il permesso di lettura. iOS mostra la richiesta una sola volta per tipo di dato.
    @discardableResult
    static func requestAuthorization(for metrics: [HealthMetric]) async -> Bool {
        guard isAvailable, !metrics.isEmpty else { return false }
        let types: Set<HKObjectType> = Set(metrics.map { quantityType(for: $0) })
        do {
            try await store.requestAuthorization(toShare: [], read: types)
            return true
        } catch {
            return false
        }
    }

    /// Totali giornalieri tra due giorni inclusi.
    static func dailyTotals(_ metric: HealthMetric, from: DayKey, to: DayKey) async throws -> [DayKey: Double] {
        let calendar = Calendar.brain
        let start = from.startDate(calendar: calendar)
        let end = to.adding(days: 1).startDate(calendar: calendar)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: HKSamplePredicate.quantitySample(type: quantityType(for: metric), predicate: predicate),
            options: .cumulativeSum,
            anchorDate: start,
            intervalComponents: DateComponents(day: 1)
        )
        let collection = try await descriptor.result(for: store)
        let healthUnit = unit(for: metric)

        var totals: [DayKey: Double] = [:]
        collection.enumerateStatistics(from: start, to: end) { statistics, _ in
            if let sum = statistics.sumQuantity() {
                totals[DayKey(statistics.startDate, calendar: calendar)] = sum.doubleValue(for: healthUnit)
            }
        }
        return totals
    }

    /// Aggiorna tutti gli obiettivi collegati ad Apple Salute.
    static func sync(using context: ModelContext) async {
        guard isAvailable, !SharedStore.isUITesting else { return }
        let goals = context.activeGoals().filter(\.isHealthLinked)
        guard !goals.isEmpty else { return }

        let today = DayKey.today()
        var changed = false
        for goal in goals {
            guard let metric = goal.healthMetric else { continue }
            let from = max(goal.startDay, today.adding(days: -lookbackDays))
            guard from <= today, let totals = try? await dailyTotals(metric, from: from, to: today) else { continue }
            for (day, value) in totals where day >= goal.startDay && day <= today {
                if context.applyHealthValue(value, for: goal, on: day) {
                    changed = true
                }
            }
        }
        if changed {
            context.saveQuietly()
        }
    }
}
