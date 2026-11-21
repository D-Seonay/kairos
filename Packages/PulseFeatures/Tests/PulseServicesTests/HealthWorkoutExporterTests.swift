import Foundation
import PulseDomain
import PulseServices
import Testing

/// L'écriture des séances dans Apple Santé (spec M4 §19.5).
struct HealthWorkoutExporterTests {
    private let workouts = InMemoryWorkoutRepository()
    private let profiles = InMemoryProfileRepository()
    private let measurements = InMemoryBodyMeasurementRepository()
    private let start = TestClock.date("2026-11-02T08:00")
    private let end = TestClock.date("2026-11-02T09:00")

    private func session(source: SessionSource = .pulse, status: SessionStatus = .completed) -> WorkoutSession {
        WorkoutSession(startedAt: start, endedAt: end, kind: .strength, source: source, status: status, title: "Push",
                       durationMinutes: 60, createdAt: start, updatedAt: start)
    }

    private func exporter(_ writer: StubWorkoutHealthWriter) -> HealthWorkoutExporter {
        HealthWorkoutExporter(writer: writer, workouts: workouts, profiles: profiles, measurements: measurements,
                              calendar: TestClock.calendar)
    }

    @Test func aCompletedPulseSessionIsWrittenWithItsEnergyAndKeepsItsHealthID() async throws {
        try await profiles.save(UserProfile(weightKg: 80, createdAt: .t0, updatedAt: .t0))
        let writer = StubWorkoutHealthWriter()
        let saved = session()
        try await workouts.save(saved)
        let written = await exporter(writer).export(saved)
        let entry = try #require(await writer.saved.values.first)
        // 5 MET × 80 kg × 1 h.
        #expect(entry == StrengthWorkoutEntry(sessionID: saved.id, start: start, end: end, energyKcal: 400))
        let id = try #require(written.healthKitUUID)
        #expect(await writer.saved.keys.map(\.uuidString) == [id])
        #expect(try await workouts.session(id: saved.id)?.healthKitUUID == id)
    }

    @Test func exportUsesTheHealthTrendForEnergy() async throws {
        try await profiles.save(UserProfile(createdAt: .t0, updatedAt: .t0))
        for daysAgo in 0..<3 {
            let date = TestClock.calendar.date(byAdding: .day, value: -daysAgo, to: start) ?? start
            try await measurements.save(BodyMeasurement(date: date, weightKg: 80, source: .appleHealth, createdAt: date, updatedAt: date))
        }
        let writer = StubWorkoutHealthWriter()
        let saved = session()
        try await workouts.save(saved)
        _ = await exporter(writer).export(saved)
        // 5 MET × 80 kg (la tendance Apple Santé, le profil n'a pas de poids) × 1 h.
        #expect(await writer.saved.values.first?.energyKcal == 400)
    }

    @Test func withoutWeightTheEnergyIsOmitted() async throws {
        let writer = StubWorkoutHealthWriter()
        let saved = session()
        try await workouts.save(saved)
        _ = await exporter(writer).export(saved)
        #expect(await writer.saved.values.first?.energyKcal == nil)
    }

    @Test func importedAbandonedOrAlreadyWrittenSessionsAreNeverWritten() async throws {
        let writer = StubWorkoutHealthWriter()
        var written = session()
        written.healthKitUUID = UUID().uuidString
        for candidate in [session(source: .hevy), session(status: .abandoned), written] {
            try await workouts.save(candidate)
            #expect(await exporter(writer).export(candidate) == candidate)
        }
        #expect(await writer.saved.isEmpty)
    }

    @Test func nothingIsWrittenWithoutAccessOrWhenTheWriteFails() async throws {
        for writer in [StubWorkoutHealthWriter(access: .denied), StubWorkoutHealthWriter(access: .notDetermined),
                       StubWorkoutHealthWriter(failsOnSave: true)] {
            let saved = session()
            try await workouts.save(saved)
            #expect(await exporter(writer).export(saved).healthKitUUID == nil)
            #expect(await writer.saved.isEmpty)
            #expect(await writer.requestCount == 0)
        }
    }

    @Test func removingASessionDeletesItsWorkout() async throws {
        let writer = StubWorkoutHealthWriter()
        let saved = session()
        try await workouts.save(saved)
        let written = await exporter(writer).export(saved)
        await exporter(writer).removeWorkout(of: written)
        #expect(await writer.saved.isEmpty)
        #expect(await writer.deleted.map(\.uuidString) == [written.healthKitUUID])
        await exporter(writer).removeWorkout(of: session())
        #expect(await writer.deleted.count == 1)
    }

    @Test func finishingALiveSessionWritesItToAppleHealth() async throws {
        let fixture = ActiveSessionFixture()
        let writer = StubWorkoutHealthWriter()
        let health = HealthWorkoutExporter(writer: writer, workouts: fixture.workouts, profiles: fixture.profiles,
                                       measurements: InMemoryBodyMeasurementRepository(), calendar: TestClock.calendar)
        let clock = fixture.clock
        let records = RecordsService(workouts: fixture.workouts, records: InMemoryPersonalRecordRepository(),
                                     userExercises: fixture.userExercises, library: .bundled, now: { clock.now })
        let service = ActiveSessionService(
            store: fixture.store, workouts: fixture.workouts, profiles: fixture.profiles, settings: fixture.settings,
            userExercises: fixture.userExercises, records: records, library: .bundled, restNotifier: fixture.notifier,
            activity: fixture.activity, calendar: TestClock.calendar, now: { clock.now }, health: health)
        let live = try await service.start(ActiveSessionFixture.pushLaunch)
        let exercise = live.exercises[0]
        _ = try await service.apply(.validate(exercise: exercise.id, set: exercise.sets[0].id))
        #expect(await service.healthAccess() == .authorized)
        let saved = try await service.finish(overallRPE: 8, note: nil, endedAt: end)
        #expect(saved.healthKitUUID != nil)
        #expect(await writer.saved.values.first?.sessionID == live.id)
        #expect(try await fixture.workouts.session(id: live.id)?.healthKitUUID == saved.healthKitUUID)
    }

    @Test func withoutAppleHealthTheAccessIsUnavailable() async throws {
        let (service, _) = try await ActiveSessionFixture().startPush()
        #expect(await service.healthAccess() == .unavailable)
        #expect(await service.requestHealthAccess() == .unavailable)
    }
}
