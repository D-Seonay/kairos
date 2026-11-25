import Foundation
import PulseDomain
import Testing

@testable import PulseServices

@Suite("Meilleurs segments des courses Pulse")
struct RunBestEffortIndexTests {
    private let start = TestClock.date("2026-11-24T07:00")

    private func run(_ id: UUID = UUID(), meters: Double?, minutes: Double, source: SessionSource = .pulse,
                     daysAgo: Double = 1) -> WorkoutSession {
        let date = start.addingTimeInterval(-daysAgo * 86_400)
        return WorkoutSession(id: id, startedAt: date, kind: .run, source: source, status: .completed, title: "Course",
                              durationMinutes: minutes, distanceMeters: meters, createdAt: date, updatedAt: date)
    }

    /// Un tracé vers le nord : `legs` donne la distance et la vitesse de chaque morceau.
    private func track(for session: WorkoutSession, legs: [(meters: Double, speed: Double)]) -> RunTrack {
        let points = RunTraceFactory.legs(legs, start: session.startedAt)
        return RunTrack(id: session.id, points: points, splits: [], createdAt: session.startedAt, updatedAt: session.startedAt)
    }

    @Test("le passage calcule une fois les courses Pulse avec tracé, et oublie les séances disparues")
    func refreshFillsTheCacheOnce() async throws {
        let workouts = InMemoryWorkoutRepository()
        let tracks = InMemoryRunTrackRepository()
        let gone = UUID()
        let store = InMemoryRunBestEffortStore([RunBestEfforts(id: gone, efforts: [])])
        // 3 km à 3 m/s, 5 km à 4 m/s, 2 km à 3 m/s : le meilleur 5 km est le morceau rapide, 1 250 s.
        let long = run(meters: 10_000, minutes: 52)
        try await workouts.save(long)
        try await tracks.save(track(for: long, legs: [(3_000, 3), (5_000, 4), (2_000, 3)]))
        // Trop courte, importée d'Apple Santé, ou sans tracé : rien.
        let short = run(meters: 4_000, minutes: 20)
        let health = run(meters: 8_000, minutes: 40, source: .appleHealth)
        let bare = run(meters: 6_000, minutes: 30)
        for session in [short, health, bare] { try await workouts.save(session) }
        try await tracks.save(track(for: short, legs: [(4_000, 3)]))
        try await tracks.save(track(for: health, legs: [(8_000, 3)]))

        let index = RunBestEffortIndex(workouts: workouts, tracks: tracks, store: store)
        #expect(await index.refresh(now: start) == 1)
        let cached = await store.all()
        #expect(Set(cached.keys) == [long.id])
        let fiveK = try #require(cached[long.id]?.seconds(for: 5_000))
        #expect(abs(fiveK - 1_250) < 15)
        #expect(cached[long.id]?.seconds(for: 10_000) != nil)
        #expect(cached[long.id]?.seconds(for: RunDistance.half.rawValue) == nil)

        // Un second passage ne relit rien : le cache n'est pas réécrit.
        let saves = await store.saveCount
        #expect(await index.refresh(now: start) == 0)
        #expect(await store.saveCount == saves)

        // Le tracé de la course sans tracé arrive (iCloud) : il entre au passage suivant.
        try await tracks.save(track(for: bare, legs: [(6_000, 3)]))
        #expect(await index.refresh(now: start) == 1)
        #expect(await store.all()[bare.id]?.seconds(for: 5_000) != nil)
    }

