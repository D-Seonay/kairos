# Pulse V2a — Course GPS dans l'app

Date : 2026-11-23. Statut : brouillon, à approuver par Mathéo.

Références : spec V1 `2026-10-31-pulse-v1-design.md` (§5.4 courses planifiées, §6 charge, §15 V2), spec M4 (séance live, Live Activity, écriture Santé §19.5), spec M8 (frontière iCloud / appareil, accessibilité).

## 1. Intention

La V2 de Pulse se limite à deux projets, faits l'un après l'autre : **V2a, la course GPS** (ce document), puis **V2b, les photos** de séance et de corps (spec à venir). L'abonnement et l'Apple Watch sont écartés par Mathéo (2026-11-23).

Aujourd'hui une course n'entre dans Pulse que si une autre app l'a écrite dans Apple Santé (la Fitbit de Mathéo, via l'app Google). Pulse sait la planifier, l'ajuster selon la récupération (« fractionné remplacé par un footing facile »), la compter dans la charge, mais pas l'accompagner. V2a fait de Pulse l'app qu'on lance pour courir : on démarre la course du jour depuis Pulse, avec l'objectif ajusté du jour, on entend son allure à chaque kilomètre, on la suit sur l'écran verrouillé, et elle arrive dans la charge, le calendrier et les stats sans attendre Apple Santé.

Mathéo a laissé les choix de conception au constructeur (« je te fais confiance ») : tout ce qui suit est donc **choix du constructeur** sauf mention contraire.

## 2. Objectifs, non-objectifs, anti-objectifs

### Objectifs
- Lancer une course depuis Pulse, téléphone en poche, écran verrouillé, avec le GPS de l'iPhone.
- Voir pendant la course : temps, distance, allure du kilomètre en cours, allure moyenne, progression vers l'objectif du jour.
- Entendre une annonce vocale à chaque kilomètre, par-dessus la musique.
- Suivre la course dans la Live Activity (écran verrouillé, Dynamic Island) et la mettre en pause ou la reprendre depuis là.
- Après la course : récap avec tracé sur une carte, temps par kilomètre, RPE à noter, note libre.
- La course est écrite dans Apple Santé (entraînement « course à pied » avec son tracé), compte dans la charge, valide le jour de course planifié et apparaît dans les stats.
- Aucune perte : une course survit à un crash de l'app, à un redémarrage forcé, à une batterie vide (on garde jusqu'au dernier point enregistré).

### Non-objectifs (V2a)
- Apple Watch, abonnement (écartés par Mathéo).
- Connexion Bluetooth directe à une ceinture cardio. La FC s'affiche seulement si la séance d'entraînement iOS la fournit d'elle-même.
- Fractionné structuré (blocs effort / récupération guidés). Le fractionné reste un type de course avec un objectif de durée ou de distance, comme en V1.
- Pause automatique, course sur tapis, vélo suivi en direct.
- Itinéraires, cartes hors ligne, navigation, segments, partage social, export Strava ou GPX.
- Refonte des stats de course : les courses Pulse s'y ajoutent avec les règles existantes.

### Anti-objectifs (échec même si « ça marche »)
- Une course comptée deux fois dans la charge parce que la Fitbit l'a aussi enregistrée.
- Une course perdue parce que l'app a été tuée en arrière-plan.
- Une distance fausse de plus de 3 % sur un parcours connu (bruit GPS non filtré, points en intérieur).
- Une donnée lue dans Apple Santé qui finit dans iCloud (règle M8, guideline 5.1.3(ii)).
- Une batterie vidée : pas plus que l'app Exercice ou Strava sur la même durée (ordre de grandeur, vérifié à la main par Mathéo).

## 3. Approches envisagées

