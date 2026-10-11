import SwiftData
import SwiftUI

/// Creazione e modifica di un obiettivo. Per crearne uno Sì/No basta il nome:
/// tipo, icona, colore e data di inizio hanno già un valore.
struct GoalEditorView: View {
    enum Mode {
        case new
        case edit(Goal)
    }

    let mode: Mode
    /// Solo in modifica: chiamato dopo la conferma di eliminazione.
    var onDelete: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var details: String
    @State private var emoji: String
    @State private var color: GoalColor
    @State private var startDate: Date
    @State private var kind: GoalKind
    @State private var weeklyTarget: Int
    @State private var comparison: NumericComparison
    @State private var targetText: String
    @State private var unit: String
    @State private var healthMetric: HealthMetric?
    @State private var customEmoji = ""
    @State private var confirmingDelete = false
    @State private var didApplyDefaults = false
    @FocusState private var nameFocused: Bool

    private static let suggestedEmojis = [
        "🎯", "🥗", "🚶", "🏃", "💧", "📚", "🧘", "😴",
        "📵", "🏋️", "🍎", "🚭", "✍️", "🎸", "🧹", "💰"
    ]

    init(mode: Mode, onDelete: (() -> Void)? = nil) {
        self.mode = mode
        self.onDelete = onDelete
        switch mode {
        case .new:
            _name = State(initialValue: "")
            _details = State(initialValue: "")
            _emoji = State(initialValue: "🎯")
            _color = State(initialValue: .blue)
            _startDate = State(initialValue: DayKey.today().startDate())
            _kind = State(initialValue: .daily)
            _weeklyTarget = State(initialValue: 3)
            _comparison = State(initialValue: .atMost)
            _targetText = State(initialValue: "")
            _unit = State(initialValue: "")
            _healthMetric = State(initialValue: nil)
        case .edit(let goal):
            _name = State(initialValue: goal.name)
            _details = State(initialValue: goal.details)
            _emoji = State(initialValue: goal.emoji)
            _color = State(initialValue: goal.color)
            _startDate = State(initialValue: goal.startDay.startDate())
            _kind = State(initialValue: goal.kind)
            _weeklyTarget = State(initialValue: goal.weeklyTarget)
            _comparison = State(initialValue: goal.comparison)
            _targetText = State(initialValue: goal.kind == .numeric ? ItalianFormat.editableNumber(goal.numericTarget) : "")
            _unit = State(initialValue: goal.unit)
            _healthMetric = State(initialValue: goal.healthMetric)
        }
    }

    private var isNew: Bool {
        if case .new = mode { return true }
        return false
    }

