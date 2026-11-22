import Foundation
import Testing

@testable import PulseDesignSystem

private let parisCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Paris") ?? .gmt
    calendar.locale = Locale(identifier: "fr_FR")
    return calendar
}()

@Test func countAgreesInNumber() {
    #expect(PulseSpoken.count(0, singular: "série", plural: "séries") == "0 série")
    #expect(PulseSpoken.count(1, singular: "série", plural: "séries") == "1 série")
    #expect(PulseSpoken.count(2, singular: "série", plural: "séries") == "2 séries")
    #expect(PulseSpoken.count(12, singular: "série", plural: "séries") == "12 séries")
}

@Test func countGroupsThousandsWithANonBreakingSpace() {
    #expect(PulseSpoken.count(12450, singular: "kilo", plural: "kilos") == "12\u{202F}450 kilos")
}

@Test func kilosAreSpokenInFull() {
    #expect(PulseSpoken.kilos(80) == "80 kilos")
    #expect(PulseSpoken.kilos(62.5) == "62,5 kilos")
    #expect(PulseSpoken.kilos(1) == "1 kilo")
    #expect(PulseSpoken.kilos(12450) == "12\u{202F}450 kilos")
}

@Test func kilosPluralFollowsTheSpokenValue() {
    #expect(PulseSpoken.kilos(1.996) == "2 kilos")
    #expect(PulseSpoken.kilos(1.994) == "1,99 kilo")
    #expect(PulseSpoken.kilos(0.5) == "0,5 kilo")
    #expect(PulseSpoken.kilos(2) == "2 kilos")
}

@Test func durationsAreSpokenWithoutAbbreviations() {
    #expect(PulseSpoken.duration(seconds: 45) == "45 secondes")
    #expect(PulseSpoken.duration(seconds: 59) == "59 secondes")
    #expect(PulseSpoken.duration(seconds: 1) == "1 seconde")
    #expect(PulseSpoken.duration(seconds: 60) == "1 minute")
    #expect(PulseSpoken.duration(seconds: 90) == "1 minute 30")
    #expect(PulseSpoken.duration(seconds: 120) == "2 minutes")
    #expect(PulseSpoken.duration(seconds: 3600) == "1 heure")
    #expect(PulseSpoken.duration(seconds: 2 * 3600 + 5 * 60) == "2 heures 5 minutes")
    #expect(PulseSpoken.duration(seconds: 3600 + 45 * 60 + 7) == "1 heure 45 minutes 7")
    #expect(PulseSpoken.duration(seconds: 3600 + 7) == "1 heure 7 secondes")
    #expect(PulseSpoken.duration(seconds: 0) == "0 seconde")
    #expect(PulseSpoken.duration(seconds: -5) == "0 seconde")
}

@Test func paceIsSpokenPerKilometer() {
    #expect(PulseSpoken.pace(secondsPerKilometer: 5 * 60 + 29) == "5 minutes 29 par kilomètre")
    #expect(PulseSpoken.pace(secondsPerKilometer: 6 * 60) == "6 minutes par kilomètre")
}

@Test func clockIsSpokenInHours() {
    #expect(PulseSpoken.clock(hour: 8, minute: 0) == "8 heures")
    #expect(PulseSpoken.clock(hour: 8, minute: 30) == "8 heures 30")
    #expect(PulseSpoken.clock(hour: 1, minute: 5) == "1 heure 5")
}

@Test func outOfReadsAsAFraction() {
    #expect(PulseSpoken.outOf(9, 12) == "9 sur 12")
}

@Test func datesSpellTheMonthOut() throws {
    let date = try #require(parisCalendar.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 12)))
    #expect(PulseSpoken.date(date, calendar: parisCalendar) == "28 octobre")
    #expect(PulseSpoken.weekday(date, calendar: parisCalendar) == "mercredi")
    let monday = try #require(parisCalendar.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 12)))
    #expect(PulseSpoken.weekday(monday, calendar: parisCalendar) == "lundi")
    #expect(PulseSpoken.date(monday, calendar: parisCalendar) == "23 novembre")
}
