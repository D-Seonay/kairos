# Pulse M4 — Programmes et séance en direct : spec complémentaire

Date : 2 novembre 2026
Statut : brouillon soumis à validation
Auteur : Mathéo Delaunay, rédigé avec Claude
Complète : `2026-10-31-pulse-v1-design.md` (la « spec V1 », autorité pour le périmètre), `2026-10-31-pulse-m2-donnees-contenu-design.md` (la « spec M2 », modèle de données) et `2026-11-01-pulse-m3-onboarding-tableau-de-bord-design.md` (la « spec M3 »). Ce document précise ce que la spec V1 laisse ouvert pour le jalon M4 de la feuille de route : onglet Séance, bibliothèque, fiche, exercice perso, éditeur de programme, import de l'historique Hevy, séance en direct, chrono de repos et Live Activity, récap, records, règle de progression, échauffement, disques, remplacement, saisie a posteriori, écriture dans Apple Santé, et le découpage en trois plans.

Les décisions prises par Mathéo pendant la conception sont marquées **(Mathéo)**. Les choix du constructeur sont marqués **(choix du constructeur)** : ils peuvent être rouverts, mais pas sans raison.

---

## 1. Intention

Mathéo tient aujourd'hui ses séances dans **Hevy**, et en est satisfait : « tout de l'app est bien ». Pulse doit le remplacer pour son PPL, parce que c'est sa propre app et qu'il veut pouvoir l'améliorer lui-même **(Mathéo)**. M4 est le jalon où Mathéo quitte Hevy. La barre est donc **la gestion de séance de Hevy** : séance en direct, chrono de repos sur l'écran verrouillé avec notification de fin, et possibilité de construire son propre entraînement **(Mathéo)**. Pulse y ajoute ce que Hevy n'a pas : les charges proposées par le moteur, la séance allégée selon le score du matin, et l'explication de chaque changement.

