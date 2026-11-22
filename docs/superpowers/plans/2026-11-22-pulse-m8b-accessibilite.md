# Pulse M8b — Accessibilité : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Chaque écran de Pulse passe la règle d'accessibilité de la spec M8 §7 : VoiceOver, Dynamic Type jusqu'à Accessibilité XL, contraste AA, « Réduire les animations », couleur jamais seule, cibles de 44 pt.

**Architecture:**
- Trois audits en lecture seule ont listé environ 170 constats, avec fichier, ligne et correction proposée. Ils sont la liste de travail des tâches 3 à 10 :
  - `docs/superpowers/plans/m8b-audit/audit-A-design-today-widgets.md`
  - `docs/superpowers/plans/m8b-audit/audit-B-train-live.md`
  - `docs/superpowers/plans/m8b-audit/audit-C-onboarding-planning-stats-profile-supplements.md`
- Les tâches 1 et 2 posent d'abord dans `PulseDesignSystem` ce que tous les écrans réutilisent :
  - les jetons de couleur corrigés et leur test de contraste ;
  - les utilitaires de mouvement et d'annonce ;
  - les textes parlés ;
  - le descripteur de graphique ;
  - les composants partagés corrigés.
- Les tâches 3 à 10 corrigent ensuite les écrans, groupe par groupe. La tâche 11 ajoute l'audit automatique en test d'interface et la liste de vérification à la main.

**Tech Stack:** SwiftUI (iOS 26 SDK, Xcode 27), Swift Charts (`AXChartDescriptorRepresentable`), `AccessibilityNotification`, Swift Testing, XCTest UI (`performAccessibilityAudit`).

**Spec:** `docs/superpowers/specs/2026-11-22-pulse-m8-app-store-design.md` §7 (règles et vérification) et §8 (barre de qualité).

## Global Constraints

- Branche `m8-accessibilite`, créée depuis `m8-confidentialite` 6835fff, car la PR #15 n'est pas encore fusionnée. Vérifier `git branch --show-current` avant chaque commit et ne jamais committer sur `master`. Ne pas pousser.
- Avant chaque commit, lancer `git status --short` et ajouter les nouveaux fichiers par leur nom ; jamais `.agents/` ni `.gemini/`. Lint et tests se lancent à part, et on ne committe qu'après avoir lu leur résultat.
- Ne jamais lancer le simulateur ni un appareil : pas de `xcodebuild test`, pas de `make test`, pas de `make test-app`, pas de `simctl`. On vérifie avec `swift test --package-path Packages/<Nom>`, `swiftlint lint --strict`, `make build-app` et `make build-release`. Si `xcodebuild` bloque dans le bac à sable, relancer cet appel avec le bac à sable désactivé. Avec `-quiet`, Xcode 27 n'affiche pas de bandeau : le code de sortie 0 fait foi.
- Étiquettes VoiceOver en français, avec le tutoiement de l'app. Une étiquette dit ce qu'est la chose et ce qu'elle vaut, avec les nombres dits naturellement : « 58 sur 100 », « 80 kilos », « 5 minutes 29 par kilomètre », « 24 minutes 31 ». Jamais « tiret », « barre oblique », « deux-points », « point médian », « tilde », « kg », « bpm », « ms », « reps », « 1RM » ni une abréviation de mois.
- Tout texte parlé composé est construit par une fonction pure et testée en Swift Testing, à côté des builders de texte existants (`*Text.swift`, `*Formatter.swift`, `OnboardingCopy`, `PulseFormat`). Rien n'est composé en ligne dans une vue.
- Dynamic Type jusqu'à `.accessibility3`. Une valeur n'est jamais tronquée. Les rangées passent en colonne aux tailles d'accessibilité, avec `AnyLayout`, `ViewThatFits` ou le motif `dynamicTypeSize.isAccessibilitySize` déjà en place. Les tailles fixes passent par `@ScaledMetric`. Le plafond `dynamicTypeSize(...accessibility1)` à `...accessibility3` n'est permis que pour le clavier de séance, les pilules RPE et les widgets.
- Toute animation et toute transition passe par l'utilitaire `PulseMotion` de la tâche 1.
- Chaque message d'erreur, chaque fin d'opération et chaque événement listé par les audits sous ANNOUNCE est annoncé par l'utilitaire d'annonce de la tâche 1. On n'utilise plus `.updatesFrequently` pour un message d'erreur. Ce trait est réservé aux chronos et aux compteurs qui défilent.
- Chaque écran touché a un aperçu `#Preview` à `.dynamicTypeSize(.accessibility3)`. Les aperçus vont dans les fichiers `*PreviewSupport.swift` ou au pied de la vue, sous `#if DEBUG` comme les voisins, pour que `make build-release` reste vert.
- Un constat d'audit peut être écarté s'il est faux ou s'il est déjà traité par une autre correction. Le rapport de la tâche le liste alors avec sa raison. Un constat n'est jamais ignoré en silence.
- Pas de changement de comportement hors accessibilité. Aucune dépendance nouvelle.

