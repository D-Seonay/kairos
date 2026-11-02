import Foundation
import Observation
import PulseServices

/// L'état du récap de fin de séance (spec M4 §17) : le bilan lu du service, le RPE global pré-placé sur la moyenne des RPE de
/// série, la note, et les deux sorties « Enregistrer » et « Plus tard ». Une erreur laisse le récap ouvert : on peut réessayer.
@MainActor
@Observable
public final class RecapModel {
    public private(set) var recap: SessionRecap?
    /// De 1 à 10 ; pré-placé sur `suggestedRPE` au chargement du bilan.
    public var rpe: Int
    public var note = ""
    public private(set) var errorMessage: String?
    public private(set) var isSaving = false

    public static let rpeRange = 1...10
    /// Le RPE avant que le bilan, qui le suggère, soit lu.
    private static let initialRPE = 7

    @ObservationIgnored private let service: ActiveSessionService
    @ObservationIgnored private let endedAt: Date
    @ObservationIgnored private var isSaved = false

    public init(service: ActiveSessionService, endedAt: Date) {
        self.service = service
        self.endedAt = endedAt
        rpe = Self.initialRPE
    }

    /// La phrase de charge pour le RPE choisi : « Charge de la séance : 55 min × 7 = 385. » et le ratio d'après la séance.
    public var loadSentence: String {
        recap?.loadSentence(rpe: rpe) ?? ""
    }

    /// « 7 · dur » : le RPE et son libellé, de « très facile » à « maximal ».
    public var effortText: String {
        "\(rpe) · \(Self.effortWord(rpe))"
    }

    /// « 7 sur 10, dur », pour VoiceOver.
    public var effortSpokenText: String {
        String(localized: "\(rpe) sur 10, \(Self.effortWord(rpe))", bundle: .module)
    }

    /// Lit le bilan, et place le RPE sur sa valeur suggérée. Un échec s'affiche et se retente par le même appel.
    public func load() async {
        do {
            let recap = try await service.recap(endedAt: endedAt)
            self.recap = recap
            rpe = recap.suggestedRPE
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu préparer le récap de la séance.", bundle: .module)
        }
    }

    /// « Enregistrer » : la séance avec le RPE choisi et la note. Vrai quand elle est enregistrée (ou l'était déjà) ; faux sur
    /// une erreur, que le récap affiche et qu'un nouvel appel retente sans doublon.
    public func save() async -> Bool {
        await finish(overallRPE: rpe)
    }

    /// « Plus tard » : la séance avec le RPE pré-placé, pas celui du curseur, et la note déjà saisie.
    public func later() async -> Bool {
        await finish(overallRPE: recap?.suggestedRPE ?? Self.initialRPE)
    }

    private func finish(overallRPE: Int) async -> Bool {
        if isSaved { return true }
        guard !isSaving else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await service.finish(overallRPE: overallRPE, note: note, endedAt: endedAt)
            isSaved = true
            errorMessage = nil
            return true
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu enregistrer la séance. Elle est gardée : tu peux réessayer.",
                                  bundle: .module)
            return false
        }
    }
}

extension RecapModel {
    /// Le libellé d'un RPE global : 1 « très facile », 10 « maximal ».
    nonisolated static func effortWord(_ rpe: Int) -> String {
        switch rpe {
        case ..<2: String(localized: "très facile", bundle: .module)
        case 2...3: String(localized: "facile", bundle: .module)
        case 4...5: String(localized: "modéré", bundle: .module)
        case 6: String(localized: "soutenu", bundle: .module)
        case 7: String(localized: "dur", bundle: .module)
        case 8: String(localized: "très dur", bundle: .module)
        case 9: String(localized: "presque maximal", bundle: .module)
        default: String(localized: "maximal", bundle: .module)
        }
    }
}
