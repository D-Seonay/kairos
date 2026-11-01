import Foundation
@testable import OnboardingFeature
import PulseContent
import PulseDomain
import PulseServices
import Testing

@MainActor
struct OnboardingViewSupportTests {
    // MARK: - Poids

    @Test func kilogramsAreShownAsIs() {
        #expect(WeightUnits.displayValue(kilograms: 61.5, unit: .kg) == 61.5)
        #expect(WeightUnits.kilograms(fromDisplay: 61.5, unit: .kg) == 61.5)
    }

    @Test func poundsConvertWithTheInternationalFactor() {
        #expect(abs(WeightUnits.displayValue(kilograms: 45.359237, unit: .lb) - 100) < 1e-9)
        #expect(abs(WeightUnits.kilograms(fromDisplay: 100, unit: .lb) - 45.359237) < 1e-9)
    }

    @Test func poundsRoundTripToTheSameKilograms() {
        let shown = WeightUnits.displayValue(kilograms: 82.3, unit: .lb)
        #expect(abs(WeightUnits.kilograms(fromDisplay: shown, unit: .lb) - 82.3) < 1e-9)
    }

    // MARK: - Douleurs

    @Test func noPainShowsTheNoneChoice() {
        #expect(PainChoice.selection(for: []) == [.none])
        #expect(PainChoice.selection(for: [.knees, .wrists]) == [.area(.knees), .area(.wrists)])
    }

    @Test func tappingAnAreaWhileNoneIsSelectedKeepsOnlyTheArea() {
        let areas = PainChoice.areas(from: [.none, .area(.knees)], previous: [])
        #expect(areas == [.knees])
    }

    @Test func tappingNoneClearsTheCheckedAreas() {
        let areas = PainChoice.areas(from: [.area(.knees), .area(.wrists), .none], previous: [.knees, .wrists])
        #expect(areas.isEmpty)
    }

    @Test func untickingTheLastAreaLeavesNoPain() {
        #expect(PainChoice.areas(from: [], previous: [.knees]).isEmpty)
    }

    @Test func areasKeepTheDomainOrder() {
        let areas = PainChoice.areas(from: [.area(.wrists), .area(.shoulders)], previous: [.wrists])
        #expect(areas == [.shoulders, .wrists])
    }

    // MARK: - Aperçu de la semaine

    private func template(week: [String?], days: [TemplateDay]) -> ProgramTemplate {
        ProgramTemplate(
            id: "t", name: LocalizedText(fr: "T"), summary: LocalizedText(fr: "S"),
            recommendedFor: TemplateRecommendation(focus: .balanced, daysPerWeek: [3]), sessionsPerWeek: 3,
            days: days, suggestedWeek: week)
    }

    @Test func weekPreviewMapsDaysToKinds() {
        let days = [
            TemplateDay(id: "a", name: LocalizedText(fr: "A"), kind: .strength),
            TemplateDay(id: "r", name: LocalizedText(fr: "R"), kind: .run)
        ]
        let preview = ProgramWeekPreview.days(for: template(week: ["a", nil, "r", nil, "a", nil, nil], days: days))
        #expect(preview.map(\.weekday) == Weekday.allCases)
        #expect(preview.map(\.kind) == [.strength, .rest, .run, .rest, .strength, .rest, .rest])
    }

    @Test func weekPreviewPadsAShortWeekAndIgnoresUnknownDays() {
        let preview = ProgramWeekPreview.days(for: template(week: ["ghost"], days: []))
        #expect(preview.count == 7)
        #expect(preview.allSatisfy { $0.kind == .rest })
    }

    @Test func everyBundledTemplatePreviewsItsSessions() {
        for template in ContentLibrary.bundled.programTemplates {
            let preview = ProgramWeekPreview.days(for: template)
            #expect(preview.count == 7)
            #expect(preview.filter { $0.kind != .rest }.count == template.sessionsPerWeek, "\(template.id)")
        }
    }

    @Test func weekPreviewReadsOutEveryDay() {
        let days = ProgramWeekPreview.days(for: template(week: [nil, nil, nil, nil, nil, nil, nil], days: []))
        let label = ProgramWeekPreview.accessibilityLabel(for: days)
        #expect(label.hasPrefix("Lundi : repos, Mardi : repos"))
        #expect(label.hasSuffix("Dimanche : repos"))
    }

    // MARK: - Ligne de base

    @Test func baselineRowsKeepOnlyTheKnownValues() {
        let full = BaselineSummary(
            hrvMeanMs: 54.4, hrvDeviationMs: 9.2, restingHeartRateMean: 49, restingHeartRateDeviation: 3,
            sleepMeanMinutes: 432, nightsAnalyzed: 31)
        let rows = BaselineRow.rows(from: full)
        #expect(rows.map(\.value) == ["54 ms", "49 bpm", "7 h 12"])
        #expect(rows.map(\.deviation) == ["± 9", "± 3", nil])
        let partial = BaselineSummary(
            hrvMeanMs: nil, hrvDeviationMs: nil, restingHeartRateMean: 50, restingHeartRateDeviation: nil,
            sleepMeanMinutes: nil, nightsAnalyzed: 3)
        #expect(BaselineRow.rows(from: partial).map(\.value) == ["50 bpm"])
        #expect(BaselineRow.rows(from: partial).first?.deviation == nil)
        let empty = BaselineSummary(
            hrvMeanMs: nil, hrvDeviationMs: nil, restingHeartRateMean: nil, restingHeartRateDeviation: nil,
            sleepMeanMinutes: nil, nightsAnalyzed: 0)
        #expect(BaselineRow.rows(from: empty).isEmpty)
    }