## Review Focus

1. **Le plus grand texte (`accessibility3`) sur l'écran de séance en direct** : la charge, les répétitions et le RPE restent lisibles avec leur titre, et « Passer » le repos reste atteignable. Couvert par l'aperçu ax3 et les tests de mise en page de la tâche 5.
2. **VoiceOver pendant une séance** : on valide une série, le repos démarre puis se termine, et chaque étape est annoncée une seule fois, pas à chaque seconde. Test sur la logique « annoncer une fois » dans la tâche 5.
3. **Un nombre au singulier** : « 1 série », « 1 exercice », « 1 kilo », « 1 minute », visible et parlé. Tests de `PulseSpoken.count` dans la tâche 1, puis tests des builders qui l'utilisent.
4. **Le contraste des écrans forcés en sombre** (séance en direct, récap, Live Activity) et des widgets en apparence sombre du système. Paires sombres dans le test de contraste de la tâche 1, et accent fixé dans la Live Activity en tâche 4.
5. **Un graphique sans données ou à un seul point** : le descripteur de graphique et la phrase de résumé ne plantent pas et disent « pas assez de données ». Test du descripteur dans la tâche 2.

---

### Task 1: Design system — couleurs, mouvement, annonces, textes parlés

**Files:**
- Modify: `Packages/PulseDesignSystem/Sources/PulseDesignSystem/Tokens/PulsePalette.swift`
- Create: `Packages/PulseDesignSystem/Sources/PulseDesignSystem/Theme/PulseMotion.swift`
- Create: `Packages/PulseDesignSystem/Sources/PulseDesignSystem/Theme/PulseAnnouncement.swift`
- Create: `Packages/PulseDesignSystem/Sources/PulseDesignSystem/Presentation/PulseSpoken.swift`
- Test: `Packages/PulseDesignSystem/Tests/PulseDesignSystemTests/PaletteTests.swift`, `PulseMotionTests.swift`, `PulseSpokenTests.swift`

