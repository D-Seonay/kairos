import CheckInFeature
import Foundation
import Observation
import PulseDomain
import PulseServices

/// L'état de l'onglet « Aujourd'hui » : salutation, score du jour et ses facteurs, carte de la séance du jour,
/// check-in si les données manquent. Toutes les lectures et écritures passent par le rafraîchisseur du jour.
@MainActor
@Observable
public final class TodayModel {
    public private(set) var greeting: String
    public private(set) var dateText: String
    public private(set) var lastSync: Date?
    public private(set) var score: TodayScore?
    public private(set) var factors: [FactorDisplay] = []
    public private(set) var marker: String?
    public private(set) var session: TodaySession?
    private(set) var card: SessionCardState = .noProgram
    /// La feuille ouverte depuis la carte de la séance : séance à suivre en salle, ou mobilité.
    public var sheet: TodaySheet?
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?
    public let checkIn = CheckInForm()

    @ObservationIgnored let environment: TodayEnvironment
    @ObservationIgnored private var isSubmittingCheckIn = false
    /// Change à chaque écriture du score (check-in, choix de la séance) : une lecture commencée avant elle n'écrase pas
    /// le score qu'elle a produit. Le rafraîchisseur sérialisant ses opérations, la garde ne sert qu'en défense.
    @ObservationIgnored private var scoreEpoch = 0
    /// Le jour de la dernière actualisation : un jour de plus et le formulaire du check-in repart de zéro.
    @ObservationIgnored private var lastRefreshDay: Date?

    public init(environment: TodayEnvironment) {
        self.environment = environment
        greeting = Self.greeting(firstName: nil)
        dateText = Self.dateText(environment.now(), calendar: environment.calendar)
    }

    /// L'heure de la dernière lecture d'Apple Santé réussie, « 08:00 ».
    public var lastSyncText: String? {
        lastSync.map { Self.timeText($0, calendar: environment.calendar) }
    }

    /// Relit le profil, le programme actif et Apple Santé, recalcule le score et la séance. Un appel pendant une lecture
    /// est ignoré : l'activation de la scène ne peut pas courir contre une actualisation manuelle.
    public func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        let now = environment.now()
        let epoch = scoreEpoch
        dateText = Self.dateText(now, calendar: environment.calendar)
        resetCheckInOnNewDay(now)

        let day = await environment.refresher.refresh(origin: .foreground)
        greeting = Self.greeting(firstName: day.profile?.firstName)
        if let readAt = day.readAt {
            lastSync = readAt
        }
        guard epoch == scoreEpoch else { return }
        if let updated = day.score {
            apply(updated)
            show(day.session)
        } else {
            // Le calcul a échoué : le score affiché reste, la séance suit le programme relu.
            show(TodaySession(plannedDay: day.plannedDay, recovery: scoredToday))
        }
    }

    /// Enregistre les réponses du check-in. Sans effet hors du cas « check-in à faire », avec des réponses incomplètes
    /// ou pendant un enregistrement déjà en cours.
    public func submitCheckIn() async {
        guard !isSubmittingCheckIn, case .needsCheckIn = score, let answers = checkIn.answers else { return }
        isSubmittingCheckIn = true
        defer { isSubmittingCheckIn = false }
        do {
            let estimated = try await environment.refresher.saveCheckIn(answers)
            errorMessage = nil
            checkIn.selection = [:]
            applyWritten(estimated)
        } catch DailyScoreError.alreadyMeasured {
            // Un score mesuré est arrivé entre-temps : il remplace le check-in, l'accueil se relit.
            errorMessage = nil
            await refresh()
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu enregistrer ton check-in.", bundle: .module)
        }
    }

    // MARK: - Interne

    /// Affiche un score que l'accueil vient d'écrire, et la séance qu'il ajuste.
    func applyWritten(_ recovery: DailyRecovery) {
        scoreEpoch += 1
        apply(.scored(recovery))
        show(TodaySession(plannedDay: session?.plannedDay ?? .noProgram, recovery: recovery))
    }

    private var scoredToday: DailyRecovery? {
        if case .scored(let recovery) = score { recovery } else { nil }
    }

    private func show(_ session: TodaySession) {
        self.session = session
        card = SessionCardState.make(session: session, score: score, library: environment.library)
    }

    private func resetCheckInOnNewDay(_ now: Date) {
        let day = environment.calendar.startOfDay(for: now)
        if let lastRefreshDay, lastRefreshDay != day {
            checkIn.selection = [:]
        }
        lastRefreshDay = day
    }

    private func apply(_ updated: TodayScore) {
        score = updated
        if case .scored(let recovery) = updated {
            factors = FactorFormatter.displays(for: recovery)
            marker = FactorFormatter.marker(for: recovery)
        } else {
            factors = []
            marker = nil
        }
    }

    private static func greeting(firstName: String?) -> String {
        let name = firstName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !name.isEmpty else { return String(localized: "Bonjour", bundle: .module) }
        return String(localized: "Bonjour \(name)", bundle: .module)
    }

    /// « lundi 2 novembre », dans le fuseau du calendrier injecté.
    private static func dateText(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
        return formatter.string(from: date)
    }

    private static func timeText(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
