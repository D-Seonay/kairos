# Pulse V2a — Course GPS dans l'app : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** lancer une course depuis Pulse avec le GPS de l'iPhone (séance d'entraînement HealthKit iOS 26), la suivre à l'écran, en Live Activity et à la voix, puis la retrouver dans la charge, le planning et les stats, écrite dans Apple Santé avec son tracé, sans doublon avec la montre et sans perte après un crash.

**Architecture:** lot 1, le moteur. Les calculs purs vivent dans `PulseServices/Run` : distance filtrée, temps par km, allures, dénivelé, simplification du tracé et doublons. Le stockage passe en V5 avec un tracé synchronisé, un brouillon local et un résumé cardio local. `RunSessionService` orchestre la course derrière des protocoles du domaine (séance HealthKit, localisation, voix, Live Activity, rappel). Lot 2, les adaptateurs et les écrans : l'adaptateur HealthKit dans `PulseHealth` ; Core Location, la voix et le rappel dans l'app ; la Live Activity de course ; la nouvelle cible `RunFeature` ; les points d'entrée Accueil, Séance et Planning ; le branchement dans l'app, l'Info.plist et les textes de confidentialité.

**Tech Stack:** Swift 6.2, SwiftUI, MapKit, HealthKit (`HKWorkoutSession`, `HKLiveWorkoutBuilder`, `HKWorkoutRouteBuilder` sur iPhone, iOS 26), Core Location (`CLLocationUpdate.liveUpdates`), AVFoundation (`AVSpeechSynthesizer`), ActivityKit et App Intents, SwiftData + CloudKit, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-11-23-pulse-v2a-course-gps-design.md`, à lire avant chaque tâche. Les chemins et signatures cités viennent d'une lecture du dépôt à 07d7c52.

## Global Constraints

- **Branche** : `v2a-course-gps`.
  - Avant tout commit, `git branch --show-current` doit afficher `v2a-course-gps` : Mathéo partage ce checkout.
  - Lancer `git status --short`, puis ajouter les nouveaux fichiers **par nom**. Ne jamais ajouter `.agents/`, `.gemini/` ni `.superpowers/`.
  - Pas de trailer `Co-Authored-By`. Ne jamais pousser.
- **Ne jamais lancer le simulateur** : pas de `xcodebuild test`, `make test`, `make test-app`, `simctl`.
  - Vérifier avec `swift test --package-path Packages/<Nom>`, `make lint`, `make build-app` et `make build-release`. Avec Xcode 27, `-quiet` n'affiche aucune bannière : on juge au code de sortie 0.
  - `PulseHealth` ne compile pas avec `swift test` sur macOS. Il se vérifie avec `make build-app`.
  - Le lint et les tests passent chacun dans une commande à part. On ne commite qu'après avoir lu leur résultat.
- **Frontière M8** : tout ce qui est lu dans Apple Santé reste local, y compris tout ce que livre `HKLiveWorkoutBuilder` (FC, distance du podomètre, énergie).
  - Une course Pulse synchronisée a toujours `averageHeartRate == nil` et `estimatedRPE == nil` dans le magasin synchronisé.
  - La distance affichée, synchronisée et écrite dans Santé est **la distance GPS filtrée**, et elle seule.
- **Valeurs de la spec à reprendre telles quelles** :
  - précision GPS « Prêt » ≤ 20 m ; point écarté si la précision dépasse 25 m ou si la vitesse implicite dépasse 25 km/h ;
  - allure du km en cours : moyenne des 30 dernières secondes sous 100 m dans le km ;
  - doublon : chevauchement ≥ 50 % de la durée de la plus courte ;
  - brouillon écrit au moins toutes les 10 s et à chaque pause ;
  - oubli : 30 min sans déplacement hors pause ;
  - Live Activity mise à jour au plus toutes les 15 s, plus à chaque km et à chaque pause ou reprise ;
  - simplification du tracé à environ 5 m ;
  - RPE du récap sans valeur présélectionnée.
- **Textes** : en français. Dans les packages, `String(localized:…, bundle: .module)` ; dans l'app, `String(localized:)`.
  - À l'oral, les unités s'écrivent en toutes lettres via `PulseSpoken`. À l'écran, les valeurs passent par `PulseFormat`.
  - Les commentaires sont en français, avec la densité du code voisin.
- **Accessibilité M8b** :
  - libellés parlés produits par des fonctions testées ;
  - annonces via `PulseAnnouncement`, le passage d'un km en priorité `.low` ;
  - mises en page pour les grandes tailles de texte et Réduire les animations ;
  - les mêmes règles s'appliquent à la Live Activity et au widget.
- **Style Argentique** : papier et encre ; `PulsePalette.signal` réservé à ce qui alerte, `PulsePalette.run` pour la course. Réutiliser `ObsidianCard`, `PulseSectionHeader`, `PulseRow`, `PillButtonStyle`, `PrimaryButtonStyle`, `IconChip` et `PulseFont`. Les écrans poussés reprennent `.pulseInlineTitle()` et `.pulseScreenBackground(aura: 0.5)`.
- **Non-objectifs** (spec §2) : pas de Bluetooth, de fractionné guidé, de pause automatique, de tapis, de vélo en direct, de carte pendant la course ni d'export GPX/Strava.

## Écarts assumés avec la spec (lus dans le code)

1. **Doublon calculé à la lecture.** La spec parle d'un doublon « marqué » dans le stockage local. Le plan le calcule plutôt à la lecture, avec `RunDuplicates`, dans un dépôt décorateur que tout le monde utilise sauf `WorkoutHistory`. Le comportement reste celui du §5.3, y compris le retour du doublon quand la course Pulse est supprimée, et il n'y a pas de marque à tenir à jour.
2. **Temps par km et dénivelé dans `StoredRunTrack`.** Ils vivent dans le nouveau modèle synchronisé, pas dans `StoredWorkoutSession`. On évite ainsi de figer `StoredWorkoutSession` et `StoredWorkoutSet` pour V3 et V4.
3. **« RPE compté »** : c'est la règle déjà en place dans `TrainingLoad.loadSession` (`overallRPE ?? estimatedRPE ?? 6`). Le dépôt remplit `estimatedRPE` en mémoire, depuis le résumé cardio local puis depuis le doublon, sans jamais l'écrire côté synchronisé.
4. **Anti-interférence inchangée.** Le code ne juge une course intense que sur le type planifié (`AntiInterference.swift:195`), et la spec dit « même règle qu'aujourd'hui ».
5. **Réglage des annonces vocales** : il vit dans `UserDefaults`, par appareil, comme `HealthReadWindowStore`, pas dans `UserProfile`. On évite ainsi de figer `StoredProfile`.

## Review Focus

1. **Course enregistrée aussi par la Fitbit** (chevauchement total, partiel à 40 % ou à 60 %, course coupée en deux par la montre) : elle compte une seule fois dans la charge, le planning et les stats. Le RPE estimé du doublon remplit la course Pulse en mémoire. → tests `fullOverlapHidesTheWatchRun`, `fortyPercentOverlapKeepsBoth`, `splitWatchRunIsHiddenTwice`, `duplicateEstimatedRPEFillsThePulseRun` (tâche 5).
2. **App tuée en pleine course, reprise HealthKit impossible** : au lancement suivant, l'app propose « Course interrompue », avec la distance rejouée depuis les points du brouillon. L'enregistrer l'écrit dans Pulse et dans Santé. → tests `interruptedDraftIsOfferedWithReplayedDistance`, `savingAnInterruptedRunWritesItWithoutLiveSession` (tâche 6).
3. **Localisation refusée** : la course enregistre le temps seul. `distanceMeters` vaut `nil` (jamais 0), la course compte dans la charge et l'écran le dit. → test `locationDeniedRecordsTimeOnly` (tâche 6).
4. **Écriture Santé refusée ou en échec** : la course est gardée dans Pulse avec `healthKitUUID == nil`, et l'erreur ne bloque pas le récap. → test `healthWriteFailureStillSavesTheRun` (tâche 6).
5. **Longue pause** (20 min) : les points reçus pendant la pause n'ajoutent rien à la distance, la pause ne compte ni dans les temps par km ni dans l'allure, et aucun rappel d'oubli ne part. → tests `pausedPointsAddNoDistance`, `splitsExcludePausedTime` (tâche 2), `pausedRunNeverSchedulesForgottenReminder` (tâche 6).

---

## Lot 1 — Moteur et stockage

### Task 1: Types de course du domaine

**Files:**
- Create: `Packages/PulseDomain/Sources/PulseDomain/Run/RunTrack.swift` (`RunTrackPoint`, `RunSplit`, `RunTrack`, `RunPause`)
- Create: `Packages/PulseDomain/Sources/PulseDomain/Run/RunLaunch.swift`
- Create: `Packages/PulseDomain/Sources/PulseDomain/Run/RunDraft.swift`
- Create: `Packages/PulseDomain/Sources/PulseDomain/Run/RunRecording.swift` (protocoles des adaptateurs et doublures `Stub…`)
- Create: `Packages/PulseDomain/Sources/PulseDomain/Repositories/RunRepositories.swift` (`RunTrackRepository`, `RunDraftStore`, `RunHealthSummaryStore`)
- Test: `Packages/PulseDomain/Tests/PulseDomainTests/RunTypesTests.swift`

**Interfaces:**
- Produces (tout est `public`, `Sendable`, `Equatable`, et `Codable` quand ça se stocke) :

```swift
public struct RunTrackPoint { var timestamp: Date; var latitude: Double; var longitude: Double
    var altitude: Double?; var horizontalAccuracy: Double; var verticalAccuracy: Double? }
