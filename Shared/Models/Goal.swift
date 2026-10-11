import Foundation
import SwiftData

/// Un obiettivo.
///
/// Tutte le proprietà hanno un valore predefinito: i campi aggiunti nella v2 vengono
/// creati in automatico sui dati della v1 (migrazione leggera di SwiftData).
@Model
final class Goal {
    var id: UUID = UUID()
    var name: String = ""
    /// Descrizione opzionale (stringa vuota se assente).
    var details: String = ""
    var emoji: String = "🎯"
    var colorKey: String = GoalColor.blue.rawValue
    /// Data di inizio come intero `yyyymmdd`; vedi `startDay`.
    var startDayRaw: Int = 0
    var createdAt: Date = Date()
    /// Valorizzata quando l'obiettivo è archiviato: non compare più in "Oggi".
    var archivedAt: Date? = nil
    var sortOrder: Int = 0

    // MARK: v2

    /// `GoalKind` grezzo: "daily", "weekly", "numeric".
    var kindRaw: String = GoalKind.daily.rawValue
    /// Giorni da fare a settimana (obiettivi settimanali).
    var weeklyTarget: Int = 3
    /// Soglia (obiettivi numerici).
    var numericTarget: Double = 0
    /// `NumericComparison` grezzo: "atMost" o "atLeast".
    var comparisonRaw: String = NumericComparison.atMost.rawValue
    /// Unità mostrata accanto al valore, es. "kcal".
    var unit: String = ""
    /// `HealthMetric` grezzo se il valore arriva da Apple Salute.
    var healthMetricRaw: String? = nil

    @Relationship(deleteRule: .cascade, inverse: \DayEntry.goal)
    var entries: [DayEntry]? = []

    init(
        name: String,
        details: String = "",
        emoji: String = "🎯",
        color: GoalColor = .blue,
        startDay: DayKey = .today(),
        sortOrder: Int = 0,
        kind: GoalKind = .daily
    ) {
        self.id = UUID()
        self.name = name
        self.details = details
        self.emoji = emoji
        self.colorKey = color.rawValue
        self.startDayRaw = startDay.rawValue
        self.createdAt = Date()
        self.sortOrder = sortOrder
        self.kindRaw = kind.rawValue
    }
}

extension Goal {
    var startDay: DayKey {
        get { DayKey(rawValue: startDayRaw) ?? DayKey(createdAt) }
        set { startDayRaw = newValue.rawValue }
    }

    var color: GoalColor {
        get { GoalColor(rawValue: colorKey) ?? .blue }
        set { colorKey = newValue.rawValue }
    }

    var kind: GoalKind {
        get { GoalKind(rawValue: kindRaw) ?? .daily }
        set { kindRaw = newValue.rawValue }
    }

    var comparison: NumericComparison {
        get { NumericComparison(rawValue: comparisonRaw) ?? .atMost }
        set { comparisonRaw = newValue.rawValue }
    }

    var healthMetric: HealthMetric? {
        get { healthMetricRaw.flatMap(HealthMetric.init(rawValue:)) }
        set { healthMetricRaw = newValue?.rawValue }
    }

    var isArchived: Bool { archivedAt != nil }

    /// Il valore arriva da Apple Salute (solo obiettivi numerici).
    var isHealthLinked: Bool { kind == .numeric && healthMetric != nil }

    /// L'obiettivo esiste già in quel giorno (tra la data di inizio e oggi)?
    func canRegister(_ day: DayKey, today: DayKey) -> Bool {
        day >= startDay && day <= today
    }

    // MARK: Dati per giorno

    func entry(on day: DayKey) -> DayEntry? {
        let raw = day.rawValue
        return (entries ?? []).first { $0.dayRaw == raw }
    }

    /// Dati grezzi di ogni giorno.
    var records: [DayKey: DayRecord] {
        var map: [DayKey: DayRecord] = [:]
        for entry in entries ?? [] {
            guard let key = DayKey(rawValue: entry.dayRaw) else { continue }
            map[key] = entry.record
        }
        return map
    }

    /// Stati effettivi (fatto / non fatto / pausa) pronti per i calcoli.
    func statusMap(today: DayKey) -> [DayKey: DayStatus] {
        GoalRules.effectiveStatuses(records, kind: kind, target: numericTarget, comparison: comparison, today: today)
    }

    func status(on day: DayKey, today: DayKey) -> DayStatus? {
        guard let entry = entry(on: day) else { return nil }
        return GoalRules.effectiveStatus(entry.record, kind: kind, target: numericTarget, comparison: comparison, day: day, today: today)
    }

    func value(on day: DayKey) -> Double? {
        entry(on: day)?.value
    }

    func note(on day: DayKey) -> String {
        entry(on: day)?.note ?? ""
    }

    // MARK: Oggi

    /// Settimana corrente (solo obiettivi settimanali).
    func currentWeek(today: DayKey) -> WeekResult {
        WeeklyStats.week(
            startingOn: today.weekStart,
            entries: statusMap(today: today),
            weeklyTarget: weeklyTarget,
            startDay: startDay,
            today: today
        )
    }

    /// Oggi c'è ancora qualcosa da registrare a mano?
    func needsRegistration(today: DayKey) -> Bool {
        guard canRegister(today, today: today) else { return false }
        switch kind {
        case .daily:
            return entry(on: today)?.status == nil
        case .weekly:
            if entry(on: today)?.status != nil { return false }
            return currentWeek(today: today).state != .success
        case .numeric:
            guard !isHealthLinked else { return false }
            let todayEntry = entry(on: today)
            return todayEntry?.value == nil && todayEntry?.status == nil
        }
    }

    /// Colore del segmento di oggi nel riepilogo: fatto, non fatto, pausa o ancora aperto.
    func todayIndicator(today: DayKey) -> DayStatus? {
        let current = status(on: today, today: today)
        if kind == .weekly && current == nil && currentWeek(today: today).state == .success {
            return .done
        }
        return current
    }

    // MARK: Testi

    /// "≤ 1.800 kcal", "≥ 10.000 passi", "3 volte a settimana".
    var targetDescription: String {
        switch kind {
        case .daily:
            return "Ogni giorno"
        case .weekly:
            return weeklyTarget == 1 ? "1 volta a settimana" : "\(weeklyTarget) volte a settimana"
        case .numeric:
            let symbol = comparison == .atMost ? "≤" : "≥"
            return "\(symbol) \(ItalianFormat.number(numericTarget)) \(unit)".trimmingCharacters(in: .whitespaces)
        }
    }

    func formattedValue(_ value: Double) -> String {
        "\(ItalianFormat.number(value)) \(unit)".trimmingCharacters(in: .whitespaces)
    }
}
