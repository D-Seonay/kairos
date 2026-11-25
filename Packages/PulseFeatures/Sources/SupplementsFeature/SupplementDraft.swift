import Foundation
import PulseDomain
import PulseServices

/// Le formulaire d'un complément (spec M5 §10), avant enregistrement. Une suggestion préremplit tout sauf la dose.
public struct SupplementDraft: Sendable, Equatable {
    public var name = ""
    public var form: SupplementForm = .capsule
    public var dose: Double?
    public var unit: DoseUnit = .mg
    public var timing: SupplementTiming = .fixedTime
    /// L'heure d'une prise à heure fixe ou au coucher, en minutes après minuit.
    public var minutes = 8 * 60
    /// « Suivre mes nuits » d'une prise au coucher : l'heure vient des nuits d'Apple Santé quand il y en a assez, sinon de
    /// `minutes`. Proposé par défaut pour un nouveau complément au coucher.
    public var followsNights = true
    public var days: SupplementDays = .everyDay
    public var weekdays: Set<Weekday> = []
    public var reminder = true
    public var healthType: SupplementHealthType?
    public var stock: Double?
    public var threshold: Double?
    /// La suggestion choisie, pour la mettre en avant dans les pastilles.
    public var suggestionID: String?

    static let defaultBedtimeMinutes = 22 * 60 + 30

    public init() {}

    /// `followsNights` : le réglage « Suivre mes nuits » de cet appareil pour ce complément.
    public init(_ supplement: Supplement, followsNights: Bool = false) {
        name = supplement.name
        form = supplement.form
        dose = supplement.dose
        unit = supplement.unit
        timing = supplement.timing
        minutes = supplement.timeOfDayMinutes ?? (supplement.timing == .bedtime ? Self.defaultBedtimeMinutes : 8 * 60)
        self.followsNights = supplement.timing == .bedtime && followsNights
        days = supplement.days
        weekdays = Set(supplement.customWeekdays)
        reminder = supplement.reminderEnabled
        healthType = supplement.healthType
        stock = supplement.stockDoses
        threshold = supplement.lowStockThreshold
    }

    /// Préremplit depuis une suggestion ; la dose saisie reste, Pulse n'en propose jamais.
    public mutating func apply(_ suggestion: SupplementSuggestion) {
        suggestionID = suggestion.id
        name = suggestion.name
        form = suggestion.form
        unit = suggestion.unit
        timing = suggestion.timing
        if let time = suggestion.timeOfDayMinutes { minutes = time }
        days = suggestion.days
        healthType = suggestion.healthType
    }

    /// Le moment change : l'heure d'un coucher repart de 22:30 et propose de suivre les nuits, celle d'une heure fixe de 8:00.
    public mutating func setTiming(_ timing: SupplementTiming) {
        guard timing != self.timing else { return }
        if timing == .bedtime && self.timing != .bedtime {
            minutes = Self.defaultBedtimeMinutes
            followsNights = true
        }
        if timing == .fixedTime && self.timing == .bedtime { minutes = 8 * 60 }
        self.timing = timing
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Ce qui manque pour enregistrer ; `nil` quand le formulaire est complet.
    public var problem: String? {
        if trimmedName.isEmpty { return String(localized: "Donne un nom au complément.", bundle: .module) }
        guard let dose, dose > 0 else { return String(localized: "Indique ta dose par prise.", bundle: .module) }
        if days == .custom && weekdays.isEmpty { return String(localized: "Choisis au moins un jour.", bundle: .module) }
        return nil
    }

    var usesTime: Bool {
        timing == .fixedTime || timing == .bedtime
    }

    /// « Suivre mes nuits » tel qu'il sera enregistré : seulement pour une prise au coucher.
    public var savesFollowingNights: Bool {
        timing == .bedtime && followsNights
    }

    /// Le sélecteur d'heure est utile : heure fixe, coucher à heure fixe, ou coucher qui suit des nuits encore trop rares
    /// (`habitualBedtime` nul) et garde donc son heure.
    func showsTimePicker(habitualBedtime: Int?) -> Bool {
        usesTime && !(savesFollowingNights && habitualBedtime != nil)
    }

    /// Ce qui sera écrit dans Apple Santé à chaque prise, ou pourquoi rien ne le sera ; `nil` sans type.
    public var healthNote: String? {
        guard let healthType else { return nil }
        guard let dose, dose > 0 else {
            return String(localized: "Chaque prise sera écrite dans Apple Santé.", bundle: .module)
        }
        guard let amount = SupplementHealthDose.amount(dose: dose, unit: unit, type: healthType) else {
            return String(localized: "Avec cette unité, Pulse ne peut pas écrire la quantité dans Apple Santé.", bundle: .module)
        }
        let unit: DoseUnit = switch healthType {
        case .vitaminD: .microgram
        case .magnesium, .caffeine: .mg
        case .protein: .gram
        }
        let quantity = SupplementText.dose(amount, unit: unit)
        return String(localized: "Écrit dans Apple Santé : \(quantity) par prise.", bundle: .module)
    }

    /// Le complément enregistré : `existing` garde son identifiant, son ordre, sa création et son archivage.
    public func supplement(existing: Supplement?, order: Int, now: Date) -> Supplement {
        Supplement(id: existing?.id ?? UUID(), name: trimmedName, form: form, dose: dose ?? 0, unit: unit, timing: timing,
                   timeOfDayMinutes: usesTime ? minutes : nil, days: days,
                   customWeekdays: days == .custom ? Weekday.allCases.filter(weekdays.contains) : [],
                   stockDoses: stock.map { max(0, $0) }, lowStockThreshold: stock == nil ? nil : threshold.map { max(0, $0) },
                   reminderEnabled: reminder, healthKitType: healthType?.rawValue, isArchived: existing?.isArchived ?? false,
                   order: existing?.order ?? order, createdAt: existing?.createdAt ?? now, updatedAt: now)
    }
}
