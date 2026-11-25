import Foundation
import PulseDomain
import PulseServices
import Testing

/// Midi le vendredi 20 novembre 2026 ; « Jambes » le mercredi et un fractionné le jeudi dans la semaine type.
struct BedtimeReminderServiceTests {
    private let calendar = TestClock.calendar
    private let now = TestClock.date("2026-11-20T12:00")
    private let created = TestClock.date("2026-10-01T08:00")
    private let legs = RoutineDay(order: 0, name: "Jambes", kind: .strength)
    private let intervals = RoutineDay(order: 1, name: "Course du jeudi", kind: .run, runType: .intervals)
    private let programID = UUID()

    private var program: Program {
        Program(id: programID, name: "Jambes le mercredi", sessionsPerWeek: 2,
                weekLayout: [nil, nil, legs.id, intervals.id, nil, nil, nil], days: [legs, intervals], createdAt: created,
                updatedAt: created)
    }

    private func profile(weekday: Int? = 420, weekend: Int? = 540, enabled: Bool = true) -> UserProfile {
        UserProfile(sleepGoalMinutes: 480, weekdayWakeMinutes: weekday, weekendWakeMinutes: weekend,
                    bedtimeReminderEnabled: enabled, bedtimeReminderLeadMinutes: 30, activeProgramID: programID,
                    createdAt: created, updatedAt: created)
    }

    /// Une nuit endormie sans phase, de 23:00 la veille jusqu'à 07:00 le matin de `wake`.
    private func night(wakingOn wake: Int) -> CachedHealthSample {
        CachedHealthSample(kind: .sleep, start: TestClock.date(String(format: "2026-11-%02dT23:00", wake - 1)),
                           end: TestClock.date(String(format: "2026-11-%02dT07:00", wake)), sleepStage: .asleepUnspecified,
                           fetchedAt: now)
    }

    private func service(profiles: any ProfileRepository, programs: FailingProgramRepository = FailingProgramRepository(),
                         cache: InMemoryHealthSampleCache = InMemoryHealthSampleCache(), scheduledDays: [ScheduledDay] = [],
                         reminders: StubBedtimeReminderScheduler) async throws -> BedtimeReminderService {
        try await programs.save(program)
        let now = now
        return BedtimeReminderService(profiles: profiles, programs: programs,
                                      scheduledDays: InMemoryScheduledDayRepository(scheduledDays),
                                      bedtime: HabitualBedtimeReader(cache: cache, calendar: calendar), reminders: reminders,
                                      calendar: calendar, now: { now })
    }

    private func profiles(_ profile: UserProfile) async throws -> InMemoryProfileRepository {
        let repository = InMemoryProfileRepository()
        try await repository.save(profile)
        return repository
    }