**Son historique le suit (Mathéo).** Mathéo importe l'export CSV de Hevy : 109 séances de novembre 2025 à octobre 2026, 1 805 séries, 74 noms d'exercices. Dès la première séance dans Pulse, la colonne « précédent », les charges proposées, les records et la jauge de charge (28 jours d'historique) sont donc remplis.

**Comment Mathéo s'entraîne**, d'après l'export et la conversation, et ce que cela impose :

- **Semaine fixe (Mathéo)** : Push lundi, Pull mardi, Legs mercredi, Push jeudi, Pull vendredi, repos le week-end. Le modèle `Program.weekLayout` le permet déjà, puisqu'un même jour de routine peut apparaître deux fois.
- **Montée en charge d'une série à l'autre** : 485 blocs d'exercice sur 556 ont des charges différentes entre séries (par exemple 60 × 12 puis 70 × 5). La règle de progression travaille donc **série par série** (§8.1), et non sur une charge unique par exercice.
- **RPE rarement noté** : 18 séries sur 1 805, presque toutes ces deux dernières semaines. La règle doit fonctionner sans RPE.
- **Types de série utilisés** : échauffement (102), échec (50), dégressive (28), et parfois un super set. Les notes de séance et d'exercice sont fréquentes.
- **Machines et poulies** : les poulies montent par 3,5 kg (23,5 → 27 → 30,5). L'incrément de progression doit donc se régler par exercice (§6.1).
- **Motivation** : avoir sa propre app est déjà une motivation selon Mathéo. Les records du récap y contribuent dès M4 ; la série de semaines arrive en M6.

---

## 2. Découpage

M4 dure environ quatre semaines. Comme pour M3 : **une spec (ce document), trois plans, une PR chacun**, exécutés l'un après l'autre. Chaque plan est écrit au moment où il démarre, à partir du code réel.

| Partie | Contenu | Fin de la partie | Branche |
| :--- | :--- | :--- | :--- |
| **M4a — Construire** | schéma V3 et empreinte étendue (§6) ; contenu : exercices tenus, correspondance Hevy, neuf exercices ajoutés (§7) ; records, moteur (§8.2) ; onglet Séance (§9) ; bibliothèque, fiche à trois onglets, exercice perso (§10) ; éditeur de programme et de routines, incrément par exercice (§11) ; historique et « Enregistrer comme routine » (§12) ; import Hevy (§13) ; suites M3b correspondantes (§20). | Le PPL de Mathéo est construit dans Pulse, son historique Hevy y est, records et charge compris. | `m4-programmes-seance-live` (déjà créée depuis `master` à d8ad52a) |
| **M4b — Séance en direct et récap** | règle de progression et ajustements de charge (§8.1) ; séance en direct (§14) ; chrono de repos, notification de fin, Live Activity avec App Intents (§15) ; enregistrement continu et reprise (§16) ; récap et records battus (§17) ; intégration à l'accueil (§18) ; séance libre ; test d'interface « arrêt forcé et reprise » (§21). | Mathéo fait ses séances dans Pulse et quitte Hevy. | `m4b-seance-live`, depuis `master` après la fusion de M4a |
| **M4c — Plus que Hevy** | échauffement automatique, calculateur de disques, remplacement avec charge équivalente (§8.3, §19) ; saisie d'une séance passée (§19.4) ; écriture dans Apple Santé et `HealthErasing` (§19.5) ; suites M3b côté Apple Santé (§20). | Critère de la feuille de route atteint, Apple Santé compris. | `m4c-plus-que-hevy`, depuis `master` après la fusion de M4b |

Le chrono de repos sur l'écran verrouillé et sa notification de fin font partie de M4b, et non de M4c : Mathéo s'en sert à chaque séance dans Hevy **(Mathéo)**. Les autres compléments de la spec V1 (échauffement, disques, remplacement, saisie a posteriori, Apple Santé) peuvent attendre que Mathéo ait quitté Hevy **(choix du constructeur)**.

---

## 3. Objectifs, non-objectifs, anti-objectifs

### Objectifs

- Une séance PPL complète se fait dans Pulse aussi vite que dans Hevy. Saisir une série prend moins de 4 secondes, valeurs proposées acceptées comme modifiées (spec V1 §2).
- Chaque série validée est sur l'iPhone dans la seconde qui suit. Une app tuée en pleine séance reprend exactement où elle en était, durée et repos compris.
- Le chrono de repos est visible dans l'app, sur l'écran verrouillé et dans la Dynamic Island, avec −30 s, +30 s et Passer. Une notification et une vibration annoncent la fin, même app en arrière-plan.
- Les charges proposées suivent la règle de Mathéo (12 répétitions à un effort correct → charge suivante), série par série, et chaque hausse ou retenue est expliquée.
- L'historique Hevy est importé sans perte ni doublon, et chaque correspondance d'exercice est montrée à Mathéo avant l'import.
- Toute la logique (progression, records, import, séance en direct, chrono, reprise, récap, échauffement, disques, charge équivalente) se teste par `swift test` sur le Mac, sans simulateur.

### Non-objectifs (jalons suivants ou hors V1)

- Planning daté, glisser-déposer de la semaine, jours de course planifiés et leur édition, anti-interférence, détail modifiable d'une séance passée (M6). En M4, la semaine se règle par un choix de routine pour chaque jour (§11.2), et l'historique est en lecture seule, suppression mise à part (§12).
- Widgets Série et Séance du jour, et le widget interactif « Démarrer » (M6).
- Compléments dans le récap (M5).
- Stats, mur des records du profil, écran Paramètres complet, unité lb (M7). En M4, tout poids est saisi et affiché en kg **(choix du constructeur)**. Le réglage `weightUnit` existe mais n'est pas encore appliqué.
- Photos, partage, fréquence cardiaque en direct (ceinture), Apple Watch, course GPS (hors V1).
- Import du cardio Hevy (tapis, escaliers, escalade) : ces lignes sont ignorées et comptées dans le résumé de l'import. Import des routines Hevy : l'export ne les contient pas, « Enregistrer comme routine » (§12) en tient lieu.
- Bouton « Pause » de la Live Activity : la durée de séance court toujours, comme dans Hevy **(choix du constructeur)**.

### Anti-objectifs

- Une série perdue : app tuée, iPhone éteint, appel entrant, réseau absent.
- Une séance qui a besoin du réseau.
- Une charge proposée qu'on ne peut pas remplacer d'une touche, ou une hausse proposée sans raison affichée.
- Un import qui double une séance, en oublie une sans le dire, ou rattache un exercice à un autre sans que Mathéo l'ait vu.
- Une donnée de santé brute (VFC, FC, sommeil) dans la Live Activity, une notification, l'écran verrouillé ou un journal (§15.4).
- Une feature qui importe `SwiftData`, `HealthKit`, `ActivityKit`, `PulsePersistence` ou `PulseHealth`.
- Un écran de séance qui demande deux mains ou de petites cibles : cibles de 56 pt, clavier intégré.

---

## 4. Contraintes

- Celles de la spec V1 §3 et §4, de la spec M2 §3 et de la spec M3 §4. Environnement : Xcode 27.0, Swift 6.4, cible iOS 26, `swift-tools-version: 6.2`, mode de langage Swift 6 sur chaque cible, SwiftLint strict (fichiers ≤ 400 lignes, corps de fonction ≤ 50 lignes, lignes ≤ 140), avertissements traités comme des erreurs.
- **Simulateur interdit (Mathéo).** Le constructeur ne lance jamais `xcodebuild test`, `test-without-building`, `make test`, `make test-app`, `simctl boot/install/launch`, ni aucun outil d'appareil. Il vérifie par `make test-packages`, `swiftlint lint --strict`, `make build-app` et `make build-release` (avec `make check-versions`), en désactivant le bac à sable du shell pour `xcodebuild`. Les tests de `PulseTests` et le test d'interface sont écrits et compilés ; c'est Mathéo qui les lance.
- **Checkout partagé avec Mathéo.** Avant chaque commit et chaque push, vérifier `git branch --show-current`. Pousser avec une branche explicite (`git push origin <branche>`), jamais de commit sur `master`. Ajouter les fichiers par chemin explicite, ne jamais modifier un commit d'un autre. Restaurer `project.pbxproj` réécrit par Xcode au lieu de le commiter, sauf changement voulu. Pas de push sans l'accord de Mathéo.
- Commits `type(scope): description` en anglais, sans trailer de co-auteur ni mention de Claude.
- Chaînes visibles en français via `String(localized:)`, avec `bundle: .module` dans les packages, et un catalogue par cible qui en a.
- Pas de `Date()`, `Date.now` ni `Calendar.current` dans la logique : horloge et calendrier injectés. Tests en grégorien `Europe/Paris`, locale `fr_FR`. Bornes horaires par `calendar.date(bySettingHour:…)`.
- Les features dépendent du domaine, du moteur, du design system, du contenu et des protocoles. L'app assemble le tout dans `AppDependencies`.
- `PulseWidgets/Info.plist` et `Pulse/Info.plist` gardent des versions identiques (`make check-versions`).

---

## 5. Architecture

### 5.1 Packages et cibles

- **`PulseDomain`** : nouvelles entités et protocoles (§6, §15.3, §19.5).
- **`PulseRecoveryEngine`** : progression série par série, records et 1RM estimé (Brzycki), charge équivalente, échauffement, disques (§8). Pur, testé sur fixtures.
- **`PulseContent`** : champ `tracksDuration`, table de correspondance des noms Hevy, neuf exercices ajoutés, recherche insensible aux accents (§7, §10.1).
- **`PulsePersistence`** : schéma V3, nouveau dépôt, `lastSets` optimisé, export et effacement étendus (§6).
- **`PulseFeatures`**, deux nouvelles cibles **(choix du constructeur)** :
  - `TrainFeature` (M4a) : onglet Séance, bibliothèque, fiche, exercice perso, éditeur de programme, historique, écrans d'import Hevy. Dépend de `PulseServices`, `PulseDomain`, `PulseRecoveryEngine`, `PulseContent` et `PulseDesignSystem`.
  - `LiveSessionFeature` (M4b) : séance en direct, clavier, chrono, récap. Mêmes dépendances.
  - `PulseServices` gagne l'analyseur et l'importeur Hevy (M4a), le service de séance active, le planificateur de séance et le recalcul des records (M4b).
- **Live Activity (M4b)** : `ActivityKit` et `AppIntents` n'entrent jamais dans `PulseFeatures`. Le type `ActivityAttributes` et les intentions −30 s, +30 s et Passer sont partagés entre l'app et `PulseWidgets`, dans une petite cible iOS seulement. Le constructeur choisit entre une cible de package dédiée et des fichiers communs aux deux cibles Xcode. L'interface de la Live Activity vit dans `PulseWidgets`.
- **`PulseHealth` (M4c)** : `HealthKitWriter` (écriture des séances, implémentation de `HealthErasing`).

### 5.2 Nouveaux protocoles du domaine

Le constructeur fixe leur forme exacte :

- `ExerciseSettingsRepository` (M4a) : lire et enregistrer les réglages par exercice (§6.1).
- `RestTimerNotifying` (M4b) : planifier, déplacer ou annuler la notification de fin de repos.
- `SessionActivityControlling` (M4b) : démarrer, mettre à jour et terminer la Live Activity de la séance. L'implémentation `ActivityKit` est dans l'app ; les tests utilisent une doublure.
- `WorkoutWriting` (M4c) : écrire une séance terminée dans Apple Santé et rendre son identifiant ; demander l'autorisation d'écriture.

Les intentions de la Live Activity s'exécutent dans le processus de l'app et passent par le même service de séance active que l'interface. Il n'y a qu'un seul état de séance.

---

## 6. Données : schéma V3 (M4a)

Une seule migration légère pour tout M4 **(choix du constructeur)**, afin que M4b et M4c n'aient pas à rouvrir le schéma et que Mathéo ne déploie le schéma CloudKit qu'une fois. Uniquement des ajouts optionnels ou avec valeur par défaut, et une nouvelle entité.

### 6.1 Ajouts

- **Nouvelle entité synchronisée `ExerciseSettings`** : `id`, référence d'exercice (`contentExerciseID: String?` ou `userExerciseID: UUID?`, exactement une renseignée), `incrementKg: Double?` (incrément propre à la machine, M4a), `warmupSetCount: Int?` (M4c ; 0 désactive l'échauffement pour cet exercice), `createdAt`, `updatedAt`, `deletedAt`. Un seul enregistrement actif par exercice : le dépôt garde le plus récent. Les réglages d'un exercice valent pour toutes les routines **(choix du constructeur : l'incrément dépend de la machine, pas de la routine)**.
- **`UserExercise.loadKind: LoadKind`** (défaut `external`), pour qu'un exercice perso puisse être assisté ou au poids du corps, comme le contenu. Plus **`UserExercise.isCompound: Bool`** et **`UserExercise.tracksDuration: Bool`** (défaut faux chacun), pour que l'échauffement de M4c et les exercices tenus marchent aussi sur un exercice perso sans nouvelle migration **(choix du constructeur)**.
- **`WorkoutSession.exerciseNotes: [ExerciseNote]`**, stocké en JSON. `ExerciseNote` = référence d'exercice et texte : la note d'un exercice dans une séance, reprise de Hevy (`exercise_notes`) et saisie en séance.
- **`WorkoutSet.durationSeconds: Int?`**, pour les exercices tenus (planche), saisis en secondes (§7.1).
- **`RoutineExercise.setTargets: [SetTarget]?`**, stocké en JSON : une fourchette par série (`repsMin`, `repsMax`), dans l'ordre des séries **(Mathéo : une fourchette par série, pour que les séries lourdes progressent sur leur propre fourchette)**. Absent, la fourchette de l'exercice (`repsMin`, `repsMax`) vaut pour toutes les séries : c'est le cas des modèles adoptés et des programmes existants. Présent, il a exactement `sets` entrées, et `repsMin` / `repsMax` de l'exercice restent renseignés avec le minimum et le maximum des séries, pour l'affichage compact et l'export lisible.
- **`SessionSource.hevy`** : nouvelle valeur d'énumération, stockée en `String`, sans changement de schéma.
- Les dates `createdAt` et `updatedAt` des enfants, différées par la spec M3 §15, sont ajoutées à **`StoredWorkoutSet`**, **`StoredRoutineDay`** et **`StoredRoutineExercise`**, puisque V3 fige le graphe des séances et celui des programmes. Le report de la spec M3 §15 est ainsi soldé.

