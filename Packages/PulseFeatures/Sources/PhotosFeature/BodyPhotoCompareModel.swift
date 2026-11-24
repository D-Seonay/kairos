import Foundation
import Observation
import PulseDesignSystem
import PulseDomain
import PulseServices

/// La comparaison avant / après d'une pose : les poses qui ont au moins deux dates, la paire de photos (la plus ancienne et la
/// plus récente par défaut), la position du trait de la scène superposée et la variation de la tendance du poids entre les deux
/// dates. Les images elles-mêmes passent par `BodyPhotosModel`, qui garde le verrou.
@MainActor @Observable
public final class BodyPhotoCompareModel {
    /// Le pas du curseur avec VoiceOver (balayer vers le haut ou le bas) : 10 %.
    static let step = 0.1

    public private(set) var poses: [BodyPose]
    public private(set) var before: BodyPhoto?
    public private(set) var after: BodyPhoto?
    /// En kilos ; `nil` sans tendance à l'une des deux dates : la tuile est alors absente.
    public private(set) var weightChange: Double?
    /// La part de la scène où l'on voit la photo d'avant, de 0 à 1.
    public var position = 0.5
    /// Les deux photos sans superposition ; la vue l'active d'office avec VoiceOver ou une taille d'accessibilité.
    public var isSideBySide = false
    private var selectedPose: BodyPose

    @ObservationIgnored private let service: BodyPhotoService
    @ObservationIgnored private let photos: [BodyPhoto]
    @ObservationIgnored private let calendar: Calendar

    public init(service: BodyPhotoService, photos: [BodyPhoto], calendar: Calendar) {
        self.service = service
        self.photos = photos
        self.calendar = calendar
        let poses = BodyPhotoTimeline.comparablePoses(photos, calendar: calendar)
        self.poses = poses
        selectedPose = poses.first ?? .front
        resetPair()
    }

    /// La pose comparée ; changer de pose revient à sa paire par défaut. Une pose sans deux dates est ignorée.
    public var pose: BodyPose {
        get { selectedPose }
        set {
            guard newValue != selectedPose, poses.contains(newValue) else { return }
            selectedPose = newValue
            resetPair()
        }
    }

    /// Les photos de la pose, une par jour, la plus récente d'abord : les dates que propose « Changer les dates ».
    public var candidates: [BodyPhoto] {
        BodyPhotoTimeline.days(photos.filter { $0.pose == selectedPose }, calendar: calendar).compactMap { $0.photos[selectedPose] }
    }

    /// Choisit deux dates de la pose, remises dans l'ordre ; deux photos du même jour ne se comparent pas.
    public func choose(before: BodyPhoto, after: BodyPhoto) async {
        guard before.pose == selectedPose, after.pose == selectedPose,
              !calendar.isDate(before.takenAt, inSameDayAs: after.takenAt) else { return }
        let ordered = before.takenAt < after.takenAt ? (before, after) : (after, before)
        self.before = ordered.0
        self.after = ordered.1
        weightChange = nil
        await refreshWeightChange()
    }

    /// Relit la variation de la tendance du poids pour la paire affichée ; une réponse arrivée après un changement de paire est
    /// ignorée.
    public func refreshWeightChange() async {
        guard let before, let after else {
            weightChange = nil
            return
        }
        let change = try? await service.weightChange(from: before.takenAt, to: after.takenAt)
        guard self.before?.id == before.id, self.after?.id == after.id else { return }
        weightChange = change ?? nil
    }

    public func increment() {
        position = Self.clamped(position + Self.step)
    }

    public func decrement() {
        position = Self.clamped(position - Self.step)
    }

    /// Arrondi au centième, borné à 0…1 : dix pas de 10 % tombent juste sur 1.
    static func clamped(_ value: Double) -> Double {
        min(max((value * 100).rounded() / 100, 0), 1)
    }

    // MARK: Textes

    /// « Avant, 1er août · Après, 28 octobre ».
    public var sliderSpokenLabel: String {
        guard let before, let after else { return PhotoText.compareTitle }
        return PhotoText.sliderLabel(before: before.takenAt, after: after.takenAt, calendar: calendar)
    }

    /// « 50 % ».
    public var sliderSpokenValue: String {
        PulseFormat.integer(position * 100, unit: "%")
    }

    /// « 1er août ».
    public var beforeTag: String? {
        before.map { PhotoText.dayMonth($0.takenAt, calendar: calendar) }
    }

    /// « 28 octobre ».
    public var afterTag: String? {
        after.map { PhotoText.dayMonth($0.takenAt, calendar: calendar) }
    }

    /// « 13 semaines d'écart ».
    public var apartText: String? {
        guard let before, let after else { return nil }
        return PhotoText.weeksApart(from: before.takenAt, to: after.takenAt, calendar: calendar)
    }

    /// « 1er août 2026 » : une date proposée par « Changer les dates ».
    public func dateText(of photo: BodyPhoto) -> String {
        PhotoText.longDate(photo.takenAt, calendar: calendar)
    }

    /// « Photo de face, 1er août 2026 » : une photo de l'affichage côte à côte.
    public func spokenLabel(of photo: BodyPhoto) -> String {
        PhotoText.bodyPhotoLabel(pose: photo.pose, day: photo.takenAt, calendar: calendar)
    }

    /// « −1,4 kg » ; `nil` sans variation.
    public var weightText: String? {
        weightChange.map(PhotoText.signedKilos)
    }

    /// « Poids, tendance, moins 1,4 kilo ».
    public var weightSpoken: String? {
        weightChange.map(PhotoText.weightTrendSpoken)
    }

    private func resetPair() {
        let pair = BodyPhotoTimeline.defaultPair(pose: selectedPose, in: photos, calendar: calendar)
        before = pair?.before
        after = pair?.after
        weightChange = nil
    }
}
