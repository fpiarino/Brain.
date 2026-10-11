import Foundation
import SwiftData

/// Quello che hai registrato per un obiettivo in un giorno.
/// Un giorno senza `DayEntry` (o con tutti i campi vuoti) è "non registrato".
@Model
final class DayEntry {
    static let noStatus = -1

    /// Giorno come intero `yyyymmdd`.
    var dayRaw: Int = 0
    /// Valore grezzo di `DayStatus` (0 non fatto, 1 fatto, 2 pausa) oppure -1 se non c'è uno stato.
    var statusRaw: Int = -1
    var updatedAt: Date = Date()
    var goal: Goal?

    // MARK: v2

    /// Valore per gli obiettivi numerici.
    var value: Double? = nil
    /// Nota libera del giorno.
    var note: String = ""
    /// Il valore è stato letto da Apple Salute (e può essere aggiornato da lì).
    var fromHealth: Bool = false

    init(day: DayKey) {
        self.dayRaw = day.rawValue
        self.statusRaw = DayEntry.noStatus
        self.updatedAt = Date()
    }

    var status: DayStatus? {
        get { DayStatus(rawValue: statusRaw) }
        set { statusRaw = newValue?.rawValue ?? DayEntry.noStatus }
    }

    var record: DayRecord {
        DayRecord(status: status, value: value, fromHealth: fromHealth)
    }

    /// Non contiene più nulla: può essere eliminata.
    var isEmpty: Bool {
        status == nil && value == nil && note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Copia dei campi, usata per "Annulla".
    var snapshot: EntrySnapshot {
        EntrySnapshot(statusRaw: statusRaw, value: value, note: note, fromHealth: fromHealth)
    }
}

/// Copia dei dati di un giorno, per poter annullare una modifica.
struct EntrySnapshot: Equatable, Sendable {
    var statusRaw: Int
    var value: Double?
    var note: String
    var fromHealth: Bool
}
