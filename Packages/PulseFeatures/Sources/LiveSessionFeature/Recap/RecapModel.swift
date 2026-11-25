import Foundation
import Observation
import PhotosFeature
import PulseDomain
import PulseServices
import SupplementsFeature

/// L'état du récap de fin de séance (spec M4 §17) : le bilan lu du service, le RPE global pré-placé sur la moyenne des RPE de
/// série, la note, et les deux sorties « Enregistrer » et « Enregistrer sans noter ». Une erreur laisse le récap ouvert : on
/// peut réessayer. La première fois, l'enregistrement passe par l'écran d'explication d'Apple Santé, puis la demande système
/// (spec M4 §19.5).
@MainActor
@Observable
public final class RecapModel {
    public private(set) var recap: SessionRecap?
    /// De 1 à 10 ; pré-placé sur `suggestedRPE` au chargement du bilan.
    public var rpe: Int
    public var note = ""
    public private(set) var errorMessage: String?
    public private(set) var isSaving = false
    /// Ce que Pulse peut écrire dans Apple Santé, lu avec le bilan.
    public private(set) var healthAccess: HealthWriteAccess = .unavailable
    /// L'écran d'explication d'Apple Santé est ouvert : la séance s'enregistre après lui.
    public private(set) var isExplainingHealth = false
    /// Les compléments « autour de la séance » à cocher (spec M5 §10) ; `nil` pour une séance saisie après coup.
    public let supplements: SupplementsModel?
    /// La section Photos : le modèle de la séance live, pour que les photos prises pendant la séance y soient ; `nil` sans service
    /// des photos et pour une saisie après coup.
    public let photos: SessionPhotosModel?
    /// Vrai une fois la séance enregistrée quand la règle demande une note : la vue appelle alors `requestReview`.
    public private(set) var shouldRequestReview = false

    /// La même échelle que la correction d'une séance enregistrée.
    public static let rpeRange = RoutineRules.overallRPE
    /// Le RPE avant que le bilan, qui le suggère, soit lu.
    private static let initialRPE = 7

    @ObservationIgnored private let service: ActiveSessionService
    @ObservationIgnored private let reviewPrompt: ReviewPrompt?
    @ObservationIgnored private let endedAt: Date
    @ObservationIgnored private var isSaved = false
    /// Le RPE à enregistrer une fois l'écran d'explication passé.
    @ObservationIgnored private var pendingRPE: Int?

    /// `reviewPrompt` : la demande de note après l'enregistrement ; `nil` pour ne jamais en faire (saisie après coup, tests).
    public init(service: ActiveSessionService, endedAt: Date, supplements: SupplementsModel? = nil,
                photos: SessionPhotosModel? = nil, reviewPrompt: ReviewPrompt? = nil) {
        self.service = service
        self.reviewPrompt = reviewPrompt
        self.endedAt = endedAt
        self.supplements = supplements
        self.photos = photos
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
            healthAccess = await service.healthAccess()
            errorMessage = nil
            await supplements?.load()
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu préparer le récap de la séance.", bundle: .module)
        }
    }

    /// « Enregistrer » : la séance avec le RPE choisi et la note. Vrai quand elle est enregistrée (ou l'était déjà) ; faux sur
    /// une erreur, que le récap affiche et qu'un nouvel appel retente sans doublon, ou quand l'écran d'explication d'Apple
    /// Santé s'ouvre d'abord.
    public func save() async -> Bool {
        await finishOrExplain(overallRPE: rpe)
    }

    /// « Enregistrer sans noter » : la séance avec le RPE pré-placé, pas celui du curseur, et la note déjà saisie.
    public func later() async -> Bool {
        await finishOrExplain(overallRPE: recap?.suggestedRPE ?? Self.initialRPE)
    }

    /// « Continuer » de l'écran d'explication : la demande système, puis l'enregistrement, écrit dans Apple Santé si c'est
    /// permis. Vrai quand la séance est enregistrée.
    public func continueAfterHealthExplanation() async -> Bool {
        guard let overallRPE = pendingRPE else { return false }
        isExplainingHealth = false
        pendingRPE = nil
        healthAccess = await service.requestHealthAccess()
        return await finish(overallRPE: overallRPE)
    }

    /// L'écran d'explication se ferme sans « Continuer » : rien n'est enregistré, le récap reste ouvert.
    public func cancelHealthExplanation() {
        isExplainingHealth = false
        pendingRPE = nil
    }

    private func finishOrExplain(overallRPE: Int) async -> Bool {
        guard !isSaved, healthAccess == .notDetermined else { return await finish(overallRPE: overallRPE) }
        pendingRPE = overallRPE
        isExplainingHealth = true
        return false
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
            await claimReview()
            return true
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu enregistrer la séance. Elle est gardée : tu peux réessayer.",
                                  bundle: .module)
            return false
        }
    }
}

extension RecapModel {
    /// Une fois la séance écrite : la 5e séance terminée au moins, ou un record battu, et pas encore de demande pour cette
    /// version (`ReviewRequestRule`).
    private func claimReview() async {
        guard let reviewPrompt, let recap else { return }
        let service = service
        shouldRequestReview = await reviewPrompt.claim(hasNewRecord: !recap.beatenRecords.isEmpty) {
            await service.completedSessionCount()
        }
    }

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
