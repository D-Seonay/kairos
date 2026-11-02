import CheckInFeature
import Foundation
import OnboardingFeature
import PulseDomain
import PulseServices
import Testing

@MainActor
struct OnboardingModelTests {
    private let now = OnboardingClock.now

    private func scored(_ phase: CalibrationPhase) -> (DailyRecovery, BaselineSummary)? {
        if case .scored(let recovery, let baseline) = phase { (recovery, baseline) } else { nil }
    }

    @Test func startsAtWelcomeWithoutSavedStep() async {
        let model = OnboardingFixture().makeModel()
        await model.start()
        #expect(model.step == .welcome)
        #expect(!model.isFinished)
        #expect(model.profile.createdAt == now)
    }

    @Test func resumesAtSavedStepWithDraftProfile() async throws {
        let fixture = OnboardingFixture()
        try await fixture.profiles.save(UserProfile(firstName: "Léa", createdAt: now))
        fixture.stepStore.save(.goals)
        let model = fixture.makeModel()
        await model.start()
        #expect(model.step == .goals)
        #expect(model.profile.firstName == "Léa")
    }

    @Test func beginSavesTheStepAndTheDraft() async throws {
        let fixture = OnboardingFixture()
        let model = fixture.makeModel()
        await model.start()
        model.profile.firstName = "Noé"
        await model.begin()
        #expect(model.step == .health)
        #expect(fixture.stepStore.load() == .health)
        #expect(try await fixture.profiles.load()?.firstName == "Noé")
    }

    @Test func allowHealthPrefillsOnlyEmptyFields() async {
        let model = OnboardingFixture().makeModel()
        await model.start()
        model.profile.heightCm = 170
        await model.allowHealth()
        #expect(model.step == .profile)
        #expect(model.profile.heightCm == 170)
        #expect(model.profile.weightKg == 74.5)
        #expect(model.profile.sex == .male)
        #expect(model.profile.birthDate != nil)
    }

    @Test func allowHealthKeepsAnExplicitSex() async {
        let model = OnboardingFixture().makeModel()
        await model.start()
        model.profile.sex = .female
        await model.allowHealth()
        #expect(model.profile.sex == .female)
    }

    @Test func allowHealthFailureShowsAMessageAndStillAdvances() async {
        let model = OnboardingFixture(health: UnavailableHealthSource()).makeModel()
        await model.start()
        await model.allowHealth()
        #expect(model.step == .profile)
        #expect(model.errorMessage != nil)
        #expect(model.profile.weightKg == nil)
    }

    @Test func skipHealthGoesToProfileAndCalibratesByCheckIn() async {
        let model = OnboardingFixture().makeModel()
        await model.start()
        await model.skipHealth()
        #expect(model.step == .profile)
        #expect(model.profile.weightKg == nil)
        await model.continueFromProfile()
        await model.continueFromGoals()
        await model.adoptProgram()
        #expect(model.step == .calibration)
        guard case .needsCheckIn(let missing, let baseline) = model.calibration else {
            Issue.record("expected a check-in, got \(model.calibration)")
            return
        }
        #expect(missing == Factor.allCases)
        #expect(baseline.nightsAnalyzed == 0)
    }

    @Test func profileLevelSetsIncrements() async {
        let model = OnboardingFixture().makeModel()
        await model.start()
        model.profile.strengthLevel = .advanced
        await model.continueFromProfile()
        #expect(model.step == .goals)
        #expect(model.profile.upperIncrementKg == 1.25)
        #expect(model.profile.lowerIncrementKg == 2.5)
    }

    @Test func goalsRecommendATemplate() async {
        let model = OnboardingFixture().makeModel()
        await model.start()
        model.profile.focus = 0.2
        model.profile.trainingDaysPerWeek = 3
        await model.continueFromGoals()
        #expect(model.step == .program)
        #expect(model.recommendedTemplateID == "ppl-3")
        #expect(model.selectedTemplateID == "ppl-3")
    }