    private var screenTitle: String {
        isNew ? "Nuovo obiettivo" : "Modifica obiettivo"
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedTarget: Double? { GoalRules.parseNumber(targetText) }

    private var canSave: Bool {
        !trimmedName.isEmpty && (kind != .numeric || parsedTarget != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                preview
                textSection
                kindSection
                emojiSection
                colorSection
                dateSection
                if case .edit(let goal) = mode {
                    manageSection(goal)
                }
            }
            .navigationTitle(screenTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                        .accessibilityIdentifier("saveGoalButton")
                }
            }
            .confirmationDialog(
                "Eliminare «\(trimmedName)»?",
                isPresented: $confirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Elimina obiettivo", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
                Button("Annulla", role: .cancel) {}
            } message: {
                Text("Verranno cancellati anche tutti i giorni registrati e le note. L'operazione non si può annullare.")
            }
            .onAppear(perform: applyDefaultsIfNeeded)
            .task {
                guard isNew else { return }
                // Piccola attesa: il campo riceve il focus quando il foglio ha finito di aprirsi.
                try? await Task.sleep(for: .milliseconds(350))
                nameFocused = true
            }
        }
    }

    // MARK: - Sezioni

    private var preview: some View {
        Section {
            VStack(spacing: 8) {
                GoalChip(emoji: emoji, color: color, size: 64)
                Text(trimmedName.isEmpty ? "Nuovo obiettivo" : trimmedName)
                    .font(.headline)
                    .foregroundStyle(trimmedName.isEmpty ? Color.secondary : Color.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
            .accessibilityHidden(true)
        }
    }

    private var textSection: some View {
        Section {
            TextField("Nome", text: $name, prompt: Text("Es. Mangiare meno di 1800 kcal"))
                .focused($nameFocused)
                .submitLabel(.done)
                .accessibilityLabel("Nome")
                .accessibilityIdentifier("goalNameField")
            TextField("Descrizione", text: $details, prompt: Text("Descrizione (opzionale)"), axis: .vertical)
                .lineLimit(1...4)
                .accessibilityLabel("Descrizione, opzionale")
        }
    }

    private var kindSection: some View {
        Section {
            Picker("Tipo", selection: $kind) {
                Text("Sì / No").tag(GoalKind.daily)
                Text("A settimana").tag(GoalKind.weekly)
                Text("Numerico").tag(GoalKind.numeric)
            }
            .pickerStyle(.segmented)

            switch kind {
            case .daily:
                EmptyView()
            case .weekly:
                Stepper(value: $weeklyTarget, in: 1...7) {
                    Text(weeklyTarget == 1 ? "1 volta a settimana" : "\(weeklyTarget) volte a settimana")
                }
            case .numeric:
                if HealthSync.isAvailable {
                    Picker("Valore", selection: $healthMetric) {
                        Text("Inserito a mano").tag(HealthMetric?.none)
                        ForEach(HealthMetric.allCases, id: \.self) { metric in
                            Text("\(metric.displayName) (Salute)").tag(HealthMetric?.some(metric))
                        }
                    }
                    .onChange(of: healthMetric) { _, metric in
                        guard let metric else { return }
                        unit = metric.unit
                        comparison = metric.suggestedComparison
                        Task { await HealthSync.requestAuthorization(for: [metric]) }
                    }
                }
                Picker("Obiettivo", selection: $comparison) {
                    Text("Al massimo").tag(NumericComparison.atMost)
                    Text("Almeno").tag(NumericComparison.atLeast)
                }
                .pickerStyle(.segmented)
                HStack {
                    TextField("Soglia", text: $targetText, prompt: Text("Es. 1800"))
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("Soglia")
                    TextField("Unità", text: $unit, prompt: Text("unità, es. kcal"))
                        .multilineTextAlignment(.trailing)
                        .accessibilityLabel("Unità di misura")
                }
            }
        } header: {
            Text("Tipo di obiettivo")
        } footer: {
            Text(kindFooter)
        }
    }

    private var kindFooter: String {
        switch kind {
        case .daily:
            return "Ogni giorno segni fatto o non fatto."
        case .weekly:
            return "Segni i giorni in cui lo fai; la settimana (lunedì–domenica) riesce quando arrivi al numero scelto."
        case .numeric:
            if healthMetric != nil {
                return "Il valore di ogni giorno arriva da Apple Salute. Puoi sempre correggerlo a mano."
            }
            return "Ogni giorno inserisci un valore: è fatto se rispetta la soglia."
        }
    }

    private var emojiSection: some View {
        Section("Icona") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 4)], spacing: 4) {
                ForEach(Self.suggestedEmojis, id: \.self) { item in
                    let isSelected = item == emoji
                    Button {
                        emoji = item
                    } label: {
                        Text(item)
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .background(
                                isSelected ? color.softBackground : Color.clear,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(isSelected ? color.color : Color.clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.vertical, 4)

            TextField("Altra emoji", text: $customEmoji, prompt: Text("Oppure scrivi un'altra emoji"))
                .onChange(of: customEmoji) { _, newValue in
                    guard !newValue.isEmpty else { return }
                    if let picked = newValue.last(where: \.isEmojiLike) {
                        emoji = String(picked)
                    }
                    customEmoji = ""
                }
        }
    }

    private var colorSection: some View {
        Section("Colore") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 4)], spacing: 4) {
                ForEach(GoalColor.allCases) { item in
                    let isSelected = item == color
                    Button {
                        color = item
                    } label: {
                        Circle()
                            .fill(item.color)
                            .frame(width: 30, height: 30)
                            .padding(4)
                            .overlay(Circle().strokeBorder(isSelected ? item.color : Color.clear, lineWidth: 2))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.name)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var dateSection: some View {
        Section {
            DatePicker("Data di inizio", selection: $startDate, displayedComponents: .date)
        } footer: {
            Text("I giorni prima della data di inizio non contano.")
        }
    }

    private func manageSection(_ goal: Goal) -> some View {
        Section {
            let archiveTitle: String = goal.isArchived ? "Ripristina obiettivo" : "Archivia obiettivo"
            Button(archiveTitle) {
                modelContext.setArchived(!goal.isArchived, goal: goal)
                dismiss()
            }
            Button("Elimina obiettivo…", role: .destructive) {
                confirmingDelete = true
            }
        } footer: {
            Text("Gli obiettivi archiviati spariscono da «Oggi» ma conservano tutto lo storico.")
        }
    }

    // MARK: - Azioni

    /// Per un nuovo obiettivo sceglie il colore successivo nella rotazione.
    private func applyDefaultsIfNeeded() {
        guard isNew, !didApplyDefaults else { return }
        didApplyDefaults = true
        color = .rotating(modelContext.goalCount())
    }

    private func save() {
        guard canSave else { return }
        let startDay = DayKey(startDate)
        let cleanDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)

        let goal: Goal
        switch mode {
        case .new:
            goal = Goal(name: trimmedName, sortOrder: modelContext.nextSortOrder())
            modelContext.insert(goal)
        case .edit(let existing):
            goal = existing
        }
        goal.name = trimmedName
        goal.details = cleanDetails
        goal.emoji = emoji
        goal.color = color
        goal.startDay = startDay
        goal.kind = kind
        goal.weeklyTarget = weeklyTarget
        if kind == .numeric {
            goal.numericTarget = parsedTarget ?? 0
            goal.comparison = comparison
            goal.unit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
            goal.healthMetric = healthMetric
        } else {
            goal.healthMetric = nil
        }
        modelContext.saveQuietly()

        if goal.isHealthLinked {
            let context = modelContext
            Task { await HealthSync.sync(using: context) }
        }
        dismiss()
    }
}

extension Character {
    /// Vero per i caratteri che appaiono come emoji (esclusi cifre e simboli semplici).
    var isEmojiLike: Bool {
        guard let first = unicodeScalars.first else { return false }
        return first.properties.isEmojiPresentation || (first.properties.isEmoji && unicodeScalars.count > 1)
    }
}

#Preview("Nuovo obiettivo") {
    GoalEditorView(mode: .new)
        .modelContainer(for: [Goal.self, DayEntry.self], inMemory: true)
        .tint(.brainTint)
}
