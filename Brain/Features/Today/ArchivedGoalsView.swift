import SwiftData
import SwiftUI

/// Obiettivi archiviati: non compaiono in Oggi, ma conservano lo storico.
struct ArchivedGoalsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<Goal> { $0.archivedAt != nil },
        sort: [SortDescriptor(\Goal.archivedAt, order: .reverse)]
    )
    private var goals: [Goal]

    init() {}

    var body: some View {
        Group {
            if goals.isEmpty {
                ContentUnavailableView(
                    "Nessun obiettivo archiviato",
                    systemImage: "archivebox",
                    description: Text("Puoi archiviare un obiettivo da «Modifica» nel suo dettaglio.")
                )
            } else {
                List {
                    Section {
                        ForEach(goals) { goal in
                            NavigationLink(value: goal) {
                                HStack(spacing: 12) {
                                    GoalChip(emoji: goal.emoji, color: goal.color)
                                    Text(goal.name)
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button("Ripristina") {
                                    modelContext.setArchived(false, goal: goal)
                                }
                                .tint(.brainTint)
                            }
                        }
                    } footer: {
                        Text("Scorri verso sinistra su un obiettivo per ripristinarlo.")
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Archiviati")
        .navigationBarTitleDisplayMode(.inline)
    }
}
