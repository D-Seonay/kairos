# Pulse M7a — Stats : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** remplacer l'onglet « Stats (M7) » par cinq vues (Charge, Biométrie, Muscles, Assiduité, Records) sur une période commune, calculées à la volée depuis les séances, les scores et les records.

**Architecture:** des constructeurs purs dans `PulseServices/Stats` (un par vue, plus `StatsPeriod`), assemblés par `StatsService.snapshot(for:)` qui lit les dépôts une fois. Une nouvelle cible `StatsFeature` (modèle `@Observable` + vues Swift Charts) les affiche. La lecture des courses Apple Santé passe de 60 à 365 jours avec une relecture complète unique.

**Tech Stack:** Swift 6.2, SwiftUI, Swift Charts, Swift Testing, packages SPM `PulseDomain`, `PulsePersistence`, `PulseFeatures`.

**Spec:** `docs/superpowers/specs/2026-11-20-pulse-m7-stats-profil-design.md` (§1 à §12, §18). À lire avant chaque tâche.

## Global Constraints

- Branche `m7-stats`. Avant tout commit : `git branch --show-current` doit dire `m7-stats` (le checkout est partagé avec Mathéo) ; `git status --short` et ajout des nouveaux fichiers **par nom** ; jamais `.agents/` ni `.gemini/`.
- Ne jamais lancer le simulateur : pas de `xcodebuild test`, `make test`, `make test-app`, `simctl`. Vérifier avec `swift test --package-path Packages/<Nom>`, `make lint`, `make build-app`, `make build-release`.
- Lint et tests dans une commande à part ; committer seulement après avoir lu leur résultat (jamais `lint; git commit`).
- Textes de l'interface en français, `String(localized:…, bundle: .module)` dans les packages, comme le code voisin. Commentaires en français, densité du code voisin.
- Pas de trailer `Co-Authored-By` dans les commits.
- Swift Charts en encre monochrome (`PulsePalette.ink` / `text`), la couleur signal (`PulsePalette.signal`) réservée à la ligne de risque ACWR, aux muscles délaissés et aux ratios d'équilibre hors bornes.
- Une valeur sans données affiche « Pas assez de données » et sa raison, jamais 0.
- Périodes : 7, 30, 90, 365 jours glissants, aujourd'hui inclus ; défaut 30 jours.
- Les séances comptées dans la charge : `status == .completed || .abandoned` (comme `TrainingLoad`) ; dans les muscles, l'assiduité et les records de course : `.completed` seulement.

## Review Focus

1. **Aucune donnée du tout** (nouvel utilisateur, M7 ouvert au jour 1) : chaque vue s'affiche sans plantage ni division par zéro, avec ses textes « pas assez de données ». → test `emptyHistoryGivesEmptyViews` dans la tâche 7.
2. **Changement d'heure** (fenêtres glissantes qui traversent le passage à l'heure d'hiver du 25 octobre 2026) : 30 jours restent 30 jours de calendrier, pas 30 × 86 400 s. → test `periodSpansDaylightSavingChange` dans la tâche 2.
3. **Exercice inconnu de l'annuaire** (exercice perso supprimé, référence Hevy non résolue) : ses séries sont ignorées pour les muscles et l'équilibre, sans fausser le reste. → test `unknownExerciseIsIgnored` dans la tâche 4.
4. **Course sans durée ou à distance nulle** (entrée Apple Santé incomplète) : jamais retenue comme record, jamais de temps infini. → test `runWithoutDurationOrDistanceIsSkipped` dans la tâche 6.
5. **Relecture élargie des courses qui échoue** (Apple Santé indisponible au premier passage après la mise à jour) : les séances déjà importées restent, et la relecture complète est retentée au passage suivant. → test `failedWideningIsRetried` dans la tâche 1.

---

## Lot 1 — Moteur

### Task 1: Courses et vélos lus sur un an

**Files:**
- Modify: `Packages/PulseDomain/Sources/PulseDomain/Repositories/HealthSampleCache.swift` (rétention par type)
- Modify: `Packages/PulsePersistence/Sources/PulsePersistence/Repositories/SwiftDataHealthSampleCache.swift:61-70`
- Modify: `Packages/PulseFeatures/Sources/PulseServices/Doubles/InMemoryHealthSampleCache.swift:25-28`
- Create: `Packages/PulseFeatures/Sources/PulseServices/Health/HealthReadWindowStore.swift`
- Modify: `Packages/PulseFeatures/Sources/PulseServices/Health/WorkoutHistory.swift`
- Test: `Packages/PulseFeatures/Tests/PulseServicesTests/WorkoutHistoryTests.swift`, `Packages/PulseFeatures/Tests/PulseServicesTests/InMemoryRepositoriesTests.swift`, le test existant du cache SwiftData dans `Packages/PulsePersistence/Tests/`

