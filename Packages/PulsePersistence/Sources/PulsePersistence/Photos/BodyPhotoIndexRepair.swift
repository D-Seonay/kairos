import Foundation
import PulseDomain

/// Les entrées des images de corps retrouvées sans entrée lisible quand l'index abîmé est reconstruit. Leur pose est perdue ;
/// leur date l'est aussi, sauf celle du fichier. Le but : que chaque image reste visible dans la frise (une photo par pose et par
/// jour) et qu'aucun remplacement ne puisse viser une image que l'utilisateur ne voit pas.
enum BodyPhotoIndexRepair {
    /// Une image retrouvée : son identifiant et la date de son fichier (création, sinon modification), si elle se lit.
    struct Image: Equatable {
        var id: UUID
        var fileDate: Date?
    }

    /// - Une image datée garde la date de son fichier (le jour de son enregistrement) et prend, ce jour-là, la première pose
    ///   encore libre dans l'ordre face, profil, dos, en partant de la plus ancienne : l'ordre habituel d'une prise.
    ///   En dernier recours, un jour qui a déjà ses trois poses lui donne face, profil, dos tour à tour ; la frise peut alors en
    ///   cacher une, que l'export et « Tout supprimer » gardent.
    /// - Une image sans date lisible reçoit un jour à elle, en reculant depuis la veille de la reconstruction et en sautant les
    ///   jours qui ont déjà une photo : elle ne partage ni son jour ni sa pose avec aucune autre.
    static func entries(for images: [Image], existing: [BodyPhoto], now: Date, calendar: Calendar) -> [BodyPhoto] {
        var photos = existing
        var added: [BodyPhoto] = []
        let dated = images.compactMap { image in image.fileDate.map { (id: image.id, date: $0) } }
            .sorted { ($0.date, $0.id.uuidString) < ($1.date, $1.id.uuidString) }
        for image in dated {
            let taken = photos.filter { calendar.isDate($0.takenAt, inSameDayAs: image.date) }.map(\.pose)
            let pose = BodyPose.allCases.first { !taken.contains($0) }
                ?? BodyPose.allCases[taken.count % BodyPose.allCases.count]
            let photo = BodyPhoto(id: image.id, pose: pose, takenAt: image.date, createdAt: image.date)
            photos.append(photo)
            added.append(photo)
        }
        let undated = images.filter { $0.fileDate == nil }.sorted { $0.id.uuidString < $1.id.uuidString }
        var day = calendar.startOfDay(for: now)
        for image in undated {
            repeat {
                day = calendar.date(byAdding: .day, value: -1, to: day) ?? day.addingTimeInterval(-86_400)
            } while photos.contains { calendar.isDate($0.takenAt, inSameDayAs: day) }
            let noon = calendar.date(byAdding: .hour, value: 12, to: day) ?? day
            let photo = BodyPhoto(id: image.id, pose: .front, takenAt: noon, createdAt: now)
            photos.append(photo)
            added.append(photo)
        }
        return added
    }
}
