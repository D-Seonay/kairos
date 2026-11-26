# Pulse V2c — App Apple Watch : repos et validation des séries au poignet

Date : 2026-11-25. Statut : brouillon, à approuver par Mathéo. Issue : #90.

Références : spec V1 `2026-10-31-pulse-v1-design.md` (§15 : « Apple Watch (miroir du repos, FC en direct) » prévue en V2), spec M4 `2026-11-02-pulse-m4-programmes-seance-live-design.md` (§14 séance en direct, §15 repos, notification et Live Activity, §16 reprise, §19.5 écriture Santé), spec M8 `2026-11-22-pulse-m8-app-store-design.md` (frontière iCloud / appareil, textes publics, accessibilité), spec V2a `2026-11-23-pulse-v2a-course-gps-design.md` (`HKWorkoutSession`, doublons Santé), spec V2b `2026-11-24-pulse-v2b-photos-design.md` (règles Info.plist, `check-info-plist.sh`).

## 1. Intention

La V1 rangeait l'Apple Watch en V2. Le 2026-11-23, Mathéo l'a écartée de la V2 (V2a §1, V2b §1). L'issue #90 la remet sur la table comme troisième projet V2, d'où **V2c**. La question ouverte Q1 (§11) demande de confirmer cette relance.

Le besoin : pendant une séance de musculation, le téléphone reste souvent dans le sac ou sur un banc. La Live Activity (M4 §15.3) montre déjà le repos et propose « Valider » sur l'écran verrouillé, mais il faut avoir l'iPhone en main. Sur la montre, on regarde son poignet entre deux séries. V2c y met l'exercice et la série en cours, le chrono de repos avec une vibration à la fin, un bouton « Valider la série » réglable à la couronne, et la fréquence cardiaque mesurée pendant la séance.

Une contrainte pèse sur toute la spec : **Mathéo n'a pas d'Apple Watch** (il porte une Fitbit dont les données arrivent dans Santé). La façon de construire et de vérifier la montre sans montre est donc un sujet à part entière (§8), pas une note de bas de page.

Sauf mention contraire, les décisions ci-dessous sont des **choix du constructeur**. Les vraies décisions produit sont dans les questions ouvertes (§11), avec une proposition pour chacune.

## 2. Objectifs, non-objectifs, anti-objectifs

### Objectifs
- Pendant une séance démarrée sur l'iPhone, l'app Pulse de la montre s'ouvre d'elle-même (réglage, Q4). Elle montre :
  - l'exercice et la série en cours (« Série 2 sur 4 », échauffement signalé) ;
  - la charge et les répétitions (ou la durée) prévues ;
  - la durée de la séance et la FC en direct.
- Le chrono de repos au poignet, avec la série suivante, et une **vibration à la fin**, même poignet baissé.
- « Valider la série » au poignet, avec la charge et les répétitions reprises de l'iPhone, **modifiables à la couronne**. La validation lance le repos exactement comme la coche de l'écran de séance.
- Les contrôles du repos de la Live Activity : −30 s, +30 s, Passer.
- La FC mesurée par la montre est **enregistrée avec la séance** : l'entraînement Santé de la séance porte la FC et l'énergie active mesurées par la montre, à la place de l'énergie estimée (M4 §19.5). Le récap et le détail de la séance affichent la FC moyenne et maximale.
- iPhone, Live Activity et montre montrent la même séance. Quand les deux appareils se joignent, un geste fait sur l'un apparaît sur les autres en moins de 2 secondes.
- Sans montre, ou avec une montre injoignable, l'iPhone marche exactement comme aujourd'hui.

### Non-objectifs (V2c, premier jalon)
- **Séance autonome sur la montre**, sans iPhone. Démarrer une séance depuis la montre.
- Terminer ou abandonner depuis la montre (proposition : non, Q3). Le récap, le RPE global et la note restent sur l'iPhone.
- Tout ce qui demande l'écran de séance complet :
  - ajouter, retirer, réordonner ou remplacer un exercice ;
  - ajouter ou supprimer une série, changer son type ;
  - le RPE par série, les notes, le calculateur de disques.
- La course sur la montre. V2a reste sur l'iPhone.
- Le miroir de la séance HealthKit vers l'iPhone (§3, approche 2), et la FC en direct sur l'écran de l'iPhone (Q6).
- Complications, widgets de la Smart Stack, cadrans.
- Le score de récupération, l'accueil ou les stats sur la montre.
- La FC dans la charge d'entraînement ou dans un RPE estimé : le RPE noté au récap reste obligatoire pour la musculation (M4 §17).