**Interfaces:**
- Produces:
  - `public func healthCacheRetention(for kind: HealthSampleKind) -> TimeInterval` dans PulseDomain : 62 jours pour `.sdnn`, `.restingHeartRate`, `.sleep` ; **367 jours** pour `.run`, `.ride`. La constante `healthCacheRetention` disparaît ; ses deux usages appellent la fonction.
  - `public protocol HealthReadWindowStore: Sendable { func days(for kind: HealthSampleKind) -> Int?; func save(days: Int, for kind: HealthSampleKind) }`, `public final class UserDefaultsHealthReadWindowStore: HealthReadWindowStore` (`init(suiteName: String?)`, clé `"pulse.healthReadWindow.<kind>"`, même forme que `UserDefaultsDayActivityLog`), `public final class InMemoryHealthReadWindowStore: HealthReadWindowStore` (verrou interne, comme `InMemoryDayActivityLog`).
  - `WorkoutHistory.historyDays = 365` ; `WorkoutHistory.init(source:cache:workouts:profiles:windows: any HealthReadWindowStore, calendar:)`.

- [ ] **Step 1: Write the failing tests**

Dans `WorkoutHistoryTests` (le `history` du test reçoit `windows: InMemoryHealthReadWindowStore()`, gardé en propriété) :

```swift
@Test func storedNarrowWindowForcesOneFullRead() async throws {
    try await cache.saveAnchor(Data("old".utf8), for: .run)
    windows.save(days: 60, for: .run)
    await source.set(runs: [run("r1", at: "2026-03-01T08:00")])
    await history.refresh(now: now)
    #expect(await source.anchorsSeen(for: .run) == [nil])          // ancre ignorée une fois
    #expect(windows.days(for: .run) == WorkoutHistory.historyDays)
    #expect(try await workouts.sessions(from: .distantPast, to: now).map(\.healthKitUUID) == ["r1"])
    await history.refresh(now: now)
    #expect(await source.anchorsSeen(for: .run).last != nil)       // ensuite, lecture ancrée
}

@Test func failedWideningIsRetried() async throws {
    windows.save(days: 60, for: .run)
    await source.set(runs: nil)                                      // la lecture échoue
    await history.refresh(now: now)
    #expect(windows.days(for: .run) == 60)
    await source.set(runs: [run("r1", at: "2026-03-01T08:00")])
    await history.refresh(now: now)
    #expect(await source.anchorsSeen(for: .run).last == .some(nil))
    #expect(windows.days(for: .run) == 365)
}

@Test func runsOlderThanTwoMonthsSurviveAlignment() async throws {
    await source.set(runs: [run("old", at: "2026-02-10T08:00"), run("new", at: "2026-11-10T08:00")])
    await history.refresh(now: now)
    await history.refresh(now: now)
    #expect(try await workouts.sessions(from: .distantPast, to: now).compactMap(\.healthKitUUID).sorted() == ["new", "old"])
}
```

`ScriptedWorkoutSource` note les ancres reçues par type (`anchorsSeen(for:) -> [Data?]`). Dans `InMemoryRepositoriesTests`, `runSamplesAreKeptForAYear` : un `.run` daté 300 jours avant le plus récent reste après `apply` ; un `.sdnn` daté 70 jours avant est élagué. Même cas dans le test du cache SwiftData.

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path Packages/PulseFeatures --filter "WorkoutHistoryTests|InMemoryRepositoriesTests"`
Expected: FAIL (initialiseur `windows:` inconnu, `healthCacheRetention(for:)` inconnu).

- [ ] **Step 3: Implement**

`WorkoutHistory.sync` : si `windows.days(for: signal.kind) ?? 0 < Self.historyDays`, l'ancre passée est `nil` (lecture complète, `isFullRead` vrai, le cache remplace le type) ; après un `cache.apply` réussi, `windows.save(days: Self.historyDays, for:)`. Une première installation (aucune ancre) écrit aussi la fenêtre. Mettre à jour le commentaire de `historyDays`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --package-path Packages/PulseFeatures --filter "WorkoutHistoryTests|InMemoryRepositoriesTests"` puis `swift test --package-path Packages/PulsePersistence` et `swift test --package-path Packages/PulseDomain`
Expected: PASS. Corriger les autres appels de `WorkoutHistory.init` dans les tests (`RefresherFixture`, `DayRefresher*Tests`) avec `InMemoryHealthReadWindowStore()`.

- [ ] **Step 5: Commit**

```bash
git add Packages/PulseFeatures/Sources/PulseServices/Health/HealthReadWindowStore.swift  # + fichiers modifiés, par nom
git commit -m "feat(health): read runs and rides over a year, with a one-time full read"
```

L'app (`Pulse/AppDependencies.swift:336`) ne compile plus avant la tâche 11 ; y passer dès maintenant `windows: UserDefaultsHealthReadWindowStore(suiteName: wiring.defaultsSuite)` pour que `make build-app` reste vert.

### Task 2: Période et vue Charge

**Files:**
- Create: `Packages/PulseFeatures/Sources/PulseServices/Stats/StatsPeriod.swift`
- Create: `Packages/PulseFeatures/Sources/PulseServices/Stats/LoadStats.swift`
- Modify: `Packages/PulseFeatures/Sources/PulseServices/Today/TrainingLoad.swift` (`loadSession` passe de `private` à interne)
- Test: `Packages/PulseFeatures/Tests/PulseServicesTests/StatsPeriodTests.swift`, `LoadStatsTests.swift`

**Interfaces:**
- Produces:

```swift
public enum StatsPeriod: String, CaseIterable, Sendable, Identifiable { case week, month, quarter, year }
//   days: 7, 30, 90, 365 ; title: « 7 jours », « 30 jours », « 90 jours », « 1 an »
//   func interval(now: Date, calendar: Calendar) -> DateInterval        // début du jour (now − days + 1) → début de demain
//   func previousInterval(now: Date, calendar: Calendar) -> DateInterval // les `days` jours d'avant
//   var chartBucket: StatsBucket   // .day, sauf .year → .week
//   var loadBucket: StatsBucket    // .day pour .week, sinon .week
public enum StatsBucket: Sendable { case day, week }   // semaine = lundi (WeekSchedule.weekStart)
public struct StatsPoint: Sendable, Equatable, Identifiable { public var date: Date; public var value: Double }
public struct StatsComparison: Sendable, Equatable {
    public var value: Double; public var previous: Double?
    public var change: Double? { /* (value − previous) / previous, nil si previous nil ou 0 */ }
}
public struct LoadBar: Sendable, Equatable, Identifiable { public var start: Date; public var strength, run, ride: Double }
public struct LoadTotals: Sendable, Equatable {
    public var tonnageKg: Double; public var runMeters: Double; public var rideMeters: Double
    public var minutes: Double; public var sessions: Int; public var strengthShare: Double?   // part de la charge, 0…1
}
public enum LoadVerdict: Sendable, Equatable {
    case deload(until: Date), optimal(weeks: Int), elevated(days: Int), low, steady
}
public struct LoadStats: Sendable, Equatable {
    public var today: ACWRResult?; public var acuteWeekBefore: Double?
    public var ratioPoints: [StatsPoint]; public var daysUntilRatio: Int?   // nil dès 28 jours d'historique
    public var verdict: LoadVerdict?; public var bars: [LoadBar]; public var totals: LoadTotals
    public static func make(sessions: [WorkoutSession], onboardingCompletedAt: Date?, deloadUntil: Date?,
                            period: StatsPeriod, now: Date, calendar: Calendar) -> LoadStats
}
```

- [ ] **Step 1: Write the failing tests**

`StatsPeriodTests` : `monthIntervalCoversThirtyCalendarDays` (now `2026-11-20T12:00` → début `2026-10-22T00:00`, fin `2026-11-21T00:00`, précédent `2026-09-22` → `2026-10-22`) ; `periodSpansDaylightSavingChange` (même cas, compte des jours de calendrier = 30, avec `TestClock.calendar` en Europe/Paris) ; `buckets` (`.year.chartBucket == .week`, `.week.loadBucket == .day`, `.month.loadBucket == .week`).

`LoadStatsTests` (fixture locale : 5 semaines de séances de 60 min RPE 7, une course de 45 min `estimatedRPE` 6, un vélo de 60 min `estimatedRPE` 8) :
- `todayMatchesTrainingLoad` : `today == TrainingLoad.acwr(sessions:onboardingCompletedAt:now:calendar:)`.
- `ratioPointsOnePerDayFromDay28` : historique de 35 jours, période `.month` → `ratioPoints.count == 8` (jours 28 à 35), `daysUntilRatio == nil`.
- `daysUntilRatioCountsDown` : historique de 10 jours → `ratioPoints.isEmpty`, `daysUntilRatio == 18`.
- `yearPointsAreWeekly` : période `.year` → un point par dimanche.
- `rideIsCappedAtFive` : la barre de la semaine du vélo a `ride == 60 * 5`.
- `totals` : tonnage = somme des `tonnageKg` des séances de musculation ; `strengthShare` = charge muscu / charge totale.
- `verdicts` : décharge passée → `.deload(until:)` prioritaire ; ratio optimal sur 15 jours d'affilée → `.optimal(weeks: 2)` ; ratio > 1,3 depuis 3 jours → `.elevated(days: 3)` ; < 0,8 → `.low` ; optimal depuis moins de 7 jours → `.steady` ; sans ratio → `nil`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path Packages/PulseFeatures --filter "StatsPeriodTests|LoadStatsTests"`
Expected: FAIL (types inconnus).

- [ ] **Step 3: Implement** `StatsPeriod` et `LoadStats.make` dans les fichiers ci-dessus. Les points du ratio réutilisent `LoadCalculator.acwr(sessions:asOf:historyStart:)` sur `TrainingLoad.loadSession`, le début d'historique calculé comme `TrainingLoad.acwr`. Les intervalles se construisent avec `calendar.date(byAdding: .day, …)` sur `startOfDay`, jamais en secondes.

- [ ] **Step 4: Run tests to verify they pass** (même commande) puis `swift test --package-path Packages/PulseFeatures --filter TrainingLoadTests`. Expected: PASS.

- [ ] **Step 5: Commit** `feat(stats): period and load view`

### Task 3: Vue Biométrie

**Files:**
- Create: `Packages/PulseFeatures/Sources/PulseServices/Stats/BiometryStats.swift`
- Test: `Packages/PulseFeatures/Tests/PulseServicesTests/BiometryStatsTests.swift`

**Interfaces:**
- Consumes: `StatsPeriod`, `StatsPoint`, `StatsComparison` (tâche 2).
- Produces:

