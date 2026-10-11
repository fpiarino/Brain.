import SwiftData
import SwiftUI

/// Inserimento del valore di un obiettivo numerico (es. kcal di oggi).
struct ValueEntrySheet: View {
    let goal: Goal
    let day: DayKey

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @FocusState private var focused: Bool

    init(goal: Goal, day: DayKey) {
        self.goal = goal
        self.day = day
        _text = State(initialValue: goal.value(on: day).map(ItalianFormat.editableNumber) ?? "")
    }

    private var parsed: Double? { GoalRules.parseNumber(text) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("Valore", text: $text, prompt: Text("Es. 1650"))
                            .keyboardType(.decimalPad)
                            .focused($focused)
                            .font(.title2.monospacedDigit())
                            .accessibilityIdentifier("valueField")
                        if !goal.unit.isEmpty {
                            Text(goal.unit)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("\(goal.emoji) \(goal.name)")
                } footer: {
                    Text(footerText)
                }

                if goal.value(on: day) != nil {
                    Section {
                        Button("Cancella il valore", role: .destructive) {
                            modelContext.setValue(nil, for: goal, on: day)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(ItalianFormat.weekdayTitle(day))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        modelContext.setValue(parsed, for: goal, on: day)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(parsed == nil)
                    .accessibilityIdentifier("saveValueButton")
                }
            }
            .task {
                try? await Task.sleep(for: .milliseconds(300))
                focused = true
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var footerText: String {
        var text = "Obiettivo: \(goal.targetDescription)."
        if goal.isHealthLinked {
            text += " Il valore arriva da Apple Salute; se lo modifichi qui, vale il tuo e Salute non lo sovrascrive più."
        }
        return text
    }
}
