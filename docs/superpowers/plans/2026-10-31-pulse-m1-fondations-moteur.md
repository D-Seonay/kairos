# Pulse M1 — Fondations et moteur de récupération : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Un projet Xcode propre, trois packages Swift testés (`PulseDomain`, `PulseRecoveryEngine`, `PulseHealth`), et une app TestFlight qui lit Apple Santé, affiche par type la dernière valeur reçue et sa source, et calcule le score de récupération provisoire du jour.

**Architecture:** App SwiftUI fine qui assemble des packages locaux. Le domaine et le moteur n'importent que Foundation et se testent avec `swift test` sur le Mac, sans simulateur. `PulseHealth` enveloppe HealthKit derrière un protocole `HealthReading` pour que l'app et les tests utilisent une doublure. Les formules du §6 de la spec sont implémentées une par une avec leurs valeurs exactes, puis vérifiées sur des scénarios JSON réutilisés plus tard par le fournisseur HealthKit factice.

**Tech Stack:** Swift 6 (mode strict), SwiftUI, Swift Testing, Swift Package Manager, HealthKit, Xcode 26, Xcode Cloud, SwiftLint.

**Spec:** `docs/superpowers/specs/2026-10-31-pulse-v1-design.md` (§4 décisions, §6 moteur, §7 Apple Santé, §9 structure, §12 qualité, §13 risques). Feuille de route : `docs/superpowers/plans/2026-10-31-pulse-v1-roadmap.md`.

## Global Constraints

- Exécution sur **macOS avec Xcode 26**. Les commandes `swift test` tournent sur le Mac hôte ; les tests de l'app tournent sur le simulateur « iPhone 17 ».
- Cible de déploiement **iOS 26**. Swift **6**, mode de langage Swift 6 activé sur l'app et tous les packages (`swiftLanguageModes: [.v6]`).
- `PulseDomain` et `PulseRecoveryEngine` : **aucun import autre que Foundation**. `PulseHealth` est le seul package qui importe HealthKit.
- Tests unitaires en **Swift Testing** (`import Testing`, `@Test`, `#expect`). Pas de XCTest pour l'unitaire.
- Toutes les chaînes visibles par l'utilisateur sont en **français** et passent par `String(localized:)`.
- Aucune donnée de santé brute n'est journalisée (`print`, `Logger`) : seuls les comptes et les types.
- Pondérations et seuils, copiés de la spec : VFC 0,50 / FC repos 0,25 / sommeil 0,25 ; catégories 90, 65, 40 ; ligne de base VFC sur 14 nuits, minimum 5, plancher d'écart-type 0,05 en unités log ; FC repos sur 7 jours, minimum 3 valeurs ; check-in 40 / 35 / 25 ; ACWR optimal 0,8 à 1,3, risque ≥ 1,5, affiché seulement avec 28 jours d'historique.
- Commits fréquents, messages au format `type: description` (anglais), terminés par la ligne `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- Ne jamais pousser sur `origin` sans que Mathéo le demande.

## Review Focus

Entrées que la spec implique sans les nommer, et qu'un utilisateur réel rencontrera. Chacune a reçu un test dans la tâche qui possède le code.

1. **Nuit du changement d'heure** (25 octobre 2026 en Europe) : la nuit dure 25 h ; la fenêtre de sommeil et les bornes de jour doivent venir du calendrier, jamais de `+ 24 × 3600`. Test dans la tâche 8.
2. **Deux sources qui écrivent la même nuit** (Fitbit et, un jour, Apple Watch) : les intervalles de sommeil se recouvrent et la durée serait comptée deux fois. Les intervalles sont fusionnés avant la somme. Test dans la tâche 8.
3. **Valeurs SDNN aberrantes** (0, négatif, > 300 ms) : `ln(0)` est infini et casserait la ligne de base. Les échantillons hors ]0, 300] sont ignorés. Tests dans les tâches 3 et 8.
4. **Historique à trous** : 14 nuits réparties sur 30 jours ne font pas une ligne de base de 14 nuits. Les fenêtres se calculent en dates calendaires, pas en nombre d'éléments. Test dans la tâche 5.
5. **Autorisation Apple Santé refusée ou lecture en erreur** : l'écran de diagnostic doit afficher l'état et rester utilisable, pas planter ni rester vide. Test dans la tâche 10.

---

## Structure des fichiers créés par ce plan

```
.gitignore
Makefile
.swiftlint.yml
ci_scripts/ci_post_clone.sh
Pulse.xcodeproj/
Pulse/
  PulseApp.swift
  AppDependencies.swift
  Info.plist (clés HealthKit)
  Pulse.entitlements (HealthKit)
  Diagnostics/
    HealthDiagnosticsModel.swift
    HealthDiagnosticsView.swift
PulseTests/
  HealthDiagnosticsModelTests.swift
Packages/
  PulseDomain/
    Package.swift
    Sources/PulseDomain/Recovery/Factor.swift
    Sources/PulseDomain/Recovery/RecoveryCategory.swift
    Sources/PulseDomain/Recovery/CalibrationState.swift
    Sources/PulseDomain/Health/TimedSample.swift
    Sources/PulseDomain/Health/SleepInterval.swift
    Sources/PulseDomain/Health/NightSample.swift
    Tests/PulseDomainTests/RecoveryCategoryTests.swift
  PulseRecoveryEngine/
    Package.swift
    Sources/PulseRecoveryEngine/Scoring/HRVBaseline.swift
    Sources/PulseRecoveryEngine/Scoring/HRVScorer.swift
    Sources/PulseRecoveryEngine/Scoring/RHRScorer.swift
    Sources/PulseRecoveryEngine/Scoring/SleepScorer.swift
    Sources/PulseRecoveryEngine/Scoring/CheckInScorer.swift
    Sources/PulseRecoveryEngine/Recovery/RecoveryResult.swift
    Sources/PulseRecoveryEngine/Recovery/RecoveryCalculator.swift
    Sources/PulseRecoveryEngine/Load/LoadCalculator.swift
    Sources/PulseRecoveryEngine/Aggregation/NightAggregator.swift
    Tests/PulseRecoveryEngineTests/HRVBaselineTests.swift
    Tests/PulseRecoveryEngineTests/HRVScorerTests.swift
    Tests/PulseRecoveryEngineTests/RHRScorerTests.swift
    Tests/PulseRecoveryEngineTests/SleepScorerTests.swift
    Tests/PulseRecoveryEngineTests/CheckInScorerTests.swift
    Tests/PulseRecoveryEngineTests/RecoveryCalculatorTests.swift
    Tests/PulseRecoveryEngineTests/LoadCalculatorTests.swift
    Tests/PulseRecoveryEngineTests/NightAggregatorTests.swift
    Tests/PulseRecoveryEngineTests/ScenarioTests.swift
    Tests/PulseRecoveryEngineTests/Support/TestCalendar.swift
    Tests/PulseRecoveryEngineTests/Fixtures/scenario-*.json
  PulseHealth/
    Package.swift
    Sources/PulseHealth/HealthDataType.swift
    Sources/PulseHealth/HealthReading.swift
    Sources/PulseHealth/HealthKitReader.swift
    Sources/PulseHealth/StubHealthReader.swift
