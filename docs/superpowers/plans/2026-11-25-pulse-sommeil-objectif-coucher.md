# Objectif de sommeil et rappel de coucher — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** un objectif de sommeil et des heures de réveil réglables, dont Pulse déduit un coucher conseillé ; un rappel de coucher par soir, contextualisé ; l'objectif pris en compte dans le score ; l'écart à l'objectif et la régularité du coucher sur l'écran Nuit.

**Architecture :** cinq champs de plus dans `UserProfile` (schéma V8). Un type pur `SleepPlan` (PulseServices) calcule le coucher conseillé et l'heure du rappel ; un planificateur pur produit les rappels des 7 prochains soirs, qu'un service remet à `UserNotificationScheduler`, sur le modèle des rappels de compléments. `SleepScorer` reçoit la cible en paramètre, passée depuis le profil par `DayRefresher`.

**Tech stack :** Swift 6.2, SwiftUI, SwiftData + CloudKit, UserNotifications, Swift Testing, iOS 26.

**Spec :** `docs/superpowers/specs/2026-11-25-pulse-sommeil-objectif-coucher-design.md`

## Global Constraints

- iOS 26 minimum ; `swiftLanguageMode(.v6)` ; `swiftlint lint --strict` passe.
- Textes en français via `String(localized: "…", bundle: .module)` ; chaque nouvelle clé est ajoutée au `Resources/Localizable.xcstrings` de son module, comme les clés voisines.
- **Rappel désactivé par défaut** : `bedtimeReminderEnabled` vaut `false` ; aucun utilisateur existant ne reçoit de rappel sans l'avoir activé.
- **Un seul rappel de coucher par soir**, jamais dans le passé, jamais hors de la plage 18 h (le soir même) à 3 h (le lendemain).
- **L'historique ne change pas** : seul le score du jour, tant qu'il n'est pas figé, suit un changement d'objectif.
- **Frontière M8** : une heure tirée d'Apple Santé (réveil habituel, régularité, écart) n'est jamais écrite dans le profil ni ailleurs. « Selon mes nuits » laisse le champ à `nil`.
- Objectif de 360 à 600 min par pas de 15 ; réveil de 240 à 720 min après minuit par pas de 5 ; avance du rappel parmi 15, 30, 45, 60 ; temps d'endormissement 15 min.
- Les heures s'écrivent `HH:mm` sur deux chiffres (« 22:45 », « 00:45 », « 07:00 »), comme sur l'écran Nuit ; les durées comme `PulseFormat.duration` (« 8 h », « 6 h 10 », « 25 min »).
- Ton du conseil : « vise », jamais « il faut » ; aucun vocabulaire médical.
- La part de sommeil profond du score et les rappels de compléments ne changent pas.
- **Le simulateur n'est jamais lancé** : ni `make test`, ni `make test-app`, ni `xcodebuild test`. La vérification passe par `swift test --package-path …`, `make lint`, `make build-app` et `make build-release`. Les tests de la cible `PulseTests` sont écrits et compilés (`make build-app`), pas lancés.
- Avant chaque commit : `git branch --show-current` doit dire `sommeil-objectif-coucher`, et `git status` ne doit laisser aucun nouveau fichier de la tâche hors de l'index. Aucun trailer `Co-Authored-By`.

## Review Focus

1. **Objectif hors bornes venu d'iCloud** (0, négatif, 2000) : le score ne divise jamais par zéro et ne vaut jamais 100 pour rien ; `SleepGoal.minutes(of:)` ramène la valeur dans 360…600 (test en tâche 1, utilisé en tâche 2).
2. **Profil illisible** : le score du jour déjà enregistré est gardé, il ne retombe pas sur 8 h ; les rappels en attente ne sont pas effacés (tests en tâches 2 et 5).
3. **Passage de minuit et week-end** : le coucher du vendredi soir suit le réveil du samedi ; un rappel à 00:15 le samedi appartient au soir du vendredi et n'en double pas un autre (tests en tâches 4 et 5).
4. **Ni réveil choisi ni nuits mesurées** (pas de montre, première semaine) : aucun rappel, les réglages invitent à choisir une heure, l'écran Nuit n'affiche pas la régularité, rien ne plante (tests en tâches 4, 5, 7 et 8).
5. **Objectif changé après midi** : le score figé ne bouge pas ; avant midi, il est recalculé une fois, sans réécriture en boucle (tests en tâche 2).

---

### Task 1 : les réglages dans le profil (schéma V8, export)

**Files :**
- Create : `Packages/PulseDomain/Sources/PulseDomain/Recovery/SleepGoal.swift`
- Modify : `Packages/PulseDomain/Sources/PulseDomain/Training/UserProfile.swift`
- Modify : `Packages/PulsePersistence/Sources/PulsePersistence/Models/StoredProfile.swift`
- Modify : `Packages/PulsePersistence/Sources/PulsePersistence/Schema/PulseSchemaV2.swift`, `PulseSchemaV4.swift`, `PulseSchemaV5.swift`, `PulseSchemaV6.swift`, `PulseSchemaV7.swift` (copie figée du profil)
- Create : `Packages/PulsePersistence/Sources/PulsePersistence/Schema/PulseSchemaV8.swift`
- Modify : `PulseMigrationPlan.swift`, `PersistenceStack.swift:59`
- Modify : `Packages/PulsePersistence/Sources/PulsePersistence/Export/CSVColumns+Training.swift`
- Create : `Packages/PulsePersistence/Tests/PulsePersistenceTests/Fixtures/schema-v8.txt` (généré)
- Test : `Packages/PulseDomain/Tests/PulseDomainTests/SleepGoalTests.swift` (nouveau), `SchemaFingerprintTests.swift`, `PersistenceStackTests.swift`, `OtherMappingTests.swift`, `ProfileRepositoryTests.swift`, `CSVExportTests.swift`

**Interfaces :**
- Produces (PulseDomain) :
  - `public enum SleepGoal` : `static let defaultMinutes = 480`, `static let range = 360...600`, `static let stepMinutes = 15`, `static let shortNightMarginMinutes = 60`,
    `static func minutes(of profile: UserProfile?) -> Int` (la valeur du profil ramenée dans `range`, `defaultMinutes` sans profil ou sans valeur),
    `static func isShortNight(asleepMinutes: Int, goalMinutes: Int) -> Bool` (`asleepMinutes < goalMinutes - shortNightMarginMinutes` : strictement, pour que 7 h pile ne soit pas « courte » à l'objectif par défaut, comme aujourd'hui).
  - `UserProfile` gagne, après `restTimerNotificationEnabled` et dans cet ordre : `sleepGoalMinutes: Int?`, `weekdayWakeMinutes: Int?`, `weekendWakeMinutes: Int?`, `bedtimeReminderEnabled: Bool`, `bedtimeReminderLeadMinutes: Int?`. Paramètres d'init au même endroit, par défaut `nil`, `nil`, `nil`, `false`, `nil`.