### 6.2 Migration, empreinte, export, effacement

- `PulseSchemaV3` et une étape légère V2 → V3. On fige dans `PulseSchemaV2` une copie de chaque modèle modifié et de ceux qui lui sont liés (`StoredUserExercise` ; `StoredWorkoutSession` et `StoredWorkoutSet` ; `StoredProgram`, `StoredRoutineDay` et `StoredRoutineExercise`). Un test construit un magasin V2 sur disque, le migre et relit les données.
- **Avant de toucher un modèle**, l'empreinte du schéma (`SchemaFingerprint`) est étendue aux options d'attributs et aux relations inverses (suite de M3b). Les fichiers de référence V1 et V2 sont régénérés à l'identique du code actuel, puis le fichier V3 est ajouté.
- Export JSON et CSV : nouvelle table `exerciseSettings` (`exercise_settings.csv`), nouveaux champs, `schemaVersion` à 3, README mis à jour. La suppression totale efface la nouvelle table.
- `WorkoutRepository.lastSets(for:)` (M4b) lit les séries par référence d'exercice au lieu de reconstruire chaque séance : mineur différé de M2, nécessaire maintenant que l'import apporte plus de cent séances. Le dépôt rend les séries **hors échauffement** (travail, dégressives, échec) de la dernière séance terminée **ou abandonnée** qui contient l'exercice **(choix du constructeur : une série à l'échec est une série de travail chez Mathéo, et une séance abandonnée reste une vraie séance)**.

Mathéo redéploie le schéma CloudKit en production avant le premier TestFlight qui synchronise (§22).

---

## 7. Contenu (M4a)

### 7.1 Exercices tenus

Un champ facultatif `tracksDuration: Bool` (défaut faux) dans `exercises.json`, vrai pour `plank`, `side-plank` et `copenhagen-plank`. Pour un tel exercice, la séance en direct et l'éditeur affichent des secondes à la place des répétitions, stockées dans `WorkoutSet.durationSeconds`. La fourchette de la routine (`repsMin`, `repsMax`) se lit alors en secondes **(choix du constructeur)**. Validé par un test de contenu. Les 84 exercices existants et leurs identifiants ne changent pas.

### 7.3 Exercices ajoutés pour l'historique de Mathéo

Un exercice importé reste rattaché pour toujours à l'identifiant choisi à l'import : il n'existe pas de fusion d'exercices en M4. Les mouvements fréquents de Mathéo qui ont une identité claire entrent donc dans le contenu plutôt que de devenir des exercices perso. Ils gagnent ainsi consignes, alternatives et drapeau `isCompound` **(choix du constructeur)**. Neuf ajouts, ce qui porte le contenu à 93 exercices et `contentVersion` de `1.1.0` à `1.2.0`. Chacun respecte les règles de la spec M2 §4.1 (trois consignes, deux ou trois erreurs, trois alternatives du même plan, `riskAreas`), et les tests de comptage passent à 93 :

| Identifiant (nom FR) | Plan | Nom Hevy repris |
| :--- | :--- | :--- |
| `assisted-dips-machine` (Dips assistés à la machine, `loadKind` assisted) | elbowExtension | Dips Torse (Assisté), Dips Pectoraux (Assisté), Dips Triceps (Assisté), Machine Dips Assis |
| `close-grip-lat-pulldown-cable` (Tirage vertical prise serrée à la poulie) | verticalPull | Tirage Poitrine - Prise Serrée (Poulie) |
| `dumbbell-curl` (Curl aux haltères) | elbowFlexion | Curl Biceps (Haltère) |
| `rope-pushdown-cable` (Extension triceps à la corde) | elbowExtension | Extension Triceps Corde |
| `triceps-extension-machine` (Extension triceps à la machine) | elbowExtension | Extension Triceps (Machine) |
| `decline-chest-press-machine` (Développé décliné à la machine) | horizontalPush | Développé Couché Décliné (Machine) |
| `back-extension-machine` (Extension du dos à la machine) | hinge | Extension Dos (Machine) |
| `hyperextension` (Hyperextension lestée) | hinge | Extension Dos (Hyperextension Lestée) |
| `seated-wrist-curl-dumbbell` (Flexion des poignets assis aux haltères) | forearm | Curl Poignets Paumes vers le Haut Assis |

Le shrug n'a pas de plan de mouvement dans le contenu et reste un exercice perso. Les noms ambigus (« Pull (machine) », « Horizontal Bench Press », « Presse à Cuisses Horizontal », « Tirage Machine Convergente »…) sont laissés au choix de Mathéo à l'import.

### 7.2 Correspondance des noms Hevy

Une ressource `hevy-exercises.json` associe des noms d'exercices Hevy (tels qu'ils apparaissent dans l'export, en français et en anglais) à un identifiant du contenu. Un test vérifie que chaque cible existe et n'est pas retirée. On n'y met que les équivalences sûres. Les variantes (autre prise, autre machine) sont laissées au choix de Mathéo pendant l'import (§13.3). Base de départ, tirée de l'export de Mathéo **(choix du constructeur, à compléter par le constructeur avec les noms standards de Hevy)** :

| Nom Hevy | Exercice Pulse |
| :--- | :--- |
| Développé Couché (Barre) | `bench-press-barbell` |
| Développé Couché (Haltère) | `bench-press-dumbbell` |
| Développé Couché Incliné (Haltère) | `incline-bench-press-dumbbell` |
| Chest Press Convergent (Machine) | `chest-press-machine` |
| Écarté (Machine), Butterfly (Pec Deck) | `pec-deck-machine` |
| Écartés Poulie | `cable-crossover` |
| Extension Triceps Poulie Haute | `triceps-pushdown-cable` |
| Overhead Triceps Extension (Cable) | `overhead-triceps-extension-cable` |
| Dips Triceps | `dips` |
| Avant Bras Poulie Barre Droite | `wrist-curl-cable` |
| Élévation Latérale (Machine) | `lateral-raise-machine` |
| Élévation Latérale (Haltère) | `lateral-raise-dumbbell` |
| Oiseau (Machine) | `reverse-pec-deck-machine` |
| Presse Épaules Assis (Machine) | `shoulder-press-machine` |
| Tirage Haut Machine Convergente | `lat-pulldown-machine` |
| Tirage Poitrine (Poulie) | `lat-pulldown-cable` |
| Tractions | `pull-up` |
| Tirage bas iso-latéral | `seated-row-machine-iso-lateral` |
| Seated Cable Row - V Grip (Cable), Tirage assis à la poulie - prise en V (poulie) | `seated-cable-row` |
| Rowing Penché (Barre) | `barbell-row` |
| Curl Pupitre (Machine) | `preacher-curl-machine` |
| Curl Marteau (Haltère) | `hammer-curl-dumbbell` |
| Crunch (Machine) | `crunch-machine` |
| Presse à Cuisses | `leg-press-machine` |
| Hack Squat (Machine) | `hack-squat-machine` |
| Extension Jambes | `leg-extension-machine` |
| Leg Curl Allongé (Machine) | `lying-leg-curl-machine` |
| Leg Curl Assis | `seated-leg-curl-machine` |
| Abduction Hanche | `hip-abduction-machine` |
| Adduction Hanche | `hip-adduction-machine` |
| Extension Mollets Assis | `seated-calf-raise-machine` |
| Extension Mollets (Machine) | `standing-calf-raise-machine` |
| Soulevé de Terre (Barre) | `deadlift-barbell` |

