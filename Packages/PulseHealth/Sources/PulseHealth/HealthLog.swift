import os
import PulseDomain

/// Le journal du module PulseHealth (catégorie « health »), sous le sous-système de l'app. Les erreurs rattrapées
/// y sont notées avec `failure` ou `attempt` ; aucune valeur de santé n'y entre.
let logger = PulseLog.logger("health")
