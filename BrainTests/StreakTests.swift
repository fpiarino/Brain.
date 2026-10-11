import XCTest
@testable import Brain

final class StreakTests: XCTestCase {

    // MARK: - Serie attuale

    func testCurrentStreakMatchesMockup() throws {
        let streak = try XCTUnwrap(GoalStats.currentStreak(
            entries: MockupScenario.entries,
            startDay: MockupScenario.startDay,
            today: MockupScenario.today
        ))
        XCTAssertEqual(streak.length, 5)
        XCTAssertEqual(streak.start, day(20261007))
        XCTAssertEqual(streak.end, day(20261011))
    }

    func testTodayNotYetRegisteredKeepsStreakAlive() throws {
        var entries = MockupScenario.entries
        entries[day(20261011)] = nil
        let streak = try XCTUnwrap(GoalStats.currentStreak(
            entries: entries,
            startDay: MockupScenario.startDay,
            today: MockupScenario.today
        ))
        XCTAssertEqual(streak.length, 4)
        XCTAssertEqual(streak.end, day(20261010))
    }

    func testTodayMissedResetsStreak() {
        var entries = MockupScenario.entries
        entries[day(20261011)] = .missed
        XCTAssertNil(GoalStats.currentStreak(
            entries: entries,
            startDay: MockupScenario.startDay,
            today: MockupScenario.today
        ))
    }

    func testUnregisteredPastDayBreaksStreak() throws {
        // 8, 9 fatti, 10 vuoto, 11 fatto: la serie attuale è solo 1.
        let entries = makeEntries(done: [day(20261008), day(20261009), day(20261011)])
        let streak = try XCTUnwrap(GoalStats.currentStreak(
            entries: entries,
            startDay: day(20261001),
            today: day(20261011)
        ))
        XCTAssertEqual(streak.length, 1)
    }

    func testYesterdayUnregisteredAndTodayUnregisteredMeansNoStreak() {
        let entries = makeEntries(done: days(20261001, through: 20261009))
        XCTAssertNil(GoalStats.currentStreak(entries: entries, startDay: day(20261001), today: day(20261011)))
    }

    func testCurrentStreakCrossesMonthBoundary() throws {
        let streak = try XCTUnwrap(GoalStats.currentStreak(
            entries: MockupScenario.entries,
            startDay: MockupScenario.startDay,
            today: day(20261003)
        ))
        XCTAssertEqual(streak.start, day(20260928))
        XCTAssertEqual(streak.length, 6)
    }

    func testCurrentStreakStopsAtStartDay() throws {
        // Giorni fatti prima dell'inizio (es. data di inizio spostata in avanti) non contano.
        let entries = makeEntries(done: days(20261001, through: 20261011))
        let streak = try XCTUnwrap(GoalStats.currentStreak(entries: entries, startDay: day(20261008), today: day(20261011)))
        XCTAssertEqual(streak.start, day(20261008))
        XCTAssertEqual(streak.length, 4)
    }

    func testCurrentStreakWithNoEntries() {
        XCTAssertNil(GoalStats.currentStreak(entries: [:], startDay: day(20261001), today: day(20261011)))
    }

    func testFirstDayDoneGivesStreakOfOne() throws {
        let entries = makeEntries(done: [day(20261011)])
        let streak = try XCTUnwrap(GoalStats.currentStreak(entries: entries, startDay: day(20261011), today: day(20261011)))
        XCTAssertEqual(streak.length, 1)
    }

    // MARK: - Serie record

    func testBestStreakMatchesMockup() throws {
        let best = try XCTUnwrap(GoalStats.bestStreak(
            entries: MockupScenario.entries,
            startDay: MockupScenario.startDay,
            today: MockupScenario.today
        ))
        XCTAssertEqual(best.start, day(20260918))
        XCTAssertEqual(best.end, day(20260926))
        XCTAssertEqual(best.length, 9)
    }

    func testBestStreakTieKeepsMostRecent() throws {
        let entries = makeEntries(
            done: days(20261001, through: 20261003) + days(20261006, through: 20261008),
            missed: [day(20261004)]
        )
        let best = try XCTUnwrap(GoalStats.bestStreak(entries: entries, startDay: day(20261001), today: day(20261011)))
        XCTAssertEqual(best.length, 3)
        XCTAssertEqual(best.start, day(20261006))
    }

    func testBestStreakEqualsCurrentWhenItIsTheLongest() throws {
        let entries = makeEntries(done: [day(20261001)] + days(20261003, through: 20261011))
        let best = try XCTUnwrap(GoalStats.bestStreak(entries: entries, startDay: day(20261001), today: day(20261011)))
        let current = try XCTUnwrap(GoalStats.currentStreak(entries: entries, startDay: day(20261001), today: day(20261011)))
        XCTAssertEqual(best, current)
        XCTAssertEqual(best.length, 9)
    }

    func testBestStreakIgnoresDaysBeforeStartAndAfterToday() throws {
        let entries = makeEntries(done: days(20260901, through: 20260920) + days(20261012, through: 20261031) + [day(20261005)])
        let best = try XCTUnwrap(GoalStats.bestStreak(entries: entries, startDay: day(20260915), today: day(20261011)))
        XCTAssertEqual(best.start, day(20260915))
        XCTAssertEqual(best.end, day(20260920))
        XCTAssertEqual(best.length, 6)
    }

    func testBestStreakIsNilWithoutDoneDays() {
        let entries = makeEntries(missed: days(20261001, through: 20261005))
        XCTAssertNil(GoalStats.bestStreak(entries: entries, startDay: day(20261001), today: day(20261011)))
    }

    func testBestStreakAcrossLeapDay() throws {
        let entries = makeEntries(done: days(20240227, through: 20240302))
        let best = try XCTUnwrap(GoalStats.bestStreak(entries: entries, startDay: day(20240101), today: day(20240310)))
        XCTAssertEqual(best.length, 5) // 27, 28, 29 febbraio, 1, 2 marzo
    }

    func testBestStreakAcrossYearBoundary() throws {
        let entries = makeEntries(done: days(20261230, through: 20270102))
        let best = try XCTUnwrap(GoalStats.bestStreak(entries: entries, startDay: day(20261201), today: day(20270110)))
        XCTAssertEqual(best.length, 4)
    }
}
