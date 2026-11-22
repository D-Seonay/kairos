import Foundation
import Observation
import PulseServices

/// L'état de l'onglet Stats (spec M7 §5) : la vue choisie, la période et les cinq vues calculées pour cette période.
@MainActor
@Observable
public final class StatsModel {
    public private(set) var snapshot: StatsSnapshot?
    public private(set) var errorMessage: String?
    /// Le nombre de lectures échouées : chaque échec, même au texte identique, s'annonce à VoiceOver.
    public private(set) var failureCount = 0
    public private(set) var hasLoaded = false
    public var view: StatsView = .load
    /// Changer la période relit les statistiques.
    public var period: StatsPeriod {
        didSet {
            guard period != oldValue else { return }
            reloadTask = Task { await load() }
        }
    }

    @ObservationIgnored let environment: StatsEnvironment
    @ObservationIgnored private var isLoading = false
    /// La relecture lancée par le dernier changement de période ; les tests l'attendent.
    @ObservationIgnored var reloadTask: Task<Void, Never>?

    public init(environment: StatsEnvironment, period: StatsPeriod = .month) {
        self.environment = environment
        self.period = period
    }

    /// Relit les statistiques de la période. Un appel pendant une lecture est ignoré (la lecture en cours reprend si la période
    /// a changé entre-temps) ; si la lecture échoue, l'écran garde son dernier état et affiche une erreur.
    public func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        var requested: StatsPeriod
        repeat {
            requested = period
            do {
                snapshot = try await environment.service.snapshot(for: requested)
                errorMessage = nil
            } catch {
                errorMessage = String(localized: "Pulse n'a pas pu lire tes statistiques.", bundle: .module)
                failureCount += 1
            }
        } while requested != period
        hasLoaded = true
    }
}
