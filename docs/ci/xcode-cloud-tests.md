# Lancer les tests dans Xcode Cloud

Issue #97. Ce document dit ce qui vit dans le dépôt, ce qu'il reste à régler à la main dans Xcode ou App Store Connect, et ce que chaque test demande pour tourner.

> Les workflows Xcode Cloud ne sont pas des fichiers du dépôt : ils se créent et se modifient dans Xcode ou dans App Store Connect. Le dépôt ne fournit que le schéma, les plans de test et les scripts `ci_scripts/`.

## 1. Ce qui est dans le dépôt

| Fichier | Rôle |
| :--- | :--- |
| `Pulse.xcodeproj/xcshareddata/xcschemes/Pulse.xcscheme` | Le schéma partagé `Pulse`. Son action Test ne liste plus les cibles une à une : elle pointe vers les deux plans ci-dessous, `Pulse` par défaut. |
| `Pulse.xctestplan` | Plan par défaut, **tous les tests** : `PulseTests`, `PulseUITests` et les 20 cibles de test des packages. C'est celui que lancent `make test-app` et le bouton Test d'Xcode. |
| `PulseUnit.xctestplan` | Le même plan **sans `PulseUITests`**. Il sert si le plan complet est trop long pour chaque pull request (voir § 3.3). |
| `ci_scripts/ci_post_clone.sh` | Inchangé : installe SwiftLint et lance `swiftlint lint --strict` après le clonage. Un écart de style fait échouer l'action, tests compris. |

Réglages communs aux deux plans :

