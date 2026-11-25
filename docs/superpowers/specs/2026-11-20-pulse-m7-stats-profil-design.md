# Pulse M7 — Stats et profil : spec complémentaire

Date : 20 novembre 2026
Statut : brouillon à valider par Mathéo (« continue de dev »), relu par un agent constructeur
Auteur : Mathéo Delaunay, rédigé avec Claude
Complète : la spec V1 (`2026-10-31-pulse-v1-design.md`, §5.8, §5.9, §6.4, §7, §8), la feuille de route (`2026-10-31-pulse-v1-roadmap.md`, M7), la spec M6 (série, semaine datée, courses lues) et la maquette (`maquette.html`, écrans `stats`, `profil`, `parametres`, `donnees`).

Les choix du constructeur sont marqués **(choix du constructeur)**. On peut les rouvrir, mais il faut une raison.

---

## 1. Intention

L'onglet Stats affiche « M7 » depuis M3, et l'onglet Profil n'est qu'une liste de debug. Pulse calcule pourtant déjà tout ce qu'il faut : la charge et l'ACWR, un score chaque matin avec ses valeurs brutes (VFC, FC repos, sommeil), les séries par muscle, la série de semaines, les records. M7 montre cette matière sur la durée, pour répondre à trois questions :

- **Est-ce que je progresse ?** Records et 1RM estimés, tonnage, assiduité.
- **Est-ce que je récupère ?** VFC face à la ligne de base, FC repos, sommeil, répartition des journées.
- **Est-ce que je m'entraîne de façon équilibrée ?** Charge aiguë contre chronique, muscles travaillés et délaissés, pousser contre tirer.

Le profil devient la page de Mathéo : son poids lu d'Apple Santé, ses records, sa régularité, et l'accès aux réglages qui jusqu'ici n'existaient qu'à l'onboarding.

## 2. Objectifs, non-objectifs, anti-objectifs

**Objectifs.**
- Les cinq vues du §5.8 de la spec V1, chacune avec un calcul pur testé sur fixtures et un aperçu SwiftUI (critère de fin de la feuille de route).
- Un profil, un écran Poids avec saisie manuelle, les paramètres complets du §5.9, un vrai écran « Mes données ».
- L'écran de debug « Données » disparaît des builds Release.

**Non-objectifs.**
- Les unités en livres. Le réglage kg / lb est dans la spec V1 §5.9, mais l'app affiche et saisit des kilos partout (clavier de séance, disques, incréments, records). Le réglage reste caché tant que l'affichage en livres n'existe pas. Mathéo s'entraîne en kilos **(choix du constructeur)**.
- Mensurations, photos, amis, abonnement, capteurs Bluetooth, coach vocal : écrans de la maquette hors V1 (spec V1 §2 et §15).
- La politique de confidentialité en ligne : elle est publiée en M8. M7 prévoit le lien.

**Anti-objectifs.**
- Des chiffres faux ou flatteurs. Une valeur sans assez de données s'affiche « pas assez de données » avec la raison, jamais un zéro ou une estimation déguisée.
- Des graphiques décoratifs. Chaque graphique répond à une des trois questions du §1 ; sinon il n'est pas fait.
- Une vue qui rame. Un an de séances (environ 250, plus de 5 000 séries) se calcule en moins de 200 ms sur l'iPhone.

## 3. Découpage

Deux PR, comme M6 **(choix du constructeur)** :

| Partie | Branche | Contenu |
| :--- | :--- | :--- |
| **M7a** | `m7-stats` | onglet Stats : période commune, cinq vues (Charge, Biométrie, Muscles, Assiduité, Records). |
| **M7b** | `m7-profil` | Profil (identité, poids, badges, mur des records), écran Poids, Paramètres, Mes données, licences. |

Chaque partie en trois lots :

| Lot | M7a | M7b |
| :--- | :--- | :--- |
| 1 — Moteur | constructeurs purs `PulseServices/Stats`, `StatsService`, courses lues sur un an, tests sur fixtures | lecture du poids et de la masse grasse, tendance lissée, badges, `SettingsService`, tests |
| 2 — Écrans | cible `StatsFeature` | cible `ProfileFeature` |
| 3 — App | onglet Stats branché, rechargement après une séance ou le passage du jour | onglet Profil remplacé, debug réservé au DEBUG, Apple Santé relu depuis les paramètres |

## 4. Approches envisagées

