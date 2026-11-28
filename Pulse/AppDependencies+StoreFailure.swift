import Foundation
import PulseDomain

extension AppDependencies {
    /// Le magasin préféré ne s'ouvre pas : l'erreur est journalisée (sinon rien ne la montrerait, l'app repart en mémoire),
    /// puis le message affiché à l'utilisateur.
    static func storeFailureMessage(logging error: any Error) -> String {
        logger.failure("Magasin SwiftData non ouvert, repli en mémoire", error)
        return String(localized: "Le stockage n'a pas pu être ouvert ; les données ne seront pas conservées.")
    }
}
