# Pulse M4b — Séance en direct et récap : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mathéo fait ses séances PPL dans Pulse et quitte Hevy. Il a des charges proposées série par série, un clavier intégré, un chrono de repos visible dans l'app, sur l'écran verrouillé et dans la Dynamic Island avec une notification de fin, une séance qui survit à un arrêt forcé, un récap avec records et RPE global, et un accueil qui sait quand la séance est faite ou en cours.

**Architecture:** Le moteur gagne la politique de hausse et la proposition des charges série par série. `PulseServices` gagne le modèle de séance active (`LiveSession`, encodé dans `ActiveSessionSnapshot`), le planificateur qui le construit depuis une routine, et le service unique `ActiveSessionService`. Ce service enregistre chaque changement, tient le repos par sa date de fin, et pilote la notification et la Live Activity derrière deux protocoles du domaine. Une nouvelle cible `LiveSessionFeature` porte l'écran de séance, le clavier et le récap. Un nouveau package iOS `PulseLiveActivity` porte les attributs ActivityKit et les intentions −30 s / +30 s / Passer, partagés par l'app et `PulseWidgets`. L'app assemble le tout et présente la séance en plein écran.

**Tech Stack:** Swift 6.4 (mode de langage 6), SwiftUI, ActivityKit, AppIntents (`LiveActivityIntent`), WidgetKit, UserNotifications (Time Sensitive), SwiftData, Swift Testing, XCTest (test d'interface), SwiftPM, SwiftLint, Xcode 27.0.

**Spec:** `docs/superpowers/specs/2026-11-02-pulse-m4-programmes-seance-live-design.md` (la « spec M4 », partie M4b : §2, §3, §5, §6.2 (`lastSets`), §8.1, §14 à §18, §20, §21, §24). Elle complète `2026-10-31-pulse-v1-design.md` (§5.5, §5.6, §5.10, §10) et la spec M3. Référence visuelle : `maquette.html`, écrans `live`, `recap`, `ios-island`, `ios-verrouille`.

## Global Constraints

- Xcode **27.0**, Swift **6.4**, cible **iOS 26**, `swift-tools-version: 6.2`, `swiftSettings: [.swiftLanguageMode(.v6)]` sur chaque cible. Les packages du domaine, du moteur, du contenu, de la persistance, du design system et des features se testent sur macOS par `swift test`. Le nouveau package `PulseLiveActivity` est iOS seulement et n'est vérifié que par les builds de l'app.
- **Ne jamais lancer le simulateur** : interdits `xcodebuild test`, `test-without-building`, `make test`, `make test-app`, `simctl boot|install|launch`, et les outils d'appareil T3. Le test d'interface et `PulseTests` sont écrits et compilés ; Mathéo les lance.
- **Vérification de fin de tâche (VFT)**, avant chaque commit de tâche :
  - `swift test --package-path Packages/<chaque package touché>` vert ;
  - `swiftlint lint --strict` à 0 ;
  - puis, **hors bac à sable du shell**, `make build-app` et `make build-release`, chacun jugé sur le code de sortie 0. `make build-release` lance aussi `make check-versions` : les versions de `Pulse/Info.plist` et `PulseWidgets/Info.plist` restent identiques.
- SwiftLint strict, avertissements traités comme des erreurs : **≤ 400 lignes par fichier**, **≤ 50 lignes par corps de fonction**, lignes ≤ 140, imports triés, pas de `!` hors tests.
- `PulseFeatures` (toutes cibles) ne dépend jamais de `PulsePersistence`, `PulseHealth`, `SwiftData`, `HealthKit`, `ActivityKit`, `AppIntents` ni `WidgetKit`. ActivityKit et AppIntents ne vivent que dans `PulseLiveActivity`, `Pulse/` et `PulseWidgets/`. Chaque dépendance importée est déclarée dans le manifeste.
- Aucune logique ne lit `Date()`, `Date.now` ni `Calendar.current`, sauf les exceptions existantes de l'assemblage et l'affichage des minuteurs (`Text(timerInterval:)`, `TimelineView`). Le service de séance utilise l'horloge injectée. Tests en grégorien `Europe/Paris`, locale `fr_FR` (`TestClock`).
- Chaînes visibles en français, avec `String(localized: "…", bundle: .module)` dans un package. Le build ne remplit pas les catalogues des packages : on y ajoute ses clés soi-même.
- **Ce qui sort de l'app** (Live Activity, écran verrouillé, notification de repos) : titre de séance, nom d'exercice, charge et répétitions prévues, durées. Jamais de score détaillé, de VFC, de FC ni de sommeil (spec M4 §15.4).
- Tout `#Preview` qui utilise une aide `#if DEBUG` est lui-même sous `#if DEBUG`.
- Accessibilité :
  - étiquette VoiceOver sur chaque contrôle, et ligne de série lue en entier (« Série 2, proposé 70 kilos, 5 répétitions, non validée ») ;
  - Dynamic Type jusqu'à « Accessibilité XL » ;
  - cibles ≥ 56 pt dans l'écran de séance ;
  - « Réduire les animations » respecté.
- Projet à dossiers synchronisés. Le `pbxproj` n'est modifié qu'en tâche 13 (package `PulseLiveActivity` et produit `LiveSessionFeature`), à la main. Ailleurs : `git restore Pulse.xcodeproj/project.pbxproj` avant de commiter si Xcode l'a réécrit.
- **Checkout partagé avec Mathéo.**
  - Avant chaque commit : `git branch --show-current` doit afficher `m4b-seance-live`.
  - On ajoute par chemin explicite, jamais `git add -A` ni `git add .`.
  - Jamais `git stash`, `git reset` ni `git clean`.
  - On ne modifie jamais un commit qui n'est pas le sien.
  - Les fichiers déjà modifiés par Mathéo (`Pulse/Localizable.xcstrings`, le catalogue de `TodayFeature`) ne sont jamais indexés. Pour y ajouter ses propres clés : partir de `git show HEAD:<chemin>`, ajouter les clés, `git hash-object -w`, puis `git update-index --cacheinfo`, et reporter les mêmes clés dans le fichier de travail.
  - Pas de push sans l'accord de Mathéo.
- Commits `type(scope): description` en anglais, **sans** trailer Co-Authored-By ni mention de Claude.
- Exécution (choix de Mathéo) : chaque tâche par un sous-agent dans son propre sous-thread T3 (`delegate_task`), en TDD, avec une revue par tâche et une revue finale de toute la branche par Opus.

## Review Focus

1. **App tuée pendant un repos, puis rouverte après la fin du repos** : la reprise montre la bonne durée écoulée et aucun repos fantôme. La notification déjà partie n'est pas replanifiée, et la Live Activity périmée est fermée. Test en tâche 6 (`resumingAfterTheRestEndedShowsNoRest`).
2. **Deux sources d'action sur le repos au même moment** (bouton de la Live Activity écran verrouillé et bouton de l'app) : les changements passent l'un après l'autre et le résultat est cohérent. −30 s ne passe jamais avant maintenant. Test en tâche 6 (`concurrentRestControlsAreSerialised`).
3. **Échec d'écriture à « Enregistrer »** : la séance n'est pas perdue. Le snapshot reste, le récap affiche une erreur avec « Réessayer », et un second essai n'enregistre pas la séance deux fois. Test en tâche 7 (`aFailedSaveKeepsTheSnapshotAndRetriesOnce`).
4. **Exercice sans historique, puis une première série validée** : les séries suivantes reprennent ses valeurs, sauf celles déjà modifiées à la main. Une série validée ne change plus quand une autre change. Test en tâche 6 (`firstValidatedSetSeedsTheFollowingUneditedSets`).
5. **Lancer une séance alors qu'une autre est en cours** (accueil, onglet Séance, ou deux touches rapides) : jamais deux séances. On propose de reprendre celle qui existe. Test en tâche 6 (`startingWhileASessionExistsThrows`) et en tâche 8 (`doubleStartPresentsOnce`).

---

## Structure des fichiers créés ou modifiés

```
Packages/PulseDomain/Sources/PulseDomain/
  Training/Program.swift (repRange sûr)
  Repositories/WorkoutRepository.swift (doc lastSets), RestTimerNotifying.swift, SessionActivityControlling.swift (nouveaux)
Packages/PulseRecoveryEngine/Sources/PulseRecoveryEngine/
  Adjustments/VolumeReducer.swift (setTargets), Progression/ProgressionPolicy.swift, LoadProgression.swift, PlateRounding.swift
Packages/PulsePersistence/Sources/PulsePersistence/Repositories/SwiftDataWorkoutRepository.swift, SwiftDataPersonalRecordRepository.swift
Packages/PulseLiveActivity/                        (nouveau, iOS) Package.swift, Sources/PulseLiveActivity/{PulseSessionAttributes, RestControl, SessionIntents, SessionIntentBridge}.swift
Packages/PulseDesignSystem/Sources/PulseDesignSystem/Platform/PlatformModifiers.swift (haptiques), Tokens/PulsePalette.swift (noir de séance)
Packages/PulseFeatures/
  Package.swift (cible LiveSessionFeature et ses tests)
  Sources/PulseServices/LiveSession/  LiveSession, SessionLaunch, LiveSessionPlanner, ActiveSessionService(+Rest, +Finish), SessionRecap, LiveSessionText
  Sources/PulseServices/Doubles/InMemoryRepositories.swift (lastSets), Records/RecordsService.swift
  Sources/LiveSessionFeature/          LiveSessionEnvironment, LiveSessionCoordinator, LiveSessionModel, Keypad/, Views/, Recap/
  Sources/TodayFeature/                TodayModel(+Session), SessionCardState, Why/WhyChanges, Views (StartSessionSheet supprimé)
  Sources/TrainFeature/                TrainModel, Views/TrainView, TrainTiles, RoutineRow
  Sources/OnboardingFeature/OnboardingModel+Calibration.swift (try?)
  Sources/WidgetFeature/SessionActivityText.swift
Pulse/      AppDependencies.swift, Root/{AppRootModel, AppRootView, MainTabView}.swift, LiveActivity/{SessionActivityController, SessionIntentWiring}.swift,
            Notifications/{UserNotificationScheduler, NotificationRouter}.swift, Info.plist, Pulse.entitlements, Debug/UITestSeeder.swift
PulseWidgets/ PulseWidgetsBundle.swift, SessionLiveActivity.swift, SessionLiveActivityViews.swift
PulseUITests/ LiveSessionResumeUITests.swift
Packages/PulseFeatures/Sources/PulseServices/App/LaunchOptions.swift
Pulse.xcodeproj/project.pbxproj, xcshareddata/xcschemes/Pulse.xcscheme (tâche 13)
```

