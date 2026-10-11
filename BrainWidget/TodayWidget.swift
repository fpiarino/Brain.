import AppIntents
import SwiftData
import SwiftUI
import WidgetKit

// MARK: - Dati

/// Un obiettivo come lo mostra il widget (copia dei dati, senza legami con il database).
struct WidgetGoal: Identifiable, Hashable {
    let id: UUID
    let name: String
    let emoji: String
    let color: GoalColor
    let kind: GoalKind
    /// Stato registrato a mano oggi (per lo stato dei pulsanti).
    let storedStatus: DayStatus?
    /// Stato effettivo di oggi (per il riepilogo).
    let indicator: DayStatus?
    /// Testo breve sotto il nome.
    let detail: String
}

struct TodayEntry: TimelineEntry {
    let date: Date
    let today: DayKey
    let goals: [WidgetGoal]
    /// Il database non è raggiungibile (es. App Group non configurato).
    var unavailable = false

    var doneCount: Int { goals.filter { $0.indicator == .done }.count }
}

enum WidgetData {
    /// Legge gli obiettivi attivi aprendo ogni volta il database: così vede sempre
    /// le ultime modifiche fatte dall'app.
    static func load(now: Date = Date()) -> TodayEntry {
        let today = DayKey(now)
        guard let container = try? SharedStore.makeContainer() else {
            return TodayEntry(date: now, today: today, goals: [], unavailable: true)
        }
        let context = ModelContext(container)
        let goals = context.activeGoals()
            .filter { $0.canRegister(today, today: today) }
            .map { goal in
                WidgetGoal(
                    id: goal.id,
                    name: goal.name,
                    emoji: goal.emoji,
                    color: goal.color,
                    kind: goal.kind,
                    storedStatus: goal.entry(on: today)?.status,
                    indicator: goal.todayIndicator(today: today),
                    detail: detail(for: goal, today: today)
                )
            }
        return TodayEntry(date: now, today: today, goals: goals)
    }

    private static func detail(for goal: Goal, today: DayKey) -> String {
        switch goal.kind {
        case .daily:
            return ItalianFormat.statusText(goal.status(on: today, today: today)).capitalizedFirst
        case .weekly:
            let week = goal.currentWeek(today: today)
            return "\(week.done) di \(week.target) questa settimana"
        case .numeric:
            if let value = goal.value(on: today) {
                return goal.formattedValue(value)
            }
            return goal.targetDescription
        }
    }

    static let sample = TodayEntry(
        date: Date(),
        today: .today(),
        goals: [
            WidgetGoal(id: UUID(), name: "Meno di 1800 kcal", emoji: "🥗", color: .orange, kind: .numeric, storedStatus: nil, indicator: .done, detail: "1.650 kcal"),
            WidgetGoal(id: UUID(), name: "Palestra", emoji: "🏋️", color: .teal, kind: .weekly, storedStatus: nil, indicator: nil, detail: "2 di 3 questa settimana"),
            WidgetGoal(id: UUID(), name: "Niente telefono dopo le 23", emoji: "📵", color: .purple, kind: .daily, storedStatus: nil, indicator: nil, detail: "Non registrato")
        ]
    )
}

private extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}

// MARK: - Timeline

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        WidgetData.sample
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(context.isPreview ? WidgetData.sample : WidgetData.load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let entry = WidgetData.load()
        // Si aggiorna a mezzanotte (nuovo giorno) e quando l'app o i pulsanti cambiano i dati.
        let midnight = entry.today.adding(days: 1).startDate()
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }
}

// MARK: - Widget

struct TodayWidget: Widget {
    let kind = "BrainTodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Oggi")
        .description("Segna i tuoi obiettivi di oggi senza aprire Brain.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryCircular])
    }
}

struct TodayWidgetView: View {
    let entry: TodayEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallTodayView(entry: entry)
        case .accessoryRectangular:
            Text("Brain · \(entry.doneCount) di \(entry.goals.count) fatti")
                .font(.headline)
                .widgetURL(URL(string: "brain://today"))
        case .accessoryCircular:
            Gauge(value: Double(entry.doneCount), in: 0...Double(max(entry.goals.count, 1))) {
                Image(systemName: "checkmark")
            } currentValueLabel: {
                Text("\(entry.doneCount)")
            }
            .gaugeStyle(.accessoryCircular)
            .widgetURL(URL(string: "brain://today"))
        default:
            ListTodayView(entry: entry, maxRows: family == .systemLarge ? 7 : 3)
        }
    }
}

/// Widget piccolo: anello di avanzamento, apre l'app.
struct SmallTodayView: View {
    let entry: TodayEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Oggi")
                .font(.headline)
            Spacer(minLength: 0)
            if entry.goals.isEmpty {
                Text(entry.unavailable ? "Apri Brain per iniziare" : "Nessun obiettivo")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Gauge(value: Double(entry.doneCount), in: 0...Double(entry.goals.count)) {
                    EmptyView()
                } currentValueLabel: {
                    Text("\(entry.doneCount)/\(entry.goals.count)")
                        .font(.title3.bold().monospacedDigit())
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(Color.statusDone)
                Text(entry.doneCount == 1 ? "obiettivo fatto" : "obiettivi fatti")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(URL(string: "brain://today"))
    }
}

/// Widget medio e grande: elenco con i pulsanti per registrare.
struct ListTodayView: View {
    let entry: TodayEntry
    let maxRows: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Oggi")
                    .font(.headline)
                Spacer()
                if !entry.goals.isEmpty {
                    Text("\(entry.doneCount) di \(entry.goals.count)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if entry.goals.isEmpty {
                Spacer()
                Text(entry.unavailable ? "Apri Brain per iniziare." : "Nessun obiettivo per oggi. Creane uno in Brain.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(entry.goals.prefix(maxRows)) { goal in
                    WidgetGoalRow(goal: goal)
                }
                if entry.goals.count > maxRows {
                    Text("+ altri \(entry.goals.count - maxRows)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
        .widgetURL(URL(string: "brain://today"))
    }
}

struct WidgetGoalRow: View {
    let goal: WidgetGoal

    var body: some View {
        HStack(spacing: 8) {
            Link(destination: URL(string: "brain://goal/\(goal.id.uuidString)")!) {
                HStack(spacing: 8) {
                    GoalChip(emoji: goal.emoji, color: goal.color, size: 28)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(goal.name)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text(goal.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
            }

            switch goal.kind {
            case .daily:
                WidgetToggle(goal: goal, status: .missed)
                WidgetToggle(goal: goal, status: .done)
            case .weekly:
                WidgetToggle(goal: goal, status: .done)
            case .numeric:
                StatusDot(status: goal.indicator, size: 22)
            }
        }
    }
}

/// Pulsante ✓ / ✗ interattivo: esegue l'intent senza aprire l'app.
struct WidgetToggle: View {
    let goal: WidgetGoal
    let status: DayStatus

    private var isSelected: Bool { goal.storedStatus == status }
    private var tint: Color { status == .done ? .statusDone : .statusMissed }

    var body: some View {
        Button(intent: ToggleGoalStatusIntent(goalID: goal.id, status: status)) {
            Image(systemName: status == .done ? "checkmark" : "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isSelected ? Color.onStatus : Color.secondary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(isSelected ? tint : Color.clear))
                .overlay(Circle().strokeBorder(isSelected ? tint : Color.statusEmpty, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(goal.name): \(status == .done ? "fatto" : "non fatto")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview(as: .systemMedium) {
    TodayWidget()
} timeline: {
    WidgetData.sample
}
