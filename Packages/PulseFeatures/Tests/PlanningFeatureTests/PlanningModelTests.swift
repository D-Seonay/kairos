import Foundation
import PlanningFeature
import PulseDomain
import PulseServices
import Testing

@MainActor
struct PlanningModelTests {
    @Test func weekTextsFollowTheDatedWeek() async throws {
        let fixture = PlanningFixture()
        try await fixture.activate()
        try await fixture.log(day: 16, tonnage: 11_240)
        try await fixture.log(day: 21, hour: 9, kind: .run, meters: 8_200, source: .appleHealth)
        let model = PlanningModel(environment: fixture.environment)
        await model.load()

        #expect(model.weekTitle == "Semaine du 16 novembre")
        #expect(model.days.map { model.title(of: $0) } == ["Push", "Pull", "Legs", "Endurance", "Push", "Course", "Repos obligatoire"])
        #expect(model.detail(of: model.days[0]) == "Validée · 11\u{202F}240 kg")
        #expect(model.detail(of: model.days[1]) == "Manquée")
        #expect(model.detail(of: model.days[2]) == "Prévue")
        #expect(model.detail(of: model.days[3]) == "Sortie facile · 45 min")
        #expect(model.detail(of: model.days[5]) == "En plus · 8,2 km")
        #expect(model.detail(of: model.days[6]) == "Choisi à l'inscription")
        #expect(model.today?.routine?.name == "Legs")
        #expect(model.weekdayText(model.days[0]) == "lun." && model.dayNumber(model.days[0]) == "16")
    }

    @Test func destinationsOpenTheRightDetail() async throws {
        let fixture = PlanningFixture()
        try await fixture.activate()
        let strength = try await fixture.log(day: 16)
        let run = try await fixture.log(day: 17, hour: 7, kind: .run, meters: 5_000, source: .appleHealth)
        let model = PlanningModel(environment: fixture.environment)
        await model.load()
        #expect(model.destination(for: model.days[0]) == .session(strength.id))
        #expect(model.destination(for: model.days[1]) == .activity(run.id))
        #expect(model.destination(for: model.days[2]) == nil)
    }

    @Test func movingSwapsDaysAndTellsWhy() async throws {
        let fixture = PlanningFixture()
        try await fixture.activate()
        let model = PlanningModel(environment: fixture.environment)
        await model.load()

        let legs = model.days[2]
        #expect(model.targets(for: legs).map { model.dayNumber($0) } == ["19", "20", "21", "22"])
        #expect(model.targets(for: model.days[1]).isEmpty, "Un jour passé ne bouge pas")
        await model.swap(legs, with: model.days[5])

        #expect(model.days[5].routine?.name == "Legs")
        #expect(model.detail(of: model.days[5]) == "Déplacée de mercredi")
        #expect(model.detail(of: model.days[2]) == "Legs déplacée à samedi")
        #expect(model.overview?.hasUserMoves == true && model.moving == nil)

        await model.restoreWeek()
        #expect(model.days[2].routine?.name == "Legs" && model.overview?.hasUserMoves == false)
    }

    @Test func monthBoundsGoFromTheFirstActivityToNextMonth() async throws {
        let fixture = PlanningFixture()
        try await fixture.activate()
        let model = PlanningModel(environment: fixture.environment)
        await model.load()
        let month = model.monthModel()
        await month.load()
        #expect(month.title == "novembre 2026" && month.canGoBack == false && month.canGoForward)
        await month.show(offset: 1)
        #expect(month.title == "décembre 2026" && !month.canGoForward)
        await month.show(offset: 1)
        #expect(month.title == "décembre 2026")
        #expect(month.currentWeekText == "0 sur 5 cette semaine")
    }

    @Test func activityDetailShowsMetricsAndSavesRPE() async throws {
        let fixture = PlanningFixture()
        try await fixture.activate()
        let run = try await fixture.log(day: 17, hour: 7, kind: .run, meters: 8_200, source: .appleHealth)
        let model = PlanningModel(environment: fixture.environment).activityDetailModel(sessionID: run.id)
        await model.load()
        #expect(model.metrics.map(\.value) == ["8,2 km", "45 min", "5:29 /km", "150 bpm", "7"])
        #expect(model.dateText == "mardi 17 novembre à 07:00")
        #expect(!model.hasChanges)

        model.rpe = 8
        model.note = " Vent de face "
        #expect(model.hasChanges)
        await model.save()
        let saved = try #require(try await fixture.workouts.session(id: run.id))
        #expect(saved.overallRPE == 8 && saved.note == "Vent de face" && !model.hasChanges)
    }

    private func track(for session: WorkoutSession, points: Int = 3, splits: Int = 1) -> RunTrack {
        let start = session.startedAt
        return RunTrack(
            id: session.id,
            points: (0..<points).map {
                RunTrackPoint(timestamp: start.addingTimeInterval(Double($0) * 10), latitude: 48.85 + Double($0) * 0.0001,
                              longitude: 2.35, horizontalAccuracy: 5)
            },
            splits: (0..<splits).map { RunSplit(kilometer: $0 + 1, seconds: 330, distanceMeters: 1_000) },
            createdAt: start, updatedAt: start)
    }

