import Foundation
import PulseDomain
import SwiftData

/// Insère le jeu de données d'exemple de la spec M2 §6.3, via les dépôts. Ne dépend pas de `PulseContent`.
public struct SampleDataSeeder: Sendable {
    private let container: ModelContainer
    private let calendar: Calendar

    public init(container: ModelContainer, calendar: Calendar) {
        self.container = container
        self.calendar = calendar
    }

    public func seed(now: Date) async throws {
        let yesterday = now.addingTimeInterval(-86_400)
        try await SwiftDataProfileRepository(modelContainer: container).save(profile(now: now))
        let program = Program(template: Self.template, now: now)
        try await SwiftDataProgramRepository(modelContainer: container).save(program)
        try await SwiftDataUserExerciseRepository(modelContainer: container).save(userExercise(now: now))
        let session = session(startedAt: yesterday, program: program, now: now)
        try await SwiftDataWorkoutRepository(modelContainer: container).save(session)
        try await SwiftDataScheduledDayRepository(modelContainer: container).save(scheduledDay(date: yesterday, program: program,
                                                                                                session: session, now: now))
        let recovery = SwiftDataRecoveryRepository(modelContainer: container, calendar: calendar)
        try await recovery.save(measuredRecovery(day: yesterday, now: now))
        try await recovery.save(estimatedRecovery(day: now))
        try await recovery.save(checkIn(day: now))
        try await seedSupplements(now: now)
        try await SwiftDataBodyMeasurementRepository(modelContainer: container)
            .save(BodyMeasurement(date: yesterday, weightKg: 78, bodyFatPercent: nil, source: .manual, createdAt: now, updatedAt: now))
        try await SwiftDataPersonalRecordRepository(modelContainer: container).save(record(session: session, now: now))
        try await SwiftDataHealthSampleCache(modelContainer: container).insert(cachedSamples(now: now))
    }

    // MARK: - Entités

    static let template = ProgramTemplate(
        id: "sample", name: LocalizedText(fr: "PPL exemple"), summary: LocalizedText(fr: "Jeu de données d'exemple"),
        recommendedFor: TemplateRecommendation(focus: .strength, daysPerWeek: [3]), sessionsPerWeek: 3,
        days: [
            TemplateDay(id: "push", name: LocalizedText(fr: "Push"), kind: .strength,
                        exercises: [exercise("bench-press-barbell", rest: 120), exercise("chest-press-machine", rest: 90)]),
            TemplateDay(id: "pull", name: LocalizedText(fr: "Pull"), kind: .strength,
                        exercises: [exercise("lat-pulldown-machine", rest: 90), exercise("seated-row-machine-iso-lateral", rest: 90)]),
            TemplateDay(id: "legs", name: LocalizedText(fr: "Legs"), kind: .strength,
                        exercises: [exercise("leg-press-machine", rest: 120), exercise("leg-extension-machine", rest: 60)])
        ],
        suggestedWeek: ["push", nil, "pull", nil, "legs", nil, nil])

    private static func exercise(_ id: String, rest: Int) -> TemplateExercise {
        TemplateExercise(exercise: id, sets: 3, repsMin: 8, repsMax: 12, targetRPE: 8, restSeconds: rest)
    }

    private func profile(now: Date) -> UserProfile {
        var profile = UserProfile(createdAt: now, updatedAt: now)
        profile.heightCm = 180
        profile.weightKg = 78
        profile.strengthLevel = .intermediate
        profile.onboardingCompletedAt = now
        return profile
    }

    private func userExercise(now: Date) -> UserExercise {
        UserExercise(name: "Rowing machine du coin", primaryMuscle: .lats, secondaryMuscles: [.biceps], equipment: .machine,
                     pattern: .horizontalPull, region: .upper, isUnilateral: false, defaultIncrementKg: 2.5, defaultRestSeconds: 90,
                     createdAt: now, updatedAt: now)
    }

    /// Une séance Push : échauffement, 8 séries de travail dont un super set, une série ratée (8 prévues, 3 faites).
    private func session(startedAt: Date, program: Program, now: Date) -> WorkoutSession {
        let plan = [
            Planned(id: "bench-press-barbell", name: "Développé couché à la barre", weight: 80, sets: 3),
            Planned(id: "chest-press-machine", name: "Chest press convergent", weight: 40, sets: 3),
            Planned(id: "triceps-pushdown-cable", name: "Extension triceps poulie haute", weight: 40, sets: 1, superset: 1),
            Planned(id: "wrist-curl-cable", name: "Flexion des poignets à la poulie", weight: 40, sets: 1, superset: 1)
        ]
        var warmup = plan[0]
        warmup.weight = 40
        var sets: [WorkoutSet] = [set(order: 1, warmup, type: .warmup, startedAt: startedAt)]
        var order = 2
        for entry in plan {
            for _ in 0..<entry.sets {
                sets.append(set(order: order, entry, type: .working, startedAt: startedAt))
                order += 1
            }
        }
        sets[4].actualReps = 3
        sets[1].isPersonalRecord = true
        return WorkoutSession(startedAt: startedAt, endedAt: startedAt.addingTimeInterval(3_600), kind: .strength, source: .pulse,
                              status: .completed, programID: program.id, routineDayID: program.days.first?.id, title: "Push",
                              appliedAdjustments: [SessionAdjustment(kind: .rest, reason: "Repos +15 s", value: 15)],
                              overallRPE: 8, note: "Dos ok, \"lourd\" aujourd'hui", tonnageKg: 2_440, durationMinutes: 60,
                              sets: sets, createdAt: now, updatedAt: now)
    }

