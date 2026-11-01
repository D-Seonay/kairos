import Foundation
import OnboardingFeature
import PulseDomain
import PulseServices
import Testing

@MainActor
struct OnboardingResumeTests {
    /// Quitte l'application à `.program` ou `.calibration` : seul ce que l'onboarding a enregistré survit au relancement.
    private func relaunch(_ fixture: OnboardingFixture) async -> OnboardingModel {
        let model = fixture.makeModel()
        await model.start()
        return model
    }

    @Test func resumeAtProgramRestoresRecommendationAndSelection() async throws {
        let fixture = OnboardingFixture()
        try await fixture.profiles.save(UserProfile(focus: 0.2, trainingDaysPerWeek: 3, createdAt: OnboardingClock.now))
        fixture.stepStore.save(.program)
        let model = await relaunch(fixture)
        #expect(model.step == .program)
        #expect(model.recommendedTemplateID == "ppl-3")
        #expect(model.selectedTemplateID == "ppl-3")
        #expect(!model.choseCustomProgram)
        await model.adoptProgram()
        let programs = try await fixture.programs.programs(includeArchived: false)
        #expect(programs.count == 1)
        #expect(programs.first?.templateID == "ppl-3")
        #expect(model.profile.activeProgramID == programs.first?.id)
    }

    @Test func resumeAtProgramKeepsTheTemplateAlreadyAdopted() async throws {
        let fixture = OnboardingFixture()
        let model = fixture.makeModel()
        await OnboardingFixture.adoptRecommended(model)
        let other = try #require(fixture.environment.library.programTemplates.first { $0.id != model.selectedTemplateID })
        model.goBack()
        model.selectedTemplateID = other.id
        await model.adoptProgram()
        model.goBack()
        let resumed = await relaunch(fixture)
        #expect(resumed.step == .program)
        #expect(resumed.selectedTemplateID == other.id)
        #expect(resumed.recommendedTemplateID != nil)
        await resumed.adoptProgram()
        let programs = try await fixture.programs.programs(includeArchived: true)
        #expect(programs.count == 1)
        #expect(programs.first?.templateID == other.id)
    }

    @Test func resumeAtCalibrationRestoresTheAdoptedTemplate() async throws {
        let fixture = OnboardingFixture()
        let model = fixture.makeModel()
        await OnboardingFixture.adoptRecommended(model)
        let adopted = try #require(model.selectedTemplateID)
        let resumed = await relaunch(fixture)
        #expect(resumed.step == .calibration)
        #expect(resumed.selectedTemplateID == adopted)
        #expect(!resumed.choseCustomProgram)
    }

    @Test func resumeAtCalibrationAfterCustomProgramStaysCustom() async {
        let fixture = OnboardingFixture()
        let model = fixture.makeModel()
        await model.start()
        await model.continueFromGoals()
        model.choseCustomProgram = true
        await model.adoptProgram()
        let resumed = await relaunch(fixture)
        #expect(resumed.step == .calibration)
        #expect(resumed.choseCustomProgram)
        #expect(resumed.profile.activeProgramID == nil)
    }

    @Test func resumeBeforeProgramLeavesTheSelectionEmpty() async throws {
        let fixture = OnboardingFixture()
        try await fixture.profiles.save(UserProfile(createdAt: OnboardingClock.now))
        fixture.stepStore.save(.goals)
        let model = await relaunch(fixture)
        #expect(model.recommendedTemplateID == nil)
        #expect(model.selectedTemplateID == nil)
    }
}

@MainActor
struct OnboardingSaveFailureTests {
    private func failingFixture() async -> (OnboardingFixture, FlakyProfileRepository) {
        let profiles = FlakyProfileRepository()
        return (OnboardingFixture(profiles: profiles), profiles)
    }

    @Test func failedDraftSaveKeepsTheStepAndShowsTheError() async {
        let (fixture, profiles) = await failingFixture()
        let model = fixture.makeModel()
        await model.start()
        await model.begin()
        await model.skipHealth()
        #expect(model.step == .profile)
        await profiles.setFailsOnSave(true)
        await model.continueFromProfile()
        #expect(model.errorMessage != nil)
        #expect(model.step == .profile)
        #expect(fixture.stepStore.load() == .profile)
    }

    @Test func retryAfterAFailedSaveAdvancesAndClearsTheError() async {
        let (fixture, profiles) = await failingFixture()
        let model = fixture.makeModel()
        await model.start()
        await profiles.setFailsOnSave(true)
        await model.begin()
        #expect(model.step == .welcome)
        #expect(model.errorMessage != nil)
        #expect(fixture.stepStore.load() == nil)
        await profiles.setFailsOnSave(false)
        await model.begin()
        #expect(model.step == .health)
        #expect(model.errorMessage == nil)
        #expect(fixture.stepStore.load() == .health)
    }

    @Test func failedSaveWhileAdoptingStaysOnProgramWithoutCalibrating() async throws {
        let (fixture, profiles) = await failingFixture()
        let model = fixture.makeModel()
        await model.start()
        await model.continueFromGoals()
        #expect(model.step == .program)
        await profiles.setFailsOnSave(true)
        await model.adoptProgram()
        #expect(model.errorMessage != nil)
        #expect(model.step == .program)
        #expect(fixture.stepStore.load() == .program)
        #expect(model.calibration == .idle)
        #expect(model.profile.activeProgramID == nil)
        #expect(try await fixture.programs.programs(includeArchived: true).isEmpty)
    }

    @Test func failedSaveWhileReadoptingKeepsThePreviousProgram() async throws {
        let (fixture, profiles) = await failingFixture()
        let model = fixture.makeModel()
        await OnboardingFixture.adoptRecommended(model)
        let first = try #require(model.profile.activeProgramID)
        model.goBack()
        await profiles.setFailsOnSave(true)
        await model.adoptProgram()
        #expect(model.errorMessage != nil)
        #expect(model.step == .program)
        #expect(model.profile.activeProgramID == first)
        let programs = try await fixture.programs.programs(includeArchived: true)
        #expect(programs.map(\.id) == [first])
    }
}