### Anti-objectifs (échec même si « ça marche »)
- Une série validée deux fois, ou la mauvaise série validée, parce que la montre, la Live Activity et l'iPhone ont agi presque en même temps.
- Une validation qui arrive avec plusieurs minutes de retard et coche une série.
- Une séance perdue, bloquée ou ralentie parce que la montre ne répond pas.
- **Deux entraînements dans Santé pour une même séance** (un de l'iPhone, un de la montre). Ou un entraînement que Pulse ne sait plus supprimer avec sa séance ou à l'effacement total.
- Une valeur de HealthKit (FC, énergie) dans le magasin synchronisé, dans la Live Activity ou dans une notification (règle M8).
- Une séance d'entraînement qui tourne encore sur la montre après la fin de la séance, et qui vide la batterie.
- Un rejet App Store parce que le mode d'arrière-plan `workout-processing` serait arrivé dans l'Info.plist de l'iPhone (V2b §6.3).
- Une politique de confidentialité, une fiche ou un manifeste qui promet plus que le code (règle M8).

## 3. Approches envisagées

1. **App watchOS compagnon, pilotée par l'iPhone (retenue).** L'iPhone reste la seule source de vérité : `ActiveSessionService` tient la séance. La montre est une télécommande qui affiche un état reçu et renvoie des commandes. Elle sert aussi de capteur : sa propre `HKWorkoutSession` mesure la FC, garde l'app vivante poignet baissé et écrit l'entraînement dans Santé. Le transport passe par WatchConnectivity (§5.3).
2. **Séance primaire sur la montre, miroir vers l'iPhone** (`startMirroringToCompanionDevice`, iOS 17 et suivants). C'est le modèle d'Apple pour une séance qu'on peut mener des deux côtés, et le bon point de départ d'une future « séance autonome sur la montre ». Mais il crée deux détenteurs de la séance à réconcilier, double la logique de reprise, et s'accorde mal avec la séance HealthKit que l'iPhone ouvre déjà pour la course (V2a). En plus, son comportement sur simulateur est incertain alors que Mathéo ne peut tester que là. Écartée pour ce jalon.
3. **Pas d'app montre** : ajouter une action « Valider la série » à la notification de fin de repos, que l'iPhone verrouillé relaie déjà à la montre. C'est le moins cher, et utilisable par tous les porteurs de montre dès aujourd'hui. Mais on n'aurait ni FC, ni couronne, ni affichage hors fin de repos, et la notification n'arrive pas quand l'iPhone est déverrouillé. Écartée comme réponse à l'issue, mais gardée en **plan B** si la montre ne peut pas être validée sur un vrai appareil (§12).

## 4. Parcours utilisateur

### 4.1 Installation, réglages, autorisations
- L'app montre est livrée dans l'app iPhone. Elle s'installe d'elle-même si le réglage « Installation automatique » de l'app Watch est actif, sinon depuis l'app Watch de l'iPhone.
- **Paramètres de l'iPhone** : une section « Apple Watch » apparaît seulement si une montre est jumelée. Elle contient :
  - l'état : « Pulse est installé sur ta montre » ou « Installe Pulse depuis l'app Watch » ;
  - l'interrupteur « Ouvrir Pulse sur la montre au début d'une séance » (actif par défaut, Q4).
- **Santé sur la montre** : au premier lancement, un écran d'une phrase explique l'usage, puis vient la demande système. Pulse demande la lecture de la FC et l'écriture des entraînements et de l'énergie active.
  - **Refus** : la montre reste une télécommande, sans FC ni séance HealthKit. Elle ne vit alors qu'écran allumé : poignet baissé, l'app est suspendue et ne vibre plus à la fin du repos. La notification relayée par l'iPhone prend le relais. L'écran le dit en une ligne.

### 4.2 Démarrer
- « Démarrer la séance » sur l'iPhone ne change pas. Si une montre est jumelée, que Pulse y est installé et que le réglage est actif, l'iPhone demande au système d'ouvrir l'app montre (`HKHealthStore.startWatchApp(toHandle:)`). La montre ouvre sa séance HealthKit et demande l'état de la séance.
- Ouvrir l'app montre à la main pendant une séance fait la même chose.
- **Une séance saisie après coup** (M4 §19.4) n'ouvre jamais la montre.
- Sans séance en cours, la montre affiche « Aucune séance en cours » et « Démarre ta séance sur l'iPhone ».

### 4.3 Écrans de la montre

Fond noir pur et contrastes maximaux, comme l'écran de séance (M4 §14.2).

**Série à faire :**
```
┌────────────────────┐
│ Développé couché   │
│ Série 2 sur 4      │
│                    │
│   70 kg  ×  5      │  toucher une valeur, puis couronne
│                    │
│ [    Valider     ] │
│ ♥ 128      24:13   │  FC · durée de la séance
└────────────────────┘
```

**Repos :**
```
┌────────────────────┐
│ Repos       ◯ 1:42 │  anneau et temps restant
│ Ensuite            │
│ Développé couché   │
│ série 3 · 70 × 5   │
│ [−30] [Passer][+30]│
│ ♥ 112              │
└────────────────────┘
```

- **Couronne** : un appui sur la charge ou sur les répétitions sélectionne la valeur (cadre visible), et la couronne la change. Les pas :
  - **charge** : l'incrément de l'exercice (`LiveExercise.incrementKg`), jamais sous 0. Le lest (« +kg ») et l'assistance (« −kg ») suivent la même règle ;
  - **répétitions** : 1, de 1 à 100 ;
  - **durée** (exercice chronométré) : 5 s, de 5 s à 10 min.

  Une valeur modifiée passe en couleur neutre, la proposition reste en couleur d'accent (M4 §14.3).
- **Valeur manquante** (exercice sans historique) : la case affiche « — » et la couronne part de la dernière série validée de l'exercice, sinon de 0. « Valider » reste grisé tant qu'une valeur manque. C'est une différence avec la Live Activity, qui ne propose rien dans ce cas.
- **Valider** envoie la série et les valeurs affichées. Le bouton montre un état « Envoi… » jusqu'à la réponse de l'iPhone (§5.3), puis l'écran passe au repos.
- **Pendant le repos**, on peut encore passer à la série suivante avec « Passer ».
- **Fin de séance sur l'iPhone** : la montre affiche « Séance terminée » quelques secondes, puis l'écran d'attente.
- **Dernière série validée** : la montre affiche « Toutes les séries sont faites » et « Termine la séance sur l'iPhone » (Q3).
- **Écran toujours allumé** (luminosité réduite) : une version épurée, sans secondes qui défilent. Le repos y affiche son heure de fin (« fin à 18:42 »).

### 4.4 Montre et iPhone qui ne se joignent plus
- Une ligne « iPhone injoignable » apparaît.
- Le chrono de repos continue à partir de sa date de fin et vibre à l'heure.
- « Valider », −30 s, +30 s et « Passer » sont grisés, et l'écran dit pourquoi. **Aucune commande n'est mise en file** pour plus tard (§5.3).
- Au retour du lien, la montre redemande l'état et remplace le sien.
- Côté iPhone, rien ne change : écran, Live Activity et notification fonctionnent comme sans montre.

### 4.5 Fin et oubli
- **« Terminer » puis « Enregistrer »** sur l'iPhone : la montre termine sa séance HealthKit à l'heure de fin retenue au récap. L'entraînement Santé suit les règles du §5.6.
- **« Abandonner »** : la montre jette sa séance HealthKit. Une séance abandonnée n'est jamais écrite dans Santé (M4 §19.5).
- **Séance oubliée** : après 3 h sans action (le seuil de M4 §16), la montre jette sa séance HealthKit et l'arrête pour épargner la batterie. Elle affiche « Séance en attente sur l'iPhone ». L'écriture dans Santé revient alors à l'iPhone (§5.6).

## 5. Règles métier

### 5.1 Une seule source de vérité
- `ActiveSessionService` reste **le seul chemin vers la séance en cours** (M4 §5.2). Les commandes de la montre entrent dans la même file que l'écran de séance et les boutons de la Live Activity. Elles s'exécutent donc l'une après l'autre, et chacune est enregistrée dans le snapshot avant la réponse.
- **Valider** porte l'identifiant de la série et les valeurs affichées. Le service applique la commande seulement si cette série est encore **la suivante** (`nextSet(after: lastCheckedSet)`), la même règle que `validateFromActivity`. Sinon, il ne coche rien et répond avec l'état à jour. Une série déjà cochée sur l'iPhone, un double appui ou une commande en retard ne font donc rien.
- Si les valeurs envoyées diffèrent de la série, le service applique une modification puis la validation, **dans la même opération de la file** : une seule écriture et une seule publication.
- **−30 s, +30 s et Passer** portent le début du repos visé (`restStartedAt`). Une commande qui vise un repos déjà remplacé par un autre ne fait rien.
- Les valeurs reçues sont bornées comme celles de l'écran de séance : charge ≥ 0, répétitions de 1 à 100, durée de 5 s à 10 min.
- Après chaque changement, d'où qu'il vienne, `publish(from:to:)` met à jour la notification, la Live Activity **et la montre**. Il n'existe pas d'autre chemin de mise à jour, donc pas de conflit à réconcilier : la Live Activity et la montre sont deux vues du même état.

### 5.2 Ce que l'iPhone envoie à la montre
Un `WatchSessionState`, construit par une fonction pure à partir de `LiveSession`, comme `activityState(for:)` :
- l'identifiant de la séance, son titre, sa date de début et sa dernière action (`lastActionAt`) ;
- une **révision**, la date de l'enregistrement qui a produit l'état. La montre ignore un état plus ancien que celui qu'elle a déjà pour la même séance ;
- la série à faire : nom de l'exercice, numéro et nombre de séries de l'exercice, type, genre de charge, exercice chronométré ou non, valeurs effectives (modifiées, sinon proposées), valeur modifiée ou non, incrément, et valeurs de la dernière série validée de l'exercice (point de départ de la couronne) ;
- le repos (début, fin) et le texte de la série suivante ;
- les séries de travail faites et prévues ;
- l'heure de fin quand la séance se termine, et son issue (enregistrée ou abandonnée).

C'est la même catégorie de données que la Live Activity (M4 §15.4) : des données d'entraînement, aucune donnée de santé. La FC mesurée par la montre ne fait jamais le trajet inverse dans cet état.

### 5.3 Transport (WatchConnectivity)
- **Un seul transport, WatchConnectivity**, pour l'état et les commandes. Il fonctionne entre un iPhone et une montre de simulateur jumelés : c'est ce qui le rend vérifiable sans montre (§8). Il marche aussi quand l'app montre tourne en arrière-plan grâce à sa séance d'entraînement : elle reste alors joignable.
- **De l'iPhone vers la montre** :
  - à chaque publication, `updateApplicationContext` : le dernier état l'emporte, et le système le livre même si l'app montre ne tourne pas ;
  - en plus, `sendMessage` quand la montre est joignable, pour un affichage immédiat.
- **De la montre vers l'iPhone** :
  - `sendMessage` avec réponse, seulement. Le message réveille l'app iPhone en arrière-plan si besoin. La réponse porte l'état à jour ;
  - **pas de `transferUserInfo` pour les commandes** : une validation livrée dix minutes plus tard serait fausse ;
  - sans réponse en 5 secondes, la montre affiche « Non envoyé » et garde son état. Le bouton redevient disponible.
- **Compte rendu Santé, de la montre vers l'iPhone** : il passe par `transferUserInfo`, en file, dont la livraison est garantie même plus tard. Il contient l'identifiant de l'entraînement écrit (ou « jeté »), plus la FC moyenne et maximale pour le récap.
- **Format** : des messages `Codable` avec un numéro de version. Une version inconnue est ignorée, et la montre affiche « Mets Pulse à jour sur tes deux appareils ». Pendant une mise à jour, l'iPhone et la montre peuvent avoir deux versions différentes quelques minutes.

### 5.4 Repos et vibration
- La montre calcule le compte à rebours à partir de la date de fin du repos, jamais avec un compteur (M4 §15.1). Il reste donc juste après une mise en veille, une perte du lien ou une relance.
- **À la fin du repos** : une vibration distincte, une annonce VoiceOver « Repos terminé » suivie de la série suivante, et l'écran passe à la série. La séance d'entraînement garde l'app vivante poignet baissé, ce qui permet de vibrer à l'heure.
- **La notification de fin de repos de l'iPhone reste planifiée** (M4 §15.2). C'est le filet de sécurité si l'app montre est fermée, n'a pas Santé ou a planté. Quand la montre tourne la séance, elle n'affiche pas cette notification relayée, pour éviter une double vibration (`willPresent` sans présentation). Le comportement exact est à vérifier sur appareil (§12). Si la montre ne peut pas la masquer, la double vibration est acceptée : mieux vaut deux vibrations qu'aucune.

### 5.5 La séance HealthKit de la montre
- Une `HKWorkoutSession` de type `traditionalStrengthTraining`, en intérieur, avec un `HKLiveWorkoutBuilder` qui collecte la FC et l'énergie active. Son rôle : afficher la FC, garder l'app vivante poignet baissé, écrire l'entraînement (§5.6).
- **Début** : quand la montre rejoint la séance, à la date de ce moment. Elle ne date jamais la collecte au passé.
- **Arrivée tardive** : si la montre rejoint la séance plus de 5 minutes après son début, son entraînement ne représenterait qu'une partie de la séance. Elle affiche la FC mais jette sa séance HealthKit à la fin, et l'iPhone écrit l'entraînement comme aujourd'hui.
- **Fin** :
  - séance enregistrée : `endCollection(at:)` à l'heure de fin retenue (qui peut être passée pour une séance oubliée), métadonnée `HKMetadataKeyExternalUUID` égale à l'identifiant de la séance (comme `HealthKitWorkoutWriter`), puis `finishWorkout()` ;
  - séance abandonnée, oubliée, ou fin reçue plus de 30 minutes après l'heure de fin : la montre jette l'entraînement (`discardWorkout()`).
- **Plantage de l'app montre** : la reprise passe par `handleActiveWorkoutRecovery()` et `recoverActiveWorkoutSession()`, puis la montre redemande l'état.
- **Plantage de l'iPhone** : la séance reprend depuis le snapshot (M4 §16). La montre garde sa séance HealthKit, et l'iPhone lui renvoie l'état à la relance.

### 5.6 Un seul entraînement dans Santé
- **Principe** : par séance, un entraînement et un seul, écrit par la montre quand elle a mesuré toute la séance, sinon par l'iPhone comme aujourd'hui.
- **Le suivi côté iPhone** : la montre joint à chaque commande et à chaque demande d'état sa situation HealthKit (`running(beganAt)` ou `none`). L'iPhone garde la dernière dans la séance en cours, sous la forme d'un champ optionnel `watchWorkoutBeganAt` du snapshot local. Ce champ survit à un plantage. Ce n'est pas une donnée de santé, c'est une date.
- **À « Enregistrer »** :
  - si `watchWorkoutBeganAt` existe et tombe au plus 5 minutes après le début de la séance, l'iPhone **n'écrit pas** l'entraînement. Il note une passation locale (identifiant de la séance, heure de fin) et envoie la fin à la montre ;
  - sinon, il écrit comme aujourd'hui, et la montre jettera son entraînement.
- **Le compte rendu de la montre** :
  - « écrit » : l'iPhone enregistre l'identifiant dans `healthKitUUID`, comme pour ses propres écritures, puis efface la passation ;
  - « jeté » : l'iPhone écrit l'entraînement lui-même (énergie estimée), puis efface la passation.
- **Rattrapage** : au lancement et à chaque passage du jour, une passation de plus d'une heure déclenche une recherche dans Santé, par la métadonnée `HKMetadataKeyExternalUUID`, d'un entraînement de la séance.
  - S'il existe, l'iPhone le relie à la séance.
  - Sinon, l'iPhone écrit lui-même.
  - Dans les deux cas, la passation est effacée.
  - La montre n'écrit jamais plus de 30 minutes après l'heure de fin : le rattrapage, une heure après, ne peut pas la doubler.
- **Doublon malgré tout** : si un compte rendu « écrit » arrive pour une séance que l'iPhone a déjà écrite (montre restée longtemps hors de portée), l'iPhone supprime son propre entraînement et garde celui de la montre.
- **Suppression et effacement** : supprimer la séance supprime son entraînement (M4 §19.5), qu'il vienne de l'iPhone ou de la montre. `deleteAllSamplesWrittenByPulse` couvre aussi la source « Pulse sur Apple Watch ». Une app iOS peut-elle supprimer ce que son app montre a écrit ? C'est **le premier point à vérifier** (§12). Si elle ne peut pas, la suppression passe par la montre, ou l'on revient au plan « l'iPhone écrit toujours ».
- **Lecture** : Pulse n'importe que les courses (`runningWorkouts`). Un entraînement de musculation écrit par la montre n'est donc jamais réimporté. Le constructeur le vérifie par un test.

### 5.7 FC au récap et dans le détail
- **Récap** : quand le compte rendu de la montre est arrivé, il affiche « FC moyenne 118 · max 162 ». Ces valeurs restent en mémoire, jamais dans le snapshot ni dans la séance synchronisée. Sans elles, rien ne s'affiche.
- **Détail d'une séance passée** : la FC moyenne et maximale de l'entraînement relié (`healthKitUUID`) sont lues dans Santé à l'affichage. Rien n'est stocké.
- La FC ne compte ni dans la charge ni dans les stats (§2).

## 6. Données, stockage et confidentialité

La règle M8 tient. Tout ce que la montre mesure par HealthKit est une donnée de Santé : elle va dans Santé, s'affiche sur l'appareil, et ne va jamais dans le magasin synchronisé.

| Donnée | Où | Pourquoi |
| :--- | :--- | :--- |
| État de la séance envoyé à la montre (titre, exercice, valeurs prévues, dates du repos) | WatchConnectivity, d'appareil à appareil, chiffré par le système. Mémoire de l'app montre et contexte d'application du système. | Même contenu que la Live Activity (M4 §15.4). |
| FC et énergie active mesurées par la montre | Santé, écrites par Pulse sur la montre. Affichées sur la montre. | Données de santé. |
| FC moyenne et maximale envoyées à l'iPhone | Mémoire de l'iPhone pour le récap. Relues dans Santé ensuite. | Données de santé, jamais stockées par Pulse. |
| `watchWorkoutBeganAt` | Snapshot local de la séance en cours (`ActiveSessionSnapshot`, non synchronisé) | Choisir qui écrit dans Santé (§5.6). |
| Passations en attente (identifiant de séance, heure de fin) | Préférences locales de l'iPhone (`UserDefaults`, déjà déclaré `CA92.1`) | Tenue de compte de l'appareil. Elle évite une version de schéma. |
| `healthKitUUID` d'un entraînement écrit par la montre | iCloud, comme aujourd'hui | Identifiant d'une écriture de Pulse, pas une mesure. |
| Réglage « Ouvrir Pulse sur la montre » | Préférences locales de l'iPhone | Réglage de l'appareil. |

- **Schéma SwiftData** : aucun changement. `watchWorkoutBeganAt` est un champ optionnel de `LiveSession`, encodée en JSON dans le snapshot. Un ancien snapshot se décode sans lui, donc `formatVersion` ne change pas. Un test de décodage le garantit.
- **Info.plist de la montre** :
  - `NSHealthShareUsageDescription` et `NSHealthUpdateUsageDescription`, au vouvoiement comme ceux de l'iPhone ;
  - `WKBackgroundModes` avec `workout-processing`, obligatoire pour une séance d'entraînement sur la montre et accepté par App Store Connect pour une app watchOS ;
  - `WKApplication`, `WKCompanionAppBundleIdentifier`, et `WKRunsIndependentlyOfCompanionApp` à `false`.
- **Info.plist de l'iPhone** : inchangé. Il ne reçoit **jamais** `workout-processing`.
- **`scripts/check-info-plist.sh`** :
  - il continue de refuser `workout-processing` dans l'iPhone ;
  - il vérifie les deux textes Santé de la montre et la présence de `workout-processing` dans ses `WKBackgroundModes` ;
  - `make check-versions` compare aussi les versions de la montre à celles de l'app.
- **Entitlements** : HealthKit pour la cible montre. L'iPhone a déjà HealthKit. Le constructeur vérifie que `startWatchApp` ne demande rien de plus.
- **Manifeste de confidentialité** : la cible montre a son propre `PrivacyInfo.xcprivacy`, qui déclare seulement les API à raison qu'elle utilise vraiment (`UserDefaults` si elle s'en sert). Le constructeur vérifie et déclare ce qu'il trouve.
- **Politique** (`docs/confidentialite/index.html`), à mettre à jour :
  - pendant une séance, la montre mesure la FC et l'énergie et les écrit dans Santé ;
  - l'iPhone et la montre échangent l'état de la séance directement, sans serveur ;
  - rien de cela ne va dans iCloud ni chez le développeur ;
  - la date de mise à jour change.