```

Responsabilités : `PulseDomain` porte les types partagés ; `PulseRecoveryEngine` porte tout calcul ; `PulseHealth` ne fait que lire HealthKit et convertir en types du domaine ; l'app assemble et affiche.

---

### Task 1 : Dépôt et projet Xcode

**Files:**
- Create: `.gitignore`, `Pulse.xcodeproj`, `Pulse/PulseApp.swift`, `PulseTests/` (cible de tests générée)

**Interfaces:**
- Produces : un schéma `Pulse` qui compile et teste sur « iPhone 17 ». Identifiant de bundle `fr.seonay.pulse` (à remplacer par celui du compte développeur de Mathéo si différent ; le nom est un choix de ce plan).

- [ ] **Step 1 : Écrire `.gitignore`**

Contenu exact :

```
# Xcode
xcuserdata/
*.xcuserstate
DerivedData/
build/
*.xcresult
# SwiftPM
.build/
.swiftpm/
Packages/*/.build/
# macOS
.DS_Store
# Secrets
*.p8
*.mobileprovision
```

- [ ] **Step 2 : Créer le projet dans Xcode**

Xcode > File > New > Project > iOS > App. Product Name `Pulse`, Organization Identifier `fr.seonay`, Interface SwiftUI, Language Swift, Testing System **Swift Testing**, Storage **None**, Host in CloudKit décoché. Enregistrer à la racine du dépôt (le dossier `Pulse.xcodeproj` doit être à côté de `README.md`).

- [ ] **Step 3 : Régler la cible**

Cible `Pulse` > General > Minimum Deployments : **iOS 26.0**. Build Settings > Swift Language Version : **Swift 6**. Supprimer iPad des « Supported Destinations » (iPhone seul). Build Settings > Strict Concurrency Checking : Complete.

- [ ] **Step 4 : Vérifier que le projet compile et que la cible de tests tourne**

Run :
```bash
xcodebuild test -scheme Pulse -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
```
Expected : se termine par `** TEST SUCCEEDED **`.

- [ ] **Step 5 : Commit**

```bash
git add .gitignore Pulse.xcodeproj Pulse PulseTests
git commit -m "chore: create Pulse Xcode project (iOS 26, Swift 6)"
```

---

### Task 2 : Package `PulseDomain`

**Files:**
- Create: `Packages/PulseDomain/Package.swift`
- Create: `Packages/PulseDomain/Sources/PulseDomain/Recovery/Factor.swift`
- Create: `Packages/PulseDomain/Sources/PulseDomain/Recovery/RecoveryCategory.swift`
- Create: `Packages/PulseDomain/Sources/PulseDomain/Recovery/CalibrationState.swift`
- Create: `Packages/PulseDomain/Sources/PulseDomain/Health/TimedSample.swift`
- Create: `Packages/PulseDomain/Sources/PulseDomain/Health/SleepInterval.swift`
- Create: `Packages/PulseDomain/Sources/PulseDomain/Health/NightSample.swift`
- Test: `Packages/PulseDomain/Tests/PulseDomainTests/RecoveryCategoryTests.swift`

**Interfaces:**
- Produces :
  - `public enum Factor: String, Sendable, Codable, CaseIterable { case hrv, restingHeartRate, sleep }`
  - `public enum RecoveryCategory: String, Sendable, Codable { case optimal, normal, moderateFatigue, overreached; public init(score: Double) }`
  - `public enum CalibrationState: Sendable, Equatable, Codable { case calibrating(nights: Int); case ready }`
  - `public struct TimedSample: Sendable, Equatable, Codable { public var date: Date; public var value: Double; public init(date: Date, value: Double) }`
  - `public enum SleepStage: String, Sendable, Codable { case inBed, awake, asleepUnspecified, core, deep, rem; public var isAsleep: Bool }` (vrai pour `asleepUnspecified`, `core`, `deep`, `rem`)
  - `public struct SleepInterval: Sendable, Equatable, Codable { public var start: Date; public var end: Date; public var stage: SleepStage; public init(start:end:stage:) }`
  - `public struct SleepSummary: Sendable, Equatable, Codable { public var asleepMinutes: Int; public var deepMinutes: Int?; public init(asleepMinutes:deepMinutes:) }`
  - `public struct NightSample: Sendable, Equatable, Codable { public var day: Date; public var sdnnMs: Double?; public var restingHeartRate: Double?; public var sleep: SleepSummary?; public init(day:sdnnMs:restingHeartRate:sleep:) }` — `day` est le **jour de réveil à minuit local**.

- [ ] **Step 1 : Créer le package**

```bash
mkdir -p Packages/PulseDomain && cd Packages/PulseDomain && swift package init --type library --name PulseDomain
```
Remplacer `Package.swift` par : `swift-tools-version: 6.0`, `platforms: [.iOS(.v26), .macOS(.v15)]`, une bibliothèque `PulseDomain`, une cible de tests `PulseDomainTests`, `swiftLanguageModes: [.v6]` sur les deux cibles. Supprimer le fichier source généré.

- [ ] **Step 2 : Écrire le test des seuils de catégorie**

```swift
import Testing
@testable import PulseDomain

@Test(arguments: [
    (100.0, RecoveryCategory.optimal), (90.0, .optimal), (89.99, .normal),
    (65.0, .normal), (64.99, .moderateFatigue), (40.0, .moderateFatigue),
    (39.99, .overreached), (0.0, .overreached)
])
func categoryThresholds(score: Double, expected: RecoveryCategory) {
    #expect(RecoveryCategory(score: score) == expected)
}
```

- [ ] **Step 3 : Lancer le test pour vérifier qu'il échoue**

Run : `swift test --package-path Packages/PulseDomain`
Expected : erreur de compilation, `RecoveryCategory` introuvable.

- [ ] **Step 4 : Écrire les six fichiers de types listés dans Interfaces**

`RecoveryCategory.init(score:)` : `≥ 90` optimal, `≥ 65` normal, `≥ 40` moderateFatigue, sinon overreached.

- [ ] **Step 5 : Lancer les tests**

Run : `swift test --package-path Packages/PulseDomain`
Expected : tous les cas passent.

- [ ] **Step 6 : Ajouter le package au projet**

Xcode > File > Add Package Dependencies > Add Local > `Packages/PulseDomain`. Lier `PulseDomain` à la cible `Pulse`. Edit Scheme `Pulse` > Test > ajouter `PulseDomainTests`.

Run : `xcodebuild test -scheme Pulse -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected : `** TEST SUCCEEDED **`.

- [ ] **Step 7 : Commit**

```bash
git add Packages/PulseDomain Pulse.xcodeproj
git commit -m "feat(domain): add recovery and health value types"
```

---

### Task 3 : Ligne de base et score VFC

**Files:**
- Create: `Packages/PulseRecoveryEngine/Package.swift` (dépend de `PulseDomain` par chemin `../PulseDomain`)
- Create: `Packages/PulseRecoveryEngine/Sources/PulseRecoveryEngine/Scoring/HRVBaseline.swift`
- Create: `Packages/PulseRecoveryEngine/Sources/PulseRecoveryEngine/Scoring/HRVScorer.swift`
- Test: `Packages/PulseRecoveryEngine/Tests/PulseRecoveryEngineTests/HRVBaselineTests.swift`
- Test: `Packages/PulseRecoveryEngine/Tests/PulseRecoveryEngineTests/HRVScorerTests.swift`

**Interfaces:**
- Produces :
  - `public struct HRVBaseline: Sendable, Equatable { public static let minimumNights = 5; public static let standardDeviationFloor = 0.05; public let mean: Double; public let standardDeviation: Double; public let nights: Int; public init?(sdnnValuesMs: [Double]); public func zScore(sdnnMs: Double) -> Double }`
    - L'init applique `ln` à chaque valeur, **ignore** les valeurs non comprises dans `]0, 300]`, retourne `nil` s'il reste moins de 5 valeurs, calcule la moyenne et l'écart-type **échantillon** (diviseur n − 1), puis `standardDeviation = max(sd, 0.05)`.
  - `public enum HRVScorer { public static func score(zScore: Double) -> Double }`

- [ ] **Step 1 : Créer le package**

```bash
mkdir -p Packages/PulseRecoveryEngine && cd Packages/PulseRecoveryEngine && swift package init --type library --name PulseRecoveryEngine
```
`Package.swift` : mêmes réglages que `PulseDomain`, plus `dependencies: [.package(path: "../PulseDomain")]` et `PulseDomain` en dépendance de la cible.

- [ ] **Step 2 : Écrire les tests de la ligne de base**

```swift
import Testing
import Foundation
@testable import PulseRecoveryEngine

@Test func baselineNeedsFiveNights() {
    #expect(HRVBaseline(sdnnValuesMs: [50, 50, 50, 50]) == nil)
    #expect(HRVBaseline(sdnnValuesMs: [50, 50, 50, 50, 50]) != nil)
}

@Test func baselineUsesSampleStandardDeviationOnLogValues() throws {
    // ln des valeurs = 1, 2, 3, 4, 5 → moyenne 3, sd échantillon √2,5
    let values = [1.0, 2.0, 3.0, 4.0, 5.0].map { exp($0) }
    let baseline = try #require(HRVBaseline(sdnnValuesMs: values))
    #expect(abs(baseline.mean - 3.0) < 1e-9)
    #expect(abs(baseline.standardDeviation - 2.5.squareRoot()) < 1e-9)
    #expect(baseline.nights == 5)
}

@Test func baselineFloorsStandardDeviation() throws {
    let baseline = try #require(HRVBaseline(sdnnValuesMs: Array(repeating: 50, count: 14)))
    #expect(baseline.standardDeviation == 0.05)
    #expect(baseline.zScore(sdnnMs: 50) == 0)
}

@Test func baselineIgnoresOutOfRangeValues() {
    #expect(HRVBaseline(sdnnValuesMs: [0, -5, 400, 50, 50, 50, 50]) == nil)      // 4 valides
    #expect(HRVBaseline(sdnnValuesMs: [0, 400, 50, 50, 50, 50, 50])?.nights == 5)
}
```

- [ ] **Step 3 : Écrire les tests du score VFC (paliers du §4.2 du cahier des charges)**

```swift
@Test(arguments: [
    (2.0, 100.0), (0.5, 100.0),
    (0.0, 90.0), (-0.5, 80.0),
    (-1.0, 65.0), (-1.5, 50.0),
    (-2.0, 37.5), (-3.5, 10.0), (-10.0, 10.0)
])
func hrvScoreTiers(z: Double, expected: Double) {
    #expect(abs(HRVScorer.score(zScore: z) - expected) < 1e-9)
}
```

- [ ] **Step 4 : Lancer pour vérifier l'échec**

Run : `swift test --package-path Packages/PulseRecoveryEngine`
Expected : erreur de compilation sur `HRVBaseline`.

- [ ] **Step 5 : Implémenter `HRVBaseline` et `HRVScorer`**

Paliers de `HRVScorer.score(zScore:)` :
- `z ≥ 0.5` → 100
- `-0.5 ≤ z < 0.5` → `80 + (z + 0.5) × 20`
- `-1.5 ≤ z < -0.5` → `50 + (z + 1.5) × 30`
- `z < -1.5` → `max(10, 50 + (z + 1.5) × 25)`

- [ ] **Step 6 : Lancer les tests**

Run : `swift test --package-path Packages/PulseRecoveryEngine`
Expected : tous les tests passent.

- [ ] **Step 7 : Commit**

```bash
git add Packages/PulseRecoveryEngine
git commit -m "feat(engine): add HRV baseline and HRV score tiers"
```

---

### Task 4 : Scores FC repos, sommeil et check-in

**Files:**
- Create: `Packages/PulseRecoveryEngine/Sources/PulseRecoveryEngine/Scoring/RHRScorer.swift`
- Create: `Packages/PulseRecoveryEngine/Sources/PulseRecoveryEngine/Scoring/SleepScorer.swift`
- Create: `Packages/PulseRecoveryEngine/Sources/PulseRecoveryEngine/Scoring/CheckInScorer.swift`
- Test: `RHRScorerTests.swift`, `SleepScorerTests.swift`, `CheckInScorerTests.swift` dans `Tests/PulseRecoveryEngineTests/`

**Interfaces:**
- Produces :
  - `public enum RHRScorer { public static func score(todayBpm: Double, baselineMeanBpm: Double) -> Double }`
  - `public enum SleepScorer { public static func score(asleepMinutes: Int, deepMinutes: Int?) -> Double }`
  - `public struct CheckInAnswers: Sendable, Equatable, Codable { public var sleep: Int; public var pain: Int; public var motivation: Int; public init(sleep:pain:motivation:) }` — chaque réponse vaut 0 à 4, **4 = le meilleur état** (bien dormi, aucune douleur, très motivé).
  - `public enum CheckInScorer { public static func score(_ answers: CheckInAnswers) -> Double }`

- [ ] **Step 1 : Écrire les tests**

```swift
@Test(arguments: [(48.0, 50.0, 100.0), (50.0, 50.0, 100.0), (52.0, 50.0, 83.0), (57.0, 50.0, 40.5), (59.0, 50.0, 20.0), (62.0, 50.0, 0.0), (70.0, 50.0, 0.0)])
func rhrScore(today: Double, baseline: Double, expected: Double) {
    #expect(abs(RHRScorer.score(todayBpm: today, baselineMeanBpm: baseline) - expected) < 1e-9)
}

@Test func sleepScoreFullNight() { #expect(SleepScorer.score(asleepMinutes: 480, deepMinutes: 96) == 100) }
@Test func sleepScoreShortNightLowDeep() { #expect(abs(SleepScorer.score(asleepMinutes: 360, deepMinutes: 36) - 67.5) < 1e-9) }
@Test func sleepScoreCapsAtOne() { #expect(SleepScorer.score(asleepMinutes: 540, deepMinutes: 162) == 100) }
@Test func sleepScoreWithoutStagesUsesDurationOnly() { #expect(SleepScorer.score(asleepMinutes: 360, deepMinutes: nil) == 75) }
@Test func sleepScoreZeroMinutes() { #expect(SleepScorer.score(asleepMinutes: 0, deepMinutes: nil) == 0) }

@Test func checkInAllBest() { #expect(CheckInScorer.score(.init(sleep: 4, pain: 4, motivation: 4)) == 100) }
@Test func checkInWeighted() { #expect(abs(CheckInScorer.score(.init(sleep: 2, pain: 4, motivation: 0)) - 55) < 1e-9) }
@Test func checkInClampsOutOfRange() { #expect(CheckInScorer.score(.init(sleep: 9, pain: -1, motivation: 4)) == 65) }
```

- [ ] **Step 2 : Lancer pour vérifier l'échec**

Run : `swift test --package-path Packages/PulseRecoveryEngine`
Expected : erreurs de compilation sur les trois types.

- [ ] **Step 3 : Implémenter**

- `RHRScorer` (§4.3) : `Δ = today − baseline`. `Δ ≤ 0` → 100 ; `0 < Δ ≤ 7` → `100 − Δ × 8.5` ; `Δ > 7` → `max(0, 40 − (Δ − 7) × 10)`.
- `SleepScorer` (§4.4) : `H = asleepMinutes / 480`. Avec `deepMinutes` : `min(1, H) × 70 + min(1, (deep / asleep) / 0.20) × 30` (si `asleepMinutes == 0`, score 0). Sans `deepMinutes` : `min(1, H) × 100`.
- `CheckInScorer` : chaque réponse bornée à `0...4` puis ramenée sur 100 (`× 25`) ; score = `sleep × 0.40 + pain × 0.35 + motivation × 0.25`.

- [ ] **Step 4 : Lancer les tests**

Run : `swift test --package-path Packages/PulseRecoveryEngine`
Expected : tous les tests passent.

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulseRecoveryEngine
git commit -m "feat(engine): add resting HR, sleep and check-in scorers"
```

---

### Task 5 : Calculateur de récupération

**Files:**
- Create: `Packages/PulseRecoveryEngine/Sources/PulseRecoveryEngine/Recovery/RecoveryResult.swift`
- Create: `Packages/PulseRecoveryEngine/Sources/PulseRecoveryEngine/Recovery/RecoveryCalculator.swift`
- Create: `Packages/PulseRecoveryEngine/Tests/PulseRecoveryEngineTests/Support/TestCalendar.swift`
- Test: `Packages/PulseRecoveryEngine/Tests/PulseRecoveryEngineTests/RecoveryCalculatorTests.swift`

**Interfaces:**
- Consumes : `HRVBaseline`, `HRVScorer`, `RHRScorer`, `SleepScorer`, types de `PulseDomain`.
- Produces :
  - `public struct FactorScore: Sendable, Equatable { public let factor: Factor; public let score: Double; public let weight: Double; public let todayValue: Double; public let baselineValue: Double? }` — `weight` est le poids **après renormalisation**.
  - `public struct RecoveryResult: Sendable, Equatable { public let day: Date; public let score: Double; public let category: RecoveryCategory; public let factors: [FactorScore]; public let missing: [Factor]; public let calibration: CalibrationState; public var allowsProgressiveOverload: Bool }` — vrai seulement si `calibration == .ready` et `missing` vide.
  - `public enum RecoveryOutcome: Sendable, Equatable { case measured(RecoveryResult); case needsCheckIn(missing: [Factor]) }`
  - `public struct RecoveryCalculator: Sendable { public init(calendar: Calendar); public func compute(day: Date, today: NightSample, history: [NightSample]) -> RecoveryOutcome }`
  - Helper de test : `enum TestCalendar { static let paris: Calendar; static func day(_ y: Int, _ m: Int, _ d: Int) -> Date; static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date }` avec `Calendar(identifier: .gregorian)` et fuseau `Europe/Paris`.

Règles de `compute` (décisions du §6.3 de la spec, précisées ici) :
- `offset(n) = calendar.dateComponents([.day], from: n.day, to: day).day`.
- **VFC** : nuits de l'historique avec `sdnnMs` non nul et `offset ∈ 1...14`. `n` = leur nombre. `calibration = n < 14 ? .calibrating(nights: n) : .ready`. Facteur présent si `HRVBaseline` se construit (≥ 5 valeurs valides) **et** `today.sdnnMs` est non nul et dans `]0, 300]`. `todayValue = sdnn du jour`, `baselineValue = exp(baseline.mean)`.
- **FC repos** : nuits avec `restingHeartRate` et `offset ∈ 1...7` ; présent si au moins 3 valeurs et `today.restingHeartRate` non nul. `baselineValue = moyenne`.
- **Sommeil** : présent si `today.sleep` non nul. `todayValue = asleepMinutes`, `baselineValue = nil`.
- Poids nominaux 0,50 / 0,25 / 0,25 ; renormalisés sur les facteurs présents (somme 1). Moins de deux facteurs présents → `.needsCheckIn(missing:)` avec les facteurs absents dans l'ordre `hrv, restingHeartRate, sleep`.
- `score = Σ score_i × weight_i`, `category = RecoveryCategory(score:)`. `factors` est toujours ordonné `hrv, restingHeartRate, sleep` (facteurs présents seulement).

- [ ] **Step 1 : Écrire `TestCalendar` et les tests**

```swift
@Test func fourteenNightsReady() {
    let day = TestCalendar.day(2026, 11, 20)
    let history = (1...14).map { i in
        NightSample(day: TestCalendar.paris.date(byAdding: .day, value: -i, to: day)!,
                    sdnnMs: i.isMultiple(of: 2) ? 49 : 51, restingHeartRate: 50,
                    sleep: .init(asleepMinutes: 450, deepMinutes: 90))
    }
    let today = NightSample(day: day, sdnnMs: 60, restingHeartRate: 49, sleep: .init(asleepMinutes: 480, deepMinutes: 100))
    guard case .measured(let r) = RecoveryCalculator(calendar: TestCalendar.paris).compute(day: day, today: today, history: history) else { Issue.record("expected measured"); return }
    #expect(r.score == 100)
    #expect(r.category == .optimal)
    #expect(r.calibration == .ready)
    #expect(r.missing.isEmpty)
    #expect(r.allowsProgressiveOverload)
    #expect(r.factors.map(\.weight) == [0.5, 0.25, 0.25])
}

@Test func missingHRVRenormalizesWeights() {
    // même historique ; aujourd'hui : sdnn nil, FC repos 52, sommeil 420 min dont 84 profond
    // attendu : FC 83, sommeil 91,25, poids 0,5 / 0,5 → 87,125, normal, missing [.hrv], calibration .ready
}

@Test func eightNightsIsCalibrating() {
    // 8 nuits sdnn 50 / FC 50 / 480 min dont 96 ; aujourd'hui identique
    // attendu : score 95 (VFC 90, FC 100, sommeil 100), .calibrating(nights: 8), allowsProgressiveOverload == false
}

@Test func threeNightsDropsHRVButKeepsOthers() {
    // 3 nuits sdnn 50 / FC 50 / 450 min dont 90 ; aujourd'hui identique
    // attendu : measured, missing == [.hrv], calibration .calibrating(nights: 3), score 97,8125
}

@Test func twoMissingFactorsNeedsCheckIn() {
    // historique vide, aujourd'hui tout nil
    // attendu : .needsCheckIn(missing: [.hrv, .restingHeartRate, .sleep])
}

@Test func gapsInHistoryUseCalendarWindow() {
    // historique : une nuit par jour pour les offsets 1...42, FC repos 50 partout, sommeil nil,
    // sdnn 50 seulement aux offsets multiples de 2 (cas A) ou de 3 (cas B) ; aujourd'hui sdnn 50, FC 50, 480 min dont 96
    // cas A : 7 nuits VFC dans la fenêtre de 14 jours → measured, .calibrating(nights: 7), missing []
    // cas B : 4 nuits VFC dans la fenêtre → measured, missing == [.hrv], .calibrating(nights: 4)
}

@Test func todaySDNNOutOfRangeIsMissing() {
    // 14 nuits valides, aujourd'hui sdnn 0 → missing contient .hrv
}
```
Écrire les corps des tests à partir des commentaires ; les valeurs attendues sont celles des commentaires, à 1e-6 près.

- [ ] **Step 2 : Lancer pour vérifier l'échec**

Run : `swift test --package-path Packages/PulseRecoveryEngine --filter RecoveryCalculatorTests`
Expected : erreur de compilation sur `RecoveryCalculator`.

- [ ] **Step 3 : Implémenter `RecoveryResult.swift` et `RecoveryCalculator.swift` selon les règles ci-dessus**

- [ ] **Step 4 : Lancer les tests**

Run : `swift test --package-path Packages/PulseRecoveryEngine`
Expected : tous passés.

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulseRecoveryEngine
git commit -m "feat(engine): add recovery calculator with calibration and missing factors"
```

---

### Task 6 : Charge d'entraînement et ACWR

**Files:**
- Create: `Packages/PulseRecoveryEngine/Sources/PulseRecoveryEngine/Load/LoadCalculator.swift`
- Test: `Packages/PulseRecoveryEngine/Tests/PulseRecoveryEngineTests/LoadCalculatorTests.swift`

**Interfaces:**
- Produces :
  - `public struct LoadSession: Sendable, Equatable, Codable { public var date: Date; public var minutes: Double; public var rpe: Double; public var load: Double { minutes * rpe }; public init(date:minutes:rpe:) }`
  - `public enum ACWRZone: String, Sendable, Codable { case undertraining, optimal, elevated, risk; public init(ratio: Double) }`
  - `public struct ACWRResult: Sendable, Equatable { public let acute: Double; public let chronic: Double; public let ratio: Double; public let zone: ACWRZone }`
  - `public struct LoadCalculator: Sendable { public init(calendar: Calendar); public func acwr(sessions: [LoadSession], asOf day: Date, historyStart: Date) -> ACWRResult? }`

Règles : `nil` si moins de 27 jours entre `historyStart` et `day` (il faut 28 jours d'historique, le jour courant compris). `offset(s) = jours entre startOfDay(s.date) et day`. Aiguë = somme des charges avec `offset ∈ 0...6`. Chronique = somme des charges avec `offset ∈ 0...27`, divisée par 4. `nil` si chronique = 0. Zones : `< 0.8` undertraining, `0.8...1.3` optimal, `1.3 <… < 1.5` elevated, `≥ 1.5` risk.

- [ ] **Step 1 : Écrire les tests**

```swift
@Test func steadyLoadIsOptimal() {
    let day = TestCalendar.day(2026, 11, 28), start = TestCalendar.day(2026, 11, 1)
    let sessions = [0, 7, 14, 21].map { LoadSession(date: TestCalendar.paris.date(byAdding: .day, value: -$0, to: day)!, minutes: 60, rpe: 7) }
    let r = LoadCalculator(calendar: TestCalendar.paris).acwr(sessions: sessions, asOf: day, historyStart: start)
    #expect(r?.acute == 420); #expect(r?.chronic == 420); #expect(r?.ratio == 1); #expect(r?.zone == .optimal)
}
@Test func spikeIsRisk() {
    // mêmes 4 séances + une séance aujourd'hui de 60 min RPE 8 → aiguë 900, chronique 540, ratio 1,6667, .risk
}
@Test func needsTwentyEightDaysOfHistory() {
    // historyStart = day − 20 jours → nil, même avec des séances
}
@Test(arguments: [(0.79, ACWRZone.undertraining), (0.8, .optimal), (1.3, .optimal), (1.31, .elevated), (1.49, .elevated), (1.5, .risk)])
func zoneBoundaries(ratio: Double, expected: ACWRZone) { #expect(ACWRZone(ratio: ratio) == expected) }
@Test func noChronicLoadReturnsNil() { /* aucune séance → nil */ }
```

- [ ] **Step 2 : Lancer pour vérifier l'échec**

Run : `swift test --package-path Packages/PulseRecoveryEngine --filter LoadCalculatorTests`
Expected : erreur de compilation.

- [ ] **Step 3 : Implémenter `LoadCalculator.swift`**

- [ ] **Step 4 : Lancer les tests, puis commit**

Run : `swift test --package-path Packages/PulseRecoveryEngine` → tous passés.
```bash
git add Packages/PulseRecoveryEngine
git commit -m "feat(engine): add training load and ACWR calculator"
```

---

### Task 7 : Scénarios JSON

**Files:**
- Create: `Packages/PulseRecoveryEngine/Tests/PulseRecoveryEngineTests/Fixtures/scenario-bonne-nuit.json`, `scenario-mauvaise-nuit.json`, `scenario-vfc-manquante.json`, `scenario-huit-nuits.json`, `scenario-trois-nuits.json`, `scenario-sans-donnees.json`
- Create: `Packages/PulseRecoveryEngine/Sources/PulseRecoveryEngine/Recovery/RecoveryScenario.swift`
- Test: `Packages/PulseRecoveryEngine/Tests/PulseRecoveryEngineTests/ScenarioTests.swift`
- Modify: `Packages/PulseRecoveryEngine/Package.swift` (ajouter `resources: [.copy("Fixtures")]` à la cible de tests)

**Interfaces:**
- Produces : `public struct RecoveryScenario: Codable, Sendable { public var name: String; public var day: Date; public var history: [NightSample]; public var today: NightSample; public var expected: Expected; public struct Expected: Codable, Sendable { public var outcome: String /* "measured" | "needsCheckIn" */; public var category: RecoveryCategory?; public var score: Double?; public var calibration: String? /* "ready" | "calibrating:8" */; public var missing: [Factor] } ; public static func load(named: String, from bundle: Bundle) throws -> RecoveryScenario }`. Les dates sont encodées en `"YYYY-MM-DD"` et décodées à minuit **Europe/Paris** (décodeur fourni par `RecoveryScenario.decoder`). Ce type est public car le fournisseur HealthKit factice (M3) rejouera ces scénarios.

Contenu des scénarios (les quatre premiers partagent l'historique « 14 nuits du 6 au 19 novembre 2026, sdnn alternant 51 et 49 en commençant par 51 le 19, FC repos 50, 450 min de sommeil dont 90 profond ») :

| Fichier | Aujourd'hui (20 nov. 2026) | Attendu |
| :--- | :--- | :--- |
| bonne-nuit | sdnn 60, FC 49, 480 min dont 100 | measured, optimal, 100, ready, missing [] |
| mauvaise-nuit | sdnn 35, FC 56, 330 min dont 33 | measured, overreached, 33.03125, ready, [] |
| vfc-manquante | sdnn null, FC 52, 420 min dont 84 | measured, normal, 87.125, ready, [hrv] |
| huit-nuits | historique réduit aux 8 nuits du 12 au 19, sdnn 50 constant, 480 min dont 96 ; aujourd'hui sdnn 50, FC 50, 480 dont 96 | measured, optimal, 95, calibrating:8, [] |
| trois-nuits | historique 17 au 19, sdnn 50, FC 50, 450 dont 90 ; aujourd'hui identique | measured, optimal, 97.8125, calibrating:3, [hrv] |
| sans-donnees | historique vide ; aujourd'hui tout null | needsCheckIn, missing [hrv, restingHeartRate, sleep] |

- [ ] **Step 1 : Écrire le test paramétré**

```swift
@Test(arguments: ["bonne-nuit", "mauvaise-nuit", "vfc-manquante", "huit-nuits", "trois-nuits", "sans-donnees"])
func scenarioMatchesExpectation(name: String) throws {
    let s = try RecoveryScenario.load(named: "scenario-\(name)", from: .module)
    let outcome = RecoveryCalculator(calendar: TestCalendar.paris).compute(day: s.day, today: s.today, history: s.history)
    switch (s.expected.outcome, outcome) {
    case ("measured", .measured(let r)):
        #expect(r.category == s.expected.category)
        #expect(abs(r.score - s.expected.score!) < 1e-6)
        #expect(r.missing == s.expected.missing)
        #expect(describe(r.calibration) == s.expected.calibration)
    case ("needsCheckIn", .needsCheckIn(let missing)):
        #expect(missing == s.expected.missing)
    default:
        Issue.record("outcome inattendu pour \(name): \(outcome)")
    }
}
```
`describe(_:)` rend `"ready"` ou `"calibrating:N"`.

- [ ] **Step 2 : Écrire les six JSON et `RecoveryScenario.swift`, lancer**

Run : `swift test --package-path Packages/PulseRecoveryEngine --filter ScenarioTests`
Expected : les six scénarios passent. Si un scénario échoue, c'est la fixture ou le calculateur qui a tort, jamais la valeur attendue de ce tableau : elle est calculée à la main depuis les formules.

- [ ] **Step 3 : Commit**

```bash
git add Packages/PulseRecoveryEngine
git commit -m "test(engine): add recovery scenarios as reusable JSON fixtures"
```

---

### Task 8 : Agrégation des nuits

**Files:**
- Create: `Packages/PulseRecoveryEngine/Sources/PulseRecoveryEngine/Aggregation/NightAggregator.swift`
- Test: `Packages/PulseRecoveryEngine/Tests/PulseRecoveryEngineTests/NightAggregatorTests.swift`

**Interfaces:**
- Produces : `public struct NightAggregator: Sendable { public init(calendar: Calendar); public func night(for day: Date, sdnn: [TimedSample], restingHeartRate: [TimedSample], sleep: [SleepInterval]) -> NightSample; public func nights(days: [Date], sdnn:restingHeartRate:sleep:) -> [NightSample] }`

Règles (`day` = minuit local du jour de réveil) :
- Fenêtre candidate de la nuit : de `calendar.date(byAdding: .hour, value: -6, to: day)` (18 h la veille) à `calendar.date(byAdding: .hour, value: 12, to: day)` (midi). Intervalles retenus : `stage.isAsleep` et `end` dans cette fenêtre.
- **Fusion** : les intervalles retenus sont fusionnés en union (tri par début, fusion des chevauchements) avant de sommer `asleepMinutes` ; `deepMinutes` = union des seuls intervalles `deep`. `deepMinutes = nil` si aucun intervalle retenu n'a un stage parmi `core, deep, rem`. `sleep = nil` si aucun intervalle retenu.
- Fenêtre SDNN : `[début du premier intervalle fusionné, fin du dernier]` ; sans sommeil, `[day, day + 8 h]` (via le calendrier). SDNN = moyenne des échantillons dans la fenêtre dont la valeur est dans `]0, 300]` ; `nil` s'il n'y en a aucun.
- FC repos : dernier échantillon dont la date est dans `[day, day + 1 jour)` ; `nil` sinon.
- Les minutes sont arrondies à l'entier le plus proche.

- [ ] **Step 1 : Écrire les tests**

```swift
@Test func typicalNight() {
    let d = TestCalendar.date
    let sleep = [SleepInterval(start: d(2026,11,19,23,10), end: d(2026,11,20,1,0), stage: .core),
                 .init(start: d(2026,11,20,1,0), end: d(2026,11,20,2,30), stage: .deep),
                 .init(start: d(2026,11,20,2,30), end: d(2026,11,20,3,30), stage: .rem),
                 .init(start: d(2026,11,20,3,30), end: d(2026,11,20,3,40), stage: .awake),
                 .init(start: d(2026,11,20,3,40), end: d(2026,11,20,6,50), stage: .core)]
    let sdnn = [TimedSample(date: d(2026,11,19,22,0), value: 40), .init(date: d(2026,11,20,0,30), value: 48),
                .init(date: d(2026,11,20,2,0), value: 52), .init(date: d(2026,11,20,5,0), value: 50), .init(date: d(2026,11,20,9,0), value: 70)]
    let rhr = [TimedSample(date: d(2026,11,20,10,0), value: 49)]
    let n = NightAggregator(calendar: TestCalendar.paris).night(for: TestCalendar.day(2026,11,20), sdnn: sdnn, restingHeartRate: rhr, sleep: sleep)
    #expect(n == NightSample(day: TestCalendar.day(2026,11,20), sdnnMs: 50, restingHeartRate: 49, sleep: .init(asleepMinutes: 450, deepMinutes: 90)))
}
@Test func noSleepFallsBackToMidnightToEight() { /* sdnn 00:30=48, 05:00=50, 09:00=70 → 49 ; sleep nil */ }
@Test func unspecifiedSleepHasNoDeepMinutes() { /* asleepUnspecified 23:00→07:00 → 480, deep nil */ }
@Test func overlappingSourcesAreMergedNotSummed() { /* deux fois les intervalles de typicalNight → 450 et 90, pas 900 */ }
@Test func dstNightUsesCalendar() {
    // nuit du 24 au 25 octobre 2026 (retour à l'heure d'hiver, 3 h → 2 h) : un intervalle .core de 23:00 (24 oct.) à 07:00 (25 oct.) heure locale
    // attendu : asleepMinutes == 540 (la nuit dure 9 h réelles) ; un échantillon SDNN daté « 23:00 + 3 h 30 » (02:30 heure d'hiver) est inclus dans la moyenne
}
@Test func outOfRangeSDNNIgnored() { /* échantillons 0 et 350 dans la fenêtre, plus 50 → sdnn 50 ; seulement 0 et 350 → nil */ }
@Test func restingHeartRateOutsideDayIsNil() { /* échantillon la veille à 23:00 → restingHeartRate nil */ }
```

- [ ] **Step 2 : Lancer pour vérifier l'échec, implémenter, relancer**

Run : `swift test --package-path Packages/PulseRecoveryEngine --filter NightAggregatorTests`
Expected après implémentation : tous les tests passent.

- [ ] **Step 3 : Commit**

```bash
git add Packages/PulseRecoveryEngine
git commit -m "feat(engine): aggregate HealthKit samples into night samples"
```

---

### Task 9 : Package `PulseHealth`

**Files:**
- Create: `Packages/PulseHealth/Package.swift` (dépend de `../PulseDomain` ; `platforms: [.iOS(.v26)]` seulement)
- Create: `Packages/PulseHealth/Sources/PulseHealth/HealthDataType.swift`
- Create: `Packages/PulseHealth/Sources/PulseHealth/HealthReading.swift`
- Create: `Packages/PulseHealth/Sources/PulseHealth/HealthKitReader.swift`
- Create: `Packages/PulseHealth/Sources/PulseHealth/StubHealthReader.swift`
- Modify: `Pulse/Info.plist` (clés d'usage), `Pulse/Pulse.entitlements` (capacité HealthKit)

**Interfaces:**
- Produces :
  - `public enum HealthDataType: String, CaseIterable, Sendable, Identifiable { case sleepAnalysis, hrvSDNN, restingHeartRate, heartRate, runningWorkouts, bodyMass; public var title: String }` (titres français : « Sommeil », « VFC (SDNN) », « FC au repos », « Fréquence cardiaque », « Courses », « Poids »).
  - `public struct HealthSamplePoint: Sendable, Equatable { public let type: HealthDataType; public let date: Date; public let valueText: String; public let sourceName: String; public let sourceBundleID: String }`
  - `public protocol HealthReading: Sendable { func requestReadAuthorization() async throws; func latestSample(of type: HealthDataType) async throws -> HealthSamplePoint?; func sampleCount(of type: HealthDataType, from: Date, to: Date) async throws -> Int; func sdnnSamples(from: Date, to: Date) async throws -> [TimedSample]; func restingHeartRateSamples(from: Date, to: Date) async throws -> [TimedSample]; func sleepIntervals(from: Date, to: Date) async throws -> [SleepInterval] }`
  - `public final class HealthKitReader: HealthReading, @unchecked Sendable { public init(store: HKHealthStore = HKHealthStore()); public static var isAvailable: Bool }` (`HKHealthStore` est thread-safe, d'où `@unchecked`).
  - `public struct StubHealthReader: HealthReading { public init(latest: [HealthDataType: HealthSamplePoint] = [:], counts: [HealthDataType: Int] = [:], sdnn: [TimedSample] = [], restingHeartRate: [TimedSample] = [], sleep: [SleepInterval] = [], error: (any Error)? = nil) }` — si `error` est non nul, chaque méthode le lance ; `sampleCount` retourne `counts[type] ?? 0` sans tenir compte des bornes ; les méthodes de séries filtrent sur `[from, to]`.

Correspondances HealthKit : `sleepAnalysis` → `HKCategoryType(.sleepAnalysis)` ; `hrvSDNN` → `HKQuantityType(.heartRateVariabilitySDNN)` en `HKUnit.secondUnit(with: .milli)` ; `restingHeartRate` et `heartRate` en `count/min` ; `runningWorkouts` → `HKWorkoutType` filtré `activityType == .running` ; `bodyMass` en `gramUnit(with: .kilo)`. Stages : `.inBed → inBed`, `.awake → awake`, `.asleepUnspecified → asleepUnspecified`, `.asleepCore → core`, `.asleepDeep → deep`, `.asleepREM → rem`. `valueText` : valeur formatée avec unité (« 52 ms », « 49 bpm », « 7 h 30 », « 5,2 km », « 78,4 kg »). `sourceName = sample.sourceRevision.source.name`, `sourceBundleID = sample.sourceRevision.source.bundleIdentifier`. Les requêtes utilisent `HKSampleQueryDescriptor` (API async) ; la source vient de l'échantillon lui-même.

- [ ] **Step 1 : Créer le package et écrire les types `HealthDataType`, `HealthSamplePoint`, `HealthReading`, `StubHealthReader`**

- [ ] **Step 2 : Écrire `HealthKitReader`**

`requestReadAuthorization()` demande la lecture des six types. Toute erreur HealthKit est relancée telle quelle.

- [ ] **Step 3 : Ajouter la capacité et les textes d'usage**

Xcode > cible `Pulse` > Signing & Capabilities > + HealthKit (sans Clinical Health Records, avec Background Delivery coché pour M3). Dans `Info.plist` :
- `NSHealthShareUsageDescription` : « Pulse lit votre sommeil, votre variabilité cardiaque et votre fréquence cardiaque au repos pour calculer votre score de récupération du matin. Ces données restent sur votre iPhone. »
- `NSHealthUpdateUsageDescription` : « Pulse enregistre vos séances de musculation et vos prises de compléments dans Apple Santé. »

- [ ] **Step 4 : Ajouter le package au projet et compiler**

File > Add Package Dependencies > Add Local > `Packages/PulseHealth` et `Packages/PulseRecoveryEngine`. Lier les deux à la cible `Pulse`. Edit Scheme > Test > ajouter `PulseRecoveryEngineTests`.

Run : `xcodebuild build -scheme Pulse -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected : `** BUILD SUCCEEDED **`.

