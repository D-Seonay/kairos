import Foundation
import PulseDomain
import PulseRecoveryEngine

/// Décide le score de récupération du jour à partir des nuits fraîchement lues (spec M3 §9.2) :
/// rien avant 4 h, calculé et recalculé jusqu'à midi, figé à midi, check-in quand les données ne suffisent pas.
/// La première passe après midi recalcule une dernière fois, puis fige : le score figé est celui des données du moment.
/// Chaque score enregistré porte les ajustements de la séance prévue et garde le choix « Séance d'origine ».
/// Une seule instance est partagée par l'app : ses opérations passent l'une après l'autre par la même file,
/// pour qu'aucune ne lise le score du jour pendant qu'une autre l'écrit.
public final class DailyScoreService: Sendable {
    public static let dayStartHour = 4
    public static let freezeHour = 12

    private let recovery: any RecoveryRepository
    private let calendar: Calendar
    private let queue = SerialTaskQueue()

    public init(recovery: any RecoveryRepository, calendar: Calendar) {
        self.recovery = recovery
        self.calendar = calendar
    }

    /// `plannedDay` à `nil` veut dire « programme illisible » : le score est calculé, les ajustements déjà enregistrés sont gardés.
    /// `sleepGoalMinutes` est l'objectif de sommeil du profil ; à `nil`, « profil illisible » : le score déjà enregistré pour le jour
    /// est gardé tel quel, et sans score enregistré le calcul prend l'objectif par défaut.
    public func update(nights: [NightSample], plannedDay: PlannedDay?, sleepGoalMinutes: Int?, now: Date) async throws -> TodayScore {
        try await queue.run {
            try await self.score(nights: nights, plannedDay: plannedDay, sleepGoalMinutes: sleepGoalMinutes, now: now)
        }
    }

    /// Enregistre le check-in. Sans score mesuré, il produit un score estimé, remplacé par un score mesuré avant midi ; avec un
    /// score mesuré, il s'y ajoute comme léger modificateur (`FeelingAdjustment`), jusqu'à midi. Refusé une fois le jour figé, et
    /// pour un score mesuré dès midi, même si aucune passe ne l'a encore figé : rien n'est alors enregistré.
    public func saveCheckIn(_ answers: CheckInAnswers, plannedDay: PlannedDay?, now: Date) async throws -> DailyRecovery {
        try await queue.run { try await self.estimate(answers, plannedDay: plannedDay, now: now) }
    }

    /// Enregistre le choix de l'utilisateur : `true` garde la séance d'origine, `false` revient à la séance ajustée.
    /// Permis après le figement : ni le score ni `frozenAt` ne changent.
    public func chooseOriginalSession(_ chosen: Bool, now: Date) async throws -> DailyRecovery {
        try await queue.run {
            guard var existing = try await self.stored(on: self.calendar.startOfDay(for: now)) else {
                throw DailyScoreError.noScoreToday
            }
            existing.originalSessionChosen = chosen
            existing.updatedAt = now
            try await self.recovery.save(existing)
            return existing
        }
    }

    // MARK: - Interne

    private func score(nights: [NightSample], plannedDay: PlannedDay?, sleepGoalMinutes: Int?, now: Date) async throws -> TodayScore {
        let day = calendar.startOfDay(for: now)
        let hour = calendar.component(.hour, from: now)
        let isAfterFreeze = hour >= Self.freezeHour
        guard hour >= Self.dayStartHour else {
            return .beforeDayStart(yesterday: try await yesterday(before: day))
        }
        let existing = try await stored(on: day)
        if let existing, existing.frozenAt != nil {
            return .scored(existing)
        }

        let tonight = nights.first { calendar.isDate($0.day, inSameDayAs: day) }
            ?? NightSample(day: day, sdnnMs: nil, restingHeartRate: nil, sleep: nil)
        let history = nights.filter { !calendar.isDate($0.day, inSameDayAs: day) }
        let outcome = RecoveryCalculator(calendar: calendar).compute(
            day: day, today: tonight, history: history, sleepGoalMinutes: sleepGoalMinutes ?? SleepGoal.defaultMinutes,
            checkIn: try await checkIn(on: day)?.answers)

        // Un profil illisible ne fait pas retomber le score du jour sur l'objectif par défaut : le score enregistré reste.
        if sleepGoalMinutes == nil, let existing {
            return .scored(isAfterFreeze ? try await freeze(existing, at: now) : existing)
        }
        switch outcome {
        case .measured(let result):
            // La passe qui fige applique d'abord la mesure fraîche : un score écrit tôt sur une nuit partielle ne reste pas.
            var measured = DailyRecovery(result: result, night: tonight, now: now)
            measured.id = existing?.id ?? measured.id
            measured.createdAt = existing?.createdAt ?? now
            measured.adjustments = Self.adjustments(for: plannedDay, category: measured.category, keeping: existing)
            measured.originalSessionChosen = existing?.originalSessionChosen
            measured.frozenAt = isAfterFreeze ? now : nil
            if let existing, existing.isSameMeasure(as: measured) { return .scored(existing) }
            try await recovery.save(measured)
            return .scored(measured)
        case .needsCheckIn(let missing):
            guard let existing else { return .needsCheckIn(missing: missing) }
            return .scored(isAfterFreeze ? try await freeze(existing, at: now) : existing)
        }
    }

