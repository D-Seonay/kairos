import Foundation

/// Déplace vers le magasin local les valeurs Apple Health que d'anciennes versions ont laissées dans le magasin synchronisé
/// (spec M8 §5.2). Appelé au lancement et à chaque passage du jour : iCloud peut redescendre d'anciennes lignes à tout moment.
public protocol HealthDataRelocating: Sendable {
    /// Rend vrai si quelque chose a été déplacé.
    func relocate() async throws -> Bool
}
