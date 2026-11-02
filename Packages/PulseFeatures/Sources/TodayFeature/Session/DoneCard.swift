import Foundation
import PulseDesignSystem
import PulseDomain

/// Le bilan de la séance de musculation terminée aujourd'hui, montré sur la carte à la place de « Démarrer » : titre, durée,
/// séries de travail, tonnage et records battus.
struct DoneCard: Equatable {
    var title: String
    var durationMinutes: Int
    var setCount: Int
    var tonnageKg: Double
    /// Les séries de travail qui portent la marque de record.
    var recordCount: Int

    init(title: String, durationMinutes: Int, setCount: Int, tonnageKg: Double, recordCount: Int) {
        self.title = title
        self.durationMinutes = durationMinutes
        self.setCount = setCount
        self.tonnageKg = tonnageKg
        self.recordCount = recordCount
    }

    /// La dernière séance de musculation terminée (pas abandonnée) parmi `sessions`, ou `nil`.
    static func latest(in sessions: [WorkoutSession]) -> DoneCard? {
        sessions
            .filter { $0.kind == .strength && $0.status == .completed }
            .max { ($0.endedAt ?? $0.startedAt) < ($1.endedAt ?? $1.startedAt) }
            .map(DoneCard.init)
    }

    private init(_ session: WorkoutSession) {
        let working = session.sets.filter { $0.setType != .warmup }
        let minutes = session.durationMinutes ?? session.endedAt.map { $0.timeIntervalSince(session.startedAt) / 60 } ?? 0
        self.init(title: session.title, durationMinutes: Int(max(0, minutes).rounded()), setCount: working.count,
                  tonnageKg: session.tonnageKg, recordCount: working.filter(\.isPersonalRecord).count)
    }

    // MARK: - Textes

    /// « 55 min », « 1 h 15 ».
    var durationText: String { PulseFormat.duration(minutes: durationMinutes) }

    /// « 1 série », « 18 séries ».
    var setsText: String {
        setCount == 1 ? String(localized: "1 série", bundle: .module) : String(localized: "\(setCount) séries", bundle: .module)
    }

    /// « 6420 kg », « 62,5 kg ».
    var tonnageText: String {
        String(localized: "\(PulseFormat.decimal(tonnageKg, maxFractionDigits: 1)) kg", bundle: .module)
    }

    /// « 1 record », « 2 records » ; `nil` sans record.
    var recordsText: String? {
        switch recordCount {
        case ..<1: nil
        case 1: String(localized: "1 record", bundle: .module)
        default: String(localized: "\(recordCount) records", bundle: .module)
        }
    }

    /// « 55 min · 18 séries · 6420 kg · 2 records ».
    var statsText: String {
        ([durationText, setsText, tonnageText] + [recordsText].compactMap { $0 }).joined(separator: " · ")
    }
}