    @Test("une course sans tracé utilisable est retenue comme traitée, pour ne pas être relue à chaque passage")
    func runsWithoutAUsableTrackAreRememberedAsDone() async throws {
        let workouts = InMemoryWorkoutRepository()
        let tracks = InMemoryRunTrackRepository()
        let store = InMemoryRunBestEffortStore()
        // Un tracé d'un seul point ; pas de tracé quatre jours après la course ; pas de tracé la veille.
        let single = run(meters: 6_000, minutes: 30)
        let old = run(meters: 6_000, minutes: 30, daysAgo: 4)
        let recent = run(meters: 6_000, minutes: 30, daysAgo: 1)
        for session in [single, old, recent] { try await workouts.save(session) }
        try await tracks.save(RunTrack(id: single.id, points: Array(track(for: single, legs: [(6_000, 3)]).points.prefix(1)),
                                       splits: [], createdAt: start, updatedAt: start))

        let index = RunBestEffortIndex(workouts: workouts, tracks: tracks, store: store)
        #expect(await index.refresh(now: start) == 2)
        let cached = await store.all()
        #expect(cached[single.id]?.efforts == [] && cached[old.id]?.efforts == [])
        #expect(cached[recent.id] == nil)
    }

    @Test("une course finie pendant le passage garde ses segments précis et n'est pas prise pour une séance disparue",
          arguments: [false, true])
    func aRunFinishedDuringThePassKeepsItsPreciseSegments(afterRead: Bool) async throws {
        let base = InMemoryWorkoutRepository()
        let tracks = InMemoryRunTrackRepository()
        let store = InMemoryRunBestEffortStore()
        let finished = run(meters: 6_000, minutes: 30, daysAgo: 0)
        let precise = RunBestEfforts(id: finished.id, efforts: [RunBestEffort(meters: 5_000, seconds: 1_234)])
        // La course se termine pendant la lecture des séances : séance, tracé puis segments précis.
        let finishedTrack = track(for: finished, legs: [(6_000, 3)])
        let workouts = HookedWorkoutRepository(base: base, afterRead: afterRead) {
            try? await base.save(finished)
            try? await tracks.save(finishedTrack)
            await store.save([precise])
        }

        let index = RunBestEffortIndex(workouts: workouts, tracks: tracks, store: store)
        await index.refresh(now: start)
        #expect(await store.all()[finished.id] == precise)
    }

    @Test("le tracé relu n'est jamais rallongé à la distance de la séance, seulement raccourci")
    func trackIsNeverStretchedToTheSessionDistance() throws {
        // Le tracé simplifié mesure un peu moins que la séance : pas de 5 km relu, le record garde l'allure moyenne.
        let session = run(meters: 5_000, minutes: 25)
        let short = RunBestEffortIndex.efforts(of: track(for: session, legs: [(4_950, 3.3)]), session: session)
        #expect(short.seconds(for: 5_000) == nil)
        // Un tracé plus long que la séance (distance parcourue pendant une pause) est raccourci à la séance.
        let long = RunBestEffortIndex.efforts(of: track(for: session, legs: [(5_500, 3.3)]), session: session)
        let seconds = try #require(long.seconds(for: 5_000))
        #expect(abs(seconds - 5_500 / 3.3) < 10)
    }

    @Test("à la fin d'une course, les pauses ne comptent ni en temps ni en distance")
    func builderSamplesSkipPauses() throws {
        let trace = RunTraceFactory.withPause(start: start)
        let builder = RunTrackBuilder.replay(startedAt: start, points: trace.points, pauses: [trace.pause])
        let samples = builder.segmentSamples(pauses: [trace.pause])
        #expect(samples.count == builder.accepted.count)
        #expect(samples.last?.meters == builder.distanceMeters)
        let end = try #require(builder.accepted.last?.timestamp)
        #expect(samples.last?.seconds == RunClock.movingSeconds(from: start, pauses: [trace.pause], at: end))
        // Le temps et la distance ne reculent jamais.
        #expect(zip(samples, samples.dropFirst()).allSatisfy { $0.seconds <= $1.seconds && $0.meters <= $1.meters })
    }

