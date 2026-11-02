import PulseRecoveryEngine
import Testing
@testable import TodayFeature

struct LoadCardContentTests {
    private func result(ratio: Double) -> ACWRResult {
        ACWRResult(acute: ratio * 100, chronic: 100, ratio: ratio, zone: ACWRZone(ratio: ratio))
    }

    @Test func hiddenWithoutResult() {
        #expect(LoadCardContent.make(nil) == .hidden)
        #expect(LoadCardContent.hiddenText
            == "La jauge de charge apparaîtra après 28 jours d'entraînement : elle compare ta dernière semaine à ton mois.")
    }

    @Test func optimalRatio() {
        let expected = LoadCardContent.ratio(
            value: 1.12, valueText: "1,12", zoneTitle: "Zone optimale", advice: "Tu peux maintenir ce rythme cette semaine.")
        #expect(LoadCardContent.make(result(ratio: 1.12)) == expected)
    }

    private struct ZoneCase {
        var ratio: Double
        var valueText: String
        var title: String
        var advice: String
    }

    @Test func zones() {
        let cases = [
            ZoneCase(ratio: 0.6, valueText: "0,6", title: "Sous-entraînement", advice: "Tu peux augmenter progressivement ta charge."),
            ZoneCase(ratio: 1.4, valueText: "1,4", title: "Charge élevée", advice: "Ta charge monte vite : surveille ta récupération."),
            ZoneCase(ratio: 1.7, valueText: "1,7", title: "Risque de blessure", advice: "Ta charge a bondi : allège les prochains jours.")
        ]
        for item in cases {
            #expect(LoadCardContent.make(result(ratio: item.ratio))
                == .ratio(value: item.ratio, valueText: item.valueText, zoneTitle: item.title, advice: item.advice))
        }
    }
}
