import SwiftUI

/// Calendario mensile con un pallino per ogni giorno e il riepilogo del mese.
struct MonthCalendarView: View {
    enum Summary {
        /// Obiettivi Sì/No e numerici: conteggi del mese (e media dei valori per i numerici).
        case daily(MonthSummary, average: String?)
        /// Obiettivi settimanali: settimane riuscite.
        case weekly(WeeklyMonthSummary)
    }

    let month: YearMonth
    let entries: [DayKey: DayStatus]
    let notedDays: Set<DayKey>
    let startDay: DayKey
    let today: DayKey
    let summary: Summary
    let valueText: (DayKey) -> String?
    let canGoBack: Bool
    let canGoForward: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onSelect: (DayKey) -> Void

    @ScaledMetric(relativeTo: .caption) private var dotSize: CGFloat = 28

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    init(
        month: YearMonth,
        entries: [DayKey: DayStatus],
        notedDays: Set<DayKey>,
        startDay: DayKey,
        today: DayKey,
        summary: Summary,
        valueText: @escaping (DayKey) -> String?,
        canGoBack: Bool,
        canGoForward: Bool,
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void,
        onSelect: @escaping (DayKey) -> Void
    ) {
        self.month = month
        self.entries = entries
        self.notedDays = notedDays
        self.startDay = startDay
        self.today = today
        self.summary = summary
        self.valueText = valueText
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
        self.onPrevious = onPrevious
        self.onNext = onNext
        self.onSelect = onSelect
    }

