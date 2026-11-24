# Pulse — Phases de sommeil et écran Nuit

Date : 2026-11-24. Statut : approuvée par Mathéo le 2026-11-24 (« ok »).

Références : spec V1 `2026-10-31-pulse-v1-design.md` (§6.1 agrégation des nuits, score), spec M3 `2026-11-01-pulse-m3-onboarding-tableau-de-bord-design.md` (Aujourd'hui, tuiles de tendance), spec M7 `2026-11-20-pulse-m7-stats-profil-design.md` (§7 vue Biométrie, §14 export), spec M8 `2026-11-22-pulse-m8-app-store-design.md` (frontière iCloud / appareil, accessibilité, export et effacement).

## 1. Intention

Mathéo veut « mieux voir ses données » : les phases de sommeil, et des données lisibles. Quand on lui a demandé ce qu'il cherche à comprendre le matin, il a répondu « je te fais confiance » (2026-11-24). L'intention ci-dessous est donc un **choix du constructeur**, comme tout ce qui suit sauf mention contraire.

- **Comprendre une nuit précise.** Le score du matin dépend du sommeil, mais l'app ne montre que deux chiffres : le total et le profond. Pour savoir pourquoi une nuit était mauvaise, il faut voir quand on s'est couché, quand on s'est réveillé, combien de fois on s'est réveillé et comment les phases se sont enchaînées.
- **Voir l'évolution par phase.** Sur 7 jours à 1 an, savoir si le profond ou le paradoxal baisse, et pas seulement si la durée totale baisse.

## 2. État actuel (ce que le code fait aujourd'hui)

- `HealthKitReader.sleepIntervals` lit les six valeurs d'`HKCategoryValueSleepAnalysis` (au lit, éveillé, endormi sans phase, léger, profond, paradoxal) en `SleepInterval`. Ces intervalles bruts vivent dans le cache local (`CachedHealthSample.sleepStage`) pendant 62 jours (`healthCacheRetention`).
- `NightAggregator` rattache chaque intervalle « endormi » au jour de réveil (fenêtre de 18 h la veille à midi), puis résume la nuit en `SleepSummary(asleepMinutes, deepMinutes?)`. `deepMinutes` vaut `nil` quand la source ne donne aucune phase.
- `DailyRecovery` porte `asleepMinutes` et `deepMinutes`, gardés en local dans `StoredRecoveryReading` (jamais sur iCloud depuis M8a). `BiometryStats` en tire les points de sommeil de Stats sur 7 jours à 1 an.
- L'affichage se limite à :
  - la tuile « Sommeil, 14 jours » d'Aujourd'hui (moyenne et petite courbe), qu'on ne peut pas toucher ;
  - la carte « Sommeil » de Stats > Biométrie, où chaque barre se lit en « profond » et « autres phases » ;
  - la phrase du facteur sommeil dans « Pourquoi ».
- On ignore encore si le Fitbit de Mathéo envoie les phases à Apple Santé (question ouverte du M1, vérifiable dans l'écran de diagnostic). La conception doit marcher dans les deux cas.

## 3. Objectifs, non-objectifs, anti-objectifs

### Objectifs
1. Un **écran Nuit** qui montre une nuit :
   - l'heure d'endormissement et de réveil ;
   - un hypnogramme (les phases au fil de la nuit) ;
   - le temps passé dans chaque phase, avec sa part de la nuit et l'écart à la moyenne des 14 nuits précédentes ;
   - le nombre de réveils.
2. On ouvre l'écran Nuit en touchant la tuile Sommeil d'Aujourd'hui, ou par un lien « Voir les nuits » sur la carte Sommeil de Stats > Biométrie. On passe d'une nuit à l'autre avec ‹ ›.
3. Dans Stats > Biométrie, les barres de sommeil se découpent par phase (profond, léger, paradoxal, endormi sans phase) sur les quatre périodes, 1 an compris. La tuile « Sommeil moyen » donne la part de chaque phase.
4. Le total des phases s'enregistre chaque jour avec les autres valeurs brutes, en local, pour que les vues 90 jours et 1 an gardent les phases au-delà des 62 jours du cache.
5. Tout cela respecte la rigueur App Store du projet :
   - VoiceOver lit l'hypnogramme et les barres (résumé et `AXChartDescriptor`) ;
   - le texte s'adapte à la taille choisie (Dynamic Type) ;
   - les nouvelles valeurs figurent dans l'export ;
   - elles disparaissent avec « Effacer mes données ».

### Non-objectifs
- Aucune nouvelle autorisation Apple Santé : le sommeil est déjà lu.
- Aucun changement du score de récupération ni de `SleepScorer`.
- Pas de fréquence cardiaque ni de VFC dessinées au fil de la nuit.
- Pas d'objectif de sommeil, d'horaire conseillé, de régularité du coucher ni de conseils.
- Pas d'« efficacité du sommeil » : elle demande un temps au lit fiable, que beaucoup de sources n'écrivent pas.
- Pas de widget, pas d'Apple Watch, pas de synchronisation iCloud des phases.
- Pas de nouvelle entrée depuis « Pourquoi » ni depuis le Planning.

### Anti-objectifs (ce qui serait un échec même si ça marche)
- Le score d'un jour change à cause de ce travail.
- Le total « endormi » de l'écran Nuit diffère du sommeil que le score a utilisé pour la même nuit, à échantillons Apple Santé égaux : les deux appliquent la même règle. *Choix du constructeur :* l'écran Nuit se reconstruit depuis le cache, qui reflète Apple Santé aujourd'hui. Si une synchronisation Fitbit tardive arrive après le figeage du score, l'écran Nuit montre la nuit à jour. Le score, lui, reste celui du matin.
- Une phase ne se reconnaît qu'à sa couleur.
- Un vocabulaire médical ou alarmant : l'app montre, elle ne diagnostique pas.
- Les phases partent sur iCloud.

## 4. Contraintes

- SwiftUI, iOS 26 minimum, Swift Charts, architecture existante en paquets (`PulseDomain`, `PulseRecoveryEngine`, `PulsePersistence`, `PulseFeatures`, `PulseDesignSystem`), textes en français dans les `Localizable.xcstrings` des modules, `swiftlint --strict`.
- Logique pure dans `PulseRecoveryEngine` et `PulseServices`, testée avec Swift Testing comme le reste.
- Le magasin local (`StoredRecoveryReading`) n'est pas soumis à CloudKit ; ajouter des attributs optionnels passe par une nouvelle version de schéma (V7) et une migration légère dans `PulseMigrationPlan`.
- **Ce poste Windows n'a ni Swift ni Xcode.** Le code et les tests s'écrivent ici, mais la compilation, `make test` et l'essai dans le simulateur se font sur le Mac de Mathéo ou dans Xcode Cloud. Le plan doit découper le travail en étapes qu'on peut vérifier une à une sur Mac.

## 5. Approches envisagées

1. **Écran Nuit + Stats par phase (retenue).** Une nuit précise se lit dans un écran dédié, et l'évolution se lit dans Stats. C'est ce qui sert les deux intentions.
2. **Seulement Stats par phase.** C'est moins de travail, mais on ne voit jamais une nuit précise. Or c'est ce qui explique le mieux un score du matin.
3. **Hypnogramme sur Aujourd'hui.** Tout est visible d'un coup d'œil, mais Aujourd'hui est déjà dense et le graphique noierait le score.

Le constructeur a retenu la 1, avec l'accord implicite de Mathéo (« je te fais confiance »).

## 6. Conception

### 6.1 Reconstituer une nuit (`PulseRecoveryEngine`)

Nouveau type de domaine `NightSleep` (dans `PulseDomain/Health`) :
- `day` : minuit local du jour de réveil, comme `NightSample.day` ;
- `segments: [SleepSegment]` : des intervalles triés et sans chevauchement, chacun avec un `stage` parmi éveillé, endormi sans phase, léger, profond et paradoxal ;
- `fellAsleep` et `wokeUp` : le début du premier et la fin du dernier segment endormi ;
- `minutes` par phase ; `awakenings` : le nombre de réveils ;
- `hasStages` : vrai si au moins un segment est en léger, profond ou paradoxal.

Nouveau `NightSleepBuilder` (pur, à côté de `NightAggregator`) :
- **Rattachement.** Il reprend exactement la fenêtre et le filtre de `NightAggregator` (intervalles endormis dont la fin tombe entre 18 h la veille et midi). Il faut extraire ces règles en un seul endroit partagé pour qu'elles ne divergent jamais.
- **Chevauchements.** Deux sources peuvent écrire en même temps (le Fitbit et l'iPhone). La priorité est : profond > paradoxal > léger > endormi sans phase > éveillé. On découpe la nuit aux bornes de tous les intervalles et chaque tranche prend la phase la plus prioritaire qui la couvre. Avec cette règle :
  - les minutes de profond égalent l'union des intervalles profonds, donc le `deepMinutes` actuel ;
  - la somme profond + paradoxal + léger + sans phase égale l'union des intervalles endormis, donc l'`asleepMinutes` actuel. C'est l'anti-objectif « total identique au score ».
- **Bloc principal** (*choix du constructeur*). La fenêtre de 18 h à midi peut contenir une sieste en fin d'après-midi, que l'agrégateur compte dans `asleepMinutes`.
  - On regroupe les segments endormis en blocs : un écart de plus de `blockGap` (60 minutes) sans sommeil sépare deux blocs.
  - Le bloc principal est celui qui a le plus de minutes endormies. `fellAsleep`, `wokeUp`, l'hypnogramme et les réveils ne portent que sur lui.
  - Les autres blocs sont gardés dans `otherBlocks` (début, fin, minutes) et restent comptés dans les totaux par phase, pour que le total reste celui du score. L'écran les liste sous l'hypnogramme : « Aussi compté : 18:05–18:30, 25 min ».
- **Éveil.** On ne garde que l'éveil compris dans le bloc principal. L'éveil avant l'endormissement et après le réveil n'apparaît pas. « Au lit » n'est jamais dessiné.
- **Trous sans donnée** (*choix du constructeur*). Une plage du bloc principal qui n'est couverte par aucun échantillon (montre retirée, trou de synchronisation) est « sans donnée ». Elle n'est pas dessinée : un vide reste dans l'hypnogramme. Elle ne compte ni dans `awakeMinutes` ni dans les réveils.
- **Réveils.** Un réveil est une plage continue d'éveil explicite, entre deux moments endormis du bloc principal, d'au moins `minimumAwakening` (le constructeur propose 2 minutes, en constante nommée et testée).
- **Part de la nuit.** Le dénominateur est la somme des lignes affichées dans la répartition (les phases endormies plus l'éveil du bloc principal), pour que les parts fassent 100 %.
- Un test vérifie, sur des jeux variés, que `NightSleepBuilder` et `NightAggregator` donnent les mêmes `asleepMinutes` et `deepMinutes` pour la même nuit.

`SleepSummary` gagne `coreMinutes`, `remMinutes`, `unspecifiedMinutes` et `awakeMinutes`, tous optionnels. Ils valent `nil` quand la source ne donne aucune phase, comme `deepMinutes` aujourd'hui. `NightAggregator` les remplit en s'appuyant sur `NightSleepBuilder`. `asleepMinutes` et `deepMinutes` gardent leur calcul actuel, et le test d'égalité ci-dessus le garantit.

### 6.2 Enregistrer les phases (`PulsePersistence`)

- `DailyRecovery` gagne `coreMinutes`, `remMinutes`, `unspecifiedMinutes` et `awakeMinutes` (optionnels). `DailyRecovery+Result` les remplit depuis la nuit.
- `StoredRecoveryReading` gagne les mêmes attributs, en schéma V7 avec une migration légère.
  - `apply`, `fill` et `isEmpty` les prennent en compte, ainsi que `RecoveryReadingJoin`.
  - `StoredDailyRecovery`, synchronisé avec iCloud, **ne change pas**.
- **Rattrapage.** Les lectures écrites avant cette version n'ont pas de phases. À chaque rafraîchissement, une lecture d'une nuit encore dans le cache qui n'a pas de phases reçoit les quatre valeurs.
  - On ne touche ni au score ni aux autres champs ; un jour figé (`frozenAt`) reste figé.
  - *Choix du constructeur :* le rattrapage ne s'applique que si l'`asleepMinutes` reconstruit depuis le cache égale celui de la lecture enregistrée. Ainsi, les phases enregistrées s'additionnent toujours au total enregistré. Sinon la lecture reste sans phases.
  - Le constructeur choisit où brancher ce rattrapage (`DayRefresher` ou le dépôt), à condition qu'il soit idempotent et testé.
- L'export CSV gagne les colonnes `core_minutes`, `rem_minutes`, `unspecified_minutes` et `awake_minutes`, à côté de `deep_minutes`. L'export JSON suit le même modèle. `StoreWiper` efface déjà `StoredRecoveryReading`.

### 6.3 Écran Nuit (nouvelle cible `NightFeature` dans `PulseFeatures`)

TodayFeature et StatsFeature l'utilisent tous les deux, d'où une cible à part. Elle dépend de `PulseServices` et `PulseDesignSystem`.

**Données.** Un `NightDetailService` (dans `PulseServices/Health`) lit les intervalles de sommeil du cache (`HealthSampleCache`, 62 jours). Il construit un `NightSleep` par jour de réveil qui a du sommeil, et la moyenne par phase des 14 nuits avec phases qui précèdent chacune. Il lit le cache seulement, sans relancer de lecture Apple Santé.

**Navigation.**
- L'écran s'ouvre sur la nuit dont le jour de réveil est le jour affiché par Aujourd'hui, ou sur la plus récente qui a du sommeil.
- ‹ et › passent à la nuit précédente ou suivante **qui a des données**, en sautant les nuits vides. Ils sont désactivés aux bouts.
- Sur Aujourd'hui, l'écran s'ouvre par un `navigationDestination` dans la `NavigationStack` existante. Dans Stats, il s'ouvre depuis la `NavigationStack` de `StatsScreen`.

**Contenu, de haut en bas :**
1. Le titre « Nuit du 23 au 24 nov. » et les boutons ‹ ›.
2. La durée endormie en grand (« 7 h 12 »), puis « Endormi à 23:41 · Réveillé à 07:05 · 2 réveils ».
3. **L'hypnogramme** (Swift Charts, `RectangleMark`) :
   - l'axe X couvre le temps, de l'endormissement au réveil ;
   - l'axe Y a quatre rangées libellées, de haut en bas Éveil, Paradoxal, Léger, Profond ;
   - chaque segment est un bloc coloré dans sa rangée ;
   - sans phases, deux rangées seulement : Éveil et Endormi.
4. **La répartition** : une ligne par phase (Profond, Léger, Paradoxal, Éveil, plus Endormi sans phase s'il y en a). Chaque ligne donne la durée, la part de la nuit, une barre proportionnelle et l'écart à la moyenne des 14 nuits (« +12 min »). Sans moyenne disponible, l'écart n'est pas affiché.
5. **Sans phases** : la répartition est remplacée par une phrase. « Ta source n'envoie pas les phases de sommeil à Apple Santé : seuls l'endormissement, le réveil et la durée sont connus. »

**Accessibilité.**
- Le titre et la durée sont des en-têtes.
- L'hypnogramme a un libellé qui résume la nuit (« Endormi à 23 h 41, réveillé à 7 h 05, 2 réveils, 1 h 32 de profond… ») et un `AXChartDescriptor` qui liste les segments.
- Chaque ligne de répartition se lit en une phrase.
- Les boutons ‹ › disent la nuit visée.
- Les rangées sont toujours libellées en texte, donc la couleur n'est jamais le seul repère.

**Couleurs.** Quatre couleurs de phase s'ajoutent aux jetons de `PulsePalette`. Elles doivent se distinguer en thème clair et sombre et rester lisibles avec un daltonisme courant. L'hypnogramme et les barres de Stats utilisent les mêmes. Le choix exact revient au constructeur.

### 6.4 Aujourd'hui

- La tuile Sommeil devient un bouton qui ouvre l'écran Nuit. Elle garde son contenu et l'indication « Ouvre le détail des nuits » pour VoiceOver.
- Les tuiles Variabilité et FC repos ne changent pas.
- Sans aucune nuit dans le cache, la tuile reste non touchable.

### 6.5 Stats > Biométrie

- `SleepPoint` gagne `coreMinutes`, `remMinutes` et `unspecifiedMinutes` (optionnels, moyennés par grain comme `deepMinutes`).
- **La barre se lit par phase**, de bas en haut : Profond, Léger, Paradoxal, Endormi sans phase.
  - *Grain mixte (choix du constructeur).* Sur 1 an, une semaine peut mêler des nuits avec et sans phases. La hauteur de la barre reste la moyenne d'`asleepMinutes` de toutes les nuits du grain. On calcule la part de chaque phase sur les seules nuits qui ont les phases, puis on l'applique à cette hauteur. Les tranches s'additionnent donc toujours à la barre.
  - Un grain sans aucune nuit à phases garde l'ancien découpage « Profond / Autres phases ». Les nuits enregistrées avant cette version, au-delà du rattrapage, sont dans ce cas.
  - La légende n'affiche que les phases présentes sur la période.
- La tuile « Sommeil moyen » donne « profond 18 % · paradoxal 22 % · léger 60 % » quand les phases sont connues. Sinon elle garde « profond x % ».
- La carte Sommeil gagne un lien « Voir les nuits » qui ouvre l'écran Nuit sur la nuit la plus récente.
- `StatsChartDescriptors.sleep` et les phrases parlées de `StatsText+Spoken` suivent ce découpage.
- L'éveil n'est pas empilé : il ne fait pas partie du sommeil.

## 7. Laissé au constructeur

- Les noms exacts des types et des fichiers, et le découpage en fichiers, en suivant les conventions du paquet.
- L'emplacement du rattrapage (§6.2), s'il est idempotent et testé.
- Les quatre couleurs de phase et leur contraste (§6.3).
- La valeur de `minimumAwakening` (2 minutes proposées) et de `blockGap` (60 minutes proposées).
- Les aperçus SwiftUI (`#Preview`) et les données d'aperçu, en suivant les `*PreviewSupport` existants. Le scénario `ScenarioHealthSource` sert déjà une nuit avec phases (`fullNightStages`).
- L'ordre des étapes du plan, pourvu que chaque étape compile et passe ses tests seule sur Mac.
