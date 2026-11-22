# Pulse M8a — Confidentialité : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Plus aucune valeur lue dans Apple Santé dans le magasin iCloud. Pulse est livré avec son manifeste de confidentialité, ses pages publiques, des textes vrais et le document App Store Connect.

**Architecture:**
- La séparation se fait dans `PulsePersistence`. Trois nouveaux modèles du magasin `local` (schéma V4) reçoivent les valeurs brutes des nuits, les courses importées et les pesées Apple Santé. Les dépôts SwiftData routent les écritures et recomposent les lectures, donc le domaine et les services ne voient rien.
- Un acteur `SwiftDataHealthDataRelocation` vide le magasin synchronisé de ce qui y reste. Il tourne au début de chaque passage du jour.
- Le poids du profil ne suit plus que les pesées saisies dans Pulse.

**Tech Stack:** Swift 6, SwiftData (deux configurations, CloudKit privé), Swift Testing, SwiftUI, HTML statique pour GitHub Pages.

**Spec:** `docs/superpowers/specs/2026-11-22-pulse-m8-app-store-design.md` (§1–6, §8–11). M8b (accessibilité, spec §7) aura son propre plan.

## Global Constraints

- Branche `m8-confidentialite` (déjà créée, spec commitée en c539567). Vérifier `git branch --show-current` avant chaque commit, ne jamais committer sur `master`. Pousser seulement avec une refspec explicite, et seulement quand Mathéo le demande.
- Avant chaque commit, lancer `git status --short` et ajouter les nouveaux fichiers par leur nom ; ne jamais ajouter `.agents/` ni `.gemini/`. Lint et tests se lancent dans une étape à part, et on ne committe qu'après avoir lu le résultat.
- Ne jamais lancer le simulateur : pas de `xcodebuild test`, pas de `make test`, pas de `make test-app`, pas de `simctl`. On vérifie avec `swift test --package-path Packages/<Nom>`, `swiftlint lint --strict`, `make build-app` et `make build-release`.
- Les modèles synchronisés ne changent pas, aucun champ n'est retiré (CloudKit en production n'accepte que des ajouts). Les champs bruts de `StoredDailyRecovery` sont documentés « plus jamais écrits (M8a) ».
- Une valeur n'est retirée du magasin synchronisé qu'une fois écrite dans le magasin local, et dans le même `save()`.
- Commentaires et chaînes en français, dans le style des fichiers voisins ; chaînes de l'app en `String(localized:bundle: .module)`.
- Aucune dépendance nouvelle.

## Review Focus