public struct RunPause { var start: Date; var end: Date? }                     // end nil = pause en cours
public struct RunSplit { var kilometer: Int; var seconds: Double; var distanceMeters: Double } // dernier partiel < 1000 m
public struct RunTrack: Identifiable { var id: UUID /* = sessionID */; var points: [RunTrackPoint]   // simplifiés
    var splits: [RunSplit]; var elevationGainMeters: Double?; var createdAt: Date; var updatedAt: Date }

public struct RunLaunch { var title: String; var programID: UUID?; var routineDayID: UUID?; var runType: RunType?
    var targetMinutes: Int?; var targetKm: Double?; var adjustmentNote: String?
    /// Progression 0…1 vers l'objectif ; nil sans objectif.
    public func targetProgress(movingSeconds: Double, distanceMeters: Double?) -> Double? }

public struct RunDraft { var sessionID: UUID; var launch: RunLaunch; var startedAt: Date; var pauses: [RunPause]
    var points: [RunTrackPoint] /* bruts */; var heartRates: [Double]; var locationDenied: Bool; var updatedAt: Date }

public enum RunLocationAuthorization { case notDetermined, authorized, denied }
public protocol RunLocationTracking: Sendable {
    func authorization() async -> RunLocationAuthorization
    func requestAuthorization() async -> RunLocationAuthorization
    func start() async -> AsyncStream<RunTrackPoint>
    func stop() async }
public struct RunWorkoutEntry { var sessionID: UUID; var start: Date; var end: Date; var pauses: [RunPause]
    var distanceMeters: Double?; var route: [RunTrackPoint] /* points retenus, non simplifiés */ }
public protocol RunWorkoutRecording: Sendable {
    func writeAccess() async -> HealthWriteAccess
    func requestWriteAccess() async -> HealthWriteAccess
    /// Démarre la séance HealthKit ; le flux rend la FC si la séance en livre.
    func start(sessionID: UUID, at date: Date) async throws -> AsyncStream<Double>
    func pause(at date: Date) async
    func resume(at date: Date) async
    /// Termine la séance en cours et écrit l'entraînement ; nil s'il n'y a pas de séance vivante.
    func finish(_ entry: RunWorkoutEntry) async throws -> UUID?
    /// Écrit un entraînement sans séance vivante (course interrompue).
    func save(_ entry: RunWorkoutEntry) async throws -> UUID
    func discard() async
    /// Rattache une séance que le système a gardée après un crash ; vrai si elle tourne encore.
    func recoverActiveSession() async -> Bool }
public protocol RunAnnouncing: Sendable { func announce(_ text: String) async }
public struct RunActivityState { var sessionID: UUID; var title: String; var timerStart: Date? /* nil en pause */
    var frozenElapsedSeconds: Int; var distanceMeters: Double?; var averagePaceSecondsPerKm: Int?; var isPaused: Bool }
public protocol RunActivityControlling: Sendable {
    func start(_ state: RunActivityState) async; func update(_ state: RunActivityState) async
    func end() async; func endAll() async }
public protocol RunReminderScheduling: Sendable { func scheduleForgotten(at date: Date) async; func cancelForgotten() async }

public protocol RunTrackRepository: Sendable {
    func track(for sessionID: UUID) async throws -> RunTrack?
    func save(_ track: RunTrack) async throws
    func delete(sessionID: UUID) async throws }
public protocol RunDraftStore: Sendable {
    func load() async throws -> RunDraft?; func save(_ draft: RunDraft) async throws; func clear() async throws }
public struct RunHealthSummary { var sessionID: UUID; var averageHeartRate: Double?; var estimatedRPE: Double? }
```

- Doublures dans le même fichier que leur protocole, sur le modèle de `StubWorkoutHealthWriter` : `StubRunWorkoutRecorder`, `StubRunLocationTracker` (les points se poussent à la main), `StubRunAnnouncer` (retient les textes), `StubRunActivityController`, `StubRunReminderScheduler`. Ce sont des `actor`, ou des classes avec `Mutex` comme le voisinage.

- [ ] **Step 1: Write the failing test** `RunTypesTests` :
  - `targetProgressFollowsMinutesOrKilometres` :
    - avec `targetMinutes: 30` et 900 s en mouvement → `0.5` ;
    - avec `targetKm: 5` et `distanceMeters: 4000` → `0.8` ;
    - sans objectif → `nil` ;
    - avec `targetKm` mais une distance `nil` → `nil`.
  - `draftRoundTripsThroughJSON` : `JSONDecoder().decode(RunDraft.self, from: JSONEncoder().encode(draft)) == draft`, avec une pause ouverte et deux points dont un sans altitude.
- [ ] **Step 2: Run** `swift test --package-path Packages/PulseDomain --filter RunTypesTests`. Expected: FAIL (types absents).
- [ ] **Step 3: Implement** les fichiers ci-dessus. `targetProgress` ne borne pas au-dessus de 1, pour que l'annonce « objectif atteint » se déclenche à ≥ 1.
- [ ] **Step 4: Run** le même filtre, puis `swift test --package-path Packages/PulseDomain`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(domain): run track, draft, launch and recorder protocols`.

### Task 2: Distance, temps par km et allures (`RunTrackBuilder`)

**Files:**
- Create: `Packages/PulseFeatures/Sources/PulseServices/Run/RunTrackBuilder.swift`
- Create: `Packages/PulseFeatures/Sources/PulseServices/Run/RunClock.swift`
- Create: `Packages/PulseFeatures/Tests/PulseServicesTests/Support/RunTraceFactory.swift`
- Test: `Packages/PulseFeatures/Tests/PulseServicesTests/RunTrackBuilderTests.swift`

**Interfaces:**
- Consumes: `RunTrackPoint`, `RunPause`, `RunSplit` (tâche 1).
- Produces:

