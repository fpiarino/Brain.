import XCTest
@testable import Brain

final class MonthGridTests: XCTestCase {

    func testOctober2026StartsOnThursday() {
        let grid = MonthGrid(month: YearMonth(year: 2026, month: 10))
        XCTAssertEqual(grid.leadingBlanks, 3)
        XCTAssertEqual(grid.days.count, 31)
        XCTAssertEqual(grid.cells.count, 34)
        XCTAssertNil(grid.cells[2])
        XCTAssertEqual(grid.cells[3], day(20261001))
        XCTAssertEqual(grid.numberOfWeeks, 5)
    }

    func testMonthStartingOnMondayHasNoBlanks() {
        let grid = MonthGrid(month: YearMonth(year: 2021, month: 2))
        XCTAssertEqual(grid.leadingBlanks, 0)
        XCTAssertEqual(grid.days.count, 28)
        XCTAssertEqual(grid.numberOfWeeks, 4)
    }

    func testMonthStartingOnSundayNeedsSixWeeks() {
        let grid = MonthGrid(month: YearMonth(year: 2026, month: 11))
        XCTAssertEqual(grid.leadingBlanks, 6)
        XCTAssertEqual(grid.numberOfWeeks, 6)
    }

    func testYearMonthNavigation() {
        XCTAssertEqual(YearMonth(year: 2026, month: 1).adding(months: -1), YearMonth(year: 2025, month: 12))
        XCTAssertEqual(YearMonth(year: 2026, month: 12).adding(months: 1), YearMonth(year: 2027, month: 1))
        XCTAssertEqual(YearMonth(year: 2026, month: 10).adding(months: 14), YearMonth(year: 2027, month: 12))
        XCTAssertEqual(YearMonth(year: 2026, month: 10).adding(months: -22), YearMonth(year: 2024, month: 12))
        XCTAssertLessThan(YearMonth(year: 2025, month: 12), YearMonth(year: 2026, month: 1))
    }

    func testYearMonthBounds() {
        let february = YearMonth(year: 2024, month: 2)
        XCTAssertEqual(february.firstDay, day(20240201))
        XCTAssertEqual(february.lastDay, day(20240229))
        XCTAssertEqual(YearMonth(day(20261011)), YearMonth(year: 2026, month: 10))
    }
}

final class ReminderPlannerTests: XCTestCase {
    private let today = day(20261011)

    func testIncludesTodayBeforeReminderTimeWhenSomethingIsPending() {
        let plan = ReminderPlanner.days(today: today, minutesNow: 18 * 60, reminderMinutes: 21 * 60, hasPendingToday: true, horizon: 7)
        XCTAssertEqual(plan.first, today)
        XCTAssertEqual(plan.count, 7)
        XCTAssertEqual(plan.last, day(20261017))
    }

    func testSkipsTodayAfterReminderTime() {
        let plan = ReminderPlanner.days(today: today, minutesNow: 22 * 60, reminderMinutes: 21 * 60, hasPendingToday: true, horizon: 7)
        XCTAssertEqual(plan.first, day(20261012))
        XCTAssertEqual(plan.count, 6)
    }

    func testSkipsTodayWhenEverythingIsRegistered() {
        let plan = ReminderPlanner.days(today: today, minutesNow: 8 * 60, reminderMinutes: 21 * 60, hasPendingToday: false, horizon: 7)
        XCTAssertEqual(plan.first, day(20261012))
    }

    func testSkipsTodayAtExactReminderMinute() {
        let plan = ReminderPlanner.days(today: today, minutesNow: 21 * 60, reminderMinutes: 21 * 60, hasPendingToday: true, horizon: 7)
        XCTAssertEqual(plan.first, day(20261012))
    }

    func testEmptyHorizon() {
        XCTAssertEqual(ReminderPlanner.days(today: today, minutesNow: 0, reminderMinutes: 60, hasPendingToday: true, horizon: 0), [])
        XCTAssertEqual(ReminderPlanner.days(today: today, minutesNow: 120, reminderMinutes: 60, hasPendingToday: true, horizon: 1), [])
    }
}