    // MARK: - VFC en attente de sa ligne de base

    private let partialBaseline = BaselineSummary(
        hrvMeanMs: 50, hrvDeviationMs: 8, restingHeartRateMean: 49, restingHeartRateDeviation: 3,
        sleepMeanMinutes: 432, nightsAnalyzed: 4)

    @Test func hrvWithoutItsBaselineStaysAsAPendingRow() {
        let measured = recovery(estimated: false, calibration: .calibrating(nights: 3), missing: [.hrv])
        let rows = BaselineRow.rows(from: partialBaseline, recovery: measured)
        #expect(rows.map(\.title).first == "Variabilité cardiaque")
        #expect(rows.first?.value == "ligne de base en cours, 3 sur 5 nuits")
        #expect(rows.first?.isPending == true)
        #expect(rows.first?.deviation == nil)
        #expect(rows.dropFirst().map(\.value) == ["49 bpm", "7 h 12"])
    }

    @Test func pendingHrvRowShowsEvenWithoutAnyOtherBaselineValue() {
        let empty = BaselineSummary(
            hrvMeanMs: nil, hrvDeviationMs: nil, restingHeartRateMean: nil, restingHeartRateDeviation: nil,
            sleepMeanMinutes: nil, nightsAnalyzed: 0)
        let measured = recovery(estimated: false, calibration: .calibrating(nights: 0), missing: [.hrv])
        #expect(BaselineRow.rows(from: empty, recovery: measured).map(\.value) == ["ligne de base en cours, 0 sur 5 nuits"])
    }

    @Test func hrvRowIsMeasuredOnceTheBaselineExists() {
        let calibrating = recovery(estimated: false, calibration: .calibrating(nights: 9))
        #expect(BaselineRow.rows(from: partialBaseline, recovery: calibrating).first?.value == "50 ms")
        // La VFC du jour manque mais la ligne de base existe : la ligne reste une mesure.
        let todayMissing = recovery(estimated: false, calibration: .calibrating(nights: 9), missing: [.hrv])
        #expect(BaselineRow.rows(from: partialBaseline, recovery: todayMissing).first?.isPending == false)
        let ready = recovery(estimated: false, calibration: .ready, missing: [.hrv])
        #expect(BaselineRow.rows(from: partialBaseline, recovery: ready).first?.isPending == false)
    }

    @Test func anEstimatedScoreHasNoPendingHrvRow() {
        let estimated = recovery(estimated: true, calibration: .calibrating(nights: 0), missing: Factor.allCases)
        #expect(BaselineRow.pendingHRVNights(estimated) == nil)
        #expect(BaselineRow.pendingHRVNights(nil) == nil)
    }

    // MARK: - Textes

    @Test func proposalNamesBothHalvesOfTheWeek() {
        #expect(OnboardingCopy.proposal(strength: 3, runs: 2) == "Proposition : 3 séances de musculation et 2 sorties par semaine.")
        #expect(OnboardingCopy.proposal(strength: 1, runs: 1) == "Proposition : 1 séance de musculation et 1 sortie par semaine.")
    }

    @Test func proposalOmitsAnEmptyHalf() {
        #expect(OnboardingCopy.proposal(strength: 4, runs: 0) == "Proposition : 4 séances de musculation par semaine.")
        #expect(OnboardingCopy.proposal(strength: 0, runs: 2) == "Proposition : 2 sorties par semaine.")
    }

    private func recovery(estimated: Bool, calibration: CalibrationState, missing: [Factor] = []) -> DailyRecovery {
        DailyRecovery(
            day: OnboardingClock.now, score: 70, category: .normal, isEstimated: estimated, missingFactors: missing,
            calibration: calibration, createdAt: OnboardingClock.now, updatedAt: OnboardingClock.now)
    }

    @Test func markerSaysEstimatedOrCalibrating() {
        #expect(OnboardingCopy.marker(for: recovery(estimated: true, calibration: .calibrating(nights: 0))) == "Estimé")
        #expect(OnboardingCopy.marker(for: recovery(estimated: false, calibration: .calibrating(nights: 9))) == "En calibration (9 nuits)")
        #expect(OnboardingCopy.marker(for: recovery(estimated: false, calibration: .ready)) == nil)
    }

    // MARK: - Modèle

    @Test func templatesPutTheRecommendedOneFirst() async {
        let model = OnboardingFixture().makeModel()
        await model.start()
        model.profile.focus = 0.9
        await model.continueFromGoals()
        let all = ContentLibrary.bundled.programTemplates
        let templates = model.templates
        #expect(templates.count == all.count)
        #expect(templates.first?.id == model.recommendedTemplateID)
        #expect(templates.first?.recommendedFor.focus == .endurance)
        #expect(Set(templates.map(\.id)) == Set(all.map(\.id)))
        #expect(templates.dropFirst().map(\.id) == all.map(\.id).filter { $0 != model.recommendedTemplateID })
    }

    @Test func templatesFollowTheLibraryBeforeAnyRecommendation() {
        let model = OnboardingFixture().makeModel()
        #expect(model.templates.map(\.id) == ContentLibrary.bundled.programTemplates.map(\.id))
    }

    @Test func suggestedBirthDateIsThirtyYearsAgoAtDayStart() {
        let model = OnboardingFixture().makeModel()
        #expect(model.suggestedBirthDate == OnboardingClock.date("1996-11-02T00:00"))
        #expect(model.latestBirthDate == OnboardingClock.now)
    }
}
