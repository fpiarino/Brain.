import Foundation

/// Tipo di obiettivo.
enum GoalKind: String, CaseIterable, Codable, Sendable {
    /// Sì / no ogni giorno.
    case daily
    /// Almeno N giorni fatti a settimana (lunedì–domenica).
    case weekly
    /// Un valore al giorno confrontato con una soglia (es. kcal ≤ 1800).
    case numeric
}

/// Come confrontare il valore di un obiettivo numerico con la soglia.
enum NumericComparison: String, CaseIterable, Codable, Sendable {
    case atMost
    case atLeast

    func isMet(value: Double, target: Double) -> Bool {
        switch self {
        case .atMost: value <= target
        case .atLeast: value >= target
        }
    }
}

/// Dato di Apple Salute che può compilare da solo un obiettivo numerico.
enum HealthMetric: String, CaseIterable, Codable, Sendable {
    case steps
    case activeEnergy
    case dietaryEnergy
    case exerciseMinutes

    var unit: String {
        switch self {
        case .steps: "passi"
        case .activeEnergy, .dietaryEnergy: "kcal"
        case .exerciseMinutes: "min"
        }
    }

    var displayName: String {
        switch self {
        case .steps: "Passi"
        case .activeEnergy: "Calorie attive"
        case .dietaryEnergy: "Calorie assunte"
        case .exerciseMinutes: "Minuti di esercizio"
        }
    }

    var suggestedComparison: NumericComparison {
        self == .dietaryEnergy ? .atMost : .atLeast
    }
}

/// Quello che è salvato per un giorno, prima di applicare le regole del tipo di obiettivo.
struct DayRecord: Equatable, Sendable {
    /// Stato scelto a mano (`nil` se non c'è, o se per i numerici conta il valore).
    var status: DayStatus?
    /// Valore per gli obiettivi numerici.
    var value: Double?
    /// Il valore viene da Apple Salute.
    var fromHealth: Bool

    init(status: DayStatus? = nil, value: Double? = nil, fromHealth: Bool = false) {
        self.status = status
        self.value = value
        self.fromHealth = fromHealth
    }
}

/// Regole che trasformano i dati salvati nello stato effettivo di ogni giorno.
enum GoalRules {

    /// Stato effettivo di un giorno.
    ///
    /// - La pausa vale per ogni tipo di obiettivo.
    /// - Obiettivi numerici: conta il valore. Un valore inserito a mano dà subito fatto/non fatto.
    ///   Un valore di Apple Salute per **oggi** è ancora parziale: diventa "fatto" appena
    ///   raggiunge una soglia "almeno", altrimenti resta in corso (non registrato) fino a domani.
    /// - Se un numerico non ha valore si usa lo stato salvato (utile se il tipo è cambiato).
    static func effectiveStatus(
        _ record: DayRecord,
        kind: GoalKind,
        target: Double,
        comparison: NumericComparison,
        day: DayKey,
        today: DayKey
    ) -> DayStatus? {
        if record.status == .paused { return .paused }
        guard kind == .numeric, let value = record.value else { return record.status }

        let met = comparison.isMet(value: value, target: target)
        if record.fromHealth && day >= today {
            return (met && comparison == .atLeast) ? .done : nil
        }
        return met ? .done : .missed
    }

    static func effectiveStatuses(
        _ records: [DayKey: DayRecord],
        kind: GoalKind,
        target: Double,
        comparison: NumericComparison,
        today: DayKey
    ) -> [DayKey: DayStatus] {
        var result: [DayKey: DayStatus] = [:]
        for (day, record) in records {
            if let status = effectiveStatus(record, kind: kind, target: target, comparison: comparison, day: day, today: today) {
                result[day] = status
            }
        }
        return result
    }

    /// Interpreta un numero scritto all'italiana ("1.800", "1800", "7,5").
    static func parseNumber(_ text: String) -> Double? {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "")
        guard !cleaned.isEmpty else { return nil }
        if cleaned.contains(",") {
            // Virgola decimale: i punti sono separatori delle migliaia.
            cleaned = cleaned.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        } else if cleaned.filter({ $0 == "." }).count > 1 {
            cleaned = cleaned.replacingOccurrences(of: ".", with: "")
        } else if let dot = cleaned.firstIndex(of: "."), cleaned.distance(from: dot, to: cleaned.endIndex) == 4 {
            // "1.800": un solo punto seguito da tre cifre = migliaia.
            cleaned = cleaned.replacingOccurrences(of: ".", with: "")
        }
        guard let value = Double(cleaned), value.isFinite, value >= 0 else { return nil }
        return value
    }
}
