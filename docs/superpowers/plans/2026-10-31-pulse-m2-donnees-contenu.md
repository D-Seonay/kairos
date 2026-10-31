# Pulse M2 — Données et contenu : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deux nouveaux packages testés, `PulseContent` (80 exercices et 5 modèles de programme en JSON, validés par test) et `PulsePersistence` (SwiftData + CloudKit derrière des protocoles de dépôt, export JSON et CSV, suppression totale), plus un écran de debug « Données » dans l'app.

**Architecture:** Les entités et les protocoles de dépôt vivent dans `PulseDomain` (Foundation seulement). `PulseContent` décode le JSON du bundle en entités du domaine et les valide. `PulsePersistence` porte les modèles `@Model` (préfixe `Stored`), le conteneur à deux configurations (synchronisée CloudKit, locale), les dépôts `@ModelActor`, l'export et l'effacement. L'app assemble tout dans `AppDependencies` et affiche un écran de debug temporaire. Le projet Xcode est régénéré une seule fois avec des dossiers synchronisés : plus aucune édition de `pbxproj` ensuite.

**Tech Stack:** Swift 6.4 (mode de langage 6), SwiftUI, SwiftData, CloudKit, Swift Testing, SwiftPM, XcodeGen 2.46 (une fois), SwiftLint, Xcode 27.0.

**Spec:** `docs/superpowers/specs/2026-10-31-pulse-m2-donnees-contenu-design.md` (la « spec M2 »), qui complète `docs/superpowers/specs/2026-10-31-pulse-v1-design.md` (§4, §5.4, §5.9, §8, §9, §12).

## Global Constraints

- Xcode **27.0**, Swift **6.4**, cible **iOS 26**, `swift-tools-version: 6.2`, `swiftSettings: [.swiftLanguageMode(.v6)]` sur chaque cible. Packages testables sur Mac : `platforms: [.iOS(.v26), .macOS(.v15)]`.
- `PulseDomain` et `PulseContent` : **aucun import autre que Foundation**. `PulsePersistence` importe SwiftData et CloudKit, jamais HealthKit ni SwiftUI.
- Tests en **Swift Testing**. Packages : `swift test --package-path Packages/<Nom>`. App : `xcodebuild build-for-testing` puis `xcodebuild test-without-building -scheme Pulse -destination 'platform=iOS Simulator,name=iPhone 17'`, toujours **hors bac à sable du shell** (sinon blocage). Avec `-quiet`, Xcode 27 n'affiche pas `** TEST SUCCEEDED **` : juger sur le code de sortie 0, ou lancer sans `-quiet` et lire `✔ Test run with N tests`.
- SwiftLint strict : les avertissements sont des erreurs. Donc **≤ 400 lignes par fichier**, **≤ 50 lignes par corps de fonction**, lignes ≤ 140, imports triés, pas de `!` (`force_unwrapping`) hors tests marqués `// swiftlint:disable force_unwrapping`.
- Contraintes CloudKit sur chaque `@Model` synchronisé : aucune `@Attribute(.unique)`, chaque attribut optionnel ou avec valeur par défaut dans la déclaration, chaque relation optionnelle avec inverse, cascade du parent vers l'enfant.
- Identifiants de contenu : `^[a-z0-9]+(-[a-z0-9]+)*$`, stables. Énumérations stockées et exportées par `rawValue`. Poids en kg, dates `Date`, « jour » = minuit local.
- Chaînes visibles : français, `String(localized:)` (`bundle: .module` dans un package). Aucune donnée de santé dans les journaux.
- Commits `type(scope): description` en anglais, **sans** trailer Co-Authored-By. Ne jamais pousser sur `origin` sans accord de Mathéo. Branche : `m2-donnees-contenu`.
- Fichiers de la cible app : une fois la tâche 1 faite, tout fichier sous `Pulse/` ou `PulseTests/` est compilé automatiquement (dossiers synchronisés). Ne pas rouvrir `project.yml` : il est supprimé en fin de tâche 1.

## Review Focus

1. **Restauration iCloud qui crée deux profils** (deux `StoredProfile` après réinstallation) : l'app doit continuer avec le plus ancien, jamais planter ni en créer un troisième. Test en tâche 13.
2. **Valeur de texte contenant virgule, guillemet ou retour à la ligne** (note de séance « Dos ok, "lourd" ») : le CSV doit rester relisible par Numbers. Test en tâche 17.
3. **Série qui référence un exercice de contenu inconnu ou retiré** (contenu renommé dans une version future) : l'export garde `exerciseName`, l'écran ne plante pas. Tests en tâches 9 et 16.
4. **Effacement Apple Santé qui échoue après l'effacement local** : le local doit être vide quand même et l'erreur remontée. Test en tâche 18.
5. **Score enregistré à 23 h 59 puis à 0 h 01 pour le même jour** : `RecoveryRepository.save` normalise `day` à minuit local et remplace. Test en tâche 14.

---

## Structure des fichiers créés ou modifiés

```
project.yml                                   (temporaire, supprimé en tâche 1)
Pulse.xcodeproj/                              (régénéré, dossiers synchronisés)
Pulse/Info.plist                              (+ UIBackgroundModes remote-notification)
Pulse/Pulse.entitlements                      (+ iCloud / CloudKit)
Pulse/Localizable.xcstrings
Pulse/PulseApp.swift                          (RootTabView)
Pulse/AppDependencies.swift                   (+ conteneur, contenu, dépôts)
Pulse/RootTabView.swift
Pulse/Debug/DataDebugModel.swift
Pulse/Debug/DataDebugView.swift
Pulse/Debug/ContentExercisesView.swift
Pulse/Debug/ContentTemplatesView.swift
Pulse/Debug/EraseConfirmationView.swift
PulseTests/DataDebugModelTests.swift
Makefile                                      (+ PulseContent, PulsePersistence, build-for-testing)
Packages/PulseDomain/Sources/PulseDomain/
  Content/LocalizedText.swift                 LocalizedText, LocalizedList
  Content/ContentEnums.swift                  Muscle, Equipment, MovementPattern, BodyRegion, LoadKind
  Content/Exercise.swift                      Exercise, ExerciseCatalog
  Content/ProgramTemplate.swift               ProgramTemplate, TemplateDay, TemplateExercise, RunTarget, TrainingFocus, RoutineDayKind, RunType
  Training/ExerciseReference.swift
  Training/UserProfile.swift                  UserProfile + Sex, TrainingLevel, Weekday, EquipmentAccess, PainArea, WeightUnit, AntiInterferenceRule, Theme
  Training/Program.swift                      Program, RoutineDay, RoutineExercise
  Training/UserExercise.swift
  Training/WorkoutSession.swift               WorkoutSession, SessionKind, SessionSource, SessionStatus, SessionAdjustment, AdjustmentKind
  Training/WorkoutSet.swift                   WorkoutSet, SetType, ReplacementReason
  Training/ScheduledDay.swift                 ScheduledDay, ScheduledDayKind, ScheduledDayStatus, MoveReason
  Recovery/DailyRecovery.swift
  Recovery/CheckIn.swift                      CheckIn, CheckInAnswers (déplacé depuis le moteur)
  Supplements/Supplement.swift                Supplement, SupplementForm, DoseUnit, SupplementTiming, SupplementDays
  Supplements/SupplementIntake.swift
  Body/BodyMeasurement.swift                  BodyMeasurement, MeasurementSource
  Records/PersonalRecord.swift                PersonalRecord, RecordKind
  Local/CachedHealthSample.swift              CachedHealthSample, HealthSampleKind
  Local/ActiveSessionSnapshot.swift
  Repositories/*.swift                        un protocole par fichier (§5.5 de la spec M2), StoreTable, EraseOptions, CloudAccountStatus, HealthErasing + StubHealthEraser, NotificationCanceling
  Export/ExportDocument.swift                 ExportDocument, ExportUnits, ExportCoding
Packages/PulseDomain/Tests/PulseDomainTests/  ContentTypesTests, ExerciseReferenceTests, TrainingTypesTests, RecoveryAndSupplementTypesTests, ExportDocumentTests
Packages/PulseContent/
  Package.swift
  Sources/PulseContent/ContentLibrary.swift
  Sources/PulseContent/ContentValidator.swift
  Sources/PulseContent/ContentEnums+Localized.swift
  Sources/PulseContent/Resources/exercises.json
  Sources/PulseContent/Resources/programs.json
  Sources/PulseContent/Resources/Programs/{ppl-3,ppl-6,upper-lower,full-body,runner-strength}.json
  Sources/PulseContent/Resources/Localizable.xcstrings
  Tests/PulseContentTests/ContentLibraryTests, ContentValidatorTests, BundledExercisesTests, BundledProgramsTests, LocalizedNamesTests, Support/Fixtures.swift
Packages/PulsePersistence/
  Package.swift
  Sources/PulsePersistence/Schema/PulseSchemaV1.swift, PulseMigrationPlan.swift, PersistenceStack.swift
  Sources/PulsePersistence/Models/Stored*.swift          un fichier par modèle, mapping inclus
  Sources/PulsePersistence/Models/CodableColumn.swift     encodage Data JSON des tableaux
  Sources/PulsePersistence/Repositories/SwiftData*Repository.swift
  Sources/PulsePersistence/Repositories/SwiftDataHealthSampleCache.swift, SwiftDataActiveSessionStore.swift, SwiftDataStoreInspector.swift
  Sources/PulsePersistence/Export/ExportSnapshotLoader.swift, JSONExportWriter.swift, CSVWriter.swift, CSVTables.swift, ZipArchiver.swift, SwiftDataExporter.swift
  Sources/PulsePersistence/Erase/StoreWiper.swift, SwiftDataEraser.swift
  Sources/PulsePersistence/Sample/SampleDataSeeder.swift
  Tests/PulsePersistenceTests/…                            un fichier de test par fichier source, Support/TestContainer.swift
```

---

### Task 1 : Projet Xcode à dossiers synchronisés, nouveaux packages vides, entitlements iCloud

**Files:**
- Create: `project.yml` (temporaire), `Packages/PulseContent/Package.swift`, `Packages/PulseContent/Sources/PulseContent/PulseContent.swift`, `Packages/PulsePersistence/Package.swift`, `Packages/PulsePersistence/Sources/PulsePersistence/PulsePersistence.swift`
- Modify: `Pulse.xcodeproj/project.pbxproj` (régénéré), `Pulse/Pulse.entitlements`, `Pulse/Info.plist`, `Makefile`
- Delete: `Packages/PulseDomain/.gitignore`, `Packages/PulseRecoveryEngine/.gitignore`, `project.yml` (en fin de tâche)

**Interfaces:**
- Produces : un projet où `Pulse/` et `PulseTests/` sont des `PBXFileSystemSynchronizedRootGroup` ; cinq packages locaux liés à la cible `Pulse` ; schéma `Pulse` qui teste les cinq packages et `PulseTests` ; `make test-packages` qui couvre `PulseDomain`, `PulseRecoveryEngine`, `PulseContent`, `PulsePersistence`.

- [ ] **Step 1 : Créer les deux packages vides**

`Packages/PulseContent/Package.swift` : nom `PulseContent`, `defaultLocalization: "fr"`, `platforms: [.iOS(.v26), .macOS(.v15)]`, produit bibliothèque `PulseContent`, cible `PulseContent` dépendant de `PulseDomain` (`.package(path: "../PulseDomain")`) avec `resources: [.process("Resources")]`, cible de test `PulseContentTests`, mode Swift 6 partout. `Packages/PulsePersistence/Package.swift` : idem sans localisation ni ressources, nom `PulsePersistence`, dépend de `PulseDomain`. Chaque package reçoit un fichier source `public enum PulseContent {}` / `public enum PulsePersistence {}` (remplacés plus tard) et un dossier `Resources/` contenant un `Localizable.xcstrings` minimal (`{"sourceLanguage":"fr","strings":{},"version":"1.0"}`) pour `PulseContent`.

Run : `swift build --package-path Packages/PulseContent && swift build --package-path Packages/PulsePersistence`
Expected : deux builds verts.

- [ ] **Step 2 : Écrire `project.yml`**

Partir de `git show 0a30786:project.yml` et appliquer exactement ces changements :
- `sources: [Pulse]` → `sources:\n      - path: Pulse\n        type: syncedFolder` ; même chose pour `PulseTests`.
- `packages:` : ajouter `PulseContent: { path: Packages/PulseContent }` et `PulsePersistence: { path: Packages/PulsePersistence }` ; `dependencies:` de la cible `Pulse` : ajouter `- package: PulseContent` et `- package: PulsePersistence`.
- `settings.base` de la cible `Pulse` : ajouter `DEVELOPMENT_TEAM: UP9NVJDBKA` (valeur présente dans le `pbxproj` actuel, posée par Mathéo).
- `info.properties` : ajouter `UIBackgroundModes: [remote-notification]`.
- `entitlements.properties` : ajouter `com.apple.developer.icloud-services: [CloudKit]`, `com.apple.developer.icloud-container-identifiers: [iCloud.fr.seonay.pulse]`.
- `schemes.Pulse.test.targets` : ajouter `- package: PulseContent/PulseContentTests` et `- package: PulsePersistence/PulsePersistenceTests`.

