import Foundation

/// Export complet des données de l'utilisateur (spec M2 §6).
public protocol DataExporter: Sendable {
    func exportJSON() async throws -> URL
    func exportCSVArchive() async throws -> URL
}
