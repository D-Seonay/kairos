# Pulse M3b — Accueil complet, arrière-plan, widgets : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Chaque matin, l'onglet Aujourd'hui montre la séance du jour ajustée au score (ou rétablie), son Pourquoi, la charge, les tendances et la mobilité ; le score se calcule aussi en arrière-plan par lecture ancrée d'Apple Santé, une notification prévient qu'il est prêt, et un widget l'affiche sur l'écran d'accueil et l'écran verrouillé.

**Architecture:** Le moteur gagne `SessionAdjuster` (table de la spec V1 §6.5). `PulseServices` gagne la lecture ancrée (`NightHistory` sur un cache qui applique ajouts et suppressions), un `DailyScoreService` partagé et sérialisé qui enregistre les ajustements et le choix « Séance d'origine », et un orchestrateur `DayRefresher` (lecture, score, séance du jour, instantané du widget, notification) appelé au premier plan par l'accueil et en arrière-plan par l'observateur HealthKit. `TodayFeature` affiche tout cela ; une nouvelle cible `WidgetFeature` (domaine et design system seulement) porte la logique et les vues du widget, utilisées par la cible d'extension `PulseWidgets`. L'app assemble (délégué d'application, notifications, App Group, routage vers l'accueil).

**Tech Stack:** Swift 6.4 (mode de langage 6), SwiftUI, WidgetKit, HealthKit (`HKAnchoredObjectQueryDescriptor`, `HKObserverQuery`, livraison en arrière-plan), UserNotifications, SwiftData, Swift Testing, SwiftPM, XcodeGen 2.46 (une fois), SwiftLint, Xcode 27.0.

**Spec:** `docs/superpowers/specs/2026-11-01-pulse-m3-onboarding-tableau-de-bord-design.md` (la « spec M3 », partie M3b : §2, §6.2, §9.3, §10 à §12.2, §13, §14, §16.3, §18, §20), qui complète `2026-10-31-pulse-v1-design.md` (§5.2, §5.10, §5.11, §6.3 à §6.5, §7, §9, §10, §12). Référence visuelle : `maquette.html` (écrans `today`, `pourquoi`, `checkin`, `ios-accueil`, `ios-verrouille`, `veille-widgets`) et `assets/maquette_v2_planche.png`.

## Global Constraints