- [ ] **Step 5 : Commit**

```bash
git add Packages/PulseHealth Pulse Pulse.xcodeproj
git commit -m "feat(health): add HealthKit reader behind HealthReading protocol"
```

---

### Task 10 : Écran de diagnostic et score provisoire

**Files:**
- Create: `Pulse/AppDependencies.swift`
- Create: `Pulse/Diagnostics/HealthDiagnosticsModel.swift`
- Create: `Pulse/Diagnostics/HealthDiagnosticsView.swift`
- Modify: `Pulse/PulseApp.swift`
- Test: `PulseTests/HealthDiagnosticsModelTests.swift`

**Interfaces:**
- Consumes : `HealthReading`, `StubHealthReader`, `NightAggregator`, `RecoveryCalculator`, `RecoveryOutcome`.
- Produces :
  - `struct AppDependencies: Sendable { let health: any HealthReading; let calendar: Calendar; static func live() -> AppDependencies; static func preview() -> AppDependencies }` — `live()` utilise `HealthKitReader` si `HealthKitReader.isAvailable`, sinon un `StubHealthReader` vide.
  - `struct DiagnosticRow: Identifiable, Equatable { let type: HealthDataType; var id: HealthDataType { type }; let latest: HealthSamplePoint?; let countLast60Days: Int }`
  - `@MainActor @Observable final class HealthDiagnosticsModel { init(dependencies: AppDependencies, today: Date = .now); private(set) var rows: [DiagnosticRow]; private(set) var nights: [NightSample]; private(set) var outcome: RecoveryOutcome?; private(set) var errorMessage: String?; private(set) var isLoading: Bool; func refresh() async }`
    - `refresh()` : demande l'autorisation, lit les 60 derniers jours (SDNN, FC repos, sommeil), construit les `nights` pour les 60 jours de réveil se terminant aujourd'hui via `NightAggregator.nights`, calcule `outcome` avec `day = startOfDay(today)`, `today = nights.last`, `history = nights.dropLast()`, remplit `rows` pour chaque `HealthDataType`. Toute erreur est rendue dans `errorMessage` (texte français, sans valeur de santé) et les sections déjà chargées restent affichées.
  - `struct HealthDiagnosticsView: View { init(model: HealthDiagnosticsModel) }` : `List` avec quatre sections : « État » (chargement ou erreur, bouton « Relire Apple Santé »), « Sources » (une ligne par `DiagnosticRow` : titre, `valueText`, date relative, `sourceName`, compte sur 60 jours ; « Aucune donnée » si `latest == nil`), « 14 dernières nuits » (date, sdnn, FC, sommeil et profond, tirets si nil), « Score provisoire » (score arrondi, catégorie en français, état de calibration, facteurs manquants ; ou « Check-in nécessaire : … »). Aucun style particulier : le design system arrive en M3.