    @Test("le cache dans UserDefaults garde, remplace et oublie des courses")
    func userDefaultsStoreRoundTrips() async {
        let suite = "pulse.tests.runBestEfforts.\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let store = UserDefaultsRunBestEffortStore(suiteName: suite)
        let first = RunBestEfforts(id: UUID(), efforts: [RunBestEffort(meters: 5_000, seconds: 1_400)])
        let second = RunBestEfforts(id: UUID(), efforts: [])
        await store.save([first, second])
        #expect(await UserDefaultsRunBestEffortStore(suiteName: suite).all() == [first.id: first, second.id: second])
        var faster = first
        faster.efforts = [RunBestEffort(meters: 5_000, seconds: 1_300)]
        await store.save([faster])
        await store.remove([second.id])
        #expect(await store.all() == [first.id: faster])
    }
}

/// Un dépôt de séances qui lance `hook` une fois, pendant la première lecture des séances : avant de lire le dépôt, ou juste
/// après (`afterRead`), la lecture rendant alors l'état d'avant.
private actor HookedWorkoutRepository: WorkoutRepository {
    private let base: InMemoryWorkoutRepository
    private let afterRead: Bool
    private var hook: (@Sendable () async -> Void)?

    init(base: InMemoryWorkoutRepository, afterRead: Bool, hook: @escaping @Sendable () async -> Void) {
        self.base = base
        self.afterRead = afterRead
        self.hook = hook
    }

    func sessions(from: Date, to: Date) async throws -> [WorkoutSession] {
        guard let hook else { return try await base.sessions(from: from, to: to) }
        self.hook = nil
        if !afterRead { await hook() }
        let read = try await base.sessions(from: from, to: to)
        if afterRead { await hook() }
        return read
    }

    func session(id: UUID) async throws -> WorkoutSession? { try await base.session(id: id) }
    func save(_ session: WorkoutSession) async throws { try await base.save(session) }
    func delete(id: UUID) async throws { try await base.delete(id: id) }
    func lastSets(for exercise: ExerciseReference, startedBefore date: Date) async throws -> [WorkoutSet] {
        try await base.lastSets(for: exercise, startedBefore: date)
    }
}

/// Le cache rempli par la fin d'une course et par le passage du jour.
@Suite("Meilleurs segments : fin de course et passage du jour")
struct RunBestEffortWiringTests {
    @Test func finishCachesTheBestSegmentsAndDeleteForgetsThem() async throws {
        let fixture = RunSessionFixture()
        let snapshot = try await fixture.service.start(.free())
        await fixture.push(Array(RunTraceFactory.clean(meters: 5_300, speed: 3, start: RunSessionFixture.start)[1...]))
        _ = try await fixture.service.finish()
        // À 3 m/s, le meilleur 5 km dure environ 1 667 s ; la course ne couvre ni 10 km ni le semi.
        let efforts = try #require(await fixture.bestEfforts.all()[snapshot.sessionID])
        let fiveK = try #require(efforts.seconds(for: 5_000))
        #expect(abs(fiveK - 5_000.0 / 3) < 25)
        #expect(efforts.seconds(for: 10_000) == nil)

        try await fixture.service.deleteRun(sessionID: snapshot.sessionID)
        #expect(await fixture.bestEfforts.all().isEmpty)
    }

    @Test func passCachesTheBestSegmentsOfPulseRuns() async throws {
        let fixture = RefresherFixture(scenario: .goodNight)
        try await fixture.adopt()
        let start = TestClock.date("2026-11-01T07:30")
        let run = WorkoutSession(startedAt: start, kind: .run, source: .pulse, status: .completed, title: "Course",
                                 durationMinutes: 30, distanceMeters: 6_000, createdAt: start, updatedAt: start)
        try await fixture.workouts.save(run)
        try await fixture.runTracks.save(RunTrack(id: run.id, points: RunTraceFactory.clean(meters: 6_000, speed: 3.3, start: start),
                                                  splits: [], createdAt: start, updatedAt: start))

        await fixture.refresher.refresh(origin: .foreground)

        #expect(await fixture.runBestEfforts.all()[run.id]?.seconds(for: 5_000) != nil)
    }
}
