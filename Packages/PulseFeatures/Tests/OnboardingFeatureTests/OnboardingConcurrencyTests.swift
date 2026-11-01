import CheckInFeature
import Foundation
import OnboardingFeature
import PulseDomain
import PulseServices
import Testing

/// Les courses entre l'écran et le modèle : une seule calibration à la fois, aucun résultat périmé, aucune action avant `start()`.
@MainActor
struct OnboardingConcurrencyTests {
    private func countingFixture(
        scenario: HealthScenario = .goodNight, gateOpen: Bool = true
    ) -> (fixture: OnboardingFixture, source: CountingHealthSource) {
        let calendar = OnboardingClock.calendar
        let inner = ScenarioHealthSource(scenario: scenario, now: OnboardingClock.now, calendar: calendar)
        let source = CountingHealthSource(inner: inner, gateOpen: gateOpen)
        return (OnboardingFixture(health: source), source)
    }

    /// Ce que fait la vue : demander la reprise à chaque occasion pendant que le modèle travaille.
    private func pollResume(_ model: OnboardingModel) -> Task<Void, Never> {
        Task { @MainActor in
            for _ in 0..<200 {
                await model.resumeCalibrationIfNeeded()
                await Task.yield()
            }
        }
    }

    // MARK: - Une seule calibration

    @Test func readoptingAProgramReadsTheNightsOnlyOnce() async throws {
        let (fixture, source) = countingFixture()
        let model = fixture.makeModel()
        await OnboardingFixture.adoptRecommended(model)
        #expect(source.reads.count == 1)
        let other = try #require(fixture.environment.library.programTemplates.first { $0.id != model.selectedTemplateID })
        model.goBack()
        model.selectedTemplateID = other.id
        let poller = pollResume(model)
        await model.adoptProgram()
        await poller.value
        #expect(source.reads.count == 2)
        #expect(model.step == .calibration)
        guard case .scored = model.calibration else {
            Issue.record("expected a score, got \(model.calibration)")
            return
        }
    }

    @Test func aFailedDeleteOfThePreviousProgramKeepsItsErrorMessage() async throws {
        let programs = FlakyProgramRepository()
        let fixture = OnboardingFixture(programs: programs)
        let model = fixture.makeModel()
        await OnboardingFixture.adoptRecommended(model)
        let other = try #require(fixture.environment.library.programTemplates.first { $0.id != model.selectedTemplateID })
        model.goBack()
        model.selectedTemplateID = other.id
        await programs.setFailsOnDelete(true)
        let poller = pollResume(model)
        await model.adoptProgram()
        await poller.value
        #expect(model.errorMessage != nil)
        #expect(model.step == .calibration)
    }

    @Test func resumingAtCalibrationReachesTheScore() async throws {
        let fixture = OnboardingFixture()
        try await fixture.profiles.save(UserProfile(createdAt: OnboardingClock.now))
        fixture.stepStore.save(.calibration)
        let model = fixture.makeModel()
        await model.start()
        #expect(model.step == .calibration)
        #expect(model.calibration == .idle)
        await model.resumeCalibrationIfNeeded()
        guard case .scored(let recovery, _) = model.calibration else {
            Issue.record("expected a score, got \(model.calibration)")
            return
        }
        #expect(recovery.category == .optimal)
    }

    @Test func resumingTwiceConcurrentlyReadsOnce() async throws {
        let (fixture, source) = countingFixture()
        try await fixture.profiles.save(UserProfile(createdAt: OnboardingClock.now))
        fixture.stepStore.save(.calibration)
        let model = fixture.makeModel()
        await model.start()
        async let first: Void = model.resumeCalibrationIfNeeded()
        async let second: Void = model.resumeCalibrationIfNeeded()
        _ = await (first, second)
        #expect(source.reads.count == 1)
    }

    @Test func resumingOutsideCalibrationDoesNothing() async {
        let (fixture, source) = countingFixture()
        let model = fixture.makeModel()
        await model.start()
        await model.resumeCalibrationIfNeeded()
        #expect(model.calibration == .idle)
        #expect(source.reads.count < 1)
    }

    @Test func resumingAfterTheScoreDoesNotReadAgain() async {
        let (fixture, source) = countingFixture()
        let model = fixture.makeModel()
        await OnboardingFixture.adoptRecommended(model)
        await model.resumeCalibrationIfNeeded()
        #expect(source.reads.count == 1)
    }