1. **Séance d'entraînement HealthKit sur iPhone (retenue).** Depuis iOS 26, `HKWorkoutSession` et `HKLiveWorkoutBuilder` fonctionnent sur iPhone sans montre. Pulse vise déjà iOS 26. La séance garde l'app vivante en arrière-plan, se reprend après un crash (`HKHealthStore.recoverActiveWorkoutSession`) et produit un vrai entraînement Santé. Le tracé vient de Core Location et part dans Santé via `HKWorkoutRouteBuilder`.
2. **Core Location seul, sans Santé.** Plus simple, mais la course n'existe pas hors de Pulse, et l'arrière-plan comme la reprise après crash sont à construire soi-même. Écarté.
3. **Pas de GPS : enrichir les courses importées** (tracé, temps par km) et ajouter des annonces vocales. Ne répond pas à la V2 prévue et dépend de ce que la chaîne Fitbit écrit vraiment. Écarté.

## 4. Parcours utilisateur

### 4.1 Points d'entrée
- **Accueil** : quand le jour est un jour de course planifié, la carte de séance du jour propose « Démarrer la course ». Elle montre l'objectif **après ajustement** du moteur (par exemple « Footing facile · 30 min, au lieu du fractionné »).
- **Onglet Séance** : un bouton « Courir » lance une course libre, sans objectif.
- **Live Activity et widgets existants** : inchangés en V2a, sauf la nouvelle Live Activity de course (§4.4).

### 4.2 Avant le départ
Un écran de départ montre :
- l'objectif (ou « Course libre ») ;
- l'état du GPS : « Recherche du signal », « Signal faible » ou « Prêt » (précision horizontale ≤ 20 m) ;
- l'interrupteur des annonces vocales ;
- un gros bouton « Partir ».

On peut partir sans signal prêt. La distance ne compte qu'à partir des premiers points précis, et le récap le signale.

Premier lancement :
- **Localisation** : demander « Lorsque l'app est active ». Le suivi continue en arrière-plan grâce à la séance d'entraînement et au mode d'arrière-plan.
- **Santé** : demander l'écriture des entraînements course et des tracés, avec l'écran d'explication existant (M4 §19.5) adapté.

Si l'utilisateur refuse la localisation, la course enregistre le temps seul, sans distance. L'écran le dit en une ligne. On ne prend pas la distance du podomètre que fournit la séance d'entraînement : ce serait une donnée HealthKit, qui ne peut pas aller dans iCloud (§6).