    @Test func adoptingActivatesTheProgram() async throws {
        let fixture = OnboardingFixture()
        let model = fixture.makeModel()
        await OnboardingFixture.adoptRecommended(model)
        let programs = try await fixture.programs.programs(includeArchived: false)
        #expect(programs.count == 1)
        #expect(model.profile.activeProgramID == programs.first?.id)
        #expect(programs.first?.templateID == model.selectedTemplateID)
        #expect(try await fixture.profiles.load()?.activeProgramID == programs.first?.id)
        #expect(fixture.stepStore.load() == .calibration)
    }

    @Test func readoptingReplacesThePreviousProgram() async throws {
        let fixture = OnboardingFixture()
        let model = fixture.makeModel()
        await OnboardingFixture.adoptRecommended(model)
        let first = model.profile.activeProgramID
        model.goBack()
        #expect(model.step == .program)
        let other = try #require(fixture.environment.library.programTemplates.first { $0.id != model.selectedTemplateID })
        model.selectedTemplateID = other.id
        await model.adoptProgram()
        let programs = try await fixture.programs.programs(includeArchived: true)
        #expect(programs.count == 1)
        #expect(programs.first?.templateID == other.id)
        #expect(model.profile.activeProgramID == programs.first?.id)
        #expect(model.profile.activeProgramID != first)
    }

    @Test func customProgramLeavesNoActiveProgram() async throws {
        let fixture = OnboardingFixture()
        let model = fixture.makeModel()
        await OnboardingFixture.adoptRecommended(model)
        model.goBack()
        model.choseCustomProgram = true
        await model.adoptProgram()
        #expect(model.profile.activeProgramID == nil)
        #expect(try await fixture.programs.programs(includeArchived: true).isEmpty)
        #expect(model.step == .calibration)
    }

    @Test func goodNightCalibrationScoresOptimal() async throws {
        let model = OnboardingFixture().makeModel()
        await OnboardingFixture.adoptRecommended(model)
        let (recovery, baseline) = try #require(scored(model.calibration))
        #expect(recovery.category == .optimal)
        #expect(baseline.nightsAnalyzed == 60)
    }

    @Test func threeNightsCalibrationNeedsCheckInThenScores() async throws {
        let model = OnboardingFixture(scenario: .threeNights).makeModel()
        await OnboardingFixture.adoptRecommended(model)
        guard case .needsCheckIn = model.calibration else {
            Issue.record("expected a check-in, got \(model.calibration)")
            return
        }
        model.checkIn.selection = [.sleep: 3, .pain: 3, .motivation: 3]
        await model.submitCheckIn()
        let (recovery, baseline) = try #require(scored(model.calibration))
        #expect(recovery.isEstimated)
        #expect(recovery.score == 75)
        #expect(baseline.nightsAnalyzed == 3)
    }

    @Test func submitCheckInWaitsForEveryAnswer() async {
        let model = OnboardingFixture(scenario: .noData).makeModel()
        await OnboardingFixture.adoptRecommended(model)
        model.checkIn.selection = [.sleep: 3]
        await model.submitCheckIn()
        guard case .needsCheckIn = model.calibration else {
            Issue.record("expected a check-in, got \(model.calibration)")
            return
        }
    }

    @Test func weekProposalSplitsDays() async {
        let model = OnboardingFixture().makeModel()
        await model.start()
        model.profile.trainingDaysPerWeek = 5
        model.profile.focus = 0.4
        #expect(model.weekProposal.strength == 3)
        #expect(model.weekProposal.runs == 2)
    }

    @Test func goBackStepsBackAndRemembersIt() async {
        let fixture = OnboardingFixture()
        let model = fixture.makeModel()
        await model.start()
        await model.begin()
        model.goBack()
        #expect(model.step == .welcome)
        #expect(fixture.stepStore.load() == .welcome)
        model.goBack()
        #expect(model.step == .welcome)
    }
}