- **Langue `fr`, région `FR`.** L'app n'a que le français, mais la région règle le premier jour de la semaine (`Calendar.current` : lundi en France, dimanche aux États-Unis) et les formats de date et de nombre. Les simulateurs d'Xcode Cloud sont en anglais américain par défaut.
- **Variable `TZ=Europe/Paris`** pour les tests unitaires (`PulseTests` tourne dans l'app hôte, les packages dans le processus de test). Les tests d'interface lancent l'app eux-mêmes et ne reçoivent pas les variables du plan : chacun pose `app.launchEnvironment["TZ"] = "Europe/Paris"`. Sans ça, `-PulseNow 2026-11-02T08:00:00+01:00` tombe le dimanche 1ᵉʳ novembre au soir sur un Mac réglé sur la côte ouest américaine, et la séance Push du lundi n'existe plus.
- **Aucune parallélisation** (`parallelizable: false`), comme avant dans le schéma : un seul simulateur, dans l'ordre.
- Configuration **Debug** (celle de l'action Test du schéma). Les options de lancement des tests d'interface (`-PulseStore`, `-PulseSeed`…) ne sont compilées qu'en Debug : ne passez pas l'action Test en Release.

Ce qui n'a **pas** été ajouté : un `ci_post_xcodebuild.sh` de résumé. Xcode Cloud affiche déjà chaque test, son message d'échec et les captures d'écran des tests d'interface dans le rapport du build (Xcode et App Store Connect), et une action Test échoue d'elle-même dès qu'un test échoue.

## 2. Vérifier sur un Mac avant le premier workflow

Rien n'a été compilé ni lancé à l'écriture de ce document (développement sous Windows). Sur un Mac avec Xcode 26 :

1. `xcodebuild -showTestPlans -scheme Pulse` liste `Pulse` et `PulseUnit`.
2. Ouvrir `Pulse.xcodeproj`, menu **Product › Test Plan** : les deux plans apparaissent, `Pulse` coché. **Product › Test Plan › Edit Test Plan** montre 22 cibles dans `Pulse`, 21 dans `PulseUnit`, et dans **Configurations › Shared Settings** la langue *French*, la région *France* et la variable `TZ`. Si Xcode réécrit un des fichiers en l'ouvrant (ordre des clés, `\/`), commitez sa version.
3. `make test-app` (plan `Pulse`, iPhone 17). Pour un seul plan ou un seul test :

   ```bash
   xcodebuild test -scheme Pulse -testPlan PulseUnit -destination 'platform=iOS Simulator,name=iPhone 17'
   xcodebuild test -scheme Pulse -destination 'platform=iOS Simulator,name=iPhone 17' \
     -only-testing:PulseUITests/SupplementsUITests
   ```

4. Les sept cibles de test de `PulseFeatures` qui ne figuraient pas dans le schéma (`NightFeatureTests`, `PhotosFeatureTests`, `PlanningFeatureTests`, `ProfileFeatureTests`, `RunFeatureTests`, `StatsFeatureTests`, `SupplementsFeatureTests`) tournent désormais sur simulateur iOS, et plus seulement avec `swift test` sous macOS : vérifier qu'elles passent aussi là.

## 3. Créer le workflow (à faire à la main)

Un workflow se crée dans Xcode (**Product › Xcode Cloud › Manage Workflows…**, interface en anglais) ou dans App Store Connect (**Apps › Pulse › Xcode Cloud › Gérer les workflows**). Les libellés ci-dessous sont ceux d'Xcode.

### 3.1 Workflow « Tests »

Un workflow à part de celui qui archive pour TestFlight, pour qu'un test rouge ne bloque pas une livraison tant que la suite n'est pas stabilisée. Une fois qu'il est vert depuis quelques jours, on peut ajouter la même action Test au workflow de livraison.

1. **+** (nouveau workflow), produit **Pulse**.
2. **General**
   - *Name* : `Tests`.
   - *Description* : « Plan de test Pulse sur simulateur iOS 26 (issue #97) ».
   - *Repository* et *Project or Workspace* : `Pulse.xcodeproj`.
3. **Environment**
   - *Xcode Version* : **Latest Release** (Xcode 26.x, nécessaire aux simulateurs iOS 26 et à la cible de déploiement 26.0).
   - *macOS Version* : celle recommandée pour cette version d'Xcode.
   - *Clean* : décoché (les builds suivants réutilisent le cache des packages). À cocher si un build se comporte bizarrement.
4. **Start Conditions** (remplacer la condition par défaut)
   - **Pull Request Changes** : *Source Branch* = Any Branch, *Target Branch* = `master`.
   - **Branch Changes** : *Branch* = `master` (le build après fusion).
   - Cocher *Auto-cancel Builds* sur les deux : un nouveau push annule le build en cours de la même branche.
5. **Actions** : supprimer l'action *Build* par défaut s'il y en a une, puis **+ › Test** :
   - *Scheme* : `Pulse`.
   - *Platform* : iOS.
   - *Test Plan* : **Pulse**.
   - *Destination* : **Simulator**, appareil **iPhone 17** (celui du `Makefile`), système **Latest Release** (iOS 26.x).
   - *Requirements* : **Required to pass** coché. L'action échoue si un test échoue, et le workflow avec elle.
6. **Post-Actions** : **+ › Notify**, *Build Failure* vers votre adresse (ou Slack), pour être prévenu sans ouvrir Xcode.
7. **Save**, puis **Start Build** sur `master` pour le premier passage.

Côté GitHub, Xcode Cloud publie un statut sur chaque pull request. Une fois la suite verte, ce statut peut devenir obligatoire dans **Settings › Branches › Branch protection rules › master › Require status checks to pass**.

### 3.2 Durée et coût

L'abonnement Apple Developer comprend 25 heures de calcul Xcode Cloud par mois. Une action Test compte la compilation pour les tests (`build-for-testing`) puis l'exécution sur le simulateur. Notez la durée du premier build vert : c'est elle qui décide du § 3.3.

### 3.3 Si c'est trop long : plan rapide sur les PR, plan complet la nuit

1. Dans le workflow `Tests`, action Test : *Test Plan* = **PulseUnit**. Les PR restent rapides, sans tests d'interface.
2. Nouveau workflow `Tests nocturnes`, mêmes réglages qu'au § 3.1 sauf :
   - *Start Conditions* : une seule condition **On a Schedule**, *Branch* = `master`, *Frequency* = Daily, une heure de nuit (par exemple 3 h, fuseau Europe/Paris).
   - Action Test : *Test Plan* = **Pulse**.
   - *Notify* sur *Build Failure*.

## 4. Ce que chaque test demande

Aucun test n'a besoin d'un appareil, d'un compte iCloud, de Santé, de Face ID ni d'une autorisation système : tout passe par des doublures. Les doublures n'existent qu'en Debug (`#if DEBUG`).

### Tests d'interface (`PulseUITests`, plan `Pulse` seulement)

Arguments communs, lus par `LaunchOptions` : `-PulseHealthScenario goodNight` remplace Apple Santé par une nuit simulée (`ScenarioHealthSource`, sans demande d'autorisation) ; `-PulseNow <date ISO 8601>` fige l'horloge. Avec `-PulseStore`, l'app passe en mode test (`useMemoryDoubles`) : notifications, widgets, Live Activity, course et rappels sont des doublures, Face ID est remplacé par `UITestOwnerAuthenticator` (réglable par `-PulseOwnerAuthentication succeeds|fails|noPasscode`, réussite par défaut ; aucun test actuel ne touche aux photos de corps).

| Test | Arguments | Données | Déjà lancé ? |
| :--- | :--- | :--- | :---: |
| `OnboardingFlowUITests` | `-PulseStore inMemory`, `goodNight`, lundi 2/11/2026 8 h | Aucune : parcourt l'onboarding jusqu'au score | Oui, sur simulateur |
| `AccessibilityAuditUITests` | Les mêmes | Aucune : onboarding, puis les cinq onglets, séance libre et récap, chacun passé à `performAccessibilityAudit` | **Non** |
| `LiveSessionResumeUITests` | `-PulseStore disk`, `-PulseResetStore YES` au premier lancement, `-PulseSeed onboardedPPL`, `goodNight`, lundi 8 h | `UITestSeeder` crée un profil terminé et le programme `ppl-3` ; le magasin vit dans `tmp/PulseUITestStore` et survit à l'arrêt forcé | **Non** |
| `SupplementsUITests` | `-PulseStore inMemory`, `-PulseSeed onboardedPPL`, `goodNight`, lundi **7 h** | Profil `ppl-3` ; crée la Créatine (prise à 8 h, donc la prochaine) et la coche | **Non** |

### Tests unitaires de l'app (`PulseTests`, plans `Pulse` et `PulseUnit`)

Ils tournent dans `Pulse.app` (`TEST_HOST`) avec `AppDependencies.testing()` : magasin en mémoire, préférences `fr.seonay.pulse.tests`, Santé `noData`, notifications refusées, Live Activity et course en doublures. L'app hôte, elle, démarre comme l'app normale (sans argument, magasin local du simulateur) ; les tests construisent leurs propres dépendances et n'en dépendent pas.

- `SessionIntentWiringTests` (boutons Pause et Reprendre de la Live Activity de course) : **jamais lancé**.
- `AppRootModelTests` : les tests de la course, à partir de `tabsCreateTheRunAndHandItToTheLiveActivityButtons` jusqu'à la fin du fichier, **jamais lancés**.
- `AppRouterTests`, `DataDebugModelTests`, `HealthDiagnosticsModelTests`, `NotificationRouterTests`, `PhotoWiringTests`, `SessionActivityControllerTests`.

### Tests des packages (plans `Pulse` et `PulseUnit`)

Les 20 cibles de test des packages (`PulseDomain`, `PulseRecoveryEngine`, `PulseHealth`, `PulseContent`, `PulsePersistence`, `PulseDesignSystem`, et les 14 de `PulseFeatures`) tournent ici sur simulateur iOS. `make test-packages` les lance aussi sous macOS avec `swift test`, sauf `PulseHealthTests`, que seul le plan lance.

## 5. Risques connus

- **Premier passage probablement rouge.** Trois tests d'interface et une partie de `PulseTests` n'ont jamais tourné. Les causes probables :
  - `AccessibilityAuditUITests` : l'audit relève tout ce qu'il trouve (cible trop petite, texte coupé en grande taille de police, contraste). Seuls les défauts de contraste d'éléments décoratifs sans libellé sont écartés.
  - `LiveSessionResumeUITests` : enchaînement long (clavier maison, arrêt forcé, relance) avec des délais de 5 à 15 s, parfois courts sur un simulateur froid.
  - `SupplementsUITests` : saisie au clavier système dans `supplements.form.dose` ; la coche peut être rangée sous `button` ou `switch` (le test interroge déjà `.any`).
  - Les sept cibles de `PulseFeatures` ajoutées au plan n'avaient jamais tourné sur simulateur iOS.
- **Lenteur du simulateur en CI.** Le premier lancement de l'app est plus lent que sur un Mac de développement. Si un test échoue sur « Élément introuvable » sans autre cause, allonger le `timeout` du `tapWhenHittable` concerné plutôt que de désactiver le test.
- **Fuseau et région.** Couverts par le plan (`fr`/`FR`, `TZ`) et par `launchEnvironment` dans les tests d'interface. Un nouveau test d'interface qui fige l'horloge doit lui aussi poser `TZ`.
- **Scripts.** `ci_post_clone.sh` installe SwiftLint avec Homebrew avant chaque build : une panne de Homebrew fait échouer les tests sans rapport avec le code.

### Corriger ou désactiver un test rouge

L'issue #97 demande que chaque test rouge au premier passage soit corrigé, ou désactivé **avec un ticket**. Pour désactiver, ouvrir d'abord une issue, puis :

- Swift Testing (`PulseTests`, packages) : `@Test(.disabled("Rouge dans Xcode Cloud, voir #NN")) func …`.
- XCTest (`PulseUITests`) : en tête du test, `throw XCTSkip("Rouge dans Xcode Cloud, voir #NN")` (la fonction doit être `throws`).

Ces deux formes affichent la raison dans le rapport. Éviter de décocher le test dans le plan (**Edit Test Plan › clic droit › Disable Test**) : ça marche, mais la raison n'apparaît nulle part.
