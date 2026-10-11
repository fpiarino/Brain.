import XCTest
@testable import Brain

/// Obiettivi "N volte a settimana". Ottobre 2026: le settimane iniziano lunedì 28/9, 5/10, 12/10…
final class WeeklyStatsTests: XCTestCase {

    private let startDay = day(20260928)

    func testWeekSucceedsWhenTargetReached() {
        let map = makeEntries(done: [day(20260928), day(20260930), day(20261002)])
        let week = WeeklyStats.week(startingOn: day(20260928), entries: map, weeklyTarget: 3, startDay: startDay, today: day(20261011))
        XCTAssertEqual(week.state, .success)
        XCTAssertEqual(week.done, 3)
        XCTAssertEqual(week.target, 3)
    }

    func testEndedWeekBelowTargetFails() {
        let map = makeEntries(done: [day(20261006)])
        let week = WeeklyStats.week(startingOn: day(20261005), entries: map, weeklyTarget: 3, startDay: startDay, today: day(20261012))
        XCTAssertEqual(week.state, .failed)
    }

    func testCurrentWeekIsInProgressUntilSundayIsOver() {
        let map = makeEntries(done: [day(20261005)])
        // Oggi è domenica 11: la settimana non è ancora finita.
        let week = WeeklyStats.week(startingOn: day(20261005), entries: map, weeklyTarget: 3, startDay: startDay, today: day(20261011))
        XCTAssertEqual(week.state, .inProgress)
    }

    func testCurrentWeekSucceedsEarly() {
        let map = makeEntries(done: [day(20261005), day(20261006)])
        let week = WeeklyStats.week(startingOn: day(20261005), entries: map, weeklyTarget: 2, startDay: startDay, today: day(20261007))
        XCTAssertEqual(week.state, .success)
    }

    func testPausedDaysLowerTheWeeklyTarget() {
        // Obiettivo 5, ma 4 giorni in pausa: restano 3 giorni disponibili → obiettivo 3.
        var map = makeEntries(done: [day(20261005), day(20261006), day(20261007)])
        for key in days(20261008, through: 20261011) { map[key] = .paused }
        let week = WeeklyStats.week(startingOn: day(20261005), entries: map, weeklyTarget: 5, startDay: startDay, today: day(20261012))
        XCTAssertEqual(week.target, 3)
        XCTAssertEqual(week.state, .success)
    }

    func testFirstPartialWeekUsesOnlyDaysAfterStart() {
        // Inizio giovedì 1/10: disponibili 4 giorni (gio–dom), obiettivo 5 → 4.
        let map = makeEntries(done: days(20261001, through: 20261003))
        let week = WeeklyStats.week(startingOn: day(20260928), entries: map, weeklyTarget: 5, startDay: day(20261001), today: day(20261010))
        XCTAssertEqual(week.target, 4)
        XCTAssertEqual(week.state, .failed)
    }

    func testFullyPausedWeekIsNeutralAndDoesNotBreakStreak() throws {
        var map = makeEntries(done: [day(20260928), day(20260929)] + [day(20261012), day(20261013)])
        for key in days(20261005, through: 20261011) { map[key] = .paused }
        let streak = try XCTUnwrap(WeeklyStats.currentStreak(entries: map, weeklyTarget: 2, startDay: startDay, today: day(20261014)))
        XCTAssertEqual(streak.length, 2)
        XCTAssertEqual(streak.start, day(20260928))
        XCTAssertEqual(streak.end, day(20261012))
    }

    func testCurrentStreakIgnoresWeekInProgress() throws {
        let map = makeEntries(done: [day(20260928), day(20260929), day(20261005), day(20261006)])
        // Settimana del 12/10 in corso con 0 fatti: la serie resta 2.
        let streak = try XCTUnwrap(WeeklyStats.currentStreak(entries: map, weeklyTarget: 2, startDay: startDay, today: day(20261013)))
        XCTAssertEqual(streak.length, 2)
    }

    func testFailedWeekBreaksStreak() {
        let map = makeEntries(done: [day(20260928), day(20260929), day(20261005)])
        XCTAssertNil(WeeklyStats.currentStreak(entries: map, weeklyTarget: 2, startDay: startDay, today: day(20261013)))
    }

    func testBestStreakOfWeeks() throws {
        // Riuscite: 28/9, 5/10; fallita 12/10; riuscita 19/10.
        let map = makeEntries(done: [day(20260928), day(20260929), day(20261005), day(20261006), day(20261019), day(20261020)])
        let best = try XCTUnwrap(WeeklyStats.bestStreak(entries: map, weeklyTarget: 2, startDay: startDay, today: day(20261021)))
        XCTAssertEqual(best.length, 2)
        XCTAssertEqual(best.start, day(20260928))
    }

    func testMonthSummaryAssignsWeeksByTheirSunday() {
        // Settimane con la domenica in ottobre: 28/9 (dom 4/10), 5/10, 12/10 e 19/10 (in corso).
        let map = makeEntries(done: [day(20260928), day(20260929), day(20261005), day(20261012), day(20261013)])
        let summary = WeeklyStats.monthSummary(entries: map, month: YearMonth(year: 2026, month: 10), weeklyTarget: 2, startDay: startDay, today: day(20261020))
        XCTAssertEqual(summary.weeks.map(\.weekStart), [day(20260928), day(20261005), day(20261012), day(20261019)])
        XCTAssertEqual(summary.weeks.last?.state, .inProgress)
        XCTAssertEqual(summary.succeeded, 2)
        XCTAssertEqual(summary.failed, 1)
        XCTAssertEqual(summary.successPercent, 67)
        XCTAssertEqual(summary.doneDays, 3) // 5, 12, 13 ottobre
    }

    func testWeekStart() {
        XCTAssertEqual(day(20261011).weekStart, day(20261005))
        XCTAssertEqual(day(20261005).weekStart, day(20261005))
        XCTAssertEqual(day(20270101).weekStart, day(20261228))
    }
}
