/// Esito di una settimana (lunedì–domenica) per un obiettivo settimanale.
struct WeekResult: Equatable, Sendable {
    enum State: Equatable, Sendable {
        /// Obiettivo della settimana raggiunto.
        case success
        /// Settimana finita senza raggiungere l'obiettivo.
        case failed
        /// Settimana in corso, obiettivo non ancora raggiunto.
        case inProgress
        /// Nessun giorno disponibile (tutto in pausa o prima della data di inizio): non conta.
        case neutral
    }

    let weekStart: DayKey
    /// Giorni fatti nella settimana.
    let done: Int
    /// Obiettivo effettivo: quello impostato, ridotto se i giorni disponibili sono meno.
    let target: Int
    let state: State

    var weekEnd: DayKey { weekStart.adding(days: 6) }
}

/// Riepilogo di un mese per un obiettivo settimanale. Ogni settimana appartiene
/// al mese in cui cade la sua domenica, così nessuna settimana è contata due volte.
struct WeeklyMonthSummary: Equatable, Sendable {
    let weeks: [WeekResult]
    /// Giorni fatti nel mese (contati giorno per giorno).
    let doneDays: Int

    var succeeded: Int { weeks.filter { $0.state == .success }.count }
    var failed: Int { weeks.filter { $0.state == .failed }.count }
    var evaluated: Int { succeeded + failed }

    var successPercent: Int? {
        evaluated == 0 ? nil : Int((Double(succeeded) / Double(evaluated) * 100).rounded())
    }
}

/// Calcoli per gli obiettivi "N volte a settimana".
///
/// - I giorni disponibili di una settimana sono quelli dalla data di inizio in poi e non in pausa.
///   Se sono meno dell'obiettivo, l'obiettivo della settimana scende di conseguenza.
/// - Una settimana in corso non interrompe la serie; diventa "riuscita" appena raggiunge l'obiettivo.
/// - Una settimana senza giorni disponibili è neutra: non conta e non interrompe la serie.
enum WeeklyStats {

    static func week(
        startingOn weekStart: DayKey,
        entries: [DayKey: DayStatus],
        weeklyTarget: Int,
        startDay: DayKey,
        today: DayKey
    ) -> WeekResult {
        var done = 0
        var available = 0
        for offset in 0..<7 {
            let day = weekStart.adding(days: offset)
            guard day >= startDay else { continue }
            let status = entries[day]
            if status == .paused { continue }
            available += 1
            if status == .done && day <= today { done += 1 }
        }

        let target = min(max(weeklyTarget, 1), available)
        let state: WeekResult.State
        if available == 0 {
            state = .neutral
        } else if done >= target {
            state = .success
        } else if weekStart.adding(days: 6) < today {
            state = .failed
        } else {
            state = .inProgress
        }
        return WeekResult(weekStart: weekStart, done: done, target: target, state: state)
    }

    /// Tutte le settimane dalla settimana della data di inizio a quella di oggi.
    static func weeks(
        entries: [DayKey: DayStatus],
        weeklyTarget: Int,
        startDay: DayKey,
        today: DayKey
    ) -> [WeekResult] {
        guard startDay <= today else { return [] }
        var result: [WeekResult] = []
        var weekStart = startDay.weekStart
        let lastWeek = today.weekStart
        while weekStart <= lastWeek {
            result.append(week(startingOn: weekStart, entries: entries, weeklyTarget: weeklyTarget, startDay: startDay, today: today))
            weekStart = weekStart.adding(days: 7)
        }
        return result
    }

    static func monthSummary(
        entries: [DayKey: DayStatus],
        month: YearMonth,
        weeklyTarget: Int,
        startDay: DayKey,
        today: DayKey
    ) -> WeeklyMonthSummary {
        let monthWeeks = WeeklyStats.weeks(entries: entries, weeklyTarget: weeklyTarget, startDay: startDay, today: today)
            .filter { YearMonth($0.weekEnd) == month }

        var doneDays = 0
        let from = max(month.firstDay, startDay)
        let to = min(month.lastDay, today)
        if from <= to {
            for ordinal in from.ordinal...to.ordinal where entries[DayKey(ordinal: ordinal)] == .done {
                doneDays += 1
            }
        }
        return WeeklyMonthSummary(weeks: monthWeeks, doneDays: doneDays)
    }

    /// Settimane riuscite consecutive fino alla settimana corrente.
    static func currentStreak(entries: [DayKey: DayStatus], weeklyTarget: Int, startDay: DayKey, today: DayKey) -> Streak? {
        let all = weeks(entries: entries, weeklyTarget: weeklyTarget, startDay: startDay, today: today)
        var count = 0
        var first: DayKey?
        var last: DayKey?
        for week in all.reversed() {
            switch week.state {
            case .success:
                count += 1
                first = week.weekStart
                if last == nil { last = week.weekStart }
            case .inProgress, .neutral:
                continue
            case .failed:
                return streak(first: first, last: last, count: count)
            }
        }
        return streak(first: first, last: last, count: count)
    }

    /// Serie record di settimane riuscite. A parità vince la più recente.
    static func bestStreak(entries: [DayKey: DayStatus], weeklyTarget: Int, startDay: DayKey, today: DayKey) -> Streak? {
        var best: Streak?
        var count = 0
        var first: DayKey?
        var last: DayKey?

        func close() {
            if let run = streak(first: first, last: last, count: count),
               best.map({ run.length >= $0.length }) ?? true {
                best = run
            }
            count = 0
            first = nil
            last = nil
        }

        for week in weeks(entries: entries, weeklyTarget: weeklyTarget, startDay: startDay, today: today) {
            switch week.state {
            case .success:
                count += 1
                if first == nil { first = week.weekStart }
                last = week.weekStart
            case .failed:
                close()
            case .inProgress, .neutral:
                break
            }
        }
        close()
        return best
    }

    private static func streak(first: DayKey?, last: DayKey?, count: Int) -> Streak? {
        guard count > 0, let first, let last else { return nil }
        return Streak(start: first, end: last, length: count)
    }
}
