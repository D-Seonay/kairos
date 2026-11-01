# Pulse M3a — Design system, onboarding et score du jour : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mathéo installe Pulse, passe les six écrans du premier lancement, voit son premier score sur la calibration, puis chaque matin le score du jour (mesuré ou par check-in) et la séance prévue sur un onglet Aujourd'hui simple.

**Architecture:** Deux nouveaux packages locaux. `PulseDesignSystem` porte les tokens de `maquette.html`, les composants, la jauge et la carte musculaire. `PulseFeatures` porte `PulseServices` (logique sans interface : historique des nuits, score du jour, adoption de programme, séance du jour, fausse source Apple Santé), `CheckInFeature`, `OnboardingFeature` et `TodayFeature`. Les features ne voient que des protocoles de `PulseDomain` ; l'app assemble dans `AppDependencies`. Toute la logique se teste par `swift test` sur le Mac ; l'app reste un assemblage mince, compilé par `xcodebuild`.

**Tech Stack:** Swift 6.4 (mode de langage 6), SwiftUI (verre iOS 26), SwiftData, HealthKit, UserNotifications, Swift Testing, XCUITest, SwiftPM, XcodeGen 2.46 (une fois), SwiftLint, Xcode 27.0.

**Spec:** `docs/superpowers/specs/2026-11-01-pulse-m3-onboarding-tableau-de-bord-design.md` (la « spec M3 », partie M3a), qui complète `2026-10-31-pulse-v1-design.md` et `2026-10-31-pulse-m2-donnees-contenu-design.md`. Référence visuelle : `maquette.html` (écrans `bienvenue`, `sante`, `profil-init`, `objectifs`, `calibration`, `today`, `checkin`) et `assets/maquette_v2_planche.png`.

## Global Constraints

