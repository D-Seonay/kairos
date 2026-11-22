import Foundation
@testable import LiveSessionFeature
import PulseDomain
import PulseServices
import Testing

/// Ce que VoiceOver dit du récap : l'annonce des records à l'ouverture et les tuiles du bilan. Des fonctions pures.
@Suite struct RecapSpokenTests {
    private let record = BeatenRecord(
        exerciseName: "Développé couché", kind: .maxWeight, text: "Développé couché : 72,5 kg, nouveau record de charge",
        spokenText: "Développé couché : 72,5 kilos, nouveau record de charge")

    @Test func noRecordMeansNoAnnouncement() {
        #expect(RecapView.recordsAnnouncement([]) == nil)
    }

    @Test func oneRecordIsAnnouncedWithItsSpokenText() {
        #expect(RecapView.recordsAnnouncement([record])
            == "Nouveau record ! Développé couché : 72,5 kilos, nouveau record de charge")
    }

    @Test func severalRecordsAreCountedAndTheFirstIsSpoken() {
        let other = BeatenRecord(exerciseName: "Tractions", kind: .repsAtWeight, text: "Tractions", spokenText: "Tractions")
        #expect(RecapView.recordsAnnouncement([record, other, other])
            == "3 nouveaux records ! Développé couché : 72,5 kilos, nouveau record de charge")
    }

    @Test func durationIsSaidInMinutes() {
        let stat = RecapView.statSpoken(.duration(minutes: 55))
        #expect(stat.name == "Durée" && stat.value == "55 minutes")
        #expect(RecapView.statSpoken(.duration(minutes: 65)).value == "1 heure 5 minutes")
    }

    @Test func tonnageIsSaidInKilosWithThousandsSeparator() {
        let stat = RecapView.statSpoken(.tonnage(kg: 12_450.5))
        #expect(stat.name == "Tonnage")
        #expect(stat.value.hasSuffix(" kilos") && !stat.value.contains("kg"))
        #expect(stat.value.filter(\.isNumber) == "124505")
        #expect(RecapView.statSpoken(.tonnage(kg: 1_240)).value.contains("240 kilos"))
    }

    @Test func setsAreCountedWithWords() {
        #expect(RecapView.statSpoken(.sets(14)).value == "14 séries")
        #expect(RecapView.statSpoken(.sets(1)).value == "1 série")
        #expect(RecapView.statSpoken(.sets(14)).name == "Séries")
    }

    @Test func recordsTileKeepsItsTitleAndCount() {
        #expect(RecapView.statSpoken(.records(2)) == ("Records", "2"))
        #expect(RecapView.statSpoken(.records(0)) == ("Record", "0"))
    }
}