```swift
public enum RunClock {
    /// Secondes en mouvement entre `start` et `date`, pauses retirées (une pause ouverte court jusqu'à `date`).
    public static func movingSeconds(from start: Date, pauses: [RunPause], at date: Date) -> Double }
public struct RunTrackBuilder: Sendable, Equatable {
    public static let maxHorizontalAccuracy = 25.0          // m
    public static let maxSpeed = 25.0 / 3.6                 // m/s
    public static let readyAccuracy = 20.0                  // m, état « Prêt »
    public init(startedAt: Date)
    public private(set) var distanceMeters: Double
    public private(set) var accepted: [RunTrackPoint]       // points retenus, pour Santé et la simplification
    public private(set) var lastMovementAt: Date?
    /// Ajoute un point. Rend le numéro du km passé, s'il y en a un.
    public mutating func add(_ point: RunTrackPoint, isPaused: Bool) -> Int?
    /// Après une pause ou une reprise : le point suivant ouvre un nouveau segment, sans distance depuis le précédent.
    public mutating func breakSegment()
    public func splits(pauses: [RunPause], end: Date) -> [RunSplit]
    public func currentKilometerPace(pauses: [RunPause], at date: Date) -> Int?     // s/km
    public func averagePace(pauses: [RunPause], at date: Date) -> Int?              // s/km, nil sous 50 m
    public func elevationGainMeters() -> Double?
    public static func replay(startedAt: Date, points: [RunTrackPoint], pauses: [RunPause]) -> RunTrackBuilder }
```

Règles (spec §5.1) :
- **Filtrage** :
  - un point dont la précision horizontale dépasse 25 m est ignoré ;
  - un point dont la vitesse implicite par rapport au **dernier point retenu** dépasse 25 km/h est ignoré ;
  - un point reçu en pause est ignoré ;
  - le premier point après `breakSegment()` est retenu sans ajouter de distance.
- **Distance** : haversine (rayon 6 371 000 m).
- **`lastMovementAt`** : l'horodatage du dernier point qui a ajouté plus de 0 m.
- **Temps par km** : l'instant de passage de chaque multiple de 1 000 m est interpolé linéairement entre les deux points. Les secondes d'un km valent `RunClock.movingSeconds` au passage, moins la même valeur au passage précédent. Le dernier km partiel va jusqu'à `end`.
- **Allure du km en cours** : temps en mouvement depuis le dernier passage, rapporté aux mètres faits depuis. Sous 100 m dans le km, on prend l'allure des 30 dernières secondes en mouvement, et `nil` si ces 30 s font moins de 20 m.
- **Dénivelé positif** :
  - on ne garde que les points avec `verticalAccuracy` ≤ 10 m ;
  - on applique une hystérésis de 3 m : une montée ne compte qu'une fois franchis 3 m au-dessus du dernier creux retenu ;
  - le résultat vaut `nil` si moins de la moitié des points retenus ont une altitude fiable.

- [ ] **Step 1: Write `RunTraceFactory`** (code déterministe, sans fichier). Les traces partent de (48.8566, 2.3522) vers le nord, à 1 point par seconde ; on utilise 1° de latitude = 111 320 m. L'écart latéral vaut `3 * sin(t / 10)` m, un bruit lent comme celui de Core Location.
  - `static func clean(meters: Double, speed: Double, start: Date) -> [RunTrackPoint]` : précision 5 m, altitude montant de 0,02 m/s, `verticalAccuracy` 4.
  - `static func tunnel(...)` : la trace propre, avec 20 points consécutifs à 65 m de précision et un saut isolé de 300 m en 1 s au milieu.
  - `static func withPause(...)` : 2 000 m, puis 20 minutes où les points piétinent sur place, puis 1 000 m. Rend `([RunTrackPoint], RunPause)`.
- [ ] **Step 2: Write the failing tests** `RunTrackBuilderTests`, avec `TestClock.date("2026-11-24T07:00")` :
  - `cleanTraceIsWithinOnePercent` : `clean(meters: 5000, speed: 3)` → `abs(distance - 5000) / 5000 < 0.01`, et `splits.count == 5` avec chaque km entre 325 et 342 s.
  - `noisyTraceIsWithinThreePercent` : `tunnel(...)` sur 5 000 m → moins de 3 % d'écart, et le saut de 300 m n'est pas compté.
  - `pausedPointsAddNoDistance` : `withPause` → distance à 1 % de 3 000 m.
  - `splitsExcludePausedTime` : sur `withPause`, le 3ᵉ km (où se trouve la pause) dure moins de 400 s.
  - `currentKilometerPaceUsesLastThirtySecondsUnderAHundredMetres` : 1 050 m à 3 m/s → l'allure vaut 333 ± 3 s/km et vient de la fenêtre de 30 s.
  - `kilometerCrossingIsReturnedOnce` : `add` ne rend `1` qu'une seule fois sur une trace de 1 200 m.
  - `lastMovementIgnoresStandingStill` : 30 points immobiles après 500 m → `lastMovementAt` reste l'horodatage du dernier déplacement.
  - `elevationGainNeedsReliableAltitude` : la trace propre de 600 s gagne 12 m → résultat dans 12 ± 3 ; la même trace avec `verticalAccuracy` 30 → `nil`.
  - `replayMatchesLiveBuilding` : `replay(points:pauses:)` donne le même `distanceMeters` et les mêmes `splits` que l'ajout point par point.
- [ ] **Step 3: Run** `swift test --package-path Packages/PulseFeatures --filter RunTrackBuilderTests`. Expected: FAIL.
- [ ] **Step 4: Implement** `RunClock` et `RunTrackBuilder`.
- [ ] **Step 5: Run** le même filtre. Expected: PASS.
- [ ] **Step 6: Commit** `feat(run): filtered GPS distance, splits and paces`.

### Task 3: Simplification du tracé et événements d'annonce

**Files:**
- Create: `Packages/PulseFeatures/Sources/PulseServices/Run/RouteSimplifier.swift`
- Create: `Packages/PulseFeatures/Sources/PulseServices/Run/RunAnnouncementEvent.swift`
- Test: `Packages/PulseFeatures/Tests/PulseServicesTests/RouteSimplifierTests.swift`, `RunAnnouncementEventTests.swift`

**Interfaces:**
- Produces:

```swift
public enum RouteSimplifier {
    /// Douglas-Peucker en mètres (projection locale équirectangulaire). Garde toujours le premier et le dernier point.
    public static func simplify(_ points: [RunTrackPoint], toleranceMeters: Double = 5) -> [RunTrackPoint] }
public enum RunAnnouncementEvent: Sendable, Equatable {
    case kilometer(Int, movingSeconds: Int, splitSeconds: Int)
    case halfTarget
    case targetReached
    /// Les événements à dire quand la course passe de `previous` à `current` (progression d'objectif et km).
    public static func events(kilometer: Int?, splits: [RunSplit], movingSeconds: Double,
                              previousProgress: Double?, progress: Double?) -> [RunAnnouncementEvent] }
```

- [ ] **Step 1: Write the failing tests** :
  - `straightLineKeepsTwoPoints` : 600 points alignés → 2 points.
  - `oneHourStaysUnderFiveHundredPoints` : 3 600 points d'une boucle (cercle de 400 m de rayon, 4 tours) → `count < 500`.
  - `simplifiedRouteStaysWithinTolerance` : chaque point d'origine est à ≤ 5,5 m du tracé simplifié.
  - `kilometerEventCarriesSplit` : `kilometer: 3` avec les splits [330, 335, 332] → `[.kilometer(3, movingSeconds: 997, splitSeconds: 332)]`.
  - `halfAndTargetFireOnCrossing` :
    - de 0.49 à 0.51 → `[.halfTarget]` ;
    - de 0.99 à 1.0 → `[.targetReached]` ;
    - de 0.6 à 0.7 → `[]` ;
    - avec une progression `nil` → `[]`.
- [ ] **Step 2: Run** `swift test --package-path Packages/PulseFeatures --filter "RouteSimplifierTests|RunAnnouncementEventTests"`. Expected: FAIL.
- [ ] **Step 3: Implement**. Dans les événements, un km passé vient avant `halfTarget` et `targetReached`.
- [ ] **Step 4: Run** le même filtre. Expected: PASS.
- [ ] **Step 5: Commit** `feat(run): route simplification and announcement events`.

### Task 4: Stockage V5 (tracé synchronisé, brouillon et résumé cardio locaux)