- Xcode **27.0**, Swift **6.4**, cible **iOS 26**, `swift-tools-version: 6.2`, `swiftSettings: [.swiftLanguageMode(.v6)]` sur chaque cible. Nouveaux packages : `platforms: [.iOS(.v26), .macOS(.v26)]`, `defaultLocalization: "fr"`.
- **Ne jamais lancer le simulateur** : interdits `xcodebuild test`, `test-without-building`, `make test`, `make test-app`, `simctl boot|install|launch`, outils d'appareil. Vérifications autorisées : `swift test --package-path Packages/<Nom>`, `swiftlint lint --strict`, `make build-app` (= `xcodebuild build-for-testing -scheme Pulse -destination 'generic/platform=iOS Simulator' -quiet`), toujours **hors bac à sable du shell** pour `xcodebuild`. Juger `xcodebuild` sur le code de sortie 0 (Xcode 27 n'affiche pas de bannière avec `-quiet`).
- SwiftLint strict, avertissements = erreurs : **≤ 400 lignes par fichier**, **≤ 50 lignes par corps de fonction**, lignes ≤ 140, imports triés, pas de `!` hors tests.
- `PulseFeatures` dépend de `PulseDomain`, `PulseRecoveryEngine`, `PulseContent`, `PulseDesignSystem` ; **jamais** de `PulsePersistence`, `PulseHealth`, `SwiftData` ni `HealthKit`. `PulseDesignSystem` ne dépend que de `PulseDomain`.
- Les packages compilent pour macOS (pour `swift test`) : toute API SwiftUI ou UIKit propre à iOS (clavier, haptique, titre en ligne) passe par `PlatformModifiers.swift` de `PulseDesignSystem` (`#if os(iOS)`).
- Aucune logique ne lit `Date()`, `Date.now` ni `Calendar.current` : l'heure vient d'un `now: @Sendable () -> Date` ou d'un paramètre `now: Date`, le calendrier d'un paramètre. Tests : calendrier grégorien `Europe/Paris`, locale `fr_FR`.
- Chaînes visibles en français. Dans un package : `String(localized: "…", bundle: .module)`, et `Text(String(localized: "…", bundle: .module))` (un `Text("…")` nu chercherait dans le bundle de l'app). Chaque cible qui a des chaînes a `Resources/Localizable.xcstrings`.
- Aucune valeur de santé (SDNN, FC, sommeil) dans un journal ou un `print`.
- Projet à dossiers synchronisés : fichiers sous `Pulse/`, `PulseTests/`, `PulseUITests/` compilés sans toucher au `pbxproj`. Le projet n'est régénéré qu'en tâche 1.
- Commits `type(scope): description` en anglais, **sans** trailer Co-Authored-By. Branche `m3-onboarding-tableau-de-bord`. Ne jamais pousser sans l'accord de Mathéo.

## Review Focus

1. **App tuée pendant la calibration ou retour arrière jusqu'au programme puis nouvelle adoption** : l'onboarding reprend à la calibration et relance la lecture ; adopter à nouveau remplace le programme adopté pendant l'onboarding au lieu d'en créer un second. Test en tâche 14 (`readoptingReplacesThePreviousProgram`).
2. **Heures limites et changement d'heure** : 3 h 59 contre 4 h 00, 11 h 59 contre 12 h 00, et la nuit de 25 h du 25 octobre 2026. Les bornes viennent du calendrier, pas de secondes. Tests en tâche 10 (`dayStartAndFreezeFollowTheCalendarOnDSTDay`).
3. **Apple Santé illisible après l'onboarding** (iPhone verrouillé, accès retiré) : l'accueil repart du cache, ne plante pas, garde la dernière heure de synchro. Tests en tâches 9 (`failedReadFallsBackToCache`) et 16 (`refreshWithFailingSourceKeepsCachedScore`).
4. **Profil laissé vide** (aucun prénom, taille, poids, Apple Santé ignoré) : chaque étape continue, l'accueil dit « Bonjour ». Tests en tâches 14 (`emptyProfileStillCompletes`) et 16 (`greetingWithoutFirstName`).
5. **Adoption sans alternative acceptable** (poids du corps, douleur aux épaules) : l'exercice d'origine est gardé, jamais deux fois le même exercice dans un jour. Tests en tâche 11.

---

## Structure des fichiers créés ou modifiés

```
project.yml                                  (temporaire, supprimé en tâche 1)
Pulse.xcodeproj/                             (régénéré : 2 packages et cible PulseUITests en plus)
Makefile                                     (+ PulseDesignSystem, PulseFeatures, build-app)
scripts/extract_musclemap.py                 (extraction unique des tracés de maquette.html)
Packages/PulseDomain/Sources/PulseDomain/
  Training/UserProfile.swift                 (+ firstName)
  Recovery/DailyRecovery.swift               (+ originalSessionChosen)
  Content/Exercise.swift                     (+ riskAreas)
  Health/HealthSampleSource.swift            HealthSampleSource, HealthProfileHints
  Repositories/NotificationAuthorizing.swift NotificationAuthorizing, StubNotificationAuthorizer
  Repositories/ProfileRepository.swift       (+ delete(id:))
Packages/PulsePersistence/Sources/PulsePersistence/
  Schema/PulseSchemaV1.swift                 (copies figées de StoredProfile et StoredDailyRecovery)
  Schema/PulseSchemaV2.swift, PulseMigrationPlan.swift, PersistenceStack.swift
  Models/StoredProfile.swift, StoredDailyRecovery.swift
  Repositories/SwiftDataProfileRepository.swift, SwiftDataRecoveryRepository.swift
  Export/CSVColumns+Training.swift, CSVColumns+Tracking.swift
Packages/PulseContent/                       Package.swift, exercises.json (riskAreas), validator, RunType/TrainingFocus.localizedName
Packages/PulseHealth/Sources/PulseHealth/HealthKitReader+SampleSource.swift
Packages/PulseDesignSystem/                  Tokens/, Theme/, Presentation/, Components/, Platform/, Gauge/, MuscleMap/, Resources/
Packages/PulseFeatures/
  Sources/PulseServices/                     Health/, Score/, Program/, Today/, App/, Doubles/
  Sources/CheckInFeature/                    CheckInQuestion, CheckInForm, CheckInView
  Sources/OnboardingFeature/                 OnboardingStep, OnboardingStepStore, OnboardingEnvironment, OnboardingModel, Views/
  Sources/TodayFeature/                      TodayEnvironment, TodayModel, FactorFormatter, Views/
  Tests/{PulseServicesTests,CheckInFeatureTests,OnboardingFeatureTests,TodayFeatureTests}/
Pulse/
  AppDependencies.swift                      (+ source Apple Santé, notifications, étapes, horloge, options de lancement)
  PulseApp.swift                             (racine AppRootView, thème sombre)
  Root/AppRootModel.swift, AppRootView.swift, MainTabView.swift, ProfileHubView.swift
  Notifications/UserNotificationAuthorizer.swift
  Debug/DataDebugModel.swift, DataDebugView.swift, EraseConfirmationView.swift
  Diagnostics/HealthDiagnosticsView.swift    (sans NavigationStack propre)
  RootTabView.swift                          (supprimé)
PulseTests/AppRootModelTests.swift, DataDebugModelTests.swift
PulseUITests/OnboardingFlowUITests.swift
```

---

### Task 1 : Projet régénéré, packages vides, cible de test d'interface

**Files:**
- Create: `project.yml` (temporaire), `Packages/PulseDesignSystem/Package.swift`, `Packages/PulseDesignSystem/Sources/PulseDesignSystem/PulseDesignSystem.swift`, `Packages/PulseDesignSystem/Tests/PulseDesignSystemTests/SmokeTests.swift`, `Packages/PulseFeatures/Package.swift`, un fichier source vide par cible (`PulseServices`, `CheckInFeature`, `OnboardingFeature`, `TodayFeature`) et un test par cible, `PulseUITests/OnboardingFlowUITests.swift` (squelette)
- Modify: `Pulse.xcodeproj/` (régénéré), `Makefile`

**Interfaces:**
- Produces : produits SwiftPM `PulseDesignSystem` (dépend de `PulseDomain`) et `PulseServices`, `CheckInFeature`, `OnboardingFeature`, `TodayFeature` (package `PulseFeatures`). Dépendances internes, toutes déclarées explicitement (pas d'import d'une dépendance transitive) : `PulseServices` → `PulseDomain`, `PulseRecoveryEngine`, `PulseContent` ; `CheckInFeature` → `PulseDomain`, `PulseRecoveryEngine`, `PulseDesignSystem` ; `OnboardingFeature` et `TodayFeature` → `PulseServices`, `CheckInFeature`, `PulseDesignSystem`, `PulseDomain`, `PulseContent`. Cibles de test `PulseDesignSystemTests`, `PulseServicesTests`, `CheckInFeatureTests`, `OnboardingFeatureTests`, `TodayFeatureTests`. Cible Xcode `PulseUITests` (`bundle.ui-testing`, `TEST_TARGET_NAME = Pulse`, identifiant `fr.seonay.pulse.uitests`). `make build-app`.

- [ ] **Step 1 : Relever les réglages actuels**

Run (hors bac à sable) : `xcodebuild -showBuildSettings -scheme Pulse -destination 'generic/platform=iOS Simulator' 2>/dev/null | grep -E '^\s+(TARGETED_DEVICE_FAMILY|DEVELOPMENT_TEAM|ASSETCATALOG_COMPILER_APPICON_NAME|INFOPLIST_KEY_LSApplicationCategoryType|CODE_SIGN_ENTITLEMENTS|PRODUCT_BUNDLE_IDENTIFIER|SWIFT_VERSION|SWIFT_STRICT_CONCURRENCY|IPHONEOS_DEPLOYMENT_TARGET|ENABLE_PREVIEWS) =' | sort -u > /tmp/pulse-settings-before.txt`
Expected : fichier non vide (une dizaine de lignes).

- [ ] **Step 2 : Créer les deux packages vides**

Manifestes selon les Interfaces ci-dessus, `resources: [.process("Resources")]` sur `PulseDesignSystem`, `CheckInFeature`, `OnboardingFeature`, `TodayFeature` (dossier `Resources/` avec un `Localizable.xcstrings` minimal `{"sourceLanguage":"fr","strings":{},"version":"1.0"}`). Chaque cible reçoit un fichier `public enum <Cible> {}` remplacé plus tard, chaque cible de test un `@Test func targetBuilds() { #expect(true) }`.

Run : `swift test --package-path Packages/PulseDesignSystem && swift test --package-path Packages/PulseFeatures`
Expected : deux exécutions vertes.

- [ ] **Step 3 : Écrire `project.yml`**

Partir de `git show 0a30786:project.yml` et y reporter **tout** l'état actuel :
- `packages:` les sept packages (`PulseDomain`, `PulseRecoveryEngine`, `PulseHealth`, `PulseContent`, `PulsePersistence`, `PulseDesignSystem`, `PulseFeatures`).
- Cible `Pulse` : `sources: [{path: Pulse, type: syncedFolder}]` ; dépendances vers les six premiers packages et `- package: PulseFeatures` avec `products: [PulseServices, CheckInFeature, OnboardingFeature, TodayFeature]` ; `settings.base` : `DEVELOPMENT_TEAM: UP9NVJDBKA`, `TARGETED_DEVICE_FAMILY: "1,2"`, `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`, `INFOPLIST_KEY_LSApplicationCategoryType: public.app-category.sports`, `CODE_SIGN_IDENTITY: iPhone Developer`, `PRODUCT_BUNDLE_IDENTIFIER: fr.seonay.pulse`, `ENABLE_PREVIEWS: "YES"`.
- `info.properties` de `Pulse` : les clés actuelles de `Pulse/Info.plist` (`CFBundleDisplayName`, `CFBundleDevelopmentRegion: fr`, `ITSAppUsesNonExemptEncryption: false`, les deux textes `NSHealth*`, `UIBackgroundModes: [remote-notification]`, `UILaunchScreen: {}`, `UISupportedInterfaceOrientations` et `UISupportedInterfaceOrientations~ipad`).
- `entitlements.properties` : HealthKit (avec `background-delivery` et `access: []`), iCloud (`icloud-services: [CloudKit]`, `icloud-container-identifiers: [iCloud.fr.seonay.pulse]`).
- Cible `PulseTests` en `syncedFolder` (inchangée), nouvelle cible `PulseUITests` (`type: bundle.ui-testing`, `syncedFolder`, dépend de `Pulse`, `GENERATE_INFOPLIST_FILE: "YES"`, `TEST_TARGET_NAME: Pulse`, `PRODUCT_BUNDLE_IDENTIFIER: fr.seonay.pulse.uitests`).
- `schemes.Pulse.test.targets` : `PulseTests`, `PulseUITests`, et les cibles de test de chaque package (`PulseDomainTests`, `PulseRecoveryEngineTests`, `PulseHealthTests`, `PulseContentTests`, `PulsePersistenceTests`, `PulseDesignSystemTests`, `PulseServicesTests`, `CheckInFeatureTests`, `OnboardingFeatureTests`, `TodayFeatureTests`).

- [ ] **Step 4 : Régénérer et comparer**

Run : `xcodegen generate && git diff --stat Pulse/Info.plist Pulse/Pulse.entitlements` puis (hors bac à sable) la commande du step 1 vers `/tmp/pulse-settings-after.txt` et `diff /tmp/pulse-settings-before.txt /tmp/pulse-settings-after.txt`
Expected : aucun changement sur `Info.plist` ni sur les entitlements (si XcodeGen réordonne des clés sans en perdre, accepter ; s'il en perd, compléter `project.yml`) ; `diff` vide.

- [ ] **Step 5 : `Makefile`**

`test-packages` gagne `swift test --package-path Packages/PulseDesignSystem` et `swift test --package-path Packages/PulseFeatures`. Nouvelle cible `build-app: xcodebuild build-for-testing -scheme Pulse -destination 'generic/platform=iOS Simulator' -quiet`. `test-app` reste tel quel (réservé à Mathéo).

- [ ] **Step 6 : Compiler l'app et les cibles de test, supprimer `project.yml`**

Run (hors bac à sable) : `rm project.yml && make build-app`
Expected : code de sortie 0.

- [ ] **Step 7 : Commit**

```bash
git add -A Pulse.xcodeproj Packages/PulseDesignSystem Packages/PulseFeatures PulseUITests Makefile
git commit -m "chore(project): add design system and features packages and a UI test target"
```

---

### Task 2 : Domaine — nouveaux champs et protocoles

**Files:**
- Modify: `Packages/PulseDomain/Sources/PulseDomain/Training/UserProfile.swift`, `Recovery/DailyRecovery.swift`, `Content/Exercise.swift`
- Create: `Packages/PulseDomain/Sources/PulseDomain/Health/HealthSampleSource.swift`, `Repositories/NotificationAuthorizing.swift`
- Test: `Packages/PulseDomain/Tests/PulseDomainTests/M3DomainTests.swift`

**Interfaces:**
- Produces :
  - `UserProfile.firstName: String?` (paramètre d'init `firstName: String? = nil`, juste après `id`).
  - `DailyRecovery.originalSessionChosen: Bool?` (paramètre `originalSessionChosen: Bool? = nil`, juste après `frozenAt`).
  - `Exercise.riskAreas: [PainArea]` (paramètre `riskAreas: [PainArea] = []`, juste avant `retired` ; décodage : clé absente → `[]`).
  - `struct HealthProfileHints: Sendable, Equatable { sex: Sex?; birthDate: Date?; heightCm: Double?; weightKg: Double? }` (init membre à membre, tout à `nil` par défaut).
  - `protocol HealthSampleSource: Sendable { func requestAuthorization() async throws; func sdnnSamples(from: Date, to: Date) async throws -> [TimedSample]; func restingHeartRateSamples(from: Date, to: Date) async throws -> [TimedSample]; func sleepIntervals(from: Date, to: Date) async throws -> [SleepInterval]; func profileHints() async throws -> HealthProfileHints }`.
  - `protocol NotificationAuthorizing: Sendable { func requestAuthorization() async -> Bool }` et `actor StubNotificationAuthorizer: NotificationAuthorizing { init(granted: Bool); var requestCount: Int }`.

- [ ] **Step 1 : Écrire les tests**

```swift
@Test func profileFirstNameRoundTripsThroughJSON() throws       // firstName "Mathéo" → encode/decode égal
@Test func recoveryOriginalSessionChosenRoundTrips() throws     // true → encode/decode égal ; nil par défaut
@Test func exerciseWithoutRiskAreasDecodesEmpty() throws        // JSON M2 sans la clé → riskAreas == []
@Test func exerciseRiskAreasDecode() throws                     // "riskAreas": ["shoulders", "wrists"] → [.shoulders, .wrists]
@Test func stubNotificationAuthorizerCountsRequests() async {
    let stub = StubNotificationAuthorizer(granted: true)
    #expect(await stub.requestAuthorization() == true)
    #expect(await stub.requestCount == 1)
}
```

- [ ] **Step 2 : Lancer, constater l'échec**

Run : `swift test --package-path Packages/PulseDomain`
Expected : FAIL à la compilation (`firstName`, `riskAreas`, `StubNotificationAuthorizer` inconnus).

- [ ] **Step 3 : Implémenter les Interfaces**

- [ ] **Step 4 : Vérifier tous les packages qui dépendent du domaine**

Run : `swift test --package-path Packages/PulseDomain && swift test --package-path Packages/PulseContent && swift test --package-path Packages/PulsePersistence && swift test --package-path Packages/PulseRecoveryEngine`
Expected : tout vert (les nouveaux paramètres ont des valeurs par défaut).

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulseDomain
git commit -m "feat(domain): add first name, original session choice, exercise risk areas and health source protocols"
```

---

### Task 3 : Persistance — schéma V2 et mineurs différés

**Files:**
- Modify: `Packages/PulsePersistence/Sources/PulsePersistence/Schema/PulseSchemaV1.swift`, `Schema/PulseMigrationPlan.swift`, `Schema/PersistenceStack.swift`, `Models/StoredProfile.swift`, `Models/StoredDailyRecovery.swift`, `Repositories/SwiftDataProfileRepository.swift`, `Repositories/SwiftDataRecoveryRepository.swift`, `Export/CSVColumns+Training.swift`, `Export/CSVColumns+Tracking.swift`, `Packages/PulseDomain/Sources/PulseDomain/Repositories/ProfileRepository.swift`, tests existants qui comptent les colonnes CSV
- Create: `Schema/PulseSchemaV2.swift`
- Test: `Packages/PulsePersistence/Tests/PulsePersistenceTests/MigrationTests.swift`, `ProfileRepositoryTests.swift`, `RecoveryRepositoryTests.swift`, `OtherMappingTests.swift`, `CSVExportTests.swift`

**Interfaces:**
- Consumes : tâche 2.
- Produces :
  - `ProfileRepository.delete(id: UUID) async throws` (suppression logique) ; `load()` renvoie le profil non supprimé le plus ancien par `createdAt`, puis par `id.uuidString` croissant (tri en mémoire : il n'y a jamais que un ou deux profils).
  - `SwiftDataRecoveryRepository.init(modelContainer: ModelContainer, calendar: Calendar)` : le jour est normalisé avec ce calendrier (init écrite à la main : `modelContainer`, `modelExecutor = DefaultSerialModelExecutor(modelContext: ModelContext(modelContainer))`, `calendar`).
  - `PulseSchemaV1` (version 1.0.0) contient des copies figées `PulseSchemaV1.StoredProfile` et `PulseSchemaV1.StoredDailyRecovery`, recopiées de `git show 863127d:Packages/PulsePersistence/Sources/PulsePersistence/Models/<Fichier>.swift` (propriétés stockées et valeurs par défaut identiques, un `init()` vide, sans mapping) ; ses `models` = les modèles actuels avec ces deux-là remplacés. `PulseSchemaV2` (version 2.0.0) : les modèles actuels. `PulseMigrationPlan.schemas = [PulseSchemaV1.self, PulseSchemaV2.self]`, `stages = [.lightweight(fromVersion: PulseSchemaV1.self, toVersion: PulseSchemaV2.self)]`. `PersistenceStack` ouvre `PulseSchemaV2`.
  - `PersistenceStack.makeContainer(directory: URL) throws -> ModelContainer` : magasins `synced.store` et `local.store` dans `directory`, sans CloudKit, avec le plan de migration ; `.localOnly` l'utilise avec le dossier d'Application Support actuel.
  - `StoredProfile.firstName`, `StoredDailyRecovery.originalSessionChosen` mappés ; colonnes CSV `first_name` (après `id`) et `original_session_chosen` (après `frozen_at`).

- [ ] **Step 1 : Écrire les tests**

```swift
@Test func v1StoreOpensAsV2KeepingData() throws {
    // dossier temporaire ; conteneur construit avec Schema(versionedSchema: PulseSchemaV1.self) et les mêmes
    // configurations "synced" / "local" que makeContainer(directory:) ; insère un PulseSchemaV1.StoredProfile (id connu)
    // et un PulseSchemaV1.StoredDailyRecovery (score 58) ; save ; on relâche le conteneur.
    let container = try PersistenceStack.makeContainer(directory: directory)
    let profile = try await SwiftDataProfileRepository(modelContainer: container).load()
    #expect(profile?.id == knownID)
    #expect(profile?.firstName == nil)
    let recoveries = try await SwiftDataRecoveryRepository(modelContainer: container, calendar: calendar)
        .dailyRecoveries(from: .distantPast, to: .distantFuture)
    #expect(recoveries.map(\.score) == [58])
    #expect(recoveries.first?.originalSessionChosen == nil)
}
@Test func profileFirstNameSurvivesSave() async throws           // save firstName "Mathéo" → load == "Mathéo"
@Test func profilesWithSameCreatedAtResolveByID() async throws   // deux profils même createdAt → load renvoie le plus petit uuidString
@Test func deletedProfileIsNotLoaded() async throws              // delete(id:) du plus ancien → load renvoie l'autre
@Test func recoveryDayUsesInjectedCalendar() async throws        // calendrier Pacific/Auckland : save à 2026-11-01T11:30Z → day == minuit d'Auckland
@Test func originalSessionChosenRoundTrips() async throws        // save true → relu true
@Test func csvHasNewColumns() throws                             // profile.csv commence par "id,first_name," ; daily_recoveries.csv contient "frozen_at,original_session_chosen"
```

- [ ] **Step 2 : Lancer, constater l'échec**

Run : `swift test --package-path Packages/PulsePersistence`
Expected : FAIL à la compilation (`makeContainer(directory:)`, `PulseSchemaV1.StoredProfile`, `delete(id:)`, `init(modelContainer:calendar:)` inconnus).

- [ ] **Step 3 : Implémenter les Interfaces**

Mettre à jour les appels de `SwiftDataRecoveryRepository(modelContainer:)` (app, eraser, tests) avec le calendrier. Si SwiftData refuse que V1 et V2 partagent les classes inchangées (erreur de sommes de contrôle ou de version inconnue au step 4), figer toute la liste V1 de la même façon et le signaler dans le rapport de tâche.

- [ ] **Step 4 : Vérifier**

Run : `swift test --package-path Packages/PulsePersistence`
Expected : tous verts, anciens tests compris (colonnes CSV ajustées).

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulsePersistence Packages/PulseDomain Pulse
git commit -m "feat(persistence): add schema V2 with first name and original session choice, profile delete and injected calendar"
```

---

### Task 4 : Contenu — zones à risque et mineurs différés

**Files:**
- Modify: `Packages/PulseContent/Package.swift`, `Sources/PulseContent/Resources/exercises.json`, `Sources/PulseContent/ContentValidator.swift`, `ExerciseRules.swift`, `TemplateRules.swift`, `ContentEnums+Localized.swift`, `Resources/Localizable.xcstrings`
- Test: `Packages/PulseContent/Tests/PulseContentTests/BundledExercisesTests.swift`, `ContentValidatorTests.swift`, `ContentLibraryTests.swift`, `LocalizedNamesTests.swift`

**Interfaces:**
- Consumes : `Exercise.riskAreas` (tâche 2).
- Produces : contenu `1.1.0` avec `riskAreas` ; règles `ContentRule.riskAreas` (doublon dans `riskAreas`) et `ContentRule.duplicateExerciseInDay` (même exercice deux fois dans un jour de modèle) ; `RunType.localizedName` (« Sortie facile », « Fractionné », « Sortie longue ») et `TrainingFocus.localizedName` (« Force », « Équilibré », « Endurance ») ; ressources : `.process("Resources/Localizable.xcstrings")`, `.process("Resources/exercises.json")`, `.process("Resources/programs.json")`, `.copy("Resources/Programs")`.

- [ ] **Step 1 : Écrire les tests**

```swift
@Test func riskAreasMatchTheSpecTable() {
    let expected: [String: [PainArea]] = [
        "overhead-press-barbell": [.shoulders], "seated-dumbbell-shoulder-press": [.shoulders], "shoulder-press-machine": [.shoulders],
        "arnold-press": [.shoulders], "dips": [.shoulders], "dumbbell-fly": [.shoulders],
        "deadlift-barbell": [.lowerBack], "romanian-deadlift-barbell": [.lowerBack], "barbell-row": [.lowerBack],
        "back-squat-barbell": [.lowerBack], "front-squat-barbell": [.lowerBack, .wrists],
        "sissy-squat": [.knees], "walking-lunge-dumbbell": [.knees], "bulgarian-split-squat": [.knees],
        "reverse-lunge-dumbbell": [.knees], "leg-extension-machine": [.knees], "single-leg-extension-machine": [.knees],
        "push-up": [.wrists], "barbell-curl": [.wrists], "wrist-curl-barbell": [.wrists], "reverse-wrist-curl-barbell": [.wrists]
    ]
    let actual = Dictionary(uniqueKeysWithValues: ContentLibrary.bundled.exercises.filter { !$0.riskAreas.isEmpty }.map { ($0.id, $0.riskAreas) })
    #expect(actual == expected)
}
@Test func machinePreacherCurlPrefersCableBeforeEZBar() {
    #expect(ContentLibrary.bundled.exercise(id: "preacher-curl-machine")?.alternatives == ["cable-curl", "ez-bar-preacher-curl", "hammer-curl-dumbbell"])
}
@Test func programsKeepTheirSubdirectory() {
    #expect(ContentLibrary.resourceBundle.url(forResource: "ppl-3", withExtension: "json", subdirectory: "Programs") != nil)
}
@Test func duplicateExerciseInDayIsReported()   // modèle de test : même id deux fois dans un jour → une issue .duplicateExerciseInDay
@Test func duplicateRiskAreaIsReported()        // exercice de test avec [.knees, .knees] → une issue .riskAreas
@Test func runTypeAndFocusHaveFrenchNames()     // les trois RunType et les trois TrainingFocus ont les libellés ci-dessus
```
`ContentLibraryTests` : `contentVersion == "1.1.0"`.

- [ ] **Step 2 : Lancer, constater l'échec**

Run : `swift test --package-path Packages/PulseContent`
Expected : FAIL (règles et libellés inconnus, `riskAreas` vides, version 1.0.0).

- [ ] **Step 3 : Implémenter**

Ajouter `"riskAreas"` dans `exercises.json` pour les 21 exercices du tableau (à la suite de `"alternatives"`), passer `contentVersion` à `1.1.0`, corriger l'ordre des alternatives du curl pupitre machine, puis règles, libellés et ressources selon les Interfaces.

- [ ] **Step 4 : Vérifier**

Run : `swift test --package-path Packages/PulseContent`
Expected : tout vert, `ContentValidator.issues(in: .bundled)` toujours vide.

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulseContent
git commit -m "feat(content): tag exercise risk areas, validate duplicate exercises per day and keep programs in a subdirectory"
```

---

### Task 5 : Design system — tokens, formats et composants de base

**Files:**
- Create (dans `Packages/PulseDesignSystem/Sources/PulseDesignSystem/`) : `Tokens/PulseRGBA.swift`, `Tokens/PulsePalette.swift`, `Tokens/PulseMetrics.swift`, `Theme/PulseThemeKey.swift`, `Presentation/RecoveryCategory+Presentation.swift`, `Presentation/FocusSplit.swift`, `Presentation/PulseFormat.swift`, `Components/Cards.swift`, `Components/ButtonStyles.swift`, `Components/ChoicePills.swift`, `Components/WeekdayToggleRow.swift`, `Components/FocusSlider.swift`, `Components/StepProgressBar.swift`, `Components/CategoryBadge.swift`, `Components/ComingSoonView.swift`, `Components/AuraBackground.swift`, `Platform/PlatformModifiers.swift`
- Delete: `PulseDesignSystem.swift` (squelette)
- Test: `Packages/PulseDesignSystem/Tests/PulseDesignSystemTests/PaletteTests.swift`, `PresentationTests.swift`, `PulseFormatTests.swift`

**Interfaces:**
- Produces :
  - `struct PulseRGBA: Equatable, Sendable { red, green, blue, opacity: Double; init(hex: UInt32, opacity: Double = 1) }` et `Color(_ rgba: PulseRGBA)`.
  - `enum PulsePalette` : constantes `PulseRGBA` et `Color` de la spec M3 §6.1 (`page`, `background`, `surface`, `surface2`, `line`, `text`, `text2`, `muted`, `opal`, `opalInk`, `opalMuted`, `opalLine`, `opalOK`, `opalWarn`, `opalBad`, `ok`, `warn`, `bad`, `run`, `gold`, `muscleBody` #262932, `muscleOff` #3A3F4B) ; `struct AccentPalette { accent, accent2, accentInk: PulseRGBA; softOpacity: Double }` ; `static func accent(for theme: Theme) -> AccentPalette` (ambre #F59E0B / #EA580C / #1A1206 / 0,16 ; améthyste #A855F7 / #6366F1 / #FFFFFF / 0,18).
  - `enum PulseMetrics { radius = 22, radiusSmall = 14, radiusTiny = 10, minButtonHeight = 50, spacing = 16 }`.
  - `EnvironmentValues.pulseTheme: Theme` (défaut `.amber`).
  - `enum CategoryTone { positive, caution, critical }` ; `RecoveryCategory.localizedName` (« Forme optimale », « Forme normale », « Fatigue modérée », « Surmenage ») et `.tone` (optimal et normal → positive, fatigue → caution, surmenage → critical) ; `CategoryTone.color(onOpal: Bool) -> Color`.
  - `enum FocusSplit { static func label(focus: Double) -> String }` (« force / endurance » en pourcentages arrondis).
  - `enum PulseFormat` : `duration(minutes: Int) -> String`, `signedPercent(_ value: Double) -> String`, `signedInteger(_ value: Double, unit: String) -> String`, `integer(_ value: Double, unit: String?) -> String`. Signe moins U+2212.
  - Vues : `OpalCard<Content>`, `ObsidianCard<Content>` (verre `glassEffect` teinté `surface`), `PrimaryButtonStyle`, `SecondaryButtonStyle`, `LinkButtonStyle`, `ChoicePills<Value: Hashable>(options: [(value: Value, label: String)], selection: Binding<Value?>)` et `MultiChoicePills<Value: Hashable>(…, selection: Binding<Set<Value>>)`, `WeekdayToggleRow(selection: Binding<Set<Weekday>>)`, `FocusSlider(focus: Binding<Double>)`, `StepProgressBar(current: Int, total: Int)`, `CategoryBadge(category: RecoveryCategory, marker: String?)`, `ComingSoonView(title: String, milestone: String)`, `AuraBackground` (dégradé de `--aura`), `View.pulseNumericKeyboard()`, `View.pulseInlineTitle()`, `enum PulseHaptics { static func selection() }`.
  - La sparkline et la jauge linéaire de charge de la spec M3 §6.2 arrivent avec le plan M3b, qui en a besoin.

- [ ] **Step 1 : Écrire les tests**

```swift
@Test func hexBecomesComponents() {
    let amber = PulseRGBA(hex: 0xF59E0B)
    #expect(amber.red == 245.0 / 255 && amber.green == 158.0 / 255 && amber.blue == 11.0 / 255 && amber.opacity == 1)
}
@Test func accentFollowsTheme()          // accent(for: .amber).accent == PulseRGBA(hex: 0xF59E0B) ; .amethyst → 0xA855F7, ink 0xFFFFFF
@Test func categoryNamesAndTones()       // les 4 libellés exacts ci-dessus ; optimal.tone == .positive ; overreached.tone == .critical
@Test func focusSplitLabels() {
    #expect(FocusSplit.label(focus: 0.4) == "60 / 40")
    #expect(FocusSplit.label(focus: 0) == "100 / 0")
    #expect(FocusSplit.label(focus: 1) == "0 / 100")
    #expect(FocusSplit.label(focus: 0.55) == "45 / 55")
}
@Test func durations() {
    #expect(PulseFormat.duration(minutes: 310) == "5 h 10")
    #expect(PulseFormat.duration(minutes: 425) == "7 h 05")
    #expect(PulseFormat.duration(minutes: 480) == "8 h")
    #expect(PulseFormat.duration(minutes: 45) == "45 min")
}
@Test func signedValues() {
    #expect(PulseFormat.signedPercent(-18.4) == "\u{2212}18 %")
    #expect(PulseFormat.signedPercent(3) == "+3 %")
    #expect(PulseFormat.signedPercent(0.2) == "0 %")
    #expect(PulseFormat.signedInteger(5, unit: "bpm") == "+5 bpm")
    #expect(PulseFormat.signedInteger(-3.4, unit: "bpm") == "\u{2212}3 bpm")
    #expect(PulseFormat.integer(44.4, unit: "ms") == "44 ms")
}
```

- [ ] **Step 2 : Lancer, constater l'échec**

Run : `swift test --package-path Packages/PulseDesignSystem`
Expected : FAIL à la compilation.

- [ ] **Step 3 : Implémenter les Interfaces**

Apparence d'après le CSS de `maquette.html` (`.btn`, `.chip`, `.card`, `.opal`, classes des écrans `objectifs` et `profil-init`). Chaque composant : un `#Preview` sur fond `background`, une étiquette VoiceOver (pilules : `.isSelected` en trait). `ChoicePills` et `WeekdayToggleRow` appellent `PulseHaptics.selection()` au changement.

- [ ] **Step 4 : Vérifier**

Run : `swift test --package-path Packages/PulseDesignSystem && swiftlint lint --strict`
Expected : vert, 0 violation.

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulseDesignSystem
git commit -m "feat(design): add tokens, formats and base components from the mockup"
```

---

### Task 6 : Design system — jauge de récupération

**Files:**
- Create: `Packages/PulseDesignSystem/Sources/PulseDesignSystem/Gauge/GaugeGeometry.swift`, `Gauge/RecoveryGauge.swift`
- Test: `Packages/PulseDesignSystem/Tests/PulseDesignSystemTests/GaugeGeometryTests.swift`

**Interfaces:**
- Consumes : `PulsePalette`, `RecoveryCategory.localizedName` (tâche 5).
- Produces :
  - `enum GaugeGeometry { static let startDegrees = 150.0; static let sweepDegrees = 240.0; static let thresholdFractions: [Double]; static func angle(for score: Double) -> Angle; static func point(for score: Double, in rect: CGRect, lineWidth: CGFloat) -> CGPoint }` : angle = 150° + 240° × score / 100, score borné à 0…100, angles SwiftUI (0° à 3 h, sens horaire) ; seuils 40 / 65 / 90 → 0,40 / 0,65 / 0,90.
  - `RecoveryGauge(score: Double?, category: RecoveryCategory?, style: RecoveryGauge.Style)` avec `Style { large, compact }` : arc filaire en dégradé angulaire rouge (`bad`) → ambre (`warn`) → vert (`ok`), repère circulaire au score, score entier au centre et « sur 100 » (style large), « — » sans score ; animation d'apparition sauf `accessibilityReduceMotion`. `static func accessibilityLabel(score: Double?, category: RecoveryCategory?) -> String`.

- [ ] **Step 1 : Écrire les tests**

```swift
@Test func anglesCoverTheArc() {
    #expect(GaugeGeometry.angle(for: 0).degrees == 150)
    #expect(GaugeGeometry.angle(for: 50).degrees == 270)
    #expect(GaugeGeometry.angle(for: 100).degrees == 390)
    #expect(GaugeGeometry.angle(for: -5).degrees == 150)
    #expect(GaugeGeometry.angle(for: 120).degrees == 390)
}
@Test func midScoreSitsAtTheTop() {
    let point = GaugeGeometry.point(for: 50, in: CGRect(x: 0, y: 0, width: 200, height: 200), lineWidth: 10)
    #expect(abs(point.x - 100) < 0.001 && abs(point.y - 5) < 0.001)   // rayon = 100 - lineWidth / 2
}
@Test func accessibilityLabelNamesTheCategory() {
    #expect(RecoveryGauge.accessibilityLabel(score: 58.4, category: .moderateFatigue) == "Récupération 58 sur 100, fatigue modérée")
    #expect(RecoveryGauge.accessibilityLabel(score: nil, category: nil) == "Récupération pas encore calculée")
}
```

- [ ] **Step 2 : Lancer, constater l'échec** — Run : `swift test --package-path Packages/PulseDesignSystem` ; Expected : FAIL à la compilation.

- [ ] **Step 3 : Implémenter les Interfaces**, avec un `#Preview` par style et pour 12, 58, 94 et `nil`.

- [ ] **Step 4 : Vérifier** — Run : `swift test --package-path Packages/PulseDesignSystem` ; Expected : vert.

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulseDesignSystem
git commit -m "feat(design): add the wire recovery gauge"
```

---

### Task 7 : Design system — lecteur de tracés SVG

**Files:**
- Create: `Packages/PulseDesignSystem/Sources/PulseDesignSystem/MuscleMap/SVGPathParser.swift`, `MuscleMap/SVGArc.swift`
- Test: `Packages/PulseDesignSystem/Tests/PulseDesignSystemTests/SVGPathParserTests.swift`

**Interfaces:**
- Produces : `enum SVGPathParser { static func parse(_ data: String) throws -> Path }` et `enum SVGPathError: Error, Equatable { case unexpectedCharacter(Character, offset: Int), missingNumber(command: Character, offset: Int) }`. Commandes `M m L l H h V v C c Q q A a Z z`, répétition implicite (après `M`, les paires suivantes sont des `L`), nombres `-.5`, `1e-3`, `0.35,0.35`, drapeaux d'arc collés (`a1 1 0 011 1`). `SVGArc.cubicSegments(from: CGPoint, to: CGPoint, rx: Double, ry: Double, rotation: Double, largeArc: Bool, sweep: Bool) -> [(CGPoint, CGPoint, CGPoint)]` (conversion standard extrémités → centre de la recommandation SVG 1.1, annexe F.6, découpage par quarts au plus).

- [ ] **Step 1 : Écrire les tests**

```swift
@Test func absoluteSquare() throws {
    #expect(try SVGPathParser.parse("M0,0 L10,0 L10,10 L0,10 Z").boundingRect == CGRect(x: 0, y: 0, width: 10, height: 10))
}
@Test func relativeAndImplicitCommands() throws {
    #expect(try SVGPathParser.parse("m 5 5 10 0 v 10 h -10 z").boundingRect == CGRect(x: 5, y: 5, width: 10, height: 10))
}
@Test func cubicAndQuadraticStayInsideControlHull() throws {
    let rect = try SVGPathParser.parse("M0,0 C0,10 10,10 10,0 Q15,-10 20,0").boundingRect
    #expect(rect.minX >= 0 && rect.maxX <= 20 && rect.minY >= -10 && rect.maxY <= 10)
}
@Test func halfCircleArc() throws {
    let rect = try SVGPathParser.parse("M0,0 a5,5 0 0 1 10,0").boundingRect
    #expect(abs(rect.width - 10) < 0.01 && abs(rect.height - 5) < 0.05)
}
@Test func compactArcFlags() throws {
    #expect(try SVGPathParser.parse("M0,0 a5 5 0 0110 0").boundingRect.width > 9.9)
}
@Test func garbageThrows() {
    #expect(throws: SVGPathError.self) { try SVGPathParser.parse("M0,0 L10") }
    #expect(throws: SVGPathError.self) { try SVGPathParser.parse("M0,0 X5,5") }
}
```

- [ ] **Step 2 : Lancer, constater l'échec** — Run : `swift test --package-path Packages/PulseDesignSystem` ; Expected : FAIL à la compilation.

- [ ] **Step 3 : Implémenter les Interfaces** (lexeur en un passage sur les `UnicodeScalar`, un fichier par responsabilité, corps de fonction ≤ 50 lignes).

- [ ] **Step 4 : Vérifier** — Run : `swift test --package-path Packages/PulseDesignSystem` ; Expected : vert.

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulseDesignSystem
git commit -m "feat(design): add an SVG path parser for the muscle map"
```

---

### Task 8 : Design system — carte musculaire

**Files:**
- Create: `scripts/extract_musclemap.py`, `Packages/PulseDesignSystem/Sources/PulseDesignSystem/Resources/musclemap.json`, `MuscleMap/MuscleMapRegion.swift`, `MuscleMap/MuscleMapArtwork.swift`, `MuscleMap/MuscleIntensity.swift`, `MuscleMap/MuscleMapView.swift`
- Test: `Packages/PulseDesignSystem/Tests/PulseDesignSystemTests/MuscleMapTests.swift`

**Interfaces:**
- Consumes : `SVGPathParser` (tâche 7), `PulsePalette`, `PulsePalette.accent(for:)` (tâche 5).
- Produces :
  - `scripts/extract_musclemap.py <maquette.html> <sortie.json>` (lancé par `python3 -I`) : lit les symboles `body-front` et `body-back`, écrit `{"license": "<texte MIT de maquette.html>", "front": {"viewBox": [0, 0, 650, 1450], "body": ["d", …], "regions": {"chest": ["d", …], …}}, "back": {"viewBox": [823, 0, 650, 1450], …}}`. Un groupe `fill:var(--mm-body)` va dans `body` ; un groupe `fill:var(--mm-<nom>, …)` va dans `regions[<nom>]`.
  - `enum MuscleMapRegion: String, CaseIterable, Sendable` : les 31 noms de régions de la maquette (`abs`, `adductors`, `biceps`, `calves`, `chest`, `deltoids`, `forearm`, `frontDeltoid`, `gluteal`, `hamstring`, `hipFlexors`, `innerQuad`, `lowerAbs`, `lowerBack`, `lowerChest`, `lowerTrapezius`, `obliques`, `outerQuad`, `quadriceps`, `rearDeltoid`, `rhomboids`, `rotatorCuff`, `serratus`, `tibialis`, `trapezius`, `triceps`, `upperAbs`, `upperBack`, `upperChest`, `upperTrapezius`), avec `isOverlay: Bool` (vrai pour celles dont le repli est `transparent` dans la maquette : dessinées seulement quand elles sont allumées).
  - `extension Muscle { var mapRegions: [MuscleMapRegion] }` : table de la spec M3 §6.3.
  - `enum MuscleMapSide { front, back }` ; `struct MuscleMapArtwork: Sendable { static let bundled: MuscleMapArtwork; func body(_ side: MuscleMapSide) -> [Path]; func regions(_ side: MuscleMapSide) -> [MuscleMapRegion: [Path]]; func viewBox(_ side: MuscleMapSide) -> CGRect; let license: String }` (tracés lus et parsés une fois).
  - `enum MuscleIntensity { static func levels(weights: [Muscle: Double]) -> [MuscleMapRegion: Int] }` : pour chaque muscle de poids > 0, niveau = `max(1, ceil(poids / poidsMax × 4))` ; une région reçoit le niveau le plus haut des muscles qui la couvrent.
  - `MuscleMapView(levels: [MuscleMapRegion: Int], label: String, height: CGFloat)` : face et dos côte à côte, corps en `muscleBody`, régions de base éteintes en `muscleOff`, niveau n en mélange accent / `muscleOff` à 32, 56, 80, 100 % ; `accessibilityElement(children: .ignore)` avec `label`.

- [ ] **Step 1 : Extraire les tracés**

Run : `python3 -I scripts/extract_musclemap.py maquette.html Packages/PulseDesignSystem/Sources/PulseDesignSystem/Resources/musclemap.json && python3 -I -c "import json,sys; d=json.load(open(sys.argv[1])); print(len(d['front']['regions']), len(d['back']['regions']))" Packages/PulseDesignSystem/Sources/PulseDesignSystem/Resources/musclemap.json`
Expected : deux nombres non nuls, dont la somme des régions distinctes couvre les 31 noms.

- [ ] **Step 2 : Écrire les tests**

```swift
@Test func everyMuscleHasARegion() { for muscle in Muscle.allCases { #expect(!muscle.mapRegions.isEmpty) } }
@Test func lowerBodyMappings() {
    #expect(Muscle.glutes.mapRegions == [.gluteal] && Muscle.abductors.mapRegions == [.gluteal])
    #expect(Muscle.lats.mapRegions == [.upperBack] && Muscle.frontDelts.mapRegions == [.frontDeltoid])
}
@Test func artworkParsesAndCoversMappedRegions() {
    let art = MuscleMapArtwork.bundled
    let drawn = Set(art.regions(.front).keys).union(art.regions(.back).keys)
    #expect(Set(Muscle.allCases.flatMap(\.mapRegions)).isSubset(of: drawn))
    #expect(!art.body(.front).isEmpty && !art.body(.back).isEmpty)
    #expect(art.license.contains("MIT"))
}
@Test func intensityQuarters() {
    let levels = MuscleIntensity.levels(weights: [.chest: 4, .triceps: 3, .frontDelts: 1.5, .abs: 0])
    #expect(levels == [.chest: 4, .triceps: 3, .frontDeltoid: 2])
}
@Test func sharedRegionTakesTheHighestLevel() {
    #expect(MuscleIntensity.levels(weights: [.glutes: 4, .abductors: 1])[.gluteal] == 4)
}
```

- [ ] **Step 3 : Lancer, constater l'échec** — Run : `swift test --package-path Packages/PulseDesignSystem` ; Expected : FAIL à la compilation.

- [ ] **Step 4 : Implémenter les Interfaces**, avec un `#Preview` (séance Push : chest 4, triceps 3, frontDeltoid 2).

- [ ] **Step 5 : Vérifier** — Run : `swift test --package-path Packages/PulseDesignSystem && swiftlint lint --strict` ; Expected : vert.

- [ ] **Step 6 : Commit**

```bash
git add scripts Packages/PulseDesignSystem
git commit -m "feat(design): add the MuscleMap front and back muscle map"
```

---

### Task 9 : Services — fausse source Apple Santé, doublures, historique des nuits, options de lancement

**Files:**
- Create (dans `Packages/PulseFeatures/Sources/PulseServices/`) : `Health/HealthScenario.swift`, `Health/ScenarioHealthSource.swift`, `Health/NightHistory.swift`, `Health/CachedSampleMapping.swift`, `Doubles/InMemoryRepositories.swift`, `Doubles/InMemoryHealthSampleCache.swift`, `Doubles/FailingHealthSource.swift`, `App/LaunchOptions.swift`
- Test: `Packages/PulseFeatures/Tests/PulseServicesTests/Support/TestClock.swift`, `ScenarioTests.swift`, `NightHistoryTests.swift`, `LaunchOptionsTests.swift`

**Interfaces:**
- Consumes : `HealthSampleSource`, `HealthProfileHints` (tâche 2), `HealthSampleCache`, `NightAggregator`, `RecoveryCalculator`.
- Produces :
  - `enum HealthScenario: String, CaseIterable, Sendable { goodNight, badNight, missingHRV, threeNights, noData }`.
  - `struct ScenarioHealthSource: HealthSampleSource { init(scenario: HealthScenario, now: Date, calendar: Calendar) }` : 60 nuits déterministes finissant au jour de `now`. Historique : sommeil 23 h → 7 h (480 min dont 96 min de profond, phases `core` / `deep` / `rem`), SDNN `50 + 2 × ((i mod 5) − 2)` ms en trois échantillons à 1 h, 3 h et 5 h, FC repos `50 + ((i mod 3) − 1)` à 7 h 30. Nuit du jour : `goodNight` SDNN 56, FC 48, 480 / 96 ; `badNight` SDNN 46, FC 55, 310 min dont 22 de profond ; `missingHRV` comme `goodNight` sans SDNN ; `threeNights` seulement les trois dernières nuits ; `noData` rien. Indices de profil : `.male`, 14/03/1998, 178 cm, 74,5 kg (vides pour `noData`). Les valeurs du jour peuvent être ajustées si le test l'exige ; le test fait foi.
  - Doublures publiques (acteurs) : `InMemoryProfileRepository`, `InMemoryProgramRepository`, `InMemoryRecoveryRepository(calendar:)` (un enregistrement par jour normalisé, comme la persistance), `InMemoryHealthSampleCache` ; `struct FailingHealthSource: HealthSampleSource` (toute méthode lance `FailingHealthSource.Failure.unavailable`).
  - `struct NightHistorySnapshot: Sendable, Equatable { nights: [NightSample]; readAt: Date? }` et `struct NightHistory: Sendable { static let historyDays = 60; init(source:cache:calendar:); func refresh(now: Date, progress: @Sendable (Double) -> Void = { _ in }) async -> NightHistorySnapshot }` : lit SDNN, FC repos et sommeil de `[minuit du jour − 60 j, minuit du lendemain)`, remplace le cache pour `.sdnn`, `.restingHeartRate`, `.sleep`, signale 1/4, 2/4, 3/4 après chaque lecture et 1 à la fin, rend 60 nuits (la plus ancienne d'abord, le jour de `now` en dernier) agrégées par `NightAggregator`. Si une lecture échoue : nuits reconstruites depuis le cache, `readAt == nil`, cache intact.
  - `struct LaunchOptions: Sendable, Equatable { storeInMemory: Bool; healthScenario: HealthScenario?; fixedNow: Date?; static func parse(_ arguments: [String]) -> LaunchOptions }` : `-PulseStore inMemory`, `-PulseHealthScenario <nom>`, `-PulseNow <ISO 8601>` ; valeur inconnue ignorée.

- [ ] **Step 1 : Écrire les tests**

```swift
// TestClock : calendar (grégorien, Europe/Paris, fr_FR) ; date("2026-11-02T08:00") en heure de Paris.
@Test(arguments: HealthScenario.allCases) func scenarioOutcome(_ scenario: HealthScenario) async throws {
    let now = TestClock.date("2026-11-02T08:00")
    let source = ScenarioHealthSource(scenario: scenario, now: now, calendar: TestClock.calendar)
    let snapshot = await NightHistory(source: source, cache: InMemoryHealthSampleCache(), calendar: TestClock.calendar).refresh(now: now)
    let outcome = RecoveryCalculator(calendar: TestClock.calendar)
        .compute(day: TestClock.calendar.startOfDay(for: now), today: try #require(snapshot.nights.last), history: snapshot.nights.dropLast())
    switch scenario {
    case .goodNight: #expect(outcome.measured?.category == .optimal && outcome.measured?.calibration == .ready)
    case .badNight: #expect(outcome.measured?.category == .moderateFatigue)
    case .missingHRV: #expect(outcome.measured?.missing == [.hrv])
    case .threeNights, .noData: #expect(outcome.isCheckIn)
    }
}   // `measured` / `isCheckIn` : petites extensions de test sur RecoveryOutcome
@Test func refreshReturnsSixtyNightsEndingToday() async     // nights.count == 60 ; last.day == minuit du 2 novembre ; readAt == now
@Test func refreshReplacesTheCache() async throws           // deux refresh → cache.samples(kind: .sdnn, …).count identique (pas de doublons)
@Test func failedReadFallsBackToCache() async throws        // refresh goodNight, puis NightHistory(source: FailingHealthSource(), même cache)
                                                            // → readAt == nil, nights.last?.sdnnMs == 56
@Test func progressEndsAtOne() async                         // valeurs reçues == [0.25, 0.5, 0.75, 1]
@Test func launchOptionsParse() {
    let options = LaunchOptions.parse(["Pulse", "-PulseStore", "inMemory", "-PulseHealthScenario", "badNight", "-PulseNow", "2026-11-02T08:00:00+01:00"])
    #expect(options.storeInMemory && options.healthScenario == .badNight && options.fixedNow != nil)
    #expect(LaunchOptions.parse(["Pulse", "-PulseHealthScenario", "nope"]).healthScenario == nil)
}
```

- [ ] **Step 2 : Lancer, constater l'échec** — Run : `swift test --package-path Packages/PulseFeatures` ; Expected : FAIL à la compilation.

- [ ] **Step 3 : Implémenter les Interfaces**

- [ ] **Step 4 : Vérifier** — Run : `swift test --package-path Packages/PulseFeatures` ; Expected : vert.

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulseFeatures
git commit -m "feat(services): add scenario health source, in-memory doubles, night history and launch options"
```

---

### Task 10 : Services — score du jour et son cycle de vie

**Files:**
- Create: `Packages/PulseFeatures/Sources/PulseServices/Score/TodayScore.swift`, `Score/DailyScoreService.swift`, `Score/DailyRecovery+Result.swift`
- Test: `Packages/PulseFeatures/Tests/PulseServicesTests/DailyScoreServiceTests.swift`

**Interfaces:**
- Consumes : `RecoveryRepository`, `RecoveryCalculator`, `CheckInScorer`, doublures et `ScenarioHealthSource` (tâche 9).
- Produces :
  - `enum TodayScore: Sendable, Equatable { case beforeDayStart(yesterday: DailyRecovery?); case scored(DailyRecovery); case needsCheckIn(missing: [Factor]) }`.
  - `enum DailyScoreError: Error, Equatable { case frozen }`.
  - `struct DailyScoreService: Sendable { static let dayStartHour = 4; static let freezeHour = 12; init(recovery: any RecoveryRepository, calendar: Calendar); func update(nights: [NightSample], now: Date) async throws -> TodayScore; func saveCheckIn(_ answers: CheckInAnswers, now: Date) async throws -> DailyRecovery }`.
  - `extension DailyRecovery { init(result: RecoveryResult, night: NightSample, now: Date) }` : sous-scores, valeurs du jour et lignes de base depuis `result.factors`, `asleepMinutes` / `deepMinutes` depuis la nuit, `missingFactors`, `calibration`, `adjustments: []`.

Règles de `update` (spec M3 §9.2), avec `hour = calendar.component(.hour, from: now)` et `day = calendar.startOfDay(for: now)` :
1. `hour < 4` → `.beforeDayStart(yesterday:)` (enregistrement de la veille ou `nil`), rien n'est écrit.
2. Un score du jour figé → `.scored(lui)`, rien n'est recalculé.
3. Calcul sur la nuit du jour (`nights` dont `day` est le jour) et l'historique (les autres).
4. Avant midi : mesuré → enregistré (remplace un estimé ou un mesuré) ; check-in demandé → l'existant s'il y en a un, sinon `.needsCheckIn(missing:)`.
5. À partir de midi : un existant non figé est figé tel quel (`frozenAt = now`), sans recalcul ; sans existant, un mesuré est enregistré figé ; sinon `.needsCheckIn(missing:)`.

`saveCheckIn` : lance `.frozen` si le jour est figé ; enregistre un `CheckIn` et un `DailyRecovery` estimé (`isEstimated: true`, score `CheckInScorer.score`, `missingFactors: Factor.allCases`, `calibration: .calibrating(nights: 0)`), figé si `hour >= 12`.

- [ ] **Step 1 : Écrire les tests**

```swift
@Test func before4amReturnsYesterday() async throws          // veille enregistrée ; update à 03:59 → .beforeDayStart(yesterday: veille), rien d'écrit aujourd'hui
@Test func morningMeasuredScoreIsSaved() async throws        // goodNight à 08:00 → .scored(optimal) et un enregistrement du jour, frozenAt nil
@Test func newDataBeforeNoonRecomputes() async throws        // badNight à 07:00 puis goodNight à 09:00 → un seul enregistrement, catégorie optimal
@Test func measuredReplacesCheckInBeforeNoon() async throws  // saveCheckIn à 07:00 puis update goodNight à 08:00 → isEstimated == false
@Test func noonFreezesTheExistingScore() async throws        // badNight à 08:00 puis goodNight à 12:00 → catégorie moderateFatigue, frozenAt == 12:00
@Test func afterNoonWithoutScoreSavesAFrozenMeasure() async throws   // goodNight à 14:00 → frozenAt == 14:00
@Test func afterNoonCheckInStaysOpenThenFreezes() async throws       // threeNights à 14:00 → .needsCheckIn ; saveCheckIn → frozenAt == 14:00
@Test func frozenDayRejectsCheckIn() async throws             // après figement : #expect(throws: DailyScoreError.frozen)
@Test func insufficientDataNeedsCheckIn() async throws        // noData à 08:00 → .needsCheckIn(missing: [.hrv, .restingHeartRate, .sleep])
@Test func measuredRecoveryCarriesRawValues() async throws    // goodNight : sdnnMs 56, restingHeartRate 48, asleepMinutes 480, deepMinutes 96,
                                                              // sdnnBaselineMs et restingHeartRateBaseline non nuls, calibration .ready
@Test func dayStartAndFreezeFollowTheCalendarOnDSTDay() async throws
    // 25/10/2026 (25 h) : update à 03:59 → .beforeDayStart ; à 04:00 → .scored ; à 12:00 → figé ; day == minuit du 25 octobre
```

- [ ] **Step 2 : Lancer, constater l'échec** — Run : `swift test --package-path Packages/PulseFeatures --filter DailyScoreServiceTests` ; Expected : FAIL à la compilation.

- [ ] **Step 3 : Implémenter les Interfaces**

- [ ] **Step 4 : Vérifier** — Run : `swift test --package-path Packages/PulseFeatures` ; Expected : vert.

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulseFeatures
git commit -m "feat(services): add the daily score service with 4 am start and noon freeze"
```

---

### Task 11 : Services — recommandation et adoption de programme

**Files:**
- Create: `Packages/PulseFeatures/Sources/PulseServices/Program/TemplateRecommender.swift`, `Program/ProgramAdopter.swift`, `Program/WeekLayoutArranger.swift`, `Program/EquipmentAccess+Allowed.swift`, `Program/TrainingLevel+Increments.swift`
- Test: `Packages/PulseFeatures/Tests/PulseServicesTests/TemplateRecommenderTests.swift`, `ProgramAdopterTests.swift`, `WeekLayoutArrangerTests.swift`

**Interfaces:**
- Consumes : `ContentLibrary`, `Program(template:now:)`, `Exercise.riskAreas` (tâches 2 et 4).
- Produces :
  - `enum TemplateRecommender { static func focus(for value: Double) -> TrainingFocus; static func recommendedID(focus: Double, daysPerWeek: Int, templates: [ProgramTemplate]) -> String? }` : `< 0,35` force, `> 0,65` endurance, sinon équilibré ; parmi les modèles du focus, le premier dont `daysPerWeek` contient le nombre, sinon celui dont le jour le plus proche est le plus près ; sans modèle du focus, le premier modèle.
  - `extension EquipmentAccess { var allowedEquipment: Set<Equipment> }` : salle complète = tout ; home gym = `dumbbell`, `kettlebell`, `band`, `bodyweight` ; poids du corps = `bodyweight`.
  - `extension TrainingLevel { var defaultIncrementsKg: (upper: Double, lower: Double) }` : débutant et intermédiaire (2,5 ; 5), confirmé (1,25 ; 2,5).
  - `struct ProgramAdopter: Sendable { init(library: ContentLibrary); func adopt(_ template: ProgramTemplate, equipment: EquipmentAccess, painAreas: [PainArea], restWeekdays: [Weekday], now: Date) -> Program; func substitute(_ exerciseID: String, equipment: EquipmentAccess, painAreas: [PainArea], excluding used: Set<String>) -> String }` : remplacement si le matériel n'est pas permis ou si `riskAreas` croise `painAreas` ; candidats dans l'ordre : `alternatives`, puis exercices actifs du même `pattern` dans l'ordre du contenu ; acceptable = matériel permis, aucun risque déclaré, non retiré, pas déjà utilisé dans le jour ; sinon l'exercice d'origine. `sessionsPerWeek` = nombre de jours placés dans la semaine.
  - `enum WeekLayoutArranger { static func arrange(_ layout: [UUID?], restWeekdays: [Weekday]) -> [UUID?] }` : parcours lundi → dimanche ; chaque séance va au premier jour libre et non imposé en repos à partir de son jour, en bouclant ; sans place, elle quitte la semaine.

- [ ] **Step 1 : Écrire les tests**

```swift
@Test func recommendations() {
    let templates = ContentLibrary.bundled.programTemplates
    #expect(TemplateRecommender.recommendedID(focus: 0.2, daysPerWeek: 3, templates: templates) == "ppl-3")
    #expect(TemplateRecommender.recommendedID(focus: 0.2, daysPerWeek: 6, templates: templates) == "ppl-6")
    #expect(TemplateRecommender.recommendedID(focus: 0.5, daysPerWeek: 4, templates: templates) == "upper-lower")
    #expect(TemplateRecommender.recommendedID(focus: 0.9, daysPerWeek: 3, templates: templates) == "runner-strength")
}
@Test func fullGymWithoutConstraintsCopiesTheTemplate() {
    // ppl-3, .fullGym, [], [] → mêmes exercices que Program(template:now:), weekLayout lundi / mercredi / vendredi, sessionsPerWeek 3
}
@Test func homeGymReplacesMachinesWithoutDuplicates() {
    // ppl-3 jour push en .homeGym → ["bench-press-dumbbell", "incline-bench-press-dumbbell", "dumbbell-fly", "dips",
    //                               "wrist-curl-cable", "reverse-crunch"]   (wrist-curl-cable : aucune alternative permise, gardé)
}
@Test func shoulderPainReplacesDips()                 // substitute("dips", .fullGym, [.shoulders], []) == "close-grip-bench-press"
@Test func noAcceptableAlternativeKeepsOriginal()     // substitute("overhead-press-barbell", .fullGym, [.shoulders], []) == "overhead-press-barbell"
@Test func usedExercisesAreSkipped()                  // substitute("chest-press-machine", .homeGym, [], ["bench-press-dumbbell"]) == "incline-bench-press-dumbbell"
@Test func restDaysSlideSessionsForward() {
    // [A, nil, B, nil, C, nil, nil], repos mercredi et dimanche → [A, nil, nil, B, C, nil, nil]
}
@Test func slidingWrapsAroundTheWeek()                // [A, nil, B, nil, C, nil, nil], repos vendredi, samedi, dimanche → [A, C, B, nil, nil, nil, nil]
@Test func sessionsWithoutRoomLeaveTheWeek()          // 6 séances lundi → samedi, repos samedi et dimanche → 5 placées, la 6e absente
@Test func levelIncrements()                          // .advanced → (1.25, 2.5) ; .beginner → (2.5, 5)
```

- [ ] **Step 2 : Lancer, constater l'échec** — Run : `swift test --package-path Packages/PulseFeatures` ; Expected : FAIL à la compilation.

- [ ] **Step 3 : Implémenter les Interfaces**

- [ ] **Step 4 : Vérifier** — Run : `swift test --package-path Packages/PulseFeatures` ; Expected : vert.

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulseFeatures
git commit -m "feat(services): recommend a template and adapt it to equipment, pain areas and rest days"
```

---

### Task 12 : Services — séance du jour, résumé, ligne de base, destination de lancement

**Files:**
- Create: `Packages/PulseFeatures/Sources/PulseServices/Today/Weekday+Date.swift`, `Today/TodayPlanner.swift`, `Today/SessionSummary.swift`, `Today/BaselineSummary.swift`, `App/LaunchDestination.swift`
- Test: `Packages/PulseFeatures/Tests/PulseServicesTests/TodayPlannerTests.swift`, `SessionSummaryTests.swift`, `BaselineSummaryTests.swift`, `LaunchDestinationTests.swift`

**Interfaces:**
- Consumes : `Program`, `ContentLibrary`, `HRVBaseline.isValid`, `NightSample`.
- Produces :
  - `extension Weekday { init(date: Date, calendar: Calendar); var index: Int }` (lundi = 0).
  - `struct NextSession: Sendable, Equatable { day: RoutineDay; weekday: Weekday }` ; `enum PlannedDay: Sendable, Equatable { case noProgram, rest(next: NextSession?), strength(RoutineDay), run(RoutineDay) }` ; `enum TodayPlanner { static func plan(program: Program?, on date: Date, calendar: Calendar) -> PlannedDay }` (prochaine séance : premier jour non vide après aujourd'hui, en bouclant sur 7 jours).
  - `struct SessionSummary: Sendable, Equatable { setCount: Int; estimatedMinutes: Int; maxRPE: Double; topMuscles: [Muscle]; muscleWeights: [Muscle: Double]; static func make(day: RoutineDay, library: ContentLibrary) -> SessionSummary }` : séries de travail ; poids 1 par série pour les muscles principaux, 0,5 pour les secondaires (références `.user` ignorées) ; trois premiers muscles par poids décroissant puis ordre de `Muscle.allCases` ; durée de la spec M3 §9.3 (45 s par série, repos après chaque série sauf la dernière de la séance, super set : un tour = 2 × 45 s et un seul repos, le plus long des deux), arrondie aux 5 minutes les plus proches.
  - `struct BaselineSummary: Sendable, Equatable { hrvMeanMs: Double?; hrvDeviationMs: Double?; restingHeartRateMean: Double?; restingHeartRateDeviation: Double?; sleepMeanMinutes: Int?; nightsAnalyzed: Int; static func make(nights: [NightSample], day: Date, calendar: Calendar) -> BaselineSummary }` : VFC sur les nuits 1 à 14 jours avant `day` à SDNN valide (moyenne et écart-type échantillon des ms, `nil` sous 2 valeurs), FC repos sur 1 à 7 jours, sommeil moyen arrondi sur 1 à 14 jours, `nightsAnalyzed` = nuits fournies ayant au moins un facteur.
  - `enum LaunchDestination: Sendable, Equatable { case onboarding, main; static func resolve(profile: UserProfile?) -> LaunchDestination }` (`main` si `onboardingCompletedAt` est renseigné).

- [ ] **Step 1 : Écrire les tests**

```swift
@Test func mondayOfPPL3IsPush()             // programme adopté ppl-3, 2026-11-02 → .strength(jour "Push")
@Test func sundayIsRestWithNextPush()       // 2026-11-08 → .rest(next: NextSession(jour "Push", .monday))
@Test func noProgram()                      // plan(program: nil, …) == .noProgram
@Test func runDay()                         // runner-strength, lundi → .run(jour de type .easy)
@Test func pushSummary() {
    let summary = SessionSummary.make(day: pushDayOfPPL3, library: .bundled)
    #expect(summary.setCount == 19 && summary.estimatedMinutes == 35 && summary.maxRPE == 8)
    #expect(summary.topMuscles == [.chest, .triceps, .frontDelts])
    #expect(summary.muscleWeights[.chest] == 10)
}
@Test func legsSummary()                    // jour legs de ppl-3 → setCount 20, estimatedMinutes 40, topMuscles.first == .glutes
@Test func baselineFromHandmadeNights() {
    // nuits à J-1, J-2, J-3 : SDNN 40 / 50 / 60, FC 48 / 50 / 52, sommeil 420 / 480 / nil ; nuit J-20 avec sommeil seul ; nuit du jour vide
    // → hrvMeanMs 50, hrvDeviationMs 10, restingHeartRateMean 50, restingHeartRateDeviation 2, sleepMeanMinutes 450, nightsAnalyzed 4
}
@Test func launchDestination()              // nil → .onboarding ; brouillon → .onboarding ; terminé → .main
```

- [ ] **Step 2 : Lancer, constater l'échec** — Run : `swift test --package-path Packages/PulseFeatures` ; Expected : FAIL à la compilation.

- [ ] **Step 3 : Implémenter les Interfaces**

- [ ] **Step 4 : Vérifier** — Run : `swift test --package-path Packages/PulseFeatures` ; Expected : vert.

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulseFeatures
git commit -m "feat(services): plan today's session and summarise sets, duration, muscles and baseline"
```

---

### Task 13 : Check-in

**Files:**
- Create: `Packages/PulseFeatures/Sources/CheckInFeature/CheckInQuestion.swift`, `CheckInForm.swift`, `CheckInView.swift`, `Resources/Localizable.xcstrings`
- Test: `Packages/PulseFeatures/Tests/CheckInFeatureTests/CheckInFormTests.swift`

**Interfaces:**
- Consumes : `CheckInAnswers`, `CheckInScorer`, `ChoicePills`, `OpalCard`, `RecoveryCategory.localizedName`.
- Produces :
  - `enum CheckInQuestion: CaseIterable, Sendable { sleep, pain, motivation }` avec `title` (« Ton sommeil cette nuit », « Courbatures et douleurs », « Motivation à t'entraîner ») et `options: [(label: String, value: Int)]` dans l'ordre affiché : sommeil Mauvais 0, Moyen 1, Correct 2, Bon 3, Excellent 4 ; douleurs Aucune 4, Légères 3, Modérées 2, Marquées 1, Douleur aiguë 0 ; motivation Zéro 0, Faible 1, Moyenne 2, Bonne 3, À fond 4.
  - `@MainActor @Observable final class CheckInForm { var selection: [CheckInQuestion: Int]; var answers: CheckInAnswers?; var estimatedScore: Double?; init() }` (`nil` tant qu'une question est sans réponse).
  - `CheckInView(form: CheckInForm, onSubmit: (CheckInAnswers) -> Void)` : bandeau « Pas de données de nuit » (« Montre déchargée ou non portée ? Trois questions suffisent pour estimer ta récupération. »), trois questions, carte opale « Estimation » avec le score en direct et la catégorie, bouton « Utiliser ce score aujourd'hui » désactivé tant que le formulaire est incomplet, mention « Un score estimé n'autorise jamais de surcharge progressive. »

- [ ] **Step 1 : Écrire les tests**

```swift
@Test func optionsMapToEngineValues()  // CheckInQuestion.pain.options.map(\.value) == [4, 3, 2, 1, 0] ; sleep == [0, 1, 2, 3, 4]
@Test @MainActor func incompleteFormHasNoScore() { let form = CheckInForm(); form.selection[.sleep] = 3; #expect(form.estimatedScore == nil) }
@Test @MainActor func completeFormScoresLive() {
    let form = CheckInForm()
    form.selection = [.sleep: 3, .pain: 3, .motivation: 3]
    #expect(form.estimatedScore == 75)
    #expect(form.answers == CheckInAnswers(sleep: 3, pain: 3, motivation: 3))
}
```

- [ ] **Step 2 : Lancer, constater l'échec** — Run : `swift test --package-path Packages/PulseFeatures --filter CheckInFormTests` ; Expected : FAIL à la compilation.

- [ ] **Step 3 : Implémenter les Interfaces** (aperçu vide et rempli).

- [ ] **Step 4 : Vérifier** — Run : `swift test --package-path Packages/PulseFeatures` ; Expected : vert.

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulseFeatures
git commit -m "feat(checkin): add the three-question morning check-in"
```

---

### Task 14 : Onboarding — modèle

**Files:**
- Create: `Packages/PulseFeatures/Sources/OnboardingFeature/OnboardingStep.swift`, `OnboardingStepStore.swift`, `OnboardingEnvironment.swift`, `OnboardingModel.swift`, `OnboardingModel+Calibration.swift`
- Test: `Packages/PulseFeatures/Tests/OnboardingFeatureTests/OnboardingModelTests.swift`, `Support/OnboardingFixture.swift`

**Interfaces:**
- Consumes : tâches 9 à 13.
- Produces :
  - `enum OnboardingStep: Int, CaseIterable, Sendable { welcome, health, profile, goals, program, calibration }`.
  - `protocol OnboardingStepStore: Sendable { func load() -> OnboardingStep?; func save(_ step: OnboardingStep); func clear() }` ; `struct UserDefaultsOnboardingStepStore: OnboardingStepStore { init(suiteName: String?, key: String = "onboarding.step") }` ; `final class InMemoryOnboardingStepStore: OnboardingStepStore, @unchecked Sendable` (verrou interne) pour les tests et aperçus.
  - `struct OnboardingEnvironment: Sendable { profiles: any ProfileRepository; programs: any ProgramRepository; health: any HealthSampleSource; nightHistory: NightHistory; scores: DailyScoreService; notifications: any NotificationAuthorizing; library: ContentLibrary; stepStore: any OnboardingStepStore; calendar: Calendar; now: @Sendable () -> Date }`.
  - `enum CalibrationPhase: Equatable { case idle, reading(progress: Double), scored(DailyRecovery, BaselineSummary), needsCheckIn(missing: [Factor], baseline: BaselineSummary) }`.
  - `@MainActor @Observable final class OnboardingModel` : `private(set) var step: OnboardingStep` ; `var profile: UserProfile` (brouillon) ; `private(set) var recommendedTemplateID: String?` ; `var selectedTemplateID: String?` ; `var choseCustomProgram: Bool` ; `var notifyWhenScoreReady = true` ; `private(set) var calibration: CalibrationPhase` ; `let checkIn: CheckInForm` ; `private(set) var isFinished: Bool` ; `private(set) var errorMessage: String?` ; `var weekProposal: (strength: Int, runs: Int)` (séances de muscu = `round(jours × (1 − focus))`, le reste en sorties) ; méthodes `start()`, `begin()`, `allowHealth()`, `skipHealth()`, `continueFromProfile()`, `continueFromGoals()`, `adoptProgram()`, `runCalibration()`, `submitCheckIn()`, `finish()`, `goBack()`, `checkForRestoredProfile() -> Bool` (toutes `async` sauf `goBack`).

Comportement :
- `start()` : si un profil terminé existe → `isFinished = true`. Sinon reprend `stepStore.load() ?? .welcome` et le brouillon (`profiles.load()`), sinon un `UserProfile` neuf (`createdAt = now()`).
- Chaque transition enregistre le brouillon (`profiles.save`) et l'étape (`stepStore.save`).
- `allowHealth()` : `health.requestAuthorization()` (erreur → message, on avance quand même), puis `profileHints()` qui ne remplit que les champs vides (sexe seulement s'il vaut `.unspecified`). `skipHealth()` retient que la lecture est ignorée (calibration directe en check-in).
- `continueFromProfile()` : incréments `strengthLevel.defaultIncrementsKg` dans `upperIncrementKg` / `lowerIncrementKg`.
- `continueFromGoals()` : `recommendedTemplateID` et `selectedTemplateID` par `TemplateRecommender`.
- `adoptProgram()` : supprime le programme adopté plus tôt dans ce parcours (`profile.activeProgramID`, via `programs.delete(id:)`), puis adopte par `ProgramAdopter` (ou `activeProgramID = nil` pour « Je construis le mien »), enregistre, passe à `.calibration` et lance `runCalibration()`.
- `runCalibration()` : Apple Santé ignoré → `.needsCheckIn` sans lecture ; sinon `.reading(progress:)` mis à jour par `nightHistory.refresh`, puis `scores.update` → `.scored` ou `.needsCheckIn`, avec `BaselineSummary.make`.
- `submitCheckIn()` : `scores.saveCheckIn(checkIn.answers)` → `.scored`.
- `finish()` : si `notifyWhenScoreReady`, demande l'autorisation ; `morningScoreNotification = notifyWhenScoreReady && accordé` ; `onboardingCompletedAt = now()` ; `stepStore.clear()` ; `isFinished = true`.
- `checkForRestoredProfile()` : si `profiles.load()` rend un profil terminé d'id différent du brouillon → supprime le brouillon (`profiles.delete(id:)`), `isFinished = true`, renvoie `true`.

- [ ] **Step 1 : Écrire les tests**

```swift
// OnboardingFixture : doublures de la tâche 9, ScenarioHealthSource(.goodNight), StubNotificationAuthorizer, InMemoryOnboardingStepStore, now = 2026-11-02 08:00.
@Test @MainActor func startsAtWelcomeWithoutSavedStep() async
@Test @MainActor func resumesAtSavedStepWithDraftProfile() async      // étape .goals enregistrée, brouillon firstName "Léa" → step == .goals, profile.firstName == "Léa"
@Test @MainActor func allowHealthPrefillsOnlyEmptyFields() async      // brouillon heightCm 170 → reste 170 ; weightKg ← 74.5 ; sex ← .male
@Test @MainActor func skipHealthGoesToProfileAndCalibratesByCheckIn() async   // … puis adoptProgram → calibration == .needsCheckIn
@Test @MainActor func profileLevelSetsIncrements() async              // strengthLevel .advanced → upperIncrementKg 1.25, lowerIncrementKg 2.5
@Test @MainActor func goalsRecommendATemplate() async                 // focus 0.2, 3 jours → recommendedTemplateID == "ppl-3"
@Test @MainActor func adoptingActivatesTheProgram() async throws      // programs.programs(includeArchived: false).count == 1 ; profile.activeProgramID == son id
@Test @MainActor func readoptingReplacesThePreviousProgram() async throws    // adopter, goBack, adopter un autre → un seul programme actif non supprimé
@Test @MainActor func customProgramLeavesNoActiveProgram() async
@Test @MainActor func goodNightCalibrationScoresOptimal() async       // .scored(r, baseline) avec r.category == .optimal, baseline.nightsAnalyzed == 60
@Test @MainActor func threeNightsCalibrationNeedsCheckInThenScores() async   // .needsCheckIn ; checkIn rempli 3/3/3 ; submitCheckIn → .scored(estimé, 75)
@Test @MainActor func finishRequestsNotificationsAndCompletes() async // requestCount 1 ; morningScoreNotification ; onboardingCompletedAt == now ; stepStore vidé ; isFinished
@Test @MainActor func finishWithoutNotificationsDoesNotAsk() async    // notifyWhenScoreReady = false → requestCount 0, morningScoreNotification false
@Test @MainActor func emptyProfileStillCompletes() async              // aucun champ rempli, Apple Santé ignoré, check-in → finish → isFinished
@Test @MainActor func restoredCompletedProfileEndsOnboarding() async  // profil terminé plus ancien ajouté au dépôt → checkForRestoredProfile() == true,
                                                                       // brouillon supprimé, isFinished
@Test @MainActor func weekProposalSplitsDays() async                  // 5 jours, focus 0.4 → (3, 2)
```

- [ ] **Step 2 : Lancer, constater l'échec** — Run : `swift test --package-path Packages/PulseFeatures --filter OnboardingModelTests` ; Expected : FAIL à la compilation.

- [ ] **Step 3 : Implémenter les Interfaces** (deux fichiers pour tenir sous 400 lignes).

- [ ] **Step 4 : Vérifier** — Run : `swift test --package-path Packages/PulseFeatures` ; Expected : vert.

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulseFeatures
git commit -m "feat(onboarding): add the resumable onboarding model through calibration"
```

---

### Task 15 : Onboarding — écrans

**Files:**
- Create: `Packages/PulseFeatures/Sources/OnboardingFeature/Views/OnboardingFlowView.swift`, `WelcomeView.swift`, `HealthAccessView.swift`, `ProfileStepView.swift`, `GoalsStepView.swift`, `ProgramStepView.swift`, `CalibrationView.swift`, `OnboardingIdentifiers.swift`; `Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes : `OnboardingModel` (tâche 14), composants (tâches 5, 6, 8), `CheckInView` (tâche 13), `TrainingFocus.localizedName`, `RunType.localizedName`.
- Produces : `public struct OnboardingFlowView: View { init(model: OnboardingModel) }` ; `enum OnboardingIdentifiers` : `welcomeStart = "onboarding.welcome.start"`, `healthAllow = "onboarding.health.allow"`, `healthSkip = "onboarding.health.skip"`, `profileContinue = "onboarding.profile.continue"`, `goalsContinue = "onboarding.goals.continue"`, `programAdopt = "onboarding.program.adopt"`, `calibrationScore = "onboarding.calibration.score"`, `calibrationCategory = "onboarding.calibration.category"`, `calibrationFinish = "onboarding.calibration.finish"`.

Contenu par écran (textes de la spec M3 §7, maquette pour la mise en page) :
- `OnboardingFlowView` : fond `background` et `AuraBackground`, barre d'étapes à partir de l'étape 2 (`StepProgressBar(current: step.rawValue, total: 5)`), bouton retour à partir de l'étape 3, `.task { await model.start() }`, et `checkForRestoredProfile()` à chaque changement d'étape.
- `WelcomeView` : logo comme la maquette (symbole SF `waveform.path.ecg` en `accentInk` sur un carré ambre arrondi de 56 pt), « Ton corps décide de la séance du jour. », sous-titre, trois bénéfices, « Commencer », pied « Pulse n'est pas un dispositif médical. »
- `HealthAccessView` : « Pulse a besoin de lire tes nuits », quatre lignes (dont l'honnêteté sur la SDNN), mention RGPD article 9, « Autoriser dans Apple Santé », « Continuer sans montre ».
- `ProfileStepView` : « Quelques repères sur toi » ; prénom (contenu `givenName`), sexe (Femme / Homme / Autre), date de naissance, taille (cm), poids (kg ou lb selon l'unité, stocké en kg), unités, expérience muscu (« Moins d'un an », « 1 à 3 ans », « Plus de 3 ans »), expérience course (« Je débute », « Je cours régulièrement », « Je prépare des courses »).
- `GoalsStepView` : « Où placer le curseur ? », `FocusSlider` et « Proposition : N séances de musculation et M sorties par semaine. », séances par semaine (2 à 6), jours de repos imposés, trois cartes de matériel, douleurs (Épaules, Lombaires, Genoux, Poignets, Aucune), phrase sur les mouvements à risque.
- `ProgramStepView` : « Ton programme », cartes des cinq modèles (nom, résumé, séances par semaine, focus, aperçu L à D), badge « Recommandé » sur `recommendedTemplateID` placé en tête, carte « Je construis le mien » ; bouton « Adopter ce programme » ou « Continuer sans programme ».
- `CalibrationView` : lecture avec `ProgressView(value:)` et « Lecture de tes nuits… » ; score : pastille « N nuits analysées », « Ta récupération ce matin », `RecoveryGauge(.large)`, catégorie, marqueur (« Estimé » ou « En calibration (N nuits) »), « Ta ligne de base » (lignes présentes seulement), phrase sur la ligne de base, interrupteur « Me prévenir quand mon score est prêt », « Voir ma séance du jour » ; check-in : explication puis `CheckInView`.

- [ ] **Step 1 : Écrire les vues**, chacune avec un `#Preview` alimenté par `OnboardingModel` et les doublures (scénarios `goodNight` et `threeNights` pour la calibration).

- [ ] **Step 2 : Compiler pour macOS et lancer les tests**

Run : `swift build --package-path Packages/PulseFeatures && swift test --package-path Packages/PulseFeatures && swiftlint lint --strict`
Expected : vert, 0 violation.

- [ ] **Step 3 : Commit**

```bash
git add Packages/PulseFeatures
git commit -m "feat(onboarding): add the six onboarding screens"
```

---

### Task 16 : Accueil simple

**Files:**
- Create: `Packages/PulseFeatures/Sources/TodayFeature/TodayEnvironment.swift`, `TodayModel.swift`, `FactorFormatter.swift`, `Views/TodayView.swift`, `Views/RecoveryCard.swift`, `Views/SessionCard.swift`, `TodayIdentifiers.swift`, `Resources/Localizable.xcstrings`
- Test: `Packages/PulseFeatures/Tests/TodayFeatureTests/FactorFormatterTests.swift`, `TodayModelTests.swift`

**Interfaces:**
- Consumes : tâches 9 à 13, `PulseFormat`, `RecoveryGauge`, `MuscleMapView`, `MuscleIntensity`.
- Produces :
  - `struct TodayEnvironment: Sendable { profiles; programs; nightHistory: NightHistory; scores: DailyScoreService; library: ContentLibrary; calendar: Calendar; now: @Sendable () -> Date }`.
  - `struct FactorDisplay: Sendable, Equatable { factor: Factor; title: String; value: String; detail: String; isMissing: Bool }` ; `enum FactorFormatter { static func displays(for recovery: DailyRecovery) -> [FactorDisplay]; static func marker(for recovery: DailyRecovery) -> String? }` (ordre : sommeil, variabilité, FC repos).
  - `@MainActor @Observable final class TodayModel { greeting: String; dateText: String; lastSync: Date?; score: TodayScore?; factors: [FactorDisplay]; marker: String?; plannedDay: PlannedDay; summary: SessionSummary?; isLoading: Bool; let checkIn: CheckInForm; init(environment:); func refresh() async; func submitCheckIn() async }`. `refresh()` : profil, programme actif, `nightHistory.refresh`, `scores.update` ; `lastSync` = `readAt` s'il existe, sinon inchangé. Date « lundi 2 novembre » (locale `fr_FR`).
  - `TodayView(model: TodayModel, onOpenProfile: () -> Void)` : en-tête (« Bonjour {prénom} » ou « Bonjour », date, pastille « Synchro HH:MM » qui relance `refresh`, bouton profil), `RecoveryCard` (carte opale : « Récupération », `CategoryBadge`, `RecoveryGauge(.large)`, marqueur, trois colonnes ; en tailles d'accessibilité, colonnes empilées) ou `CheckInView` quand `.needsCheckIn`, ou carte « Score d'hier » quand `.beforeDayStart` ; `SessionCard` simple (musculation : « Séance du jour », nom du jour, `MuscleMapView` mini, « N séries », « ~ M min », « RPE max X », trois muscles ; course : `RunType.localizedName` et cible ; repos : « Repos » et prochaine séance ; sans programme : texte de la spec M3 §10.3). Rafraîchit à l'apparition et au retour au premier plan (`scenePhase == .active`).
  - `enum TodayIdentifiers { score = "today.score", sessionTitle = "today.session.title" }`.

- [ ] **Step 1 : Écrire les tests**

```swift
@Test func allFactorsPresent() {
    // asleep 310, deep 22, sdnn 44, baseline 53.7, rhr 54, baseline 49 →
    // [("Sommeil", "5 h 10", "profond 7 %"), ("Variabilité", "44 ms", "−18 % vs 14 j"), ("FC repos", "54", "+5 bpm")]
}
@Test func missingFactorReadsNoData()          // sleep nil → value "—", detail "pas de donnée cette nuit", isMissing
@Test func unknownDeepSleep()                  // deepMinutes nil → detail "phases inconnues"
@Test func hrvBaselineInProgress()             // hrv manquant, calibration .calibrating(nights: 3) → detail "ligne de base en cours, 3 sur 5 nuits"
@Test func markers()                           // hrv présent + .calibrating(9) → "En calibration (9 nuits)" ; .ready → nil ; isEstimated → "Estimé"
@Test @MainActor func refreshScoresAndPlansMonday() async     // goodNight, ppl-3 adopté, lundi 08:00 → score .scored(optimal), plannedDay .strength("Push"), summary.setCount 19
@Test @MainActor func greetingWithoutFirstName() async        // greeting == "Bonjour"
@Test @MainActor func greetingWithFirstName() async           // firstName "Mathéo" → "Bonjour Mathéo"
@Test @MainActor func checkInFromToday() async                // threeNights → .needsCheckIn ; 3/3/3 ; submitCheckIn → .scored(estimé)
@Test @MainActor func refreshWithFailingSourceKeepsCachedScore() async
    // refresh goodNight (lastSync = 08:00), puis environnement avec FailingHealthSource et même cache à 09:00
    // → score toujours optimal, lastSync toujours 08:00
@Test @MainActor func dateTextIsFrench() async                // "lundi 2 novembre"
```

- [ ] **Step 2 : Lancer, constater l'échec** — Run : `swift test --package-path Packages/PulseFeatures --filter TodayFeatureTests` ; Expected : FAIL à la compilation.

- [ ] **Step 3 : Implémenter les Interfaces**, avec des aperçus (`goodNight`, `missingHRV`, `threeNights`, jour de repos).

- [ ] **Step 4 : Vérifier** — Run : `swift test --package-path Packages/PulseFeatures && swiftlint lint --strict` ; Expected : vert.

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulseFeatures
git commit -m "feat(today): add the simple Today tab with score, factors, check-in and planned session"
```

---

### Task 17 : App — assemblage, racine, onglets, mineurs du debug

**Files:**
- Create: `Packages/PulseHealth/Sources/PulseHealth/HealthKitReader+SampleSource.swift`, `Pulse/Notifications/UserNotificationAuthorizer.swift`, `Pulse/Root/AppRootModel.swift`, `Pulse/Root/AppRootView.swift`, `Pulse/Root/MainTabView.swift`, `Pulse/Root/ProfileHubView.swift`, `PulseTests/AppRootModelTests.swift`
- Modify: `Pulse/AppDependencies.swift`, `Pulse/PulseApp.swift`, `Pulse/Debug/DataDebugModel.swift`, `Pulse/Debug/DataDebugView.swift`, `Pulse/Debug/EraseConfirmationView.swift`, `Pulse/Diagnostics/HealthDiagnosticsView.swift`, `PulseTests/DataDebugModelTests.swift`
- Delete: `Pulse/RootTabView.swift`

**Interfaces:**
- Consumes : tout ce qui précède.
- Produces :
  - `extension HealthKitReader: HealthSampleSource` : `requestAuthorization()` lit sommeil, SDNN, FC repos, FC, entraînements, poids, masse grasse, taille, date de naissance, sexe ; `profileHints()` depuis `biologicalSex()`, `dateOfBirthComponents()`, dernière taille (cm) et dernier poids (kg). Aucune valeur journalisée.
  - `struct UserNotificationAuthorizer: NotificationAuthorizing` (`UNUserNotificationCenter`, options alerte, son, pastille ; erreur → `false`).
  - `AppDependencies` gagne `healthSource: any HealthSampleSource`, `notifications: any NotificationAuthorizing`, `onboardingSteps: any OnboardingStepStore`, `now: @Sendable () -> Date`, `launch: LaunchOptions`, et `func onboardingEnvironment() -> OnboardingEnvironment`, `func todayEnvironment() -> TodayEnvironment`. `live()` : en Debug, `LaunchOptions.parse(ProcessInfo.processInfo.arguments)` ; scénario → `ScenarioHealthSource(scenario:now:calendar:)` ; `storeInMemory` → conteneur `.inMemory`, suite de préférences `fr.seonay.pulse.memory` vidée au lancement, et `StubNotificationAuthorizer(granted: false)` pour qu'aucune alerte système n'interrompe le test d'interface ; `fixedNow` → horloge fixe. `testing()` : suite dédiée `fr.seonay.pulse.tests` pour l'effaceur et les étapes (mineur M2).
  - `@MainActor @Observable final class AppRootModel { enum Destination { case loading, onboarding, main }; private(set) var destination; init(dependencies:); func load() async; func onboardingFinished(); func dataErased() async }` (`load` et `dataErased` passent par `LaunchDestination.resolve`).
  - `AppRootView` : écran de chargement, `OnboardingFlowView` (quand `model.isFinished` devient vrai → `onboardingFinished()`), ou `MainTabView` ; `.preferredColorScheme(.dark)`, `tint` ambre, environnement `pulseTheme` depuis le profil.
  - `MainTabView` : onglets « Aujourd'hui » (`TodayView`), « Planning » (`ComingSoonView`, M6), « Séance » (M4), « Stats » (M7), « Profil » (`ProfileHubView`) ; le bouton profil de l'accueil sélectionne l'onglet Profil.
  - `ProfileHubView` : `NavigationStack` avec le prénom, puis liens « Santé (diagnostic) » vers `HealthDiagnosticsView` et « Données » vers `DataDebugView` (ces deux vues perdent leur propre `NavigationStack`). `DataDebugView` reçoit `onErased: () async -> Void`, appelé après une suppression réussie → `AppRootModel.dataErased()`.
  - Mineurs M2 : `DataDebugModel.erase` recompte les tables même si l'effacement échoue ; la feuille de suppression a `.interactiveDismissDisabled(model.isBusy)` et son bouton Annuler désactivé pendant l'opération.

- [ ] **Step 1 : Écrire les tests de la cible app** (compilés ici, lancés par Mathéo)

```swift
@Test @MainActor func freshInstallGoesToOnboarding() async        // AppDependencies.testing() → load() → .onboarding
@Test @MainActor func completedProfileGoesToMain() async          // profil terminé enregistré → .main
@Test @MainActor func erasingReturnsToOnboarding() async          // profil terminé → .main ; eraser.eraseEverything ; dataErased() → .onboarding
@Test @MainActor func eraseFailureStillRefreshesCounts() async    // DataDebugModelTests : effaceur Apple Santé qui échoue → counts rafraîchis, lastError non nil
```

- [ ] **Step 2 : Implémenter les Interfaces**

- [ ] **Step 3 : Compiler l'app et toutes les cibles de test**

Run (hors bac à sable) : `make build-app && swiftlint lint --strict`
Expected : code de sortie 0, 0 violation.

- [ ] **Step 4 : Commit**

```bash
git add Pulse PulseTests Packages/PulseHealth
git commit -m "feat(app): route between onboarding and tabs, wire health source and notifications"
```

---

### Task 18 : Test d'interface de l'onboarding

**Files:**
- Modify: `PulseUITests/OnboardingFlowUITests.swift`

**Interfaces:**
- Consumes : `OnboardingIdentifiers`, `TodayIdentifiers` (tâches 15 et 16), options de lancement (tâche 9).

- [ ] **Step 1 : Écrire le test**

```swift
final class OnboardingFlowUITests: XCTestCase {
    @MainActor func testOnboardingReachesTheFirstScoreThenToday() {
        let app = XCUIApplication()
        app.launchArguments = ["-PulseStore", "inMemory", "-PulseHealthScenario", "goodNight", "-PulseNow", "2026-11-02T08:00:00+01:00"]
        app.launch()
        app.buttons["onboarding.welcome.start"].tap()
        app.buttons["onboarding.health.allow"].tap()
        app.buttons["onboarding.profile.continue"].tap()
        app.buttons["onboarding.goals.continue"].tap()
        app.buttons["onboarding.program.adopt"].tap()
        XCTAssertTrue(app.staticTexts["onboarding.calibration.score"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["onboarding.calibration.category"].label, "Forme optimale")
        app.buttons["onboarding.calibration.finish"].tap()
        XCTAssertTrue(app.staticTexts["today.score"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["today.session.title"].exists)
    }
}
```
Les boutons « Continuer » peuvent être sous le pli : faire défiler (`app.swipeUp()`) avant de toucher si l'élément n'est pas `isHittable`.

- [ ] **Step 2 : Compiler**

Run (hors bac à sable) : `make build-app`
Expected : code de sortie 0. **Ne pas exécuter** le test : Mathéo le lance (`make test-app` ou Xcode).

- [ ] **Step 3 : Commit**

```bash
git add PulseUITests
git commit -m "test(ui): add the onboarding to first score UI test"
```

---

### Task 19 : Vérification finale, documentation, revue, PR

**Files:**
- Modify: `README.md` (feuille de route : M3a fait, M3b à venir), `docs/superpowers/plans/2026-10-31-pulse-v1-roadmap.md` (M3 découpé en M3a / M3b, renvoi vers la spec M3)

- [ ] **Step 1 : Tout vérifier**

Run : `make test-packages && swiftlint lint --strict`, puis (hors bac à sable) `make build-app`
Expected : chaque package vert (`PulseHealth` exclu : iOS seulement), 0 violation, code de sortie 0.

- [ ] **Step 2 : Mettre à jour la documentation, commit**

```bash
git add README.md docs/superpowers/plans/2026-10-31-pulse-v1-roadmap.md
git commit -m "docs: mark M3a done and split M3 in the roadmap"
```

- [ ] **Step 3 : Revue de toute la branche** avec `superpowers:requesting-code-review` contre la spec M3 (partie M3a) ; corriger les points retenus, en TDD, un commit par correction.

- [ ] **Step 4 : PR** — seulement avec l'accord de Mathéo : `git push -u origin m3-onboarding-tableau-de-bord`, puis `gh pr create --base master` avec un résumé, la liste de ce qui reste à Mathéo (spec M3 §20 : test d'interface, `make test-app`, onboarding sur l'iPhone, tableau du diagnostic M1, schéma CloudKit V2 en production) et la ligne de fin de PR demandée par la session.