```swift
public struct BaselinePoint: Sendable, Equatable, Identifiable { public var date: Date; public var value: Double; public var baseline: Double? }
public struct SleepPoint: Sendable, Equatable, Identifiable { public var date: Date; public var asleepMinutes: Double; public var deepMinutes: Double? }
public struct CategoryCount: Sendable, Equatable, Identifiable { public var category: RecoveryCategory; public var days: Int }
public struct BiometryStats: Sendable, Equatable {
    public var hrv: StatsComparison?; public var restingHeartRate: StatsComparison?
    public var sleepMinutes: StatsComparison?; public var deepShare: Double?; public var score: StatsComparison?
    public var hrvPoints: [BaselinePoint]; public var restingPoints: [BaselinePoint]; public var sleepPoints: [SleepPoint]
    public var categories: [CategoryCount]   // toujours les 4 catégories, dans l'ordre de RecoveryCategory.allCases
    public static func make(recoveries: [DailyRecovery], period: StatsPeriod, now: Date, calendar: Calendar) -> BiometryStats
}
```

- [ ] **Step 1: Write the failing tests**
- `averagesSkipEstimatedDays` : 3 jours mesurés (SDNN 50, 60, 70) + 1 jour `isEstimated` avec SDNN nul → `hrv?.value == 60` ; le jour estimé compte dans `categories` et dans `score`.
- `comparesWithPreviousPeriod` : SDNN moyen 60 sur la période, 50 sur la précédente → `hrv?.change == 0.2`.
- `noPreviousDataMeansNoComparison` : `previous == nil`, `change == nil`.
- `deepShare` : 420 min de sommeil dont 84 profond, sur deux nuits → `deepShare == 0.2`.
- `yearAveragesPerWeek` : période `.year`, 14 nuits sur 2 semaines → `hrvPoints.count == 2`, valeur = moyenne de la semaine, `baseline` = moyenne des lignes de base de la semaine.
- `categoriesAlwaysListed` : aucun score → 4 lignes à 0, toutes les comparaisons `nil`.

- [ ] **Step 2: Run** `swift test --package-path Packages/PulseFeatures --filter BiometryStatsTests` → FAIL.
- [ ] **Step 3: Implement** `BiometryStats.make`. Les lignes `DailyRecovery` hors de `period.interval` ou de `previousInterval` sont ignorées ; un jour = `calendar.startOfDay(for: recovery.day)`.
- [ ] **Step 4: Run** la même commande → PASS.
- [ ] **Step 5: Commit** `feat(stats): biometry view`

### Task 4: Vue Muscles

**Files:**
- Create: `Packages/PulseFeatures/Sources/PulseServices/Stats/MuscleStats.swift`
- Test: `Packages/PulseFeatures/Tests/PulseServicesTests/MuscleStatsTests.swift`

**Interfaces:**
- Consumes: `StatsPeriod` ; `ExerciseDirectory.info(_:) -> ExerciseInfo?` (`primaryMuscles`, `secondaryMuscles`, `pattern`, `region`) ; `MuscleGroup(_ muscle:)` (PulseContent).
- Produces:

```swift
public struct MuscleLoad: Sendable, Equatable, Identifiable { public var muscle: Muscle; public var sets: Double }
public struct NeglectedGroup: Sendable, Equatable, Identifiable {
    public var group: MuscleGroup; public var weeklySets: Double; public var muscles: [MuscleLoad]   // les muscles du groupe, total décroissant
}
public struct MuscleStats: Sendable, Equatable {
    public static let neglectedWeeklySets = 4.0
    public static let balanceRange = 0.67...1.5
    public var weights: [Muscle: Double]; public var top: [MuscleLoad]   // 8 au plus, décroissant, à égalité ordre de Muscle.allCases
    public var neglected: [NeglectedGroup]
    public var push: Int; public var pull: Int; public var upper: Int; public var lower: Int
    public var isPushPullUnbalanced: Bool; public var isUpperLowerUnbalanced: Bool
    public var strengthSessions: Int
    public static func make(sessions: [WorkoutSession], directory: ExerciseDirectory, period: StatsPeriod, now: Date,
                            calendar: Calendar) -> MuscleStats
}
```

Règles (spec §8) : séries `setType != .warmup` des séances `.strength` `.completed` de la période ; principal +1, secondaire +0,5 (un muscle principal et secondaire ne compte qu'en principal, comme `SessionRecap.muscleWeights`) ; pousser = `horizontalPush, chestFly, verticalPush, elbowExtension`, tirer = `verticalPull, horizontalPull, elbowFlexion` ; haut = `.upper`, bas = `.lower`. Déséquilibre : un des deux > 0 et ratio hors de `balanceRange` (l'autre à 0 compte comme déséquilibré). Délaissé seulement si `period.days >= 30` et `strengthSessions / (days / 7) >= 1` ; un groupe délaissé a `weeklySets < 4`.

