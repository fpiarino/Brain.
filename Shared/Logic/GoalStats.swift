/// Una serie di giorni (o settimane) riusciti consecutivi.
///
/// `start` e `end` sono il primo e l'ultimo giorno riuscito della serie; tra i due possono
/// esserci giorni in pausa, che non interrompono la serie ma non contano in `length`.
/// Per le serie settimanali `start` e `end` sono i lunedì della prima e dell'ultima settimana.
struct Streak: Equatable, Sendable {
    let start: DayKey
    let end: DayKey
    let length: Int
}

/// Riepilogo di un mese per un obiettivo giornaliero o numerico.
struct MonthSummary: Equatable, Sendable {
    /// Giorni fatti (verdi).
    let done: Int
    /// Giorni non fatti (rossi).
    let missed: Int
    /// Giorni in pausa: esclusi dalla percentuale.
    let paused: Int
    /// Giorni già trascorsi (oggi escluso) senza registrazione: esclusi dalla percentuale.
    let unregistered: Int

    init(done: Int, missed: Int, paused: Int = 0, unregistered: Int) {
        self.done = done
        self.missed = missed
        self.paused = paused
        self.unregistered = unregistered
    }

    var registered: Int { done + missed }

    /// Quota di giorni fatti sui giorni registrati (fatti + non fatti), tra 0 e 1.
    var successRate: Double? {
        registered == 0 ? nil : Double(done) / Double(registered)
    }

    /// Percentuale arrotondata all'intero più vicino (es. 2 su 3 → 67).
    var successPercent: Int? {
        successRate.map { Int(($0 * 100).rounded()) }
    }

    static let empty = MonthSummary(done: 0, missed: 0, paused: 0, unregistered: 0)
}

/// Calcoli per gli obiettivi giornalieri e numerici. Funzioni pure: ricevono gli stati
/// effettivi e la data di oggi, non leggono il database né l'orologio.
///
/// Regole comuni:
/// - contano solo i giorni dalla data di inizio a oggi inclusi;
/// - un giorno non registrato non conta né come fatto né come non fatto;
/// - un giorno in pausa è neutro.
enum GoalStats {

    static func monthSummary(
        entries: [DayKey: DayStatus],
        month: YearMonth,
        startDay: DayKey,
        today: DayKey
    ) -> MonthSummary {
        let from = max(month.firstDay, startDay)
        let to = min(month.lastDay, today)
        guard from <= to else { return .empty }

        var done = 0, missed = 0, paused = 0, unregistered = 0
        for ordinal in from.ordinal...to.ordinal {
            let day = DayKey(ordinal: ordinal)
            switch entries[day] {
            case .done?: done += 1
            case .missed?: missed += 1
            case .paused?: paused += 1
            case nil: if day < today { unregistered += 1 }
            }
        }
        return MonthSummary(done: done, missed: missed, paused: paused, unregistered: unregistered)
    }

    /// Serie attuale di giorni fatti che arriva fino a oggi.
    ///
    /// - Oggi fatto: la serie include oggi.
    /// - Oggi non registrato o in pausa: la serie resta viva e si conta da ieri.
    /// - Oggi non fatto: nessuna serie.
    /// - Giorni in pausa: saltati, non interrompono.
    /// - Giorno passato non registrato o non fatto: interrompe.
    static func currentStreak(entries: [DayKey: DayStatus], startDay: DayKey, today: DayKey) -> Streak? {
        if entries[today] == .missed { return nil }

        var day = entries[today] == .done ? today : today.adding(days: -1)
        var count = 0
        var first: DayKey?
        var last: DayKey?

        while day >= startDay {
            switch entries[day] {
            case .done?:
                count += 1
                first = day
                if last == nil { last = day }
            case .paused?:
                break
            case .missed?, nil:
                return makeStreak(first: first, last: last, count: count)
            }
            day = day.adding(days: -1)
        }
        return makeStreak(first: first, last: last, count: count)
    }

    /// Serie record: la più lunga di sempre. A parità di lunghezza vince la più recente.
    static func bestStreak(entries: [DayKey: DayStatus], startDay: DayKey, today: DayKey) -> Streak? {
        guard startDay <= today else { return nil }

        var best: Streak?
        var count = 0
        var first: DayKey?
        var last: DayKey?

        func close() {
            if let run = makeStreak(first: first, last: last, count: count),
               best.map({ run.length >= $0.length }) ?? true {
                best = run
            }
            count = 0
            first = nil
            last = nil
        }

        for ordinal in startDay.ordinal...today.ordinal {
            let day = DayKey(ordinal: ordinal)
            switch entries[day] {
            case .done?:
                count += 1
                if first == nil { first = day }
                last = day
            case .paused?:
                break
            case .missed?:
                close()
            case nil:
                // Oggi non ancora registrato non chiude la serie.
                if day < today { close() }
            }
        }
        close()
        return best
    }

    /// Totali da sempre (dalla data di inizio a oggi).
    static func totals(entries: [DayKey: DayStatus], startDay: DayKey, today: DayKey) -> MonthSummary {
        guard startDay <= today else { return .empty }
        var done = 0, missed = 0, paused = 0, unregistered = 0
        for ordinal in startDay.ordinal...today.ordinal {
            let day = DayKey(ordinal: ordinal)
            switch entries[day] {
            case .done?: done += 1
            case .missed?: missed += 1
            case .paused?: paused += 1
            case nil: if day < today { unregistered += 1 }
            }
        }
        return MonthSummary(done: done, missed: missed, paused: paused, unregistered: unregistered)
    }

    private static func makeStreak(first: DayKey?, last: DayKey?, count: Int) -> Streak? {
        guard count > 0, let first, let last else { return nil }
        return Streak(start: first, end: last, length: count)
    }
}
