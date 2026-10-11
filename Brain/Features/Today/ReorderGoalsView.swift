import SwiftData
import SwiftUI

/// Riordino degli obiettivi attivi trascinandoli.
struct ReorderGoalsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(GoalQueries.active)
    private var goals: [Goal]

    init() {}

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(goals) { goal in
                        HStack(spacing: 12) {
                            GoalChip(emoji: goal.emoji, color: goal.color, size: 32)
                            Text(goal.name)
                        }
                    }
                    .onMove(perform: move)
                } footer: {
                    Text("Trascina le maniglie a destra per cambiare l'ordine in «Oggi» e nel widget.")
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Riordina")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fine") { dismiss() }
                }
            }
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = goals
        ordered.move(fromOffsets: source, toOffset: destination)
        modelContext.reorder(ordered)
    }
}
