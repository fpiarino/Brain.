import XCTest
@testable import Brain

final class BackupCodecTests: XCTestCase {

    private func sampleGoal(entries: [EntryBackup]) -> GoalBackup {
        GoalBackup(
            id: UUID(uuidString: "6E0B7A3C-0000-4000-8000-000000000001")!,
            name: "Meno di 1800 kcal",
            details: "",
            emoji: "🥗",
            color: "orange",
            startDay: 20260915,
            createdAt: Date(timeIntervalSince1970: 1_789_000_000),
            archivedAt: nil,
            sortOrder: 0,
            kind: "numeric",
            weeklyTarget: 3,
            numericTarget: 1800,
            comparison: "atMost",
            unit: "kcal",
            healthMetric: nil,
            entries: entries
        )
    }

    func testRoundTrip() throws {
        let file = BackupFile(
            exportedAt: Date(timeIntervalSince1970: 1_791_720_000),
            goals: [sampleGoal(entries: [
                EntryBackup(day: 20261010, status: nil, value: 1650, note: "cena fuori", fromHealth: false),
                EntryBackup(day: 20261011, status: 2, value: nil, note: nil, fromHealth: nil)
            ])]
        )
        let decoded = try BackupCodec.decode(BackupCodec.encode(file))
        XCTAssertEqual(decoded, file)
    }

    func testRejectsNewerFormat() throws {
        var file = BackupFile(exportedAt: Date(timeIntervalSince1970: 0), goals: [])
        file.formatVersion = 99
        XCTAssertThrowsError(try BackupCodec.decode(BackupCodec.encode(file))) { error in
            XCTAssertEqual(error as? BackupError, .unsupportedVersion(99))
        }
    }

    func testRejectsOtherFiles() {
        XCTAssertThrowsError(try BackupCodec.decode(Data("{\"ciao\": 1}".utf8))) { error in
            XCTAssertEqual(error as? BackupError, .notABrainBackup)
        }
        XCTAssertThrowsError(try BackupCodec.decode(Data("non è json".utf8)))
    }

    func testCleansInvalidData() throws {
        var goal = sampleGoal(entries: [
            EntryBackup(day: 20260230, status: 1, value: nil, note: nil, fromHealth: nil),    // data non valida
            EntryBackup(day: 20261001, status: 7, value: nil, note: nil, fromHealth: nil),    // stato sconosciuto e nient'altro
            EntryBackup(day: 20261002, status: 0, value: nil, note: nil, fromHealth: nil),
            EntryBackup(day: 20261002, status: 1, value: nil, note: nil, fromHealth: nil),    // doppione: vince l'ultimo
            EntryBackup(day: 20261003, status: 9, value: nil, note: "nota", fromHealth: nil)  // stato sconosciuto ma con nota
        ])
        goal.weeklyTarget = 12
        let file = BackupFile(exportedAt: Date(timeIntervalSince1970: 0), goals: [goal, goal])
        let decoded = try BackupCodec.decode(BackupCodec.encode(file))

        XCTAssertEqual(decoded.goals.count, 1) // obiettivo duplicato scartato
        let cleaned = try XCTUnwrap(decoded.goals.first)
        XCTAssertEqual(cleaned.weeklyTarget, 7)
        XCTAssertEqual(cleaned.entries.map(\.day), [20261002, 20261003])
        XCTAssertEqual(cleaned.entries.first?.status, 1)
        XCTAssertNil(cleaned.entries.last?.status)
        XCTAssertEqual(cleaned.entries.last?.note, "nota")
    }

    func testSuggestedFileName() {
        XCTAssertEqual(BackupCodec.suggestedFileName(for: day(20261011)), "Brain-backup-2026-10-11.json")
    }
}
