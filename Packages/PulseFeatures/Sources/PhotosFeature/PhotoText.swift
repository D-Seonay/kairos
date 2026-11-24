import Foundation
import PulseDesignSystem
import PulseDomain

/// Les textes des photos, affichés et parlés. Des fonctions pures, testées. Les dates sont en français (« 1er août 2026 »,
/// « 18 h 42 »), dans le calendrier donné.
public enum PhotoText {
    // MARK: Libellés parlés

    /// « Photo 2 sur 4, ajoutée à 18 h 42 ». `index` est le rang de la photo à partir de 1, `count` leur nombre.
    static func sessionPhotoLabel(index: Int, count: Int, addedAt: Date, calendar: Calendar) -> String {
        let time = formatted(addedAt, calendar: calendar, format: "H 'h' mm")
        return String(localized: "Photo \(index) sur \(count), ajoutée à \(time)", bundle: .module)
    }

    /// « Photo de face, 1er août 2026 », « Photo de profil, … », « Photo de dos, … ».
    static func bodyPhotoLabel(pose: BodyPose, day: Date, calendar: Calendar) -> String {
        let date = longDate(day, calendar: calendar)
        return switch pose {
        case .front: String(localized: "Photo de face, \(date)", bundle: .module)
        case .side: String(localized: "Photo de profil, \(date)", bundle: .module)
        case .back: String(localized: "Photo de dos, \(date)", bundle: .module)
        }
    }

    /// « Ajouter une photo de face », « … de profil », « … de dos » : la case d'une pose sans photo.
    static func emptyPoseLabel(_ pose: BodyPose) -> String {
        switch pose {
        case .front: String(localized: "Ajouter une photo de face", bundle: .module)
        case .side: String(localized: "Ajouter une photo de profil", bundle: .module)
        case .back: String(localized: "Ajouter une photo de dos", bundle: .module)
        }
    }

    /// « Face », « Profil », « Dos ».
    static func poseName(_ pose: BodyPose) -> String {
        switch pose {
        case .front: String(localized: "Face", bundle: .module)
        case .side: String(localized: "Profil", bundle: .module)
        case .back: String(localized: "Dos", bundle: .module)
        }
    }

    /// Le bouton de la séance live : « Ajouter une photo », « Ajouter une photo, 3 photos dans la séance ».
    static func liveButtonLabel(count: Int) -> String {
        guard count > 0 else { return addPhoto }
        let photos = PulseSpoken.count(count, singular: String(localized: "photo", bundle: .module),
                                       plural: String(localized: "photos", bundle: .module))
        return String(localized: "Ajouter une photo, \(photos) dans la séance", bundle: .module)
    }

    // MARK: Écarts et dates

    /// « 13 semaines d'écart » ; sous 2 semaines, en jours : « 9 jours d'écart », « 7 jours d'écart », « 1 jour d'écart ».
    /// L'écart se compte en jours de calendrier, sans égard au sens ni à l'heure.
    static func weeksApart(from: Date, to: Date, calendar: Calendar) -> String {
        let days = dayCount(from: from, to: to, calendar: calendar)
        return String(localized: "\(duration(days: days)) d'écart", bundle: .module)
    }

    /// « Dernière prise aujourd'hui », « … hier », « … il y a 5 jours » (moins de 14 jours), « … il y a 4 semaines ».
    static func lastShot(_ day: Date, now: Date, calendar: Calendar) -> String {
        let days = max(0, dayCount(from: day, to: now, calendar: calendar))
        switch days {
        case 0: return String(localized: "Dernière prise aujourd'hui", bundle: .module)
        case 1: return String(localized: "Dernière prise hier", bundle: .module)
        default:
            let elapsed = days < 14 ? daysText(days) : weeksText(days / 7)
            return String(localized: "Dernière prise il y a \(elapsed)", bundle: .module)
        }
    }

    /// Les jours entre deux dates (la valeur absolue), au jour de calendrier près.
    private static func dayCount(from: Date, to: Date, calendar: Calendar) -> Int {
        let start = calendar.startOfDay(for: from)
        let end = calendar.startOfDay(for: to)
        return abs(calendar.dateComponents([.day], from: start, to: end).day ?? 0)
    }