    private struct Planned {
        var id: String
        var name: String
        var weight: Double
        var sets: Int
        var superset: Int?
    }

    private func set(order: Int, _ entry: Planned, type: SetType, startedAt: Date) -> WorkoutSet {
        let reps = type == .warmup ? 10 : 8
        return WorkoutSet(order: order, exercise: .content(id: entry.id), exerciseName: entry.name, setType: type,
                          supersetGroup: entry.superset, plannedWeightKg: entry.weight, plannedReps: reps, actualWeightKg: entry.weight,
                          actualReps: reps, rpe: type == .warmup ? nil : 8, restSeconds: 90,
                          completedAt: startedAt.addingTimeInterval(Double(order) * 240))
    }

    private func scheduledDay(date: Date, program: Program, session: WorkoutSession, now: Date) -> ScheduledDay {
        ScheduledDay(date: calendar.startOfDay(for: date), programID: program.id, routineDayID: program.days.first?.id,
                     title: "Push", kind: .strength, status: .completed, sessionID: session.id, createdAt: now, updatedAt: now)
    }

    private func measuredRecovery(day: Date, now: Date) -> DailyRecovery {
        DailyRecovery(day: day, score: 72, category: .normal, isEstimated: false, hrvScore: 80, restingHeartRateScore: 60,
                      sleepScore: 70, sdnnMs: 52, sdnnBaselineMs: 48, restingHeartRate: 52, restingHeartRateBaseline: 50,
                      asleepMinutes: 420, deepMinutes: 80, calibration: .ready,
                      adjustments: [SessionAdjustment(kind: .rest, reason: "Repos +15 s", value: 15)], createdAt: now, updatedAt: now)
    }

    private func estimatedRecovery(day: Date) -> DailyRecovery {
        DailyRecovery(day: day, score: 55, category: .moderateFatigue, isEstimated: true, sleepScore: 55, asleepMinutes: 360,
                      missingFactors: [.hrv, .restingHeartRate], calibration: .calibrating(nights: 9), createdAt: day, updatedAt: day)
    }

    private func checkIn(day: Date) -> CheckIn {
        CheckIn(day: day, answers: CheckInAnswers(sleep: 2, pain: 3, motivation: 2), score: 55, createdAt: day, updatedAt: day)
    }

    private func seedSupplements(now: Date) async throws {
        let repo = SwiftDataSupplementRepository(modelContainer: container)
        let creatine = Supplement(name: "Créatine", form: .powder, dose: 5, unit: .gram, timing: .afterWorkout, days: .everyDay,
                                  stockDoses: 60, lowStockThreshold: 10, reminderEnabled: true, order: 0, createdAt: now, updatedAt: now)
        try await repo.save(creatine)
        for offset in [-86_400.0, 0] {
            try await repo.save(SupplementIntake(supplementID: creatine.id, takenAt: now.addingTimeInterval(offset), dose: 5,
                                                 createdAt: now, updatedAt: now))
        }
    }

    private func record(session: WorkoutSession, now: Date) -> PersonalRecord {
        PersonalRecord(exercise: .content(id: "bench-press-barbell"), exerciseName: "Développé couché à la barre",
                       kind: .estimatedOneRepMax, value: 100, date: session.startedAt, sessionID: session.id, setID: session.sets[1].id,
                       createdAt: now, updatedAt: now)
    }

    private func cachedSamples(now: Date) -> [CachedHealthSample] {
        let night = now.addingTimeInterval(-8 * 3_600)
        return [
            CachedHealthSample(kind: .sdnn, start: night, end: night, value: 52, sourceBundleID: "com.fitbit.FitbitMobile", fetchedAt: now),
            CachedHealthSample(kind: .restingHeartRate, start: now, end: now, value: 52, sourceBundleID: "com.fitbit.FitbitMobile",
                               fetchedAt: now),
            CachedHealthSample(kind: .sleep, start: night, end: now.addingTimeInterval(-3_600), sleepStage: .deep,
                               sourceBundleID: "com.fitbit.FitbitMobile", fetchedAt: now)
        ]
    }
}
