/// Disposizione di un mese in una griglia a 7 colonne che parte dal lunedì.
struct MonthGrid: Equatable, Sendable {
    let month: YearMonth

    /// Caselle vuote prima del giorno 1 (0 se il mese inizia di lunedì).
    var leadingBlanks: Int { month.firstDay.isoWeekday - 1 }

    var days: [DayKey] {
        (1...month.numberOfDays).map { DayKey(year: month.year, month: month.month, day: $0) }
    }

    /// Caselle della griglia: `nil` per le caselle vuote iniziali, poi un giorno per casella.
    var cells: [DayKey?] {
        Array(repeating: nil, count: leadingBlanks) + days.map { Optional($0) }
    }

    /// Numero di righe (settimane) necessarie.
    var numberOfWeeks: Int {
        (leadingBlanks + month.numberOfDays + 6) / 7
    }
}

/// Mappa di calore di un anno: una colonna per settimana (da lunedì a domenica),
/// come il grafico dei contributi di GitHub.
struct YearHeatmap: Equatable, Sendable {
    let year: Int

    var firstDay: DayKey { DayKey(year: year, month: 1, day: 1) }
    var lastDay: DayKey { DayKey(year: year, month: 12, day: 31) }

    /// Colonne di 7 caselle; `nil` per i giorni fuori dall'anno.
    var columns: [[DayKey?]] {
        var result: [[DayKey?]] = []
        var weekStart = firstDay.weekStart
        while weekStart <= lastDay {
            let column: [DayKey?] = (0..<7).map { offset in
                let day = weekStart.adding(days: offset)
                return (day >= firstDay && day <= lastDay) ? day : nil
            }
            result.append(column)
            weekStart = weekStart.adding(days: 7)
        }
        return result
    }
}

/// Andamento per giorno della settimana.
struct WeekdayStat: Equatable, Sendable {
    /// 1 = lunedì … 7 = domenica.
    let weekday: Int
    let done: Int
    let missed: Int

    var registered: Int { done + missed }

    var successPercent: Int? {
        registered == 0 ? nil : Int((Double(done) / Double(registered) * 100).rounded())
    }
}

enum Insights {

    /// Fatti e non fatti per giorno della settimana, dalla data di inizio a oggi.
    /// Pause e giorni non registrati non contano.
    static func weekdayStats(entries: [DayKey: DayStatus], startDay: DayKey, today: DayKey) -> [WeekdayStat] {
        var done = Array(repeating: 0, count: 8)
        var missed = Array(repeating: 0, count: 8)
        if startDay <= today {
            for ordinal in startDay.ordinal...today.ordinal {
                let day = DayKey(ordinal: ordinal)
                switch entries[day] {
                case .done?: done[day.isoWeekday] += 1
                case .missed?: missed[day.isoWeekday] += 1
                default: break
                }
            }
        }
        return (1...7).map { WeekdayStat(weekday: $0, done: done[$0], missed: missed[$0]) }
    }

    /// Il giorno della settimana con la percentuale più bassa (almeno `minimumDays` registrati).
    static func weakestWeekday(_ stats: [WeekdayStat], minimumDays: Int = 3) -> WeekdayStat? {
        stats
            .filter { $0.registered >= minimumDays && $0.successPercent != nil }
            .min { ($0.successPercent ?? 0) < ($1.successPercent ?? 0) }
    }
}

/// Decide in quali giorni pianificare il promemoria serale.
enum ReminderPlanner {

    /// iOS tiene al massimo 64 notifiche in attesa per app: ne usiamo al più 60.
    static let notificationBudget = 60

    /// Quanti giorni pianificare, dato quanti obiettivi ricevono un promemoria al giorno.
    static func horizon(goalsPerDay: Int, maxDays: Int = 14) -> Int {
        let perDay = max(goalsPerDay, 1)
        return min(maxDays, max(1, notificationBudget / perDay))
    }

    /// Giorni per cui pianificare un promemoria, partendo da oggi, per `horizon` giorni.
    ///
    /// Il promemoria di oggi viene saltato se l'orario è già passato oppure se
    /// oggi non c'è più nulla da registrare.
    static func days(
        today: DayKey,
        minutesNow: Int,
        reminderMinutes: Int,
        hasPendingToday: Bool,
        horizon: Int
    ) -> [DayKey] {
        guard horizon > 0 else { return [] }
        let includeToday = hasPendingToday && reminderMinutes > minutesNow
        let firstOffset = includeToday ? 0 : 1
        guard firstOffset < horizon else { return [] }
        return (firstOffset..<horizon).map { today.adding(days: $0) }
    }
}
