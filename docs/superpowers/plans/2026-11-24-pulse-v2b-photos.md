# Pulse V2b — Photos de séance et photos de corps : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ajouter jusqu'à 6 photos privées à une séance (live, récap, plus tard), synchronisées avec iCloud. Ajouter des photos de corps face, profil et dos qui restent sur l'iPhone, dans des fichiers protégés exclus des sauvegardes, derrière Face ID, avec un comparateur avant / après. Prévoir un export et une suppression pour chacune.

**Architecture :**
- **Lot 1, photos de séance.**
  - Les types et protocoles vont dans `PulseDomain/Photos`.
  - Le traitement d'image (ImageIO, sans métadonnées) et les règles pures vont dans `PulseServices/Photos`.
  - Le stockage passe en schéma V6 avec `StoredSessionPhoto` synchronisé (`externalStorage`). La suppression d'une séance emporte ses photos.
  - Une nouvelle cible `PhotosFeature` porte la section Photos réutilisable. Elle est branchée dans la séance live, le récap, le récap de course et les deux écrans de détail.
- **Lot 2, photos de corps.**
  - Un dépôt de fichiers `FileBodyPhotoStore` (protection `complete`, exclusion de sauvegarde, index JSON).
  - Un service, puis les écrans verrouillés, la comparaison et les réglages dans `PhotosFeature`.
  - Le branchement dans l'app, l'Info.plist, la vérification des clés et les textes publics.