- Produces (PulsePersistence) : `StoredProfile` gagne les cinq attributs (`bedtimeReminderEnabled: Bool = false`, les autres optionnels) ; `PulseSchemaV8` ; colonnes CSV `sleep_goal_minutes`, `weekday_wake_minutes`, `weekend_wake_minutes`, `bedtime_reminder_enabled`, `bedtime_reminder_lead_minutes`, juste après `rest_timer_notification_enabled`.

- [ ] **Step 1 : écrire les tests qui échouent.**
  - `SleepGoalTests` :
    ```swift
    @Test func goalDefaultsToEightHours()       // minutes(of: nil) == 480 ; profil sans valeur == 480
    @Test func goalIsClampedToItsRange()        // 0 → 360, -30 → 360, 2000 → 600, 420 → 420
    @Test func shortNightIsOneHourUnderTheGoal()
    // (419, 480) true ; (420, 480) false ; (359, 420) true ; (360, 420) false
    ```
  - `SchemaFingerprintTests` : `v8SchemaMatchesItsFingerprint()` (fixture `schema-v8`) et `v8OnlyAddsTheFiveSleepSettings()` :
    ```swift
    #expect(v7.subtracting(v8).isEmpty)
    #expect(Set(added.compactMap { $0.split(separator: ":").first.map(String.init) })
        == ["StoredProfile.bedtimeReminderEnabled", "StoredProfile.bedtimeReminderLeadMinutes",
            "StoredProfile.sleepGoalMinutes", "StoredProfile.weekdayWakeMinutes", "StoredProfile.weekendWakeMinutes"])
    ```
    Les tests `v2…v7SchemaMatchesItsFingerprint` restent intacts : ils prouvent que la copie figée est fidèle.
  - `PersistenceStackTests` : `PulseSchemaV8.versionIdentifier == Schema.Version(8, 0, 0)`. `OtherMappingTests` : `PulseSchemaV8.models.count == 25`.
  - `ProfileRepositoryTests` : `saveKeepsTheSleepSettings()` enregistre un profil avec 450, 420, 540, `true`, 45 et les relit ; un profil neuf relit `nil`, `nil`, `nil`, `false`, `nil`.
  - `CSVExportTests` : l'en-tête de `profile.csv` contient les cinq colonnes à la suite, après `rest_timer_notification_enabled`.

- [ ] **Step 2 : lancer et vérifier l'échec.** `swift test --package-path Packages/PulseDomain --filter SleepGoalTests` et `swift test --package-path Packages/PulsePersistence` → échecs de compilation (`SleepGoal`, `PulseSchemaV8` inconnus).

- [ ] **Step 3 : implémenter.**
  - `SleepGoal` et les cinq champs de `UserProfile`.
  - `extension PulseSchemaV7 { @Model public final class StoredProfile { … } }` : la copie des attributs actuels de `StoredProfile` (de `id` à `deletedAt`), avec `public init() {}` et le commentaire « Copie figée de `StoredProfile` en V7 : ne pas modifier. ».
  - `PulseSchemaV7` reçoit `static let syncedModels` : les 17 modèles de `PersistenceStack.syncedModels` avec `PulseSchemaV7.StoredProfile.self` à la place de `StoredProfile.self`, et `models = syncedModels + PersistenceStack.localModels`. `PulseSchemaV6.models` prend `PulseSchemaV7.syncedModels + localModels`. Dans `PulseSchemaV2.models`, `PulseSchemaV4.syncedModels` et `PulseSchemaV5.syncedModels`, remplacer le profil par `PulseSchemaV7.StoredProfile.self`. Mettre à jour les commentaires « figés en… ».
  - `PulseSchemaV8` (version 8.0.0, `models = PersistenceStack.syncedModels + PersistenceStack.localModels`), commentaire d'en-tête dans le style des précédents ; étape `.lightweight(fromVersion: PulseSchemaV7.self, toVersion: PulseSchemaV8.self)` ; `PersistenceStack.swift:59` passe sur `PulseSchemaV8`.
  - `StoredProfile` : les cinq attributs, dans `apply` et `toDomain`.
  - Les cinq colonnes CSV. L'export JSON encode `UserProfile` tel quel.

- [ ] **Step 4 : générer la fixture et lancer les tests.**
  - `PULSE_WRITE_SCHEMA_FIXTURES=1 swift test --package-path Packages/PulsePersistence --filter v8SchemaMatchesItsFingerprint`
  - `diff Packages/PulsePersistence/Tests/PulsePersistenceTests/Fixtures/schema-v7.txt Packages/PulsePersistence/Tests/PulsePersistenceTests/Fixtures/schema-v8.txt` → exactement cinq lignes ajoutées, toutes `StoredProfile.…`.
  - `swift test --package-path Packages/PulseDomain` et `swift test --package-path Packages/PulsePersistence` → tout passe, `MigrationTests` compris.

- [ ] **Step 5 : commit.**
```bash
git add Packages/PulseDomain Packages/PulsePersistence
git commit -m "feat(persistence): sleep goal, wake times and bedtime reminder settings in the profile (schema V8), exported"
```

---

### Task 2 : l'objectif dans le score et dans « Pourquoi »

**Files :**
- Modify : `Packages/PulseRecoveryEngine/Sources/PulseRecoveryEngine/Scoring/SleepScorer.swift`
- Modify : `Packages/PulseRecoveryEngine/Sources/PulseRecoveryEngine/Recovery/RecoveryCalculator.swift`
- Modify : `Packages/PulseFeatures/Sources/PulseServices/Planning/AntiInterference.swift:110`
- Modify : `Packages/PulseFeatures/Sources/PulseServices/Score/DailyScoreService.swift`
- Modify : `Packages/PulseFeatures/Sources/PulseServices/Refresh/DayRefresher.swift` (appel de `scores.update`)
- Modify : `Packages/PulseFeatures/Sources/TodayFeature/Why/WhyReading.swift`, `WhyContent.swift`, `Packages/PulseFeatures/Sources/TodayFeature/TodayModel.swift:215`
- Modify : `Packages/PulseFeatures/Sources/TodayFeature/Trends/TrendTile.swift` (commentaire « cibles fixes (8 h…) » à corriger)
- Test : `SleepScorerTests.swift`, `RecoveryCalculatorTests.swift`, `AntiInterferenceTests.swift`, `DailyScoreServiceTests.swift`, `DayRefresherTests.swift`, `Packages/PulseFeatures/Tests/TodayFeatureTests/WhyContentTests.swift`