    @Test func pulseRunDetailLoadsItsTrack() async throws {
        let fixture = PlanningFixture()
        try await fixture.activate()
        let run = try await fixture.log(day: 17, hour: 7, kind: .run, meters: 4_400, source: .pulse)
        let saved = track(for: run)
        try await fixture.tracks.save(saved)
        let model = PlanningModel(environment: fixture.environment).activityDetailModel(sessionID: run.id)
        await model.load()
        #expect(model.routeTrack == saved)
    }

    @Test func runDetailHasNoRouteWithoutAUsableTrack() async throws {
        let fixture = PlanningFixture()
        try await fixture.activate()
        // Une course lue d'Apple Santé n'a pas de tracé Pulse, même si un tracé existait sous le même identifiant.
        let health = try await fixture.log(day: 16, hour: 7, kind: .run, meters: 8_200, source: .appleHealth)
        try await fixture.tracks.save(track(for: health))
        // Une course Pulse sans tracé, et une dont le tracé est vide.
        let bare = try await fixture.log(day: 17, hour: 7, kind: .run, meters: 4_400, source: .pulse)
        let empty = try await fixture.log(day: 15, hour: 7, kind: .run, meters: 4_400, source: .pulse)
        try await fixture.tracks.save(track(for: empty, points: 0, splits: 0))
        // Une course Pulse dont seuls les kilomètres sont gardés montre quand même son tracé.
        let splitsOnly = try await fixture.log(day: 14, hour: 7, kind: .run, meters: 4_400, source: .pulse)
        try await fixture.tracks.save(track(for: splitsOnly, points: 0, splits: 2))
        let planning = PlanningModel(environment: fixture.environment)
        var routes: [Bool] = []
        for session in [health, bare, empty, splitsOnly] {
            let model = planning.activityDetailModel(sessionID: session.id)
            await model.load()
            routes.append(model.routeTrack != nil)
        }
        #expect(routes == [false, false, false, true])

        // Sans dépôt de tracés, le détail reste celui d'avant.
        var environment = fixture.environment
        environment.tracks = nil
        let model = PlanningModel(environment: environment).activityDetailModel(sessionID: splitsOnly.id)
        await model.load()
        #expect(model.routeTrack == nil && model.session != nil)
    }

    @Test func ruleMovesShowTheirReasonAndCanBeRefused() async throws {
        let fixture = PlanningFixture()
        try await fixture.activate()
        let created = PlanningClock.date(day: 18)
        try await fixture.scheduled.save(ScheduledDay(
            date: PlanningClock.date(day: 19), programID: fixture.program.id, title: "Repos", kind: .rest, status: .planned,
            moveReason: .antiInterferenceAfterHeavyLegs, moveReasonText: "Course déplacée : 36 h après les jambes",
            createdAt: created, updatedAt: created))
        try await fixture.scheduled.save(ScheduledDay(
            date: PlanningClock.date(day: 21), programID: fixture.program.id, routineDayID: PlanningFixture.run.id, title: "Endurance",
            kind: .run, status: .planned, movedFromDate: PlanningClock.date(day: 19), moveReason: .antiInterferenceAfterHeavyLegs,
            moveReasonText: "Déplacée : 36 h après les jambes", createdAt: created, updatedAt: created))
        let model = PlanningModel(environment: fixture.environment)
        await model.load()

        #expect(model.detail(of: model.days[3]) == "Course déplacée : 36 h après les jambes")
        #expect(model.detail(of: model.days[5]) == "Déplacée : 36 h après les jambes")
        #expect(model.canKeepPlanned(model.days[5]) && !model.canKeepPlanned(model.days[2]))
        #expect(model.overview?.hasUserMoves == false)

        await model.keepPlanned(model.days[5])
        #expect(model.days[3].routine?.name == "Endurance" && model.days[5].routine == nil)
        #expect(!model.canKeepPlanned(model.days[3]) && model.errorMessage == nil)
    }

    @Test func aRunDoneOnALegsDayAsksForSpacing() async throws {
        let fixture = PlanningFixture()
        try await fixture.activate()
        try await fixture.log(day: 18, hour: 7, kind: .run, meters: 5_000, source: .appleHealth)
        let model = PlanningModel(environment: fixture.environment)
        await model.load()
        let today = try #require(model.today)
        #expect(model.spacingReminder(for: today) == "Au moins 6 h entre les deux, la plus technique le matin.")
        #expect(model.spacingReminder(for: model.days[3]) == nil)

        var profile = try #require(try await fixture.profiles.load())
        profile.antiInterferenceRulesDisabled = [.sameDayOrdering]
        try await fixture.profiles.save(profile)
        await model.load()
        #expect(model.spacingReminder(for: try #require(model.today)) == nil)
    }
}