1. **Calcul à la volée à l'ouverture de la vue (retenue).** `StatsService` lit les séances, les scores et les records de la période plus large utile (un an au plus), puis des fonctions pures produisent chaque vue. Rien de nouveau n'est stocké, il n'y a rien à rattraper après une correction de séance ou un import Hevy. Les volumes (≈ 250 séances par an) tiennent sans cache.
2. **Agrégats quotidiens stockés** (une ligne par jour avec charge, séries par muscle…). Plus rapide sur des années de données, mais il faut un modèle SwiftData de plus, une migration CloudKit et une invalidation à chaque séance corrigée, importée ou supprimée. Trop cher pour le gain.
3. **Swift Charts seul dans les vues, calculs dans les modèles de vue.** Moins de fichiers, mais les calculs ne sont plus testables sans SwiftUI, alors que la feuille de route exige un test de calcul par vue.

**Graphiques :** Swift Charts (iOS 26), en encre monochrome sur papier, la couleur signal réservée à ce qui alerte (zone de risque ACWR, muscle délaissé). Les tuiles reprennent les gros chiffres fins et les étiquettes mono de la direction Argentique **(choix du constructeur)**.

---

# M7a — Stats

## 5. Période commune

Un sélecteur sous les onglets de vue : **7 jours, 30 jours, 90 jours, 1 an** (libellés de la maquette), 30 jours par défaut. Ce sont des fenêtres glissantes qui finissent aujourd'hui inclus, pas des semaines ou des mois civils : « 30 jours » se compare ainsi toujours aux 30 jours précédents **(choix du constructeur)**. La période choisie est gardée dans `@AppStorage`.

Chaque tuile chiffrée compare à la **période précédente de même longueur** (« +4 % vs 30 j précédents »). Sans aucune donnée dans la période précédente, pas de comparaison.

L'Assiduité garde sa matrice fixe de 16 semaines quelle que soit la période (spec V1 §5.8) ; seules ses tuiles suivent la période.

## 6. Charge

Sources : les séances terminées et abandonnées (comme `TrainingLoad`, M4 §14.6), Pulse, Hevy et Apple Santé.

**Courses sur un an.** `WorkoutHistory.historyDays` passe de 60 à 365 jours, pour que la vue « 1 an » et les records de course voient les sorties anciennes. L'ancre de lecture des courses et des vélos est effacée une fois (marqueur de version dans le cache) pour relire la fenêtre élargie ; les séances déjà importées sont retrouvées par `healthKitUUID` et gardent leur RPE et leur note **(choix du constructeur)**.

- **Tuiles :** charge aiguë (7 j) et chronique (28 j) du jour, ratio et sa zone (`ACWRZone`). Comparaison de l'aiguë à la semaine d'avant.
- **Courbe ACWR :** un point par jour de la période, calculé par `LoadCalculator.acwr(asOf:)` pour chaque jour. Bande optimale 0,8 – 1,3, ligne de risque à 1,5 en couleur signal. Les jours avec moins de 28 jours d'historique n'ont pas de point. Sur « 1 an », un point par semaine (le dimanche) pour garder la courbe lisible **(choix du constructeur)**.
- **Phrase de bilan** sous la courbe, choisie par règle : « Dans la zone optimale depuis N semaines », « Au-dessus de 1,3 depuis N jours », « Sous 0,8 : charge en baisse », ou la décharge en cours (M6).
- **Charge par semaine :** barres empilées musculation / course / vélo (minutes × RPE, mêmes règles que `TrainingLoad`, vélo plafonné à 5). Sur 7 jours, barres par jour.
- **Totaux de la période :** tonnage (séries de travail, `SessionTonnage`), distance courue et roulée, durée totale, nombre de séances. Répartition muscu / endurance en pourcentage de la charge.

Avec moins de 28 jours d'historique, la courbe est remplacée par « L'ACWR s'affiche après 28 jours d'entraînement (encore N jours) », comme l'accueil.

## 7. Biométrie

Source : les lignes `DailyRecovery`, qui gardent les valeurs brutes de chaque matin et ne sont jamais purgées, contrairement au cache Apple Santé de 60 jours **(choix du constructeur)**. Les journées estimées par check-in comptent dans la répartition, pas dans les moyennes de VFC, FC et sommeil.