- [ ] **Step 1: Write the failing tests** (annuaire de test : `ExerciseDirectory(library: ContentLibrary(...), userExercises: [...])` avec 4 exercices perso — développé (pectoraux principal, triceps secondaire, `horizontalPush`, `.upper`), tirage (grand dorsal, biceps, `horizontalPull`), squat (quadriceps, fessiers, `.squat`, `.lower`), gainage (abdos, `.coreStability`, `.core`)) :
- `weightsCountPrimaryOneSecondaryHalf` : 3 séries de développé → `weights[.chest] == 3`, `weights[.triceps] == 1.5`.
- `warmupsAndAbandonedSessionsAreSkipped`.
- `unknownExerciseIsIgnored` : une série d'une référence absente de l'annuaire ne change ni `weights` ni `push`.
- `topIsCappedAtEight`.
- `balance` : 10 séries de développé, 5 de tirage → `push == 10`, `pull == 5`, `isPushPullUnbalanced` ; le gainage n'entre ni dans `upper` ni dans `lower`.
- `neglectedNeedsThirtyDaysAndRegularTraining` : 30 jours, 8 séances, 2 séries de gainage → `neglected.map(\.group) == [.core, …]` contient `.core` ; même données sur `.week` → `neglected.isEmpty` ; 30 jours avec 2 séances → vide.

- [ ] **Step 2: Run** `swift test --package-path Packages/PulseFeatures --filter MuscleStatsTests` → FAIL.
- [ ] **Step 3: Implement** `MuscleStats.make`.
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `feat(stats): muscles view`

### Task 5: Vue Assiduité et meilleure série

**Files:**
- Create: `Packages/PulseFeatures/Sources/PulseServices/Stats/AttendanceStats.swift`
- Modify: `Packages/PulseFeatures/Sources/PulseServices/Planning/WeekStreak.swift` (ajout de `best`)
- Test: `Packages/PulseFeatures/Tests/PulseServicesTests/AttendanceStatsTests.swift`, `WeekStreakTests.swift`

**Interfaces:**
- Consumes: `WeekStreak.summary`, `WeekStreak.counts`, `WeekSchedule.weekStart(of:calendar:)`, `TrainingLoad.loadSession`, `StatsPeriod`.
- Produces:

```swift
public struct BestStreak: Sendable, Equatable { public var weeks: Int; public var firstWeek: Date; public var lastWeek: Date }
extension WeekStreak {
    /// La plus longue suite de semaines réussies depuis la semaine de `historyStart` ; la semaine en cours compte si elle est déjà réussie.
    public static func best(sessions: [WorkoutSession], target: Int, historyStart: Date?, now: Date, calendar: Calendar) -> BestStreak?
}
public struct AttendanceDay: Sendable, Equatable, Identifiable { public var date: Date; public var level: Int; public var isFuture: Bool }  // level 0…4
public struct AttendanceStats: Sendable, Equatable {
    public static let matrixWeeks = 16
    public var weeks: [[AttendanceDay]]   // 16 colonnes de 7 jours (lundi → dimanche), la semaine en cours en dernier
    public var streak: StreakSummary; public var best: BestStreak?
    public var sessionsInPeriod: Int; public var sessionsTotal: Int; public var firstSession: Date?
    public var averageMinutes: Double?; public var usualHour: Int?; public var regularity: Double?
    public static func make(sessions: [WorkoutSession], target: Int, historyStart: Date?, period: StatsPeriod, now: Date,
                            calendar: Calendar) -> AttendanceStats
}
```

Niveaux (spec §9) : charge du jour = somme des `TrainingLoad.loadSession` du jour ; les jours à charge > 0 des 16 semaines, triés, donnent les seuils q1, q2, q3 au rang le plus proche (25 %, 50 %, 75 %) ; niveau 1 si ≤ q1, 2 si ≤ q2, 3 si ≤ q3, sinon 4. Séances comptées (`sessionsInPeriod`, `sessionsTotal`, durée, heure) : `WeekStreak.counts`. Heure habituelle : l'heure de début la plus fréquente, la plus tôt à égalité. Régularité : semaines (lundi) qui chevauchent la période, sans remonter avant la semaine de `historyStart`, semaine en cours exclue sauf si déjà réussie ; réussies / total ; `nil` sans semaine.

- [ ] **Step 1: Write the failing tests**
- `WeekStreakTests.bestFindsLongestRunAnywhere` : réussites sur 5 semaines, une manquée, puis 2 → `best?.weeks == 5`, `firstWeek`/`lastWeek` aux lundis attendus ; `bestIsNilWithoutSuccess`.
- `matrixHasSixteenWeeksOfSevenDays` : `weeks.count == 16`, chaque colonne 7 jours, les jours après aujourd'hui `isFuture`.
- `levelsFollowQuartiles` : charges quotidiennes 100, 200, 300, 400 → niveaux 1, 2, 3, 4 ; jour sans séance → 0.
- `usualHourIsTheMostFrequent` : séances à 18 h ×3, 7 h ×2 → `usualHour == 18`.
- `regularityIgnoresWeeksBeforeHistory`.
- `emptyHistory` : tout à 0 ou `nil`, `weeks` complet au niveau 0.

- [ ] **Step 2: Run** `swift test --package-path Packages/PulseFeatures --filter "AttendanceStatsTests|WeekStreakTests"` → FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `feat(stats): attendance view and best streak`

### Task 6: Vue Records

**Files:**
- Create: `Packages/PulseFeatures/Sources/PulseServices/Stats/RecordStats.swift`
- Test: `Packages/PulseFeatures/Tests/PulseServicesTests/RecordStatsTests.swift`