---

## 8. Moteur

### 8.1 Charges proposées et règle de progression (M4b)

Une fonction pure prend un exercice de la séance du jour (séries prévues après ajustement, fourchette, RPE cible), ses séries de la dernière fois (§6.2), son incrément, sa façon d'arrondir et la politique du jour. Elle rend, pour chaque série prévue, une charge et des répétitions proposées, ainsi que l'ajustement nommé éventuel.

**Série par série (proposé par le constructeur, accepté par Mathéo).** La série *n* d'aujourd'hui se compare à la série *n* de la dernière fois, hors échauffement, dans l'ordre. S'il y a plus de séries prévues que faites la dernière fois, les séries en plus reprennent la dernière série faite. Chaque série a **sa propre fourchette** : celle de `setTargets` quand la routine en a, sinon celle de l'exercice (§6.1). Pour chaque série :

- **Pas d'historique** : pas de charge proposée, répétitions = bas de la fourchette. Une fois la première série validée, les séries suivantes de l'exercice reprennent sa charge et ses répétitions comme valeurs proposées **(choix du constructeur)**.
- **Hausse** (règle de Mathéo, double progression de la spec V1) : si la série de référence a atteint le **haut de la fourchette de cette série** et que son RPE noté est **≤ 8, ou absent**, Pulse propose la charge suivante et le bas de la fourchette en répétitions. Sans RPE noté, la hausse est proposée et c'est Mathéo qui juge en tapant autre chose **(choix du constructeur, accepté)**.
- **Sinon** : même charge, une répétition de plus visée, sans dépasser le haut de la fourchette.
- **Charge suivante** : on ajoute l'incrément, puis on arrondit. Barre : aux disques déclarés, par paires. Ailleurs : à la charge réellement faisable, c'est-à-dire la dernière charge plus l'incrément. Exercice au poids du corps : la charge est le lest ajouté, à partir de 0. Exercice assisté : la hausse est une baisse de l'assistance, sans descendre sous 0. Une fois l'assistance à 0, Pulse continue de viser une répétition de plus, même au-delà de la fourchette, et la raison suggère de passer à la version au poids du corps pour lester. À l'import comme en séance, une charge vide sur un exercice assisté vaut 0 d'assistance **(choix du constructeur)**.
- **Incrément** **(choix du constructeur)** : celui de `ExerciseSettings` s'il est réglé ; sinon le plus petit entre l'incrément de l'exercice (contenu ou perso) et celui du profil pour sa région (`upperIncrementKg` ou `lowerIncrementKg`, fixés par le niveau à l'onboarding).

**Politique du jour.**

| Situation | Hausse possible | Séries et repos |
| :--- | :--- | :--- |
| Optimal (90+) | oui **(Mathéo)** | tels que prévus |
| Normal (65 à 89) | oui **(Mathéo : « il faut toujours progresser »)** | repos +15 s (M3b) |
| Fatigue modérée (40 à 64) | non : charges et répétitions de la dernière fois | −20 % de séries, RPE plafonné à 7,5, repos +45 s (M3b) ; une série retirée emporte sa fourchette (`setTargets` garde `sets` entrées), en commençant par la dernière **(choix du constructeur)** |
| Surmenage (< 40) | mobilité ou repos (M3b) ; « Séance d'origine » démarre la séance prévue sans hausse | tels que prévus |
| Score estimé (check-in) ou en calibration | non, comme le promet déjà l'écran du check-in (spec V1 §5.2, §6.3) | selon la catégorie |
| Un facteur manquant cette nuit | ne bloque pas la hausse **(choix du constructeur)** | selon la catégorie |
| Aucun score (pas de données ni de check-in) | oui, puisque l'adaptation ne s'applique pas **(choix du constructeur)** | tels que prévus |
| « Séance d'origine » choisie | oui si la catégorie l'autorise | tels que prévus |
| `adaptationEnabled` faux | oui | tels que prévus, aucun ajustement de catégorie |

Ce tableau remplace, pour la catégorie normale, la ligne « charges de la dernière fois » de la spec V1 §6.5, ainsi que `RecoveryResult.allowsProgressiveOverload` pour la décision de hausse. La question laissée ouverte par la spec M3 §9.1 est tranchée par la ligne « facteur manquant ».

**Ajustements nommés.** Chaque exercice qui reçoit au moins une hausse produit un `SessionAdjustment` de nature `load`, avec sa raison (« Développé couché : +2,5 kg sur 2 séries, 12 répétitions atteintes la dernière fois ») et l'écart en kg comme valeur. Ces ajustements apparaissent dans le Pourquoi (§18) et dans l'en-tête de l'exercice en séance (§14.3). Ils sont enregistrés dans `WorkoutSession.appliedAdjustments`, avec ceux de la catégorie. `DailyRecovery.adjustments` ne garde que ceux de la catégorie, comme en M3b, parce que la charge dépend de la routine réellement démarrée **(choix du constructeur)**.

### 8.2 Records et 1RM estimé (M4a)

Une fonction pure parcourt les séances dans l'ordre chronologique et produit les records :

- **Séries prises en compte** : celles qui ont des répétitions réalisées, hors échauffement.
- **Exercices à charge externe** : `maxWeight` (plus lourde charge faite au moins une fois), `estimatedOneRepMax` (Brzycki, spec V1 §5.4 : `charge × 36 / (37 − reps)`, calculé seulement de 1 à 12 répétitions **(choix du constructeur)**), et `repsAtWeight` (plus de répétitions que jamais à une charge donnée).
- **Exercices au poids du corps ou assistés** : `repsAtWeight` seulement, la charge étant le lest ou l'assistance.
- **Stockage** : chaque record battu est un nouvel enregistrement `PersonalRecord`, ce qui garde l'historique des records ; le record actuel est le plus récent par exercice, nature et charge. La série qui l'a battu porte `isPersonalRecord`.
- **Recalcul** : la table des records se recalcule entièrement depuis l'historique à chaque import, suppression de séance ou saisie a posteriori **(choix du constructeur : c'est une table dérivée, plus simple à garder juste qu'à corriger)**. À la fin d'une séance en direct, on ne calcule que les records de la séance.
- **Première apparition d'un exercice** : elle établit ses records, mais n'est pas annoncée comme « record battu » dans le récap.
- **Première fois à une charge** : ce n'est pas un record `repsAtWeight` (seulement `maxWeight` si la charge est la plus lourde jamais faite). Un record de répétitions demande que la même charge ait déjà été faite. Sinon, avec les poulies à 3,5 kg et la montée en charge, chaque hausse apparaîtrait comme un record **(choix du constructeur)**. Records `maxWeight` et `estimatedOneRepMax` : seulement quand ils sont strictement dépassés.

Le 1RM estimé sert aussi à la fiche (§10.2) et à la charge équivalente (§8.3).

### 8.3 Échauffement, disques, charge équivalente (M4c)

