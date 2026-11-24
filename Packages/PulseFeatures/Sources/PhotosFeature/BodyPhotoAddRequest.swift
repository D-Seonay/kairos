import Foundation
import PulseDomain
import PulseServices

/// Une demande d'ajout de photo de corps : la pose proposée et, depuis une case vide, le jour que cette case complète (spec V2b :
/// « Une case vide sert à compléter ce jour »). Depuis « + », la première pose qui manque aujourd'hui, sans jour imposé.
struct BodyPhotoAddRequest: Identifiable {
    let id = UUID()
    let pose: BodyPose
    /// Le début du jour de la case vide touchée ; `nil` depuis « + », la date vient alors de la photo.
    var day: Date?

    /// La date proposée pour une image traitée dont les métadonnées (ou l'heure de la prise) donnent `proposed` : celle-ci si
    /// elle tombe le jour demandé ou sans jour demandé, sinon le jour de la case. Elle reste modifiable dans la feuille.
    func takenAt(proposed: Date, calendar: Calendar) -> Date {
        guard let day, !calendar.isDate(proposed, inSameDayAs: day) else { return proposed }
        return day
    }

    /// La demande de « + » : la première pose, dans l'ordre face, profil, dos, qui manque encore aujourd'hui ; face quand les
    /// trois y sont déjà.
    static func next(in days: [BodyPhotoDay], today: Date, calendar: Calendar) -> BodyPhotoAddRequest {
        let taken = days.first { calendar.isDate($0.day, inSameDayAs: today) }?.photos ?? [:]
        let pose = BodyPose.allCases.first { taken[$0] == nil } ?? .front
        return BodyPhotoAddRequest(pose: pose)
    }
}
