import Foundation
import SwiftData

/// Tutte le scritture passano da qui, così le regole sono in un solo posto:
/// - al massimo una registrazione per obiettivo e giorno (`#Unique` richiede iOS 18, quindi lo garantiamo noi);
/// - una registrazione vuota (niente stato, valore o nota) viene eliminata;
/// - salvataggio esplicito dopo ogni modifica, poi aggiornamento del widget.
extension ModelContext {

    // MARK: Lettura

    func goal(withID id: UUID) -> Goal? {
        var descriptor = FetchDescriptor<Goal>(predicate: #Predicate<Goal> { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? fetch(descriptor))?.first
    }

    func activeGoals() -> [Goal] {
        let descriptor = FetchDescriptor<Goal>(
            predicate: #Predicate<Goal> { $0.archivedAt == nil },
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
        )
        return (try? fetch(descriptor)) ?? []
    }

    func allGoals() -> [Goal] {
        let descriptor = FetchDescriptor<Goal>(sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)])
        return (try? fetch(descriptor)) ?? []
    }

    /// Prossimo valore di ordinamento per un nuovo obiettivo.
    func nextSortOrder() -> Int {
        var descriptor = FetchDescriptor<Goal>(sortBy: [SortDescriptor(\.sortOrder, order: .reverse)])
        descriptor.fetchLimit = 1
        let last = (try? fetch(descriptor))?.first
        return (last?.sortOrder ?? -1) + 1
    }

    /// Numero totale di obiettivi (archiviati compresi), usato per scegliere il colore successivo.
    func goalCount() -> Int {
        (try? fetchCount(FetchDescriptor<Goal>())) ?? 0
    }

    // MARK: Registrazioni

    /// La registrazione del giorno, creata se manca. Elimina eventuali doppioni.
    private func entryForWriting(goal: Goal, day: DayKey) -> DayEntry {
        let raw = day.rawValue
        let matches = (goal.entries ?? []).filter { $0.dayRaw == raw }
        for duplicate in matches.dropFirst() {
            delete(duplicate)
        }
        if let existing = matches.first {
            return existing
        }
        // Prima si inserisce nel contesto, poi si collega all'obiettivo:
        // è l'ordine raccomandato da Apple per le relazioni SwiftData.
        let entry = DayEntry(day: day)
        insert(entry)
        entry.goal = goal
        return entry
    }

    private func finish(_ entry: DayEntry, save: Bool) {
        entry.updatedAt = Date()
        if entry.isEmpty {
            delete(entry)
        }
        if save { saveQuietly() }
    }

    /// Imposta lo stato di un giorno. `nil` lo riporta a "non registrato" (resta l'eventuale nota).
    /// Lo stato sostituisce un eventuale valore numerico.
    func setStatus(_ status: DayStatus?, for goal: Goal, on day: DayKey) {
        let entry = entryForWriting(goal: goal, day: day)
        entry.status = status
        entry.value = nil
        entry.fromHealth = false
        finish(entry, save: true)
    }

    /// Imposta il valore di un obiettivo numerico. `nil` lo cancella.
    func setValue(_ value: Double?, for goal: Goal, on day: DayKey, fromHealth: Bool = false, save: Bool = true) {
        let entry = entryForWriting(goal: goal, day: day)
        entry.value = value
        entry.fromHealth = value != nil && fromHealth
        if entry.status != .paused || value != nil {
            entry.status = nil
        }
        finish(entry, save: save)
    }

    func setNote(_ note: String, for goal: Goal, on day: DayKey) {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty && goal.entry(on: day) == nil { return }
        let entry = entryForWriting(goal: goal, day: day)
        guard entry.note != trimmed else { return }
        entry.note = trimmed
        finish(entry, save: true)
    }

    /// Segna fatto/non fatto; se il giorno aveva già quello stato lo riporta a "non registrato".
    /// Restituisce la copia dei dati precedenti, per poter annullare.
    @discardableResult
    func toggle(_ status: DayStatus, for goal: Goal, on day: DayKey) -> EntrySnapshot? {
        let previous = goal.entry(on: day)?.snapshot
        let current = goal.entry(on: day)?.status
        setStatus(current == status ? nil : status, for: goal, on: day)
        return previous
    }

    /// Ripristina i dati di un giorno com'erano (`nil` = nessuna registrazione).
    func restore(_ snapshot: EntrySnapshot?, for goal: Goal, on day: DayKey) {
        let entry = entryForWriting(goal: goal, day: day)
        entry.statusRaw = snapshot?.statusRaw ?? DayEntry.noStatus
        entry.value = snapshot?.value
        entry.note = snapshot?.note ?? ""
        entry.fromHealth = snapshot?.fromHealth ?? false
        finish(entry, save: true)
    }

    /// Valore letto da Apple Salute. Non sovrascrive mai un valore inserito a mano né una pausa.
    /// Restituisce `true` se ha cambiato qualcosa. Non salva: chi chiama salva una volta alla fine.
    @discardableResult
    func applyHealthValue(_ value: Double, for goal: Goal, on day: DayKey) -> Bool {
        if let existing = goal.entry(on: day) {
            if existing.status == .paused { return false }
            if existing.status != nil && existing.value == nil { return false }
            if existing.value != nil && !existing.fromHealth { return false }
            if existing.fromHealth, let old = existing.value, abs(old - value) < 0.5 { return false }
        }
        setValue(value, for: goal, on: day, fromHealth: true, save: false)
        return true
    }

    // MARK: Obiettivi

    func setArchived(_ archived: Bool, goal: Goal) {
        goal.archivedAt = archived ? Date() : nil
        saveQuietly()
    }

    /// Salva il nuovo ordine degli obiettivi.
    func reorder(_ goals: [Goal]) {
        for (index, goal) in goals.enumerated() where goal.sortOrder != index {
            goal.sortOrder = index
        }
        saveQuietly()
    }

    /// Elimina l'obiettivo e tutte le sue registrazioni.
    /// Le registrazioni vengono cancellate esplicitamente perché su iOS 17 la
    /// cancellazione a cascata di SwiftData non è sempre affidabile.
    func deleteGoal(_ goal: Goal) {
        for entry in goal.entries ?? [] {
            delete(entry)
        }
        delete(goal)
        saveQuietly()
    }

    // MARK: Backup

    func makeBackup(exportedAt: Date = Date()) -> BackupFile {
        let goals = allGoals().map { goal in
            GoalBackup(
                id: goal.id,
                name: goal.name,
                details: goal.details,
                emoji: goal.emoji,
                color: goal.colorKey,
                startDay: goal.startDayRaw,
                createdAt: goal.createdAt,
                archivedAt: goal.archivedAt,
                sortOrder: goal.sortOrder,
                kind: goal.kindRaw,
                weeklyTarget: goal.weeklyTarget,
                numericTarget: goal.numericTarget,
                comparison: goal.comparisonRaw,
                unit: goal.unit,
                healthMetric: goal.healthMetricRaw,
                entries: (goal.entries ?? [])
                    .filter { !$0.isEmpty }
                    .sorted { $0.dayRaw < $1.dayRaw }
                    .map { entry in
                        EntryBackup(
                            day: entry.dayRaw,
                            status: entry.status?.rawValue,
                            value: entry.value,
                            note: entry.note.isEmpty ? nil : entry.note,
                            fromHealth: entry.fromHealth ? true : nil
                        )
                    }
            )
        }
        return BackupFile(exportedAt: exportedAt, goals: goals)
    }

    /// Sostituisce tutti i dati con quelli del backup.
    func replaceAll(with backup: BackupFile) {
        for goal in allGoals() {
            deleteGoalWithoutSaving(goal)
        }
        for item in backup.goals {
            let goal = Goal(name: item.name)
            insert(goal)
            goal.id = item.id
            goal.details = item.details
            goal.emoji = item.emoji
            goal.colorKey = item.color
            goal.startDayRaw = item.startDay
            goal.createdAt = item.createdAt
            goal.archivedAt = item.archivedAt
            goal.sortOrder = item.sortOrder
            goal.kindRaw = GoalKind(rawValue: item.kind)?.rawValue ?? GoalKind.daily.rawValue
            goal.weeklyTarget = item.weeklyTarget
            goal.numericTarget = item.numericTarget
            goal.comparisonRaw = NumericComparison(rawValue: item.comparison)?.rawValue ?? NumericComparison.atMost.rawValue
            goal.unit = item.unit
            goal.healthMetricRaw = item.healthMetric.flatMap(HealthMetric.init(rawValue:))?.rawValue

            for saved in item.entries {
                guard let day = DayKey(rawValue: saved.day) else { continue }
                let entry = DayEntry(day: day)
                insert(entry)
                entry.goal = goal
                entry.statusRaw = saved.status ?? DayEntry.noStatus
                entry.value = saved.value
                entry.note = saved.note ?? ""
                entry.fromHealth = saved.fromHealth ?? false
            }
        }
        saveQuietly()
    }

    private func deleteGoalWithoutSaving(_ goal: Goal) {
        for entry in goal.entries ?? [] {
            delete(entry)
        }
        delete(goal)
    }

    // MARK: Salvataggio

    func saveQuietly() {
        do {
            try save()
        } catch {
            assertionFailure("Salvataggio non riuscito: \(error)")
        }
        StoreChangeNotifier.didSave()
    }
}
