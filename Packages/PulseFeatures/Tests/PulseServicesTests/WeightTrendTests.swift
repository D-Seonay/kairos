import Foundation
import PulseDomain
import PulseServices
import Testing

struct WeightTrendTests {
    private let now = TestClock.date("2026-11-20T12:00")

    private func measurement(_ weight: Double?, daysAgo: Int, at time: String = "07:00", source: MeasurementSource = .appleHealth,
                             fat: Double? = nil) -> BodyMeasurement {
        let day = TestClock.calendar.date(byAdding: .day, value: -daysAgo, to: TestClock.calendar.startOfDay(for: now)) ?? now
        let parts = time.split(separator: ":").compactMap { Int($0) }
        let date = TestClock.calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: day) ?? day
        return BodyMeasurement(date: date, weightKg: weight, bodyFatPercent: fat, source: source, createdAt: date, updatedAt: date)
    }

    private func trend(_ measurements: [BodyMeasurement]) -> WeightTrend {
        WeightTrend.make(measurements: measurements, now: now, calendar: TestClock.calendar)
    }

    @Test func noMeasurementGivesNoTrend() {
        let empty = trend([])

        #expect(empty.current == nil && empty.lastMeasured == nil && empty.change30Days == nil)
        #expect(empty.days.isEmpty && empty.trendPoints.isEmpty && !empty.isStale && empty.latestBodyFat == nil)
    }

    @Test func trendIsTheSevenDayMeanOfMeasuredDays() {
        let result = trend([measurement(80, daysAgo: 2), measurement(79, daysAgo: 1), measurement(78, daysAgo: 0)])

        #expect(result.current == 79)
        #expect(result.trendPoints.map(\.value) == [80, 79.5, 79])
        #expect(result.trendPoints.map(\.date) == result.days.map(\.date))

        // Une mesure sept jours avant le dernier point (J-7) sort de sa fenêtre ; J-6 y entre.
        let wide = trend([measurement(90, daysAgo: 8), measurement(80, daysAgo: 7), measurement(70, daysAgo: 6),
                          measurement(78, daysAgo: 0)])
        #expect(wide.current == 74.0)
        #expect(trend([measurement(90, daysAgo: 8), measurement(78, daysAgo: 0)]).current == 78)
    }

    @Test func manualWinsTheDay() {
        let result = trend([measurement(80.2, daysAgo: 0, at: "07:00"), measurement(79.6, daysAgo: 0, at: "06:00", source: .manual)])

        #expect(result.days.count == 1)
        #expect(result.days.last?.weightKg == 79.6 && result.days.last?.source == .manual)
    }

    @Test func latestMeasurementOfTheDayWins() {
        let result = trend([measurement(80, daysAgo: 0, at: "07:00"), measurement(79, daysAgo: 0, at: "21:00")])

        #expect(result.days.map(\.weightKg) == [79])
    }

    @Test func staleTrendKeepsItsDate() {
        let result = trend([measurement(80, daysAgo: 21), measurement(78, daysAgo: 20)])

        #expect(result.isStale)
        #expect(result.current == 79)
        #expect(result.lastMeasured == TestClock.calendar.date(byAdding: .day, value: -20, to: TestClock.calendar.startOfDay(for: now)))
        #expect(!trend([measurement(80, daysAgo: 14)]).isStale)
        #expect(trend([measurement(80, daysAgo: 15)]).isStale)
    }

    @Test func changeNeedsAMeasurementThirtyDaysBefore() throws {
        // 40 jours de pesées qui baissent de 0,1 kg par jour.
        let long = (0...40).map { measurement(76 + 0.1 * Double($0), daysAgo: $0) }
        let change = try #require(trend(long).change30Days)
        #expect(abs(change + 3.0) < 0.001)

        let short = (0...20).map { measurement(76 + 0.1 * Double($0), daysAgo: $0) }
        #expect(trend(short).change30Days == nil)
    }

    @Test func changeUsesTheLatestMeasuredDayAtLeastThirtyDaysBefore() throws {
        // Pas de pesée exactement 30 jours avant : on prend la dernière avant.
        let result = trend([measurement(82, daysAgo: 40), measurement(81, daysAgo: 33), measurement(79, daysAgo: 0)])

        let change = try #require(result.change30Days)
        #expect(abs(change + 2.0) < 0.001)
    }

    @Test func changeIgnoresAReferenceOlderThanThirtySevenDays() throws {
        // Une pesée vieille de 300 jours ne dit rien d'un écart « en 30 j ».
        let old = trend([measurement(85, daysAgo: 300), measurement(79, daysAgo: 3), measurement(78.6, daysAgo: 0)])
        #expect(old.change30Days == nil)
        // La borne : 37 jours avant le dernier jour mesuré compte encore, 38 non.
        #expect(trend([measurement(81, daysAgo: 37), measurement(79, daysAgo: 0)]).change30Days != nil)
        #expect(trend([measurement(81, daysAgo: 38), measurement(79, daysAgo: 0)]).change30Days == nil)
        // 33 jours avant : l'écart est calculé.
        let change = try #require(trend([measurement(81, daysAgo: 33), measurement(79, daysAgo: 0)]).change30Days)
        #expect(abs(change + 2.0) < 0.001)
    }

    @Test func bodyFatComesFromTheLatestReading() throws {
        let result = trend([measurement(nil, daysAgo: 5, fat: 18), measurement(80, daysAgo: 3, fat: 17.2),
                            measurement(nil, daysAgo: 9, fat: 19)])

        let fat = try #require(result.latestBodyFat)
        #expect(fat.percent == 17.2)
        #expect(fat.date == measurement(80, daysAgo: 3).date)
    }

    @Test func fatOnlyMeasurementsDoNotMakeAWeightDay() {
        let result = trend([measurement(nil, daysAgo: 1, fat: 18)])

        #expect(result.days.isEmpty && result.current == nil && result.lastMeasured == nil)
        #expect(result.latestBodyFat?.percent == 18)
    }

    // MARK: - Poids du profil (spec M8 §5.3)

    private func sync(_ measurements: [BodyMeasurement], profileWeight: Double?) async throws -> (UserProfile?, Double?) {
        let profiles = InMemoryProfileRepository()
        try await profiles.save(UserProfile(weightKg: profileWeight, createdAt: now, updatedAt: now))
        let repository = InMemoryBodyMeasurementRepository(measurements)
        try await ProfileWeightSync.apply(measurements: repository, profiles: profiles, now: now, calendar: TestClock.calendar)
        let current = await ProfileWeightSync.currentWeight(measurements: repository, profiles: profiles, now: now,
                                                            calendar: TestClock.calendar)
        return (try await profiles.load(), current)
    }

    @Test func profileWeightIgnoresHealthWeighIns() async throws {
        let weighIns = (0..<3).flatMap { [measurement(80, daysAgo: $0, source: .manual), measurement(70, daysAgo: $0, at: "08:00")] }

        let (profile, _) = try await sync(weighIns, profileWeight: nil)

        #expect(profile?.weightKg == 80)
    }

    @Test func profileWeightTakesTheLastManualWhenOld() async throws {
        let weighIns = [measurement(82, daysAgo: 90, source: .manual), measurement(78, daysAgo: 1), measurement(78, daysAgo: 0)]

        let (profile, current) = try await sync(weighIns, profileWeight: 80)

        #expect(profile?.weightKg == 82)
        #expect(current == 78)
    }

    @Test func profileWeightClearsWhenOnlyHealthWeighInsExist() async throws {
        let (profile, current) = try await sync([measurement(78, daysAgo: 1), measurement(76, daysAgo: 0)], profileWeight: 77)

        #expect(profile?.weightKg == nil)
        #expect(current == 77)
    }

    /// Sans tendance sur 30 jours, la dernière pesée l'emporte, quelle que soit sa source : le profil n'a plus de poids dès que
    /// des pesées Apple Santé existent.
    @Test func currentWeightFallsBackOnTheLatestWeighInOfAnySource() async throws {
        let (profile, current) = try await sync([measurement(77, daysAgo: 45), measurement(76, daysAgo: 40)], profileWeight: 80)

        #expect(profile?.weightKg == nil)
        #expect(current == 76)
    }

    @Test func profileWeightUntouchedWithoutAnyWeighIn() async throws {
        let (profile, current) = try await sync([], profileWeight: 77)

        #expect(profile?.weightKg == 77 && profile?.updatedAt == now)
        #expect(current == 77)
    }

    @Test func profileWeightIsNotRewrittenWhenUnchanged() async throws {
        let later = TestClock.date("2026-11-21T12:00")
        let profiles = InMemoryProfileRepository()
        try await profiles.save(UserProfile(weightKg: 80, createdAt: now, updatedAt: now))
        let repository = InMemoryBodyMeasurementRepository([measurement(80, daysAgo: 0, source: .manual)])

        try await ProfileWeightSync.apply(measurements: repository, profiles: profiles, now: later, calendar: TestClock.calendar)

        #expect(try await profiles.load()?.updatedAt == now)
    }
}