- **Fiche** (`docs/app-store/fiche.md`) :
  - la description mentionne l'app Apple Watch ;
  - les notes de revue expliquent que la montre suit une séance démarrée sur l'iPhone, et comment la tester ;
  - les captures Apple Watch sont ajoutées ;
  - le libellé « Données non collectées » reste vrai.

## 7. Architecture

Elle suit la découpe existante : domaine pur, services, adaptateurs, cibles.

- **Nouveau package `PulseWatchLink`**, pur Swift, pour iOS 26, watchOS 26 et macOS (donc testable par `swift test`), sans dépendance :
  - les messages : `WatchSessionState`, `WatchCommand`, `WatchWorkoutStatus`, `WatchWorkoutReport`, `WatchEnvelope` (version) et leur codec ;
  - `WatchCrownStepper` : les pas et les bornes de la couronne (§4.3) ;
  - `WatchSessionText` : textes affichés et parlés en français, avec son catalogue de chaînes ;
  - `WatchSessionModel` : la machine d'état de la montre. Elle gère l'état reçu, les révisions, la joignabilité, la commande en cours, la fin du repos et l'oubli, avec une horloge injectée.
- **PulseServices** (dépend de `PulseWatchLink`) :
  - le port `SessionWatchPublishing` (démarrer, mettre à jour, terminer), à côté de `SessionActivityControlling`, avec sa doublure ;
  - `ActiveSessionService+Watch` : `watchState(for:revision:)`, `applyFromWatch(_:)`, l'appel dans `publish(from:to:)`, et les branchements dans `start`, `finish`, `abandon` et le ménage ;
  - `WatchHealthHandoff` : passations, compte rendu, rattrapage (§5.6), derrière un protocole de stockage dont l'implémentation lit et écrit `UserDefaults`.