    var body: some View {
        VStack(spacing: 10) {
            navigationBar

            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(Array(ItalianFormat.weekdayInitials.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityHidden(true)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(MonthGrid(month: month).cells.enumerated()), id: \.offset) { _, cell in
                    if let day = cell {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 1)
                            .accessibilityHidden(true)
                    }
                }
            }

            Divider()

            summaryView
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Intestazione con frecce

    private var navigationBar: some View {
        HStack {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .disabled(!canGoBack)
            .accessibilityLabel("Mese precedente")

            Spacer()

            Text(ItalianFormat.monthTitle(month))
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .disabled(!canGoForward)
            .accessibilityLabel("Mese successivo")
        }
        .buttonStyle(.borderless)
    }

    // MARK: - Giorno

    @ViewBuilder
    private func dayCell(_ day: DayKey) -> some View {
        let isToday = day == today
        let registrable = day >= startDay && day <= today
        let hasNote = notedDays.contains(day)
        let size = min(dotSize, 40)

        Button {
            onSelect(day)
        } label: {
            VStack(spacing: 3) {
                HStack(spacing: 2) {
                    Text("\(day.day)")
                        .font(.caption2.weight(isToday ? .bold : .regular))
                        .foregroundStyle(isToday ? Color.brainTint : (registrable ? Color.primary : Color.secondary.opacity(0.6)))
                        .monospacedDigit()
                    if hasNote {
                        Circle()
                            .fill(Color.brainTint)
                            .frame(width: 4, height: 4)
                    }
                }

                if registrable {
                    StatusDot(status: entries[day], size: size)
                        .overlay {
                            if isToday {
                                Circle()
                                    .strokeBorder(Color.brainTint, lineWidth: 2)
                                    .padding(-4)
                            }
                        }
                } else {
                    Circle()
                        .fill(Color(uiColor: .systemGray6))
                        .frame(width: size, height: size)
                }
            }
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!registrable)
        .accessibilityLabel(cellLabel(day, isToday: isToday, registrable: registrable, hasNote: hasNote))
        .accessibilityHint(registrable ? "Tocca per registrare o correggere" : "")
    }

    private func cellLabel(_ day: DayKey, isToday: Bool, registrable: Bool, hasNote: Bool) -> String {
        var text = ItalianFormat.dayMonthText(day)
        if isToday { text += ", oggi" }
        if registrable {
            text += ", \(ItalianFormat.statusText(entries[day]))"
            if let value = valueText(day) { text += ", \(value)" }
        } else if day > today {
            text += ", nel futuro"
        } else {
            text += ", prima della data di inizio"
        }
        if hasNote { text += ", con nota" }
        return text
    }

    // MARK: - Riepilogo

    @ViewBuilder
    private var summaryView: some View {
        switch summary {
        case .daily(let monthSummary, let average):
            dailySummary(monthSummary, average: average)
        case .weekly(let weekly):
            weeklySummary(weekly)
        }
    }

    private func dailySummary(_ summary: MonthSummary, average: String?) -> some View {
        VStack(spacing: 10) {
            HStack(alignment: .top) {
                summaryItem(value: "\(summary.done)", label: summary.done == 1 ? "fatto" : "fatti", status: .done)
                summaryItem(value: "\(summary.missed)", label: summary.missed == 1 ? "non fatto" : "non fatti", status: .missed)
                summaryItem(
                    value: summary.successPercent.map { "\($0)%" } ?? "–",
                    label: summary.registered == 0 ? "nessun giorno registrato" : "su \(summary.registered) registrati",
                    status: nil,
                    showsDot: false
                )
            }
            let extra = extraText(paused: summary.paused, average: average)
            if !extra.isEmpty {
                Text(extra)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(dailyAccessibilityText(summary, average: average))
    }

    private func extraText(paused: Int, average: String?) -> String {
        var parts: [String] = []
        if paused > 0 { parts.append(paused == 1 ? "1 giorno in pausa" : "\(paused) giorni in pausa") }
        if let average { parts.append("media \(average)") }
        return parts.joined(separator: " · ")
    }

    private func weeklySummary(_ summary: WeeklyMonthSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                summaryItem(value: "\(summary.succeeded)", label: summary.succeeded == 1 ? "settimana riuscita" : "settimane riuscite", status: .done)
                summaryItem(value: "\(summary.failed)", label: summary.failed == 1 ? "non riuscita" : "non riuscite", status: .missed)
                summaryItem(value: "\(summary.doneDays)", label: summary.doneDays == 1 ? "giorno fatto" : "giorni fatti", status: nil, showsDot: false)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(ItalianFormat.monthTitle(month)): \(summary.succeeded) settimane riuscite, \(summary.failed) non riuscite, \(summary.doneDays) giorni fatti")

            ForEach(summary.weeks, id: \.weekStart) { week in
                HStack(spacing: 10) {
                    StatusDot(status: weekStatus(week), size: 18)
                    Text("Settimana del \(ItalianFormat.shortDayMonthText(week.weekStart))")
                        .font(.footnote)
                    Spacer()
                    Text(weekDetail(week))
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Settimana del \(ItalianFormat.dayMonthText(week.weekStart)): \(weekDetail(week))")
            }
        }
    }

    private func weekStatus(_ week: WeekResult) -> DayStatus? {
        switch week.state {
        case .success: .done
        case .failed: .missed
        case .neutral: .paused
        case .inProgress: nil
        }
    }

    private func weekDetail(_ week: WeekResult) -> String {
        switch week.state {
        case .neutral: "in pausa"
        case .inProgress: "\(week.done) di \(week.target), in corso"
        case .success, .failed: "\(week.done) di \(week.target)"
        }
    }

    private func summaryItem(value: String, label: String, status: DayStatus?, showsDot: Bool = true) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 6) {
                if showsDot {
                    StatusDot(status: status, size: 18)
                }
                Text(value)
                    .font(.title3.bold())
                    .monospacedDigit()
            }
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func dailyAccessibilityText(_ summary: MonthSummary, average: String?) -> String {
        var text = "\(ItalianFormat.monthTitle(month)): \(summary.done) fatti, \(summary.missed) non fatti"
        if let percent = summary.successPercent {
            text += ", successo \(percent) per cento su \(summary.registered) giorni registrati"
        }
        if summary.paused > 0 { text += ", \(ItalianFormat.days(summary.paused)) in pausa" }
        if summary.unregistered > 0 { text += ", \(ItalianFormat.days(summary.unregistered)) non registrati" }
        if let average { text += ", media \(average)" }
        return text
    }
}