**Interfaces :**
- Consumes : `SleepGoal` (tâche 1).
- Produces :
  - `SleepScorer.score(asleepMinutes: Int, deepMinutes: Int?, targetMinutes: Int = SleepGoal.defaultMinutes) -> Double` ; la constante `targetMinutes` disparaît.
  - `RecoveryCalculator.compute(day:today:history:sleepGoalMinutes: Int = SleepGoal.defaultMinutes) -> RecoveryOutcome`.
  - `DailyScoreService.update(nights: [NightSample], plannedDay: PlannedDay?, sleepGoalMinutes: Int?, now: Date) async throws -> TodayScore` ; `nil` veut dire « profil illisible ».
  - `WhyReading.make(recovery:session:sleepGoalMinutes: Int = SleepGoal.defaultMinutes)`, de même `spokenText` ; `WhyContent.make(…, sleepGoalMinutes: Int = SleepGoal.defaultMinutes)`.

- [ ] **Step 1 : écrire les tests qui échouent.**
  - `SleepScorerTests` :
    ```swift
    @Test func targetDrivesTheWholeScoreWithoutStages()
    // (420, nil, target 420) == 100 ; (420, nil) == 87.5 ; (210, nil, target 420) == 50
    @Test func targetDrivesSeventyPointsWithStages()
    // (420, deep 84, target 420) == 100 ; (390, deep 39, target 420) == 80 ; (420, deep 84) == 91.25
    @Test func sleepingPastTheTargetIsCapped()   // (600, nil, target 420) == 100
    ```
  - `RecoveryCalculatorTests` : `sleepGoalChangesTheSleepFactor()` — même nuit de 420 min sans phases, facteur sommeil à 87.5 par défaut et à 100 avec `sleepGoalMinutes: 420`.
  - `AntiInterferenceTests` : `restDayRuleFollowsTheSleepGoal()` — 7 jours avec séance, 7 nuits de 300 min sans phases : `needsRestDay` vrai avec un profil sans objectif (62,5 < 65), faux avec `sleepGoalMinutes = 360` (83,3).
  - `DailyScoreServiceTests` (reprendre les aides du fichier) :
    ```swift
    @Test func goalChangeRecomputesBeforeNoon()
    // 09:00 goal 480 puis 09:30 goal 420, mêmes nuits : le facteur sommeil passe de 87.5 à 100, même id, une écriture de plus
    @Test func sameGoalDoesNotRewriteTheScore()      // deux passages goal 420 : une seule écriture
    @Test func goalChangeIsIgnoredOnceFrozen()
    // score écrit à 09:00 (480), passage à 13:00 avec 420 : score inchangé, frozenAt posé
    @Test func unreadableProfileKeepsTheStoredScore()
    // score écrit à 09:00 avec 420, passage à 10:00 avec nil : le même score rendu, aucune écriture
    @Test func unreadableProfileWithoutScoreUsesTheDefault()   // nil, rien d'enregistré : facteur sommeil 87.5
    ```
  - `DayRefresherTests` : `refreshScoresAgainstTheProfileGoal()` — profil à 420, nuit de 420 min : facteur sommeil 100 dans le score du passage.
  - `WhyContentTests` : `shortSleepSentenceFollowsTheGoal()` — nuit de 6 h 30 : la lecture contient « tu n'as dormi que » avec l'objectif par défaut, et « tu as dormi » avec `sleepGoalMinutes: 420`.

- [ ] **Step 2 : lancer et vérifier l'échec.** `swift test --package-path Packages/PulseRecoveryEngine --filter SleepScorerTests` → échec de compilation (paramètre inconnu).

