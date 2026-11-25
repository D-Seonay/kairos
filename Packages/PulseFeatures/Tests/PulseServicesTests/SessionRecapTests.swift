import Foundation
import PulseContent
import PulseDomain
import PulseServices
import Testing

struct SessionRecapTests {
    private typealias Fix = FinishFixtures
    private let fixture = ActiveSessionFixture()

    @Test func recapCountsWorkingSetsTonnageAndBeatenRecords() async throws {
        // Historique : bench 60 × 12, 70 × 5, 70 × 5. Séance : É 20 × 10, 60 × 12, 72,5 × 5 validées, 4e série non validée.
        try await fixture.seedHistory(LiveFixtures.rampingBench)
        let service = try await fixture.resume(Fix.session([Fix.bench(Fix.benchSets())]))
        let recap = try await service.recap(endedAt: fixture.clock.now.addingTimeInterval(3_300))
        #expect(recap.title == "Push" && recap.startedAt == Fix.start)
        #expect(recap.endedAt == TestClock.date("2026-11-02T08:55"))
        #expect(recap.workingSets == 2)
        #expect(recap.tonnageKg == 1_082.5)   // 60 × 12 + 72,5 × 5
        #expect(recap.durationMinutes == 55)
        #expect(recap.beatenRecords == [BeatenRecord(exerciseName: "Développé couché à la barre", kind: .maxWeight,
                                                     text: "Développé couché à la barre : 72,5 kg, nouveau record de charge",
                                                     spokenText: "Développé couché à la barre : 72,5 kilos, nouveau record de charge")])
        #expect(recap.suggestedRPE == 7)
    }

    @Test func eachBeatenRecordNamesItsKind() async throws {
        // 65 × 10 : 1RM estimé 86,7 kg contre 86,4 (60 × 12). 70 × 6 : une répétition de plus qu'à 70 kg. Le pec deck, fait
        // pour la première fois, ne bat aucun record.
        try await fixture.seedHistory(LiveFixtures.rampingBench)
        let session = Fix.session([
            Fix.bench([Fix.set(65, 10, at: "2026-11-02T08:10"), Fix.set(70, 6, at: "2026-11-02T08:20")]),
            Fix.pecDeck([Fix.set(40, 10, at: "2026-11-02T08:30")])
        ])
        let service = try await fixture.resume(session)
        let recap = try await service.recap(endedAt: fixture.clock.now)
        #expect(recap.beatenRecords.map(\.kind) == [.estimatedOneRepMax, .repsAtWeight])
        #expect(recap.beatenRecords.map(\.text) == ["Développé couché à la barre : 1RM estimé 86,7 kg, nouveau record",
                                                    "Développé couché à la barre : 6 répétitions à 70 kg, nouveau record"])
        #expect(recap.beatenRecords.map(\.spokenText) == [
            "Développé couché à la barre : maximum estimé sur une répétition 86,7 kilos, nouveau record",
            "Développé couché à la barre : 6 répétitions à 70 kilos, nouveau record"])
    }

    @Test func aBodyweightRecordNamesTheBodyweightOrTheBelt() async throws {
        try await fixture.seedHistory([LiveFixtures.done(LiveFixtures.pullUp, 0, 8), LiveFixtures.done(LiveFixtures.pullUp, 10, 5)])
        let session = Fix.session([Fix.pullUp([Fix.set(0, 10, at: "2026-11-02T08:10"), Fix.set(10, 6, at: "2026-11-02T08:20")])])
        let service = try await fixture.resume(session)
        let recap = try await service.recap(endedAt: fixture.clock.now)
        #expect(recap.beatenRecords.map(\.text) == ["Tractions : 10 répétitions au poids du corps, nouveau record",
                                                    "Tractions : 6 répétitions à +10 kg, nouveau record"])
        #expect(recap.beatenRecords.map(\.spokenText) == ["Tractions : 10 répétitions au poids du corps, nouveau record",
                                                          "Tractions : 6 répétitions avec un lest de 10 kilos, nouveau record"])
    }

    @Test func recapWeighsMusclesAndCountsSetsPerGroup() async throws {
        // Bench : 2 séries de travail (l'échauffement ne compte pas) ; pec deck : 1 ; tractions : 1.
        let session = Fix.session([
            Fix.bench(Fix.benchSets()),
            Fix.pecDeck([Fix.set(40, 10, at: "2026-11-02T08:45"), Fix.set(40, 10)]),
            Fix.pullUp([Fix.set(0, 8, at: "2026-11-02T08:50")])
        ])
        let service = try await fixture.resume(session)
        let recap = try await service.recap(endedAt: fixture.clock.now)
        #expect(recap.workingSets == 4)
        #expect(recap.muscleWeights == [.chest: 3, .frontDelts: 1.5, .triceps: 1, .lats: 1, .biceps: 0.5, .upperBack: 0.5,
                                        .abs: 0.5])
        #expect(recap.setsPerGroup.map(\.0) == [.chest, .back])
        #expect(recap.setsPerGroup.map(\.1) == [3, 1])
    }

    @Test func suggestedRPEIsTheRoundedMeanOfTheSetRPEs() async throws {
        let service = try await fixture.resume(Fix.session([Fix.bench(Fix.benchSets(rpes: (7.5, 9)))]))
        #expect(try await service.recap(endedAt: fixture.clock.now).suggestedRPE == 8)
    }

    @Test func loadSentenceNamesTheRatioWhenThereIsOne() async throws {
        // Sans 28 jours d'historique, la phrase s'arrête à la charge.
        let service = try await fixture.resume(Fix.session([Fix.bench(Fix.benchSets())]))
        let early = try await service.recap(endedAt: TestClock.date("2026-11-02T08:55"))
        #expect(early.loadSentence(rpe: 7) == "Charge de la séance : 55 min × 7 = 385.")
        // Onboarding de septembre, 145 min × 7 = 1015 le 20 octobre : chronique (385 + 1015) / 4 = 350, aigu 385.
        try await fixture.completeOnboarding()
        let day = TestClock.date("2026-10-20T18:00")
        try await fixture.workouts.save(WorkoutSession(startedAt: day, kind: .strength, source: .pulse, status: .completed,
                                                       title: "Jambes", overallRPE: 7, durationMinutes: 145, createdAt: day,
                                                       updatedAt: day))
        let recap = try await service.recap(endedAt: TestClock.date("2026-11-02T08:55"))
        #expect(recap.loadSentence(rpe: 7)
            == "Charge de la séance : 55 min × 7 = 385. Ratio aigu / chronique après la séance : 1,1.")
        // Le RPE choisi change la charge de la séance et le ratio : 440 / ((440 + 1015) / 4).
        #expect(recap.loadSentence(rpe: 8)
            == "Charge de la séance : 55 min × 8 = 440. Ratio aigu / chronique après la séance : 1,21.")
    }

    @Test func recapWithoutSessionThrows() async throws {
        let service = fixture.makeService()
        await #expect(throws: ActiveSessionError.noSession) { try await service.recap(endedAt: fixture.clock.now) }
    }

    /// Bench 80 × 5 (90 kg estimés) le 5 octobre, puis 80 × 4 les 12, 19 et 26 octobre : la séance du 2 novembre (au mieux
    /// 60 × 12, 86,4 kg) est la 4e sans progrès, à 4 semaines du meilleur.
    private func seedStalledBench() async throws {
        for (date, reps) in [("2026-09-28T08:00", 4), ("2026-10-05T08:00", 5), ("2026-10-12T08:00", 4), ("2026-10-19T08:00", 4),
                             ("2026-10-26T08:00", 4)] {
            let day = TestClock.date(date)
            try await fixture.workouts.save(WorkoutSession(
                startedAt: day, kind: .strength, source: .pulse, status: .completed, title: "Push",
                sets: [LiveFixtures.done(LiveFixtures.bench, 80, reps)], createdAt: day, updatedAt: day))
        }
    }

    @Test func recapNamesAPlateauThisSessionConfirms() async throws {
        try await seedStalledBench()
        let service = try await fixture.resume(Fix.session([Fix.bench(Fix.benchSets())]))
        let recap = try await service.recap(endedAt: fixture.clock.now)
        let notice = try #require(recap.plateaus.first)
        #expect(recap.plateaus.count == 1 && notice.exerciseName == "Développé couché à la barre")
        #expect(notice.plateau.bestKg == 90 && notice.plateau.bestDate == TestClock.date("2026-10-05T08:00"))
        #expect(notice.plateau.sessionCount == 4 && notice.plateau.lastDate == Fix.start)
        #expect(notice.variantName != nil && notice.variantName != notice.exerciseName)
    }

    @Test func aFatigueDayConfirmsNoPlateau() async throws {
        try await seedStalledBench()
        let fatigue = SessionAdjustment(kind: .rest, reason: "Repos rallongés de 45 secondes", value: 45)
        let service = try await fixture.resume(Fix.session([Fix.bench(Fix.benchSets())], applied: [fatigue]))
        #expect(try await service.recap(endedAt: fixture.clock.now).plateaus.isEmpty)
    }

    @Test func anExerciseWithARecordHasNoPlateau() async throws {
        // 85 × 1 bat le record de charge (80 kg) sans dépasser 90 kg estimés : le récap dit le record, pas le plateau.
        try await seedStalledBench()
        let session = Fix.session([Fix.bench([Fix.set(60, 12, at: "2026-11-02T08:10"), Fix.set(85, 1, at: "2026-11-02T08:20")])])
        let service = try await fixture.resume(session)
        let recap = try await service.recap(endedAt: fixture.clock.now)
        #expect(recap.beatenRecords.map(\.kind).contains(.maxWeight))
        #expect(recap.plateaus.isEmpty)
    }
}
