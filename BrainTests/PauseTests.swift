import XCTest
@testable import Brain

/// Giorni in pausa: neutri per percentuale e serie.
final class PauseTests: XCTestCase {

    private func entries(done: [DayKey] = [], missed: [DayKey] = [], paused: [DayKey] = []) -> [DayKey: DayStatus] {
        var result = makeEntries(done: done, missed: missed)
        for key in paused { result[key] = .paused }
        return result
    }

    func testPausedDaysAreExcludedFromPercentage() {
        // 1–3 fatti, 4–5 pausa, 6 non fatto, 7 vuoto, oggi 8.
        let map = entries(done: days(20261001, through: 20261003), missed: [day(20261006)], paused: [day(20261004), day(20261005)])
        let summary = GoalStats.monthSummary(entries: map, month: YearMonth(year: 2026, month: 10), startDay: day(20261001), today: day(20261008))
        XCTAssertEqual(summary.done, 3)
        XCTAssertEqual(summary.missed, 1)
        XCTAssertEqual(summary.paused, 2)
        XCTAssertEqual(summary.unregistered, 1)
        XCTAssertEqual(summary.successPercent, 75)
    }

    func testPauseDoesNotBreakCurrentStreak() throws {
        // 5, 6 fatti, 7, 8 pausa, 9, 10 fatti, oggi 11 fatto → serie di 5 giorni fatti.
        let map = entries(
            done: days(20261005, through: 20261006) + days(20261009, through: 20261011),
            paused: [day(20261007), day(20261008)]
        )
        let streak = try XCTUnwrap(GoalStats.currentStreak(entries: map, startDay: day(20261001), today: day(20261011)))
        XCTAssertEqual(streak.length, 5)
        XCTAssertEqual(streak.start, day(20261005))
        XCTAssertEqual(streak.end, day(20261011))
    }

    func testTodayPausedKeepsStreakFromYesterday() throws {
        let map = entries(done: days(20261008, through: 20261010), paused: [day(20261011)])
        let streak = try XCTUnwrap(GoalStats.currentStreak(entries: map, startDay: day(20261001), today: day(20261011)))
        XCTAssertEqual(streak.length, 3)
        XCTAssertEqual(streak.end, day(20261010))
    }

    func testOnlyPausedDaysGiveNoStreak() {
        let map = entries(paused: days(20261001, through: 20261011))
        XCTAssertNil(GoalStats.currentStreak(entries: map, startDay: day(20261001), today: day(20261011)))
        XCTAssertNil(GoalStats.bestStreak(entries: map, startDay: day(20261001), today: day(20261011)))
    }

    func testPauseDoesNotBreakBestStreak() throws {
        // 1–3 fatti, 4 pausa, 5–6 fatti, 7 non fatto, 8–11 fatti → record 5 (1–6).
        let map = entries(
            done: days(20261001, through: 20261003) + days(20261005, through: 20261006) + days(20261008, through: 20261011),
            missed: [day(20261007)],
            paused: [day(20261004)]
        )
        let best = try XCTUnwrap(GoalStats.bestStreak(entries: map, startDay: day(20261001), today: day(20261011)))
        XCTAssertEqual(best.length, 5)
        XCTAssertEqual(best.start, day(20261001))
        XCTAssertEqual(best.end, day(20261006))
    }

    func testUnregisteredTodayDoesNotCloseBestStreak() throws {
        let map = entries(done: days(20261001, through: 20261010))
        let best = try XCTUnwrap(GoalStats.bestStreak(entries: map, startDay: day(20261001), today: day(20261011)))
        XCTAssertEqual(best.length, 10)
    }

    func testTotalsSinceStart() {
        let totals = GoalStats.totals(entries: MockupScenario.entries, startDay: MockupScenario.startDay, today: MockupScenario.today)
        XCTAssertEqual(totals.done, 21)
        XCTAssertEqual(totals.missed, 4)
        XCTAssertEqual(totals.unregistered, 2)
        XCTAssertEqual(totals.successPercent, 84)
    }
}
