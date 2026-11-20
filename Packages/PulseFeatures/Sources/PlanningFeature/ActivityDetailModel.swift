import Foundation
import Observation
import PulseDesignSystem
import PulseDomain
import PulseServices

/// Le détail d'une course ou d'un vélo lu d'Apple Santé (spec M6 §7) : distance, durée, allure, FC moyenne, RPE estimé ; le
/// RPE et la note se corrigent. L'entraînement se supprime dans Apple Santé, pas ici.
@MainActor
@Observable
public final class ActivityDetailModel {
    public private(set) var session: WorkoutSession?
    public private(set) var hasLoaded = false
    public private(set) var errorMessage: String?
    public var rpe: Double?
    public var note = ""

    @ObservationIgnored private let environment: PlanningEnvironment
    @ObservationIgnored private let sessionID: UUID

    public init(environment: PlanningEnvironment, sessionID: UUID) {
        self.environment = environment
        self.sessionID = sessionID
    }

    public func load() async {
        do {
            session = try await environment.train.workouts.session(id: sessionID)
            rpe = session?.overallRPE
            note = session?.note ?? ""
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu lire cette séance.", bundle: .module)
        }
        hasLoaded = true
    }

    /// Vrai quand le RPE ou la note diffère de ce qui est enregistré.
    public var hasChanges: Bool {
        guard let session else { return false }
        return rpe != session.overallRPE || trimmedNote != session.note
    }

    /// Enregistre le RPE et la note sur la séance relue à l'instant.
    public func save() async {
        do {
            guard var fresh = try await environment.train.workouts.session(id: sessionID) else { return }
            fresh.overallRPE = rpe
            fresh.note = trimmedNote
            fresh.updatedAt = environment.now()
            try await environment.train.workouts.save(fresh)
            session = fresh
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu enregistrer tes corrections.", bundle: .module)
        }
    }

    private var trimmedNote: String? {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - Textes

    /// « mardi 17 novembre à 07:30 ».
    public var dateText: String {
        guard let date = session?.startedAt else { return "" }
        let day = environment.text(of: date) { $0.weekday(.wide).day().month(.wide) }
        let time = environment.text(of: date) { $0.hour().minute() }
        return String(localized: "\(day) à \(time)", bundle: .module)
    }

    /// Les mesures lues, dans l'ordre de l'écran ; une mesure absente est omise.
    public var metrics: [(label: String, value: String)] {
        guard let session else { return [] }
        var rows: [(String, String)] = []
        if let meters = session.distanceMeters, meters > 0 {
            rows.append((String(localized: "Distance", bundle: .module), PlanningText.distance(meters: meters)))
        }
        if let minutes = session.durationMinutes, minutes > 0 {
            rows.append((String(localized: "Durée", bundle: .module), PulseFormat.duration(minutes: Int(minutes.rounded()))))
        }
        if session.kind == .run, let pace = PlanningText.pace(minutes: session.durationMinutes, meters: session.distanceMeters) {
            rows.append((String(localized: "Allure", bundle: .module), pace))
        }
        if let heartRate = session.averageHeartRate, heartRate > 0 {
            rows.append((String(localized: "FC moyenne", bundle: .module), "\(Int(heartRate.rounded())) bpm"))
        }
        if let estimated = session.estimatedRPE {
            rows.append((String(localized: "RPE estimé", bundle: .module), PulseFormat.decimal(estimated, maxFractionDigits: 1)))
        }
        return rows
    }
}
