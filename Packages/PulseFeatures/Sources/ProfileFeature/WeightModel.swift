import Foundation
import Observation
import PulseDesignSystem
import PulseDomain
import PulseServices

/// La pesée ouverte dans la feuille : une nouvelle (`measurementID` nul) ou une saisie manuelle à modifier.
public struct WeighInDraft: Identifiable, Equatable {
    public let id: UUID
    public var measurementID: UUID?
    /// Le poids tapé, virgule ou point.
    public var weightText: String
    public var date: Date

    public init(id: UUID = UUID(), measurementID: UUID? = nil, weightText: String = "", date: Date) {
        self.id = id
        self.measurementID = measurementID
        self.weightText = weightText
        self.date = date
    }

    /// Le poids tapé en kilos : « 78,4 » ou « 78.4 », espaces autour ignorés ; `nil` vide ou illisible.
    var weightKg: Double? {
        let text = weightText.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard !text.isEmpty, text.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == ".") }),
              let value = Double(text), value.isFinite else { return nil }
        return value
    }
}

/// L'état de l'écran Poids (spec M7 §14) : la tendance, les mesures de l'année et la feuille de pesée. Toutes les écritures
/// passent par `BodyService` ; après chacune, `onChanged` recharge la page Profil.
@MainActor
@Observable
public final class WeightModel {
    public private(set) var overview: BodyOverview?
    /// Les erreurs de l'écran : lecture, suppression.
    public private(set) var errorMessage: String?
    /// Un échec de l'écran de plus (lecture, suppression) : la même erreur revue est annoncée à nouveau.
    public private(set) var failureCount = 0
    /// Un échec de la feuille de plus : le poids refusé deux fois de suite est annoncé deux fois.
    public private(set) var editorFailureCount = 0
    /// Les erreurs de la feuille (poids refusé, date à venir, écriture ratée), affichées dans la feuille.
    public private(set) var editorError: String?
    public private(set) var hasLoaded = false
    public private(set) var isSaving = false
    public var editor: WeighInDraft?

    @ObservationIgnored let environment: ProfileEnvironment
    @ObservationIgnored private let onChanged: @MainActor () async -> Void

    public init(environment: ProfileEnvironment, onChanged: @escaping @MainActor () async -> Void) {
        self.environment = environment
        self.onChanged = onChanged
    }

    /// « Entre un poids entre 20 et 400 kilos. »
    static var invalidWeightMessage: String {
        String(localized: "Entre un poids entre 20 et 400 kilos.", bundle: .module)
    }

    /// Relit les pesées. Une lecture qui échoue garde l'affichage précédent et le dit.
    public func load() async {
        do {
            overview = try await environment.body.overview()
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu lire tes pesées.", bundle: .module)
            failureCount += 1
        }
        hasLoaded = true
    }

    /// Ouvre la feuille sur une pesée vide, datée de maintenant.
    public func startNew() {
        editorError = nil
        editor = WeighInDraft(date: environment.now())
    }

    /// Ouvre la feuille sur une saisie manuelle ; une mesure Apple Santé ne se modifie pas.
    public func edit(_ measurement: BodyMeasurement) {
        guard measurement.source == .manual, let weight = measurement.weightKg else { return }
        editorError = nil
        editor = WeighInDraft(measurementID: measurement.id, weightText: PulseFormat.decimal(weight, maxFractionDigits: 2),
                              date: measurement.date)
    }

    /// Ferme la feuille sans enregistrer ; son message part avec elle.
    public func closeEditor() {
        editor = nil
        editorError = nil
    }

    /// La feuille a fini de disparaître (« Annuler », balayage, enregistrement) : son message part, sauf si une nouvelle pesée
    /// s'est ouverte pendant l'animation.
    public func editorDismissed() {
        if editor == nil { editorError = nil }
    }

    /// Enregistre la feuille. Un poids hors de 20 à 400 kg (ou illisible), une date à venir ou une écriture ratée gardent la
    /// feuille ouverte avec son message.
    public func save() async {
        guard let draft = editor, !isSaving else { return }
        guard let weight = draft.weightKg, BodyService.weightRange.contains(weight) else {
            failEditor(Self.invalidWeightMessage)
            return
        }
        guard draft.date <= environment.now() else {
            failEditor(String(localized: "Choisis une date passée.", bundle: .module))
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            if let id = draft.measurementID {
                guard var measurement = overview?.measurements.first(where: { $0.id == id }) else {
                    throw BodyServiceError.notManual
                }
                measurement.weightKg = weight
                measurement.date = draft.date
                try await environment.body.updateManual(measurement)
            } else {
                try await environment.body.addManual(weightKg: weight, date: draft.date)
            }
        } catch BodyServiceError.invalidWeight {
            failEditor(Self.invalidWeightMessage)
            return
        } catch {
            failEditor(String(localized: "Pulse n'a pas pu enregistrer ta pesée.", bundle: .module))
            return
        }
        editorError = nil
        editor = nil
        await load()
        await onChanged()
    }

    /// Supprime une saisie manuelle ; une mesure Apple Santé reste (c'est Apple Santé qui l'efface).
    public func delete(_ measurement: BodyMeasurement) async {
        guard measurement.source == .manual else { return }
        do {
            try await environment.body.deleteManual(id: measurement.id)
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu supprimer la pesée.", bundle: .module)
            failureCount += 1
            return
        }
        await load()
        await onChanged()
    }

    private func failEditor(_ message: String) {
        editorError = message
        editorFailureCount += 1
    }
}
