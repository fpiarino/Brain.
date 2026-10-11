import Foundation

/// Un giorno di calendario (anno, mese, giorno), indipendente da ora e fuso orario.
///
/// Su disco viene salvato come intero `yyyymmdd` (es. `20261011`): così un giorno
/// registrato resta lo stesso giorno anche se cambi fuso orario viaggiando.
/// L'aritmetica sui giorni usa un numero ordinale (giorni dal 1° gennaio 1970)
/// calcolato con un algoritmo puro, senza `Calendar`: niente sorprese con l'ora legale.
struct DayKey: Hashable, Comparable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        precondition((1...12).contains(month), "Mese non valido: \(month)")
        precondition((1...DayKey.daysInMonth(year: year, month: month)).contains(day), "Giorno non valido: \(day)")
        self.year = year
        self.month = month
        self.day = day
    }

    /// Crea un giorno da un intero `yyyymmdd`. Restituisce `nil` se il valore non è una data valida.
    init?(rawValue: Int) {
        let y = rawValue / 10_000
        let m = (rawValue / 100) % 100
        let d = rawValue % 100
        guard rawValue > 0, (1...12).contains(m), (1...DayKey.daysInMonth(year: y, month: m)).contains(d) else {
            return nil
        }
        self.init(year: y, month: m, day: d)
    }

    /// Crea un giorno dal numero di giorni trascorsi dal 1° gennaio 1970.
    init(ordinal: Int) {
        let c = DayKey.civil(fromOrdinal: ordinal)
        self.init(year: c.year, month: c.month, day: c.day)
    }

    /// Il giorno di calendario a cui appartiene `date` nel calendario indicato.
    init(_ date: Date, calendar: Calendar = .brain) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year ?? 1970, month: c.month ?? 1, day: c.day ?? 1)
    }

    static func today(calendar: Calendar = .brain) -> DayKey {
        DayKey(Date(), calendar: calendar)
    }

    /// Valore salvato su disco, es. `20261011`.
    var rawValue: Int { year * 10_000 + month * 100 + day }

    /// Giorni trascorsi dal 1° gennaio 1970 (negativo per date precedenti).
    var ordinal: Int { DayKey.ordinal(year: year, month: month, day: day) }

    /// Giorno della settimana ISO: 1 = lunedì … 7 = domenica.
    var isoWeekday: Int {
        // Il 1° gennaio 1970 (ordinale 0) era un giovedì (4).
        let mod = ((ordinal % 7) + 7) % 7
        return (mod + 3) % 7 + 1
    }

    func adding(days: Int) -> DayKey {
        DayKey(ordinal: ordinal + days)
    }

    /// Mezzanotte di questo giorno nel calendario indicato.
    func startDate(calendar: Calendar = .brain) -> Date {
        let components = DateComponents(year: year, month: month, day: day)
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    // MARK: - Calendario gregoriano

    static func isLeapYear(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    static func daysInMonth(year: Int, month: Int) -> Int {
        switch month {
        case 1, 3, 5, 7, 8, 10, 12: return 31
        case 4, 6, 9, 11: return 30
        case 2: return isLeapYear(year) ? 29 : 28
        default: return 0
        }
    }

    /// Algoritmo "days from civil" di Howard Hinnant.
    private static func ordinal(year: Int, month: Int, day: Int) -> Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yearOfEra = y - era * 400
        let shiftedMonth = (month + 9) % 12 // marzo = 0 … febbraio = 11
        let dayOfYear = (153 * shiftedMonth + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }

    /// Algoritmo "civil from days" di Howard Hinnant.
    private static func civil(fromOrdinal ordinal: Int) -> (year: Int, month: Int, day: Int) {
        let z = ordinal + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let dayOfEra = z - era * 146_097
        let yearOfEra = (dayOfEra - dayOfEra / 1_460 + dayOfEra / 36_524 - dayOfEra / 146_096) / 365
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let shiftedMonth = (5 * dayOfYear + 2) / 153
        let day = dayOfYear - (153 * shiftedMonth + 2) / 5 + 1
        let month = shiftedMonth < 10 ? shiftedMonth + 3 : shiftedMonth - 9
        let year = yearOfEra + era * 400 + (month <= 2 ? 1 : 0)
        return (year, month, day)
    }
}

extension DayKey: Identifiable {
    var id: Int { rawValue }
}

extension Calendar {
    /// Calendario gregoriano nel fuso orario attuale del telefono, settimana da lunedì.
    /// Usato al posto di `Calendar.current` perché chi ha impostato un calendario
    /// diverso (es. buddista) avrebbe numeri di anno diversi.
    static var brain: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        calendar.locale = Locale(identifier: "it_IT")
        calendar.firstWeekday = 2
        return calendar
    }
}