**Files:**
- Create: `Packages/PulsePersistence/Sources/PulsePersistence/Models/StoredRunTrack.swift` (synchronisé : `id: UUID`, `points: Data?` et `splits: Data?` en `@Attribute(.externalStorage)` pour `points`, `elevationGainMeters: Double?`, `createdAt`, `updatedAt`, `deletedAt: Date?`. Tous les attributs sont optionnels ou ont une valeur par défaut, comme l'exige CloudKit, et il n'y a pas de `.unique`.)
- Create: `Packages/PulsePersistence/Sources/PulsePersistence/Models/StoredRunDraft.swift` (local : `@Attribute(.unique) id`, `payload: Data?`, `updatedAt`)
- Create: `Packages/PulsePersistence/Sources/PulsePersistence/Models/StoredRunHealthSummary.swift` (local : `@Attribute(.unique) sessionID`, `averageHeartRate: Double?`, `estimatedRPE: Double?`)
- Create: `Packages/PulsePersistence/Sources/PulsePersistence/Schema/PulseSchemaV5.swift`
- Modify: `Schema/PulseSchemaV4.swift` : listes figées `static let syncedModels` (les 15 actuels) et `static let localModels` (les 6 actuels) ; `models` = ces listes.
- Modify: `Schema/PulseSchemaV3.swift` : `PulseSchemaV4.syncedModels` à la place de `PersistenceStack.syncedModels`.
- Modify: `Schema/PersistenceStack.swift` : ajouter `StoredRunTrack` aux modèles synchronisés, `StoredRunDraft` et `StoredRunHealthSummary` aux locaux ; `Schema(versionedSchema: PulseSchemaV5.self)`.
- Modify: `Schema/PulseMigrationPlan.swift` : ajouter V5 et `.lightweight(fromVersion: PulseSchemaV4.self, toVersion: PulseSchemaV5.self)`.
- Create: `Packages/PulsePersistence/Sources/PulsePersistence/Repositories/SwiftDataRunRepositories.swift` (`SwiftDataRunTrackRepository`, `SwiftDataRunDraftStore` en `@ModelActor`)
- Modify: `Repositories/SwiftDataWorkoutRepository.swift` (routage du résumé cardio, voir Step 3)
- Modify: `Erase/StoreWiper.swift`, `PulseDomain/Repositories/StoreTable.swift` (`runTracks` exporté ; `runDrafts` et `runHealthSummaries` non exportés), `SwiftDataStoreInspector` (compteurs), `PulseDomain/Export/ExportDocument.swift` (`runTracks: [RunTrack]`), `Export/ExportSnapshotLoader.swift`, les colonnes CSV (`CSVColumns+Training.swift` : table `run_tracks` avec `session_id`, `split_seconds` en liste séparée par `;`, `elevation_gain_meters`, `point_count`)
- Modify: `Packages/PulseFeatures/Sources/PulseServices/Doubles/InMemoryRepositories.swift` (`InMemoryRunTrackRepository`, `InMemoryRunDraftStore`)
- Test: `PulsePersistenceTests/SchemaFingerprintTests.swift` (+ `Fixtures/schema-v5.txt`), `MigrationTests.swift`, `HealthBoundaryTests.swift`, `RunRepositoriesTests.swift`, `WorkoutRepositoryTests.swift`

**Interfaces:**
- Consumes: `RunTrack`, `RunDraft`, `RunHealthSummary` et les protocoles de dépôt (tâche 1).
- Produces: `SwiftDataRunTrackRepository: RunTrackRepository` et `SwiftDataRunDraftStore: RunDraftStore`. `SwiftDataWorkoutRepository` rend les courses Pulse avec `averageHeartRate` et `estimatedRPE` lus dans le résumé local.

- [ ] **Step 1: Write the failing tests** :
  - `v5SchemaMatchesItsFingerprint` et `v5OnlyAddsTheThreeRunModels` : on regénère la fixture avec `PULSE_WRITE_SCHEMA_FIXTURES=1`, puis on vérifie que `v3…` et `v4…` restent inchangés.
  - `v4StoreOpensAsV5KeepingData` : sur le modèle de `v3StoreOpensAsV4KeepingData`, avec un brouillon de liste V4 figée.
  - `runTrackRoundTrips` : sauvegarde puis lecture → égal, points et splits compris ; `delete(sessionID:)` le fait disparaître des lectures (suppression logique).
  - `draftStoreKeepsOneDraft` : deux `save` suivis de `load` rendent le dernier ; `clear` fait rendre `nil` à `load`.
  - `pulseRunHeartRateStaysLocal` : on sauvegarde une `WorkoutSession` `kind: .run`, `source: .pulse`, `averageHeartRate: 150`, `estimatedRPE: 8`. Le `StoredWorkoutSession` synchronisé a alors les deux champs à `nil`, le `StoredRunHealthSummary` local porte 150 et 8, et `session(id:)` comme `sessions(from:to:)` rendent 150 et 8.
  - Dans `HealthBoundaryTests`, `syncedStoreHoldsNoHealthValue` vérifie en plus qu'aucun `StoredWorkoutSession` avec `source == "pulse"` et `kind == "run"` n'a de FC ni de RPE estimé.
  - `wipeAllRemovesRunModels` : les trois nouveaux modèles sont vides après `wipeAll()`.
- [ ] **Step 2: Run** `swift test --package-path Packages/PulsePersistence`. Expected: FAIL.
- [ ] **Step 3: Implement**. Dans `save`, une séance `.pulse` de `kind == .run` écrit ses deux champs cardio dans `StoredRunHealthSummary` (upsert sur `sessionID`) et met `nil` dans le synchronisé. Les lectures de séances `.pulse` `.run` réinjectent le résumé. `delete` supprime aussi le résumé et le tracé. Le reste de l'export suit le modèle des tables existantes.
- [ ] **Step 4: Run** `swift test --package-path Packages/PulsePersistence`, puis `swift test --package-path Packages/PulseDomain`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(persistence): schema V5 with synced run track and local run draft`.

### Task 5: Doublons avec la montre et courses écrites par Pulse

**Files:**
- Create: `Packages/PulseFeatures/Sources/PulseServices/Run/RunDuplicates.swift`
- Create: `Packages/PulseFeatures/Sources/PulseServices/Run/DeduplicatingWorkoutRepository.swift`
- Modify: `Packages/PulseFeatures/Sources/PulseServices/Health/WorkoutHistory.swift` (paramètre `ownBundleIdentifier: String?`)
- Test: `Packages/PulseFeatures/Tests/PulseServicesTests/RunDuplicatesTests.swift`, `WorkoutHistoryTests.swift`

**Interfaces:**
- Produces:

```swift
public enum RunDuplicates {
    public static let minimumOverlap = 0.5
    /// Retire les courses `appleHealth` qui chevauchent une course `pulse` d'au moins 50 % de la plus courte, et remplit en
    /// mémoire la FC et le RPE estimé manquants de la course Pulse avec ceux du premier doublon.
    public static func resolve(_ sessions: [WorkoutSession]) -> [WorkoutSession] }