- [ ] **Step 3 : Régénérer et vérifier le résultat**

Run : `xcodegen generate && grep -c PBXFileSystemSynchronizedRootGroup Pulse.xcodeproj/project.pbxproj && grep -c "DEVELOPMENT_TEAM = UP9NVJDBKA" Pulse.xcodeproj/project.pbxproj && grep -A2 "icloud-container" Pulse/Pulse.entitlements`
Expected : `4` (deux groupes, deux références), `2`, et l'identifiant `iCloud.fr.seonay.pulse`.

- [ ] **Step 4 : Mettre à jour `Makefile`**

```make
DEST = platform=iOS Simulator,name=iPhone 17
.PHONY: test test-packages test-app lint
test: lint test-packages test-app
test-packages:
	swift test --package-path Packages/PulseDomain
	swift test --package-path Packages/PulseRecoveryEngine
	swift test --package-path Packages/PulseContent
	swift test --package-path Packages/PulsePersistence
test-app:
	xcodebuild build-for-testing -scheme Pulse -destination '$(DEST)' -quiet
	xcodebuild test-without-building -scheme Pulse -destination '$(DEST)' -quiet
lint:
	swiftlint lint --strict
```

- [ ] **Step 5 : Supprimer les `.gitignore` redondants et `project.yml`, puis tester l'app**

Run : `rm Packages/PulseDomain/.gitignore Packages/PulseRecoveryEngine/.gitignore project.yml && make test-app` (hors bac à sable)
Expected : code de sortie 0 ; les tests M1 (`PulseTests`, trois packages) passent toujours.

- [ ] **Step 6 : Commit**

```bash
git add -A
git commit -m "chore(project): regenerate project with synced folders, iCloud entitlements and empty M2 packages"
```

---

### Task 2 : Types de contenu dans `PulseDomain`

**Files:**
- Create: `Packages/PulseDomain/Sources/PulseDomain/Content/LocalizedText.swift`, `Content/ContentEnums.swift`, `Content/Exercise.swift`, `Content/ProgramTemplate.swift`
- Test: `Packages/PulseDomain/Tests/PulseDomainTests/ContentTypesTests.swift`

**Interfaces:**
- Produces (tous `Sendable, Equatable, Codable`, propriétés `public var`, init public membre à membre) :
  - `struct LocalizedText { fr: String; en: String? }`, `struct LocalizedList { fr: [String]; en: [String]? }`.
  - `enum Muscle: String, CaseIterable` (20 valeurs de la spec M2 §4.1, dans cet ordre), `enum Equipment: String, CaseIterable` (9), `enum MovementPattern: String, CaseIterable` (19), `enum BodyRegion: String, CaseIterable { upper, lower, core }`, `enum LoadKind: String, CaseIterable { external, bodyweight, assisted }`.
  - `struct Exercise: Identifiable { id: String; name: LocalizedText; primaryMuscles: [Muscle]; secondaryMuscles: [Muscle]; equipment: Equipment; pattern: MovementPattern; region: BodyRegion; isCompound: Bool; isUnilateral: Bool; loadKind: LoadKind; defaultIncrementKg: Double; defaultRestSeconds: Int; cues: LocalizedList; mistakes: LocalizedList; alternatives: [String]; retired: Bool }` — décodage : `retired` absent → `false` (init(from:) manuel ; tous les autres champs obligatoires).
  - `struct ExerciseCatalog { schemaVersion: Int; contentVersion: String; exercises: [Exercise] }`.
  - `enum TrainingFocus: String, CaseIterable { strength, balanced, endurance }`, `enum RoutineDayKind: String { strength, run }`, `enum RunType: String { easy, intervals, long }`.
  - `struct RunTarget { type: RunType; targetMinutes: Int?; targetKm: Double? }`, `struct TemplateExercise { exercise: String; sets: Int; repsMin: Int; repsMax: Int; targetRPE: Double; restSeconds: Int; supersetGroup: Int? }`, `struct TemplateDay: Identifiable { id: String; name: LocalizedText; kind: RoutineDayKind; exercises: [TemplateExercise]; run: RunTarget? }` (décodage : `exercises` absent → `[]`), `struct TemplateRecommendation { focus: TrainingFocus; daysPerWeek: [Int] }`, `struct ProgramTemplate: Identifiable { schemaVersion: Int; id: String; name: LocalizedText; summary: LocalizedText; recommendedFor: TemplateRecommendation; sessionsPerWeek: Int; days: [TemplateDay]; suggestedWeek: [String?] }`.

- [ ] **Step 1 : Écrire les tests**

```swift
@Test func exerciseDecodesFromSpecExampleAndDefaultsRetired() throws {
    // JSON de l'exemple §4.1 de la spec M2, sans la clé "retired"
    let exercise = try JSONDecoder().decode(Exercise.self, from: specExampleJSON)
    #expect(exercise.id == "bench-press-barbell")
    #expect(exercise.primaryMuscles == [.chest])
    #expect(exercise.secondaryMuscles == [.frontDelts, .triceps])
    #expect(exercise.pattern == .horizontalPush)
    #expect(exercise.cues.fr.count == 3)
    #expect(exercise.alternatives == ["chest-press-machine", "bench-press-dumbbell", "incline-chest-press-machine"])
    #expect(exercise.retired == false)
}

@Test func exerciseRoundTripsThroughJSON() throws   // encode puis decode == original, avec retired: true et name.en nil

@Test func templateDecodesNullsInSuggestedWeekAndMissingExercises() throws {
    // JSON de l'exemple §4.3 : un jour "run" sans clé "exercises"
    let template = try JSONDecoder().decode(ProgramTemplate.self, from: specTemplateJSON)
    #expect(template.suggestedWeek == ["push", nil, "pull", nil, "legs", nil, nil])
    #expect(template.days[1].kind == .run)
    #expect(template.days[1].exercises.isEmpty)
    #expect(template.days[1].run == RunTarget(type: .easy, targetMinutes: 40, targetKm: nil))
    #expect(template.days[0].exercises[1].supersetGroup == 1)
}

@Test func enumCountsMatchSpec() {
    #expect(Muscle.allCases.count == 20)
    #expect(Equipment.allCases.count == 9)
    #expect(MovementPattern.allCases.count == 19)
}
```

- [ ] **Step 2 : Lancer pour vérifier l'échec**

Run : `swift test --package-path Packages/PulseDomain`
Expected : erreur de compilation, `Exercise` introuvable.

- [ ] **Step 3 : Écrire les quatre fichiers listés dans Interfaces**

- [ ] **Step 4 : Lancer les tests**

