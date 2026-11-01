import Foundation
import PulseDomain

/// Erreur de chargement du contenu embarqué.
public enum ContentError: Error, Equatable {
    case missingResource(String)
    case decoding(file: String, detail: String)
}

/// Le contenu embarqué : exercices et modèles de programme, chargés une fois depuis le bundle (spec M2 §4.5).
public struct ContentLibrary: Sendable {
    public let contentVersion: String
    public let exercises: [Exercise]
    public let programTemplates: [ProgramTemplate]
    private let exercisesByID: [String: Exercise]
    private let templatesByID: [String: ProgramTemplate]

    public init(catalog: ExerciseCatalog, templates: [ProgramTemplate]) {
        contentVersion = catalog.contentVersion
        exercises = catalog.exercises
        programTemplates = templates
        exercisesByID = Dictionary(catalog.exercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        templatesByID = Dictionary(templates.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Les exercices non retirés.
    public var activeExercises: [Exercise] {
        exercises.filter { !$0.retired }
    }

    public func exercise(id: String) -> Exercise? {
        exercisesByID[id]
    }

    public func programTemplate(id: String) -> ProgramTemplate? {
        templatesByID[id]
    }

    /// Le bundle de ressources du package (pour les tests).
    public static var resourceBundle: Bundle { .module }

    /// Le contenu du bundle ; un contenu invalide est fatal (les tests de validation l'empêchent d'arriver là).
    public static let bundled: ContentLibrary = {
        do {
            return try load(from: resourceBundle)
        } catch {
            fatalError("Contenu Pulse invalide : \(error)")
        }
    }()

    /// Lit `exercises.json`, `programs.json`, puis `Programs/<id>.json` pour chaque identifiant listé.
    public static func load(from bundle: Bundle) throws -> ContentLibrary {
        let catalog: ExerciseCatalog = try decode("exercises", from: bundle)
        let index: ProgramIndex = try decode("programs", from: bundle)
        let templates = try index.programs.map { id -> ProgramTemplate in try decode(id, subdirectory: "Programs", from: bundle) }
        return ContentLibrary(catalog: catalog, templates: templates)
    }

    private struct ProgramIndex: Decodable {
        var schemaVersion: Int
        var programs: [String]
    }

    private static func decode<T: Decodable>(_ name: String, subdirectory: String? = nil, from bundle: Bundle) throws -> T {
        let file = (subdirectory.map { "\($0)/" } ?? "") + "\(name).json"
        guard let url = bundle.url(forResource: name, withExtension: "json", subdirectory: subdirectory)
            ?? bundle.url(forResource: name, withExtension: "json") else {
            throw ContentError.missingResource(file)
        }
        do {
            return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
        } catch {
            throw ContentError.decoding(file: file, detail: String(describing: error))
        }
    }
}