- **PulseDomain** : `WorkoutHealthWriting` gagne la recherche d'un entraînement par identifiant de séance, la FC d'un entraînement, et la suppression qui couvre les deux sources Pulse.
- **PulseHealth** : l'implémentation de ces trois ajouts dans `HealthKitWorkoutWriter`, et un petit adaptateur `startWatchApp`.
- **App iPhone** (`Pulse/Watch/`) :
  - le pont WatchConnectivity (`WCSessionDelegate` vers le service, état vers la montre) ;
  - le lanceur de l'app montre ;
  - le branchement dans `AppDependencies` ;
  - la section « Apple Watch » des Paramètres (ProfileFeature) ;
  - un écran de debug « Montre » avec une **montre simulée** dans le processus (§8).
- **Nouvelle cible Xcode `PulseWatch`** (app watchOS, SwiftUI, watchOS 26), dans un dossier `PulseWatch/` synchronisé comme les autres :
  - l'app et son délégué (configuration d'entraînement reçue, reprise) ;
  - le client WatchConnectivity ;
  - le contrôleur `HKWorkoutSession` ;
  - les vues (attente, autorisation, série, repos, toujours allumé) ;
  - l'Info.plist, les entitlements, le manifeste, l'icône.

  Elle ne dépend que de `PulseWatchLink`. Le design system iOS (`PulseDesignSystem`) n'est pas porté sur watchOS : la montre utilise les styles du système, une couleur d'accent et le fond noir.
