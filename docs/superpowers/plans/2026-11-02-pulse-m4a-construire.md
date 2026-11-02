# Pulse M4a — Construire : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mathéo construit son PPL dans Pulse (bibliothèque, fiche, exercice perso, éditeur de programme et de routines, incrément par exercice) et y retrouve son historique Hevy importé, avec records et charge d'entraînement.

**Architecture:** Une migration SwiftData V3 unique pose tous les champs de M4 (réglages par exercice, fourchettes par série, notes d'exercice, durées, dates des enfants), après extension de l'empreinte du schéma. Le contenu gagne neuf exercices, les exercices tenus, la recherche sans accents et la table des noms Hevy. Le moteur gagne le 1RM estimé, le tonnage et le calcul des records. `PulseServices` gagne l'annuaire des exercices (contenu et perso), l'édition de programme, l'analyse et l'import Hevy, et le recalcul des records. Une nouvelle cible `TrainFeature` porte l'onglet Séance et ses écrans. L'app assemble le tout.

**Tech Stack:** Swift 6.4 (mode de langage 6), SwiftUI, Swift Charts, SwiftData + CloudKit, Swift Testing, SwiftPM, SwiftLint, Xcode 27.0.

**Spec:** `docs/superpowers/specs/2026-11-02-pulse-m4-programmes-seance-live-design.md` (la « spec M4 », partie M4a : §1, §2, §5, §6, §7, §8.2, §9 à §13, §20, §21, §24). Elle complète `2026-10-31-pulse-v1-design.md`, `2026-10-31-pulse-m2-donnees-contenu-design.md` (modèle de données, export, contenu) et `2026-11-01-pulse-m3-onboarding-tableau-de-bord-design.md`. Référence visuelle : `maquette.html`, écrans `seance`, `biblio`, `fiche`, et `assets/maquette_v2_planche.png`.

## Global Constraints

- Xcode **27.0**, Swift **6.4**, cible **iOS 26**, `swift-tools-version: 6.2`, `swiftSettings: [.swiftLanguageMode(.v6)]` sur chaque cible. `PulseFeatures`, `PulseDesignSystem`, `PulseContent`, `PulseDomain`, `PulseRecoveryEngine` et `PulsePersistence` se testent sur macOS par `swift test`.
- **Ne jamais lancer le simulateur** : interdits `xcodebuild test`, `test-without-building`, `make test`, `make test-app`, `simctl boot|install|launch`, outils d'appareil T3. Les tests de `PulseTests` sont écrits et compilés ; Mathéo les lance.
- **Vérification de fin de tâche (VFT)**, avant chaque commit de tâche : `swift test --package-path Packages/<chaque package touché>` vert ; `swiftlint lint --strict` à 0 ; puis, **hors bac à sable du shell** (`dangerouslyDisableSandbox: true`), `make build-app` et `make build-release`, chacun jugé sur le code de sortie 0 (Xcode 27 n'affiche pas de bannière avec `-quiet`). `make build-release` lance `make check-versions` : les versions de `Pulse/Info.plist` et `PulseWidgets/Info.plist` restent identiques.
- SwiftLint strict, avertissements = erreurs : **≤ 400 lignes par fichier**, **≤ 50 lignes par corps de fonction**, lignes ≤ 140, imports triés, pas de `!` hors tests.
- `PulseFeatures` (toutes cibles) ne dépend jamais de `PulsePersistence`, `PulseHealth`, `SwiftData`, `HealthKit`, `ActivityKit` ni `WidgetKit`. Chaque dépendance importée est déclarée dans le manifeste (pas d'import transitif).
- Aucune logique ne lit `Date()`, `Date.now` ni `Calendar.current` : heure injectée (`now`), calendrier injecté. Exception existante : les `deletedAt = Date()` des réconciliations d'enfants dans `PulsePersistence`, inchangés. Tests : grégorien `Europe/Paris`, locale `fr_FR` ; bornes horaires par `calendar.date(bySettingHour:…)`.
- Chaînes visibles en français. Dans un package : `String(localized: "…", bundle: .module)` et `Text(String(localized: "…", bundle: .module))`. Toute cible qui a des chaînes a `Resources/Localizable.xcstrings`.
- **Aucune donnée de santé brute** dans un journal, un `print` ou une vue hors de l'app. **L'export Hevy réel de Mathéo n'est jamais commité** ni recopié dans un test, un journal ou une PR. Il peut être lu localement pour régler la table des noms et les mots-clés : `/Users/seonay/.t3/userdata/attachments/mcp-01e8ded7-3d65-4f4d-b280-6b4e89238509-101a0bf9-1319-48e5-b7d5-15cc7752bbb2-csv.csv` (copie dans `~/Downloads/workout_data.csv`), lu par `python3 -I` avec le chemin en argument.
- Tout `#Preview` qui utilise une aide `#if DEBUG` est lui-même sous `#if DEBUG`.
- Accessibilité : étiquette VoiceOver sur chaque contrôle ; Dynamic Type jusqu'à « Accessibilité XL » ; cibles ≥ 44 pt ; « Réduire les animations » respecté.
- Projet à dossiers synchronisés : tout fichier sous `Pulse/`, `PulseTests/`, `PulseUITests/`, `PulseWidgets/` est compilé sans toucher au `pbxproj`. Le `pbxproj` n'est modifié qu'en tâche 13 (produit `TrainFeature`), à la main. Ailleurs, Xcode le réécrit pendant les builds : `git restore Pulse.xcodeproj/project.pbxproj` avant chaque commit, sauf en tâche 13.
- **Checkout partagé avec Mathéo.** Avant chaque commit : `git branch --show-current` doit afficher `m4-programmes-seance-live` (sinon s'arrêter et le signaler) et `git status --short` ne doit montrer que les fichiers de la tâche, plus `.agents/`, `.gemini/` et `Pulse/Localizable.xcstrings` de Mathéo, qu'on ne touche pas. On ajoute par chemin explicite, jamais `git add -A` ni `git add .` ; on ne modifie jamais un commit qui n'est pas le sien. Jamais de commit sur `master`. Pas de push sans l'accord de Mathéo, et toujours `git push origin m4-programmes-seance-live`.
- Commits `type(scope): description` en anglais, **sans** trailer Co-Authored-By ni mention de Claude.
- Exécution (choix de Mathéo) : chaque tâche par un sous-agent dans son propre sous-thread T3 (`delegate_task`), TDD, relecture par tâche, revue finale de toute la branche par Opus.

## Review Focus

1. **Notes Hevy réelles** : guillemets doublés, virgules, apostrophes typographiques, émojis et retours à la ligne dans un champ entre guillemets. Le lecteur CSV garde la note entière et ne décale aucune colonne. Test en tâche 10 (`quotedFieldsWithNewlinesQuotesAndEmojiParse`).
2. **Import relancé ou interrompu** : réimporter le même fichier n'ajoute ni séance ni record ; un import coupé après quelques séances se termine au second essai sans doublon. Tests en tâche 12 (`importingTheSameExportTwiceAddsNothing`, `interruptedImportCompletesWithoutDuplicates`).
3. **Le vrai magasin V2 de Mathéo** (programme adopté avec jours et exercices, séances) : il s'ouvre en V3 avec ses relations, ses ordres et ses valeurs intacts. Les copies figées avec relations sont la partie la plus fragile de la migration. Test en tâche 3 (`v2StoreWithProgramAndSessionsOpensAsV3`).
4. **Routine supprimée alors qu'elle est placée aujourd'hui, ou programme modifié après le figement de midi** : la semaine ne garde aucun identifiant orphelin, l'accueil passe en repos sans planter, et le score figé ne change pas. Tests en tâches 8 (`removingADayClearsItFromTheWeek`) et 9 (`editedProgramAfterFreezeKeepsTheFrozenScore`).
5. **Heures Hevy au changement d'heure** : « 29 mars 2026, 02:30 » n'existe pas à Paris et « 25 oct. 2026, 02:30 » existe deux fois. L'analyse rend une date (l'heure valide suivante, la première occurrence) au lieu d'échouer ou de faire planter l'import. Test en tâche 10 (`daylightSavingTimesParse`).

---

## Structure des fichiers créés ou modifiés

```
Packages/PulseDomain/Sources/PulseDomain/
  Training/SetTarget.swift, Training/ExerciseNote.swift, Training/ExerciseSettings.swift      (nouveaux)
  Training/Program.swift, WorkoutSession.swift, WorkoutSet.swift, UserExercise.swift          (champs V3)
  Content/Exercise.swift (tracksDuration), Export/ExportDocument.swift (exerciseSettings, avertissement Release)
  Repositories/ExerciseSettingsRepository.swift (nouveau), PersonalRecordRepository.swift (replaceAll), StoreTable.swift
Packages/PulsePersistence/
  Sources/…/Schema/PulseSchemaV2.swift (copies figées), PulseSchemaV3.swift, PulseMigrationPlan.swift, PersistenceStack.swift
  Sources/…/Models/StoredExerciseSettings.swift (nouveau) + six modèles modifiés
  Sources/…/Repositories/SwiftDataExerciseSettingsRepository.swift (nouveau), SwiftDataPersonalRecordRepository.swift
  Sources/…/Export/*, Erase/StoreWiper.swift, Repositories/SwiftDataStoreInspector.swift
  Tests/…/Support/SchemaFingerprint.swift, Fixtures/schema-v1.txt, schema-v2.txt, schema-v3.txt, MigrationTests.swift …
Packages/PulseContent/
  Sources/PulseContent/Resources/exercises.json (+9, tracksDuration), hevy-exercises.json (nouveau)
  Sources/PulseContent/MuscleGroup.swift, SearchText.swift (nouveaux), ContentLibrary.swift, ContentValidator.swift
Packages/PulseRecoveryEngine/Sources/PulseRecoveryEngine/Records/OneRepMax.swift, SessionTonnage.swift, RecordBook.swift
Packages/PulseFeatures/
  Package.swift (cible TrainFeature et TrainFeatureTests)
  Sources/PulseServices/Exercises/  ExerciseInfo, ExerciseDirectory, ExerciseBrowser, RecentExercises, IncrementResolver
  Sources/PulseServices/Program/    ProgramEditor, RoutineEditor, RoutineRules, RoutineFromSession
  Sources/PulseServices/Import/     CSVReader, HevyRow, HevyDate, HevyCSV, HevyWorkout, HevyNameGuesser, HevyMappingChoice,
                                    HevyImportPlanner, HevySessionBuilder, HevyMappingStore, HevyImporter
  Sources/PulseServices/Records/    RecordsService
  Sources/PulseServices/Doubles/    InMemoryTrainingRepositories.swift
  Sources/PulseServices/Score/DailyScoreService.swift, Refresh/DayRefresher.swift, Today/SessionSummary.swift
  Sources/TrainFeature/             TrainEnvironment, TrainModel, Library/, Sheet/, CustomExercise/, Editor/, History/, Import/, Views/
  Tests/TrainFeatureTests/
Pulse/AppDependencies.swift, Root/MainTabView.swift, Root/AppRootModel.swift, Root/AppRootView.swift (selon le passage du modèle)
Pulse.xcodeproj/project.pbxproj, Pulse.xcodeproj/xcshareddata/xcschemes/Pulse.xcscheme   (tâche 13)
```

---

### Task 1 : Empreinte du schéma étendue aux options et aux relations inverses

Suite de M3b (spec M4 §6.2, §20) : à faire **avant** de toucher un modèle.

**Files:**
- Modify: `Packages/PulsePersistence/Tests/PulsePersistenceTests/Support/SchemaFingerprint.swift`, `Tests/PulsePersistenceTests/SchemaFingerprintTests.swift`
- Create: `Packages/PulsePersistence/Tests/PulsePersistenceTests/Support/FingerprintProbe.swift`
- Regenerate: `Tests/PulsePersistenceTests/Fixtures/schema-v1.txt`, `schema-v2.txt`

**Interfaces:**
- Produces : `SchemaFingerprint.lines(_:)` écrit, pour un attribut qui a des options, ` [options: …]` à la fin (options triées, décrites par `String(describing:)`) ; pour une relation, ` [to-one|to-many, <deleteRule>, inverse: <nom>]` (`inverse: none` sans inverse). Les tâches 3 et 4 régénèrent et comparent avec ce format.

- [ ] **Step 1 : Écrire les tests qui échouent**

```swift
@Test func fingerprintNamesTheInverseOfEachRelationship() {
    let lines = SchemaFingerprint.lines(Schema(versionedSchema: PulseSchemaV2.self))
    #expect(lines.contains { $0.hasPrefix("StoredProgram.days -> StoredRoutineDay") && $0.contains("inverse: program") })
    #expect(lines.contains { $0.hasPrefix("StoredRoutineDay.program -> StoredProgram") && $0.contains("inverse: days") })
    #expect(lines.contains { $0.hasPrefix("StoredWorkoutSession.sets -> StoredWorkoutSet") && $0.contains("inverse: session") })
}

@Test func fingerprintListsAttributeOptions() {
    let lines = SchemaFingerprint.lines(Schema([FingerprintProbe.self]))
    #expect(lines.contains { $0.hasPrefix("FingerprintProbe.blob:") && $0.contains("externalStorage") })
}
```

`FingerprintProbe` : un `@Model` de test, avec `var id = UUID()` et `@Attribute(.externalStorage) var blob: Data?`.

- [ ] **Step 2 : Lancer, vérifier l'échec**

Run : `swift test --package-path Packages/PulsePersistence --filter SchemaFingerprintTests`
Expected : FAIL sur les deux nouveaux tests ; les deux tests d'empreinte existants passent encore.

- [ ] **Step 3 : Étendre `SchemaFingerprint.lines(_:)`** avec `attribute.options` et le nom de la relation inverse (`relationship.inverseName`, ou le dernier composant de `inverseKeyPath`).

- [ ] **Step 4 : Régénérer les références V1 et V2 et vérifier leur contenu**

Run : `PULSE_WRITE_SCHEMA_FIXTURES=1 swift test --package-path Packages/PulsePersistence --filter SchemaFingerprintTests`, puis `git diff --stat Packages/PulsePersistence/Tests/PulsePersistenceTests/Fixtures`, puis `swift test --package-path Packages/PulsePersistence`.
Expected : seules les lignes de relation changent (suffixe `inverse:`), aucune ligne n'apparaît ni ne disparaît (`git diff` : autant de lignes retirées qu'ajoutées), et le paquet entier est vert. Le test `v2OnlyAddsTheTwoM3Fields` reste vert.

- [ ] **Step 5 : VFT, puis commit**

```bash
git add Packages/PulsePersistence/Tests/PulsePersistenceTests/Support/SchemaFingerprint.swift \
  Packages/PulsePersistence/Tests/PulsePersistenceTests/Support/FingerprintProbe.swift \
  Packages/PulsePersistence/Tests/PulsePersistenceTests/SchemaFingerprintTests.swift \
  Packages/PulsePersistence/Tests/PulsePersistenceTests/Fixtures/schema-v1.txt \
  Packages/PulsePersistence/Tests/PulsePersistenceTests/Fixtures/schema-v2.txt
git commit -m "test(persistence): fingerprint attribute options and relationship inverses"
```

---

### Task 2 : Domaine — types et champs de M4

**Files:**
- Create: `Packages/PulseDomain/Sources/PulseDomain/Training/SetTarget.swift`, `Training/ExerciseNote.swift`, `Training/ExerciseSettings.swift`
- Modify: `Training/Program.swift`, `Training/WorkoutSession.swift`, `Training/WorkoutSet.swift`, `Training/UserExercise.swift`, `Content/Exercise.swift`, `Export/ExportDocument.swift`
- Test: `Packages/PulseDomain/Tests/PulseDomainTests/M4TrainingTypesTests.swift`

**Interfaces:**
- Produces (tous `Sendable, Equatable, Codable`) :
  - `public struct SetTarget { public var repsMin: Int; public var repsMax: Int }`.
  - `RoutineExercise.setTargets: [SetTarget]?`, paramètre d'init `setTargets: [SetTarget]? = nil` en dernier. `public func repRange(forSet index: Int) -> ClosedRange<Int>` (index à partir de 0) : `setTargets[index]` s'il existe, sinon `repsMin...repsMax`.
  - `public struct ExerciseNote { public var exercise: ExerciseReference; public var text: String }`.
  - `WorkoutSession.exerciseNotes: [ExerciseNote]`, paramètre d'init `exerciseNotes: [ExerciseNote] = []` placé juste avant `sets:`.
  - `WorkoutSet.durationSeconds: Int?`, paramètre d'init `durationSeconds: Int? = nil` placé après `actualReps:`.
  - `SessionSource.hevy` (nouveau cas, après `appleHealth`).
  - `UserExercise.loadKind: LoadKind`, `isCompound: Bool`, `tracksDuration: Bool`, paramètres d'init `loadKind: LoadKind = .external, isCompound: Bool = false, tracksDuration: Bool = false` placés après `defaultRestSeconds:`.
  - `Exercise.tracksDuration: Bool` (décodé par `decodeIfPresent`, défaut `false`), paramètre d'init `tracksDuration: Bool = false` après `riskAreas:`.
  - `public struct ExerciseSettings: Identifiable { id: UUID; exercise: ExerciseReference; incrementKg: Double?; warmupSetCount: Int?; createdAt: Date; updatedAt: Date }`, init avec `id: UUID = UUID()`.
  - `ExportDocument.exerciseSettings: [ExerciseSettings]`, paramètre d'init `exerciseSettings: [ExerciseSettings] = []` placé après `userExercises:` ; `empty(…)` le met à `[]`.
- Les autres packages compilent sans changement grâce aux valeurs par défaut.

- [ ] **Step 1 : Écrire les tests qui échouent**

```swift
@Test func repRangeUsesThePerSetTargetWhenPresent() {
    var exercise = RoutineExercise(order: 0, exercise: .content(id: "bench-press-barbell"), sets: 3, repsMin: 4, repsMax: 12,
                                   targetRPE: 8, restSeconds: 120)
    #expect(exercise.repRange(forSet: 2) == 4...12)
    exercise.setTargets = [SetTarget(repsMin: 10, repsMax: 12), SetTarget(repsMin: 4, repsMax: 6), SetTarget(repsMin: 4, repsMax: 6)]
    #expect(exercise.repRange(forSet: 0) == 10...12)
    #expect(exercise.repRange(forSet: 1) == 4...6)
    #expect(exercise.repRange(forSet: 5) == 4...12)
}

@Test func exerciseWithoutTracksDurationDecodesAsReps() throws {
    // JSON d'un exercice du contenu sans la clé tracksDuration (format du contenu 1.1.0).
    let exercise = try JSONDecoder().decode(Exercise.self, from: Data(Fixtures.benchPressJSON.utf8))
    #expect(exercise.tracksDuration == false)
}

@Test func m4TypesRoundTripThroughJSON() throws {
    let note = ExerciseNote(exercise: .content(id: "pec-deck-machine"), text: "Siège cran 4")
    let settings = ExerciseSettings(exercise: .user(id: UUID()), incrementKg: 3.5, warmupSetCount: 0, createdAt: .t0, updatedAt: .t0)
    #expect(try roundTrip(note) == note)
    #expect(try roundTrip(settings) == settings)
    #expect(SessionSource(rawValue: "hevy") == .hevy)
}
```

`Fixtures.benchPressJSON` : l'entrée `bench-press-barbell` de la spec M2 §4.1, sans `tracksDuration`. `roundTrip` encode puis décode avec `JSONEncoder`/`JSONDecoder`. `.t0` : la date fixe déjà utilisée par les tests du domaine (sinon `Date(timeIntervalSince1970: 1_794_700_000)`).

- [ ] **Step 2 : Lancer, vérifier l'échec**

Run : `swift test --package-path Packages/PulseDomain`
Expected : FAIL à la compilation (`SetTarget`, `ExerciseNote`, `ExerciseSettings` inconnus).

- [ ] **Step 3 : Ajouter les types et les champs selon les Interfaces.** Corriger aussi l'avertissement Release de `ExportCoding.encoder(timeZone:)` et `decoder()` (`ExportDocument.swift:81` et `:93`) : `ISO8601DateFormatter` n'est pas `Sendable` et il est capturé par une fermeture `@Sendable`. On crée le formateur dans la fermeture, ou on l'enveloppe dans une petite boîte `@unchecked Sendable` immuable, comme `CSVFormat` dans `PulsePersistence`.

- [ ] **Step 4 : Lancer, vérifier le succès**

Run : `swift test --package-path Packages/PulseDomain`, puis `swift build -c release --package-path Packages/PulseDomain 2>&1 | grep -i warning`
Expected : vert ; aucune ligne d'avertissement.

- [ ] **Step 5 : VFT (tous les packages, puisque le domaine change), puis commit**

```bash
git add Packages/PulseDomain/Sources/PulseDomain/Training Packages/PulseDomain/Sources/PulseDomain/Content/Exercise.swift \
  Packages/PulseDomain/Sources/PulseDomain/Export/ExportDocument.swift Packages/PulseDomain/Tests/PulseDomainTests/M4TrainingTypesTests.swift
git commit -m "feat(domain): add per-set targets, exercise notes and settings, timed sets and the Hevy source"
```

---

### Task 3 : Persistance — schéma V3 et migration

**Files:**
- Create: `Packages/PulsePersistence/Sources/PulsePersistence/Schema/PulseSchemaV3.swift`, `Models/StoredExerciseSettings.swift`, `Tests/PulsePersistenceTests/Fixtures/schema-v3.txt`
- Modify: `Schema/PulseSchemaV2.swift` (copies figées), `Schema/PulseSchemaV1.swift` (pointe vers les copies V2), `Schema/PulseMigrationPlan.swift`, `Schema/PersistenceStack.swift`, `Models/StoredUserExercise.swift`, `StoredWorkoutSession.swift`, `StoredWorkoutSet.swift`, `StoredProgram.swift`, `StoredRoutineDay.swift`, `StoredRoutineExercise.swift`
- Test: `Tests/PulsePersistenceTests/MigrationTests.swift`, `SchemaFingerprintTests.swift`, `TrainingMappingTests.swift`, `Support/TestContainer.swift` (échantillons)

**Interfaces:**
- Consumes : tâche 2 (champs du domaine), tâche 1 (format d'empreinte).
- Produces :
  - `@Model public final class StoredExerciseSettings` : `id: UUID = UUID()`, `contentExerciseID: String?`, `userExerciseID: UUID?`, `incrementKg: Double?`, `warmupSetCount: Int?`, `createdAt: Date = Date()`, `updatedAt: Date = Date()`, `deletedAt: Date?` ; `init(_ settings: ExerciseSettings)`, `apply(_:)`, `toDomain() -> ExerciseSettings`. Ajouté à `PersistenceStack.syncedModels`.
  - Nouveaux attributs : `StoredUserExercise.loadKind: String = LoadKind.external.rawValue`, `isCompound: Bool = false`, `tracksDuration: Bool = false` ; `StoredWorkoutSession.exerciseNotes: Data?` ; `StoredWorkoutSet.durationSeconds: Int?`, `createdAt: Date = Date()`, `updatedAt: Date = Date()` ; `StoredRoutineDay.createdAt`, `updatedAt` ; `StoredRoutineExercise.setTargets: Data?`, `createdAt`, `updatedAt`. Les dates des enfants n'existent qu'en stockage : à la création, `createdAt = updatedAt =` le `updatedAt` du parent ; à chaque `apply` du parent, l'enfant mis à jour reçoit le `updatedAt` du parent.
  - `PulseSchemaV3` (`Schema.Version(3, 0, 0)`, modèles = `syncedModels + localModels`). `PulseSchemaV2.models` remplace les six modèles modifiés par leurs copies figées `PulseSchemaV2.StoredProgram`, `.StoredRoutineDay`, `.StoredRoutineExercise`, `.StoredUserExercise`, `.StoredWorkoutSession`, `.StoredWorkoutSet` (champs de `d8ad52a`, relations entre copies figées, `init()` vide, commentaire « Copie figée … en V2 (d8ad52a) : ne pas modifier »). `PulseSchemaV1.models` utilise ces mêmes copies figées V2 pour les six modèles, qui n'avaient pas changé entre V1 et V2.
  - `PulseMigrationPlan` : schémas `[V1, V2, V3]`, étapes légères V1 → V2 et V2 → V3. `PersistenceStack.makeContainer` ouvre `PulseSchemaV3`.

- [ ] **Step 1 : Écrire les tests qui échouent**

```swift
@Test func v3SchemaMatchesItsFingerprint() throws {
    try checkFingerprint(of: Schema(versionedSchema: PulseSchemaV3.self), against: "schema-v3")
}

@Test func v3OnlyAddsTheM4Fields() {
    let v2 = Set(SchemaFingerprint.lines(Schema(versionedSchema: PulseSchemaV2.self)))
    let v3 = Set(SchemaFingerprint.lines(Schema(versionedSchema: PulseSchemaV3.self)))
    #expect(v2.subtracting(v3).isEmpty)
    let added = v3.subtracting(v2).compactMap { $0.split(separator: ":").first.map(String.init) }.filter { !$0.contains(" -> ") }
    #expect(Set(added) == [
        "StoredExerciseSettings.contentExerciseID", "StoredExerciseSettings.createdAt", "StoredExerciseSettings.deletedAt",
        "StoredExerciseSettings.id", "StoredExerciseSettings.incrementKg", "StoredExerciseSettings.updatedAt",
        "StoredExerciseSettings.userExerciseID", "StoredExerciseSettings.warmupSetCount",
        "StoredRoutineDay.createdAt", "StoredRoutineDay.updatedAt",
        "StoredRoutineExercise.createdAt", "StoredRoutineExercise.setTargets", "StoredRoutineExercise.updatedAt",
        "StoredUserExercise.isCompound", "StoredUserExercise.loadKind", "StoredUserExercise.tracksDuration",
        "StoredWorkoutSession.exerciseNotes",
        "StoredWorkoutSet.createdAt", "StoredWorkoutSet.durationSeconds", "StoredWorkoutSet.updatedAt"
    ])
}

@Test func v2StoreWithProgramAndSessionsOpensAsV3() async throws {
    // Magasin V2 sur disque (copies figées PulseSchemaV2) : un programme de 2 jours × 3 exercices (dont un super set),
    // une séance de 9 séries, un exercice perso. Ouvert par PersistenceStack.makeContainer(directory:).
    let program = try #require(try await SwiftDataProgramRepository(modelContainer: container).programs(includeArchived: false).first)
    #expect(program.days.map(\.name) == ["Jour 1", "Jour 2"])
    #expect(program.days[0].exercises.map(\.order) == [0, 1, 2])
    #expect(program.days[0].exercises[1].supersetGroup == 1)
    #expect(program.days[0].exercises.allSatisfy { $0.setTargets == nil })
    let session = try #require(try await SwiftDataWorkoutRepository(modelContainer: container).sessions(from: .distantPast, to: .distantFuture).first)
    #expect(session.sets.count == 9)
    #expect(session.exerciseNotes.isEmpty)
    #expect(session.sets.allSatisfy { $0.durationSeconds == nil })
    let user = try #require(try await SwiftDataUserExerciseRepository(modelContainer: container).all(includeArchived: false).first)
    #expect(user.loadKind == .external && user.isCompound == false && user.tracksDuration == false)
}
```

Garder `v1StoreOpensAsV2KeepingData` en le renommant `v1StoreOpensAsV3KeepingData` ; son `writeV1Store` utilise maintenant les copies figées V2 pour les six modèles. Étendre les tests d'aller-retour de `TrainingMappingTests` aux nouveaux champs : `setTargets`, `exerciseNotes`, `durationSeconds`, `loadKind`/`isCompound`/`tracksDuration` renseignés (`.assisted`, `true`, `true`), et `ExerciseSettings`, tout rempli puis tout à `nil`.

- [ ] **Step 2 : Lancer, vérifier l'échec**

Run : `swift test --package-path Packages/PulsePersistence`
Expected : FAIL (`PulseSchemaV3` inconnu).

- [ ] **Step 3 : Figer les copies V2, ajouter les attributs et `StoredExerciseSettings`, déclarer V3 et l'étape de migration.** Écrire `schema-v3.txt` avec `PULSE_WRITE_SCHEMA_FIXTURES=1 swift test --package-path Packages/PulsePersistence --filter v3SchemaMatchesItsFingerprint`.

- [ ] **Step 4 : Lancer, vérifier le succès**

Run : `swift test --package-path Packages/PulsePersistence`, puis `git diff Packages/PulsePersistence/Tests/PulsePersistenceTests/Fixtures/schema-v1.txt Packages/PulsePersistence/Tests/PulsePersistenceTests/Fixtures/schema-v2.txt`
Expected : vert ; aucune différence sur les références V1 et V2 (elles sont figées).

- [ ] **Step 5 : VFT, puis commit**

```bash
git add Packages/PulsePersistence/Sources/PulsePersistence/Schema Packages/PulsePersistence/Sources/PulsePersistence/Models \
  Packages/PulsePersistence/Tests/PulsePersistenceTests/Fixtures/schema-v3.txt Packages/PulsePersistence/Tests/PulsePersistenceTests/MigrationTests.swift \
  Packages/PulsePersistence/Tests/PulsePersistenceTests/SchemaFingerprintTests.swift Packages/PulsePersistence/Tests/PulsePersistenceTests/TrainingMappingTests.swift \
  Packages/PulsePersistence/Tests/PulsePersistenceTests/Support/TestContainer.swift
git commit -m "feat(persistence): add schema V3 with exercise settings, per-set targets, notes, timed sets and child dates"
```

---

### Task 4 : Persistance — dépôt des réglages, records remplacés, export et effacement

**Files:**
- Create: `Packages/PulseDomain/Sources/PulseDomain/Repositories/ExerciseSettingsRepository.swift`, `Packages/PulsePersistence/Sources/PulsePersistence/Repositories/SwiftDataExerciseSettingsRepository.swift`
- Modify: `PulseDomain/…/Repositories/PersonalRecordRepository.swift`, `StoreTable.swift` ; `PulsePersistence/…/Repositories/SwiftDataPersonalRecordRepository.swift`, `SwiftDataStoreInspector.swift`, `Erase/StoreWiper.swift`, `Export/ExportSnapshotLoader.swift`, `JSONExportWriter.swift`, `CSVTables.swift`, `CSVColumns+Training.swift`, `Sample/SampleDataSeeder.swift`
- Test: `Tests/PulsePersistenceTests/ExerciseSettingsRepositoryTests.swift`, `PersonalRecordRepositoryTests.swift`, `JSONExportTests.swift`, `CSVExportTests.swift`, `EraserTests.swift`, `StoreInspectorTests.swift`

**Interfaces:**
- Produces :
  - `public protocol ExerciseSettingsRepository: Sendable { func all() async throws -> [ExerciseSettings]; func settings(for exercise: ExerciseReference) async throws -> ExerciseSettings?; func save(_ settings: ExerciseSettings) async throws }`. `settings(for:)` rend le plus récent par `updatedAt` quand il y en a plusieurs (restauration iCloud). `save` remplace l'enregistrement actif du même exercice : il le met à jour et garde son `id`.
  - `PersonalRecordRepository.replaceAll(with records: [PersonalRecord]) async throws` : un record dont la clé (`setID`, `kind`, `weightKg`) existe déjà garde son enregistrement (même `id`, valeurs mises à jour) ; les absents sont supprimés logiquement ; les nouveaux sont insérés. Un seul `save()` à la fin. On évite ainsi de recréer des centaines d'enregistrements CloudKit à chaque recalcul.
  - `StoreTable.exerciseSettings` (après `.userExercises`, exportée, fichier `exercise_settings.csv`).
  - `public actor SwiftDataExerciseSettingsRepository: ExerciseSettingsRepository` (`@ModelActor`).
  - Export : `exerciseSettings` dans `ExportSnapshot`, le JSON et le CSV (colonnes `id, content_exercise_id, user_exercise_id, increment_kg, warmup_set_count, created_at, updated_at`) ; colonnes ajoutées : `workout_sessions.exercise_notes` (JSON), `workout_sets.duration_seconds`, `routine_exercises.set_targets` (JSON), `user_exercises.load_kind`, `is_compound`, `tracks_duration`. `schemaVersion` de l'export = `PulseSchemaV3.versionIdentifier.major` (aujourd'hui `PulseSchemaV1` par erreur). Description README : « réglages par exercice (incrément, échauffement) ». `StoreWiper` efface `StoredExerciseSettings` ; l'inspecteur la compte.

- [ ] **Step 1 : Écrire les tests qui échouent**

```swift
@Test func settingsAreReplacedPerExercise() async throws {
    let repo = SwiftDataExerciseSettingsRepository(modelContainer: try TestContainer.make())
    let cable = ExerciseReference.content(id: "triceps-pushdown-cable")
    try await repo.save(ExerciseSettings(exercise: cable, incrementKg: 2.5, warmupSetCount: nil, createdAt: Fixed.t0, updatedAt: Fixed.t0))
    try await repo.save(ExerciseSettings(exercise: cable, incrementKg: 3.5, warmupSetCount: nil, createdAt: Fixed.t1, updatedAt: Fixed.t1))
    #expect(try await repo.all().count == 1)
    #expect(try await repo.settings(for: cable)?.incrementKg == 3.5)
    #expect(try await repo.settings(for: .content(id: "pec-deck-machine")) == nil)
}

@Test func replaceAllKeepsMatchingRecordsAndRetiresTheRest() async throws {
    // Trois records (setID A maxWeight, setID A e1RM, setID B maxWeight) puis replaceAll avec A maxWeight (valeur 75) et C repsAtWeight.
    let after = try await repo.records(for: nil)
    #expect(after.count == 2)
    #expect(after.first { $0.setID == setA && $0.kind == .maxWeight }?.id == originalAMaxWeightID)
    #expect(after.first { $0.setID == setA && $0.kind == .maxWeight }?.value == 75)
    #expect(after.contains { $0.setID == setC && $0.kind == .repsAtWeight })
}

@Test func exportCarriesExerciseSettingsAndTheV3Fields() async throws {
    // Jeu d'exemple + un ExerciseSettings + une séance avec exerciseNotes et une série durationSeconds = 45.
    let document = try decodeExportedJSON()
    #expect(document.schemaVersion == 3)
    #expect(document.exerciseSettings.count == 1)
    #expect(document.workoutSessions.flatMap(\.sets).contains { $0.durationSeconds == 45 })
    let csv = try exportedCSV()
    #expect(csv[.exerciseSettings]?.header == ["id", "content_exercise_id", "user_exercise_id", "increment_kg", "warmup_set_count",
                                               "created_at", "updated_at"])
}
```

Compléter `EraserTests` (la table `exerciseSettings` est vide après l'effacement) et `StoreInspectorTests` (la table est comptée).

- [ ] **Step 2 : Lancer, vérifier l'échec**

Run : `swift test --package-path Packages/PulsePersistence`
Expected : FAIL à la compilation.

- [ ] **Step 3 : Implémenter selon les Interfaces.** Le jeu d'exemple (`SampleDataSeeder`) gagne un `ExerciseSettings`.

- [ ] **Step 4 : Lancer, vérifier le succès**

Run : `swift test --package-path Packages/PulseDomain && swift test --package-path Packages/PulsePersistence`
Expected : vert.

- [ ] **Step 5 : VFT, puis commit**

```bash
git add Packages/PulseDomain/Sources/PulseDomain/Repositories Packages/PulsePersistence/Sources Packages/PulsePersistence/Tests
git commit -m "feat(persistence): store exercise settings, replace records in place and export the V3 fields"
```

---

### Task 5 : Contenu — neuf exercices, exercices tenus, groupes, recherche, noms Hevy

**Files:**
- Modify: `Packages/PulseContent/Sources/PulseContent/Resources/exercises.json`, `ContentLibrary.swift`, `ContentValidator.swift`, `ExerciseRules.swift`, `ContentEnums+Localized.swift`, `Resources/Localizable.xcstrings`, `Package.swift`
- Create: `Sources/PulseContent/Resources/hevy-exercises.json`, `Sources/PulseContent/MuscleGroup.swift`, `Sources/PulseContent/SearchText.swift`
- Test: `Tests/PulseContentTests/BundledExercisesTests.swift`, `ContentLibraryTests.swift`, `Tests/PulseContentTests/HevyNamesTests.swift`, `SearchTextTests.swift`, `MuscleGroupTests.swift`, `Support/Fixtures.swift`

**Interfaces:**
- Produces :
  - `exercises.json` : `contentVersion` `1.2.0` ; `tracksDuration: true` sur `plank`, `side-plank`, `copenhagen-plank` ; neuf exercices (spec M4 §7.3), avec les valeurs suivantes. Les consignes (3, ≤ 90 caractères) et les erreurs (2 ou 3) sont rédigées par l'implémenteur, en français, dans le ton du contenu existant.

| id | name fr / en | primary | secondary | equipment | pattern | region | compound | loadKind | incr. | repos | alternatives | riskAreas |
| :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- |
| `assisted-dips-machine` | Dips assistés à la machine / Assisted Dip Machine | triceps, chest | frontDelts | machine | elbowExtension | upper | oui | assisted | 2.5 | 90 | dips, triceps-extension-machine, close-grip-bench-press | shoulders |
| `close-grip-lat-pulldown-cable` | Tirage vertical prise serrée à la poulie / Close-Grip Lat Pulldown | lats | biceps, upperBack | cable | verticalPull | upper | oui | external | 2.5 | 90 | lat-pulldown-cable, lat-pulldown-machine, assisted-pull-up-machine | — |
| `dumbbell-curl` | Curl aux haltères / Dumbbell Curl | biceps | forearms | dumbbell | elbowFlexion | upper | non | external | 2.5 | 60 | hammer-curl-dumbbell, cable-curl, preacher-curl-machine | — |
| `rope-pushdown-cable` | Extension triceps à la corde / Rope Triceps Pushdown | triceps | — | cable | elbowExtension | upper | non | external | 2.5 | 60 | triceps-pushdown-cable, overhead-triceps-extension-cable, triceps-extension-machine | — |
| `triceps-extension-machine` | Extension triceps à la machine / Machine Triceps Extension | triceps | — | machine | elbowExtension | upper | non | external | 2.5 | 60 | triceps-pushdown-cable, rope-pushdown-cable, assisted-dips-machine | — |
| `decline-chest-press-machine` | Développé décliné à la machine / Decline Chest Press Machine | chest | triceps, frontDelts | machine | horizontalPush | upper | oui | external | 2.5 | 90 | chest-press-machine, incline-chest-press-machine, bench-press-dumbbell | — |
| `back-extension-machine` | Extension du dos à la machine / Back Extension Machine | lowerBack | glutes, hamstrings | machine | hinge | lower | non | external | 2.5 | 90 | hyperextension, romanian-deadlift-dumbbell, hip-thrust-barbell | lowerBack |
| `hyperextension` | Hyperextension lestée / Weighted Back Extension | lowerBack | glutes, hamstrings | bodyweight | hinge | lower | non | bodyweight | 2.5 | 90 | back-extension-machine, romanian-deadlift-dumbbell, single-leg-romanian-deadlift | lowerBack |
| `seated-wrist-curl-dumbbell` | Flexion des poignets assis aux haltères / Seated Dumbbell Wrist Curl | forearms | — | dumbbell | forearm | upper | non | external | 1.25 | 60 | wrist-curl-cable, wrist-curl-barbell, reverse-wrist-curl-barbell | wrists |

  - `ContentValidator.expectedExerciseCount = 93`.
  - `hevy-exercises.json` : `{"schemaVersion": 1, "names": {"<nom Hevy>": "<id>", …}}`, avec les lignes de la spec M4 §7.2 et §7.3. L'implémenteur peut y ajouter d'autres noms standards de Hevy, seulement quand l'équivalence est sûre.
  - `ContentLibrary` gagne `public let hevyNames: [String: String]` (clés repliées par `SearchText.fold`), un paramètre d'init `hevyNames: [String: String] = [:]`, et `public func exerciseID(forHevyName name: String) -> String?`. `load(from:)` lit `hevy-exercises.json`.
  - `public enum SearchText { public static func fold(_ text: String) -> String }` : minuscules, sans diacritiques (locale `fr_FR`), ponctuation et tirets remplacés par une espace, espaces multiples réduites, sans espaces au début ni à la fin.
  - `public enum MuscleGroup: String, Sendable, CaseIterable { case chest, back, shoulders, arms, legs, core }`, `public init(_ muscle: Muscle)` (chest → chest ; lats, upperBack, lowerBack, traps → back ; frontDelts, sideDelts, rearDelts → shoulders ; biceps, triceps, forearms → arms ; quads, hamstrings, glutes, adductors, abductors, calves, hipFlexors → legs ; abs, obliques → core), `localizedName` : Pectoraux, Dos, Épaules, Bras, Jambes, Tronc.
  - Nouvelle règle `ContentRule.hevyNames` : chaque cible de la table existe et n'est pas retirée.

- [ ] **Step 1 : Écrire les tests qui échouent**

```swift
@Test func catalogHas93ValidExercises() throws {
    let lib = try ContentLibrary.load(from: ContentLibrary.resourceBundle)
    #expect(lib.exercises.count == 93)
    #expect(lib.contentVersion == "1.2.0")
    #expect(ContentValidator.issues(in: lib).isEmpty)
    #expect(lib.exercise(id: "assisted-dips-machine")?.loadKind == .assisted)
    #expect(lib.exercise(id: "hyperextension")?.loadKind == .bodyweight)
    #expect(["plank", "side-plank", "copenhagen-plank"].allSatisfy { lib.exercise(id: $0)?.tracksDuration == true })
    #expect(lib.exercises.filter(\.tracksDuration).count == 3)
}

@Test func hevyNamesResolveWhateverTheCaseAndAccents() throws {
    let lib = try ContentLibrary.load(from: ContentLibrary.resourceBundle)
    #expect(lib.exerciseID(forHevyName: "Écarté (Machine)") == "pec-deck-machine")
    #expect(lib.exerciseID(forHevyName: "ecarte (machine)") == "pec-deck-machine")
    #expect(lib.exerciseID(forHevyName: "Dips Torse (Assisté)") == "assisted-dips-machine")
    #expect(lib.exerciseID(forHevyName: "Pull (machine)") == nil)
}

@Test func searchTextFoldsAccentsCaseAndPunctuation() {
    #expect(SearchText.fold("  Développé Couché (Barre) ") == "developpe couche barre")
    #expect(SearchText.fold("Tirage Poitrine - Prise Serrée") == "tirage poitrine prise serree")
}

@Test func everyMuscleBelongsToAGroup() {
    #expect(MuscleGroup(.traps) == .back)
    #expect(MuscleGroup(.rearDelts) == .shoulders)
    #expect(MuscleGroup(.hipFlexors) == .legs)
    #expect(MuscleGroup.allCases.allSatisfy { !$0.localizedName.isEmpty })
}
```

Mettre à jour les comptes existants : `expectCounts` passe à `horizontalPush: 7`, `verticalPull: 5`, `elbowFlexion: 6`, `elbowExtension: 8`, `forearm: 5`, `hinge: 7` ; `bundledCatalogIsCompleteAndValid` attend 93 ; `ContentLibraryTests` attend `1.2.0`.

- [ ] **Step 2 : Lancer, vérifier l'échec**

Run : `swift test --package-path Packages/PulseContent`
Expected : FAIL.

- [ ] **Step 3 : Implémenter selon les Interfaces** (ressource ajoutée au manifeste par `.process("Resources/hevy-exercises.json")`).

- [ ] **Step 4 : Lancer, vérifier le succès, et confronter la table à l'export réel**

Run : `swift test --package-path Packages/PulseContent` ; puis, avec un script de `/tmp` lancé par `python3 -I` sur l'export réel (chemin des Global Constraints), lister les noms d'exercices de l'export que la table résout et ceux qu'elle ne résout pas, sans rien écrire dans le dépôt.
Expected : vert ; chaque nom de la spec M4 §7.2 et §7.3 est résolu.

- [ ] **Step 5 : VFT (PulseContent, PulseFeatures), puis commit**

```bash
git add Packages/PulseContent
git commit -m "feat(content): add nine exercises, timed holds, muscle groups, accent-free search and the Hevy name table"
```

---

### Task 6 : Moteur — 1RM estimé, tonnage, records

**Files:**
- Create: `Packages/PulseRecoveryEngine/Sources/PulseRecoveryEngine/Records/OneRepMax.swift`, `SessionTonnage.swift`, `RecordBook.swift`
- Test: `Packages/PulseRecoveryEngine/Tests/PulseRecoveryEngineTests/RecordBookTests.swift`, `OneRepMaxTests.swift`

**Interfaces:**
- Produces :
  - `public enum OneRepMax { public static let maxReps = 12; public static func brzycki(weightKg: Double, reps: Int) -> Double? }` : `weightKg × 36 / (37 − reps)` pour `1...12` répétitions et une charge > 0, sinon `nil`.
  - `public enum SessionTonnage { public static func kilograms(of sets: [WorkoutSet], loadKind: (ExerciseReference) -> LoadKind) -> Double }` : somme de `charge × répétitions` des séries hors échauffement qui ont des répétitions ; charge externe = `actualWeightKg` ; poids du corps = lest (`actualWeightKg ?? 0`) ; assisté = 0.
  - `public enum RecordBook { public struct Result: Sendable, Equatable { public var records: [PersonalRecord]; public var recordSetIDs: Set<UUID> }; public static func compute(sessions: [WorkoutSession], loadKind: (ExerciseReference) -> LoadKind, now: Date) -> Result }`.
- Règles (spec M4 §8.2, à appliquer dans cet ordre) :
  - Séances prises : `completed` et `abandoned`, triées par `startedAt`. Séries prises : hors échauffement, avec `actualReps > 0`.
  - Pour chaque séance, et pour chaque exercice qu'elle contient, la meilleure série de la séance est comparée au meilleur des séances **précédentes**. Une seule ligne par (exercice, nature, charge pour `repsAtWeight`) et par séance.
  - Charge externe : `maxWeight` (plus lourde charge), `estimatedOneRepMax` (Brzycki), `repsAtWeight` (plus de répétitions à une charge exacte **déjà faite lors d'une séance précédente**). Poids du corps et assisté : `repsAtWeight` seulement, sur `actualWeightKg ?? 0`.
  - Un record exige un dépassement strict.
  - **Première séance d'un exercice** : ses meilleures valeurs donnent des `PersonalRecord` (base), mais ses séries n'entrent pas dans `recordSetIDs`. Aucun `repsAtWeight` à la première séance.
  - `PersonalRecord.date` = `startedAt` de la séance, `sessionID` et `setID` renseignés, `exerciseName` = celui de la série, `createdAt = updatedAt = now`.

- [ ] **Step 1 : Écrire les tests qui échouent**

```swift
@Test func brzyckiMatchesTheFormulaAndStopsAt12Reps() {
    #expect(OneRepMax.brzycki(weightKg: 70, reps: 5).map { ($0 * 100).rounded() / 100 } == 78.75)
    #expect(OneRepMax.brzycki(weightKg: 60, reps: 12) == 60 * 36 / 25)
    #expect(OneRepMax.brzycki(weightKg: 60, reps: 13) == nil)
    #expect(OneRepMax.brzycki(weightKg: 0, reps: 5) == nil)
}

@Test func tonnageSkipsWarmupsAndCountsOnlyAddedWeight() {
    // bench (externe) : É 20×10, 60×12, 70×5 ; dips assistés : 12,5×12 ; hyperextension (poids du corps) : 10×12.
    #expect(SessionTonnage.kilograms(of: sets, loadKind: kinds) == 60 * 12 + 70 * 5 + 10 * 12)
}

@Test func firstSessionSetsTheBaselineWithoutFlaggingSets() {
    let result = RecordBook.compute(sessions: [session(on: day1, bench: [(60, 12), (70, 5)])], loadKind: { _ in .external }, now: .t0)
    #expect(result.recordSetIDs.isEmpty)
    #expect(Set(result.records.map(\.kind)) == [.maxWeight, .estimatedOneRepMax])
}

@Test func heavierAndMoreRepsBeatTheirRecordsOncePerSession() {
    let result = RecordBook.compute(sessions: [
        session(on: day1, bench: [(60, 12), (70, 5)]),
        session(on: day2, bench: [(60, 12), (72.5, 5), (70, 6), (70, 7)])
    ], loadKind: { _ in .external }, now: .t0)
    let second = result.records.filter { $0.date == day2 }
    #expect(second.contains { $0.kind == .maxWeight && $0.value == 72.5 })
    #expect(second.filter { $0.kind == .repsAtWeight }.map(\.weightKg) == [70])   // 70×7, une seule ligne
    #expect(second.first { $0.kind == .repsAtWeight }?.value == 7)
    #expect(!second.contains { $0.kind == .repsAtWeight && $0.weightKg == 72.5 }) // première fois à 72,5 kg
}

@Test func assistedAndBodyweightOnlyTrackRepsAtWeight() { … }   // aucune ligne maxWeight ni e1RM
@Test func warmupsAndAbandonedSessionsFollowTheRules() { … }    // échauffement ignoré ; séance abandonnée prise en compte
@Test func equalValuesAreNotRecords() { … }                     // même charge max : pas de nouveau maxWeight
```

- [ ] **Step 2 : Lancer, vérifier l'échec** — Run : `swift test --package-path Packages/PulseRecoveryEngine` — Expected : FAIL à la compilation.

- [ ] **Step 3 : Implémenter selon les Interfaces et les règles.**

- [ ] **Step 4 : Lancer, vérifier le succès** — Run : `swift test --package-path Packages/PulseRecoveryEngine` — Expected : vert.

- [ ] **Step 5 : VFT, puis commit**

```bash
git add Packages/PulseRecoveryEngine/Sources/PulseRecoveryEngine/Records Packages/PulseRecoveryEngine/Tests/PulseRecoveryEngineTests/RecordBookTests.swift \
  Packages/PulseRecoveryEngine/Tests/PulseRecoveryEngineTests/OneRepMaxTests.swift
git commit -m "feat(engine): estimate one-rep max, sum session tonnage and compute personal records"
```

---

### Task 7 : Services — annuaire des exercices, bibliothèque, incrément, doublures

**Files:**
- Create: `Packages/PulseFeatures/Sources/PulseServices/Exercises/ExerciseInfo.swift`, `ExerciseDirectory.swift`, `ExerciseBrowser.swift`, `RecentExercises.swift`, `IncrementResolver.swift` ; `Sources/PulseServices/Doubles/InMemoryTrainingRepositories.swift`
- Modify: `Sources/PulseServices/Today/SessionSummary.swift` (exercices perso comptés), `Sources/TodayFeature/TodayEnvironment.swift`, `TodayModel.swift` et ses appelants de `SessionSummary`, `Pulse/AppDependencies.swift`, `Package.swift` si nécessaire
- Test: `Tests/PulseServicesTests/ExerciseDirectoryTests.swift`, `ExerciseBrowserTests.swift`, `IncrementResolverTests.swift`, `SessionSummaryTests.swift` (existant)

**Interfaces:**
- Consumes : tâches 2, 4, 5.
- Produces :
  - `public struct ExerciseInfo: Sendable, Equatable, Identifiable` : `reference: ExerciseReference` (`id` = `reference`), `name: String` (fr), `englishName: String?`, `primaryMuscles: [Muscle]`, `secondaryMuscles: [Muscle]`, `equipment`, `pattern`, `region`, `isCompound`, `isUnilateral`, `loadKind`, `defaultIncrementKg`, `defaultRestSeconds`, `tracksDuration`, `isActive` (non retiré, non archivé), `content: Exercise?` (consignes, erreurs, alternatives, `riskAreas` ; nul pour un exercice perso). `public var group: MuscleGroup` (groupe du premier muscle principal).
  - `public struct ExerciseDirectory: Sendable { public init(library: ContentLibrary, userExercises: [UserExercise]); public func info(_ reference: ExerciseReference) -> ExerciseInfo?; public var active: [ExerciseInfo]; public func name(of reference: ExerciseReference, fallback: String) -> String; public func loadKind(of reference: ExerciseReference) -> LoadKind }` (`.external` pour une référence inconnue).
  - `public enum ExerciseBrowser { public static func results(_ exercises: [ExerciseInfo], query: String, group: MuscleGroup?, equipment: Equipment?, recent: [ExerciseReference]) -> [ExerciseInfo] }` : recherche sur `SearchText.fold` du nom français et anglais (chaque mot de la requête doit apparaître). Ordre : récents dans l'ordre de `recent`, puis alphabétique français (`localizedStandardCompare`).
  - `public enum RecentExercises { public static func references(in sessions: [WorkoutSession], now: Date, calendar: Calendar, days: Int = 30) -> [ExerciseReference] }` : les exercices des séances des `days` derniers jours, du plus récent au plus ancien, sans doublon.
  - `public enum IncrementResolver { public static func increment(for info: ExerciseInfo, settings: ExerciseSettings?, profile: UserProfile?) -> Double }` : `settings.incrementKg` s'il est réglé, sinon `min(info.defaultIncrementKg, profil)`, où le profil donne `lowerIncrementKg` pour `region == .lower` et `upperIncrementKg` sinon ; sans profil, `info.defaultIncrementKg`.
  - `SessionSummary.make(day:directory:)` remplace `make(day:library:)`, et les exercices perso comptent dans les muscles. `TodayEnvironment` gagne `userExercises: any UserExerciseRepository` (paramètre d'init après `workouts:`) ; `TodayModel` construit son `ExerciseDirectory` à chaque rafraîchissement, et `AppDependencies.todayEnvironment()` le fournit.
  - Doublures publiques (acteurs) : `InMemoryUserExerciseRepository`, `InMemoryExerciseSettingsRepository`, `InMemoryPersonalRecordRepository` (avec `replaceAll` selon la règle de la tâche 4). `InMemoryWorkoutRepository` reste tel quel en M4a.

- [ ] **Step 1 : Écrire les tests qui échouent**

```swift
@Test func directoryResolvesContentAndUserExercises() {
    let shrug = UserExercise(name: "Shrug (Haltère)", primaryMuscle: .traps, secondaryMuscles: [], equipment: .dumbbell,
                             pattern: .shoulderIsolation, region: .upper, isUnilateral: false, defaultIncrementKg: 2.5,
                             defaultRestSeconds: 60, createdAt: .t0, updatedAt: .t0)
    let directory = ExerciseDirectory(library: .bundled, userExercises: [shrug])
    #expect(directory.info(.content(id: "pec-deck-machine"))?.name == "Écarté à la machine")
    #expect(directory.info(.user(id: shrug.id))?.group == .back)
    #expect(directory.active.count == 94)
    #expect(directory.loadKind(of: .content(id: "assisted-dips-machine")) == .assisted)
}

@Test func searchIgnoresAccentsAndPutsRecentsFirst() {
    let all = ExerciseDirectory(library: .bundled, userExercises: []).active
    let found = ExerciseBrowser.results(all, query: "developpe couche", group: nil, equipment: nil,
                                        recent: [.content(id: "bench-press-dumbbell")])
    #expect(found.first?.reference == .content(id: "bench-press-dumbbell"))
    #expect(found.contains { $0.reference == .content(id: "bench-press-barbell") })
    #expect(ExerciseBrowser.results(all, query: "", group: .arms, equipment: .cable, recent: []).allSatisfy { $0.group == .arms && $0.equipment == .cable })
}

@Test func incrementPrefersTheSettingThenTheSmallerDefault() {
    let pushdown = ExerciseDirectory(library: .bundled, userExercises: []).info(.content(id: "triceps-pushdown-cable"))!
    let advanced = UserProfile(upperIncrementKg: 1.25, lowerIncrementKg: 2.5)
    #expect(IncrementResolver.increment(for: pushdown, settings: nil, profile: advanced) == 1.25)
    #expect(IncrementResolver.increment(for: pushdown, settings: nil, profile: UserProfile()) == 2.5)
    let cable = ExerciseSettings(exercise: pushdown.reference, incrementKg: 3.5, warmupSetCount: nil, createdAt: .t0, updatedAt: .t0)
    #expect(IncrementResolver.increment(for: pushdown, settings: cable, profile: advanced) == 3.5)
}

@Test func recentExercisesComeFromTheLast30Days() { … }   // séance à J-31 ignorée, J-2 avant J-10, sans doublon
```

Ajouter à `SessionSummaryTests` un jour qui mélange un exercice du contenu et un exercice perso : les muscles de l'exercice perso comptent.

- [ ] **Step 2 : Lancer, vérifier l'échec** — Run : `swift test --package-path Packages/PulseFeatures --filter PulseServicesTests` — Expected : FAIL à la compilation.

- [ ] **Step 3 : Implémenter selon les Interfaces.**

- [ ] **Step 4 : Lancer, vérifier le succès** — Run : `swift test --package-path Packages/PulseFeatures` — Expected : vert (`TodayFeatureTests` compris).

- [ ] **Step 5 : VFT, puis commit**

```bash
git add Packages/PulseFeatures/Sources/PulseServices Packages/PulseFeatures/Sources/TodayFeature Packages/PulseFeatures/Tests/PulseServicesTests \
  Packages/PulseFeatures/Tests/TodayFeatureTests Pulse/AppDependencies.swift
git commit -m "feat(services): resolve content and custom exercises, browse the library and pick increments"
```

---

### Task 8 : Services — édition de programme et de routine, routine depuis une séance

**Files:**
- Create: `Packages/PulseFeatures/Sources/PulseServices/Program/ProgramEditor.swift`, `RoutineEditor.swift`, `RoutineRules.swift`, `RoutineFromSession.swift`
- Test: `Tests/PulseServicesTests/ProgramEditorTests.swift`, `RoutineEditorTests.swift`, `RoutineRulesTests.swift`, `RoutineFromSessionTests.swift`

**Interfaces:**
- Consumes : tâches 2 et 7.
- Produces (fonctions pures ; chacune rend une copie modifiée avec `updatedAt = now` sur le programme) :
  - `public enum ProgramEditor` :
    - `emptyProgram(name: String, now: Date) -> Program` (aucun jour, `weekLayout` de 7 `nil`, `sessionsPerWeek` 0) ;
    - `assign(_ dayID: UUID?, to weekday: Weekday, in program: Program, now: Date) -> Program` ;
    - `addDay(named: String, exercises: [RoutineExercise], to program: Program, now: Date) -> (program: Program, dayID: UUID)` ;
    - `replaceDay(_ day: RoutineDay, in program: Program, now: Date) -> Program` ;
    - `removeDay(id: UUID, from program: Program, now: Date) -> Program` (retire aussi le jour de `weekLayout` et renumérote `order`) ;
    - `duplicateDay(id: UUID, in program: Program, now: Date) -> Program` (nom suffixé « (copie) », nouveaux identifiants) ;
    - `rename(_ program: Program, to name: String, now: Date) -> Program`.
    `sessionsPerWeek` est **toujours** recalculé : nombre d'entrées non nulles de `weekLayout`.
  - `public enum RoutineEditor` :
    - `add(_ references: [ExerciseReference], to day: RoutineDay, directory: ExerciseDirectory) -> RoutineDay` : valeurs par défaut 3 séries, 8 à 12 répétitions (30 à 60 s pour un exercice tenu), RPE 8, repos `defaultRestSeconds` ;
    - `move(fromOffsets: IndexSet, toOffset: Int, in day: RoutineDay) -> RoutineDay` ;
    - `remove(at index: Int, from day: RoutineDay) -> RoutineDay` ;
    - `toggleSuperset(at index: Int, in day: RoutineDay) -> RoutineDay` : apparie l'exercice `index` et `index + 1`, ou défait la paire. Un exercice déjà en paire ne peut pas entrer dans une autre.
    - `setSets(_ count: Int, at index: Int, in day: RoutineDay) -> RoutineDay` : garde `setTargets` à `count` entrées, en répétant la dernière.
    - `setPerSetTargets(_ enabled: Bool, at index: Int, in day: RoutineDay) -> RoutineDay` : activé, chaque série reçoit la fourchette de l'exercice ; désactivé, `setTargets = nil` et la fourchette de l'exercice devient min…max des séries.
    - `updateSetTarget(_ target: SetTarget, set: Int, at index: Int, in day: RoutineDay) -> RoutineDay` : tient `repsMin`/`repsMax` de l'exercice égaux au min/max des séries.
    Après chaque opération : `order` renuméroté de 0 à n−1 ; groupes de super set renumérotés de 1 à k dans l'ordre ; une paire qui n'est plus consécutive est défaite.
  - `public enum RoutineRules { public static let sets = 1...10; reps = 1...30; seconds = 5...600; rpe = 6.0...10.0 (pas 0,5); rest = 0...300 (pas 15); public static func issues(in exercise: RoutineExercise, tracksDuration: Bool) -> [RoutineIssue] }` avec `public enum RoutineIssue: Sendable, Equatable { case sets, reps, rpe, rest, setTargets }` (`setTargets` : nombre ≠ `sets`, ou fourchette inversée).
  - `public enum RoutineFromSession { public static func day(from session: WorkoutSession, directory: ExerciseDirectory, order: Int) -> RoutineDay }` (spec M4 §12) : nom = titre de la séance ; exercices dans l'ordre de première apparition ; `sets` = séries hors échauffement ; super sets repris par paires consécutives ; si l'écart entre le plus petit et le plus grand nombre de répétitions dépasse 3, une fourchette par série `max(1, r − 2)…r` quand `r ≥ 10`, et `max(1, r − 1)…r + 1` sinon ; sinon une seule fourchette `min…max`, élargie vers le bas jusqu'à 4 répétitions d'écart (plancher 1) ; RPE 8 ; repos par défaut de l'exercice ; un exercice tenu prend les secondes au lieu des répétitions.

- [ ] **Step 1 : Écrire les tests qui échouent**

```swift
@Test func matheoWeekCountsFiveSessions() {
    var program = ProgramEditor.emptyProgram(name: "PPL", now: .t0)
    var push: UUID, pull: UUID, legs: UUID
    (program, push) = ProgramEditor.addDay(named: "Push", exercises: [], to: program, now: .t0)
    (program, pull) = ProgramEditor.addDay(named: "Pull", exercises: [], to: program, now: .t0)
    (program, legs) = ProgramEditor.addDay(named: "Legs", exercises: [], to: program, now: .t0)
    for (weekday, day) in [(Weekday.monday, push), (.tuesday, pull), (.wednesday, legs), (.thursday, push), (.friday, pull)] {
        program = ProgramEditor.assign(day, to: weekday, in: program, now: .t1)
    }
    #expect(program.weekLayout == [push, pull, legs, push, pull, nil, nil])
    #expect(program.sessionsPerWeek == 5)
    #expect(program.updatedAt == .t1)
}

@Test func removingADayClearsItFromTheWeek() {
    let program = ProgramEditor.removeDay(id: push, from: matheoProgram, now: .t2)
    #expect(program.weekLayout == [nil, pull, legs, nil, pull, nil, nil])
    #expect(program.days.map(\.order) == [0, 1])
    #expect(program.sessionsPerWeek == 3)
    #expect(TodayPlanner.plan(program: program, on: monday, calendar: .paris) == .rest(next: NextSession(day: pullDay, weekday: .tuesday)))
}

@Test func movingAnExerciseBreaksASupersetThatIsNoLongerConsecutive() { … }
@Test func perSetTargetsFollowTheSetCount() {
    var day = RoutineEditor.add([.content(id: "bench-press-barbell")], to: emptyDay, directory: directory)
    day = RoutineEditor.setPerSetTargets(true, at: 0, in: day)
    day = RoutineEditor.updateSetTarget(SetTarget(repsMin: 4, repsMax: 6), set: 1, at: 0, in: day)
    day = RoutineEditor.setSets(4, at: 0, in: day)
    #expect(day.exercises[0].setTargets == [SetTarget(repsMin: 8, repsMax: 12), SetTarget(repsMin: 4, repsMax: 6),
                                            SetTarget(repsMin: 4, repsMax: 6), SetTarget(repsMin: 4, repsMax: 6)])
    #expect(day.exercises[0].repsMin == 4 && day.exercises[0].repsMax == 12)
}
@Test func rulesRejectOutOfRangeValues() { … }   // 11 séries, RPE 10,5, repos 310 s, setTargets de 2 entrées pour 3 séries
@Test func routineFromARampingSessionGetsPerSetRanges() {
    // Séance « Push » : bench É 20×10, 60×12, 70×5, 70×5 ; pec deck 80×10, 80×8, 72,5×9 (drop).
    let day = RoutineFromSession.day(from: session, directory: directory, order: 0)
    #expect(day.name == "Push")
    #expect(day.exercises[0].sets == 3)
    #expect(day.exercises[0].setTargets == [SetTarget(repsMin: 10, repsMax: 12), SetTarget(repsMin: 4, repsMax: 6), SetTarget(repsMin: 4, repsMax: 6)])
    #expect(day.exercises[1].setTargets == nil)
    #expect(day.exercises[1].repsMin == 6 && day.exercises[1].repsMax == 10)
}
```

- [ ] **Step 2 : Lancer, vérifier l'échec** — Run : `swift test --package-path Packages/PulseFeatures --filter PulseServicesTests` — Expected : FAIL à la compilation.

- [ ] **Step 3 : Implémenter selon les Interfaces.**

- [ ] **Step 4 : Lancer, vérifier le succès** — Run : `swift test --package-path Packages/PulseFeatures` — Expected : vert.

- [ ] **Step 5 : VFT, puis commit**

```bash
git add Packages/PulseFeatures/Sources/PulseServices/Program Packages/PulseFeatures/Tests/PulseServicesTests
git commit -m "feat(services): edit programs and routines, with per-set ranges and routines built from a session"
```

---

### Task 9 : Services — une lecture de programme ratée n'écrase plus les ajustements

Suite de M3b (spec M4 §20) : `DayRefresher.plannedDay(for:now:)` avale l'erreur (`try?`), rend `.noProgram`, et `DailyScoreService` enregistre alors des ajustements vides, qui restent après le figement.

**Files:**
- Modify: `Packages/PulseFeatures/Sources/PulseServices/Refresh/DayRefresher.swift`, `Score/DailyScoreService.swift`
- Test: `Tests/PulseServicesTests/DayRefresherTests.swift` (ou le fichier existant le plus proche), `DailyScoreServiceTests.swift`

**Interfaces:**
- Produces : `DailyScoreService.update(nights:plannedDay:now:)` et `saveCheckIn(_:plannedDay:now:)` prennent `plannedDay: PlannedDay?`. `nil` veut dire « programme illisible » : le score est calculé, mais les ajustements déjà enregistrés pour le jour sont gardés (`existing?.adjustments ?? []`). Côté `DayRefresher`, une lecture ratée du profil ou du programme donne `nil` au service, et `.noProgram` seulement pour l'affichage de `TodaySession`. Un programme absent (aucun `activeProgramID`) reste `.noProgram`.

- [ ] **Step 1 : Écrire les tests qui échouent**

```swift
@Test func programReadFailureKeepsTheStoredAdjustments() async throws {
    // 7 h : score « fatigue modérée » avec ajustements (volume, rpeCap, rest) enregistré ; puis le dépôt de programmes lève ;
    // 9 h : nouvelle nuit arrivée, refresh(origin: .foreground).
    let stored = try await recovery.dailyRecoveries(from: today, to: tomorrow).first
    #expect(stored?.adjustments.map(\.kind) == [.volume, .rpeCap, .rest])
}

@Test func editedProgramAfterFreezeKeepsTheFrozenScore() async throws {
    // 13 h : score figé ; le jour du lundi est retiré du programme ; refresh(origin: .foreground).
    #expect(refresh.score == .scored(frozen))
    #expect(refresh.plannedDay == .rest(next: …))
}
```

Le dépôt qui échoue : un `ProgramRepository` de test (dans `Tests/PulseServicesTests/Support/`) qui lève sur commande.

- [ ] **Step 2 : Lancer, vérifier l'échec** — Run : `swift test --package-path Packages/PulseFeatures --filter programReadFailureKeepsTheStoredAdjustments` — Expected : FAIL (ajustements vides).

- [ ] **Step 3 : Implémenter selon les Interfaces** ; adapter les appelants de `OnboardingFeature` et `TodayFeature` (ils passent un `PlannedDay` non nul).

- [ ] **Step 4 : Lancer, vérifier le succès** — Run : `swift test --package-path Packages/PulseFeatures` — Expected : vert.

- [ ] **Step 5 : VFT, puis commit**

```bash
git add Packages/PulseFeatures/Sources/PulseServices Packages/PulseFeatures/Sources/OnboardingFeature Packages/PulseFeatures/Sources/TodayFeature \
  Packages/PulseFeatures/Tests/PulseServicesTests
git commit -m "fix(services): keep the day's adjustments when the program cannot be read"
```

---

### Task 10 : Services — lecture de l'export Hevy

**Files:**
- Create: `Packages/PulseFeatures/Sources/PulseServices/Import/CSVReader.swift`, `HevyRow.swift`, `HevyDate.swift`, `HevyCSV.swift`, `HevyWorkout.swift`
- Test: `Tests/PulseServicesTests/HevyCSVTests.swift`, `HevyDateTests.swift`, `Tests/PulseServicesTests/Support/HevyFixtures.swift`

**Interfaces:**
- Produces :
  - `enum CSVReader { static func records(_ text: String) -> [[String]] }` (interne) : RFC 4180, champs entre guillemets avec `""`, virgules et retours à la ligne ; fins de ligne `\n` ou `\r\n` ; BOM UTF-8 ignoré ; dernière ligne vide ignorée.
  - `public struct HevyRow: Sendable, Equatable` : `title: String`, `startedAt: Date`, `endedAt: Date`, `description: String?`, `exerciseTitle: String`, `supersetID: Int?`, `exerciseNotes: String?`, `setIndex: Int`, `setType: String`, `weightKg: Double?`, `reps: Int?`, `distanceKm: Double?`, `durationSeconds: Int?`, `rpe: Double?`. Une chaîne vide devient `nil`.
  - `public enum HevyDate { public static func parse(_ text: String, calendar: Calendar) -> Date? }` : `d MMM yyyy, HH:mm`, mois français (`janv.`, `févr.`, `mars`, `avr.`, `mai`, `juin`, `juil.`, `août`, `sept.`, `oct.`, `nov.`, `déc.`, avec ou sans point) ou anglais (`Jan` … `Dec`), sans tenir compte de la casse. Composants assemblés par `calendar.date(from:)` dans le fuseau du calendrier, ce qui donne l'heure valide suivante pour une heure inexistante et la première occurrence pour une heure ambiguë.
  - `public enum HevyImportError: Error, Equatable { case notHevyExport; case invalidDate(line: Int); case empty }`.
  - `public enum HevyCSV { public static let header = ["title", "start_time", "end_time", "description", "exercise_title", "superset_id", "exercise_notes", "set_index", "set_type", "weight_kg", "reps", "distance_km", "duration_seconds", "rpe"]; public static func rows(from data: Data, calendar: Calendar) throws -> [HevyRow] }` : l'en-tête doit contenir ces colonnes (dans n'importe quel ordre, colonnes en plus ignorées), sinon `notHevyExport` ; nombres avec point décimal.
  - `public struct HevyWorkout: Sendable, Equatable { title; startedAt; endedAt; description: String?; exercises: [HevyExerciseBlock] }`, `public struct HevyExerciseBlock: Sendable, Equatable { name: String; notes: String?; supersetID: Int?; sets: [HevyRow] }`, `public enum HevyWorkouts { public static func group(_ rows: [HevyRow]) -> [HevyWorkout] }` : une séance par (`title`, `startedAt`, `endedAt`) ; un bloc par suite de lignes consécutives du même exercice ; séances triées par `startedAt` croissant.
- `HevyFixtures.csv` : un extrait **inventé** au format réel. Exemple :

```
"title","start_time","end_time","description","exercise_title","superset_id","exercise_notes","set_index","set_type","weight_kg","reps","distance_km","duration_seconds","rpe"
"Push 🫷🫸","26 oct. 2026, 07:00","26 oct. 2026, 08:06","Note, avec ""guillemets""
et retour","Développé Couché (Barre)",,"",0,"warmup",,20,,,6
"Push 🫷🫸","26 oct. 2026, 07:00","26 oct. 2026, 08:06","Note, avec ""guillemets""
et retour","Développé Couché (Barre)",,"",1,"normal",60,12,,,7.5
"Push 🫷🫸","26 oct. 2026, 07:00","26 oct. 2026, 08:06","Note, avec ""guillemets""
et retour","Écarté (Machine)",,"Siège cran 4 — l’épaule ok",0,"dropset",72.5,5,,,
"Push 🫷🫸","26 oct. 2026, 07:00","26 oct. 2026, 08:06","Note, avec ""guillemets""
et retour","Tapis de Course",,"",0,"normal",,,1.4,600,
"Pull","27 Oct 2026, 07:17","27 Oct 2026, 07:59","","Extension Triceps Poulie Haute",0,"",0,"failure",30.5,3,,,9.5
"Pull","27 Oct 2026, 07:17","27 Oct 2026, 07:59","","Avant Bras Poulie Barre Droite",0,"",0,"normal",27,12,,,
```

- [ ] **Step 1 : Écrire les tests qui échouent**

```swift
@Test func quotedFieldsWithNewlinesQuotesAndEmojiParse() throws {
    let rows = try HevyCSV.rows(from: Data(HevyFixtures.csv.utf8), calendar: .paris)
    #expect(rows.count == 6)
    #expect(rows[0].title == "Push 🫷🫸")
    #expect(rows[0].description == "Note, avec \"guillemets\"\net retour")
    #expect(rows[2].exerciseNotes == "Siège cran 4 — l’épaule ok")
    #expect(rows[0].weightKg == nil && rows[0].reps == 20 && rows[0].rpe == 6)
    #expect(rows[3].durationSeconds == 600 && rows[3].distanceKm == 1.4)
    #expect(rows[4].supersetID == 0 && rows[4].setType == "failure")
}

@Test func frenchAndEnglishDatesParseInParis() {
    #expect(HevyDate.parse("27 oct. 2026, 07:17", calendar: .paris) == TestClock.date("2026-10-27T07:17:00"))
    #expect(HevyDate.parse("27 Oct 2026, 07:17", calendar: .paris) == TestClock.date("2026-10-27T07:17:00"))
    #expect(HevyDate.parse("3 févr. 2026, 18:30", calendar: .paris) == TestClock.date("2026-02-03T18:30:00"))
    #expect(HevyDate.parse("12 août 2026, 06:47", calendar: .paris) == TestClock.date("2026-08-12T06:47:00"))
    #expect(HevyDate.parse("31 foo 2026, 07:00", calendar: .paris) == nil)
}

@Test func daylightSavingTimesParse() {
    #expect(HevyDate.parse("29 mars 2026, 02:30", calendar: .paris) != nil)
    #expect(HevyDate.parse("25 oct. 2026, 02:30", calendar: .paris) != nil)
}

@Test func aFileWithoutTheHevyHeaderIsRejected() {
    #expect(throws: HevyImportError.notHevyExport) { try HevyCSV.rows(from: Data("a,b\n1,2\n".utf8), calendar: .paris) }
}

@Test func rowsGroupIntoChronologicalWorkoutsAndBlocks() throws {
    let workouts = HevyWorkouts.group(try HevyCSV.rows(from: Data(HevyFixtures.csv.utf8), calendar: .paris))
    #expect(workouts.map(\.title) == ["Push 🫷🫸", "Pull"])
    #expect(workouts[0].exercises.map(\.name) == ["Développé Couché (Barre)", "Écarté (Machine)", "Tapis de Course"])
    #expect(workouts[0].exercises[0].sets.count == 2)
}
```

`.paris` : le calendrier des tests de `PulseServicesTests` (grégorien, `Europe/Paris`, `fr_FR`). L'ajouter à `Support/` s'il n'existe pas déjà sous un autre nom ; sinon utiliser celui qui existe.

- [ ] **Step 2 : Lancer, vérifier l'échec** — Run : `swift test --package-path Packages/PulseFeatures --filter Hevy` — Expected : FAIL à la compilation.

- [ ] **Step 3 : Implémenter selon les Interfaces.**

- [ ] **Step 4 : Lancer, vérifier le succès, puis l'export réel en local**

Run : `swift test --package-path Packages/PulseFeatures`. Puis vérifier une fois, à la main, que l'export réel se lit sans erreur, par un test temporaire **non commité** qui lit le fichier des Global Constraints et compte les séances.
Expected : vert ; l'export réel donne 109 séances et 1 805 lignes ; le test temporaire est supprimé avant le commit.

- [ ] **Step 5 : VFT, puis commit**

```bash
git add Packages/PulseFeatures/Sources/PulseServices/Import Packages/PulseFeatures/Tests/PulseServicesTests/HevyCSVTests.swift \
  Packages/PulseFeatures/Tests/PulseServicesTests/HevyDateTests.swift Packages/PulseFeatures/Tests/PulseServicesTests/Support/HevyFixtures.swift
git commit -m "feat(import): read Hevy workout exports, quoted notes and French dates included"
```

---

### Task 11 : Services — plan d'import Hevy et conversion en séances

**Files:**
- Create: `Packages/PulseFeatures/Sources/PulseServices/Import/HevyMappingChoice.swift`, `HevyNameGuesser.swift`, `HevyImportPlanner.swift`, `HevySessionBuilder.swift`
- Test: `Tests/PulseServicesTests/HevyImportPlannerTests.swift`, `HevyNameGuesserTests.swift`, `HevySessionBuilderTests.swift`

**Interfaces:**
- Consumes : tâches 5, 6, 7 et 10.
- Produces :
  - `public struct UserExerciseDraft: Sendable, Equatable, Codable { name; primaryMuscle: Muscle; secondaryMuscles: [Muscle]; equipment; pattern; region; loadKind; isUnilateral: Bool; needsReview: Bool }` et `public func userExercise(id: UUID, now: Date) -> UserExercise` : incrément 2,5, ou 5 pour la région `lower` ; repos 90 ; `isCompound` vrai pour les plans de poussée, de tirage, de squat et de charnière.
  - `public enum HevyMappingChoice: Sendable, Equatable, Codable { case content(id: String); case user(id: UUID); case create(UserExerciseDraft); case ignore }`.
  - `public enum HevyNameGuesser { public static func draft(for name: String) -> UserExerciseDraft }` : premier mot-clé trouvé dans `SearchText.fold(name)`, dans cet ordre (`needsReview` toujours vrai) :

| Mots-clés (repliés) | Muscle principal | Plan |
| :-- | :-- | :-- |
| `poignet`, `avant bras`, `wrist` | forearms | forearm |
| `shrug` | traps | shoulderIsolation |
| `oiseau`, `reverse fly`, `face pull` | rearDelts | shoulderIsolation |
| `elevation laterale`, `lateral` | sideDelts | shoulderIsolation |
| `developpe militaire`, `presse epaules`, `shoulder press`, `overhead press` | frontDelts | verticalPush |
| `dips`, `triceps`, `pushdown` | triceps | elbowExtension |
| `curl jambe`, `leg curl` | hamstrings | kneeFlexion |
| `curl` | biceps | elbowFlexion |
| `ecarte`, `butterfly`, `fly`, `pec deck` | chest | chestFly |
| `developpe`, `bench`, `chest press`, `pompe` | chest | horizontalPush |
| `traction`, `tirage haut`, `tirage poitrine`, `pulldown`, `pull up` | lats | verticalPull |
| `rowing`, `row`, `tirage bas`, `tirage assis`, `tirage` | upperBack | horizontalPull |
| `extension dos`, `hyperextension`, `lombaire` | lowerBack | hinge |
| `souleve`, `deadlift`, `hip thrust` | hamstrings | hinge |
| `extension jambe`, `leg extension` | quads | kneeExtension |
| `mollet`, `calf` | calves | calfRaise |
| `abduction` | abductors | hipAbduction |
| `adduction` | adductors | hipAdduction |
| `fente`, `lunge` | quads | lunge |
| `squat`, `presse`, `leg press` | quads | squat |
| `crunch`, `abdo`, `oblique`, `toes`, `releve` | abs | coreFlexion |
| `planche`, `plank` | abs | coreStability |
| (aucun) | chest | horizontalPush |

    Matériel, au premier mot trouvé : `barre ez`/`ez` → ezBar ; `barre`/`barbell` → barbell ; `haltere`/`dumbbell` → dumbbell ; `poulie`/`cable`/`corde` → cable ; `smith` → smithMachine ; `elastique`/`band` → band ; `poids du corps`/`traction`/`dips`/`lestee` → bodyweight ; sinon machine. Nature de charge : `assiste` → assisted (matériel machine) ; matériel bodyweight → bodyweight ; sinon external. Région selon le plan (jambes, mollets, charnière → lower ; tronc → core ; sinon upper). `isUnilateral` si `un bras`, `unilateral`, `une jambe` ou `single`.
  - `public struct HevyNameSummary: Sendable, Equatable, Identifiable { name (id); sessionCount: Int; setCount: Int; isCardio: Bool; isSure: Bool; choice: HevyMappingChoice }`.
  - `public struct HevyImportPreview: Sendable, Equatable { newWorkouts: [HevyWorkout]; duplicateCount: Int; cardioSetCount: Int; period: ClosedRange<Date>?; names: [HevyNameSummary] }`.
  - `public enum HevyImportPlanner { public static func preview(rows: [HevyRow], existing: [WorkoutSession], library: ContentLibrary, userExercises: [UserExercise], remembered: [String: HevyMappingChoice]) throws -> HevyImportPreview }` :
    - `empty` si aucune ligne.
    - **Doublon** : une séance existante de source `.hevy`, au même `startedAt` (à la minute) et au même titre.
    - **Cardio** : un nom dont toutes les lignes n'ont ni charge ni répétitions mais une durée ou une distance.
    - **Choix par défaut**, dans l'ordre : choix mémorisé (s'il désigne encore un exercice existant) ; correspondance sûre de la table (`isSure`) ; exercice perso au nom identique une fois replié ; cardio → `.ignore` ; sinon `.create(HevyNameGuesser.draft(for:))`.
    - Noms triés par `sessionCount` décroissant, puis par nom ; `cardioSetCount` compte les lignes de cardio des séances nouvelles.
  - `public enum HevySessionBuilder { public static func session(from workout: HevyWorkout, references: [String: ExerciseReference], directory: ExerciseDirectory, now: Date) -> WorkoutSession? }` (spec M4 §13.2) :
    - `nil` si, une fois les noms ignorés (absents de `references`) retirés, il ne reste aucune série.
    - Séance `kind .strength`, `source .hevy`, `status .completed` ; titre, `startedAt`, `endedAt` ; `durationMinutes` = écart en minutes ; `note` = description ; `exerciseNotes` = une note par bloc qui en a une ; `tonnageKg` = `SessionTonnage` ; `createdAt = updatedAt = now`.
    - Séries dans l'ordre (`order` de 0 à n−1) : type `normal` → `working`, `warmup` → `warmup`, `dropset` → `drop`, `failure` → `failure`, autre → `working` ; `actualWeightKg`, `actualReps`, `rpe`, `durationSeconds` ; `supersetGroup` = `supersetID + 1` ; `exerciseName` = nom français de l'exercice Pulse ; `completedAt` vide.
    - Une ligne sans charge, sans répétitions et sans durée est ignorée.

- [ ] **Step 1 : Écrire les tests qui échouent**

```swift
@Test func previewSkipsDuplicatesAndFlagsCardio() throws {
    let rows = try HevyCSV.rows(from: Data(HevyFixtures.csv.utf8), calendar: .paris)
    let existing = [WorkoutSession(startedAt: TestClock.date("2026-10-27T07:17:00"), kind: .strength, source: .hevy, status: .completed,
                                   title: "Pull", createdAt: .t0, updatedAt: .t0)]
    let preview = try HevyImportPlanner.preview(rows: rows, existing: existing, library: .bundled, userExercises: [], remembered: [:])
    #expect(preview.newWorkouts.map(\.title) == ["Push 🫷🫸"])
    #expect(preview.duplicateCount == 1)
    #expect(preview.cardioSetCount == 1)
    #expect(preview.names.first { $0.name == "Tapis de Course" }?.choice == .ignore)
    #expect(preview.names.first { $0.name == "Écarté (Machine)" }?.choice == .content(id: "pec-deck-machine"))
    #expect(preview.names.first { $0.name == "Écarté (Machine)" }?.isSure == true)
}

@Test func rememberedAndUserExerciseChoicesWin() throws { … }   // mémorisé > table ; perso au même nom > création

@Test func guesserReadsMuscleEquipmentAndAssistance() {
    let dips = HevyNameGuesser.draft(for: "Machine Dips Assis")
    #expect(dips.primaryMuscle == .triceps && dips.pattern == .elbowExtension && dips.equipment == .machine)
    let shrug = HevyNameGuesser.draft(for: "Shrug (Haltère)")
    #expect(shrug.primaryMuscle == .traps && shrug.equipment == .dumbbell && shrug.loadKind == .external)
    let pull = HevyNameGuesser.draft(for: "Traction Supination (Assisté)")
    #expect(pull.pattern == .verticalPull && pull.loadKind == .assisted)
    #expect(HevyNameGuesser.draft(for: "Leg Curl Assis").pattern == .kneeFlexion)
    #expect(HevyNameGuesser.draft(for: "Oiseau Un Bras (Poulie)").isUnilateral)
}

@Test func builderConvertsTypesSupersetsNotesAndTonnage() throws {
    let workout = HevyWorkouts.group(try HevyCSV.rows(from: Data(HevyFixtures.csv.utf8), calendar: .paris))[0]
    let session = try #require(HevySessionBuilder.session(from: workout, references: [
        "Développé Couché (Barre)": .content(id: "bench-press-barbell"), "Écarté (Machine)": .content(id: "pec-deck-machine")
    ], directory: directory, now: .t0))
    #expect(session.source == .hevy && session.status == .completed && session.durationMinutes == 66)
    #expect(session.sets.map(\.setType) == [.warmup, .working, .drop])
    #expect(session.sets.map(\.order) == [0, 1, 2])
    #expect(session.exerciseNotes == [ExerciseNote(exercise: .content(id: "pec-deck-machine"), text: "Siège cran 4 — l’épaule ok")])
    #expect(session.tonnageKg == 60 * 12 + 72.5 * 5)
    #expect(session.sets[0].exerciseName == "Développé couché à la barre")
}

@Test func supersetIDsBecomeGroupsAndOnlyIgnoredExercisesYieldNoSession() { … }
```

- [ ] **Step 2 : Lancer, vérifier l'échec** — Run : `swift test --package-path Packages/PulseFeatures --filter Hevy` — Expected : FAIL à la compilation.

- [ ] **Step 3 : Implémenter selon les Interfaces.**

- [ ] **Step 4 : Lancer, vérifier le succès** — Run : `swift test --package-path Packages/PulseFeatures` — Expected : vert.

- [ ] **Step 5 : VFT, puis commit**

```bash
git add Packages/PulseFeatures/Sources/PulseServices/Import Packages/PulseFeatures/Tests/PulseServicesTests
git commit -m "feat(import): plan a Hevy import, guess custom exercises and convert workouts into sessions"
```

---

### Task 12 : Services — recalcul des records et importeur Hevy

**Files:**
- Create: `Packages/PulseFeatures/Sources/PulseServices/Records/RecordsService.swift`, `Import/HevyMappingStore.swift`, `Import/HevyImporter.swift`
- Test: `Tests/PulseServicesTests/RecordsServiceTests.swift`, `HevyImporterTests.swift`

**Interfaces:**
- Consumes : tâches 4, 6, 7 et 11.
- Produces :
  - `public final class RecordsService: Sendable { public init(workouts: any WorkoutRepository, records: any PersonalRecordRepository, userExercises: any UserExerciseRepository, library: ContentLibrary, now: @escaping @Sendable () -> Date); public func recomputeAll() async throws -> Int }` : lit toutes les séances, calcule `RecordBook`, appelle `replaceAll(with:)`, puis réenregistre seulement les séances dont un `isPersonalRecord` change. Rend le nombre de records. Ses appels passent par une `SerialTaskQueue`.
  - `public protocol HevyMappingStore: Sendable { func load() -> [String: HevyMappingChoice]; func save(_ choices: [String: HevyMappingChoice]) }` et `public final class UserDefaultsHevyMappingStore: HevyMappingStore` (`init(suiteName: String?)`, clé `pulse.hevyMappings`, JSON), sur le modèle de `UserDefaultsDayActivityLog`. `InMemoryHevyMappingStore` dans les doublures.
  - `public struct HevyImportResult: Sendable, Equatable { importedSessions: Int; createdExercises: Int; records: Int }`.
  - `public final class HevyImporter: Sendable` :
    - `init(workouts: any WorkoutRepository, userExercises: any UserExerciseRepository, records: RecordsService, mappings: any HevyMappingStore, library: ContentLibrary, calendar: Calendar, now: @escaping @Sendable () -> Date)`.
    - `public func preview(_ data: Data) async throws -> HevyImportPreview` lit les séances existantes, les exercices perso et les choix mémorisés.
    - `public func run(_ preview: HevyImportPreview, choices: [String: HevyMappingChoice], progress: @escaping @Sendable (Double) -> Void) async throws -> HevyImportResult` : crée les exercices perso (`.create` → `UserExercise`, enregistré, puis traité comme `.user`), enregistre les choix (les créations deviennent `.user(id:)`), puis convertit et enregistre chaque séance nouvelle, dans l'ordre. Avant chaque séance, la règle de doublon est revérifiée sur les séances déjà en base, ce qui rend la reprise sûre. Enfin `recomputeAll()`.
    - `public func removeImportedSessions() async throws -> Int` : suppression logique de toutes les séances `.hevy`, puis `recomputeAll()`.

- [ ] **Step 1 : Écrire les tests qui échouent**

```swift
@Test func importCreatesSessionsCustomExercisesAndRecords() async throws {
    let importer = makeImporter()
    let preview = try await importer.preview(Data(HevyFixtures.csv.utf8))
    var choices = Dictionary(uniqueKeysWithValues: preview.names.map { ($0.name, $0.choice) })
    choices["Extension Triceps Poulie Haute"] = .create(HevyNameGuesser.draft(for: "Extension Triceps Poulie Haute"))
    let result = try await importer.run(preview, choices: choices, progress: { _ in })
    #expect(result.importedSessions == 2)
    #expect(result.createdExercises == 1)
    #expect(try await userExercises.all(includeArchived: false).map(\.name) == ["Extension Triceps Poulie Haute"])
    #expect(mappings.load()["Extension Triceps Poulie Haute"] == .user(id: try #require(try await userExercises.all(includeArchived: false).first?.id)))
    #expect(try await records.records(for: nil).isEmpty == false)
}

@Test func importingTheSameExportTwiceAddsNothing() async throws {
    _ = try await importer.run(try await importer.preview(data), choices: defaults, progress: { _ in })
    let again = try await importer.preview(data)
    #expect(again.newWorkouts.isEmpty && again.duplicateCount == 2)
    let result = try await importer.run(again, choices: defaults, progress: { _ in })
    #expect(result.importedSessions == 0)
    #expect(try await workouts.sessions(from: .distantPast, to: .distantFuture).count == 2)
    #expect(try await records.records(for: nil).count == recordsAfterFirstImport)
}

@Test func interruptedImportCompletesWithoutDuplicates() async throws {
    // Dépôt de séances qui lève à la 2e sauvegarde : run échoue après 1 séance ; nouvelle preview + run avec un dépôt sain.
    #expect(try await workouts.sessions(from: .distantPast, to: .distantFuture).count == 2)
}

@Test func removingImportedSessionsRecomputesRecords() async throws {
    // Une séance Pulse + l'import ; removeImportedSessions() → 2 ; il ne reste que les records de la séance Pulse.
}

@Test func recomputeOnlyResavesSessionsWhoseFlagsChange() async throws { … }   // dépôt qui compte les save
```

- [ ] **Step 2 : Lancer, vérifier l'échec** — Run : `swift test --package-path Packages/PulseFeatures --filter "HevyImporter|RecordsService"` — Expected : FAIL à la compilation.

- [ ] **Step 3 : Implémenter selon les Interfaces.**

- [ ] **Step 4 : Lancer, vérifier le succès** — Run : `swift test --package-path Packages/PulseFeatures` — Expected : vert.

- [ ] **Step 5 : VFT, puis commit**

```bash
git add Packages/PulseFeatures/Sources/PulseServices/Records Packages/PulseFeatures/Sources/PulseServices/Import \
  Packages/PulseFeatures/Sources/PulseServices/Doubles Packages/PulseFeatures/Tests/PulseServicesTests
git commit -m "feat(import): import Hevy history idempotently and recompute personal records"
```

---

### Task 13 : Cible `TrainFeature`, onglet Séance et assemblage de l'app

**Files:**
- Modify: `Packages/PulseFeatures/Package.swift`, `Pulse.xcodeproj/project.pbxproj`, `Pulse.xcodeproj/xcshareddata/xcschemes/Pulse.xcscheme`, `Pulse/AppDependencies.swift`, `Pulse/Root/MainTabView.swift`, `Pulse/Root/AppRootModel.swift`, `Pulse/Root/AppRootView.swift` (selon où les modèles sont passés)
- Create: `Packages/PulseFeatures/Sources/TrainFeature/TrainEnvironment.swift`, `TrainModel.swift`, `TrainIdentifiers.swift`, `Views/TrainView.swift`, `Views/TrainTiles.swift`, `Views/RoutineRow.swift`, `Views/TrainPreviewSupport.swift`, `Resources/Localizable.xcstrings` ; `Tests/TrainFeatureTests/TrainModelTests.swift`

**Interfaces:**
- Consumes : tâches 7, 8 et 12.
- Produces :
  - Produit SwiftPM `TrainFeature` (dépend de `PulseServices`, `PulseDomain`, `PulseRecoveryEngine`, `PulseContent`, `PulseDesignSystem` ; `resources: [.process("Resources")]`) et cible `TrainFeatureTests` (dépend de `TrainFeature`, `PulseServices`, `PulseDomain`, `PulseContent`).
  - `public struct TrainEnvironment: Sendable` : `profiles`, `programs`, `recovery`, `workouts`, `userExercises`, `exerciseSettings`, `personalRecords`, `records: RecordsService`, `importer: HevyImporter`, `library: ContentLibrary`, `calendar: Calendar`, `now`.
  - `@MainActor @Observable public final class TrainModel` : `init(environment:)`, `func refresh() async`. Publie :
    - `today: TodaySession?`, construit par `TodayPlanner` et le `DailyRecovery` du jour lu dans `recovery`, sans relire Apple Santé ;
    - `program: Program?` ;
    - `routines: [RoutineSummary]`, avec `public struct RoutineSummary: Sendable, Equatable, Identifiable { day: RoutineDay; exerciseCount: Int; estimatedMinutes: Int; weekdays: [Weekday] }`, durée par `SessionSummary` ;
    - `nextRun: NextSession?` (course du jour ou prochaine course) ;
    - `directory: ExerciseDirectory` ;
    - `errorMessage: String?`.
  - `public struct TrainView: View` (`init(model: TrainModel)`), sur le modèle de la maquette `seance` : tuile Musculation (opale), tuile Course (obsidienne), « Mes routines » (toucher → éditeur, tâche 15), puis lignes « Bibliothèque d'exercices », « Historique », « Importer depuis Hevy ». Les écrans des tâches 14 à 17 s'y branchent par `NavigationLink`/feuilles ; en attendant, des destinations vides marquées `// Tâche 14` à `// Tâche 17`. Pas de bouton « Démarrer » ni « Lancer » en M4a : la tuile Musculation renvoie à l'accueil pour démarrer.
  - App : `AppDependencies` gagne `exerciseSettings: any ExerciseSettingsRepository`, `records: RecordsService`, `hevyImporter: HevyImporter`, `hevyMappings: UserDefaultsHevyMappingStore(suiteName: wiring.defaultsSuite)` et `func trainEnvironment() -> TrainEnvironment`. Le modèle `TrainModel` est créé à côté de `TodayModel` dans `AppRootModel.show(.main)`. L'onglet `.session` de `MainTabView` affiche `TrainView`.
  - `pbxproj` (à la main, sur le modèle exact des quatre entrées de `TodayFeature` : `PBXBuildFile` « TrainFeature in Frameworks », phase Frameworks de `Pulse`, `packageProductDependencies` de `Pulse`, `XCSwiftPackageProductDependency` `productName = TrainFeature` vers le paquet `PulseFeatures`) ; identifiants hexadécimaux de 24 caractères nouveaux et uniques. Schéma : `TrainFeatureTests` ajouté aux `TestableReference`, comme `TodayFeatureTests`.

- [ ] **Step 1 : Écrire les tests qui échouent**

```swift
@MainActor @Test func trainModelListsRoutinesWithTheirWeekdays() async {
    // Programme PPL : Push lundi et jeudi, Pull mardi et vendredi, Legs mercredi ; aujourd'hui lundi 9 h, score « normal ».
    let model = TrainModel(environment: environment)
    await model.refresh()
    #expect(model.routines.map(\.day.name) == ["Push", "Pull", "Legs"])
    #expect(model.routines[0].weekdays == [.monday, .thursday])
    #expect(model.today?.status == .adjusted)
    #expect(model.today?.originalDay?.name == "Push")
}

@MainActor @Test func trainModelWithoutProgramShowsNoRoutines() async { … }
@MainActor @Test func trainModelReportsAReadFailure() async { … }   // dépôt qui lève → errorMessage non nul, pas de plantage
```

- [ ] **Step 2 : Lancer, vérifier l'échec** — Run : `swift test --package-path Packages/PulseFeatures --filter TrainFeatureTests` — Expected : FAIL (cible absente).

- [ ] **Step 3 : Implémenter la cible, le modèle, la vue et ses aperçus, puis l'assemblage de l'app et le `pbxproj`.**

- [ ] **Step 4 : Lancer, vérifier le succès**

Run : `swift test --package-path Packages/PulseFeatures`, puis (hors bac à sable) `make build-app` et `make build-release`, puis `git diff --stat Pulse.xcodeproj`.
Expected : vert ; codes de sortie 0 ; seules les quatre entrées `TrainFeature` (et le schéma) changent dans le projet.

- [ ] **Step 5 : VFT, puis commit** (cette fois avec `project.pbxproj`, relu ligne à ligne)

```bash
git add Packages/PulseFeatures/Package.swift Packages/PulseFeatures/Sources/TrainFeature Packages/PulseFeatures/Tests/TrainFeatureTests \
  Pulse/AppDependencies.swift Pulse/Root Pulse.xcodeproj/project.pbxproj Pulse.xcodeproj/xcshareddata/xcschemes/Pulse.xcscheme
git commit -m "feat(train): add the Séance tab with today's session and the program's routines"
```

---

### Task 14 : Bibliothèque, fiche exercice, exercice perso

**Files:**
- Create: `Packages/PulseFeatures/Sources/TrainFeature/Library/LibraryModel.swift`, `LibraryView.swift` ; `Sheet/ExerciseSheetModel.swift`, `ExerciseSheetView.swift`, `ExerciseProgressionChart.swift` ; `CustomExercise/CustomExerciseModel.swift`, `CustomExerciseForm.swift`
- Modify: `Sources/TrainFeature/Views/TrainView.swift` (destination bibliothèque)
- Test: `Tests/TrainFeatureTests/LibraryModelTests.swift`, `ExerciseSheetModelTests.swift`, `CustomExerciseModelTests.swift`

**Interfaces:**
- Consumes : tâches 5, 6, 7, 12 et 13.
- Produces :
  - `@MainActor @Observable public final class LibraryModel` : `init(environment: TrainEnvironment, mode: LibraryMode)`, avec `public enum LibraryMode: Equatable { case browse; case pick(multiple: Bool) }`. Propriétés `query`, `group: MuscleGroup?`, `equipment: Equipment?`, `results: [ExerciseInfo]` (via `ExerciseBrowser` et `RecentExercises`), `selection: Set<ExerciseReference>`, `oneRepMax(for:) -> Double?` (record `estimatedOneRepMax` actuel). Méthodes : `load() async`, `toggle(_:)`, `confirm() -> [ExerciseReference]` (dans l'ordre des touches).
  - `public struct LibraryView: View` (`init(model:onPick:)`) : champ de recherche, pilules de groupe (« Tous » + les six) et de matériel, section « Récents » puis le reste, ligne « nom · groupe · matériel · 1RM », bouton « Créer un exercice ».
  - `@MainActor @Observable public final class ExerciseSheetModel` : `init(environment:reference:)`, `load() async`. Publie :
    - `info` ; `tab` (`.technique`, `.progression`, `.alternatives`) ;
    - `painReminder: String?` (zones de `riskAreas` ∩ `painAreas` du profil, en clair) ;
    - `currentOneRepMax: Double?`, `oneRepMaxChange30Days: Double?`, `bestSet: (weightKg: Double, reps: Int, date: Date)?`, `chart: [ChartPoint]` (meilleur 1RM estimé par séance sur 90 jours ; `public struct ChartPoint: Identifiable, Equatable { date: Date; value: Double }`) ;
    - `recentSessions: [ExerciseHistoryLine]` (10 dernières), avec `public struct ExerciseHistoryLine: Identifiable, Equatable { id: UUID /* séance */; date: Date; setsText: String /* « 70 × 5 · 5 », hors échauffement */; maxRPE: Double?; tonnageKg: Double; hasRecord: Bool }` ;
    - `alternatives: [ExerciseInfo]` ; `increment: Double` (via `IncrementResolver`).
    Méthode : `setIncrement(_ kg: Double) async` (enregistre `ExerciseSettings`).
  - `public struct ExerciseSheetView: View` : trois onglets (spec M4 §10.2) ; carte musculaire avec `MuscleMapView` (principaux niveau 4, secondaires niveau 2) ; courbe Swift Charts avec étiquette VoiceOver récapitulative ; réglage d'incrément (pas de 0,25 kg, de 0,25 à 20).
  - `@MainActor @Observable public final class CustomExerciseModel` : `init(environment:draft: UserExerciseDraft?, editing: UserExercise?)`, champs liés (ceux de la spec M4 §10.3, plus « polyarticulaire » et « tenu en secondes » pour `isCompound` et `tracksDuration`), `canSave` (nom non vide une fois rogné, muscles secondaires sans le principal), `save() async throws -> UserExercise`, `archive() async throws`. Valeurs par défaut sans brouillon : machine, `horizontalPush`, `upper`, `external`, incrément 2,5, repos 90.

- [ ] **Step 1 : Écrire les tests qui échouent**

```swift
@MainActor @Test func libraryFiltersAndPicksInTapOrder() async {
    let model = LibraryModel(environment: environment, mode: .pick(multiple: true))
    await model.load()
    model.query = "ecarte"
    #expect(model.results.allSatisfy { SearchText.fold($0.name).contains("ecarte") })
    model.toggle(.content(id: "pec-deck-machine")); model.toggle(.content(id: "cable-crossover"))
    #expect(model.confirm() == [.content(id: "pec-deck-machine"), .content(id: "cable-crossover")])
}

@MainActor @Test func sheetShowsProgressionFromHistory() async {
    // Trois séances bench : 2 oct 60×10 (1RM 80) ; 12 oct 70×5 (78,75) ; 26 oct 72,5×5 (81,56). Records recalculés. Aujourd'hui 2 nov.
    let model = ExerciseSheetModel(environment: environment, reference: .content(id: "bench-press-barbell"))
    await model.load()
    #expect(model.currentOneRepMax.map { ($0 * 10).rounded() / 10 } == 81.6)
    #expect(model.chart.count == 3)
    #expect(model.recentSessions.first?.setsText == "72,5 × 5")
    #expect(model.alternatives.map(\.reference) == [.content(id: "chest-press-machine"), .content(id: "bench-press-dumbbell"),
                                                    .content(id: "incline-chest-press-machine")])
}

@MainActor @Test func sheetRemindsDeclaredPainAreas() async { … }   // profil épaules + dips → rappel non nul ; curl → nil
@MainActor @Test func settingTheIncrementStoresExerciseSettings() async { … }
@MainActor @Test func customExerciseNeedsANameAndKeepsTheDraft() async throws {
    let model = CustomExerciseModel(environment: environment, draft: HevyNameGuesser.draft(for: "Shrug (Haltère)"), editing: nil)
    #expect(model.canSave)
    model.name = "  "
    #expect(!model.canSave)
    model.name = "Shrug haltères"
    let saved = try await model.save()
    #expect(saved.primaryMuscle == .traps && saved.equipment == .dumbbell)
}
```

L'ordre attendu des alternatives est celui du contenu pour `bench-press-barbell`. Le vérifier dans `exercises.json` et corriger l'assertion si le contenu dit autre chose.

- [ ] **Step 2 : Lancer, vérifier l'échec** — Run : `swift test --package-path Packages/PulseFeatures --filter TrainFeatureTests` — Expected : FAIL à la compilation.

- [ ] **Step 3 : Implémenter les modèles, les vues et leurs aperçus.**

- [ ] **Step 4 : Lancer, vérifier le succès** — Run : `swift test --package-path Packages/PulseFeatures` puis, hors bac à sable, `make build-app` — Expected : vert ; code 0.

- [ ] **Step 5 : VFT, puis commit**

```bash
git add Packages/PulseFeatures/Sources/TrainFeature Packages/PulseFeatures/Tests/TrainFeatureTests
git commit -m "feat(train): add the exercise library, the three-tab exercise sheet and custom exercises"
```

---

### Task 15 : Éditeur de programme et de routine

**Files:**
- Create: `Packages/PulseFeatures/Sources/TrainFeature/Editor/ProgramEditorModel.swift`, `ProgramEditorView.swift`, `WeekAssignmentView.swift`, `RoutineEditorModel.swift`, `RoutineEditorView.swift`, `RoutineExerciseEditor.swift`
- Modify: `Sources/TrainFeature/Views/TrainView.swift`
- Test: `Tests/TrainFeatureTests/ProgramEditorModelTests.swift`, `RoutineEditorModelTests.swift`

**Interfaces:**
- Consumes : tâches 8, 13 et 14.
- Produces :
  - `@MainActor @Observable public final class ProgramEditorModel` : `init(environment:)`, `load() async`. Publie `program: Program?`, `otherPrograms: [Program]`, `templates: [ProgramTemplate]`. Méthodes, chacune enregistrant tout de suite par `programs.save` :
    - `rename(_:)`, `assign(_ dayID: UUID?, to: Weekday)`, `addRoutine(named:)` (rend l'id), `duplicate(_:)`, `remove(_:)` ;
    - `activate(_ programID: UUID)` (profil `activeProgramID`) ;
    - `adopt(_ templateID: String)` (via `ProgramAdopter` de M3a, puis actif) ;
    - `createEmpty(named:)` (puis actif) ; `archive(_:)`.
  - `@MainActor @Observable public final class RoutineEditorModel` : `init(environment:programID:dayID:)`. Publie `day: RoutineDay`, `estimatedMinutes`, `issues: [Int: [RoutineIssue]]`. Méthodes (déléguées à `RoutineEditor`) : `add(_ references:)`, `move(fromOffsets:toOffset:)`, `remove(at:)`, `toggleSuperset(at:)`, `setSets(_:at:)`, `setRange(_:at:)`, `setPerSetTargets(_:at:)`, `updateSetTarget(_:set:at:)`, `setRPE(_:at:)`, `setRest(_:at:)`, `setIncrement(_:for:) async`, `rename(_:)`. Enregistrement par `save() async throws`, refusé tant que `issues` n'est pas vide. Un brouillon non enregistré est abandonné à la sortie, après confirmation.
  - Vues : `ProgramEditorView` (nom, routines, semaine L–D avec un menu « routine ou Repos » par jour, programmes et modèles ; les jours de course d'un modèle adopté sont affichés en lecture seule, leur édition arrive en M6), `RoutineEditorView` (liste réordonnable, `RoutineExerciseEditor` par exercice : pas à pas séries 1–10, fourchette ou « Par série », RPE 6–10 par 0,5, repos par 15 s, super set, incrément, retrait ; durée estimée en tête ; « Ajouter des exercices » ouvre `LibraryView` en mode choix multiple).

- [ ] **Step 1 : Écrire les tests qui échouent**

```swift
@MainActor @Test func buildingMatheoPPLSavesTheWeek() async throws {
    let model = ProgramEditorModel(environment: environment)
    await model.load()
    try await model.createEmpty(named: "Mon PPL")
    let push = try await model.addRoutine(named: "Push"), pull = try await model.addRoutine(named: "Pull"),
        legs = try await model.addRoutine(named: "Legs")
    for (weekday, day) in [(Weekday.monday, push), (.tuesday, pull), (.wednesday, legs), (.thursday, push), (.friday, pull)] {
        try await model.assign(day, to: weekday)
    }
    let saved = try #require(try await programs.program(id: try #require(model.program?.id)))
    #expect(saved.sessionsPerWeek == 5)
    #expect(try await profiles.load()?.activeProgramID == saved.id)
}

@MainActor @Test func routineEditorRefusesInvalidValuesAndSavesValidOnes() async throws {
    let model = RoutineEditorModel(environment: environment, programID: program.id, dayID: push.id)
    model.add([.content(id: "bench-press-barbell"), .content(id: "chest-press-machine")])
    model.setRest(310, at: 0)
    #expect(model.issues[0] == [.rest])
    await #expect(throws: (any Error).self) { try await model.save() }
    model.setRest(120, at: 0)
    model.setPerSetTargets(true, at: 0)
    model.updateSetTarget(SetTarget(repsMin: 4, repsMax: 6), set: 1, at: 0)
    try await model.save()
    #expect(try await programs.program(id: program.id)?.days.first { $0.id == push.id }?.exercises[0].setTargets?[1] == SetTarget(repsMin: 4, repsMax: 6))
}

@MainActor @Test func adoptingATemplateMakesItActive() async throws { … }
@MainActor @Test func removingTodaysRoutineLeavesNoOrphanInTheWeek() async throws { … }
```

- [ ] **Step 2 : Lancer, vérifier l'échec** — Run : `swift test --package-path Packages/PulseFeatures --filter TrainFeatureTests` — Expected : FAIL à la compilation.

- [ ] **Step 3 : Implémenter les modèles, les vues et leurs aperçus.**

- [ ] **Step 4 : Lancer, vérifier le succès** — Run : `swift test --package-path Packages/PulseFeatures` puis, hors bac à sable, `make build-app` — Expected : vert ; code 0.

- [ ] **Step 5 : VFT, puis commit**

```bash
git add Packages/PulseFeatures/Sources/TrainFeature Packages/PulseFeatures/Tests/TrainFeatureTests
git commit -m "feat(train): edit the program week and its routines, with per-set rep ranges"
```

---

### Task 16 : Historique, détail d'une séance, « Enregistrer comme routine »

**Files:**
- Create: `Packages/PulseFeatures/Sources/TrainFeature/History/HistoryModel.swift`, `HistoryView.swift`, `SessionDetailModel.swift`, `SessionDetailView.swift`
- Modify: `Sources/TrainFeature/Views/TrainView.swift`
- Test: `Tests/TrainFeatureTests/HistoryModelTests.swift`, `SessionDetailModelTests.swift`

**Interfaces:**
- Consumes : tâches 6, 8, 12, 13 et 15.
- Produces :
  - `@MainActor @Observable public final class HistoryModel` : `init(environment:)`, `load() async`. Publie `months: [HistoryMonth]`, avec `public struct HistoryMonth: Identifiable, Equatable { title: String /* « octobre 2026 » */; sessions: [HistoryLine] }` et `public struct HistoryLine: Identifiable, Equatable { id: UUID; title; date: Date; durationMinutes: Int?; workingSets: Int; tonnageKg: Double; recordCount: Int; isImported: Bool; isAbandoned: Bool }`. Séances `completed` et `abandoned`, de la plus récente à la plus ancienne. Méthode : `removeImported() async throws -> Int` (via `HevyImporter.removeImportedSessions`, confirmation dans la vue).
  - `@MainActor @Observable public final class SessionDetailModel` : `init(environment:sessionID:)`, `load() async`. Publie `session`, `blocks: [SessionExerciseBlock]` (exercice, note, séries « 70 × 5 », type, RPE, record) et `muscleLevels` (via `MuscleIntensity.levels`, poids de la spec M3 §6.3). Méthodes : `saveAsRoutine() async throws -> (programID: UUID, dayID: UUID)` (via `RoutineFromSession` et `ProgramEditor.addDay`, dans le programme actif, ou dans un nouveau programme actif nommé « Mon programme » s'il n'y en a pas) et `delete() async throws` (suppression logique, puis `RecordsService.recomputeAll`).
  - Vues : `HistoryView` (sections par mois, pastille « Hevy », action « Supprimer toutes les séances importées de Hevy »), `SessionDetailView` (lecture seule, carte musculaire, notes, « Enregistrer comme routine » qui ouvre ensuite l'éditeur de la tâche 15, « Supprimer » avec confirmation).

- [ ] **Step 1 : Écrire les tests qui échouent**

```swift
@MainActor @Test func historyGroupsByMonthNewestFirst() async {
    // Séances : 28 sept (Hevy), 12 oct (Hevy), 27 oct (Pulse, abandonnée).
    let model = HistoryModel(environment: environment)
    await model.load()
    #expect(model.months.map(\.title) == ["octobre 2026", "septembre 2026"])
    #expect(model.months[0].sessions.map(\.isImported) == [false, true])
    #expect(model.months[0].sessions[0].isAbandoned)
}

@MainActor @Test func savingAnImportedSessionAsRoutineAddsItToTheActiveProgram() async throws {
    let model = SessionDetailModel(environment: environment, sessionID: hevyPush.id)
    await model.load()
    let (programID, dayID) = try await model.saveAsRoutine()
    let program = try #require(try await programs.program(id: programID))
    #expect(program.days.first { $0.id == dayID }?.name == "Push")
    #expect(try await profiles.load()?.activeProgramID == programID)
}

@MainActor @Test func deletingASessionRecomputesRecords() async throws { … }
```

- [ ] **Step 2 : Lancer, vérifier l'échec** — Run : `swift test --package-path Packages/PulseFeatures --filter TrainFeatureTests` — Expected : FAIL à la compilation.

- [ ] **Step 3 : Implémenter les modèles, les vues et leurs aperçus.**

- [ ] **Step 4 : Lancer, vérifier le succès** — Run : `swift test --package-path Packages/PulseFeatures` puis, hors bac à sable, `make build-app` — Expected : vert ; code 0.

- [ ] **Step 5 : VFT, puis commit**

```bash
git add Packages/PulseFeatures/Sources/TrainFeature Packages/PulseFeatures/Tests/TrainFeatureTests
git commit -m "feat(train): browse past sessions, save one as a routine, delete sessions"
```

---

### Task 17 : Parcours d'import Hevy

**Files:**
- Create: `Packages/PulseFeatures/Sources/TrainFeature/Import/HevyImportModel.swift`, `HevyImportFlow.swift`, `HevyIntroView.swift`, `HevySummaryView.swift`, `HevyMappingView.swift`, `HevyMappingRow.swift`, `HevyResultView.swift`
- Modify: `Sources/TrainFeature/Views/TrainView.swift`
- Test: `Tests/TrainFeatureTests/HevyImportModelTests.swift`

**Interfaces:**
- Consumes : tâches 11, 12, 13, 14 (bibliothèque en mode choix, formulaire d'exercice perso) et 16 (lien vers l'historique).
- Produces :
  - `@MainActor @Observable public final class HevyImportModel` : `init(environment:)`. Publie :
    - `step` : `public enum HevyImportStep: Equatable { case intro, reading, summary, mapping, importing(progress: Double), done(HevyImportResult), failed(String) }` ;
    - `preview: HevyImportPreview?`, `choices: [String: HevyMappingChoice]`, `canImport: Bool` ;
    - `unresolvedCount: Int` (noms dont le brouillon a `needsReview` et n'a pas été ouvert ; information seulement : le choix par défaut reste valable, et l'import n'est pas bloqué) ;
    - `sureNames`, `toChooseNames`, `ignoredNames` (sections de la correspondance).
    Méthodes :
    - `read(_ data: Data) async` ; `choose(_ choice: HevyMappingChoice, for name: String)` ; `markReviewed(_ name: String)` ;
    - `start() async` (lance `HevyImporter.run` et suit la progression) ;
    - `message(for error: any Error) -> String` : textes français pour `notHevyExport` (« Ce fichier n'est pas un export de séances Hevy. »), `empty` et une erreur d'enregistrement.
  - Vues (spec M4 §13.3) :
    - `HevyIntroView` : où trouver l'export dans Hevy, puis `fileImporter` (`.commaSeparatedText`), avec accès à la ressource à portée de sécurité pendant la lecture.
    - `HevySummaryView` : séances nouvelles, période, exercices, cardio ignoré, séances déjà présentes.
    - `HevyMappingView` : sections « Correspondances sûres », « À choisir », « Ignorés », chaque ligne avec son nombre de séances et son choix ; toucher ouvre un menu : exercice Pulse (`LibraryView` en mode choix simple), « Créer un exercice perso » (`CustomExerciseForm` pré-rempli, marqué « à vérifier »), « Ignorer ».
    - `HevyResultView` : bilan et lien « Voir l'historique ».

- [ ] **Step 1 : Écrire les tests qui échouent**

```swift
@MainActor @Test func readingAnExportGoesToTheSummaryWithDefaultChoices() async {
    let model = HevyImportModel(environment: environment)
    await model.read(Data(HevyFixtures.csv.utf8))
    #expect(model.step == .summary)
    #expect(model.choices["Écarté (Machine)"] == .content(id: "pec-deck-machine"))
    #expect(model.ignoredNames.map(\.name) == ["Tapis de Course"])
    #expect(model.canImport)
}

@MainActor @Test func aWrongFileShowsAFrenchMessage() async {
    let model = HevyImportModel(environment: environment)
    await model.read(Data("a,b\n1,2\n".utf8))
    #expect(model.step == .failed("Ce fichier n'est pas un export de séances Hevy."))
}

@MainActor @Test func importingReportsProgressAndTheResult() async {
    // choose(.content(id: "triceps-pushdown-cable"), for: "Extension Triceps Poulie Haute") puis start().
    guard case .done(let result) = model.step else { Issue.record("import non terminé"); return }
    #expect(result.importedSessions == 2)
}
```

`HevyFixtures` vit dans `PulseServicesTests`. Recopier l'extrait (inventé) dans `Tests/TrainFeatureTests/Support/HevyFixtures.swift`, ou le rendre accessible par une petite cible de support de test partagée, au choix de l'implémenteur.

- [ ] **Step 2 : Lancer, vérifier l'échec** — Run : `swift test --package-path Packages/PulseFeatures --filter HevyImportModelTests` — Expected : FAIL à la compilation.

- [ ] **Step 3 : Implémenter le modèle, les vues et leurs aperçus.**

- [ ] **Step 4 : Lancer, vérifier le succès** — Run : `swift test --package-path Packages/PulseFeatures` puis, hors bac à sable, `make build-app` et `make build-release` — Expected : vert ; codes 0.

- [ ] **Step 5 : VFT complète (tous les packages : `make test-packages`), puis commit**

```bash
git add Packages/PulseFeatures/Sources/TrainFeature Packages/PulseFeatures/Tests/TrainFeatureTests
git commit -m "feat(train): import Hevy history with an exercise matching review"
```

---

## Fin de M4a

- `make test-packages` vert, `swiftlint lint --strict` à 0, `make build-app` et `make build-release` réussis (hors bac à sable).
- Revue finale de toute la branche par Opus, puis correction de ses retours.
- PR `m4-programmes-seance-live` → `master` **seulement après l'accord explicite de Mathéo pour pousser** (`git push origin m4-programmes-seance-live`). La description se termine par « 🤖 Generated with [Claude Code](https://claude.com/claude-code) » et rappelle ce qui revient à Mathéo :
  - lancer `make test-app` ;
  - sur l'iPhone, importer son export Hevy, vérifier les correspondances et construire son PPL ;
  - déployer le schéma CloudKit V3 en production avant le premier TestFlight qui synchronise ;
  - garder des versions identiques dans les deux `Info.plist`.
