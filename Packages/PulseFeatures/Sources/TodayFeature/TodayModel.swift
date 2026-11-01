import CheckInFeature
import Foundation
import Observation
import PulseDomain
import PulseServices

/// L'état de l'onglet « Aujourd'hui » : salutation, score du jour et ses facteurs, séance prévue, check-in si les données manquent.
@MainActor
@Observable
public final class TodayModel {
    public private(set) var greeting: String
    public private(set) var dateText: String
    public private(set) var lastSync: Date?
    public private(set) var score: TodayScore?
    public private(set) var factors: [FactorDisplay] = []
    public private(set) var marker: String?
    public private(set) var plannedDay: PlannedDay = .noProgram
    public private(set) var summary: SessionSummary?
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?
    public let checkIn = CheckInForm()

    @ObservationIgnored private let environment: TodayEnvironment
    @ObservationIgnored private var isSubmittingCheckIn = false
    /// Change à chaque check-in enregistré : une lecture qui a commencé avant lui n'écrase pas le score estimé.
    @ObservationIgnored private var scoreEpoch = 0

    public init(environment: TodayEnvironment) {
        self.environment = environment
        greeting = Self.greeting(firstName: nil)
        dateText = Self.dateText(environment.now(), calendar: environment.calendar)
    }

    /// L'heure de la dernière lecture d'Apple Santé réussie, « 08:00 ».
    public var lastSyncText: String? {
        lastSync.map { Self.timeText($0, calendar: environment.calendar) }
    }

    /// Relit le profil, le programme actif et Apple Santé, puis recalcule le score. Un appel pendant une lecture est ignoré :
    /// l'activation de la scène ne peut pas courir contre une actualisation manuelle.
    public func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        let now = environment.now()
        let epoch = scoreEpoch
        dateText = Self.dateText(now, calendar: environment.calendar)

        let profile = try? await environment.profiles.load()
        greeting = Self.greeting(firstName: profile?.firstName)
        await plan(for: profile, now: now)

        let snapshot = await environment.nightHistory.refresh(now: now)
        if let readAt = snapshot.readAt {
            lastSync = readAt
        }
        guard let updated = try? await environment.scores.update(nights: snapshot.nights, now: now), epoch == scoreEpoch else { return }
        apply(updated)
    }

    /// Enregistre les réponses du check-in. Sans effet hors du cas « check-in à faire », avec des réponses incomplètes
    /// ou pendant un enregistrement déjà en cours.
    public func submitCheckIn() async {
        guard !isSubmittingCheckIn, case .needsCheckIn = score, let answers = checkIn.answers else { return }
        isSubmittingCheckIn = true
        defer { isSubmittingCheckIn = false }
        do {
            let estimated = try await environment.scores.saveCheckIn(answers, now: environment.now())
            scoreEpoch += 1
            errorMessage = nil
            apply(.scored(estimated))
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu enregistrer ton check-in.", bundle: .module)
        }
    }

    // MARK: - Interne

    private func plan(for profile: UserProfile?, now: Date) async {
        var program: Program?
        if let id = profile?.activeProgramID {
            program = try? await environment.programs.program(id: id)
        }
        plannedDay = TodayPlanner.plan(program: program, on: now, calendar: environment.calendar)
        if case .strength(let day) = plannedDay {
            summary = SessionSummary.make(day: day, library: environment.library)
        } else {
            summary = nil
        }
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