- **Accessibilité watchOS** (règles M8b transposées) :
  - **VoiceOver** : chaque valeur et chaque bouton a une étiquette construite par une fonction testée de `WatchSessionText`. Exemples : « Développé couché, série 2 sur 4, 70 kilos, 5 répétitions », « Valider la série 2 », « Repos, 1 minute 42 restantes » ;
  - la charge et les répétitions sont des éléments **ajustables** : balayer vers le haut ou le bas fait le même pas que la couronne ;
  - annonces : « Repos terminé » avec la série suivante, « Série validée », « iPhone injoignable » ;
  - **tailles de texte** jusqu'aux tailles d'accessibilité de watchOS : mise en page dans une vue défilante, aucune valeur tronquée, valeurs sur deux lignes et boutons en pleine largeur aux grandes tailles. Chaque vue a un aperçu à la plus grande taille ;
  - **Réduire les animations** : l'anneau du repos ne s'anime plus, il se met à jour par paliers ;
  - la vibration est toujours doublée d'un changement visible et d'une annonce ;
  - grands boutons en pleine largeur, contraste blanc sur noir.

## 8. Tester sans Apple Watch

Le principe : presque tout se vérifie sans montre. Il reste une liste courte et explicite de ce qui ne peut se vérifier que sur une vraie montre.

