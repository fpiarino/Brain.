import XCTest
@testable import Brain

final class DayKeyTests: XCTestCase {

    func testRawValueRoundTrip() {
        let key = day(20261011)
        XCTAssertEqual(key.year, 2026)
        XCTAssertEqual(key.month, 10)
        XCTAssertEqual(key.day, 11)
        XCTAssertEqual(key.rawValue, 20261011)
    }

    func testInvalidRawValuesAreRejected() {
        XCTAssertNil(DayKey(rawValue: 20260230))
        XCTAssertNil(DayKey(rawValue: 20261301))
        XCTAssertNil(DayKey(rawValue: 20261000))
        XCTAssertNil(DayKey(rawValue: 20250229))
        XCTAssertNil(DayKey(rawValue: 0))
        XCTAssertNotNil(DayKey(rawValue: 20240229))
    }

    func testOrdinalReferencePoints() {
        XCTAssertEqual(day(19700101).ordinal, 0)
        XCTAssertEqual(day(19691231).ordinal, -1)
        XCTAssertEqual(day(20000301).ordinal, 11_017)
        XCTAssertEqual(day(20261011).ordinal, 20_737)
    }

    func testOrdinalRoundTripOverManyYears() {
        // Dal 2020 al 2031: ogni giorno deve tornare uguale a sé stesso.
        for ordinal in 18_262...22_644 {
            XCTAssertEqual(DayKey(ordinal: ordinal).ordinal, ordinal)
        }
    }

    func testConsecutiveOrdinalsAreConsecutiveDates() {
        var previous = DayKey(ordinal: 18_262)
        for ordinal in 18_263...22_644 {
            let current = DayKey(ordinal: ordinal)
            XCTAssertLessThan(previous, current)
            if current.day != 1 {
                XCTAssertEqual(current.day, previous.day + 1)
            }
            previous = current
        }
    }

    func testAddingAcrossMonthYearAndLeapDay() {
        XCTAssertEqual(day(20261231).adding(days: 1), day(20270101))
        XCTAssertEqual(day(20240228).adding(days: 1), day(20240229))
        XCTAssertEqual(day(20240228).adding(days: 2), day(20240301))
        XCTAssertEqual(day(20260301).adding(days: -1), day(20260228))
        XCTAssertEqual(day(20261011).adding(days: 0), day(20261011))
        XCTAssertEqual(day(20261011).adding(days: 365), day(20271011))
    }

    func testIsoWeekday() {
        XCTAssertEqual(day(19700101).isoWeekday, 4) // giovedì
        XCTAssertEqual(day(20261001).isoWeekday, 4) // giovedì
        XCTAssertEqual(day(20261011).isoWeekday, 7) // domenica
        XCTAssertEqual(day(20261012).isoWeekday, 1) // lunedì
        XCTAssertEqual(day(19691229).isoWeekday, 1) // lunedì, prima del 1970
    }

    func testComparable() {
        XCTAssertLessThan(day(20261011), day(20261012))
        XCTAssertLessThan(day(20261231), day(20270101))
        XCTAssertEqual(max(day(20260915), day(20261001)), day(20261001))
    }

    func testDateConversionAroundDaylightSavingChange() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Rome"))

        // 25 ottobre 2026: fine dell'ora legale in Italia (giornata di 25 ore).
        let lateEvening = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 23, minute: 30)))
        XCTAssertEqual(DayKey(lateEvening, calendar: calendar), day(20261025))

        let midnight = day(20261025).startDate(calendar: calendar)
        XCTAssertEqual(DayKey(midnight, calendar: calendar), day(20261025))
        XCTAssertEqual(DayKey(midnight.addingTimeInterval(25 * 3600 - 1), calendar: calendar), day(20261025))
        XCTAssertEqual(DayKey(midnight.addingTimeInterval(25 * 3600), calendar: calendar), day(20261026))
    }
}
