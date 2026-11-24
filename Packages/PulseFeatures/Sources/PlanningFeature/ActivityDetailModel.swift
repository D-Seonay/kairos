import Foundation
import Observation
import PulseDesignSystem
import PulseDomain
import PulseServices

/// Le détail d'une course ou d'un vélo lu d'Apple Santé (spec M6 §7) : distance, durée, allure, FC moyenne, RPE estimé ; le
/// RPE et la note se corrigent. L'entraînement se supprime dans Apple Santé, pas ici. Une course faite avec Pulse y ajoute son
/// tracé et ses temps par kilomètre (spec V2a §4.5).
@MainActor
@Observable
public final class ActivityDetailModel {
    public private(set) var session: WorkoutSession?
    public private(set) var hasLoaded = false
    /// Le tracé d'une course Pulse, quand il a des points ou des kilomètres à montrer ; `nil` sinon.
    public private(set) var routeTrack: RunTrack?
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
            routeTrack = await track(of: session)
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu lire cette séance.", bundle: .module)
        }
        hasLoaded = true
    }

    /// Le tracé de `session` si c'est une course Pulse qui en a un d'utilisable. Un tracé illisible ne gâche pas le détail : il
    /// manque, rien de plus.
    private func track(of session: WorkoutSession?) async -> RunTrack? {
        guard let session, session.source == .pulse, session.kind == .run, let tracks = environment.tracks,
              let track = try? await tracks.track(for: session.id), !track.points.isEmpty || !track.splits.isEmpty else { return nil }
        return track
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

    /// Les mesures lues, dans l'ordre de l'écran ; une mesure absente est omise. `spokenValue` est ce que VoiceOver lit.
    public var metrics: [ActivityMetric] {
        guard let session else { return [] }
        var rows: [ActivityMetric] = []
        if let meters = session.distanceMeters, meters > 0 {
            rows.append(ActivityMetric(
                label: String(localized: "Distance", bundle: .module), value: PlanningText.distance(meters: meters),
                spokenValue: PlanningText.distanceSpoken(meters: meters)))
        }
        if let minutes = session.durationMinutes, minutes > 0 {
            let rounded = Int(minutes.rounded())
            rows.append(ActivityMetric(
                label: String(localized: "Durée", bundle: .module), value: PulseFormat.duration(minutes: rounded),
                spokenValue: PulseSpoken.duration(seconds: rounded * 60)))
        }
        if session.kind == .run, let pace = PlanningText.pace(minutes: session.durationMinutes, meters: session.distanceMeters),
           let spoken = PlanningText.paceSpoken(minutes: session.durationMinutes, meters: session.distanceMeters) {
            rows.append(ActivityMetric(label: String(localized: "Allure", bundle: .module), value: pace, spokenValue: spoken))
        }
        if let heartRate = session.averageHeartRate, heartRate > 0 {
            let rounded = Int(heartRate.rounded())
            rows.append(ActivityMetric(
                label: String(localized: "FC moyenne", bundle: .module), value: "\(rounded) bpm",
                spokenValue: PlanningText.heartRateSpoken(rounded)))
        }
        if let estimated = session.estimatedRPE {
            let value = PulseFormat.decimal(estimated, maxFractionDigits: 1)
            rows.append(ActivityMetric(label: String(localized: "RPE estimé", bundle: .module), value: value, spokenValue: value))
        }
        return rows
    }
}

/// Une mesure de l'écran de détail : son libellé, sa valeur affichée et la même valeur sans abréviation pour VoiceOver.
public struct ActivityMetric: Equatable, Sendable {
    public let label: String
    public let value: String
    public let spokenValue: String
}
