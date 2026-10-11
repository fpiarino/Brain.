import XCTest
@testable import Brain

final class InsightsTests: XCTestCase {

    func testWeekdayStatsForMockup() {
        let stats = Insights.weekdayStats(entries: MockupScenario.entries, startDay: MockupScenario.startDay, today: MockupScenario.today)
        XCTAssertEqual(stats.count, 7)
        XCTAssertEqual(stats.map(\.weekday), Array(1...7))
        // Domenica (7): 20/9 ✓, 27/9 ✗, 4/10 ✗, 11/10 ✓.
        XCTAssertEqual(stats[6].done, 2)
        XCTAssertEqual(stats[6].missed, 2)
        XCTAssertEqual(stats[6].successPercent, 50)
        // Totali coerenti con il conteggio complessivo.
        XCTAssertEqual(stats.map(\.done).reduce(0, +), 21)
        XCTAssertEqual(stats.map(\.missed).reduce(0, +), 4)
    }

    func testWeakestWeekday() throws {
        let stats = Insights.weekdayStats(entries: MockupScenario.entries, startDay: MockupScenario.startDay, today: MockupScenario.today)
        let weakest = try XCTUnwrap(Insights.weakestWeekday(stats))
        XCTAssertEqual(weakest.weekday, 7)
    }

    func testWeakestWeekdayNeedsEnoughData() {
        let stats = [WeekdayStat(weekday: 1, done: 0, missed: 2)]
        XCTAssertNil(Insights.weakestWeekday(stats))
    }

    func testWeekdayStatsWithFutureStartIsEmpty() {
        let stats = Insights.weekdayStats(entries: [:], startDay: day(20261020), today: day(20261011))
        XCTAssertTrue(stats.allSatisfy { $0.registered == 0 })
    }

    func testYearHeatmap2026() {
        let map = YearHeatmap(year: 2026)
        let columns = map.columns
        // 1/1/2026 è giovedì: la prima colonna ha 3 caselle vuote.
        XCTAssertEqual(columns.first?.prefix(3).allSatisfy { $0 == nil }, true)
        XCTAssertEqual(columns.first?[3], day(20260101))
        XCTAssertEqual(columns.count, 53)
        XCTAssertTrue(columns.allSatisfy { $0.count == 7 })
        XCTAssertEqual(columns.flatMap { $0 }.compactMap { $0 }.count, 365)
        // 31/12/2026 è giovedì: ultime 3 caselle vuote.
        XCTAssertEqual(columns.last?[3], day(20261231))
        XCTAssertNil(columns.last?[4] ?? nil)
    }

    func testYearHeatmapLeapYear() {
        XCTAssertEqual(YearHeatmap(year: 2024).columns.flatMap { $0 }.compactMap { $0 }.count, 366)
    }

    func testReminderHorizonRespectsNotificationLimit() {
        XCTAssertEqual(ReminderPlanner.horizon(goalsPerDay: 1), 14)
        XCTAssertEqual(ReminderPlanner.horizon(goalsPerDay: 4), 14)
        XCTAssertEqual(ReminderPlanner.horizon(goalsPerDay: 5), 12)
        XCTAssertEqual(ReminderPlanner.horizon(goalsPerDay: 10), 6)
        XCTAssertEqual(ReminderPlanner.horizon(goalsPerDay: 100), 1)
        XCTAssertEqual(ReminderPlanner.horizon(goalsPerDay: 0), 14)
    }
}