- **Échauffement automatique** (spec V1 §5.5) : si `autoWarmupEnabled` est vrai et que l'exercice est un polyarticulaire (`isCompound`, ou réglage de l'exercice), Pulse ajoute avant la première série de travail des séries d'échauffement. Pour la barre : barre seule, 60 % et 80 % de la première charge de travail. Pour le reste : 60 % et 80 % **(choix du constructeur)**. Arrondi aux disques ou à l'incrément, repos de 60 s, hors volume et hors records. Les séries qui retombent sur la barre seule ou en double sont supprimées. `warmupSetCount` en limite le nombre. Pas d'échauffement si le muscle principal a déjà été travaillé plus tôt dans la séance. Recalculé tant que la première série de travail n'est pas validée et que sa charge change.
- **Calculateur de disques** : pour les exercices à la barre (`barbell`), les disques par côté pour la charge de la série courante, à partir de `barWeightKg` et `availablePlatesKg` du profil, avec le moins de disques possible. Si la charge n'est pas faisable exactement, il affiche les deux charges faisables les plus proches. Barre et disques se règlent depuis la feuille du calculateur, qui enregistre le profil (l'écran Paramètres arrive en M7).
- **Charge équivalente au remplacement** : si l'exercice de remplacement a un historique, ses propres valeurs proposées (§8.1). Sinon, une estimation à partir du 1RM estimé de l'exercice remplacé, multiplié par un coefficient selon le matériel de départ et d'arrivée (table du moteur, documentée comme une approximation), puis ramenée aux répétitions visées par Brzycki inversé et arrondie. Elle est affichée comme une proposition à ajuster.

---

## 9. Onglet Séance (M4a, complété en M4b et M4c)

L'onglet « Séance » de la barre d'onglets (libellé de la spec M3 §17) remplace l'écran d'attente, sur le modèle de la maquette `seance` :

1. **Tuile Musculation** (opale) : la séance du jour, ajustée ou d'origine, comme sur l'accueil, avec « Démarrer » (M4b). Jour de repos : la prochaine séance. **Tuile Course** (obsidienne) : la course du jour ou la prochaine prévue, sans bouton.
2. **Mes routines** : les jours du programme actif, chacun avec ses exercices, sa durée estimée et ses jours de la semaine. « Lancer » (M4b) et toucher pour modifier. Lien « Mon programme » vers l'éditeur (§11) et « + Nouvelle ».
3. **Bibliothèque d'exercices** (§10).
4. **Historique** (§12).
5. **Séance libre** (M4b) : une séance sans routine, exercices ajoutés à la volée, titre « Séance libre ».
6. **Saisir une séance passée** (M4c, §19.4).
7. **Importer depuis Hevy** (§13).

Pendant une séance en cours, le haut de l'onglet et de l'accueil affiche « Reprendre la séance » avec la durée écoulée (§16).

---

## 10. Bibliothèque, fiche, exercice perso (M4a)

### 10.1 Bibliothèque (`biblio`)

Les exercices non retirés du contenu et les exercices perso non archivés. Recherche insensible aux accents et à la casse sur les noms français et anglais. Filtres par groupe musculaire (Pectoraux, Dos, Épaules, Bras, Jambes, Tronc) et par matériel. Les exercices récents (faits lors des 30 derniers jours) en tête, puis l'ordre alphabétique. Chaque ligne affiche le nom, le groupe, le matériel et le 1RM estimé quand il existe. Bouton « Créer un exercice ». Deux modes : consultation (toucher une ligne ouvre la fiche) et choix (sélection multiple, pour une routine, la séance en direct ou l'import). La recherche et les filtres sont des fonctions pures testées.

### 10.2 Fiche exercice (`fiche`)

Trois onglets (spec V1 §5.4) :

- **Technique** : carte musculaire face et dos (principaux en accent, secondaires en `run`, comme la maquette), matériel, plan de mouvement, trois consignes, erreurs à éviter, et le rappel des douleurs déclarées qui concernent l'exercice (`riskAreas` croisés avec `painAreas`). Pour un exercice perso, seulement ce qui existe.
- **Progression** : 1RM estimé actuel et son évolution sur 30 jours, meilleure série, courbe du 1RM estimé sur 90 jours (Swift Charts), dernières séances (date, séries, RPE, tonnage, mention record). Le réglage d'incrément de l'exercice est aussi modifiable ici.
- **Alternatives** : les trois alternatives du contenu ; toucher l'une d'elles ouvre sa fiche.

### 10.3 Exercice perso

Création et modification depuis la bibliothèque et depuis l'import : nom, muscle principal, muscles secondaires, matériel, plan de mouvement, région, unilatéral, nature de charge (externe, poids du corps, assistée), incrément et repos par défaut, pré-remplis selon le matériel et la région. Archivage. Les consignes et alternatives ne sont pas demandées (spec V1 §5.4).

---

## 11. Programme et routines (M4a)

### 11.1 Mon programme

Le programme actif : son nom, ses routines, et sa **semaine**, sept lignes de lundi à dimanche où chaque jour reçoit une routine ou « Repos ». C'est ainsi que Mathéo pose Push, Pull, Legs, Push, Pull **(Mathéo)**. `sessionsPerWeek` est le nombre de jours non vides **(choix du constructeur)**. Actions : renommer, ajouter une routine (vide, copiée d'une autre, ou depuis une séance passée, §12), supprimer une routine (elle sort aussi de la semaine), changer de programme actif, adopter un modèle (réutilise `ProgramAdopter` de M3a), créer un programme vide, archiver. Les jours de course des modèles restent affichés, mais ne s'éditent pas avant M6.

### 11.2 Éditeur de routine

