import Foundation

/// Contenuto di un file di backup di Brain (JSON leggibile).
struct BackupFile: Codable, Equatable, Sendable {
    static let currentVersion = 1

    var formatVersion: Int
    var app: String
    var exportedAt: Date
    var goals: [GoalBackup]

    init(exportedAt: Date, goals: [GoalBackup]) {
        self.formatVersion = BackupFile.currentVersion
        self.app = "Brain"
        self.exportedAt = exportedAt
        self.goals = goals
    }
}

struct GoalBackup: Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var details: String
    var emoji: String
    var color: String
    var startDay: Int
    var createdAt: Date
    var archivedAt: Date?
    var sortOrder: Int
    var kind: String
    var weeklyTarget: Int
    var numericTarget: Double
    var comparison: String
    var unit: String
    var healthMetric: String?
    var entries: [EntryBackup]
}

struct EntryBackup: Codable, Equatable, Sendable {
    /// Giorno `yyyymmdd`.
    var day: Int
    /// 0 = non fatto, 1 = fatto, 2 = pausa, assente = nessuno stato.
    var status: Int?
    var value: Double?
    var note: String?
    var fromHealth: Bool?
}

enum BackupError: LocalizedError, Equatable {
    case notABrainBackup
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case .notABrainBackup:
            "Il file non è un backup di Brain."
        case .unsupportedVersion(let version):
            "Il backup è stato creato da una versione più recente di Brain (formato \(version))."
        }
    }
}

/// Codifica e decodifica i backup, ripulendo i dati non validi.
enum BackupCodec {

    static func encode(_ file: BackupFile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(file)
    }

    /// Decodifica e normalizza: scarta giorni non validi e stati sconosciuti,
    /// tiene una sola registrazione per giorno (l'ultima nel file).
    static func decode(_ data: Data) throws -> BackupFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let file: BackupFile
        do {
            file = try decoder.decode(BackupFile.self, from: data)
        } catch {
            throw BackupError.notABrainBackup
        }
        guard file.app == "Brain" else { throw BackupError.notABrainBackup }
        guard file.formatVersion <= BackupFile.currentVersion else {
            throw BackupError.unsupportedVersion(file.formatVersion)
        }

        var cleaned = file
        var seenGoals = Set<UUID>()
        cleaned.goals = file.goals.compactMap { goal in
            guard seenGoals.insert(goal.id).inserted else { return nil }
            var goal = goal
            if DayKey(rawValue: goal.startDay) == nil {
                goal.startDay = DayKey(goal.createdAt).rawValue
            }
            goal.weeklyTarget = min(max(goal.weeklyTarget, 1), 7)

            var byDay: [Int: EntryBackup] = [:]
            for entry in goal.entries {
                guard DayKey(rawValue: entry.day) != nil else { continue }
                var entry = entry
                if let status = entry.status, DayStatus(rawValue: status) == nil {
                    entry.status = nil
                }
                if let value = entry.value, !value.isFinite { entry.value = nil }
                let hasNote = !(entry.note ?? "").isEmpty
                guard entry.status != nil || entry.value != nil || hasNote else { continue }
                byDay[entry.day] = entry
            }
            goal.entries = byDay.values.sorted { $0.day < $1.day }
            return goal
        }
        return cleaned
    }

    /// Nome file suggerito, es. `Brain-backup-2026-10-11.json`.
    static func suggestedFileName(for day: DayKey) -> String {
        String(format: "Brain-backup-%04d-%02d-%02d.json", day.year, day.month, day.day)
    }
}