---

### Task 1 : Plages sûres et séries retirées avec leur fourchette

Suites de M4a, prérequis de la séance (spec M4 §8.1, ligne « fatigue modérée »).

**Files:**
- Modify: `Packages/PulseDomain/Sources/PulseDomain/Training/Program.swift` (`repRange(forSet:)`), `Packages/PulseRecoveryEngine/Sources/PulseRecoveryEngine/Adjustments/VolumeReducer.swift`
- Test: `Packages/PulseDomain/Tests/PulseDomainTests/M4TrainingTypesTests.swift`, `Packages/PulseRecoveryEngine/Tests/PulseRecoveryEngineTests/SessionAdjusterTests.swift` (ou le fichier existant des ajustements)

**Interfaces:**
- Produces :
  - `RoutineExercise.repRange(forSet:)` ne piège plus : une fourchette inversée (cible ou exercice) est rendue `min…max`.
  - `VolumeReducer` retire aussi l'entrée de `setTargets` pour chaque série retirée, **en commençant par la dernière**. `setTargets` garde ainsi exactement `sets` entrées, ou reste `nil`.

- [ ] **Step 1 : Écrire les tests qui échouent**

```swift
@Test func anInvertedRangeNeverTraps() {
    var exercise = RoutineExercise(order: 0, exercise: .content(id: "bench-press-barbell"), sets: 2, repsMin: 12, repsMax: 4,
                                   targetRPE: 8, restSeconds: 120)
    #expect(exercise.repRange(forSet: 0) == 4...12)
    exercise.setTargets = [SetTarget(repsMin: 6, repsMax: 4), SetTarget(repsMin: 10, repsMax: 12)]
    #expect(exercise.repRange(forSet: 0) == 4...6)
}

@Test func fatigueRemovesTheLastPerSetTargets() {
    // Push : bench 3 séries [10–12, 4–6, 4–6], pec deck 3 séries sans setTargets, 4 autres exercices à 3 séries (18 séries).
    let adjusted = SessionAdjuster.adjust(push, category: .moderateFatigue)
    let bench = adjusted.day.exercises[0]
    #expect(bench.sets == 2)
    #expect(bench.setTargets == [SetTarget(repsMin: 10, repsMax: 12), SetTarget(repsMin: 4, repsMax: 6)])
    #expect(adjusted.day.exercises.allSatisfy { $0.setTargets == nil || $0.setTargets?.count == $0.sets })
}
```

- [ ] **Step 2 : Lancer, vérifier l'échec** — Run : `swift test --package-path Packages/PulseDomain && swift test --package-path Packages/PulseRecoveryEngine` — Expected : FAIL (piège à l'exécution, puis `setTargets` à 3 entrées).

- [ ] **Step 3 : Implémenter selon les Interfaces.**

- [ ] **Step 4 : Lancer, vérifier le succès** — même commande, plus `swift test --package-path Packages/PulseFeatures` — Expected : vert.

- [ ] **Step 5 : VFT, puis commit**

```bash
git add Packages/PulseDomain/Sources/PulseDomain/Training/Program.swift Packages/PulseDomain/Tests/PulseDomainTests/M4TrainingTypesTests.swift \
  Packages/PulseRecoveryEngine/Sources/PulseRecoveryEngine/Adjustments/VolumeReducer.swift Packages/PulseRecoveryEngine/Tests/PulseRecoveryEngineTests
git commit -m "fix(engine): keep per-set ranges with their sets when fatigue removes some, and never trap on an inverted range"
```

---

### Task 2 : « Dernière fois » rapide et records sans réécriture inutile

Suites de M4a (spec M4 §6.2 et §20 ; revue finale de M4a).

**Files:**
- Modify: `Packages/PulseDomain/Sources/PulseDomain/Repositories/WorkoutRepository.swift` (doc), `Packages/PulsePersistence/Sources/PulsePersistence/Repositories/SwiftDataWorkoutRepository.swift`, `SwiftDataPersonalRecordRepository.swift`, `Packages/PulseFeatures/Sources/PulseServices/Doubles/InMemoryRepositories.swift`, `Sources/PulseServices/Records/RecordsService.swift`, `Sources/OnboardingFeature/OnboardingModel+Calibration.swift`
- Test: `Packages/PulsePersistence/Tests/PulsePersistenceTests/WorkoutRepositoryTests.swift`, `PersonalRecordRepositoryTests.swift`, `Packages/PulseFeatures/Tests/PulseServicesTests/RecordsServiceTests.swift`, `InMemoryTrainingRepositoriesTests.swift` (ou le fichier des doublures), `Tests/OnboardingFeatureTests/…`

**Interfaces:**
- Produces :
  - **`lastSets(for:)`** rend les séries **hors échauffement** (travail, dégressives, échec), dans l'ordre, de la dernière séance **terminée ou abandonnée** non supprimée qui contient l'exercice. La lecture se fait par la référence d'exercice sur `StoredWorkoutSet` (et non plus en reconstruisant chaque séance). Même règle dans `InMemoryWorkoutRepository`.
  - **`replaceAll(with:)`** ne réécrit ni ne re-date un record identique (même clé, même valeur, même date, même séance) : il évite le trafic CloudKit inutile.
  - **`RecordsService.recomputeAll()`** relit chaque séance dont les marques changent (`session(id:)`) juste avant de l'enregistrer, et y applique les marques. Une modification faite entre-temps n'est donc pas écrasée.
  - **`OnboardingModel+Calibration`** : une lecture ratée du programme passe `nil` au service du score (programme illisible, spec M4 §20), et non plus `.noProgram`.

- [ ] **Step 1 : Écrire les tests qui échouent**

```swift
@Test func lastSetsComeFromTheLatestCompletedOrAbandonedSessionWithoutWarmups() async throws {
    // bench dans : 12 oct terminée (É 20×10, 60×12, 70×5), 20 oct abandonnée (60×10), 25 oct en cours (62,5×8), 26 oct supprimée.
    let sets = try await repo.lastSets(for: .content(id: "bench-press-barbell"))
    #expect(sets.map(\.actualReps) == [10])
}

@Test func failureAndDropSetsCountAsLastTime() async throws { … }   // types failure et drop rendus, warmup exclu

@Test func replaceAllLeavesIdenticalRecordsUntouched() async throws {
    // replaceAll(A) puis replaceAll(A identique) : updatedAt du record inchangé.
}

@Test func recomputeAppliesFlagsToAFreshCopy() async throws {
    // Un dépôt de séances qui, entre la lecture et la sauvegarde, rend une note modifiée : la note survit au recalcul.
}
```

Ajouter dans `OnboardingFeatureTests` un test où le dépôt de programmes lève : les ajustements déjà enregistrés pour le jour ne sont pas effacés.

- [ ] **Step 2 : Lancer, vérifier l'échec** — Run : `swift test --package-path Packages/PulsePersistence && swift test --package-path Packages/PulseFeatures` — Expected : FAIL.

- [ ] **Step 3 : Implémenter selon les Interfaces.**

- [ ] **Step 4 : Lancer, vérifier le succès** — même commande — Expected : vert.

- [ ] **Step 5 : VFT, puis commit**

```bash
git add Packages/PulseDomain/Sources/PulseDomain/Repositories/WorkoutRepository.swift Packages/PulsePersistence Packages/PulseFeatures/Sources/PulseServices \
  Packages/PulseFeatures/Sources/OnboardingFeature Packages/PulseFeatures/Tests
git commit -m "fix(persistence): read last time per exercise directly, include abandoned sessions and leave identical records alone"
```

---

### Task 3 : Moteur — politique de hausse et charges proposées

Spec M4 §8.1, tableau « Politique du jour » et règles série par série.

**Files:**
- Create: `Packages/PulseRecoveryEngine/Sources/PulseRecoveryEngine/Progression/ProgressionPolicy.swift`, `LoadProgression.swift`, `PlateRounding.swift`
- Modify: `Packages/PulseRecoveryEngine/Sources/PulseRecoveryEngine/Resources/Localizable.xcstrings`
- Test: `Packages/PulseRecoveryEngine/Tests/PulseRecoveryEngineTests/ProgressionPolicyTests.swift`, `LoadProgressionTests.swift`, `PlateRoundingTests.swift`