Run : `swift test --package-path Packages/PulseDomain`
Expected : tous verts.

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulseDomain
git commit -m "feat(domain): add exercise and program template content types"
```

---

### Task 3 : Référence d'exercice, profil, programme, exercice personnalisé

**Files:**
- Create: `Packages/PulseDomain/Sources/PulseDomain/Training/ExerciseReference.swift`, `Training/UserProfile.swift`, `Training/Program.swift`, `Training/UserExercise.swift`
- Test: `Packages/PulseDomain/Tests/PulseDomainTests/ExerciseReferenceTests.swift`, `TrainingTypesTests.swift`

**Interfaces:**
- Produces (tous `Sendable, Equatable, Codable`, `public var`, init public ; les entités synchronisées ont `id: UUID`, `createdAt: Date`, `updatedAt: Date`) :
  - `enum ExerciseReference: Hashable { case content(id: String); case user(id: UUID) }` avec `Codable` **manuel** : `{"content":"bench-press-barbell"}` / `{"user":"<uuid>"}` ; décodage d'un objet sans ces clés → `DecodingError.dataCorrupted`. Propriétés `contentID: String?`, `userID: UUID?`, `init?(contentID: String?, userID: UUID?)` (nil si les deux ou aucun ne sont renseignés).
  - `enum Sex: String { female, male, unspecified }`, `enum TrainingLevel: String { beginner, intermediate, advanced }`, `enum Weekday: String, CaseIterable { monday, tuesday, wednesday, thursday, friday, saturday, sunday }`, `enum EquipmentAccess: String { fullGym, homeGym, bodyweight }`, `enum PainArea: String { shoulders, lowerBack, knees, wrists }`, `enum WeightUnit: String { kg, lb }`, `enum AntiInterferenceRule: String { noIntenseRunAfterHeavyLegs, sameDayOrdering, fullRestDay }`, `enum Theme: String { amber, amethyst }`.
  - `struct UserProfile: Identifiable` avec les champs de la spec M2 §5.3 et un `init` dont **chaque paramètre a une valeur par défaut** (celles de la spec : `focus 0.5`, `trainingDaysPerWeek 3`, `adaptationEnabled true`, `upperIncrementKg 2.5`, `lowerIncrementKg 5`, `barWeightKg 20`, `availablePlatesKg [25, 20, 15, 10, 5, 2.5, 1.25]`, `defaultRestSeconds 90`, `autoWarmupEnabled true`, `theme .amber`, `weightUnit .kg`, `sex .unspecified`, niveaux `.beginner`, `strengthLevel`, `runningLevel`, booléens de notification `true`, `id UUID()`, dates `Date()`).
  - `struct RoutineExercise: Identifiable { id: UUID; order: Int; exercise: ExerciseReference; sets: Int; repsMin: Int; repsMax: Int; targetRPE: Double; restSeconds: Int; supersetGroup: Int? }`, `struct RoutineDay: Identifiable { id: UUID; order: Int; name: String; kind: RoutineDayKind; runType: RunType?; runTargetMinutes: Int?; runTargetKm: Double?; exercises: [RoutineExercise] }`, `struct Program: Identifiable { id; name: String; templateID: String?; sessionsPerWeek: Int; weekLayout: [UUID?] (7 entrées); isArchived: Bool; days: [RoutineDay]; createdAt; updatedAt }`.
  - `extension Program { public init(template: ProgramTemplate, now: Date) }` : copie le modèle (un `RoutineDay` par `TemplateDay` dans l'ordre, `exercise: .content(id:)`, `name = name.fr`, `weekLayout` traduit `suggestedWeek` en identifiants des jours créés, `templateID = template.id`).
  - `struct UserExercise: Identifiable { id; name; primaryMuscle: Muscle; secondaryMuscles: [Muscle]; equipment: Equipment; pattern: MovementPattern; region: BodyRegion; isUnilateral: Bool; defaultIncrementKg: Double; defaultRestSeconds: Int; isArchived: Bool; createdAt; updatedAt }`.

- [ ] **Step 1 : Écrire les tests**

```swift
@Test func exerciseReferenceEncodesReadably() throws {
    let content = try String(decoding: JSONEncoder().encode(ExerciseReference.content(id: "plank")), as: UTF8.self)
    #expect(content == #"{"content":"plank"}"#)
    let uuid = UUID()
    let user = try JSONDecoder().decode(ExerciseReference.self, from: Data(#"{"user":"\#(uuid.uuidString)"}"#.utf8))
    #expect(user == .user(id: uuid))
    #expect(throws: DecodingError.self) { try JSONDecoder().decode(ExerciseReference.self, from: Data(#"{"other":"x"}"#.utf8)) }
}

@Test func exerciseReferenceColumns() {
    #expect(ExerciseReference(contentID: "plank", userID: nil) == .content(id: "plank"))
    #expect(ExerciseReference(contentID: nil, userID: nil) == nil)
    #expect(ExerciseReference(contentID: "a", userID: UUID()) == nil)
    #expect(ExerciseReference.content(id: "plank").contentID == "plank")
}

@Test func defaultProfileMatchesSpec() {
    let profile = UserProfile()
    #expect(profile.focus == 0.5)
    #expect(profile.availablePlatesKg == [25, 20, 15, 10, 5, 2.5, 1.25])
    #expect(profile.barWeightKg == 20)
    #expect(profile.defaultRestSeconds == 90)
    #expect(profile.sex == .unspecified && profile.theme == .amber)
}

@Test func programFromTemplateCopiesDaysAndWeek() throws {
    // template §4.3 de la spec (push, easy-run) avec suggestedWeek ["push", nil, "easy-run", nil, nil, nil, nil]
    let program = Program(template: template, now: Date(timeIntervalSince1970: 0))
    #expect(program.templateID == "ppl-3")
    #expect(program.days.count == 2)
    #expect(program.days[0].exercises[0].exercise == .content(id: "bench-press-barbell"))
    #expect(program.days[1].kind == .run && program.days[1].runType == .easy && program.days[1].runTargetMinutes == 40)
    #expect(program.weekLayout == [program.days[0].id, nil, program.days[1].id, nil, nil, nil, nil])
}

@Test func trainingTypesRoundTrip() throws  // UserProfile, Program (avec 2 jours), UserExercise : encode → decode == original
```

- [ ] **Step 2 : Lancer pour vérifier l'échec**

Run : `swift test --package-path Packages/PulseDomain`
Expected : erreur de compilation.

- [ ] **Step 3 : Écrire les quatre fichiers**

- [ ] **Step 4 : Lancer les tests**

Run : `swift test --package-path Packages/PulseDomain`
Expected : verts.

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulseDomain
git commit -m "feat(domain): add exercise reference, user profile, program and user exercise"
```

---

### Task 4 : Séances, séries, semaine datée, récupération, check-in

**Files:**
- Create: `Packages/PulseDomain/Sources/PulseDomain/Training/WorkoutSession.swift`, `Training/WorkoutSet.swift`, `Training/ScheduledDay.swift`, `Recovery/DailyRecovery.swift`, `Recovery/CheckIn.swift`
- Modify: `Packages/PulseRecoveryEngine/Sources/PulseRecoveryEngine/Scoring/CheckInScorer.swift` → ne garde que `CheckInScorer` et gagne `import PulseDomain` ; `CheckInAnswers` part dans `PulseDomain/Recovery/CheckIn.swift`
- Modify: `Packages/PulseRecoveryEngine/Tests/PulseRecoveryEngineTests/CheckInScorerTests.swift` (+ `import PulseDomain`)
- Test: `Packages/PulseDomain/Tests/PulseDomainTests/RecoveryAndSessionTypesTests.swift`

**Interfaces:**
- Produces :
  - `enum SessionKind: String { strength, run, ride }`, `enum SessionSource: String { pulse, appleHealth }`, `enum SessionStatus: String { inProgress, completed, abandoned }`, `enum AdjustmentKind: String { volume, rpeCap, rest, load, replaceWithMobility, suggestRest, swapIntervalsForEasy, deload }`, `struct SessionAdjustment { kind: AdjustmentKind; reason: String; value: Double? }`.
  - `struct WorkoutSession: Identifiable { id; startedAt; endedAt: Date?; kind; source; status; programID: UUID?; routineDayID: UUID?; title: String; appliedAdjustments: [SessionAdjustment]; refusedAdjustments: [SessionAdjustment]; overallRPE: Double?; note: String?; tonnageKg: Double; durationMinutes: Double?; distanceMeters: Double?; averageHeartRate: Double?; estimatedRPE: Double?; healthKitUUID: String?; sets: [WorkoutSet]; createdAt; updatedAt }`.
  - `enum SetType: String { warmup, working, drop, failure }`, `enum ReplacementReason: String { machineBusy, pain, other }`, `struct WorkoutSet: Identifiable { id; order: Int; exercise: ExerciseReference; exerciseName: String; setType; supersetGroup: Int?; plannedWeightKg: Double?; plannedReps: Int?; actualWeightKg: Double?; actualReps: Int?; rpe: Double?; restSeconds: Int?; completedAt: Date?; isPersonalRecord: Bool; replacedExercise: ExerciseReference?; replacementReason: ReplacementReason? }` + `var isMissed: Bool` (vrai si `actualReps` et `plannedReps` renseignés et `actualReps < plannedReps`).
  - `enum ScheduledDayKind: String { strength, run, rest }`, `enum ScheduledDayStatus: String { planned, completed, skipped }`, `enum MoveReason: String { antiInterferenceAfterHeavyLegs, antiInterferenceSameDay, antiInterferenceRestDay, user }`, `struct ScheduledDay: Identifiable { id; date; programID: UUID?; routineDayID: UUID?; title; kind; status; movedFromDate: Date?; moveReason: MoveReason?; moveReasonText: String?; validatedManually: Bool; sessionID: UUID?; createdAt; updatedAt }`.
  - `struct DailyRecovery: Identifiable { id; day; score: Double; category: RecoveryCategory; isEstimated: Bool; hrvScore, restingHeartRateScore, sleepScore: Double?; sdnnMs, sdnnBaselineMs, restingHeartRate, restingHeartRateBaseline: Double?; asleepMinutes, deepMinutes: Int?; missingFactors: [Factor]; calibration: CalibrationState; adjustments: [SessionAdjustment]; frozenAt: Date?; createdAt; updatedAt }`.
  - `struct CheckInAnswers { sleep, pain, motivation: Int }` (déplacée telle quelle), `struct CheckIn: Identifiable { id; day; answers: CheckInAnswers; score: Double; createdAt; updatedAt }`.

- [ ] **Step 1 : Écrire les tests**

```swift
@Test func missedSetIsDerived() {
    var set = WorkoutSet(id: UUID(), order: 1, exercise: .content(id: "plank"), exerciseName: "Planche", setType: .working, ...)
    set.plannedReps = 8; set.actualReps = 3
    #expect(set.isMissed)
    set.actualReps = 8
    #expect(!set.isMissed)
    set.plannedReps = nil
    #expect(!set.isMissed)
}

@Test func sessionWithSetsRoundTrips() throws   // séance 2 séries dont une avec replacedExercise et replacementReason, appliedAdjustments non vide
@Test func scheduledDayAndRecoveryRoundTrip() throws   // ScheduledDay avec moveReason ; DailyRecovery avec calibration .calibrating(nights: 7) et missingFactors [.hrv]
@Test func checkInRoundTrip() throws
```

Dans `PulseRecoveryEngineTests`, `CheckInScorerTests` compile avec `import PulseDomain` ajouté.

- [ ] **Step 2 : Lancer pour vérifier l'échec**

Run : `swift test --package-path Packages/PulseDomain`
Expected : erreur de compilation.

- [ ] **Step 3 : Écrire les fichiers, déplacer `CheckInAnswers`**

- [ ] **Step 4 : Lancer les tests des deux packages**

Run : `swift test --package-path Packages/PulseDomain && swift test --package-path Packages/PulseRecoveryEngine`
Expected : verts (le moteur retrouve `CheckInAnswers` via `import PulseDomain`).

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulseDomain Packages/PulseRecoveryEngine
git commit -m "feat(domain): add workout session, set, scheduled day, daily recovery and check-in"
```

---

### Task 5 : Compléments, mesures, records, cache local, protocoles de dépôt, document d'export

**Files:**
- Create: `Packages/PulseDomain/Sources/PulseDomain/Supplements/Supplement.swift`, `Supplements/SupplementIntake.swift`, `Body/BodyMeasurement.swift`, `Records/PersonalRecord.swift`, `Local/CachedHealthSample.swift`, `Local/ActiveSessionSnapshot.swift`, `Repositories/ProfileRepository.swift`, `Repositories/ProgramRepository.swift`, `Repositories/UserExerciseRepository.swift`, `Repositories/WorkoutRepository.swift`, `Repositories/ScheduledDayRepository.swift`, `Repositories/RecoveryRepository.swift`, `Repositories/SupplementRepository.swift`, `Repositories/BodyMeasurementRepository.swift`, `Repositories/PersonalRecordRepository.swift`, `Repositories/HealthSampleCache.swift`, `Repositories/ActiveSessionStore.swift`, `Repositories/DataExporter.swift`, `Repositories/DataEraser.swift`, `Repositories/StoreInspector.swift`, `Repositories/StoreTable.swift`, `Repositories/HealthErasing.swift`, `Export/ExportDocument.swift`
- Test: `Packages/PulseDomain/Tests/PulseDomainTests/SupplementAndRecordTypesTests.swift`, `ExportDocumentTests.swift`

**Interfaces:**
- Produces :
  - `enum SupplementForm: String { powder, capsule, tablet, liquid }`, `enum DoseUnit: String { g, mg, iu, ml, serving }`, `enum SupplementTiming: String { fixedTime, beforeWorkout, afterWorkout, bedtime }`, `enum SupplementDays: String { everyDay, trainingDays, custom }`, `struct Supplement: Identifiable { id; name; form; dose: Double; unit; timing; timeOfDayMinutes: Int?; days; customWeekdays: [Weekday]; stockDoses: Double?; lowStockThreshold: Double?; reminderEnabled: Bool; healthKitType: String?; isArchived: Bool; order: Int; createdAt; updatedAt }`, `struct SupplementIntake: Identifiable { id; supplementID: UUID; takenAt; dose: Double; writtenToHealthKit: Bool; healthKitUUID: String?; createdAt; updatedAt }`.
  - `enum MeasurementSource: String { manual, appleHealth }`, `struct BodyMeasurement: Identifiable { id; date; weightKg: Double?; bodyFatPercent: Double?; source; healthKitUUID: String?; createdAt; updatedAt }`.
  - `enum RecordKind: String { maxWeight, estimatedOneRepMax, repsAtWeight }`, `struct PersonalRecord: Identifiable { id; exercise: ExerciseReference; exerciseName; kind; value: Double; weightKg: Double?; date; sessionID: UUID?; setID: UUID?; createdAt; updatedAt }`.
  - `enum HealthSampleKind: String { sdnn, restingHeartRate, sleep, run, ride }`, `struct CachedHealthSample: Identifiable { id; kind; start; end; value: Double?; sleepStage: SleepStage?; distanceMeters: Double?; averageHeartRate: Double?; durationMinutes: Double?; healthKitUUID: String?; sourceBundleID: String?; fetchedAt }`, `struct ActiveSessionSnapshot: Identifiable { id; startedAt; updatedAt; payload: Data }`.
  - `enum StoreTable: String, CaseIterable { profile, programs, routineDays, routineExercises, userExercises, workoutSessions, workoutSets, scheduledDays, dailyRecoveries, checkIns, supplements, supplementIntakes, bodyMeasurements, personalRecords, cachedHealthSamples, healthQueryAnchors, activeSessionSnapshots }` + `var fileName: String` (snake_case : `routine_days`, …) + `static var exported: [StoreTable]` (les 14 premières, sans les trois locales).
  - Protocoles (tous `: Sendable`, méthodes `async throws`), signatures exactes de la spec M2 §5.5, avec ces précisions : `WorkoutRepository.lastSets(for: ExerciseReference) -> [WorkoutSet]` (séries de travail de la dernière séance **terminée** contenant l'exercice, triées par `order`) ; `ProgramRepository.save(_ program: Program)` ; `HealthSampleCache.replace(kind: HealthSampleKind, with: [CachedHealthSample])`, `insert(_:)`, `samples(kind:from:to:)`, `anchor(for: HealthSampleKind) -> Data?`, `saveAnchor(_ data: Data, for: HealthSampleKind)`, `clear()` ; `StoreInspector.counts() -> [StoreTable: Int]`, `cloudAccountStatus() -> CloudAccountStatus`.
  - `enum CloudAccountStatus: String { available, noAccount, restricted, unknown }`, `struct EraseOptions { includeAppleHealth: Bool }`, `protocol DataEraser: Sendable { func eraseEverything(options: EraseOptions) async throws }`, `protocol DataExporter: Sendable { func exportJSON() async throws -> URL; func exportCSVArchive() async throws -> URL }`.
  - `protocol HealthErasing: Sendable { func deleteAllSamplesWrittenByPulse() async throws }`, `final class StubHealthEraser: HealthErasing, @unchecked Sendable { init(error: (any Error)? = nil); private(set) var callCount: Int }` (verrou interne `NSLock`), `protocol NotificationCanceling: Sendable { func cancelAllScheduled() async }`.
  - `struct ExportUnits: Codable, Equatable { weight = "kg"; distance = "m"; duration = "minutes"; rest = "seconds" }`, `struct ExportDocument: Codable, Sendable, Equatable { format: String ("pulse-export"); formatVersion: Int (1); schemaVersion: Int; contentVersion: String; appVersion: String; exportedAt: Date; locale: String; units: ExportUnits; profile: UserProfile?; programs: [Program]; userExercises: [UserExercise]; workoutSessions: [WorkoutSession]; scheduledDays: [ScheduledDay]; dailyRecoveries: [DailyRecovery]; checkIns: [CheckIn]; supplements: [Supplement]; supplementIntakes: [SupplementIntake]; bodyMeasurements: [BodyMeasurement]; personalRecords: [PersonalRecord]; contentExercises: [String: String] }`.
  - `enum ExportCoding { static func encoder(timeZone: TimeZone = .current) -> JSONEncoder (sortedKeys + prettyPrinted, dates ISO 8601 `withInternetDateTime` dans `timeZone`) ; static func decoder() -> JSONDecoder (accepte toute date ISO 8601 avec décalage) }`.

- [ ] **Step 1 : Écrire les tests**

```swift
@Test func supplementTypesRoundTrip() throws        // Supplement custom + 1 intake + BodyMeasurement + PersonalRecord(repsAtWeight, weightKg 80)
@Test func cachedSampleRoundTrip() throws           // CachedHealthSample kind .sleep avec sleepStage .deep

@Test func storeTableFileNamesAreSnakeCase() {
    #expect(StoreTable.routineExercises.fileName == "routine_exercises")
    #expect(StoreTable.exported.count == 14)
    #expect(!StoreTable.exported.contains(.cachedHealthSamples))
}

@Test func exportDatesUseLocalOffset() throws {
    let paris = TimeZone(identifier: "Europe/Paris")!
    let date = Date(timeIntervalSince1970: 1_763_194_353)      // 2026-11-15T08:12:33+01:00
    let doc = ExportDocument.empty(exportedAt: date, appVersion: "1.0 (1)", schemaVersion: 1, contentVersion: "1.0.0", locale: "fr_FR")
    let text = try String(decoding: ExportCoding.encoder(timeZone: paris).encode(doc), as: UTF8.self)
    #expect(text.contains(#""exportedAt" : "2026-11-15T08:12:33+01:00""#))
    #expect(text.contains(#""format" : "pulse-export""#))
    let back = try ExportCoding.decoder().decode(ExportDocument.self, from: Data(text.utf8))
    #expect(back == doc)
}

@Test func stubHealthEraserCountsAndThrows() async throws
```

`ExportDocument.empty(exportedAt:appVersion:schemaVersion:contentVersion:locale:)` : tous les tableaux vides, `profile` nil.

- [ ] **Step 2 : Lancer pour vérifier l'échec**

Run : `swift test --package-path Packages/PulseDomain`
Expected : erreur de compilation.

- [ ] **Step 3 : Écrire les fichiers**

- [ ] **Step 4 : Lancer les tests**

Run : `swift test --package-path Packages/PulseDomain`
Expected : verts.

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulseDomain
git commit -m "feat(domain): add supplements, measurements, records, local cache, repository protocols and export document"
```

---

### Task 6 : `PulseContent` : chargement et validateur

**Files:**
- Create: `Packages/PulseContent/Sources/PulseContent/ContentLibrary.swift`, `ContentValidator.swift`, `ContentEnums+Localized.swift`
- Create: `Packages/PulseContent/Sources/PulseContent/Resources/exercises.json`, `Resources/programs.json` (vides pour l'instant : `{"schemaVersion":1,"contentVersion":"1.0.0","exercises":[]}` et `{"schemaVersion":1,"programs":[]}`)
- Delete: `Packages/PulseContent/Sources/PulseContent/PulseContent.swift`
- Test: `Packages/PulseContent/Tests/PulseContentTests/ContentLibraryTests.swift`, `ContentValidatorTests.swift`, `LocalizedNamesTests.swift`, `Support/Fixtures.swift`

**Interfaces:**
- Consumes : `Exercise`, `ExerciseCatalog`, `ProgramTemplate` (tâche 2).
- Produces :
  - `struct ContentLibrary: Sendable { let contentVersion: String; let exercises: [Exercise]; var activeExercises: [Exercise]; func exercise(id: String) -> Exercise?; let programTemplates: [ProgramTemplate]; func programTemplate(id: String) -> ProgramTemplate?; init(catalog: ExerciseCatalog, templates: [ProgramTemplate]); static func load(from bundle: Bundle) throws -> ContentLibrary; static let bundled: ContentLibrary }`. `load` lit `exercises.json`, `programs.json` (`{"schemaVersion":1,"programs":["ppl-3", …]}`) puis `Programs/<id>.json` pour chaque identifiant, dans l'ordre. Erreurs : `enum ContentError: Error, Equatable { case missingResource(String); case decoding(file: String, detail: String) }`. `bundled` : `try! load(from: .module)` remplacé par un `fatalError("Contenu Pulse invalide : \(error)")` dans un `do/catch` (pas de `!`).
  - `enum ContentRule: String, CaseIterable { exerciseCount, idFormat, duplicateID, nameMissing, primaryMuscles, secondaryMuscles, cues, mistakes, increment, rest, alternatives, patternPopulation, templateExercise, templateSets, templateReps, templateRPE, templateRest, superset, runTarget, suggestedWeek, sessionsPerWeek, dayID }`, `struct ContentIssue: Equatable, CustomStringConvertible { rule: ContentRule; subject: String; message: String }`, `enum ContentValidator { static func issues(in library: ContentLibrary) -> [ContentIssue]; static func issues(in library: ContentLibrary, ignoring: Set<ContentRule>) -> [ContentIssue] }`.
  - Règles, dans l'ordre de la spec M2 §4.1 et §4.3 : `exerciseCount` (exactement 80) ; `idFormat` ; `duplicateID` ; `nameMissing` (`fr` ou `en` vide) ; `primaryMuscles` (1 à 3, sans doublon) ; `secondaryMuscles` (0 à 4, disjoints des principaux) ; `cues` (exactement 3 en `fr`, ≤ 90 caractères) ; `mistakes` (2 ou 3, ≤ 90) ; `increment` (∈ {1.25, 2.5, 5}) ; `rest` (∈ {60, 90, 120, 180}) ; `alternatives` (exactement 3, existantes, ≠ id, distinctes, même `pattern`) ; `patternPopulation` (chaque `MovementPattern` a ≥ 4 exercices non retirés) ; `templateExercise` (existe et non retiré) ; `templateSets` (1…6) ; `templateReps` (1 ≤ min ≤ max ≤ 30) ; `templateRPE` (6…10, pas de 0,5) ; `templateRest` (∈ {60, 90, 120, 180}) ; `superset` (groupes de 2, consécutifs) ; `runTarget` (jour `run` : `run` présent, exactement un des deux objectifs ; jour `strength` : 1 à 10 exercices et `run` nil) ; `suggestedWeek` (7 entrées, identifiants existants, chaque jour présent au moins une fois) ; `sessionsPerWeek` (= nombre d'entrées non nulles) ; `dayID` (uniques dans le modèle).
  - `extension Muscle { var localizedName: String }`, idem `Equipment`, `MovementPattern`, `BodyRegion`, `LoadKind`, via `String(localized:bundle: .module)`, libellés français (par exemple `chest` → « Pectoraux », `horizontalPull` → « Tirage horizontal », `cable` → « Poulie »).

- [ ] **Step 1 : Écrire les fixtures de test**

`Support/Fixtures.swift` : `enum Fixtures { static func exercise(id: String, pattern: MovementPattern = .squat, alternatives: [String] = [], retired: Bool = false) -> Exercise` (valeurs valides par défaut : 3 consignes, 2 erreurs, incrément 2,5, repos 90) ; `static func library(exercises: [Exercise], templates: [ProgramTemplate] = []) -> ContentLibrary` ; `static func fourExercises(pattern:) -> [Exercise]` (4 exercices `p-1…p-4` qui se citent mutuellement en alternatives) ; `static func template(id: String, days: [TemplateDay], suggestedWeek: [String?], sessionsPerWeek: Int) -> ProgramTemplate`.

- [ ] **Step 2 : Écrire les tests du validateur**

```swift
@Test func validMinimalLibraryHasNoIssuesExceptCount() {
    let lib = Fixtures.library(exercises: Fixtures.fourExercises(pattern: .squat))
    let issues = ContentValidator.issues(in: lib, ignoring: [.exerciseCount, .patternPopulation])
    #expect(issues.isEmpty)
    #expect(ContentValidator.issues(in: lib).map(\.rule).contains(.exerciseCount))
}

@Test(arguments: ["Bench", "bench_press", "-bench", "bench-", "bench--press"])
func rejectsMalformedIDs(id: String)

@Test func rejectsDuplicateIDs()
@Test func rejectsAlternativesOfAnotherPatternOrSelfOrUnknown()   // 3 cas → 3 issues .alternatives
@Test func rejectsWrongCueOrMistakeCounts()
@Test func rejectsUnpopulatedPattern()      // 3 exercices pour un pattern → .patternPopulation
@Test func rejectsTemplateReferencingRetiredExercise()
@Test func rejectsSupersetOfThreeOrNonConsecutive()
@Test func rejectsRunDayWithBothTargets()
@Test func rejectsSuggestedWeekMismatch()   // 6 entrées ; identifiant inconnu ; sessionsPerWeek ≠ non nuls → 3 issues distinctes
```

- [ ] **Step 3 : Écrire les tests du chargement et des libellés**

```swift
@Test func loadFailsOnMissingResource() {
    #expect(throws: ContentError.missingResource("exercises.json")) { try ContentLibrary.load(from: Bundle(for: Marker.self)) }  // bundle de test sans ressources
}
@Test func bundledLibraryLoads() throws {
    let lib = try ContentLibrary.load(from: .module)
    #expect(lib.contentVersion == "1.0.0")
}
@Test func everyEnumHasALocalizedName() {
    for m in Muscle.allCases { #expect(!m.localizedName.isEmpty && m.localizedName != m.rawValue) }
    // idem Equipment, MovementPattern, BodyRegion, LoadKind
}
```

- [ ] **Step 4 : Lancer pour vérifier l'échec**

Run : `swift test --package-path Packages/PulseContent`
Expected : erreur de compilation.

- [ ] **Step 5 : Écrire `ContentLibrary`, `ContentValidator`, `ContentEnums+Localized`, les JSON vides**

Validateur : une fonction privée par règle, chacune renvoyant `[ContentIssue]`, assemblées dans `issues(in:ignoring:)` (respect des 50 lignes).

- [ ] **Step 6 : Lancer les tests**

Run : `swift test --package-path Packages/PulseContent`
Expected : verts.

- [ ] **Step 7 : Commit**

```bash
git add Packages/PulseContent
git commit -m "feat(content): add content library loader and validator"
```

---

### Task 7 : Exercices, première moitié du haut du corps (28)

**Files:**
- Modify: `Packages/PulseContent/Sources/PulseContent/Resources/exercises.json`
- Test: `Packages/PulseContent/Tests/PulseContentTests/BundledExercisesTests.swift`

**Interfaces:**
- Consumes : `ContentLibrary.bundled`, `ContentValidator`.
- Produces : 28 exercices des plans `horizontalPush` (6), `chestFly` (4), `verticalPush` (4), `shoulderIsolation` (5), `verticalPull` (4), `horizontalPull` (5), avec exactement les identifiants et noms FR de la spec M2 §4.2.

- [ ] **Step 1 : Écrire le test de la tranche**

```swift
@Test func upperBodyPushPullExercisesArePresentAndValid() throws {
    let lib = try ContentLibrary.load(from: .module)
    let expected: [MovementPattern: Int] = [.horizontalPush: 6, .chestFly: 4, .verticalPush: 4, .shoulderIsolation: 5, .verticalPull: 4, .horizontalPull: 5]
    for (pattern, count) in expected { #expect(lib.exercises.filter { $0.pattern == pattern }.count == count, "\(pattern)") }
    #expect(lib.exercise(id: "bench-press-barbell")?.name.fr == "Développé couché à la barre")
    #expect(lib.exercise(id: "chest-press-machine")?.equipment == .machine)
    #expect(lib.exercise(id: "lat-pulldown-machine")?.pattern == .verticalPull)
    let issues = ContentValidator.issues(in: lib, ignoring: [.exerciseCount, .patternPopulation])
    #expect(issues.isEmpty, "\(issues)")
}
```

- [ ] **Step 2 : Lancer pour vérifier l'échec**

Run : `swift test --package-path Packages/PulseContent --filter BundledExercisesTests`
Expected : échec sur les comptes (0 exercice).

- [ ] **Step 3 : Écrire les 28 exercices dans `exercises.json`**

Pour chaque identifiant du tableau §4.2 (six premiers plans) : nom `fr` exact du tableau, nom `en` usuel, muscles, matériel, `pattern`, `region: upper`, `isCompound` selon la règle §4.2, `isUnilateral` selon la règle, `loadKind` (`bodyweight` pour `push-up`, `pull-up`, `dips` ; `assisted` pour `assisted-pull-up-machine` ; `external` sinon), incrément 2,5 (1,25 pour `lateral-raise-dumbbell`, `lateral-raise-cable`, `face-pull-cable`, `reverse-pec-deck-machine`), repos 120 pour les développés barre et tractions, 90 pour les autres composés, 60 pour les isolations, 3 consignes et 2 ou 3 erreurs en français courant (≤ 90 caractères), 3 alternatives du même plan en privilégiant machine et poulie.

- [ ] **Step 4 : Lancer les tests**

Run : `swift test --package-path Packages/PulseContent`
Expected : verts (le validateur n'a rien à redire sur la tranche).

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulseContent
git commit -m "feat(content): add upper body push and pull exercises"
```

---

### Task 8 : Exercices, bras, avant-bras et bas du corps (28)

**Files:**
- Modify: `Packages/PulseContent/Sources/PulseContent/Resources/exercises.json`
- Test: `Packages/PulseContent/Tests/PulseContentTests/BundledExercisesTests.swift`

**Interfaces:**
- Produces : `elbowFlexion` (5), `elbowExtension` (5), `forearm` (4), `squat` (5), `lunge` (4), `hinge` (5), identifiants et noms de la spec M2 §4.2.

- [ ] **Step 1 : Ajouter le test de la tranche**

```swift
@Test func armsAndLowerBodyExercisesArePresentAndValid() throws {
    let lib = try ContentLibrary.load(from: .module)
    let expected: [MovementPattern: Int] = [.elbowFlexion: 5, .elbowExtension: 5, .forearm: 4, .squat: 5, .lunge: 4, .hinge: 5]
    for (pattern, count) in expected { #expect(lib.exercises.filter { $0.pattern == pattern }.count == count, "\(pattern)") }
    #expect(lib.exercise(id: "leg-press-machine")?.region == .lower)
    #expect(lib.exercise(id: "leg-press-machine")?.defaultIncrementKg == 5)
    #expect(lib.exercise(id: "hammer-curl-dumbbell")?.name.fr == "Curl marteau aux haltères")
    #expect(lib.exercise(id: "wrist-curl-cable")?.pattern == .forearm)
    #expect(ContentValidator.issues(in: lib, ignoring: [.exerciseCount, .patternPopulation]).isEmpty)
}
```

- [ ] **Step 2 : Lancer pour vérifier l'échec**

Run : `swift test --package-path Packages/PulseContent --filter BundledExercisesTests`
Expected : échec sur les comptes.

- [ ] **Step 3 : Écrire les 28 exercices**

Mêmes règles qu'en tâche 7. `region: upper` pour bras et avant-bras, `lower` pour squat, lunge, hinge. Incrément 5 pour squat, hinge, `leg-press-machine`, `hack-squat-machine` ; 2,5 pour lunge, bras ; 1,25 pour `forearm`. Repos 180 pour `deadlift-barbell` et `back-squat-barbell`, 120 pour les autres composés bas du corps, 60 pour les isolations. `loadKind: bodyweight` pour `dips` (déjà en tâche 7) ; ici tout est `external`.

- [ ] **Step 4 : Lancer les tests**

Run : `swift test --package-path Packages/PulseContent`
Expected : verts.

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulseContent
git commit -m "feat(content): add arm, forearm and lower body exercises"
```

---

### Task 9 : Exercices, isolations du bas et tronc (24), et validation complète des 80

**Files:**
- Modify: `Packages/PulseContent/Sources/PulseContent/Resources/exercises.json`
- Test: `Packages/PulseContent/Tests/PulseContentTests/BundledExercisesTests.swift`

**Interfaces:**
- Produces : `kneeFlexion` (4), `kneeExtension` (4), `hipAbduction` (4), `hipAdduction` (4), `calfRaise` (4), `coreFlexion` (4), `coreStability` (4) ; catalogue complet de 80.

- [ ] **Step 1 : Ajouter les tests finaux**

```swift
@Test func bundledCatalogIsCompleteAndValid() throws {
    let lib = try ContentLibrary.load(from: .module)
    let issues = ContentValidator.issues(in: lib, ignoring: Set(ContentRule.allCases.filter { $0.rawValue.hasPrefix("template") || [.superset, .runTarget, .suggestedWeek, .sessionsPerWeek, .dayID].contains($0) }))
    #expect(issues.isEmpty, "\(issues)")
    #expect(lib.exercises.count == 80)
    #expect(lib.activeExercises.count == 80)
    for pattern in MovementPattern.allCases { #expect(lib.exercises.filter { $0.pattern == pattern }.count >= 4, "\(pattern)") }
}

@Test func matheoPPLExercisesArePresent() throws {
    let ids = ["bench-press-barbell", "chest-press-machine", "pec-deck-machine", "triceps-pushdown-cable", "wrist-curl-cable", "crunch-machine",
               "lat-pulldown-machine", "seated-row-machine-iso-lateral", "lateral-raise-machine", "preacher-curl-machine", "hammer-curl-dumbbell",
               "leg-press-machine", "lying-leg-curl-machine", "hip-abduction-machine", "hip-adduction-machine", "seated-calf-raise-machine", "leg-extension-machine"]
    let lib = try ContentLibrary.load(from: .module)
    for id in ids { #expect(lib.exercise(id: id) != nil, id) }
}

@Test func unknownExerciseResolvesToNil() throws {
    #expect(try ContentLibrary.load(from: .module).exercise(id: "does-not-exist") == nil)
}
```

- [ ] **Step 2 : Lancer pour vérifier l'échec**

Run : `swift test --package-path Packages/PulseContent --filter BundledExercisesTests`
Expected : échec sur le compte 80.

- [ ] **Step 3 : Écrire les 24 exercices**

`region: lower` pour les cinq premiers plans, `core` pour `coreFlexion` et `coreStability`. `loadKind: bodyweight` pour `nordic-hamstring-curl`, `stability-ball-leg-curl`, `sissy-squat`, `spanish-squat-band`, `band-lateral-walk`, `side-lying-hip-abduction`, `copenhagen-plank`, `side-lying-hip-adduction`, `hanging-leg-raise`, `reverse-crunch`, `plank`, `side-plank`, `dead-bug`. Incrément 5 pour `leg-press-calf-raise`, 2,5 sinon ; `isUnilateral` pour les unijambistes, allongés, planche latérale, Copenhague. Repos 60 partout sauf `nordic-hamstring-curl` 90.

- [ ] **Step 4 : Lancer tous les tests du package et le lint**

Run : `swift test --package-path Packages/PulseContent && swiftlint lint --strict`
Expected : verts, lint à zéro.

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulseContent
git commit -m "feat(content): complete the 80-exercise library"
```

---

### Task 10 : Les cinq modèles de programme

**Files:**
- Create: `Packages/PulseContent/Sources/PulseContent/Resources/Programs/ppl-3.json`, `ppl-6.json`, `upper-lower.json`, `full-body.json`, `runner-strength.json`
- Modify: `Packages/PulseContent/Sources/PulseContent/Resources/programs.json`
- Test: `Packages/PulseContent/Tests/PulseContentTests/BundledProgramsTests.swift`

**Interfaces:**
- Produces : `ContentLibrary.bundled.programTemplates` = 5 modèles dans l'ordre `ppl-3`, `ppl-6`, `upper-lower`, `full-body`, `runner-strength`.

- [ ] **Step 1 : Écrire les tests**

```swift
@Test func fiveTemplatesInOrderAndValid() throws {
    let lib = try ContentLibrary.load(from: .module)
    #expect(lib.programTemplates.map(\.id) == ["ppl-3", "ppl-6", "upper-lower", "full-body", "runner-strength"])
    #expect(ContentValidator.issues(in: lib).isEmpty)
}

@Test func ppl3MatchesMatheoRoutineExactly() throws {
    let t = try #require(ContentLibrary.load(from: .module).programTemplate(id: "ppl-3"))
    #expect(t.recommendedFor == TemplateRecommendation(focus: .strength, daysPerWeek: [3]))
    #expect(t.sessionsPerWeek == 3)
    #expect(t.suggestedWeek == ["push", nil, "pull", nil, "legs", nil, nil])
    struct Row: Equatable { let day: String; let exercise: String; let sets: Int; let min: Int; let max: Int; let rpe: Double; let rest: Int; let superset: Int? }
    let rows: [Row] = [   // Row(day, exercise, sets, repsMin, repsMax, RPE, repos, super set) — écrire chaque ligne avec les étiquettes
        ("push", "bench-press-barbell", 4, 6, 10, 8, 120, nil), ("push", "chest-press-machine", 3, 8, 12, 8, 90, nil),
        ("push", "pec-deck-machine", 3, 10, 15, 8, 60, nil), ("push", "triceps-pushdown-cable", 3, 10, 15, 8, 60, 1),
        ("push", "wrist-curl-cable", 3, 12, 20, 8, 60, 1), ("push", "crunch-machine", 3, 12, 20, 8, 60, nil),
        ("pull", "lat-pulldown-machine", 4, 8, 12, 8, 90, nil), ("pull", "seated-row-machine-iso-lateral", 3, 8, 12, 8, 90, nil),
        ("pull", "lateral-raise-machine", 3, 12, 15, 8, 60, nil), ("pull", "preacher-curl-machine", 3, 10, 12, 8, 60, nil),
        ("pull", "hammer-curl-dumbbell", 3, 10, 12, 8, 60, nil),
        ("legs", "leg-press-machine", 4, 8, 12, 8, 120, nil), ("legs", "lying-leg-curl-machine", 3, 10, 12, 8, 90, nil),
        ("legs", "hip-abduction-machine", 3, 12, 15, 8, 60, nil), ("legs", "hip-adduction-machine", 3, 12, 15, 8, 60, nil),
        ("legs", "seated-calf-raise-machine", 4, 12, 15, 8, 60, nil), ("legs", "leg-extension-machine", 3, 12, 15, 8, 60, nil)
    ]
    let flat = t.days.flatMap { day in day.exercises.map { Row(day: day.id, exercise: $0.exercise, sets: $0.sets, min: $0.repsMin, max: $0.repsMax, rpe: $0.targetRPE, rest: $0.restSeconds, superset: $0.supersetGroup) } }
    #expect(flat == rows)
}

@Test func otherTemplatesFollowTheirFrames() throws {
    let lib = try ContentLibrary.load(from: .module)
    let ppl6 = try #require(lib.programTemplate(id: "ppl-6"))
    #expect(ppl6.days.count == 6 && ppl6.sessionsPerWeek == 6 && ppl6.suggestedWeek[6] == nil)
    let ul = try #require(lib.programTemplate(id: "upper-lower"))
    #expect(ul.days.count == 4 && ul.recommendedFor.focus == .balanced && ul.suggestedWeek == ["upper-a", "lower-a", nil, "upper-b", "lower-b", nil, nil])
    let fb = try #require(lib.programTemplate(id: "full-body"))
    #expect(fb.days.count == 3 && fb.days.allSatisfy { $0.exercises.count == 6 })
    let runner = try #require(lib.programTemplate(id: "runner-strength"))
    #expect(runner.recommendedFor.focus == .endurance && runner.sessionsPerWeek == 5)
    #expect(runner.days.filter { $0.kind == .run }.map { $0.run?.type } == [.easy, .intervals, .long])
    #expect(runner.suggestedWeek == ["easy-run", "strength-a", nil, "intervals", "strength-b", nil, "long-run"])
}
```

- [ ] **Step 2 : Lancer pour vérifier l'échec**

Run : `swift test --package-path Packages/PulseContent --filter BundledProgramsTests`
Expected : échec, aucun modèle.

- [ ] **Step 3 : Écrire les cinq JSON et `programs.json`**

`ppl-3` : exactement le tableau de la spec M2 §4.4 (jours `push`, `pull`, `legs`). `ppl-6` : jours `push`, `pull`, `legs`, `push-2`, `pull-2`, `legs-2`, lundi à samedi, 3 séries partout, variantes listées en §4.4. `upper-lower` : jours `upper-a`, `lower-a`, `upper-b`, `lower-b`. `full-body` : jours `full-a`, `full-b`, `full-c`, lundi / mercredi / vendredi. `runner-strength` : jours `easy-run` (40 min), `strength-a`, `intervals` (30 min), `strength-b`, `long-run` (60 min), exercices listés en §4.4. Résumés `fr` en une phrase.

- [ ] **Step 4 : Lancer les tests et le lint**

Run : `swift test --package-path Packages/PulseContent && swiftlint lint --strict`
Expected : verts.

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulseContent
git commit -m "feat(content): add the five program templates"
```

---

### Task 11 : `PulsePersistence` : schéma, conteneur, modèles d'entraînement

**Files:**
- Create: `Packages/PulsePersistence/Sources/PulsePersistence/Schema/PulseSchemaV1.swift`, `Schema/PulseMigrationPlan.swift`, `Schema/PersistenceStack.swift`, `Models/CodableColumn.swift`, `Models/StoredProfile.swift`, `Models/StoredProgram.swift`, `Models/StoredRoutineDay.swift`, `Models/StoredRoutineExercise.swift`, `Models/StoredUserExercise.swift`, `Models/StoredWorkoutSession.swift`, `Models/StoredWorkoutSet.swift`, `Models/StoredScheduledDay.swift`
- Delete: `Packages/PulsePersistence/Sources/PulsePersistence/PulsePersistence.swift`
- Test: `Packages/PulsePersistence/Tests/PulsePersistenceTests/Support/TestContainer.swift`, `PersistenceStackTests.swift`, `TrainingMappingTests.swift`

**Interfaces:**
- Consumes : entités du domaine (tâches 3 à 5).
- Produces :
  - `enum PulseSchemaV1: VersionedSchema { versionIdentifier = Schema.Version(1, 0, 0); models = PersistenceStack.syncedModels + PersistenceStack.localModels }` (les huit modèles de cette tâche ; la liste est complétée en tâche 12), `enum PulseMigrationPlan: SchemaMigrationPlan { schemas = [PulseSchemaV1.self]; stages = [] }`.
  - `enum StoreMode: Sendable, Equatable { case cloud, localOnly, inMemory }`, `enum PersistenceStack { static let cloudContainerIdentifier = "iCloud.fr.seonay.pulse"; static var syncedModels: [any PersistentModel.Type]; static var localModels: [any PersistentModel.Type]; static func makeContainer(mode: StoreMode) throws -> ModelContainer }`. Deux `ModelConfiguration` nommées `"synced"` et `"local"` : `cloud` → `cloudKitDatabase: .private(cloudContainerIdentifier)` pour `synced`, `.none` pour `local` ; `localOnly` → `.none` pour les deux ; `inMemory` → `isStoredInMemoryOnly: true` pour les deux. Fichiers : `URL.applicationSupportDirectory/Pulse/synced.store` et `local.store` (dossier créé si absent).
  - `enum CodableColumn { static func encode<T: Encodable>(_ value: T) -> Data?; static func decode<T: Decodable>(_ type: T.Type, from data: Data?, default: T) -> T }` (JSON).
  - Modèles (`@Model public final class`, attributs avec valeur par défaut ou optionnels ; énumérations en `String` ; tableaux en `Data?` via `CodableColumn` ; `createdAt`, `updatedAt`, `deletedAt: Date?` sur les synchronisés) :
    - `StoredProfile` : tous les champs de `UserProfile`.
    - `StoredProgram` (`days: [StoredRoutineDay]?` cascade, inverse `program`), `StoredRoutineDay` (`program: StoredProgram?`, `exercises: [StoredRoutineExercise]?` cascade, inverse `day`), `StoredRoutineExercise` (`day: StoredRoutineDay?`, `contentExerciseID: String?`, `userExerciseID: UUID?`).
    - `StoredUserExercise`.
    - `StoredWorkoutSession` (`sets: [StoredWorkoutSet]?` cascade, inverse `session`), `StoredWorkoutSet` (`session: StoredWorkoutSession?`, colonnes d'exercice et de remplacement aplaties).
    - `StoredScheduledDay`.
  - Mapping par modèle : `convenience init(_ domain: X)`, `func apply(_ domain: X)` (recopie tout sauf `createdAt`), `func toDomain() -> X` ; pour les parents, `apply` met à jour, crée et supprime logiquement les enfants par `id` (`deletedAt`), et `toDomain()` exclut les enfants supprimés et les trie par `order`.
  - Tests : `enum TestContainer { static func make() throws -> ModelContainer }` (= `PersistenceStack.makeContainer(mode: .inMemory)`).

- [ ] **Step 1 : Écrire les tests**

```swift
@Test func inMemoryContainerBuildsWithMigrationPlanAndBothConfigurations() throws {
    let container = try TestContainer.make()
    #expect(container.configurations.count == 2)
    let context = ModelContext(container)
    context.insert(StoredProfile(UserProfile()))
    try context.save()
    #expect(try context.fetchCount(FetchDescriptor<StoredProfile>()) == 1)
}

@Test func programRoundTripsThroughStoredModel() throws {
    let program = /* Program avec 2 jours, 3 exercices dont un user(id:) et un supersetGroup, weekLayout renseigné */
    let stored = StoredProgram(program)
    #expect(stored.toDomain() == program)
}

@Test func applyRemovesMissingDaysLogically() throws {
    // program avec jours A et B → stored ; apply(program sans B) ; toDomain().days == [A] ; le StoredRoutineDay B a deletedAt != nil
}

@Test func sessionRoundTripsWithSetsAndAdjustments() throws   // séance 9 séries, appliedAdjustments 2 éléments, set.replacedExercise .content
@Test func profileScheduledDayAndUserExerciseRoundTrip() throws   // tout renseigné, puis tout optionnel à nil
```

- [ ] **Step 2 : Lancer pour vérifier l'échec**

Run : `swift test --package-path Packages/PulsePersistence`
Expected : erreur de compilation.

- [ ] **Step 3 : Écrire le schéma, le conteneur, `CodableColumn`, les huit modèles avec leur mapping**

Si les deux configurations en mémoire refusent de cohabiter (erreur à la création du conteneur), donner à la configuration `local` du mode `.inMemory` une `url` de fichier temporaire unique plutôt que `isStoredInMemoryOnly`.

- [ ] **Step 4 : Lancer les tests**

Run : `swift test --package-path Packages/PulsePersistence`
Expected : verts.

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulsePersistence
git commit -m "feat(persistence): add versioned schema, container and training models"
```

---

### Task 12 : Modèles de récupération, compléments, corps, records et locaux

**Files:**
- Create: `Packages/PulsePersistence/Sources/PulsePersistence/Models/StoredDailyRecovery.swift`, `StoredCheckIn.swift`, `StoredSupplement.swift`, `StoredSupplementIntake.swift`, `StoredBodyMeasurement.swift`, `StoredPersonalRecord.swift`, `StoredCachedHealthSample.swift`, `StoredHealthQueryAnchor.swift`, `StoredActiveSessionSnapshot.swift`
- Modify: `Schema/PulseSchemaV1.swift`, `Schema/PersistenceStack.swift` (listes complètes)
- Test: `Packages/PulsePersistence/Tests/PulsePersistenceTests/OtherMappingTests.swift`, `PersistenceStackTests.swift`

**Interfaces:**
- Produces : les neuf modèles avec `init(_:)`, `apply(_:)`, `toDomain()` ; `StoredHealthQueryAnchor { kind: String; anchorData: Data?; updatedAt }` ; `PersistenceStack.localModels = [StoredCachedHealthSample, StoredHealthQueryAnchor, StoredActiveSessionSnapshot]`.

- [ ] **Step 1 : Écrire les tests**

```swift
@Test func localModelsLiveInTheLocalConfiguration() throws {
    let container = try TestContainer.make()
    let context = ModelContext(container)
    context.insert(StoredCachedHealthSample(sample))
    context.insert(StoredActiveSessionSnapshot(snapshot))
    try context.save()
    #expect(try context.fetchCount(FetchDescriptor<StoredCachedHealthSample>()) == 1)
    #expect(PersistenceStack.localModels.count == 3)
    #expect(PersistenceStack.syncedModels.count == 14)
}

@Test func recoveryCheckInSupplementRoundTrip() throws   // DailyRecovery (calibrating 7, missing [.hrv, .sleep], 1 adjustment) ; CheckIn ; Supplement custom + intake
@Test func bodyRecordCacheSnapshotRoundTrip() throws
```

- [ ] **Step 2 : Lancer pour vérifier l'échec**

Run : `swift test --package-path Packages/PulsePersistence`
Expected : erreur de compilation.

- [ ] **Step 3 : Écrire les modèles, compléter les listes**

- [ ] **Step 4 : Lancer les tests**

Run : `swift test --package-path Packages/PulsePersistence`
Expected : verts.

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulsePersistence
git commit -m "feat(persistence): add recovery, supplement, body, record and local models"
```

---

### Task 13 : Dépôts profil, programmes, exercices personnalisés

**Files:**
- Create: `Packages/PulsePersistence/Sources/PulsePersistence/Repositories/SwiftDataProfileRepository.swift`, `SwiftDataProgramRepository.swift`, `SwiftDataUserExerciseRepository.swift`, `Repositories/FetchHelpers.swift`
- Test: `Packages/PulsePersistence/Tests/PulsePersistenceTests/ProfileRepositoryTests.swift`, `ProgramRepositoryTests.swift`, `UserExerciseRepositoryTests.swift`

**Interfaces:**
- Consumes : protocoles de la tâche 5, modèles des tâches 11 et 12.
- Produces : `@ModelActor public actor SwiftDataProfileRepository: ProfileRepository`, `SwiftDataProgramRepository: ProgramRepository`, `SwiftDataUserExerciseRepository: UserExerciseRepository` (init généré `init(modelContainer:)`). Règles : `save` cherche par `id` non supprimé ; s'il existe, `apply` + `updatedAt = Date()` ; sinon insertion avec `updatedAt = Date()` et `createdAt` du domaine ; `delete(id:)` pose `deletedAt = Date()` ; les lectures excluent `deletedAt != nil` ; `ProfileRepository.load()` renvoie le profil non supprimé avec le plus petit `createdAt`. `FetchHelpers` : `extension ModelContext { func first<T: PersistentModel>(_ type: T.Type, where predicate: Predicate<T>) throws -> T? }`.

- [ ] **Step 1 : Écrire les tests**

```swift
@Test func profileSaveThenLoadAndUpdate() async throws {
    let repo = SwiftDataProfileRepository(modelContainer: try TestContainer.make())
    #expect(try await repo.load() == nil)
    var profile = UserProfile(); profile.heightCm = 180
    let before = Date()
    try await repo.save(profile)
    let loaded = try #require(try await repo.load())
    #expect(loaded.id == profile.id && loaded.heightCm == 180 && loaded.updatedAt >= before)
    profile.heightCm = 181
    try await repo.save(profile)
    #expect(try await repo.load()?.heightCm == 181)
}

@Test func loadPrefersOldestProfileWhenDuplicatesExist() async throws {   // Review Focus 1
    // insérer deux profils via save avec createdAt 2026-01-01 et 2026-02-01 → load().id == le premier
}

@Test func programSaveReadsBackSortedAndDeleteHides() async throws
@Test func programSaveRemovingADayDeletesItLogically() async throws   // programs() renvoie 1 jour ; fetch direct des StoredRoutineDay : 2 dont 1 deletedAt != nil
@Test func programsOrderedByCreatedAtThenName() async throws
@Test func userExerciseCRUDAndArchivedFilter() async throws   // all(includeArchived: false) exclut isArchived
```

- [ ] **Step 2 : Lancer pour vérifier l'échec**

Run : `swift test --package-path Packages/PulsePersistence`
Expected : erreur de compilation.

- [ ] **Step 3 : Écrire les trois dépôts et `FetchHelpers`**

- [ ] **Step 4 : Lancer les tests**

Run : `swift test --package-path Packages/PulsePersistence`
Expected : verts.

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulsePersistence
git commit -m "feat(persistence): add profile, program and user exercise repositories"
```

---

### Task 14 : Dépôts séances, semaine datée, récupération

**Files:**
- Create: `Packages/PulsePersistence/Sources/PulsePersistence/Repositories/SwiftDataWorkoutRepository.swift`, `SwiftDataScheduledDayRepository.swift`, `SwiftDataRecoveryRepository.swift`
- Test: `Packages/PulsePersistence/Tests/PulsePersistenceTests/WorkoutRepositoryTests.swift`, `ScheduledDayRepositoryTests.swift`, `RecoveryRepositoryTests.swift`

**Interfaces:**
- Produces : `SwiftDataWorkoutRepository: WorkoutRepository` (`sessions(from:to:)` : `startedAt` dans `[from, to)`, triées par `startedAt` croissant ; `lastSets(for:)` : parmi les séances `completed` non supprimées, la plus récente par `startedAt` contenant une série de cet exercice, puis ses séries `working` de cet exercice triées par `order`), `SwiftDataScheduledDayRepository: ScheduledDayRepository` (`days(from:to:)` par `date`), `SwiftDataRecoveryRepository: RecoveryRepository` (`init(modelContainer:)` ; `save(DailyRecovery)` normalise `day` avec `Calendar.current.startOfDay` et remplace l'enregistrement non supprimé du même jour en gardant son `id` et son `createdAt` ; `save(CheckIn)` idem).

- [ ] **Step 1 : Écrire les tests**

```swift
@Test func sessionsFilterByRangeAndSortAscending() async throws
@Test func saveSessionUpdatesSetsInPlace() async throws   // 3 séries → modifier actualReps d'une, retirer une : session(id:) a 2 séries, 1 StoredWorkoutSet deletedAt
@Test func lastSetsReturnsWorkingSetsOfLatestCompletedSession() async throws {
    // séance A (completed, J-3) : squat 2 working + 1 warmup ; séance B (completed, J-1) : squat 3 working ; séance C (inProgress, J0) : squat 1 working
    let sets = try await repo.lastSets(for: .content(id: "back-squat-barbell"))
    #expect(sets.count == 3 && sets.allSatisfy { $0.setType == .working } && sets.map(\.order) == [1, 2, 3])
}
@Test func lastSetsIsEmptyForUnknownExercise() async throws
@Test func scheduledDaysRangeAndDelete() async throws
@Test func recoverySaveReplacesSameLocalDay() async throws {   // Review Focus 5
    let cal = Calendar.current
    let late = cal.date(bySettingHour: 23, minute: 59, second: 0, of: Date())!
    let early = cal.date(bySettingHour: 0, minute: 1, second: 0, of: Date())!
    try await repo.save(DailyRecovery(id: UUID(), day: late, score: 50, ...))
    try await repo.save(DailyRecovery(id: UUID(), day: early, score: 70, ...))
    let all = try await repo.dailyRecoveries(from: cal.startOfDay(for: Date()), to: cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date()))!)
    #expect(all.count == 1 && all[0].score == 70 && all[0].day == cal.startOfDay(for: Date()))
}
@Test func checkInSaveReplacesSameDay() async throws
```

- [ ] **Step 2 : Lancer pour vérifier l'échec**

Run : `swift test --package-path Packages/PulsePersistence`
Expected : erreur de compilation.

- [ ] **Step 3 : Écrire les trois dépôts**

- [ ] **Step 4 : Lancer les tests**

Run : `swift test --package-path Packages/PulsePersistence`
Expected : verts.

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulsePersistence
git commit -m "feat(persistence): add workout, scheduled day and recovery repositories"
```

---

### Task 15 : Dépôts compléments, corps, records, cache Apple Santé, séance en cours, inspecteur

**Files:**
- Create: `Packages/PulsePersistence/Sources/PulsePersistence/Repositories/SwiftDataSupplementRepository.swift`, `SwiftDataBodyMeasurementRepository.swift`, `SwiftDataPersonalRecordRepository.swift`, `SwiftDataHealthSampleCache.swift`, `SwiftDataActiveSessionStore.swift`, `SwiftDataStoreInspector.swift`
- Test: un fichier de test par dépôt.

**Interfaces:**
- Produces : cinq acteurs `@ModelActor` et `public struct SwiftDataStoreInspector: StoreInspector { init(container: ModelContainer, cloudEnabled: Bool) }` (qui délègue les comptes à un acteur interne `@ModelActor StoreCounter`). `counts()` compte les enregistrements **non supprimés** par `StoreTable` (toutes les 17 tables) ; `cloudAccountStatus()` renvoie `.unknown` sans rien appeler si `cloudEnabled` est faux (un `CKContainer` sans entitlement iCloud fait planter le processus, donc jamais dans les tests ni sur simulateur en mode local) ; sinon il appelle `CKContainer(identifier: PersistenceStack.cloudContainerIdentifier).accountStatus()` et mappe `.available` → `.available`, `.noAccount` → `.noAccount`, `.restricted` → `.restricted`, sinon `.unknown` ; toute erreur → `.unknown`. `SwiftDataHealthSampleCache.replace(kind:with:)` supprime physiquement les échantillons du `kind` puis insère ; `clear()` vide les trois tables locales.

- [ ] **Step 1 : Écrire les tests**

```swift
@Test func supplementsAndIntakes() async throws        // ordre par `order`, archivés exclus, intakes(from:to:) par takenAt, delete(intakeID:)
@Test func bodyMeasurementsByDate() async throws
@Test func recordsFilterByExercise() async throws       // records(for: nil) → tous ; records(for: .content("x")) → les siens, triés par date décroissante
@Test func cacheReplaceInsertQueryClear() async throws {
    try await cache.replace(kind: .sdnn, with: [s1, s2])
    try await cache.replace(kind: .sdnn, with: [s3])
    #expect(try await cache.samples(kind: .sdnn, from: .distantPast, to: .distantFuture).map(\.id) == [s3.id])
    try await cache.saveAnchor(Data([1, 2]), for: .sleep)
    #expect(try await cache.anchor(for: .sleep) == Data([1, 2]))
    try await cache.clear()
    #expect(try await cache.anchor(for: .sleep) == nil)
}
@Test func activeSessionStoreSingleSlot() async throws  // save deux fois → load() renvoie le dernier, un seul enregistrement ; clear() → nil
@Test func inspectorCountsEveryTable() async throws {
    // inspector = SwiftDataStoreInspector(container: container, cloudEnabled: false) ; #expect(await inspector.cloudAccountStatus() == .unknown)
    let counts = try await inspector.counts()
    #expect(counts.count == StoreTable.allCases.count)
    #expect(counts[.profile] == 1 && counts[.workoutSets] == 3)
}
```

- [ ] **Step 2 : Lancer pour vérifier l'échec**

Run : `swift test --package-path Packages/PulsePersistence`
Expected : erreur de compilation.

- [ ] **Step 3 : Écrire les cinq acteurs et l'inspecteur**

- [ ] **Step 4 : Lancer les tests et le lint**

Run : `swift test --package-path Packages/PulsePersistence && swiftlint lint --strict`
Expected : verts.

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulsePersistence
git commit -m "feat(persistence): add supplement, body, record, health cache, active session and inspector"
```

---

### Task 16 : Données d'exemple et export JSON

**Files:**
- Create: `Packages/PulsePersistence/Sources/PulsePersistence/Sample/SampleDataSeeder.swift`, `Export/ExportSnapshotLoader.swift`, `Export/JSONExportWriter.swift`, `Export/SwiftDataExporter.swift`
- Test: `Packages/PulsePersistence/Tests/PulsePersistenceTests/SampleDataSeederTests.swift`, `JSONExportTests.swift`

**Interfaces:**
- Consumes : dépôts (13 à 15), `ExportDocument`, `ExportCoding`.
- Produces :
  - `public struct SampleDataSeeder: Sendable { init(container: ModelContainer); func seed(now: Date) async throws }` : via les dépôts, insère le jeu de la spec M2 §6.3 : 1 profil (`heightCm 180`, `weightKg 78`), 1 programme = `Program(template:)` d'un modèle minimal à 3 jours (push / pull / legs, 2 exercices de contenu chacun ; le seeder ne dépend pas de `PulseContent`, il construit le `ProgramTemplate` en dur avec des identifiants réels : `bench-press-barbell`, `chest-press-machine`, `lat-pulldown-machine`, `seated-row-machine-iso-lateral`, `leg-press-machine`, `leg-extension-machine`), 1 exercice perso (« Rowing machine du coin »), 1 séance `completed` (J-1, `title "Push"`, 3 exercices, 9 séries : 1 `warmup` + 8 `working`, dont 2 séries `supersetGroup 1`, une série ratée 8 → 3, note `Dos ok, "lourd" aujourd'hui`), 1 jour planifié (`completed`, `sessionID` de la séance), 2 scores (J-1 mesuré 72 ; J0 estimé 55 avec `missingFactors [.hrv, .restingHeartRate]`), 1 check-in (J0), 1 complément (créatine, `powder`, 5 g, `afterWorkout`, `everyDay`) + 2 prises, 1 mesure (78 kg, `manual`), 1 record (`estimatedOneRepMax` 100 kg sur `bench-press-barbell`), et 3 échantillons de cache (`sdnn`, `restingHeartRate`, `sleep`).
  - `@ModelActor actor ExportSnapshotLoader { func snapshot() throws -> ExportSnapshot }` avec `struct ExportSnapshot: Sendable { profile; programs; userExercises; workoutSessions; scheduledDays; dailyRecoveries; checkIns; supplements; supplementIntakes; bodyMeasurements; personalRecords }` (non supprimés, triés comme les dépôts).
  - `enum JSONExportWriter { static func document(from snapshot: ExportSnapshot, exportedAt: Date, appVersion: String, contentVersion: String, locale: String, exerciseNames: (String) -> String?) -> ExportDocument; static func write(_ document: ExportDocument, to directory: URL, date: Date, timeZone: TimeZone) throws -> URL }` : fichier `Pulse-AAAA-MM-JJ.json` ; `contentExercises` = pour chaque `.content(id:)` rencontré dans séries, routines et records, `exerciseNames(id)` si non nil.
  - `public struct SwiftDataExporter: DataExporter { init(container: ModelContainer, appVersion: String, contentVersion: String, exerciseNames: @Sendable @escaping (String) -> String?, directory: URL = exportsDirectory) ; static var exportsDirectory: URL (= temporaryDirectory/PulseExports) }` ; `exportJSON()` vide le dossier puis écrit ; `exportCSVArchive()` arrive en tâche 17 (ici `throw ExportError.notImplemented`).

- [ ] **Step 1 : Écrire les tests**

```swift
@Test func seederFillsEveryExportedTable() async throws {
    let container = try TestContainer.make()
    try await SampleDataSeeder(container: container).seed(now: fixedNow)
    let counts = try await SwiftDataStoreInspector(container: container, cloudEnabled: false).counts()
    for table in StoreTable.allCases where table != .healthQueryAnchors && table != .activeSessionSnapshots { #expect((counts[table] ?? 0) > 0, "\(table)") }
    #expect(counts[.workoutSets] == 9 && counts[.dailyRecoveries] == 2 && counts[.supplementIntakes] == 2)
}

@Test func jsonExportDecodesBackToSameData() async throws {
    // seed → exportJSON() → ExportCoding.decoder().decode(ExportDocument.self) ; comparer avec ExportSnapshotLoader.snapshot()
    // exporteur construit avec exerciseNames: { ["bench-press-barbell": "Développé couché à la barre"][$0] }
    #expect(doc.format == "pulse-export" && doc.formatVersion == 1 && doc.schemaVersion == 1)
    #expect(doc.workoutSessions[0].sets.count == 9)
    #expect(doc.workoutSessions == snapshot.workoutSessions && doc.programs == snapshot.programs && doc.profile == snapshot.profile)
    #expect(doc.contentExercises["bench-press-barbell"] == "Développé couché à la barre")
    #expect(url.lastPathComponent == "Pulse-2026-11-15.json")
}

@Test func jsonExportOfEmptyStoreIsValid() async throws   // tableaux vides, profile nil, décodage ok
@Test func jsonExportKeepsNameOfUnknownContentExercise() async throws {   // Review Focus 3
    // séance avec une série .content(id: "ghost") exerciseName "Fantôme" ; exerciseNames renvoie nil pour "ghost"
    #expect(doc.workoutSessions[0].sets[0].exerciseName == "Fantôme")
    #expect(doc.contentExercises["ghost"] == nil)
}
@Test func jsonExportExcludesLogicallyDeleted() async throws
```

- [ ] **Step 2 : Lancer pour vérifier l'échec**

Run : `swift test --package-path Packages/PulsePersistence`
Expected : erreur de compilation.

- [ ] **Step 3 : Écrire le seeder, le chargeur, le writer, l'exporteur**

Le seeder se découpe en une fonction privée par entité (limite de 50 lignes).

- [ ] **Step 4 : Lancer les tests**

Run : `swift test --package-path Packages/PulsePersistence`
Expected : verts.

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulsePersistence
git commit -m "feat(persistence): add sample data seeder and JSON export"
```

---

### Task 17 : Export CSV et archive zip

**Files:**
- Create: `Packages/PulsePersistence/Sources/PulsePersistence/Export/CSVWriter.swift`, `Export/CSVTables.swift`, `Export/ZipArchiver.swift`
- Modify: `Export/SwiftDataExporter.swift` (`exportCSVArchive()`)
- Test: `Packages/PulsePersistence/Tests/PulsePersistenceTests/CSVWriterTests.swift`, `CSVExportTests.swift`

**Interfaces:**
- Produces :
  - `enum CSVWriter { static func line(_ fields: [String?]) -> String` (RFC 4180 : vide pour nil ; guillemets doublés et champ entouré si virgule, guillemet, `\n` ou `\r`) ; `static func file(header: [String], rows: [[String?]]) -> String` (lignes terminées par `\n`) }`.
  - `struct CSVTable: Equatable { header: [String]; rows: [[String?]] }`, `enum CSVTables { static func tables(from document: ExportDocument, timeZone: TimeZone) -> [StoreTable: CSVTable]` pour les 14 tables de `StoreTable.exported` ; `static func readme(for document: ExportDocument) -> String` }`. Colonnes : noms de champs du domaine en snake_case dans l'ordre de déclaration, `id` en premier, clé étrangère en second (`program_id`, `routine_day_id`, `session_id`, `supplement_id`) ; `ExerciseReference` → `content_exercise_id`, `user_exercise_id` ; tableaux d'énumérations joints par `|` ; `[SessionAdjustment]` et `weekLayout` en JSON compact dans la cellule ; `CheckInAnswers` → `sleep_answer`, `pain_answer`, `motivation_answer` ; `CalibrationState` → `calibration` (`ready` ou `calibrating:N`) ; dates ISO 8601 (`ExportCoding`), nombres avec point, booléens `true` / `false`.
  - En-tête exact de `workout_sets.csv` : `id,session_id,order,content_exercise_id,user_exercise_id,exercise_name,set_type,superset_group,planned_weight_kg,planned_reps,actual_weight_kg,actual_reps,rpe,rest_seconds,completed_at,is_personal_record,replaced_content_exercise_id,replaced_user_exercise_id,replacement_reason`.
  - `enum ZipArchiver { static func zip(directory: URL, to destination: URL) throws }` via `NSFileCoordinator().coordinate(readingItemAt:options: [.forUploading])` et copie du résultat vers `destination`.
  - `SwiftDataExporter.exportCSVArchive()` : dossier `Pulse-AAAA-MM-JJ-csv/` avec les 14 CSV et `README.txt`, zippé en `Pulse-AAAA-MM-JJ-csv.zip`.

- [ ] **Step 1 : Écrire les tests**

```swift
@Test func csvLineQuotesOnlyWhenNeeded() {
    #expect(CSVWriter.line(["a", nil, "1.5"]) == "a,,1.5")
x    #expect(CSVWriter.line(["Dos ok, \"lourd\"", "x\ny"]) == "\"Dos ok, \"\"lourd\"\"\",\"x\ny\"")""","x"# + "\n" + #"y""#)
}

@Test func workoutSetsHeaderIsExact()   // CSVTables.tables(from: sample).[.workoutSets]!.header == liste ci-dessus

@Test func csvArchiveContainsEveryTableAndRoundTripsQuotedNote() async throws {   // Review Focus 2
    // seed → exportCSVArchive() ; dézipper avec `Process("/usr/bin/unzip")` dans les tests Mac (ou lire le dossier non zippé exposé par l'exporteur : `lastCSVDirectory`)
    #expect(fichiers == Set(StoreTable.exported.map { $0.fileName + ".csv" }) ∪ ["README.txt"])
    #expect(lignes(workout_sets.csv) == 10)       // en-tête + 9
    #expect(lignes(workout_sessions.csv)[1] contient #""Dos ok, ""lourd"" aujourd'hui""#)
}

@Test func csvExportOfEmptyStoreHasHeadersOnly() async throws
```

Pour éviter de dépendre d'`unzip`, `SwiftDataExporter` expose `public private(set) var lastCSVDirectory: URL?` après `exportCSVArchive()` ; le test lit le dossier et vérifie seulement que le zip existe et pèse plus de 100 octets.

- [ ] **Step 2 : Lancer pour vérifier l'échec**

Run : `swift test --package-path Packages/PulsePersistence`
Expected : erreur de compilation.

- [ ] **Step 3 : Écrire `CSVWriter`, `CSVTables` (une fonction par table), `ZipArchiver`, compléter l'exporteur**

- [ ] **Step 4 : Lancer les tests et le lint**

Run : `swift test --package-path Packages/PulsePersistence && swiftlint lint --strict`
Expected : verts.

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulsePersistence
git commit -m "feat(persistence): add CSV export archive"
```

---

### Task 18 : Suppression totale

**Files:**
- Create: `Packages/PulsePersistence/Sources/PulsePersistence/Erase/StoreWiper.swift`, `Erase/SwiftDataEraser.swift`
- Test: `Packages/PulsePersistence/Tests/PulsePersistenceTests/EraserTests.swift`

**Interfaces:**
- Produces :
  - `@ModelActor actor StoreWiper { func wipeAll() throws }` : `modelContext.delete(model:)` pour chaque type de `PersistenceStack.syncedModels` puis `localModels`, puis `save()`.
  - `public struct SwiftDataEraser: DataEraser { init(container: ModelContainer, defaults: UserDefaults, defaultsDomain: String, healthEraser: any HealthErasing, notifications: (any NotificationCanceling)?, exportsDirectory: URL) }`. `eraseEverything(options:)` dans l'ordre de la spec M2 §7.2 : wipe, `defaults.removePersistentDomain(forName: defaultsDomain)`, suppression du dossier d'exports s'il existe, `healthEraser` si `options.includeAppleHealth`, `notifications?.cancelAllScheduled()`. Une erreur de l'effacement Apple Santé est relancée **après** que tout le reste a été fait.

- [ ] **Step 1 : Écrire les tests**

```swift
@Test func eraseEmptiesEveryTableDefaultsAndExports() async throws {
    let container = try TestContainer.make()
    try await SampleDataSeeder(container: container).seed(now: Date())
    let suite = "pulse.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.set(true, forKey: "onboardingCompleted")
    let exports = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: exports, withIntermediateDirectories: true)
    let health = StubHealthEraser()
    let eraser = SwiftDataEraser(container: container, defaults: defaults, defaultsDomain: suite, healthEraser: health, notifications: nil, exportsDirectory: exports)
    try await eraser.eraseEverything(options: EraseOptions(includeAppleHealth: false))
    let counts = try await SwiftDataStoreInspector(container: container, cloudEnabled: false).counts()
    #expect(counts.values.allSatisfy { $0 == 0 })
    #expect(defaults.object(forKey: "onboardingCompleted") == nil)
    #expect(!FileManager.default.fileExists(atPath: exports.path))
    #expect(health.callCount == 0)
}

@Test func eraseCallsHealthEraserOnlyWhenRequested() async throws   // includeAppleHealth: true → callCount == 1

@Test func healthEraseFailureStillWipesLocalStore() async throws {   // Review Focus 4
    struct Boom: Error {}
    let health = StubHealthEraser(error: Boom())
    await #expect(throws: Boom.self) { try await eraser.eraseEverything(options: EraseOptions(includeAppleHealth: true)) }
    #expect(try await inspector.counts().values.allSatisfy { $0 == 0 })
}
```

- [ ] **Step 2 : Lancer pour vérifier l'échec**

Run : `swift test --package-path Packages/PulsePersistence`
Expected : erreur de compilation.

- [ ] **Step 3 : Écrire `StoreWiper` et `SwiftDataEraser`**

- [ ] **Step 4 : Lancer tous les tests des packages et le lint**

Run : `make test-packages && make lint`
Expected : verts.

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulsePersistence
git commit -m "feat(persistence): add total data eraser"
```

---

### Task 19 : Assemblage dans l'app et écran de debug « Données »

**Files:**
- Modify: `Pulse/AppDependencies.swift`, `Pulse/PulseApp.swift`
- Create: `Pulse/RootTabView.swift`, `Pulse/Debug/DataDebugModel.swift`, `Pulse/Debug/DataDebugView.swift`, `Pulse/Debug/ContentExercisesView.swift`, `Pulse/Debug/ContentTemplatesView.swift`, `Pulse/Debug/EraseConfirmationView.swift`, `Pulse/Localizable.xcstrings`
- Test: `PulseTests/DataDebugModelTests.swift`

**Interfaces:**
- Consumes : `ContentLibrary`, `PersistenceStack`, dépôts, `SwiftDataExporter`, `SwiftDataEraser`, `SampleDataSeeder`, `SwiftDataStoreInspector`, `StubHealthEraser`.
- Produces :
  - `AppDependencies` gagne : `let content: ContentLibrary`, `let container: ModelContainer`, `let storeMode: StoreMode`, `let storeError: String?`, `let inspector: any StoreInspector`, `let exporter: any DataExporter`, `let eraser: any DataEraser`, `let seeder: SampleDataSeeder`, et les dix dépôts (`profiles`, `programs`, `userExercises`, `workouts`, `scheduledDays`, `recovery`, `supplements`, `bodyMeasurements`, `personalRecords`, `healthCache`, `activeSession`). `live()` : `StoreMode` = `.localOnly` sous `#if targetEnvironment(simulator)`, `.cloud` sinon ; si `makeContainer` lance, repli sur `.inMemory` avec `storeError` renseigné (texte français). `healthEraser` = `StubHealthEraser()` en M2 ; `exerciseNames` = `{ content.exercise(id: $0)?.name.fr }` ; `appVersion` lu dans `Bundle.main` (`CFBundleShortVersionString (CFBundleVersion)`). `preview()` et `testing()` : `.inMemory`, `StubHealthReader`.
  - `@MainActor @Observable final class DataDebugModel { init(dependencies: AppDependencies); let contentVersion: String; let exerciseCount: Int; let templateCount: Int; var exercisesByPattern: [(pattern: MovementPattern, exercises: [Exercise])]; let templates: [ProgramTemplate]; let storeModeText: String; private(set) var cloudStatus: CloudAccountStatus?; private(set) var counts: [StoreTable: Int]; private(set) var lastError: String?; private(set) var isBusy: Bool; private(set) var shareURL: URL?; private(set) var didErase: Bool; func refresh() async; func seedSampleData() async; func exportJSON() async; func exportCSV() async; func erase(includeAppleHealth: Bool) async; func exerciseName(for id: String) -> String? }`. Toute erreur → `lastError` en français, jamais de crash.
  - `RootTabView` : `TabView` avec « Santé » (`HealthDiagnosticsView`) et « Données » (`DataDebugView`). `PulseApp` crée `AppDependencies.live()` une fois et le passe aux deux modèles.
  - `DataDebugView` : sections « Contenu » (version, comptes, `NavigationLink` vers `ContentExercisesView` et `ContentTemplatesView`), « Stockage » (mode, compte iCloud en français, une ligne par `StoreTable` avec son compte, `lastError`), « Actions » (« Insérer des données d'exemple », « Exporter en JSON », « Exporter en CSV » qui affichent une `ShareLink(item: shareURL)` une fois l'URL prête, « Tout supprimer » en rouge qui présente `EraseConfirmationView` en feuille). `ContentTemplatesView` : chaque modèle, ses jours, chaque exercice résolu « nom FR · séries × repsMin à repsMax » ; un identifiant non résolu s'affiche en rouge avec l'identifiant brut. `EraseConfirmationView` : texte d'explication de la spec M2 §7.1, `Toggle` « Supprimer aussi ce que Pulse a écrit dans Apple Santé » avec note « disponible quand Pulse écrit dans Apple Santé », `TextField` et bouton rouge « Supprimer définitivement » actif seulement si le texte == `SUPPRIMER` ; pendant `isBusy` : `ProgressView` et « Suppression en cours… » ; après : message « Toutes les données ont été supprimées ».

- [ ] **Step 1 : Écrire les tests (`PulseTests`, simulateur)**

```swift
@MainActor
@Suite struct DataDebugModelTests {
    @Test func contentSummaryComesFromBundledLibrary() {
        let model = DataDebugModel(dependencies: .testing())
        #expect(model.exerciseCount == 80 && model.templateCount == 5)
        #expect(model.exercisesByPattern.map(\.pattern) == MovementPattern.allCases)
        #expect(model.exerciseName(for: "leg-press-machine") == "Presse à cuisses")
    }

    @Test func seedThenExportThenEraseUpdatesCounts() async {
        let model = DataDebugModel(dependencies: .testing())
        await model.refresh()
        #expect(model.counts[.workoutSets] == 0)
        await model.seedSampleData()
        #expect(model.counts[.workoutSets] == 9 && model.lastError == nil)
        await model.exportJSON()
        #expect(model.shareURL?.pathExtension == "json")
        await model.exportCSV()
        #expect(model.shareURL?.pathExtension == "zip")
        await model.erase(includeAppleHealth: false)
        #expect(model.didErase && model.counts.values.allSatisfy { $0 == 0 })
    }

    @Test func liveDependenciesBuildAContainerOnSimulator() {
        let deps = AppDependencies.live()
        #expect(deps.storeMode == .localOnly || deps.storeMode == .inMemory)
    }
}
```

- [ ] **Step 2 : Lancer pour vérifier l'échec**

Run (hors bac à sable) : `xcodebuild build-for-testing -scheme Pulse -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected : erreur de compilation sur `DataDebugModel`.

- [ ] **Step 3 : Écrire les vues, le modèle, `RootTabView`, étendre `AppDependencies`, créer `Pulse/Localizable.xcstrings` minimal**

Chaque vue dans son fichier, chaque section de `DataDebugView` en propriété calculée privée (limite de 50 lignes par corps).

- [ ] **Step 4 : Construire et tester l'app**

Run (hors bac à sable) : `make test-app`
Expected : code de sortie 0 ; `PulseTests` compte les tests M1 plus les trois nouveaux.

- [ ] **Step 5 : Vérifier à l'œil sur le simulateur**

Run : `xcrun simctl launch booted fr.seonay.pulse` après `xcodebuild build -scheme Pulse -destination 'platform=iOS Simulator,name=iPhone 17'` et installation (`xcrun simctl install booted <chemin de Pulse.app dans DerivedData>`), puis `xcrun simctl io booted screenshot /tmp/pulse-m2-donnees.png`.
Expected : l'onglet « Données » affiche « 80 exercices », « 5 modèles », mode « local », comptes à zéro ; après « Insérer des données d'exemple », les comptes sont non nuls.

- [ ] **Step 6 : Commit**

```bash
git add Pulse PulseTests
git commit -m "feat(app): add data debug screen with content, store status, export and erase"
```

---

### Task 20 : Mineurs de la revue M1, `make test`, revue finale

**Files:**
- Modify: `Packages/PulseHealth/Sources/PulseHealth/HealthKitReader.swift`, `Packages/PulseRecoveryEngine/Sources/PulseRecoveryEngine/Recovery/RecoveryCalculator.swift`
- Test: `Packages/PulseRecoveryEngine/Tests/PulseRecoveryEngineTests/RecoveryCalculatorTests.swift`

**Interfaces:**
- Produces : `HealthKitReader.sampleCount` plafonné (`static let sampleCountLimit = 10_000`, passé en `limit:` du descripteur) ; `RecoveryCalculator` ne compte dans `calibration` que les nuits dont `HRVBaseline.isValid(sdnnMs:)` est vrai.

- [ ] **Step 1 : Écrire le test de calibration**

```swift
@Test func calibrationCountsOnlyValidSDNNNights() {
    // 14 nuits d'historique dont 3 avec sdnnMs 0 ou 400 → calibration == .calibrating(nights: 11)
}
```

- [ ] **Step 2 : Lancer pour vérifier l'échec**

Run : `swift test --package-path Packages/PulseRecoveryEngine --filter calibrationCountsOnlyValidSDNNNights`
Expected : échec (`.ready`).

- [ ] **Step 3 : Corriger `RecoveryCalculator.hrvFactor` et plafonner `sampleCount`**

- [ ] **Step 4 : Tout lancer**

Run (hors bac à sable) : `make test`
Expected : lint à zéro, les six suites de packages vertes, `make test-app` code de sortie 0. Noter le nombre total de tests.

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulseHealth Packages/PulseRecoveryEngine
git commit -m "fix: cap HealthKit sample count and count only valid SDNN nights in calibration"
```

- [ ] **Step 6 : Revue finale de la branche et PR**

Utiliser `superpowers:requesting-code-review` sur `master..m2-donnees-contenu` avec la spec M2 comme référence, corriger ce qui est bloquant, puis `superpowers:finishing-a-development-branch` : PR `m2-donnees-contenu` → `master` après accord de Mathéo pour le push. Corps de PR : résumé par package, nombre de tests, et la liste « Ce qui revient à Mathéo » de la spec M2 §11 (équipe, conteneur iCloud, déploiement du schéma CloudKit en production).

---

## Sortie du jalon

M2 est fini quand `make test` est vert, l'onglet « Données » affiche le contenu chargé et les comptes, un export JSON et un zip CSV s'ouvrent depuis la feuille de partage, « Tout supprimer » ramène tous les comptes à zéro, et la PR est fusionnée. Restent à Mathéo après la fusion : lancer sur l'iPhone avec iCloud, vérifier « compte disponible », tester la restauration après réinstallation, déployer le schéma CloudKit en production avant le premier TestFlight synchronisé.
