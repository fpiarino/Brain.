import Charts
import SwiftUI

/// Statistiche di un obiettivo: mappa dell'anno, andamento per giorno della settimana e totali.
struct GoalInsightsView: View {
    let goal: Goal
    let today: DayKey

    @State private var year: Int

    private static let chartLabels = ["Lun", "Mar", "Mer", "Gio", "Ven", "Sab", "Dom"]

    init(goal: Goal, today: DayKey) {
        self.goal = goal
        self.today = today
        _year = State(initialValue: today.year)
    }

    var body: some View {
        let entries = goal.statusMap(today: today)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                totalsCard(entries: entries)
                heatmapCard(entries: entries)
                weekdayCard(entries: entries)
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Statistiche")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Totali

    private func totalsCard(entries: [DayKey: DayStatus]) -> some View {
        let totals = GoalStats.totals(entries: entries, startDay: goal.startDay, today: today)
        let weeks = WeeklyStats.weeks(entries: entries, weeklyTarget: goal.weeklyTarget, startDay: goal.startDay, today: today)
        let weeksDone = weeks.filter { $0.state == .success }.count
        let weeksFailed = weeks.filter { $0.state == .failed }.count

        return card(title: "Da sempre") {
            if goal.kind == .weekly {
                Text("\(weeksDone) settimane riuscite su \(weeksDone + weeksFailed) concluse · \(totals.done) giorni fatti")
            } else {
                Text("\(totals.done) fatti · \(totals.missed) non fatti" + (totals.successPercent.map { " · \($0)% di successo" } ?? ""))
            }
            if totals.paused > 0 || totals.unregistered > 0 {
                Text("\(ItalianFormat.days(totals.paused)) in pausa · \(ItalianFormat.days(totals.unregistered)) non registrati")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Mappa dell'anno

    private func heatmapCard(entries: [DayKey: DayStatus]) -> some View {
        let columns = YearHeatmap(year: year).columns
        let yearDone = entries.filter { $0.key.year == year && $0.value == .done }.count
        let yearMissed = entries.filter { $0.key.year == year && $0.value == .missed }.count

        return card(title: nil) {
            HStack {
                Button {
                    year -= 1
                } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                }
                .disabled(year <= goal.startDay.year)
                .accessibilityLabel("Anno precedente")

                Spacer()
                Text(String(year))
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()

                Button {
                    year += 1
                } label: {
                    Image(systemName: "chevron.right").frame(width: 44, height: 44)
                }
                .disabled(year >= today.year)
                .accessibilityLabel("Anno successivo")
            }
            .buttonStyle(.borderless)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 3) {
                        ForEach(Array(columns.enumerated()), id: \.offset) { index, column in
                            VStack(spacing: 3) {
                                Text(monthLabel(column))
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                                    .frame(height: 11)
                                    .fixedSize()
                                ForEach(0..<7, id: \.self) { row in
                                    HeatCell(day: column[row], entries: entries, startDay: goal.startDay, today: today)
                                }
                            }
                            .id(index)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onAppear { scrollToToday(proxy, columns: columns) }
                .onChange(of: year) { _, _ in scrollToToday(proxy, columns: YearHeatmap(year: year).columns) }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Mappa dell'anno \(year): \(yearDone) giorni fatti, \(yearMissed) non fatti")

            HStack(spacing: 12) {
                legend(.done, "fatto")
                legend(.missed, "non fatto")
                legend(.paused, "pausa")
                legend(nil, "vuoto")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
        }
    }

    /// Sigla del mese sopra la colonna che contiene il giorno 1 di quel mese.
    private func monthLabel(_ column: [DayKey?]) -> String {
        guard let firstOfMonth = column.compactMap({ $0 }).first(where: { $0.day == 1 }) else { return "" }
        let names = ["gen", "feb", "mar", "apr", "mag", "giu", "lug", "ago", "set", "ott", "nov", "dic"]
        return names[firstOfMonth.month - 1]
    }

    private func scrollToToday(_ proxy: ScrollViewProxy, columns: [[DayKey?]]) {
        let target = year == today.year ? today : DayKey(year: year, month: 12, day: 31)
        if let index = columns.firstIndex(where: { $0.contains(target) }) {
            proxy.scrollTo(index, anchor: .trailing)
        }
    }

    private func legend(_ status: DayStatus?, _ text: String) -> some View {
        HStack(spacing: 4) {
            HeatSquare(status: status, isInRange: true)
            Text(text)
        }
    }

    // MARK: - Giorni della settimana

    private func weekdayCard(entries: [DayKey: DayStatus]) -> some View {
        let stats = Insights.weekdayStats(entries: entries, startDay: goal.startDay, today: today)
        let weakest = goal.kind == .weekly ? nil : Insights.weakestWeekday(stats)

        return card(title: goal.kind == .weekly ? "Giorni fatti per giorno della settimana" : "Successo per giorno della settimana") {
            Chart(stats, id: \.weekday) { stat in
                BarMark(
                    x: .value("Giorno", Self.chartLabels[stat.weekday - 1]),
                    y: .value(goal.kind == .weekly ? "Giorni" : "Percentuale", barValue(stat))
                )
                .foregroundStyle(stat.weekday == weakest?.weekday ? Color.statusMissed : Color.statusDone)
                .annotation(position: .top) {
                    Text(barLabel(stat))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel(ItalianFormat.weekdayName(stat.weekday))
                .accessibilityValue(barAccessibilityValue(stat))
            }
            .chartYAxis(.hidden)
            .chartYScale(domain: 0...(goal.kind == .weekly ? max(1, Double(stats.map(\.done).max() ?? 1)) * 1.2 : 115))
            .frame(height: 180)

            if let weakest, let percent = weakest.successPercent {
                Text("Il giorno più difficile è il \(ItalianFormat.weekdayName(weakest.weekday).lowercased()): \(percent)% su \(weakest.registered) giorni registrati.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func barValue(_ stat: WeekdayStat) -> Double {
        goal.kind == .weekly ? Double(stat.done) : Double(stat.successPercent ?? 0)
    }

    private func barLabel(_ stat: WeekdayStat) -> String {
        if goal.kind == .weekly { return "\(stat.done)" }
        return stat.successPercent.map { "\($0)%" } ?? "–"
    }

    private func barAccessibilityValue(_ stat: WeekdayStat) -> String {
        if goal.kind == .weekly { return ItalianFormat.days(stat.done) + " fatti" }
        guard let percent = stat.successPercent else { return "nessun giorno registrato" }
        return "\(percent) per cento, \(stat.done) fatti su \(stat.registered)"
    }

    // MARK: - Contenitore

    private func card<Content: View>(title: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Casella della mappa dell'anno.
private struct HeatCell: View {
    let day: DayKey?
    let entries: [DayKey: DayStatus]
    let startDay: DayKey
    let today: DayKey

    var body: some View {
        if let day {
            HeatSquare(status: entries[day], isInRange: day >= startDay && day <= today)
        } else {
            Color.clear.frame(width: HeatSquare.side, height: HeatSquare.side)
        }
    }
}

/// Quadratino colorato. Anche qui la forma cambia con lo stato, non solo il colore:
/// pieno = fatto, con un foro al centro = non fatto, con una barra = pausa.
struct HeatSquare: View {
    static let side: CGFloat = 12
    let status: DayStatus?
    let isInRange: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
            .fill(fill)
            .frame(width: Self.side, height: Self.side)
            .overlay {
                switch status {
                case .missed?:
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        .frame(width: 4, height: 4)
                case .paused?:
                    Rectangle()
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        .frame(width: 6, height: 1.5)
                default:
                    EmptyView()
                }
            }
    }

    private var fill: Color {
        guard isInRange else { return Color(uiColor: .systemGray6) }
        switch status {
        case .done?: return .statusDone
        case .missed?: return .statusMissed
        case .paused?: return .statusPaused
        case nil: return Color(uiColor: .systemGray4)
        }
    }
}
