# Phases de sommeil et écran Nuit — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** montrer chaque nuit en détail (endormissement, réveil, hypnogramme, minutes par phase, réveils) et découper le sommeil par phase dans Stats > Biométrie, sans toucher au score.

**Architecture :** un `NightSleepBuilder` pur (PulseRecoveryEngine) reconstitue une nuit depuis les `SleepInterval` du cache, avec les mêmes règles de rattachement que `NightAggregator`. L'agrégateur en tire quatre nouveaux totaux (léger, paradoxal, sans phase, éveil) qui suivent `DailyRecovery` jusqu'au magasin local (schéma V7). Une nouvelle cible `NightFeature` affiche l'écran Nuit, ouvert depuis Aujourd'hui et Stats.

**Tech stack :** Swift 6.2, SwiftUI, Swift Charts, SwiftData, Swift Testing, iOS 26.

**Spec :** `docs/superpowers/specs/2026-11-24-pulse-sommeil-phases-design.md`

## Global Constraints

- iOS 26 minimum ; `swiftLanguageMode(.v6)` sur chaque cible ; `swiftlint lint --strict` passe.
- Textes en français via `String(localized: "…", bundle: .module)` ; chaque cible avec ressources a un `Resources/Localizable.xcstrings`, `sourceLanguage` `fr`.
- **Le score ne change pas :** `SleepScorer`, `RecoveryCalculator` et le calcul de `asleepMinutes` / `deepMinutes` restent tels quels.
- `StoredDailyRecovery` (synchronisé iCloud) ne change pas. Les phases ne vivent qu'en local, dans `StoredRecoveryReading`.
- Le papier est le thème clair, forcé dans l'app. Toute couleur qui porte une information atteint 3:1 contre `PulsePalette.backgroundLightRGBA` et `PulsePalette.surfaceLightRGBA` (WCAG 1.4.11).
- Une phase ne se reconnaît jamais à sa seule couleur : son nom est toujours écrit (axe, légende, ligne).
- Vocabulaire neutre, jamais médical.
- **Aucune compilation possible sur le poste Windows.** Chaque commande `swift test` / `xcodebuild` / `make` de ce plan se lance sur le Mac. Une tâche n'est finie que lorsque ses tests passent sur le Mac.

## Review Focus

