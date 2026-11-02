import Foundation
import SwiftData

/// Modèle de test : sert à vérifier que l'empreinte décrit les options d'attribut.
@Model
final class FingerprintProbe {
    var id = UUID()
    @Attribute(.externalStorage) var blob: Data?

    init() {}
}