- [ ] **Step 1 : Écrire le test du modèle (dans `PulseTests`, exécuté sur simulateur)**

```swift
import Testing
import Foundation
import PulseDomain
import PulseHealth
@testable import Pulse

@MainActor
@Test func refreshBuildsRowsNightsAndOutcome() async {
    let cal = Calendar.current
    let today = cal.startOfDay(for: .now)
    // 20 nuits : pour i dans 0..<20, sommeil 23:00 (jour-i-1) → 07:00 (jour-i) en .core, un échantillon SDNN à 03:00 de 50 ms, FC repos 50 à 10:00
    let stub = StubHealthReader(/* construire à partir de la description ci-dessus ; latest et counts pour .hrvSDNN seulement */)
    let model = HealthDiagnosticsModel(dependencies: .init(health: stub, calendar: cal), today: today)
    await model.refresh()
    #expect(model.rows.count == HealthDataType.allCases.count)
    #expect(model.rows.first { $0.type == .hrvSDNN }?.countLast60Days == 20)
    #expect(model.nights.count == 60)
    #expect(model.nights.last?.sdnnMs == 50)
    guard case .measured(let r)? = model.outcome else { Issue.record("expected measured"); return }
    #expect(r.calibration == .ready)
    #expect(r.missing.isEmpty)
    #expect(model.errorMessage == nil)
}

@MainActor
@Test func refreshSurfacesErrorsWithoutCrashing() async {
    struct Boom: Error {}
    let model = HealthDiagnosticsModel(dependencies: .init(health: StubHealthReader(error: Boom()), calendar: .current))
    await model.refresh()
    #expect(model.errorMessage != nil)
    #expect(model.isLoading == false)
    #expect(model.outcome == nil)
}
```

