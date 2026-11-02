import Foundation
import SwiftData

/// Empreinte textuelle d'un schéma : une ligne par attribut et par relation, triées.
enum SchemaFingerprint {
    static func lines(_ schema: Schema) -> [String] {
        var result: [String] = []
        for entity in schema.entities {
            for attribute in entity.attributes {
                let type = String(describing: attribute.valueType)
                let isOptionalType = type.hasPrefix("Optional<")
                let options = attribute.options.map { String(describing: $0) }.sorted()
                let optionsSuffix = options.isEmpty ? "" : " [options: \(options.joined(separator: ", "))]"
                result.append(
                    "\(entity.name).\(attribute.name): \(type)\(attribute.isOptional && !isOptionalType ? "?" : "")\(optionsSuffix)"
                )
            }
            for relationship in entity.relationships {
                let cardinality = relationship.isToOneRelationship ? "to-one" : "to-many"
                result.append(
                    "\(entity.name).\(relationship.name) -> \(relationship.destination) "
                        + "[\(cardinality), \(relationship.deleteRule), inverse: \(inverseName(of: relationship))]"
                )
            }
        }
        return result.sorted()
    }

    private static func inverseName(of relationship: Schema.Relationship) -> String {
        if let name = relationship.inverseName {
            return name
        }
        if let keyPath = relationship.inverseKeyPath {
            return String(describing: keyPath).split(separator: ".").last.map(String.init) ?? "none"
        }
        return "none"
    }

    /// Le contenu d'un fichier de référence : les lignes jointes par `\n`, avec un `\n` final.
    static func fileContents(_ schema: Schema) -> String {
        lines(schema).joined(separator: "\n") + "\n"
    }
}