Nom, puis la liste des exercices, réordonnable par glisser. Ajout depuis la bibliothèque en mode choix. Pour chaque exercice : nombre de séries (1 à 10), fourchette de répétitions (ou de secondes, §7.1), la même pour toutes les séries ou une par série (bascule « Par série », §6.1), RPE cible (6 à 10 par pas de 0,5, défaut 8), repos (0 à 5 min par pas de 15 s, défaut : repos de l'exercice), super set avec l'exercice suivant (deux exercices consécutifs, comme le contenu), incrément (écrit dans `ExerciseSettings`), retrait. La durée estimée (règle de la spec M3 §9.3) se met à jour en direct. Les limites sont validées par une fonction pure testée.

Une modification du programme actif change la séance du jour dès le retour à l'accueil. Le score n'est pas recalculé ; les ajustements de catégorie s'appliquent à la routine modifiée.

---

## 12. Historique (M4a)

La liste des séances terminées et abandonnées, de la plus récente à la plus ancienne, regroupées par mois : titre, date, durée, séries, tonnage, records, et une marque « Hevy » pour les séances importées. Le détail est en lecture seule : exercices et séries, notes, carte musculaire, records. La modification d'une séance passée arrive en M6. Deux actions :

- **Enregistrer comme routine (proposé par le constructeur, accepté par Mathéo)** : crée un jour de routine dans le programme actif, ou dans un nouveau programme s'il n'y en a pas. On reprend les exercices dans l'ordre de leur première apparition et les super sets ; le nombre de séries est celui des séries hors échauffement ; si les répétitions faites varient de plus de 3 d'une série à l'autre (montée en charge), une fourchette par série encadre les répétitions de chaque série, sinon une seule fourchette va du plus petit au plus grand nombre, élargie à au moins 4 répétitions d'écart ; RPE cible 8 ; repos par défaut de l'exercice **(choix du constructeur)**. Ensuite, l'éditeur s'ouvre.
- **Supprimer** (suppression logique, confirmation), suivi du recalcul des records (§8.2). Plus « Supprimer toutes les séances importées de Hevy », pour annuler un import raté.

---

## 13. Import Hevy (M4a)

### 13.1 Format (relevé sur l'export de Mathéo)

`workout_data.csv`, RFC 4180, une ligne par série, colonnes `title`, `start_time`, `end_time`, `description`, `exercise_title`, `superset_id`, `exercise_notes`, `set_index`, `set_type` (`normal`, `warmup`, `failure`, `dropset`), `weight_kg`, `reps`, `distance_km`, `duration_seconds`, `rpe`. Les dates sont en heure locale, sans fuseau, au format de la langue de Hevy : `27 oct. 2026, 07:17` en français. L'analyseur accepte aussi les mois anglais (`27 Oct 2026, 07:17`) **(choix du constructeur)** et applique le fuseau du calendrier injecté. Champs vides : poids absent (poids du corps, barre non saisie), RPE absent. Les titres peuvent contenir des émojis.

### 13.2 Ce qui est importé

- **Une séance** par trio (`title`, `start_time`, `end_time`) : `source = hevy`, `status = completed`, titre de Hevy, `startedAt`, `endedAt`, `durationMinutes`, `note` = `description`, `exerciseNotes` = notes d'exercice non vides, tonnage calculé, sans programme ni ajustements, `overallRPE` vide (la charge d'entraînement compte alors le RPE par défaut de 6, comme `TrainingLoad` aujourd'hui).
- **Les séries**, dans l'ordre du fichier : `normal` → `working`, `warmup` → `warmup`, `dropset` → `drop`, `failure` → `failure`. Charge, répétitions, RPE, durée ; `supersetGroup` repris de `superset_id` ; `completedAt` vide.
- **Lignes de cardio** (sans poids ni répétitions, avec durée ou distance) : ignorées et comptées dans le résumé. Une séance qui n'aurait que du cardio n'est pas créée.
- **Doublons** : une séance dont la clé (source Hevy, `startedAt` à la minute, titre) existe déjà est ignorée. Réimporter un export plus récent n'ajoute que les nouvelles séances **(choix du constructeur : Mathéo peut continuer quelques jours sur Hevy pendant la transition)**.
- **Records** recalculés sur tout l'historique (§8.2). Les séances importées ne sont jamais écrites dans Apple Santé (§19.5).

### 13.3 Parcours

1. **Explication et choix du fichier** : où trouver l'export dans Hevy, puis sélecteur de fichiers (`.csv`).
2. **Résumé** : nombre de séances, période, nombre d'exercices, lignes de cardio ignorées, séances déjà présentes. Message clair si le fichier n'est pas un export Hevy.
3. **Correspondance**, triée par nombre de séances. Pour chaque nom Hevy, le choix en cours :
   - une correspondance sûre de la table (§7.2), cochée ;
   - un exercice Pulse choisi dans la bibliothèque ;
   - « Créer un exercice perso », avec un formulaire pré-rempli : nom de Hevy ; matériel, muscle principal et plan de mouvement déduits par mots-clés du nom (« (Poulie) » → poulie, « Mollets » → mollets, « Curl » → biceps, etc.), et signalés « à vérifier » **(choix du constructeur)** ;
   - « Ignorer ».
   Un nom sans correspondance sûre propose par défaut « Créer un exercice perso » avec ces déductions. L'import ne démarre que lorsque chaque ligne a un choix, et chaque choix reste visible et modifiable avant l'import. Les choix sont mémorisés localement (préférences de l'app, effacées par la suppression totale) pour un import suivant.
4. **Import**, avec progression, puis bilan : séances importées, exercices créés, records, et lien vers l'historique.

L'analyse du CSV, la déduction par mots-clés, la conversion en séances, les doublons et les records sont des fonctions pures, testées sur un **extrait anonymisé** construit pour les tests. L'export réel de Mathéo (fourni pendant la conception, 109 séances, c'est celui qu'il importera) peut être lu localement par le constructeur pour régler la table de noms, les mots-clés et l'extrait de test. Il n'est jamais commité, ni recopié dans un test, un journal ou une PR.

---

## 14. Séance en direct (M4b, `live`)

### 14.1 Démarrer

- Depuis l'accueil, « Démarrer la séance » lance la séance du jour : l'ajustée, ou l'originale si « Séance d'origine » est choisie. Dans ce cas, les ajustements de catégorie refusés vont dans `refusedAdjustments` (spec M3 §15). En surmenage, « Séance d'origine » puis « Démarrer quand même » lance la séance prévue.
- Depuis l'onglet Séance : « Lancer » sur une routine (avec les ajustements du jour s'il y a un score), ou « Séance libre ».
- Une seule séance à la fois. S'il y en a déjà une en cours, « Démarrer » propose de la reprendre.

### 14.2 En-tête

Titre, durée écoulée, tonnage cumulé, séries de travail faites sur prévues, bouton « Terminer ». Écran noir pur (`#000`) pendant la séance, contrastes maximaux.

### 14.3 Exercices et séries

Les exercices sont dans l'ordre, et un super set est signalé comme tel. Pour chaque exercice :

- **En-tête** : nom (toucher ouvre la fiche), « Dernière fois 70 × 5 · 5 », et une ligne qui dit ce que le jour a changé (« Même charge, une série en moins, repos 2:45 », ou la raison de la hausse, §8.1). Menu : note, réglage d'incrément, remplacer (M4c), retirer, réordonner.
- **Lignes de série** : numéro (toucher pour passer en échauffement « É », normale, dégressive « D » ou échec « X »), précédent (charge × répétitions de la même série la dernière fois), kg, reps (ou secondes), RPE facultatif, et coche d'au moins 56 pt. Exercice au poids du corps : la colonne « +kg » est le lest. Exercice assisté : « −kg ».
- **Valeurs proposées** en couleur d'accent. Une valeur modifiée passe en couleur neutre et le reste. Toucher la coche sans rien modifier valide les valeurs proposées.
- « + Ajouter une série » (elle reprend la dernière série de l'exercice), suppression d'une série par balayage. « + Ajouter un exercice » ouvre la bibliothèque en mode choix.

### 14.4 Saisie

Un grand clavier numérique intégré, sans clavier système : chiffres, virgule, effacement, −/+ incrément pour la charge, et « Suivant » qui passe de kg à reps puis à la série suivante. Pour le RPE : pilules 6 à 10 par pas de 0,5, et « — » pour l'effacer. Haptiques : légère à la modification, double à la validation, longue à la fin du repos (spec V1 §10). Respect de « Réduire les animations ».

### 14.5 Ajustements en séance

Les séries retirées par la fatigue ne sont pas affichées, mais « Ajouter une série » reste possible. Le RPE plafond du jour s'affiche dans l'en-tête de l'exercice. Le repos de chaque exercice inclut le supplément du jour. Les valeurs proposées sont calculées au démarrage et quand on ajoute un exercice ; elles ne bougent pas quand Mathéo modifie une série précédente. Seule exception : pour un exercice sans historique, les séries suivantes reprennent la première série validée (§8.1) **(choix du constructeur)**.

### 14.6 Terminer, abandonner

« Terminer » demande une confirmation s'il reste des séries prévues non validées, puis ouvre le récap (§17). « Abandonner » (menu de l'en-tête, confirmation) garde les séries validées et enregistre la séance avec le statut `abandoned`. Les séries non validées ne sont jamais enregistrées. Une séance abandonnée compte dans la charge d'entraînement et dans la « dernière fois » **(choix du constructeur)**.

---

## 15. Chrono de repos, notification, Live Activity (M4b)

### 15.1 Chrono dans l'app

La validation d'une série lance le repos de l'exercice (repos de la routine, supplément du jour compris). Exceptions : la dernière série de la séance, et le premier exercice d'un super set, puisque le repos part après le second exercice du tour. Les séries d'échauffement ont 60 s (M4c). Un bandeau en bas de l'écran montre le temps restant, un anneau, la série suivante, et les boutons −30 s, +30 s et Passer. Le chrono repose sur une date de fin (`restEndsAt`), pas sur un compteur, pour rester juste après une mise en veille ou une reprise.

### 15.2 Notification de fin

À chaque lancement ou modification du repos, une notification locale est planifiée à `restEndsAt` (identifiant fixe, remplacée à chaque changement, annulée par Passer ou par la fin de la séance), si `restTimerNotificationEnabled` est vrai. Elle ne s'affiche pas quand l'app est au premier plan, où la vibration longue suffit (même règle que la notification du matin en M3b). Texte : « Repos terminé », et la série suivante (« Développé couché, série 3 : 70 kg × 5 »). Elle est marquée **Time Sensitive**, pour passer un mode de concentration (Sport) en salle. Le constructeur ajoute l'entitlement `com.apple.developer.usernotifications.time-sensitive` à l'app **(choix du constructeur)**. L'autorisation des notifications est déjà demandée à l'onboarding ; si elle est refusée, la séance le signale une fois.

### 15.3 Live Activity et Dynamic Island

Démarrée avec la séance, terminée à « Terminer » ou « Abandonner ». Elle est aussi fermée au lancement suivant si elle ne correspond plus à aucune séance en cours.

- **Pendant un repos** : en compact, l'icône et le temps restant ; en minimal, un anneau. En étendu et sur l'écran verrouillé : anneau, temps restant, série suivante, boutons −30 s, +30 s et Passer.
- **Hors repos** : titre de la séance, durée écoulée, série suivante.
- Les comptes à rebours et la durée utilisent les minuteurs système (`Text(timerInterval:)`). L'activité n'est mise à jour qu'à une action de Mathéo (validation, −30 s, +30 s, Passer, ajout), jamais chaque seconde.
- Les boutons sont des `LiveActivityIntent`. Ils agissent sur le service de séance active de l'app, qui enregistre l'état, met à jour l'activité et replanifie la notification.

### 15.4 Ce qui sort de l'app

La Live Activity, l'écran verrouillé et la notification de repos ne montrent que le titre de la séance, un nom d'exercice, une charge et des répétitions prévues, et des durées. Ce sont des données d'entraînement, pas des données de santé brutes : ni score détaillé, ni VFC, ni FC, ni sommeil. La spec V1 §5.10 prévoit déjà la « série suivante » dans la Live Activity **(choix du constructeur, lecture de la règle de confidentialité à confirmer par Mathéo)**.

---

## 16. Enregistrement continu et reprise (M4b)

- **L'état complet de la séance en cours** est encodé en JSON dans `ActiveSessionSnapshot.payload` (local, non synchronisé, spec M2 §5.4) à chaque validation et à chaque changement de structure ou de valeur : séance, exercices, séries validées ou non, valeurs proposées et modifiées, notes, `restEndsAt`, ajustements. Le format a un numéro de version. Le constructeur choisit le rythme d'écriture des modifications de valeur, mais une validation est écrite avant le retour du geste.
- **À la réouverture** après un arrêt forcé : le bandeau « Reprendre la séance » (accueil et onglet Séance) affiche la durée écoulée calculée depuis `startedAt`. Reprendre rouvre la séance telle quelle, avec le repos encore en cours s'il n'est pas fini. « Abandonner » reste possible depuis le bandeau.
- **Terminer ou abandonner** écrit la `WorkoutSession` synchronisée, puis efface le snapshot. Si l'écriture échoue, le snapshot reste et la séance n'est pas perdue.
- **Séance oubliée** : si plus de 3 h séparent la dernière action (validation ou modification) de « Terminer » ou d'une reprise, Pulse propose de clore la séance à l'heure de la dernière série validée, plus son repos. C'est le choix par défaut ; « Garder l'heure actuelle » reste possible. Ainsi, une séance laissée ouverte toute la nuit ne fausse pas la durée ni la charge (durée × RPE) **(choix du constructeur)**.
- La suppression totale efface aussi le snapshot, termine la Live Activity et annule la notification de repos.

---

## 17. Récap et records (M4b, `recap`)

- Bilan : titre, date, durée, tonnage (séries hors échauffement ; poids du corps : lest seulement ; assisté : 0), séries, et les **records battus**, chacun avec sa nature (« Développé couché : 72,5 kg, nouveau record de charge »).
- Carte des muscles travaillés (fonction d'intensité de M3a : 1 par série de travail pour les principaux, 0,5 pour les secondaires), avec le nombre de séries par groupe.
- **RPE global** par curseur de 1 à 10, pré-placé sur la moyenne des RPE de série s'il y en a, sinon sur 7. Une phrase explique son effet : la charge de la séance (durée × RPE) et le ratio aigu / chronique après la séance quand il est affiché.
- Note libre.
- **Enregistrer** : séance `completed`, `overallRPE`, `note`, tonnage, durée, records enregistrés et séries marquées. En M4c, écriture dans Apple Santé (§19.5). Le récap n'est pas fermable sans « Enregistrer » ou « Plus tard ». « Plus tard » enregistre avec le RPE pré-placé **(choix du constructeur)**.

---

## 18. Accueil (M4b)

- « Démarrer la séance » ouvre la séance en direct à la place de la feuille d'attente de M3b.
- **Pourquoi** : sur les jours optimaux et normaux, la ligne « Charges inchangées » est remplacée par les ajustements de charge du jour (§8.1), calculés sur la séance du jour et l'historique. S'il n'y en a aucun : « Charges de la dernière fois : aucune série n'a atteint le haut de sa fourchette ». Sur les jours de fatigue, la ligne reste.
- **Séance faite** : une fois la séance du jour terminée, la carte affiche son bilan (durée, séries, tonnage, records) à la place de « Démarrer ».
- **Séance en cours** : la carte affiche « Reprendre la séance ».
- Le suivi de charge (ACWR) prend en compte les séances Pulse et les séances importées.

---

## 19. Plus que Hevy (M4c)

### 19.1 Échauffement automatique

Règle du §8.3. Les séries d'échauffement apparaissent en tête de l'exercice, marquées « É », avec leurs valeurs proposées. On peut les supprimer, et leur nombre se règle depuis le menu de l'exercice (`warmupSetCount`).

### 19.2 Calculateur de disques

Une icône disque sur les exercices à la barre ouvre une feuille : charge de la série courante, disques par côté, barre. Réglage de la barre et des disques disponibles. Avec ±2,5 kg, la charge s'applique aux séries restantes de l'exercice (maquette `live`).

### 19.3 Remplacer (`remplacer`)

Depuis le menu de l'exercice : raison (machine occupée, douleur, autre), puis trois alternatives du même plan de mouvement. On prend les alternatives du contenu, filtrées par le matériel accessible et les douleurs déclarées (règle d'acceptabilité de M3a) ; pour un exercice perso, les exercices du même plan. Chaque alternative affiche sa charge équivalente (§8.3), et « Chercher un autre exercice » ouvre la bibliothèque. Les séries déjà validées restent sur l'exercice d'origine. Les séries restantes passent au remplaçant, avec `replacedExercise` et `replacementReason`. Le repos et le plafond de RPE du jour sont conservés. L'historique reste séparé par exercice.

### 19.4 Saisir une séance passée

Depuis l'onglet Séance : date, heure de début (dans le passé), durée, routine ou séance vide. Puis le même écran que la séance en direct, en mode saisie : sans chrono, sans Live Activity, sans notification, avec les valeurs proposées tirées de l'historique antérieur à cette date. Enfin le récap (RPE, note). Enregistrée `completed`, source `pulse`, records recalculés (§8.2).

### 19.5 Écriture dans Apple Santé

- À l'enregistrement d'une séance Pulse terminée (en direct ou saisie a posteriori) : un `HKWorkout` de type `traditionalStrengthTraining`, avec début, fin et énergie estimée. L'énergie est estimée à 5 MET × poids du profil × durée, et omise sans poids **(choix du constructeur)**. `healthKitUUID` est enregistré.
- L'autorisation d'écriture est demandée la première fois, avec un écran d'explication (spec M3 §7.2 : l'écriture se demande au premier besoin). En cas de refus, le récap le dit discrètement, sans bloquer.
- Les séances importées de Hevy et les séances abandonnées ne sont jamais écrites **(choix du constructeur)**. Supprimer une séance de l'historique supprime aussi son entraînement Apple Santé.
- `HealthKitWriter` implémente `HealthErasing.deleteAllSamplesWrittenByPulse()` pour les entraînements écrits par Pulse (rappel de la spec M2 §7.2). L'option de la suppression totale perd sa mention « disponible quand Pulse écrit dans Apple Santé ».
- Si Hevy écrit aussi dans Apple Santé, Mathéo désactive cette écriture dans Hevy pour éviter les doublons (§22).

