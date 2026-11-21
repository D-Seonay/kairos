# Pulse M7b — Profil, paramètres, données : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** remplacer l'onglet Profil de debug par une vraie page (identité, tuiles, poids, mur des records, badges), un écran Poids lu d'Apple Santé avec saisie manuelle, les paramètres complets et un écran « Mes données », le debug « Données » réservé au DEBUG.

**Architecture:** lot 1 dans `PulseServices` : lecture ancrée du poids et de la masse grasse (`BodyHistory`, calquée sur `WorkoutHistory`), tendance pure `WeightTrend`, `BodyService`, badges purs, `ProfileService` (résumé de la page) et `SettingsService` (seul point d'écriture des réglages, replanifications reçues en fermetures). Lot 2 : nouvelle cible `ProfileFeature` (page, Poids, Paramètres, Mes données). Lot 3 : branchement dans l'app ; les écrans propres à l'app (diagnostic Apple Santé, debug, confirmation de suppression) sont passés à `ProfileFeature` en vues.

**Tech Stack:** Swift 6.2, SwiftUI, Swift Charts, Swift Testing, HealthKit (`PulseHealth`), packages SPM `PulseDomain`, `PulsePersistence`, `PulseFeatures`, `PulseDesignSystem`.

**Spec:** `docs/superpowers/specs/2026-11-20-pulse-m7-stats-profil-design.md` (§1 à §4, §13 à §19). À lire avant chaque tâche. Carte du code utile : les chemins et signatures cités ci-dessous viennent d'une lecture du dépôt à 7550adb.

## Global Constraints

- Branche `m7-profil`, créée depuis `m7-stats` (M7a n'est pas encore fusionné). Avant tout commit : `git branch --show-current` doit dire `m7-profil` (checkout partagé avec Mathéo) ; `git status --short` et ajout des nouveaux fichiers **par nom** ; jamais `.agents/`, `.gemini/`, `.superpowers/`.
- Ne jamais lancer le simulateur : pas de `xcodebuild test`, `make test`, `make test-app`, `simctl`. Vérifier avec `swift test --package-path Packages/<Nom>`, `make lint`, `make build-app`, `make build-release` (Xcode 27 : `-quiet` n'affiche pas de bannière, juger au code de sortie 0). `PulseHealth` ne se compile pas avec `swift test` sur macOS : il est vérifié par `make build-app`.
- Lint et tests dans une commande à part ; committer seulement après avoir lu leur résultat. Pas de trailer `Co-Authored-By`. Ne jamais pousser.
- Textes de l'interface en français, `String(localized:…, bundle: .module)` dans les packages, `String(localized:)` dans l'app. Commentaires en français, densité du code voisin.
- Kilos partout ; le réglage kg / lb reste caché (spec §2). Le thème clair reste forcé (spec §15).
- Une valeur sans données affiche « Pas assez de données » (ou une phrase précise) et sa raison, jamais 0 (spec §2).
- Style Argentique : papier, encre, `PulsePalette.signal` seulement pour ce qui alerte. Réutiliser `PulseSectionHeader`, `PulseRow`, `ObsidianCard`, `PillButtonStyle`, `IconChip`, `pulseEyebrow()`, `PulseFont`, et la structure d'écran de `StatsScreen` (`NavigationStack`, `pulseScreenBackground(aura: 0.5)`, `hidingNavigationBar()` copié dans le module).
- Les écrans poussés : `.navigationTitle(…)`, `.pulseInlineTitle()`, `.pulseScreenBackground(aura: 0.5)` (comme `SupplementsView`).
- Lecture Apple Santé du poids : 365 jours, comme les courses ; un échantillon effacé d'Apple Santé supprime sa mesure ; une lecture complète vide ne supprime jamais rien quand le cache avait des échantillons (accès révoqué ≠ suppression).

## Review Focus

1. **Accès Apple Santé révoqué** (lecture complète qui revient vide) : aucune mesure `.appleHealth` n'est supprimée, et aucune mesure `.manual` n'est jamais touchée par l'alignement. → tests `emptyFullReadKeepsMeasurements` et `manualMeasurementsAreNeverTouched` (tâche 1).
2. **Peu ou pas de pesées** (aucune, une seule, la dernière il y a plus de 14 jours) : la tendance dit « Pas encore de pesée » ou « dernière mesure le … », jamais 0, et la variation sur 30 jours est absente. → tests `noMeasurementGivesNoTrend`, `staleTrendKeepsItsDate`, `changeNeedsAMeasurementThirtyDaysBefore` (tâche 2).
3. **Pesée manuelle et Apple Santé le même jour** : la manuelle gagne pour la valeur du jour. → test `manualWinsTheDay` (tâche 2).
4. **Réglage invalide** (taille 0, prénom fait d'espaces, incrément négatif, repos hors liste) : refusé avec un message, le profil n'est pas écrit et aucune replanification ne part. → tests `invalidChangesAreRejected`, `unchangedProfileIsNotWritten` (tâche 4).
5. **Build Release** : le debug « Données » n'existe pas en Release, le diagnostic Apple Santé reste accessible depuis les paramètres. → vérification `make build-release` et `grep` dans la tâche 9.

---

## Lot 1 — Moteur

### Task 1: Poids et masse grasse lus d'Apple Santé

**Files:**
- Modify: `Packages/PulseDomain/Sources/PulseDomain/Local/CachedHealthSample.swift` (`HealthSampleKind` : `bodyMass`, `bodyFat`)
- Modify: `Packages/PulseDomain/Sources/PulseDomain/Repositories/HealthSampleCache.swift` (`healthCacheRetention(for:)` : 367 jours pour les deux)
- Create: `Packages/PulseDomain/Sources/PulseDomain/Health/HealthBodySource.swift`
- Create: `Packages/PulseFeatures/Sources/PulseServices/Doubles/InMemoryBodyMeasurementRepository.swift`
- Create: `Packages/PulseFeatures/Sources/PulseServices/Health/BodyHistory.swift`
- Modify: `Packages/PulseFeatures/Sources/PulseServices/Health/WorkoutHistory.swift` (garde de lecture vide)
- Modify: `Packages/PulseFeatures/Sources/PulseServices/Health/ScenarioHealthSource.swift` (conforme à `HealthBodySource`)
- Modify: `Packages/PulseFeatures/Sources/PulseServices/Refresh/DayRefresher.swift` (paramètre `bodyHistory: BodyHistory? = nil`, appelé juste après `workoutHistory`)
- Modify: `Packages/PulseHealth/Sources/PulseHealth/HealthKitReader+SampleSource.swift` (conforme à `HealthBodySource`)
- Test: `Packages/PulseFeatures/Tests/PulseServicesTests/BodyHistoryTests.swift`, `WorkoutHistoryTests.swift`, `InMemoryRepositoriesTests.swift`

**Interfaces:**
- Produces:

```swift
// PulseDomain
public enum BodySignal: String, Sendable, CaseIterable { case bodyMass, bodyFat; public var kind: HealthSampleKind }
public protocol HealthBodySource: Sendable {
    /// Comme `workoutChanges` : sans ancre utilisable, lecture complète (`isFullRead`). `value` en kg pour le poids,
    /// en pourcentage 0…100 pour la masse grasse.
    func bodyChanges(of signal: BodySignal, since anchor: Data?, from start: Date) async throws -> HealthSampleChanges
}
// PulseServices
public actor InMemoryBodyMeasurementRepository: BodyMeasurementRepository { public init(_ measurements: [BodyMeasurement] = []) }
public struct BodyHistory: Sendable {
    public static let historyDays = 365
    public init(source: any HealthBodySource, cache: any HealthSampleCache, measurements: any BodyMeasurementRepository,
                windows: any HealthReadWindowStore, calendar: Calendar)
    @discardableResult public func refresh(now: Date) async -> Bool   // vrai si une mesure a été ajoutée, modifiée ou supprimée
}
```

Règles :
- `BodyHistory` suit `WorkoutHistory` (fenêtre `HealthReadWindowStore`, lecture complète tant que la fenêtre stockée est < 365, ancre sinon). Un échantillon donne une `BodyMeasurement` `.appleHealth` (`date` = début de l'échantillon, `weightKg` **ou** `bodyFatPercent` selon le signal, `healthKitUUID`), retrouvée par UUID (garde `id` et `createdAt`). Après l'alignement, une mesure `.appleHealth` de la fenêtre dont l'UUID n'est plus dans le cache est supprimée ; les `.manual` ne sont jamais lues ni écrites par l'alignement.
- **Garde de lecture vide** (ici et dans `WorkoutHistory.sync`, à la place de la garde actuelle liée à la fenêtre) : si `changes.isFullRead && changes.added.isEmpty` et que le cache contient déjà des échantillons du type, `sync` rend `false` sans appliquer ni sauver la fenêtre.
- `HealthKitReader` : `HKQuantityType(.bodyMass)` en `.gramUnit(with: .kilo)`, `HKQuantityType(.bodyFatPercentage)` en `.percent()` multiplié par 100 ; même descripteur ancré que `quantityChanges`.
- `ScenarioHealthSource` : propriété `bodySamples: [BodySignal: [CachedHealthSample]]` (vide par défaut) rendue en lecture complète.
- L'app ne compile plus que si `DayRefresher` garde un défaut : `bodyHistory` vaut `nil` par défaut, l'app le branche en tâche 9.

- [ ] **Step 1: Write the failing tests** (`BodyHistoryTests`, source scriptée qui note les ancres comme `ScriptedWorkoutSource`) :
  - `weightSamplesBecomeMeasurements` : deux poids (78,4 et 78,1) et une masse grasse (17,5) → trois mesures `.appleHealth`, valeurs et UUID repris.
  - `secondPassKeepsIdsAndChangesNothing` : deux passages → mêmes `id`, `refresh` rend `false` au second.
  - `deletedSampleRemovesItsMeasurement` : l'échantillon « w1 » dans `deletedHealthKitUUIDs` → sa mesure disparaît.
  - `manualMeasurementsAreNeverTouched` : une manuelle du même jour qu'un échantillon, puis une lecture qui supprime tout → la manuelle reste, inchangée.
  - `emptyFullReadKeepsMeasurements` : cache rempli, fenêtre remise à 60, lecture complète vide → mesures gardées, fenêtre toujours à 60, lecture complète retentée au passage suivant.
  - `WorkoutHistoryTests.emptyFullReadWithCurrentWindowKeepsSessions` : fenêtre à 365, ancre illisible (la source rend `isFullRead` vrai et rien) → séances importées gardées.
  - `InMemoryRepositoriesTests.bodyMeasurementsAreSoftDeleted` : `measurements(from:to:)` filtre `date >= from && date < to`, trié par date ; `delete` retire du résultat.
  - `DayRefresherTests` (fichier existant du refresher) : `passReadsBodyAfterWorkouts` — un `BodyHistory` branché est rafraîchi pendant le passage (une mesure apparaît).
- [ ] **Step 2: Run** `swift test --package-path Packages/PulseFeatures --filter "BodyHistoryTests|WorkoutHistoryTests|InMemoryRepositoriesTests|DayRefresher"` → FAIL (types inconnus).
- [ ] **Step 3: Implement** les fichiers ci-dessus.
- [ ] **Step 4: Run** la même commande, puis `swift test --package-path Packages/PulseDomain`, `swift test --package-path Packages/PulsePersistence`, `swift test --package-path Packages/PulseFeatures`, `make build-app` → PASS / exit 0.
- [ ] **Step 5: Commit** `feat(health): read weight and body fat from Apple Health over a year`

### Task 2: Tendance du poids et BodyService

**Files:**
- Create: `Packages/PulseFeatures/Sources/PulseServices/Body/WeightTrend.swift`
- Create: `Packages/PulseFeatures/Sources/PulseServices/Body/BodyService.swift`
- Modify: `Packages/PulseFeatures/Sources/PulseServices/Health/BodyHistory.swift` (init reçoit `profiles:` ; après un alignement qui change quelque chose, `ProfileWeightSync.apply`)
- Test: `Packages/PulseFeatures/Tests/PulseServicesTests/WeightTrendTests.swift`, `BodyServiceTests.swift`, `BodyHistoryTests.swift`

**Interfaces:**
- Consumes: `BodyMeasurement`, `BodyMeasurementRepository`, `InMemoryBodyMeasurementRepository` (tâche 1), `StatsPoint` (M7a).
- Produces:

```swift
public struct WeightDay: Sendable, Equatable, Identifiable { public var date: Date; public var weightKg: Double; public var source: MeasurementSource; public var id: Date { date } }
public struct BodyFatReading: Sendable, Equatable { public var percent: Double; public var date: Date }
public struct WeightTrend: Sendable, Equatable {
    public static let window = 7            // jours de la moyenne
    public static let staleDays = 14
    public var days: [WeightDay]            // une valeur par jour mesuré, chronologique
    public var trendPoints: [StatsPoint]    // pour chaque jour mesuré : moyenne des jours mesurés des 7 jours finissant ce jour
    public var current: Double?             // dernier point de tendance
    public var lastMeasured: Date?
    public var isStale: Bool                // aucune pesée depuis 14 jours (lastMeasured < début du jour − 14 j)
    public var change30Days: Double?        // current − tendance au dernier jour mesuré ≤ lastMeasured − 30 j, nil sinon
    public var latestBodyFat: BodyFatReading?
    public static func make(measurements: [BodyMeasurement], now: Date, calendar: Calendar) -> WeightTrend
}
public enum ProfileWeightSync {
    /// Met `UserProfile.weightKg` sur la tendance (arrondie au dixième) s'il diffère ; rien sans tendance ni profil.
    public static func apply(measurements: any BodyMeasurementRepository, profiles: any ProfileRepository, now: Date, calendar: Calendar) async throws
}
public struct BodyOverview: Sendable, Equatable {
    public var trend: WeightTrend; public var measurements: [BodyMeasurement]   // 365 derniers jours, plus récente d'abord
    public var hasAppleHealthData: Bool
}
public enum BodyServiceError: Error, Equatable { case invalidWeight, notManual }
public struct BodyService: Sendable {
    public static let weightRange = 20.0...400.0
    public init(measurements: any BodyMeasurementRepository, profiles: any ProfileRepository, calendar: Calendar, now: @escaping @Sendable () -> Date)
    public func overview() async throws -> BodyOverview
    public func addManual(weightKg: Double, date: Date) async throws
    public func updateManual(_ measurement: BodyMeasurement) async throws      // `.manual` seulement, sinon `.notManual`
    public func deleteManual(id: UUID) async throws                             // idem
}
```

Règles (spec §14) : valeur du jour = la dernière mesure de poids du jour par `date`, une `.manual` l'emporte sur `.appleHealth` le même jour ; les mesures sans `weightKg` ne comptent que pour `latestBodyFat` (la plus récente avec `bodyFatPercent`). Chaque ajout, modification ou suppression manuelle appelle `ProfileWeightSync.apply`. Un poids hors de `weightRange` → `.invalidWeight`, rien n'est écrit.

- [ ] **Step 1: Write the failing tests**
  - `noMeasurementGivesNoTrend` : `current == nil`, `lastMeasured == nil`, `change30Days == nil`, `days.isEmpty`.
  - `trendIsTheSevenDayMeanOfMeasuredDays` : 80, 79, 78 aux jours J−2, J−1, J → `current == 79` ; une mesure à J−8 n'entre pas dans le dernier point.
  - `manualWinsTheDay` : à J, Santé 80,2 à 7 h puis manuelle 79,6 à 6 h → `days.last?.weightKg == 79.6`, source `.manual`.
  - `staleTrendKeepsItsDate` : dernière pesée il y a 20 jours → `isStale`, `current` = sa tendance, `lastMeasured` à sa date.
  - `changeNeedsAMeasurementThirtyDaysBefore` : pesées sur 40 jours qui baissent de 0,1 kg par jour → `change30Days` ≈ −3,0 ; sur 20 jours seulement → `nil`.
  - `bodyFatComesFromTheLatestReading` ; `fatOnlyMeasurementsDoNotMakeAWeightDay`.
  - `BodyServiceTests` : `addManualWritesAndSyncsProfile` (profil à 80, ajout de 78,5 → profil à 78,5) ; `invalidWeightIsRejected` (15 et 500 → `.invalidWeight`, rien d'écrit) ; `appleHealthMeasurementsCannotBeEdited` (`updateManual` / `deleteManual` sur une `.appleHealth` → `.notManual`) ; `overviewListsNewestFirstAndFlagsHealthData`.
  - `BodyHistoryTests.alignmentSyncsProfileWeight` : après un passage qui ajoute 77,9 → `profile.weightKg == 77.9`.
- [ ] **Step 2: Run** `swift test --package-path Packages/PulseFeatures --filter "WeightTrendTests|BodyServiceTests|BodyHistoryTests"` → FAIL.
- [ ] **Step 3: Implement.** Dates en jours de calendrier (`startOfDay`, `date(byAdding: .day, …)`), jamais en secondes.
- [ ] **Step 4: Run** la même commande puis toute la suite `PulseFeatures` → PASS ; `make lint` → 0.
- [ ] **Step 5: Commit** `feat(body): weight trend, manual weigh-ins and profile weight`

### Task 3: Badges et résumé du profil

**Files:**
- Create: `Packages/PulseFeatures/Sources/PulseServices/Profile/Badges.swift`
- Create: `Packages/PulseFeatures/Sources/PulseServices/Profile/ProfileService.swift`
- Test: `Packages/PulseFeatures/Tests/PulseServicesTests/BadgesTests.swift`, `ProfileServiceTests.swift`

**Interfaces:**
- Consumes: `WeekStreak.counts`, `WeekStreak.weeklyCounts` (interne au module), `WeekStreak.summary`, `WeekStreak.target(program:profile:)`, `WeekSchedule.weekStart(of:calendar:)`, `RecordStats.make` et `RecordStats.mainLifts` (M7a), `ExerciseDirectory`.
- Produces:

```swift
public enum BadgeKind: Sendable, Equatable, Hashable {
    case streak(weeks: Int)        // 4, 8, 12, 26, 52
    case sessions(count: Int)      // 10, 50, 100, 250, 500
    case firstFullMonth
}
public struct Badge: Sendable, Equatable, Identifiable {
    public var kind: BadgeKind; public var earnedAt: Date?
    public var current: Int; public var goal: Int            // progression : semaines d'affilée, séances, semaines réussies du meilleur mois
    public var progress: Double { /* min(1, current / goal) */ }
    public var id: BadgeKind { kind }
}
public struct BadgeShelf: Sendable, Equatable {
    public var earned: [Badge]     // chronologique
    public var next: [Badge]       // au plus un par famille (série, séances, premier mois), dans cet ordre
}
public enum Badges {
    public static let streakGoals = [4, 8, 12, 26, 52]
    public static let sessionGoals = [10, 50, 100, 250, 500]
    public static let fullMonthWeeks = 4
    public static func make(sessions: [WorkoutSession], target: Int, historyStart: Date?, now: Date, calendar: Calendar) -> BadgeShelf
}
public struct ProfileSummary: Sendable, Equatable {
    public var firstName: String?; public var sessionsTotal: Int; public var firstSession: Date?
    public var streakWeeks: Int; public var morningScore: Double?          // score du jour, nil sans score aujourd'hui
    public var mainLifts: [StrengthRecordLine]                            // les levés de base qui ont un record, dans l'ordre de RecordStats.mainLifts
    public var runs: [RunBest]                                            // toujours 3
    public var badges: BadgeShelf
}
public struct ProfileService: Sendable {
    public init(profiles: any ProfileRepository, programs: any ProgramRepository, workouts: any WorkoutRepository,
                recoveries: any RecoveryRepository, records: any PersonalRecordRepository,
                userExercises: any UserExerciseRepository, library: ContentLibrary, calendar: Calendar,
                now: @escaping @Sendable () -> Date)
    public func summary() async throws -> ProfileSummary
}
```

Règles (spec §13, §9) : séances comptées = `WeekStreak.counts` ; semaines jugées avec l'objectif d'aujourd'hui ; `historyStart` comme `StatsService`. `earnedAt` d'un badge de série = `startedAt` de la séance qui fait réussir la dernière semaine de la première suite de N semaines ; de séances = `startedAt` de la Nᵉ séance comptée ; premier mois complet = premier mois civil où au moins 4 semaines (lundi dans le mois) sont réussies, `earnedAt` = séance qui fait réussir la 4ᵉ. Progression des suivants : série = série en cours ; séances = total ; premier mois = meilleur nombre de semaines réussies dans un mois civil. Le résumé lit les séances `from: .distantPast`, le score du jour par `RecoveryRepository` sur le jour de `now`, et les records via `RecordStats.make(…, period: .year, …)`.

- [ ] **Step 1: Write the failing tests**
  - `streakBadgesDateTheirFirstRun` : 9 semaines réussies d'affilée → `.streak(4)` et `.streak(8)` gagnés, `earnedAt` = séance qui valide la 4ᵉ (et 8ᵉ) semaine ; `next.first?.kind == .streak(weeks: 12)` avec `current == 9`.
  - `sessionBadgesDateTheNthSession` : 12 séances → `.sessions(10)` daté à la 10ᵉ ; `next` contient `.sessions(50)` avec `current == 12`.
  - `firstFullMonthNeedsFourSuccessfulWeeks` : un mois avec 3 semaines réussies → pas gagné, `current == 3` ; le mois suivant avec 4 → gagné.
  - `ridesDoNotCount` ; `emptyHistory` (rien de gagné, trois `next` à 0).
  - `ProfileServiceTests.summaryOnSmallHistory` : 3 semaines de séances, un record de squat, un score aujourd'hui → `sessionsTotal`, `firstSession`, `streakWeeks`, `morningScore`, `mainLifts.first?.exercise == .content(id: "back-squat-barbell")`, `runs.count == 3` ; `noScoreToday` → `morningScore == nil`.
- [ ] **Step 2: Run** `swift test --package-path Packages/PulseFeatures --filter "BadgesTests|ProfileServiceTests"` → FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** → PASS ; `make lint` → 0.
- [ ] **Step 5: Commit** `feat(profile): badges and profile summary`

### Task 4: SettingsService et état d'Apple Santé

**Files:**
- Create: `Packages/PulseFeatures/Sources/PulseServices/Settings/SettingsService.swift`
- Create: `Packages/PulseFeatures/Sources/PulseServices/Settings/HealthReadStatus.swift`
- Test: `Packages/PulseFeatures/Tests/PulseServicesTests/SettingsServiceTests.swift`, `HealthReadStatusTests.swift`

**Interfaces:**
- Produces:

```swift
public enum SettingsError: Error, Equatable { case noProfile, invalidHeight, invalidIncrement, invalidRest, invalidDeadline, invalidPlates }
public struct SettingsService: Sendable {
    public static let restChoices = [60, 90, 120, 180]
    public static let heightRange = 100.0...250.0
    public static let deadlineRange = 360...720          // minutes après minuit : 6 h à 12 h
    /// `onChange(ancien, nouveau)` part après chaque écriture réussie ; c'est là que l'app replanifie.
    public init(profiles: any ProfileRepository, now: @escaping @Sendable () -> Date,
                onChange: @escaping @Sendable (UserProfile, UserProfile) async -> Void)
    public func load() async throws -> UserProfile                                   // `.noProfile` sans profil
    @discardableResult
    public func update(_ change: @Sendable (inout UserProfile) -> Void) async throws -> UserProfile
}
public struct HealthKindStatus: Sendable, Equatable, Identifiable { public var kind: HealthSampleKind; public var latest: Date?; public var id: HealthSampleKind { kind } }
public struct HealthReadStatus: Sendable, Equatable {
    public var kinds: [HealthKindStatus]   // HealthSampleKind.allCases, dans cet ordre
    public var lastRead: Date?             // le plus récent `fetchedAt` du cache
    public static func read(cache: any HealthSampleCache) async throws -> HealthReadStatus
}
```

Règles : `update` charge, applique `change`, normalise (prénom rogné, vide → `nil` ; disques > 0 triés décroissants), valide (taille dans `heightRange` ou `nil` ; incréments > 0 ; `defaultRestSeconds` dans `restChoices` ; `morningScoreDeadlineMinutes` dans `deadlineRange` ou `nil` ; barre > 0 et au moins un disque), puis, seulement si le profil a changé, pose `updatedAt = now()`, enregistre et appelle `onChange`. Une erreur de validation n'écrit rien et n'appelle rien. HealthKit ne dit pas si la lecture est refusée : l'état par type est « dernière donnée lue », pas une autorisation (spec §14).

- [ ] **Step 1: Write the failing tests**
  - `updateWritesAndNotifiesOnce` : prénom « Mathéo » → profil enregistré, `onChange` appelé une fois avec ancien et nouveau, `updatedAt` = `now`.
  - `unchangedProfileIsNotWritten` : même valeur → aucun enregistrement, aucun `onChange`.
  - `invalidChangesAreRejected` : taille 0 → `.invalidHeight` ; incrément −2,5 → `.invalidIncrement` ; repos 75 → `.invalidRest` ; heure plafond 13 h → `.invalidDeadline` ; disques vides → `.invalidPlates` ; dans chaque cas le profil stocké est inchangé et `onChange` n'est pas appelé.
  - `firstNameIsTrimmedAndEmptyBecomesNil` ; `platesAreSortedDescending`.
  - `HealthReadStatusTests.latestPerKindAndLastRead` : échantillons sdnn d'hier et course du 1ᵉʳ nov. → `latest` de chaque type, les autres `nil`, `lastRead` = plus grand `fetchedAt`.
- [ ] **Step 2: Run** `swift test --package-path Packages/PulseFeatures --filter "SettingsServiceTests|HealthReadStatusTests"` → FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** → PASS ; toute la suite `PulseFeatures` ; `make lint` → 0.
- [ ] **Step 5: Commit** `feat(settings): settings service and Apple Health read status`

---

## Lot 2 — Écrans (`ProfileFeature`)

### Task 5: Cible ProfileFeature et page Profil

**Files:**
- Modify: `Packages/PulseFeatures/Package.swift` (produit et cible `ProfileFeature` : dépendances `["PulseServices", "StatsFeature", "SupplementsFeature", "TrainFeature", designSystem, domain, recoveryEngine, content]`, `resources: [.process("Resources")]`, `swiftSettings` comme `StatsFeature` ; cible de test `ProfileFeatureTests` : `["ProfileFeature", "PulseServices", domain, content]`)
- Create: `Packages/PulseFeatures/Sources/ProfileFeature/ProfileEnvironment.swift`, `ProfileModel.swift`, `ProfileText.swift`, `Resources/Localizable.xcstrings`, `Views/ProfileScreen.swift`, `Views/ProfileSections.swift`, `Views/ProfilePreviewSupport.swift`
- Test: `Packages/PulseFeatures/Tests/ProfileFeatureTests/ProfileModelTests.swift`

**Interfaces:**
- Consumes: `ProfileService.summary()`, `BodyService.overview()`, `SettingsService`, `HealthReadStatus`, `BodyService` (tâches 2 à 4) ; `SupplementsModel`, `SupplementsView` ; `RecordStats`, `RunBest`, `StatsText`-like formats (copier les formats utiles dans `ProfileText`, `StatsText` étant interne).
- Produces:

```swift
public struct ProfileEnvironment: Sendable {
    public var profile: ProfileService; public var body: BodyService; public var settings: SettingsService
    public var healthCache: any HealthSampleCache
    public var inspector: any StoreInspector; public var exporter: any DataExporter; public var eraser: any DataEraser
    public var notificationsDenied: @Sendable () async -> Bool        // réglages iOS refusés
    public var refreshHealth: @Sendable () async -> Void              // « Relire maintenant » : le passage du jour
    public var appVersion: String; public var privacyPolicyURL: URL?
    public var calendar: Calendar; public var now: @Sendable () -> Date
    public init(…)   // tous les champs, dans cet ordre
}
/// Les écrans qui restent dans la cible app (spec §16).
public struct ProfileAppScreens {
    public var healthDiagnostics: () -> AnyView
    public var dataDebug: (() -> AnyView)?                              // nil en Release
    public var eraseConfirmation: (_ onErased: @escaping () async -> Void) -> AnyView
    public init(healthDiagnostics:dataDebug:eraseConfirmation:)
}
@MainActor @Observable public final class ProfileModel {
    public private(set) var summary: ProfileSummary?; public private(set) var body: BodyOverview?
    public private(set) var errorMessage: String?; public private(set) var hasLoaded: Bool
    public init(environment: ProfileEnvironment, onProfileSaved: @escaping @MainActor (UserProfile) -> Void)
    public func load() async          // même garde de réentrance et même style d'erreur que StatsModel.load
}
public struct ProfileScreen: View {
    public init(model: ProfileModel, supplements: SupplementsModel, screens: ProfileAppScreens,
                onOpenStats: @escaping () -> Void, onOpenRecords: @escaping () -> Void, onErased: @escaping () async -> Void)
}
```

Contenu (spec §13) : en-tête (initiale dans une pastille, prénom ou « Ton profil », « N séances · depuis <mois année> » ou « Aucune séance pour l'instant ») ; trois tuiles (série en cours en semaines, score de ce matin ou « Pas encore de score aujourd'hui », poids tendance ou « Pas encore de pesée ») ; carte Poids et corps (tendance, variation 30 jours signée « −0,8 kg en 30 j », dernière masse grasse « 17,5 % · 12 nov. ») qui pousse l'écran Poids (tâche 6, placeholder `Text` jusque-là) ; mur des records (les levés de base « 120 kg » et les trois chronos, « Pas encore couru ») avec « Tout voir » → `onOpenRecords` ; vitrine (badges gagnés avec leur date, puis les `next` avec une barre de progression « 9 / 12 semaines ») ; liens en `PulseRow` : Statistiques (`onOpenStats`), Compléments (pousse `SupplementsView`), Paramètres (tâche 7), Mes données (tâche 8) — les deux derniers en placeholder jusqu'à leur tâche. Titres de badge : « 4 semaines d'affilée », « 10 séances », « Premier mois complet ».

- [ ] **Step 1: Write the failing tests** : `loadFillsSummaryAndBody` (environnement en mémoire avec quelques séances et une pesée) ; `failureKeepsLastDataAndShowsError` (dépôt de séances qui échoue à la demande, comme `ScriptedWorkouts` dans `StatsModelTests`) ; `ProfileText` : `sessionsSince(12, firstSession: 2026-03-14) == "12 séances · depuis mars 2026"`, `weightChange(-0.8) == "−0,8 kg en 30 j"`, `badgeTitle(.streak(weeks: 4)) == "4 semaines d'affilée"`.
- [ ] **Step 2: Run** `swift test --package-path Packages/PulseFeatures --filter ProfileFeatureTests` → FAIL.
- [ ] **Step 3: Implement** ; aperçus `#Preview` avec un environnement en mémoire (`#if DEBUG`, comme `StatsPreviewSupport`).
- [ ] **Step 4: Run** → PASS ; `swift build -c release --package-path Packages/PulseFeatures` ; `make lint` → 0.
- [ ] **Step 5: Commit** `feat(profile): ProfileFeature target and profile page`

### Task 6: Écran Poids

**Files:**
- Create: `Packages/PulseFeatures/Sources/ProfileFeature/WeightModel.swift`, `Views/WeightScreen.swift`, `Views/WeighInSheet.swift`
- Modify: `Packages/PulseFeatures/Sources/ProfileFeature/Views/ProfileSections.swift` (la carte Poids pousse `WeightScreen`)
- Test: `Packages/PulseFeatures/Tests/ProfileFeatureTests/WeightModelTests.swift`

**Interfaces:**
- Consumes: `BodyService` (`overview`, `addManual`, `updateManual`, `deleteManual`, `weightRange`, `BodyServiceError`), `WeightTrend`.
- Produces: `@MainActor @Observable public final class WeightModel { overview: BodyOverview?; errorMessage: String?; editor: WeighInDraft?; init(environment: ProfileEnvironment, onChanged: @escaping @MainActor () async -> Void); load(); startNew(); edit(_ measurement: BodyMeasurement); save() async; delete(_ measurement: BodyMeasurement) async }`, `struct WeighInDraft: Identifiable { id: UUID; measurementID: UUID?; weightText: String; date: Date }`.

Contenu (spec §14) : courbe 90 jours (`PointMark` des jours mesurés, `LineMark` de la tendance, domaine des dates épinglé aux 90 jours et coupé comme `statsPinnedDomain`) ; tendance et dernière masse grasse ; liste des mesures (date, poids ou masse grasse, source « Apple Santé » / « Saisie »), une saisie manuelle se modifie au toucher et se supprime par balayage, une mesure Apple Santé n'a ni l'un ni l'autre ; bouton « Ajouter une pesée » (feuille avec clavier décimal `pulseNumericKeyboard()`, date limitée à aujourd'hui) ; sans aucune mesure Apple Santé : « Aucune pesée dans Apple Santé. Vérifie l'accès de Pulse dans Santé → Partage. » ; erreur `.invalidWeight` : « Entre un poids entre 20 et 400 kg. ». Après chaque écriture, `onChanged` recharge la page Profil.

- [ ] **Step 1: Write the failing tests** : `savingADraftAddsAManualWeighIn` (« 78,4 » avec virgule → 78,4 kg) ; `invalidDraftShowsMessageAndKeepsSheet` (« 12 ») ; `editingKeepsTheMeasurementID` ; `deleteRemovesManualOnly`.
- [ ] **Step 2: Run** `swift test --package-path Packages/PulseFeatures --filter WeightModelTests` → FAIL.
- [ ] **Step 3: Implement** ; aperçus avec et sans mesures.
- [ ] **Step 4: Run** → PASS ; `make lint` → 0.
- [ ] **Step 5: Commit** `feat(profile): weight screen with manual weigh-ins`

### Task 7: Paramètres

**Files:**
- Create: `Packages/PulseFeatures/Sources/ProfileFeature/SettingsModel.swift`, `Views/SettingsScreen.swift`, `Views/SettingsSections.swift`, `Views/LicensesView.swift`
- Modify: `Packages/PulseFeatures/Sources/TrainFeature/Editor/AntiInterferenceSection.swift` (type, `init(disabled:onChange:)`, `title(of:)` et `detail(of:)` deviennent `public`)
- Modify: `Packages/PulseDesignSystem/Sources/PulseDesignSystem/Tokens/PulsePalette.swift` (ajout de `extension Theme { public var title: String }` : « Ivoire » pour `.amber`, « Acier » pour `.amethyst`, catalogue de `PulseDesignSystem`)
- Modify: `ProfileSections.swift` (le lien Paramètres pousse `SettingsScreen`)
- Test: `Packages/PulseFeatures/Tests/ProfileFeatureTests/SettingsModelTests.swift`

**Interfaces:**
- Consumes: `SettingsService` (`load`, `update`, `restChoices`, `heightRange`, `deadlineRange`, `SettingsError`), `HealthReadStatus.read(cache:)`, `ProfileEnvironment.notificationsDenied`, `refreshHealth`, `appVersion`, `ProfileAppScreens.healthDiagnostics`, `AntiInterferenceSection`.
- Produces: `@MainActor @Observable public final class SettingsModel { profile: UserProfile?; health: HealthReadStatus?; notificationsDenied: Bool; errorMessage: String?; isRefreshingHealth: Bool; init(environment: ProfileEnvironment, onProfileSaved: @escaping @MainActor (UserProfile) -> Void); load() async; update(_ change: @escaping @Sendable (inout UserProfile) -> Void) async; refreshHealth() async }`.

Sections (spec §15), chacune écrivant par `SettingsModel.update` (une erreur affiche son message français et recharge le profil stocké) :
- **Mon profil** : prénom (`pulseGivenNameField()`), date de naissance (« sert à la FC max des courses »), sexe (`Sex`, libellés « Femme », « Homme », « Non précisé »), taille en cm.
- **Apple Santé** : une ligne par type lu (sommeil, VFC, FC repos, courses, vélo, poids, masse grasse) avec « dernière donnée le … » ou « Aucune donnée lue » ; « Dernière lecture : … » ; bouton « Relire maintenant » (`refreshHealth`, puis relit l'état) ; lien « Diagnostic » (`screens.healthDiagnostics()`) ; phrase : « Apple Santé ne dit pas à Pulse si l'accès est refusé. Pour le vérifier : Santé → Partage → Apps → Pulse. »
- **Moteur d'adaptation** : « Ajuster mes séances automatiquement » (`adaptationEnabled`), `AntiInterferenceSection`, incréments haut et bas du corps (pas de 0,5 kg, de 0,5 à 10).
- **Séance** : échauffement automatique, repos par défaut (puces 60 / 90 / 120 / 180 s), barre (kg) et disques disponibles (puces multiples parmi 25, 20, 15, 10, 5, 2,5, 1,25, 0,5).
- **Affichage** : ambiance Ivoire / Acier (`Theme.title`).
- **Notifications** : score du matin (toggle) et heure plafond (6 h à 12 h, par demi-heure ; `nil` = 10 h), rappels de compléments, fin de repos ; si `notificationsDenied` : « Les notifications de Pulse sont coupées dans les réglages d'iOS. » et un lien `UIApplication.openSettingsURLString` (`#if canImport(UIKit)`).
- **À propos** : « Version 1.0.2 (14) » (`appVersion`), lien Licences (`LicensesView` : `MuscleMapArtwork.bundled.license`, « 1RM estimé : formule de Brzycki (1993) », « FC max : formule de Tanaka (2001), 208 − 0,7 × âge », « Polices : SF Pro et SF Mono, Apple »).

- [ ] **Step 1: Write the failing tests** : `loadReadsProfileHealthAndNotifications` ; `updateSavesThroughTheServiceAndReportsTheProfile` (`onProfileSaved` reçoit le nouveau thème) ; `invalidUpdateShowsMessageAndReloads` (repos 75 → message « Choisis un repos de 60, 90, 120 ou 180 s. », profil inchangé) ; `refreshHealthCallsThePassThenRereadsStatus`.
- [ ] **Step 2: Run** `swift test --package-path Packages/PulseFeatures --filter SettingsModelTests` → FAIL.
- [ ] **Step 3: Implement** ; aperçus.
- [ ] **Step 4: Run** → PASS ; `swift test --package-path Packages/PulseDesignSystem` ; `swift test --package-path Packages/PulseFeatures` ; `make lint` → 0.
- [ ] **Step 5: Commit** `feat(profile): settings screen`

### Task 8: Mes données

**Files:**
- Create: `Packages/PulseFeatures/Sources/ProfileFeature/MyDataModel.swift`, `Views/MyDataScreen.swift`
- Modify: `ProfileSections.swift` (le lien Mes données pousse `MyDataScreen`)
- Test: `Packages/PulseFeatures/Tests/ProfileFeatureTests/MyDataModelTests.swift`

**Interfaces:**
- Consumes: `StoreInspector` (`counts()`, `cloudAccountStatus()`), `DataExporter` (`exportJSON()`, `exportCSVArchive()`), `ProfileAppScreens.eraseConfirmation`, `.dataDebug`, `ProfileEnvironment.privacyPolicyURL`.
- Produces: `@MainActor @Observable public final class MyDataModel { counts: [StoreTable: Int]; cloudStatus: CloudAccountStatus?; shareURL: URL?; isBusy: Bool; errorMessage: String?; init(environment: ProfileEnvironment); refresh() async; exportJSON() async; exportCSV() async; static func cloudText(_ status: CloudAccountStatus?) -> String }`.

Contenu (spec §16) : « Sur ce téléphone » — séances (`workoutSessions`), scores (`dailyRecoveries`), pesées (`bodyMeasurements`), compléments (`supplements`), échantillons Apple Santé (`cachedHealthSamples`) ; état iCloud avec la phrase (`available` « Tes données se synchronisent avec ton compte iCloud. », `noAccount` « Aucun compte iCloud : tes données restent sur ce téléphone. », `restricted` « Le compte iCloud est restreint : la synchronisation est coupée. », `unknown` « État iCloud inconnu. ») ; « Exporter » — « Tout en JSON », « Tout en CSV (zip) » puis `ShareLink` ; « Supprimer » — « Tout supprimer » en rouge qui présente `screens.eraseConfirmation(onErased)` en feuille ; « Liens » — politique de confidentialité (ligne masquée si `privacyPolicyURL == nil`), Licences (`LicensesView`) ; « Outils de développement » (`screens.dataDebug`, section absente si `nil`).

- [ ] **Step 1: Write the failing tests** : `refreshReadsCountsAndCloudStatus` (inspecteur de test) ; `exportSetsShareURL` (exporteur de test) ; `exportFailureShowsMessage` ; `cloudTextCoversEveryStatus`.
- [ ] **Step 2: Run** `swift test --package-path Packages/PulseFeatures --filter MyDataModelTests` → FAIL.
- [ ] **Step 3: Implement** ; aperçus.
- [ ] **Step 4: Run** → PASS ; `swift test --package-path Packages/PulseFeatures` ; `swift build -c release --package-path Packages/PulseFeatures` ; `make lint` → 0.
- [ ] **Step 5: Commit** `feat(profile): my data screen`

---

## Lot 3 — App

### Task 9: Onglet Profil branché

**Files:**
- Modify: `Pulse/AppDependencies.swift` (`bodyHistory` passé à `DayRefresher` dans `makeRefresher` quand la source est un `HealthBodySource`, avec `UserDefaultsHealthReadWindowStore(suiteName: wiring.defaultsSuite)` ; `appVersion` passe de `private` à interne ; `settings: SettingsService` dont `onChange` relance `supplementService.rescheduleReminders()` quand `supplementRemindersEnabled` change)
- Modify: `Pulse/AppDependencies+Environments.swift` (`func profileEnvironment() -> ProfileEnvironment` : `ProfileService`, `BodyService` sur `bodyMeasurements`, `settings`, `healthCache`, `inspector`, `exporter`, `eraser`, `notificationsDenied` lu par `UNUserNotificationCenter.current().notificationSettings()` (`.denied`), `refreshHealth` = `refresher.refresh(origin: .foreground)`, `appVersion`, `privacyPolicyURL` lu dans l'Info.plist sous `PulsePrivacyPolicyURL`, `nil` si vide)
- Modify: `Pulse/Root/AppRootModel.swift` (`private(set) var profileModel: ProfileModel?`, créé dans `show(.main)` avec `onProfileSaved: { [weak self] in self?.profile = $0 }`, remis à `nil` dans `dropMainModels()` ; rechargé dans `becameActive` seulement si `hasLoaded`, en dernier, comme `stats`)
- Modify: `Pulse/Root/AppRootView.swift`, `Pulse/Root/MainTabView.swift` (l'onglet Profil montre `ProfileScreen` ; `onOpenStats` = `router.selectedTab = .stats` ; `onOpenRecords` = `stats.view = .records` puis `.stats` ; `refreshTabs()` recharge le profil s'il est chargé ; `ProfileAppScreens` : diagnostic = `HealthDiagnosticsView`, debug = `DataDebugView` sous `#if DEBUG` sinon `nil`, confirmation = `EraseConfirmationView` sur un `DataDebugModel`)
- Delete: `Pulse/Root/ProfileHubView.swift`
- Modify: `Pulse/Info.plist` (clé `PulsePrivacyPolicyURL` vide ; `NSHealthShareUsageDescription` cite aussi les entraînements, le poids et la masse grasse)
- Modify: `Pulse.xcodeproj/project.pbxproj` (produit `ProfileFeature`, quatre entrées sur le modèle de `StatsFeature` : lignes 26, 161, 288, 844-847, nouveaux identifiants hexadécimaux uniques de 24 caractères)

- [ ] **Step 1: Build** `make build-app` → exit 0.
- [ ] **Step 2: Verify** `swift test` sur PulseDomain, PulseRecoveryEngine, PulseContent, PulsePersistence, PulseDesignSystem, PulseFeatures (chacun à part) ; `make lint` → 0 ; `make build-release` → exit 0 ; `grep -n "DataDebugView" Pulse/Root/*.swift` montre l'usage sous `#if DEBUG` seulement.
- [ ] **Step 3: Commit** `feat(app): wire the Profile tab, settings and my data`

Vérifications laissées à Mathéo sur l'iPhone : sa balance lue d'Apple Santé et la courbe 90 jours, une pesée manuelle, un réglage changé et pris en compte en séance (repos par défaut, échauffement, disques), le thème Acier, l'export JSON et CSV, le debug absent de TestFlight.