1. **Logique pure** (`swift test --package-path Packages/PulseWatchLink`) : codec et versions, pas de la couronne, textes affichés et parlés, machine d'état de la montre avec une horloge injectée. Cela couvre la vibration programmée à la fin du repos, un état ancien ignoré, les commandes grisées hors de portée, le délai de 5 secondes et l'oubli à 3 h.
2. **Service** (`swift test --package-path Packages/PulseFeatures`), avec des doublures de la montre :
   - chaque geste publie vers la montre ;
   - une validation de la montre et une de la Live Activity sur la même série n'en cochent qu'une ;
   - une commande en retard ne fait rien ;
   - les règles de passation, d'arrivée tardive et de rattrapage (§5.6) ;
   - aucune FC dans le snapshot ni dans la séance synchronisée.
3. **Compilation** : `make build-app` construit aussi l'app montre embarquée, et une nouvelle cible `make build-watch` construit la montre seule pour le simulateur watchOS. L'agent compile, il ne lance pas le simulateur.
4. **Simulateurs jumelés** (Mathéo) : un iPhone 17 et une Apple Watch jumelés dans Xcode, les schémas Pulse et PulseWatch lancés côte à côte.
   - WatchConnectivity fonctionne entre simulateurs jumelés.
   - Le simulateur watchOS fait tourner une séance d'entraînement. Qu'il fournisse une FC simulée reste à vérifier.
   - `startWatchApp` peut ne pas ouvrir l'app montre en simulateur. On l'ouvre alors à la main.
   - Les captures App Store de la montre se font ici.