**Tech Stack:** Swift 6.2, SwiftUI, PhotosUI (`PhotosPicker`), UIKit (`UIImagePickerController`), ImageIO, LocalAuthentication, AVFoundation (état de l'autorisation caméra), SwiftData + CloudKit, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-11-24-pulse-v2b-photos-design.md`, à lire avant chaque tâche. Les chemins et les signatures cités viennent d'une lecture du dépôt à f7aad42.

## Global Constraints

- **Branche** : `v2b-photos`, empilée sur `v2a-course-gps`.
  - Avant tout commit, `git branch --show-current` doit afficher `v2b-photos` : Mathéo partage ce checkout.
  - Lancer `git status --short`, puis ajouter les nouveaux fichiers **par nom**. Ne jamais ajouter `.agents/`, `.gemini/` ni `.superpowers/`.
  - Pas de trailer `Co-Authored-By`. Ne jamais pousser.
- **Ne jamais lancer le simulateur** : pas de `xcodebuild test`, `make test`, `make test-app`, `simctl` ni d'outils d'appareil.
  - Vérifier avec `swift test --package-path Packages/<Nom>`, `make lint`, `make build-app` et `make build-release`.
  - Avec Xcode 27, `-quiet` n'affiche aucune bannière : on juge au code de sortie 0.
  - Le lint et les tests passent chacun dans une commande à part. On ne commite qu'après avoir lu leur résultat.
- **Ne jamais ajouter le mode d'arrière-plan `workout-processing`** : App Store Connect le refuse.
- **Frontière des photos de corps** : aucune image, vignette ni entrée d'index de photo de corps ne doit aller dans :
  - un modèle SwiftData ;
  - l'export JSON ou CSV ;
  - une feuille de partage, la photothèque ou un widget.

  Leur dossier a `isExcludedFromBackup = true`, et chaque fichier est écrit avec `.completeFileProtection`.
- **Premier plan seulement** : rien de ce qui tourne en arrière-plan (passage du jour, Santé, course, widgets) n'appelle `BodyPhotoStore`.
- **Valeurs de la spec à reprendre telles quelles** :
  - 6 photos au plus par séance ;
  - grand côté 2 048 px, vignette 400 px, JPEG d'environ 600 Ko (qualité de départ 0,8) ;
  - poses face, profil et dos, une par pose et par jour local ;
  - une variation de poids absente si l'une des deux dates n'a pas de tendance.
- **Séances qui acceptent des photos** : `source != .appleHealth`, donc `.pulse` et `.hevy`.
- **Suppression d'une photo de séance** : logique, mais l'image et la vignette sont vidées, comme `StoredRunTrack.markDeleted`.
- **Textes** :
  - en français ; l'app tutoie, les textes d'autorisation de l'Info.plist vouvoient ;
  - dans les packages, `String(localized:…, bundle: .module)` ; dans l'app, `String(localized:)` ;
  - les commentaires sont en français, avec la densité du code voisin.
- **Accessibilité M8b** :
  - les libellés parlés sont produits par des fonctions testées ;
  - les annonces passent par `PulseAnnouncement` ;
  - cibles de 44 points ou plus, aperçus en `accessibility3`, Réduire les animations respecté.
- **Style Argentique** : réutiliser `ObsidianCard`, `PulseSectionHeader`, `PulseRow`, `PillButtonStyle`, `PrimaryButtonStyle`, `IconChip` et `PulseFont`. `PulsePalette.signal` est réservé à ce qui alerte. Les écrans poussés reprennent `.pulseInlineTitle()` et `.pulseScreenBackground(aura: 0.5)`.
- **Non-objectifs** (spec §2) : pas de social, de mensurations, d'appareil photo maison (fantôme, retardateur), de rappel, de retouche, de vidéo, de photo sur les séances `.appleHealth`, ni de copie iCloud des photos de corps.
- **Aucune dépendance nouvelle.**

## Écarts assumés avec la spec (lus dans le code)

1. **Une nouvelle cible `PhotosFeature`.** La section Photos sert dans cinq écrans répartis sur quatre cibles (LiveSessionFeature, RunFeature, TrainFeature, PlanningFeature), et les photos de corps vivent dans ProfileFeature. Une cible commune, dont dépendent les cinq autres, évite de dupliquer les vues.
2. **L'export JSON liste les photos de séance** (`ExportDocument.sessionPhotos`, sans image). L'archive CSV ajoute la table `session_photos` et les fichiers `photos/…jpg`.
3. **Le réglage du verrou** vit dans `UserDefaults`, comme `RunPreferencesStore`. L'effacement total vide le domaine, ce qui remet le verrou actif, sa valeur par défaut.

## Review Focus

1. **Photo ajoutée pendant une séance qui est ensuite abandonnée sans série** : rien n'est enregistré, et la photo disparaît aussi. Une séance abandonnée avec des séries garde ses photos. → tests `abandonWithoutSetsDeletesSessionPhotos` et `abandonWithSetsKeepsSessionPhotos` (tâche 6).
2. **Photo importée depuis Photos qui porte une position GPS et une orientation EXIF** : l'image gardée et l'export n'ont plus aucune métadonnée, et l'image est redressée. → tests `processedImageHasNoMetadata` et `orientationIsAppliedToPixels` (tâche 2), `csvArchiveCopiesPhotoBytesUnchanged` (tâche 4).
3. **Index des photos de corps restauré sans ses fichiers** (index ou fichier manquant, index illisible) : l'écran montre ce qui existe vraiment, sans planter, et l'index est réécrit. → tests `missingFileDropsItsIndexEntry` et `unreadableIndexStartsEmpty` (tâche 5).
4. **App qui passe en arrière-plan pendant que les photos de corps sont affichées** : un cache couvre l'écran dès l'inactivité, et au retour Face ID est redemandé. → tests `inactiveScenePhaseShowsCover` et `backgroundRelocks` (tâche 10).
5. **Septième photo, ou import multiple au-delà de la place restante** : rien au-delà de 6. L'import multiple garde les premières dans la limite, et l'écran le dit. → tests `serviceRefusesASeventhPhoto` (tâche 6) et `multipleImportIsCappedToRemainingSlots` (tâche 7).

---

## Lot 1 — Photos de séance

### Task 1: Types et protocoles des photos (domaine)

**Files:**
- Create: `Packages/PulseDomain/Sources/PulseDomain/Photos/SessionPhoto.swift` (`SessionPhoto`, `PhotoImage`)
- Create: `Packages/PulseDomain/Sources/PulseDomain/Photos/BodyPhoto.swift` (`BodyPose`, `BodyPhoto`)
- Create: `Packages/PulseDomain/Sources/PulseDomain/Repositories/PhotoRepositories.swift` (`SessionPhotoRepository`, `BodyPhotoStore`, `DeviceOwnerAuthenticating`)
- Test: `Packages/PulseDomain/Tests/PulseDomainTests/PhotoTypesTests.swift`

**Interfaces:**
- Produces (tout est `public` et `Sendable`) :

```swift
public struct SessionPhoto: Equatable, Identifiable, Codable {   // pas d'image : métadonnées seules
    public var id: UUID; public var sessionID: UUID; public var order: Int
    public var createdAt: Date; public var updatedAt: Date
    public static let maxPerSession = 6
}
public struct PhotoImage: Equatable { public var image: Data; public var thumbnail: Data }   // JPEG tous deux
public enum BodyPose: String, Codable, CaseIterable { case front, side, back }   // ordre d'affichage : face, profil, dos
public struct BodyPhoto: Equatable, Identifiable, Codable {
    public var id: UUID; public var pose: BodyPose
    public var takenAt: Date   // date choisie (métadonnées ou aujourd'hui, modifiable)
    public var createdAt: Date
}
public protocol SessionPhotoRepository: Sendable {
    /// Les photos vivantes de la séance, triées par `order` puis `createdAt`.
    func photos(for sessionID: UUID) async throws -> [SessionPhoto]
    func image(of photoID: UUID) async throws -> PhotoImage?
    func add(_ photo: SessionPhoto, image: PhotoImage) async throws
    func delete(photoID: UUID) async throws
    func deleteAll(sessionID: UUID) async throws
}
public protocol BodyPhotoStore: Sendable {
    /// Les photos dont le fichier existe, sans ordre garanti.
    func photos() async throws -> [BodyPhoto]
    func image(of photoID: UUID) async throws -> PhotoImage?
    /// Crée ou remplace la photo de même identifiant.
    func save(_ photo: BodyPhoto, image: PhotoImage) async throws
    func delete(photoID: UUID) async throws
    func deleteAll() async throws
    /// Écrit une archive zip des images dans `directory` et rend son URL.
    func exportArchive(to directory: URL) async throws -> URL
}
public protocol DeviceOwnerAuthenticating: Sendable {
    /// Vrai si l'iPhone a un code : sans code, ni verrou ni chiffrement.
    func isAvailable() async -> Bool
    func authenticate(reason: String) async -> Bool
}
```

- [ ] **Step 1: Write the failing tests** :
  - `bodyPosesAreOrderedFrontSideBack` : `BodyPose.allCases == [.front, .side, .back]` ;
  - `sessionPhotoRoundTripsThroughJSON` : encodage puis décodage donnent une valeur égale ;
  - `maxPerSessionIsSix`.
- [ ] **Step 2: Run** `swift test --package-path Packages/PulseDomain`. Expected: FAIL (types absents).
- [ ] **Step 3: Implement** les types et protocoles ci-dessus, avec des initialiseurs publics memberwise.
- [ ] **Step 4: Run** `swift test --package-path Packages/PulseDomain`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(photos): domain types and repository protocols for session and body photos`.

### Task 2: Traitement d'image (`PhotoProcessor`)

**Files:**
- Create: `Packages/PulseFeatures/Sources/PulseServices/Photos/PhotoProcessor.swift`
- Test: `Packages/PulseFeatures/Tests/PulseServicesTests/PhotoProcessorTests.swift`. Les images de test sont fabriquées dans le test (`CGContext` puis `CGImageDestination` avec un dictionnaire EXIF, GPS et TIFF), sans fichier binaire.

**Interfaces:**
- Consumes: `PhotoImage` (tâche 1).
- Produces:

```swift
public struct ProcessedPhoto: Sendable, Equatable { public var image: PhotoImage; public var capturedAt: Date? }
public enum PhotoProcessingError: Error, Equatable { case unreadable, encodingFailed }
public enum PhotoProcessor {
    public static let longSide = 2048
    public static let thumbnailLongSide = 400
    public static let quality = 0.8
    /// Redresse selon l'orientation EXIF, réduit, réencode en JPEG sans aucune métadonnée. `capturedAt` vient de
    /// `DateTimeOriginal`, lu dans `timeZone` (l'EXIF n'a pas de fuseau).
    public static func process(_ data: Data, timeZone: TimeZone) throws -> ProcessedPhoto
}
```

- [ ] **Step 1: Write the failing tests** :
  - `downscalesLongSideTo2048` : une image de 3000 × 1000 donne 2048 × 683 (± 1), et sa vignette 400 × 133 (± 1) ;
  - `keepsSmallerImagesAtTheirSize` : une image de 800 × 600 reste en 800 × 600 ;
  - `orientationIsAppliedToPixels` : 400 × 200 avec l'orientation EXIF 6 donne une image plus haute que large, d'orientation 1 ou absente ;
  - `processedImageHasNoMetadata` : une source avec GPS (latitude 48.85), EXIF (`DateTimeOriginal`) et TIFF (`Make`) donne une image et une vignette dont `CGImageSourceCopyPropertiesAtIndex` n'a ni clé `{GPS}`, ni `{Exif}` `DateTimeOriginal`, ni `{TIFF}` `Make` ;
  - `readsOriginalCaptureDate` : `DateTimeOriginal` `"2026:08:01 07:30:00"` en `Europe/Paris` donne le 1er août 2026 à 05:30 UTC ;
  - `missingCaptureDateIsNil` ;
  - `rejectsNonImageData` : `Data("abc".utf8)` lance `.unreadable`.
- [ ] **Step 2: Run** `swift test --package-path Packages/PulseFeatures --filter PhotoProcessorTests`. Expected: FAIL.
- [ ] **Step 3: Implement** avec `CGImageSourceCreateThumbnailAtIndex` (`kCGImageSourceCreateThumbnailFromImageAlways`, `kCGImageSourceCreateThumbnailWithTransform`, `kCGImageSourceThumbnailMaxPixelSize`), une fois pour 2048 et une fois pour 400. Encoder avec `CGImageDestinationAddImage` en `UTType.jpeg` et un dictionnaire qui ne contient que `kCGImageDestinationLossyCompressionQuality`. Ne jamais copier les propriétés de la source.
- [ ] **Step 4: Run** la même commande. Expected: PASS.
- [ ] **Step 5: Commit** `feat(photos): strip metadata, orient and downscale photos with ImageIO`.

### Task 3: Règles pures des photos

**Files:**
- Create: `Packages/PulseFeatures/Sources/PulseServices/Photos/SessionPhotoRules.swift`
- Create: `Packages/PulseFeatures/Sources/PulseServices/Photos/BodyPhotoTimeline.swift`
- Test: `Packages/PulseFeatures/Tests/PulseServicesTests/PhotoRulesTests.swift`

**Interfaces:**
- Consumes: tâche 1, `WorkoutSession`, `WeightTrend` (`PulseServices/Body/WeightTrend.swift`, `trendPoints: [StatsPoint]` à minuit local).
- Produces:

```swift
public enum SessionPhotoRules {
    public static func acceptsPhotos(_ session: WorkoutSession) -> Bool      // source != .appleHealth
    public static func remainingSlots(current: Int) -> Int                  // max(0, 6 - current)
}
public struct BodyPhotoDay: Sendable, Equatable, Identifiable {
    public var day: Date                       // début du jour local
    public var photos: [BodyPose: BodyPhoto]
    public var id: Date { day }
}
public enum BodyPhotoTimeline {
    /// Un jour par date de prise, le plus récent d'abord ; si deux photos ont même pose et même jour, la plus récente gagne.
    public static func days(_ photos: [BodyPhoto], calendar: Calendar) -> [BodyPhotoDay]
    public static func existing(pose: BodyPose, on date: Date, in photos: [BodyPhoto], calendar: Calendar) -> BodyPhoto?
    /// Les poses qui ont au moins deux jours différents, dans l'ordre de `BodyPose.allCases`.
    public static func comparablePoses(_ photos: [BodyPhoto], calendar: Calendar) -> [BodyPose]
    /// La plus ancienne et la plus récente photo de la pose ; nil sous deux jours.
    public static func defaultPair(pose: BodyPose, in photos: [BodyPhoto], calendar: Calendar) -> (before: BodyPhoto, after: BodyPhoto)?
    /// Tendance de l'après moins tendance de l'avant. La tendance d'une date est celle du dernier jour mesuré dans les 7 jours qui
    /// finissent ce jour (`WeightTrend.window`) ; nil si l'une manque.
    public static func weightChange(trend: WeightTrend, from: Date, to: Date, calendar: Calendar) -> Double?
}
```

- [ ] **Step 1: Write the failing tests** :
  - `appleHealthSessionsTakeNoPhotos` : `.pulse` et `.hevy` donnent vrai, `.appleHealth` faux ;
  - `remainingSlotsNeverNegative` : 0 → 6, 6 → 0, 7 → 0 ;
  - `daysGroupNewestFirst` : trois photos sur deux jours donnent deux jours, le plus récent d'abord, avec les bonnes poses ;
  - `samePoseSameDayKeepsLatest` ;
  - `comparablePosesNeedTwoDays` : face sur deux jours et dos sur un seul donnent `[.front]` ;
  - `defaultPairIsOldestAndNewest` : trois dates donnent la première et la dernière ;
  - `weightChangeUsesTrendWithinSevenDays` : des pesées le 1er août (70) et le 28 octobre (68,6) donnent −1,4 (± 0,01) ;
  - `weightChangeIsNilWithoutRecentTrend` : la dernière pesée 10 jours avant la date de fin donne `nil`.
- [ ] **Step 2: Run** `swift test --package-path Packages/PulseFeatures --filter PhotoRulesTests`. Expected: FAIL.
- [ ] **Step 3: Implement** les deux types.
- [ ] **Step 4: Run** la même commande. Expected: PASS.
- [ ] **Step 5: Commit** `feat(photos): pure rules for session photo limits and body photo timeline`.

### Task 4: Stockage V6 des photos de séance

**Files:**
- Create: `Packages/PulsePersistence/Sources/PulsePersistence/Models/StoredSessionPhoto.swift`. Il est synchronisé :
  - `id: UUID = UUID()`, `sessionID: UUID?`, `order: Int = 0` ;
  - `@Attribute(.externalStorage) imageData: Data?` et `@Attribute(.externalStorage) thumbnailData: Data?` ;
  - `createdAt`, `updatedAt`, `deletedAt: Date?` ;
  - `markDeleted(at:)` vide les deux données.

  Il n'a pas de `.unique`, comme l'exige CloudKit.
- Create: `Packages/PulsePersistence/Sources/PulsePersistence/Schema/PulseSchemaV6.swift`
- Modify: `Schema/PulseSchemaV5.swift` : listes figées `static let syncedModels` (les 16 actuels) et `static let localModels` (les 8 actuels) ; `models` = ces listes. Mettre à jour le commentaire de `PulseSchemaV4` qui cite V5.
- Modify: `Schema/PersistenceStack.swift` : `StoredSessionPhoto` ajouté aux modèles synchronisés ; `Schema(versionedSchema: PulseSchemaV6.self)` partout où V5 apparaît.
- Modify: `Schema/PulseMigrationPlan.swift` : V6 et `.lightweight(fromVersion: PulseSchemaV5.self, toVersion: PulseSchemaV6.self)`.
- Create: `Packages/PulsePersistence/Sources/PulsePersistence/Repositories/SwiftDataSessionPhotoRepository.swift`. C'est un `@ModelActor`, avec l'extension `ModelContext.markSessionPhotosDeleted(sessionID:at:) -> Bool`, sur le modèle de `markRunTracksDeleted`.
- Modify: `Repositories/SwiftDataWorkoutRepository.swift` : `delete(id:)` d'une séance synchronisée appelle aussi `markSessionPhotosDeleted`.
- Modify: `Erase/StoreWiper.swift`, `SwiftDataStoreInspector` (compteur) et `PulseDomain/Repositories/StoreTable.swift` (`sessionPhotos`, après `runTracks`, exporté).
- Modify: `PulseDomain/Export/ExportDocument.swift` (`sessionPhotos: [SessionPhoto] = []`), `Export/ExportSnapshotLoader.swift`, `Export/JSONExportWriter.swift`.
- Modify: `Export/CSVColumns+Training.swift`, avec la table `session_photos` : `id`, `session_id`, `order`, `created_at`, `file`.
- Modify: `Export/SwiftDataExporter.swift`. `exportCSVArchive()` écrit chaque image vivante dans `photos/AAAA-MM-JJ-<8 premiers caractères de session_id>-<order+1>.jpg`, le nom repris dans la colonne `file`, et le README le mentionne. `exportJSON()` ne contient aucune image.
- Modify: `Packages/PulseFeatures/Sources/PulseServices/Doubles/InMemoryRepositories.swift` (`InMemorySessionPhotoRepository`)
- Test: `SchemaFingerprintTests.swift` (+ `Fixtures/schema-v6.txt`), `MigrationTests.swift`, `SessionPhotoRepositoryTests.swift`, `WorkoutRepositoryTests.swift`, `ExportTests` (le fichier existant des exports), `EraseTests` (le fichier existant)

**Interfaces:**
- Consumes: tâche 1.
- Produces: `SwiftDataSessionPhotoRepository: SessionPhotoRepository` (init `modelContainer:`) et `InMemorySessionPhotoRepository: SessionPhotoRepository` (init sans argument).

- [ ] **Step 1: Write the failing tests** :
  - `v6SchemaMatchesItsFingerprint` et `v6OnlyAddsSessionPhotos` : on regénère la fixture avec `PULSE_WRITE_SCHEMA_FIXTURES=1`. La différence V5 → V6 se limite aux lignes `StoredSessionPhoto.*`, et `imageData` et `thumbnailData` portent `externalStorage`. Les fixtures v1 à v5 restent inchangées.
  - `v5StoreOpensAsV6KeepingData` : sur le modèle de `v4StoreOpensAsV5KeepingData`.
  - `sessionPhotosRoundTripInOrder` : trois ajouts dans le désordre (`order` 2, 0, 1) sont relus triés, et `image(of:)` rend les octets d'origine.
  - `deletedPhotoKeepsNoImage` : après `delete(photoID:)`, la photo n'est plus lue. La ligne `StoredSessionPhoto` relue directement a `deletedAt` posé et `imageData == nil`, `thumbnailData == nil`.
  - `deletingASessionDeletesItsPhotos` : `SwiftDataWorkoutRepository.delete(id:)` d'une séance `.pulse` vide les photos de cette séance et laisse celles d'une autre.
  - `jsonExportListsPhotosWithoutImages` : le JSON contient `sessionPhotos` avec l'identifiant, et aucune chaîne base64 de plus de 1 000 caractères.
  - `csvArchiveContainsSessionPhotos` : le dossier CSV contient `photos/` avec un `.jpg` par photo vivante et une table `session_photos.csv` dont la colonne `file` correspond.
  - `csvArchiveCopiesPhotoBytesUnchanged` : chaque `.jpg` de l'archive a exactement les octets enregistrés. Seules des images passées par `PhotoProcessor` sont enregistrées, donc l'archive n'a pas de GPS (tâche 2).
  - `wipeAllRemovesSessionPhotos`.
- [ ] **Step 2: Run** `swift test --package-path Packages/PulsePersistence`. Expected: FAIL.
- [ ] **Step 3: Implement**. `add` insère une ligne. `photos(for:)` filtre `deletedAt == nil` et trie. `deleteAll(sessionID:)` appelle `markSessionPhotosDeleted` puis `save()`.
- [ ] **Step 4: Run** `swift test --package-path Packages/PulsePersistence`, puis `swift test --package-path Packages/PulseDomain` et `swift test --package-path Packages/PulseFeatures`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(persistence): schema V6 with synced session photos, export and cascade on session delete`.

### Task 5: Dépôt de fichiers des photos de corps

**Files:**
- Create: `Packages/PulsePersistence/Sources/PulsePersistence/Photos/FileBodyPhotoStore.swift`
- Modify: `Erase/SwiftDataEraser.swift` : nouveau paramètre `bodyPhotos: (any BodyPhotoStore)? = nil`, appelé (`deleteAll()`) juste après `StoreWiper`. Une erreur est gardée et relancée à la fin, comme `healthError`.
- Modify: `Packages/PulseFeatures/Sources/PulseServices/Doubles/InMemoryRepositories.swift` (`InMemoryBodyPhotoStore`)
- Test: `Packages/PulsePersistence/Tests/PulsePersistenceTests/FileBodyPhotoStoreTests.swift`, sur un dossier temporaire unique par test

**Interfaces:**
- Consumes: tâche 1, `ZipArchiver` (interne au module).
- Produces: `public actor FileBodyPhotoStore: BodyPhotoStore` avec `public init(directory: URL)`, et `InMemoryBodyPhotoStore: BodyPhotoStore`.
- **Disposition** : dans `directory`, on trouve `index.json` (`[BodyPhoto]`, dates en ISO 8601), `<id>.jpg` et `<id>-thumb.jpg`.
  - Chaque écriture utilise `[.atomic, .completeFileProtection]`.
  - Le dossier est créé avec `FileAttributeKey.protectionKey: FileProtectionType.complete`, puis il reçoit `URLResourceValues.isExcludedFromBackup = true` à chaque création.

- [ ] **Step 1: Write the failing tests** :
  - `savedPhotoIsReadBack` : `save` puis `photos()` et `image(of:)` donnent des valeurs égales ;
  - `saveWithSameIDReplaces` ;
  - `deleteRemovesFilesAndEntry` : après suppression, les deux fichiers sont absents et l'index n'a plus l'entrée ;
  - `deleteAllRemovesTheDirectory` ;
  - `directoryIsExcludedFromBackup` : `resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true` après le premier `save` ;
  - `missingFileDropsItsIndexEntry` : on supprime à la main `<id>.jpg`. `photos()` ne rend plus l'entrée, et `index.json` relu ne la contient plus ;
  - `unreadableIndexStartsEmpty` : avec `index.json` = `"x"`, `photos()` rend `[]` sans erreur, et un `save` suivant fonctionne ;
  - `exportArchiveNamesFilesByDayAndPose` : une face du 1er août et un dos du 28 octobre donnent un zip, dézippé avec `/usr/bin/ditto -x -k` dans le test, qui contient `2026-08-01-face.jpg` et `2026-10-28-dos.jpg` ;
  - `generalExportHasNoBodyPhoto` (test de frontière, spec §8) : avec un `FileBodyPhotoStore` rempli dans un dossier temporaire et un magasin en mémoire, ni le JSON ni le dossier CSV exportés ne contiennent un fichier ou une chaîne égale aux octets, au nom de fichier ou à l'identifiant d'une photo de corps.
  - `eraserDeletesBodyPhotos` : `SwiftDataEraser` avec un `InMemoryBodyPhotoStore` rempli laisse `photos()` vide.
- [ ] **Step 2: Run** `swift test --package-path Packages/PulsePersistence --filter "FileBodyPhotoStore|Erase"`. Expected: FAIL.
- [ ] **Step 3: Implement**.
  - Les noms d'export utilisent `face`, `profil` et `dos`, avec le jour dans `TimeZone.current`. Deux photos de même nom reçoivent le suffixe `-2`.
  - L'archive s'appelle `Pulse-photos-de-corps-AAAA-MM-JJ.zip`, à partir d'un dossier temporaire supprimé après le zip.
  - Ne lire aucune date de fichier : pas de raison `C617.1` à déclarer.
- [ ] **Step 4: Run** `swift test --package-path Packages/PulsePersistence`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(persistence): protected, backup-excluded file store for body photos`.

### Task 6: `SessionPhotoService` et photos d'une séance abandonnée

**Files:**
- Create: `Packages/PulseFeatures/Sources/PulseServices/Photos/SessionPhotoService.swift`
- Modify: `Packages/PulseFeatures/Sources/PulseServices/LiveSession/ActiveSessionService.swift`, avec un paramètre d'init `sessionPhotos: (any SessionPhotoRepository)? = nil`
- Modify: `LiveSession/ActiveSessionService+Finish.swift` : `abandon` appelle `sessionPhotos?.deleteAll(sessionID:)` quand rien n'est écrit (sans série validée, séance passée, ou instantané illisible).
- Test: `Packages/PulseFeatures/Tests/PulseServicesTests/SessionPhotoServiceTests.swift`, `ActiveSessionServiceTests` (le fichier existant de l'abandon)

**Interfaces:**
- Consumes: tâches 1 à 3.
- Produces:

```swift
public enum SessionPhotoError: Error, Equatable { case full, unreadable }
public actor SessionPhotoService {
    public init(repository: any SessionPhotoRepository, timeZone: TimeZone = .current, now: @escaping @Sendable () -> Date)
    public func photos(for sessionID: UUID) async throws -> [SessionPhoto]
    public func thumbnail(of photoID: UUID) async throws -> Data?
    public func image(of photoID: UUID) async throws -> Data?
    /// Traite l'image hors de l'acteur principal, puis l'ajoute en dernier (`order` = plus grand + 1).
    public func add(_ data: Data, to sessionID: UUID) async throws -> SessionPhoto
    public func delete(photoID: UUID) async throws
}
```

- [ ] **Step 1: Write the failing tests** :
  - `addedPhotosKeepTheirOrder` : trois ajouts donnent `order` 0, 1 et 2 ;
  - `serviceRefusesASeventhPhoto` : la septième lance `.full`, et le dépôt garde 6 photos ;
  - `unreadableDataThrowsUnreadable` ;
  - `deletedPhotoFreesASlot` ;
  - `abandonWithoutSetsDeletesSessionPhotos` : une séance démarrée, une photo ajoutée sous son identifiant, puis `abandon` sans série laissent le dépôt sans photo ;
  - `abandonWithSetsKeepsSessionPhotos`.
- [ ] **Step 2: Run** `swift test --package-path Packages/PulseFeatures --filter "SessionPhotoService|ActiveSession"`. Expected: FAIL.
- [ ] **Step 3: Implement**. `PhotoProcessingError.unreadable` devient `SessionPhotoError.unreadable`.
- [ ] **Step 4: Run** `swift test --package-path Packages/PulseFeatures`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(photos): session photo service, drop photos of a session abandoned without saving`.

### Task 7: Cible `PhotosFeature` et section Photos réutilisable

**Files:**
- Modify: `Packages/PulseFeatures/Package.swift`. Ajouter :
  - le produit et la cible `PhotosFeature` (dépendances `PulseServices`, `designSystem`, `domain` ; ressources `Resources`) ;
  - la cible de test `PhotosFeatureTests` ;
  - `PhotosFeature` aux dépendances de `LiveSessionFeature`, `RunFeature`, `TrainFeature`, `PlanningFeature` et `ProfileFeature`.
- Create: `Packages/PulseFeatures/Sources/PhotosFeature/SessionPhotosModel.swift`
- Create: `Packages/PulseFeatures/Sources/PhotosFeature/PhotoText.swift` (libellés affichés et parlés)
- Create: `Packages/PulseFeatures/Sources/PhotosFeature/CameraAccess.swift`. Il donne l'état de l'autorisation, via `AVCaptureDevice.authorizationStatus(for: .video)`, et la disponibilité de la caméra.
- Create: `Packages/PulseFeatures/Sources/PhotosFeature/Views/SessionPhotosSection.swift` (en-tête « Photos » et « privées · 6 au maximum », grille 3 colonnes, case « Ajouter »)
- Create: `Packages/PulseFeatures/Sources/PhotosFeature/Views/AddPhotoMenu.swift` (`Menu` : « Prendre une photo » si la caméra existe, « Choisir dans Photos » avec `PhotosPicker` et `maxSelectionCount` = places restantes)
- Create: `Packages/PulseFeatures/Sources/PhotosFeature/Views/CameraPicker.swift` (`UIImagePickerController`, `.camera`, sous `#if canImport(UIKit)`, rend les octets JPEG de l'image prise, n'enregistre rien dans Photos)
- Create: `Packages/PulseFeatures/Sources/PhotosFeature/Views/SessionPhotoViewer.swift` (plein écran, pages, `ShareLink` de l'image seule, « Supprimer » avec confirmation)
- Create: `Packages/PulseFeatures/Sources/PhotosFeature/Views/LiveCameraButton.swift` (icône appareil photo et badge du nombre de photos)
- Create: `Packages/PulseFeatures/Sources/PhotosFeature/Resources/Localizable.xcstrings`
- Test: `Packages/PulseFeatures/Tests/PhotosFeatureTests/SessionPhotosModelTests.swift` et `PhotoTextTests.swift`

**Interfaces:**
- Consumes: `SessionPhotoService` (tâche 6), `SessionPhotoRules` (tâche 3).
- Produces:

```swift
@MainActor @Observable public final class SessionPhotosModel {
    public init(service: SessionPhotoService, sessionID: UUID, calendar: Calendar)
    public private(set) var photos: [SessionPhoto]
    public private(set) var thumbnails: [UUID: Data]
    public private(set) var isAdding: Bool
    public private(set) var errorMessage: String?
    public var remainingSlots: Int { get }
    public var canAdd: Bool { get }
    public func load() async
    /// Garde les premières données dans la limite ; au-delà, `errorMessage` le dit.
    public func add(_ items: [Data]) async
    public func delete(_ photoID: UUID) async
    public func image(of photoID: UUID) async -> Data?
    public func spokenLabel(of photo: SessionPhoto) -> String
}
public struct SessionPhotosSection: View { public init(model: SessionPhotosModel) }
public struct LiveCameraButton: View { public init(model: SessionPhotosModel) }
public enum PhotoText {   // déclarations ; les textes exacts sont ci-dessous
    static func sessionPhotoLabel(index: Int, count: Int, addedAt: Date, calendar: Calendar) -> String
    static func bodyPhotoLabel(pose: BodyPose, day: Date, calendar: Calendar) -> String
    static func emptyPoseLabel(_ pose: BodyPose) -> String
    static func poseName(_ pose: BodyPose) -> String                       // « Face », « Profil », « Dos »
    static func weeksApart(from: Date, to: Date, calendar: Calendar) -> String
    static func lastShot(_ day: Date, now: Date, calendar: Calendar) -> String
}
```

- **Textes exacts** (fixés par la spec) :
  - « Photo 2 sur 4, ajoutée à 18 h 42 » ;
  - « Photo de face, 1er août 2026 », « Photo de profil… », « Photo de dos… » ;
  - « Ajouter une photo de profil » ;
  - « 13 semaines d'écart » ; sous 2 semaines, « 9 jours d'écart » ; « 1 semaine » au singulier ;
  - « Dernière prise aujourd'hui », « … hier », « … il y a 5 jours » (moins de 14 jours), « … il y a 4 semaines » ;
  - quand l'import dépasse la limite : « 6 photos au maximum par séance : 2 n'ont pas été ajoutées. »

- [ ] **Step 1: Write the failing tests** (doublures : `InMemorySessionPhotoRepository`, images fabriquées comme dans la tâche 2) :
  - `loadShowsPhotosAndThumbnails` ;
  - `multipleImportIsCappedToRemainingSlots` : avec 4 photos, un import de 4 en ajoute 2, et `errorMessage` vaut le texte ci-dessus avec « 2 » ;
  - `canAddIsFalseAtSix` ;
  - `deleteRemovesThePhotoAndAnnounces` : l'annonce vaut « Photo supprimée », et « Photo ajoutée » après un ajout ;
  - `spokenLabelsMatchTheSpec` : chaque texte exact ci-dessus, avec le pluriel et le singulier.
- [ ] **Step 2: Run** `swift test --package-path Packages/PulseFeatures --filter PhotosFeatureTests`. Expected: FAIL.
- [ ] **Step 3: Implement** le modèle, les textes et les vues.
  - L'ajout pendant la séance live ne bloque rien : `add` tourne dans une `Task`, et la vue montre une case « en cours ».
  - Avec la caméra refusée, le menu affiche « Autoriser l'appareil photo dans Réglages » (lien `UIApplication.openSettingsURLString`) à la place de « Prendre une photo », et l'import reste possible.
  - Chaque vignette est un bouton de 44 points ou plus, avec `spokenLabel`.
  - Les aperçus incluent `accessibility3`.
- [ ] **Step 4: Run** `swift test --package-path Packages/PulseFeatures`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(photos): reusable session photos section, viewer, camera and picker`.

### Task 8: Brancher la section Photos dans les écrans de séance

**Files:**
- Modify: `Packages/PulseFeatures/Sources/TrainFeature/TrainEnvironment.swift` (`sessionPhotos: SessionPhotoService? = nil`, dernier paramètre de l'init)
- Modify: `Packages/PulseFeatures/Sources/RunFeature/RunEnvironment.swift` (idem)
- Modify: `TrainFeature/History/SessionDetailModel.swift` et `SessionDetailView.swift`. Ajouter `public private(set) var photos: SessionPhotosModel?`, construit au `load()` si `SessionPhotoRules.acceptsPhotos(session)` et si le service existe. La section se place après la note.
- Modify: `PlanningFeature/ActivityDetailModel.swift` et `Views/ActivityDetailView.swift` : même règle, via `environment.train.sessionPhotos`. Une activité `.appleHealth` n'a pas de section.
- Modify: `RunFeature/RunRecapModel.swift` et `Views/RunRecapView.swift` : `photos` est construit pour `data.session.id`.
- Modify: `LiveSessionFeature/LiveSessionModel.swift` et `Views/LiveHeader.swift`. `photos: SessionPhotosModel?` est construit pour l'identifiant de la séance live (`session.id`), qui sera celui de la séance enregistrée. `LiveCameraButton` va dans l'en-tête.
- Modify: `LiveSessionFeature/Recap/RecapModel.swift` (ou `FinishFlowModel.swift`, là où vit l'identifiant) et `RecapView.swift` : la section se place après la note, avec le même modèle que la séance live s'il existe encore, sinon un nouveau.
- Test: `TrainFeatureTests`, `PlanningFeatureTests`, `RunFeatureTests`, `LiveSessionFeatureTests` (fichiers existants des modèles concernés)

**Interfaces:**
- Consumes: `SessionPhotosModel` et ses vues (tâche 7), `SessionPhotoRules` (tâche 3).
- Produces: `TrainEnvironment.sessionPhotos` et `RunEnvironment.sessionPhotos`, que l'app remplit dans la tâche 11.

- [ ] **Step 1: Write the failing tests** :
  - `sessionDetailOffersPhotosForPulseAndHevy` : `photos != nil` pour `.pulse` et `.hevy`, et `nil` sans service ;
  - `activityDetailHidesPhotosForAppleHealth` : `.appleHealth` donne `nil`, une course `.pulse` non nil ;
  - `runRecapPhotosUseTheRunSessionID` ;
  - `livePhotosUseTheLiveSessionID` : une photo ajoutée pendant la séance live se relit, après `finish`, avec le même `sessionID` que la `WorkoutSession` enregistrée.
- [ ] **Step 2: Run** `swift test --package-path Packages/PulseFeatures`. Expected: FAIL.
- [ ] **Step 3: Implement**. Les appels existants de `TrainEnvironment(…)` et `RunEnvironment(…)` dans les aperçus et les tests compilent sans changement grâce à la valeur par défaut.
- [ ] **Step 4: Run** `swift test --package-path Packages/PulseFeatures`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(photos): photos in the live session, recaps and past session details`.

---

## Lot 2 — Photos de corps

### Task 9: `BodyPhotoService`

**Files:**
- Create: `Packages/PulseFeatures/Sources/PulseServices/Photos/BodyPhotoService.swift`
- Create: `Packages/PulseFeatures/Sources/PulseServices/Photos/BodyPhotoLockStore.swift`. C'est le protocole `BodyPhotoLockStore`, avec `isLockEnabled: Bool` (vrai par défaut) et `setLockEnabled(_:)`. Il a deux implémentations : `UserDefaultsBodyPhotoLockStore(suiteName:)` (clé `pulse.bodyPhotos.lockEnabled`) et `InMemoryBodyPhotoLockStore`, sur le modèle de `RunPreferencesStore`.
- Test: `Packages/PulseFeatures/Tests/PulseServicesTests/BodyPhotoServiceTests.swift`

**Interfaces:**
- Consumes: tâches 1 à 3 et 5, `BodyMeasurementRepository`, `WeightTrend.make(measurements:now:calendar:)`.
- Produces:

```swift
public actor BodyPhotoService {
    public init(store: any BodyPhotoStore, measurements: any BodyMeasurementRepository, calendar: Calendar,
                timeZone: TimeZone = .current, now: @escaping @Sendable () -> Date)
    public func days() async throws -> [BodyPhotoDay]
    public func photos() async throws -> [BodyPhoto]
    public func thumbnail(of photoID: UUID) async throws -> Data?
    public func image(of photoID: UUID) async throws -> Data?
    /// Traite l'image ; `capturedAt` propose la date (aujourd'hui si nil, au choix de l'appelant).
    public func process(_ data: Data) async throws -> ProcessedPhoto
    public func existing(pose: BodyPose, on date: Date) async throws -> BodyPhoto?
    /// Enregistre ; une photo de même pose et même jour est supprimée d'abord (l'appelant a confirmé le remplacement).
    public func save(_ processed: ProcessedPhoto, pose: BodyPose, takenAt: Date) async throws -> BodyPhoto
    public func delete(photoID: UUID) async throws
    public func deleteAll() async throws
    public func exportArchive() async throws -> URL          // dans FileManager.default.temporaryDirectory/PulseBodyPhotoExport
    public func weightChange(from: Date, to: Date) async throws -> Double?   // pesées de toutes sources sur [from − 7 j, to + 1 j]
}
```

- [ ] **Step 1: Write the failing tests** (doublures `InMemoryBodyPhotoStore`, `InMemoryBodyMeasurementRepository` ou celle qui existe) :
  - `saveReplacesSamePoseSameDay` : deux faces le même jour laissent une seule photo, la seconde ;
  - `saveKeepsOtherPosesAndDays` ;
  - `existingFindsSamePoseSameDay` ;
  - `weightChangeReadsMeasurements` : −1,4 avec les pesées de la tâche 3 ;
  - `deleteAllEmptiesTheStore` ;
  - `lockIsEnabledByDefault` : `UserDefaultsBodyPhotoLockStore` sur une suite vierge donne vrai, puis faux après `setLockEnabled(false)`.
- [ ] **Step 2: Run** `swift test --package-path Packages/PulseFeatures --filter BodyPhotoService`. Expected: FAIL.
- [ ] **Step 3: Implement**.
- [ ] **Step 4: Run** `swift test --package-path Packages/PulseFeatures`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(photos): body photo service with replace rule, weight change and lock setting`.

### Task 10: Écrans des photos de corps (verrou, liste, ajout, comparaison, réglages)

**Files:**
- Create: `Packages/PulseFeatures/Sources/PhotosFeature/BodyPhotosModel.swift` (verrou, liste, ajout, réglages)
- Create: `Packages/PulseFeatures/Sources/PhotosFeature/BodyPhotoCompareModel.swift`
- Create: `Packages/PulseFeatures/Sources/PhotosFeature/Views/BodyPhotosScreen.swift`, `BodyPhotoAddSheet.swift` (pose, source, date modifiable, conseil, confirmation de remplacement), `BodyPhotoViewer.swift` (plein écran, « Supprimer » seul, sans partage, copie, menu contextuel ni glisser-déposer), `BodyPhotoCompareScreen.swift` (scène superposée et curseur, « Côte à côte », tuile poids), `PrivacyCover.swift` (cache plein écran en trame argentique)
- Modify: `Packages/PulseFeatures/Sources/ProfileFeature/ProfileEnvironment.swift` : ajouter `bodyPhotos: BodyPhotoService? = nil`, `ownerAuthentication: (any DeviceOwnerAuthenticating)? = nil` et `bodyPhotoLock: any BodyPhotoLockStore = InMemoryBodyPhotoLockStore()`.
- Modify: `ProfileFeature/Views/ProfileScreen.swift` (`ProfileDestination.bodyPhotos`) et `ProfileSections.swift` : une ligne « Photos de corps » avec l'icône `lock.fill`, juste après la ligne Poids, seulement si `bodyPhotos != nil`.
- Modify: `ProfileFeature/Views/MyDataScreen.swift` : sous les boutons d'export, la ligne « Les photos de séance sont dans l'export CSV. Les photos de corps n'y sont jamais : exporte-les depuis leur écran. »
- Test: `Packages/PulseFeatures/Tests/PhotosFeatureTests/BodyPhotosModelTests.swift` et `BodyPhotoCompareModelTests.swift`

**Interfaces:**
- Consumes: tâches 7 et 9, `DeviceOwnerAuthenticating` (tâche 1).
- Produces:

```swift
public enum BodyPhotosLockState: Equatable, Sendable { case locked, unlocked, unavailable }   // unavailable : pas de code
@MainActor @Observable public final class BodyPhotosModel {
    public init(service: BodyPhotoService, authentication: (any DeviceOwnerAuthenticating)?, lock: any BodyPhotoLockStore,
                calendar: Calendar, now: @escaping @Sendable () -> Date)
    public private(set) var lockState: BodyPhotosLockState
    public private(set) var isCovered: Bool            // vrai dès que la scène n'est plus active
    public private(set) var days: [BodyPhotoDay]
    public private(set) var hasPasscode: Bool
    public var isLockEnabled: Bool { get }
    public func appear() async                           // authentifie si le verrou est actif, puis charge
    public func unlock() async
    public func scenePhaseChanged(_ phase: ScenePhase)  // .inactive → couvert ; .background → couvert et verrouillé ; .active → découvert
    public func disappear()                              // reverrouille
    public func setLockEnabled(_ on: Bool) async         // couper demande une authentification réussie
    public func exportArchive() async -> URL?            // authentification d'abord, si le verrou est actif
    public func deleteAll() async
    public var headerLines: [String] { get }             // texte fixe, plus la ligne « sans code » si besoin, plus la dernière prise
}
@MainActor @Observable public final class BodyPhotoCompareModel {
    public init(service: BodyPhotoService, photos: [BodyPhoto], calendar: Calendar)
    public private(set) var poses: [BodyPose]            // BodyPhotoTimeline.comparablePoses
    public var pose: BodyPose
    public private(set) var before: BodyPhoto?
    public private(set) var after: BodyPhoto?
    public private(set) var weightChange: Double?
    public var position: Double                          // 0…1, 0,5 au départ
    public var isSideBySide: Bool                         // vrai d'office avec VoiceOver ou une taille d'accessibilité
    public func choose(before: BodyPhoto, after: BodyPhoto) async
    public var sliderSpokenLabel: String { get }         // « Avant, 1er août · Après, 28 octobre »
}
```

- **Textes exacts de l'en-tête** :
  - « Sur cet iPhone seulement. Ni iCloud, ni sauvegarde. Exporte-les avant de changer de téléphone. »
  - sans code : « Sans code sur cet iPhone, ces photos ne sont ni chiffrées ni verrouillables. »
- **Raison Face ID** : « Déverrouille tes photos de corps. »
- **Conseil d'ajout** : « Même lumière, même tenue, même distance. »
- **Tuile poids** : « Poids, tendance » suivi de la valeur signée (« −1,4 kg », par `PulseFormat`). La phrase reprend la maquette : « Les variations sont affichées sans jugement : c'est toi qui décides de ce qui compte. »

- [ ] **Step 1: Write the failing tests** (doublure `StubOwnerAuthentication`, avec `available` et `succeeds` réglables) :
  - `appearAuthenticatesWhenLocked` : un succès donne `.unlocked` puis charge `days` ; un échec reste `.locked` avec `days` vide ;
  - `lockDisabledSkipsAuthentication` ;
  - `noPasscodeIsUnavailableAndShowsTheExtraLine` : `.unavailable`, l'interrupteur est inactif, et `headerLines` contient la ligne sans code ;
  - `inactiveScenePhaseShowsCover` : `.inactive` donne `isCovered`, l'état reste `.unlocked`, puis `.active` découvre ;
  - `backgroundRelocks` : `.background` puis `.active` donnent `.locked`, avec une nouvelle authentification ;
  - `disablingTheLockNeedsAuthentication` : un échec laisse le verrou actif ;
  - `exportNeedsAuthentication` : un échec donne `nil` ;
  - `compareDefaultsToOldestAndNewest`, `compareListsOnlyComparablePoses`, `sliderLabelNamesBothDates` ;
  - `weightTileAbsentWithoutTrend`.
- [ ] **Step 2: Run** `swift test --package-path Packages/PulseFeatures --filter "BodyPhotosModel|BodyPhotoCompare"`. Expected: FAIL.
- [ ] **Step 3: Implement**.
  - L'écran observe `@Environment(\.scenePhase)` et appelle `scenePhaseChanged`. `PrivacyCover` est posé en `overlay` quand `isCovered` ou `lockState != .unlocked`, sauf `.unavailable`.
  - L'export passe par `fileExporter` (document zip), jamais par `ShareLink`.
  - « Supprimer toutes les photos de corps » et chaque suppression demandent une confirmation.
  - Le curseur est un élément ajustable (`accessibilityAdjustableAction`, pas de 10 %).
  - Les annonces disent « Photos de corps déverrouillées », « Photo ajoutée » et « Photo supprimée ».
- [ ] **Step 4: Run** `swift test --package-path Packages/PulseFeatures`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(photos): locked body photo screen, comparison and settings in Profile`.

### Task 11: Branchement dans l'app, Info.plist, vérification des clés, textes publics

**Files:**
- Create: `Pulse/Photos/LocalAuthenticationOwnerAuthenticator.swift`. C'est une implémentation de `DeviceOwnerAuthenticating` :
  - `isAvailable` vaut `LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)` ;
  - `authenticate` utilise `evaluatePolicy(.deviceOwnerAuthentication, localizedReason:)` avec un nouveau `LAContext` à chaque appel.
- Modify: `Pulse/AppDependencies.swift` :
  - `SwiftDataSessionPhotoRepository`, `SessionPhotoService` et `ActiveSessionService(…, sessionPhotos:)` ;
  - `FileBodyPhotoStore(directory: URL.applicationSupportDirectory.appending(path: "Pulse/BodyPhotos", directoryHint: .isDirectory))` et `BodyPhotoService` ;
  - `SwiftDataEraser(…, bodyPhotos:)` ;
  - les doublures dans `testing(...)`.
- Modify: `Pulse/AppDependencies+Environments.swift` (`sessionPhotos` dans `TrainEnvironment` et `RunEnvironment` ; `bodyPhotos`, `ownerAuthentication` et `bodyPhotoLock` dans `ProfileEnvironment`) et `Pulse/AppDependencies+Run.swift` si `RunEnvironment` y est construit.
- Modify: l'écran de confirmation de suppression totale (cible app, `ProfileAppScreens.eraseConfirmation`). Le texte mentionne « les photos de séance, iCloud compris, et les photos de corps de cet iPhone ».
- Modify: `Pulse.xcodeproj/project.pbxproj` : le produit `PhotosFeature` est lié à l'app, sur le modèle des cinq entrées de `RunFeature`.
- Modify: `Pulse/Info.plist`, avec les textes de la spec §6.3 :
  - `NSCameraUsageDescription` = « Pulse utilise l'appareil photo quand vous ajoutez une photo à une séance ou une photo de corps. Les photos prises ne sont pas enregistrées dans Photos. » ;
  - `NSFaceIDUsageDescription` = « Pulse utilise Face ID pour protéger vos photos de corps. » ;
  - `NSPhotoLibraryAddUsageDescription` = « Pulse enregistre dans Photos seulement l'image de séance que vous choisissez d'enregistrer. » ;
  - pas de `NSPhotoLibraryUsageDescription`, et `UIBackgroundModes` inchangé.
- Create: `scripts/check-info-plist.sh`. Avec `/usr/libexec/PlistBuddy`, il échoue (code 1, message en français) si l'une de ces clés manque ou est vide dans `Pulse/Info.plist` :
  - `NSCameraUsageDescription`, `NSFaceIDUsageDescription`, `NSPhotoLibraryAddUsageDescription` ;
  - `NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription`, `NSLocationWhenInUseUsageDescription`.

  Il échoue aussi si `UIBackgroundModes` contient `workout-processing`.
- Modify: `Makefile` : la cible `lint` lance `scripts/check-info-plist.sh` après `swiftlint lint --strict`.
- Modify: `docs/confidentialite/index.html` (spec §6.5, date de mise à jour), `docs/app-store/fiche.md` (description, notes de revue : appareil photo, Face ID, photos de corps locales, « Données non collectées » inchangé), `docs/app-store/verification-accessibilite.md` (les nouveaux écrans), `Pulse/PrivacyInfo.xcprivacy` (relire : aucune nouvelle raison attendue)

- [ ] **Step 1: Implement** le branchement, les clés, le script et les textes.
- [ ] **Step 2: Run** `scripts/check-info-plist.sh`. Expected: code 0. Puis, sur une copie temporaire de l'Info.plist sans `NSCameraUsageDescription` (le script prend le chemin en premier argument, `Pulse/Info.plist` par défaut). Expected: code 1.
- [ ] **Step 3: Run** `grep -c "workout-processing" Pulse/Info.plist`. Expected: `0`.
- [ ] **Step 4: Run** `make build-app`, puis `make build-release`. Expected: les deux sortent avec le code 0.
- [ ] **Step 5: Run** les six `swift test --package-path Packages/<Nom>` (`PulseDomain`, `PulseRecoveryEngine`, `PulseContent`, `PulsePersistence`, `PulseDesignSystem`, `PulseFeatures`), puis `make lint`. `PulseHealth` et `PulseLiveActivity` se vérifient par `make build-app`, comme en V2a. Expected: tout vert, lint 0.
- [ ] **Step 6: Commit** `feat(photos): wire photos into the app, camera, Face ID and photo library texts, privacy pages`.

---

## Après le plan (hors tâches)

- Revue finale de toute la branche.
- Push de `v2b-photos`, puis PR empilée sur `v2a-course-gps` (sur `master` si #22 est mergée), puis envoi sur TestFlight selon `testflight-upload`.
- Ce qui reste à Mathéo (spec §10) :
  - le déploiement du schéma CloudKit V6 en production, après V5 ;
  - les vérifications sur l'iPhone : photos live sans gêne, réinstallation, partage vers Photos, Face ID et cache, export Fichiers, image géolocalisée.
