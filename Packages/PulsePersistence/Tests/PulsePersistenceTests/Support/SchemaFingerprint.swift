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
                result.append("\(entity.name).\(attribute.name): \(type)\(attribute.isOptional && !isOptionalType ? "?" : "")")
            }
            for relationship in entity.relationships {
                let cardinality = relationship.isToOneRelationship ? "to-one" : "to-many"
                result.append(
                    "\(entity.name).\(relationship.name) -> \(relationship.destination) "
                        + "[\(cardinality), \(relationship.deleteRule)]"
                )
            }
        }
        return result.sorted()
    }

    /// Le contenu d'un fichier de référence : les lignes jointes par `\n`, avec un `\n` final.
    static func fileContents(_ schema: Schema) -> String {
        lines(schema).joined(separator: "\n") + "\n"
    }
}