5. **Montre simulée sur le vrai iPhone** (écran de debug « Montre ») : une doublure dans le processus envoie les mêmes `WatchCommand` par le même chemin que le pont WatchConnectivity. Sur son iPhone, Mathéo vérifie ainsi Live Activity, notification, snapshot, passation et rattrapage, sans montre. La même session vérifie qu'un iPhone sans montre jumelée ne change pas de comportement.
6. **Testeur TestFlight avec une Apple Watch** (Q2) : une liste de vérification `docs/app-store/verification-apple-watch.md`. Seule une vraie montre peut vérifier :
   - la vibration poignet baissé ;
   - l'app qui s'ouvre au démarrage ;
   - la FC réelle et l'entraînement unique dans Santé ;
   - la suppression de cet entraînement depuis l'iPhone ;
   - la notification relayée masquée ;
   - la batterie sur une heure.

## 9. Contraintes et barre de qualité
- Mêmes exigences que V1, M8, V2a et V2b :
  - `swift test` vert sur tous les packages, `PulseWatchLink` compris ;
  - `make lint` à 0, avec `PulseWatch` ajouté aux chemins de SwiftLint ;
  - `make build-app`, `make build-watch` et `make build-release` verts.
- Aucune dépendance nouvelle.
- Le simulateur n'est jamais lancé par l'agent. Les tests d'interface (iPhone et montre) sont écrits, mais c'est Mathéo qui les lance.
- **Autonomie** :
  - la montre ne met à jour l'écran qu'à la réception d'un état, à un geste, ou par les minuteurs du système (`Text(timerInterval:)`, `ProgressView(timerInterval:)`) ;
  - aucun message périodique entre les appareils, seulement des messages déclenchés par des gestes ;
  - pas de GPS ;
  - la séance HealthKit s'arrête à la fin ou à l'oubli (§4.5) ;
  - cible : une heure de séance coûte moins de 15 % de batterie sur une montre récente, ordre de grandeur vérifié par le testeur.
- Textes en français, accessibles, au pluriel correct, unités en toutes lettres à l'oral. L'app tutoie, les textes d'autorisation vouvoient.

## 10. Laissé au constructeur
- Le découpage en lots et en PR. Le plus probable :
  - lot 1 : `PulseWatchLink`, service, passation Santé, pont iPhone et montre simulée (vérifiable sans montre) ;
  - lot 2 : la cible watchOS, ses écrans, l'Info.plist et les textes publics.
- La création de la cible watchOS : par édition du projet sur le modèle de `PulseWidgets`, ou en la confiant à Mathéo dans Xcode si `make build-app` ne passe pas.
- Le type exact de vibration, la présentation fine des écrans et la vue toujours allumée.
- Le nom exact des types, des fichiers et des messages.
- La valeur du délai de réponse (5 s proposées) et des fenêtres de passation (5 min, 30 min, 1 h), à l'intérieur des règles du §5.

## 11. Questions ouvertes (à trancher par Mathéo)

