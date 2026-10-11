import SwiftData
import SwiftUI

/// Foglio per registrare o correggere un giorno (anche passato): stato, valore, pausa e nota.
/// La scelta di uno stato si salva subito e chiude il foglio; la nota si salva alla chiusura.
struct DayStatusSheet: View {
    let goal: Goal
    let day: DayKey
    let today: DayKey

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var note: String
    @State private var valueText: String

    init(goal: Goal, day: DayKey, today: DayKey) {
        self.goal = goal
        self.day = day
        self.today = today
        _note = State(initialValue: goal.note(on: day))
        _valueText = State(initialValue: goal.value(on: day).map(ItalianFormat.editableNumber) ?? "")
    }

    var body: some View {
        let stored = goal.entry(on: day)
        let current: DayStatus? = goal.kind == .numeric
            ? (stored?.status == .paused ? .paused : nil)
            : stored?.status
        let hasData = stored.map { $0.status != nil || $0.value != nil } ?? false

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("\(goal.emoji) \(goal.name)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if goal.kind == .numeric {
                        valueSection
                    }

                    VStack(spacing: 8) {
                        switch goal.kind {
                        case .daily:
                            option(.done, label: "Fatto", isSelected: current == .done)
                            option(.missed, label: "Non fatto", isSelected: current == .missed)
                        case .weekly:
                            option(.done, label: "Fatto", isSelected: current == .done)
                        case .numeric:
                            EmptyView()
                        }
                        option(.paused, label: "Pausa (malattia, viaggio…)", isSelected: current == .paused)
                        option(nil, label: "Non registrato", isSelected: !hasData)
                    }

                    Text("«Pausa» e «Non registrato» non contano nella percentuale. La pausa non interrompe la serie; un giorno non registrato sì.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Nota")
                            .font(.subheadline.weight(.semibold))
                        TextField("Nota", text: $note, prompt: Text("Es. cena fuori, giornata pesante…"), axis: .vertical)
                            .lineLimit(2...6)
                            .padding(10)
                            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .accessibilityLabel("Nota del giorno, opzionale")
                    }
                }
                .padding(20)
            }
            .navigationTitle(ItalianFormat.weekdayTitle(day))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fine") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onDisappear(perform: saveNote)
    }

    private var valueSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Valore (obiettivo \(goal.targetDescription))")
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 10) {
                TextField("Valore", text: $valueText, prompt: Text("Es. 1650"))
                    .keyboardType(.decimalPad)
                    .font(.title3.monospacedDigit())
                    .padding(10)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                if !goal.unit.isEmpty {
                    Text(goal.unit).foregroundStyle(.secondary)
                }
                Button("Salva") {
                    modelContext.setValue(GoalRules.parseNumber(valueText), for: goal, on: day)
                    saveNote()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(GoalRules.parseNumber(valueText) == nil)
            }
            if let status = goal.status(on: day, today: today), status != .paused {
                Text("Esito: \(ItalianFormat.statusText(status))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if goal.isHealthLinked && day == today {
                Text("Il valore di oggi da Apple Salute è parziale: l'esito si decide a fine giornata.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func option(_ status: DayStatus?, label: String, isSelected: Bool) -> some View {
        Button {
            if status == nil && goal.kind == .numeric {
                modelContext.setValue(nil, for: goal, on: day)
            }
            modelContext.setStatus(status, for: goal, on: day)
            saveNote()
            dismiss()
        } label: {
            HStack(spacing: 12) {
                StatusDot(status: status, size: 28)
                Text(label)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.brainTint)
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 56)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? Color.brainTint : Color.clear, lineWidth: 1.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func saveNote() {
        guard !goal.isDeleted else { return }
        modelContext.setNote(note, for: goal, on: day)
    }
}