---

## 20. Suites de M3b et mineurs différés

| Suite | Partie | Raison |
| :--- | :--- | :--- |
| Étendre l'empreinte du schéma aux options d'attributs et aux relations inverses avant le premier changement de modèle | M4a | V3 change six modèles (§6.2) |
| Le `try?` sur la lecture du programme enregistre des ajustements vides, qui restent après le figement de midi : un échec de lecture ne doit plus écraser les ajustements du jour | M4a | l'éditeur rend le programme modifiable à toute heure |
| Avertissement Release dans `PulseDomain/Export/ExportDocument.swift:81` et `:93` (formateur non `Sendable` capturé dans une fermeture `@Sendable`) | M4a | l'export change pour V3 |
| `WorkoutRepository.lastSets(for:)` optimisé (spec M3 §19) | M4b | séance en direct et historique importé |
| Élaguer le cache Santé au-delà de 60 jours dans `apply`, filtrer par UUID dans la requête, `rollback()` après un enregistrement raté | M4c | M4c touche Apple Santé et `PulsePersistence` côté santé |
| Relancer les observateurs Santé à l'activation de l'app (accès accordé plus tard dans Réglages) | M4c | même raison |
| Une passe au premier plan juste après une suppression totale peut relire Santé et republier le widget : à empêcher | M4c | M4c touche la suppression totale (`HealthErasing`) |
| `HealthErasing` côté HealthKit (spec M2 §7.2) | M4c | première écriture |