**Interfaces:**
- Consumes: `PersonalRecord` (chaque record battu est une ligne ; le record actuel d'un exercice et d'un type est la plus grande `value`), `StatsPeriod`, `ExerciseDirectory.name(of:fallback:)`.
- Produces:

```swift
public struct StrengthRecordLine: Sendable, Equatable, Identifiable {
    public var exercise: ExerciseReference; public var name: String
    public var kind: RecordKind            // .estimatedOneRepMax, ou .repsAtWeight pour un exercice sans 1RM
    public var value: Double; public var weightKg: Double?; public var reps: Int?   // la série d'origine, retrouvée par setID
    public var date: Date; public var gain: Double?; public var isNew: Bool
    public var id: ExerciseReference { exercise }
}
public enum RunDistance: Double, CaseIterable, Sendable { case fiveK = 5_000, tenK = 10_000, half = 21_097.5 }
public struct RunBest: Sendable, Equatable, Identifiable {
    public var distance: RunDistance; public var seconds: Double?; public var date: Date?; public var isNew: Bool
    public var id: RunDistance { distance }
}
public struct RecordStats: Sendable, Equatable {
    public static let mainLifts: [String] = ["back-squat-barbell", "bench-press-barbell", "deadlift-barbell", "overhead-press-barbell"]
    public static let minimumSessions = 5
    public var strength: [StrengthRecordLine]; public var runs: [RunBest]   // toujours 3 lignes de course
    public static func make(records: [PersonalRecord], sessions: [WorkoutSession], directory: ExerciseDirectory,
                            period: StatsPeriod, now: Date, calendar: Calendar) -> RecordStats
}
```

Règles (spec §10) : lignes de force = les quatre levés de base qui ont un record, dans cet ordre, puis tout autre exercice présent (série hors échauffement) dans au moins 5 séances `.completed`, par nom. `gain` = valeur actuelle − meilleure valeur datée avant le début de la période, `nil` sans record antérieur ou si le record actuel est lui-même antérieur à la période. `isNew` = record actuel daté dans la période. Course : séances `.run` `.completed` avec `distanceMeters >= distance.rawValue`, `durationMinutes > 0` ; temps = `durationMinutes × 60 × distance / distanceMeters` ; le plus petit gagne.

- [ ] **Step 1: Write the failing tests**
- `mainLiftsComeFirstInOrder` ; `otherExercisesNeedFiveSessions` (4 séances → absent, 5 → présent).
- `currentIsTheHighestValueAndGainIsAgainstBeforePeriod` : 1RM 90 (septembre), 95 (dans la période) → `value == 95`, `gain == 5`, `isNew`.
- `bodyweightExerciseShowsRepsRecord` : pas de 1RM, `repsAtWeight` 14 → `kind == .repsAtWeight`, `value == 14`.
- `repsComeFromTheRecordSet` : `reps` lu sur la série `setID`.
- `runTimeIsScaledFromAveragePace` : course de 10,2 km en 51 min → 5 km en 1 500 s, 10 km en 3 000 s, semi `nil`.
- `runWithoutDurationOrDistanceIsSkipped` : `durationMinutes` nil ou 0, `distanceMeters` nil → aucune ligne remplie.

- [ ] **Step 2: Run** `swift test --package-path Packages/PulseFeatures --filter RecordStatsTests` → FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `feat(stats): records view`

### Task 7: StatsService et fixture de 20 semaines

**Files:**
- Create: `Packages/PulseFeatures/Sources/PulseServices/Stats/StatsService.swift`
- Create: `Packages/PulseFeatures/Tests/PulseServicesTests/Support/StatsFixtures.swift`
- Test: `Packages/PulseFeatures/Tests/PulseServicesTests/StatsServiceTests.swift`

**Interfaces:**
- Consumes: les cinq `make` des tâches 2 à 6 ; `Deload.status(profile:now:calendar:)` (`.active(_, until)` → `deloadUntil`) ; `WeekStreak.target(program:profile:)`.
- Produces:

```swift
public struct StatsSnapshot: Sendable, Equatable {
    public var period: StatsPeriod; public var load: LoadStats; public var biometry: BiometryStats
    public var muscles: MuscleStats; public var attendance: AttendanceStats; public var records: RecordStats
}
public struct StatsService: Sendable {
    public init(profiles: any ProfileRepository, programs: any ProgramRepository, workouts: any WorkoutRepository,
                recoveries: any RecoveryRepository, records: any PersonalRecordRepository,
                userExercises: any UserExerciseRepository, library: ContentLibrary, calendar: Calendar,
                now: @escaping @Sendable () -> Date)
    public func snapshot(for period: StatsPeriod) async throws -> StatsSnapshot
}
```

Lectures : séances `from: .distantPast` (la meilleure série remonte à tout l'historique), scores depuis `period.previousInterval.start`, `records(for: nil)`, exercices perso `all(includeArchived: true)` (pour l'annuaire). `historyStart` = fin de l'onboarding ou première séance, la plus ancienne (comme `PlanningService.overview`).