/// Le dépôt que voient l'Accueil, le planning, les stats et l'historique. `WorkoutHistory` garde le dépôt brut.
public struct DeduplicatingWorkoutRepository: WorkoutRepository {
    public init(base: any WorkoutRepository)   // sessions(from:to:) lit un jour de plus de chaque côté, résout, puis recoupe
}
// WorkoutHistory.init(..., calendar: Calendar, ownBundleIdentifier: String? = nil)
```

- [ ] **Step 1: Write the failing tests** `RunDuplicatesTests` :
  - `fullOverlapHidesTheWatchRun` : une course Pulse de 07:00 à 07:30 et une course montre de 07:01 à 07:31 → seule la course Pulse reste.
  - `fortyPercentOverlapKeepsBoth` : la course montre chevauche 12 min sur 30 → les deux restent.
  - `splitWatchRunIsHiddenTwice` : la montre a coupé la course en deux (07:00 à 07:14, puis 07:16 à 07:30) → aucune des deux ne reste.
  - `duplicateEstimatedRPEFillsThePulseRun` : la course Pulse n'a ni RPE noté ni estimé, le doublon a un RPE estimé de 8 → la course rendue porte `estimatedRPE == 8`, et `TrainingLoad.loadSession` donne `rpe == 8`.
  - `pulseRunOwnHeartRateWins` : si la course Pulse a déjà `averageHeartRate`, il n'est pas remplacé.
  - `deletedPulseRunBringsTheWatchRunBack` : sans course Pulse, la course montre reste.
  - `ridesAreNeverMerged` : un vélo `appleHealth` qui chevauche une course Pulse reste.
  - `decoratorSaveNeverCopiesTheDuplicateIntoStorage` : lire par le décorateur puis sauver la course rendue garde `averageHeartRate == nil` dans le dépôt de base, quand cette FC venait du doublon. Le décorateur doit donc retirer les valeurs empruntées avant d'appeler `base.save`, et il retient lesquelles il a empruntées.
- [ ] **Step 2: Write the failing test** `WorkoutHistoryTests.ownWorkoutsAreNotImported` : un échantillon dont `sourceBundleID == "fr.seonay.pulse"` avec `ownBundleIdentifier: "fr.seonay.pulse"` → aucune séance `appleHealth` créée, et une séance déjà importée de cette source est supprimée.
- [ ] **Step 3: Run** `swift test --package-path Packages/PulseFeatures --filter "RunDuplicatesTests|WorkoutHistoryTests"`. Expected: FAIL.
- [ ] **Step 4: Implement**. Pour le chevauchement : `min(fin)` moins `max(début)`, rapporté à la durée la plus courte. La fin d'une course vaut `endedAt`, ou à défaut `startedAt + durationMinutes`.
- [ ] **Step 5: Run** le même filtre, puis `swift test --package-path Packages/PulseFeatures`. Expected: PASS.
- [ ] **Step 6: Commit** `feat(run): hide watch duplicates of Pulse runs and skip own workouts on import`.

### Task 6: `RunSessionService` (orchestration, brouillon, reprise, oubli)

**Files:**
- Create: `Packages/PulseFeatures/Sources/PulseServices/Run/RunSessionService.swift`
- Create: `Packages/PulseFeatures/Sources/PulseServices/Run/RunSnapshot.swift`
- Create: `Packages/PulseFeatures/Sources/PulseServices/Run/RunLaunch+Planning.swift`
- Create: `Packages/PulseFeatures/Sources/PulseServices/Run/RunPreferencesStore.swift` (protocole, `UserDefaultsRunPreferencesStore(suiteName:)`, `InMemoryRunPreferencesStore`)
- Test: `Packages/PulseFeatures/Tests/PulseServicesTests/RunSessionServiceTests.swift`, `RunLaunchPlanningTests.swift`

**Interfaces:**
- Consumes: tâches 1 à 5, `WorkoutRepository`, `ProfileRepository`, `EstimatedRPE`, `AdjustedSession` (`PulseRecoveryEngine`).
- Produces:

```swift
public protocol RunPreferencesStore: Sendable { var announcesKilometres: Bool { get }; func setAnnouncesKilometres(_ on: Bool) }
// Défaut : true. Clé « pulse.run.announcesKilometres ».

public enum RunGPSQuality: Sendable, Equatable { case searching, weak, ready }
public struct RunSnapshot: Sendable, Equatable {
    public var sessionID: UUID; public var launch: RunLaunch; public var startedAt: Date; public var pauses: [RunPause]
    public var isPaused: Bool
    public var movingSeconds: Double; public var distanceMeters: Double?   // nil si localisation refusée
    public var currentKilometerPace: Int?; public var averagePace: Int?; public var heartRate: Double?
    public var targetProgress: Double?; public var gps: RunGPSQuality; public var locationDenied: Bool }
public struct RunRecoveryOffer: Sendable, Equatable { public var sessionID: UUID; public var distanceMeters: Double?
    public var lastPointAt: Date; public var isStillRecording: Bool }
public struct RunRecapData: Sendable, Equatable { public var session: WorkoutSession; public var track: RunTrack? }

extension RunLaunch {
    /// `.swapIntervalsForEasy` → `runType: .easy`, `adjustmentNote` « au lieu du fractionné » ;
    /// `.suggestRest` → objectif gardé, `adjustmentNote` « repos conseillé aujourd'hui ».
    public static func planned(_ day: RoutineDay, programID: UUID?, adjusted: AdjustedSession?) -> RunLaunch
    public static func free() -> RunLaunch   // titre « Course libre »
}

