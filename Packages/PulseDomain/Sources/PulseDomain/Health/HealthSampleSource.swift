import Foundation

/// Ce qu'Apple Santé sait du profil physique de l'utilisateur, pour préremplir l'accueil.
public struct HealthProfileHints: Sendable, Equatable {
    public var sex: Sex?
    public var birthDate: Date?
    public var heightCm: Double?
    public var weightKg: Double?

    public init(sex: Sex? = nil, birthDate: Date? = nil, heightCm: Double? = nil, weightKg: Double? = nil) {
        self.sex = sex
        self.birthDate = birthDate
        self.heightCm = heightCm
        self.weightKg = weightKg
    }
}

/// Lecture des échantillons d'Apple Santé. Implémenté par `PulseHealth` ; le moteur et les fonctionnalités n'en voient que le protocole.
public protocol HealthSampleSource: Sendable {
    func requestAuthorization() async throws
    func profileHints() async throws -> HealthProfileHints
    /// Ce qui a changé dans Apple Santé pour un signal depuis `anchor`, en ne regardant que les échantillons postérieurs à `start`.
    /// Sans ancre utilisable, la réponse est une lecture complète (`isFullRead`).
    func changes(of signal: NightSignal, since anchor: Data?, from start: Date) async throws -> HealthSampleChanges
}
