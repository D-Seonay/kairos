import Foundation
import Observation
import PhotosFeature
import PulseDomain
import PulseServices

/// Le récap d'une course enregistrée (spec V2a §4.5) : le tracé, les temps par km, le bilan, puis le RPE global et la note.
/// Le RPE n'a aucune valeur présélectionnée : sans note, la charge prend le RPE estimé (spec §5.2).
@MainActor
@Observable
public final class RunRecapModel {
    /// Les valeurs proposées, de 1 à 10.
    public static let rpeRange = 1...10

    public let data: RunRecapData
    /// `nil` : « Pas noté ».
    public var rpe: Int?
    public var note = ""
    public private(set) var isSaving = false
    public private(set) var errorMessage: String?
    /// Parti avant « Prêt » : la distance ne compte qu'à partir des premiers points précis.
    public let startedWithoutSignal: Bool
    /// La section Photos de la course ; `nil` sans service des photos ou si la séance n'en accepte pas.
    public let photos: SessionPhotosModel?

    @ObservationIgnored private let service: RunSessionService
    /// Ferme la course une fois le récap enregistré ou la course supprimée.
    @ObservationIgnored var onClose: @MainActor () -> Void = {}

    init(data: RunRecapData, service: RunSessionService, startedWithoutSignal: Bool, sessionPhotos: SessionPhotoService?,
         calendar: Calendar) {
        self.data = data
        self.service = service
        self.startedWithoutSignal = startedWithoutSignal
        photos = SessionPhotoRules.acceptsPhotos(data.session)
            ? sessionPhotos.map { SessionPhotosModel(service: $0, sessionID: data.session.id, calendar: calendar) } : nil
    }

    // MARK: Bilan

    public var title: String { data.session.title }

    /// Le temps total en mouvement, en secondes.
    public var movingSeconds: Int {
        Int(((data.session.durationMinutes ?? 0) * 60).rounded())
    }

    /// `nil` si la localisation était refusée.
    public var distanceMeters: Double? { data.session.distanceMeters }

    /// Secondes par km sur toute la course ; `nil` sous 100 m, où l'allure n'a pas de sens.
    public var averagePace: Int? {
        guard let distance = distanceMeters, distance >= 100, movingSeconds > 0 else { return nil }
        return Int((Double(movingSeconds) / (distance / 1_000)).rounded())
    }

    /// Le dénivelé positif, seulement si l'altitude était fiable.
    public var elevationGain: Double? { data.track?.elevationGainMeters }

    /// La FC moyenne livrée par la séance HealthKit ; elle reste locale (frontière M8).
    public var averageHeartRate: Double? { data.session.averageHeartRate }

    public var splits: [RunSplit] { data.track?.splits ?? [] }

    public var points: [RunTrackPoint] { data.track?.points ?? [] }

    // MARK: Actions

    /// « Enregistrer » : écrit le RPE (ou son absence) et la note, puis ferme la course.
    @discardableResult
    public func save() async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            try await service.completeRecap(sessionID: data.session.id, rpe: rpe.map(Double.init), note: note)
            errorMessage = nil
            onClose()
            return true
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu enregistrer le récap.", bundle: .module)
            return false
        }
    }

    /// « Supprimer la course », une fois confirmé : la séance, son tracé et l'entraînement écrit dans Santé disparaissent.
    @discardableResult
    public func delete() async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            try await service.deleteRun(sessionID: data.session.id)
            errorMessage = nil
            onClose()
            return true
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu supprimer la course.", bundle: .module)
            return false
        }
    }
}
