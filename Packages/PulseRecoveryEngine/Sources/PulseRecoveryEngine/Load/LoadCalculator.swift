import Foundation

/// Une séance comptée dans la charge d'entraînement : charge = minutes × RPE (spec §6.4).
public struct LoadSession: Sendable, Equatable, Codable {
    public var date: Date
    public var minutes: Double
    public var rpe: Double

    public var load: Double { minutes * rpe }

    public init(date: Date, minutes: Double, rpe: Double) {
        self.date = date
        self.minutes = minutes
        self.rpe = rpe
    }
}

/// Zone du ratio charge aiguë / charge chronique.
public enum ACWRZone: String, Sendable, Codable {
    case undertraining
    case optimal
    case elevated
    case risk

    public init(ratio: Double) {
        if ratio < 0.8 {
            self = .undertraining
        } else if ratio <= 1.3 {
            self = .optimal
        } else if ratio < 1.5 {
            self = .elevated
        } else {
            self = .risk
        }
    }
}

public struct ACWRResult: Sendable, Equatable {
    public let acute: Double
    public let chronic: Double
    public let ratio: Double
    public let zone: ACWRZone

    public init(acute: Double, chronic: Double, ratio: Double, zone: ACWRZone) {
        self.acute = acute
        self.chronic = chronic
        self.ratio = ratio
        self.zone = zone
    }
}

/// Charge aiguë (7 jours), chronique (moyenne hebdomadaire sur 28 jours) et leur ratio.
public struct LoadCalculator: Sendable {
    /// Jours d'historique requis, jour courant compris.
    public static let requiredHistoryDays = 28
    static let acuteWindow = 0...6
    static let chronicWindow = 0...27

    private let calendar: Calendar

    public init(calendar: Calendar) {
        self.calendar = calendar
    }

    /// `nil` sans 28 jours d'historique ou sans charge chronique.
    public func acwr(sessions: [LoadSession], asOf day: Date, historyStart: Date) -> ACWRResult? {
        let dayStart = calendar.startOfDay(for: day)
        guard let historyDays = daysBetween(calendar.startOfDay(for: historyStart), dayStart),
              historyDays >= Self.requiredHistoryDays - 1 else { return nil }

        var acute = 0.0
        var chronicTotal = 0.0
        for session in sessions {
            guard let offset = daysBetween(calendar.startOfDay(for: session.date), dayStart) else { continue }
            if Self.acuteWindow.contains(offset) { acute += session.load }
            if Self.chronicWindow.contains(offset) { chronicTotal += session.load }
        }
        let chronic = chronicTotal / 4
        guard chronic > 0 else { return nil }
        let ratio = acute / chronic
        return ACWRResult(acute: acute, chronic: chronic, ratio: ratio, zone: ACWRZone(ratio: ratio))
    }

    private func daysBetween(_ from: Date, _ to: Date) -> Int? {
        calendar.dateComponents([.day], from: from, to: to).day
    }
}