- [ ] **Step 3 : implémenter.**
  - `SleepScorer` et `RecoveryCalculator` selon les signatures ; `sleepFactor` passe l'objectif.
  - `AntiInterference.needsRestDay` passe `SleepGoal.minutes(of: input.profile)`.
  - `DailyScoreService.score` : avec `sleepGoalMinutes == nil` et un score déjà enregistré pour le jour, rendre ce score sans recalcul (le figement après midi s'applique toujours avant) ; sans score enregistré, calculer avec `SleepGoal.defaultMinutes`.
  - `DayRefresher.pass` passe `profileReadFailed ? nil : SleepGoal.minutes(of: profile)`.
  - `WhyReading` : `shortSleepMinutes` disparaît au profit de `SleepGoal.isShortNight` ; `TodayModel` passe `SleepGoal.minutes(of:)` du profil qu'il tient.

- [ ] **Step 4 : lancer les tests.** `swift test --package-path Packages/PulseRecoveryEngine` et `swift test --package-path Packages/PulseFeatures` → tout passe.

- [ ] **Step 5 : commit.**
```bash
git add Packages/PulseRecoveryEngine Packages/PulseFeatures
git commit -m "feat(score): score sleep against the profile's sleep goal, from the next computation on"
```

---

### Task 3 : valider les réglages (`SettingsService`)

**Files :**
- Modify : `Packages/PulseFeatures/Sources/PulseServices/Settings/SettingsService.swift`
- Test : `Packages/PulseFeatures/Tests/PulseServicesTests/SettingsServiceTests.swift`

**Interfaces :**
- Produces : `SettingsError.invalidSleepGoal`, `.invalidWakeTime`, `.invalidBedtimeLead` ; `SettingsService.wakeRange = 240...720`, `SettingsService.wakeStepMinutes = 5`, `SettingsService.bedtimeLeadChoices = [15, 30, 45, 60]`, `SettingsService.sleepGoalChoices` (360, 375, … 600).

- [ ] **Step 1 : écrire les tests qui échouent.**
    ```swift
    @Test func sleepGoalMustBeAQuarterHourBetweenSixAndTenHours()
    // 345, 615, 367 → .invalidSleepGoal, rien d'écrit ; 360, 600, 450, nil acceptés
    @Test func wakeTimeMustBeAFiveMinuteStepBetweenFourAndNoon()
    // 235, 725, 422 → .invalidWakeTime (semaine comme week-end) ; 240, 720, 425, nil acceptés
    @Test func bedtimeLeadMustBeOneOfTheChoices()   // 20 → .invalidBedtimeLead ; 15, 30, 45, 60, nil acceptés
    @Test func storedOutOfRangeGoalDoesNotBlockAnotherSetting()
    // profil déjà à 2000 : changer le thème réussit
    ```

- [ ] **Step 2 : lancer et vérifier l'échec.** `swift test --package-path Packages/PulseFeatures --filter SettingsServiceTests` → échec de compilation.

- [ ] **Step 3 : implémenter** les trois cas dans `validate`, sur le modèle de `invalidDeadline` : seul un champ modifié est validé.

- [ ] **Step 4 : lancer les tests.** Même commande → tout passe.

- [ ] **Step 5 : commit.**
```bash
git add Packages/PulseFeatures
git commit -m "feat(settings): validate the sleep goal, wake times and bedtime reminder lead"
```

---

### Task 4 : le coucher conseillé (`SleepPlan`, `HabitualWake`, `BedtimeRegularity`)

**Files :**
- Create : `Packages/PulseFeatures/Sources/PulseServices/Sleep/SleepPlan.swift`
- Create : `Packages/PulseFeatures/Sources/PulseServices/Sleep/HabitualWake.swift`
- Create : `Packages/PulseFeatures/Sources/PulseServices/Sleep/BedtimeRegularity.swift`
- Modify : `Packages/PulseFeatures/Sources/PulseServices/Supplements/HabitualBedtime.swift` (`HabitualBedtimeReader`)
- Test : `Packages/PulseFeatures/Tests/PulseServicesTests/SleepPlanTests.swift`, `HabitualWakeTests.swift`, `BedtimeRegularityTests.swift` (nouveaux), `HabitualBedtimeTests.swift`

**Interfaces :**
- Consumes : `SleepGoal`, les champs de `UserProfile` (tâche 1).
- Produces (tous `public`) :
  - `HabitualBedtimeReader.nights(now: Date) async -> [NightSleep]` : les nuits des 14 derniers jours, de la plus récente à la plus ancienne ; `fellAsleepTimes` s'écrit dessus, comportement inchangé.
  - `enum HabitualWake` : `static let groupMinimumNights = 3`, `static let minimumNights = 5`, `static func minutes(wokeUp: [Date], weekend: Bool, calendar: Calendar) -> Int?`. La médiane, arrondie à 5 min, des réveils du groupe demandé (week-end : samedi et dimanche) ; un groupe de moins de 3 nuits prend la médiane de toutes les nuits, qui en demande 5 ; sinon `nil`.
  - `struct SleepPlan: Sendable, Equatable` :
    - champs `goalMinutes: Int`, `leadMinutes: Int`, `reminderEnabled: Bool`, `chosenWeekdayWake: Int?`, `chosenWeekendWake: Int?`, `habitualWeekdayWake: Int?`, `habitualWeekendWake: Int?` ;
    - constantes `fallAsleepMinutes = 15`, `defaultLeadMinutes = 30`, `earliestReminderHour = 18`, `latestReminderHour = 3` ;
    - `init(profile: UserProfile?, wokeUp: [Date], calendar: Calendar)` (objectif par `SleepGoal.minutes(of:)`, réveils habituels par `HabitualWake`) ;
    - `func wakeMinutes(weekend: Bool) -> Int?` (choisi, sinon habituel) ;
    - `func bedtimeMinutes(weekend: Bool) -> Int?` (réveil − objectif − 15, ramené dans 0…1439) ;
    - `static func wakesOnWeekend(afterEvening day: Date, calendar: Calendar) -> Bool` (le lendemain est un samedi ou un dimanche) ;
    - `func bedtime(onEvening day: Date, calendar: Calendar) -> Date?` ;
    - `func reminderDate(onEvening day: Date, calendar: Calendar) -> Date?` (coucher − avance ; `nil` hors de 18:00 le jour même … 03:00 le lendemain, bornes comprises) ;
    - `static func clockText(minutes: Int) -> String` (« 22:45 », « 00:45 ») ;
    - `static func settingsChanged(from old: UserProfile, to new: UserProfile) -> Bool` (l'un des cinq champs diffère).
  - `enum BedtimeRegularity` : `static let windowNights = 14`, `static let minimumNights = 5`, `static func minutes(fellAsleep: [Date], calendar: Calendar) -> Int?` (écart moyen à la médiane, sur un cadran qui commence à midi comme `HabitualBedtime`, arrondi à 5 min) ; `enum Level { case regular, fairlyRegular, irregular }` ; `static func level(minutes: Int) -> Level` (≤ 30, ≤ 60, au-delà).

- [ ] **Step 1 : écrire les tests qui échouent.** Reprendre `TestClock` de `HabitualBedtimeTests`. Le 20 novembre 2026 est un vendredi.
    ```swift
    // SleepPlanTests — profil : objectif 480, réveil semaine 420, week-end 540, avance 30
    @Test func weekdayBedtimeIsWakeMinusGoalMinusFallAsleep()   // bedtimeMinutes(weekend: false) == 1365 (22:45)
    @Test func weekendBedtimeCrossesMidnight()                  // bedtimeMinutes(weekend: true) == 45 (00:45)
    @Test func fridayEveningFollowsTheWeekendWake()
    // bedtime(onEvening: ven. 20) == sam. 21 00:45 ; reminderDate == sam. 21 00:15
    @Test func sundayEveningFollowsTheWeekdayWake()
    // bedtime(onEvening: dim. 22) == dim. 22 22:45 ; reminderDate == dim. 22 22:15
    @Test func reminderOutsideTheEveningIsDropped()
    // réveil 720, objectif 360 → rappel 05:15 : nil ; réveil 240, objectif 600 → rappel 17:15 : nil
    @Test func reminderBoundsAreInclusive()                     // rappel à 18:00 pile et à 03:00 pile : gardés
    @Test func chosenWakeWinsOverTheHabitualOne()
    @Test func noWakeGivesNoBedtime()                           // ni choisi ni habituel : bedtimeMinutes, bedtime, reminderDate == nil
    @Test func outOfRangeGoalIsClamped()                        // profil à 2000 → goalMinutes == 600
    @Test func missingLeadDefaultsToThirtyMinutes()
    @Test func clockTextPadsHours()                             // 1365 → "22:45", 45 → "00:45", 420 → "07:00"
    @Test func settingsChangedSeesEachOfTheFiveFields()         // faux pour un changement de thème
    // HabitualWakeTests
    @Test func eachGroupHasItsOwnMedian()
    // 5 réveils de semaine 07:00, 07:10, 06:50, 07:05, 07:20 et 3 de week-end 09:30, 10:00, 09:00 → 425 (07:05) et 570 (09:30)
    @Test func smallGroupFallsBackToAllNights()
    // les mêmes 5 de semaine et 2 de week-end 09:30, 10:00 → week-end == 430 (07:10)
    @Test func fewerThanFiveNightsGiveNothing()                 // 2 de semaine et 2 de week-end → nil pour les deux
    // BedtimeRegularityTests
    @Test func regularityIsTheMeanGapToTheMedian()              // 23:00, 23:30, 00:00, 23:30, 23:30 → 10
    @Test func fewerThanFiveNightsGiveNoRegularity()
    @Test func levelsFollowTheThresholds()                      // 30 regular, 35 et 60 fairlyRegular, 65 irregular
    ```
  - `HabitualBedtimeTests` : `nightsListsTheLastFourteenNights()` — même cache que les tests de lecture existants, `nights(now:)` rend les nuits du plus récent au plus ancien.

- [ ] **Step 2 : lancer et vérifier l'échec.** `swift test --package-path Packages/PulseFeatures --filter SleepPlanTests` → échec de compilation.

- [ ] **Step 3 : implémenter.** Les dates se construisent avec l'horloge locale (`calendar.date(bySettingHour:minute:second:of:)` sur le lendemain pour le réveil), puis on retire des minutes : un soir de changement d'heure garde le bon réveil.

- [ ] **Step 4 : lancer les tests.** `swift test --package-path Packages/PulseFeatures --filter "SleepPlanTests|HabitualWakeTests|BedtimeRegularityTests|HabitualBedtimeTests"` → tout passe.

- [ ] **Step 5 : commit.**
```bash
git add Packages/PulseFeatures
git commit -m "feat(sleep): advised bedtime from the wake time and the sleep goal, habitual wake time, bedtime regularity"
```

---

### Task 5 : planifier le rappel de coucher

**Files :**
- Create : `Packages/PulseDomain/Sources/PulseDomain/Repositories/BedtimeReminderScheduling.swift`
- Modify : `Packages/PulseDomain/Sources/PulseDomain/App/AppLink.swift`
- Create : `Packages/PulseFeatures/Sources/PulseServices/Sleep/BedtimeReminderPlanner.swift`
- Create : `Packages/PulseFeatures/Sources/PulseServices/Sleep/BedtimeReminderText.swift`
- Create : `Packages/PulseFeatures/Sources/PulseServices/Sleep/BedtimeReminderService.swift`
- Modify : `Packages/PulseFeatures/Sources/PulseServices/Resources/Localizable.xcstrings`
- Test : `Packages/PulseFeatures/Tests/PulseServicesTests/BedtimeReminderPlannerTests.swift`, `BedtimeReminderServiceTests.swift` (nouveaux)

**Interfaces :**
- Consumes : `SleepPlan`, `HabitualBedtimeReader.nights(now:)` (tâche 4) ; `SleepGoal.isShortNight` (tâche 1) ; `TodayPlanner.routineDay(of:on:calendar:overrides:)` (existant).
- Produces :
  - PulseDomain : `struct BedtimeReminder: Sendable, Equatable { var evening: Date; var fireDate: Date; var title: String; var body: String }` (`evening` : minuit local du soir concerné) ; `protocol BedtimeReminderScheduling: Sendable { func replaceBedtimeReminders(with reminders: [BedtimeReminder]) async }` ; `actor StubBedtimeReminderScheduler` (`reminders`, `replaceCount`), sur le modèle de `StubSupplementReminderScheduler` ; `AppLink.night` (valeur brute `"night"`).
  - `enum BedtimeReminderPlanner` : `static let horizonEvenings = 7`,
    `static func reminders(plan: SleepPlan, lastNightAsleepMinutes: Int?, sessionName: (Date) -> String?, now: Date, calendar: Calendar) -> [BedtimeReminder]` (`sessionName(jour)` : le nom de la séance prévue ce jour-là, `nil` un jour de repos).
  - `enum BedtimeReminderText` : `static func title(bedtime: Date, calendar: Calendar) -> String`, `static func body(goalMinutes: Int, wakeMinutes: Int, shortNightMinutes: Int?, sessionName: String?) -> String`, `static func duration(minutes: Int) -> String` (« 8 h », « 6 h 10 », « 45 min »).
  - `struct BedtimeReminderService: Sendable` : `init(profiles: any ProfileRepository, programs: any ProgramRepository, scheduledDays: (any ScheduledDayRepository)?, bedtime: HabitualBedtimeReader, reminders: any BedtimeReminderScheduling, calendar: Calendar, now: @escaping @Sendable () -> Date)`, `func reschedule() async`, `func plan() async -> SleepPlan?` (`nil` : profil illisible).

- [ ] **Step 1 : écrire les tests qui échouent.** Plan des tests : objectif 480, réveil semaine 420, week-end 540, avance 30, rappel activé ; `now` = ven. 20 nov. 2026 12:00.
    ```swift
    // BedtimeReminderPlannerTests
    @Test func sevenEveningsArePlanned()
    // 7 rappels, soirs du 20 au 26 ; fireDate : sam. 21 00:15, dim. 22 00:15, puis 22:15 du dim. 22 au jeu. 26
    @Test func disabledReminderPlansNothing()
    @Test func noAdvisedBedtimePlansNothing()                   // plan sans réveil → []
    @Test func pastReminderIsSkipped()                          // now = dim. 22 22:30 : le premier rappel est celui du lun. 23
    @Test func eveningsOutsideTheWindowAreSkippedNotTheOthers() // réveil week-end 720 + objectif 360 : 5 rappels, ceux de semaine
    @Test func titleGivesTheBedtime()                           // soir du dim. 22 → "Au lit avant 22:45" ; soir du ven. 20 → "Au lit avant 00:45"
    @Test func bodyNamesTomorrowsSession()
    // sessionName(lun. 23) == "Jambes" → "Séance Jambes demain : vise tes 8 h de sommeil."
    @Test func bodyMentionsAShortNightOnlyTonight()
    // lastNightAsleepMinutes 370 : soir du 20 → "Nuit courte hier (6 h 10) : vise tes 8 h cette nuit." ; les six autres sans « Nuit courte »
    @Test func bodyCombinesShortNightAndSession()
    // 370 et "Jambes" le sam. 21 → "Nuit courte hier (6 h 10) et séance Jambes demain : vise tes 8 h."
    @Test func bodyFallsBackToTheWakeTime()                     // soir du dim. 22, rien d'autre → "Pour tes 8 h de sommeil avant le réveil de 07:00."
    @Test func nightJustUnderTheGoalIsNotShort()                // 420 (objectif 480) : pas de « Nuit courte »
    @Test func eachEveningAppearsOnce()                         // les `evening` sont distincts
    // BedtimeReminderServiceTests (dépôts en mémoire de PulseServices/Doubles, cache de HabitualBedtimeTests)
    @Test func rescheduleReplacesTheReminders()                 // profil activé, réveils choisis : 7 rappels remis au planificateur
    @Test func rescheduleClearsThemWhenDisabled()               // rappel désactivé : remplacement par []
    @Test func rescheduleUsesTheHabitualWakeWithoutChosenTime() // cache de 7 nuits réveil 07:00 : rappels à 22:15
    @Test func rescheduleReadsTomorrowsSessionAfterMoves()      // une ligne `ScheduledDay` déplace « Jambes » au lendemain : le corps le dit
    @Test func unreadableProfileLeavesPendingRemindersAlone()   // dépôt qui lève : replaceCount == 0, plan() == nil
    ```

- [ ] **Step 2 : lancer et vérifier l'échec.** `swift test --package-path Packages/PulseFeatures --filter BedtimeReminder` → échec de compilation.

- [ ] **Step 3 : implémenter.**
  - Le planificateur parcourt les soirs d'aujourd'hui à J+6 ; pour chacun : `plan.reminderDate` (sinon on saute), `fire > now`, le titre depuis `plan.bedtime`, le corps depuis `sessionName(lendemain)` et, pour le seul soir d'aujourd'hui, `lastNightAsleepMinutes` s'il est court selon `SleepGoal.isShortNight`.
  - Les quatre corps et le titre, mot pour mot ceux des tests, en `String(localized:bundle:)`.
  - Le service : profil (échec de lecture → ne rien toucher), nuits par `bedtime.nights(now:)` (les réveils pour `SleepPlan`, la nuit dont `day` est aujourd'hui pour la nuit de la veille), programme actif et lignes `scheduledDays.days(from: aujourd'hui, to: J+8)` pour `sessionName` (le `name` du `RoutineDay`). Un programme ou des lignes illisibles donnent des rappels sans séance.
  - Notifications refusées : rien à faire ici ; iOS refuse l'ajout, et l'interrupteur des réglages se rééteint (`SettingsModel.setNotification`).

- [ ] **Step 4 : lancer les tests.** `swift test --package-path Packages/PulseDomain` puis `swift test --package-path Packages/PulseFeatures --filter BedtimeReminder` → tout passe.

- [ ] **Step 5 : commit.**
```bash
git add Packages/PulseDomain Packages/PulseFeatures
git commit -m "feat(sleep): plan one bedtime reminder per evening, seven evenings ahead, aware of last night and tomorrow's session"
```

---

### Task 6 : brancher le rappel dans l'app

**Files :**
- Modify : `Pulse/Notifications/UserNotificationScheduler.swift`
- Modify : `Pulse/AppDependencies.swift` (`Wiring` lignes ~107, ~164, ~203, ~382 ; `makeSettings` ~360), `Pulse/AppDependencies+Environments.swift`
- Modify : `Pulse/Root/AppRootModel.swift:107`, `Pulse/AppDelegate.swift:63`, `Pulse/Root/MainTabView.swift:227,250`
- Modify : `Pulse/Root/AppRouter.swift`, `Pulse/Root/MainTabView.swift:104`, `Pulse/Root/MainTabView+Shortcuts.swift`
- Modify : `Packages/PulseFeatures/Sources/TodayFeature/TodayModel.swift`, `Packages/PulseFeatures/Sources/TodayFeature/Views/TodayView.swift:121`
- Test : `PulseTests/AppRouterTests.swift`, `PulseTests/NotificationRouterTests.swift` (écrits et compilés, pas lancés) ; `Packages/PulseFeatures/Tests/TodayFeatureTests/TodayModelTests.swift`

**Interfaces :**
- Consumes : `BedtimeReminderScheduling`, `BedtimeReminder`, `AppLink.night`, `BedtimeReminderService`, `SleepPlan.settingsChanged` (tâches 4 et 5).
- Produces :
  - `UserNotificationScheduler: BedtimeReminderScheduling` : `static let bedtimePrefix = "fr.seonay.pulse.bedtime."`, `static func bedtimeIdentifier(_ reminder: BedtimeReminder, calendar: Calendar) -> String` (« fr.seonay.pulse.bedtime.2026-11-20 », le jour de `evening`), `static func bedtimeContent(_ reminder: BedtimeReminder) -> UNMutableNotificationContent` (titre, corps, son par défaut, `userInfo[NotificationRouter.linkKey] = AppLink.night.rawValue`).
  - `AppDependencies.bedtimeReminderService: BedtimeReminderService` ; `Wiring.bedtimeReminders: any BedtimeReminderScheduling` (le planificateur réel ; `StubBedtimeReminderScheduler()` là où `StubSupplementReminderScheduler()` est posé).
  - `AppRouter` : `private(set) var nightRequests = 0`, `var pendingNight = false`, sur le modèle de `whyRequests` / `pendingWhy`.
  - `TodayModel` : `private(set) var nightRequests = 0`, `func requestNight()`.

- [ ] **Step 1 : écrire les tests.**
  - `AppRouterTests` : `nightLinkOpensTodayAndAsksForTheNightScreen()` — après `open(.night)` : onglet Aujourd'hui, `isShowingSupplements == false`, `pendingNight == true`, `nightRequests == 1` ; `dropPendingRequests()` remet `pendingNight` à faux.
  - `NotificationRouterTests` : `bedtimeReminderLinksToTheNight()` — `NotificationRouter.link(from: UserNotificationScheduler.bedtimeContent(reminder).userInfo) == .night` ; `bedtimeIdentifierNamesTheEvening()` ; `bedtimeReminderShowsABannerInForeground()` (`presentationOptions` == `[.banner, .sound]`).
  - `TodayModelTests` : `requestNightBumpsTheCounter()`.

- [ ] **Step 2 : implémenter.**
  - `replaceBedtimeReminders` : retirer les demandes en attente dont l'identifiant commence par `bedtimePrefix`, puis ajouter une `UNCalendarNotificationTrigger` ponctuelle par rappel (année, mois, jour, heure, minute de `fireDate`), comme `replaceSupplementReminders`.
  - `AppDependencies` : construire `BedtimeReminderService` avec les dépôts du passage du jour et `HabitualBedtimeReader(cache: stores.healthCache, calendar: wiring.calendar)`.
  - `makeSettings` : après la ligne des compléments (dont le `guard … else { return }` devient un `if`), `if SleepPlan.settingsChanged(from: old, to: new) { await bedtimeReminderService.reschedule() }`.
  - Appeler `bedtimeReminderService.reschedule()` juste après chaque `supplementService.rescheduleReminders()` de `AppRootModel.refreshSupplementReminders`, `AppDelegate.refreshInBackground`, `MainTabView.planChanged` et `MainTabView.refreshTabs`.
  - `AppRouter.open(.night)` : comme `.why` (sans `showTodayRoot`), avec `pendingNight` et `nightRequests`. `MainTabView` : `.task(id: router.nightRequests) { await openPendingNight() }`, qui remet `pendingNight` à faux et appelle `today.requestNight()`. `TodayView` : `.onChange(of: model.nightRequests)` appelle `openNight()` quand `model.canOpenNight` ; sans nuit en cache, l'app reste sur Aujourd'hui.
  - Tout autre `switch` exhaustif sur `AppLink` reçoit le cas `.night`.

- [ ] **Step 3 : vérifier.** `swift test --package-path Packages/PulseFeatures --filter TodayModelTests` passe ; `make build-app` réussit (il compile `PulseTests`).

- [ ] **Step 4 : commit.**
```bash
git add Pulse PulseTests Packages/PulseFeatures
git commit -m "feat(app): schedule bedtime reminders wherever supplement reminders are, open the Night screen from them"
```

---

### Task 7 : Réglages, section « Sommeil »

**Files :**
- Create : `Packages/PulseFeatures/Sources/ProfileFeature/Views/SettingsSleepSection.swift`
- Modify : `Packages/PulseFeatures/Sources/ProfileFeature/Views/SettingsScreen.swift:69` (la section juste avant `NotificationSettingsSection`)
- Modify : `Packages/PulseFeatures/Sources/ProfileFeature/SettingsModel.swift`, `ProfileEnvironment.swift`, `ProfileText.swift`, `ProfileText+Spoken.swift`
- Modify : `Packages/PulseFeatures/Sources/ProfileFeature/Resources/Localizable.xcstrings`
- Modify : `Pulse/AppDependencies+Environments.swift` (fournir `sleepPlan`), les aperçus qui construisent `ProfileEnvironment`
- Test : `Packages/PulseFeatures/Tests/ProfileFeatureTests/SettingsModelTests.swift`, `ProfileSpokenTests.swift`, `SleepSettingsTextTests.swift` (nouveau)

**Interfaces :**
- Consumes : `SleepPlan`, `BedtimeReminderService.plan()` (tâches 4, 5), `SettingsService` et ses bornes (tâche 3).
- Produces :
  - `ProfileEnvironment.sleepPlan: @Sendable () async -> SleepPlan?` (dans l'app : `bedtimeReminderService.plan`).
  - `SettingsModel.sleepPlan: SleepPlan?`, relu au chargement et après chaque `update` réussi.
  - `ProfileText` : `sleepGoal(minutes: Int) -> String` (« 8 h », « 7 h 30 »), `followsNights(habitual: Int?) -> String` (« Selon mes nuits (07:00) », « Selon mes nuits » sans heure), `advisedBedtime(weekday: Int?, weekend: Int?) -> String`, `bedtimeLead(minutes: Int) -> String` (« 30 min avant »).

- [ ] **Step 1 : écrire les tests qui échouent.**
    ```swift
    // SleepSettingsTextTests
    @Test func advisedBedtimeNamesBothDays()
    // (1365, 45) == "Coucher conseillé : 22:45 en semaine, 00:45 le week-end."
    @Test func advisedBedtimeNamesTheOnlyKnownDay()
    // (1365, nil) == "Coucher conseillé : 22:45 en semaine." ; (nil, 45) == "Coucher conseillé : 00:45 le week-end."
    @Test func advisedBedtimeInvitesToChooseAWakeTime()
    // (nil, nil) == "Choisis une heure de réveil pour obtenir un coucher conseillé."
    @Test func followsNightsShowsTheMeasuredHour()   // 420 → "Selon mes nuits (07:00)" ; nil → "Selon mes nuits"
    // SettingsModelTests
    @Test func sleepPlanIsReloadedAfterAChange()     // changer l'objectif relit `environment.sleepPlan`
    @Test func followingNightsWritesNothingInTheProfile()
    // choisir « Selon mes nuits » avec un réveil habituel à 420 : weekdayWakeMinutes == nil dans le profil enregistré
    @Test func deniedNotificationsTurnTheBedtimeReminderBackOff()   // comme le test existant du score du matin
    ```
  - `ProfileSpokenTests` : le libellé VoiceOver d'un réveil choisi à 420 dit l'heure en mots, par `ProfileText.clockSpoken`.

- [ ] **Step 2 : lancer et vérifier l'échec.** `swift test --package-path Packages/PulseFeatures --filter ProfileFeatureTests` → échec de compilation.

- [ ] **Step 3 : implémenter `SleepSettingsSection(model:profile:)`.** En-tête « Sommeil ». Lignes, dans l'ordre :
  - « Objectif de sommeil » : `Picker` en menu sur `SettingsService.sleepGoalChoices`, valeur affichée `profile.sleepGoalMinutes ?? SleepGoal.defaultMinutes`, même mise en forme que « Heure plafond ».
  - « Réveil en semaine », puis « Réveil le week-end » : un `Picker` en menu à deux choix, « Selon mes nuits (07:00) » (écrit `nil`) et « Heure choisie ». Avec « Heure choisie », une ligne de plus porte un `DatePicker` `.hourAndMinute` borné de 04:00 à 12:00, dont la valeur est arrondie à 5 min à l'écriture. Valeur de départ : le réveil habituel du groupe, sinon 07:00 en semaine et 09:00 le week-end.
  - « Rappel de coucher » : `SettingsToggle` par `model.notificationBinding(profile.bedtimeReminderEnabled) { $0.bedtimeReminderEnabled = $1 }`.
  - « Prévenir », seulement rappel activé : `Picker` en menu sur `SettingsService.bedtimeLeadChoices`, valeur affichée `profile.bedtimeReminderLeadMinutes ?? SleepPlan.defaultLeadMinutes`.
  - Pied : `ProfileText.advisedBedtime(weekday: plan.bedtimeMinutes(weekend: false), weekend: plan.bedtimeMinutes(weekend: true))`, puis à la ligne « L'objectif compte dans le score de sommeil dès le prochain calcul. ».
  - Cibles de 44 pt, `listRowBackground(PulsePalette.surface)`, valeurs VoiceOver en mots, comme `NotificationSettingsSection`.

- [ ] **Step 4 : lancer les tests.** `swift test --package-path Packages/PulseFeatures --filter ProfileFeatureTests` → tout passe ; `make build-app` réussit.

- [ ] **Step 5 : commit.**
```bash
git add Packages/PulseFeatures Pulse
git commit -m "feat(settings): Sommeil section with the sleep goal, wake times, bedtime reminder and the advised bedtime"
```

---

### Task 8 : écran Nuit, écart à l'objectif et régularité

**Files :**
- Modify : `Packages/PulseFeatures/Sources/PulseServices/Health/NightDetailService.swift`
- Modify : `Packages/PulseFeatures/Sources/NightFeature/NightModel.swift`, `NightText.swift`, `Views/NightScreen.swift` (`SummaryCard`), `Views/NightPreviewSupport.swift`
- Modify : `Packages/PulseFeatures/Sources/NightFeature/Resources/Localizable.xcstrings`
- Modify : `Pulse/AppDependencies+Environments.swift:30,50` (passer le dépôt du profil)
- Test : `Packages/PulseFeatures/Tests/PulseServicesTests/NightDetailServiceTests.swift`, `Packages/PulseFeatures/Tests/NightFeatureTests/NightModelTests.swift`, `NightTextTests.swift`

**Interfaces :**
- Consumes : `BedtimeRegularity` (tâche 4), `SleepGoal` (tâche 1).
- Produces :
  - `NightDetail.bedtimeRegularityMinutes: Int?` (paramètre d'init par défaut `nil`).
  - `NightDetailService.init(cache:profiles: (any ProfileRepository)? = nil, calendar:now:)` ; `func sleepGoalMinutes() async -> Int` (`SleepGoal.minutes(of:)` du profil, la valeur par défaut sans dépôt ou si la lecture échoue).
  - `NightModel.goalMinutes: Int` (lu dans `load()`).
  - `NightText.goalGap(asleepMinutes: Int, goalMinutes: Int) -> String`, `spokenGoalGap(…)`, `regularity(minutes: Int) -> String`, `spokenRegularity(minutes: Int) -> String`.

- [ ] **Step 1 : écrire les tests qui échouent.**
    ```swift
    // NightDetailServiceTests
    @Test func regularityCoversTheFourteenDaysEndingAtEachNight()
    // 6 nuits endormies à 23:00, 23:30, 00:00, 23:30, 23:30, 23:30 : la dernière a bedtimeRegularityMinutes == 10
    @Test func regularityNeedsFiveNights()            // les quatre premières nuits : nil
    @Test func regularityIgnoresNightsOlderThanFourteenDays()
    @Test func sleepGoalComesFromTheProfile()         // profil à 420 → 420 ; sans dépôt → 480 ; dépôt qui lève → 480
    // NightTextTests
    @Test func goalGapSaysHowMuchIsMissing()          // (430, 480) == "Objectif 8 h · 50 min de moins"
    @Test func goalGapSaysWhenTheGoalIsMet()          // (480, 480) et (500, 480) == "Objectif 8 h atteint"
    @Test func spokenGoalGapUsesWords()               // (430, 480) == "Objectif 8 heures, 50 minutes de moins"
    @Test func regularityNamesItsLevel()
    // 25 → "Coucher régulier, à ± 25 min sur 14 nuits" ; 45 → "Coucher assez régulier, à ± 45 min sur 14 nuits" ;
    // 90 → "Coucher irrégulier, à ± 1 h 30 sur 14 nuits"
    @Test func spokenRegularityUsesWords()            // 25 → "Coucher régulier, à plus ou moins 25 minutes sur 14 nuits"
    // NightModelTests
    @Test func loadReadsTheGoal()                     // service avec un profil à 420 : goalMinutes == 420 après load()
    ```

- [ ] **Step 2 : lancer et vérifier l'échec.** `swift test --package-path Packages/PulseFeatures --filter "NightDetailServiceTests|NightFeatureTests"` → échec de compilation.

- [ ] **Step 3 : implémenter.**
  - `NightDetailService.nights()` : pour chaque nuit, `BedtimeRegularity.minutes` sur les `fellAsleep` des nuits dont le `day` tombe dans les 14 jours qui se terminent à la sienne.
  - `SummaryCard` : sous la ligne des heures, la ligne d'écart à l'objectif, puis la ligne de régularité quand elle existe ; même style que la ligne des heures (`.subheadline`, `PulsePalette.text2`), chacune avec son libellé VoiceOver en mots. `NightModel` passe `goalMinutes` et le `NightDetail` à la carte.
  - Les aperçus (`NightPreviewSupport`) gardent un service sans profil.

- [ ] **Step 4 : lancer les tests.** Même commande → tout passe ; `make build-app` réussit.

- [ ] **Step 5 : commit.**
```bash
git add Packages/PulseFeatures Pulse
git commit -m "feat(night): show the gap to the sleep goal and the bedtime regularity on the Night screen"
```

---

### Task 9 : vérification d'ensemble, confidentialité, livraison

**Files :**
- Modify si besoin : `docs/confidentialite/index.html`, `docs/app-store/fiche.md`
- Modify : `docs/superpowers/specs/2026-11-25-pulse-sommeil-objectif-coucher-design.md` (seulement si la construction s'en est écartée)

- [ ] **Step 1 : tout vérifier.** `make lint`, `make test-packages`, `make build-app`, `make build-release` → les quatre réussissent. Ne pas lancer `make test` ni `make test-app`.
- [ ] **Step 2 : confidentialité.** Lire `docs/confidentialite/index.html` et `docs/app-store/fiche.md` : si la liste des préférences ou des notifications y est énumérée, ajouter l'objectif de sommeil, les heures de réveil et le rappel de coucher (préférences synchronisées, notifications locales). Sinon ne rien changer.
- [ ] **Step 3 : commit** des éventuels changements de documentation (`docs: …`).
- [ ] **Step 4 : pousser et ouvrir la PR** vers `master`, avec dans sa description la liste « Laissé à vérifier sur iPhone » de la spec §8 et, en tête, l'étape manuelle : **lancer un build de debug sur l'iPhone, puis « Deploy Schema Changes » dans la console CloudKit, avant tout build TestFlight** (cinq champs ajoutés à `StoredProfile`).
- [ ] **Step 5 : TestFlight.** N'envoyer le build qu'une fois le schéma CloudKit déployé en production par Mathéo ; tant que ce n'est pas confirmé, le dire et s'arrêter là.