1. **Synchronisation tardive après le figeage.** Le cache change après midi, et le total d'une nuit passée ne correspond plus à la lecture enregistrée. Le rattrapage doit alors laisser la lecture sans phases plutôt qu'écrire des phases qui ne s'additionnent pas au total (test en tâche 4).
2. **Nuit sans phases** (Fitbit qui n'envoie que « endormi »). Aucune phase n'est inventée, et l'écran Nuit affiche la phrase de la spec §6.3.5 (tests en tâches 2, 6 et 7).
3. **Arrondis.** Avec des intervalles à la demi-minute, profond + léger + paradoxal + sans phase doit égaler exactement `asleepMinutes`, et le profond égaler le `deepMinutes` du score (test en tâche 1).
4. **Grain mixte sur 1 an.** Une semaine mêle des nuits avec et sans phases. Les tranches s'additionnent quand même à la hauteur de la barre (test en tâche 9).
5. **Navigation aux bouts et nuits vides.** ‹ › sautent les nuits sans sommeil et se désactivent aux extrémités. Un cache vide donne un écran vide qui le dit, sans plantage (tests en tâche 7).

---

### Task 1 : reconstituer une nuit (`NightSleepBuilder`)

**Files :**
- Create : `Packages/PulseDomain/Sources/PulseDomain/Health/NightSleep.swift`
- Create : `Packages/PulseRecoveryEngine/Sources/PulseRecoveryEngine/Aggregation/NightWindow.swift`
- Create : `Packages/PulseRecoveryEngine/Sources/PulseRecoveryEngine/Aggregation/NightSleepBuilder.swift`
- Modify : `Packages/PulseRecoveryEngine/Sources/PulseRecoveryEngine/Aggregation/NightAggregator.swift` (fenêtre et filtre déplacés dans `NightWindow`)
- Test : `Packages/PulseRecoveryEngine/Tests/PulseRecoveryEngineTests/NightSleepBuilderTests.swift`

**Interfaces :**
- Produces (PulseDomain, tous `public`, `Sendable, Equatable, Codable`) :
  - `struct SleepSegment { var start: Date; var end: Date; var stage: SleepStage }`
  - `struct SleepBlock { var start: Date; var end: Date; var asleepMinutes: Int }`
  - `struct NightSleep { var day: Date; var fellAsleep: Date; var wokeUp: Date; var segments: [SleepSegment]; var otherBlocks: [SleepBlock]; var asleepMinutes: Int; var deepMinutes: Int; var coreMinutes: Int; var remMinutes: Int; var unspecifiedMinutes: Int; var awakeMinutes: Int; var awakenings: Int; var hasStages: Bool }`, avec un init memberwise public.
- Produces (PulseRecoveryEngine) :
  - `enum NightWindow` (interne) : `static let startHours = -6`, `static let endHours = 12`, `static func retainedAsleep(for day: Date, in sleep: [SleepInterval], calendar: Calendar) -> [SleepInterval]` (exactement le filtre actuel de `NightAggregator.retainedIntervals`).
  - `public struct NightSleepBuilder: Sendable` : `public static let minimumAwakening: TimeInterval = 120`, `public static let blockGap: TimeInterval = 3600`, `public init(calendar: Calendar)`, `public func night(for day: Date, sleep: [SleepInterval]) -> NightSleep?`.

- [ ] **Step 1 : écrire les tests qui échouent.** Reprendre les aides de `NightAggregatorTests` (`TestCalendar.paris`, `TestCalendar.date`, `day = TestCalendar.day(2026, 11, 20)`). Les nuits sont celles du 19 au 20 novembre.

```swift
@Test func typicalNight()                       // fixture typicalSleep de NightAggregatorTests
// fellAsleep 23:10, wokeUp 06:50, asleep 450, deep 90, rem 60, core 300, unspecified 0, awake 10,
// awakenings 1, segments.count 5, hasStages true, otherBlocks == []
@Test func overlappingSourcesResolveByPriority()
// core 23:00–07:00 + deep 01:00–02:00 + asleepUnspecified 22:30–07:00
// asleep 510, deep 60, core 420, unspecified 30 ; segments.map(\.stage) == [.asleepUnspecified, .core, .deep, .core]
@Test func awakeningsShorterThanTwoMinutesAreNotCounted()
// core 23:00–03:00, awake 03:00–03:01, core 03:01–07:00 → awakenings 0, awakeMinutes 1
@Test func gapWithoutSamplesIsNeitherAwakeNorAwakening()
// core 23:00–02:00, core 02:20–07:00 → awakeMinutes 0, awakenings 0, segments.count 2, asleep 460
@Test func eveningNapIsAnOtherBlock()
// core 18:05–18:30 (veille) + core 23:00–07:00 → fellAsleep 23:00,
// otherBlocks == [SleepBlock(start: 18:05, end: 18:30, asleepMinutes: 25)], asleep 505, core 505
@Test func awakeOutsideTheMainBlockIsDropped()
// awake 22:00–23:00 + core 23:00–07:00 + awake 07:00–07:30 → awakeMinutes 0, segments.count 1
@Test func unspecifiedOnlyHasNoStages()
// asleepUnspecified 23:00–07:00 → hasStages false, unspecified 480, deep 0, core 0, rem 0
@Test func noAsleepIntervalGivesNil()           // seulement awake et inBed → nil
@Test func stageMinutesAddUpToAsleepDespiteRounding()
// deep 01:00:30–01:30:00, rem 01:30:00–02:00:30, core 02:00:30–02:30:00
// asleep 90, deep 30 ; deep + core + rem + unspecified == asleep
@Test func dstNightUsesCalendar()               // core 24 oct 23:00 → 25 oct 07:00 → asleep 540
```

- [ ] **Step 2 : lancer et vérifier l'échec.** `swift test --package-path Packages/PulseRecoveryEngine --filter NightSleepBuilderTests` → échec de compilation (`NightSleepBuilder` inconnu).

- [ ] **Step 3 : implémenter.** Ajouter les types de domaine et `NightWindow`. Faire appeler `NightWindow` par `NightAggregator`, en gardant `windowStartHours` / `windowEndHours` comme alias de `NightWindow.startHours` / `.endHours`. Puis écrire `NightSleepBuilder.night(for:sleep:)` :

```
asleep = NightWindow.retainedAsleep(day); vide → nil
span = [min(asleep.start), max(asleep.end)]
awake = intervalles .awake (end > start), coupés à span, non vides
bornes = débuts et fins triés et dédoublonnés de asleep + awake
pour chaque tranche [a, b) : phase = la plus prioritaire des intervalles qui la couvrent
  (start <= a && end >= b) ; priorité deep 5 > rem 4 > core 3 > asleepUnspecified 2 > awake 1 ;
  aucune → trou sans donnée (pas de segment)
fusionner les tranches contiguës (fin == début) de même phase → segments
blocs : nouveau bloc quand l'écart entre la fin d'un segment endormi et le début du suivant > blockGap ;
  un bloc va du premier au dernier segment endormi ; l'éveil hors de tout bloc est jeté
principal = le bloc qui a le plus de secondes endormies (égalité → le plus tardif)
secondes par phase endormie sur tous les blocs ; asleepMinutes = round(total / 60) ;
  deep, rem, unspecified = round(secondes / 60) ;
  core = asleepMinutes − deep − rem − unspecified (≥ 0) ; si aucune seconde de core, le reste va à
  unspecified, puis à rem ; deep n'est jamais ajusté
awakeMinutes = round(secondes d'éveil du bloc principal / 60)
awakenings = segments d'éveil du bloc principal d'une durée >= minimumAwakening
hasStages = au moins une tranche en core, deep ou rem
segments renvoyés = ceux du bloc principal ; otherBlocks = les autres, chronologiques
```

  `round` est `Double.rounded()`, comme `NightAggregator.minutes`.

- [ ] **Step 4 : lancer les tests.** `swift test --package-path Packages/PulseRecoveryEngine` → tout passe, `NightAggregatorTests` compris (comportement inchangé).

- [ ] **Step 5 : commit.**
```bash
git add Packages/PulseDomain Packages/PulseRecoveryEngine
git commit -m "feat(engine): rebuild a night's sleep stages with the aggregator's window rules"
```

### Task 2 : les totaux par phase dans `SleepSummary`

**Files :**
- Modify : `Packages/PulseDomain/Sources/PulseDomain/Health/NightSample.swift`
- Modify : `Packages/PulseRecoveryEngine/Sources/PulseRecoveryEngine/Aggregation/NightAggregator.swift` (`summary`)
- Test : `Packages/PulseRecoveryEngine/Tests/PulseRecoveryEngineTests/NightAggregatorTests.swift`

**Interfaces :**
- Consumes : `NightSleepBuilder` (tâche 1).
- Produces : `SleepSummary` gagne `public var coreMinutes: Int?`, `remMinutes: Int?`, `unspecifiedMinutes: Int?`, `awakeMinutes: Int?`. L'init devient `init(asleepMinutes: Int, deepMinutes: Int?, coreMinutes: Int? = nil, remMinutes: Int? = nil, unspecifiedMinutes: Int? = nil, awakeMinutes: Int? = nil)`. Les quatre valent `nil` exactement quand `deepMinutes` est `nil` (aucune phase).

- [ ] **Step 1 : mettre à jour les tests.**
  - `typicalNight` attend `.init(asleepMinutes: 450, deepMinutes: 90, coreMinutes: 300, remMinutes: 60, unspecifiedMinutes: 0, awakeMinutes: 10)`.
  - `overlappingSourcesAreMergedNotSummed` attend la même chose.
  - `unspecifiedSleepHasNoDeepMinutes` ne change pas.
  - Ajouter `@Test func builderAgreesWithAggregatorOnTotals()` : pour chaque nuit des fixtures des deux suites (typique, chevauchements, sieste, arrondis, sans phase, changement d'heure), `aggregator.night(...).sleep?.asleepMinutes == builder.night(...)?.asleepMinutes`, et de même pour `deepMinutes` quand `hasStages`.

- [ ] **Step 2 : lancer et vérifier l'échec.** `swift test --package-path Packages/PulseRecoveryEngine --filter NightAggregatorTests` → `typicalNight` échoue (les champs restent nil).

- [ ] **Step 3 : implémenter.**
  - `summary` garde son calcul de `asleepMinutes` et `deepMinutes`.
  - Quand il y a des phases, il prend `coreMinutes`, `remMinutes`, `unspecifiedMinutes` et `awakeMinutes` de `NightSleepBuilder(calendar:).night(for:sleep:)`.

- [ ] **Step 4 : lancer tous les paquets.**
  - Lancer `swift test` sur PulseRecoveryEngine et PulseFeatures.
  - Corriger chaque test qui compare un `SleepSummary` ou un `NightSample` complet construit depuis des intervalles avec phases. Les repérer avec `grep -rn "SleepSummary(asleepMinutes" Packages/*/Tests`.
  - Les fixtures JSON se décodent sans changement : les champs optionnels absents donnent `nil`.

- [ ] **Step 5 : commit.**
```bash
git commit -am "feat(engine): carry light, REM, unstaged and awake minutes in the night summary"
```

### Task 3 : enregistrer les phases (schéma V7, export)

**Files :**
- Modify : `Packages/PulseDomain/Sources/PulseDomain/Recovery/DailyRecovery.swift`
- Modify : `Packages/PulseFeatures/Sources/PulseServices/Score/DailyRecovery+Result.swift`
- Modify : `Packages/PulsePersistence/Sources/PulsePersistence/Models/StoredRecoveryReading.swift`
- Modify : `Packages/PulsePersistence/Sources/PulsePersistence/Schema/PulseSchemaV4.swift`, `PulseSchemaV5.swift`, `PulseSchemaV6.swift` (copie figée)
- Create : `Packages/PulsePersistence/Sources/PulsePersistence/Schema/PulseSchemaV7.swift`
- Modify : `PulseMigrationPlan.swift`, `PersistenceStack.swift:59`
- Modify : `Packages/PulsePersistence/Sources/PulsePersistence/Export/CSVColumns+Tracking.swift`
- Create : `Packages/PulsePersistence/Tests/PulsePersistenceTests/Fixtures/schema-v7.txt`
- Test : `SchemaFingerprintTests.swift`, `RecoveryRepositoryTests.swift`, `CSVExportTests.swift`, `PersistenceStackTests.swift`, `OtherMappingTests.swift`

**Interfaces :**
- Consumes : `SleepSummary` (tâche 2).
- Produces :
  - `DailyRecovery` gagne `coreMinutes`, `remMinutes`, `unspecifiedMinutes`, `awakeMinutes` (`Int?`), placés après `deepMinutes`, avec des paramètres d'init par défaut à `nil` au même endroit.
  - `StoredRecoveryReading` gagne les mêmes attributs.
  - Les colonnes CSV `core_minutes`, `rem_minutes`, `unspecified_minutes` et `awake_minutes` suivent `deep_minutes`.

- [ ] **Step 1 : écrire les tests qui échouent.**
  - `v7SchemaMatchesItsFingerprint()` (fixture `schema-v7`).
  - `v7OnlyAddsTheFourSleepStageFields()`. Différence entre V7 et V6 :
    ```swift
    #expect(v6.subtracting(v7).isEmpty)
    #expect(Set(added.compactMap { $0.split(separator: ":").first.map(String.init) })
        == ["StoredRecoveryReading.awakeMinutes", "StoredRecoveryReading.coreMinutes",
            "StoredRecoveryReading.remMinutes", "StoredRecoveryReading.unspecifiedMinutes"])
    ```
  - Laisser `v6SchemaMatchesItsFingerprint` intact : il prouve que la copie figée est fidèle.
  - `PersistenceStackTests` attend `PulseSchemaV7.versionIdentifier == Schema.Version(7, 0, 0)`.
  - `OtherMappingTests` compte `PulseSchemaV7.models.count == 25`.
  - Dans `RecoveryRepositoryTests`, ajouter `@Test func saveKeepsSleepStagesInTheLocalReading()` : enregistrer un `DailyRecovery` avec core 300, rem 60, unspecified 0 et awake 10, puis le relire avec `dailyRecoveries` et retrouver les quatre valeurs.
  - Dans `CSVExportTests`, l'en-tête de `dailyRecoveries` contient les quatre colonnes juste après `deep_minutes`.

- [ ] **Step 2 : lancer et vérifier l'échec.** `swift test --package-path Packages/PulsePersistence` → échec de compilation (`PulseSchemaV7` inconnu).

- [ ] **Step 3 : implémenter.**
  - Ajouter `extension PulseSchemaV6 { @Model public final class StoredRecoveryReading { … } }`. C'est la copie des neuf attributs actuels, avec un `public init() {}` et le commentaire « Copie figée de `StoredRecoveryReading` en V6 : ne pas modifier. ».
  - Dans `PulseSchemaV4.localModels`, `PulseSchemaV5.localModels` et dans la liste de `PulseSchemaV6.models` (rendue explicite : `PersistenceStack.syncedModels` + les huit modèles locaux), remplacer `StoredRecoveryReading.self` par `PulseSchemaV6.StoredRecoveryReading.self`.
  - Créer `PulseSchemaV7` (version 7.0.0, `models = PersistenceStack.syncedModels + PersistenceStack.localModels`), avec un commentaire d'en-tête dans le style des précédents.
  - Ajouter l'étape `.lightweight(fromVersion: PulseSchemaV6.self, toVersion: PulseSchemaV7.self)`.
  - Faire passer `PersistenceStack.swift:59` sur `PulseSchemaV7`.
  - Ajouter les quatre attributs à `StoredRecoveryReading`, ainsi qu'à `apply`, `fill` et `isEmpty`. Mettre à jour le commentaire « six valeurs » en « dix valeurs ».
  - `DailyRecovery+Result` passe `night.sleep?.coreMinutes` et les trois autres.
  - Ajouter les colonnes CSV. L'export JSON encode `DailyRecovery` tel quel (`Codable`) : les quatre champs y entrent sans autre changement. `StoreWiper` efface déjà `StoredRecoveryReading`.

- [ ] **Step 4 : générer la fixture et lancer les tests.**
  - `PULSE_WRITE_SCHEMA_FIXTURES=1 swift test --package-path Packages/PulsePersistence --filter v7SchemaMatchesItsFingerprint`
  - `diff Packages/PulsePersistence/Tests/PulsePersistenceTests/Fixtures/schema-v6.txt Packages/PulsePersistence/Tests/PulsePersistenceTests/Fixtures/schema-v7.txt` doit montrer exactement quatre lignes ajoutées.
  - Puis `swift test --package-path Packages/PulsePersistence` doit tout passer, `MigrationTests` compris.

- [ ] **Step 5 : commit.**
```bash
git add Packages/PulseDomain Packages/PulsePersistence Packages/PulseFeatures/Sources/PulseServices/Score
git commit -m "feat(persistence): keep each night's stage minutes in the local reading (schema V7), export them"
```

### Task 4 : rattraper les nuits déjà enregistrées

**Files :**
- Modify : `Packages/PulseDomain/Sources/PulseDomain/Repositories/RecoveryRepository.swift`
- Modify : `Packages/PulsePersistence/Sources/PulsePersistence/Repositories/SwiftDataRecoveryRepository.swift`
- Modify : `Packages/PulseFeatures/Sources/PulseServices/Doubles/InMemoryRepositories.swift`
- Modify : les trois doubles de test, `Tests/OnboardingFeatureTests/Support/CountingDoubles.swift`, `Tests/PulseServicesTests/Support/CountingRecoveryRepository.swift` et `Tests/TodayFeatureTests/Support/ConcurrencyDoubles.swift`, qui transmettent à `inner`. Vérifier avec `grep -rn "RecoveryRepository {" Packages Pulse` qu'il n'y en a pas d'autre.
- Modify : `Packages/PulseFeatures/Sources/PulseServices/Refresh/DayRefresher.swift` (`pass`)
- Test : `RecoveryRepositoryTests.swift`, `PulseServicesTests/DayRefresherTests.swift`

**Interfaces :**
- Consumes : `NightSample.sleep` (tâche 2), les champs de `DailyRecovery` (tâche 3).
- Produces : une nouvelle exigence du protocole, `func backfillSleepStages(_ nights: [NightSample]) async throws`.
  - Pour chaque nuit dont `sleep?.coreMinutes != nil`, la lecture locale du même jour reçoit les quatre valeurs, à condition qu'elle existe, que son `coreMinutes` soit `nil` et que son `asleepMinutes == night.sleep?.asleepMinutes`.
  - Le reste n'est pas touché : la ligne synchronisée, `updatedAt` du score et les autres champs. Un seul `save()`.
  - Le double en mémoire applique la même règle à son `DailyRecovery`.

- [ ] **Step 1 : écrire les tests qui échouent.**
  - `backfillFillsAReadingWithoutStagesWhenTotalsMatch`
  - `backfillSkipsAReadingWhoseTotalNoLongerMatches` : la lecture enregistrée a 430 et le cache 450 → `coreMinutes` reste `nil`.
  - `backfillNeverOverwritesStoredStages`
  - `backfillLeavesTheSyncedRowUntouched` : `updatedAt` de la ligne synchronisée inchangé.
  - Dans `DayRefresherTests` : `refreshBackfillsStagesOfPastNights`, avec une lecture d'hier sans phases et un cache avec phases → après `refresh`, `dailyRecoveries` donne les phases d'hier, et le score d'hier est inchangé.

- [ ] **Step 2 : lancer et vérifier l'échec.** `swift test --package-path Packages/PulsePersistence --filter backfill` → échec de compilation.

- [ ] **Step 3 : implémenter.**
  - Écrire la méthode dans les cinq conformances.
  - Dans `DayRefresher.pass`, juste après `nightHistory.refresh`, ajouter `try? await recovery.backfillSleepStages(history.nights)`. Un échec ne retient pas le passage, comme `relocate()`.

- [ ] **Step 4 : lancer les tests.** `swift test` sur PulsePersistence et PulseFeatures → tout passe.

- [ ] **Step 5 : commit.**
```bash
git commit -am "feat(refresh): backfill stage minutes of cached nights whose stored total still matches"
```

### Task 5 : couleurs et noms des phases (design system)

**Files :**
- Create : `Packages/PulseDesignSystem/Sources/PulseDesignSystem/Presentation/SleepStage+Presentation.swift`
- Modify : `Packages/PulseDesignSystem/Sources/PulseDesignSystem/Resources/Localizable.xcstrings` (rempli par Xcode à la compilation, rien à écrire à la main)
- Test : `Packages/PulseDesignSystem/Tests/PulseDesignSystemTests/PaletteTests.swift` (aides de `ContrastSupport.swift`)

**Interfaces :**
- Produces :
  - `extension SleepStage { public var displayName: String; public var colorRGBA: PulseRGBA; public var color: Color }`.
  - `public static let SleepStage.chartOrder: [SleepStage] = [.awake, .rem, .core, .deep]` : rangées de l'hypnogramme, de haut en bas.
  - Noms : `.deep` « Profond », `.core` « Léger », `.rem` « Paradoxal », `.awake` « Éveil », `.asleepUnspecified` « Endormi », `.inBed` « Au lit ».
  - Couleurs de départ (thème clair) : deep `0x1E3A8A`, core `0x2563EB`, rem `0x7C3AED`, awake `0xC2410C`, asleepUnspecified `0x57554F`, inBed `0x68655F`. Le constructeur peut les ajuster si le test l'exige.

- [ ] **Step 1 : écrire le test qui échoue.** `@Test func sleepStageColorsReachThreeToOne()` : pour chaque phase et chaque papier (`backgroundLightRGBA`, `surfaceLightRGBA`), le contraste vaut au moins 3. `@Test func sleepStageNamesAreDistinct()` : six noms différents.

- [ ] **Step 2 : lancer et vérifier l'échec.** `swift test --package-path Packages/PulseDesignSystem --filter sleepStage` → échec de compilation.

- [ ] **Step 3 : implémenter** l'extension.

- [ ] **Step 4 : lancer les tests.** `swift test --package-path Packages/PulseDesignSystem` → tout passe.

- [ ] **Step 5 : commit.**
```bash
git commit -am "feat(design): sleep stage names and colors that reach 3:1 on paper"
```

### Task 6 : le service des nuits (`NightDetailService`)

**Files :**
- Create : `Packages/PulseFeatures/Sources/PulseServices/Health/NightDetailService.swift`
- Test : `Packages/PulseFeatures/Tests/PulseServicesTests/NightDetailServiceTests.swift`

**Interfaces :**
- Consumes : `HealthSampleCache.samples(kind: .sleep, from:to:)`, `CachedSampleMapping.sleepIntervals`, `NightSleepBuilder`, `NightHistory.historyDays` (60).
- Produces :
  - `public struct StageAverages: Sendable, Equatable { public var deep, core, rem, awake: Double; public var nights: Int }`
  - `public struct NightDetail: Sendable, Equatable, Identifiable { public var night: NightSleep; public var averages: StageAverages?; public var id: Date { night.day } }`
  - `public struct NightDetailService: Sendable { public init(cache: any HealthSampleCache, calendar: Calendar, now: @escaping @Sendable () -> Date); public func nights() async -> [NightDetail] }`
  - Le service rend les nuits **avec sommeil**, dont le jour de réveil tombe dans les 60 derniers jours, dans l'ordre chronologique.
  - `averages` porte sur au plus les 14 nuits **avec phases** qui précèdent. Il vaut `nil` quand il n'y en a aucune, et `nil` aussi quand la nuit elle-même n'a pas de phases.
  - Une lecture du cache qui échoue rend `[]`.

- [ ] **Step 1 : écrire les tests qui échouent** (avec `InMemoryHealthSampleCache`).
  - `nightsSkipDaysWithoutSleep`
  - `nightsAreChronological`
  - `averagesUseUpToFourteenPreviousStagedNights` : 16 nuits de 90 min de profond, puis une nuit de 60 → la dernière a `averages?.deep == 90` et `averages?.nights == 14`.
  - `firstNightHasNoAverages`
  - `unstagedNightHasNoAverages`
  - `emptyCacheGivesNoNights`

- [ ] **Step 2 : lancer et vérifier l'échec.** `swift test --package-path Packages/PulseFeatures --filter NightDetailServiceTests` → échec de compilation.

- [ ] **Step 3 : implémenter.**
  - Lire le cache de `today − 62 jours` à demain.
  - Construire une nuit par jour de réveil, pour les 60 jours.
  - Les moyennes sont des moyennes arithmétiques des minutes.

- [ ] **Step 4 : lancer les tests.** → passent.

- [ ] **Step 5 : commit.**
```bash
git commit -am "feat(services): list the cached nights with their stage averages"
```

### Task 7 : modèle et textes de l'écran Nuit (cible `NightFeature`)

**Files :**
- Modify : `Packages/PulseFeatures/Package.swift`
  - Ajouter le produit et la cible `NightFeature` : dépendances `["PulseServices", designSystem, domain]`, `resources: [.process("Resources")]`, `swiftLanguageMode(.v6)`.
  - Ajouter la cible de test `NightFeatureTests` : `["NightFeature", "PulseServices", domain]`.
  - Ajouter `"NightFeature"` aux dépendances de `TodayFeature` et de `StatsFeature`.
- Create : `Packages/PulseFeatures/Sources/NightFeature/Resources/Localizable.xcstrings`, avec `{"sourceLanguage":"fr","strings":{},"version":"1.0"}`
- Create : `Sources/NightFeature/NightModel.swift`, `Sources/NightFeature/NightText.swift`, `Sources/NightFeature/NightIdentifiers.swift`
- Test : `Packages/PulseFeatures/Tests/NightFeatureTests/NightModelTests.swift`, `NightTextTests.swift`

**Interfaces :**
- Consumes : `NightDetailService`, `NightDetail` (tâche 6), `SleepStage.displayName` (tâche 5).
- Produces :
  - `@MainActor @Observable public final class NightModel`, avec :
    - `public init(service: NightDetailService, initialDay: Date?, calendar: Calendar)`
    - `public func load() async`
    - `private(set) var details: [NightDetail]`, `private(set) var index: Int?`, `var current: NightDetail?`, `private(set) var hasLoaded: Bool`
    - `var canGoBack: Bool`, `var canGoForward: Bool`, `func goBack()`, `func goForward()`
  - À l'ouverture, `index` pointe la nuit dont `day == startOfDay(initialDay)`, sinon la plus récente.
  - `enum NightText` (interne), avec :
    - `title(_ night: NightSleep, calendar:) -> String` : « Nuit du 19 au 20 nov. »
    - `times(_:calendar:) -> String` : « Endormi à 23:10 · Réveillé à 06:50 · 1 réveil »
    - `share(minutes:of:) -> String` : « 20 % »
    - `delta(minutes:average:) -> String?` : « +12 min » ou « −5 min » ; `nil` si l'écart arrondi vaut 0 ou s'il n'y a pas de moyenne
    - `otherBlock(_ block: SleepBlock, calendar:) -> String` : « Aussi compté : 18:05–18:30, 25 min »
    - `noStagesNote` : la phrase exacte de la spec §6.3.5
    - `spokenSummary(_ night: NightSleep, calendar:) -> String` : « Endormi à 23 h 10, réveillé à 6 h 50, 1 réveil, 1 heure 30 de profond… », en réutilisant `PulseSpoken` et `PulseFormat`
    - `breakdownRows(_ detail: NightDetail) -> [BreakdownRow]`, avec `struct BreakdownRow: Equatable { stage: SleepStage; minutes: Int; share: Double; delta: String? }`. Ordre : Profond, Léger, Paradoxal, Éveil, puis Endormi sans phase seulement si `unspecifiedMinutes > 0`. La part est calculée sur la somme des lignes. Le résultat est vide si `!hasStages`.

- [ ] **Step 1 : écrire les tests qui échouent.**
  - `opensOnTheRequestedNight`
  - `opensOnTheLatestNightWhenTheDayHasNone`
  - `backAndForwardStopAtTheEnds` : `canGoBack == false` sur la première nuit, et `goBack()` ne fait rien.
  - `emptyServiceLeavesNoCurrentNight` : `hasLoaded == true` et `current == nil`.
  - `titleSpansTwoMonths` : la nuit du 31 oct. au 1er nov. donne « Nuit du 31 oct. au 1 nov. »
  - `timesSayOneOrSeveralAwakenings` : 1 donne « 1 réveil », 2 donne « 2 réveils », 0 donne « aucun réveil ».
  - `breakdownSharesAddUpToOne`
  - `breakdownIsEmptyWithoutStages`
  - `deltaIsHiddenWhenRoundedToZero`

- [ ] **Step 2 : lancer et vérifier l'échec.** `swift test --package-path Packages/PulseFeatures --filter NightFeatureTests` → échec de compilation.

- [ ] **Step 3 : implémenter** le modèle et les textes.

- [ ] **Step 4 : lancer les tests.** → passent.

- [ ] **Step 5 : commit.**
```bash
git commit -am "feat(night): night model and texts with navigation across cached nights"
```

### Task 8 : vues de l'écran Nuit

**Files :**
- Create : `Sources/NightFeature/Views/NightScreen.swift`, `HypnogramChart.swift`, `StageBreakdownList.swift`, `NightPreviewSupport.swift`
- Create : `Sources/NightFeature/NightChartDescriptor.swift`
- Test : `Tests/NightFeatureTests/NightChartDescriptorTests.swift`

**Interfaces :**
- Consumes : `NightModel`, `NightText` (tâche 7), `SleepStage.color` et `chartOrder` (tâche 5), `PulseChartDescriptor` (PulseDesignSystem).
- Produces :
  - `public struct NightScreen: View { public init(model: NightModel) }`. Il charge à l'apparition (`.task { if !model.hasLoaded { await model.load() } }`).
  - `enum NightChartDescriptor { static func hypnogram(_ night: NightSleep, calendar: Calendar) -> PulseChartDescriptor }` : une série par phase présente, un point par segment, de valeur la durée en minutes au début du segment.

- [ ] **Step 1 : écrire le test qui échoue.** `hypnogramDescriptorHasOneSeriesPerPresentStage` : la nuit typique donne quatre séries, Profond, Léger, Paradoxal et Éveil, dont trois points pour Léger. `unstagedDescriptorHasAsleepAndAwake`.

- [ ] **Step 2 : lancer et vérifier l'échec.**

- [ ] **Step 3 : implémenter les vues.** Suivre la disposition de la spec §6.3, dans le style de `StatsChartCard` et `ObsidianCard` :
  - le titre (`.isHeader`) et les boutons ‹ ›, dont le libellé VoiceOver nomme la nuit visée ;
  - la durée, en `PulseFont.value(.largeTitle)` ;
  - `NightText.times` ;
  - l'hypnogramme (`RectangleMark` de `segment.start` à `segment.end`, `y: .value(…, stage.displayName)`, domaine Y = `chartOrder` ou `[.awake, .asleepUnspecified]` sans phases, `.foregroundStyle(stage.color)`), puis `.accessibilityLabel(NightText.spokenSummary)` et `.accessibilityChartDescriptor` ;
  - les `otherBlocks` ;
  - `StageBreakdownList` (nom, durée, part, barre, écart), ou `noStagesNote` ;
  - un état vide : « Aucune nuit enregistrée ces 60 derniers jours. »
  - Hauteur des graphiques en `@ScaledMetric`.
  - Ajouter les `#Preview` (nuit typique, sans phases, sieste, taille de texte accessibility3).

- [ ] **Step 4 : lancer les tests et ouvrir les aperçus.** `swift test --package-path Packages/PulseFeatures --filter NightFeatureTests` passe. Dans Xcode, les quatre aperçus s'affichent sans troncature.

- [ ] **Step 5 : commit.**
```bash
git commit -am "feat(night): night screen with hypnogram, stage breakdown and VoiceOver summary"
```

### Task 9 : Stats > Biométrie par phase

**Files :**
- Modify : `Packages/PulseFeatures/Sources/PulseServices/Stats/BiometryStats.swift`
- Modify : `Sources/StatsFeature/Views/BiometrySection.swift`, `StatsChartDescriptors.swift`, `StatsText+Spoken.swift`, `StatsEnvironment.swift`, `Views/StatsScreen.swift`, `Views/StatsPreviewSupport.swift`
- Modify : `Pulse/AppDependencies+Environments.swift` (`statsEnvironment`)
- Test : `Tests/PulseServicesTests/BiometryStatsTests.swift`, `Tests/StatsFeatureTests/StatsSpokenTests.swift`

**Interfaces :**
- Consumes : les champs de `DailyRecovery` (tâche 3), `SleepStage.color` (tâche 5), `NightScreen` / `NightModel` (tâches 7 et 8), `NightDetailService` (tâche 6).
- Produces :
  - `SleepPoint` gagne `coreMinutes`, `remMinutes`, `unspecifiedMinutes` (`Double?`) et `var hasStages: Bool { coreMinutes != nil }`. Les quatre parts (deep inclus) suivent la règle du grain mixte de la spec §6.5 : part moyenne sur les nuits du grain qui ont les phases, multipliée par la moyenne d'`asleepMinutes` de toutes ses nuits. `deepMinutes` garde l'ancienne règle quand aucune nuit du grain n'a de phases.
  - `BiometryStats` gagne `public var stageShares: StageShares?`, avec `public struct StageShares: Sendable, Equatable { deep, core, rem, unspecified: Double }`. Les parts portent sur les seules nuits à phases et valent `nil` sans elles.
  - `StatsEnvironment` gagne `public var nights: NightDetailService`, ajouté à la fin de l'init.

- [ ] **Step 1 : écrire les tests qui échouent.**
  - `sleepPointCarriesStagesWhenNightsHaveThem`
  - `mixedWeekScalesStageSharesToTheBarHeight` : sur 1 an, une semaine avec une nuit de 420 min sans phases et une nuit de 480 min avec profond 96, léger 288 et paradoxal 96 → hauteur 450, deep 90, core 270, rem 90, et la somme vaut 450.
  - `weekWithoutStagedNightsKeepsDeepOnly`
  - `stageSharesIgnoreUnstagedNights`
  - Dans `StatsSpokenTests` : `sleepPointSpokenListsStages` donne « 7 heures 30 minutes, dont 1 heure 30 de profond, 4 heures 30 de léger, 1 heure 30 de paradoxal ».

- [ ] **Step 2 : lancer et vérifier l'échec.**

- [ ] **Step 3 : implémenter.**
  - `SleepChartCard` empile, pour un point avec phases, Profond, Léger, Paradoxal puis Endormi (sans phase), chacun de sa couleur. Sinon il garde l'ancien découpage à l'encre.
  - La légende ne liste que les phases présentes sur la période.
  - Seule la barre entière est lue par VoiceOver, avec `sleepPointSpoken`.
  - La tuile « Sommeil moyen » affiche « profond 18 % · paradoxal 22 % · léger 60 % » quand `stageShares` existe.
  - Ajouter un bouton « Voir les nuits » au pied de la carte : `BiometrySection(…, onOpenNights: () -> Void)`.
  - `StatsScreen` tient un `@State var showsNights` et ajoute `.navigationDestination(isPresented:) { NightScreen(model: NightModel(service: model.environment.nights, initialDay: nil, calendar: …)) }`.
  - `StatsChartDescriptors.sleep` ajoute une série par phase présente.
  - Le câblage de l'app passe `NightDetailService(cache: healthCache, calendar: calendar, now: now)`.

- [ ] **Step 4 : lancer les tests.** `swift test --package-path Packages/PulseFeatures` passe, puis `make build-app` réussit.

- [ ] **Step 5 : commit.**
```bash
git commit -am "feat(stats): stack sleep bars by stage, stage shares tile, open the night screen"
```

### Task 10 : ouvrir l'écran Nuit depuis Aujourd'hui

**Files :**
- Modify : `Sources/TodayFeature/TodayEnvironment.swift` (`public var nights: NightDetailService`, ajouté à la fin de l'init)
- Modify : `Sources/TodayFeature/TodayModel.swift` (`var isShowingNight = false`, `var canOpenNight: Bool`)
- Modify : `Sources/TodayFeature/Views/TrendTilesView.swift`, `Views/TodayView.swift`, `Views/TodayPreviewSupport.swift`
- Modify : `Pulse/AppDependencies+Environments.swift` (`todayEnvironment`)
- Modify : chaque construction de `TodayEnvironment` dans les tests (`grep -rn "TodayEnvironment(" Packages Pulse`)
- Test : `Tests/TodayFeatureTests/TodayModelTests.swift`

**Interfaces :**
- Consumes : `NightScreen`, `NightModel`, `NightDetailService`.
- Produces :
  - `TrendTilesView(tiles:onOpenSleep:)`, avec `onOpenSleep: (() -> Void)?`.
  - La tuile `.sleep` devient un `Button` quand `onOpenSleep` n'est pas `nil`, avec `.accessibilityHint("Ouvre le détail des nuits")` et `accessibilityIdentifier(TodayIdentifiers.sleepTile)`.
  - `TodayModel.canOpenNight` est vrai si la tuile sommeil a au moins une valeur.

- [ ] **Step 1 : écrire les tests qui échouent.** `canOpenNightOnlyWithASleepValue` : faux avant la première lecture et avec 14 nuits sans sommeil, vrai avec au moins une nuit de sommeil.

- [ ] **Step 2 : lancer et vérifier l'échec.**

- [ ] **Step 3 : implémenter.**
  - `TodayView` passe `onOpenSleep: model.canOpenNight ? { model.isShowingNight = true } : nil`.
  - Il ajoute `.navigationDestination(isPresented: $model.isShowingNight) { NightScreen(model: NightModel(service: model.environment.nights, initialDay: model.environment.now(), calendar: model.environment.calendar)) }`.
  - Brancher le câblage de l'app.

- [ ] **Step 4 : vérification complète sur le Mac.**
  - `make test` : lint, tous les paquets, tests de l'app.
  - Dans le simulateur, lancer chaque scénario de santé (`goodNight`, `badNight`, `noData`).
  - Vérifier ces points :
    - la tuile Sommeil ouvre l'écran Nuit ;
    - ‹ › parcourent les nuits ;
    - Stats > Biométrie empile les phases sur 7 j, 30 j, 90 j et 1 an ;
    - « Voir les nuits » ouvre l'écran ;
    - VoiceOver lit le résumé de la nuit ;
    - la taille de texte accessibility3 ne tronque rien.

- [ ] **Step 5 : commit.**
```bash
git commit -am "feat(today): open the night screen from the sleep trend tile"
```
