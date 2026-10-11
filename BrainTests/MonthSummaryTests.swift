import XCTest
@testable import Brain

final class MonthSummaryTests: XCTestCase {

    func testOctoberMatchesMockup() {
        let summary = GoalStats.monthSummary(
            entries: MockupScenario.entries,
            month: MockupScenario.october,
            startDay: MockupScenario.startDay,
            today: MockupScenario.today
        )
        XCTAssertEqual(summary.done, 8)
        XCTAssertEqual(summary.missed, 2)
        XCTAssertEqual(summary.registered, 10)
        XCTAssertEqual(summary.unregistered, 1)
        XCTAssertEqual(summary.successPercent, 80)
        XCTAssertEqual(try XCTUnwrap(summary.successRate), 0.8, accuracy: 0.000_1)
    }

    func testSeptemberStartsFromStartDay() {
        let summary = GoalStats.monthSummary(
            entries: MockupScenario.entries,
            month: MockupScenario.september,
            startDay: MockupScenario.startDay,
            today: MockupScenario.today
        )
        XCTAssertEqual(summary.done, 13)
        XCTAssertEqual(summary.missed, 2)
        // Solo il 17: i giorni dal 1° al 14 sono prima dell'inizio e non contano.
        XCTAssertEqual(summary.unregistered, 1)
        XCTAssertEqual(summary.successPercent, 87)
    }

    func testUnregisteredDaysDoNotCountAsMissed() {
        // 3 fatti, 1 non fatto, 3 giorni vuoti: la percentuale è 3/4, non 3/7.
        let entries = makeEntries(
            done: [day(20261001), day(20261003), day(20261005)],
            missed: [day(20261002)]
        )
        let summary = GoalStats.monthSummary(
            entries: entries,
            month: MockupScenario.october,
            startDay: day(20261001),
            today: day(20261007)
        )
        XCTAssertEqual(summary.missed, 1)
        XCTAssertEqual(summary.unregistered, 2) // 4 e 6; il 7 è oggi
        XCTAssertEqual(summary.successPercent, 75)
    }

    func testTodayWithoutEntryIsNotCountedAsUnregistered() {
        let summary = GoalStats.monthSummary(
            entries: [:],
            month: MockupScenario.october,
            startDay: day(20261011),
            today: day(20261011)
        )
        XCTAssertEqual(summary, .empty)
        XCTAssertNil(summary.successPercent)
    }

    func testFutureMonthIsEmpty() {
        let summary = GoalStats.monthSummary(
            entries: MockupScenario.entries,
            month: YearMonth(year: 2026, month: 11),
            startDay: MockupScenario.startDay,
            today: MockupScenario.today
        )
        XCTAssertEqual(summary, .empty)
    }

    func testMonthBeforeStartDayIsEmpty() {
        let summary = GoalStats.monthSummary(
            entries: MockupScenario.entries,
            month: YearMonth(year: 2026, month: 8),
            startDay: MockupScenario.startDay,
            today: MockupScenario.today
        )
        XCTAssertEqual(summary, .empty)
    }

    func testEntriesOutsideValidRangeAreIgnored() {
        // Registrazione prima della data di inizio e una nel futuro: non devono contare.
        let entries = makeEntries(
            done: [day(20261002), day(20261005), day(20261020)],
            missed: [day(20261001)]
        )
        let summary = GoalStats.monthSummary(
            entries: entries,
            month: MockupScenario.october,
            startDay: day(20261002),
            today: day(20261011)
        )
        XCTAssertEqual(summary.done, 2)
        XCTAssertEqual(summary.missed, 0)
        XCTAssertEqual(summary.unregistered, 7) // 3, 4, 6, 7, 8, 9, 10
        XCTAssertEqual(summary.successPercent, 100)
    }

    func testOnlyUnregisteredDaysHaveNoPercentage() {
        let summary = GoalStats.monthSummary(
            entries: [:],
            month: MockupScenario.october,
            startDay: day(20261001),
            today: day(20261011)
        )
        XCTAssertEqual(summary.registered, 0)
        XCTAssertEqual(summary.unregistered, 10)
        XCTAssertNil(summary.successRate)
        XCTAssertNil(summary.successPercent)
    }

    func testAllMissedIsZeroPercent() {
        let summary = MonthSummary(done: 0, missed: 4, unregistered: 0)
        XCTAssertEqual(summary.successPercent, 0)
    }

    func testPercentRounding() {
        XCTAssertEqual(MonthSummary(done: 2, missed: 1, unregistered: 0).successPercent, 67)
        XCTAssertEqual(MonthSummary(done: 1, missed: 2, unregistered: 0).successPercent, 33)
        XCTAssertEqual(MonthSummary(done: 1, missed: 7, unregistered: 0).successPercent, 13) // 12,5 → 13
        XCTAssertEqual(MonthSummary(done: 31, missed: 0, unregistered: 0).successPercent, 100)
    }

    func testFullPastMonthCountsEveryDay() {
        // Febbraio 2024 (bisestile) tutto fatto tranne il 29.
        let entries = makeEntries(done: days(20240201, through: 20240228), missed: [day(20240229)])
        let summary = GoalStats.monthSummary(
            entries: entries,
            month: YearMonth(year: 2024, month: 2),
            startDay: day(20240101),
            today: day(20240315)
        )
        XCTAssertEqual(summary.done, 28)
        XCTAssertEqual(summary.missed, 1)
        XCTAssertEqual(summary.unregistered, 0)
        XCTAssertEqual(summary.successPercent, 97)
    }
}
