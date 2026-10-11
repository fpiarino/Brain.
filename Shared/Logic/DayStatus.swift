/// Stato effettivo di un obiettivo in un giorno.
///
/// Il quarto stato, "non registrato", non ha un valore: è l'assenza di un dato.
/// - `done` / `missed`: contano nella percentuale e nelle serie.
/// - `paused`: giorno neutro (malattia, viaggio…). Non entra nella percentuale,
///   non interrompe la serie e non la allunga.
enum DayStatus: Int, Sendable, CaseIterable, Codable {
    case missed = 0
    case done = 1
    case paused = 2
}

/// Un mese di calendario (anno + mese), usato dalla navigazione del calendario.
struct YearMonth: Hashable, Comparable, Sendable {
    let year: Int
    let month: Int

    init(year: Int, month: Int) {
        precondition((1...12).contains(month), "Mese non valido: \(month)")
        self.year = year
        self.month = month
    }

    init(_ day: DayKey) {
        self.init(year: day.year, month: day.month)
    }

    var firstDay: DayKey { DayKey(year: year, month: month, day: 1) }
    var lastDay: DayKey { DayKey(year: year, month: month, day: numberOfDays) }
    var numberOfDays: Int { DayKey.daysInMonth(year: year, month: month) }

    func adding(months: Int) -> YearMonth {
        let index = year * 12 + (month - 1) + months
        let newYear = Int((Double(index) / 12).rounded(.down))
        return YearMonth(year: newYear, month: index - newYear * 12 + 1)
    }

    static func < (lhs: YearMonth, rhs: YearMonth) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }
}

extension DayKey {
    /// Lunedì della settimana a cui appartiene questo giorno.
    var weekStart: DayKey { adding(days: -(isoWeekday - 1)) }
}
