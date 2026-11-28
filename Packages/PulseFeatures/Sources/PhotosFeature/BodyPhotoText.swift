import Foundation
import PulseDesignSystem
import PulseDomain
import PulseServices

/// Les textes des photos de corps, affichés et parlés : verrou, en-tête, ajout, comparaison et réglages.
extension PhotoText {
    // MARK: Verrou et en-tête

    static var bodyTitle: String { String(localized: "Photos de corps", bundle: .module) }
    static var unlockReason: String { String(localized: "Déverrouille tes photos de corps.", bundle: .module) }
    static var unlock: String { String(localized: "Déverrouiller", bundle: .module) }
    static var lockedTitle: String { String(localized: "Photos de corps verrouillées", bundle: .module) }
    static var unlocked: String { String(localized: "Photos de corps déverrouillées", bundle: .module) }
    static var bodyNotice: String {
        String(localized: "Sur cet iPhone seulement. Ni iCloud, ni sauvegarde. Exporte-les avant de changer de téléphone.",
               bundle: .module)
    }
    static var noPasscodeNotice: String {
        String(localized: "Sans code sur cet iPhone, ces photos ne sont ni chiffrées ni verrouillables.", bundle: .module)
    }

    // MARK: Liste

    /// « 1 photo », « 3 photos ».
    static func photoCount(_ count: Int) -> String {
        PulseSpoken.count(count, singular: String(localized: "photo", bundle: .module),
                          plural: String(localized: "photos", bundle: .module))
    }

    static var emptyBodyTitle: String { String(localized: "Aucune photo pour l'instant", bundle: .module) }
    static var emptyBodyNote: String {
        String(localized: "Ajoute une photo de face, de profil ou de dos pour suivre ta progression.", bundle: .module)
    }
    static var compare: String { String(localized: "Comparer avant / après", bundle: .module) }
    static var compareNeedsTwoDates: String {
        String(localized: "Pour comparer, il faut deux dates d'une même pose.", bundle: .module)
    }

    // MARK: Ajout

    static var addTip: String { String(localized: "Même lumière, même tenue, même distance.", bundle: .module) }
    static var pose: String { String(localized: "Pose", bundle: .module) }
    static var date: String { String(localized: "Date", bundle: .module) }
    static var save: String { String(localized: "Enregistrer", bundle: .module) }
    static var preparingPhoto: String { String(localized: "Préparation de la photo", bundle: .module) }
    static var replace: String { String(localized: "Remplacer", bundle: .module) }
    static var replaceMessage: String {
        String(localized: "Une seule photo par pose et par jour : l'ancienne est supprimée.", bundle: .module)
    }
    static var discardPhotoTitle: String { String(localized: "Abandonner cette photo ?", bundle: .module) }
    static var discardPhoto: String { String(localized: "Abandonner", bundle: .module) }
    static var keepPhoto: String { String(localized: "Garder la photo", bundle: .module) }

    /// « Remplacer la photo de face du 28 octobre ? ».
    static func replaceTitle(pose: BodyPose, day: Date, calendar: Calendar) -> String {
        let date = dayMonth(day, calendar: calendar)
        return switch pose {
        case .front: String(localized: "Remplacer la photo de face du \(date) ?", bundle: .module)
        case .side: String(localized: "Remplacer la photo de profil du \(date) ?", bundle: .module)
        case .back: String(localized: "Remplacer la photo de dos du \(date) ?", bundle: .module)
        }
    }

    // MARK: Visionneuse

    static var bodyDeleteMessage: String {
        String(localized: "La photo est effacée de cet iPhone. Il n'en reste aucune autre copie, sauf dans un export.",
               bundle: .module)
    }

    // MARK: Comparaison

    static var compareTitle: String { String(localized: "Comparer", bundle: .module) }
    static var sideBySide: String { String(localized: "Côte à côte", bundle: .module) }
    static var overlay: String { String(localized: "Superposer", bundle: .module) }
    static var changeDates: String { String(localized: "Changer les dates", bundle: .module) }
    static var before: String { String(localized: "Avant", bundle: .module) }
    static var after: String { String(localized: "Après", bundle: .module) }
    static var done: String { String(localized: "OK", bundle: .module) }
    static var weightTrend: String { String(localized: "Poids, tendance", bundle: .module) }
    static var noJudgement: String {
        String(localized: "Les variations sont affichées sans jugement : c'est toi qui décides de ce qui compte.", bundle: .module)
    }

