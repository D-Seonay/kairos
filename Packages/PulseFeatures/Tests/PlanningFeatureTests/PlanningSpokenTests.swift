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

    @Test func distanceSingularFollowsTheRoundedValue() {
        #expect(PlanningText.distanceSpoken(meters: 1_960) == "2 kilomètres")
        #expect(PlanningText.distanceSpoken(meters: 1_940) == "1,9 kilomètre")
        #expect(PlanningText.distanceSpoken(meters: 12_500) == "12,5 kilomètres")
    }

    @Test func streakRowAgreesInNumberAndReadsWithoutTheMiddleDot() {
        #expect(PlanningText.streakRow(weeks: 3, count: 2, target: 5) == "Série de 3 semaines · 2 sur 5 cette semaine")
        #expect(PlanningText.streakRow(weeks: 1, count: 1, target: 4) == "Série de 1 semaine · 1 sur 4 cette semaine")
        #expect(PlanningText.streakRow(weeks: 0, count: 0, target: 4) == "Série de 0 semaine · 0 sur 4 cette semaine")
        #expect(PlanningText.streakRow(weeks: 3, count: 2, target: 5, spoken: true) == "Série de 3 semaines, 2 sur 5 cette semaine")
        #expect(PlanningText.monthEntrySpoken(weeks: 1, count: 2, target: 5)
            == "Mois et série, Série de 1 semaine, 2 sur 5 cette semaine")
    }

    @Test func pillarAndStreakCounterAgreeInNumber() {
        #expect(PlanningText.pillarText(successes: 1, total: 8) == "1 semaine réussie sur les 8 dernières")
        #expect(PlanningText.pillarText(successes: 0, total: 8) == "0 semaine réussie sur les 8 dernières")
        #expect(PlanningText.pillarText(successes: 5, total: 8) == "5 semaines réussies sur les 8 dernières")
        #expect(PlanningText.weeksInARow(1) == "semaine d'affilée")
        #expect(PlanningText.weeksInARow(6) == "semaines d'affilée")
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
