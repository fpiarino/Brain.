import SwiftUI

/// Riga di un obiettivo nella schermata Oggi. Tocca il nome per aprire il dettaglio.
/// - Sì/No: pulsanti ✗ e ✓.
/// - Settimanale: solo ✓ (conta quante volte lo fai nella settimana).
/// - Numerico: pulsante con il valore di oggi, che apre l'inserimento.
struct TodayGoalRow: View {
    let goal: Goal
    let today: DayKey
    let onOpen: () -> Void
    let onToggle: (DayStatus) -> Void
    let onEnterValue: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(
        goal: Goal,
        today: DayKey,
        onOpen: @escaping () -> Void,
        onToggle: @escaping (DayStatus) -> Void,
        onEnterValue: @escaping () -> Void
    ) {
        self.goal = goal
        self.today = today
        self.onOpen = onOpen
        self.onToggle = onToggle
        self.onEnterValue = onEnterValue
    }

    var body: some View {
        let canRegister = goal.canRegister(today, today: today)
        let subtitle = subtitleText(canRegister: canRegister)

        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // Con testo molto grande i controlli vanno sotto, invece di schiacciare il nome.
                VStack(alignment: .leading, spacing: 10) {
                    info(subtitle: subtitle, canRegister: canRegister)
                    if canRegister { controls }
                }
            } else {
                HStack(spacing: 12) {
                    info(subtitle: subtitle, canRegister: canRegister)
                    if canRegister { controls }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func info(subtitle: String, canRegister: Bool) -> some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                GoalChip(emoji: goal.emoji, color: goal.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(subtitle: subtitle, canRegister: canRegister))
        .accessibilityHint("Apre il calendario dell'obiettivo")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var controls: some View {
        let stored = goal.entry(on: today)?.status
        switch goal.kind {
        case .daily:
            HStack(spacing: 10) {
                StatusToggleButton(kind: .missed, isSelected: stored == .missed, goalName: goal.name) {
                    onToggle(.missed)
                }
                StatusToggleButton(kind: .done, isSelected: stored == .done, goalName: goal.name) {
                    onToggle(.done)
                }
            }
        case .weekly:
            StatusToggleButton(kind: .done, isSelected: stored == .done, goalName: goal.name) {
                onToggle(.done)
            }
        case .numeric:
            ValueButton(goal: goal, today: today, action: onEnterValue)
        }
    }

    private func subtitleText(canRegister: Bool) -> String {
        guard canRegister else {
            return "Inizia il \(ItalianFormat.shortDayMonthText(goal.startDay))"
        }
        if goal.entry(on: today)?.status == .paused {
            return "Oggi in pausa"
        }
        let entries = goal.statusMap(today: today)

        switch goal.kind {
        case .weekly:
            let week = goal.currentWeek(today: today)
            let streak = WeeklyStats.currentStreak(entries: entries, weeklyTarget: goal.weeklyTarget, startDay: goal.startDay, today: today)?.length ?? 0
            var text = "\(week.done) di \(week.target) questa settimana"
            if week.state == .success { text += " ✓" }
            if streak > 1 { text += " · serie \(streak) sett." }
            return text
        case .daily, .numeric:
            let current = GoalStats.currentStreak(entries: entries, startDay: goal.startDay, today: today)?.length ?? 0
            let best = GoalStats.bestStreak(entries: entries, startDay: goal.startDay, today: today)?.length ?? 0
            var parts: [String] = []
            if goal.kind == .numeric {
                parts.append(goal.targetDescription + (goal.isHealthLinked ? " · da Salute" : ""))
            }
            if current == 0 {
                parts.append(best > 0 ? "Serie: 0 · record \(best)" : "Nessuna serie, per ora")
            } else if current >= best && current > 1 {
                parts.append("Serie: \(ItalianFormat.days(current)) · record!")
            } else {
                parts.append("Serie: \(ItalianFormat.days(current))")
            }
            return parts.joined(separator: "\n")
        }
    }

    private func accessibilityText(subtitle: String, canRegister: Bool) -> String {
        var parts = [goal.name, subtitle.replacingOccurrences(of: "\n", with: ", ")]
        if canRegister {
            parts.append("Oggi: \(ItalianFormat.statusText(goal.status(on: today, today: today)))")
        }
        return parts.joined(separator: ", ")
    }
}

/// Pulsante rotondo ✓ o ✗. Pieno e colorato quando è lo stato scelto, solo contorno altrimenti.
struct StatusToggleButton: View {
    let kind: DayStatus
    let isSelected: Bool
    let goalName: String
    let action: () -> Void

    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 44

    init(kind: DayStatus, isSelected: Bool, goalName: String, action: @escaping () -> Void) {
        self.kind = kind
        self.isSelected = isSelected
        self.goalName = goalName
        self.action = action
    }

    private var tint: Color { kind == .done ? .statusDone : .statusMissed }

    var body: some View {
        Button(action: action) {
            Image(systemName: kind == .done ? "checkmark" : "xmark")
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(isSelected ? Color.onStatus : Color.secondary)
                .frame(width: size, height: size)
                .background(Circle().fill(isSelected ? tint : Color.clear))
                .overlay(Circle().strokeBorder(isSelected ? tint : Color.statusEmpty, lineWidth: 1.5))
                .contentShape(Circle())
        }
        .buttonStyle(.borderless)
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityLabel(kind == .done ? "Fatto" : "Non fatto")
        .accessibilityHint(isSelected ? "Tocca di nuovo per tornare a non registrato" : "Registra la giornata di oggi")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityRemoveTraits(isSelected ? [] : [.isSelected])
        .accessibilityIdentifier("\(kind == .done ? "done" : "missed")-\(goalName)")
    }
}

/// Pulsante degli obiettivi numerici: mostra il valore di oggi o invita a inserirlo.
struct ValueButton: View {
    let goal: Goal
    let today: DayKey
    let action: () -> Void

    init(goal: Goal, today: DayKey, action: @escaping () -> Void) {
        self.goal = goal
        self.today = today
        self.action = action
    }

    var body: some View {
        let value = goal.value(on: today)
        let status = goal.status(on: today, today: today)

        Button(action: action) {
            HStack(spacing: 6) {
                if value != nil {
                    StatusDot(status: status, size: 18)
                }
                if goal.isHealthLinked {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(Color.statusMissed)
                        .accessibilityHidden(true)
                }
                Text(value.map { goal.formattedValue($0) } ?? "Inserisci")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(value.map { "Valore di oggi: \(goal.formattedValue($0)), \(ItalianFormat.statusText(status))" } ?? "Inserisci il valore di oggi")
        .accessibilityHint("Apre l'inserimento del valore")
        .accessibilityIdentifier("value-\(goal.name)")
    }
}