- **Tuiles :** VFC moyenne (ms), FC repos moyenne (bpm), sommeil moyen (h min) avec la part de profond, score moyen. Chacune contre la période précédente.
- **VFC et ligne de base :** la VFC de chaque nuit en points, la ligne de base (`sdnnBaselineMs`) en ligne. Pas de bande d'écart type : `DailyRecovery` ne la stocke pas, et l'ajouter demanderait une migration pour un gain mince **(choix du constructeur)**.
- **FC repos :** ligne par nuit avec sa ligne de base.
- **Sommeil :** barres par nuit, la part profonde en encre pleine.
- **Journées par état de forme :** nombre de jours par `RecoveryCategory` sur la période, en barres horizontales.

Sur « 1 an », les séries sont moyennées par semaine.

## 8. Muscles

Sources : les séances de musculation terminées de la période, séries de travail seulement (pas d'échauffement), exercices du catalogue et exercices perso.

- **Carte de chaleur face et dos :** pour chaque série, +1 sur chaque muscle moteur, +0,5 sur chaque stabilisateur (spec V1 §5.8). `MuscleStats` rend les poids par muscle ; `StatsFeature` les convertit en niveaux par `MuscleIntensity.levels(weights:)` (`PulseDesignSystem`), la même échelle que le récap.
- **Les plus travaillés :** les 8 muscles au plus haut total, avec leur nombre de séries pondérées.
- **Délaissés :** un groupe (`MuscleGroup`) est délaissé quand sa moyenne est sous **4 séries pondérées par semaine** sur la période, et que la période compte au moins une séance de musculation par semaine en moyenne. Une phrase factuelle le dit, en couleur signal : « Tronc peu sollicité : 8 séries d'abdominaux et 6 d'obliques en 30 jours. » Pas de conseil de programme en M7 **(choix du constructeur)**.
- **Équilibre :** séries de travail (non pondérées) par schéma de mouvement :
  - pousser = `horizontalPush`, `chestFly`, `verticalPush`, `elbowExtension` ;
  - tirer = `verticalPull`, `horizontalPull`, `elbowFlexion` ;
  - haut = `BodyRegion.upper`, bas = `.lower` ; le tronc est exclu des deux **(choix du constructeur)**.
  Un ratio hors de 0,67 – 1,5 est signalé.

Sur 7 jours, la vue s'affiche telle quelle ; la règle « délaissé » ne s'applique qu'à partir de 30 jours.

## 9. Assiduité

- **Matrice 7 × 16 :** lundi à dimanche en lignes, les 16 dernières semaines en colonnes, la semaine en cours à droite. Cinq niveaux : 0 = aucune séance ; 1 à 4 = quartiles de la charge quotidienne (minutes × RPE) des jours entraînés sur ces 16 semaines. Les niveaux s'adaptent ainsi à l'utilisateur **(choix du constructeur)**. La matrice montre aussi les vélos terminés lus d'Apple Santé (charge plafonnée à RPE 5, comme `TrainingLoad`) : le vélo ne compte pas pour la série (spec M6 §5), mais une sortie reste un jour d'activité. Les tuiles et la série, elles, ne comptent que les séances de `WeekStreak.counts` **(choix du constructeur, issue #71)**.
- **Tuiles :** série en cours et sa semaine (`WeekStreak`), **meilleure série** avec ses dates (nouveau : `WeekStreak.best`, sur tout l'historique), séances validées sur la période et depuis la première séance, durée moyenne et heure habituelle (l'heure de début la plus fréquente, par tranche d'une heure).
- Régularité en pourcentage : semaines réussies / semaines de la période.

Les « piliers de récupération » de la maquette (boire, écrans coupés…) ne sont pas en V1.

**Objectif des semaines passées.** Pulse ne garde pas l'historique de l'objectif hebdomadaire. Toutes les semaines passées sont jugées avec l'objectif d'aujourd'hui (`WeekStreak.target`), comme le pilier de M6. Changer de programme peut donc changer la meilleure série et les badges de série ; c'est accepté plutôt que d'ajouter une table et une migration CloudKit **(choix du constructeur)**.

## 10. Records

- **Force :** 1RM estimé (Brzycki, `OneRepMax`) pour squat, développé couché, soulevé de terre et développé militaire du catalogue, puis tout exercice avec au moins cinq séances. Pour chacun : 1RM actuel, la série qui l'a donné (charge × reps, date), et l'écart avec le meilleur 1RM d'avant la période (« +2,5 kg »). Les records viennent de `PersonalRecord` (`RecordBook`, M4a). Un exercice au poids du corps montre son record de répétitions.
- **Course :** meilleurs temps 5 km, 10 km et semi-marathon parmi les courses lues d'Apple Santé. Une course compte pour une distance si elle la couvre ; son temps est **ramené à la distance à l'allure moyenne** de la sortie, puisque Apple Santé ne donne pas les temps intermédiaires sans relire le tracé. La ligne le dit : « allure moyenne de la sortie du 14 sept. » **(choix du constructeur)**. Lire les échantillons de distance pour trouver le meilleur segment est laissé pour plus tard.
- Toucher un record de force ouvre la fiche de l'exercice sur l'onglet Progression (M4a).

La vue Records ignore la période pour les meilleures valeurs (un record est un record), mais marque « nouveau » ce qui a été battu dans la période.

## 11. Moteur M7a

Dans `PulseServices/Stats`, des types valeur et des fonctions pures :

- `StatsPeriod` (`.week`, `.month`, `.quarter`, `.year`) : intervalle, intervalle précédent, regroupement (jour ou semaine).
- `LoadStats.make(sessions:period:now:calendar:)`, `BiometryStats.make(recoveries:…)`, `MuscleStats.make(sessions:exercises:…)`, `AttendanceStats.make(sessions:target:…)`, `RecordStats.make(records:sessions:…)`.
- `StatsService` lit les dépôts une fois (séances depuis un an avant la période précédente la plus longue, scores, records), puis construit la vue demandée. Il s'abonne aux mêmes signaux de rafraîchissement que l'onglet Planning.

Tests : une fixture de 20 semaines (PPL, courses avec FC, nuits avec trous, une semaine manquée, un import Hevy) et des cas limites (aucune donnée, une seule séance, moins de 28 jours, période précédente vide, exercice perso sans muscle).

## 12. Écrans M7a

Cible `StatsFeature`, un `NavigationStack` : en-tête « Statistiques », segment des cinq vues (défilable sur iPhone mini), puces de période, puis la vue. Chaque vue a son aperçu avec la fixture. Accessibilité : chaque graphique a un `accessibilityChartDescriptor` ou un résumé texte ; la matrice d'assiduité se lit semaine par semaine.

---

# M7b — Profil, paramètres, données

## 13. Profil

L'onglet Profil devient une page :

- **En-tête :** initiale, prénom, « N séances · depuis <mois de la première séance> ».
- **Trois tuiles :** série en cours (semaines), score de ce matin, poids (tendance).
- **Poids et corps :** poids tendance, variation sur 30 jours, dernière masse grasse s'il y en a ; ouvre l'écran Poids.
- **Mur des records :** les quatre 1RM de base et les trois chronos de course ; « Tout voir » ouvre Stats → Records.
- **Vitrine (badges de régularité) :** calculés, jamais stockés : séries de 4, 8, 12, 26 et 52 semaines ; 10, 50, 100, 250 et 500 séances ; premier mois complet (4 semaines réussies d'un mois civil). Chaque badge obtenu a sa date ; le prochain à obtenir montre sa progression **(choix du constructeur)**.
- **Liens :** Statistiques, Compléments, Paramètres, Mes données.

## 14. Poids

- **Lecture :** au passage du jour, Pulse lit dans Apple Santé le poids (`bodyMass`) et la masse grasse (`bodyFatPercentage`, déjà dans les types demandés à l'onboarding) par une lecture ancrée qui part de 365 jours, comme les courses. Chaque échantillon devient un `BodyMeasurement` `.appleHealth`, retrouvé par `healthKitUUID` ; un échantillon effacé d'Apple Santé est supprimé, comme les courses (M6 §3).
- **Saisie manuelle :** un poids et une date, `.manual`, non écrit dans Apple Santé **(choix du constructeur)**. Une saisie manuelle se supprime ou se modifie depuis la liste.
- **Tendance :** une valeur par jour (la dernière mesure du jour, manuelle prioritaire le même jour), puis la moyenne des mesures des 7 derniers jours. Sans mesure depuis 14 jours, la tendance s'affiche avec « dernière mesure le … ».
- `UserProfile.weightKg` suit la dernière tendance. Rien ne le lit encore pour la charge : le tonnage et les records d'un exercice au poids du corps ne comptent que la charge ajoutée, et M7 ne change pas ce calcul **(choix du constructeur)**.
- **Écran :** courbe 90 jours (points des mesures, ligne de tendance), dernière masse grasse, liste des mesures avec leur source, bouton « Ajouter une pesée ».
- **Autorisation :** les deux types sont déjà demandés à l'onboarding, et HealthKit ne dit jamais si la lecture est refusée. Sans aucune mesure lue, l'écran Poids dit « Aucune pesée dans Apple Santé. Vérifie l'accès de Pulse dans Santé → Partage » et propose la saisie manuelle.

## 15. Paramètres

Ils écrivent le `UserProfile` à travers `SettingsService` (un seul point d'écriture, qui replanifie ce qui en dépend : notifications du matin, rappels de compléments, widgets). Les replanifications vivent en partie dans la cible app (`Pulse/Notifications`) : `SettingsService` les reçoit en fermetures à sa création.

| Section | Réglages |
| :--- | :--- |
| **Mon profil** | prénom, date de naissance (FC max des courses), sexe, taille |
| **Apple Santé** | état des autorisations par type, dernière lecture, « Relire maintenant » (lance le passage du jour), diagnostic (l'actuel écran, déplacé ici) |
| **Moteur d'adaptation** | ajuster mes séances automatiquement, les trois règles anti-interférence (la section de M6, déplacée ici ; l'éditeur de programme garde un lien), incréments haut et bas du corps |
| **Séance** | échauffement automatique, repos par défaut 60 / 90 / 120 / 180 s, barre et disques disponibles |
| **Affichage** | ambiance Ivoire ou Acier (`Theme.amber` / `.amethyst`, renommés depuis Argentique ; l'« améthyste » de la feuille de route n'existe plus) |
| **Notifications** | score du matin et son heure plafond, rappels de compléments, fin de repos ; un lien vers les réglages iOS si les notifications sont refusées |
| **À propos** | version et build, licences |

Le thème clair reste forcé (Argentique) : pas de choix Sombre / Clair / Auto en M7 **(choix du constructeur)**.

## 16. Mes données

- **Sur ce téléphone :** nombre de séances, de nuits, de scores, de mesures et de compléments stockés (`StoreInspector.counts()`) ; état du compte iCloud (`cloudAccountStatus()` : disponible, pas de compte, restreint, inconnu) avec la phrase qui va avec. L'état de la synchronisation elle-même n'est pas exposé par SwiftData : il n'est pas affiché **(choix du constructeur)**.
- **Exporter :** tout en JSON, tout en CSV (un fichier par table, zippé), par la feuille de partage. Les exports existent depuis M2 ; M7 les sort du debug.
- **Supprimer :** suppression totale locale et iCloud, avec la confirmation existante (taper « SUPPRIMER »).
- **Liens :** politique de confidentialité (URL lue dans l'Info.plist, ligne masquée tant qu'elle est vide ; M8 la remplit) et licences : MuscleMap, Brzycki et Tanaka cités, polices.
- L'écran de debug « Données » (données d'exemple, inspection des tables) reste, mais seulement en DEBUG.
- Le diagnostic Apple Santé, le debug « Données » et la confirmation de suppression sont dans la cible app (`Pulse/Diagnostics`, `Pulse/Debug`). `ProfileFeature` reçoit ces écrans de l'app (vues ou fermetures) plutôt que de les déplacer dans un package.

## 17. Moteur M7b

- `HealthSampleSource` gagne la lecture ancrée du poids et de la masse grasse ; `BodyHistory` aligne les mesures comme `WorkoutHistory` le fait pour les courses.
- `WeightTrend.make(measurements:now:calendar:)`, `Badges.make(sessions:streak:now:calendar:)`, purs et testés.
- `SettingsService` : lit, modifie et enregistre le profil, puis appelle les replanifications.

## 18. Qualité

- `swift test` vert sur tous les packages, `swiftlint --strict` à 0, `make build-app` et `make build-release` verts.
- Aucun lancement du simulateur depuis la session ; les vérifications sur l'iPhone sont pour Mathéo (une vraie période de 30 jours, la courbe ACWR, le poids lu de sa balance, un changement de réglage pris en compte en séance).

## 19. Laissé au constructeur

- La mise en page exacte des vues dans le style Argentique, les formules des phrases de bilan, l'ordre des tuiles.
- Les seuils d'affichage (« pas assez de données ») non fixés ici.
- La structure interne de `StatsFeature` et `ProfileFeature`.