    /// Fige le score enregistré tel quel : la passe de midi n'a rien de plus frais à lui appliquer.
    private func freeze(_ existing: DailyRecovery, at now: Date) async throws -> DailyRecovery {
        var frozen = existing
        frozen.frozenAt = now
        frozen.updatedAt = now
        try await recovery.save(frozen)
        return frozen
    }

    private func estimate(_ answers: CheckInAnswers, plannedDay: PlannedDay?, now: Date) async throws -> DailyRecovery {
        let day = calendar.startOfDay(for: now)
        let existing = try await stored(on: day)
        let isAfterFreeze = calendar.component(.hour, from: now) >= Self.freezeHour
        if existing?.frozenAt != nil || (isAfterFreeze && existing?.isEstimated == false) {
            throw DailyScoreError.frozen
        }
        let score = CheckInScorer.score(answers)
        let checkIn = CheckIn(day: day, answers: answers, score: score, createdAt: now, updatedAt: now)
        try await recovery.save(checkIn)
        if let existing, !existing.isEstimated {
            return try await applyFeeling(checkIn, to: existing, plannedDay: plannedDay, now: now)
        }
        let category = RecoveryCategory(score: score)
        let estimated = DailyRecovery(
            id: existing?.id ?? UUID(), day: day, score: score, category: category, isEstimated: true,
            missingFactors: Factor.allCases, calibration: .calibrating(nights: 0),
            adjustments: Self.adjustments(for: plannedDay, category: category, keeping: existing),
            frozenAt: isAfterFreeze ? now : nil,
            originalSessionChosen: existing?.originalSessionChosen,
            createdAt: existing?.createdAt ?? now, updatedAt: now)
        try await recovery.save(estimated)
        return estimated
    }

    /// Le score mesuré, son ressenti appliqué : la catégorie peut baisser (et la séance s'alléger), jamais monter.
    private func applyFeeling(_ checkIn: CheckIn, to measured: DailyRecovery, plannedDay: PlannedDay?,
                              now: Date) async throws -> DailyRecovery {
        guard let feeling = measured.feeling(checkIn) else { return measured }
        var adjusted = measured
        adjusted.score = feeling.score
        adjusted.category = RecoveryCategory(score: feeling.score)
        adjusted.adjustments = Self.adjustments(for: plannedDay, category: adjusted.category, keeping: measured)
        adjusted.updatedAt = now
        try await recovery.save(adjusted)
        return adjusted
    }

    private func checkIn(on day: Date) async throws -> CheckIn? {
        guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
        return try await recovery.checkIns(from: day, to: next).first
    }

    /// Les ajustements que la catégorie impose à la séance prévue ; aucun un jour de repos ou sans programme.
    /// Un programme illisible (`plannedDay` à `nil`) garde ceux du score déjà enregistré.
    private static func adjustments(for plannedDay: PlannedDay?, category: RecoveryCategory,
                                    keeping existing: DailyRecovery?) -> [SessionAdjustment] {
        guard let plannedDay else { return existing?.adjustments ?? [] }
        guard let day = plannedDay.routineDay else { return [] }
        return SessionAdjuster.adjust(day, category: category).adjustments
    }

    private func stored(on day: Date) async throws -> DailyRecovery? {
        guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
        return try await recovery.dailyRecoveries(from: day, to: next).first
    }

    private func yesterday(before day: Date) async throws -> DailyRecovery? {
        guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { return nil }
        return try await stored(on: previous)
    }
}

private extension DailyRecovery {
    /// Vrai si `other` ne diffère de ce score que par son identité et ses dates d'écriture : le réenregistrer ne changerait rien,
    /// sinon qu'une écriture CloudKit de plus à chaque retour sur l'onglet Aujourd'hui.
    func isSameMeasure(as other: DailyRecovery) -> Bool {
        var comparable = other
        comparable.id = id
        comparable.createdAt = createdAt
        comparable.updatedAt = updatedAt
        return comparable == self
    }
}