`StatsFixtures` : 20 semaines finissant le vendredi 20 novembre 2026 — PPL lundi / mardi / mercredi + Push jeudi, course le samedi avec FC (≈ 8 km, 45 min), une semaine manquée (la 12ᵉ), 8 séances importées de Hevy au début, un vélo par mois, un score par nuit avec des trous (une nuit sur 10 absente, une sur 15 estimée), des records recalculés par `RecordBook.compute`.

- [ ] **Step 1: Write the failing tests**
- `snapshotOnFixture` : sur `.month`, `load.today != nil`, `attendance.best?.weeks == 8` (semaines après la semaine manquée), `records.strength.first?.exercise == .content(id: "back-squat-barbell")`, `records.runs[0].seconds != nil`, `biometry.hrv != nil`.
- `emptyHistoryGivesEmptyViews` : dépôts vides → `load.today == nil`, `load.daysUntilRatio != nil`, `muscles.top.isEmpty`, `attendance.weeks.count == 16`, `records.runs.allSatisfy { $0.seconds == nil }`, `biometry.categories.count == 4`.
- `aYearOfSessionsIsFast` : 52 semaines × 5 séances × 20 séries ; `snapshot(for: .year)` mesuré avec `ContinuousClock` < 1 s en debug (garde-fou ; la cible de la spec est 200 ms sur l'iPhone en release).

- [ ] **Step 2: Run** `swift test --package-path Packages/PulseFeatures --filter StatsServiceTests` → FAIL.
- [ ] **Step 3: Implement** `StatsService`.
- [ ] **Step 4: Run** puis toute la suite : `swift test --package-path Packages/PulseFeatures` → PASS. `make lint` → 0.
- [ ] **Step 5: Commit** `feat(stats): stats service and 20-week fixture`

---

## Lot 2 — Écrans (`StatsFeature`)

### Task 8: Cible StatsFeature et modèle

**Files:**
- Modify: `Packages/PulseFeatures/Package.swift` (produit et cible `StatsFeature` : dépendances `["PulseServices", "TrainFeature", designSystem, domain, content]`, `resources: [.process("Resources")]` ; cible de test `StatsFeatureTests` : `["StatsFeature", "PulseServices", domain, content]`)
- Create: `Packages/PulseFeatures/Sources/StatsFeature/StatsEnvironment.swift`, `StatsModel.swift`, `StatsText.swift`, `Resources/Localizable.xcstrings`
- Test: `Packages/PulseFeatures/Tests/StatsFeatureTests/StatsModelTests.swift`

**Interfaces:**
- Consumes: `StatsService.snapshot(for:)`, `TrainEnvironment` (pour la fiche d'exercice).
- Produces:

```swift
public struct StatsEnvironment: Sendable {
    public var service: StatsService; public var train: TrainEnvironment
    public var calendar: Calendar; public var now: @Sendable () -> Date
    public init(service: StatsService, train: TrainEnvironment, calendar: Calendar, now: @escaping @Sendable () -> Date)
}
public enum StatsView: String, CaseIterable, Sendable, Identifiable { case load, biometry, muscles, attendance, records }
@MainActor @Observable public final class StatsModel {
    public private(set) var snapshot: StatsSnapshot?; public private(set) var errorMessage: String?
    public private(set) var hasLoaded: Bool
    public var view: StatsView              // défaut .load
    public var period: StatsPeriod          // défaut .month ; le changer relance load()
    public init(environment: StatsEnvironment, period: StatsPeriod = .month)
    public func load() async                 // même garde de réentrance et même message d'erreur que PlanningModel.load
}
enum StatsText {   // formats français : « 2 140 », « +6 % », « 7 h 12 », « 24:31 », « 4:54 /km », « 91 200 kg »
    static func number(_ value: Double) -> String
    static func change(_ comparison: StatsComparison?) -> String?
    static func duration(minutes: Double) -> String
    static func raceTime(seconds: Double) -> String
    static func pace(secondsPerKm: Double) -> String
}
```

- [ ] **Step 1: Write the failing tests** : `loadFillsSnapshot`, `changingPeriodReloads` (le service de test compte les appels ; `period = .year` → un nouvel appel avec `.year`), `failureKeepsLastSnapshotAndShowsError`, `StatsText` (`change(+0,06) == "+6 %"`, `duration(432) == "7 h 12"`, `raceTime(1471) == "24:31"`, `number(91200) == "91 200"` avec espace fine insécable comme `PulseFormat` s'il l'utilise).
- [ ] **Step 2: Run** `swift test --package-path Packages/PulseFeatures --filter StatsFeatureTests` → FAIL.
- [ ] **Step 3: Implement.** Réutiliser `PulseFormat` (PulseDesignSystem : `duration(minutes:)`, `decimal(_:maxFractionDigits:)`, `signedPercent(_:)`, `integer(_:unit:)`) plutôt que d'écrire de nouveaux formats ; `StatsText` ne fait que les combiner et ajouter les temps de course.
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `feat(stats): StatsFeature target and model`

### Task 9: Écran Stats, vues Charge et Biométrie

**Files:**
- Create: `Packages/PulseFeatures/Sources/StatsFeature/Views/StatsScreen.swift`, `StatsTiles.swift`, `LoadSection.swift`, `BiometrySection.swift`, `StatsPreviewSupport.swift`

**Interfaces:**
- Consumes: `StatsModel`, `StatsSnapshot`.
- Produces: `public struct StatsScreen: View { public init(model: StatsModel) }` (l'énumération des vues s'appelle déjà `StatsView`).

Contenu (spec §5 à §7, §12) : `NavigationStack`, titre « Statistiques » ; segment des cinq vues défilable horizontalement ; puces de période ; `@AppStorage("stats.period")` dans l'écran, poussé dans `model.period`. Charge : tuiles aiguë / chronique / ratio, courbe `LineMark` du ratio avec `RectangleMark` 0,8–1,3 et `RuleMark` 1,5 en signal, la phrase du `LoadVerdict`, barres empilées `BarMark` (musculation, course, vélo en trois niveaux d'encre), totaux. Sans ratio : « L'ACWR s'affiche après 28 jours d'entraînement (encore N jours) ». Biométrie : quatre tuiles avec comparaison, `PointMark` VFC + `LineMark` ligne de base, FC repos, barres de sommeil (profond en encre pleine), barres horizontales des catégories. Chaque graphique : `.accessibilityChartDescriptor` ou `.accessibilityLabel` résumé. Aperçus `#Preview` avec un `StatsSnapshot` tiré d'une fixture de `StatsPreviewSupport` (environnement en mémoire, comme `PlanningFeature`).

- [ ] **Step 1: Build** `swift build --package-path Packages/PulseFeatures` → OK.
- [ ] **Step 2: Run** `swift test --package-path Packages/PulseFeatures` → PASS ; `make lint` → 0.
- [ ] **Step 3: Commit** `feat(stats): stats screen, load and biometry views`

### Task 10: Vues Muscles, Assiduité, Records

**Files:**
- Create: `Packages/PulseFeatures/Sources/StatsFeature/Views/MusclesSection.swift`, `AttendanceSection.swift`, `RecordsSection.swift`
- Modify: `Packages/PulseFeatures/Sources/StatsFeature/Views/StatsScreen.swift` (aiguillage des vues, destination de navigation)

Contenu (spec §8 à §10) : Muscles — `MuscleMapView(levels: MuscleIntensity.levels(weights:), …)` face et dos, liste des 8 plus travaillés, phrase de chaque `NeglectedGroup` en signal (« Tronc peu sollicité : 8 séries d'abdominaux et 6 d'obliques en 30 jours. »), équilibre pousser / tirer et haut / bas avec le ratio en signal hors bornes. Assiduité — grille 16 × 7 de pastilles à cinq niveaux d'encre, lisible semaine par semaine avec VoiceOver (« Semaine du 3 novembre : 4 séances »), tuiles série en cours / meilleure série avec dates / séances / durée moyenne et heure habituelle, régularité en %. Records — lignes de force (1RM « 96 kg », série d'origine « 85 kg × 5 · 28 oct. », « +2,5 kg » ou « nouveau »), lignes de course (« 24:31 », « allure moyenne de la sortie du 14 sept. », « Pas encore couru »). Toucher une ligne de force pousse `ExerciseSheetView(model:)` avec `model.tab = .progression`.