- [ ] **Step 2 : Lancer pour vérifier l'échec**

Run : `xcodebuild test -scheme Pulse -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:PulseTests -quiet`
Expected : échec de compilation sur `HealthDiagnosticsModel`.

- [ ] **Step 3 : Implémenter `AppDependencies`, `HealthDiagnosticsModel`, `HealthDiagnosticsView`, et faire de la vue la racine de `PulseApp`**

`PulseApp` : `WindowGroup { HealthDiagnosticsView(model: HealthDiagnosticsModel(dependencies: .live())) }` avec `.task { await model.refresh() }` dans la vue.

- [ ] **Step 4 : Lancer les tests**

Run : `xcodebuild test -scheme Pulse -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected : `** TEST SUCCEEDED **` (tests des trois packages + `PulseTests`).

- [ ] **Step 5 : Essai sur l'iPhone de Mathéo**

Brancher l'iPhone, sélectionner la destination, Run. Accepter la modale Apple Santé en autorisant tout. Vérifier que la section « Sources » montre, pour sommeil, SDNN et FC repos, une valeur, une date récente et le nom de l'app source. Noter le résultat dans `docs/superpowers/plans/2026-10-31-pulse-m1-fondations-moteur.md` sous « Résultat du diagnostic » (section à ajouter en fin de fichier) : pour chaque type, source, fréquence, présence des phases de sommeil, présence de SDNN pendant la nuit.

- [ ] **Step 6 : Commit**

```bash
git add Pulse PulseTests Pulse.xcodeproj docs/superpowers/plans/2026-10-31-pulse-m1-fondations-moteur.md
git commit -m "feat(app): add Apple Health diagnostics screen with provisional recovery score"
```

---

### Task 11 : Lint, Makefile, Xcode Cloud, TestFlight

**Files:**
- Create: `.swiftlint.yml`, `Makefile`, `ci_scripts/ci_post_clone.sh`

**Interfaces:**
- Produces : `make test` (tout), `make test-packages` (rapide, sur le Mac), `make lint`.

- [ ] **Step 1 : Écrire `.swiftlint.yml`**

```yaml
included: [Pulse, PulseTests, PulseWidgets, Packages]
excluded: [Packages/*/.build, DerivedData]
opt_in_rules: [force_unwrapping, implicitly_unwrapped_optional, sorted_imports, closure_spacing, empty_count]
line_length: { warning: 140, error: 180 }
file_length: { warning: 400, error: 600 }
function_body_length: { warning: 50, error: 80 }
identifier_name: { min_length: 2, excluded: [id, x, y, z, i, n, r, d] }
```

- [ ] **Step 2 : Écrire `Makefile`**

```make
DEST = platform=iOS Simulator,name=iPhone 17
.PHONY: test test-packages test-app lint
test: lint test-packages test-app
test-packages:
	swift test --package-path Packages/PulseDomain
	swift test --package-path Packages/PulseRecoveryEngine
test-app:
	xcodebuild test -scheme Pulse -destination '$(DEST)' -quiet
lint:
	swiftlint lint --strict
```

- [ ] **Step 3 : Installer SwiftLint, corriger les avertissements, vérifier**

Run : `brew install swiftlint && make test`
Expected : lint sans erreur, tous les tests verts.

- [ ] **Step 4 : Écrire `ci_scripts/ci_post_clone.sh`**

```bash
#!/bin/sh
set -e
brew install swiftlint
cd "$CI_PRIMARY_REPOSITORY_PATH"
swiftlint lint --strict
```
`chmod +x ci_scripts/ci_post_clone.sh`.

- [ ] **Step 5 : Créer le workflow Xcode Cloud**

Xcode > Product > Xcode Cloud > Create Workflow. Produit `Pulse`. Accorder l'accès au dépôt GitHub `D-Seonay/fitness`. Workflow « CI » : démarrage sur changement de n'importe quelle branche ; action **Test** avec le schéma `Pulse` sur « iPhone 17 » ; environnement Xcode 26 ; post-action **TestFlight Internal Testing** uniquement quand la branche est `master`, groupe « Mathéo ». Pousser la branche courante pour déclencher (après accord de Mathéo).

Expected : la première exécution est verte dans App Store Connect > Xcode Cloud, et un build apparaît dans TestFlight.

- [ ] **Step 6 : Installer depuis TestFlight sur l'iPhone et refaire le diagnostic**

Expected : même résultat qu'en tâche 10 étape 5.

- [ ] **Step 7 : Commit**

```bash
git add .swiftlint.yml Makefile ci_scripts
git commit -m "chore: add SwiftLint, Makefile and Xcode Cloud post-clone script"
```

---

## Sortie du jalon

M1 est fini quand :
- `make test` est vert localement et dans Xcode Cloud ;
- l'app TestFlight affiche sur l'iPhone de Mathéo les sources Apple Santé et un score provisoire ;
- la section « Résultat du diagnostic » ci-dessous est remplie et dit si la SDNN nocturne, les phases de sommeil et la FC repos arrivent de Fitbit, à quelle heure, et avec quelle régularité.

Cette section décide d'un point du plan M3 : si la SDNN nocturne n'arrive pas ou arrive trop tard le matin, le facteur VFC sera traité comme souvent absent et l'écran du matin devra être conçu pour le score à deux facteurs.

## Résultat du diagnostic

_À remplir en tâche 10, étape 5._