**Interfaces:**
- Produces :
  - `public struct ProgressionPolicy: Sendable, Equatable, Codable { public var allowsIncrease: Bool }` et `public static func make(recovery: DailyRecovery?, adaptationEnabled: Bool, startsOriginalAfterOverreach: Bool) -> ProgressionPolicy`. La hausse est permise dans ces cas :
    - `adaptationEnabled` faux ;
    - aucun score ;
    - score mesuré, `calibration == .ready`, catégorie `.optimal` ou `.normal`, facteurs manquants ou non.
    
    Elle est refusée si le score est estimé, si la calibration est en cours, en fatigue modérée, et en surmenage (`startsOriginalAfterOverreach` compris).
  - `public enum WeightRounding: Sendable, Equatable, Codable { case plates(barKg: Double, smallestPlateKg: Double); case increment }`.
  - `public enum PlateRounding { public static func nextLoad(after weightKg: Double, increment: Double, rounding: WeightRounding) -> Double }` :
    - barre : la plus petite charge `bar + 2 × n × smallestPlate` qui soit ≥ `weightKg + increment` ;
    - sinon : `weightKg + increment`.
  - `public struct ProposedSet: Sendable, Equatable, Codable { public var weightKg: Double?; public var reps: Int?; public var durationSeconds: Int?; public var isIncrease: Bool }`.
  - `public struct ExerciseProposal: Sendable, Equatable { public var sets: [ProposedSet]; public var loadAdjustment: SessionAdjustment? }`.
  - `public enum LoadProgression { public static let maxRPEForIncrease = 8.0; public static func propose(exercise: RoutineExercise, name: String, loadKind: LoadKind, tracksDuration: Bool, lastSets: [WorkoutSet], incrementKg: Double, rounding: WeightRounding, policy: ProgressionPolicy) -> ExerciseProposal }`. Règles du §8.1, pour chaque série *n* de `0..<exercise.sets` :
    - **Référence** : la série *n* de `lastSets`, ou la dernière si *n* dépasse le nombre de séries faites.
    - **Pas de référence** : pas de charge, répétitions = bas de `repRange(forSet: n)` (secondes pour un exercice tenu).
    - **Hausse** : si la politique la permet, que la référence a atteint le haut de `repRange(forSet: n)`, et que son RPE est absent ou ≤ 8. Charge selon la nature :
      - externe : `PlateRounding.nextLoad` ;
      - poids du corps : `(lest ?? 0) + incrément` ;
      - assistée : `max(0, assistance − incrément)`.
      
      Répétitions = bas de la fourchette, `isIncrease = true`.
    - **Assistance à 0 et haut de la fourchette atteint** : charge 0, répétitions = référence + 1 (même au-delà de la fourchette), `isIncrease = false`. La raison suggère de passer au poids du corps.
    - **Sinon** : même charge. Répétitions = `min(référence + 1, haut)` si la politique permet la hausse, sinon celles de la référence.
    - **Ajustement nommé** : il y en a un si au moins une série monte. `SessionAdjustment(kind: .load, reason: "<Nom> : +2,5 kg sur 2 séries, 12 répétitions atteintes la dernière fois", value: écart en kg)`. Pour l'assisté : « assistance −2,5 kg ». Texte dans le catalogue du moteur ; l'écart est formaté à la française, sans « ,0 ».

- [ ] **Step 1 : Écrire les tests qui échouent**

```swift
@Test func policyFollowsTheDayTable() {
    #expect(ProgressionPolicy.make(recovery: nil, adaptationEnabled: true, startsOriginalAfterOverreach: false).allowsIncrease)
    #expect(ProgressionPolicy.make(recovery: .measured(score: 72), adaptationEnabled: true, startsOriginalAfterOverreach: false).allowsIncrease)
    #expect(ProgressionPolicy.make(recovery: .measured(score: 72, missing: [.hrv]), adaptationEnabled: true,
                                   startsOriginalAfterOverreach: false).allowsIncrease)
    #expect(!ProgressionPolicy.make(recovery: .measured(score: 55), adaptationEnabled: true, startsOriginalAfterOverreach: false).allowsIncrease)
    #expect(!ProgressionPolicy.make(recovery: .estimated(score: 92), adaptationEnabled: true, startsOriginalAfterOverreach: false).allowsIncrease)
    #expect(!ProgressionPolicy.make(recovery: .measured(score: 92, calibrating: 8), adaptationEnabled: true,
                                    startsOriginalAfterOverreach: false).allowsIncrease)
    #expect(!ProgressionPolicy.make(recovery: .measured(score: 30), adaptationEnabled: true, startsOriginalAfterOverreach: true).allowsIncrease)
    #expect(ProgressionPolicy.make(recovery: .measured(score: 55), adaptationEnabled: false, startsOriginalAfterOverreach: false).allowsIncrease)
}

@Test func rampingBenchProgressesSetBySet() {
    // Bench, setTargets [10–12, 4–6, 4–6], dernière fois 60×12 (RPE 7,5), 70×6, 70×5 ; barre 20, plus petit disque 1,25 ; incrément 2,5.
    let proposal = LoadProgression.propose(exercise: bench, name: "Développé couché à la barre", loadKind: .external, tracksDuration: false,
                                           lastSets: last, incrementKg: 2.5, rounding: .plates(barKg: 20, smallestPlateKg: 1.25), policy: .open)
    #expect(proposal.sets.map(\.weightKg) == [62.5, 72.5, 70])
    #expect(proposal.sets.map(\.reps) == [10, 4, 6])
    #expect(proposal.sets.map(\.isIncrease) == [true, true, false])
    #expect(proposal.loadAdjustment?.reason == "Développé couché à la barre : +2,5 kg sur 2 séries, 12 répétitions atteintes la dernière fois")
}

@Test func aHighRPEBlocksTheIncrease() { … }          // 60×12 RPE 9 → 60 kg, 12 reps
@Test func aClosedPolicyKeepsLastTimeExactly() { … }  // fatigue : 60×12, 70×6, 70×5 reproduits
@Test func noHistoryProposesTheBottomOfEachRange() { … }
@Test func moreSetsThanLastTimeRepeatTheLastOne() { … }
@Test func cableStackUsesTheMachineIncrement() { … }  // poulie 27 kg ×15 (haut 15), incrément 3,5 → 30,5
@Test func assistedDipsLowerTheAssistanceThenAskForMoreReps() { … }
@Test func timedHoldsProposeSeconds() { … }
@Test func platesRoundUpToAPair() {
    #expect(PlateRounding.nextLoad(after: 60, increment: 1.25, rounding: .plates(barKg: 20, smallestPlateKg: 1.25)) == 62.5)
    #expect(PlateRounding.nextLoad(after: 27, increment: 3.5, rounding: .increment) == 30.5)
}
```

`.measured(score:missing:calibrating:)`, `.estimated(score:)` et `.open` sont de petites fabriques de test, dans le fichier de support du moteur.

- [ ] **Step 2 : Lancer, vérifier l'échec** — Run : `swift test --package-path Packages/PulseRecoveryEngine` — Expected : FAIL à la compilation.

- [ ] **Step 3 : Implémenter selon les Interfaces.**

- [ ] **Step 4 : Lancer, vérifier le succès** — même commande, plus `swift test --package-path Packages/PulseFeatures` — Expected : vert.

- [ ] **Step 5 : VFT, puis commit**

```bash
git add Packages/PulseRecoveryEngine/Sources/PulseRecoveryEngine/Progression Packages/PulseRecoveryEngine/Sources/PulseRecoveryEngine/Resources \
  Packages/PulseRecoveryEngine/Tests/PulseRecoveryEngineTests
git commit -m "feat(engine): propose loads set by set with the day's progression policy and plate rounding"
```

---

### Task 4 : Services — modèle de séance active, lancement et planificateur

**Files:**
- Create: `Packages/PulseFeatures/Sources/PulseServices/LiveSession/LiveSession.swift`, `SessionLaunch.swift`, `LiveSessionPlanner.swift`, `LiveSessionText.swift`
- Modify: `Sources/PulseServices/Resources/Localizable.xcstrings`
- Test: `Tests/PulseServicesTests/LiveSessionPlannerTests.swift`, `SessionLaunchTests.swift`, `LiveSessionCodingTests.swift`

