import Foundation
import PulseServices
import Testing

struct HevyDateTests {
    private let calendar = TestClock.calendar

    @Test func frenchAndEnglishDatesParseInParis() {
        #expect(HevyDate.parse("27 oct. 2026, 07:17", calendar: calendar) == TestClock.date("2026-10-27T07:17"))
        #expect(HevyDate.parse("27 Oct 2026, 07:17", calendar: calendar) == TestClock.date("2026-10-27T07:17"))
        #expect(HevyDate.parse("3 févr. 2026, 18:30", calendar: calendar) == TestClock.date("2026-02-03T18:30"))
        #expect(HevyDate.parse("12 août 2026, 06:47", calendar: calendar) == TestClock.date("2026-08-12T06:47"))
        #expect(HevyDate.parse("31 foo 2026, 07:00", calendar: calendar) == nil)
    }

    @Test func everyMonthNameParsesWithOrWithoutDotAndInAnyCase() {
        let french = ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc."]
        let english = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        for month in 1...12 {
            let expected = calendar.date(from: DateComponents(year: 2026, month: month, day: 5, hour: 9, minute: 5))
            let names = [french[month - 1], french[month - 1].replacingOccurrences(of: ".", with: ""),
                         french[month - 1].uppercased(), english[month - 1], english[month - 1].lowercased()]
            for name in names {
                #expect(HevyDate.parse("5 \(name) 2026, 09:05", calendar: calendar) == expected, "\(name)")
            }
        }
    }

    @Test func malformedDatesAreRejected() {
        for text in ["", "27 oct. 2026", "oct. 27 2026, 07:17", "32 oct. 2026, 07:17", "27 oct. 2026, 25:00", "27 oct. 2026, 07:61",
                     "27 oct. 2026 07:17", "x oct. 2026, 07:17"] {
            #expect(HevyDate.parse(text, calendar: calendar) == nil, "\(text)")
        }
    }

    @Test func surroundingWhitespaceIsIgnored() {
        #expect(HevyDate.parse("  27 oct. 2026, 07:17 ", calendar: calendar) == TestClock.date("2026-10-27T07:17"))
    }

    @Test func daylightSavingTimesParse() {
        #expect(HevyDate.parse("29 mars 2026, 02:30", calendar: calendar) != nil)
        #expect(HevyDate.parse("25 oct. 2026, 02:30", calendar: calendar) != nil)
    }
}