    @Test func rescheduleReplacesTheReminders() async throws {
        let reminders = StubBedtimeReminderScheduler()
        try await service(profiles: profiles(profile()), reminders: reminders).reschedule()
        #expect(await reminders.replaceCount == 1)
        #expect(await reminders.reminders.count == 7)
        #expect(await reminders.reminders.first?.fireDate == TestClock.date("2026-11-21T00:15"))
        // La semaine type : mardi 24, « Jambes » le lendemain.
        #expect(await reminders.reminders.first { $0.evening == TestClock.date("2026-11-24T00:00") }?.body
            == "Séance Jambes demain : vise tes 8 h de sommeil.")
    }

    @Test func aRunIsNamedByItsRunTypeAndAStrengthDayByItsName() async throws {
        let reminders = StubBedtimeReminderScheduler()
        try await service(profiles: profiles(profile()), reminders: reminders).reschedule()
        let planned = await reminders.reminders
        #expect(planned.first { $0.evening == TestClock.date("2026-11-25T00:00") }?.body
            == "Séance Fractionné demain : vise tes 8 h de sommeil.")
        #expect(planned.first { $0.evening == TestClock.date("2026-11-24T00:00") }?.body
            == "Séance Jambes demain : vise tes 8 h de sommeil.")
    }

    @Test func aRescheduleWaitsForTheOneInFlight() async throws {
        let profiles = GatedProfileRepository(profile())
        let reminders = StubBedtimeReminderScheduler()
        let service = try await service(profiles: profiles, reminders: reminders)
        let first = Task { await service.reschedule() }
        await profiles.waitForArrival()
        // Le rappel désactivé pendant que la première lecture attend : sa liste vide doit passer après.
        await profiles.set(profile(enabled: false))
        let second = Task { await service.reschedule() }
        for _ in 0..<100 { await Task.yield() }
        await profiles.open()
        await first.value
        await second.value
        #expect(await reminders.replaceCount == 2)
        #expect(await reminders.reminders.isEmpty)
    }

    @Test func rescheduleClearsThemWhenDisabled() async throws {
        let reminders = StubBedtimeReminderScheduler()
        try await service(profiles: profiles(profile(enabled: false)), reminders: reminders).reschedule()
        #expect(await reminders.replaceCount == 1)
        #expect(await reminders.reminders.isEmpty)
    }

    @Test func rescheduleUsesTheHabitualWakeWithoutChosenTime() async throws {
        let cache = InMemoryHealthSampleCache()
        try await cache.insert((14...20).map { night(wakingOn: $0) })
        let reminders = StubBedtimeReminderScheduler()
        let service = try await service(profiles: profiles(profile(weekday: nil, weekend: nil)), cache: cache,
                                        reminders: reminders)
        await service.reschedule()
        let planned = await reminders.reminders
        #expect(!planned.isEmpty)
        #expect(planned.allSatisfy { calendar.dateComponents([.hour, .minute], from: $0.fireDate) == DateComponents(hour: 22, minute: 15) })
        #expect(await service.plan()?.wakeMinutes(weekend: false) == 420)
    }

    @Test func rescheduleReadsTomorrowsSessionAfterMoves() async throws {
        let moved = ScheduledDay(date: TestClock.date("2026-11-21T00:00"), programID: programID, routineDayID: legs.id,
                                 title: legs.name, kind: .strength, status: .planned,
                                 movedFromDate: TestClock.date("2026-11-25T00:00"), moveReason: .user, createdAt: created,
                                 updatedAt: created)
        let reminders = StubBedtimeReminderScheduler()
        try await service(profiles: profiles(profile()), scheduledDays: [moved], reminders: reminders).reschedule()
        #expect(await reminders.reminders.first?.evening == TestClock.date("2026-11-20T00:00"))
        #expect(await reminders.reminders.first?.body == "Séance Jambes demain : vise tes 8 h de sommeil.")
    }

    @Test func unreadableProfileLeavesPendingRemindersAlone() async throws {
        let reminders = StubBedtimeReminderScheduler()
        let service = try await service(profiles: UnreadableProfileRepository(), reminders: reminders)
        await service.reschedule()
        #expect(await reminders.replaceCount == 0)
        #expect(await service.plan() == nil)
    }

    @Test func unreadableProgramStillPlansRemindersWithoutASession() async throws {
        let programs = FailingProgramRepository()
        let reminders = StubBedtimeReminderScheduler()
        let service = try await service(profiles: profiles(profile()), programs: programs, reminders: reminders)
        await programs.setFails(true)
        await service.reschedule()
        let planned = await reminders.reminders
        #expect(planned.count == 7)
        #expect(planned.allSatisfy { !$0.body.contains("Séance") && !$0.body.contains("séance") })
    }

    @Test func lastNightShortensTonightsBody() async throws {
        // Une nuit de 23:00 à 05:00 : 6 h, plus d'une heure sous l'objectif.
        let cache = InMemoryHealthSampleCache()
        try await cache.insert([CachedHealthSample(kind: .sleep, start: TestClock.date("2026-11-19T23:00"),
                                                   end: TestClock.date("2026-11-20T05:00"), sleepStage: .asleepUnspecified,
                                                   fetchedAt: now)])
        let reminders = StubBedtimeReminderScheduler()
        try await service(profiles: profiles(profile()), cache: cache, reminders: reminders).reschedule()
        #expect(await reminders.reminders.first?.body == "Nuit courte hier (6 h) : vise tes 8 h cette nuit.")
    }
}

/// Un dépôt de profils dont la première lecture rend le profil du moment après `open()` ; les suivantes le rendent tout de suite.
private actor GatedProfileRepository: ProfileRepository {
    private var profile: UserProfile
    private var reads = 0
    private var arrived = false
    private var arrival: CheckedContinuation<Void, Never>?
    private var gate: CheckedContinuation<Void, Never>?

    init(_ profile: UserProfile) {
        self.profile = profile
    }

    func set(_ profile: UserProfile) {
        self.profile = profile
    }

    /// Attend que la première lecture soit arrêtée à la barrière.
    func waitForArrival() async {
        guard !arrived else { return }
        await withCheckedContinuation { arrival = $0 }
    }

    func open() {
        gate?.resume()
        gate = nil
    }

    func load() async throws -> UserProfile? {
        reads += 1
        let read = profile
        guard reads == 1 else { return read }
        arrived = true
        arrival?.resume()
        arrival = nil
        await withCheckedContinuation { gate = $0 }
        return read
    }

    func save(_ profile: UserProfile) async throws {
        self.profile = profile
    }

    func delete(id: UUID) async throws {}

    func update(_ transform: @Sendable (inout UserProfile) throws -> Void) async throws -> ProfileUpdate? { nil }
}

/// Un dépôt de profils dont la lecture lève toujours.
private struct UnreadableProfileRepository: ProfileRepository {
    private struct Failure: Error {}

    func load() async throws -> UserProfile? { throw Failure() }

    func save(_ profile: UserProfile) async throws { throw Failure() }

    func delete(id: UUID) async throws { throw Failure() }

    func update(_ transform: @Sendable (inout UserProfile) throws -> Void) async throws -> ProfileUpdate? { throw Failure() }
}