public actor RunSessionService {
    public static let forgottenAfter: TimeInterval = 30 * 60
    public static let draftInterval: TimeInterval = 10
    public static let activityInterval: TimeInterval = 15
    public init(recorder: any RunWorkoutRecording, location: any RunLocationTracking, announcer: any RunAnnouncing,
                activity: any RunActivityControlling, reminders: any RunReminderScheduling, drafts: any RunDraftStore,
                workouts: any WorkoutRepository, tracks: any RunTrackRepository, profiles: any ProfileRepository,
                preferences: any RunPreferencesStore, spokenText: @escaping @Sendable (RunAnnouncementEvent) -> String,
                now: @escaping @Sendable () -> Date, calendar: Calendar)
    public func snapshots() -> AsyncStream<RunSnapshot>        // un abonné, l'écran de course
    /// Écran de départ : démarre la localisation et rend la qualité du signal (`ready` à ≤ 20 m) ; arrêtée par `start` ou
    /// `cancelPreview()`. Avec la localisation refusée, le flux se termine aussitôt.
    public func gpsPreview() async -> AsyncStream<RunGPSQuality>
    public func cancelPreview() async
    public func current() -> RunSnapshot?
    public func start(_ launch: RunLaunch) async throws -> RunSnapshot
    public func pause() async; public func resume() async
    /// Termine, écrit dans Santé (si autorisé), sauve séance + tracé, vide le brouillon. Rend la séance enregistrée.
    public func finish() async throws -> RunRecapData
    /// Termine à l'heure du dernier déplacement (oubli).
    public func finish(at end: Date) async throws -> RunRecapData
    public func discard() async
    /// Au lancement et au retour au premier plan.
    public func recoveryOffer() async -> RunRecoveryOffer?
    public func reattach() async -> RunSnapshot?               // séance HealthKit encore vivante
    public func saveInterrupted() async throws -> RunRecapData
    public func forgottenEnd() async -> Date?                  // dernier déplacement si ≥ 30 min sans bouger hors pause
    public func completeRecap(sessionID: UUID, rpe: Double?, note: String?) async throws
    public func deleteRun(sessionID: UUID) async throws        // séance, tracé, entraînement Santé
}
```

Comportement :
- **`start`** :
  - Il échoue (`RunSessionError.alreadyRunning`) si un brouillon existe.
  - Il demande, si besoin, la localisation puis l'écriture Santé. Un refus de Santé ne bloque pas ; un refus de localisation donne `locationDenied`.
  - Il démarre la séance HealthKit, puis la localisation, puis la Live Activity, et écrit le brouillon.
- **À chaque point** :
  - `RunTrackBuilder.add`, puis les événements d'annonce, dits seulement si `announcesKilometres` est vrai ;
  - le brouillon si 10 s ont passé depuis la dernière écriture ;
  - la Live Activity si 15 s ont passé ou si un km vient d'être passé ;
  - si `lastMovementAt` avance de plus de 60 s, `scheduleForgotten(at: lastMovementAt + 30 min)`.
- **`pause`** et **`resume`** : la séance HealthKit, `breakSegment()`, le brouillon et la Live Activity tout de suite. `pause` appelle aussi `cancelForgotten()` ; `resume` replanifie à partir de `now`.
- **`finish`** :
  - séance `kind: .run`, `source: .pulse`, `status: .completed`, `durationMinutes` en mouvement et `distanceMeters` ;
  - `averageHeartRate` (moyenne des FC reçues) et `estimatedRPE` (`EstimatedRPE.rpe` avec la FC max du profil), que le dépôt garde en local ;
  - `healthKitUUID` rendu par `recorder.finish`, ou `nil` en cas d'échec ou de refus ;
  - `RunTrack` avec `RouteSimplifier.simplify(builder.accepted)`, les `splits` et le dénivelé ;
  - `activity.end()`, `cancelForgotten()`, `drafts.clear()`, `location.stop()`.
- **`saveInterrupted`** : il rejoue le brouillon avec `RunTrackBuilder.replay`, termine au dernier point et écrit dans Santé avec `recorder.save`.

- [ ] **Step 1: Write the failing tests** `RunLaunchPlanningTests` :
  - `swappedIntervalsBecomeEasy` : le type passe à `.easy`, la note est présente et l'objectif est gardé.
  - `suggestRestKeepsTheTarget`.
  - `freeRunHasNoTarget`.
- [ ] **Step 2: Write the failing tests** `RunSessionServiceTests`, avec les doublures de la tâche 1, `InMemoryWorkoutRepository`, `InMemoryRunTrackRepository`, `InMemoryRunDraftStore` et une horloge mutable :
  - `startWritesADraftAndStartsEverything` : le brouillon existe, la séance HealthKit, la localisation et la Live Activity sont démarrées.
  - `secondStartIsRefused`.
  - `previewReportsReadyUnderTwentyMetres` : des points à 40 m, puis à 15 m → `[.weak, .ready]`, après `.searching` au départ.
  - `kilometreIsAnnouncedOnce` : 1 200 m poussés → `StubRunAnnouncer.texts == [spokenText(.kilometer(1, …))]`.
  - `announcementsCanBeTurnedOff` : préférence à faux → aucun texte.
  - `draftIsWrittenEveryTenSeconds` : 25 s de points → 3 écritures (au départ, à 10 s et à 20 s).
  - `activityIsNotUpdatedEverySecond` : 60 s de points sans passage de km → au plus 4 mises à jour.
  - `pausedRunNeverSchedulesForgottenReminder` : `pause()`, puis 40 min → dernier appel `cancelForgotten`, `forgottenEnd() == nil`.
  - `standingStillForThirtyMinutesOffersTheLastMovement` : 1 km, puis 31 min immobile hors pause → `forgottenEnd()` rend l'heure du dernier déplacement ; `finish(at:)` donne une durée qui s'arrête là.
  - `finishSavesSessionTrackAndHealthWorkout` : la séance a `source == .pulse`, `kind == .run`, `distanceMeters` à 1 % près et `healthKitUUID` égal à l'UUID de la doublure. Le tracé est sauvé avec `points.count < accepted.count`. Le brouillon est vide et la Live Activity terminée.
  - `healthWriteFailureStillSavesTheRun` : la doublure lève une erreur dans `finish` → la séance est sauvée avec `healthKitUUID == nil` et `finish` ne lève pas.
  - `locationDeniedRecordsTimeOnly` : localisation `.denied` → snapshot `locationDenied == true`, puis `distanceMeters == nil` sur la séance, `durationMinutes > 0` et aucun tracé.
  - `interruptedDraftIsOfferedWithReplayedDistance` : un brouillon de 2 000 m dans le store et un `recoverActiveSession() == false` → `recoveryOffer()` rend la distance à 1 % près, `isStillRecording == false` et `lastPointAt` égal au dernier point.
  - `savingAnInterruptedRunWritesItWithoutLiveSession` : `saveInterrupted()` appelle `recorder.save` (pas `finish`), sauve la séance et vide le brouillon.
  - `recoveredLiveSessionReattaches` : `recoverActiveSession() == true` → `reattach()` rend un snapshot, avec une distance rejouée depuis le brouillon.
  - `completeRecapStoresRPEAndNote` : `overallRPE` et `note` sont écrits ; `rpe: nil` laisse `overallRPE == nil`.
  - `deleteRunRemovesSessionTrackAndHealthWorkout`.
- [ ] **Step 3: Run** `swift test --package-path Packages/PulseFeatures --filter "RunSessionServiceTests|RunLaunchPlanningTests"`. Expected: FAIL.
- [ ] **Step 4: Implement**. Le service consomme le flux de points dans une `Task` qu'il garde, et l'annule dans `finish`, `discard` et `saveInterrupted`. Les snapshots partent par un `AsyncStream.Continuation`. Le service ne publie pas chaque seconde : l'écran calcule lui-même le temps en mouvement, chaque seconde, depuis `startedAt` et `pauses`.
- [ ] **Step 5: Run** le même filtre, puis `swift test --package-path Packages/PulseFeatures` et `make lint`. Expected: PASS, lint 0.
- [ ] **Step 6: Commit** `feat(run): run session service with draft, recovery and forgotten-run reminder`.

---

## Lot 2 — Adaptateurs, écrans, app

### Task 7: Adaptateurs système (HealthKit, Core Location, voix, rappel)

**Files:**
- Create: `Packages/PulseHealth/Sources/PulseHealth/HealthKitRunRecorder.swift` (`public final class HealthKitRunRecorder: RunWorkoutRecording, @unchecked Sendable`)
- Modify: `Packages/PulseHealth/Sources/PulseHealth/HealthKitWorkoutWriter.swift` (`shared` gagne `HKSeriesType.workoutRoute()` et `HKQuantityType(.distanceWalkingRunning)`)
- Create: `Pulse/Run/CoreLocationRunTracker.swift` (`RunLocationTracking`)
- Create: `Pulse/Run/SpeechRunAnnouncer.swift` (`RunAnnouncing`)
- Modify: `Pulse/Notifications/UserNotificationScheduler.swift` (`RunReminderScheduling`, identifiant `fr.seonay.pulse.run-forgotten`)

Contraintes :
- **`HealthKitRunRecorder.start`** :
  - `HKWorkoutConfiguration` avec `activityType = .running` et `locationType = .outdoor`, puis `HKWorkoutSession(healthStore:configuration:)` et `associatedWorkoutBuilder()` ;
  - `HKLiveWorkoutDataSource` avec `disableCollection(for: HKQuantityType(.distanceWalkingRunning))`, pour que seule la distance GPS de Pulse arrive dans Santé ;
  - `prepare()`, `startActivity(with:)` puis `beginCollection(at:)` ;
  - la FC se lit dans `workoutBuilder(_:didCollectDataOf:)` avec `statistics(for: HKQuantityType(.heartRate))?.mostRecentQuantity()`.
- **`finish`** :
  - un seul échantillon `distanceWalkingRunning` du début à la fin, égal à `entry.distanceMeters`, ajouté au builder ;
  - `HKMetadataKeyExternalUUID = sessionID` ;
  - `end()`, `endCollection(at:)` puis `finishWorkout()` ;
  - le tracé via `HKWorkoutRouteBuilder(healthStore:device: .local())`, `insertRouteData` (points convertis en `CLLocation`) puis `finishRoute(with:metadata:)`.
- **`save`** (course interrompue) : la même chose avec `HKWorkoutBuilder(.running)`, sans séance.
- **`recoverActiveSession`** : il rend `true` si `AppDelegate` lui a transmis une séance récupérée (tâche 11). Il rattache alors le builder et recrée la source de données.
- **`CoreLocationRunTracker`** :
  - `CLLocationUpdate.liveUpdates(.fitness)` et `CLBackgroundActivitySession` gardée pendant la course ;
  - autorisation « lorsque l'app est active » ;
  - chaque `CLLocation` devient un `RunTrackPoint` ;
  - `stop()` annule la tâche et invalide la session d'arrière-plan.
- **`SpeechRunAnnouncer`** :
  - `AVSpeechSynthesizer` avec une voix `fr-FR` ;
  - `AVAudioSession` en `.playback`, mode `.voicePrompt`, options `[.duckOthers, .interruptSpokenAudioAndMixWithOthers]`, activée avant l'annonce ;
  - désactivée avec `.notifyOthersOnDeactivation` dans `speechSynthesizer(_:didFinish:)`.
- **Rappel d'oubli** : notification locale « Course toujours en cours ? », corps « Aucun déplacement depuis 30 minutes. Ouvre Pulse pour la terminer. » ; `scheduleForgotten` remplace la précédente.

- [ ] **Step 1: Implement** les quatre adaptateurs.
- [ ] **Step 2: Run** `make build-app`. Expected: code de sortie 0.
- [ ] **Step 3: Run** `make lint`. Expected: 0 violation.
- [ ] **Step 4: Commit** `feat(run): HealthKit run recorder, location tracker, spoken announcements and reminder`.

### Task 8: Live Activity de course

**Files:**
- Create: `Packages/PulseLiveActivity/Sources/PulseLiveActivity/PulseRunAttributes.swift` (`ContentState` reprend les champs de `RunActivityState` sauf `sessionID` ; l'attribut porte `sessionID`)
- Create: `Packages/PulseLiveActivity/Sources/PulseLiveActivity/RunIntents.swift` (`RunControl { pause, resume }`, `RunIntentBridge` sur le modèle de `SessionIntentBridge`, `RunPauseIntent` et `RunResumeIntent` en `LiveActivityIntent`, ajoutés au paquet d'intents existant)
- Create: `Pulse/LiveActivity/RunActivityController.swift` (`RunActivityControlling`, sur le modèle de `SessionActivityController`)
- Modify: `Pulse/LiveActivity/SessionIntentWiring.swift` (installe aussi `RunIntentBridge.handler`, qui appelle `RunSessionService.pause()` ou `resume()`)
- Create: `PulseWidgets/RunLiveActivity.swift`, `PulseWidgets/RunLiveActivityViews.swift`; Modify: `PulseWidgets/PulseWidgetsBundle.swift`
- Create: `Packages/PulseFeatures/Sources/WidgetFeature/RunActivityText.swift`
- Test: `Packages/PulseFeatures/Tests/WidgetFeatureTests/RunActivityTextTests.swift`

**Interfaces:**
- Produces: `RunActivityText.distance(_ meters: Double?) -> String` (« 4,38 km », « — » si nil), `pace(_ secondsPerKm: Int?) -> String` (« 5'32" /km »), `spokenSummary(_ state: RunActivityState, elapsed: Int) -> String`.

Contraintes :
- **Temps écoulé** : quand `timerStart` est non nil, `Text(timerInterval: timerStart...Date.distantFuture, countsDown: false)` ; en pause, le temps figé `frozenElapsedSeconds` formaté, avec le libellé « En pause ».
- **Contenu** : jamais de FC, et une seule couleur signal. Le bouton Pause/Reprendre est un `Button(intent:)`.
- **Accessibilité** : libellés et Dynamic Type plafonné comme dans `SessionLiveActivityViews`.

- [ ] **Step 1: Write the failing tests** `RunActivityTextTests` :
  - `distanceFormatsKilometres` : 4 380 → « 4,38 km », nil → « — ».
  - `paceFormatsMinutesSeconds` : 332 → « 5'32" /km », nil → « — ».
  - `spokenSummaryReadsUnitsInFull` : le résumé contient « kilomètres » et « par kilomètre ».
- [ ] **Step 2: Run** `swift test --package-path Packages/PulseFeatures --filter RunActivityTextTests`. Expected: FAIL.
- [ ] **Step 3: Implement** le texte, les attributs, les intents, le contrôleur et les vues.
- [ ] **Step 4: Run** le même filtre, puis `make build-app` et `make lint`. Expected: PASS, code 0, lint 0.
- [ ] **Step 5: Commit** `feat(run): run Live Activity with pause and resume`.

### Task 9: `RunFeature` (départ, course, récap, tracé)

**Files:**
- Modify: `Packages/PulseFeatures/Package.swift` (cible `RunFeature`, dépend de `["PulseServices", designSystem, domain]` ; produit ; cible de test `RunFeatureTests`)
- Create: `Packages/PulseFeatures/Sources/RunFeature/RunEnvironment.swift`, `RunCoordinator.swift`, `RunModel.swift`, `RunRecapModel.swift`, `RunText.swift` (textes affichés et parlés, `spokenText(for: RunAnnouncementEvent) -> String`), `RunIdentifiers.swift`
- Create: `Packages/PulseFeatures/Sources/RunFeature/Views/RunStartView.swift`, `RunView.swift`, `RunRecapView.swift`, `RunRouteMap.swift`, `RunSplitsList.swift`, `RunEffortPicker.swift`, `ResumeRunBar.swift`
- Create: `Packages/PulseFeatures/Sources/RunFeature/Resources/Localizable.xcstrings`
- Test: `Packages/PulseFeatures/Tests/RunFeatureTests/RunTextTests.swift`, `RunModelTests.swift`, `RunCoordinatorTests.swift`

**Interfaces:**
- Consumes: `RunSessionService`, `RunSnapshot`, `RunRecoveryOffer`, `RunRecapData`, `RunLaunch`, `RunPreferencesStore` (tâche 6), `RunTrackRepository` (tâche 1).
- Produces:

```swift
public struct RunEnvironment { public init(service: RunSessionService, tracks: any RunTrackRepository,
    preferences: any RunPreferencesStore, isStrengthSessionActive: @escaping @MainActor () -> Bool,
    now: @escaping @Sendable () -> Date, calendar: Calendar) }
