# Pulse V2c — App Apple Watch : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** pendant une séance démarrée sur l'iPhone, la montre affiche l'exercice et la série en cours, le chrono de repos avec une vibration à la fin, et un bouton « Valider la série » réglable à la couronne. La FC mesurée par la montre est enregistrée avec la séance, dans un seul entraînement Santé. L'iPhone reste la seule source de vérité, et marche comme aujourd'hui sans montre.

**Architecture :** deux lots.
- **Lot 1, tout ce qui se vérifie sans montre :**
  - un nouveau package pur `PulseWatchLink` : messages, codec, couronne, textes, machine d'état de la montre ;
  - le branchement de la montre dans `ActiveSessionService`, au même titre que la Live Activity ;
  - la passation de l'écriture Santé entre la montre et l'iPhone ;
  - le pont WatchConnectivity de l'iPhone ;
  - la FC au récap et dans le détail ;
  - les Paramètres, et une montre simulée dans l'écran de debug.
- **Lot 2, la cible watchOS `PulseWatch` :**
  - le client WatchConnectivity et la séance HealthKit de la montre ;
  - les écrans, l'Info.plist, les entitlements et le manifeste ;
  - l'outillage (`make build-watch`, contrôles d'Info.plist et de versions) et les textes publics.

**Tech Stack :** Swift 6.2, SwiftUI (iOS 26 et watchOS 26), WatchConnectivity, HealthKit (`HKWorkoutSession` et `HKLiveWorkoutBuilder` sur la montre, `startWatchApp(toHandle:)` sur l'iPhone), WatchKit (haptiques, `WKApplicationDelegate`), ActivityKit (inchangé), Swift Testing.

**Spec :** `docs/superpowers/specs/2026-11-25-pulse-v2c-apple-watch-design.md`, à lire avant chaque tâche. Les chemins et signatures cités viennent d'une lecture du dépôt à d8200f8. **Les questions ouvertes de la spec (§11) doivent être tranchées par Mathéo avant la tâche 2.** Le plan suit les propositions de la spec ; une réponse différente change les tâches indiquées dans la section « Si Mathéo répond autrement ».

## Global Constraints

- **Branche** : `v2c-apple-watch`, créée depuis `origin/master` à jour.
  - Avant tout commit, `git branch --show-current` doit afficher `v2c-apple-watch`.
  - Lancer `git status --short`, puis ajouter les nouveaux fichiers **par nom**. Ne jamais ajouter `.agents/`, `.gemini/` ni `.superpowers/`.
  - Pas de trailer `Co-Authored-By`, aucune mention d'outil d'IA dans les commits ni dans la PR. Ne pas pousser sans accord.
- **Ne jamais lancer le simulateur** : pas de `xcodebuild test`, `make test`, `make test-app` ni `simctl`, que ce soit pour l'iPhone ou pour la montre.
  - Vérifier avec `swift test --package-path Packages/<Nom>`, `make lint`, `make build-app`, `make build-watch` (créée à la tâche 12) et `make build-release`. Avec Xcode 27, `-quiet` n'affiche aucune bannière : on juge au code de sortie 0.
  - `PulseHealth` et `PulseLiveActivity` ne compilent pas avec `swift test` sur macOS : ils se vérifient avec `make build-app`.
  - Le lint et les tests passent chacun dans une commande à part. On ne commite qu'après avoir lu leur résultat.
- **Une seule source de vérité** : toute commande de la montre passe par `ActiveSessionService`, dans sa file (`queue.run`). Aucune autre écriture du snapshot, aucune autre mise à jour de la Live Activity.
- **Frontière M8** : aucune valeur de HealthKit (FC, énergie) dans `ActiveSessionSnapshot`, dans `WorkoutSession` synchronisée, dans `SessionActivityState` ni dans `WatchSessionState`. Seule exception admise dans le snapshot : `watchWorkoutBeganAt`, une date.
- **`workout-processing`** : seulement dans `WKBackgroundModes` de `PulseWatch/Info.plist`. Jamais dans `UIBackgroundModes` de `Pulse/Info.plist` (refusé par App Store Connect, V2b §6.3).
- **Valeurs de la spec à reprendre telles quelles** :
  - couronne : charge au pas de `incrementKg` et jamais sous 0, répétitions au pas de 1 (de 1 à 100), durée au pas de 5 s (de 5 s à 600 s) ;
  - réponse attendue en 5 s, sinon « Non envoyé » ;
  - arrivée tardive : montre arrivée plus de 5 min après le début, donc l'iPhone écrit ;
  - la montre n'écrit plus 30 min après l'heure de fin ; rattrapage de l'iPhone après 1 h ;
  - oubli : 3 h sans action (`ActiveSessionService.forgottenAfter`) ;
  - version de message : 1.
- **Textes** : en français. Dans les packages, `String(localized:…, bundle: .module)` ; dans les cibles, `String(localized:)`. L'app tutoie, les textes d'autorisation vouvoient. Les commentaires sont en français, avec la densité du code voisin.
- **Accessibilité** : libellés parlés produits par des fonctions testées (`WatchSessionText`), valeurs ajustables, annonces, aperçus à la plus grande taille de texte, Réduire les animations (spec §7).
- **Non-objectifs** (spec §2) : pas de séance autonome sur la montre, pas de fin de séance depuis la montre, pas de miroir HealthKit, pas de FC sur l'écran de l'iPhone, pas de complication.

## Écarts assumés avec la spec (lus dans le code)

1. **Port de la montre dans `PulseServices`, pas dans `PulseDomain`.** `SessionActivityControlling` vit dans `PulseDomain`, mais l'état de la montre est un type de `PulseWatchLink`, et `PulseDomain` ne dépend de rien. Le port `SessionWatchPublishing` vit donc dans `PulseServices`, qui dépend de `PulseWatchLink`. `PulseDomain` ne change pas de plateformes.
2. **Passations dans `UserDefaults`**, comme `UserDefaultsRunPreferencesStore` (V2a, écart 5), pour éviter une version de schéma `PulseSchemaV8`. Attention : `PulseSchemaV7` lit encore la liste courante des modèles. Si un modèle devait changer plus tard, il faudrait d'abord figer V7.
3. **`watchWorkoutBeganAt` sans changement de `formatVersion`** : le décodage synthétisé d'un optionnel tolère son absence. La tâche 5 le prouve par un test sur un snapshot de l'ancienne forme.
4. **Pas de package `PulseHealth` pour la montre.** L'adaptateur `HKWorkoutSession` de la montre vit dans la cible `PulseWatch`, derrière un protocole de `PulseWatchLink`. `PulseHealth` reste iOS seulement.

## Si Mathéo répond autrement (spec §11)

- **Q2, pas de testeur** : faire le lot 1, puis remplacer le lot 2 par le plan B (action « Valider la série » sur la notification de fin de repos), dans un plan à part.
- **Q3, terminer depuis la montre** : ajouter `WatchCommand.finish` et un récap minimal sur la montre (RPE à la couronne). Tâches 2, 6 et 14, plus une tâche de récap.
- **Q4, pas d'ouverture automatique** : la tâche 9 n'appelle `startWatchApp` que si l'interrupteur est actif, avec un défaut à faux. La tâche 11 change le défaut.
- **Q5, l'iPhone écrit toujours** : supprimer les tâches 7 et 8 (sauf la FC du détail), et la montre jette toujours son entraînement (tâche 13).

## Review Focus

1. **Validation simultanée** : montre et Live Activity valident la même série à quelques millisecondes d'écart. Une seule série est cochée, un seul repos part. → tests `watchAndActivityValidatingTheSameSetCheckItOnce`, `staleWatchValidationChecksNothing` (tâche 6).
2. **Commande de repos en retard** : un « Passer » visant le repos A arrive après le début du repos B. Le repos B continue. → test `skipAimedAtAnOlderRestKeepsTheCurrentOne` (tâche 6).
3. **Un seul entraînement Santé** dans chaque cas : montre présente du début à la fin, arrivée tardive, compte rendu « jeté », compte rendu perdu puis rattrapage, compte rendu « écrit » arrivé après une écriture de l'iPhone. → tests de la tâche 8.
4. **Aucune FC hors de Santé** : après une séance avec compte rendu de FC, le snapshot, la `WorkoutSession` relue et les états publiés ne contiennent aucune FC. → test `heartRateNeverReachesSnapshotOrSyncedSession` (tâche 8).
5. **Sans montre** : sans montre jumelée, aucun appel à WatchConnectivity ni à `startWatchApp`, et le comportement de la séance est identique à d8200f8. Les tests existants d'`ActiveSessionService` passent sans modification de leurs attentes. → tâche 5, étape 4.

---

## Lot 1 — Ce qui se vérifie sans montre

### Task 1: Vérifications préalables (documentation)

Cette tâche n'écrit pas de code de l'app. Elle lève les inconnues de la spec (§12) avant d'en dépendre.

**Files:**
- Modify: `docs/superpowers/specs/2026-11-25-pulse-v2c-apple-watch-design.md` (nouvelle sous-section « Vérifications » au §12, avec sources)

- [ ] **Step 1: Lire la documentation Apple** et noter, avec le lien de chaque source :
  - une app iOS peut-elle supprimer (`HKHealthStore.delete`, `deleteObjects(of:predicate:)`) un `HKWorkout` écrit par son app watchOS compagnon ? Quelle `HKSource` porte cet entraînement sur l'iPhone ?
  - `HKHealthStore.startWatchApp(toHandle:completion:)` : entitlement ou clé d'Info.plist requis côté iPhone, et conditions (app installée, montre à portée) ;
  - `HKWorkoutBuilder.discardWorkout()` : les échantillons de FC collectés restent-ils dans Santé ?
  - `WCSession` entre simulateurs jumelés, et `isReachable` côté iPhone quand l'app montre tourne une séance d'entraînement en arrière-plan ;
  - les clés exactes de l'Info.plist d'une app watchOS 26 en une seule cible (`WKApplication`, `WKCompanionAppBundleIdentifier`, `WKRunsIndependentlyOfCompanionApp`, `WKBackgroundModes`).
- [ ] **Step 2: Décider** en appliquant les règles du §12 de la spec :
  - si la suppression depuis l'iPhone est impossible, on retient la variante « suppression envoyée à la montre ». Il faut alors ajouter `WatchMessage.deleteWorkout(UUID)` à la tâche 2, et sa gestion aux tâches 9 et 13 ;
  - si un entitlement manque, l'ajouter à la tâche 9.
- [ ] **Step 3: Commit** `docs(spec): V2c, findings on HealthKit deletion, startWatchApp and WatchConnectivity`.

### Task 2: Package `PulseWatchLink`, messages et codec

**Files:**
- Create: `Packages/PulseWatchLink/Package.swift` (`platforms: [.iOS(.v26), .watchOS(.v26), .macOS(.v15)]`, Swift 6, une bibliothèque `PulseWatchLink`, une cible de tests, ressources `Localizable.xcstrings`)
- Create: `Packages/PulseWatchLink/Sources/PulseWatchLink/WatchMessages.swift`
- Create: `Packages/PulseWatchLink/Sources/PulseWatchLink/WatchCodec.swift`
- Test: `Packages/PulseWatchLink/Tests/PulseWatchLinkTests/WatchCodecTests.swift`
- Modify: `Makefile` (`test-packages` += `swift test --package-path Packages/PulseWatchLink`)

**Interfaces:**
- Produces (tout est `public`, `Sendable`, `Equatable`, `Codable`) :

```swift
public enum WatchSetKind { case warmup, working, drop, failure }          // miroir de SetType
public enum WatchLoadKind { case external, bodyweight, assisted }          // miroir de LoadKind
public struct WatchSet { var setID: UUID; var exerciseName: String; var number: Int; var count: Int
    var kind: WatchSetKind; var load: WatchLoadKind; var tracksDuration: Bool
    var weightKg: Double?; var reps: Int?; var durationSeconds: Int?   // valeurs effectives : modifiées, sinon proposées
    var isEdited: Bool; var incrementKg: Double
    var lastWeightKg: Double?; var lastReps: Int?; var lastDurationSeconds: Int? } // dernière série validée de l'exercice
public struct WatchRest { var startedAt: Date; var endsAt: Date; var nextSet: String? }
public enum WatchSessionEnding { case finished(endedAt: Date), abandoned }
public struct WatchSessionState { var sessionID: UUID; var revision: Date; var title: String; var startedAt: Date
    var lastActionAt: Date; var current: WatchSet?   /* nil : toutes les séries faites */
    var rest: WatchRest?; var doneSets: Int; var plannedSets: Int; var ending: WatchSessionEnding? }
public enum WatchCommand {
    case validate(setID: UUID, weightKg: Double?, reps: Int?, durationSeconds: Int?)
    case restMinus30(restStartedAt: Date), restPlus30(restStartedAt: Date), skipRest(restStartedAt: Date) }
public enum WatchWorkoutStatus { case none, running(beganAt: Date) }
public struct WatchWorkoutReport { var sessionID: UUID; var outcome: Outcome
    var averageHeartRate: Double?; var maxHeartRate: Double?
    public enum Outcome { case saved(workoutID: UUID), discarded } }
public enum WatchMessage {
    case state(WatchSessionState?)                         // iPhone → montre ; nil : aucune séance
    case requestState(workout: WatchWorkoutStatus)          // montre → iPhone
    case command(WatchCommand, workout: WatchWorkoutStatus) // montre → iPhone, réponse : .state
    case workoutReport(WatchWorkoutReport) }                // montre → iPhone, par transferUserInfo

public enum WatchCodec {
    public static let version = 1
    public static let key = "pulse"                         // le dictionnaire WatchConnectivity : [key: Data]
    public enum Decoded: Equatable { case message(WatchMessage), unsupportedVersion(Int), unreadable }
    public static func encode(_ message: WatchMessage) throws -> Data   // JSON de { version, message }
    public static func decode(_ data: Data?) -> Decoded
}
```

- [ ] **Step 1: Write the failing test** `WatchCodecTests` :
  - `everyMessageRoundTrips` : un exemple de chaque cas de `WatchMessage` (état complet, état `nil`, chaque commande, chaque issue du compte rendu) ;
  - `unknownVersionIsReported` : une enveloppe `version: 2` donne `.unsupportedVersion(2)` ;
  - `garbageIsUnreadable` : `nil`, des octets vides ou un JSON d'une autre forme donnent `.unreadable` ;
  - `datesSurviveToTheMillisecond` : `revision` et `endsAt` relus à la milliseconde près (stratégie de dates explicite) ;
  - `stateStaysSmall` : un état réaliste (nom d'exercice de 60 caractères) encodé fait moins de 2 Ko.
- [ ] **Step 2: Run** `swift test --package-path Packages/PulseWatchLink`. Expected: FAIL (types absents).
- [ ] **Step 3: Implement**.
- [ ] **Step 4: Run** `swift test --package-path Packages/PulseWatchLink`, puis `make lint`. Expected: PASS, lint 0.
- [ ] **Step 5: Commit** `feat(watch): PulseWatchLink package with versioned messages between iPhone and Watch`.

### Task 3: Couronne et textes de la montre

**Files:**
- Create: `Packages/PulseWatchLink/Sources/PulseWatchLink/WatchCrownStepper.swift`
- Create: `Packages/PulseWatchLink/Sources/PulseWatchLink/WatchSessionText.swift`
- Create: `Packages/PulseWatchLink/Sources/PulseWatchLink/Resources/Localizable.xcstrings`
- Test: `Packages/PulseWatchLink/Tests/PulseWatchLinkTests/WatchCrownStepperTests.swift`, `WatchSessionTextTests.swift`

**Interfaces:**
- Consumes: tâche 2.
- Produces :

```swift
public enum WatchValueField: Sendable, Equatable { case weight, reps, duration }
public enum WatchCrownStepper {
    /// La valeur après `steps` crans (négatif vers le bas), bornée (spec §4.3).
    public static func step(_ field: WatchValueField, from value: Double?, steps: Int, in set: WatchSet) -> Double
    /// Le point de départ d'une valeur manquante : dernière série validée, sinon 0 (charge) ou le minimum (reps, durée).
    public static func start(_ field: WatchValueField, in set: WatchSet) -> Double
    /// Vrai quand la série a toutes ses valeurs (même règle que `LiveSet.hasValuesToValidate`).
    public static func canValidate(weightKg: Double?, reps: Int?, durationSeconds: Int?, in set: WatchSet) -> Bool
}
public enum WatchSessionText {
    public static func setTitle(_ set: WatchSet) -> String          // « Série 2 sur 4 », « Échauffement · série 1 sur 2 »
    public static func values(_ set: WatchSet, weightKg: Double?, reps: Int?, durationSeconds: Int?) -> String // « 70 kg × 5 », « +10 kg × 8 », « −20 kg × 6 », « 45 s »
    public static func spokenSet(_ set: WatchSet, weightKg: Double?, reps: Int?, durationSeconds: Int?) -> String
        // « Développé couché, série 2 sur 4, 70 kilos, 5 répétitions »
    public static func spokenValidate(_ set: WatchSet) -> String     // « Valider la série 2 »
    public static func spokenRest(remaining: TimeInterval) -> String // « Repos, 1 minute 42 restantes »
    public static func restEndedAnnouncement(nextSet: String?) -> String // « Repos terminé. Développé couché, série 3 »
    public static let unreachable: String                            // « iPhone injoignable »
    public static let notSent: String                                // « Non envoyé »
    public static let noSession: String                              // « Aucune séance en cours »
    public static let allSetsDone: String                            // « Toutes les séries sont faites »
    public static let finishOnPhone: String                          // « Termine la séance sur l'iPhone »
    public static let updateBothApps: String                         // « Mets Pulse à jour sur tes deux appareils »
}
```

- [ ] **Step 1: Write the failing tests** :
  - `WatchCrownStepperTests` :
    - `weightStepsByTheExerciseIncrement` : 2,5 kg puis 1,25 kg ;
    - `weightNeverGoesBelowZero` ;
    - `repsStayBetweenOneAndAHundred` ;
    - `durationStepsByFiveSecondsUpToTenMinutes` ;
    - `missingValueStartsFromTheLastValidatedSet`, puis de 0 sans historique ;
    - `externalLoadWithoutWeightCannotValidate` ;
    - `bodyweightWithoutAddedWeightCanValidate` (le lest est facultatif, comme dans l'app) ;
  - `WatchSessionTextTests` :
    - les exemples ci-dessus ;
    - les pluriels (« 1 répétition », « 1 minute ») ;
    - virgule décimale (« 72,5 kg ») ;
    - lest et assistance ;
    - durée.
- [ ] **Step 2: Run** `swift test --package-path Packages/PulseWatchLink --filter "WatchCrownStepperTests|WatchSessionTextTests"`. Expected: FAIL.
- [ ] **Step 3: Implement**. Les nombres passent par un `FormatStyle` français fixe (`Locale(identifier: "fr_FR")`) dans les tests, et par la locale courante dans l'app, comme `PulseFormat`.
- [ ] **Step 4: Run** `swift test --package-path Packages/PulseWatchLink`, puis `make lint`. Expected: PASS, lint 0.
- [ ] **Step 5: Commit** `feat(watch): crown steps and spoken labels for the Watch set screen`.

### Task 4: Machine d'état de la montre (`WatchSessionModel`)

**Files:**
- Create: `Packages/PulseWatchLink/Sources/PulseWatchLink/WatchSessionModel.swift`
- Create: `Packages/PulseWatchLink/Sources/PulseWatchLink/WatchPorts.swift` (protocoles des adaptateurs de la montre et doublures)
- Test: `Packages/PulseWatchLink/Tests/PulseWatchLinkTests/WatchSessionModelTests.swift`

**Interfaces:**
- Consumes: tâches 2 et 3.
- Produces :

```swift
public protocol WatchPhoneLink: Sendable {                       // implémenté par la cible PulseWatch (tâche 13)
    var isReachable: Bool { get async }
    /// Envoie et attend la réponse ; lève après `timeout`.
    func send(_ message: WatchMessage, timeout: Duration) async throws -> WatchMessage
    func transfer(_ report: WatchWorkoutReport) async               // file garantie (transferUserInfo)
}
public protocol WatchWorkoutRunning: Sendable {                   // implémenté par la cible PulseWatch (tâche 13)
    func authorization() async -> WatchHealthAuthorization          // .notDetermined, .authorized, .denied
    func requestAuthorization() async -> WatchHealthAuthorization
    func begin(at date: Date) async throws
    var status: WatchWorkoutStatus { get async }
    func heartRates() async -> AsyncStream<Double>
    /// Termine et écrit avec la métadonnée HKMetadataKeyExternalUUID ; rend l'identifiant et le résumé FC.
    func finish(sessionID: UUID, endedAt: Date) async throws -> (workoutID: UUID, average: Double?, max: Double?)
    func discard() async
    func recover() async -> Bool
}
public protocol WatchHaptics: Sendable { func restEnded() async; func validated() async }
public protocol WatchAnnouncing: Sendable { func announce(_ text: String) async }

public enum WatchScreen: Equatable { case idle, healthPermission, set, rest, allDone, ended }
@MainActor @Observable
public final class WatchSessionModel {
    public init(link: any WatchPhoneLink, workout: any WatchWorkoutRunning, haptics: any WatchHaptics,
                announcer: any WatchAnnouncing, now: @escaping @Sendable () -> Date,
                sleep: @escaping @Sendable (Duration) async throws -> Void)
    public private(set) var state: WatchSessionState?
    public private(set) var screen: WatchScreen
    public private(set) var isReachable: Bool
    public private(set) var isSending: Bool
    public private(set) var lastError: String?                     // « Non envoyé », « Mets Pulse à jour… »
    public private(set) var heartRate: Double?
    public var editedWeightKg: Double?; public var editedReps: Int?; public var editedDurationSeconds: Int?
    public var focusedField: WatchValueField?
    public var canSendCommands: Bool { get }                      // joignable, pas d'envoi en cours, séance en cours
    public func receive(_ decoded: WatchCodec.Decoded) async      // contexte d'application ou message de l'iPhone
    public func reachabilityChanged(_ reachable: Bool) async      // au retour : requestState
    public func launched() async                                  // ouverture, configuration d'entraînement ou reprise
    public func validate() async
    public func restMinus30() async; public func restPlus30() async; public func skipRest() async
    public func crown(steps: Int) async                            // sur le champ sélectionné
}
```

**Règles à couvrir** (spec §4 et §5) :
- Un état d'une autre séance remplace l'actuel. Pour la même séance, un état d'une `revision` plus ancienne est ignoré.
- Un nouvel état efface les valeurs modifiées si la série affichée change.
- La fin du repos est programmée sur `rest.endsAt` avec `sleep`, puis vibration, annonce et écran `set`. Elle est annulée si le repos change.
- Une commande sans réponse en 5 s donne `lastError = notSent`, avec l'état gardé. Hors de portée, aucune commande ne part.
- `ending` reçu :
  - `.finished(endedAt)` : `workout.finish` si la séance HealthKit a commencé au plus 5 min après `startedAt` et si l'heure actuelle tombe au plus 30 min après `endedAt` ; sinon `discard` ;
  - `.abandoned` : `discard` ;
  - puis le compte rendu par `link.transfer`, et l'écran `ended`, puis `idle`.
- Oubli : à 3 h après `lastActionAt` sans nouvel état, `discard`, puis compte rendu « jeté ».
- Santé refusée : pas de `begin`, la montre fonctionne sans FC.

- [ ] **Step 1: Write the failing test** `WatchSessionModelTests`, avec des doublures (`StubWatchPhoneLink`, `StubWatchWorkout`, `StubWatchHaptics`, `StubWatchAnnouncer`), une horloge réglable et un `sleep` contrôlé :
  - `olderRevisionIsIgnored` ;
  - `otherSessionReplacesTheState` ;
  - `restEndVibratesAndAnnouncesAtEndsAt` ;
  - `changedRestReschedulesTheVibration` ;
  - `validateSendsTheEditedValuesAndShowsTheReply` ;
  - `noReplyWithinFiveSecondsShowsNotSent` ;
  - `unreachableDisablesCommandsAndSendsNothing` ;
  - `reachableAgainRequestsTheState` ;
  - `finishedSessionSavesTheWorkoutAndReportsIt` ;
  - `lateJoinDiscardsTheWorkout` (début HealthKit à `startedAt` + 6 min) ;
  - `endingReceivedTooLateDiscards` (31 min après `endedAt`) ;
  - `abandonedSessionDiscards` ;
  - `forgottenSessionDiscardsAfterThreeHours` ;
  - `deniedHealthStillShowsTheSession` ;
  - `unsupportedVersionAsksToUpdate`.
- [ ] **Step 2: Run** `swift test --package-path Packages/PulseWatchLink --filter WatchSessionModelTests`. Expected: FAIL.
- [ ] **Step 3: Implement**.
- [ ] **Step 4: Run** `swift test --package-path Packages/PulseWatchLink`, puis `make lint`. Expected: PASS, lint 0.
- [ ] **Step 5: Commit** `feat(watch): Watch session state machine with rest haptics, reachability and workout ending rules`.

### Task 5: La montre dans `ActiveSessionService` (publication)

**Files:**
- Modify: `Packages/PulseFeatures/Package.swift` (dépendance locale `PulseWatchLink` pour `PulseServices`)
- Create: `Packages/PulseFeatures/Sources/PulseServices/LiveSession/SessionWatchPublishing.swift` (port et `StubSessionWatchPublisher`)
- Create: `Packages/PulseFeatures/Sources/PulseServices/LiveSession/ActiveSessionService+Watch.swift`
- Modify: `Packages/PulseFeatures/Sources/PulseServices/LiveSession/ActiveSessionService.swift` (init : `watch: any SessionWatchPublishing = NoWatch()`, appel au démarrage)
- Modify: `Packages/PulseFeatures/Sources/PulseServices/LiveSession/ActiveSessionService+Rest.swift` (`publish(from:to:)` publie aussi vers la montre)
- Modify: `Packages/PulseFeatures/Sources/PulseServices/LiveSession/ActiveSessionService+Finish.swift` (fin et abandon envoient `ending`, ménage après effacement)
- Modify: `Packages/PulseFeatures/Sources/PulseServices/LiveSession/LiveSession.swift` (`public var watchWorkoutBeganAt: Date?`)
- Test: `Packages/PulseFeatures/Tests/PulseServicesTests/ActiveSessionWatchTests.swift`, `LiveSessionCodingTests.swift` (ajout)

**Interfaces:**
- Consumes: tâche 2, `LiveSession`, `publish(from:to:)`, `activityState(for:)`.
- Produces :

```swift
public protocol SessionWatchPublishing: Sendable {
    /// Début d'une séance en direct : ouvre l'app montre si le réglage le permet, puis publie l'état.
    func start(_ state: WatchSessionState) async
    func update(_ state: WatchSessionState) async
    /// Plus de séance (fin, abandon, snapshot illisible, effacement) : publie `.state(nil)` après l'état final.
    func end(_ finalState: WatchSessionState?) async
}
public struct NoWatch: SessionWatchPublishing { … }               // défaut : ne fait rien

extension ActiveSessionService {
    /// L'état de la montre (spec §5.2) ; `revision` est la date de l'enregistrement qui le produit.
    static func watchState(for session: LiveSession, revision: Date, ending: WatchSessionEnding? = nil) -> WatchSessionState
    /// L'état courant pour une demande de la montre ; `nil` sans séance en direct.
    public func watchState() async -> WatchSessionState?
}
```

- [ ] **Step 1: Write the failing tests** `ActiveSessionWatchTests`, sur le modèle d'`ActiveSessionServiceTests` et `ActiveSessionRestTests` :
  - `startPublishesToTheWatch` ;
  - `pastEntryNeverReachesTheWatch` ;
  - `eachValidationPublishesANewerRevision` ;
  - `watchStateCarriesTheNextSetAndItsLastValues` ;
  - `restControlsPublishTheNewRest` ;
  - `finishSendsTheFinishedEndingThenNoSession` ;
  - `abandonSendsTheAbandonedEnding` ;
  - `unreadableSnapshotEndsTheWatchToo` ;
  - `watchStateHasNoHealthValue` (vérifie par réflexion `Mirror` qu'aucun champ ne porte de FC).

  Dans `LiveSessionCodingTests` : `snapshotWithoutWatchFieldStillDecodes`, sur un JSON figé de la forme actuelle.
- [ ] **Step 2: Run** `swift test --package-path Packages/PulseFeatures --filter "ActiveSessionWatchTests|LiveSessionCodingTests"`. Expected: FAIL.
- [ ] **Step 3: Implement**. `publish(from:to:)` compare `watchState` sans `revision` pour ne publier que les vrais changements, comme pour la Live Activity.
- [ ] **Step 4: Run** `swift test --package-path Packages/PulseFeatures`. Expected: PASS. **Les tests existants passent sans modifier leurs attentes** (Review Focus 5). Puis `make lint`.
- [ ] **Step 5: Commit** `feat(watch): publish the live session to the Watch from the single session service`.

### Task 6: Commandes de la montre

**Files:**
- Modify: `Packages/PulseFeatures/Sources/PulseServices/LiveSession/ActiveSessionService+Watch.swift`
- Test: `Packages/PulseFeatures/Tests/PulseServicesTests/ActiveSessionWatchCommandTests.swift`

**Interfaces:**
- Consumes: tâche 5, `apply(_:to:)`, `validateFromActivity(set:)`.
- Produces :

```swift
extension ActiveSessionService {
    /// Applique la commande dans la file, retient le statut HealthKit de la montre (`watchWorkoutBeganAt`), et rend l'état à
    /// jour (`nil` sans séance en direct). Une commande périmée ne change rien et rend l'état courant.
    public func applyFromWatch(_ command: WatchCommand, workout: WatchWorkoutStatus) async -> WatchSessionState?
    /// Demande d'état : retient le statut HealthKit et rend l'état courant.
    public func watchRequestedState(workout: WatchWorkoutStatus) async -> WatchSessionState?
}
```

**Règles** (spec §5.1) :
- `validate(setID:…)` ne fait quelque chose que si `setID` est la série de `nextSet(after: lastCheckedSet)`.
  - Valeurs bornées : charge ≥ 0 ; répétitions de 1 à 100 ; durée de 5 à 600 s.
  - Si elles diffèrent des valeurs effectives de la série : `.edit(…)` puis `.validate(…)` dans **une** opération de la file, avec un seul `save` et un seul `publish`.
- `restMinus30`, `restPlus30` et `skipRest` ne font quelque chose que si `session.rest?.startedAt == restStartedAt`.
- `workout: .running(beganAt)` pose `watchWorkoutBeganAt` s'il est vide. `.none` ne l'efface pas : une montre qui redémarre sans reprise ne réécrit pas l'histoire, et la règle des 5 min tranche à la fin.

- [ ] **Step 1: Write the failing tests** :
  - `watchValidatesTheNextSetWithItsValues` ;
  - `editedValuesAreSavedThenValidatedOnce` (un seul snapshot écrit, un seul état publié) ;
  - `staleWatchValidationChecksNothing` ;
  - `watchAndActivityValidatingTheSameSetCheckItOnce` (deux `Task` concurrentes, `validateFromActivity` et `applyFromWatch`) ;
  - `outOfRangeValuesAreClamped` ;
  - `missingWeightForExternalLoadIsRefused` ;
  - `skipAimedAtAnOlderRestKeepsTheCurrentOne` ;
  - `plus30OnAFinishedRestDoesNothing` ;
  - `runningWorkoutIsRememberedInTheSnapshot` ;
  - `workoutStatusNoneKeepsTheRememberedDate` ;
  - `commandWithoutSessionReturnsNil`.
- [ ] **Step 2: Run** `swift test --package-path Packages/PulseFeatures --filter ActiveSessionWatchCommandTests`. Expected: FAIL.
- [ ] **Step 3: Implement**.
- [ ] **Step 4: Run** `swift test --package-path Packages/PulseFeatures`, puis `make lint`. Expected: PASS, lint 0.
- [ ] **Step 5: Commit** `feat(watch): apply Watch validations and rest controls through the session queue, stale commands do nothing`.

### Task 7: Santé, recherche, FC et suppression des deux sources

**Files:**
- Modify: `Packages/PulseDomain/Sources/PulseDomain/Health/WorkoutHealthWriting.swift` (trois méthodes et `StubWorkoutHealthWriter`)
- Modify: `Packages/PulseHealth/Sources/PulseHealth/HealthKitWorkoutWriter.swift`
- Test: `Packages/PulseDomain/Tests/PulseDomainTests/StubWorkoutHealthWriterTests.swift` (ou le fichier de test voisin existant)

**Interfaces:**
- Produces :

```swift
public struct WorkoutHeartRateSummary: Sendable, Equatable { public var average: Double?; public var max: Double? }
extension WorkoutHealthWriting {
    /// L'entraînement écrit par Pulse (iPhone ou montre) avec HKMetadataKeyExternalUUID == sessionID, s'il existe.
    func workoutID(forSession sessionID: UUID) async -> UUID?
    /// FC moyenne et maximale des échantillons associés à l'entraînement ; nil sans entraînement ou sans lecture permise.
    func heartRateSummary(workoutID: UUID) async -> WorkoutHeartRateSummary?
}
// deleteWorkout(id:) et deleteAllSamplesWrittenByPulse() couvrent l'app iPhone ET l'app montre :
// sources trouvées par HKSourceQuery dont bundleIdentifier commence par celui de l'app (tâche 1 confirme).
```

- [ ] **Step 1: Write the failing test** de la doublure : `stubFindsAWorkoutBySessionID`, `stubReturnsTheConfiguredHeartRate`, `stubDeletesWatchWrittenWorkouts`.
- [ ] **Step 2: Run** `swift test --package-path Packages/PulseDomain`. Expected: FAIL.
- [ ] **Step 3: Implement** la doublure, puis `HealthKitWorkoutWriter` :
  - `HKSampleQueryDescriptor` avec `predicateForObjects(withMetadataKey:allowedValues:)` ;
  - `HKStatisticsQueryDescriptor` avec `.discreteAverage` et `.discreteMax` sur `predicateForObjects(from: workout)` ;
  - prédicat des sources Pulse.

  La variante retenue à la tâche 1 s'applique : sans suppression possible depuis l'iPhone, `deleteWorkout` renvoie une erreur dédiée et la tâche 9 transmet la suppression à la montre.
- [ ] **Step 4: Run** `swift test --package-path Packages/PulseDomain`, `make build-app`, puis `make lint`. Expected: PASS, build 0, lint 0.
- [ ] **Step 5: Commit** `feat(health): find a session's workout, read its heart rate, delete what the Watch app wrote`.

### Task 8: Passation de l'écriture Santé (`WatchHealthHandoff`)

**Files:**
- Create: `Packages/PulseFeatures/Sources/PulseServices/Health/WatchHealthHandoff.swift`
- Create: `Packages/PulseFeatures/Sources/PulseServices/Health/WatchHandoffStore.swift` (protocole, `UserDefaultsWatchHandoffStore(suiteName:)`, `InMemoryWatchHandoffStore`)
- Modify: `Packages/PulseFeatures/Sources/PulseServices/LiveSession/ActiveSessionService+Finish.swift` (`finish` consulte la passation avant `health?.export`)
- Modify: `Packages/PulseFeatures/Sources/PulseServices/Health/HealthWorkoutExporter.swift` (`link(_ session:, workoutID:)` : poser `healthKitUUID` sans écrire ; `replaceOwnWorkout`)
- Test: `Packages/PulseFeatures/Tests/PulseServicesTests/WatchHealthHandoffTests.swift`

**Interfaces:**
- Consumes: tâches 2, 6 et 7, `HealthWorkoutExporter`, `WorkoutRepository`.
- Produces :

```swift
public struct WatchHandoff: Sendable, Equatable, Codable { public var sessionID: UUID; public var endedAt: Date }
public protocol WatchHandoffStore: Sendable { func all() -> [WatchHandoff]; func add(_ h: WatchHandoff); func remove(_ id: UUID) }

public final class WatchHealthHandoff: Sendable {
    public static let lateJoinLimit: TimeInterval = 5 * 60
    public static let catchUpAfter: TimeInterval = 60 * 60
    public init(exporter: HealthWorkoutExporter, writer: any WorkoutHealthWriting, workouts: any WorkoutRepository,
                store: any WatchHandoffStore, now: @escaping @Sendable () -> Date)
    /// Vrai si la montre doit écrire : watchWorkoutBeganAt ≤ startedAt + 5 min. Note la passation dans ce cas.
    public func delegatesToWatch(_ session: WorkoutSession, watchWorkoutBeganAt: Date?) -> Bool
    /// Compte rendu de la montre. Rend la FC pour le récap, en mémoire seulement.
    public func receive(_ report: WatchWorkoutReport) async -> WorkoutHeartRateSummary?
    /// Au lancement et à chaque passage du jour.
    public func catchUp() async
}
```

**Règles** (spec §5.6) :
- `receive(.saved(id))` :
  - si la séance a déjà un `healthKitUUID` différent écrit par l'iPhone, supprimer celui de l'iPhone ;
  - puis `link`, et retirer la passation.
- `receive(.discarded)` : `exporter.export(session)` si la séance n'a pas d'entraînement, puis retirer la passation.
- `catchUp()` : pour chaque passation de plus d'une heure, `writer.workoutID(forSession:)` puis `link`, sinon `export`. Retirer la passation dans les deux cas. Une séance supprimée entre-temps : retirer seulement la passation.
- Un compte rendu pour une séance inconnue est ignoré.

- [ ] **Step 1: Write the failing tests** :
  - `watchPresentFromTheStartWritesAndIPhoneDoesNot` ;
  - `lateJoinLetsTheIPhoneWrite` ;
  - `savedReportLinksTheWatchWorkout` ;
  - `discardedReportMakesTheIPhoneWrite` ;
  - `lostReportIsCaughtUpByMetadataAfterAnHour` ;
  - `lostReportWithoutWatchWorkoutIsWrittenByTheIPhone` ;
  - `catchUpWaitsAnHour` ;
  - `lateSavedReportReplacesTheIPhoneWorkout` ;
  - `abandonedSessionNeverWritesAnything` ;
  - `deletedSessionDropsItsHandoff` ;
  - `heartRateNeverReachesSnapshotOrSyncedSession` (relit `WorkoutSession` et le snapshot après un compte rendu avec FC).
- [ ] **Step 2: Run** `swift test --package-path Packages/PulseFeatures --filter WatchHealthHandoffTests`. Expected: FAIL.
- [ ] **Step 3: Implement**. `ActiveSessionService.finish` demande `delegatesToWatch` avant d'exporter. Il garde le chemin actuel quand `handoff == nil` (pas de montre).
- [ ] **Step 4: Run** `swift test --package-path Packages/PulseFeatures`, puis `make lint`. Expected: PASS, lint 0.
- [ ] **Step 5: Commit** `feat(watch): one Health workout per session, written by the Watch when it measured it all, caught up by the iPhone otherwise`.

### Task 9: Pont WatchConnectivity de l'iPhone et branchement

**Files:**
- Create: `Pulse/Watch/WatchConnectivityBridge.swift` (`WCSessionDelegate`, implémente `SessionWatchPublishing`)
- Create: `Pulse/Watch/WatchAppLauncher.swift` (`HKHealthStore.startWatchApp(toHandle:)` avec une configuration `traditionalStrengthTraining`, en intérieur)
- Create: `Pulse/Watch/WatchPreferencesStore.swift` (`opensWatchAppOnStart`, défaut `true`, clé `pulse.watch.opensOnStart`)
- Modify: `Pulse/AppDependencies.swift` (construire le pont, `WatchHealthHandoff`, `UserDefaultsWatchHandoffStore`, et les passer à `ActiveSessionService` ; doublures dans `testing(...)` et `preview()`)
- Modify: `Pulse/AppDependencies+Refresher.swift` (ou le passage du jour) : `handoff.catchUp()` après le passage du jour
- Modify: `Pulse/AppDelegate.swift` : activer `WCSession` au lancement, avant toute intention
- Modify: l'effacement total (là où les clés `pulse.run.*` sont vidées) : vider aussi `pulse.watch.*` et les passations
- Test: `PulseTests/WatchConnectivityBridgeTests.swift` (logique du pont avec un faux `WCSession` derrière un petit protocole)

**Règles :**
- Si `WCSession.isSupported()` est faux ou si `!isPaired || !isWatchAppInstalled`, aucun envoi et aucun `startWatchApp`.
- `update` envoie `updateApplicationContext` à chaque état, plus `sendMessage` si `isReachable`.
- Message reçu :
  - `.command` donne `applyFromWatch`, et la réponse `.state` ;
  - `.requestState` donne `watchRequestedState` ;
  - `userInfo` `.workoutReport` donne `handoff.receive`, puis le coordinateur de séance est rafraîchi.
- Après une commande de la montre : `coordinator?.refresh()`, comme `SessionIntentWiring`.

- [ ] **Step 1: Write the failing test** `WatchConnectivityBridgeTests` :
  - `nothingIsSentWithoutAPairedWatch` ;
  - `contextIsAlwaysUpdatedAndMessageOnlyWhenReachable` ;
  - `commandMessageRepliesWithTheNewState` ;
  - `reportIsHandedToTheHandoff` ;
  - `launcherRespectsThePreference`.
- [ ] **Step 2: Run** `make build-app`. Expected: échec de compilation des tests (types absents). Les tests de `PulseTests` ne se lancent pas ici, Mathéo les lance.
- [ ] **Step 3: Implement**.
- [ ] **Step 4: Run** `make build-app`, `make build-release`, puis `make lint`. Expected: code 0 partout.
- [ ] **Step 5: Commit** `feat(watch): WatchConnectivity bridge on the iPhone, Watch app launch, handoff catch-up on the daily pass`.

### Task 10: FC au récap et dans le détail de séance

**Files:**
- Modify: `Packages/PulseFeatures/Sources/LiveSessionFeature/Recap/` (le modèle du récap reçoit un `WorkoutHeartRateSummary?` en mémoire ; une ligne « FC moyenne 118 · max 162 »)
- Modify: `Packages/PulseFeatures/Sources/TrainFeature/History/SessionDetailModel.swift` et `SessionDetailView.swift` (lecture à l'affichage par `heartRateSummary(workoutID:)` si `healthKitUUID` existe)
- Modify: les textes (`LiveSessionText` ou le fichier de textes du récap, `TrainText` ou équivalent) avec leurs libellés parlés
- Test: `Packages/PulseFeatures/Tests/LiveSessionFeatureTests/…RecapHeartRateTests.swift`, `Packages/PulseFeatures/Tests/TrainFeatureTests/SessionDetailHeartRateTests.swift`

- [ ] **Step 1: Write the failing tests** :
  - `recapShowsTheWatchHeartRateWhenReported` ;
  - `recapShowsNothingWithoutReport` ;
  - `detailReadsTheHeartRateOfTheLinkedWorkout` ;
  - `detailShowsNothingWithoutWorkoutOrPermission` ;
  - `heartRateSpokenLabel` (« Fréquence cardiaque moyenne 118 battements par minute, maximale 162 »).
- [ ] **Step 2: Run** `swift test --package-path Packages/PulseFeatures --filter "RecapHeartRate|SessionDetailHeartRate"`. Expected: FAIL.
- [ ] **Step 3: Implement**. Ajouter un aperçu à `accessibility3`.
- [ ] **Step 4: Run** `swift test --package-path Packages/PulseFeatures`, puis `make lint`. Expected: PASS, lint 0.
- [ ] **Step 5: Commit** `feat(session): show the Watch heart rate on the recap and in the session detail, read from Health`.

### Task 11: Paramètres « Apple Watch » et montre simulée (debug)

**Files:**
- Modify: `Packages/PulseFeatures/Sources/ProfileFeature/` (section « Apple Watch » des Paramètres, visible seulement si une montre est jumelée : état de l'installation et interrupteur « Ouvrir Pulse sur la montre au début d'une séance »), et son environnement
- Create: `Pulse/Debug/SimulatedWatchView.swift`, `Pulse/Debug/SimulatedWatch.swift`
  - La montre simulée appelle `applyFromWatch` et `watchRequestedState` exactement comme le pont, et affiche le dernier état publié.
  - Ses boutons : Valider (avec couronne simulée par −/+), −30 s, +30 s, Passer, « Rapport : écrit » et « Rapport : jeté ».
  - Un interrupteur « Montre injoignable ».
- Modify: `Pulse/Debug/DataDebugView.swift` (lien « Montre simulée », Debug seulement)
- Test: `Packages/PulseFeatures/Tests/ProfileFeatureTests/WatchSettingsTests.swift`

- [ ] **Step 1: Write the failing tests** : `watchSectionHiddenWithoutPairedWatch`, `toggleWritesThePreference`, `installStateText`.
- [ ] **Step 2: Run** `swift test --package-path Packages/PulseFeatures --filter WatchSettingsTests`. Expected: FAIL.
- [ ] **Step 3: Implement**. La montre simulée est compilée seulement en Debug (`#if DEBUG`).
- [ ] **Step 4: Run** `swift test --package-path Packages/PulseFeatures`, `make build-app`, `make build-release`, puis `make lint`. Expected: PASS, code 0, lint 0.
- [ ] **Step 5: Commit** `feat(watch): Apple Watch settings section and a simulated Watch in the debug screen`.

---

## Lot 2 — La cible watchOS

### Task 12: Cible `PulseWatch` et outillage

**Files:**
- Modify: `Pulse.xcodeproj/project.pbxproj`. Nouvelle cible `PulseWatch` (`com.apple.product-type.application`, SDK `watchos`, déploiement watchOS 26), sur le modèle de `PulseWidgets` :
  - dossier synchronisé `PulseWatch/` ;
  - produit `PulseWatchLink` lié ;
  - phase « Embed Watch Content » dans `Pulse` ;
  - identifiant `fr.seonay.pulse.watchkitapp` ;
  - signature automatique et équipe identique ;
  - schéma partagé `PulseWatch`.

  **Si `make build-app` ne passe pas après une édition à la main, s'arrêter et demander à Mathéo de créer la cible dans Xcode** (File › New › Target › watchOS › App, « Watch App for Existing iOS App »), puis reprendre (spec §10).
- Create: `PulseWatch/Info.plist` :
  - `WKApplication` = `true`, `WKCompanionAppBundleIdentifier` = `fr.seonay.pulse`, `WKRunsIndependentlyOfCompanionApp` = `false` ;
  - `WKBackgroundModes` = [`workout-processing`] ;
  - `NSHealthShareUsageDescription` = « Pulse lit votre fréquence cardiaque pendant une séance pour l'afficher sur la montre et l'enregistrer avec la séance dans Apple Santé. » ;
  - `NSHealthUpdateUsageDescription` = « Pulse enregistre vos séances de musculation, leur fréquence cardiaque et l'énergie dépensée dans Apple Santé. » ;
  - `CFBundleShortVersionString` et `CFBundleVersion` égaux à ceux de `Pulse/Info.plist`.
- Create: `PulseWatch/PulseWatch.entitlements` (`com.apple.developer.healthkit`, `com.apple.developer.healthkit.access` vide)
- Create: `PulseWatch/PrivacyInfo.xcprivacy` (déclarer seulement ce que la cible utilise ; `NSPrivacyTracking` faux, aucune donnée collectée)
- Create: `PulseWatch/Assets.xcassets` (icône de l'app, couleur d'accent)
- Create: `PulseWatch/PulseWatchApp.swift` (squelette : écran « Aucune séance en cours »)
- Modify: `Makefile` :
  - `build-watch:` `xcodebuild build -scheme PulseWatch -destination 'generic/platform=watchOS Simulator' -quiet` ;
  - `check-versions` compare aussi `PulseWatch/Info.plist` ;
  - `build-release` construit aussi `swift build -c release --package-path Packages/PulseWatchLink`.
- Modify: `scripts/check-info-plist.sh` :
  - un second contrôle sur `PulseWatch/Info.plist` : les deux textes Santé sont présents et non vides, `workout-processing` est présent dans `WKBackgroundModes` ;
  - le contrôle de l'iPhone est inchangé.
- Modify: `.swiftlint.yml` (`included` += `PulseWatch`, `PulseWatchUITests`)

- [ ] **Step 1: Implement**.
- [ ] **Step 2: Run** `scripts/check-info-plist.sh`. Expected: code 0. Puis, sur une copie temporaire de `Pulse/Info.plist` à laquelle on ajoute `workout-processing`, `scripts/check-info-plist.sh <copie>`. Expected: code 1, avec le message.
- [ ] **Step 3: Run** `make check-versions`, `make build-watch`, `make build-app`, puis `make build-release`. Expected: code 0 partout.
- [ ] **Step 4: Run** `make lint`. Expected: 0.
- [ ] **Step 5: Commit** `feat(watch): PulseWatch watchOS target embedded in the app, plist and version checks`.

### Task 13: Adaptateurs de la montre (WatchConnectivity, HealthKit, haptiques)

**Files:**
- Create: `PulseWatch/Link/WatchConnectivityPhoneLink.swift` (`WatchPhoneLink` au-dessus de `WCSession` : `sendMessageData` avec réponse et délai, `transferUserInfo`, contexte d'application et joignabilité transmis au modèle)
- Create: `PulseWatch/Workout/HealthKitWatchWorkout.swift` (`WatchWorkoutRunning` : `HKWorkoutSession` `traditionalStrengthTraining` en intérieur, `HKLiveWorkoutBuilder` avec `HKLiveWorkoutDataSource`, flux de FC, `finish` avec `HKMetadataKeyExternalUUID`, `discard`, `recover`)
- Create: `PulseWatch/System/WatchKitHaptics.swift` (`WKInterfaceDevice.current().play(…)`), `PulseWatch/System/VoiceOverAnnouncer.swift`
- Create: `PulseWatch/PulseWatchAppDelegate.swift` (`WKApplicationDelegate` : `handle(_ workoutConfiguration:)`, puis `model.launched()` ; `handleActiveWorkoutRecovery()`, puis `workout.recover()` et `model.launched()`)
- Create: `PulseWatch/Notifications/RestNotificationFilter.swift` (`UNUserNotificationCenterDelegate.willPresent` : pas de présentation pour la notification de fin de repos quand une séance tourne, spec §5.4)
- Modify: `PulseWatch/PulseWatchApp.swift` (`@WKApplicationDelegateAdaptor`, construction du modèle)

- [ ] **Step 1: Implement**, en suivant `HealthKitRunRecorder` (verrou, `@unchecked Sendable` justifié en commentaire) pour la séance HealthKit.
- [ ] **Step 2: Run** `make build-watch`, puis `make build-app`. Expected: code 0.
- [ ] **Step 3: Run** `swift test --package-path Packages/PulseWatchLink` (non-régression), puis `make lint`. Expected: PASS, lint 0.
- [ ] **Step 4: Commit** `feat(watch): WatchConnectivity link, strength workout session with heart rate, haptics and recovery on the Watch`.

### Task 14: Écrans de la montre et accessibilité

**Files:**
- Create: `PulseWatch/Views/IdleView.swift`, `HealthPermissionView.swift`, `SetView.swift`, `RestView.swift`, `AllDoneView.swift`, `RootView.swift`
- Create: `PulseWatch/Views/ValueField.swift`
  - Une valeur sélectionnable à la couronne : `digitalCrownRotation` relayé à `model.crown(steps:)`.
  - `accessibilityAdjustableAction` fait le même pas.
  - Couleur d'accent pour une proposition, neutre pour une valeur modifiée.
- Modify: `Pulse.xcodeproj/project.pbxproj` (cible de tests d'interface `PulseWatchUITests` pour `PulseWatch`, sur le modèle de `PulseUITests`)
- Create: `PulseWatchUITests/WatchSessionUITests.swift` (écrit et compilé, lancé par Mathéo : affichage de l'écran d'attente, navigation série puis repos avec un modèle de démonstration)

**Exigences** (spec §4.3 et §7) :
- fond noir, contrastes maximaux ;
- `Text(timerInterval:)` et `ProgressView(timerInterval:)` pour la durée et le repos, sans `Timer` ;
- vue épurée quand `isLuminanceReduced` est vrai (heure de fin du repos) ;
- `ScrollView`, boutons en pleine largeur aux tailles d'accessibilité, aucune valeur tronquée ;
- `accessibilityReduceMotion` : anneau sans animation ;
- étiquettes VoiceOver prises dans `WatchSessionText` ;
- aperçus en tailles standard et à la plus grande taille d'accessibilité, avec un `WatchSessionModel` alimenté par les doublures de `PulseWatchLink`.

- [ ] **Step 1: Implement**.
- [ ] **Step 2: Run** `make build-watch`, `make build-app`, puis `make build-release`. Expected: code 0.
- [ ] **Step 3: Run** `make lint`. Expected: 0.
- [ ] **Step 4: Commit** `feat(watch): set, rest and idle screens on the Watch with crown editing and VoiceOver`.

### Task 15: Textes publics et liste de vérification

**Files:**
- Modify: `docs/confidentialite/index.html` (spec §6 : FC et énergie mesurées par la montre écrites dans Santé ; échange direct entre l'iPhone et la montre ; rien dans iCloud ni chez le développeur ; date de mise à jour)
- Modify: `docs/app-store/fiche.md` (description, notes de revue avec la marche à suivre pour tester, captures Apple Watch à fournir, « Données non collectées » inchangé)
- Create: `docs/app-store/verification-apple-watch.md`, en trois parties, chacune avec le résultat attendu :
  1. **Simulateurs jumelés** : ouverture manuelle, validation, repos, injoignable, fin, captures ;
  2. **iPhone avec la montre simulée** : Live Activity, notification, passation, rattrapage, et iPhone sans montre ;
  3. **Vraie montre, pour le testeur TestFlight** : vibration poignet baissé, ouverture automatique, FC, un seul entraînement dans Santé, suppression depuis l'iPhone, effacement total, notification masquée, batterie sur une heure.
- Modify: `README.md` (section « Développement sans Apple Watch » : la montre simulée et les simulateurs jumelés ; liste des packages et des commandes `make`)

- [ ] **Step 1: Implement**. Relire chaque phrase de la politique contre le code : rien ne doit promettre plus que ce que font les tâches 2 à 14.
- [ ] **Step 2: Run** `make lint` (inchangé, mais vérifie que rien n'a bougé). Expected: 0.
- [ ] **Step 3: Commit** `docs(watch): privacy policy, App Store sheet and Apple Watch verification checklist`.

---

## Après le plan (hors tâches)

- Revue finale de toute la branche, en insistant sur le Review Focus.
- Tous les `swift test --package-path Packages/<Nom>` (`PulseDomain`, `PulseRecoveryEngine`, `PulseContent`, `PulsePersistence`, `PulseDesignSystem`, `PulseFeatures`, `PulseWatchLink`), puis `make lint`, `make build-app`, `make build-watch` et `make build-release` : tout vert.
- Ce qui reste à Mathéo (spec §13) :
  - les questions ouvertes ;
  - l'identifiant de la montre et la capacité HealthKit dans le portail développeur, puis un premier build Xcode Cloud ;
  - les parties 1 et 2 de `verification-apple-watch.md` ;
  - les captures Apple Watch ;
  - un testeur TestFlight pour la partie 3 ;
  - aucune soumission avant son retour (Q2).
