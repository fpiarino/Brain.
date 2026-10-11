import XCTest
@testable import Brain

/// Obiettivi numerici e lettura dei numeri.
final class GoalRulesTests: XCTestCase {
    private let today = day(20261011)
    private let yesterday = day(20261010)

    private func status(_ record: DayRecord, on date: DayKey, comparison: NumericComparison = .atMost, target: Double = 1800, kind: GoalKind = .numeric) -> DayStatus? {
        GoalRules.effectiveStatus(record, kind: kind, target: target, comparison: comparison, day: date, today: today)
    }

    func testManualValueAtMost() {
        XCTAssertEqual(status(DayRecord(value: 1650), on: yesterday), .done)
        XCTAssertEqual(status(DayRecord(value: 1800), on: yesterday), .done) // soglia inclusa
        XCTAssertEqual(status(DayRecord(value: 1950), on: yesterday), .missed)
    }

    func testManualValueAtLeast() {
        XCTAssertEqual(status(DayRecord(value: 10_000), on: today, comparison: .atLeast, target: 10_000), .done)
        XCTAssertEqual(status(DayRecord(value: 9_999), on: today, comparison: .atLeast, target: 10_000), .missed)
    }

    func testManualValueTodayCountsImmediately() {
        XCTAssertEqual(status(DayRecord(value: 2100), on: today), .missed)
    }

    func testHealthValueTodayIsInProgress() {
        // kcal assunte oggi sotto soglia: la giornata non è finita, quindi non registrato.
        XCTAssertNil(status(DayRecord(value: 900, fromHealth: true), on: today))
        // Sopra soglia "al massimo" oggi: ancora in corso (deciderà la fine della giornata).
        XCTAssertNil(status(DayRecord(value: 2100, fromHealth: true), on: today))
        // Passi oggi già raggiunti: fatto subito.
        XCTAssertEqual(status(DayRecord(value: 12_000, fromHealth: true), on: today, comparison: .atLeast, target: 10_000), .done)
        XCTAssertNil(status(DayRecord(value: 4_000, fromHealth: true), on: today, comparison: .atLeast, target: 10_000))
    }

    func testHealthValuePastDayIsFinal() {
        XCTAssertEqual(status(DayRecord(value: 1700, fromHealth: true), on: yesterday), .done)
        XCTAssertEqual(status(DayRecord(value: 4_000, fromHealth: true), on: yesterday, comparison: .atLeast, target: 10_000), .missed)
    }

    func testPauseWinsOverValue() {
        XCTAssertEqual(status(DayRecord(status: .paused, value: 3000), on: yesterday), .paused)
    }

    func testNumericWithoutValueUsesStoredStatus() {
        XCTAssertEqual(status(DayRecord(status: .done), on: yesterday), .done)
        XCTAssertNil(status(DayRecord(), on: yesterday))
    }

    func testDailyGoalIgnoresValue() {
        XCTAssertEqual(status(DayRecord(status: .missed, value: 10), on: yesterday, kind: .daily), .missed)
        XCTAssertNil(status(DayRecord(value: 10), on: yesterday, kind: .daily))
    }

    func testEffectiveStatusesDropsUnregistered() {
        let records: [DayKey: DayRecord] = [
            yesterday: DayRecord(value: 1500),
            today: DayRecord(value: 800, fromHealth: true)
        ]
        let map = GoalRules.effectiveStatuses(records, kind: .numeric, target: 1800, comparison: .atMost, today: today)
        XCTAssertEqual(map, [yesterday: .done])
    }

    func testParseItalianNumbers() {
        XCTAssertEqual(GoalRules.parseNumber("1800"), 1800)
        XCTAssertEqual(GoalRules.parseNumber("1.800"), 1800)
        XCTAssertEqual(GoalRules.parseNumber("10.000"), 10_000)
        XCTAssertEqual(GoalRules.parseNumber("1.234.567"), 1_234_567)
        XCTAssertEqual(GoalRules.parseNumber("7,5"), 7.5)
        XCTAssertEqual(GoalRules.parseNumber("1.800,5"), 1800.5)
        XCTAssertEqual(GoalRules.parseNumber(" 2,25 "), 2.25)
        XCTAssertEqual(GoalRules.parseNumber("7.5"), 7.5)
        XCTAssertNil(GoalRules.parseNumber(""))
        XCTAssertNil(GoalRules.parseNumber("abc"))
        XCTAssertNil(GoalRules.parseNumber("-5"))
    }
}