---

## 21. Tests et qualité

- **`swift test` sur le Mac** :
  - `PulseRecoveryEngine` : progression (chaque ligne du tableau du §8.1, série par série avec montée en charge, fourchette par série et fourchette unique, retrait de séries qui garde `setTargets` cohérent, RPE absent, incréments, arrondi aux disques, poids du corps, assisté, plus de séries que la dernière fois, pas d'historique), records (chaque nature, échauffement exclu, première apparition, recalcul), Brzycki, échauffement, disques, charge équivalente.
  - `PulseContent` : 93 exercices valides, `tracksDuration`, correspondance Hevy valide, recherche et filtres.
  - `PulsePersistence` : migration V2 → V3, empreintes V1, V2 et V3, aller-retour des nouveaux champs et de `ExerciseSettings`, `lastSets` (abandonnées incluses, échauffement exclu), export, effacement.
  - `PulseServices` : analyse du CSV Hevy (format français et anglais, guillemets, émojis, champs vides), conversion, doublons, cardio ignoré, déduction par mots-clés, service de séance active (validation, ajout, réordonnancement, super set, chrono par date de fin, −30 s, +30 s, Passer, snapshot et reprise après « arrêt » simulé, terminer, abandonner, échec d'écriture qui garde le snapshot).
  - `TrainFeature` : modèles de la bibliothèque, de l'éditeur et de l'import.
  - `LiveSessionFeature` : modèles de la séance, du clavier et du récap.
  - `TodayFeature` : Pourquoi avec ajustements de charge, états « séance faite » et « séance en cours ».
- **Test d'interface (M4b)**, critère de la feuille de route : « séance complète avec arrêt forcé et reprise ». L'app est lancée avec un magasin sur disque remis à zéro au début du test (le magasin en mémoire ne survit pas à l'arrêt), un scénario Apple Santé, et un argument de lancement Debug qui crée un profil terminé et un programme adopté. Le test démarre la séance, valide deux séries, termine l'app (`terminate()`), la relance, vérifie le bandeau, reprend, valide une série, termine et enregistre. Le constructeur l'écrit et le compile ; Mathéo l'exécute.
- **Cible app** : tests de modèles dans `PulseTests` (compilés, lancés par Mathéo).
- **Aperçus SwiftUI** pour chaque écran et composant, sous `#if DEBUG` quand ils utilisent une aide de debug.
- **Accessibilité** : étiquette VoiceOver sur chaque contrôle, ligne de série lue en entier (« Série 2, proposé 70 kilos, 5 répétitions, non validée »), chrono annoncé, Dynamic Type jusqu'à « Accessibilité XL » (les lignes de série passent sur deux lignes), cibles ≥ 56 pt en séance.
- **Makefile** : `test-packages` inclut les nouvelles cibles ; `build-release` compile aussi en Release les packages modifiés.

---

## 22. Ce qui revient à Mathéo

- Lancer `make test-app` et le test d'interface sur son Mac.
- Sur l'iPhone : importer son export Hevy et vérifier la correspondance (M4a) ; faire ses séances PPL dans Pulse, avec la Live Activity, la notification de repos, un arrêt forcé et la reprise (M4b) ; vérifier l'écriture dans Apple Santé (M4c).
- Désactiver l'écriture de Hevy dans Apple Santé une fois passé à Pulse, pour éviter les doublons.
- Déployer le schéma CloudKit V3 en production avant le premier TestFlight qui synchronise (spec M2 §11).
- Vérifier la signature sur l'iPhone. La Live Activity demande une clé `NSSupportsLiveActivities` dans `Pulse/Info.plist`, et la notification Time Sensitive son entitlement ; le constructeur ajoute les deux. Si la signature automatique n'active pas la capacité « Time Sensitive Notifications » sur l'App ID `fr.seonay.pulse`, c'est à Mathéo de l'activer. L'App Group et l'App ID du widget de M3b restent à enregistrer s'ils ne le sont pas déjà.
- Garder des versions identiques dans les deux `Info.plist`.

---

## 23. Laissé au constructeur

- La forme exacte des protocoles du §5.2, l'organisation interne des packages, le nommage des fichiers, et le choix de la cible partagée de la Live Activity (§5.1).
- Le format du snapshot de séance et le rythme d'écriture des modifications de valeur (§16).
- Les textes exacts des écrans, dans l'esprit de la maquette : tutoiement, sans jargon non expliqué.
- Les mots-clés de déduction de l'import et le complément de la table Hevy (§7.2, §13.3).
- La table des coefficients de charge équivalente (§8.3).
- Les animations et micro-interactions, dans le respect de la maquette et de « Réduire les animations ».

---

## 24. Critères de fin

**Pour chaque partie** : `make test-packages` vert, `swiftlint lint --strict` à 0, `make build-app` et `make build-release` réussis (`PulseWidgets` compris), PR ouverte vers `master` avec l'accord de Mathéo pour pousser.

- **M4a** : côté Mathéo, son historique Hevy est importé et son PPL construit dans Pulse.
- **M4b** : test d'interface « séance complète avec arrêt forcé et reprise » compilé. Côté Mathéo : test vert, et ses séances PPL faites dans Pulse (critère de la feuille de route).
- **M4c** : côté Mathéo, séances écrites dans Apple Santé, et échauffement, disques et remplacement essayés en salle.