@MainActor @Observable public final class RunCoordinator {
    public init(environment: RunEnvironment)
    public private(set) var current: RunSnapshot?; public var isPresented: Bool
    public private(set) var recovery: RunRecoveryOffer?; public private(set) var forgottenEnd: Date?
    public var errorMessage: String?
    public func prepare(_ launch: RunLaunch)     // ouvre l'écran de départ ; refuse si une séance de musculation est en cours
    public func refresh() async                  // lancement et retour au premier plan : reprise, offre d'interruption, oubli
    public func model() -> RunModel
}
public enum RunText { public static func spokenText(for event: RunAnnouncementEvent) -> String /* … */ }
public struct RunRouteMap: View { public init(points: [RunTrackPoint]) }
public struct RunSplitsList: View { public init(splits: [RunSplit]) }
```

Contraintes :
- **Écrans** : ceux de la spec §4.2, §4.3 (croquis compris) et §4.5.
  - Le temps se rafraîchit avec `TimelineView(.periodic(from:by: 1))` depuis `RunClock.movingSeconds`.
  - Les gros chiffres utilisent `PulseFont` et sont `monospacedDigit`.
- **Terminer** : une `confirmationDialog` « Terminer la course ? » avec « Terminer » et « Annuler ». Elle reste accessible au clavier et à VoiceOver.
- **`RunEffortPicker`** : RPE de 1 à 10, plus « Pas noté ». **Aucune valeur présélectionnée.** La consigne « Note ton effort : sans note, Pulse l'estime » est affichée au-dessus.
- **Texte parlé** :
  - `RunText.spokenText(.kilometer(3, movingSeconds: 1000, splitSeconds: 332))` = « \(PulseSpoken.count(3, singular: "kilomètre", plural: "kilomètres")). \(PulseSpoken.duration(seconds: 1000)). Allure \(PulseSpoken.pace(secondsPerKilometer: 332)). » ;
  - `.halfTarget` = « Mi-objectif. » ;
  - `.targetReached` = « Objectif atteint. ».
- **Récap** :
  - `RunRouteMap` est une polyligne MapKit tracée à l'encre, sans contrôles, avec `accessibilityLabel` « Tracé de la course, 4,4 kilomètres ». Elle ne s'affiche pas quand le tracé est vide.
  - `RunSplitsList` dit chaque ligne en entier (« Kilomètre 3, 5 minutes 32 secondes »).
- **Localisation refusée** : la ligne « Localisation refusée : seul le temps est enregistré. » apparaît au départ et pendant la course.
- **Coordinateur** :
  - `refresh()` : si `recoveryOffer()` signale une séance vivante, il appelle `reattach()` et présente la course ; sinon il expose `recovery`.
  - Il expose aussi `forgottenEnd` quand la course est ouverte et que `forgottenEnd()` n'est pas nil.

- [ ] **Step 1: Write the failing tests** :
  - `RunTextTests.kilometerSentenceUsesSpokenUnits` : la phrase exacte ci-dessus.
  - `RunTextTests.singleKilometreIsSingular` : « 1 kilomètre ».
  - `RunModelTests.locationDeniedShowsTheNotice`.
  - `RunModelTests.effortStartsUnset` : `recap.rpe == nil`.
  - `RunModelTests.savingRecapPassesNilWhenUnset`.
  - `RunCoordinatorTests.refusesWhileStrengthSessionIsActive` : `prepare` laisse `isPresented == false` et met `errorMessage` à « Une séance de musculation est en cours. ».
  - `RunCoordinatorTests.refreshPresentsAReattachedRun`.
  - `RunCoordinatorTests.refreshOffersAnInterruptedRun`.
  - `RunCoordinatorTests.refreshExposesForgottenEnd`.
- [ ] **Step 2: Run** `swift test --package-path Packages/PulseFeatures --filter "RunTextTests|RunModelTests|RunCoordinatorTests"`. Expected: FAIL.
- [ ] **Step 3: Implement** les modèles, les textes et les vues, avec des aperçus pour la course en cours, la pause, la localisation refusée, le récap et le texte en grande taille (ax3).
- [ ] **Step 4: Run** le même filtre, puis `swift test --package-path Packages/PulseFeatures` et `make lint`. Expected: PASS, lint 0.
- [ ] **Step 5: Commit** `feat(run): run start, live and recap screens`.

### Task 10: Points d'entrée et réglage

**Files:**
- Modify: `Packages/PulseFeatures/Sources/TodayFeature/Session/SessionCardState.swift` (`RunCard` gagne `launch: RunLaunch`, construit avec `RunLaunch.planned(day, programID:, adjusted: session.adjusted)`), `TodayFeature/Views/SessionCard.swift` (bouton « Démarrer la course »), `TodayFeature/Views/TodayView.swift` (paramètre `onStartRun: @escaping (RunLaunch) -> Void`)
- Modify: `Packages/PulseFeatures/Sources/TrainFeature/Views/TrainTiles.swift` (`RunTile` : bouton « Courir » qui lance la prochaine course si elle tombe aujourd'hui, sinon une course libre), `TrainFeature/Views/TrainView.swift` (entrée « Courir » dans « Aller plus loin », identifiant `TrainIdentifiers.freeRun` ; paramètre `onStartRun`), `TrainModel.swift` (`func runLaunch() -> RunLaunch`)
- Modify: `Packages/PulseFeatures/Sources/PlanningFeature/Views/ActivityDetailView.swift` (pour une course `.pulse`, section « Tracé » avec `RunRouteMap` et `RunSplitsList`, lus par `RunTrackRepository`), `PlanningEnvironment.swift` (`tracks: (any RunTrackRepository)?`), `Package.swift` (`PlanningFeature` dépend de `RunFeature`)
- Modify: `Packages/PulseFeatures/Sources/ProfileFeature/Views/SettingsTrainingSections.swift` (interrupteur « Annonces vocales pendant la course »), `ProfileEnvironment.swift` (`runPreferences: any RunPreferencesStore`)
- Test: `TodayFeatureTests`, `TrainFeatureTests`, `PlanningFeatureTests`, `ProfileFeatureTests` (fichiers existants des modèles touchés)

- [ ] **Step 1: Write the failing tests** :
  - `runCardCarriesAdjustedLaunch` : un jour de fractionné avec `.swapIntervalsForEasy` donne `card.launch.runType == .easy`.
  - `trainRunLaunchIsTodayPlannedRunOrFree`.
  - `pulseRunDetailLoadsItsTrack`.
  - `announcementsToggleWritesThePreference`.
- [ ] **Step 2: Run** `swift test --package-path Packages/PulseFeatures --filter "runCardCarriesAdjustedLaunch|trainRunLaunchIsTodayPlannedRunOrFree|pulseRunDetailLoadsItsTrack|announcementsToggleWritesThePreference"`. Expected: FAIL.
- [ ] **Step 3: Implement**. Mettre à jour le commentaire « Pas de bouton Démarrer » de `RunCard` et celui de `RunTile`.
- [ ] **Step 4: Run** `swift test --package-path Packages/PulseFeatures` et `make lint`. Expected: PASS, lint 0.
- [ ] **Step 5: Commit** `feat(run): start a run from Today and Train, route in activity detail, voice setting`.

### Task 11: Branchement dans l'app, Info.plist, confidentialité

**Files:**
- Modify: `Pulse/AppDependencies.swift`
  - Construire `HealthKitRunRecorder`, `CoreLocationRunTracker`, `SpeechRunAnnouncer`, `RunActivityController`, `UserDefaultsRunPreferencesStore(suiteName: nil)`, `SwiftDataRunTrackRepository`, `SwiftDataRunDraftStore` et `RunSessionService`.
  - Envelopper le dépôt de séances dans `DeduplicatingWorkoutRepository` pour tous les services **sauf** `WorkoutHistory`.
  - Passer `Bundle.main.bundleIdentifier` en `ownBundleIdentifier`.
  - Prévoir les doublures dans `testing(...)`.
- Modify: `Pulse/AppDependencies+Environments.swift` (`runEnvironment()`, et `tracks` et `runPreferences` dans les environnements Planning et Profil)
- Modify: `Pulse/AppDelegate.swift` : `application(_:configurationForConnecting:options:)`. Quand `options.shouldHandleActiveWorkoutRecovery` est vrai, appeler `HKHealthStore().recoverActiveWorkoutSession`, puis remettre la séance à `HealthKitRunRecorder`. Rendre la configuration de scène par défaut.
- Modify: `Pulse/Root/AppRootModel.swift` (créer `RunCoordinator` ; `refresh()` au chargement et dans `becameActive()`), `Pulse/Root/MainTabView.swift` (`fullScreenCover` de course, `ResumeRunBar`, alertes de reprise et d'oubli, `onStartRun` passé à Today et Train)
- Modify: `Pulse/Info.plist` :
  - `NSLocationWhenInUseUsageDescription` = « Pulse utilise ta position pendant une course que tu lances, pour mesurer la distance et tracer ton parcours. Elle reste sur ton iPhone, dans ton iCloud et dans Apple Santé. » ;
  - `UIBackgroundModes` += `location`, `workout-processing`, `audio` ;
  - `NSHealthUpdateUsageDescription` mentionne aussi les courses et leurs tracés.
- Modify: `Pulse.xcodeproj/project.pbxproj` : le produit `RunFeature` lié à l'app, avec les quatre entrées, sur le modèle de `StatsFeature`.
- Modify: `Packages/PulsePersistence/Sources/PulsePersistence/Erase/SwiftDataEraser.swift` ou son appelant dans l'app, pour que l'effacement total vide aussi la clé `pulse.run.announcesKilometres`, comme les autres clés `UserDefaults`.
- Modify: `docs/confidentialite/index.html`, `docs/app-store/fiche.md` (notes de revue : la localisation en arrière-plan sert seulement pendant une course lancée par l'utilisateur ; l'audio en arrière-plan sert aux annonces de km), `Pulse/PrivacyInfo.xcprivacy` (relire : aucune nouvelle API à raison attendue)

- [ ] **Step 1: Implement** le branchement.
- [ ] **Step 2: Run** `grep -c "DeduplicatingWorkoutRepository" Pulse/AppDependencies.swift`. Expected: ≥ 1. Relire aussi que `WorkoutHistory` reçoit bien le dépôt brut.
- [ ] **Step 3: Run** `/usr/libexec/PlistBuddy -c "Print :UIBackgroundModes" Pulse/Info.plist`. Expected: `remote-notification`, `location`, `workout-processing`, `audio`.
- [ ] **Step 4: Run** `make build-app`, puis `make build-release`. Expected: les deux sortent avec le code 0.
- [ ] **Step 5: Run** les six `swift test --package-path Packages/<Nom>` (`PulseDomain`, `PulseRecoveryEngine`, `PulseContent`, `PulsePersistence`, `PulseDesignSystem`, `PulseFeatures`), puis `make lint`. Expected: tout vert, lint 0.
- [ ] **Step 6: Commit** `feat(run): wire GPS running into the app, location and background modes, privacy texts`.

---

## Après le plan (hors tâches)

- Revue finale de toute la branche.
- Ce qui reste à Mathéo (spec §10) : trois vraies courses, un test de reprise après fermeture forcée, un test du doublon avec la Fitbit, et le déploiement du schéma CloudKit V5 en production avant TestFlight.
