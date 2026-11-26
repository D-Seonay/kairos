import Foundation
import PulseDomain

/// L'accès à Apple Santé demandé après l'onboarding : « Connecter Apple Santé », dans les Paramètres et sur la bannière du
/// check-in. iOS ne liste une app dans Réglages › Santé qu'une fois la demande faite : qui a passé l'étape Apple Santé de
/// l'onboarding n'avait sinon aucun chemin pour la faire.
///
/// HealthKit ne dit jamais si la lecture est accordée : `wasRequested()` dit seulement si la demande a déjà été faite sur cet
/// appareil, jamais si Apple Santé est « connecté ».
public struct HealthAccess: Sendable {
    private let source: any HealthSampleSource
    private let cache: any HealthSampleCache
    private let once: any OnceLog
    private let afterRequest: @Sendable () async -> Void

    /// `afterRequest` : ce que l'app fait une fois la demande passée, avant que l'appelant relise le jour (relancer les
    /// observateurs d'Apple Santé, que HealthKit a arrêtés faute d'accès).
    public init(source: any HealthSampleSource, cache: any HealthSampleCache, once: any OnceLog,
                afterRequest: @escaping @Sendable () async -> Void = {}) {
        self.source = source
        self.cache = cache
        self.once = once
        self.afterRequest = afterRequest
    }

    /// Les types dont une donnée en cache prouve la demande : les nuits, que Pulse ne fait que lire. Une course ou une pesée ne
    /// prouve rien : Pulse relit celles qu'il a écrites lui-même dans Apple Santé, sans que la lecture ait jamais été demandée.
    static let provingKinds: [HealthSampleKind] = [.sleep, .sdnn, .restingHeartRate]

    /// Vrai une fois la demande faite sur cet appareil. Une installation d'avant ce réglage ne l'a pas retenue : une nuit
    /// d'Apple Santé déjà dans le cache prouve qu'elle a eu lieu, et elle est retenue à ce moment-là. Un cache illisible ne
    /// prouve rien.
    public func wasRequested() async -> Bool {
        if once.hasHappened(.healthAccessRequest) { return true }
        for kind in Self.provingKinds {
            guard let samples = try? await cache.samples(kind: kind, from: .distantPast, to: .distantFuture),
                  !samples.isEmpty else { continue }
            once.record(.healthAccessRequest)
            return true
        }
        return false
    }

    /// Fait la demande d'accès de l'onboarding (la feuille d'iOS ne s'affiche que la première fois), la retient, puis laisse
    /// l'app y donner suite. Une demande qui échoue (Apple Santé indisponible) n'est pas retenue : elle reste à faire.
    /// L'appelant relit ensuite le jour, comme au retour au premier plan.
    public func request() async throws {
        try await source.requestAuthorization()
        once.record(.healthAccessRequest)
        await afterRequest()
    }
}