**Interfaces (produces):**
- **Couleurs du thème clair** (valeurs de l'audit A §1 et §3) :
  - `mutedLightRGBA` = 0x68655F ;
  - `warnLightRGBA` = 0x6D6A64 ;
  - `badLightRGBA` et `opalBadLightRGBA` = 0xC02B08 ;
  - `goldLightRGBA` = 0x75623A.

  Les valeurs sombres ne bougent que si le test des paires sombres échoue ; on prend alors la valeur la plus proche qui passe et on la note dans le rapport.
- **`PulseMotion`** :
  - `static func resolved(_ animation: Animation?, reduceMotion: Bool) -> Animation?` rend `nil` quand le réglage est actif ;
  - `static func resolved(_ transition: AnyTransition, reduceMotion: Bool) -> AnyTransition` rend `.opacity` quand le réglage est actif ;
  - modificateurs de vue `pulseAnimation(_:value:)`, `pulseTransition(_:)` et `pulseNumericTransition(value:)` (l'identité quand le réglage est actif), qui lisent tous `accessibilityReduceMotion` ;
  - `static func perform(_ animation: Animation?, reduceMotion: Bool, _ body: () -> Void)` remplace `withAnimation`.
- **`PulseAnnouncement`** :
  - `static func post(_ text: String)` enveloppe `AccessibilityNotification.Announcement`, en priorité haute pour les erreurs et normale sinon ;
  - modificateur `pulseAnnounce(_ message: String?)` qui annonce quand la valeur passe à une chaîne non nulle et différente de la précédente ;
  - modificateur `pulseAnnounceOnce(_ message: String?, id: some Hashable)` qui annonce une seule fois par identifiant (fin de repos, record).
- **`PulseSpoken`** (fonctions pures, `fr_FR`) :
  - `count(_ n: Int, singular: String, plural: String) -> String`, qui sert aussi à l'affichage visible ;
  - `kilos(_ kg: Double) -> String` : « 80 kilos », « 62,5 kilos », « 1 kilo » ;
  - `duration(seconds: Int) -> String` : « 45 secondes », « 1 minute 30 », « 1 heure 45 minutes 7 » ;
  - `pace(secondsPerKilometer: Int) -> String` : « 5 minutes 29 par kilomètre » ;
  - `clock(hour: Int, minute: Int) -> String` : « 8 heures », « 8 heures 30 » ;
  - `outOf(_ value: Int, _ total: Int) -> String` : « 9 sur 12 » ;
  - `date(_ date: Date, calendar: Calendar) -> String` : « 28 octobre », avec le mois en toutes lettres ;
  - `weekday(_ date: Date, calendar: Calendar) -> String` : « lundi ».

- [ ] **Step 1: Write the failing tests**
  - **`PaletteTests`** énumère chaque paire de l'audit A §3 (thème clair), avec les seuils : 4,5 pour le texte, 3 pour les grands chiffres et les éléments graphiques porteurs d'information. Il ajoute les paires sombres utilisées par la séance en direct, le récap, la Live Activity et les widgets : `text`, `text2`, `muted`, `warn`, `bad`, `run` et `gold` sur `liveBackground`, `surface` et `surface2` sombres, ainsi que `accentInk` sur l'accent. La fonction de luminance existante est extraite en helper de test partagé, sans être recopiée. Le test `onlyTheSignalCarriesColor` reste vrai.
  - **`PulseMotionTests`** : `resolved(.snappy, reduceMotion: true) == nil`, `resolved(.snappy, reduceMotion: false) != nil`, et la transition résolue est l'opacité quand le réglage est actif. On compare par description si `AnyTransition` n'est pas `Equatable`.
  - **`PulseSpokenTests`** : chaque exemple ci-dessus, plus 0 et 1 au singulier (« 0 série », « 1 série »), 2 au pluriel, « 1 heure », « 2 heures 5 minutes », « 59 secondes », et le séparateur des milliers « 12 450 kilos » avec l'espace insécable que produit `PulseFormat`.

- [ ] **Step 2: Run to verify they fail**
  - Run: `swift test --package-path Packages/PulseDesignSystem`
  - Expected: FAIL. Les paires `muted`, `warn`, `bad` et `gold` sont sous le seuil, et les nouveaux types n'existent pas.

- [ ] **Step 3: Implement**

  Poser les quatre jetons du thème clair, puis `PulseMotion`, `PulseAnnouncement` et `PulseSpoken`. Les sites du design system qui lisent déjà `reduceMotion` en ligne (`AuraBackground`, `ButtonStyles`, `Interaction` ×2, `RecoveryGauge`) passent par `PulseMotion`. `AuraBackground` réagit aussi au réglage changé en cours d'affichage (audit A, MOTION).

- [ ] **Step 4: Verify**
  - Run: `swift test --package-path Packages/PulseDesignSystem && swift test --package-path Packages/PulseFeatures`
  - Run: `swiftlint lint --strict`
  - Expected: PASS, 0 violation. `PulseFeatures` passe encore : seules des couleurs ont changé.

- [ ] **Step 5: Commit** — `feat(design): AA palette, motion and announcement helpers, spoken French formats`

### Task 2: Design system — composants partagés et descripteur de graphique

**Files:**
- Modify (constats de l'audit A sur `DS/…` et des audits B et C sur `ChoicePills`) : `Components/ChoicePills.swift`, `WeekdayToggleRow.swift`, `CategoryBadge.swift`, `FocusSlider.swift`, `Interaction.swift` (`IconChip`, `PillButtonStyle`, `PulseSectionHeader`, barre ancrée), `Gauge/RecoveryGauge.swift`, `MuscleMap/MuscleIntensity.swift`, `MuscleMap/MuscleMapView.swift`
- Create: `Packages/PulseDesignSystem/Sources/PulseDesignSystem/MuscleMap/MuscleMapSummary.swift`, `Packages/PulseDesignSystem/Sources/PulseDesignSystem/Presentation/PulseChartDescriptor.swift`
- Test: `MuscleMapTests.swift`, `PulseChartDescriptorTests.swift`, plus les tests des composants touchés

**Interfaces (produces):**
- **`ChoicePills` et `MultiChoicePills`** :
  - `groupLabel: String?` : le conteneur `.contain` porte le nom de la question ;
  - `spokenLabel: (Option) -> String?` : une étiquette parlée par option, par exemple « 3 séances par semaine » ;
  - `minHeight` passe à 44.
- **`MuscleMapSummary.text(levels: [Muscle: MuscleIntensity]) -> String`**, par exemple « Pectoraux, intensité forte. Triceps, intensité moyenne. ». Les niveaux sont triés du plus fort au plus faible, puis par nom. Le texte vide se lit « Aucun muscle travaillé ». `MuscleIntensity.accentShares` vaut `[0.5, 0.7, 0.85, 1]`.
- **`PulseChartDescriptor: AXChartDescriptorRepresentable`**, construit par `init(title: String, summary: String, xAxis: XAxis, yAxis: YAxis, series: [Series])` :
  - `XAxis` vaut `.dates(title:)` ou `.categories(title:, names:)` ;
  - `YAxis` est `(title, unit, range)` ;
  - `Series` est `(name, points: [(x: Date or String, y: Double)])`.

  `makeChartDescriptor()` produit les descripteurs d'axes et de séries en français, avec les dates formatées par `PulseSpoken.date`. Les séries vides sont gérées sans plantage.
- Les autres corrections suivent l'audit A : DYNTYPE de `CategoryBadge`, `FocusSlider`, `IconChip`, `PillButtonStyle` et `PulseSectionHeader`, LABEL et TARGET de `WeekdayToggleRow`, COLOR et MOTION de `RecoveryGauge` (« sur 100 » en `opalMuted`, `pulseNumericTransition`), MOTION de la barre ancrée.

- [ ] **Step 1: Write the failing tests**
  - **`MuscleMapSummary`** : l'ordre, les noms français, l'état vide.
  - **`PulseChartDescriptorTests`** : un descripteur à 2 séries et dates a 2 séries, l'axe Y a la plage donnée, une série vide donne 0 point, et le titre et le résumé sont repris. Ajouter le cas d'un seul point (Review Focus 5).
  - **Composants** : la valeur parlée de `WeekdayToggleRow` (« Jour d'entraînement possible » ou « Jour de repos ») est extraite en fonction pure et testée, et l'étiquette de groupe de `ChoicePills` aussi.

- [ ] **Step 2: Run to verify they fail**
  - Run: `swift test --package-path Packages/PulseDesignSystem`
  - Expected: FAIL.

- [ ] **Step 3: Implement**

  Corriger chaque constat de l'audit A rangé sous `DS/` et ajouter un aperçu ax3 par composant touché. `MuscleMapView` garde son paramètre d'étiquette, et les appelants passent `MuscleMapSummary.text`.

- [ ] **Step 4: Verify**
  - Run: `swift test --package-path Packages/PulseDesignSystem && swift test --package-path Packages/PulseFeatures`
  - Run: `swiftlint lint --strict`
  - Run: `make build-app`
  - Expected: PASS, 0 violation, code de sortie 0. Les appelants de `ChoicePills` compilent, car les nouveaux paramètres ont des valeurs par défaut.

- [ ] **Step 5: Commit** — `feat(design): accessible pills, badges, gauge, muscle map summary, chart descriptor`

### Tasks 3 à 10 : écrans

Chaque tâche d'écran suit le même cycle :
1. Écrire les tests des nouveaux builders parlés, avec les textes exacts proposés par l'audit, ajustés à `PulseSpoken`.
2. Les voir échouer.
3. Corriger chaque constat de l'audit pour les fichiers de la tâche, avec les outils des tâches 1 et 2 : `PulseMotion`, `pulseAnnounce`, `pulseAnnounceOnce`, `PulseSpoken`, `ChoicePills(groupLabel:spokenLabel:)`, `MuscleMapSummary` et `PulseChartDescriptor`.
4. Ajouter les aperçus ax3.
5. Lancer `swift test` sur `Packages/PulseFeatures`, `swiftlint lint --strict` et `make build-app`.
6. Committer.

Le rapport de chaque tâche liste chaque constat de son périmètre avec sa ligne : corrigé, ou écarté avec sa raison.

Les tests de builders sont dans le dossier de tests de la feature (`Packages/PulseFeatures/Tests/<Feature>Tests/`). Les textes d'annonce y sont testés aussi, par exemple « Repos terminé. Série suivante : … », « Nouveau record ! » ou « Ton score est prêt : … ».

### Task 3: Accueil, check-in, racine

- **Périmètre :** audit A, constats sur `TF/` (TodayFeature), `CF/` (CheckInFeature) et `Pulse/Root`.
- **Builders :**
  - `FactorDisplay.accessibilityLabel` ;
  - `TrendTile.spokenValue` et le sens de la tendance ;
  - `TodayModel.syncAccessibilityText` ;
  - `TodayModel.scoreAnnouncement(old:new:)` ;
  - `SessionSummary.spokenText` ;
  - `DoneCard.spokenStats` ;
  - `CheckInText.estimation(score:category:)` ;
  - `LoadCardContent.accessibilityLabel` ;
  - `WhyContent.Signal.accessibilityLabel`.
- **Annonces :** le score mis à jour (seulement s'il change), l'erreur de check-in, la fin de la mobilité, l'estimation du check-in disponible.
- **Commit :** `feat(today): VoiceOver labels, announcements and large text on Today and check-in`

### Task 4: Widgets et Live Activity

- **Périmètre :** audit A, constats sur `WF/` et `PW/`.
- **Polices :** toutes les polices `.system(size:)` passent en `@ScaledMetric` relatif à un style de texte, avec un plafond `...accessibility3`, ou `...xxxLarge` si la mise en page casse, choisi et noté widget par widget. Les tailles visibles sont d'au moins 11 pt.
- **Live Activity :** l'accent est fixé à ses valeurs sombres, avec `.environment(\.colorScheme, .dark)`.
- **Builders :** les étiquettes de `StreakWidgetContent` et `WeekWidgetContent` disent l'état des 7 jours, et `WidgetPlanningText.spokenPace` lit l'allure. Les tests vont dans les tests de widgets existants.
- **Commit :** `feat(widgets): scalable widget text, spoken day states, Live Activity contrast`

### Task 5: Séance en direct

- **Périmètre :** audit B, constats sur `LiveSessionFeature/Views/` (`LiveSessionView`, `LiveHeader`, `LiveExerciseCard`, `LiveSetRow`, `NumericKeypad`, `RPEPicker`, `RestBanner`, `PlateCalculatorSheet`, `ReplaceExerciseSheet`) et l'écran forcé en sombre.
- **Builders :**
  - `RestBanner.restStartedText(seconds:)`, `restEndedText(next:)` et `remainingSpokenText(of:at:)` ;
  - `NumericKeypad.valueAnnouncement(field:text:)` et `stepSpokenText` avec son unité ;
  - `LiveSetRow.weightSpokenTitle(for:)` ;
  - `PlateCalculatorSheet.perSideSpokenText(_:)`.
- **Focus et annonces :**
  - Le clavier prend le focus VoiceOver à l'ouverture, avec `@AccessibilityFocusState`.
  - Chaque touche annonce la valeur du champ en priorité basse.
  - Le début et la fin du repos sont annoncés une fois chacun (`pulseAnnounceOnce` avec l'identifiant de la série). Le test vérifie la logique « une fois » sur la fonction qui choisit le texte.
- **Couleur :** la coche « série validée » change de symbole, pas seulement de couleur.
- **Mise en page ax3 :** l'en-tête de séance, le bandeau de repos (boutons en colonne), les cellules de série avec leur titre visible et la calculatrice passent en colonne. Le clavier et les pilules RPE sont plafonnés à `...accessibility1`.
- **Aperçus ax3 :** repos en cours, RPE, calculatrice, remplacement.
- **Commit :** `feat(live): announce rest and keypad values, accessible set rows and large text in live session`

### Task 6: Récap et explication Apple Santé

- **Périmètre :** audit B, constats sur `LiveSessionFeature/Recap/`.
- **Builders :** `RecapView.recordsAnnouncement(_:) -> String?` (nil sans record), annoncé une fois à l'ouverture, et `statSpoken` (tonnage en kilos, durée en minutes).
- **Mise en page :** le nom du groupe musculaire est en `@ScaledMetric`, avec une colonne en ax3. `HealthWriteExplanation` défile, avec « Continuer » épinglé. L'en-tête de carte est combiné et les icônes sont masquées.
- **Aperçus ax3 :** l'explication Apple Santé et `FinishFlow`.
- **Commit :** `feat(recap): announce new records, spoken stats, scrollable Health explanation`

### Task 7: Entraîner (bibliothèque, fiche, historique, éditeurs, import)

- **Périmètre :** audit B, constats sur `TrainFeature/`.
- **Nouveau fichier :** `Packages/PulseFeatures/Sources/TrainFeature/TrainText.swift`, qui contient :
  - les séries parlées (« 70 kilos, 2 séries de 5 répétitions ») ;
  - le résumé de routine parlé (« environ 55 minutes ») ;
  - le résumé d'exercice de routine (« 3 séries de 8 à 12 répétitions, RPE 8, repos 2 minutes »).
- **Pluriels :** tous les pluriels visibles et parlés (« 1 exercice », « 1 série », « 1 séance », « Importer 1 séance ») passent par `PulseSpoken.count`.
- **Graphique de progression :** il prend un `PulseChartDescriptor` et garde sa phrase de résumé en étiquette. On retire `.ignore`.
- **Autres corrections :** les étiquettes des `ProgressView`, des champs de correction de séance et des `Stepper` (valeur dans `accessibilityValue`), et la mise en colonne de `HistoryRow` et de la correction.
- **Commit :** `feat(train): spoken sets and summaries, plurals, accessible progression chart and forms`

### Task 8: Onboarding et Planning

- **Périmètre :** audit C, constats sur `OnboardingFeature/` et `PlanningFeature/`.
- **Builders :**
  - `OnboardingCopy.scoreReadyAnnouncement(recovery:)`, `scoreAccessibility(recovery:)`, `measureLabel(title:unit:)` et `sessionsPerWeekLabel(_:)` ;
  - `PlanningText.dayAccessibility(...)`, `rowAccessibility(...)` et `paceSpoken(...)`.
- **Mise en page :** le pied de l'onboarding descend dans le `ScrollView` en ax3. La bande des jours est plafonnée à `...xxxLarge`, puisqu'elle double la liste. `StreakCard` passe en `@ScaledMetric` et en colonne.
- **Couleur :** l'aperçu de semaine du programme double la couleur d'une forme et d'une légende.
- **Aperçus :** Planning n'a encore aucun aperçu. En créer un pour `PlanningView`, `MonthView` et `ActivityDetailView`, en mémoire comme les autres features, plus leur version ax3.
- **Commit :** `feat(onboarding,planning): score announcement, spoken fields and days, large text`

### Task 9: Statistiques

- **Périmètre :** audit C, constats sur `StatsFeature/`.
- **Graphiques :** les 5 graphiques (ratio, charge empilée, VFC et FC repos, sommeil, journées par état) prennent chacun un `PulseChartDescriptor`. Leurs phrases de résumé sortent des vues vers `StatsText`, où elles sont testées.
- **Builders :** `StatsText.raceTimeSpoken`, `strengthRecordSpoken` (valeur d'abord) et `attendanceDays(week:calendar:)`, cette dernière en valeur de chaque colonne de la grille.
- **Couleur :** les encres de `StatsInk` et les niveaux d'assiduité porteurs d'information atteignent 3:1, ou sont doublés d'un motif. On ajoute leurs paires au test de contraste de la tâche 1, dans `PaletteTests` si les jetons sont dans le design system, sinon dans un test de StatsFeature. L'état « déséquilibré » s'écrit.
- **Mise en page :** les hauteurs de graphiques, les tuiles, les légendes et les lignes de records passent en `@ScaledMetric` ou en colonne.
- **Commit :** `feat(stats): audio graphs, spoken records and attendance, AA chart inks`

### Task 10: Profil et compléments

- **Périmètre :** audit C, constats sur `ProfileFeature/` et `SupplementsFeature/`.
- **Graphique :** le graphique du poids prend un `PulseChartDescriptor`, et son résumé sort vers `ProfileText.weightChartSummary(...)`.
- **Builders profil :** `ProfileText.weightChangeSpoken`, `raceTimeSpoken`, `recordValueSpoken` et `badgeAccessibility`.
- **Builders compléments :** `SupplementsModel.detailSpoken(item)` (« 1 000 unités internationales, à 8 heures ») et `takenAnnouncement(item:taken:due:)`.
- **Contrôles :** la coche d'un complément devient un interrupteur (`.isToggle` avec la valeur « Pris » ou « Pas pris »), et « Archiver » devient une action VoiceOver nommée.
- **Annonces :** les erreurs des Paramètres, de la pesée et des compléments, la fin d'une relecture d'Apple Santé, l'export prêt.
- **Mise en page ax3 :** l'en-tête du profil, le mur des records, les champs des réglages et les barres de stock.
- **Commit :** `feat(profile,supplements): spoken records and doses, toggle semantics, announcements, large text`

### Task 11: Audit automatique et liste de vérification

**Files:**
- Create: `PulseUITests/AccessibilityAuditUITests.swift`
- Create: `docs/app-store/verification-accessibilite.md`

- [ ] **Step 1: Write `AccessibilityAuditUITests`**

  Les arguments de lancement sont ceux de `OnboardingFlowUITests` : `-PulseStore inMemory`, `-PulseHealthScenario goodNight` et `-PulseNow 2026-11-02T08:00:00+01:00`. Le test traverse l'onboarding avec les mêmes identifiants. Puis, pour chaque onglet (Aujourd'hui, Entraîner, Planning, Stats, Profil), il appelle `try app.performAccessibilityAudit()`. Il démarre aussi une séance libre et appelle l'audit sur l'écran de séance, puis sur le récap après « Terminer ». Les identifiants viennent des `*Identifiers.swift` existants ; s'il en manque, en ajouter dans les vues.

  Un seul type d'écart peut être filtré dans la closure de `performAccessibilityAudit`, `.contrast` sur les éléments de trame décorative, avec un commentaire. Rien d'autre n'est filtré.

- [ ] **Step 2: Compile it**
  - Run: `make build-app` (`build-for-testing`, qui compile aussi la cible de tests d'interface).
  - Expected: code de sortie 0.
  - Le test n'est pas lancé : c'est Mathéo qui le lance (spec §7.2).

- [ ] **Step 3: Write `docs/app-store/verification-accessibilite.md`**

  La liste de vérification à la main, écran par écran :
  - **VoiceOver** : l'ordre, les étiquettes clés à entendre et les annonces attendues (repos terminé, record, score prêt, erreurs) ;
  - **Dynamic Type au maximum** dans Réglages → Accessibilité → Affichage et taille du texte → Police plus grande : ce qui doit rester lisible ;
  - **Réduire les animations** : ce qui ne doit plus bouger ;
  - **les animations système non pilotables** (audit A §4).

  Chaque ligne est une case à cocher.

- [ ] **Step 4: Commit** — `test(a11y): accessibility audit UI test and manual VoiceOver checklist`

### Vérification finale de la branche

- [ ] Les six `swift test --package-path Packages/<Nom>` sont verts.
- [ ] `swiftlint lint --strict` : 0 violation.
- [ ] `make build-app` et `make build-release` : code de sortie 0.
- [ ] `grep -rn "updatesFrequently" Packages/PulseFeatures/Sources` ne laisse que des chronos et des compteurs.
- [ ] `grep -rnE "withAnimation|\.animation\(|\.transition\(" Packages/PulseFeatures/Sources Packages/PulseDesignSystem/Sources Pulse` : chaque occurrence restante passe par `PulseMotion`, ou figure dans la liste des animations système de la vérification à la main.