**Interfaces:**
- Consumes : tâches 1–3 ; `ExerciseDirectory`, `IncrementResolver`, `SessionAdjuster`, `ExerciseSettingsRepository`, `WorkoutRepository.lastSets`.
- Produces :
  - **`public struct LiveSession: Sendable, Equatable, Codable, Identifiable`** : `formatVersion: Int` (= `LiveSession.currentFormat`, 1), `id: UUID`, `title: String`, `startedAt: Date`, `lastActionAt: Date`, `programID: UUID?`, `routineDayID: UUID?`, `appliedAdjustments: [SessionAdjustment]`, `refusedAdjustments: [SessionAdjustment]`, `exercises: [LiveExercise]`, `rest: LiveRest?`. Plus `public var plannedWorkingSets: Int`, `doneWorkingSets: Int`, `tonnageKg: Double` (via `SessionTonnage` sur les séries validées), `nextSet: (exerciseIndex: Int, setIndex: Int)?` (la prochaine série non validée dans l'ordre, super set compris : A1, B1, A2, B2…).
  - **`public struct LiveExercise: Sendable, Equatable, Codable, Identifiable`** : `id: UUID`, `exercise: ExerciseReference`, `name: String`, `loadKind: LoadKind`, `tracksDuration: Bool`, `isBarbell: Bool`, `incrementKg: Double`, `supersetGroup: Int?`, `restSeconds: Int` (repos de la routine avec le supplément du jour), `rpeCap: Double?`, `dayNote: String?` (la ligne « ce que le jour a changé »), `lastTimeText: String?` (« Dernière fois 70 × 5 · 5 »), `note: String?`, `sets: [LiveSet]`.
  - **`public struct LiveSet: Sendable, Equatable, Codable, Identifiable`** : `id: UUID`, `setType: SetType`, `previous: String?` (« 70 × 5 »), `proposed: ProposedSet`, `weightKg: Double?`, `reps: Int?`, `durationSeconds: Int?`, `rpe: Double?`, `isEdited: Bool` (une valeur a été changée à la main), `completedAt: Date?`. Les valeurs non éditées valent les propositions.
  - **`public struct LiveRest: Sendable, Equatable, Codable`** : `startedAt: Date`, `endsAt: Date`, `exerciseID: UUID`.
  - **`public struct SessionLaunch: Sendable, Equatable`** : `title: String`, `day: RoutineDay?` (`nil` = séance libre), `programID: UUID?`, `applied: [SessionAdjustment]`, `refused: [SessionAdjustment]`, `policy: ProgressionPolicy`. Fabriques :
    - `public static func routine(_ day: RoutineDay, programID: UUID?, recovery: DailyRecovery?, originalChosen: Bool, profile: UserProfile?) -> SessionLaunch`. Avec un score et l'adaptation activée, `SessionAdjuster.adjust`. Si `originalChosen` ou si la catégorie est le surmenage : le jour original, et les ajustements de catégorie vont dans `refused`. Sinon : le jour ajusté, et ses ajustements dans `applied`. La politique vient de `ProgressionPolicy.make`.
    - `public static func free(policy: ProgressionPolicy) -> SessionLaunch`, au titre « Séance libre ».
  - **`public enum LiveSessionPlanner`** :
    - `public static func session(for launch: SessionLaunch, directory: ExerciseDirectory, history: [ExerciseReference: [WorkoutSet]], settings: [ExerciseReference: ExerciseSettings], profile: UserProfile?, now: Date) -> LiveSession` : pure ; elle construit les exercices avec `LoadProgression` (arrondi aux disques si `equipment == .barbell`, avec `barWeightKg` et le plus petit de `availablePlatesKg`), `previous`, `lastTimeText`, `dayNote`, et ajoute les ajustements de charge à `appliedAdjustments`.
    - `public static func exercise(_ reference: ExerciseReference, directory: ExerciseDirectory, history: [WorkoutSet], settings: ExerciseSettings?, profile: UserProfile?, policy: ProgressionPolicy) -> LiveExercise` : un exercice ajouté en séance, avec 3 séries, une fourchette de 8 à 12 (30 à 60 s s'il est tenu) et le repos par défaut de l'exercice, sinon celui du profil.
  - `dayNote` assemble, dans cet ordre :
    - « Même charge » si la politique bloque la hausse et qu'il y a un historique, ou la raison de la hausse ;
    - « une série en moins » ou « N séries en moins » ;
    - « RPE 7,5 max » ;
    - « repos 2:45 », seulement si le jour a changé le repos (`PulseFormat.restDuration`).
    
    Les morceaux sont séparés par « , », première lettre en majuscule. `nil` si rien n'a changé.

- [ ] **Step 1 : Écrire les tests qui échouent**

```swift
@Test func aFatigueDayPlanKeepsLoadsAndSaysWhatChanged() {
    // Push ajusté en fatigue (bench 3→2 séries, RPE 7,5, repos 120+45) ; dernière fois bench 60×12, 70×5, 70×5.
    let session = LiveSessionPlanner.session(for: launch, directory: directory, history: history, settings: [:], profile: profile, now: .t0)
    let bench = session.exercises[0]
    #expect(bench.sets.count == 2)
    #expect(bench.sets.map(\.proposed.weightKg) == [60, 70])
    #expect(bench.dayNote == "Même charge, une série en moins, RPE 7,5 max, repos 2:45")
    #expect(bench.lastTimeText == "Dernière fois 60 × 12 · 70 × 5 · 5")
    #expect(bench.sets.map(\.previous) == ["60 × 12", "70 × 5"])
    #expect(session.appliedAdjustments.map(\.kind) == [.volume, .rpeCap, .rest])
}

@Test func aNormalDayAddsTheLoadAdjustment() { … }     // .load ajouté à appliedAdjustments, dayNote = la raison, repos 1:45
@Test func launchFromTheOriginalSessionRefusesTheCategoryAdjustments() { … }
@Test func overreachedLaunchStartsTheOriginalWithoutIncrease() { … }
@Test func aFreeSessionStartsEmpty() { … }             // titre « Séance libre », aucun exercice
@Test func addedExerciseGetsThreeSetsAndItsDefaultRest() { … }
@Test func supersetOrderAlternatesTheTwoExercises() { … } // nextSet A1, B1, A2…
@Test func aSnapshotRoundTripsAndRejectsAnUnknownFormat() throws {
    let data = try JSONEncoder().encode(session)
    #expect(try JSONDecoder().decode(LiveSession.self, from: data) == session)
    // formatVersion 99 → LiveSession.decode(_:) rend nil (pas de plantage).
}
```

`LiveSession.decode(_ data: Data) -> LiveSession?` (statique) rend `nil` pour un format inconnu ou un JSON illisible.

- [ ] **Step 2 : Lancer, vérifier l'échec** — Run : `swift test --package-path Packages/PulseFeatures --filter "LiveSession|SessionLaunch"` — Expected : FAIL à la compilation.

- [ ] **Step 3 : Implémenter selon les Interfaces.**

- [ ] **Step 4 : Lancer, vérifier le succès** — Run : `swift test --package-path Packages/PulseFeatures` — Expected : vert.

- [ ] **Step 5 : VFT, puis commit**

```bash
git add Packages/PulseFeatures/Sources/PulseServices/LiveSession Packages/PulseFeatures/Sources/PulseServices/Resources Packages/PulseFeatures/Tests/PulseServicesTests
git commit -m "feat(services): plan a live session from a routine with proposed loads, last time and the day's changes"
```

---

### Task 5 : Domaine — repos et Live Activity derrière des protocoles

**Files:**
- Create: `Packages/PulseDomain/Sources/PulseDomain/Repositories/RestTimerNotifying.swift`, `SessionActivityControlling.swift`
- Test: `Packages/PulseDomain/Tests/PulseDomainTests/SessionActivityStateTests.swift`

**Interfaces:**
- Produces :
  - `public struct RestEndMessage: Sendable, Equatable { public var title: String; public var body: String }`.
  - `public protocol RestTimerNotifying: Sendable { func scheduleRestEnd(at date: Date, message: RestEndMessage) async; func cancelRestEnd() async }` et la doublure `public actor StubRestTimerNotifier` (`scheduled: [(Date, RestEndMessage)]`, `cancelCount`).
  - `public struct SessionActivityState: Sendable, Equatable, Codable { public var sessionID: UUID; public var title: String; public var startedAt: Date; public var restStartedAt: Date?; public var restEndsAt: Date?; public var nextSet: String? }`.
  - `public protocol SessionActivityControlling: Sendable { func start(_ state: SessionActivityState) async; func update(_ state: SessionActivityState) async; func end() async; func endAll(except sessionID: UUID?) async }` et la doublure `public actor StubSessionActivityController` (`states: [SessionActivityState]`, `endCount`, `endAllCalls: [UUID?]`).

- [ ] **Step 1 à 5 :** un test d'aller-retour `Codable` de `SessionActivityState` et un test des doublures (enregistrement dans l'ordre). Puis implémentation, vert, VFT et commit :

```bash
git add Packages/PulseDomain/Sources/PulseDomain/Repositories/RestTimerNotifying.swift \
  Packages/PulseDomain/Sources/PulseDomain/Repositories/SessionActivityControlling.swift Packages/PulseDomain/Tests/PulseDomainTests/SessionActivityStateTests.swift
git commit -m "feat(domain): describe the rest notification and the session live activity as protocols"
```

---

### Task 6 : Services — le service de séance active

Spec M4 §14.1, §14.3 à §14.5, §15.1 à §15.3, §16.

**Files:**
- Create: `Packages/PulseFeatures/Sources/PulseServices/LiveSession/ActiveSessionService.swift`, `ActiveSessionService+Rest.swift`, `LiveSessionChange.swift`
- Test: `Tests/PulseServicesTests/ActiveSessionServiceTests.swift`, `ActiveSessionRestTests.swift`

**Interfaces:**
- Consumes : tâches 4 et 5 ; `ActiveSessionStore`, `ProfileRepository`, `WorkoutRepository`, `ExerciseSettingsRepository`, `UserExerciseRepository`, `ContentLibrary`, `SerialTaskQueue`.
- Produces :
  - **`public enum ActiveSessionError: Error, Equatable { case alreadyInProgress, noSession, notStored }`**.
  - **`public enum LiveSessionChange: Sendable, Equatable`**, avec ses règles :
    - `validate(exercise: UUID, set: UUID)` : pose `completedAt = now`, et prend les valeurs proposées pour celles qui ne sont pas éditées. Si l'exercice n'a pas d'historique et que c'est sa première série validée, les séries suivantes **non éditées** de l'exercice reçoivent ses valeurs comme propositions.
    - `unvalidate(exercise:set:)`.
    - `edit(exercise:set:weightKg:reps:durationSeconds:rpe:)` : chaque champ facultatif ; `nil` laisse le champ tel quel, et `.some(nil)` l'efface pour le RPE. Pose `isEdited`.
    - `setType(exercise:set:SetType)`.
    - `addSet(exercise:)` : reprend la dernière série de l'exercice.
    - `deleteSet(exercise:set:)`.
    - `addExercises([LiveExercise])`, `removeExercise(UUID)`, `moveExercise(UUID, by: Int)`.
    - `setNote(exercise:String?)`, `setIncrement(exercise:Double)`.
    - `restMinus30`, `restPlus30`, `skipRest`.
  - **`public final class ActiveSessionService: Sendable`** :
    - `init(store: any ActiveSessionStore, workouts: any WorkoutRepository, profiles: any ProfileRepository, settings: any ExerciseSettingsRepository, userExercises: any UserExerciseRepository, records: RecordsService, library: ContentLibrary, restNotifier: any RestTimerNotifying, activity: any SessionActivityControlling, calendar: Calendar, now: @escaping @Sendable () -> Date)` ;
    - `public func current() async -> LiveSession?` : snapshot décodé, ou `nil` ;
    - `public func start(_ launch: SessionLaunch) async throws -> LiveSession` : lève `alreadyInProgress` si un snapshot existe ; lit l'historique et les réglages, appelle `LiveSessionPlanner`, enregistre, puis démarre la Live Activity ;
    - `public func newExercises(_ references: [ExerciseReference]) async throws -> [LiveExercise]` : planifie les exercices ajoutés en séance ;
    - `public func apply(_ change: LiveSessionChange) async throws -> LiveSession`.
    
    Tout passe par **une seule** `SerialTaskQueue`. Chaque appel qui change la séance pose `lastActionAt = now`, enregistre le snapshot (`ActiveSessionSnapshot`, `payload` = JSON) **avant de rendre la main**, puis met à jour le repos, la notification et la Live Activity.
  - **Règles du repos** (`+Rest`) :
    - **Valider une série** lance `LiveRest(startedAt: now, endsAt: now + restSeconds)`. Une série d'échauffement a 60 s.
    - **Pas de repos** après la dernière série non validée de la séance, ni après une série du premier exercice d'un super set : dans ce cas, le repos part après la série du second.
    - **Ajuster** : −30 s donne `endsAt = max(now, endsAt − 30)`, et le repos se termine s'il atteint `now` ; +30 s ajoute 30 s ; Passer efface le repos.
    - **Repos terminé** : `current()` et chaque changement effacent un repos dont `endsAt ≤ now`.
    - **Notification** : planifiée à `endsAt` si `profile.restTimerNotificationEnabled`, avec le message « Repos terminé » / « <Nom>, série <n> : <charge> × <reps> » (série suivante). Elle est annulée par Passer, par un repos terminé ou effacé, et à la fin de la séance.
    - **Live Activity** : `update` avec `SessionActivityState`, dont `nextSet` vaut « <Nom> · série <n> · 70 kg × 5 ».

- [ ] **Step 1 : Écrire les tests qui échouent**

```swift
@Test func startingWhileASessionExistsThrows() async throws {
    _ = try await service.start(pushLaunch)
    await #expect(throws: ActiveSessionError.alreadyInProgress) { try await service.start(pushLaunch) }
}

@Test func eachValidationIsStoredBeforeReturning() async throws {
    let session = try await service.start(pushLaunch)
    _ = try await service.apply(.validate(exercise: session.exercises[0].id, set: session.exercises[0].sets[0].id))
    let stored = try #require(LiveSession.decode(try #require(try await store.load()).payload))
    #expect(stored.exercises[0].sets[0].completedAt == clock.now)
    #expect(stored.rest?.endsAt == clock.now.addingTimeInterval(165))   // 120 + 45 en fatigue
    #expect(await notifier.scheduled.last?.1.body == "Développé couché à la barre, série 2 : 70 kg × 5")
}

@Test func firstValidatedSetSeedsTheFollowingUneditedSets() async throws { … }   // sans historique : 40×10 validé → séries 2 et 3 = 40×10, sauf la 3 éditée
@Test func supersetRestStartsAfterTheSecondExercise() async throws { … }
@Test func theLastSetStartsNoRest() async throws { … }
@Test func restControlsMoveTheEndDateAndTheNotification() async throws { … }      // −30 jamais avant maintenant, +30, Passer annule
@Test func concurrentRestControlsAreSerialised() async throws {
    // 10 × restPlus30 et 10 × restMinus30 lancés en parallèle : endsAt final = départ, aucune erreur, snapshot cohérent.
}
@Test func resumingAfterTheRestEndedShowsNoRest() async throws {
    // repos jusqu'à 08:02:45 ; horloge à 08:10 ; current() → rest nil, notification annulée, startedAt inchangé.
}
@Test func editsMarkTheSetAndKeepProposalsForTheOthers() async throws { … }
@Test func disabledRestNotificationsScheduleNothing() async throws { … }
```

- [ ] **Step 2 : Lancer, vérifier l'échec** — Run : `swift test --package-path Packages/PulseFeatures --filter ActiveSession` — Expected : FAIL à la compilation.

- [ ] **Step 3 : Implémenter selon les Interfaces.**

- [ ] **Step 4 : Lancer, vérifier le succès** — Run : `swift test --package-path Packages/PulseFeatures` — Expected : vert.

- [ ] **Step 5 : VFT, puis commit**

```bash
git add Packages/PulseFeatures/Sources/PulseServices/LiveSession Packages/PulseFeatures/Tests/PulseServicesTests
git commit -m "feat(services): run the live session, store every change and drive the rest timer, its notification and the live activity"
```

---

### Task 7 : Services — récap, enregistrement, abandon, séance oubliée

Spec M4 §14.6, §16 et §17.

**Files:**
- Create: `Packages/PulseFeatures/Sources/PulseServices/LiveSession/ActiveSessionService+Finish.swift`, `SessionRecap.swift`
- Test: `Tests/PulseServicesTests/SessionRecapTests.swift`, `ActiveSessionFinishTests.swift`

**Interfaces:**
- Consumes : tâche 6, `RecordBook`, `SessionTonnage`, `TrainingLoad`, `RecordsService`.
- Produces :
  - `public struct BeatenRecord: Sendable, Equatable { public var exerciseName: String; public var kind: RecordKind; public var text: String }`, avec un texte par nature :
    - charge max : « Développé couché à la barre : 72,5 kg, nouveau record de charge » ;
    - 1RM estimé : « … : 1RM estimé 84 kg, nouveau record » ;
    - répétitions à une charge : « … : 8 répétitions à 70 kg, nouveau record ».
  - `public struct SessionRecap: Sendable, Equatable`, avec ses champs :
    - `title`, `startedAt`, `endedAt` ;
    - `durationMinutes: Int`, `tonnageKg: Double`, `workingSets: Int` ;
    - `beatenRecords: [BeatenRecord]` : `RecordBook` sur l'historique plus la séance en brouillon ; seules les séries de cette séance qui entrent dans `recordSetIDs` comptent ;
    - `muscleWeights: [Muscle: Double]` ;
    - `setsPerGroup: [(MuscleGroup, Int)]` ;
    - `suggestedRPE: Int` : moyenne arrondie des RPE de série, sinon 7 ;
    - `loadSentence(rpe: Int) -> String` : « Charge de la séance : 55 min × 7 = 385. » suivi de « Ratio aigu / chronique après la séance : 1,15. » quand `TrainingLoad.acwr` en rend un.
  - Sur `ActiveSessionService` :
    - `public func suggestedEnd() async -> Date?` : si `now − lastActionAt > 3 h`, l'heure de la dernière série validée plus son repos ; sinon `nil` ;
    - `public func recap(endedAt: Date) async throws -> SessionRecap` ;
    - `public func finish(overallRPE: Int, note: String?, endedAt: Date) async throws -> WorkoutSession`. Elle écrit la séance `completed`, source `pulse`, avec :
      - les séries **validées seulement**, `order` de 0 à n−1, prévu = propositions, réalisé = valeurs ;
      - `exerciseNotes`, tonnage, `durationMinutes`, et les ajustements appliqués et refusés.
      
      Ensuite `records.recomputeAll()`, effacement du snapshot, `activity.end()` et `restNotifier.cancelRestEnd()`.
      
      **Idempotente** : l'identifiant de la `WorkoutSession` est celui de la `LiveSession`. Si l'enregistrement échoue, le snapshot reste et l'erreur remonte ; un second appel réécrit la même séance, sans doublon.
    - `public func abandon(endedAt: Date) async throws -> WorkoutSession` : même chose avec le statut `abandoned` et sans RPE. Une séance sans aucune série validée n'est pas enregistrée : le snapshot est effacé et la séance rendue n'a pas de séries.
    - `public func discardAfterErase() async` : appelée après une suppression totale ; termine toutes les Live Activities et annule le repos, sans écrire.

- [ ] **Step 1 : Écrire les tests qui échouent**

```swift
@Test func recapCountsWorkingSetsTonnageAndBeatenRecords() async throws {
    // Historique : bench 70×5 max. Séance : É 20×10, 60×12, 72,5×5 validées, 3e série non validée.
    let recap = try await service.recap(endedAt: clock.now.addingTimeInterval(3_300))
    #expect(recap.workingSets == 2)
    #expect(recap.tonnageKg == 60 * 12 + 72.5 * 5)
    #expect(recap.durationMinutes == 55)
    #expect(recap.beatenRecords.map(\.text).contains("Développé couché à la barre : 72,5 kg, nouveau record de charge"))
    #expect(recap.suggestedRPE == 7)
}

@Test func finishWritesOnlyValidatedSetsAndClearsEverything() async throws { … }
@Test func aFailedSaveKeepsTheSnapshotAndRetriesOnce() async throws {
    // Dépôt de séances qui lève au 1er save : finish lève, snapshot présent, activité non terminée ; 2e finish → 1 seule séance en base.
}
@Test func abandonKeepsValidatedSetsAsAbandoned() async throws { … }
@Test func anEmptyAbandonWritesNothing() async throws { … }
@Test func aForgottenSessionSuggestsTheLastSetPlusItsRest() async throws {
    // dernière série validée 08:40, repos 90 s ; horloge 12:00 → suggestedEnd = 08:41:30 ; à 09:30 → nil.
}
@Test func loadSentenceNamesTheRatioWhenThereIsOne() { … }
```

- [ ] **Step 2 : Lancer, vérifier l'échec** — Run : `swift test --package-path Packages/PulseFeatures --filter "SessionRecap|ActiveSessionFinish"` — Expected : FAIL.

- [ ] **Step 3 : Implémenter selon les Interfaces.**

- [ ] **Step 4 : Lancer, vérifier le succès** — Run : `swift test --package-path Packages/PulseFeatures` — Expected : vert.

- [ ] **Step 5 : VFT, puis commit**

```bash
git add Packages/PulseFeatures/Sources/PulseServices/LiveSession Packages/PulseFeatures/Sources/PulseServices/Resources Packages/PulseFeatures/Tests/PulseServicesTests
git commit -m "feat(services): sum up a live session, save or abandon it once, and catch a session left open"
```

---

### Task 8 : Cible `LiveSessionFeature` — coordination, modèle de séance, clavier

**Files:**
- Modify: `Packages/PulseFeatures/Package.swift` (produit `LiveSessionFeature`, dépend de `PulseServices`, `PulseDomain`, `PulseRecoveryEngine`, `PulseContent`, `PulseDesignSystem`, `TrainFeature` ; cible de tests `LiveSessionFeatureTests`), `Packages/PulseDesignSystem/Sources/PulseDesignSystem/Platform/PlatformModifiers.swift` (`PulseHaptics.light()`, `.validation()` double, `.restEnded()` long), `Tokens/PulsePalette.swift` (`liveBackground` `#000000`)
- Create: `Packages/PulseFeatures/Sources/LiveSessionFeature/LiveSessionEnvironment.swift`, `LiveSessionCoordinator.swift`, `LiveSessionModel.swift`, `Keypad/KeypadInput.swift`, `Keypad/KeypadField.swift`, `LiveSessionIdentifiers.swift`, `Resources/Localizable.xcstrings`
- Test: `Packages/PulseFeatures/Tests/LiveSessionFeatureTests/LiveSessionCoordinatorTests.swift`, `LiveSessionModelTests.swift`, `KeypadInputTests.swift`

**Interfaces:**
- Consumes : tâches 4, 6 et 7 ; `TrainEnvironment` (pour la bibliothèque en mode choix et la fiche).
- Produces :
  - `public struct LiveSessionEnvironment: Sendable { service: ActiveSessionService; train: TrainEnvironment; notifications: any NotificationAuthorizing; calendar: Calendar; now: @Sendable () -> Date }`.
  - **`@MainActor @Observable public final class LiveSessionCoordinator`** : `init(environment:)`. Publie `current: LiveSession?` (pour le bandeau « Reprendre la séance »), `isPresented: Bool` et `errorMessage: String?`. Méthodes :
    - `refresh() async` : relit `service.current()` au lancement et au retour au premier plan ;
    - `start(_ launch: SessionLaunch) async` : s'il existe déjà une séance, présente celle-là au lieu d'en créer une ;
    - `resume()` ;
    - `abandonFromBanner() async` ;
    - `model() -> LiveSessionModel` : un seul modèle par séance ;
    - `didFinish()`.
    
    Une garde empêche deux démarrages simultanés. Au premier démarrage du lancement de l'app, `notifications.requestAuthorization()` est appelé (iOS ne redemande pas une décision déjà prise). S'il rend faux, `notice` affiche une seule fois : « Notifications désactivées : la fin du repos ne sonnera pas écran verrouillé. Tu peux les activer dans Réglages. » (spec M4 §15.2).
  - **`@MainActor @Observable public final class LiveSessionModel`**. Publie `session: LiveSession`, `focus: KeypadField?` (exercice, série, champ `.weight | .reps | .duration`), `keypad: KeypadInput`, `errorMessage` et `isSaving`. Méthodes :
    - `tap(set:)` : valide la série, avec une double vibration. Si la série n'a ni répétitions (ou secondes) ni proposition, ou si un exercice à charge externe n'a pas de charge, la touche ouvre le clavier sur le champ manquant au lieu de valider **(choix du constructeur)** ;
    - `focus(_:)` ;
    - `keypadKey(_ key: KeypadInput.Key)` : chiffre, virgule, effacement, −/+ incrément, « Suivant » (kg → reps → série suivante) ; chaque touche applique `edit` ;
    - `setRPE(_:)` (6 à 10 par 0,5, `nil` pour « — »), `setType`, `addSet`, `deleteSet` ;
    - `addExercises(_ references:)`, `removeExercise`, `moveExercise`, `setNote`, `setIncrement` ;
    - `restMinus30`, `restPlus30`, `skipRest` ;
    - `restRemaining(at now: Date) -> TimeInterval?` ;
    - `didReachRestEnd()` : vibration longue, une seule fois par repos.
    
    Chaque action passe par `service.apply` et prend la séance qu'il rend.
  - **`public struct KeypadInput: Sendable, Equatable`** : une machine pure. Elle a un tampon texte, et ces opérations :
    - `start(with value: Double?)` ;
    - `apply(_ key:) -> Double?` ;
    - virgule unique ;
    - deux décimales au plus pour la charge, aucune pour reps et secondes ;
    - −/+ incrément arrondi à 0,25 kg, jamais sous 0.

- [ ] **Step 1 : Écrire les tests qui échouent**

```swift
@Test func keypadBuildsFrenchDecimalsAndSteps() {
    var input = KeypadInput(field: .weight, increment: 2.5)
    input.start(with: 70)
    #expect(input.apply(.minus) == 67.5)
    input.start(with: nil)
    _ = input.apply(.digit(7)); _ = input.apply(.digit(2)); _ = input.apply(.comma); _ = input.apply(.comma)
    #expect(input.apply(.digit(5)) == 72.5)
    #expect(input.text == "72,5")
}

@MainActor @Test func doubleStartPresentsOnce() async {
    async let first: Void = coordinator.start(pushLaunch)
    async let second: Void = coordinator.start(pushLaunch)
    _ = await (first, second)
    #expect(coordinator.isPresented)
    #expect(await service.current() != nil)   // une seule séance, aucune erreur affichée
}

@MainActor @Test func nextMovesFromWeightToRepsThenToTheNextSet() async { … }
@MainActor @Test func tappingTheCheckValidatesProposedValues() async { … }
@MainActor @Test func tappingAnEmptySetOpensTheKeypadInstead() async { … }
@MainActor @Test func restEndVibratesOncePerRest() async { … }
@MainActor @Test func aStoredSessionShowsTheResumeBanner() async { … }
@MainActor @Test func deniedNotificationsAreSaidOnce() async { … }   // StubNotificationAuthorizer(granted: false) : notice au 1er start, pas au 2e
```

- [ ] **Step 2 : Lancer, vérifier l'échec** — Run : `swift test --package-path Packages/PulseFeatures --filter LiveSessionFeatureTests` — Expected : FAIL (cible absente).

- [ ] **Step 3 : Implémenter selon les Interfaces.**

- [ ] **Step 4 : Lancer, vérifier le succès** — Run : `swift test --package-path Packages/PulseFeatures && swift test --package-path Packages/PulseDesignSystem` — Expected : vert.

- [ ] **Step 5 : VFT, puis commit**

```bash
git add Packages/PulseFeatures/Package.swift Packages/PulseFeatures/Sources/LiveSessionFeature Packages/PulseFeatures/Tests/LiveSessionFeatureTests \
  Packages/PulseDesignSystem/Sources/PulseDesignSystem
git commit -m "feat(live): coordinate the live session, its keypad and its actions"
```

---

### Task 9 : Écran de séance en direct

Spec M4 §14.2 à §14.5, §15.1 ; maquette `live`.

**Files:**
- Create: `Packages/PulseFeatures/Sources/LiveSessionFeature/Views/LiveSessionView.swift`, `LiveHeader.swift`, `LiveExerciseCard.swift`, `LiveSetRow.swift`, `NumericKeypad.swift`, `RPEPicker.swift`, `RestBanner.swift`, `LivePreviewSupport.swift`
- Modify: `Sources/LiveSessionFeature/Resources/Localizable.xcstrings`
- Test: `Tests/LiveSessionFeatureTests/LiveSessionTextTests.swift`, pour les textes et étiquettes VoiceOver construits par des fonctions pures du modèle

**Interfaces:**
- Consumes : tâche 8.
- Produces : `public struct LiveSessionView: View` (`init(model: LiveSessionModel, onFinish: @escaping () -> Void, onAbandon: @escaping () -> Void)`). Fond `PulsePalette.liveBackground`. L'écran contient :
  - **En-tête** : titre, durée écoulée (`Text(timerInterval:)` depuis `startedAt`), tonnage, séries faites/prévues, « Terminer », et un menu avec « Abandonner ».
  - **Une carte par exercice**, avec la mention super set. Elle montre le nom (qui ouvre `ExerciseSheetView`), `lastTimeText`, `dayNote`, le RPE plafond, et un menu : note, incrément, monter, descendre, retirer (avec confirmation).
  - **Lignes de série** : numéro qui ouvre le menu des types É / normale / D / X, précédent, kg (« +kg » pour le poids du corps, « −kg » pour l'assisté), reps ou secondes, RPE, et coche de 56 pt.
    - Valeurs proposées en couleur d'accent, éditées en neutre.
    - Suppression d'une série par balayage, et « + Ajouter une série ».
  - **« + Ajouter un exercice »**, qui ouvre `LibraryView` en choix multiple.
  - **Clavier intégré** en bas quand un champ a le focus, et choix du RPE par pilules.
  - **Bandeau de repos** : anneau, temps restant (`Text(timerInterval:)`), série suivante, −30 s, +30 s et Passer. Une `TimelineView` appelle `didReachRestEnd()`.
  
  Identifiants d'accessibilité (dans `LiveSessionIdentifiers`) :
  - `live.finish`, `live.menu`, `live.abandon` ;
  - `live.exercise.<i>.set.<j>.check` et `live.exercise.<i>.set.<j>.weight` ;
  - `live.rest.skip`.
  
  Étiquettes VoiceOver des lignes : « Série 2, proposé 70 kilos, 5 répétitions, non validée ».

- [ ] **Step 1 : Tests des textes purs** (`LiveSetRow.accessibilityText(for:index:loadKind:)`, `LiveHeader.progressText`, le format « +kg » / « −kg ») : écrire, voir échouer.
- [ ] **Step 2 : Implémenter les vues et leurs aperçus**, sous `#if DEBUG`, avec une séance d'exemple.
- [ ] **Step 3 : Lancer** `swift test --package-path Packages/PulseFeatures` puis, hors bac à sable, `make build-app` — Expected : vert ; code 0.
- [ ] **Step 4 : VFT, puis commit**

```bash
git add Packages/PulseFeatures/Sources/LiveSessionFeature Packages/PulseFeatures/Tests/LiveSessionFeatureTests
git commit -m "feat(live): show the live session with set rows, the built-in keypad and the rest banner"
```

---

### Task 10 : Récap, fin de séance et séance oubliée

Spec M4 §14.6, §16 (séance oubliée), §17 ; maquette `recap`.

**Files:**
- Create: `Packages/PulseFeatures/Sources/LiveSessionFeature/Recap/RecapModel.swift`, `RecapView.swift`, `FinishFlow.swift`
- Test: `Tests/LiveSessionFeatureTests/RecapModelTests.swift`

**Interfaces:**
- Consumes : tâches 7 à 9.
- Produces :
  - **`@MainActor @Observable public final class RecapModel`** : `init(service:endedAt:)`. Propriétés publiées :
    - `recap: SessionRecap?` ;
    - `rpe: Int` (de 1 à 10, pré-placé sur `suggestedRPE`) ;
    - `note: String` ;
    - `loadSentence: String` ;
    - `errorMessage: String?` ;
    - `isSaving: Bool`.
    
    Méthodes : `load() async`, `save() async -> Bool`, `later() async -> Bool` (enregistre avec le RPE pré-placé). Une erreur garde le récap ouvert avec « Réessayer ».
  - **`FinishFlow`** : la suite de « Terminer ».
    1. Une confirmation s'il reste des séries non validées (« Il reste N séries prévues »).
    2. Si `suggestedEnd()` existe, une alerte « Séance commencée il y a longtemps : la clore à 08:41 ? » avec « Clore à 08:41 » (choix par défaut) et « Garder l'heure actuelle ».
    3. Le récap en plein écran, non fermable sans « Enregistrer » ou « Plus tard ».
    
    « Abandonner » passe par une confirmation, la même règle d'heure, puis `abandon`.
  - **`RecapView`** :
    - le bilan : durée, tonnage, séries ;
    - les records battus ;
    - `MuscleMapView` (`MuscleIntensity.levels`) et les séries par groupe ;
    - le curseur RPE de 1 à 10, avec les libellés « très facile » … « maximal » et la phrase de charge ;
    - la note, puis « Enregistrer » et « Plus tard ».
    
    Identifiants : `recap.save`, `recap.later`, `recap.rpe`.

- [ ] **Step 1 : Écrire les tests qui échouent**

```swift
@MainActor @Test func recapStartsOnTheSuggestedRPEAndSavesOnce() async { … }
@MainActor @Test func aFailedSaveStaysOpenAndRetries() async { … }
@MainActor @Test func laterSavesWithThePrePlacedRPE() async { … }
@MainActor @Test func aForgottenSessionOffersTheSuggestedEnd() async { … }
```

- [ ] **Step 2 à 5 :** implémenter les modèles et les vues avec leurs aperçus, vert, VFT, puis commit :

```bash
git add Packages/PulseFeatures/Sources/LiveSessionFeature Packages/PulseFeatures/Tests/LiveSessionFeatureTests
git commit -m "feat(live): finish or abandon a session through a recap with records, muscles and the overall effort"
```

---

### Task 11 : Accueil — démarrer, Pourquoi avec charges, séance faite ou en cours

Spec M4 §14.1, §18.

**Files:**
- Modify: `Packages/PulseFeatures/Sources/TodayFeature/TodayEnvironment.swift` (+ `activeSession: ActiveSessionService`, `exerciseSettings`, `profiles` si absent), `TodayModel.swift`, `TodayModel+Session.swift`, `Session/SessionCardState.swift`, `Why/WhyChanges.swift`, `Views/TodayView.swift`, `Views/StrengthSessionCard.swift`, `Package.swift` si une dépendance manque
- Delete: `Sources/TodayFeature/Views/StartSessionSheet.swift`
- Test: `Tests/TodayFeatureTests/TodayModelSessionTests.swift`, `WhyChangesTests.swift`, `SessionCardStateTests.swift`

**Interfaces:**
- Consumes : tâches 3, 4 et 6.
- Produces :
  - `TodayModel.sessionLaunch(startsOriginal: Bool) -> SessionLaunch?`, construit avec `SessionLaunch.routine`, et `TodayView(model:onOpenProfile:onStartSession: (SessionLaunch) -> Void, onResumeSession: () -> Void)`. « Démarrer la séance » et « Démarrer quand même » appellent `onStartSession`. La feuille `TodaySheet.start` et `StartSessionSheet` disparaissent.
  - Identifiants : `today.session.done` sur la carte de séance faite, `today.session.resume` sur « Reprendre la séance ».
  - `SessionCardState` gagne deux cas :
    - `.done(DoneCard)` : titre, durée, séries, tonnage, records. C'est la dernière séance de musculation **terminée** aujourd'hui, et elle remplace « Démarrer » ;
    - `.inProgress(title:)`, quand `activeSession.current()` existe, avec un bouton « Reprendre la séance ».
  - **Pourquoi** : sur les jours optimaux et normaux, la ligne « Charges inchangées » est remplacée par les ajustements de charge du jour. Ils sont calculés par `LiveSessionPlanner.session` sur le jour à faire et l'historique (`lastSets`), en lecture seule, avec une pastille « +2,5 ». Sans aucun ajustement : « Charges de la dernière fois : aucune série n'a atteint le haut de sa fourchette ». Les jours de fatigue gardent « Charges inchangées ». Le cas `.load` de `WhyChanges` montre la raison et l'écart.

- [ ] **Step 1 : Écrire les tests qui échouent**

```swift
@MainActor @Test func startingFromTheCardLaunchesTheAdjustedDay() async { … }        // fatigue : jour ajusté, applied = volume, rpeCap, rest
@MainActor @Test func originalChoiceLaunchesTheOriginalAndRefusesAdjustments() async { … }
@MainActor @Test func aDoneSessionReplacesStart() async { … }
@MainActor @Test func aStoredLiveSessionShowsResume() async { … }
@Test func normalDayWhyListsTheLoadIncreases() { … }
@Test func normalDayWithoutIncreaseSaysWhy() {
    #expect(changes.last?.title == "Charges de la dernière fois : aucune série n'a atteint le haut de sa fourchette")
}
```

- [ ] **Step 2 à 5 :** implémenter, vert (`swift test --package-path Packages/PulseFeatures`), `make build-app`, VFT, puis commit (catalogue de TodayFeature selon la règle des Global Constraints) :

```bash
git commit -m "feat(today): start the live session from the card, list today's load increases and show a done or running session"
```

---

### Task 12 : Onglet Séance — Lancer, Séance libre, Reprendre

Spec M4 §9, §14.1.

**Files:**
- Modify: `Packages/PulseFeatures/Sources/TrainFeature/TrainEnvironment.swift` (+ `activeSession`), `TrainModel.swift`, `Views/TrainView.swift`, `Views/TrainTiles.swift`, `Views/RoutineRow.swift`
- Test: `Tests/TrainFeatureTests/TrainModelTests.swift`

**Interfaces:**
- Produces :
  - `TrainModel.launch(routine dayID: UUID) -> SessionLaunch?` utilise `SessionLaunch.routine` avec le score du jour et `originalChosen` du jour. `TrainModel.freeLaunch() -> SessionLaunch` utilise la politique du jour. `TrainModel.activeSessionTitle: String?` est relu à chaque `refresh()`.
  - `TrainView(model:onOpenToday:onStartSession:onResumeSession:)` comporte :
    - « Lancer » sur chaque ligne de routine (bouton séparé de la touche qui ouvre l'éditeur) ;
    - « Démarrer » sur la tuile Musculation, qui lance la séance du jour ;
    - une ligne « Séance libre » ;
    - le bandeau « Reprendre la séance » en tête quand une séance est en cours, et « Lancer » qui propose de reprendre dans ce cas.

- [ ] **Step 1 à 5 :** tests `launchingARoutineAppliesTodaysAdjustments`, `freeSessionUsesTodaysPolicy` et `activeSessionIsReported`. Puis implémentation, vert, `make build-app`, VFT et commit :

```bash
git commit -m "feat(train): launch a routine or a free session from the Séance tab and resume a running one"
```

---

### Task 13 : App — Live Activity, notification Time Sensitive, présentation et assemblage

Spec M4 §5.1, §15.2, §15.3, §16, §22.

**Files:**
- Create:
  - le package `Packages/PulseLiveActivity/Package.swift` : iOS 26 seulement, produit `PulseLiveActivity`, aucune dépendance ;
  - ses sources dans `Packages/PulseLiveActivity/Sources/PulseLiveActivity/` : `PulseSessionAttributes.swift`, `RestControl.swift`, `SessionIntents.swift`, `SessionIntentBridge.swift` ;
  - dans l'app : `Pulse/LiveActivity/SessionActivityController.swift` et `Pulse/LiveActivity/SessionIntentWiring.swift`.
- Modify: `Pulse/Notifications/UserNotificationScheduler.swift` (`RestTimerNotifying`), `Pulse/Notifications/NotificationRouter.swift`, `Pulse/AppDependencies.swift`, `Pulse/AppDelegate.swift`, `Pulse/Root/AppRootModel.swift`, `Pulse/Root/AppRootView.swift`, `Pulse/Root/MainTabView.swift`, `Pulse/Info.plist` (`NSSupportsLiveActivities` = YES), `Pulse/Pulse.entitlements` (`com.apple.developer.usernotifications.time-sensitive` = true), `Pulse.xcodeproj/project.pbxproj`, `Pulse.xcodeproj/xcshareddata/xcschemes/Pulse.xcscheme`
- Test: `PulseTests/NotificationRouterTests.swift` (compilé ; lancé par Mathéo), `PulseTests/SessionActivityControllerTests.swift` (conversion d'état seulement)

**Interfaces:**
- Produces :
  - **Package `PulseLiveActivity`** :
    - `public struct PulseSessionAttributes: ActivityAttributes` avec `sessionID: UUID` ; son `ContentState` (Codable, Hashable) porte `title`, `startedAt`, `restStartedAt: Date?`, `restEndsAt: Date?`, `nextSet: String?` ;
    - `public enum RestControl: String, Sendable { case minus30, plus30, skip }` ;
    - `public struct RestMinus30Intent`, `RestPlus30Intent`, `SkipRestIntent: LiveActivityIntent`, chacune avec `perform()` qui appelle `await SessionIntentBridge.handle(_:)` ;
    - `public enum SessionIntentBridge` : `@MainActor public static var handler: (@Sendable (RestControl) async -> Void)?` et `public static func handle(_:) async`.
  - **App** :
    - `SessionActivityController: SessionActivityControlling` s'appuie sur ActivityKit : `Activity.request` au démarrage, `update`, `end(…, dismissalPolicy: .immediate)`, et `endAll(except:)` sur `Activity<PulseSessionAttributes>.activities`.
    - `UserNotificationScheduler` implémente `RestTimerNotifying` avec l'identifiant `fr.seonay.pulse.rest-timer`, `interruptionLevel = .timeSensitive` et `UNTimeIntervalNotificationTrigger(timeInterval: max(1, endsAt − now))`.
    - `NotificationRouter.presentationOptions` ne présente rien pour le repos quand l'app est ouverte.
    - `AppDependencies` construit `ActiveSessionService` et un `LiveSessionEnvironment`, et passe `activeSession` aux environnements de l'accueil et de l'onglet Séance. En mode mémoire et en test, il utilise les doublures `StubRestTimerNotifier` et `StubSessionActivityController`.
    - Au lancement, `AppDelegate` pose `SessionIntentBridge.handler`. Le handler appelle `activeSession.apply(.restMinus30 | .restPlus30 | .skipRest)`, puis `coordinator.refresh()` sur le fil principal.
    - `AppRootModel` crée `LiveSessionCoordinator` avec les modèles du mode `.main`, appelle `refresh()` au premier plan et ferme les activités périmées (`endAll(except: current?.id)`). Après une suppression totale, il appelle `discardAfterErase()`.
    - `MainTabView` montre le bandeau « Reprendre la séance » (identifiant `session.resume`, avec la durée écoulée depuis `startedAt` et « Abandonner ») en haut des onglets quand une séance existe sans être présentée.
    - `LiveSessionEnvironment.notifications` reçoit l'autorisateur des notifications de l'app (une doublure en mode mémoire et en test). La séance s'affiche en plein écran par `fullScreenCover`, pilotée par `coordinator.isPresented`. Le tout est branché sur `TodayView` et `TrainView` (`onStartSession`, `onResumeSession`).
  - **`pbxproj`**, à la main, sur le modèle exact des entrées existantes :
    - le package local `Packages/PulseLiveActivity` : référence de dossier, groupe, `XCLocalSwiftPackageReference` et `packageReferences` du projet ;
    - le produit `PulseLiveActivity` dans les cibles `Pulse` et `PulseWidgets` (`PBXBuildFile`, phase Frameworks, `packageProductDependencies`, `XCSwiftPackageProductDependency`) ;
    - le produit `LiveSessionFeature` dans la cible `Pulse` ;
    - et dans le schéma, `LiveSessionFeatureTests` parmi les `TestableReference`.

- [ ] **Step 1 :** écrire les tests de `PulseTests` : rien n'est présenté pour le repos au premier plan, et `SessionActivityState` est bien converti en `ContentState`. Ils sont compilés par `make build-app` et lancés par Mathéo.
- [ ] **Step 2 :** créer le package, puis faire l'assemblage et le `pbxproj`.
- [ ] **Step 3 :** lancer `swift test --package-path Packages/PulseFeatures`, puis, hors bac à sable, `make build-app` et `make build-release`, puis `git diff --stat Pulse.xcodeproj`. Expected : vert ; codes 0 ; seules les entrées prévues changent dans le projet.
- [ ] **Step 4 :** VFT, puis commit, `project.pbxproj` compris et relu ligne à ligne :

```bash
git commit -m "feat(app): present the live session, drive its live activity and send a time-sensitive rest notification"
```

---

### Task 14 : Live Activity — écran verrouillé et Dynamic Island

Spec M4 §15.3, §15.4 ; maquettes `ios-island`, `ios-verrouille`.

**Files:**
- Create: `PulseWidgets/SessionLiveActivity.swift`, `PulseWidgets/SessionLiveActivityViews.swift`, `Packages/PulseFeatures/Sources/WidgetFeature/SessionActivityText.swift`
- Modify: `PulseWidgets/PulseWidgetsBundle.swift` (+ `SessionLiveActivity()`), `Packages/PulseFeatures/Sources/WidgetFeature/Resources/Localizable.xcstrings`
- Test: `Packages/PulseFeatures/Tests/WidgetFeatureTests/SessionActivityTextTests.swift`

**Interfaces:**
- Consumes : tâche 13 (`PulseSessionAttributes`, intentions).
- Produces :
  - `public enum SessionActivityText` (WidgetFeature, sans ActivityKit) : `restTitle` (« Repos »), `nextSetTitle` (« Série suivante »), `accessibilityLabel(title:restEndsAt:nextSet:now:)`, et les libellés des boutons (« −30 s », « +30 s », « Passer »).
  - `SessionLiveActivity: Widget`, en `ActivityConfiguration(for: PulseSessionAttributes.self)` :
    - **écran verrouillé et Dynamic Island étendue** : anneau (`ProgressView(timerInterval:)`), temps restant (`Text(timerInterval:countsDown: true)`), série suivante, et boutons `Button(intent: RestMinus30Intent())` / `RestPlus30Intent` / `SkipRestIntent`. Hors repos : titre, durée écoulée (`Text(timerInterval:)` depuis `startedAt`) et série suivante ;
    - **compact** : une icône haltère et le temps restant ;
    - **minimal** : un anneau.
    
    Rien d'autre que les champs de `ContentState` : aucune donnée de santé.

- [ ] **Step 1 à 4 :** tests des textes et de l'étiquette VoiceOver. Puis implémentation, vert, `make build-app`, `make build-release`, VFT et commit :

```bash
git commit -m "feat(widgets): show the rest timer and the next set on the lock screen and in the Dynamic Island"
```

---

### Task 15 : Test d'interface « séance complète avec arrêt forcé et reprise »

Critère de la feuille de route (spec M4 §21).

**Files:**
- Modify: `Packages/PulseFeatures/Sources/PulseServices/App/LaunchOptions.swift`, `Pulse/AppDependencies.swift`
- Create: `Pulse/Debug/UITestSeeder.swift`, `PulseUITests/LiveSessionResumeUITests.swift`
- Test: `Packages/PulseFeatures/Tests/PulseServicesTests/LaunchOptionsTests.swift`

**Interfaces:**
- Produces :
  - `LaunchOptions` gagne `storeOnDisk: Bool` (`-PulseStore disk`), `resetsStore: Bool` (`-PulseResetStore YES`) et `seed: LaunchSeed?` (`-PulseSeed onboardedPPL`), avec `public enum LaunchSeed: String { case onboardedPPL }`.
  - En **Debug** seulement, `AppDependencies.live()` traite ces options :
    - `-PulseStore disk` : magasin sur disque dans `FileManager.default.temporaryDirectory/PulseUITestStore`, ouvert par `PersistenceStack.makeContainer(directory:)`, avec les doublures du mode mémoire pour les notifications, le widget et la Live Activity ;
    - `-PulseResetStore YES` : ce dossier est effacé au lancement ;
    - `-PulseSeed onboardedPPL` : `UITestSeeder` crée, **s'il n'y a pas encore de profil**, un profil terminé et le modèle `ppl-3` adopté et actif.
  - `LiveSessionResumeUITests.testCompleteSessionSurvivesAForcedQuit()`. Lancement avec `-PulseStore disk -PulseResetStore YES -PulseSeed onboardedPPL -PulseHealthScenario goodNight -PulseNow 2026-11-02T08:00:00+01:00`, un lundi, jour de Push. Le test :
    1. touche `today.session.start` et valide `live.exercise.0.set.0.check` puis `live.exercise.0.set.1.check` ;
    2. arrête l'app (`app.terminate()`) puis la relance avec les mêmes arguments, **sans** `-PulseResetStore` ;
    3. attend `session.resume`, le touche, et vérifie que les deux séries sont validées (étiquettes) ;
    4. valide `live.exercise.0.set.2.check`, touche `live.finish`, confirme, et touche `recap.save` ;
    5. vérifie la carte « séance faite » (`today.session.done`).

- [ ] **Step 1 :** écrire les tests de `LaunchOptions` (lecture des nouveaux arguments, valeur inconnue ignorée), les voir échouer, puis implémenter.
- [ ] **Step 2 :** écrire le seeder et le test d'interface, puis les compiler par `make build-app` (build-for-testing compile `PulseUITests`). **Ne pas les exécuter.**
- [ ] **Step 3 :** VFT complète, `make test-packages` compris, puis commit :

```bash
git commit -m "test(app): cover a complete live session with a forced quit and a resume"
```

---

## Fin de M4b

- `make test-packages` vert, `swiftlint lint --strict` à 0, `make build-app` et `make build-release` réussis (hors bac à sable).
- Revue finale de toute la branche par Opus, puis une vague de corrections et sa revue.
- PR `m4b-seance-live` → `master` **seulement après l'accord explicite de Mathéo pour pousser**. La description se termine par « 🤖 Generated with [Claude Code](https://claude.com/claude-code) » et rappelle ce qui revient à Mathéo :
  - lancer `make test-app` et le test d'interface ;
  - faire une séance PPL réelle avec écran verrouillé, Live Activity, notification de repos en mode Sport, arrêt forcé et reprise ;
  - vérifier que la signature active « Time Sensitive Notifications » sur `fr.seonay.pulse` ;
  - garder des versions identiques dans les deux `Info.plist`.
