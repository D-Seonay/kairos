import Foundation
@testable import PulseServices
import Testing

/// Les mots que le module des services dit lui-même (`PulseFormat` du design system n'y est pas accessible) : le singulier
/// jusqu'à 1, les milliers séparés, d'après la valeur arrondie telle qu'elle est dite.
struct LiveSessionSpokenTextTests {
    @Test func kilosAgreeInNumberFromTheRoundedValue() {
        #expect(LiveSessionText.kilosSpoken(70) == "70 kilos")
        #expect(LiveSessionText.kilosSpoken(1) == "1 kilo")
        #expect(LiveSessionText.kilosSpoken(1.5) == "1,5 kilo")
        #expect(LiveSessionText.kilosSpoken(2) == "2 kilos")
        #expect(LiveSessionText.kilosSpoken(1.996) == "2 kilos")
        #expect(LiveSessionText.kilosSpoken(1.994) == "1,99 kilo")
    }

    @Test func kilosGroupThousandsWithANonBreakingSpace() {
        #expect(LiveSessionText.kilosSpoken(12_450) == "12\u{202F}450 kilos")
    }

    @Test func repetitionsAgreeInNumber() {
        #expect(LiveSessionText.repetitions(0) == "0 répétition")
        #expect(LiveSessionText.repetitions(1) == "1 répétition")
        #expect(LiveSessionText.repetitions(8) == "8 répétitions")
    }
}
