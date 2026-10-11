import Combine
import SwiftData
import SwiftUI

/// Destinazione di navigazione per l'elenco degli obiettivi archiviati.
struct ArchivedRoute: Hashable {}

/// Un obiettivo in un giorno: usato per aprire i fogli di registrazione.
struct GoalDaySelection: Identifiable {
    let goal: Goal
    let day: DayKey
    var id: String { "\(goal.id.uuidString)-\(day.rawValue)" }
}

/// Schermata principale: gli obiettivi attivi e la registrazione di oggi.
struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppModel.self) private var appModel

    @Query(
        filter: #Predicate<Goal> { $0.archivedAt == nil },
        sort: [SortDescriptor(\Goal.sortOrder), SortDescriptor(\Goal.createdAt)]
    )
    private var goals: [Goal]

    @Query(filter: #Predicate<Goal> { $0.archivedAt != nil })
    private var archivedGoals: [Goal]

    @State private var today = DayKey.today()
    @State private var path = NavigationPath()
    @State private var showingNewGoal = false
    @State private var showingReminder = false
    @State private var showingReorder = false
    @State private var showingBackup = false
    @State private var valueEntry: GoalDaySelection?
    @State private var undo: UndoAction?

    init() {}

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if goals.isEmpty {
                    emptyState
                } else {
                    goalList
                }
            }
            .navigationTitle("Oggi")
            .toolbar { toolbarContent }
            .navigationDestination(for: Goal.self) { goal in
                GoalDetailView(goal: goal, today: today, onDelete: delete)
            }
            .navigationDestination(for: ArchivedRoute.self) { _ in
                ArchivedGoalsView()
            }
        }
        .overlay(alignment: .bottom) {
            if let undo {
                UndoToast(message: undo.message) { performUndo() }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: undo)
        .task(id: undo?.id) {
            // L'avviso "Annulla" sparisce da solo dopo qualche secondo.
            guard undo != nil else { return }
            try? await Task.sleep(for: .seconds(5))
            if !Task.isCancelled { undo = nil }
        }
        .sheet(isPresented: $showingNewGoal) {
            GoalEditorView(mode: .new)
        }
        .sheet(isPresented: $showingReminder) {
            ReminderSettingsView()
        }
        .sheet(isPresented: $showingReorder) {
            ReorderGoalsView()
        }
        .sheet(isPresented: $showingBackup) {
            BackupView()
        }
        .sheet(item: $valueEntry) { selection in
            ValueEntrySheet(goal: selection.goal, day: selection.day)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                today = .today()
                refreshExternalData()
            case .background:
                // Le registrazioni fatte in questa sessione aggiornano i promemoria.
                Task { await ReminderScheduler.reschedule(using: modelContext) }
            default:
                break
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            today = .today()
        }
        .onChange(of: appModel.pendingGoalID) { _, id in
            if let id { open(goalID: id) }
        }
        .onOpenURL(perform: handle)
        .task {
            refreshExternalData()
            if let id = appModel.pendingGoalID { open(goalID: id) }
        }
    }

    // MARK: - Contenuto

    private var goalList: some View {
        List {
            Section {
                TodaySummaryCard(
                    today: today,
                    indicators: registrableGoals.map { $0.todayIndicator(today: today) },
                    pendingCount: goals.filter { $0.needsRegistration(today: today) }.count
                )
            }

            Section {
                ForEach(goals) { goal in
                    TodayGoalRow(
                        goal: goal,
                        today: today,
                        onOpen: { path.append(goal) },
                        onToggle: { status in toggle(status, goal: goal) },
                        onEnterValue: { valueEntry = GoalDaySelection(goal: goal, day: today) }
                    )
                }
            } header: {
                Text("Obiettivi attivi")
            } footer: {
                Text("Un tocco su ✓ o ✗ registra il giorno; un secondo tocco lo riporta a «non registrato». Tocca il nome per il calendario, le note e le pause.")
            }
        }
        .listStyle(.insetGrouped)
        // Spazio per l'avviso "Annulla" in fondo.
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: undo == nil ? 0 : 64)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nessun obiettivo", systemImage: "circle.dashed")
        } description: {
            Text("Crea il tuo primo obiettivo e segna ogni giorno se l'hai rispettato.")
        } actions: {
            Button("Crea un obiettivo") {
                showingNewGoal = true
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("createFirstGoalButton")

            Button("Ripristina da un backup") {
                showingBackup = true
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                Button {
                    showingReorder = true
                } label: {
                    Label("Riordina obiettivi", systemImage: "arrow.up.arrow.down")
                }
                .disabled(goals.count < 2)

                Button {
                    showingReminder = true
                } label: {
                    Label("Promemoria serale", systemImage: "bell")
                }

                Button {
                    showingBackup = true
                } label: {
                    Label("Backup e ripristino", systemImage: "externaldrive")
                }

                if !archivedGoals.isEmpty {
                    Button {
                        path.append(ArchivedRoute())
                    } label: {
                        Label("Obiettivi archiviati (\(archivedGoals.count))", systemImage: "archivebox")
                    }
                }
            } label: {
                Label("Altro", systemImage: "ellipsis.circle")
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                showingNewGoal = true
            } label: {
                Label("Nuovo obiettivo", systemImage: "plus")
            }
            .accessibilityIdentifier("newGoalButton")
        }
    }

    /// Obiettivi che si possono già registrare oggi (esclusi quelli con data di inizio futura).
    private var registrableGoals: [Goal] {
        goals.filter { $0.canRegister(today, today: today) }
    }

    // MARK: - Azioni

    private func toggle(_ status: DayStatus, goal: Goal) {
        let previous = modelContext.toggle(status, for: goal, on: today)
        let newStatus = goal.entry(on: today)?.status
        let message: String
        switch newStatus {
        case .done?: message = "\(goal.emoji) Segnato come fatto"
        case .missed?: message = "\(goal.emoji) Segnato come non fatto"
        default: message = "\(goal.emoji) Tornato a non registrato"
        }
        undo = UndoAction(goalID: goal.id, day: today, previous: previous, message: message)
        AccessibilityNotification.Announcement(message).post()
    }

    private func performUndo() {
        guard let action = undo else { return }
        if let goal = modelContext.goal(withID: action.goalID) {
            modelContext.restore(action.previous, for: goal, on: action.day)
        }
        undo = nil
        AccessibilityNotification.Announcement("Modifica annullata").post()
    }

    /// Rilegge Apple Salute e ricalcola i promemoria.
    private func refreshExternalData() {
        Task {
            await HealthSync.sync(using: modelContext)
            await ReminderScheduler.reschedule(using: modelContext)
        }
    }

    private func open(goalID: UUID) {
        appModel.pendingGoalID = nil
        guard let goal = modelContext.goal(withID: goalID) else { return }
        path = NavigationPath()
        path.append(goal)
    }

    /// Collegamenti dal widget: `brain://today` e `brain://goal/<id>`.
    private func handle(_ url: URL) {
        guard url.scheme == "brain" else { return }
        if url.host() == "goal", let id = UUID(uuidString: url.lastPathComponent) {
            open(goalID: id)
        } else {
            path = NavigationPath()
        }
    }

    /// Torna alla schermata Oggi e solo dopo elimina l'obiettivo,
    /// così nessuna schermata mostra un obiettivo già cancellato.
    private func delete(_ goal: Goal) {
        path = NavigationPath()
        undo = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            modelContext.deleteGoal(goal)
            await ReminderScheduler.reschedule(using: modelContext)
        }
    }
}

/// Ultima modifica fatta da Oggi, per poterla annullare.
struct UndoAction: Identifiable, Equatable {
    let id = UUID()
    let goalID: UUID
    let day: DayKey
    let previous: EntrySnapshot?
    let message: String
}

/// Avviso in fondo allo schermo con il pulsante "Annulla".
struct UndoToast: View {
    let message: String
    let onUndo: () -> Void

    init(message: String, onUndo: @escaping () -> Void) {
        self.message = message
        self.onUndo = onUndo
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(message)
                .font(.subheadline)
                .lineLimit(2)
            Spacer(minLength: 8)
            Button("Annulla", action: onUndo)
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
                .accessibilityIdentifier("undoButton")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
    }
}

#Preview("Oggi") {
    TodayView()
        .modelContainer(PreviewData.container)
        .environment(AppModel.shared)
        .tint(.brainTint)
        .environment(\.locale, Locale(identifier: "it_IT"))
}