    // MARK: - Lecture périmée et retour

    @Test func aStaleReadCannotWriteAfterGoingBack() async throws {
        let (fixture, source) = countingFixture(gateOpen: false)
        try await fixture.profiles.save(UserProfile(createdAt: OnboardingClock.now))
        fixture.stepStore.save(.calibration)
        let model = fixture.makeModel()
        await model.start()
        let run = Task { await model.resumeCalibrationIfNeeded() }
        await Task.yield()
        #expect(model.calibration == .reading(progress: 0))
        model.goBack()
        #expect(model.step == .program)
        #expect(model.calibration == .idle)
        await source.gate.open()
        await run.value
        #expect(model.calibration == .idle)
        #expect(model.errorMessage == nil)
    }

    @Test func backIsOfferedExceptWhileTheNightsAreRead() async throws {
        let (fixture, source) = countingFixture(gateOpen: false)
        let model = fixture.makeModel()
        #expect(!model.canGoBack)
        await model.start()
        await model.begin()
        #expect(!model.canGoBack)
        await model.skipHealth()
        #expect(model.canGoBack)
        try await fixture.profiles.save(UserProfile(createdAt: OnboardingClock.now))
        fixture.stepStore.save(.calibration)
        let resumed = fixture.makeModel()
        await resumed.start()
        #expect(!resumed.canGoBack)
        let run = Task { await resumed.resumeCalibrationIfNeeded() }
        await Task.yield()
        #expect(!resumed.canGoBack)
        await source.gate.open()
        await run.value
        #expect(resumed.canGoBack)
    }

    // MARK: - Avant start()

    @Test func nothingIsSavedBeforeStartHasFinished() async throws {
        let fixture = OnboardingFixture()
        try await fixture.profiles.save(UserProfile(firstName: "Léa", createdAt: OnboardingClock.now))
        fixture.stepStore.save(.goals)
        let model = fixture.makeModel()
        #expect(!model.hasStarted)
        await model.begin()
        #expect(model.step == .welcome)
        #expect(try await fixture.profiles.load()?.firstName == "Léa")
        #expect(fixture.stepStore.load() == .goals)
        await model.start()
        #expect(model.hasStarted)
        #expect(model.step == .goals)
        #expect(model.profile.firstName == "Léa")
    }

    @Test func hasStartedAlsoHoldsWhenTheProfileIsAlreadyDone() async throws {
        let fixture = OnboardingFixture()
        try await fixture.profiles.save(OnboardingFixture.completedProfile())
        let model = fixture.makeModel()
        await model.start()
        #expect(model.hasStarted)
        #expect(model.isFinished)
    }

    // MARK: - Check-in

    @Test func aDoubleTapOnTheCheckInSavesItOnce() async throws {
        let recovery = CountingRecoveryRepository(inner: InMemoryRecoveryRepository(calendar: OnboardingClock.calendar))
        let fixture = OnboardingFixture(scenario: .threeNights, recovery: recovery)
        let model = fixture.makeModel()
        await OnboardingFixture.adoptRecommended(model)
        guard case .needsCheckIn = model.calibration else {
            Issue.record("expected a check-in, got \(model.calibration)")
            return
        }
        model.checkIn.selection = [.sleep: 3, .pain: 3, .motivation: 3]
        async let first: Void = model.submitCheckIn()
        async let second: Void = model.submitCheckIn()
        _ = await (first, second)
        #expect(recovery.checkInSaves.count == 1)
        guard case .scored(let estimated, _) = model.calibration else {
            Issue.record("expected an estimated score, got \(model.calibration)")
            return
        }
        #expect(estimated.isEstimated)
    }

    @Test func aCheckInSavedAfterGoingBackDoesNotRevive() async throws {
        let fixture = OnboardingFixture(scenario: .threeNights)
        let model = fixture.makeModel()
        await OnboardingFixture.adoptRecommended(model)
        model.checkIn.selection = [.sleep: 3, .pain: 3, .motivation: 3]
        let submit = Task { await model.submitCheckIn() }
        await Task.yield()
        model.goBack()
        await submit.value
        #expect(model.step == .program)
        #expect(model.calibration == .idle)
    }
}