    private static func duration(days: Int) -> String {
        days >= 14 ? weeksText(days / 7) : daysText(days)
    }

    private static func daysText(_ count: Int) -> String {
        PulseSpoken.count(count, singular: String(localized: "jour", bundle: .module),
                          plural: String(localized: "jours", bundle: .module))
    }

    private static func weeksText(_ count: Int) -> String {
        PulseSpoken.count(count, singular: String(localized: "semaine", bundle: .module),
                          plural: String(localized: "semaines", bundle: .module))
    }

    /// « 1er août 2026 », « 28 octobre 2026 » : le premier du mois est un ordinal.
    static func longDate(_ date: Date, calendar: Calendar) -> String {
        let day = calendar.component(.day, from: date)
        let monthAndYear = formatted(date, calendar: calendar, format: "MMMM yyyy")
        return day == 1 ? "1er \(monthAndYear)" : "\(day) \(monthAndYear)"
    }

    private static func formatted(_ date: Date, calendar: Calendar, format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    // MARK: Section de séance

    static var sectionTitle: String { String(localized: "Photos", bundle: .module) }

    /// « privées · 6 au maximum ».
    static var sectionNote: String {
        String(localized: "privées · \(SessionPhoto.maxPerSession) au maximum", bundle: .module)
    }

    static var addPhoto: String { String(localized: "Ajouter une photo", bundle: .module) }
    static var addShort: String { String(localized: "Ajouter", bundle: .module) }
    static var takePhoto: String { String(localized: "Prendre une photo", bundle: .module) }
    static var chooseFromLibrary: String { String(localized: "Choisir dans Photos", bundle: .module) }
    static var allowCamera: String { String(localized: "Autoriser l'appareil photo dans Réglages", bundle: .module) }
    static var cameraDeniedNote: String {
        String(localized: "L'appareil photo est refusé. Autorise-le dans Réglages ; l'import depuis Photos reste possible.",
               bundle: .module)
    }
    static var addingPhoto: String { String(localized: "Ajout de la photo en cours", bundle: .module) }

    // MARK: Annonces et erreurs

    static var photoAdded: String { String(localized: "Photo ajoutée", bundle: .module) }
    static var photoDeleted: String { String(localized: "Photo supprimée", bundle: .module) }

    static func photosAdded(_ count: Int) -> String {
        count == 1 ? photoAdded : String(localized: "\(count) photos ajoutées", bundle: .module)
    }

    /// « 6 photos au maximum par séance : 2 n'ont pas été ajoutées. »
    static func overLimit(dropped: Int) -> String {
        let maximum = SessionPhoto.maxPerSession
        return dropped == 1
            ? String(localized: "\(maximum) photos au maximum par séance : \(dropped) n'a pas été ajoutée.", bundle: .module)
            : String(localized: "\(maximum) photos au maximum par séance : \(dropped) n'ont pas été ajoutées.", bundle: .module)
    }

    static var unreadableImage: String { String(localized: "Une image n'a pas pu être lue.", bundle: .module) }
    static var unreadableImages: String { String(localized: "Des images n'ont pas pu être lues.", bundle: .module) }
    static var addFailed: String { String(localized: "La photo n'a pas pu être ajoutée.", bundle: .module) }
    static var loadFailed: String { String(localized: "Les photos n'ont pas pu être chargées.", bundle: .module) }
    static var imageUnavailable: String { String(localized: "La photo n'a pas pu être ouverte.", bundle: .module) }
    static var deleteFailed: String { String(localized: "La photo n'a pas pu être supprimée.", bundle: .module) }

    // MARK: Visionneuse

    static var share: String { String(localized: "Partager", bundle: .module) }
    static var delete: String { String(localized: "Supprimer", bundle: .module) }
    static var cancel: String { String(localized: "Annuler", bundle: .module) }
    static var close: String { String(localized: "Fermer", bundle: .module) }
    static var deleteTitle: String { String(localized: "Supprimer cette photo ?", bundle: .module) }
    static var openPhotoHint: String { String(localized: "Ouvre la photo en plein écran", bundle: .module) }
    static var deleteMessage: String {
        String(localized: "La photo est supprimée de Pulse. L'original dans Photos, s'il existe, reste en place.", bundle: .module)
    }
}