| # | Question | Proposition |
| :--- | :--- | :--- |
| Q1 | La montre avait été écartée de la V2 le 2026-11-23. On la relance comme V2c, après V2b ? | Oui. Ce document suppose que c'est le cas. |
| Q2 | Qui teste sur une vraie Apple Watch, et la sortie App Store attend-elle ce test ? | Un testeur TestFlight qui a une montre déroule la liste du §8. Aucune soumission de la version qui contient la montre avant une séance complète réussie sur un vrai appareil. Sans testeur, on livre le plan B (§3, approche 3). |
| Q3 | Peut-on terminer (ou abandonner) la séance depuis la montre ? | Non dans ce jalon : le récap demande le RPE global, qu'on note mieux sur l'iPhone. La montre dit « Termine la séance sur l'iPhone ». À rouvrir au jalon « séance autonome ». |
| Q4 | L'app montre s'ouvre-t-elle d'elle-même au début de chaque séance ? | Oui par défaut, avec l'interrupteur des Paramètres pour le couper. |
| Q5 | Quand la montre a mesuré la séance, l'entraînement Santé vient d'elle (« Pulse » sur Apple Watch, FC et énergie mesurées) plutôt que de l'iPhone (énergie estimée). D'accord ? | Oui : c'est ce qui « enregistre la FC avec la séance ». Les anneaux d'activité comptent alors l'énergie mesurée. |
| Q6 | Afficher aussi la FC en direct sur l'écran de séance de l'iPhone ? | Non dans ce jalon : il faudrait le miroir HealthKit (§3, approche 2), et le téléphone est dans le sac. |
| Q7 | Une complication ou un widget Smart Stack « séance en cours » ? | Non dans ce jalon. À rouvrir après les premiers retours. |
| Q8 | watchOS 26 minimum (comme iOS 26), donc les montres compatibles avec watchOS 26 seulement ? | Oui : une seule version de chaque API, et le même calendrier que l'iPhone. |

## 12. Risques

| Risque | Parade |
| :--- | :--- |
| L'app iOS ne peut pas supprimer un entraînement écrit par son app montre, donc suppression et effacement incomplets. | La première tâche du plan le vérifie (documentation, puis simulateurs jumelés). Si c'est impossible : suppression envoyée à la montre par `transferUserInfo`, ou retour à « l'iPhone écrit toujours, la montre jette » (on perd l'énergie mesurée, pas la FC affichée). |
| La FC ou la séance d'entraînement ne marchent pas sur le simulateur watchOS. | La logique est testée sans simulateur (§8, points 1 et 2). Le point 6 couvre le vrai appareil. Q2 bloque la sortie sans ce test. |
| Double vibration : la notification relayée par l'iPhone et la montre. | Masquage par `willPresent` sur la montre (§5.4). À défaut, double vibration acceptée. La notification n'est jamais retirée, elle sert de filet de sécurité. |
| Message perdu ou en retard, donc une série mal cochée. | Commande liée à l'identifiant de la série et au début du repos (§5.1), aucune file de commandes, état révisé. Tests de concurrence avec la Live Activity. |
| Deux entraînements dans Santé (montre longtemps hors de portée). | Fenêtres 30 min et 1 h (§5.6), recherche par métadonnée avant d'écrire, suppression de l'entraînement iPhone si celui de la montre arrive quand même. |
| Revue App Store : relecteur sans montre, captures montre manquantes, mode d'arrière-plan. | Notes de revue précises, captures depuis le simulateur. `workout-processing` seulement dans la montre, vérifié par `check-info-plist.sh`. L'iPhone marche entièrement sans montre. |
| Xcode Cloud : nouvel identifiant `fr.seonay.pulse.watchkitapp`, capacité HealthKit, signature. | Signature automatique. Mathéo vérifie l'identifiant et la capacité dans le portail développeur avant le premier build Xcode Cloud (§13). Le script `ci_post_clone.sh` ne change pas. |
| Autonomie de la montre. | Règles du §9, séance HealthKit coupée à la fin ou à l'oubli. Mesure par le testeur. |
| Deux versions différentes sur l'iPhone et la montre pendant une mise à jour. | Messages versionnés (§5.3). Un message inconnu est ignoré, avec un texte clair. |

## 13. Laissé à Mathéo
- Répondre aux questions du §11.
- **Portail développeur et Xcode Cloud** : vérifier que l'identifiant de la montre et sa capacité HealthKit existent, puis lancer un premier build Xcode Cloud et vérifier que l'archive contient l'app montre.
- **Simulateurs jumelés** : dérouler la partie simulateur de `verification-apple-watch.md` et faire les captures App Store de la montre.
- **Sur son iPhone, avec la montre simulée** : Live Activity, notification, passation et rattrapage. Et une séance sans montre, pour vérifier que rien n'a changé.
- **Trouver un testeur TestFlight** qui a une Apple Watch (Q2), lui envoyer la liste, et attendre son retour avant de soumettre.
- **App Store Connect** : captures Apple Watch, description et notes de revue depuis `docs/app-store/fiche.md`.
