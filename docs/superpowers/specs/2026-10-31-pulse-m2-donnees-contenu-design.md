# Pulse M2 — Données et contenu : spec complémentaire

Date : 31 octobre 2026
Statut : brouillon soumis à validation
Auteur : Mathéo Delaunay, rédigé avec Claude
Complète : `2026-10-31-pulse-v1-design.md` (la « spec V1 »), qui reste l'autorité. Ce document ne fait que préciser ce que la spec V1 laisse ouvert pour le jalon M2 de la feuille de route : schéma JSON du contenu, contenu lui-même, champs exacts de la persistance, export, suppression totale, écran de debug.

---

## 1. Intention

M2 donne à Pulse sa mémoire et son contenu, sans encore d'interface finale :

- un package `PulseContent` qui embarque **84 exercices** et **5 modèles de programme** en JSON, chargés et validés par test ;
- un package `PulsePersistence` qui stocke tout ce que l'utilisateur produit dans SwiftData, synchronisé par iCloud (CloudKit privé), derrière des protocoles de dépôt définis dans `PulseDomain` ;
- l'**export** complet (JSON et CSV) et la **suppression totale**, exigés par l'App Store (spec V1 §11) ;
- un **écran de debug** temporaire qui montre le contenu chargé, l'état du stockage, et déclenche export, données d'exemple et suppression.

**Pourquoi maintenant.** M3 (onboarding, accueil) et M4 (séance en direct) écrivent et lisent ces données. Le schéma SwiftData + CloudKit est coûteux à changer une fois des données réelles en iCloud : il doit sortir de M2 complet, y compris les champs que M4 à M7 rempliront plus tard (super sets, ajustements, compléments, records).

**Ce que Mathéo a dit et qui a façonné ce document.**

- Sa salle est une salle commerciale équipée ; son PPL repose presque entièrement sur des machines guidées, des poulies et la presse, avec une seule barre libre (développé couché) et un seul exercice haltère (curl marteau). La bibliothèque couvre donc sérieusement les machines et les poulies, et chaque exercice a des alternatives machine réalistes pour « machine occupée ».
- Son PPL actuel (§4.2) devient tel quel le modèle « PPL 3 jours ».
- Il fait des séries d'échauffement, un **super set** (deux exercices enchaînés sans repos), du **dégressif** (drop), et il lui arrive de **rater** une série (8 prévues, 3 faites). Le super set n'était pas dans la spec V1 : il entre dans le modèle de données dès M2 (§5.3), l'interface arrivera en M4. Le « raté » n'est pas un type de série : chaque série garde les répétitions prévues et les répétitions faites, c'est suffisant.
- L'export sert d'abord à l'obligation légale, et ensuite à donner ses données à une IA pour les faire analyser : il doit être complet et auto-descriptif, dans un seul fichier JSON (§6).
- À la suppression totale, il veut **le choix** d'effacer ou non ce que Pulse aura écrit dans Apple Santé ; l'app repart ensuite comme au premier lancement (§7).

---

## 2. Objectifs, non-objectifs, anti-objectifs

### Objectifs

- Les dépôts passent leurs tests ; le mapping domaine ↔ SwiftData est testé en aller-retour sur chaque entité.
- Le contenu est validé par test : 84 exercices exactement (le tableau du §4.2 fait foi), identifiants stables et uniques, alternatives cohérentes, modèles qui ne référencent que des exercices existants.
- Un export produit deux fichiers lisibles (JSON, zip de CSV) partageables par la feuille de partage iOS.
- La suppression totale vide tout, local et iCloud, et ramène l'app au premier lancement.
- Le schéma de données couvre les besoins de M3 à M7 pour que les jalons suivants n'aient qu'à ajouter des champs optionnels (migration légère), jamais à restructurer.

### Non-objectifs (jalons suivants)

- Aucun écran final : pas de bibliothèque, pas de fiche exercice, pas de séance live, pas d'écran « Mes données » stylé (M4, M7). L'écran de M2 est un écran de debug, sans design system.
- Pas d'écriture dans Apple Santé (M4, M5). La suppression côté Apple Santé est **préparée** (option et protocole) mais son implémentation HealthKit arrive avec la première écriture, en M4.
- Pas de lecture ancrée ni de livraison en arrière-plan HealthKit (M3). Le cache Apple Santé est créé et testé ; M3 le remplit.
- Pas de recherche insensible aux accents, pas de filtres (M4) : le contenu fournit les données, pas les index.
- Pas de contenu anglais au-delà du nom EN de chaque exercice.

### Anti-objectifs