### 4.3 Pendant la course
```
┌─────────────────────────────┐
│ Footing facile · obj. 30 min│
│                             │
│          24:13              │  temps (gros)
│        4,38 km              │
│                             │
│  5'31"/km      5'32"/km     │  km en cours · moyenne
│  allure km     moyenne      │
│                             │
│  ▓▓▓▓▓▓▓▓▓▓▓▓░░░░  81 %     │  progression objectif
│  ♥ 152 (si disponible)      │
│                             │
│   [ Pause ]   [ Terminer ]  │
└─────────────────────────────┘
```
- **Pause / Reprendre** met en pause la séance HealthKit et le décompte. Les points GPS enregistrés pendant la pause ne comptent pas dans la distance.
- **Terminer** demande une confirmation (appui long ou alerte, au choix du constructeur selon les règles d'accessibilité M8b), puis ouvre le récap.
- **Pas de carte en direct** : elle coûte de la batterie et ne sert pas en poche. La carte n'apparaît qu'au récap.
- **Annonces vocales** à chaque kilomètre : « 3 kilomètres. 16 minutes 40. Allure 5 minutes 32 au kilomètre. » Une annonce aussi à mi-objectif et à l'objectif atteint. Les textes passent par `PulseSpoken` (unités en toutes lettres). La session audio baisse la musique le temps de l'annonce (`.duckOthers` ou `.interruptSpokenAudioAndMixWithOthers`), puis la rend. L'interrupteur est sur l'écran de course et dans Paramètres, et il est mémorisé.
- **FC** : affichée seulement si `HKLiveWorkoutBuilder` livre des échantillons de fréquence cardiaque. Pulse n'écrit aucun code Bluetooth.

### 4.4 Live Activity de course
C'est une nouvelle `PulseRunAttributes`, distincte de celle de la musculation. Elle affiche :
- le temps écoulé, compté par le système à partir des dates, et figé pendant la pause ;
- la distance et l'allure moyenne ;
- un bouton Pause / Reprendre (App Intent, même mécanique que les contrôles du repos M4).

Mises à jour : à chaque pause ou reprise, à chaque kilomètre, et au plus toutes les 15 secondes pour la distance. Comme la séance M4, elle ne porte aucune donnée lue dans Santé : la FC n'y figure pas.

### 4.5 Récap
- La carte du tracé (MapKit, polyligne monochrome dans le style argentique), plus les temps par kilomètre en liste avec le dernier kilomètre partiel.
- Le temps total en mouvement, la distance, l'allure moyenne, le dénivelé positif si l'altitude est fiable (sinon rien), et la FC moyenne si disponible.
- Le RPE global (même composant que le récap musculation) et une note.
- « Enregistrer » écrit l'entraînement dans Santé, valide le jour planifié et rafraîchit l'accueil et la charge. « Supprimer la course » demande une confirmation.

Le récap reste consultable ensuite depuis l'historique et le détail d'activité du planning, comme les courses importées aujourd'hui.

## 5. Règles métier

### 5.1 Distance et allure
- **Filtrage des points** : on écarte un point dont la précision horizontale dépasse 25 m, ou dont la vitesse implicite par rapport au point précédent dépasse 25 km/h. La distance est la somme des segments entre points retenus, hors pause.
- **Allure du km en cours** : temps du kilomètre entamé rapporté à la distance parcourue dans ce kilomètre. Sous 100 m, on affiche l'allure moyenne des 30 dernières secondes.
- **Temps par km** : chaque passage d'un multiple de 1 000 m, interpolé entre deux points.
- Ces calculs vivent dans un module pur, testé sur des traces enregistrées en fixtures, comme le moteur de récupération.

### 5.2 Charge et anti-interférence
- **Charge** : une course Pulse est une `WorkoutSession` avec `kind: .run` et `source: .pulse`. Son RPE compté est, dans l'ordre :
  1. le `overallRPE` noté au récap ;
  2. sinon le RPE estimé depuis la FC livrée pendant la course (V1 §6), gardé en local ;
  3. sinon le RPE estimé du doublon venu de la montre (§5.3), lu en local au moment du calcul, jamais recopié ;
  4. sinon 6.

  L'iPhone n'a pas de capteur cardiaque : sans RPE noté, c'est presque toujours le cas 3 ou le cas 4. Le récap met donc le RPE en avant, sans le rendre obligatoire et sans valeur présélectionnée. Après une réinstallation, les doublons sont relus depuis Santé (fenêtre de 365 jours) et la charge revient à l'identique.
- **Validation du jour** : elle valide automatiquement le jour de course planifié qui tombe ce jour-là, comme une course importée.
- **Course intense** (anti-interférence) : même règle qu'aujourd'hui, RPE compté d'au moins 8 (avec le même ordre de priorité) ou jour planifié en fractionné. `TrainingLoad`, les stats et l'anti-interférence passent par une seule fonction « RPE compté d'une course », testée.

### 5.3 Doublons avec la montre
- **Course écrite par Pulse et relue** : quand la lecture Santé ramène l'entraînement écrit par Pulse, on l'ignore, reconnu par l'UUID gardé dans `healthKitUUID` ou par la source `HKSource.default()`.
- **Même course enregistrée par la montre** : si une course importée d'une autre source chevauche une course Pulse sur au moins 50 % de la durée de la plus courte, elle est marquée « doublon » dans le stockage local. Elle ne compte alors ni dans la charge, ni dans le calendrier, ni dans les stats.
- **FC récupérée de la montre** : si la course Pulse n'a pas de FC, l'écran de détail affiche la FC moyenne de ce doublon. On l'associe à la lecture, sans jamais la recopier dans la séance synchronisée (§6). Son RPE estimé sert à la charge (§5.2).
- **Courses Pulse supprimées** : si l'utilisateur supprime la course Pulse, le doublon redevient une course normale.

### 5.4 Reprise et oubli
- **Pendant la course** : les points et l'état (début, pauses) sont écrits dans le stockage local au fil de l'eau, au moins toutes les 10 secondes et à chaque pause.
- **Au lancement** : si une course était en cours, l'app tente `recoverActiveWorkoutSession`. Si la reprise marche, elle rouvre l'écran de course. Sinon, elle propose « Course interrompue : enregistrer 4,2 km jusqu'à 7 h 52 ? » ou « Supprimer ».
- **Oubli** : 30 minutes sans déplacement hors pause déclenchent une notification locale « Course toujours en cours ? ». Au retour, l'app propose de terminer la course à l'heure du dernier déplacement.

## 6. Données, stockage et confidentialité

La règle M8 tient : tout ce que Pulse **lit** dans Apple Santé reste sur l'appareil. **Tout ce que livre `HKLiveWorkoutBuilder` (FC, distance du podomètre, énergie) compte comme lu dans Santé** et reste donc local. Une course Pulse est une donnée produite par Pulse à partir du GPS et de l'horloge ; elle peut donc aller dans iCloud. Pulse ne relit jamais le tracé depuis Santé. Le test de frontière M8 est étendu aux nouveaux champs.

| Donnée | Où | Pourquoi |
| :--- | :--- | :--- |
| La course : début, fin, temps en mouvement, distance, temps par km, dénivelé, RPE, note, titre, lien au jour planifié | iCloud (`WorkoutSession` existante, champs ajoutés) | Produite par Pulse, restaurée avec l'historique. |
| Le tracé, simplifié (Douglas-Peucker, tolérance d'environ 5 m, horodatage gardé par point) | iCloud, nouveau modèle synchronisé, stockage externe (`.externalStorage`) | Pour revoir la carte après une réinstallation. |
| Les points bruts de la course en cours | Local uniquement, supprimés après l'enregistrement | Brouillon de reprise après crash. |
| La FC livrée par la séance d'entraînement et le RPE qui en est estimé | Local uniquement | Ils viennent de HealthKit. |
| Les doublons importés et leur FC | Local uniquement (modèle importé V4 + marque « doublon ») | Ils sont lus dans Santé. |

- **Schéma** : V5. Un modèle synchronisé `StoredRunTrack` (identifiant de séance unique, points encodés) et un modèle local de brouillon. Les champs de course s'ajoutent à la séance synchronisée et sont tous optionnels, comme l'exige CloudKit. Un test de migration V4 → V5 est requis. Le schéma CloudKit doit être déployé en production avant TestFlight (laissé à Mathéo, comme pour les versions précédentes).
- **Export et suppression** : « Mes données » exporte les courses Pulse (CSV existant, plus une colonne distance et une colonne temps par km). L'effacement supprime aussi les tracés et les brouillons.
- **Info.plist** : texte `NSLocationWhenInUseUsageDescription`, mode d'arrière-plan `location`, et ce qu'exige iOS 26 pour une séance d'entraînement sur iPhone (à vérifier par le constructeur, voir §9). Le texte d'usage Santé en écriture est mis à jour pour les tracés. Les deux versions de l'Info.plist restent égales.
- **Politique de confidentialité** (`docs/confidentialite/`) et fiche (`docs/app-store/fiche.md`) : elles mentionnent la localisation pendant une course, le tracé dans iCloud privé et dans Santé, et le fait que rien ne quitte l'appareil ou le compte iCloud de l'utilisateur. Le libellé App Store « Data Not Collected » reste vrai.
- **Manifeste de confidentialité** : aucune nouvelle API à raison déclarée attendue. À vérifier.

## 7. Architecture

Elle suit la découpe existante : domaine pur, services, adaptateurs, features.
- **PulseDomain** : `RunTrackPoint`, `RunSplit`, les champs de course de `WorkoutSession`, les protocoles `RunRecording` (séance d'entraînement + localisation) et `RunAnnouncing` (voix), derrière lesquels les tests mettent des doublures.
- **PulseServices** (ou un nouveau module pur) : le calcul de distance, d'allure et des temps par km, la simplification du tracé, la détection de doublon, les textes d'annonce, et l'intégration à `TrainingLoad`, aux stats et à la validation du planning.
- **PulseHealth** : l'adaptateur `HKWorkoutSession`, `HKLiveWorkoutBuilder` et `HKWorkoutRouteBuilder`, plus la reprise. Le filtre « ignorer ce que Pulse a écrit » s'applique aussi aux courses.
- **Nouvelle cible `RunFeature`** : écran de départ, écran de course, récap, modèle de course. Elle reprend les briques du design system (argentique, une seule couleur signal) et les règles d'accessibilité M8b : libellés parlés via des fonctions testées, annonces VoiceOver (kilomètre passé à priorité basse pour ne pas couper la voix de course), mises en page pour les grandes tailles de texte, Réduire les animations.
- **PulseLiveActivity / PulseWidgets** : `PulseRunAttributes`, ses vues et l'intent Pause / Reprendre.
- **App** : le branchement de l'environnement, la reprise au lancement, les permissions.

## 8. Contraintes et barre de qualité

- Mêmes exigences que V1 et M8 : `swift test` vert sur tous les packages, lint à 0, `make build-app` et `make build-release` verts.
- Le simulateur n'est jamais lancé par l'agent. Les tests d'interface sont écrits mais lancés par Mathéo.
- Les calculs de distance, d'allure, de temps par km, de doublon et de simplification sont couverts par des tests sur fixtures. Au moins trois traces : une course propre, une avec un passage en tunnel ou sous des arbres, et une avec une pause.
- La Live Activity n'est jamais mise à jour chaque seconde.
- Textes en français, accessibles, au pluriel correct, unités en toutes lettres à l'oral.

## 9. Laissé au constructeur

- Les clés exactes d'Info.plist et de capacités qu'exige `HKWorkoutSession` sur iPhone en iOS 26 : vérifier dans la doc Apple avant d'écrire le plan.
- Comment donner la distance GPS à Santé (échantillons de distance ajoutés au builder ou autre moyen). Contrainte : la distance écrite dans Santé est celle du GPS filtré, la même que celle affichée et synchronisée.
- Le découpage en lots et en PR (probablement deux : moteur et enregistrement, puis écrans, Live Activity et app).
- La présentation fine des écrans, dans le style argentique et la maquette.
- Le nom exact des modèles et des types.

## 10. Laissé à Mathéo (sur l'iPhone)

- **Courses de vérification** : au moins trois vraies courses, dont une sur un parcours de distance connue. Écart de distance, batterie consommée, annonces vocales par-dessus la musique, Live Activity, pause depuis l'écran verrouillé.
- **Reprise** : forcer la fermeture de l'app en pleine course, puis vérifier la reprise.
- **Doublon** : une course enregistrée à la fois par la Fitbit et par Pulse doit apparaître une seule fois dans la charge.
- **Déploiement** : le schéma CloudKit V5 en production avant TestFlight.

## 11. Risques

| Risque | Parade |
| :--- | :--- |
| `HKWorkoutSession` sur iPhone récent, peu documenté, comportement en arrière-plan inattendu. | Une première tâche du plan isole l'adaptateur derrière `RunRecording`. Si la séance ne garde pas l'app vivante, la localisation en arrière-plan avec `CLBackgroundActivitySession` prend le relais. |
| Guideline 2.5.4 (mode d'arrière-plan localisation justifié). | Le mode ne sert que pendant une course lancée par l'utilisateur. La fiche de revue l'explique. |
| Points GPS faux au départ (froid) ou en ville. | Filtrage §5.1, état « Signal faible », tests sur fixtures bruitées. |
| Taille du tracé dans CloudKit. | Tracé simplifié dans un stockage externe, quelques centaines de points pour une heure. |
| Doublon mal détecté (horloges décalées, course coupée en deux par la montre). | Règle de chevauchement à 50 % testée sur des cas limites. La FC de la montre n'est jamais recopiée. |
