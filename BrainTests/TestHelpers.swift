@testable import Brain

/// Giorno da un intero `yyyymmdd`. Interrompe il test se la data non è valida.
func day(_ raw: Int) -> DayKey {
    guard let key = DayKey(rawValue: raw) else {
        preconditionFailure("Data di test non valida: \(raw)")
    }
    return key
}

/// Tutti i giorni da `from` a `to` inclusi.
func days(_ from: Int, through to: Int) -> [DayKey] {
    (day(from).ordinal...day(to).ordinal).map { DayKey(ordinal: $0) }
}

/// Costruisce una mappa di registrazioni.
func makeEntries(done: [DayKey] = [], missed: [DayKey] = []) -> [DayKey: DayStatus] {
    var result: [DayKey: DayStatus] = [:]
    for key in done { result[key] = .done }
    for key in missed { result[key] = .missed }
    return result
}

/// Lo scenario dei mockup: obiettivo iniziato il 15 settembre 2026, oggi è l'11 ottobre 2026.
///
/// Settembre: 15 ✓, 16 ✗, 17 vuoto, 18–26 ✓, 27 ✗, 28–30 ✓
/// Ottobre:   1–3 ✓, 4–5 ✗, 6 vuoto, 7–11 ✓, dal 12 in poi futuro
enum MockupScenario {
    static let startDay = day(20260915)
    static let today = day(20261011)
    static let september = YearMonth(year: 2026, month: 9)
    static let october = YearMonth(year: 2026, month: 10)

    static var entries: [DayKey: DayStatus] {
        let done = [day(20260915)]
            + days(20260918, through: 20260926)
            + days(20260928, through: 20261003)
            + days(20261007, through: 20261011)
        let missed = [day(20260916), day(20260927), day(20261004), day(20261005)]
        return makeEntries(done: done, missed: missed)
    }
}