- [ ] **Step 1: Build** `swift build --package-path Packages/PulseFeatures` → OK.
- [ ] **Step 2: Run** `swift test --package-path Packages/PulseFeatures` → PASS ; `make lint` → 0.
- [ ] **Step 3: Commit** `feat(stats): muscles, attendance and records views`

---

## Lot 3 — App

### Task 11: Onglet Stats branché

**Files:**
- Modify: `Pulse/AppDependencies.swift` (un `StatsService` construit avec les dépôts existants, à côté de `planning`)
- Modify: `Pulse/AppDependencies+Environments.swift` (`func statsEnvironment() -> StatsEnvironment`)
- Modify: `Pulse/Root/AppRootModel.swift` (`private(set) var stats: StatsModel?`, créé et remis à nil comme `planning` ; `stats?.load()` après `planning?.load()` dans `becameActive` et au chargement)
- Modify: `Pulse/Root/AppRootView.swift`, `Pulse/Root/MainTabView.swift` (l'onglet Stats montre `StatsScreen(model:)` ; `refreshTabs()` appelle `await stats.load()` ; le commentaire « Stats arrive en M7 » disparaît ; `comingSoon` supprimé s'il n'a plus d'usage)
- Modify: `Pulse.xcodeproj/project.pbxproj` (dépendance de produit `StatsFeature`, à la main, sur le modèle des entrées `PlanningFeature` lignes 25, 159, 285, 837)

- [ ] **Step 1: Build** `make build-app` → `BUILD SUCCEEDED` (avec Xcode 27 `-quiet` n'affiche pas la bannière : vérifier le code de sortie 0).
- [ ] **Step 2: Verify** `swift test` sur chaque package (`for p in Packages/*; do swift test --package-path $p || break; done`), `make lint` → 0, `make build-release` → succès.
- [ ] **Step 3: Commit** `feat(app): wire the Stats tab`

Vérifications laissées à Mathéo sur l'iPhone : les cinq vues sur ses vraies données, la courbe ACWR sur 90 jours, ses courses anciennes après la relecture d'un an, la fiche d'exercice ouverte depuis Records.
