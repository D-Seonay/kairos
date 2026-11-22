# Audit A11y M8b, partie A (read-only)

Périmètre : PulseDesignSystem (Components, Gauge, MuscleMap, PulsePalette), TodayFeature, CheckInFeature, Pulse/Root, PulseWidgets, WidgetFeature.
Abréviations de chemin : `DS` = Packages/PulseDesignSystem/Sources/PulseDesignSystem, `TF` = Packages/PulseFeatures/Sources/TodayFeature, `CF` = Packages/PulseFeatures/Sources/CheckInFeature, `WF` = Packages/PulseFeatures/Sources/WidgetFeature, `PW` = PulseWidgets.
Contrastes calculés avec la formule WCAG 2.x (script : scratchpad/a11y/contrast.py), thème clair.

---

## 1. Findings par catégorie

### COLOR (contraste AA et information portée par la couleur)

- [COLOR] DS/Tokens/PulsePalette.swift:61 — `mutedLightRGBA` 0x86837C = 3,21:1 sur `background`, 3,62:1 sur `surface`, 2,93:1 sur `surface2` ; il sert de TEXTE (<4,5:1) à : `pulseEyebrow()` par défaut (DS/Tokens/PulseFont.swift:30, donc « Séance du jour » TF/Views/StrengthSessionCard.swift:59 et le titre de chaque tuile TF/Views/TrendTilesView.swift:33), libellés de LoadGauge (DS/Components/LoadGauge.swift:95), note « Tu gardes toujours le dernier mot. » (TF/Views/WhyView.swift:221), note du check-in (CF/CheckInView.swift:41), lettre d'un jour de repos (DS/Components/WeekdayToggleRow.swift:22), widgets (WF/Views/LoadWidgetSmallView.swift:38,93 ; TodaySessionWidgetMediumView.swift:37,64 ; WeekWidgetLargeView.swift:52,96,114,160) — proposé : assombrir `mutedLightRGBA` en 0x68655F (4,92 / 5,56 / 4,50 sur background / surface / surface2). `text2` (0x57554F) reste distinct (6,32).
- [COLOR] DS/Tokens/PulsePalette.swift:96 — `badLightRGBA` / `opalBadLightRGBA` (ligne 81) 0xD9391A = 3,91:1 sur background, 4,42:1 sur surface et sur opale, 3,57:1 sur surface2 ; utilisé en TEXTE : message d'erreur du check-in (TF/Views/TodayView.swift:114, sur background, 3,91), libellé « SURMENAGE » de CategoryBadge (DS/Components/CategoryBadge.swift:26, 4,34 sur le fond de la pastille), pastille de zone « Risque de blessure » (TF/Views/LoadCard.swift:55-56, 4,42) — proposé : 0xC02B08 (chroma 0,72, passe encore le test `chroma > 0,7` de PaletteTests ; 4,96 background / 5,60 surface / 4,53 surface2). Le sombre (0xFF4F2E : 5,89 sur surface sombre) est déjà bon.
- [COLOR] DS/Tokens/PulsePalette.swift:94 — `warnLightRGBA` 0x77746D = 3,95:1 sur background, 4,47:1 sur surface (juste sous 4,5), utilisé en texte dans la pastille « Charge élevée » (TF/Views/LoadCard.swift:56) et `zoneLabel` du widget Charge (WF/Views/LoadWidgetSmallView.swift:53) — proposé : 0x6D6A64 (4,57 / 5,16).
- [COLOR] DS/Tokens/PulsePalette.swift:102 — `goldLightRGBA` 0x8A743F = 3,83 background, 4,33 surface, 3,50 surface2 ; si utilisé en texte ailleurs (records) il échoue — proposé : 0x75623A (4,99 / 5,64 / 4,56). À vérifier dans les features hors périmètre.
- [COLOR] DS/Gauge/RecoveryGauge.swift:160-163 — « SUR 100 » en `.foregroundStyle(.secondary)` (hiérarchique, ~3,4:1 sur l'opale) en 10 à 13 pt — proposé : `PulsePalette.opalMuted` (4,79 sur opale) ; même remarque pour `.secondary` du titre de WF/Views/RecoveryWidgetSmallView.swift:25 (fond opale, texte caption2).
- [COLOR] DS/MuscleMap/MuscleIntensity.swift:7 — l'intensité (niveaux 1 à 4) n'est portée que par la nuance : niveau 1 = 1,95:1 contre `muscleOff` et 2,40:1 contre `muscleBody` (élément graphique porteur d'information, 3:1 requis) ; niveau 2 = 3,60:1 — proposé : `accentShares = [0.5, 0.7, 0.85, 1]` (niveau 1 à 3,06 contre off) et donner les niveaux dans l'étiquette (voir GROUP).
- [COLOR] PW/SessionLiveActivityViews.swift:9-10 — `SessionActivityStyle.accent` = `Color(PulseTone)` dynamique ; la Live Activity pose un fond noir (`activityBackgroundTint(liveBackground)`, PW/SessionLiveActivity.swift:14) mais l'extension ne force pas l'apparence : en apparence claire du système, `accent` vaut 0x17140F (encre) sur noir = ~1,1:1 (minuteur, icône, anneau invisibles) et le bouton « Passer » devient noir sur noir (texte `accentInk` clair, mais bouton non délimité). PLAUSIBLE, à vérifier sur appareil — proposé : fixer `Color(PulsePalette.accent(for: .amber).accent.dark)` et `accentInk.dark`, et `.environment(\.colorScheme, .dark)` sur `SessionLockScreenView` et la Dynamic Island.
- [COLOR] widgets PW/* (jetons `PulsePalette.surface`/`muted`/`text2`) — contrairement à l'app (forcée en clair par Pulse/Root/AppRootView.swift:22), les widgets suivent l'apparence système et prennent donc les tirages SOMBRES (muted sombre 0x6E6E6C sur surface sombre = 3,78:1, sur noir 4,11:1). Décider : soit `.environment(\.colorScheme, .light)` sur les vues widgets pleine couleur (cohérent avec « thème clair seul »), soit étendre le test de contraste aux paires sombres et remonter `mutedRGBA` à ~0x8A8A88 (>= 5:1 sur 0x0E0E0F).
- [COLOR] TF/Views/RecoveryCard.swift:159-171 — textes `opalMuted` (détail des facteurs, caption) posés dans la moitié basse de la dalle, où se mêlent des points de trame (voile opale à 0,7 seulement, DS/Components/Cards.swift:63) : le contraste réel est inférieur aux 4,79:1 de la paire. PLAUSIBLE — vérifier sur capture ; remède : voile à 0,9 en bas, ou masquer la trame sous les facteurs.
- [COLOR] WF/Views/StreakWidgetSmallView.swift:68-88 — statuts de jour distingués par la forme (plein, anneau épais, anneau fin, tiret), bien ; mais l'anneau « repos » (`primary.opacity(0.2)`) et « à venir » (0.35) sont sous 3:1 sur le dégradé — proposé : monter à 0.5 / 0.45.
- OK sur le principe : DS/Components/WeekdayToggleRow.swift:22-26 (diagonale + étiquette « Jour de repos », sous réserve du `muted`), CategoryBadge (repère plein / demi / signal + nom écrit), LoadCard (zone nommée).

### LABEL

- [LABEL] CF/CheckInView.swift:74-77 + DS/Components/ChoicePills.swift:14-24 — les pilules « Mauvais », « Moyen »… « Aucune », « Légères »… sont lues sans leur question (la question n'est qu'un en-tête voisin) ; les réponses se ressemblent d'une question à l'autre — proposé : ajouter à `ChoicePills`/`MultiChoicePills` un paramètre `groupLabel: String?` appliqué par `.accessibilityElement(children: .contain).accessibilityLabel(groupLabel)` sur le `PillFlowLayout` ; CheckInView passe `question.title`.
- [LABEL] DS/Components/WeekdayToggleRow.swift:31 — `accessibilityValue("")` quand le jour n'est pas imposé en repos ; la rangée n'a pas de nom de groupe — proposé : valeur « Jour d'entraînement possible » (sinon « Jour de repos »), et `.accessibilityElement(children: .contain).accessibilityLabel("Jours de repos imposés")` sur le HStack (ligne 14).
- [LABEL] Pulse/Root/AppRootView.swift:70 — `ProgressView()` du `LoadingView` sans étiquette — proposé : `.accessibilityLabel(String(localized: "Chargement"))`.
- [LABEL] TF/Trends/TrendTile.swift:30-33,41,49 — étiquette de tuile « FC repos, 14 jours, dernière valeur 54 bpm » / « Variabilité … 44 ms » : « ms » et « bpm » mal prononcés, « FC » épelé — proposé : fonction pure `TrendTile.spokenValue` : « 44 millisecondes », « 54 battements par minute », titre parlé « Fréquence cardiaque au repos, 14 jours », et ajouter le sens de la tendance (« en hausse / en baisse / stable ») calculé depuis `values` ; texte à tester avec les tests existants de TrendTile.
- [LABEL] TF/Views/TodayView.swift:160-179 — pastille de synchro : le texte « SYNCHRO 08:00 » est lu tel quel ; « 08:00 » est lu comme un nombre — proposé : `accessibilityLabel("Synchronisé à 8 h 00")` / « Pas encore synchronisé » via `TodayModel.syncAccessibilityText` (pur).
- [LABEL] CF/CheckInView.swift:132-138 — étiquette d'estimation « Estimation, 58, Fatigue modérée » (le score n'est pas dit « sur 100 », catégorie en capitale) — proposé : « Estimation : 58 sur 100, fatigue modérée » en réutilisant `RecoveryGauge.accessibilityLabel(score:category:)` (déjà publique) ou une fonction pure `CheckInText.estimation(score:category:)` testée.

### GROUP

- [GROUP] TF/FactorFormatter.swift:62,72 + TF/Views/RecoveryCard.swift:174 — colonne de facteur `.combine` : lit « Sommeil, —, pas de donnée cette nuit » (tiret lu « tiret cadratin » ou ignoré), « FC repos, 54, −3 bpm » (valeur sans unité ni référent), « Variabilité, 62 ms, +5 % vs 14 j » — proposé : propriété pure `FactorDisplay.accessibilityLabel` dans FactorFormatter.swift : « Sommeil, 7 h 12, sommeil profond 22 % », « Fréquence cardiaque au repos, 54 battements par minute, 3 de moins que ta ligne de base », « Variabilité, 62 millisecondes, 5 % de plus que sur 14 jours », valeur manquante : « Sommeil, pas de donnée cette nuit ». Appliquer avec `.accessibilityElement(children: .ignore).accessibilityLabel(...)`.
- [GROUP] TF/Views/StrengthSessionCard.swift:129-138,143-153 — la mini carte musculaire (étiquette « Muscles sollicités : A, B, C »), le texte `statsText` et la liste `topMuscles` sont trois éléments, et les noms de muscles sont dits deux fois ; `statsText` « 19 séries · ~ 55 min · RPE max 8 » lit « tilde » — proposé : un seul élément `.accessibilityElement(children: .ignore)` sur le conteneur de `SessionOverview` avec `SessionSummary.spokenText` pure : « 19 séries, environ 55 minutes, effort perçu maximal 8 sur 10, muscles principaux : pectoraux, triceps, épaules » ; la `MuscleMapView` est alors couverte par ce texte.
- [GROUP] DS/MuscleMap/MuscleMapView.swift:25-26 — l'étiquette est fournie par l'appelant sans niveaux : « Muscles sollicités : pectoraux, triceps » ne dit pas que les pectoraux sont le plus travaillés — proposé : fonction pure `MuscleMapSummary.text(levels:)` : « Pectoraux, intensité forte. Triceps, intensité moyenne… » (testable), réutilisée par la partie B (« Travaillés cette semaine : … », règle 7.1).
- [GROUP] TF/Session/DoneCard.swift:62-64 + TF/Views/LiveSessionCards.swift:15-20 — « 55 min · 18 séries · 6420 kg · 2 records » : séparateur « · » parfois lu, « 6420 » lu en un bloc — proposé : `DoneCard.spokenStats` pure : « 55 minutes, 18 séries, 6 420 kilogrammes, 2 records » ; le bloc est `.combine` (ligne 19), passer à `.ignore` + label.
- [GROUP] TF/Views/WhyView.swift:178-179 — `SignalBar` : bon (un élément « titre, 58 sur 100 ») mais construit dans la vue — proposé : déplacer vers `WhyContent.Signal.accessibilityLabel` (TF/Why/WhyContent.swift) pour le tester.
- [GROUP] TF/Views/LoadCard.swift:20,53-60,74-76 — l'étiquette de la jauge dit déjà la zone et la pastille de zone la répète : doublon bénin — proposé : `.accessibilityHidden(true)` sur `zoneBadge` quand la jauge est affichée ; déplacer l'étiquette `gaugeLabel` (ligne 74) dans `LoadCardContent` (TF/Load/LoadCardContent.swift) comme `accessibilityLabel` pure testable.
- [GROUP] TF/Views/RecoveryCard.swift:33-34 — doublon « Récupération » (en-tête) / badge « Fatigue modérée » / jauge « Récupération 58 sur 100, fatigue modérée » ; le badge porte seul « Estimé » / « En calibration » — proposé : inclure `marker` dans l'étiquette de la jauge de cette carte (« , estimé ») et masquer le badge.
- [GROUP] WF/StreakWidgetContent.swift:67 — l'étiquette « Série de 14 semaines, 3 séances sur 5 cette semaine » ne dit pas l'état des 7 pastilles (plein / aujourd'hui / à venir / repos) — proposé : ajouter « lundi fait, mardi fait, mercredi repos, aujourd'hui jeudi, … » dans `StreakWidgetContent.content(...)` à partir de `days` et du calendrier ; test dans les tests de widget existants.
- [GROUP] WF/NextWorkoutWidgetContent.swift:52-53,63 — l'étiquette contient « · » et « /km » (« Zone 2 · 5:45 à 6:05 /km »), et se termine par « , » quand `detail` est vide — proposé : `WidgetPlanningText.spokenPace` (« 5 minutes 45 à 6 minutes 5 par kilomètre ») et ne joindre que les parties non vides.
- [GROUP] WF/WeekWidgetContent.swift:79-86 — l'étiquette parlée de la semaine reprend « 1,12 · zone optimale » (point médian) : utiliser « 1,12, zone optimale » ; elle ne décrit pas non plus les pastilles de jours (voir Série).
- RAS : DS/Components/LoadGauge.swift:25-26, DS/Gauge/RecoveryGauge.swift:94-95 (`accessibilityLabel` pure publique), DS/Components/StepProgressBar.swift:25-26, DS/Components/CategoryBadge.swift:34-35 sont déjà groupés avec étiquette.

### HIDE

- Aucun défaut relevé : AuraBackground (DS/Components/AuraBackground.swift:32), HalftoneField (Halftone.swift:26), StateMark (CategoryBadge.swift:62), IconChip (Interaction.swift:113), RowChevron (228), Sparkline (ligne 52), PlateBarDiagram (44), SessionRestRing (PW/SessionLiveActivityViews.swift:47) et les icônes décoratives de WF/PW sont masqués. Remarque : OpalCard (DS/Components/Cards.swift:28) et ObsidianCard (85) posent `.accessibilityElement(children: .contain)`, ce qui crée un conteneur supplémentaire sans effet nocif.

### CHART

- Aucun Swift Charts dans le périmètre. Graphiques maison (Canvas) : Sparkline (étiquette portée par la tuile, mais pas de sens de la tendance : voir LABEL TrendTile), LoadGauge (étiquette OK), RecoveryGauge (OK), MuscleMapView (voir GROUP), barre de charge des widgets (couverte par l'étiquette du widget), PlateBarDiagram (muet, le texte voisin dit les disques : OK).

### ANNOUNCE

- [ANNOUNCE] TF/TodayModel.swift:86-88,162-166 (`showScoreAndSession`, `applyWritten`) — aucune annonce quand le score du jour arrive ou change (lecture Santé terminée, check-in validé) ; l'écran se met à jour sous le focus — proposé : après `apply(...)`, publier `AccessibilityNotification.Announcement("Score mis à jour : " + RecoveryGauge.accessibilityLabel(score:category:)).post()` uniquement si le score ou la catégorie diffère de l'ancien et n'est pas `nil` ; déclenchement dans TodayView via `.onChange(of: model.score)` ; texte pur testable `TodayModel.scoreAnnouncement(old:new:)`.
- [ANNOUNCE] TF/Views/TodayView.swift:111-116 — l'erreur « Pulse n'a pas pu enregistrer ton check-in. » apparaît sans annonce — proposé : `.onChange(of: model.errorMessage)` qui poste `AccessibilityNotification.Announcement(message)`.
- [ANNOUNCE] TF/Views/MobilitySheet.swift:47-62 — fin du minuteur (« Séance terminée ») sans annonce ; le décompte (`TimelineView` à 1 s) n'a pas le trait `.updatesFrequently` — proposé : `.accessibilityAddTraits(.updatesFrequently)` sur le chrono (ligne 52) et une annonce « Mobilité terminée » au passage `isOver` (via une sous-vue avec `.onChange(of: isOver)`, `TimelineView` ne permet pas d'effets de bord).
- [ANNOUNCE] CF/CheckInView.swift:94-97 — l'estimation se met à jour à chaque réponse sans annonce — proposé : annoncer l'estimation quand la troisième réponse la rend disponible (`.onChange(of: form.estimatedScore)`), texte `estimationAccessibilityLabel` pur.
- Hors périmètre A (partie live / récap) : fin du repos et record battu restent à traiter côté LiveSessionFeature / récap.

### DYNTYPE

- [DYNTYPE] DS/Components/CategoryBadge.swift:27-28,31-32 — `lineLimit(1)` sur le nom + marqueur (« FORME NORMALE · EN CALIBRATION (9 NUITS) ») : tronqué aux grandes tailles, alors que c'est une valeur d'état — proposé : retirer `lineLimit`, `.fixedSize(horizontal: false, vertical: true)`, remplacer `Capsule()` par `RoundedRectangle(cornerRadius: 13)` quand `dynamicTypeSize.isAccessibilitySize`, garder `minHeight: 26`.
- [DYNTYPE] TF/Views/LoadCard.swift:57-60 — `zoneBadge` : `lineLimit(1)` sur « Risque de blessure » + capsule à hauteur 24 — même remède (retirer `lineLimit`, rectangle arrondi aux tailles d'accessibilité).
- [DYNTYPE] TF/Views/TrendTilesView.swift:34-35,39-40 — titre `lineLimit(1)` / `minimumScaleFactor(0.7)` et valeur `lineLimit(1)` / `minimumScaleFactor(0.6)` : sur deux colonnes à xxxLarge la valeur « 7 h 12 » rétrécit à 60 % ; la grille ne passe à une colonne qu'à `isAccessibilitySize` (ligne 19) — proposé : une colonne dès `dynamicTypeSize >= .xxxLarge`, retirer `lineLimit(1)` et `minimumScaleFactor` de la valeur, laisser le titre sur 2 lignes.
- [DYNTYPE] TF/Views/RecoveryCard.swift:149-151,163-164 — les 3 colonnes de facteurs ne s'empilent qu'à `isAccessibilitySize`, et le titre garde `lineLimit(1)` + `minimumScaleFactor(0.8)` : « VARIABILITÉ » tronque entre xxLarge et xxxLarge — proposé : seuil `>= .xxLarge` pour la pile verticale, retirer `lineLimit(1)` du titre.
- [DYNTYPE] DS/Components/FocusSlider.swift:20-29,38-44 — deux HStack (« Force | 60 / 40 | Endurance » et « 100 % musculation | Hybride | 100 % running ») qui ne passent jamais en colonne : à accessibility3 les trois textes se tassent / se tronquent (la seconde rangée est masquée à VoiceOver mais reste visible) — proposé : `@Environment(\.dynamicTypeSize)` et `AnyLayout` VStack aux tailles d'accessibilité, ou `ViewThatFits`.
- [DYNTYPE] CF/CheckInView.swift:95 — `PulseFont.score(size: 64)` taille fixe pour l'estimation — proposé : `@ScaledMetric(relativeTo: .largeTitle) private var scoreSize: CGFloat = 64` (comme `digitSize` dans TF/Views/MobilitySheet.swift:10), avec `lineLimit(1).minimumScaleFactor(0.5)`.
- [DYNTYPE] DS/Components/Interaction.swift:94-105 — `IconChip` : rond de `size` fixe (40 par défaut) et police `size * 0.4` fixes ; l'icône ne grandit pas avec le texte — proposé : `@ScaledMetric(relativeTo: .body)` pour le cadre et la police, plafonné à ~2x.
- [DYNTYPE] DS/Components/Interaction.swift:56-57,147 — `PillButtonStyle` : `lineLimit(1)` + `fixedSize()` : jamais tronquée, mais déborde de l'écran à accessibility3 (« Mon programme » + « + Nouvelle » côte à côte dans `PulseSectionHeader`, ligne 147, sans retour à la ligne) — proposé : `fixedSize(horizontal: false, vertical: true)` sans `lineLimit`, et dans `PulseSectionHeader` un `VStack(alignment: .leading)` des actions quand `isAccessibilitySize`.
- [DYNTYPE] DS/Gauge/RecoveryGauge.swift:151-160 — le score est dimensionné par la largeur du cadran (`side * 0.32`, `idealWidth` 240/116) et « sur 100 » par `max(10, side*0.045)` : ne suit pas Dynamic Type ; la jauge est `.ignore` donc VoiceOver est servi, mais le texte visible reste à 10-13 pt — proposé : acceptable pour le score (grand chiffre, cadran), mais utiliser `@ScaledMetric` pour « sur 100 » ou le masquer au-delà de xxxLarge ; documenter.
- [DYNTYPE] WF/Views/*, PW — TOUTES les polices des widgets (sauf RecoveryWidgetSmallView) sont `.system(size: N)` (non adaptatives), donc le plafond `.dynamicTypeSize(...xxxLarge)` ne sert à rien et les tailles 8 à 12 pt ne grandissent jamais : LoadWidgetSmallView.swift:37,44,52,92 ; StreakWidgetSmallView.swift:36,44,48,94 ; NextWorkoutWidgetSmallView.swift:36,43,51 ; TodaySessionWidgetMediumView.swift:36,47,51,63,77 (tag 9,5 pt, icône 8 pt),91 ; TodaySessionWidgetRectangularView.swift:18,34,36 ; WeekWidgetLargeView.swift:33,37,51,75,95,98,102,112,117,156,159 ; StreakWidgetCircularView.swift:17,19 ; LoadWidgetCircularView.swift:17 — proposé : `@ScaledMetric(relativeTo: .caption/.body)` pour chaque taille (ou styles de texte), plafond `...accessibility3` (autorisé par 7.1) ou `...xxxLarge` si la mise en page casse ; relever le tag « Ajustée » à >= 11 pt.
- [DYNTYPE] WF/Views/TodaySessionWidgetMediumView.swift:94 — `.frame(height: 30)` fixe sur le faux bouton « Démarrer » : hauteur fixe sur du texte — proposé : `.frame(minHeight: 30)`.
- [DYNTYPE] WF/Views/StreakWidgetSmallView.swift:96-97, WeekWidgetLargeView.swift:100-104,161, NextWorkoutWidgetSmallView.swift:45-46,53-54, TodaySessionWidgetMediumView.swift:49,52 — `lineLimit(1)` sur des valeurs (« 3 sur 5 cette semaine », titre de séance, méta) : troncature possible dès que les polices grandiront (après correction ci-dessus) — proposé : `lineLimit(2)` ou `minimumScaleFactor(0.7)` sur ces champs.
- [DYNTYPE] PW/SessionLiveActivityViews.swift:129-132,155,172-175 — écran verrouillé : titre `lineLimit(1)` et chrono `largeTitle` en HStack, plafonnés à accessibility1 : le titre tronque, acceptable car l'étiquette VoiceOver porte le texte complet ; à confirmer visuellement.
- [DYNTYPE] DS/Components/WeekdayToggleRow.swift:14-34 — 7 boutons à largeur `maxWidth: .infinity` : à 375 pt de large, (375 - 32 - 36) / 7 = 43,9 pt (voir TARGET) ; initiale seule, rien de tronqué.
- Déjà traités (bon) : FactorColumns pile (RecoveryCard.swift:149), SessionCardHeader / StrengthSessionCard / SessionOverview / DeloadOfferCard / MobilitySheet.controls / WhyView.ChangeRow / SignalBar / ResumeSessionBar passent en colonne à `isAccessibilitySize` ; LoadGauge utilise `@ScaledMetric` ; PulseSectionHeader, CardHeader et LoadCard.header utilisent `ViewThatFits` ; ChoicePills et `PillFlowLayout` retournent à la ligne.

### MOTION

- [MOTION] TF/Views/TodayView.swift:45 — `.animation(.snappy, value: startTitle)` non gardé : fait entrer/sortir la barre « Démarrer » ancrée en glissant ; et DS/Components/Interaction.swift:241 `.transition(.move(edge: .bottom).combined(with: .opacity))` non gardé — proposé : `@Environment(\.accessibilityReduceMotion)` : `.animation(reduceMotion ? nil : .snappy, value:)` et transition `reduceMotion ? .opacity : .move(...).combined(with: .opacity)` (via l'utilitaire DS ci-dessous).
- [MOTION] DS/Components/AuraBackground.swift:33-36 — halo : animation `repeatForever` démarrée seulement si `!reduceMotion` à l'apparition ; si l'utilisateur active « Réduire les animations » pendant que la vue est affichée, la dérive continue jusqu'à la recréation — proposé : `.onChange(of: reduceMotion)` qui remet `phase` à une valeur fixe sans animation ; marge faible.
- [MOTION] DS/Gauge/RecoveryGauge.swift:154 — `contentTransition(.numericText(...))` n'est pas conditionné : l'animation propre (ligne 155) est gardée, mais une transaction animée du parent (par ex. l'`.animation(.snappy, ...)` de TodayView.swift:45 enveloppe tout l'écran) peut faire rouler les chiffres — proposé : `.contentTransition(reduceMotion ? .identity : .numericText(...))`.
- [MOTION] CF/CheckInView.swift:96 — `contentTransition(.numericText())` non gardé (inerte aujourd'hui, aucune animation ne l'enclenche ; il animerait dès qu'une transaction animée englobe la vue) — proposé : même garde.
- Il n'existe pas d'utilitaire DS : chaque site relit `@Environment(\.accessibilityReduceMotion)` (AuraBackground, ButtonStyles, Interaction x2, RecoveryGauge). Proposé (règle 7.1) : `PulseMotion` dans DS (par ex. `DS/Theme/PulseMotion.swift`) avec `View.pulseAnimation(_ animation:, value:)` (nil si Réduire les animations), `pulseTransition(_ transition:)` (repli sur `.opacity`) et `PulseMotion.withAnimation(_:_ body:)` ; test sur une fonction pure `PulseMotion.resolved(animation:, reduceMotion:) -> Animation?`.
- Animations système non pilotables (à mettre dans la liste manuelle) : `.tabBarMinimizeBehavior(.onScrollDown)` (Pulse/Root/MainTabView.swift:86), `GlassEffectContainer` (Interaction.swift:251), `ProgressView(timerInterval:)` de la Live Activity (PW/SessionLiveActivityViews.swift:40).

### TARGET

- [TARGET] TF/Views/TodayView.swift:172 — pastille de synchro `minHeight: 32` sans extension de zone tactile — proposé : `.padding(.vertical, 6)` après le fond + `.contentShape(Rectangle())` (comme `PillBody`, Interaction.swift:69-70), le visuel reste à 32.
- [TARGET] DS/Components/ChoicePills.swift:25 — `PillButton` `minHeight: 42` (< 44) — proposé : `minHeight: 44`.
- [TARGET] DS/Components/WeekdayToggleRow.swift:23 — 44 de haut mais largeur calculée 43,9 pt sur un écran de 375 pt — proposé : `spacing: 4` (>= 44,7) ou `frame(minWidth: 44)`.
- [TARGET] DS/Components/Interaction.swift:94 — `IconChip` à 40 pt par défaut : à l'intérieur d'un `Button` (appelants hors périmètre, à vérifier) la cible est < 44 — proposé : `contentShape(Rectangle()).frame(minWidth: 44, minHeight: 44)` côté appelant, ou taille par défaut 44. L'appel de l'accueil (TodayView.swift:154) est déjà à 44.
- OK : PrimaryButton / SecondaryButton (56), PillButtonStyle (36 + 2 x 4 = 44), WhyLink (44), SessionRestButton (44), boutons de ResumeSessionBar, WeekdayToggleRow (hauteur). Widgets : les pseudo-boutons (« Démarrer » du widget moyen) ne sont pas des cibles (tout le widget est un `widgetURL`).

### ORDER

- Aucun défaut : accueil (date, titre, profil, synchro, carte récupération, séance, charge, tendances), carte récupération (en-tête, jauge, facteurs, lien), « Pourquoi » (lecture, changements, signaux, boutons) lisent dans l'ordre visuel ; le bouton ancré « Démarrer » est dans `safeAreaInset(edge: .bottom)`, donc lu après le contenu.
- Remarque : TF/Views/RecoveryCard.swift:43-44, `onTapGesture` sur toute la dalle n'est pas atteignable à VoiceOver ; l'action « Pourquoi ce score ? » (ligne 38) et le bouton `WhyLink` compensent : OK.
- Remarque : Pulse/Root/MainTabView.swift:39-47, le bandeau « Reprendre la séance » est placé avant les onglets (lu en premier) : correct. Ajouter `.accessibilityAddTraits(.updatesFrequently)` au chrono `Text(startedAt, style: .timer)` (Pulse/Root/ResumeSessionBar.swift:29).

---

## 2. Textes d'accessibilité : où ils vivent et où mettre les fonctions pures

Déjà purs et testables (à réutiliser) : `RecoveryGauge.accessibilityLabel(score:category:)` (DS/Gauge/RecoveryGauge.swift:194), les `*WidgetContent.make` (WF/*Content.swift, champ `accessibilityLabel`), `SessionActivityText.accessibilityLabel` (WF/SessionActivityText.swift:19), `MobilitySheet.spokenText` (TF/Views/MobilitySheet.swift:101), `TrendTile.accessibilityLabel` (TF/Trends/TrendTile.swift), `FactorFormatter` / `FactorDisplay` (TF/FactorFormatter.swift), `DoneCard.statsText` (TF/Session/DoneCard.swift), `PulseFormat` (DS/Presentation/PulseFormat.swift), `LoadCardContent` (TF/Load/LoadCardContent.swift), `WhyContent` (TF/Why/WhyContent.swift), `RecoveryCategory+Presentation.swift` (DS/Presentation).
Construits dans la vue (à extraire pour les tester) : étiquette de `SignalBar` (WhyView.swift:179), `gaugeLabel` de `LoadCard` (LoadCard.swift:74), `estimationAccessibilityLabel` (CheckInView.swift:132), `SessionOverview.statsText` / `musclesLabel` (StrengthSessionCard.swift:143-153), `syncText` (TodayView.swift:181).
Emplacements proposés : `TF/Session/SessionSummary+Spoken.swift`, `TF/FactorFormatter.swift` (ajout `FactorDisplay.accessibilityLabel`), `TF/Trends/TrendTile.swift`, `TF/TodayModel+Announcement.swift`, `CF/CheckInText.swift`, `DS/MuscleMap/MuscleMapSummary.swift`, `DS/Theme/PulseMotion.swift`, `WF/WidgetPlanningText.swift` (allure parlée, jours de la semaine).

---

## 3. Paires texte / fond du thème clair à énumérer dans le test de contraste

Seuils : 4,5:1 pour le texte normal, 3:1 pour les grands chiffres et éléments graphiques porteurs d'information. « ECHEC » = sous le seuil de l'usage indiqué.

Fonds clairs : `background` / `page` 0xEFECE5, `surface` 0xFBFAF7 (= `opal`), `surface2` 0xE6E2DA, `muscleBody` 0xE3DFD7, `muscleOff` 0xCFCAC0.

| Texte (jeton) | Fond | Ratio | Usage | Verdict |
|---|---|---|---|---|
| text 0x111110 | background / surface / surface2 | 16,01 / 18,10 / 14,62 | titres, valeurs | OK |
| text2 0x57554F | background / surface / surface2 | 6,32 / 7,14 / 5,77 | détails, étiquettes (déjà testé pour bg et surface) | OK |
| muted 0x86837C | background / surface / surface2 | 3,21 / 3,62 / 2,93 | eyebrow par défaut, libellés jauge, notes, widgets | ECHEC texte ; ok graphique sur surface (chevron) |
| ok 0x111110 | background / surface | 16,01 / 18,10 | état bon | OK |
| warn 0x77746D | background / surface / surface2 | 3,95 / 4,47 / 3,61 | pastille « Charge élevée », widget Charge | ECHEC texte (graphique OK) |
| bad 0xD9391A | background / surface / surface2 | 3,91 / 4,42 / 3,57 | erreur, « Risque », surmenage | ECHEC texte |
| run 0x4E5764 | background / surface / surface2 | 6,20 / 7,01 / 5,66 | course, sous-charge | OK |
| gold 0x8A743F | background / surface / surface2 | 3,83 / 4,33 / 3,50 | records (si texte) | ECHEC texte |
| opalInk 0x0B0B0A | opal 0xFBFAF7 | 18,87 | texte sur la dalle | OK |
| opalMuted (0x0B0B0A à 0,58) | opal (mélangé) | 4,79 | détails de la dalle | OK (hors trame) |
| opalOK 0x111110 | opal | 18,10 | badge positif sur dalle | OK |
| opalWarn 0x6D6A64 | opal | 5,16 | badge fatigue sur dalle | OK |
| opalBad 0xD9391A | opal / fond du badge (opal 0,85 sur bg) | 4,42 / 4,34 | badge surmenage | ECHEC texte |
| text (badge) | fond du badge (opal 0,85 sur bg) | 17,78 | nom de catégorie | OK |
| accentInk Ivoire 0xF7F3EC | accent 0x17140F | 16,61 | bouton principal | OK |
| accentInk Acier 0xF2F5F8 | accent 0x0F141B | 16,89 | idem | OK |
| accentInk Ivoire / Acier | accent2 0x4D473E / 0x434B56 (fin du dégradé) | 8,30 / 8,07 | bas du bouton, fond du widget Série | OK |
| accent Ivoire / Acier | background | 15,57 / 15,67 | bouton lien | OK |
| accent Ivoire / Acier | surface | 17,60 / 17,71 | pastille « Ajustée », puces | OK |
| accent | accent à 0,1 (`soft`) sur background | 12,71 / 12,78 | IconChip .accent, SessionBadge | OK |
| text2 | surface2 | 5,77 | badge « Planifiée » | OK |
| page 0xEFECE5 | ink 0x0B0B0A | 16,69 | IconChip .inverted | OK |
| ok / warn / bad / run / gold | leur fond `…Soft` posé sur surface | 14,68 / 3,87 / 3,51 / 5,88 / 3,75 | si un texte est posé sur `warnSoft`, `badSoft`, `goldSoft` | ECHEC pour warn, bad, gold |

Éléments graphiques porteurs d'information (3:1) :

| Élément | Contre | Ratio | Verdict |
|---|---|---|---|
| Niveau 1 de la carte musculaire (accent 0,32 + off), Ivoire | muscleOff / muscleBody | 1,95 / 2,40 | ECHEC |
| Niveau 2 (0,56) | muscleOff / muscleBody | 3,60 / 4,42 | OK |
| Niveaux 3 et 4 | muscleOff | 7,10 / 11,25 | OK |
| Acier, niveaux 1 à 4 | muscleOff | 1,96 / 3,63 / 7,18 / 11,32 | idem |
| muscleOff / muscleBody | page | 1,23 (off/body), 1,13 (body/bg) | décor, pas d'information |
| Points éteints de LoadGauge (text2 0,45 ; text 0,4 ; warn 0,4 ; bad 0,4) | background | 2,01 / 2,56 / 1,61 / 1,76 | piste ; l'information est dans le texte ; à documenter |
| Points allumés warn / text2 0,9 | background | 3,95 / 5,01 | OK |
| Bordure de pilule non sélectionnée (ink 0,18) | background | 1,48 | le texte identifie le contrôle ; état sélectionné = remplissage + gras + trait `.isSelected` : OK |
| Segments inactifs de StepProgressBar (ink 0,12) | background | 1,29 | décor, étiquette « Étape x sur y » : OK |
| Bordure jour de repos (ink 0,3) | background | 2,00 | l'état est dit par la diagonale et l'étiquette : OK |

Test existant (DS/Tests/.../PaletteTests.swift:55-69) : seuls text et text2 sur background et surface sont vérifiés. À ajouter : muted, warn, bad (et opalBad), gold, opalMuted, opalWarn, accentInk/accent, accentInk/accent2, accent/background, text2/surface2, avec les seuils ci-dessus ; le contrôle `chroma(bad) > 0,7` (PaletteTests.swift:92-93) doit rester vrai (0xC02B08 : 0,72). Si les widgets restent en apparence système, ajouter les paires sombres (muted/surface sombre 3,78 : ECHEC).

---

## 4. Animations : inventaire et respect de Réduire les animations

| Fichier:ligne | Animation | Respecte reduceMotion ? |
|---|---|---|
| DS/Components/AuraBackground.swift:35 | halo qui dérive (`easeInOut 14 s repeatForever`) | Oui à l'apparition (garde ligne 34) ; pas de réaction si le réglage change en cours d'affichage |
| DS/Components/ButtonStyles.swift:53,55 | `scaleEffect` 0,97 + `spring` sur l'appui | Oui (`reduceMotion ? nil`) |
| DS/Components/ButtonStyles.swift:57 | `sensoryFeedback` impact | Retour haptique, pas un mouvement |
| DS/Components/Interaction.swift:22-24 | `PressableButtonStyle` : échelle 0,975 + opacité, `spring` | Oui |
| DS/Components/Interaction.swift:71-73 | `PillButtonStyle` : échelle 0,95, `spring` | Oui |
| DS/Components/Interaction.swift:241 | transition `move(bottom) + opacity` de la barre ancrée | NON |
| TF/Views/TodayView.swift:45 | `.animation(.snappy, value: startTitle)` | NON |
| DS/Gauge/RecoveryGauge.swift:154-155 | `numericText` + `.animation(.snappy)` sur le score | Animation gardée ; `contentTransition` non gardé |
| DS/Gauge/RecoveryGauge.swift:171-177 | révélation de la jauge (`spring` 1,1 s, graduations et aiguille animables `TickRing` / `Needle`) | Oui (pose directe si `reduceMotion` ou `animatesReveal == false`) |
| CF/CheckInView.swift:96 | `contentTransition(.numericText())` sur l'estimation | NON (inerte sans transaction animée) |
| TF/Views/MobilitySheet.swift:47 | `TimelineView(.periodic 1 s)` : le chrono tictaque | Pas une animation décorative |
| Pulse/Root/MainTabView.swift:86 | `tabBarMinimizeBehavior(.onScrollDown)` | Système, non pilotable |
| DS/Components/Interaction.swift:251 | `GlassEffectContainer` / `glassEffect` | Système |
| PW/SessionLiveActivityViews.swift:40 | `ProgressView(timerInterval:)` (anneau du repos) | Système |
| PW, WF | aucune autre animation (WidgetKit rend des images fixes ; `animatesReveal: false` pour la jauge) | n/a |

Aucun utilitaire DS commun : les sites gardés lisent chacun `@Environment(\.accessibilityReduceMotion)`.

---

## 5. Aperçus SwiftUI (#Preview) et accessibility3

Aucun aperçu du périmètre ne pose `.dynamicTypeSize(.accessibility3)` (aucune occurrence de `accessibility3` dans les dossiers audités ; les `dynamicTypeSize` trouvés sont des plafonds de widgets).

| Écran / composant | Aperçus existants | accessibility3 |
|---|---|---|
| Accueil complet (TF/Views/TodayPreviewSupport.swift:132-181) | 12 aperçus de `TodayPreviewHost` (bonne nuit, charge 1,12, charge 1,7, mauvaise nuit, surmenage, repos <65, fractionné, sans VFC, check-in, jour de repos, jour de course, sans programme, avant 4 h) | Non |
| LoadCard (TF/Views/LoadCard.swift:88,95) | 2 | Non |
| TrendTilesView (TF/Views/TrendTilesView.swift:59) | 1 | Non |
| WhyView (TF/Views/WhyView.swift:269-278) | 3 (DEBUG) | Non |
| MobilitySheet (TF/Views/MobilitySheet.swift:135) | 1 | Non |
| RecoveryCard, StrengthSessionCard, SessionCard, DeloadOfferCard, LiveSessionCards | pas d'aperçu propre (couverts par l'accueil) | Non |
| CheckInView (CF/CheckInView.swift:141,145) | 2 (vide, rempli) | Non |
| Pulse/Root (MainTabView, ResumeSessionBar, AppRootView) | AUCUN aperçu | Non |
| DS : AuraBackground, ButtonStyles, Cards, CategoryBadge (x2), ChoicePills, FocusSlider, Halftone, Interaction, LoadGauge, PlateBarDiagram, Sparkline, StepProgressBar, WeekdayToggleRow, RecoveryGauge (x2), MuscleMapView | 1 ou 2 chacun | Non |
| WF : toutes les vues widgets | 1 ou 2 chacune | Non |
| PW : widgets (Récupération, Série, Séance, Charge, Prochaine séance, Semaine) et SessionLiveActivity (4 aperçus) | oui | Non |

À ajouter (priorité) : un aperçu `accessibility3` pour l'accueil (`TodayPreviewHost` bonne nuit + check-in + charge risque), WhyView, MobilitySheet, CheckInView, FocusSlider, ChoicePills, CategoryBadge, ResumeSessionBar (aperçu à créer), LoadCard ; pour les widgets, aperçu au plafond retenu (xxxLarge ou accessibility3).

---

## 6. Checked, no finding

- DS/Components/Halftone.swift, PlateBarDiagram.swift, Sparkline.swift (masqués, décor), StepProgressBar.swift (étiquette « Étape x sur y » OK), Cards.swift (hors remarque de voile), ButtonStyles.swift (cibles 56, animations gardées), DS/Gauge/GaugeGeometry.swift, DS/MuscleMap/{MuscleMapArtwork, MuscleMapRegion, SVGArc, SVGPathLexer, SVGPathParser}.swift (pur, pas de vue).
- TF/Views/SessionCard.swift, DeloadOfferCard.swift (étiquettes OK, empilé aux grandes tailles), TF/TodayModel*.swift, TodayEnvironment.swift, TodayIdentifiers.swift, TF/Session/{LiveReading, SessionCardState, SessionPlanLine}.swift (texte ; `SessionPlanLine.prescription` « 3 × 6–10 » est repris par WhyChanges : envisager une version parlée « 3 fois 6 à 10 »), TF/Why/*.swift (la formule « Score = 50 % × 59 + … = 58 » pourrait avoir une version parlée, faible priorité), TF/Mobility/*.swift.
- CF/CheckInForm.swift, CheckInQuestion.swift.
- Pulse/Root/AppRootModel.swift, AppRouter.swift, MainTabView.swift (onglets avec libellés, alertes OK), ResumeSessionBar.swift (boutons étiquetés « Reprendre la séance » / « Abandonner la séance », bloc `.combine`, empilé aux grandes tailles).
- PW/*TimelineProvider.swift, PulseWidgetsBundle.swift, WidgetIntents.swift, RecoveryScoreControlWidget.swift, LaunchSessionControlWidget.swift (libellés français OK), RecoveryWidget.swift, StreakWidget.swift, TodaySessionWidget.swift, NextWorkoutWidget.swift, WeekWidget.swift, LoadWidget.swift (étiquettes d'accessoire en ligne présentes ; `widgetURL` OK).
- PW/SessionLiveActivity.swift et SessionLiveActivityViews.swift : boutons « Retirer 30 secondes de repos », « Ajouter 30 secondes… », « Passer le repos », titre et série suivante lus d'un tenant, anneau masqué, cibles 44 : OK (voir COLOR pour l'accent sur noir).
- WF/RecoveryWidgetContent.swift (étiquette « Récupération 58 sur 100, fatigue modérée, séance allégée »), LoadWidgetContent.swift, WidgetSnapshotFile.swift, RecoveryWidgetTimeline.swift, RecoveryWidgetSmallView / CircularView.swift, LoadWidgetCircularView.swift, StreakWidgetCircularView.swift, TodaySessionWidgetRectangularView.swift (étiquettes portées par le contenu, vues `.ignore`).

---

## 7. Résumé (5 lignes)

1. Compte : COLOR 10, LABEL 6, GROUP 10, HIDE 0, CHART 0 (aucun Swift Charts), ANNOUNCE 4, DYNTYPE 14, MOTION 4 (+ utilitaire DS `PulseMotion` manquant), TARGET 4, ORDER 0.
2. Pire n°1 : contraste AA, `muted` (3,2 à 3,6:1), `bad` (3,9 à 4,4:1) et `warn` utilisés en texte dans l'app et les widgets ; les widgets rendent aussi les jetons sombres (apparence système) et l'accent de la Live Activity peut devenir de l'encre sur noir.
3. Pire n°2 : DYNTYPE, toutes les polices des widgets sont en tailles fixes (8 à 12 pt) donc le plafond xxxLarge est sans effet, et plusieurs valeurs/états tronquent (`CategoryBadge`, zone de `LoadCard`, `TrendTilesView`, `FocusSlider`).
4. Pire n°3 : VoiceOver, aucune annonce (score prêt, erreur de check-in, fin de mobilité), colonnes de facteurs lues avec « — » / « bpm » / « ms », pilules du check-in sans leur question, carte musculaire sans niveaux.
5. Animations : sites existants bien gardés (boutons, jauge, aura) mais barre « Démarrer » (TodayView:45, Interaction:241) et `numericText` ne le sont pas ; aucun aperçu `accessibility3`.