1. **Une course corrigée** (RPE ou note modifiés depuis « Modifier ») : elle doit rester dans `StoredImportedWorkout`, sans jamais réapparaître dans `StoredWorkoutSession`. Test dans la tâche 3.
2. **Un score réécrit** dans la journée (passage suivant, check-in, choix de la séance d'origine) : la ligne brute du jour est mise à jour, pas dupliquée, et un score sans aucune valeur brute supprime la ligne brute. Test dans la tâche 2.
3. **Des lignes `appleHealth` redescendues d'iCloud après le déplacement**, y compris marquées supprimées : un nouveau passage les retire sans dupliquer celles déjà copiées. Test dans la tâche 5.
4. **Un passage sans rien à déplacer** : le magasin n'est pas modifié (pas de `save()`, pas de `updatedAt` touché). Test dans la tâche 5.
5. **Une pesée saisie très ancienne et des pesées Apple Santé récentes** : `weightKg` prend la dernière pesée saisie, et le poids utilisé à l'export prend la tendance Apple Santé. Test dans la tâche 6.

---

### Task 1: Schéma V4 et modèles locaux

**Files:**
- Create: `Packages/PulsePersistence/Sources/PulsePersistence/Models/StoredRecoveryReading.swift`
- Create: `Packages/PulsePersistence/Sources/PulsePersistence/Models/StoredImportedWorkout.swift`
- Create: `Packages/PulsePersistence/Sources/PulsePersistence/Models/StoredImportedBodyMeasurement.swift`
- Create: `Packages/PulsePersistence/Sources/PulsePersistence/Schema/PulseSchemaV4.swift`
- Modify: `Packages/PulsePersistence/Sources/PulsePersistence/Schema/PulseSchemaV1.swift`, `PulseSchemaV2.swift`, `PulseSchemaV3.swift` (liste locale explicite)
- Modify: `Packages/PulsePersistence/Sources/PulsePersistence/Schema/PersistenceStack.swift` (`localModels`)
- Modify: `Packages/PulsePersistence/Sources/PulsePersistence/Schema/PulseMigrationPlan.swift`
- Modify: `Packages/PulsePersistence/Sources/PulsePersistence/Models/StoredDailyRecovery.swift` (commentaire sur les six champs)
- Test: `Packages/PulsePersistence/Tests/PulsePersistenceTests/SchemaFingerprintTests.swift`, `MigrationTests.swift`, `Fixtures/schema-v4.txt`

**Interfaces:**
- Produces :
  - `StoredRecoveryReading` (`@Model public final class`) : `day: Date`, `sdnnMs: Double?`, `sdnnBaselineMs: Double?`, `restingHeartRate: Double?`, `restingHeartRateBaseline: Double?`, `asleepMinutes: Int?`, `deepMinutes: Int?`, `createdAt`, `updatedAt`. Il expose aussi `init(day:from recovery: DailyRecovery, at: Date)`, `apply(_ recovery: DailyRecovery, at: Date)`, `var isEmpty: Bool` (vrai si les six valeurs sont nulles) et `func fill(_ recovery: inout DailyRecovery)`.
  - `StoredImportedWorkout` : tous les champs scalaires de `StoredWorkoutSession`, sans `sets`. Il expose `init(_ session: WorkoutSession)`, `apply(_:)` et `toDomain() -> WorkoutSession` (avec `sets: []`).
  - `StoredImportedBodyMeasurement` : mêmes champs et mêmes méthodes que `StoredBodyMeasurement`.
  - `PulseSchemaV4` (`Schema.Version(4, 0, 0)`, `models = PersistenceStack.syncedModels + PersistenceStack.localModels`).
  - `PersistenceStack.localModels` ajoute les trois modèles après les trois actuels.

- [ ] **Step 1: Write the failing tests**

Dans `SchemaFingerprintTests.swift` :
- `v4SchemaMatchesItsFingerprint()` : comme v3, contre `"schema-v4"`.
- `v4OnlyAddsTheThreeLocalModels()` : `v3.subtracting(v4)` est vide. Les noms d'entités ajoutés, c'est-à-dire le préfixe avant le premier `.` des lignes de `v4.subtracting(v3)`, valent exactement `["StoredImportedBodyMeasurement", "StoredImportedWorkout", "StoredRecoveryReading"]`.
- Les tests v1, v2 et v3 existants doivent rester verts sans régénérer leurs fichiers de référence. C'est ce qui prouve que la liste locale est bien figée.

Dans `MigrationTests.swift` : `v3StoreOpensAsV4KeepingData()`. Il écrit un magasin V3 avec un conteneur figé (`PulseSchemaV3.models` sans plan de migration, même mécanique que `writeV2Store`), avec un `StoredDailyRecovery` qui porte `sdnnMs = 50` et un `StoredWorkoutSession` en `source = "appleHealth"`. Ensuite il ouvre `PersistenceStack.makeContainer(directory:)` et vérifie que `fetchCount` des deux lignes vaut 1, et que `fetchCount(FetchDescriptor<StoredRecoveryReading>())` vaut 0.

- [ ] **Step 2: Run to verify they fail**

Run: `swift test --package-path Packages/PulsePersistence --filter "SchemaFingerprint|Migration"`
Expected: FAIL. `PulseSchemaV4` et `StoredRecoveryReading` n'existent pas.

- [ ] **Step 3: Implement**

- Dans V1, V2 et V3, remplacer `+ PersistenceStack.localModels` par la liste écrite en dur `[StoredCachedHealthSample.self, StoredHealthQueryAnchor.self, StoredActiveSessionSnapshot.self]`, avec le commentaire « liste locale figée en M8a ».
- Dans le commentaire de V3, retirer « les modèles actuels » pour V3 seulement si c'est faux : ses modèles synchronisés restent les modèles actuels.
- Les nouveaux modèles n'ont pas d'attribut `.unique` (la ligne d'un jour est retrouvée par requête, comme `StoredDailyRecovery`).
- Le plan de migration gagne `PulseSchemaV4` et `.lightweight(fromVersion: PulseSchemaV3.self, toVersion: PulseSchemaV4.self)`.
- Générer la référence v4 avec `PULSE_WRITE_SCHEMA_FIXTURES=1 swift test --package-path Packages/PulsePersistence --filter v4SchemaMatchesItsFingerprint`, puis relire le fichier : il ne doit contenir aucune ligne retirée par rapport à v3.

- [ ] **Step 4: Run to verify they pass**

Run: `swift test --package-path Packages/PulsePersistence`
Expected: PASS, tous les tests du package.

- [ ] **Step 5: Commit**

```bash
git add Packages/PulsePersistence/Sources/PulsePersistence/Models/StoredRecoveryReading.swift \
  Packages/PulsePersistence/Sources/PulsePersistence/Models/StoredImportedWorkout.swift \
  Packages/PulsePersistence/Sources/PulsePersistence/Models/StoredImportedBodyMeasurement.swift \
  Packages/PulsePersistence/Sources/PulsePersistence/Schema/PulseSchemaV4.swift \
  Packages/PulsePersistence/Tests/PulsePersistenceTests/Fixtures/schema-v4.txt
git add -u Packages/PulsePersistence
git commit -m "feat(persistence): schema V4 with local models for Apple Health values"
```

### Task 2: Dépôt des scores : valeurs brutes sur l'appareil

**Files:**
- Modify: `Packages/PulsePersistence/Sources/PulsePersistence/Repositories/SwiftDataRecoveryRepository.swift`
- Modify: `Packages/PulsePersistence/Sources/PulsePersistence/Models/StoredDailyRecovery.swift` (`apply` n'écrit plus les six champs bruts)
- Test: `Packages/PulsePersistence/Tests/PulsePersistenceTests/RecoveryRepositoryTests.swift`

**Interfaces:**
- Consumes : `StoredRecoveryReading` (tâche 1).
- Produces : `StoredDailyRecovery.apply(_:)` laisse les six champs bruts tels quels ; un nouveau `StoredDailyRecovery.clearHealthValues()` les met à nul. `toDomain()` lit encore les champs pour les anciennes lignes ; la tâche 5 s'en sert. Les signatures publiques du dépôt ne changent pas.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func savedRecoveryKeepsRawValuesOffTheSyncedStore() async throws {
    let box = try ModelContainerBox()
    let repository = SwiftDataRecoveryRepository(modelContainer: box.container, calendar: Fixed.calendar)
    try await repository.save(Sample.recovery())
    let context = ModelContext(box.container)
    let synced = try #require(try context.fetch(FetchDescriptor<StoredDailyRecovery>()).first)
    #expect(synced.sdnnMs == nil && synced.sdnnBaselineMs == nil && synced.restingHeartRate == nil)
    #expect(synced.restingHeartRateBaseline == nil && synced.asleepMinutes == nil && synced.deepMinutes == nil)
    #expect(synced.score == 72 && synced.hrvScore == 80)
    let reading = try #require(try context.fetch(FetchDescriptor<StoredRecoveryReading>()).first)
    #expect(reading.sdnnMs == 50 && reading.deepMinutes == 80)
    let read = try await repository.dailyRecoveries(from: .distantPast, to: .distantFuture)
    #expect(read.first?.sdnnMs == 50 && read.first?.restingHeartRateBaseline == 50 && read.first?.asleepMinutes == 420)
}
```

D'autres tests suivent la même forme :
- `rewritingTheDayUpdatesItsReadingInPlace` : deux `save` le même jour avec `sdnnMs` 50 puis 55 donnent une seule `StoredRecoveryReading`, à 55.
- `recoveryWithoutRawValuesDropsTheReading` : un `save` avec les six valeurs nulles après un `save` complet donne 0 `StoredRecoveryReading`, et la lecture rend des valeurs nulles.
- `readingsJoinTheirOwnDay` : deux jours aux valeurs différentes, chaque `DailyRecovery` lu porte les siennes.

- [ ] **Step 2: Run to verify they fail**

Run: `swift test --package-path Packages/PulsePersistence --filter RecoveryRepository`
Expected: FAIL sur `savedRecoveryKeepsRawValuesOffTheSyncedStore` (`synced.sdnnMs == 50`).

- [ ] **Step 3: Implement**

- `save` : calculer le jour local, insérer ou mettre à jour le `StoredDailyRecovery` (sans les valeurs brutes), puis créer, mettre à jour ou supprimer la `StoredRecoveryReading` du même `day`. Un seul `modelContext.save()` à la fin.
- `dailyRecoveries(from:to:)` : lire les lectures de la même plage en un fetch, les indexer par `day`, et appeler `fill` sur chaque score. Si aucune lecture n'existe pour un jour, garder les valeurs encore présentes dans l'ancienne ligne.

- [ ] **Step 4: Run to verify they pass**

Run: `swift test --package-path Packages/PulsePersistence`
Expected: PASS. `MigrationTests` et `JSONExportTests` passent encore. Si un test d'export dépendait des champs bruts du magasin synchronisé, il est réparé en tâche 4 : le noter, ne pas le contourner ici.

- [ ] **Step 5: Commit**

```bash
git add -u Packages/PulsePersistence
git commit -m "feat(persistence): keep raw night values in the local store"
```

### Task 3: Dépôts des séances et des mesures : imports sur l'appareil

**Files:**
- Modify: `Packages/PulsePersistence/Sources/PulsePersistence/Repositories/SwiftDataWorkoutRepository.swift`
- Modify: `Packages/PulsePersistence/Sources/PulsePersistence/Repositories/SwiftDataBodyMeasurementRepository.swift`
- Test: `Packages/PulsePersistence/Tests/PulsePersistenceTests/WorkoutRepositoryTests.swift`, `BodyMeasurementRepositoryTests.swift`

**Interfaces:**
- Consumes : `StoredImportedWorkout`, `StoredImportedBodyMeasurement` (tâche 1).
- Produces : les signatures publiques ne changent pas. La règle de routage est `source == .appleHealth` → modèle local, sinon modèle synchronisé.

- [ ] **Step 1: Write the failing tests**

Ajouter dans `Sample` (`TestContainer.swift`) `importedRun(startedAt:)`, un `WorkoutSession` avec `kind: .run`, `source: .appleHealth`, `status: .completed`, `durationMinutes: 42`, `distanceMeters: 8_000`, `averageHeartRate: 151`, `estimatedRPE: 6`, `healthKitUUID: "RUN"` et `sets: []`.

Puis :
- `importedRunLivesOnlyInTheLocalStore` : après `save(Sample.importedRun())`, `StoredWorkoutSession` en compte 0 et `StoredImportedWorkout` en compte 1.
- `pulseSessionLivesOnlyInTheSyncedStore` : `Sample.session()` donne l'inverse.
- `sessionsMergeBothStoresInOrder` : une séance Pulse à `Fixed.t0` et une course à `Fixed.t0 - 3600`. `sessions(from:to:)` rend les identifiants dans l'ordre course puis séance. `session(id:)` trouve les deux.
- `correctedRunStaysLocal` (Review Focus 1) : une course est enregistrée, puis relue, puis on fixe `overallRPE = 8` et `note = "Jambes lourdes"` avant un nouveau `save`. Ensuite, `StoredWorkoutSession` en compte 0, la lecture rend RPE 8, et `StoredImportedWorkout` en compte 1.
- `deletingAnImportedRunMarksItDeleted` : `delete(id:)` d'une course fait disparaître la course de `sessions(from:to:)`.
- `healthMeasurementLivesOnlyInTheLocalStore` et `manualMeasurementLivesOnlyInTheSyncedStore` : même forme, avec `Sample.measurement()` (en `.appleHealth`) et une copie en `.manual`. `measurements(from:to:)` fusionne les deux dans l'ordre `date` puis `createdAt`.

- [ ] **Step 2: Run to verify they fail**

Run: `swift test --package-path Packages/PulsePersistence --filter "WorkoutRepository|BodyMeasurementRepository"`
Expected: FAIL. `StoredImportedWorkout` compte 0.

- [ ] **Step 3: Implement**

- `save` : chercher la ligne dans le modèle cible et la créer ou la mettre à jour. Si une ligne de même `id` existe dans l'autre modèle, la supprimer physiquement dans le même `save()` (spec §5.1, changement de source).
- `sessions` et `measurements` : deux fetchs, une fusion, puis le tri existant `(startedAt, createdAt)` ou `(date, createdAt)`.
- `delete` : suppression logique là où se trouve la ligne.
- `lastSets` ne change pas.

- [ ] **Step 4: Run to verify they pass**

Run: `swift test --package-path Packages/PulsePersistence`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -u Packages/PulsePersistence
git commit -m "feat(persistence): keep imported runs and Health weigh-ins in the local store"
```

### Task 4: Export, suppression, inspecteur, test de frontière

**Files:**
- Modify: `Packages/PulsePersistence/Sources/PulsePersistence/Export/ExportSnapshotLoader.swift`
- Modify: `Packages/PulsePersistence/Sources/PulsePersistence/Erase/StoreWiper.swift`
- Modify: `Packages/PulsePersistence/Sources/PulsePersistence/Repositories/SwiftDataStoreInspector.swift`
- Create: `Packages/PulsePersistence/Tests/PulsePersistenceTests/HealthBoundaryTests.swift`
- Test: `JSONExportTests.swift`, `CSVExportTests.swift`, `EraserTests.swift`, `StoreInspectorTests.swift`

**Interfaces:**
- Consumes : les trois modèles locaux (tâche 1) et le routage (tâches 2 et 3).
- Produces :
  - `ExportSnapshot` garde ses champs. `workoutSessions`, `dailyRecoveries` et `bodyMeasurements` contiennent les deux magasins, fusionnés et triés comme les dépôts.
  - `StoreTable` ne change pas : l'inspecteur additionne les lignes locales à `.workoutSessions` et `.bodyMeasurements`.

- [ ] **Step 1: Write the failing tests**

- `JSONExportTests` : `exportIncludesLocalHealthValues`. Il enregistre par les dépôts `Sample.recovery()`, `Sample.importedRun()` et `Sample.measurement()`, puis exporte. Le JSON contient `"sdnnMs" : 50`, la course `"healthKitUUID" : "RUN"` et la pesée `"healthKitUUID" : "ABC"`. On suit les clés et la mise en forme que vérifient déjà les tests voisins.
- `CSVExportTests` : `csvIncludesLocalHealthValues`. Mêmes données. Les fichiers `daily_recoveries`, `workout_sessions` et `body_measurements` ont chacun une ligne avec ces valeurs.
- `EraserTests` : `eraseWipesLocalHealthModels`. Après l'effacement, les trois modèles comptent 0.
- `StoreInspectorTests` : `countsIncludeLocalImports`. Une séance Pulse, une course, une pesée manuelle et une pesée Apple Santé donnent `.workoutSessions == 2` et `.bodyMeasurements == 2`.
- `HealthBoundaryTests.syncedStoreHoldsNoHealthValue` :

```swift
@Test func syncedStoreHoldsNoHealthValue() async throws {
    let box = try ModelContainerBox()
    try await SwiftDataRecoveryRepository(modelContainer: box.container, calendar: Fixed.calendar).save(Sample.recovery())
    let workouts = SwiftDataWorkoutRepository(modelContainer: box.container)
    try await workouts.save(Sample.importedRun())
    try await workouts.save(Sample.session())
    try await SwiftDataBodyMeasurementRepository(modelContainer: box.container).save(Sample.measurement())
    let context = ModelContext(box.container)
    let recoveries = try context.fetch(FetchDescriptor<StoredDailyRecovery>())
    #expect(recoveries.allSatisfy { $0.sdnnMs == nil && $0.sdnnBaselineMs == nil && $0.restingHeartRate == nil
        && $0.restingHeartRateBaseline == nil && $0.asleepMinutes == nil && $0.deepMinutes == nil })
    let health = SessionSource.appleHealth.rawValue
    #expect(try context.fetchCount(FetchDescriptor<StoredWorkoutSession>(predicate: #Predicate { $0.source == health })) == 0)
    let healthMeasure = MeasurementSource.appleHealth.rawValue
    #expect(try context.fetchCount(FetchDescriptor<StoredBodyMeasurement>(predicate: #Predicate { $0.source == healthMeasure })) == 0)
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `swift test --package-path Packages/PulsePersistence --filter "Export|Eraser|StoreInspector|HealthBoundary"`
Expected: FAIL sur l'export (pas de course, pas de `sdnnMs`), sur l'effacement (modèles locaux non vidés) et sur l'inspecteur (compte à 1). `HealthBoundaryTests` passe déjà grâce aux tâches 2 et 3.

- [ ] **Step 3: Implement**

- Loader : fusionner les séances et les mesures des deux magasins, et compléter chaque score avec sa `StoredRecoveryReading` par `fill`. La jointure est la même que dans le dépôt des scores : la factoriser dans une fonction interne partagée (`RecoveryReadingJoin.fill(_ recoveries:with readings:)`) plutôt que la recopier.
- Wiper : `delete(model:)` des trois modèles locaux.
- Inspecteur : additionner les lignes locales non supprimées.

- [ ] **Step 4: Run to verify they pass**

Run: `swift test --package-path Packages/PulsePersistence`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/PulsePersistence/Tests/PulsePersistenceTests/HealthBoundaryTests.swift
git add -u Packages/PulsePersistence
git commit -m "feat(persistence): export, erase and count the local Health models"
```

### Task 5: Déplacement des données existantes

**Files:**
- Create: `Packages/PulseDomain/Sources/PulseDomain/Repositories/HealthDataRelocating.swift`
- Create: `Packages/PulsePersistence/Sources/PulsePersistence/Repositories/SwiftDataHealthDataRelocation.swift`
- Create: `Packages/PulsePersistence/Tests/PulsePersistenceTests/HealthDataRelocationTests.swift`

**Interfaces:**
- Consumes : les trois modèles locaux (tâche 1), `StoredDailyRecovery.clearHealthValues()` et `toDomain()` (tâche 2).
- Produces :
  - `public protocol HealthDataRelocating: Sendable { func relocate() async throws -> Bool }`. La fonction rend vrai si quelque chose a été déplacé.
  - `@ModelActor public actor SwiftDataHealthDataRelocation: HealthDataRelocating`.

- [ ] **Step 1: Write the failing tests**

Chaque test écrit directement des modèles synchronisés « à l'ancienne » via un `ModelContext`, car les dépôts n'écrivent plus comme ça. Pour un score, il s'agit d'un `StoredDailyRecovery(Sample.recovery())` dont on remet à la main `sdnnMs = 50`, etc., après `init`. Pour une séance, d'un `StoredWorkoutSession` en `source = "appleHealth"`. Pour une pesée, d'un `StoredBodyMeasurement` en `source = "appleHealth"`.

- `movesRawNightValuesToTheDevice` : après `relocate()`, qui rend `true`, les champs bruts synchronisés sont nuls, et `dailyRecoveries` rend `sdnnMs == 50`.
- `localReadingWinsOverAnOldSyncedValue` : une `StoredRecoveryReading` du jour existe à 55 et le synchronisé porte 50. Après le déplacement, la lecture rend 55 et le synchronisé est nul.
- `movesImportedRunsAndDropsDeletedOnes` : une course vivante et une course marquée `deletedAt`. Après le déplacement, `StoredWorkoutSession` en `appleHealth` compte 0 (les deux sont supprimées physiquement) et `StoredImportedWorkout` compte 1, avec le même `id`.
- `doesNotDuplicateAnAlreadyMovedRun` (Review Focus 3) : la même course existe des deux côtés. Après le déplacement, il y a une seule ligne locale.
- `movesHealthWeighInsAndKeepsManualOnes` : une pesée Apple Santé et une pesée manuelle. La pesée Apple Santé passe en local, la manuelle reste synchronisée.
- `relocatingTwiceChangesNothing` (Review Focus 4) : le second `relocate()` rend `false`, et `updatedAt` du score synchronisé ne bouge pas entre le premier et le second appel.

- [ ] **Step 2: Run to verify they fail**

Run: `swift test --package-path Packages/PulsePersistence --filter HealthDataRelocation`
Expected: FAIL, le type n'existe pas.

- [ ] **Step 3: Implement `relocate()`**

Trois étapes : nuits, séances, mesures. Chacune commence par un fetch filtré :
- nuits : `sdnnMs != nil || sdnnBaselineMs != nil || restingHeartRate != nil || restingHeartRateBaseline != nil || asleepMinutes != nil || deepMinutes != nil` ;
- séances et mesures : `source == "appleHealth"`, sans filtre sur `deletedAt`.

Si le fetch revient vide, l'étape ne fait rien. Sinon elle écrit d'abord le local, puis vide ou supprime côté synchronisé, puis appelle `modelContext.save()` une fois. Une erreur est relancée : la ligne n'a pas été retirée, elle sera rejouée au passage suivant. Pour une nuit, une `StoredRecoveryReading` existante n'est pas écrasée ; les champs synchronisés sont vidés quand même. `updatedAt` des scores synchronisés n'est pas touché.

- [ ] **Step 4: Run to verify they pass**

Run: `swift test --package-path Packages/PulsePersistence && swift test --package-path Packages/PulseDomain`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/PulseDomain/Sources/PulseDomain/Repositories/HealthDataRelocating.swift \
  Packages/PulsePersistence/Sources/PulsePersistence/Repositories/SwiftDataHealthDataRelocation.swift \
  Packages/PulsePersistence/Tests/PulsePersistenceTests/HealthDataRelocationTests.swift
git commit -m "feat(persistence): move Apple Health values out of the synced store"
```

### Task 6: Services : poids du profil, poids utilisé, passage du jour

**Files:**
- Modify: `Packages/PulseFeatures/Sources/PulseServices/Body/WeightTrend.swift` (`ProfileWeightSync`)
- Modify: `Packages/PulseFeatures/Sources/PulseServices/Health/BodyHistory.swift` (synchronise le poids du profil à chaque passage ; commentaires de la garde)
- Modify: `Packages/PulseFeatures/Sources/PulseServices/Health/WorkoutHistory.swift` (commentaire de la garde seulement)
- Modify: `Packages/PulseFeatures/Sources/PulseServices/Health/HealthWorkoutExporter.swift`
- Modify: `Packages/PulseFeatures/Sources/PulseServices/Refresh/DayRefresher.swift`
- Create (test double) : `Packages/PulseFeatures/Sources/PulseServices/Doubles/RecordingHealthDataRelocation.swift`, à côté des doubles existants.
- Test: `Packages/PulseFeatures/Tests/PulseServicesTests/WeightTrendTests.swift`, `HealthWorkoutExporterTests.swift`, `DayRefresherTests.swift`, `BodyServiceTests.swift`

**Interfaces:**
- Consumes : `HealthDataRelocating` (tâche 5).
- Produces :
  - `ProfileWeightSync.apply(measurements:profiles:now:calendar:)` garde la même signature et suit la nouvelle règle.
  - `ProfileWeightSync.currentWeight(measurements: any BodyMeasurementRepository, profiles: any ProfileRepository, now: Date, calendar: Calendar) async -> Double?`.
  - `HealthWorkoutExporter.init(writer:workouts:profiles:measurements: any BodyMeasurementRepository, calendar: Calendar)`.
  - `DayRefresher.init(..., relocation: (any HealthDataRelocating)? = nil, ...)`, placé juste après `planning:`.

Règle de `apply` (spec §5.3) :
- Lire toutes les pesées (`.distantPast` à demain).
- `manual` = les pesées `.manual` avec un poids.
- Si `manual` n'est pas vide : la cible est la tendance (`WeightTrend.make(...).current`) des pesées manuelles des 30 derniers jours. Faute de tendance, c'est le poids de la dernière pesée manuelle. On arrondit au dixième.
- Sinon, s'il existe une pesée `.appleHealth` avec un poids : la cible est `nil`.
- Sinon : on ne touche à rien.
- On n'écrit le profil que si la valeur change.

`currentWeight` rend la tendance de toutes les pesées des 30 derniers jours, sinon `profile.weightKg`.

- [ ] **Step 1: Write the failing tests**

Dans `WeightTrendTests` :
- `profileWeightIgnoresHealthWeighIns` : des pesées manuelles à 80 et des pesées Apple Santé à 70, sur les mêmes jours. Le profil est à 80.
- `profileWeightTakesTheLastManualWhenOld` (Review Focus 5) : une pesée manuelle à 82 il y a 90 jours et des pesées Apple Santé récentes à 78. Le profil est à 82, et `currentWeight` rend environ 78.
- `profileWeightClearsWhenOnlyHealthWeighInsExist` : le profil est à 77 avec seulement des pesées Apple Santé. `weightKg` devient `nil`.
- `profileWeightUntouchedWithoutAnyWeighIn` : le profil reste à 77.

Dans `HealthWorkoutExporterTests` : `exportUsesTheHealthTrendForEnergy`. Le profil est à `weightKg = nil` et les pesées Apple Santé sont à 80. L'entrée écrite a la même énergie que `energyKcal(weightKg: 80, ...)`.

Dans `DayRefresherTests` : `passRelocatesBeforeReadingHealth`. Le double de déplacement note l'appel, et la source de nuits factice note sa lecture : le déplacement précède la lecture. Si le double lève une erreur, le passage continue et rend un score.

- [ ] **Step 2: Run to verify they fail**

Run: `swift test --package-path Packages/PulseFeatures --filter "WeightTrend|HealthWorkoutExporter|DayRefresher"`
Expected: FAIL, le profil est à 70 au lieu de 80 et `relocation:` n'existe pas.

- [ ] **Step 3: Implement**

- `ProfileWeightSync.apply` et `currentWeight` suivent la règle ci-dessus.
- `BodyHistory.refresh` appelle `ProfileWeightSync.apply` à chaque passage, plus seulement quand `changed` est vrai, ce qui couvre le cas du déplacement.
- Dans `BodyHistory` et `WorkoutHistory`, les commentaires de la garde ne disent plus que les imports « passent par iCloud » : ils sont locaux, et la garde couvre un cache vidé sans le magasin local.
- `HealthWorkoutExporter.export` utilise `currentWeight`.
- `DayRefresher.pass` appelle `try? await relocation?.relocate()` juste avant `nightHistory.refresh`, après la garde d'onboarding.
- Mettre à jour les appels de `HealthWorkoutExporter.init` dans les tests et les aperçus du package (le build le signale).

- [ ] **Step 4: Run to verify they pass**

Run: `swift test --package-path Packages/PulseFeatures`
Expected: PASS, tous les tests du package.

- [ ] **Step 5: Commit**

```bash
git status --short
git add Packages/PulseFeatures/Sources/PulseServices/Doubles/RecordingHealthDataRelocation.swift
git add -u Packages/PulseFeatures
git commit -m "feat(services): profile weight from typed weigh-ins, relocate Health data each day pass"
```

### Task 7: App : câblage, manifestes, textes

**Files:**
- Modify: `Pulse/AppDependencies.swift` (créer `SwiftDataHealthDataRelocation(modelContainer: container)`, le passer à `DayRefresher(relocation:)` et passer `measurements:` et `calendar:` à `HealthWorkoutExporter`)
- Create: `Pulse/PrivacyInfo.xcprivacy`, `PulseWidgets/PrivacyInfo.xcprivacy`
- Modify: `Pulse/Info.plist` (`NSHealthShareUsageDescription` et `PulsePrivacyPolicyURL`)
- Modify: `Packages/PulseFeatures/Sources/ProfileFeature/MyDataModel.swift` (phrase iCloud « disponible »)
- Modify: `Packages/PulseFeatures/Sources/ProfileFeature/Views/SettingsScreen.swift` (`AboutSettingsSection`)
- Modify: `Packages/PulseFeatures/Sources/ProfileFeature/Resources/Localizable.xcstrings` (nouvelles chaînes, si le catalogue n'est pas tenu à jour automatiquement par la compilation)
- Test: `Packages/PulseFeatures/Tests/ProfileFeatureTests/` (le fichier de tests de `MyDataModel`)

**Interfaces:**
- Consumes : `SwiftDataHealthDataRelocation` (tâche 5) et les nouvelles signatures (tâche 6).

- [ ] **Step 1: Write the failing test**

Dans le test de `MyDataModel` existant, `availableCloudSaysHealthStaysOnThePhone` vérifie que la phrase de `.available` vaut exactement :
« Tes séances, compléments et scores se synchronisent avec ton compte iCloud. Les données d'Apple Santé restent sur ce téléphone. »

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --package-path Packages/PulseFeatures --filter MyData`
Expected: FAIL, c'est l'ancienne phrase.

- [ ] **Step 3: Implement**

- **`MyDataModel`** : la nouvelle phrase.
- **`AboutSettingsSection`** : après la ligne Licences, un `Text` en `PulsePalette.text2` (pas de contrôle) qui dit exactement : « Pulse n'est pas un dispositif médical. Le score et les ajustements sont des repères d'entraînement, pas un avis médical. » Les deux modules ont des bundles différents, donc l'onboarding garde sa phrase courte ; le partage d'une seule chaîne prévu par la spec §6.3 est abandonné, ce qui est le choix du constructeur.
- **`NSHealthShareUsageDescription`**, texte exact : « Pulse lit votre sommeil, votre variabilité cardiaque et votre fréquence cardiaque au repos pour calculer votre score de récupération du matin, ainsi que vos entraînements, votre poids et votre masse grasse pour suivre votre progression. Ces données restent sur votre iPhone : elles ne sont ni synchronisées ni partagées. »
- **`PulsePrivacyPolicyURL`** : `https://d-seonay.github.io/kairos/confidentialite/`.
- **Manifestes** (les dossiers `Pulse/` et `PulseWidgets/` sont synchronisés, donc le fichier entre tout seul dans la cible). Contenu :
  - `NSPrivacyTracking` vaut `false` ;
  - `NSPrivacyTrackingDomains` et `NSPrivacyCollectedDataTypes` sont des tableaux vides ;
  - `NSPrivacyAccessedAPITypes` contient `NSPrivacyAccessedAPICategoryUserDefaults` avec les raisons `CA92.1` et `1C8F.1`.

  Avant d'écrire, lancer `grep -rnE "creationDate|modificationDate|contentModificationDate|systemUptime|mach_absolute_time|volumeAvailableCapacity|activeInputModes|attributesOfItem" Packages Pulse PulseWidgets --include=*.swift` en excluant `.build`. Chaque usage trouvé ajoute sa catégorie avec la raison Apple qui convient. Le commit dit ce que la recherche a trouvé.
- Vérifier que `plutil -lint` passe sur les deux manifestes et sur `Info.plist`.
- Compléments (spec §6.3) : déjà conformes (« Pulse ne propose pas de dose », `SupplementLabels.swift`) ; vérifier qu'aucune suggestion du catalogue (`PulseContent`) ne porte de dose préremplie, sans rien changer sinon.

- [ ] **Step 4: Verify**

Run, chacune lue séparément :
- `swift test --package-path Packages/PulseFeatures`
- `swiftlint lint --strict`
- `make build-app`
- `make build-release`

Expected: tests PASS, lint `0 violations`, builds sans erreur (Xcode 27 avec `-quiet` n'affiche pas de bandeau SUCCEEDED : le code de sortie 0 fait foi). Vérifier que `PrivacyInfo.xcprivacy` est bien copié dans le produit avec `find ~/Library/Developer/Xcode/DerivedData -path "*Pulse.app/PrivacyInfo.xcprivacy" -newer Pulse/Info.plist`.

- [ ] **Step 5: Commit**

```bash
git add Pulse/PrivacyInfo.xcprivacy PulseWidgets/PrivacyInfo.xcprivacy
git add -u Pulse Packages/PulseFeatures
git commit -m "feat(app): privacy manifests, truthful Health text, medical notice in settings, relocation wired"
```

### Task 8: Pages publiques et document App Store Connect

**Files:**
- Create: `docs/.nojekyll` (vide)
- Create: `docs/confidentialite/index.html`
- Create: `docs/support/index.html`
- Create: `docs/app-store/fiche.md`

**Interfaces:** aucune avec le code. Les pages ne disent que ce que le build fait après les tâches 1 à 7.

- [ ] **Step 1: Write `docs/confidentialite/index.html`**

Page autonome, `lang="fr"`, `<meta name="viewport">`, CSS en ligne, sans script ni ressource distante. Style papier monochrome : fond `#F4F1EA`, texte `#141414`, polices système, largeur de lecture d'environ 40 em, contraste AA.

Sections dans l'ordre :
1. En bref.
2. Ce que Pulse lit dans Apple Santé : sommeil, VFC (SDNN), FC au repos, entraînements, poids et masse grasse, chacun avec sa raison.
3. Ce que Pulse écrit dans Apple Santé : séances de musculation, prises de vitamine D, magnésium, caféine et protéines.
4. Où vivent tes données : sur l'iPhone ; dans ton iCloud privé pour ce que tu saisis et ce que Pulse calcule (séances, compléments, programme, check-ins, scores) ; les valeurs lues dans Apple Santé ne quittent jamais l'iPhone.
5. Ce que Pulse ne fait pas : aucun serveur, aucun compte, aucune analytics, aucune publicité, aucun partage avec un tiers.
6. Rapports de plantage : seulement ceux qu'Apple transmet si tu l'as accepté dans les réglages d'iOS.
7. Exporter et supprimer : depuis Profil → Mes données, sans contacter personne.
8. Pas un dispositif médical.
9. Contact : les issues du dépôt `https://github.com/D-Seonay/kairos/issues`.
10. « Mise à jour le 22 novembre 2026 ».

Ton : tutoiement, comme l'app.

- [ ] **Step 2: Write `docs/support/index.html`**

Même gabarit. Questions fréquentes :
- Pourquoi je n'ai pas de score ?
- Ma montre n'est pas une Apple Watch.
- Combien de temps dure la calibration ?
- Comment exporter mes données ?
- Comment tout supprimer ?
- Mes données sur un nouvel iPhone : la sauvegarde iCloud de l'iPhone ou le transfert direct gardent tout. Après une désinstallation, séances, compléments et scores reviennent d'iCloud, et le détail des nuits ne revient pas.

Ajouter le lien vers la politique et le contact.

- [ ] **Step 3: Write `docs/app-store/fiche.md`**

Sections (spec §6.4) :
1. **Confidentialité de l'app** : « Données non collectées », avec la justification en deux phrases.
2. **Classification** : les réponses au questionnaire.
3. **Chiffrement** : exempt, déjà dans l'Info.plist.
4. **Notes pour la revue** : en anglais et en français, puisque la revue lit l'anglais.
5. **Fiche** : nom « Pulse » et deux alternatives (« Pulse — Récupération & Muscu », « Pulse Training ») ; sous-titre de 30 caractères au plus ; description ; mots-clés de 100 caractères au plus, séparés par des virgules ; catégorie principale Forme et santé ; URL de politique et d'assistance.
6. **Avant de soumettre** : la liste de la spec §10, à cocher.

- [ ] **Step 4: Verify**

- Lancer `grep -c "<script" docs/confidentialite/index.html docs/support/index.html` : 0 partout.
- Ouvrir les deux fichiers par leur chemin et relire chaque phrase de la politique face aux tâches 1 à 7 (anti-objectif de la spec §2). Ne pas lancer de serveur.

- [ ] **Step 5: Commit**

```bash
git add docs/.nojekyll docs/confidentialite/index.html docs/support/index.html docs/app-store/fiche.md
git commit -m "docs(m8): privacy policy, support page and App Store Connect sheet"
```

### Vérification finale de la branche

- [ ] Les six `swift test --package-path Packages/<Nom>` (PulseDomain, PulseRecoveryEngine, PulseContent, PulsePersistence, PulseDesignSystem, PulseFeatures) sont verts.
- [ ] `swiftlint lint --strict` : 0.
- [ ] `make build-app` et `make build-release` : code de sortie 0.
- [ ] `git log --oneline master..m8-confidentialite` : la spec, le plan et 8 commits de tâches.
- [ ] Après la fusion sur `master` seulement : activer GitHub Pages (`master`, `/docs`), avec l'accord de Mathéo donné le 22 novembre 2026, puis vérifier que les deux URL répondent.