- Un schéma SwiftData qui viole une contrainte CloudKit (attribut non optionnel sans valeur par défaut, relation non optionnelle, contrainte d'unicité) : l'app planterait au premier lancement avec iCloud.
- Un export qui oublie une table, ou qui n'est pas relisible sans le code.
- Une suppression « totale » qui laisse des traces (préférences, cache, séance en cours, enregistrements iCloud).
- Du contenu d'exercice copié dans SwiftData (spec V1 §4) : le contenu reste dans le bundle, les séries le référencent par identifiant.
- Des données de santé brutes dans les journaux.

---

## 3. Contraintes

- Celles de la spec V1 §3 et §4, plus les contraintes d'environnement vérifiées en M1 : Xcode 27.0, Swift 6.4, cible iOS 26, `swift-tools-version: 6.2`, mode de langage Swift 6 sur chaque cible, SwiftLint strict, commits `type: description` sans trailer de co-auteur, pas de push sans accord.
- `PulseDomain` et `PulseContent` n'importent que Foundation et se testent avec `swift test` sur le Mac. `PulsePersistence` importe SwiftData et CloudKit : ses tests tournent avec un conteneur en mémoire, sans CloudKit ; ils sont lancés par `swift test` sur le Mac si SwiftData s'y construit correctement, sinon via le schéma `Pulse` sur le simulateur « iPhone 17 » (le plan tranche avec un essai en première tâche).
- Toutes les chaînes visibles passent par `String(localized:)`, en français.
- Les identifiants d'exercices et de modèles sont **stables pour toujours** : une fois publiés, on ne renomme pas un identifiant, on en ajoute. Une suppression de contenu se fait par le drapeau `retired` (§4.1), jamais en retirant l'entrée, pour que l'historique continue de résoudre ses références.

---

## 4. Contenu : `PulseContent`

### 4.1 Schéma JSON des exercices

Un seul fichier `exercises.json` dans les ressources du package. Clés en camelCase anglais, identiques aux propriétés Swift. Les textes sont des objets localisés avec une clé par langue (`fr` obligatoire, `en` facultative sauf pour `name` où elle est obligatoire), pour ajouter l'anglais plus tard sans changer le schéma.

```json
{
  "schemaVersion": 1,
  "contentVersion": "1.0.0",
  "exercises": [
    {
      "id": "bench-press-barbell",
      "name": { "fr": "Développé couché à la barre", "en": "Barbell Bench Press" },
      "primaryMuscles": ["chest"],
      "secondaryMuscles": ["frontDelts", "triceps"],
      "equipment": "barbell",
      "pattern": "horizontalPush",
      "region": "upper",
      "isCompound": true,
      "isUnilateral": false,
      "loadKind": "external",
      "defaultIncrementKg": 2.5,
      "defaultRestSeconds": 120,
      "cues": { "fr": ["Omoplates serrées et abaissées sur le banc.", "Barre au niveau du bas des pectoraux, coudes à 45°.", "Pieds ancrés, pousser le sol pendant la montée."] },
      "mistakes": { "fr": ["Rebondir la barre sur la poitrine.", "Décoller les fesses du banc."] },
      "alternatives": ["chest-press-machine", "bench-press-dumbbell", "incline-chest-press-machine"],
      "retired": false
    }
  ]
}
```

| Champ | Type | Règle |
| :--- | :--- | :--- |
| `id` | chaîne | `^[a-z0-9]+(-[a-z0-9]+)*$`, unique, stable. Forme : mouvement puis matériel (`lat-pulldown-machine`). |
| `name` | localisé | `fr` et `en` obligatoires, non vides. |
| `primaryMuscles` | tableau de `Muscle` | 1 à 3 entrées, sans doublon. Le premier est le muscle principal (fiche, filtre, incrément). |
| `secondaryMuscles` | tableau de `Muscle` | 0 à 4 entrées, disjoint de `primaryMuscles`. Ce sont les stabilisateurs de la spec V1 (poids 0,5 dans la carte de chaleur). |
| `equipment` | `Equipment` | une seule valeur. |
| `pattern` | `MovementPattern` | le « plan de mouvement » de la spec V1 ; sert au remplacement et aux alternatives. |
| `region` | `upper`, `lower`, `core` | catégorie haut / bas de la spec V1 ; `core` pour le tronc. |
| `isCompound` | booléen | drapeau « base » : échauffement automatique (spec V1 §5.5). |
| `isUnilateral` | booléen | vrai quand la charge est par côté (affichage M4). |
| `loadKind` | `external`, `bodyweight`, `assisted` | `bodyweight` : le poids saisi est le lest ajouté ; `assisted` : le poids saisi est l'assistance (machine de tractions assistées). |
| `defaultIncrementKg` | nombre | incrément de progression par défaut : 5 pour les polyarticulaires lourds du bas à la barre ou à la presse (squats, hack squat, presse, soulevés à la barre, hip thrust, mollets à la presse) ; 2,5 pour le haut, le tronc, les fentes, les exercices aux haltères et les isolations du bas ; 1,25 pour les isolations légères. Précise la règle « 2,5 haut / 5 bas » de la spec V1 §6.5 : 5 kg d'un coup sur une extension de jambes ou un leg curl est un saut trop grand. |
| `defaultRestSeconds` | entier | 60, 90, 120 ou 180. |
| `cues` | localisé, tableaux | exactement 3 consignes en `fr`, chacune ≤ 90 caractères. |
| `mistakes` | localisé, tableaux | 2 ou 3 erreurs fréquentes en `fr`, chacune ≤ 90 caractères. |
| `alternatives` | tableau d'`id` | exactement 3, tous existants, différents de `id` et entre eux, **de même `pattern`**. |
| `retired` | booléen | facultatif, faux par défaut. Un exercice retiré n'est plus proposé mais reste résoluble. |

Énumérations (valeurs JSON = `rawValue` Swift, définies dans `PulseDomain`) :

- `Muscle` (20) : `chest`, `frontDelts`, `sideDelts`, `rearDelts`, `traps`, `lats`, `upperBack`, `lowerBack`, `biceps`, `triceps`, `forearms`, `abs`, `obliques`, `quads`, `hamstrings`, `glutes`, `adductors`, `abductors`, `calves`, `hipFlexors`. Chaque valeur correspondra à une région de la carte musculaire MuscleMap en M3 ; la correspondance est un détail de M3.
- `Equipment` (9) : `barbell`, `ezBar`, `dumbbell`, `kettlebell`, `machine`, `cable`, `smithMachine`, `band`, `bodyweight`.
- `MovementPattern` (19) : `horizontalPush`, `chestFly`, `verticalPush`, `shoulderIsolation`, `verticalPull`, `horizontalPull`, `elbowFlexion`, `elbowExtension`, `forearm`, `squat`, `lunge`, `hinge`, `kneeFlexion`, `kneeExtension`, `hipAbduction`, `hipAdduction`, `calfRaise`, `coreFlexion`, `coreStability`.
- `BodyRegion` : `upper`, `lower`, `core`.
- `LoadKind` : `external`, `bodyweight`, `assisted`.

Chaque énumération a un libellé français exposé par une extension dans `PulseContent` (`localizedName`), comme `SleepStage.localizedName` en M1.

### 4.2 Les 84 exercices

Exactement 84 (le tableau ci-dessous fait foi ; la spec V1 disait « environ 80 »), 19 plans de mouvement, au moins 4 exercices par plan pour que chaque exercice ait ses 3 alternatives. Les 17 exercices du PPL de Mathéo sont marqués ★. Les consignes, erreurs et alternatives sont laissées au constructeur dans ces règles ; la liste des identifiants et des noms, elle, est fixée ici.

| Plan | Identifiants (nom FR) |
| :--- | :--- |
| horizontalPush (6) | `bench-press-barbell` ★ (Développé couché à la barre), `bench-press-dumbbell` (Développé couché aux haltères), `incline-bench-press-dumbbell` (Développé incliné aux haltères), `chest-press-machine` ★ (Chest press convergent), `incline-chest-press-machine` (Chest press incliné), `push-up` (Pompes) |
| chestFly (4) | `pec-deck-machine` ★ (Écarté à la machine), `cable-crossover` (Écarté à la poulie vis-à-vis), `dumbbell-fly` (Écarté aux haltères), `low-to-high-cable-fly` (Écarté poulie basse) |
| verticalPush (4) | `overhead-press-barbell` (Développé militaire à la barre), `seated-dumbbell-shoulder-press` (Développé épaules assis aux haltères), `shoulder-press-machine` (Développé épaules à la machine), `arnold-press` (Développé Arnold) |
| shoulderIsolation (5) | `lateral-raise-machine` ★ (Élévation latérale à la machine), `lateral-raise-dumbbell` (Élévation latérale aux haltères), `lateral-raise-cable` (Élévation latérale à la poulie), `reverse-pec-deck-machine` (Oiseau à la machine), `face-pull-cable` (Face pull à la poulie) |
| verticalPull (4) | `lat-pulldown-machine` ★ (Tirage vertical machine convergente), `lat-pulldown-cable` (Tirage vertical à la poulie), `pull-up` (Tractions), `assisted-pull-up-machine` (Tractions assistées) |
| horizontalPull (5) | `seated-row-machine-iso-lateral` ★ (Tirage bas iso-latéral), `seated-cable-row` (Tirage horizontal à la poulie), `barbell-row` (Rowing à la barre), `one-arm-dumbbell-row` (Rowing haltère un bras), `chest-supported-row-machine` (Rowing buste appuyé à la machine) |
| elbowFlexion (5) | `preacher-curl-machine` ★ (Curl pupitre à la machine), `hammer-curl-dumbbell` ★ (Curl marteau aux haltères), `barbell-curl` (Curl à la barre), `ez-bar-preacher-curl` (Curl pupitre barre EZ), `cable-curl` (Curl à la poulie) |
| elbowExtension (5) | `triceps-pushdown-cable` ★ (Extension triceps poulie haute), `overhead-triceps-extension-cable` (Extension triceps au-dessus de la tête à la poulie), `skull-crusher-ez-bar` (Barre au front), `close-grip-bench-press` (Développé couché prise serrée), `dips` (Dips) |
| forearm (4) | `wrist-curl-cable` ★ (Flexion des poignets à la poulie, barre droite), `wrist-curl-barbell` (Flexion des poignets à la barre), `reverse-wrist-curl-barbell` (Extension des poignets à la barre), `reverse-curl-ez-bar` (Curl inversé barre EZ) |
| squat (5) | `back-squat-barbell` (Squat barre), `front-squat-barbell` (Squat avant), `goblet-squat` (Goblet squat), `hack-squat-machine` (Hack squat), `leg-press-machine` ★ (Presse à cuisses) |
| lunge (4) | `walking-lunge-dumbbell` (Fentes marchées aux haltères), `bulgarian-split-squat` (Fente bulgare), `reverse-lunge-dumbbell` (Fente arrière aux haltères), `step-up-dumbbell` (Montée sur banc aux haltères) |
| hinge (5) | `deadlift-barbell` (Soulevé de terre), `romanian-deadlift-barbell` (Soulevé de terre roumain à la barre), `romanian-deadlift-dumbbell` (Soulevé de terre roumain aux haltères), `single-leg-romanian-deadlift` (Soulevé de terre roumain unijambiste), `hip-thrust-barbell` (Hip thrust à la barre) |
| kneeFlexion (4) | `lying-leg-curl-machine` ★ (Leg curl allongé), `seated-leg-curl-machine` (Leg curl assis), `nordic-hamstring-curl` (Nordic curl), `stability-ball-leg-curl` (Leg curl au ballon) |
| kneeExtension (4) | `leg-extension-machine` ★ (Extension des jambes), `single-leg-extension-machine` (Extension des jambes unilatérale), `sissy-squat` (Sissy squat), `spanish-squat-band` (Squat espagnol à l'élastique) |
| hipAbduction (4) | `hip-abduction-machine` ★ (Abduction de hanche à la machine), `cable-hip-abduction` (Abduction de hanche à la poulie), `band-lateral-walk` (Marche latérale à l'élastique), `side-lying-hip-abduction` (Abduction de hanche allongé) |
| hipAdduction (4) | `hip-adduction-machine` ★ (Adduction de hanche à la machine), `cable-hip-adduction` (Adduction de hanche à la poulie), `copenhagen-plank` (Planche de Copenhague), `side-lying-hip-adduction` (Adduction de hanche allongé) |
| calfRaise (4) | `seated-calf-raise-machine` ★ (Extension des mollets assis), `standing-calf-raise-machine` (Extension des mollets debout à la machine), `leg-press-calf-raise` (Mollets à la presse), `single-leg-calf-raise-dumbbell` (Mollets unijambiste avec haltère) |
| coreFlexion (4) | `crunch-machine` ★ (Crunch à la machine), `cable-crunch` (Crunch à la poulie), `hanging-leg-raise` (Relevé de jambes suspendu), `reverse-crunch` (Crunch inversé) |
| coreStability (4) | `plank` (Planche), `side-plank` (Planche latérale), `dead-bug` (Dead bug), `pallof-press-cable` (Pallof press à la poulie) |

Règles de contenu : les alternatives d'un exercice machine privilégient d'autres machines ou poulies avant la barre ; `isCompound` est vrai pour les développés, squats, presses, soulevés, tractions, rowings, dips et pompes ; `isUnilateral` est vrai pour les exercices « un bras », « unijambiste », fentes, montées sur banc, planche latérale, abduction et adduction allongées, Copenhague.

### 4.3 Schéma JSON des modèles de programme

Un fichier par modèle dans `Resources/Programs/` (`ppl-3.json`, `ppl-6.json`, `upper-lower.json`, `full-body.json`, `runner-strength.json`), et une liste `programs.json` qui les ordonne.

```json
{
  "schemaVersion": 1,
  "id": "ppl-3",
  "name": { "fr": "PPL 3 jours", "en": "PPL 3 days" },
  "summary": { "fr": "Pousser, tirer, jambes : un cycle par semaine, idéal pour trois séances." },
  "recommendedFor": { "focus": "strength", "daysPerWeek": [3] },
  "sessionsPerWeek": 3,
  "days": [
    {
      "id": "push",
      "name": { "fr": "Push" },
      "kind": "strength",
      "exercises": [
        { "exercise": "bench-press-barbell", "sets": 4, "repsMin": 6, "repsMax": 10, "targetRPE": 8, "restSeconds": 120 },
        { "exercise": "triceps-pushdown-cable", "sets": 3, "repsMin": 10, "repsMax": 15, "targetRPE": 8, "restSeconds": 60, "supersetGroup": 1 },
        { "exercise": "wrist-curl-cable", "sets": 3, "repsMin": 12, "repsMax": 20, "targetRPE": 8, "restSeconds": 60, "supersetGroup": 1 }
      ]
    },
    {
      "id": "easy-run",
      "name": { "fr": "Course facile" },
      "kind": "run",
      "run": { "type": "easy", "targetMinutes": 40 }
    }
  ],
  "suggestedWeek": ["push", null, "pull", null, "legs", null, null]
}
```

| Champ | Règle |
| :--- | :--- |
| `id` | même forme et même stabilité que les exercices. |
| `recommendedFor.focus` | `strength`, `balanced`, `endurance` : position du curseur force / endurance qui pré-sélectionne ce modèle à l'onboarding (M3). `daysPerWeek` : nombres de jours pour lesquels le modèle est proposé. |
| `sessionsPerWeek` | séances attendues pour réussir la semaine (spec V1 §5.7), courses planifiées comprises. Égal au nombre de jours non nuls de `suggestedWeek`. |
| `days[].id` | unique dans le modèle. |
| `days[].kind` | `strength` avec `exercises` (1 à 10 entrées), ou `run` avec `run`. |
| `exercises[].exercise` | identifiant d'un exercice **non retiré** du contenu. |
| `sets` | 1 à 6. `repsMin` ≤ `repsMax`, dans 1…30. `targetRPE` dans 6…10 par pas de 0,5. `restSeconds` dans {60, 90, 120, 180}. |
| `supersetGroup` | entier facultatif ; les exercices d'un même groupe sont **consécutifs** dans la liste, et un groupe a exactement 2 exercices. |
| `run.type` | `easy`, `intervals`, `long`. `targetMinutes` ou `targetKm`, l'un des deux, pas les deux. |
| `suggestedWeek` | 7 entrées, lundi à dimanche, identifiant de jour ou `null` ; chaque jour du modèle y apparaît au moins une fois. |

Quand l'utilisateur adopte un modèle (M3), Pulse **copie** le modèle dans un `Program` SwiftData avec `templateID` renseigné : l'utilisateur peut ensuite le modifier et le placer dans sa semaine, et ses modifications se synchronisent. Les modèles eux-mêmes restent dans le bundle. Une modification ultérieure d'un modèle (nouvelle version de l'app) ne se propage **pas** aux programmes déjà adoptés : la copie appartient à l'utilisateur. C'est un choix de ce document ; la spec V1 laissait ouvert « origine (modèle ou custom) ».

### 4.4 Les cinq modèles

**PPL 3 jours** (`ppl-3`, focus `strength`, 3 jours, lundi / mercredi / vendredi). Le PPL de Mathéo. Les valeurs par exercice sont une proposition du constructeur à corriger par Mathéo ; le super set est placé là où il semble le plus probable, à confirmer.

| Jour | Exercice | Séries | Reps | RPE | Repos |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Push | Développé couché à la barre | 4 | 6 à 10 | 8 | 120 s |
| Push | Chest press convergent | 3 | 8 à 12 | 8 | 90 s |
| Push | Écarté à la machine | 3 | 10 à 15 | 8 | 60 s |
| Push | Extension triceps poulie haute | 3 | 10 à 15 | 8 | 60 s (super set A) |
| Push | Flexion des poignets à la poulie | 3 | 12 à 20 | 8 | 60 s (super set A) |
| Push | Crunch à la machine | 3 | 12 à 20 | 8 | 60 s |
| Pull | Tirage vertical machine convergente | 4 | 8 à 12 | 8 | 90 s |
| Pull | Tirage bas iso-latéral | 3 | 8 à 12 | 8 | 90 s |
| Pull | Élévation latérale à la machine | 3 | 12 à 15 | 8 | 60 s |
| Pull | Curl pupitre à la machine | 3 | 10 à 12 | 8 | 60 s |
| Pull | Curl marteau aux haltères | 3 | 10 à 12 | 8 | 60 s |
| Legs | Presse à cuisses | 4 | 8 à 12 | 8 | 120 s |
| Legs | Leg curl allongé | 3 | 10 à 12 | 8 | 90 s |
| Legs | Abduction de hanche à la machine | 3 | 12 à 15 | 8 | 60 s |
| Legs | Adduction de hanche à la machine | 3 | 12 à 15 | 8 | 60 s |
| Legs | Extension des mollets assis | 4 | 12 à 15 | 8 | 60 s |
| Legs | Extension des jambes | 3 | 12 à 15 | 8 | 60 s |

**PPL 6 jours** (`ppl-6`, focus `strength`, 6 jours, lundi à samedi) : les trois mêmes jours, puis une seconde passe « Push 2 / Pull 2 / Legs 2 » avec des variantes de la bibliothèque (développé incliné haltères, chest press incliné, écarté poulie ; tirage poulie, rowing buste appuyé, face pull, curl poulie ; hack squat, leg curl assis, fente bulgare, mollets debout) pour varier les angles. Volume par séance légèrement réduit (3 séries) pour tenir six jours.

**Haut / Bas** (`upper-lower`, focus `balanced`, 4 jours, lundi / mardi / jeudi / vendredi) : Haut A (poussée dominante), Bas A (quadriceps dominant), Haut B (tirage dominant), Bas B (chaîne postérieure). Machines et poulies d'abord, 5 à 6 exercices par jour.

**Full Body** (`full-body`, focus `balanced`, 3 jours, lundi / mercredi / vendredi) : trois séances A / B / C de 6 exercices couvrant à chaque fois une poussée, un tirage, un mouvement de jambes, une charnière ou un ischio, un tronc, une isolation.

**Renforcement coureur** (`runner-strength`, focus `endurance`, 5 séances par semaine dont 3 courses planifiées) : Force A (mardi : squat ou presse, soulevé de terre roumain unijambiste, fente bulgare, mollets, planche latérale, Copenhague), Force B (vendredi : hip thrust, leg curl, montée sur banc, abduction, dead bug, marche latérale à l'élastique), Course facile 40 min (lundi), Fractionné 30 min (jeudi), Sortie longue 60 min (dimanche). `sessionsPerWeek` = 5.

Le détail exercice par exercice des quatre autres modèles est laissé au constructeur dans ces cadres, avec la même grille de valeurs (3 ou 4 séries, RPE 8, repos selon l'exercice).

### 4.5 Chargement

`ContentLibrary` (dans `PulseContent`) charge les JSON depuis `Bundle.module` une seule fois, de façon synchrone au premier accès, et expose :

- `exercises: [Exercise]` dans l'ordre du fichier, `exercise(id:) -> Exercise?`, `activeExercises` (non retirés) ;
- `programTemplates: [ProgramTemplate]` dans l'ordre de `programs.json`, `programTemplate(id:)` ;
- `contentVersion: String`.

Toute erreur de décodage est fatale au chargement (`fatalError` avec le nom du fichier) : un contenu invalide ne doit jamais atteindre un utilisateur, et les tests de validation (§9) garantissent qu'il n'y arrive pas. `ContentValidator` expose la même validation sous forme de liste de problèmes `[ContentIssue]` pour que le test affiche tout ce qui cloche d'un coup plutôt que la première erreur.

---

## 5. Persistance : `PulseDomain` et `PulsePersistence`

### 5.1 Principe

- Les **entités de domaine** sont des `struct` `Sendable, Equatable, Codable` dans `PulseDomain`, avec `id: UUID` généré côté appareil, et sans aucune dépendance SwiftData. Ce sont elles que les features manipulent et que l'export sérialise.
- Les **modèles SwiftData** (`@Model`, préfixés `Stored`) vivent dans `PulsePersistence` et ne sortent jamais du package. Chaque modèle synchronisé porte `createdAt`, `updatedAt`, `deletedAt` (suppression logique). Les dépôts filtrent `deletedAt == nil` par défaut.
- Les **dépôts** sont des protocoles dans `PulseDomain`, implémentés dans `PulsePersistence` par des `@ModelActor`. Les features ne connaissent que les protocoles ; l'app assemble (spec V1 §9).
- Contraintes CloudKit respectées partout : aucune `@Attribute(.unique)`, chaque attribut optionnel ou avec valeur par défaut, chaque relation optionnelle avec son inverse déclaré, suppression en cascade du parent vers les enfants.
- Tout poids est stocké en **kg**, toute durée en secondes ou minutes selon le champ, toute date en `Date` (UTC en base, le calendrier local s'applique à l'affichage). Un « jour » (score, check-in) est stocké comme minuit local du jour, convention déjà prise par `NightSample.day` en M1.
- Les tableaux de valeurs (facteurs manquants, ajustements, jours personnalisés) sont stockés dans SwiftData comme `Data` JSON via des propriétés `Codable`, pas en relations.

### 5.2 Référence à un exercice

Partout où une série ou une routine désigne un exercice :

```swift
public enum ExerciseReference: Sendable, Equatable, Hashable, Codable {
    case content(id: String)   // exercice du bundle
    case user(id: UUID)        // UserExercise
}
```

Encodage `Codable` lisible, utilisé tel quel dans l'export JSON : `{"content": "bench-press-barbell"}` ou `{"user": "8C3A…"}`. En SwiftData, deux colonnes optionnelles `contentExerciseID: String?` et `userExerciseID: UUID?` (exactement une renseignée). En CSV seulement, la référence est aplatie en deux colonnes `content_exercise_id` et `user_exercise_id`. Partout où une série ou un record désigne un exercice, `exerciseName` est recopié au moment de l'écriture pour que l'export reste lisible même si le contenu évolue.

### 5.3 Entités et champs

Les énumérations citées sont des `String` `rawValue`, stockées telles quelles.

**UserProfile** (un seul enregistrement ; le dépôt renvoie le plus ancien par `createdAt` s'il en existe plusieurs après une restauration)
`id`, `sex` (`female`, `male`, `unspecified`), `birthDate: Date?`, `heightCm: Double?`, `weightKg: Double?`, `strengthLevel` et `runningLevel` (`beginner`, `intermediate`, `advanced`), `focus: Double` (0 = force, 1 = endurance, défaut 0,5), `trainingDaysPerWeek: Int` (défaut 3), `restWeekdays: [Weekday]` (`monday`…`sunday`), `equipmentAccess` (`fullGym`, `homeGym`, `bodyweight`), `painAreas: [PainArea]` (`shoulders`, `lowerBack`, `knees`, `wrists`), `weightUnit` (`kg`, `lb`), `adaptationEnabled: Bool` (défaut vrai), `antiInterferenceRulesDisabled: [AntiInterferenceRule]` (`noIntenseRunAfterHeavyLegs`, `sameDayOrdering`, `fullRestDay`), `upperIncrementKg: Double` (2,5), `lowerIncrementKg: Double` (5), `barWeightKg: Double` (20), `availablePlatesKg: [Double]` (25, 20, 15, 10, 5, 2,5, 1,25), `defaultRestSeconds: Int` (90), `autoWarmupEnabled: Bool` (vrai), `theme` (`amber`, `amethyst`), `morningScoreNotification: Bool`, `morningScoreDeadlineMinutes: Int?` (minutes après minuit), `supplementRemindersEnabled: Bool`, `restTimerNotificationEnabled: Bool`, `onboardingCompletedAt: Date?`, `activeProgramID: UUID?`, `deloadWeekStartedAt: Date?` et `deloadDeclinedAt: Date?` (décision sur la semaine de décharge, spec V1 §6.4, remplie en M6).

**Program** → `RoutineDay` (ordonnés) → `RoutineExercise` (ordonnés)
- `Program` : `id`, `name`, `templateID: String?`, `sessionsPerWeek: Int`, `weekLayout: [UUID?]` (7 entrées lundi à dimanche, identifiants de `RoutineDay`, initialisé depuis `suggestedWeek` du modèle), `isArchived: Bool`.
- `RoutineDay` : `id`, `programID`, `order: Int`, `name`, `kind` (`strength`, `run`), `runType` (`easy`, `intervals`, `long`)?, `runTargetMinutes: Int?`, `runTargetKm: Double?`, `exercises: [RoutineExercise]`.
- `RoutineExercise` : `id`, `routineDayID`, `order: Int`, `exercise: ExerciseReference`, `sets: Int`, `repsMin: Int`, `repsMax: Int`, `targetRPE: Double`, `restSeconds: Int`, `supersetGroup: Int?`.

**UserExercise** : `id`, `name`, `primaryMuscle: Muscle`, `secondaryMuscles: [Muscle]`, `equipment: Equipment`, `pattern: MovementPattern`, `region: BodyRegion`, `isUnilateral: Bool`, `defaultIncrementKg: Double`, `defaultRestSeconds: Int`, `isArchived: Bool`.

**WorkoutSession** → `WorkoutSet` (ordonnés)
- `WorkoutSession` : `id`, `startedAt`, `endedAt: Date?`, `kind` (`strength`, `run`, `ride`), `source` (`pulse`, `appleHealth`), `status` (`inProgress`, `completed`, `abandoned`), `programID: UUID?`, `routineDayID: UUID?`, `title` (nom du jour de routine au moment de la séance, ou « Séance libre », ou nom du type de course), `appliedAdjustments: [SessionAdjustment]`, `refusedAdjustments: [SessionAdjustment]`, `overallRPE: Double?`, `note: String?`, `tonnageKg: Double`, `durationMinutes: Double?` (courses importées : durée Apple Santé ; muscu : calculée à la fin), `distanceMeters: Double?`, `averageHeartRate: Double?`, `estimatedRPE: Double?` (courses importées, spec V1 §6.1), `healthKitUUID: String?` (identifiant du `HKWorkout` lu ou écrit), `sets: [WorkoutSet]`.
- `SessionAdjustment` (`Codable`, stocké en JSON) : `kind` (`volume`, `rpeCap`, `rest`, `load`, `replaceWithMobility`, `suggestRest`, `swapIntervalsForEasy`, `deload`), `reason: String` (texte français au moment de la génération), `value: Double?`. M4 et M6 définiront la génération ; M2 fixe le format pour ne pas rouvrir le schéma.
- `WorkoutSet` : `id`, `sessionID`, `order: Int`, `exercise: ExerciseReference`, `exerciseName: String` (copie), `setType` (`warmup`, `working`, `drop`, `failure`), `supersetGroup: Int?`, `plannedWeightKg: Double?`, `plannedReps: Int?`, `actualWeightKg: Double?`, `actualReps: Int?`, `rpe: Double?`, `restSeconds: Int?`, `completedAt: Date?`, `isPersonalRecord: Bool`, `replacedExercise: ExerciseReference?` et `replacementReason` (`machineBusy`, `pain`, `other`)? quand l'exercice a été remplacé en séance (spec V1 §5.5, rempli en M4). Une série « ratée » est une série où `actualReps < plannedReps` ; aucun champ dédié.

**ScheduledDay** (la semaine datée, remplie en M6 ; M2 crée l'entité pour que le glisser-déposer, les déplacements anti-interférence et la validation manuelle d'une course n'ajoutent pas de table plus tard) : `id`, `date` (minuit local), `programID: UUID?`, `routineDayID: UUID?`, `title` (copie du nom du jour), `kind` (`strength`, `run`, `rest`), `status` (`planned`, `completed`, `skipped`), `movedFromDate: Date?`, `moveReason` (`antiInterferenceAfterHeavyLegs`, `antiInterferenceSameDay`, `antiInterferenceRestDay`, `user`)?, `moveReasonText: String?`, `validatedManually: Bool`, `sessionID: UUID?` (séance Pulse ou course Apple Santé qui a validé le jour). Un seul enregistrement par `date` et `routineDayID`.

**DailyRecovery** : `id`, `day`, `score: Double`, `category: RecoveryCategory`, `isEstimated: Bool` (vrai quand issu du check-in), `hrvScore`, `restingHeartRateScore`, `sleepScore` (`Double?` chacun), `sdnnMs`, `sdnnBaselineMs`, `restingHeartRate`, `restingHeartRateBaseline` (`Double?`), `asleepMinutes`, `deepMinutes` (`Int?`), `missingFactors: [Factor]`, `calibration: CalibrationState`, `adjustments: [SessionAdjustment]`, `frozenAt: Date?` (figé à midi, spec V1 §6.3). Un seul enregistrement par `day` ; le dépôt remplace.

**CheckIn** : `id`, `day`, `answers: CheckInAnswers` (`sleep`, `pain`, `motivation`, 0 à 4 ; le type existe dans `PulseRecoveryEngine` depuis M1 et **déménage** dans `PulseDomain`, le moteur l'importe), `score: Double`.

**Supplement** : `id`, `name`, `form` (`powder`, `capsule`, `tablet`, `liquid`), `dose: Double`, `unit` (`g`, `mg`, `iu`, `ml`, `serving`), `timing` (`fixedTime`, `beforeWorkout`, `afterWorkout`, `bedtime`), `timeOfDayMinutes: Int?` (pour `fixedTime`), `days` (`everyDay`, `trainingDays`, `custom`), `customWeekdays: [Weekday]`, `stockDoses: Double?`, `lowStockThreshold: Double?`, `reminderEnabled: Bool`, `healthKitType: String?` (`dietaryVitaminD`, `dietaryMagnesium`, `dietaryCaffeine`, `dietaryProtein`), `isArchived: Bool`, `order: Int`.

**SupplementIntake** : `id`, `supplementID`, `takenAt`, `dose: Double`, `writtenToHealthKit: Bool`, `healthKitUUID: String?`.

**BodyMeasurement** : `id`, `date`, `weightKg: Double?`, `bodyFatPercent: Double?`, `source` (`manual`, `appleHealth`), `healthKitUUID: String?`.

**PersonalRecord** : `id`, `exercise: ExerciseReference`, `exerciseName`, `kind` (`maxWeight`, `estimatedOneRepMax`, `repsAtWeight`), `value: Double`, `weightKg: Double?` (pour `repsAtWeight`), `date`, `sessionID: UUID?`, `setID: UUID?`.

### 5.4 Données locales non synchronisées

Deux modèles vivent dans une configuration SwiftData **séparée, sans CloudKit** (`cloudKitDatabase: .none`), dans le même `ModelContainer` :

- **CachedHealthSample** (la table `HealthSample` de la spec V1) : `id`, `kind` (`sdnn`, `restingHeartRate`, `sleep`, `run`, `ride`), `start`, `end`, `value: Double?` (ms, bpm), `sleepStage: SleepStage?`, `distanceMeters`, `averageHeartRate`, `durationMinutes` (`Double?`), `healthKitUUID: String?`, `sourceBundleID: String?`, `fetchedAt`. Pas de `deletedAt` : la table est reconstructible, on la vide et on relit.
- **HealthQueryAnchor** : `kind`, `anchorData: Data`, `updatedAt`. Réservé aux lectures ancrées de M3.
- **ActiveSessionSnapshot** : `id`, `startedAt`, `updatedAt`, `payload: Data`. La séance en cours de M4 y est écrite à chaque validation, encodée en JSON ; à « Terminer » ou « Abandonner », elle devient un `WorkoutSession` synchronisé et le snapshot est supprimé. C'est ainsi que la spec V1 §4 (« la séance en cours n'est pas synchronisée ») est respectée sans dupliquer les modèles. M2 crée le modèle et son dépôt ; M4 décide du contenu de `payload`.

### 5.5 Dépôts (protocoles dans `PulseDomain`)

Tous `Sendable`, méthodes `async throws`, entrées et sorties en types du domaine.

- `ProfileRepository` : `load() -> UserProfile?`, `save(UserProfile)`.
- `ProgramRepository` : `programs(includeArchived:) -> [Program]`, `program(id:) -> Program?`, `save(Program)` (le programme entier avec ses jours et exercices ; les enfants absents sont supprimés logiquement), `delete(id:)`.
- `UserExerciseRepository` : `all(includeArchived:)`, `save`, `delete(id:)`.
- `WorkoutRepository` : `sessions(from:to:) -> [WorkoutSession]`, `session(id:)`, `save(WorkoutSession)` (séance et séries), `delete(id:)`, `lastSets(for: ExerciseReference, limit:) -> [WorkoutSet]` (« précédent » de la séance live).
- `ScheduledDayRepository` : `days(from:to:) -> [ScheduledDay]`, `save(ScheduledDay)`, `delete(id:)`.
- `RecoveryRepository` : `dailyRecoveries(from:to:)`, `save(DailyRecovery)` (remplace le jour), `checkIns(from:to:)`, `save(CheckIn)`.
- `SupplementRepository` : `supplements(includeArchived:)`, `save(Supplement)`, `delete(id:)`, `intakes(from:to:)`, `save(SupplementIntake)`, `delete(intakeID:)`.
- `BodyMeasurementRepository` : `measurements(from:to:)`, `save`, `delete(id:)`.
- `PersonalRecordRepository` : `records(for: ExerciseReference?) -> [PersonalRecord]`, `save`, `delete(id:)`.
- `HealthSampleCache` : `samples(kind:from:to:) -> [CachedHealthSample]`, `replace(kind:, with: [CachedHealthSample])`, `insert([CachedHealthSample])`, `anchor(for:) -> Data?`, `saveAnchor(_:for:)`, `clear()`.
- `ActiveSessionStore` : `load() -> ActiveSessionSnapshot?`, `save(ActiveSessionSnapshot)`, `clear()`.
- `DataExporter` : `exportJSON() -> URL`, `exportCSVArchive() -> URL` (§6).
- `DataEraser` : `eraseEverything(options: EraseOptions)` (§7).
- `StoreInspector` (debug) : `counts() -> [String: Int]` par table, `cloudAccountStatus() -> CloudAccountStatus` (`available`, `noAccount`, `restricted`, `unknown`).

`delete(id:)` pose `deletedAt` (suppression logique). Les suppressions physiques n'existent que dans `DataEraser`. Les dépôts renvoient les listes triées de façon stable (par `order`, puis par date, puis par `id`).

### 5.6 Conteneur, schéma versionné, iCloud

- `PersistenceStack.makeContainer(mode:)` avec `mode` ∈ {`.cloud` (CloudKit privé, conteneur `iCloud.fr.seonay.pulse`), `.localOnly` (fichier sur disque, sans CloudKit : simulateur sans compte iCloud, aperçus), `.inMemory` (tests)}. L'app choisit `.cloud` si l'entitlement iCloud est présent, sinon `.localOnly`, et l'écran de debug affiche le mode.
- Le schéma est déclaré via `VersionedSchema` (`PulseSchemaV1`) et un `SchemaMigrationPlan` vide dès M2, pour que le premier changement de schéma (M3 ou plus tard) soit une étape de migration et non une refonte. Un test construit le conteneur en mémoire avec le plan.
- Entitlements à ajouter : `com.apple.developer.icloud-services` = `CloudKit`, `com.apple.developer.icloud-container-identifiers` = `iCloud.fr.seonay.pulse`, mode d'arrière-plan `remote-notification` dans `Info.plist` (nécessaire aux notifications de changement CloudKit). Le conteneur CloudKit doit exister sur le compte développeur de Mathéo ; Xcode le crée automatiquement en signature automatique quand l'équipe est renseignée (`DEVELOPMENT_TEAM`, absent du projet aujourd'hui). Le constructeur ajoute les entitlements ; la vérification sur iPhone revient à Mathéo (§10).

### 5.7 Mapping

Pour chaque entité, deux fonctions dans `PulsePersistence` : `Stored*.init(_ domain:)` et `Stored*.toDomain()`. La mise à jour d'un enregistrement existant passe par `Stored*.apply(_ domain:)` qui recopie les champs et pose `updatedAt = now`. Un test d'aller-retour par entité (domaine → stocké → domaine, égalité stricte) avec toutes les options renseignées et avec toutes à `nil`.

---

## 6. Export

Déclenché depuis l'écran de debug en M2, depuis « Mes données » en M7. Tourne hors du thread principal (`@ModelActor`), écrit dans le répertoire temporaire de l'app, rend l'URL ; la vue présente une `ShareLink`. Les enregistrements supprimés logiquement sont **exclus**. Le cache Apple Santé est **exclu** (ce sont des données d'Apple Santé, exportables depuis l'app Santé).

### 6.1 JSON

Fichier `Pulse-AAAA-MM-JJ.json`, UTF-8, clés triées, indenté. Dates ISO 8601 avec décalage horaire de l'appareil (`2026-11-15T08:12:33+01:00`), nombres avec point décimal, énumérations par `rawValue`, `null` pour les absents.

```json
{
  "format": "pulse-export",
  "formatVersion": 1,
  "schemaVersion": 1,
  "contentVersion": "1.0.0",
  "appVersion": "1.0 (1)",
  "exportedAt": "2026-11-15T08:12:33+01:00",
  "locale": "fr_FR",
  "units": { "weight": "kg", "distance": "m", "duration": "minutes", "rest": "seconds" },
  "profile": { },
  "programs": [ ],
  "userExercises": [ ],
  "workoutSessions": [ { "sets": [ ] } ],
  "scheduledDays": [ ],
  "dailyRecoveries": [ ],
  "checkIns": [ ],
  "supplements": [ ],
  "supplementIntakes": [ ],
  "bodyMeasurements": [ ],
  "personalRecords": [ ],
  "contentExercises": { "bench-press-barbell": "Développé couché à la barre" }
}
```

Les objets reprennent **exactement** les champs du §5.3 (mêmes noms), séries imbriquées dans leur séance, jours et exercices imbriqués dans leur programme. `contentExercises` donne le nom français de chaque exercice du contenu référencé au moins une fois, pour qu'une IA lise le fichier sans le bundle. Les `createdAt` / `updatedAt` sont inclus, `deletedAt` jamais (toujours `null` par construction).

### 6.2 CSV

Archive `Pulse-AAAA-MM-JJ-csv.zip` contenant un fichier par table : `profile.csv`, `programs.csv`, `routine_days.csv`, `routine_exercises.csv`, `user_exercises.csv`, `workout_sessions.csv`, `workout_sets.csv`, `scheduled_days.csv`, `daily_recoveries.csv`, `check_ins.csv`, `supplements.csv`, `supplement_intakes.csv`, `body_measurements.csv`, `personal_records.csv`, plus `README.txt` (une ligne par fichier : ce qu'il contient, les unités, la version).

Format RFC 4180 : séparateur virgule, guillemets doubles quand nécessaire, ligne d'en-tête avec les noms de champs du §5.3 en snake_case (`actual_weight_kg`), dates ISO 8601, point décimal, cellule vide pour `nil`, tableaux joints par `|` (`hrv|sleep`), structures JSON (`applied_adjustments`) sérialisées en JSON dans la cellule. Les clés étrangères sont des colonnes (`session_id`, `program_id`, `routine_day_id`, `supplement_id`). `ExerciseReference` devient `content_exercise_id`, `user_exercise_id`, `exercise_name`.

Le zip est produit avec `NSFileCoordinator` et l'option `.forUploading` sur le dossier temporaire (API système, sans dépendance). C'est un choix du constructeur ; toute autre méthode sans dépendance externe est acceptable.

### 6.3 Tests

- Un jeu de données d'exemple (une entité de chaque type, une séance de 3 exercices et 9 séries dont un échauffement et un super set, deux scores, un check-in, un complément et deux prises, un record) inséré dans un conteneur en mémoire, puis exporté : le JSON se décode avec `JSONDecoder` vers les types du domaine et redonne les mêmes valeurs ; chaque CSV a le bon nombre de lignes et les bonnes colonnes ; une valeur contenant une virgule et un guillemet est correctement échappée.
- Export d'une base vide : fichiers valides, tableaux vides, aucune erreur.

---

## 7. Suppression totale

### 7.1 Parcours

1. Écran de confirmation : rappel de ce qui va être effacé (données Pulse sur cet iPhone et dans iCloud), case « Supprimer aussi ce que Pulse a écrit dans Apple Santé » décochée par défaut, champ où taper `SUPPRIMER`, bouton rouge actif seulement quand le mot est exact.
2. Pendant l'opération : indicateur bloquant, texte « Suppression en cours… ».
3. À la fin : l'app repart sur le premier écran du premier lancement (en M2 : l'écran de debug vide, avec un message « Toutes les données ont été supprimées »).

### 7.2 Ce qui est effacé, dans l'ordre

1. Tous les enregistrements de tous les modèles synchronisés, par **suppression physique** (pas `deletedAt`), puis sauvegarde du contexte : le miroir CloudKit propage les suppressions vers iCloud. Si l'iPhone est hors ligne, elles partent dès le retour du réseau ; l'écran le dit (« La suppression dans iCloud se termine dès que l'iPhone est en ligne. »).
2. Tous les enregistrements des modèles locaux (`CachedHealthSample`, `HealthQueryAnchor`, `ActiveSessionSnapshot`).
3. Toutes les clés `UserDefaults` du domaine de l'app (par `removePersistentDomain(forName:)`), y compris le drapeau d'onboarding.
4. Les fichiers d'export restés dans le répertoire temporaire.
5. Si la case est cochée : `HealthErasing.deleteAllSamplesWrittenByPulse()`. `HealthErasing` est un protocole **Foundation seulement, dans `PulseDomain`** (pour que `PulsePersistence` reste testable sur Mac) avec une seule méthode, et une doublure `StubHealthEraser` dans `PulseDomain` qui compte les appels ; `HealthKitWriter` (dans `PulseHealth`) l'implémentera en M4 avec la première écriture (suppression des objets dont la source est l'app, pour les types écrits : entraînements, compléments, poids). L'option est affichée dès M2 mais annotée « disponible quand Pulse écrit dans Apple Santé » tant que l'implémentation est un stub ; le plan M4 porte un rappel explicite.
6. Les notifications locales planifiées (M5) : `DataEraser` prend un `NotificationCanceling` optionnel, nul en M2.

Choix du constructeur, à ne pas rouvrir sans raison : la suppression iCloud passe par le miroir SwiftData (suppression enregistrement par enregistrement) et non par la suppression directe de la zone CloudKit, pour ne pas désynchroniser le magasin local du miroir. Si l'App Store exige une suppression immédiate même hors ligne, la zone pourra être supprimée en plus dans un jalon ultérieur.

### 7.3 Tests

- Conteneur en mémoire rempli avec le jeu d'exemple de §6.3 et des échantillons de cache : après `eraseEverything`, chaque table est vide (`counts()` ne contient que des zéros), `UserDefaults` du domaine de test est vide, le `StubHealthEraser` a été appelé si et seulement si l'option était cochée.

---

## 8. Écran de debug « Données »

Temporaire (remplacé par M3 à M7), sans design system, en `List`. L'app passe à une `TabView` à deux onglets : « Santé » (écran de diagnostic M1) et « Données » (cet écran).

Sections :

1. **Contenu** : version du contenu, `84 exercices`, `5 modèles`. Lien vers une liste des exercices groupés par plan de mouvement (nom FR, matériel, muscle principal, nombre d'alternatives) et une liste des modèles (jours, et pour chaque jour ses exercices résolus avec séries × reps). Un exercice non résolu s'afficherait en rouge ; les tests garantissent qu'il n'y en a pas.
2. **Stockage** : mode du conteneur (`iCloud`, `local`, `mémoire`), état du compte iCloud, nombre d'enregistrements par table, dernière erreur de dépôt.
3. **Actions** : « Insérer des données d'exemple » (le jeu de §6.3, pour tester l'export avant M4), « Exporter en JSON », « Exporter en CSV » (chacun ouvre la feuille de partage), « Tout supprimer » (parcours §7.1).

Un test de modèle (`DataDebugModel`) vérifie que les comptes se mettent à jour après insertion et après suppression, avec un conteneur en mémoire.

---

## 9. Tests et qualité

- **PulseDomain** : égalité et `Codable` des nouvelles entités (aller-retour JSON), `ExerciseReference` encodé lisiblement (`{"content":"id"}` / `{"user":"uuid"}`).
- **PulseContent** (`swift test` sur Mac) : `ContentValidator` ne renvoie aucun problème ; 84 exercices ; identifiants uniques et bien formés ; 3 consignes et 2 à 3 erreurs par exercice ; 3 alternatives existantes, distinctes, de même plan ; au moins 4 exercices par plan ; les 17 exercices ★ présents ; chaque modèle : exercices existants et non retirés, super sets par paires consécutives, `sessionsPerWeek` cohérent avec `suggestedWeek`, `recommendedFor` renseigné ; `ppl-3` reproduit exactement le tableau du §4.4 ; chaque `Muscle`, `Equipment`, `MovementPattern` a un `localizedName` non vide.
- **PulsePersistence** (conteneur en mémoire) : aller-retour par entité ; chaque dépôt (créer, lire, mettre à jour, supprimer logiquement, exclusion des supprimés, tri) ; `save(Program)` qui retire un jour marque le jour et ses exercices supprimés ; `RecoveryRepository.save` remplace le jour ; `lastSets` renvoie les séries de la dernière séance terminée pour l'exercice ; export (§6.3) ; suppression (§7.3) ; le conteneur se construit avec `PulseSchemaV1` et le plan de migration.
- **App** : `DataDebugModel` ; `AppDependencies.live()` construit un conteneur sans planter sur simulateur sans compte iCloud.
- **Lint** : `swiftlint lint --strict` vert ; `file_length` : les fichiers de contenu JSON ne sont pas lintés, mais les tableaux Swift de test non plus ne doivent pas dépasser 400 lignes (découper par thème).
- **Mineurs reportés de la revue M1**, traités dans ce jalon : plafonner `HealthKitReader.sampleCount` (limite de requête, par exemple 10 000) ; ajouter `Pulse/Localizable.xcstrings` à la cible app ; dans `RecoveryCalculator`, ne compter dans la calibration que les nuits dont la SDNN est valide (`HRVBaseline.isValid`) ; supprimer les `.gitignore` redondants de `Packages/PulseDomain` et `Packages/PulseRecoveryEngine`.

---

## 10. Laissé au constructeur

- Les consignes, erreurs et alternatives des 84 exercices, et le détail des quatre modèles autres que PPL 3 jours, dans les cadres du §4.
- L'organisation interne des packages, le nommage des fichiers, la découpe des tests.
- L'implémentation exacte du zip et de l'écriture des fichiers temporaires.
- Le choix entre `swift test` sur Mac et le schéma `Pulse` pour les tests de `PulsePersistence`, après essai.

## 11. Ce qui revient à Mathéo

- Corriger le tableau PPL 3 jours du §4.4 (séries, reps, RPE, repos, position du super set), de préférence avant le plan. Une correction qui arriverait après la fusion de M2 serait un simple changement de contenu, sans effet sur un programme déjà adopté (§4.3).
- Renseigner son équipe de développement dans Xcode (`DEVELOPMENT_TEAM`) et vérifier que le conteneur `iCloud.fr.seonay.pulse` est créé ; puis lancer l'app sur son iPhone connecté à iCloud et vérifier dans l'écran de debug que l'état du compte est « disponible » et que les données d'exemple survivent à une désinstallation / réinstallation (test de restauration, repris en M8).
- **Déployer le schéma CloudKit en production** avant le premier build TestFlight qui doit synchroniser : le premier lancement d'un build de debug sur l'iPhone crée le schéma dans l'environnement *Development* du conteneur ; les builds TestFlight utilisent l'environnement *Production*, où le schéma doit être poussé à la main depuis la console CloudKit (« Deploy Schema Changes »). Tant que ce n'est pas fait, un build TestFlight tourne mais ne synchronise rien, sans erreur visible. Une fois en production, un champ ne peut plus être retiré ni renommé : c'est la raison pour laquelle M2 pose dès maintenant les entités de M3 à M7. À refaire à chaque changement de schéma dans les jalons suivants ; le plan de chaque jalon le rappellera.

## 12. Critère de fin du jalon (feuille de route)

Les dépôts passent leurs tests, l'écran de debug liste le contenu chargé, un export produit des fichiers lisibles, la suppression vide tout. `make test` et `make lint` verts. PR `m2-donnees-contenu` fusionnée dans `master`.
