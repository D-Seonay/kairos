import Foundation
@testable import PlanningFeature
import PulseDomain
import PulseServices
import Testing

/// Les textes lus par VoiceOver à l'onglet Planning : les jours, les allures et les détails sans abréviation.
@MainActor
struct PlanningSpokenTests {
    @Test func paceIsSpokenInMinutesPerKilometer() {
        #expect(PlanningText.paceSpoken(minutes: 45, meters: 8_200) == "5 minutes 29 par kilomètre")
        #expect(PlanningText.paceSpoken(minutes: 40, meters: 10_000) == "4 minutes par kilomètre")
        #expect(PlanningText.paceSpoken(minutes: nil, meters: 8_200) == nil)
        #expect(PlanningText.paceSpoken(minutes: 45, meters: 0) == nil)
    }

    @Test func spokenPaceMatchesTheVisibleOne() {
        #expect(PlanningText.pace(minutes: 45, meters: 8_200) == "5:29 /km")
    }

    @Test func dayLabelSaysTodayAndTheFullWeekday() {
        #expect(PlanningText.dayAccessibility(weekday: "lundi", number: "16", isToday: true, title: "Pectoraux", detail: "Prévue")
            == "lundi 16, aujourd'hui, Pectoraux, Prévue")
        #expect(PlanningText.dayAccessibility(weekday: "mardi", number: "17", isToday: false, title: "Repos", detail: "Récupération")
            == "mardi 17, Repos, Récupération")
    }

    @Test func todayHeadingReadsWithoutTheMiddleDot() {
        #expect(PlanningText.todayHeading(weekday: "mercredi", number: "18") == "Aujourd'hui · mercredi 18")
        #expect(PlanningText.todayHeading(weekday: "mercredi", number: "18", spoken: true) == "Aujourd'hui, mercredi 18")
    }

    @Test func distanceAndTonnageAreSpokenInFullWords() {
        #expect(PlanningText.distanceSpoken(meters: 8_200) == "8,2 kilomètres")
        #expect(PlanningText.distanceSpoken(meters: 1_000) == "1 kilomètre")
        #expect(PlanningText.heartRateSpoken(150) == "150 battements par minute")
    }

    @Test func detailsAreSpokenWithoutAbbreviationsOrMiddleDots() async throws {
        let fixture = PlanningFixture()
        try await fixture.activate()
        try await fixture.log(day: 16, tonnage: 11_240)
        try await fixture.log(day: 21, hour: 9, kind: .run, meters: 8_200, source: .appleHealth)
        let model = PlanningModel(environment: fixture.environment)
        await model.load()

        #expect(model.spokenDetail(of: model.days[0]).replacingOccurrences(of: "\u{202F}", with: " ") == "Validée, 11 240 kilos")
        #expect(model.spokenDetail(of: model.days[1]) == "Manquée")
        #expect(model.spokenDetail(of: model.days[2]) == "Prévue")
        #expect(model.spokenDetail(of: model.days[3]) == "Sortie facile, 45 minutes")
        #expect(model.spokenDetail(of: model.days[5]) == "En plus, 8,2 kilomètres")
    }

    @Test func dayLabelsCarryTodayAndTheSpokenDetail() async throws {
        let fixture = PlanningFixture()
        try await fixture.activate()
        let model = PlanningModel(environment: fixture.environment)
        await model.load()

        #expect(model.accessibilityText(of: model.days[2]) == "mercredi 18, aujourd'hui, Legs, Prévue")
        #expect(model.accessibilityText(of: model.days[3]) == "jeudi 19, Endurance, Sortie facile, 45 minutes")
    }

    @Test func activityMetricsAreSpoken() async throws {
        let fixture = PlanningFixture()
        try await fixture.activate()
        let run = try await fixture.log(day: 17, hour: 7, kind: .run, meters: 8_200, source: .appleHealth)
        let model = ActivityDetailModel(environment: fixture.environment, sessionID: run.id)
        await model.load()

        let spoken = Dictionary(uniqueKeysWithValues: model.metrics.map { ($0.label, $0.spokenValue) })
        #expect(spoken["Distance"] == "8,2 kilomètres")
        #expect(spoken["Durée"] == "45 minutes")
        #expect(spoken["Allure"] == "5 minutes 29 par kilomètre")
        #expect(spoken["FC moyenne"] == "150 battements par minute")
        #expect(model.metrics.first { $0.label == "Allure" }?.value == "5:29 /km")
    }
}
