import SwiftData
import SwiftUI

/// Dettaglio di un obiettivo: serie, calendario del mese con riepilogo, note e statistiche.
struct GoalDetailView: View {
    let goal: Goal
    let today: DayKey
    /// Chiamato quando l'utente conferma l'eliminazione: chi mostra la schermata
    /// torna indietro e poi elimina l'obiettivo.
    let onDelete: (Goal) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var month: YearMonth
    @State private var selectedDay: DayKey?
    @State private var showingEditor = false
    @State private var deleteRequested = false
    @State private var isSyncingHealth = false

    init(goal: Goal, today: DayKey, onDelete: @escaping (Goal) -> Void) {
        self.goal = goal
        self.today = today
        self.onDelete = onDelete
        _month = State(initialValue: YearMonth(today))
    }

    var body: some View {
        if goal.isDeleted {
            Color.clear
        } else {
            content
        }
    }

    private var content: some View {
        let entries = goal.statusMap(today: today)

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                streakCards(entries: entries)

                MonthCalendarView(
                    month: month,
                    entries: entries,
                    notedDays: notedDays,
                    startDay: goal.startDay,
                    today: today,
                    summary: calendarSummary(entries: entries),
                    valueText: { day in goal.value(on: day).map { goal.formattedValue($0) } },
                    canGoBack: month > earliestMonth,
                    canGoForward: month < YearMonth(today),
                    onPrevious: { month = month.adding(months: -1) },
                    onNext: { month = month.adding(months: 1) },
                    onSelect: { selectedDay = $0 }
                )

                Text("Tocca un giorno per registrarlo, correggerlo, metterlo in pausa o aggiungere una nota.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)

                if goal.isHealthLinked {
                    healthCard
                }

                notesSection

                NavigationLink {
                    GoalInsightsView(goal: goal, today: today)
                } label: {
                    HStack {
                        Label("Statistiche", systemImage: "chart.bar.xaxis")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 50)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(goal.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Il nome è già nell'intestazione grande: la barra resta pulita.
            ToolbarItem(placement: .principal) { Text("") }
            ToolbarItem(placement: .primaryAction) {
                Button("Modifica") { showingEditor = true }
            }
        }
        .sheet(item: $selectedDay) { day in
            DayStatusSheet(goal: goal, day: day, today: today)
        }
        .sheet(isPresented: $showingEditor, onDismiss: {
            if deleteRequested {
                deleteRequested = false
                onDelete(goal)
            }
        }) {
            GoalEditorView(mode: .edit(goal), onDelete: { deleteRequested = true })
        }
    }

    // MARK: - Intestazione e serie

    private var header: some View {
        HStack(spacing: 14) {
            GoalChip(emoji: goal.emoji, color: goal.color, size: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(goal.name)
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                Text(headerSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 4)
    }

    private var headerSubtitle: String {
        var parts: [String] = []
        let details = goal.details.trimmingCharacters(in: .whitespacesAndNewlines)
        if !details.isEmpty { parts.append(details) }
        if goal.kind != .daily { parts.append(goal.targetDescription) }
        let start = goal.startDay
        parts.append(start > today ? "inizia il \(ItalianFormat.fullDateText(start))" : "dal \(ItalianFormat.fullDateText(start))")
        if goal.isArchived { parts.append("archiviato") }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func streakCards(entries: [DayKey: DayStatus]) -> some View {
        if goal.kind == .weekly {
            let current = WeeklyStats.currentStreak(entries: entries, weeklyTarget: goal.weeklyTarget, startDay: goal.startDay, today: today)
            let best = WeeklyStats.bestStreak(entries: entries, weeklyTarget: goal.weeklyTarget, startDay: goal.startDay, today: today)
            HStack(alignment: .top, spacing: 10) {
                StreakCard(title: "Serie attuale", value: current?.length ?? 0, unit: .weeks,
                           caption: current.map { "dalla settimana del \(ItalianFormat.shortDayMonthText($0.start))" } ?? "Nessuna serie in corso")
                StreakCard(title: "Record", value: best?.length ?? 0, unit: .weeks,
                           caption: best.map { "dalla settimana del \(ItalianFormat.shortDayMonthText($0.start))" } ?? "Ancora nessuno")
            }
        } else {
            let current = GoalStats.currentStreak(entries: entries, startDay: goal.startDay, today: today)
            let best = GoalStats.bestStreak(entries: entries, startDay: goal.startDay, today: today)
            HStack(alignment: .top, spacing: 10) {
                StreakCard(title: "Serie attuale", value: current?.length ?? 0, unit: .days,
                           caption: current.map { "dal \(ItalianFormat.dayMonthText($0.start))" } ?? "Nessuna serie in corso")
                StreakCard(title: "Record", value: best?.length ?? 0, unit: .days,
                           caption: best.map(recordCaption) ?? "Ancora nessuno")
            }
        }
    }

    private func recordCaption(_ streak: Streak) -> String {
        if streak.start == streak.end { return ItalianFormat.dayMonthText(streak.start) }
        return "\(ItalianFormat.shortDayMonthText(streak.start)) – \(ItalianFormat.shortDayMonthText(streak.end))"
    }

    // MARK: - Calendario

    private func calendarSummary(entries: [DayKey: DayStatus]) -> MonthCalendarView.Summary {
        switch goal.kind {
        case .weekly:
            return .weekly(WeeklyStats.monthSummary(entries: entries, month: month, weeklyTarget: goal.weeklyTarget, startDay: goal.startDay, today: today))
        case .daily:
            return .daily(GoalStats.monthSummary(entries: entries, month: month, startDay: goal.startDay, today: today), average: nil)
        case .numeric:
            return .daily(GoalStats.monthSummary(entries: entries, month: month, startDay: goal.startDay, today: today), average: monthAverage)
        }
    }

    /// Media dei valori del mese (giorni finiti, pause escluse).
    private var monthAverage: String? {
        let values = (goal.entries ?? []).compactMap { entry -> Double? in
            guard let day = DayKey(rawValue: entry.dayRaw), YearMonth(day) == month,
                  day < today || !entry.fromHealth, entry.status != .paused else { return nil }
            return entry.value
        }
        guard !values.isEmpty else { return nil }
        return goal.formattedValue(values.reduce(0, +) / Double(values.count))
    }

    private var notedDays: Set<DayKey> {
        Set((goal.entries ?? []).compactMap { entry in
            entry.note.isEmpty ? nil : DayKey(rawValue: entry.dayRaw)
        })
    }

    /// Primo mese navigabile: quello della data di inizio (o il mese corrente se l'inizio è nel futuro).
    private var earliestMonth: YearMonth {
        min(YearMonth(goal.startDay), YearMonth(today))
    }

    // MARK: - Apple Salute e note

    private var healthCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "heart.fill")
                .foregroundStyle(Color.statusMissed)
                .accessibilityHidden(true)
            Text("I valori arrivano da Apple Salute. Un valore inserito a mano ha la precedenza.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button {
                Task {
                    isSyncingHealth = true
                    await HealthSync.requestAuthorization(for: goal.healthMetric.map { [$0] } ?? [])
                    await HealthSync.sync(using: modelContext)
                    isSyncingHealth = false
                }
            } label: {
                if isSyncingHealth {
                    ProgressView()
                } else {
                    Text("Aggiorna")
                }
            }
            .buttonStyle(.bordered)
            .disabled(isSyncingHealth)
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var notesSection: some View {
        let notes = (goal.entries ?? [])
            .filter { !$0.note.isEmpty && YearMonth(DayKey(rawValue: $0.dayRaw) ?? goal.startDay) == month }
            .sorted { $0.dayRaw > $1.dayRaw }

        if !notes.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Note di \(ItalianFormat.monthTitle(month).lowercased())")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                ForEach(notes, id: \.dayRaw) { entry in
                    if let day = DayKey(rawValue: entry.dayRaw) {
                        Button {
                            selectedDay = day
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                StatusDot(status: entries(for: day), size: 18)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ItalianFormat.weekdayTitle(day))
                                        .font(.footnote.weight(.semibold))
                                    Text(entry.note)
                                        .font(.subheadline)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Apre il giorno")
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func entries(for day: DayKey) -> DayStatus? {
        goal.status(on: day, today: today)
    }
}

/// Riquadro con il numero di giorni o settimane di una serie.
struct StreakCard: View {
    enum Unit { case days, weeks }

    let title: String
    let value: Int
    let unit: Unit
    let caption: String

    init(title: String, value: Int, unit: Unit, caption: String) {
        self.title = title
        self.value = value
        self.unit = unit
        self.caption = caption
    }

    private var unitText: String {
        switch unit {
        case .days: value == 1 ? "giorno" : "giorni"
        case .weeks: value == 1 ? "settimana" : "settimane"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(value)")
                    .font(.title.bold())
                    .monospacedDigit()
                Text(unitText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Text(caption)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value) \(unitText), \(caption)")
    }
}

#Preview("Dettaglio") {
    NavigationStack {
        GoalDetailView(goal: PreviewData.sampleGoal, today: .today(), onDelete: { _ in })
    }
    .modelContainer(PreviewData.container)
    .tint(.brainTint)
}
