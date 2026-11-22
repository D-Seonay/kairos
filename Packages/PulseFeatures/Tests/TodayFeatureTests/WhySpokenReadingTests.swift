import PulseDomain
import Testing
@testable import TodayFeature

/// La lecture de la nuit telle que VoiceOver la dit : les unités en toutes lettres.
struct WhySpokenReadingTests {
    @Test func spokenReadingSaysItsUnitsInFull() throws {
        let content = try WhyFixture.content(WhyFixture.recovery())
        #expect(content.spokenReading == "Ta variabilité cardiaque est 18 % sous ta moyenne de 14 jours, ta fréquence au repos a pris "
            + "5 battements par minute et tu n'as dormi que 5 heures 10 minutes. "
            + "Ton système nerveux est sous tension : la séance est allégée.")
    }

    @Test func spokenReadingHandlesSingularsAndFallsBackToTheWrittenSentences() throws {
        let night = WhyFixture.recovery(score: 95) {
            $0.restingHeartRate = 48
            $0.restingHeartRateBaseline = 50
            $0.asleepMinutes = 480
        }
        let content = try WhyFixture.content(night)
        #expect(content.spokenReading.contains("ta fréquence au repos a baissé de 2 battements par minute"))
        #expect(content.spokenReading.contains("tu as dormi 8 heures."))
        let estimated = try WhyFixture.content(WhyFixture.estimated(score: 58))
        #expect(estimated.spokenReading == estimated.reading)
    }

    @Test func spokenReadingHasNoAbbreviation() throws {
        let nights = [
            WhyFixture.recovery(), WhyFixture.recovery(score: 95), WhyFixture.recovery(score: 75),
            WhyFixture.recovery { $0.asleepMinutes = 480 }, WhyFixture.estimated(score: 58)
        ]
        for night in nights {
            let spoken = try WhyFixture.content(night).spokenReading
            for forbidden in ["bpm", " h ", "h 0", "min "] {
                #expect(!spoken.contains(forbidden), "« \(spoken) » contient « \(forbidden) »")
            }
        }
    }
}
