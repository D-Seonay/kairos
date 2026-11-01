import Foundation
import PulseDomain
import PulseRecoveryEngine

/// Décide le score de récupération du jour à partir des nuits fraîchement lues (spec M3 §9.2) :
/// rien avant 4 h, calculé et recalculé jusqu'à midi, figé à midi, check-in quand les données ne suffisent pas.
public struct DailyScoreService: Sendable {
    public static let dayStartHour = 4
    public static let freezeHour = 12

    private let recovery: any RecoveryRepository
    private let calendar: Calendar

    public init(recovery: any RecoveryRepository, calendar: Calendar) {
        self.recovery = recovery
        self.calendar = calendar
    }

    public func update(nights: [NightSample], now: Date) async throws -> TodayScore {
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
        let outcome = RecoveryCalculator(calendar: calendar).compute(day: day, today: tonight, history: history)

        if isAfterFreeze, var existing {
            existing.frozenAt = now
            existing.updatedAt = now
            try await recovery.save(existing)
            return .scored(existing)
        }
        switch outcome {
        case .measured(let result):
            var measured = DailyRecovery(result: result, night: tonight, now: now)
            measured.id = existing?.id ?? measured.id
            measured.createdAt = existing?.createdAt ?? now
            measured.frozenAt = isAfterFreeze ? now : nil
            if let existing, existing.isSameMeasure(as: measured) { return .scored(existing) }
            try await recovery.save(measured)
            return .scored(measured)
        case .needsCheckIn(let missing):
            return existing.map(TodayScore.scored) ?? .needsCheckIn(missing: missing)
        }
    }

    /// Enregistre le check-in et le score estimé qu'il produit ; il sera remplacé par un score mesuré avant midi.
    public func saveCheckIn(_ answers: CheckInAnswers, now: Date) async throws -> DailyRecovery {
        let day = calendar.startOfDay(for: now)
        let existing = try await stored(on: day)
        if existing?.frozenAt != nil {
            throw DailyScoreError.frozen
        }
        let score = CheckInScorer.score(answers)
        try await recovery.save(CheckIn(day: day, answers: answers, score: score, createdAt: now, updatedAt: now))
        let estimated = DailyRecovery(
            id: existing?.id ?? UUID(), day: day, score: score, category: RecoveryCategory(score: score), isEstimated: true,
            missingFactors: Factor.allCases, calibration: .calibrating(nights: 0),
            frozenAt: calendar.component(.hour, from: now) >= Self.freezeHour ? now : nil,
            createdAt: existing?.createdAt ?? now, updatedAt: now)
        try await recovery.save(estimated)
        return estimated
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