    /// « Fais glisser pour comparer · 13 semaines d'écart ».
    static func dragToCompare(_ apart: String) -> String {
        String(localized: "Fais glisser pour comparer · \(apart)", bundle: .module)
    }

    /// « Avant, 1er août · Après, 28 octobre ».
    static func sliderLabel(before: Date, after: Date, calendar: Calendar) -> String {
        let first = dayMonth(before, calendar: calendar)
        let second = dayMonth(after, calendar: calendar)
        return String(localized: "Avant, \(first) · Après, \(second)", bundle: .module)
    }

    /// « −1,4 kg », « +1,3 kg », « 0 kg » : arrondi au dixième, signe moins U+2212.
    static func signedKilos(_ kilograms: Double) -> String {
        let units = PulseUnits.current
        let rounded = (units.displayedWeight(kilograms: kilograms) * 10).rounded() / 10
        let magnitude = PulseFormat.decimal(abs(rounded), maxFractionDigits: 1)
        let signed = rounded > 0 ? "+\(magnitude)" : rounded < 0 ? "\u{2212}\(magnitude)" : magnitude
        return "\(signed) \(units.weightSymbol)"
    }

    /// « Poids, tendance, moins 1,4 kilo », « …, plus 1,3 kilo », « …, 0 kilo ».
    static func weightTrendSpoken(_ kilograms: Double) -> String {
        let rounded = (kilograms * 10).rounded() / 10
        let amount = PulseSpoken.kilos(abs(rounded))
        let title = weightTrend
        if rounded > 0 { return String(localized: "\(title), plus \(amount)", bundle: .module) }
        if rounded < 0 { return String(localized: "\(title), moins \(amount)", bundle: .module) }
        return String(localized: "\(title), \(amount)", bundle: .module)
    }

    // MARK: Réglages

    static var settingsTitle: String { String(localized: "Réglages", bundle: .module) }
    static var lockWithFaceID: String { String(localized: "Verrouiller avec Face ID", bundle: .module) }
    static var lockNeedsPasscode: String {
        String(localized: "Le verrou demande un code sur cet iPhone.", bundle: .module)
    }
    static var reminderTitle: String { String(localized: "Rappel de photo", bundle: .module) }
    /// « Désactivé », « Toutes les 2 semaines », « Tous les mois ».
    static func reminderInterval(_ interval: BodyPhotoReminderInterval) -> String {
        switch interval {
        case .off: String(localized: "Désactivé", bundle: .module)
        case .everyTwoWeeks: String(localized: "Toutes les 2 semaines", bundle: .module)
        case .monthly: String(localized: "Tous les mois", bundle: .module)
        }
    }
    static var reminderNote: String {
        String(localized: "Une notification à 9 h, sans image ni mot sur le sujet. Chaque nouvelle photo repousse la suivante.",
               bundle: .module)
    }
    static var reminderNotificationsOff: String {
        String(localized: "Les notifications de Pulse sont coupées dans les réglages d'iOS : le rappel n'apparaîtra pas.",
               bundle: .module)
    }
    static var export: String { String(localized: "Exporter les photos de corps", bundle: .module) }
    static var exportNote: String {
        String(localized: "Une archive enregistrée dans Fichiers, à l'emplacement que tu choisis.", bundle: .module)
    }
    static var deleteAll: String { String(localized: "Supprimer toutes les photos de corps", bundle: .module) }
    static var deleteAllTitle: String { String(localized: "Supprimer toutes les photos de corps ?", bundle: .module) }
    static var deleteAllConfirm: String { String(localized: "Tout supprimer", bundle: .module) }
    static var deleteAllMessage: String {
        String(localized: "Elles sont effacées de cet iPhone. Sans export, elles sont perdues.", bundle: .module)
    }
    static var allDeleted: String { String(localized: "Photos de corps supprimées", bundle: .module) }
    static var exportFailed: String { String(localized: "L'export n'a pas pu être préparé.", bundle: .module) }
    static var exportSaveFailed: String { String(localized: "L'export n'a pas pu être enregistré.", bundle: .module) }
    static var deleteAllFailed: String {
        String(localized: "Les photos de corps n'ont pas pu être supprimées.", bundle: .module)
    }
}