- Xcode **27.0**, Swift **6.4**, cible **iOS 26**, `swift-tools-version: 6.2`, `swiftSettings: [.swiftLanguageMode(.v6)]` sur chaque cible. Les packages de features et de design system compilent aussi pour macOS (`swift test`).
- **Ne jamais lancer le simulateur** : interdits `xcodebuild test`, `test-without-building`, `make test`, `make test-app`, `simctl boot|install|launch`, outils d'appareil T3. Les tests de `PulseTests` sont écrits et compilés, Mathéo les lance.
- **Vérification de fin de tâche (VFT)**, avant chaque commit de tâche : `swift test --package-path Packages/<chaque package touché>` vert ; `swiftlint lint --strict` à 0 ; puis, **hors bac à sable du shell**, `make build-app` et `make build-release`, chacun jugé sur le code de sortie 0 (Xcode 27 n'affiche pas de bannière avec `-quiet`). `PulseHealth` (iOS seulement) n'est vérifié que par ces deux compilations.
- SwiftLint strict, avertissements = erreurs : **≤ 400 lignes par fichier**, **≤ 50 lignes par corps de fonction**, lignes ≤ 140, imports triés, pas de `!` hors tests.
- `PulseFeatures` (toutes cibles) ne dépend jamais de `PulsePersistence`, `PulseHealth`, `SwiftData`, `HealthKit` ni `WidgetKit`. `WidgetFeature` ne dépend que de `PulseDomain` et `PulseDesignSystem`. Chaque dépendance importée est déclarée dans le manifeste (pas d'import transitif).
- Aucune logique ne lit `Date()`, `Date.now` ni `Calendar.current` : heure injectée (`now`), calendrier injecté. Seules exceptions, l'assemblage : `AppDependencies`, l'extension `PulseWidgets` (date de l'entrée de timeline, `Calendar.current`) et le minuteur affiché de la mobilité (horloge murale, voir tâche 10). Tests : grégorien `Europe/Paris`, locale `fr_FR`.
- Chaînes visibles en français. Dans un package : `String(localized: "…", bundle: .module)` et `Text(String(localized: "…", bundle: .module))`. Toute cible qui a des chaînes a `Resources/Localizable.xcstrings`.
- **Aucune donnée de santé brute** (VFC, FC, sommeil) dans un journal, un `print`, une notification, le widget, l'écran verrouillé ou l'instantané. Seuls en sortent : score entier, catégorie, estimé ou non, titre de la séance, séance allégée ou non.
- Tout `#Preview` qui utilise une aide `#if DEBUG` est lui-même sous `#if DEBUG` (erreur Release de M3a).
- Accessibilité (spec M3 §18) : étiquette VoiceOver sur chaque contrôle, jauge, sparkline et widget ; catégorie toujours écrite, jamais portée par la seule couleur ; Dynamic Type jusqu'à « Accessibilité XL » (empilement vertical aux tailles d'accessibilité) ; « Réduire les animations » respecté ; cibles ≥ 44 pt, boutons principaux ≥ 50 pt.
- Identifiants fixés : App Group **`group.fr.seonay.pulse`** (app et extension), extension `fr.seonay.pulse.widgets`, schéma d'URL **`fr.seonay.pulse`** (`fr.seonay.pulse://today`), type de widget `RecoveryWidget`, notification `fr.seonay.pulse.morning-score`.
- Projet à dossiers synchronisés : tout fichier sous `Pulse/`, `PulseTests/`, `PulseUITests/`, `PulseWidgets/` est compilé sans toucher au `pbxproj`. Le projet n'est régénéré qu'en tâche 1.
- **Checkout partagé avec Mathéo.** Avant chaque commit : `git branch --show-current` doit afficher `m3b-accueil-widgets` (sinon s'arrêter et le signaler) et `git status --short` ne doit montrer que les fichiers de la tâche ; on ajoute par chemin explicite, jamais `git add -A` ni `git add .` ; on ne modifie jamais un commit qui n'est pas le sien. Jamais de commit sur `master`. Pas de push sans l'accord de Mathéo, et toujours `git push origin m3b-accueil-widgets`.
- Commits `type(scope): description` en anglais, **sans** trailer Co-Authored-By ni mention de Claude.
- Exécution (choix de Mathéo) : chaque tâche par un sous-agent dans son propre sous-thread T3 (`delegate_task`), TDD, relecture par tâche, revue finale de toute la branche par Opus.

## Review Focus

1. **Mise à jour depuis M3a sur l'iPhone de Mathéo** : son cache est plein d'échantillons sans UUID HealthKit et sans ancre. La première lecture ancrée doit remplacer ce cache, jamais le doubler (sinon VFC et sommeil comptés deux fois). Test en tâche 6 (`m3aCacheIsReplacedOnFirstAnchoredRead`).
2. **Trois observateurs HealthKit qui se réveillent ensemble, plus une ouverture de l'app** : une seule notification par jour, aucun score ni check-in écrasé. Tests en tâches 7 (`updateAndCheckInAreSerialised`) et 9 (`concurrentBackgroundRefreshesNotifyOnce`).
3. **iPhone verrouillé pendant une livraison en arrière-plan** (données protégées) : la lecture échoue sans avancer l'ancre ni toucher au cache, le score déjà calculé reste, et la lecture est refaite plus tard. Tests en tâches 6 (`failingSignalKeepsItsAnchorAndCache`) et 9 (`backgroundRefreshWithUnreadableHealthKeepsTheScore`).
4. **« Séance d'origine » puis nouvelle nuit avant midi, ou choix fait le soir après le figement** : le choix survit au recalcul, et reste possible après midi sans changer le score figé. Tests en tâche 7 (`recomputeKeepsTheOriginalSessionChoice`, `originalSessionCanBeChosenAfterNoon`).
5. **Widget entre minuit et 4 h, y compris la nuit du changement d'heure** : l'instantané de la veille affiche « — » et « Score pas encore prêt », jamais le score d'hier comme celui du jour. Tests en tâche 14 (`yesterdaysSnapshotIsNotShownAsToday`, `timelineChangesAtNextMidnight`).

---

## Structure des fichiers créés ou modifiés

```
project.yml                                       (temporaire, supprimé en tâche 1)
Pulse.xcodeproj/                                  (régénéré : cible PulseWidgets, App Group, WidgetFeature)
Makefile                                          (+ check-versions dans build-release)
Packages/PulseDomain/Sources/PulseDomain/
  Health/NightSignal.swift, Health/HealthSampleChanges.swift, Health/HealthSampleSource.swift (lecture ancrée)
  Repositories/HealthSampleCache.swift (apply), Repositories/NotificationScheduling.swift
  Widgets/WidgetSnapshot.swift, Widgets/WidgetPublishing.swift
  Notifications/MorningScoreMessage.swift, App/AppLink.swift
Packages/PulseRecoveryEngine/                     Package.swift (ressources), Adjustments/, Resources/Localizable.xcstrings
Packages/PulsePersistence/                        SwiftDataHealthSampleCache (apply), SwiftDataEraser (widget),
                                                  Tests/…/SchemaFingerprintTests.swift, Fixtures/schema-v1.txt, schema-v2.txt
Packages/PulseHealth/Sources/PulseHealth/         HealthKitTypes.swift, HealthKitReader+SampleSource.swift, HealthKitBackgroundDelivery.swift
Packages/PulseDesignSystem/                       Sparkline, LoadGauge et leurs géométries, PulseFormat
Packages/PulseFeatures/
  Sources/PulseServices/                          Concurrency/, Health/ (ancrée, UnavailableHealthSource), Score/, Today/ (TodaySession,
                                                  TrainingLoad), Widgets/, Notifications/, Refresh/ (DayRefresher), Resources/
  Sources/TodayFeature/                           Session/, Why/, Load/, Trends/, Mobility/, Views/, TodayModel…
  Sources/WidgetFeature/                          WidgetSnapshotFile, RecoveryWidgetContent, RecoveryWidgetTimeline, Views/, Resources/
  Tests/WidgetFeatureTests/
PulseWidgets/                                     PulseWidgetsBundle, RecoveryWidget, RecoveryTimelineProvider, Info.plist, entitlements
Pulse/
  AppDelegate.swift, PulseApp.swift, AppDependencies.swift, Info.plist (URL), Pulse.entitlements (App Group)
  Root/AppRouter.swift, AppRootView.swift, MainTabView.swift
  Notifications/UserNotificationScheduler.swift, NotificationRouter.swift
  Widgets/AppGroupWidgetPublisher.swift, Debug/DataDebugModel.swift
PulseTests/AppRouterTests.swift, DataDebugModelTests.swift
```

---

### Task 1 : Branche, catalogue de l'onboarding, cible d'extension et App Group

**Files:**
- Create: `project.yml` (temporaire), `PulseWidgets/PulseWidgetsBundle.swift`, `Packages/PulseFeatures/Sources/WidgetFeature/WidgetFeature.swift`, `Packages/PulseFeatures/Sources/WidgetFeature/Resources/Localizable.xcstrings`, `Packages/PulseFeatures/Tests/WidgetFeatureTests/WidgetFeatureSmokeTests.swift` ; générés par XcodeGen : `PulseWidgets/Info.plist`, `PulseWidgets/PulseWidgets.entitlements`
- Modify: `Packages/PulseFeatures/Package.swift`, `Pulse.xcodeproj/`, `Pulse/Info.plist`, `Pulse/Pulse.entitlements`, `Makefile`

**Interfaces:**
- Produces : produit SwiftPM `WidgetFeature` (dépend de `PulseDomain` et `PulseDesignSystem`, `resources: [.process("Resources")]`) et cible `WidgetFeatureTests`. Cible Xcode `PulseWidgets` (`app-extension`, `NSExtensionPointIdentifier = com.apple.widgetkit-extension`, `fr.seonay.pulse.widgets`, embarquée dans `Pulse`, dépend de `PulseDomain`, `PulseDesignSystem`, `WidgetFeature`). App Group `group.fr.seonay.pulse` sur l'app et l'extension. Schéma d'URL `fr.seonay.pulse` sur l'app. `make check-versions` (appelée en tête de `build-release`) échoue si `CFBundleShortVersionString` ou `CFBundleVersion` diffèrent entre `Pulse/Info.plist` et `PulseWidgets/Info.plist`.

- [ ] **Step 1 : Créer la branche et commiter le catalogue à part**

Run : `git branch --show-current && git status --short`
Expected : `master`, et seulement `M Packages/PulseFeatures/Sources/OnboardingFeature/Resources/Localizable.xcstrings`, `?? .agents/`, `?? .gemini/`.

Run : `git show HEAD:Packages/PulseFeatures/Sources/OnboardingFeature/Resources/Localizable.xcstrings > /tmp/xc_head.json && python3 -I -c "import json,sys; a=json.load(open(sys.argv[1]))['strings']; b=json.load(open(sys.argv[2]))['strings']; print(set(a)^set(b), [k for k in a if a[k].get('localizations')!=b[k].get('localizations')])" /tmp/xc_head.json Packages/PulseFeatures/Sources/OnboardingFeature/Resources/Localizable.xcstrings`
Expected : `set() []` (mêmes 118 clés, mêmes valeurs françaises ; seuls l'ordre et le commentaire de « M » changent). Sinon, s'arrêter et le signaler.

```bash
git switch -c m3b-accueil-widgets
git add Packages/PulseFeatures/Sources/OnboardingFeature/Resources/Localizable.xcstrings
git commit -m "chore(onboarding): keep Xcode's normalisation of the onboarding string catalogue"
```

- [ ] **Step 2 : Relever les réglages actuels**

Run (hors bac à sable) : pour `CONFIG` dans `Debug Release` : `xcodebuild -showBuildSettings -project Pulse.xcodeproj -target Pulse -configuration $CONFIG 2>/dev/null | grep -E '^\s+(TARGETED_DEVICE_FAMILY|DEVELOPMENT_TEAM|ASSETCATALOG_COMPILER_APPICON_NAME|INFOPLIST_KEY_LSApplicationCategoryType|CODE_SIGN_ENTITLEMENTS|CODE_SIGN_IDENTITY|PRODUCT_BUNDLE_IDENTIFIER|SWIFT_VERSION|SWIFT_STRICT_CONCURRENCY|IPHONEOS_DEPLOYMENT_TARGET|ENABLE_PREVIEWS|INFOPLIST_FILE|SUPPORTS_MACCATALYST) =' | sort -u > /tmp/pulse-$CONFIG-before.txt` ; copier aussi `Pulse/Info.plist`, `Pulse/Pulse.entitlements` et `Pulse.xcodeproj/xcshareddata/xcschemes/Pulse.xcscheme` dans `/tmp/`.
Expected : deux fichiers d'une douzaine de lignes.

- [ ] **Step 3 : Ajouter la cible `WidgetFeature`**

Manifeste selon les Interfaces ; `public enum WidgetFeature {}` (remplacé en tâche 14), catalogue minimal `{"sourceLanguage":"fr","strings":{},"version":"1.0"}`, test `@Test func targetBuilds() { #expect(true) }`.
Run : `swift test --package-path Packages/PulseFeatures` — Expected : vert.

- [ ] **Step 4 : Écrire `project.yml`**

Partir de `git show 0a30786:project.yml` et y reporter **tout** l'état actuel :
- `options.deploymentTarget.iOS: "26.0"`, `xcodeVersion: "27.0"` ; `settings.base` du projet : `SWIFT_VERSION: "6.0"`, `SWIFT_STRICT_CONCURRENCY: complete`, `TARGETED_DEVICE_FAMILY: "1"`, `SUPPORTS_MACCATALYST: "NO"`, `CODE_SIGN_STYLE: Automatic`.
- `packages:` les sept (`PulseDomain`, `PulseRecoveryEngine`, `PulseHealth`, `PulseContent`, `PulsePersistence`, `PulseDesignSystem`, `PulseFeatures`).
- Cible `Pulse` : `sources: [{path: Pulse, type: syncedFolder}]` ; dépendances : les six premiers packages, `- package: PulseFeatures` avec `products: [PulseServices, CheckInFeature, OnboardingFeature, TodayFeature, WidgetFeature]`, et `- target: PulseWidgets` (embarquée) ; `settings.base` : `DEVELOPMENT_TEAM: UP9NVJDBKA`, `TARGETED_DEVICE_FAMILY: "1,2"`, `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`, `INFOPLIST_KEY_LSApplicationCategoryType: public.app-category.sports`, `CODE_SIGN_IDENTITY: iPhone Developer`, `PRODUCT_BUNDLE_IDENTIFIER: fr.seonay.pulse`, `ENABLE_PREVIEWS: "YES"`.
- `info` de `Pulse` (`path: Pulse/Info.plist`) : toutes les clés actuelles du fichier — `CFBundleDevelopmentRegion: fr`, `CFBundleDisplayName: Pulse`, **`CFBundleShortVersionString: "1.0.2"`, `CFBundleVersion: "3"`**, `ITSAppUsesNonExemptEncryption: false`, les deux textes `NSHealth*` mot pour mot, `UIBackgroundModes: [remote-notification]`, `UILaunchScreen: {}`, `UISupportedInterfaceOrientations: [UIInterfaceOrientationPortrait]`, `UISupportedInterfaceOrientations~ipad` (les quatre) — plus `CFBundleURLTypes: [{CFBundleURLName: fr.seonay.pulse, CFBundleURLSchemes: [fr.seonay.pulse]}]`.
- `entitlements` de `Pulse` : `com.apple.developer.healthkit: true`, `com.apple.developer.healthkit.access: []`, `com.apple.developer.healthkit.background-delivery: true`, `com.apple.developer.icloud-container-identifiers: [iCloud.fr.seonay.pulse]`, `com.apple.developer.icloud-services: [CloudKit]`, plus `com.apple.security.application-groups: [group.fr.seonay.pulse]`.
- Cible `PulseWidgets` : `type: app-extension`, `platform: iOS`, `sources: [{path: PulseWidgets, type: syncedFolder}]`, dépendances `PulseDomain`, `PulseDesignSystem`, `PulseFeatures` (`products: [WidgetFeature]`) ; `info` (`path: PulseWidgets/Info.plist`) : `CFBundleDisplayName: Pulse`, `CFBundleShortVersionString: "1.0.2"`, `CFBundleVersion: "3"`, `NSExtension: {NSExtensionPointIdentifier: com.apple.widgetkit-extension}` ; `entitlements` (`path: PulseWidgets/PulseWidgets.entitlements`) : l'App Group ; `settings.base` : `PRODUCT_BUNDLE_IDENTIFIER: fr.seonay.pulse.widgets`, `DEVELOPMENT_TEAM: UP9NVJDBKA`, `TARGETED_DEVICE_FAMILY: "1,2"`, `CODE_SIGN_IDENTITY: iPhone Developer`, `SKIP_INSTALL: "YES"`, `ENABLE_PREVIEWS: "YES"`, `LD_RUNPATH_SEARCH_PATHS: ["$(inherited)", "@executable_path/Frameworks", "@executable_path/../../Frameworks"]`.
- Cibles `PulseTests` (`bundle.unit-test`, `syncedFolder`, `GENERATE_INFOPLIST_FILE`, `fr.seonay.pulse.tests`, `TARGETED_DEVICE_FAMILY: "1,2"`) et `PulseUITests` (`bundle.ui-testing`, `syncedFolder`, `GENERATE_INFOPLIST_FILE`, `TEST_TARGET_NAME: Pulse`, `fr.seonay.pulse.uitests`, `TARGETED_DEVICE_FAMILY: "1,2"`), dépendant de `Pulse`.
- `schemes.Pulse.test.targets` : `PulseTests`, `PulseUITests` et `PulseDomainTests`, `PulseRecoveryEngineTests`, `PulseHealthTests`, `PulseContentTests`, `PulsePersistenceTests`, `PulseDesignSystemTests`, `PulseServicesTests`, `CheckInFeatureTests`, `OnboardingFeatureTests`, `TodayFeatureTests`, `WidgetFeatureTests`.

`PulseWidgets/PulseWidgetsBundle.swift` : un `@main WidgetBundle` provisoire avec un `StaticConfiguration(kind: "RecoveryWidget")` qui affiche `Text("Pulse")` (remplacé en tâche 14).

- [ ] **Step 5 : Régénérer et comparer**

Run : `xcodegen generate`, puis `diff /tmp/Info.plist Pulse/Info.plist`, `diff /tmp/Pulse.entitlements Pulse/Pulse.entitlements`, `diff /tmp/Pulse.xcscheme Pulse.xcodeproj/xcshareddata/xcschemes/Pulse.xcscheme`, et (hors bac à sable) la commande du step 2 vers `/tmp/pulse-$CONFIG-after.txt` avec `diff` des deux configurations.
Expected : `Info.plist` ne gagne que `CFBundleURLTypes` ; les entitlements que l'App Group ; le schéma que `WidgetFeatureTests` et l'extension ; réglages de `Pulse` identiques en Debug et en Release. `PulseWidgets/Info.plist` figure dans les exceptions de son dossier synchronisé, comme `Pulse/Info.plist` (sinon « Multiple commands produce »). Une clé perdue se corrige dans `project.yml`, puis on régénère.

- [ ] **Step 6 : `Makefile`**

Cible `check-versions` : lit les deux clés des deux `Info.plist` avec `/usr/libexec/PlistBuddy -c 'Print …'` et sort en erreur avec un message clair si elles diffèrent ; `build-release` l'appelle en premier.

- [ ] **Step 7 : VFT, puis supprimer `project.yml`**

Run (hors bac à sable) : `rm project.yml && make build-app && make build-release`
Expected : code de sortie 0 pour les deux.

- [ ] **Step 8 : Commit**

```bash
git add Pulse.xcodeproj Pulse/Info.plist Pulse/Pulse.entitlements PulseWidgets Makefile \
  Packages/PulseFeatures/Package.swift Packages/PulseFeatures/Sources/WidgetFeature Packages/PulseFeatures/Tests/WidgetFeatureTests
git commit -m "chore(project): add the widget extension target, the app group and the widget feature package target"
```

---

### Task 2 : Persistance — empreinte figée des schémas V1 et V2

**Files:**
- Create: `Packages/PulsePersistence/Tests/PulsePersistenceTests/SchemaFingerprintTests.swift`, `Tests/PulsePersistenceTests/Support/SchemaFingerprint.swift`, `Tests/PulsePersistenceTests/Fixtures/schema-v1.txt`, `Tests/PulsePersistenceTests/Fixtures/schema-v2.txt`
- Modify: `Packages/PulsePersistence/Package.swift` (cible de test : `resources: [.copy("Fixtures")]`), commentaires de `Schema/PulseSchemaV1.swift` et `Schema/PulseSchemaV2.swift`

**Interfaces:**
- Produces (tests seulement) : `enum SchemaFingerprint { static func lines(_ schema: Schema) -> [String] }` — une ligne par attribut, `"<Entité>.<nom>: <type>"` suivi de `?` s'il est optionnel, et par relation, `"<Entité>.<nom> -> <Destination> [to-one|to-many, <règle de suppression>]"` ; lignes triées ; un fichier de référence = les lignes jointes par `\n`, avec un `\n` final. Avec `PULSE_WRITE_SCHEMA_FIXTURES=1`, les tests écrivent les fichiers de référence à côté du fichier de test (`#filePath`) au lieu de comparer.
- Le commentaire de `PulseSchemaV1` et `PulseSchemaV2` dit : « Avant de modifier un modèle partagé, figer sa copie dans la version précédente et ajouter une version : le test d'empreinte échoue sinon. »

- [ ] **Step 1 : Écrire les tests**

```swift
@Test func v1SchemaMatchesItsFrozenFingerprint() throws   // lines(Schema(versionedSchema: PulseSchemaV1.self)) == fixture("schema-v1")
@Test func v2SchemaMatchesItsFingerprint() throws          // idem avec PulseSchemaV2 et "schema-v2"
@Test func v2OnlyAddsTheTwoM3Fields() {
    let v1 = Set(SchemaFingerprint.lines(Schema(versionedSchema: PulseSchemaV1.self)))
    let v2 = Set(SchemaFingerprint.lines(Schema(versionedSchema: PulseSchemaV2.self)))
    #expect(v1.subtracting(v2).isEmpty)
    #expect(v2.subtracting(v1).compactMap { $0.split(separator: ":").first.map(String.init) }.sorted()
        == ["StoredDailyRecovery.originalSessionChosen", "StoredProfile.firstName"])
}
```
Message d'échec des deux premiers : « Un modèle partagé a changé : figer sa copie dans la version précédente du schéma avant de le modifier. »

- [ ] **Step 2 : Lancer, constater l'échec** — Run : `swift test --package-path Packages/PulsePersistence --filter SchemaFingerprint` ; Expected : FAIL (fichiers de référence absents).

- [ ] **Step 3 : Implémenter `SchemaFingerprint`**, à partir de `Schema.entities` (`attributes` : `name`, `valueType`, `isOptional` ; `relationships` : `name`, `destination`, `isToOneRelationship`, `deleteRule`), sans doubler le `?` quand `valueType` est déjà un `Optional`.

- [ ] **Step 4 : Générer et relire les références**

Run : `PULSE_WRITE_SCHEMA_FIXTURES=1 swift test --package-path Packages/PulsePersistence --filter SchemaFingerprint && wc -l Packages/PulsePersistence/Tests/PulsePersistenceTests/Fixtures/schema-v*.txt`
Expected : deux fichiers, V2 = V1 plus deux lignes ; aucune ligne `?` doublée.

- [ ] **Step 5 : VFT** — `swift test --package-path Packages/PulsePersistence` vert (sans la variable), lint, `make build-app`, `make build-release`.

- [ ] **Step 6 : Commit**

```bash
git add Packages/PulsePersistence/Package.swift Packages/PulsePersistence/Tests Packages/PulsePersistence/Sources/PulsePersistence/Schema
git commit -m "test(persistence): pin the V1 and V2 schema fingerprints so a shared model cannot drift"
```

---

### Task 3 : Moteur — ajustements de séance par catégorie

**Files:**
- Create: `Packages/PulseRecoveryEngine/Sources/PulseRecoveryEngine/Adjustments/AdjustedSession.swift`, `Adjustments/SessionAdjuster.swift`, `Adjustments/VolumeReducer.swift`, `Resources/Localizable.xcstrings`
- Modify: `Packages/PulseRecoveryEngine/Package.swift` (`defaultLocalization: "fr"`, `resources: [.process("Resources")]` sur la cible)
- Test: `Packages/PulseRecoveryEngine/Tests/PulseRecoveryEngineTests/SessionAdjusterTests.swift`

**Interfaces:**
- Produces :
  - `struct AdjustedSession: Sendable, Equatable { var day: RoutineDay; var adjustments: [SessionAdjustment]; var removedSets: Int; var isVolumeReduced: Bool { removedSets > 0 }; var isReplacedByMobility: Bool }` (vrai si un ajustement `.replaceWithMobility`).
  - `enum SessionAdjuster { static let normalExtraRestSeconds = 15; static let fatigueExtraRestSeconds = 45; static let fatigueRPECap = 7.5; static let volumeReduction = 0.2; static let mobilityMinutes = 20; static func adjust(_ day: RoutineDay, category: RecoveryCategory) -> AdjustedSession }`.
  - Musculation : optimal → rien. Normal → repos +15 s partout, `.rest` valeur 15, « Repos rallongés de 15 secondes ». Fatigue modérée, dans cet ordre : `.volume` valeur `-removedSets`, « Volume réduit de 19 à 15 séries » (seulement si des séries sont retirées) ; `.rpeCap` valeur 7,5, « Effort plafonné à RPE 7,5 » (RPE cible = `min(cible, 7,5)`, l'ajustement n'apparaît que s'il baisse au moins une cible) ; `.rest` valeur 45, « Repos rallongés de 45 secondes ». Surmenage → séance inchangée, `.replaceWithMobility` valeur 20, « Séance remplacée par 20 min de mobilité ou du repos, au choix ».
  - Course : fatigue modérée et `runType == .intervals` → `.swapIntervalsForEasy`, « Fractionné remplacé par une sortie facile » ; surmenage → `.suggestRest`, « Repos conseillé plutôt que la course » ; sinon rien. La séance de course n'est jamais modifiée.
  - `VolumeReducer` (interne) : objectif `Int((Double(total) × 0,2).rounded())`. Unités : un exercice seul, ou les membres d'un même `supersetGroup` (dans l'ordre de première apparition). Par tour : unités triées par séries décroissantes (une unité de super set compte le maximum de ses membres), puis par ordre dans la séance ; chaque unité perd au plus une série par membre et par tour, seulement si chaque membre a plus d'une série et si `retirées + membres ≤ objectif`. On recommence un tour tant qu'un tour a retiré quelque chose et que l'objectif n'est pas atteint.
  - La durée estimée reste celle de `SessionSummary` (M3a, déjà conforme à la spec M3 §9.3) : rien à déplacer.

- [ ] **Step 1 : Écrire les tests**

Aide de test `push()` : un `RoutineDay` construit à la main comme le Push de PPL 3 — `bench-press-barbell` 4 séries 120 s, `chest-press-machine` 3 / 90 s, `pec-deck-machine` 3 / 60 s, `triceps-pushdown-cable` et `wrist-curl-cable` 3 / 60 s en super set 1, `crunch-machine` 3 / 60 s, tous à RPE 8 (19 séries).

```swift
@Test func optimalChangesNothing()          // adjust(push(), .optimal) : day == push(), adjustments vides, removedSets 0
@Test func normalAddsFifteenSeconds()       // repos [135, 105, 75, 75, 75, 75] ; adjustments == [rest 15]
@Test func moderateFatigueOnPush() {
    let adjusted = SessionAdjuster.adjust(push(), category: .moderateFatigue)
    #expect(adjusted.day.exercises.map(\.sets) == [3, 2, 2, 3, 3, 2])
    #expect(adjusted.removedSets == 4)
    #expect(adjusted.day.exercises.allSatisfy { $0.targetRPE == 7.5 })
    #expect(adjusted.day.exercises.map(\.restSeconds) == [165, 135, 105, 105, 105, 105])
    #expect(adjusted.adjustments == [
        SessionAdjustment(kind: .volume, reason: "Volume réduit de 19 à 15 séries", value: -4),
        SessionAdjustment(kind: .rpeCap, reason: "Effort plafonné à RPE 7,5", value: 7.5),
        SessionAdjustment(kind: .rest, reason: "Repos rallongés de 45 secondes", value: 45)
    ])
}
@Test func supersetLosesSetsTogether()      // [A 4 + B 4 en super set, C 2] : 10 séries → [3, 3, 2]
@Test func supersetSkippedWhenOneSetIsLeft()// [A 3 + B 3 en super set, C 1] : objectif 1 → [3, 3, 1], removedSets 0, pas de .volume
@Test func volumeLoopsOverRounds()          // [6, 1, 1] : objectif 2 → [4, 1, 1]
@Test func capOnlyWhenItLowersATarget()     // jour à RPE 7 en fatigue : kinds == [.volume, .rest]
@Test func overreachedStrengthProposesMobility() // day == push(), adjustments == [replaceWithMobility 20 …], isReplacedByMobility
@Test func runDays()                        // fractionné + fatigue → [.swapIntervalsForEasy] ; facile + fatigue → [] ;
                                            // course + surmenage → [.suggestRest] ; course + normal → [] ; day inchangé
```

- [ ] **Step 2 : Lancer, constater l'échec** — Run : `swift test --package-path Packages/PulseRecoveryEngine` ; Expected : FAIL à la compilation.

- [ ] **Step 3 : Implémenter les Interfaces** (raisons par `String(localized: …, bundle: .module)` avec interpolation des nombres).

- [ ] **Step 4 : VFT** (`PulseRecoveryEngine`, puis `PulseFeatures` qui en dépend).

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulseRecoveryEngine
git commit -m "feat(engine): adjust the day's session to the recovery category with named reasons"
```

---

### Task 4 : Design system — sparkline, jauge de charge, formats

**Files:**
- Create: `Packages/PulseDesignSystem/Sources/PulseDesignSystem/Presentation/SparklineGeometry.swift`, `Components/Sparkline.swift`, `Presentation/LoadGaugeGeometry.swift`, `Components/LoadGauge.swift`
- Modify: `Presentation/PulseFormat.swift`, `Resources/Localizable.xcstrings`
- Test: `Tests/PulseDesignSystemTests/SparklineGeometryTests.swift`, `LoadGaugeGeometryTests.swift`, `PulseFormatTests.swift`

**Interfaces:**
- Produces :
  - `enum SparklineGeometry { static func points(values: [Double?], in rect: CGRect, inset: CGFloat) -> [CGPoint?] }` : x réparti de `minX + inset` à `maxX − inset` (une seule valeur : `midX`) ; y : maximum en `minY + inset`, minimum en `maxY − inset`, valeurs toutes égales en `midY` ; `nil` reste `nil`.
  - `Sparkline(values: [Double?], color: Color, lineWidth: CGFloat = 2)` : segments entre valeurs consécutives présentes (un trou coupe la ligne), point plein sur la dernière valeur présente, `accessibilityHidden(true)` (la tuile porte l'étiquette).
  - `enum LoadGaugeGeometry { static func fraction(ratio: Double) -> Double }` : linéaire par morceaux par (0 ; 0), (0,8 ; 0,20), (1,3 ; 0,60), (1,5 ; 0,78), (2,0 ; 1), borné à 0…1.
  - `LoadGauge(ratio: Double, accessibilityLabel: String)` : barre de `.acwr` de la maquette (`run` 0–20 %, `ok` 20–60 %, `warn` 60–78 %, `bad` au-delà), repère rond couleur `text` cerclé `background`, libellés « Sous-entraînement », « 0,8 à 1,3 », « Risque ».
  - `PulseFormat.restDuration(seconds: Int) -> String` et `PulseFormat.decimal(_ value: Double, maxFractionDigits: Int) -> String` (fr_FR, virgule).

- [ ] **Step 1 : Écrire les tests**

```swift
@Test func sparklineSpansTheRect() {
    let points = SparklineGeometry.points(values: [10, nil, 20], in: CGRect(x: 0, y: 0, width: 100, height: 40), inset: 2)
    #expect(points[0] == CGPoint(x: 2, y: 38) && points[1] == nil && points[2] == CGPoint(x: 98, y: 2))
}
@Test func flatSparklineSitsInTheMiddle()   // [5, 5] → y == 20
@Test func singleValueIsCentered()          // [7], largeur 100 → x == 50
@Test func loadFractions()                  // 0 → 0 ; 0,8 → 0,2 ; 1,12 → 0,456 ; 1,5 → 0,78 ; 3 → 1 (à 1e-9 près)
@Test func restDurations()                  // 45 → "45 s" ; 120 → "2 min" ; 165 → "2 min 45" ; 65 → "1 min 05"
@Test func decimals()                       // (1.123, 2) → "1,12" ; (7.5, 1) → "7,5" ; (8, 1) → "8"
```

- [ ] **Step 2 : Lancer, constater l'échec** — Run : `swift test --package-path Packages/PulseDesignSystem` ; Expected : FAIL à la compilation.

- [ ] **Step 3 : Implémenter les Interfaces**, un `#Preview` par composant (sparkline avec trous ; jauge à 0,6, 1,12 et 1,7).

- [ ] **Step 4 : VFT.**

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulseDesignSystem
git commit -m "feat(design): add the sparkline, the linear training load gauge and rest and decimal formats"
```

---

### Task 5 : Domaine et persistance — le cache applique une lecture ancrée

**Files:**
- Create: `Packages/PulseDomain/Sources/PulseDomain/Health/NightSignal.swift`, `Health/HealthSampleChanges.swift`
- Modify: `Packages/PulseDomain/Sources/PulseDomain/Repositories/HealthSampleCache.swift`, `Packages/PulsePersistence/Sources/PulsePersistence/Repositories/SwiftDataHealthSampleCache.swift`, `Packages/PulseFeatures/Sources/PulseServices/Doubles/InMemoryHealthSampleCache.swift`
- Test: `Packages/PulseDomain/Tests/PulseDomainTests/M3bDomainTests.swift`, `Packages/PulsePersistence/Tests/PulsePersistenceTests/HealthSampleCacheTests.swift`, `Packages/PulseFeatures/Tests/PulseServicesTests/InMemoryRepositoriesTests.swift`

**Interfaces:**
- Produces :
  - `enum NightSignal: String, Sendable, CaseIterable { case sdnn, restingHeartRate, sleep; var kind: HealthSampleKind }` (ordre de lecture).
  - `struct HealthSampleChanges: Sendable, Equatable { var kind: HealthSampleKind; var added: [CachedHealthSample]; var deletedHealthKitUUIDs: [String]; var anchor: Data; var isFullRead: Bool }` (init membre à membre).
  - `HealthSampleCache.apply(_ changes: HealthSampleChanges) async throws` : lecture complète → tous les échantillons de ce type sont retirés ; sinon, ceux de ce type dont `healthKitUUID` est dans `deletedHealthKitUUIDs` ou parmi ceux de `added` ; puis `added` est inséré et l'ancre enregistrée, **en une seule sauvegarde** (SwiftData : un seul `modelContext.save()`). Les autres types ne bougent pas. `replace(kind:with:)` reste jusqu'à la tâche 6.

- [ ] **Step 1 : Écrire les tests** (mêmes noms pour la version SwiftData et la version en mémoire)

```swift
@Test func fullReadReplacesTheKind()          // 2 SDNN sans UUID (cache M3a) et 1 sommeil ; apply(sdnn, added [a], isFullRead) →
                                              // samples(.sdnn) == [a], sommeil intact, anchor(for: .sdnn) == l'ancre
@Test func incrementalReadRemovesDeleted()    // [a, b] puis apply(added [], deleted [a.uuid]) → [b]
@Test func returningSampleIsNotDuplicated()   // [a] puis apply(added [a]) → un seul a
@Test func anchorIsKeptPerKind()              // anchor(for: .sleep) == nil après un apply SDNN
```
`M3bDomainTests` : `NightSignal.allCases.map(\.kind) == [.sdnn, .restingHeartRate, .sleep]`.

- [ ] **Step 2 : Lancer, constater l'échec** — Run : `swift test --package-path Packages/PulsePersistence` ; Expected : FAIL à la compilation.

- [ ] **Step 3 : Implémenter les Interfaces.**

- [ ] **Step 4 : VFT** (`PulseDomain`, `PulsePersistence`, `PulseFeatures`).

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulseDomain Packages/PulsePersistence Packages/PulseFeatures/Sources/PulseServices/Doubles Packages/PulseFeatures/Tests/PulseServicesTests
git commit -m "feat(health): apply anchored Health changes to the sample cache in one write"
```

---

### Task 6 : Lecture ancrée — sources Apple Santé et historique des nuits

**Files:**
- Create: `Packages/PulseHealth/Sources/PulseHealth/HealthKitTypes.swift`, `Packages/PulseFeatures/Sources/PulseServices/Health/UnavailableHealthSource.swift`, `Packages/PulseFeatures/Tests/PulseServicesTests/Support/ScriptedHealthSource.swift`
- Delete: `Packages/PulseFeatures/Sources/PulseServices/Doubles/FailingHealthSource.swift`
- Modify: `Packages/PulseDomain/Sources/PulseDomain/Health/HealthSampleSource.swift`, `Repositories/HealthSampleCache.swift` (− `replace`), `Packages/PulseHealth/Sources/PulseHealth/HealthKitReader.swift`, `HealthKitReader+SampleSource.swift`, `Packages/PulseFeatures/Sources/PulseServices/Health/NightHistory.swift`, `CachedSampleMapping.swift`, `ScenarioHealthSource.swift`, les deux caches (− `replace`), `Pulse/AppDependencies.swift`, doublures de test (`TodayFeatureTests/Support/TodayFixture.swift`, `ConcurrencyDoubles.swift`, `OnboardingFeatureTests/Support/CountingDoubles.swift`, `OnboardingModelTests.swift`)
- Test: `Packages/PulseFeatures/Tests/PulseServicesTests/NightHistoryTests.swift`, `ScenarioTests.swift`

**Interfaces:**
- Consumes : `NightSignal`, `HealthSampleChanges`, `HealthSampleCache.apply` (tâche 5).
- Produces :
  - `protocol HealthSampleSource: Sendable { func requestAuthorization() async throws; func profileHints() async throws -> HealthProfileHints; func changes(of signal: NightSignal, since anchor: Data?, from start: Date) async throws -> HealthSampleChanges }` — les trois lectures par période quittent ce protocole (`HealthReading`, celui du diagnostic, garde les siennes).
  - `enum HealthKitTypes { static var read: Set<HKObjectType>; static func sampleType(for signal: NightSignal) -> HKSampleType; static var observed: [HKSampleType] }` : `read` = les dix types de l'onboarding ; `requestReadAuthorization()` (diagnostic) et `requestAuthorization()` demandent tous deux `read` (fin des deux listes).
  - `HealthKitReader.changes(of:since:from:)` : `HKAnchoredObjectQueryDescriptor` avec le prédicat `start…` sans fin et l'ancre décodée par `NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from:)` (illisible = absente) ; SDNN en ms et FC repos en bpm → `CachedHealthSample(kind:, start: endDate, end: endDate, value:, healthKitUUID: uuid.uuidString, sourceBundleID:, fetchedAt: endDate)` (même date que les lectures de M3a) ; sommeil → début, fin, phase ; objets supprimés → `uuid.uuidString` ; `isFullRead` = pas d'ancre utilisable ; nouvelle ancre par `NSKeyedArchiver.archivedData(withRootObject:requiringSecureCoding: true)`.
  - `ScenarioHealthSource.changes` : ancre = jour des données générées en texte (`"2026-11-02"`) ; sans ancre ou ancre d'un autre jour → lecture complète des échantillons dont le début est ≥ `start`, UUID déterministes `"scenario.<kind>.<n>"` ; même jour → aucun changement, `isFullRead` faux.
  - `struct UnavailableHealthSource: HealthSampleSource` (repli de production sans HealthKit ; chaque appel lance `UnavailableHealthSource.Failure.unavailable`), remplace `FailingHealthSource` partout.
  - `NightHistory.refresh(now:progress:)` (même signature) : pour chaque `NightSignal`, ancre du cache (`try?`), `source.changes(of:since:from: aujourd'hui − 60 j)`, échantillons ajoutés horodatés `fetchedAt = now`, `cache.apply` ; progression 0,25 / 0,5 / 0,75 après chaque signal, 1 à la fin ; puis les 60 nuits sont agrégées **depuis le cache**. `readAt = now` seulement si les trois lectures et écritures ont réussi ; un signal en échec garde son ancre et son cache. `HealthSampleCache.replace(kind:with:)` et `CachedSampleMapping.cached(…)` disparaissent.
  - Test seulement : `actor ScriptedHealthSource: HealthSampleSource` — `enqueue(_ result: Result<HealthSampleChanges, any Error>, for: NightSignal)`, `receivedAnchors(for: NightSignal) -> [Data?]`.

- [ ] **Step 1 : Écrire les tests**

```swift
@Test func firstRefreshReadsSixtyDaysAndStoresAnchors() // goodNight : 60 nuits, readAt == now, une ancre par signal dans le cache
@Test func secondRefreshOnlyAsksForChanges()            // ScriptedHealthSource : le 2ᵉ appel de chaque signal reçoit l'ancre du 1ᵉʳ ; nuits identiques
@Test func deletedSampleLeavesTheNights()               // 2ᵉ lecture : SDNN du jour supprimées → nights.last?.sdnnMs == nil
@Test func m3aCacheIsReplacedOnFirstAnchoredRead()      // cache prérempli par insert() avec les échantillons du scénario, sans UUID ni ancre →
                                                        // après refresh, nuits == celles d'un refresh sur cache vide (aucun doublon)
@Test func failingSignalKeepsItsAnchorAndCache()        // 2ᵉ lecture : le sommeil lance → readAt nil, ancre sommeil inchangée, sommeil des nuits gardé
@Test func unavailableSourceFallsBackToCache()          // (renommé) → nuits du cache, readAt nil
// ScenarioTests
@Test func scenarioSendsEverythingThenNothing()        // 1ᵉʳ appel : isFullRead, 180 SDNN (3 par nuit × 60) ; 2ᵉ avec l'ancre : added vide
@Test func scenarioResendsEverythingForAnotherDay()     // ancre "2026-11-01" pour des données du 2 → isFullRead
```
Les tests existants de `TodayFeatureTests` et `OnboardingFeatureTests` passent tels quels une fois leurs doublures réécrites sur `changes(of:since:from:)`.

- [ ] **Step 2 : Lancer, constater l'échec** — Run : `swift test --package-path Packages/PulseFeatures` ; Expected : FAIL à la compilation.

- [ ] **Step 3 : Implémenter les Interfaces** (`AppDependencies` : `UnavailableHealthSource()` en repli).

- [ ] **Step 4 : VFT** (`PulseDomain`, `PulsePersistence`, `PulseFeatures` ; `PulseHealth` par les deux compilations).

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulseDomain Packages/PulsePersistence Packages/PulseHealth Packages/PulseFeatures Pulse/AppDependencies.swift
git commit -m "feat(health): read Apple Health incrementally with anchored queries and one shared type list"
```

---

### Task 7 : Services — score du jour partagé, sérialisé, avec ajustements et séance d'origine

**Files:**
- Create: `Packages/PulseFeatures/Sources/PulseServices/Concurrency/SerialTaskQueue.swift`, `Tests/PulseServicesTests/SerialTaskQueueTests.swift`, `Tests/PulseServicesTests/Support/Gate.swift` (copie de la porte de `TodayFeatureTests`)
- Modify: `Sources/PulseServices/Score/DailyScoreService.swift`, `Score/TodayScore.swift`, `Today/TodayPlanner.swift`, `Sources/OnboardingFeature/OnboardingModel+Calibration.swift`, `Sources/TodayFeature/TodayModel.swift`, `Sources/TodayFeature/Views/TodayPreviewSupport.swift`, `Sources/OnboardingFeature/Views/OnboardingPreviewSupport.swift`, `Pulse/AppDependencies.swift`
- Test: `Tests/PulseServicesTests/DailyScoreServiceTests.swift`

**Interfaces:**
- Consumes : `SessionAdjuster` (tâche 3).
- Produces :
  - `actor SerialTaskQueue { init(); func run<T: Sendable>(_ operation: @escaping @Sendable () async throws -> T) async throws -> T }` : chaque opération démarre après la fin (réussie ou non) de la précédente, dans l'ordre d'appel.
  - `extension PlannedDay { var routineDay: RoutineDay? }` (musculation ou course).
  - `final class DailyScoreService: Sendable` (init inchangé : `init(recovery:calendar:)`) — **une seule instance** (`let scores` dans `AppDependencies`, partagée par l'onboarding et l'accueil) ; ses trois méthodes passent par la même file :
    - `update(nights: [NightSample], plannedDay: PlannedDay, now: Date) async throws -> TodayScore`
    - `saveCheckIn(_ answers: CheckInAnswers, plannedDay: PlannedDay, now: Date) async throws -> DailyRecovery`
    - `chooseOriginalSession(_ chosen: Bool, now: Date) async throws -> DailyRecovery`
  - `DailyScoreError` : `.frozen`, `.alreadyMeasured`, `.noScoreToday`.
  - Règles : tout score enregistré (mesuré ou estimé) porte `adjustments = SessionAdjuster.adjust(jour, category:).adjustments` pour `plannedDay.routineDay` (`[]` sinon) ; un recalcul garde `originalSessionChosen` ; `saveCheckIn` lance `.alreadyMeasured` si le score du jour est mesuré ; `chooseOriginalSession` enregistre `chosen` (vrai : séance d'origine ; faux : retour à l'ajustée), reste permis après le figement et ne change ni le score ni `frozenAt`. Le cycle de vie de M3a (4 h, midi, figement) est inchangé.
  - L'onboarding passe le jour prévu du programme adopté (`TodayPlanner.plan` sur `profile.activeProgramID`) à `update` et `saveCheckIn` ; l'accueil passe son `plannedDay`.

- [ ] **Step 1 : Écrire les tests**

```swift
@Test func measuredScoreStoresTheDaysAdjustments()   // badNight, lundi 2 nov 08:00, PPL 3 adopté → adjustments.map(\.kind) == [.volume, .rpeCap, .rest]
@Test func restDayStoresNoAdjustment()                // mardi 3 nov → adjustments vides
@Test func recomputeKeepsTheOriginalSessionChoice()   // update 07:00, chooseOriginalSession(true), update 09:00 avec d'autres nuits → originalSessionChosen == true
@Test func checkInIsRefusedOnceMeasured()             // goodNight : update puis saveCheckIn → throws .alreadyMeasured ; score inchangé
@Test func checkInStoresAdjustments()                 // threeNights, réponses (1, 1, 1) un lundi → isEstimated, adjustments non vides
@Test func originalSessionCanBeChosenAfterNoon()      // update 08:00, update 12:30 (figé), choose(true) 18:00 → score et frozenAt inchangés, choix vrai
@Test func choosingWithoutScoreThrows()               // noData → .noScoreToday
@Test func updateAndCheckInAreSerialised()            // dépôt dont save() passe une Gate : update bloqué, saveCheckIn lancé n'atteint pas
                                                      // le dépôt avant open() ; ensuite il lance .alreadyMeasured et un seul score existe
// SerialTaskQueueTests
@Test func operationsRunOneAtATimeInOrder()           // la 2ᵉ opération ne démarre qu'après la fin de la 1ʳᵉ (bloquée par une Gate)
@Test func aFailureDoesNotBlockTheNext()
```

- [ ] **Step 2 : Lancer, constater l'échec** — Run : `swift test --package-path Packages/PulseFeatures` ; Expected : FAIL à la compilation.

- [ ] **Step 3 : Implémenter les Interfaces**, puis adapter les appels (onboarding, accueil, aperçus, `AppDependencies`). Les tests existants de l'onboarding et de l'accueil restent verts.

- [ ] **Step 4 : VFT** (`PulseFeatures`).

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulseFeatures Pulse/AppDependencies.swift
git commit -m "feat(services): serialise the daily score, store the session adjustments and the original session choice"
```

---

### Task 8 : Services — séance du jour, instantané du widget, règle de la notification, lien vers l'accueil

**Files:**
- Create: `Packages/PulseDomain/Sources/PulseDomain/Widgets/WidgetSnapshot.swift`, `Notifications/MorningScoreMessage.swift`, `App/AppLink.swift` ; `Packages/PulseFeatures/Sources/PulseServices/Today/TodaySession.swift`, `Widgets/WidgetSnapshot+Session.swift`, `Notifications/MorningNotificationRule.swift`, `Resources/Localizable.xcstrings`
- Modify: `Packages/PulseFeatures/Package.swift` (`PulseServices` : `resources: [.process("Resources")]`)
- Test: `Packages/PulseDomain/Tests/PulseDomainTests/M3bDomainTests.swift`, `Packages/PulseFeatures/Tests/PulseServicesTests/TodaySessionTests.swift`, `WidgetSnapshotTests.swift`, `MorningNotificationRuleTests.swift`

**Interfaces:**
- Consumes : `SessionAdjuster`, `AdjustedSession` (tâche 3) ; `PlannedDay.routineDay` (tâche 7).
- Produces :
  - `struct WidgetSnapshot: Sendable, Equatable, Codable { var day: Date; var score: Int; var category: RecoveryCategory; var isEstimated: Bool; var sessionTitle: String?; var isLightened: Bool }`.
  - `struct MorningScoreMessage: Sendable, Equatable { var title: String; var body: String }`.
  - `enum AppLink: String, Sendable { case today; static let scheme = "fr.seonay.pulse"; var url: URL?; init?(url: URL) }` (`fr.seonay.pulse://today`).
  - `struct TodaySession: Sendable, Equatable` :
    - `init(plannedDay: PlannedDay, recovery: DailyRecovery?)` — `recovery` est le score **du jour** (nul avant 4 h ou sans score) ; `adjusted = recovery.flatMap { plannedDay.routineDay.map { SessionAdjuster.adjust($0, category: recovery.category) } }`.
    - `enum Status { case planned, adjusted, restored }` ; `status` : `.planned` sans ajustement (ou sans score), `.restored` si `recovery.originalSessionChosen == true`, sinon `.adjusted`.
    - `var plannedDay`, `var adjusted: AdjustedSession?`, `var originalChosen: Bool`, `var originalDay: RoutineDay?` (= `plannedDay.routineDay`), `var activeDay: RoutineDay?` (le jour ajusté en `.adjusted`, l'origine sinon).
    - `var isLightened: Bool` : `.adjusted` et au moins un ajustement autre que `.rest`.
    - `var title: String?` : musculation → nom du jour, suivi de « , volume allégé » en `.adjusted` quand le volume baisse ; course → `runType?.localizedName ?? name` ; repos et sans programme → nul.
  - `extension WidgetSnapshot { init(recovery: DailyRecovery, session: TodaySession) }` : `score = Int(recovery.score.rounded())`, titre et allègement de la séance.
  - `extension RecoveryCategory { var sentenceName: String }` dans `PulseServices` : « forme optimale », « forme normale », « fatigue modérée », « surmenage ».
  - `enum MorningNotificationRule { static let defaultDeadlineMinutes = 600; static func message(recovery: DailyRecovery, session: TodaySession, profile: UserProfile, lastOpenedAt: Date?, lastNotifiedDay: Date?, now: Date, calendar: Calendar) -> MorningScoreMessage? }` : un message seulement si le score est mesuré, du jour de `now`, `profile.morningScoreNotification` vrai, aucune ouverture de l'app depuis 4 h ce jour-là (`lastOpenedAt`), pas déjà notifié ce jour (`lastNotifiedDay`), et `now` avant l'heure plafond (`morningScoreDeadlineMinutes ?? 600` minutes après minuit). Titre « Ton score du matin est prêt », corps « {score} · {sentenceName} » suivi de « , séance allégée » si `session.isLightened`.

- [ ] **Step 1 : Écrire les tests**

```swift
// TodaySessionTests — PPL 3 adopté (ProgramAdopter), lundi 2 nov = Push
@Test func noScoreMeansPlanned()            // recovery nil → .planned, adjusted nil, activeDay == Push, title "Push", !isLightened
@Test func fatigueAdjustsAndLightens()      // fatigue → .adjusted, activeDay 15 séries, title "Push, volume allégé", isLightened
@Test func normalIsAdjustedNotLightened()   // normal → .adjusted, title "Push", !isLightened
@Test func restoredUsesTheOriginal()        // originalSessionChosen true → .restored, activeDay == Push (19 séries), !isLightened
@Test func overreachedKeepsTheDayAndLightens() // surmenage → .adjusted, activeDay == Push, isLightened
@Test func runTitleUsesTheRunType()         // runner-strength, jour du fractionné → "Fractionné"
@Test func restDayHasNoTitle()              // mardi → title nil, activeDay nil
// WidgetSnapshotTests
@Test func snapshotCarriesNoRawValue() throws {
    let data = try JSONEncoder().encode(WidgetSnapshot(recovery: fatigueRecovery, session: session))
    let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(Set(object.keys) == ["day", "score", "category", "isEstimated", "sessionTitle", "isLightened"])
}
@Test func snapshotRoundsTheScore()         // 58,4 → 58 ; 64,5 → 65
// MorningNotificationRuleTests — score 58,4 fatigue modérée, Push, lundi 2 nov 07:30
@Test func measuredMorningScoreGivesTheMessage() // title "Ton score du matin est prêt", body "58 · fatigue modérée, séance allégée"
@Test func normalSessionHasNoSuffix()       // 72, normal → "72 · forme normale"
@Test func estimatedScoreIsNotAnnounced()
@Test func disabledPreferenceIsRespected()
@Test func deadlineDefaultsToTen()          // 09:59 → message ; 10:00 → nil
@Test func customDeadline()                 // morningScoreDeadlineMinutes 450 : 07:29 → message ; 07:30 → nil
@Test func openingAfterFourSilencesIt()     // lastOpenedAt 07:00 → nil ; 02:00 → message
@Test func oncePerDay()                     // lastNotifiedDay aujourd'hui → nil ; hier → message
@Test func yesterdaysScoreIsNotAnnounced()
// M3bDomainTests
@Test func appLinkRoundTrips()              // url?.absoluteString == "fr.seonay.pulse://today" ; AppLink(url:) == .today ; "https://x" → nil
```

- [ ] **Step 2 : Lancer, constater l'échec** — Run : `swift test --package-path Packages/PulseDomain && swift test --package-path Packages/PulseFeatures` ; Expected : FAIL à la compilation.

- [ ] **Step 3 : Implémenter les Interfaces.**

- [ ] **Step 4 : VFT** (`PulseDomain`, `PulseFeatures`).

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulseDomain Packages/PulseFeatures
git commit -m "feat(services): describe the day's session and derive the widget snapshot and the morning notification"
```

---

### Task 9 : Services — rafraîchissement du jour (`DayRefresher`)

**Files:**
- Create: `Packages/PulseDomain/Sources/PulseDomain/Widgets/WidgetPublishing.swift`, `Repositories/NotificationScheduling.swift` ; `Packages/PulseFeatures/Sources/PulseServices/Refresh/DayActivityLog.swift`, `Refresh/DayRefresh.swift`, `Refresh/DayRefresher.swift`
- Test: `Packages/PulseFeatures/Tests/PulseServicesTests/DayRefresherTests.swift`, `DayActivityLogTests.swift`, `Support/RefresherFixture.swift`

**Interfaces:**
- Consumes : `NightHistory` (tâche 6), `DailyScoreService` (tâche 7), `TodaySession`, `WidgetSnapshot`, `MorningNotificationRule` (tâche 8).
- Produces :
  - `protocol WidgetPublishing: Sendable { func publish(_ snapshot: WidgetSnapshot) async; func clear() async }` et `actor StubWidgetPublisher: WidgetPublishing { init(); var published: [WidgetSnapshot]; var clearCount: Int }`.
  - `protocol NotificationScheduling: Sendable { func scheduleMorningScore(_ message: MorningScoreMessage) async; func cancelMorningScore() async }` et `actor StubNotificationScheduler { init(); var scheduled: [MorningScoreMessage]; var cancelCount: Int }`.
  - `protocol DayActivityLog: Sendable { func lastOpenedAt() -> Date?; func markOpened(at: Date); func lastNotifiedDay() -> Date?; func markNotified(day: Date) }`, `final class UserDefaultsDayActivityLog: DayActivityLog { init(suiteName: String?) }` (clés `pulse.lastOpenedAt`, `pulse.lastNotifiedDay`, effacées par la suppression totale), `final class InMemoryDayActivityLog: DayActivityLog`.
  - `struct DayRefresh: Sendable, Equatable { var profile: UserProfile?; var nights: [NightSample]; var readAt: Date?; var plannedDay: PlannedDay; var score: TodayScore?; var session: TodaySession; var checkIn: CheckIn? }` (`score` nul si le calcul a échoué ; `checkIn` : celui du jour quand le score est estimé).
  - `final class DayRefresher: Sendable` :
    - `init(profiles:programs:recovery:nightHistory:scores:widgets:notifications:activity:calendar:now:)` (types : les protocoles de dépôt, `NightHistory`, `DailyScoreService`, `any WidgetPublishing`, `any NotificationScheduling`, `any DayActivityLog`, `Calendar`, `@escaping @Sendable () -> Date`).
    - `enum Origin: Sendable { case foreground, background }`.
    - `refresh(origin: Origin) async -> DayRefresh` ; `saveCheckIn(_ answers: CheckInAnswers) async throws -> DailyRecovery` ; `chooseOriginalSession(_ chosen: Bool) async throws -> DailyRecovery`. Les trois passent par une `SerialTaskQueue` propre au rafraîchisseur.
  - `refresh`, dans l'ordre : profil ; en arrière-plan sans profil terminé (`onboardingCompletedAt` nul), retour immédiat sans rien lire ni publier ; au premier plan, `activity.markOpened(at: now)` et `notifications.cancelMorningScore()` ; programme actif et `TodayPlanner.plan` ; `nightHistory.refresh(now:)` ; `scores.update(nights:plannedDay:now:)` ; `TodaySession` ; si `.scored(recovery)` : `widgets.publish(WidgetSnapshot(recovery:session:))`, et en arrière-plan, si `MorningNotificationRule.message(…)` rend un message, `scheduleMorningScore` puis `markNotified(day:)` ; check-in du jour si le score est estimé. `saveCheckIn` et `chooseOriginalSession` relisent le jour prévu, appellent le service du score puis republient l'instantané.

- [ ] **Step 1 : Écrire les tests** (`RefresherFixture` : dépôts en mémoire, `ScenarioHealthSource`, `InMemoryHealthSampleCache`, doublures, horloge modifiable, PPL 3 adopté, onboarding terminé)

```swift
@Test func foregroundRefreshScoresPlansAndPublishes() // goodNight lundi 08:00 → .scored optimal, session .planned "Push" ; un instantané
                                                     // (score arrondi, "Push", !isLightened) ; lastOpenedAt == now ; cancelCount 1 ; aucun message
@Test func backgroundRefreshNotifiesOnce()          // badNight 07:30 → un message "… · fatigue modérée, séance allégée" ; 2ᵉ refresh → toujours un
@Test func concurrentBackgroundRefreshesNotifyOnce() // trois refresh(.background) lancés ensemble → scheduled.count == 1
@Test func openedAppSilencesTheBackground()          // refresh(.foreground) 07:00 puis refresh(.background) 07:30 → aucun message
@Test func backgroundBeforeOnboardingDoesNothing()   // aucun profil → source jamais lue, rien publié
@Test func backgroundRefreshWithUnreadableHealthKeepsTheScore() // score à 07:00, puis source en échec, refresh(.background) 08:00 →
                                                     // même score, readAt nil, pas de plantage
@Test func choosingTheOriginalRepublishesAsNormal()  // badNight → chooseOriginalSession(true) → dernier instantané !isLightened ;
                                                     // valeur rendue originalSessionChosen == true
@Test func checkInPublishesAnEstimatedSnapshot()     // threeNights → saveCheckIn → dernier instantané isEstimated ; refresh suivant : checkIn non nul
@Test func noScoreNoSnapshot()                       // noData → .needsCheckIn, published vide
// DayActivityLogTests
@Test func userDefaultsLogRoundTrips()               // suite dédiée, vidée avant et après
```

- [ ] **Step 2 : Lancer, constater l'échec** — Run : `swift test --package-path Packages/PulseFeatures --filter "DayRefresher|DayActivityLog"` ; Expected : FAIL à la compilation.

- [ ] **Step 3 : Implémenter les Interfaces** (l'app n'est pas encore branchée : tâche 11).

- [ ] **Step 4 : VFT** (`PulseDomain`, `PulseFeatures`).

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulseDomain Packages/PulseFeatures
git commit -m "feat(services): refresh the day in one serialised pass for the foreground and the background"
```

---

### Task 10 : Accueil — 20 minutes de mobilité

**Files:**
- Create: `Packages/PulseFeatures/Sources/TodayFeature/Mobility/MobilityTimer.swift`, `Mobility/MobilityGuide.swift`, `Views/MobilitySheet.swift`
- Modify: `Sources/TodayFeature/Resources/Localizable.xcstrings`
- Test: `Packages/PulseFeatures/Tests/TodayFeatureTests/MobilityTimerTests.swift`

**Interfaces:**
- Produces :
  - `struct MobilityTimer: Sendable, Equatable { static let duration: TimeInterval = 1200; enum Phase: Sendable, Equatable { case ready, running(since: Date, elapsedBefore: TimeInterval), paused(elapsed: TimeInterval), finished }; private(set) var phase: Phase; init(); mutating func start(at: Date); mutating func pause(at: Date); mutating func finish(); func remaining(at: Date) -> TimeInterval; func isOver(at: Date) -> Bool; static func clockText(_ remaining: TimeInterval) -> String }` — `start` depuis `ready` ou `paused` ; `remaining` borné à 0 ; `clockText` arrondit à la seconde supérieure (« 20:00 »).
  - `enum MobilityGuide { static var steps: [String] }` : « Hanches : 10 cercles lents de chaque côté, puis 1 min en fente basse par jambe. », « Chevilles : 10 flexions du genou vers l'avant par cheville, talon au sol. », « Colonne thoracique : 10 rotations à quatre pattes de chaque côté. », « Épaules : 10 passages de bâton ou d'élastique devant puis derrière. », « Respiration : 2 min allongé, inspire 4 s, expire 6 s. ».
  - `public struct MobilitySheet: View { public init() }` : titre « 20 min de mobilité », minuteur en grands chiffres tabulaires (`TimelineView(.periodic(from:by: 1))`), boutons « Démarrer », « Pause », « Reprendre », « Terminer » (≥ 50 pt), les cinq consignes, la phrase « Rien n'est enregistré : la mobilité ne compte ni dans la charge ni dans ta série. », bouton « Fermer ». **Horloge murale** (`Date.now` au toucher, date du `TimelineView`) : une horloge fixée par `-PulseNow` figerait le minuteur ; c'est de l'interface, la logique reste dans `MobilityTimer`. Étiquette VoiceOver du minuteur : « Temps restant 18 minutes 55 secondes ».

- [ ] **Step 1 : Écrire les tests**

```swift
@Test func countsDownFromTwentyMinutes()     // start(t0) → remaining(t0 + 65) == 1135 ; clockText(1135) == "18:55"
@Test func pauseFreezesTheRemainingTime()    // start t0, pause t0+60 → remaining(t0+600) == 1140 ; start t0+600 → remaining(t0+660) == 1080
@Test func endsAtZero()                      // remaining(t0 + 1300) == 0 ; isOver
@Test func finishEndsAtOnce()                // finish() → .finished, isOver
@Test func clockTexts()                      // 1200 → "20:00" ; 0,4 → "00:01" ; 0 → "00:00"
@Test func guideHasFiveSteps()               // 5 consignes, commençant par « Hanches », « Chevilles », « Colonne thoracique », « Épaules », « Respiration »
```

- [ ] **Step 2 : Lancer, constater l'échec** — Run : `swift test --package-path Packages/PulseFeatures --filter MobilityTimer` ; Expected : FAIL à la compilation.

- [ ] **Step 3 : Implémenter les Interfaces**, avec un `#Preview`.

- [ ] **Step 4 : VFT** (`PulseFeatures`).

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulseFeatures/Sources/TodayFeature Packages/PulseFeatures/Tests/TodayFeatureTests
git commit -m "feat(today): add the 20 minute mobility sheet with a pausable timer"
```

---

### Task 11 : Accueil — modèle sur `DayRefresher`, carte séance complète, Démarrer

**Files:**
- Create: `Packages/PulseFeatures/Sources/TodayFeature/Session/SessionCardState.swift`, `Session/SessionPlanLine.swift`, `TodayModel+Session.swift`, `Views/StrengthSessionCard.swift`, `Views/StartSessionSheet.swift`
- Modify: `Packages/PulseFeatures/Package.swift` (`TodayFeature` + `PulseRecoveryEngine`), `Sources/TodayFeature/TodayEnvironment.swift`, `TodayModel.swift`, `TodayIdentifiers.swift`, `Views/TodayView.swift`, `Views/SessionCard.swift`, `Views/TodayPreviewSupport.swift`, `Resources/Localizable.xcstrings`, `Pulse/AppDependencies.swift`
- Test: `Packages/PulseFeatures/Tests/TodayFeatureTests/SessionCardStateTests.swift`, `SessionPlanLineTests.swift`, `TodayModelTests.swift`, `TodayModelConcurrencyTests.swift`, `Support/TodayFixture.swift`, `Support/ConcurrencyDoubles.swift`

**Interfaces:**
- Consumes : `DayRefresher`, `DayRefresh` (tâche 9), `TodaySession` (tâche 8), `MobilitySheet` (tâche 10).
- Produces :
  - `TodayEnvironment(refresher: DayRefresher, library: ContentLibrary, calendar: Calendar, now: @escaping @Sendable () -> Date)` (la tâche 13 y ajoute `workouts`).
  - `TodayModel` garde `greeting`, `dateText`, `lastSync`, `lastSyncText`, `score`, `factors`, `marker`, `isLoading`, `errorMessage`, `checkIn` et la garde contre une lecture périmée ; gagne `private(set) var session: TodaySession?`, `private(set) var card: SessionCardState = .noProgram`, `var sheet: TodaySheet?`, et `func chooseOriginalSession(_ chosen: Bool) async`, `func startSession()` (`sheet = .start(activeDay)` pour une séance de musculation), `func startMobility()` (`sheet = .mobility`). `refresh()` appelle `refresher.refresh(origin: .foreground)` ; `submitCheckIn()` appelle `refresher.saveCheckIn`. `public enum TodaySheet: Identifiable, Equatable { case start(RoutineDay), mobility }`. `summary` disparaît (dans la carte).
  - `struct StrengthCard: Equatable { enum Badge { case adjusted, planned }; var title: String; var badge: Badge; var summary: SessionSummary; var showsWhy: Bool; var originButton: String?; var startButton: String }`, `struct RunCard: Equatable { var title: String; var target: String?; var suggestion: String? }`, `enum SessionCardState: Equatable { case strength(StrengthCard); case mobilityOrRest(dayName: String); case run(RunCard); case rest(next: NextSession?, suggestsMobility: Bool); case noProgram; static func make(session: TodaySession, score: TodayScore?, library: ContentLibrary) -> SessionCardState }`.
    - Musculation `.adjusted` : `session.title`, `.adjusted`, résumé du jour ajusté, `showsWhy`, « Séance d'origine », « Démarrer la séance ». `.restored` : nom du jour, `.planned`, résumé d'origine, `showsWhy`, « Revenir à l'ajustée », « Démarrer quand même ». `.planned` : nom du jour, `.planned`, résumé d'origine, ni Pourquoi ni bouton d'origine, « Démarrer la séance ».
    - Surmenage ajusté un jour de musculation : `.mobilityOrRest(dayName:)` — texte « Ton corps a besoin de récupérer : 20 min de mobilité ou repos complet, au choix. », bouton principal « 20 min de mobilité », bouton « Séance d'origine » (rétabli, la carte redevient `.strength` en `.restored`). Choisir le repos, c'est ne rien faire : rien n'est enregistré (spec V1 §5.2).
    - Course : titre et cible comme en M3a ; `suggestion` : `.swapIntervalsForEasy` → « Fatigue modérée : remplace le fractionné par une sortie facile de même durée. », `.suggestRest` → « Surmenage : repos conseillé aujourd'hui, la course peut attendre. ». Pas de bouton Démarrer.
    - Repos : `suggestsMobility` si le score du jour (`.scored`) est sous 65 ; la carte montre alors « Score sous 65 : 20 min de mobilité t'aideront à récupérer. » et un bouton qui appelle `startMobility()`.
  - `struct SessionPlanLine: Equatable { var name: String; var prescription: String; var rest: String; static func lines(for day: RoutineDay, library: ContentLibrary) -> [SessionPlanLine] }` : nom du contenu (`name.fr`, « Exercice personnel » pour un exercice de l'utilisateur), « 3 × 6–10 », « repos 2 min 45 », super set signalé par « super set » dans `rest`.
  - `StartSessionSheet(day: RoutineDay, library: ContentLibrary)` : titre « La séance en direct arrive bientôt », phrase « En attendant, voici ta séance à suivre en salle : », la liste des `SessionPlanLine`, bouton « Fermer ».
  - `TodayIdentifiers` garde `score` et `sessionTitle` (test d'interface de M3a) et gagne `sessionStart = "today.session.start"`, `sessionOrigin = "today.session.origin"`, `sessionWhy = "today.session.why"`.
  - `AppDependencies` : `let activity: any DayActivityLog` (`UserDefaultsDayActivityLog(suiteName: defaultsSuite)`), `let refresher: DayRefresher` construit une fois sur `scores`, `nightHistory` et les dépôts, avec `StubWidgetPublisher()` et `StubNotificationScheduler()` provisoires (remplacés en tâches 14 et 15) ; `todayEnvironment()` le passe.

- [ ] **Step 1 : Écrire les tests**

```swift
// SessionCardStateTests (PPL 3, lundi = Push ; runner-strength pour la course)
@Test func fatigueOnPushIsAnAdjustedCard()   // title "Push, volume allégé", .adjusted, summary.setCount 15, showsWhy, "Séance d'origine", "Démarrer la séance"
@Test func restoredCardOffersBackToAdjusted()// .planned, setCount 19, "Revenir à l'ajustée", "Démarrer quand même"
@Test func optimalCardIsPlannedWithoutWhy()  // .planned, !showsWhy, originButton nil
@Test func beforeFourTheCardIsPlanned()      // score .beforeDayStart → .planned, sans bouton d'origine
@Test func overreachedProposesMobilityOrRest() // .mobilityOrRest(dayName: "Push")
@Test func overreachedRestoredShowsTheOriginal() // → .strength(.planned, "Revenir à l'ajustée", "Démarrer quand même")
@Test func intervalsUnderFatigueSuggestAnEasyRun() // RunCard("Fractionné", "30 min", "Fatigue modérée : remplace le fractionné par une sortie facile de même durée.")
@Test func restDaySuggestsMobilityUnder65()  // 58 → vrai ; 70 → faux ; .needsCheckIn → faux
@Test func noProgramCard()
// SessionPlanLineTests
@Test func linesShowAdjustedSetsAndRest()    // Push en fatigue : 1ʳᵉ ligne = nom de "bench-press-barbell", "3 × 6–10", "repos 2 min 45"
// TodayModelTests (réécrits sur l'environnement à base de DayRefresher ; tous les cas de M3a gardés)
@Test func refreshScoresAndShowsMondayPush() // goodNight → .strength(.planned) "Push", 19 séries ; lastSyncText "08:00"
@Test func badNightShowsTheAdjustedPush()     // .strength(.adjusted), 15 séries
@Test func chooseOriginalSessionSwitchesTheCard() // true → .restored ; false → de nouveau .adjusted
@Test func startOpensTheSheetWithTheActiveDay()   // badNight → startSession() → sheet == .start(jour ajusté)
@Test func startMobilityOpensTheSheet()
```

- [ ] **Step 2 : Lancer, constater l'échec** — Run : `swift test --package-path Packages/PulseFeatures --filter "SessionCardState|SessionPlanLine|TodayModel"` ; Expected : FAIL à la compilation.

- [ ] **Step 3 : Implémenter les Interfaces.** Vues d'après `today` de la maquette (badge « Ajustée » accent, « Planifiée » neutre ; boutons « Pourquoi ? » et « Séance d'origine » côte à côte en `SecondaryButtonStyle`, « Démarrer » en `PrimaryButtonStyle`) ; la vue présente `sheet` par `.sheet(item:)` (`StartSessionSheet` ou `MobilitySheet`) ; aperçus `goodNight`, `badNight`, surmenage, repos, course.

- [ ] **Step 4 : VFT** (`PulseFeatures`).

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulseFeatures Pulse/AppDependencies.swift
git commit -m "feat(today): show the adjusted session with the original session choice and a start sheet"
```

---

### Task 12 : Accueil — écran Pourquoi

**Files:**
- Create: `Packages/PulseFeatures/Sources/TodayFeature/Why/WhyContent.swift`, `Why/WhyReading.swift`, `Why/WhyChanges.swift`, `Why/WhySignals.swift`, `Views/WhyView.swift`
- Modify: `Sources/TodayFeature/TodayModel.swift`, `Views/TodayView.swift` (`NavigationStack`, destination), `Views/RecoveryCard.swift` (toucher la carte), `Views/StrengthSessionCard.swift` (« Pourquoi ? »), `Resources/Localizable.xcstrings`
- Test: `Packages/PulseFeatures/Tests/TodayFeatureTests/WhyContentTests.swift`, `TodayModelTests.swift`

**Interfaces:**
- Consumes : `TodaySession` (tâche 8), `CheckInQuestion` (M3a), `PulseFormat` (tâche 4).
- Produces :
  - `struct WhyContent: Equatable, Sendable { struct Change: Equatable, Sendable { var pill: String; var title: String; var detail: String? }; struct Signal: Equatable, Sendable { var title: String; var score: Int }; enum Action: Equatable, Sendable { case startSession, startMobility }; var reading: String; var changes: [Change]; var signals: [Signal]; var formula: String; var rule: String; var primaryAction: Action?; var restoreTitle: String?; static func make(recovery: DailyRecovery, session: TodaySession, checkIn: CheckIn?, library: ContentLibrary) -> WhyContent }`.
  - **Lecture** : propositions des facteurs présents, dans l'ordre VFC, FC, sommeil, jointes « A, B et C. », première lettre en capitale. VFC : écart arrondi `(sdnn − base) / base × 100` ; ≤ −5 → « ta variabilité cardiaque est 18 % sous ta moyenne de 14 jours » ; ≥ 5 → « … 12 % au-dessus de ta moyenne de 14 jours » ; sinon « … proche de ta moyenne de 14 jours ». FC : écart arrondi ; ≥ 2 → « ta fréquence au repos a pris 5 bpm » ; ≤ −2 → « ta fréquence au repos a baissé de 2 bpm » ; sinon « ta fréquence au repos est stable ». Sommeil : sous 420 min → « tu n'as dormi que 5 h 10 », sinon « tu as dormi 8 h ». Puis, si un facteur manque : « Pas de variabilité cette nuit : le score repose sur le sommeil et la fréquence au repos. » / « Pas de fréquence au repos cette nuit : le score repose sur la variabilité et le sommeil. » / « Pas de sommeil enregistré cette nuit : le score repose sur la variabilité et la fréquence au repos. ». Puis, en calibration avec la VFC présente : « Ta ligne de base se construit encore : 9 nuits sur 14. ». Puis la conclusion : optimal « Tu es en pleine forme : la séance prévue reste telle quelle. », normal « Ta récupération est correcte : la séance reste la même, avec un peu plus de repos. », fatigue « Ton système nerveux est sous tension : la séance est allégée. », surmenage « Ton corps demande du repos : mobilité douce ou repos complet aujourd'hui. ». Score estimé : « Pas de données de nuit : ce score vient de ton check-in. » puis la conclusion.
  - **Changements** : un `Change` par ajustement de `session.adjusted` — `.volume` pastille « −4 » (U+2212), titre = raison, détail « Une série en moins sur : A, B et C. » (exercices qui ont perdu des séries, noms du contenu ; « Des séries en moins sur : … » si l'un en a perdu plus d'une) ; `.rpeCap` « 7,5 », détail « Arrête-toi deux répétitions avant l'échec sur chaque série de travail. » ; `.rest` « +45 » / « +15 », détail « 2 min 45 au lieu de 2 min sur A. » (premier exercice) ; `.replaceWithMobility` « 20 », détail « La séance prévue reste disponible avec « Séance d'origine ». » ; `.swapIntervalsForEasy` « → » ; `.suggestRest` « 0 ». Puis, en normal et fatigue un jour de musculation : « = », « Charges inchangées », « Celles de ta dernière séance, sans surcharge progressive aujourd'hui. ». Sans ajustement : un seul `Change("✓", "Rien à alléger aujourd'hui.", nil)`, ou `Change("✓", "Pas de séance aujourd'hui : rien à ajuster.", nil)` un jour de repos ou sans programme.
  - **Signaux** : score mesuré → « Variabilité », « FC au repos », « Sommeil » (facteurs présents, sous-scores arrondis) ; formule « Score = 50 % × 59 + 25 % × 58 + 25 % × 56 = 58 » avec les poids appliqués (renormalisés, pourcentages entiers) et le score arrondi. Score estimé → « Sommeil : Bon », « Courbatures et douleurs : Légères », « Motivation : Bonne » (libellés de `CheckInQuestion`, score = réponse × 25), formule « Score = 40 % × 75 + 35 % × 75 + 25 % × 75 = 75 ».
  - **Règle** : optimal « À 90 et plus, la séance prévue reste telle quelle. » ; normal « Entre 65 et 89, la séance reste la même, avec 15 secondes de repos en plus entre les séries. » ; fatigue « Entre 40 et 64, la séance perd 20 % de son volume, l'effort est plafonné à RPE 7,5 et les repos s'allongent de 45 secondes. » ; surmenage « Sous 40, la séance laisse place à 20 minutes de mobilité ou à du repos, au choix. ».
  - **Boutons** : `primaryAction` `.startMobility` si surmenage ajusté, `.startSession` pour une autre séance de musculation, nul sinon (titres « Démarrer 20 min de mobilité », « Valider et démarrer ») ; `restoreTitle` « Rétablir la séance d'origine » en `.adjusted`, « Revenir à l'ajustée » en `.restored`, nul en `.planned` ; phrase fixe « Tu gardes toujours le dernier mot. ».
  - `TodayModel` : `private(set) var why: WhyContent?` (nul sans score du jour), `var isShowingWhy = false`, `func showWhy()` (sans effet si `why` est nul) ; le check-in du jour vient de `DayRefresh.checkIn` ou des réponses que l'accueil vient d'enregistrer. `WhyView(model:)` : poussée dans le `NavigationStack` de l'accueil ; restaurer appelle `chooseOriginalSession` puis revient.

- [ ] **Step 1 : Écrire les tests**

```swift
@Test func readingWithThreeFactorsFollowsTheMockup() {
    // sdnn 44, base 53,66 ; FC 54, base 49 ; sommeil 310 min ; fatigue modérée
    #expect(content.reading == "Ta variabilité cardiaque est 18 % sous ta moyenne de 14 jours, ta fréquence au repos a pris 5 bpm "
        + "et tu n'as dormi que 5 h 10. Ton système nerveux est sous tension : la séance est allégée.")
}
@Test func goodNightReading()          // sdnn 56 / 50, FC 48 / 50, 480 min, optimal → "Ta variabilité cardiaque est 12 % au-dessus de ta moyenne
                                        // de 14 jours, ta fréquence au repos a baissé de 2 bpm et tu as dormi 8 h. Tu es en pleine forme : …"
@Test func missingHRVIsSaid()          // contient "Pas de variabilité cette nuit : le score repose sur le sommeil et la fréquence au repos."
@Test func calibrationIsSaid()         // .calibrating(nights: 9), VFC présente → contient "Ta ligne de base se construit encore : 9 nuits sur 14."
@Test func formulaUsesTheAppliedWeights()   // sous-scores 59 / 58 / 56, score 58 → "Score = 50 % × 59 + 25 % × 58 + 25 % × 56 = 58"
@Test func formulaRenormalisesWithoutHRV()  // FC 58, sommeil 56, score 57 → "Score = 50 % × 58 + 50 % × 56 = 57"
@Test func estimatedShowsTheAnswers()       // check-in (3, 3, 3), score 75 → signaux et formule ci-dessus, lecture "Pas de données de nuit : …"
@Test func fatigueChangesOnPush()           // pastilles ["\u{2212}4", "7,5", "+45", "="] ; titre 0 "Volume réduit de 19 à 15 séries" ;
                                            // détails 0 et 2 construits avec les noms lus dans ContentLibrary.bundled
@Test func optimalHasNothingToLighten()     // changes == [Change("✓", "Rien à alléger aujourd'hui.", nil)], restoreTitle nil, .startSession
@Test func restoredOffersBackToAdjusted()   // restoreTitle "Revenir à l'ajustée"
@Test func overreachedStartsMobility()      // .startMobility, pastille "20"
@Test func categoryRules()                  // les quatre règles exactes
@Test func restDayHasNothingToAdjust()      // "Pas de séance aujourd'hui : rien à ajuster.", primaryAction nil
// TodayModelTests
@Test func whyIsAvailableOnceScored()       // goodNight → why non nul ; noData → nil, showWhy() ne fait rien
```

- [ ] **Step 2 : Lancer, constater l'échec** — Run : `swift test --package-path Packages/PulseFeatures --filter "WhyContent|TodayModel"` ; Expected : FAIL à la compilation.

- [ ] **Step 3 : Implémenter les Interfaces** (une fonction par section, fichiers sous 400 lignes) ; `WhyView` d'après `pourquoi` (carte opale « Lecture de ce matin », lignes à pastille, barres colorées par ton de catégorie, boutons), aperçus mesuré, estimé, surmenage.

- [ ] **Step 4 : VFT** (`PulseFeatures`).

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulseFeatures/Sources/TodayFeature Packages/PulseFeatures/Tests/TodayFeatureTests
git commit -m "feat(today): explain the score and every adjustment on the why screen"
```

---

### Task 13 : Accueil — charge d'entraînement et tendances

**Files:**
- Create: `Packages/PulseFeatures/Sources/PulseServices/Today/TrainingLoad.swift`, `Sources/TodayFeature/Load/LoadCardContent.swift`, `Trends/TrendTile.swift`, `Views/LoadCard.swift`, `Views/TrendTilesView.swift`
- Modify: `Sources/TodayFeature/TodayEnvironment.swift` (+ `workouts`), `TodayModel.swift`, `Views/TodayView.swift`, `Views/TodayPreviewSupport.swift`, `Resources/Localizable.xcstrings`, `Pulse/AppDependencies.swift`, `Tests/TodayFeatureTests/Support/TodayFixture.swift`
- Test: `Packages/PulseFeatures/Tests/PulseServicesTests/TrainingLoadTests.swift`, `Tests/TodayFeatureTests/LoadCardContentTests.swift`, `TrendTileTests.swift`, `TodayModelTests.swift`

**Interfaces:**
- Consumes : `LoadCalculator`, `ACWRResult` (M1), `LoadGauge`, `Sparkline` (tâche 4), `DayRefresh.nights` (tâche 9).
- Produces :
  - `enum TrainingLoad { static func acwr(sessions: [WorkoutSession], onboardingCompletedAt: Date?, now: Date, calendar: Calendar) -> ACWRResult? }` : séances `.completed` seulement ; minutes = `durationMinutes` sinon `endedAt − startedAt` ; RPE = `overallRPE ?? estimatedRPE ?? 6`, plafonné à 5 pour `.ride` ; début de l'historique = le plus ancien de `onboardingCompletedAt` et de la première séance lue ; `LoadCalculator.acwr` (nul sous 28 jours ou sans charge).
  - `enum LoadCardContent: Equatable { case hidden; case ratio(value: Double, valueText: String, zoneTitle: String, advice: String); static let hiddenText: String; static func make(_ result: ACWRResult?) -> LoadCardContent }` : `hiddenText` = « La jauge de charge apparaîtra après 28 jours d'entraînement : elle compare ta dernière semaine à ton mois. » ; zones « Sous-entraînement » / « Tu peux augmenter progressivement ta charge. », « Zone optimale » / « Tu peux maintenir ce rythme cette semaine. », « Charge élevée » / « Ta charge monte vite : surveille ta récupération. », « Risque de blessure » / « Ta charge a bondi : allège les prochains jours. » ; `valueText` par `PulseFormat.decimal(_, maxFractionDigits: 2)`.
  - `struct TrendTile: Equatable { var factor: Factor; var title: String; var valueText: String; var values: [Double?]; var accessibilityLabel: String; static func make(nights: [NightSample], day: Date, calendar: Calendar) -> [TrendTile] }` : trois tuiles « Variabilité, 14 jours » (dernière SDNN valide, « 44 ms »), « FC repos, 14 jours » (dernière valeur, « 54 bpm »), « Sommeil, 14 jours » (moyenne, « 7 h 12 ») ; 14 valeurs du jour − 13 au jour, trous à nul ; « — » sans valeur ; étiquette « Variabilité, 14 jours, dernière valeur 44 ms ».
  - `TodayEnvironment` gagne `workouts: any WorkoutRepository` ; `TodayModel` gagne `private(set) var load: LoadCardContent = .hidden` et `private(set) var trends: [TrendTile] = []`, calculés à chaque `refresh()` (séances `from:` début du jour − 27 j, `to:` lendemain). `TodayView` : `LoadCard` (titre « Charge d'entraînement », pastille de zone, jauge, « Ratio aigu / chronique 1,12. » et le conseil ; sinon le texte caché) puis les trois tuiles (deux colonnes, une seule aux tailles d'accessibilité).

- [ ] **Step 1 : Écrire les tests**

```swift
// TrainingLoadTests
@Test func hiddenBeforeTwentyEightDays()     // onboarding il y a 20 j, séances régulières → nil
@Test func ratioOverFourWeeks()               // onboarding il y a 40 j, 4 séances par semaine de 60 min à RPE 7 sur 28 j → ratio 1
@Test func ridesAreCappedAtFive()             // vélo 60 min RPE 8 → charge comptée 300
@Test func unfinishedSessionsDoNotCount()
// LoadCardContentTests
@Test func hiddenWithoutResult()              // make(nil) == .hidden ; hiddenText exact
@Test func optimalRatio()                     // 1,12 → "1,12", "Zone optimale", "Tu peux maintenir ce rythme cette semaine."
@Test func zones()                            // 0,6 « Sous-entraînement » ; 1,4 « Charge élevée » ; 1,7 « Risque de blessure »
// TrendTileTests — scénarios au lundi 2 nov
@Test func threeTilesOverFourteenDays()       // titres dans l'ordre, values.count == 14
@Test func goodNightTexts()                   // "56 ms", "48 bpm", "8 h"
@Test func missingHRVKeepsTheLastValue()      // missingHRV → values.last == nil, valueText "52 ms"
@Test func noDataShowsDashes()                // trois "—", toutes valeurs nulles
// TodayModelTests
@Test func refreshFillsLoadAndTrends()        // goodNight → load == .hidden, trends.count == 3
```

- [ ] **Step 2 : Lancer, constater l'échec** — Run : `swift test --package-path Packages/PulseFeatures --filter "TrainingLoad|LoadCardContent|TrendTile|TodayModel"` ; Expected : FAIL à la compilation.

- [ ] **Step 3 : Implémenter les Interfaces**, aperçus (charge cachée, 1,12, 1,7 ; tendances goodNight et missingHRV).

- [ ] **Step 4 : VFT** (`PulseFeatures`).

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulseFeatures Pulse/AppDependencies.swift
git commit -m "feat(today): add the training load gauge and the fourteen day trend tiles"
```

---

### Task 14 : Widgets — instantané, contenu, extension, publication et effacement

**Files:**
- Create: `Packages/PulseFeatures/Sources/WidgetFeature/WidgetSnapshotFile.swift`, `RecoveryWidgetContent.swift`, `RecoveryWidgetTimeline.swift`, `Views/RecoveryWidgetSmallView.swift`, `Views/RecoveryWidgetCircularView.swift` ; `PulseWidgets/RecoveryWidget.swift`, `PulseWidgets/RecoveryTimelineProvider.swift` ; `Pulse/Widgets/AppGroupWidgetPublisher.swift`
- Delete: `Packages/PulseFeatures/Sources/WidgetFeature/WidgetFeature.swift`, `Tests/WidgetFeatureTests/WidgetFeatureSmokeTests.swift`
- Modify: `Sources/WidgetFeature/Resources/Localizable.xcstrings`, `PulseWidgets/PulseWidgetsBundle.swift`, `Packages/PulsePersistence/Sources/PulsePersistence/Erase/SwiftDataEraser.swift`, `Pulse/AppDependencies.swift`
- Test: `Packages/PulseFeatures/Tests/WidgetFeatureTests/RecoveryWidgetContentTests.swift`, `WidgetSnapshotFileTests.swift`, `Packages/PulsePersistence/Tests/PulsePersistenceTests/EraserTests.swift`

**Interfaces:**
- Consumes : `WidgetSnapshot`, `AppLink` (tâche 8), `WidgetPublishing` (tâche 9), `RecoveryGauge` (M3a, style `.compact`).
- Produces :
  - `struct WidgetSnapshotFile: Sendable { static let appGroupIdentifier = "group.fr.seonay.pulse"; static let fileName = "recovery-widget.json"; let url: URL; init(url: URL); static func appGroup(fileManager: FileManager = .default) -> WidgetSnapshotFile?; func read() -> WidgetSnapshot?; @discardableResult func write(_ snapshot: WidgetSnapshot) throws -> Bool; func delete() throws }` : JSON à clés triées, dates ISO 8601 ; `read` rend nul pour un fichier absent ou illisible ; `write` rend faux sans réécrire si le contenu est identique ; `appGroup` est nul sans l'App Group.
  - `struct RecoveryWidgetContent: Sendable, Equatable { static let kind = "RecoveryWidget"; static var displayName: String; static var summary: String; var score: Int?; var category: RecoveryCategory?; var categoryText: String; var footer: String?; var inlineText: String; var accessibilityLabel: String; static func make(snapshot: WidgetSnapshot?, at date: Date, calendar: Calendar) -> RecoveryWidgetContent }` — instantané du jour de `date` : `categoryText` = nom de la catégorie (`localizedName`), suivi de « · estimé » si estimé ; `footer` « Séance allégée » si allégée, « Séance normale » avec un titre, « Pas de séance aujourd'hui » sinon ; `inlineText` « 58 · fatigue modérée » ; étiquette « Récupération 58 sur 100, fatigue modérée, séance allégée ». Autre jour ou aucun instantané : score et catégorie nuls, `categoryText` et `inlineText` « Score pas encore prêt », `footer` nul, étiquette « Récupération : score pas encore prêt ». `displayName` « Récupération », `summary` « Ton score du matin et ta séance du jour. ».
  - `enum RecoveryWidgetTimeline { static func entryDates(now: Date, calendar: Calendar) -> [Date] }` : `[now, début du lendemain]` (politique `.atEnd` dans l'extension).
  - `RecoveryWidgetSmallView(content:)` (jauge compacte, score, catégorie, pied, d'après `ios-accueil` ; lisible en monochrome) et `RecoveryWidgetCircularView(content:)` (jauge et score) ; vues SwiftUI sans WidgetKit, avec aperçus.
  - Extension `PulseWidgets` : `RecoveryWidget` (`StaticConfiguration(kind: RecoveryWidgetContent.kind)`, familles `.systemSmall`, `.accessoryCircular`, `.accessoryInline`, `containerBackground` opale pour le petit, `.widgetURL(AppLink.today.url)`), `RecoveryTimelineProvider` (lit `WidgetSnapshotFile.appGroup()?.read()` à chaque timeline ; entrées aux `entryDates`, `Calendar.current`). L'extension ne contient aucune logique testable.
  - `struct AppGroupWidgetPublisher: WidgetPublishing { init(file: WidgetSnapshotFile?) }` : `publish` écrit et, si le contenu a changé, `WidgetCenter.shared.reloadTimelines(ofKind: RecoveryWidgetContent.kind)` ; `clear` supprime le fichier et recharge ; erreurs ignorées (le widget est un confort). `AppDependencies` le passe au `DayRefresher` et à l'effaceur à la place de la doublure ; le mode mémoire (`-PulseStore inMemory`) et `testing()` gardent `StubWidgetPublisher`.
  - `SwiftDataEraser.init(container:defaultsSuite:defaultsDomain:healthEraser:notifications:widgets:exportsDirectory:)` (`widgets: (any WidgetPublishing)?`) : `await widgets?.clear()` juste après l'effacement du magasin.

- [ ] **Step 1 : Écrire les tests**

```swift
// RecoveryWidgetContentTests — instantané du lundi 2 nov : 58, fatigue modérée, "Push", allégée
@Test func todaySnapshotShowsScoreAndSession()  // à 09:00 : score 58, categoryText "Fatigue modérée", footer "Séance allégée",
                                                // inlineText "58 · fatigue modérée", étiquette "Récupération 58 sur 100, fatigue modérée, séance allégée"
@Test func normalSessionFooter()               // isLightened faux → "Séance normale"
@Test func noSessionFooter()                   // sessionTitle nul → "Pas de séance aujourd'hui"
@Test func estimatedIsSaid()                   // → "Fatigue modérée · estimé"
@Test func yesterdaysSnapshotIsNotShownAsToday()// à 3 nov 02:00 → score nul, "Score pas encore prêt", footer nul
@Test func missingSnapshotShowsPlaceholder()
@Test func timelineChangesAtNextMidnight()     // now 2026-10-24T22:00 Paris → [now, 2026-10-25T00:00 Paris] (nuit de 25 h)
// WidgetSnapshotFileTests (dossier temporaire)
@Test func fileRoundTrip()                     // write → vrai ; read == instantané ; même write → faux ; delete → read nul
@Test func unreadableFileIsNoSnapshot()        // contenu "{" → nil
// EraserTests
@Test func eraseClearsTheWidgetSnapshot()      // StubWidgetPublisher → clearCount == 1
```

- [ ] **Step 2 : Lancer, constater l'échec** — Run : `swift test --package-path Packages/PulseFeatures --filter "RecoveryWidget|WidgetSnapshotFile" && swift test --package-path Packages/PulsePersistence --filter Eraser` ; Expected : FAIL à la compilation.

- [ ] **Step 3 : Implémenter les Interfaces.**

- [ ] **Step 4 : VFT** (`PulseFeatures`, `PulsePersistence` ; l'extension compile dans `make build-app` et `make build-release`).

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulseFeatures/Sources/WidgetFeature Packages/PulseFeatures/Tests/WidgetFeatureTests PulseWidgets \
  Pulse/Widgets Pulse/AppDependencies.swift Packages/PulsePersistence
git commit -m "feat(widgets): add the recovery widget for the home and lock screens fed by an app group snapshot"
```

---

### Task 15 : App — livraison en arrière-plan, notification du matin, retour à l'accueil

**Files:**
- Create: `Packages/PulseHealth/Sources/PulseHealth/HealthKitBackgroundDelivery.swift`, `Pulse/AppDelegate.swift`, `Pulse/Root/AppRouter.swift`, `Pulse/Notifications/UserNotificationScheduler.swift`, `Pulse/Notifications/NotificationRouter.swift`, `PulseTests/AppRouterTests.swift`
- Modify: `Pulse/PulseApp.swift`, `Pulse/AppDependencies.swift`, `Pulse/Root/AppRootView.swift`, `Pulse/Root/MainTabView.swift`, `Pulse/Debug/DataDebugModel.swift`, `PulseTests/DataDebugModelTests.swift`

**Interfaces:**
- Consumes : `DayRefresher` (tâche 9), `HealthKitTypes.observed` (tâche 6), `AppLink` (tâche 8), `NotificationScheduling` (tâche 9), `NotificationCanceling` (M2).
- Produces :
  - `final class HealthKitBackgroundDelivery: @unchecked Sendable { init(reader: HealthKitReader); func start(onChange: @escaping @Sendable () async -> Void) }` : pour chaque type de `HealthKitTypes.observed`, une `HKObserverQuery` exécutée et `enableBackgroundDelivery(for:frequency: .immediate)` (erreurs ignorées) ; à chaque réveil, `onChange` est attendu puis le gestionnaire de fin de HealthKit est appelé, même en cas d'erreur (gestionnaire enveloppé dans une petite boîte `@unchecked Sendable`).
  - `final class AppDelegate: NSObject, UIApplicationDelegate` : possède `let dependencies = AppDependencies.live()` et `let router = AppRouter()` ; dans `application(_:didFinishLaunchingWithOptions:)`, avant de rendre `true` : `UNUserNotificationCenter.current().delegate = NotificationRouter(router:)` (référence gardée) et `dependencies.backgroundDelivery?.start { await refresher.refresh(origin: .background) }` ; `applicationProtectedDataDidBecomeAvailable(_:)` relance `refresh(origin: .background)` si l'app n'est pas active (lecture refaite après un échec iPhone verrouillé). `PulseApp` : `@UIApplicationDelegateAdaptor(AppDelegate.self)` et `AppRootView(dependencies: appDelegate.dependencies, router: appDelegate.router)`.
  - `AppDependencies` : `let backgroundDelivery: HealthKitBackgroundDelivery?` (nul sans HealthKit, avec un scénario ou en mémoire) ; `UserNotificationScheduler()` passé au `DayRefresher` et à l'effaceur (`notifications:`), `StubNotificationScheduler` en mode mémoire et dans `testing()` ; `testing(…, inspector: (any StoreInspector)? = nil)` pour remplacer l'inspecteur en test.
  - `struct UserNotificationScheduler: NotificationScheduling, NotificationCanceling { static let morningScoreIdentifier = "fr.seonay.pulse.morning-score" }` : `scheduleMorningScore` → `UNNotificationRequest` immédiat (déclencheur nul), titre et corps du message, son par défaut, `userInfo["link"] = AppLink.today.rawValue` ; `cancelMorningScore` retire la notification en attente et livrée de cet identifiant ; `cancelAllScheduled` retire tout.
  - `@MainActor @Observable final class AppRouter { var selectedTab: MainTabView.Item = .today; func open(_ link: AppLink) }` ; `MainTabView` lie sa sélection au routeur ; `AppRootView` : `.onOpenURL { AppLink(url: $0).map(router.open) }`.
  - `final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate` : `static func link(from userInfo: [AnyHashable: Any]) -> AppLink` (`.today` par défaut) ; `didReceive` → `router.open(link)` sur l'acteur principal ; `willPresent` → `[.banner, .sound]`.
  - `DataDebugModel.erase` pose `didErase = true` dès que `eraseEverything` a réussi, avant de recompter (un recomptage en échec n'efface plus le succès).

- [ ] **Step 1 : Écrire les tests** (cible `PulseTests`, compilés seulement)

```swift
@Test func openingTodaySelectsTheTab()           // selectedTab = .profile ; open(.today) → .today
@Test func notificationLinkDefaultsToToday()     // link(from: ["link": "today"]) == .today ; link(from: [:]) == .today
@Test func eraseReportsSuccessBeforeTheRecount() // testing(inspector: inspecteur qui échoue au recomptage après effacement)
                                                 // → didErase vrai, lastError non nul, isBusy faux
```

- [ ] **Step 2 : Implémenter les Interfaces.**

- [ ] **Step 3 : VFT** (lint, `make build-app` qui compile `PulseTests`, `make build-release`). **Ne pas exécuter** les tests de la cible app.

- [ ] **Step 4 : Commit**

```bash
git add Packages/PulseHealth Pulse PulseTests
git commit -m "feat(app): compute the score on Health background delivery, send the morning notification and open today from links"
```

---

### Task 16 : Vérification finale, documentation, revue, PR

**Files:**
- Modify: `README.md` (feuille de route : M3b fait), `docs/superpowers/plans/2026-10-31-pulse-v1-roadmap.md` (M3 fait, renvoi vers ce plan)

- [ ] **Step 1 : Tout vérifier**

Run : `git branch --show-current && make test-packages && swiftlint lint --strict`, puis (hors bac à sable) `make build-app && make build-release`
Expected : `m3b-accueil-widgets` ; chaque package vert ; 0 violation ; codes de sortie 0.

- [ ] **Step 2 : Documentation, commit**

```bash
git add README.md docs/superpowers/plans/2026-10-31-pulse-v1-roadmap.md
git commit -m "docs: mark M3b done in the roadmap"
```

- [ ] **Step 3 : Revue de toute la branche** par Opus avec `superpowers:requesting-code-review`, contre la spec M3 (partie M3b), les reports de M3a et la Review Focus ; corriger les points retenus en TDD, un commit par correction, VFT après chaque vague.

- [ ] **Step 4 : PR — seulement avec l'accord explicite de Mathéo pour pousser**

`git branch --show-current` puis `git push -u origin m3b-accueil-widgets` et `gh pr create --base master --head m3b-accueil-widgets`, avec un résumé et ce qui reste à Mathéo : lancer `make test-app` et le test d'interface ; activer l'App Group `group.fr.seonay.pulse` sur le compte développeur si la signature automatique ne le fait pas ; vérifier sur quelques matins réels le score à l'ouverture, la livraison en arrière-plan, la notification, le widget (accueil, écran verrouillé, veille) et le figement à midi ; garder `CFBundleShortVersionString` et `CFBundleVersion` identiques dans `Pulse/Info.plist` et `PulseWidgets/Info.plist` à chaque montée de version (`make check-versions`) ; déployer le schéma CloudKit V2 en production avant TestFlight. Terminer la description par la ligne de fin de PR demandée par la session.
