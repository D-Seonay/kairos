# Pulse V2b — Photos de séance et photos de corps

Date : 2026-11-24. Statut : brouillon, à approuver par Mathéo.

Références : spec V1 `2026-10-31-pulse-v1-design.md` (§2 non-objectifs, §5.6 récap, §5.7 séance passée, §5.9 profil et Mes données, §15 V2), spec M8 `2026-11-22-pulse-m8-app-store-design.md` (frontière iCloud / appareil, confidentialité, accessibilité), spec V2a `2026-11-23-pulse-v2a-course-gps-design.md` (schéma V5, récap de course, tracé en `externalStorage`), maquette V3 `maquette.html` (écrans « Photos » du récap, de la séance passée et de la course, « Photos de progression », « Comparer »).

## 1. Intention

La V2 se limite à deux projets : V2a, la course GPS (PR #22), puis **V2b, les photos** (ce document). L'abonnement et l'Apple Watch sont écartés par Mathéo.

Interrogé sur ce qu'il veut faire des photos, Mathéo a répondu « je te fais confiance » (2026-11-24). L'intention ci-dessous est donc **choix du constructeur**, comme tout ce qui suit sauf mention contraire :

- **Les photos de corps** montrent ce que la balance ne montre pas. Un poids stable peut cacher une recomposition, et une photo de face prise tous les mois la révèle. Elles servent à une seule personne, l'utilisateur, et ne sont jamais montrées à quelqu'un d'autre par l'app.
- **Les photos de séance** forment un journal privé : la salle, la barre chargée, le parcours d'une course. Elles rendent l'historique vivant. Ce n'est pas du social (V3).

## 2. Objectifs, non-objectifs, anti-objectifs

### Objectifs
- Ajouter jusqu'à 6 photos à une séance Pulse (musculation ou course) :
  - pendant la séance live de musculation ;
  - au récap de musculation et au récap de course ;
  - plus tard, depuis le détail de la séance passée.
- Prendre la photo avec l'appareil photo ou l'importer depuis la photothèque.
- Les revoir en grand, les supprimer, et partager une photo de séance si on le décide.
- Prendre des photos de corps de face, de profil et de dos, datées, et les revoir par date.
- Comparer deux dates pour une même pose avec un curseur avant / après. La variation de la tendance du poids entre ces deux dates s'affiche à côté.
- Protéger les photos de corps :
  - elles restent sur l'iPhone ;
  - elles sont chiffrées tant que l'iPhone est verrouillé, dès qu'un code le protège (§5.2) ;
  - elles sont exclues des sauvegardes ;
  - Face ID (ou le code) protège leur écran ;
  - l'app ne les met jamais dans la photothèque.
- Exporter et supprimer les photos, celles de séance comme celles de corps.

### Non-objectifs (V2b)
- Social, partage dans l'app, studio 9:16, flux d'amis (V3).
- Mensurations (tour de taille, bras…), même si la maquette les montre. C'est un autre projet.
- Appareil photo maison :
  - pas de silhouette fantôme de la photo précédente pour s'aligner ;
  - pas de retardateur ;
  - pas de grille.

  On utilise l'appareil photo du système. Ce sera pour plus tard si l'usage le demande.
- Rappel par notification pour reprendre des photos de corps.
- Retouche, recadrage, filtres, vidéo, Live Photos.
- Photos sur les courses et vélos importés d'Apple Santé (§5.1).
- Copie iCloud des photos de corps. Elle est possible plus tard sous forme d'interrupteur, si Mathéo la demande (§3).

### Anti-objectifs (échec même si « ça marche »)
- Une photo de corps qui apparaît ailleurs que dans son écran verrouillé. Aucun de ces endroits n'est acceptable :
  - la photothèque, une feuille de partage, l'export général ;
  - iCloud, une sauvegarde de l'iPhone ;
  - un widget, Spotlight, l'aperçu du sélecteur d'apps.
- Une photo qui garde la position GPS de la prise de vue, dans Pulse ou dans un export.
- Une séance qui ne s'enregistre plus, ou une saisie de série qui ralentit, à cause des photos.
- Une photo de séance perdue parce que l'app a planté pendant la séance.
- Une politique de confidentialité ou un texte d'autorisation qui promet plus que le code ne fait (règle M8).

## 3. Approches envisagées

1. **Photos de séance dans iCloud, photos de corps sur l'iPhone seulement (retenue).**
   - Les photos de séance suivent l'historique, déjà synchronisé : elles reviennent après une réinstallation ou sur un nouvel iPhone.
   - Les photos de corps vivent dans un dossier à part, avec une protection de fichier complète, exclu des sauvegardes, derrière Face ID.
   - Le prix : un iPhone perdu ou changé sans export emporte les photos de corps. L'écran le dit, et un export dédié existe.
2. **Tout dans iCloud, photos de corps verrouillées dans l'app.** Rien ne se perd. En revanche, les photos les plus intimes partent par défaut sur les serveurs d'Apple, chiffrées mais lisibles par Apple sans la Protection avancée des données. Écartée : c'est l'inverse de la promesse la plus forte qu'on puisse faire.
3. **Tout sur l'iPhone.** C'est le plus simple, mais une séance restaurée depuis iCloud reviendrait sans ses photos. Écartée pour cette incohérence.

## 4. Parcours utilisateur

Le registre des textes (tu / vous), le style argentique et la couleur signal unique suivent l'existant.

### 4.1 Photos de séance

**Points d'entrée :**
- **Séance live de musculation** : une icône appareil photo dans l'en-tête, avec un badge qui compte les photos (maquette). Un appui propose « Prendre une photo » ou « Choisir dans Photos ». L'ajout ne doit jamais bloquer la saisie : la photo se traite en arrière-plan et le minuteur de repos continue.
- **Récap de musculation et récap de course** : une section « Photos », avec la mention « privées · 6 au maximum », une grille et une case « Ajouter ».
- **Détail d'une séance passée** (`SessionDetailView` de TrainFeature, ouvert depuis l'historique et le planning) et détail d'une course Pulse (`ActivityDetailModel` de PlanningFeature) : la même section, modifiable.
- La course en direct n'a pas de bouton photo : le téléphone est en poche. On ajoute les photos au récap ou après.

**Comportement :**
- **La grille** : vignettes carrées. Un appui ouvre la visionneuse plein écran, où l'on glisse entre les photos de la séance. La visionneuse propose :
  - « Partager » (feuille de partage du système, l'image seule) ;
  - « Supprimer » (avec confirmation).
- **Limite de 6** : la case « Ajouter » disparaît à 6. L'import multiple est plafonné aux places restantes.
- **Photothèque** : l'import passe par le sélecteur du système, qui ne demande aucune autorisation. L'original reste dans Photos : Pulse en garde une copie réduite.
- **Appareil photo** : la photo prise n'est pas enregistrée dans Photos.
- **Autorisation refusée** : une ligne explique comment l'activer dans Réglages, et l'import reste possible.

### 4.2 Photos de corps

**Point d'entrée** : dans Profil, une ligne « Photos de corps » avec une icône de cadenas, à côté de la ligne Poids. L'écran Poids ne change pas.

**Le verrou :**
- À l'ouverture, Face ID (ou le code de l'iPhone) est demandé quand le verrou est actif, ce qui est le réglage par défaut. En cas d'échec ou d'annulation, l'écran reste masqué et propose « Déverrouiller ».
- Le déverrouillage vaut tant qu'on reste dans la section. Il se perd dès que l'app passe en arrière-plan ou que l'on quitte la section.
- Dès que l'app n'est plus active (sélecteur d'apps, centre de contrôle, appel), un cache plein écran couvre la section. L'aperçu du sélecteur d'apps ne montre donc jamais une photo.

**L'écran principal :**
```
┌─────────────────────────────┐
│ ‹  Photos de corps     [+]  │
│ 🔒 Sur cet iPhone seulement │
│ Ni iCloud, ni sauvegarde.   │
│ Exporte-les avant de        │
│ changer de téléphone.       │
│                             │
│ 28 octobre        3 photos  │
│ [face] [profil] [dos]       │
│ 30 septembre      2 photos  │
│ [face] [  —   ] [dos]       │
│ 1er août          3 photos  │
│ [face] [profil] [dos]       │
│                             │
│ [ Comparer avant / après ]  │
└─────────────────────────────┘
```
- **La liste** : une rangée par jour de prise, la plus récente en haut, avec trois cases (face, profil, dos). Une case vide sert à compléter ce jour.
- **Ajouter** : on choisit la pose, puis « Prendre une photo » ou « Choisir dans Photos ».
  - Une photo importée prend la date de prise de vue de ses métadonnées si elle en a une, sinon aujourd'hui. La date reste modifiable avant d'enregistrer.
  - Un conseil d'une ligne : « Même lumière, même tenue, même distance. »
- **Une seule photo par pose et par jour.** En ajouter une autre propose de remplacer la première, avec confirmation.
- **La visionneuse** : plein écran, avec seulement « Supprimer » (confirmation). Elle n'a ni partage, ni copie, ni menu contextuel, ni glisser-déposer.
- **L'en-tête** : il affiche la phrase « Sur cet iPhone seulement… » et la date de la dernière prise (« Dernière prise il y a 4 semaines »). Si l'iPhone n'a pas de code, une ligne de plus le dit : « Sans code sur cet iPhone, ces photos ne sont ni chiffrées ni verrouillables. »

**Comparer :**
- On choisit d'abord une pose : Face, Profil ou Dos, seulement celles qui ont au moins deux dates.
- Par défaut, la comparaison oppose la plus ancienne et la plus récente photo de cette pose. « Changer les dates » propose les dates qui ont une photo de cette pose.
- La scène superpose les deux photos avec un trait vertical que l'on fait glisser. Des étiquettes donnent les dates, et une ligne l'écart : « 13 semaines d'écart ».
- Sous la scène, une seule tuile : la variation de la tendance du poids entre les deux dates (« Poids, tendance −1,4 kg »), calculée par la même fonction que l'écran Poids. Sans assez de pesées, la tuile est absente. La phrase « Les variations sont affichées sans jugement » reprend la maquette.
- Les tuiles mensurations et 1RM de la maquette sont hors périmètre.

**Réglages** (en bas de l'écran Photos de corps, accessibles seulement une fois déverrouillé) :
- **« Verrouiller avec Face ID »**, actif par défaut. Le désactiver demande une authentification.
- Si l'iPhone n'a pas de code, le verrou est impossible : l'interrupteur est grisé et une ligne l'explique.
- **« Exporter les photos de corps »** : authentification, puis une archive enregistrée dans Fichiers via le sélecteur d'emplacement du système, pas la feuille de partage (§6.3).
- **« Supprimer toutes les photos de corps »**, avec confirmation.

### 4.3 Mes données
- **L'export CSV** (l'archive zip existante, `exportCSVArchive`) inclut les photos de séance dans un dossier `photos/`. L'export JSON reste un fichier unique : il liste les photos (identifiant, séance, ordre, dates) sans les images, et une ligne sous le bouton renvoie à l'export CSV pour les images **(choix du constructeur)**. Aucun des deux n'inclut **jamais** les photos de corps, et une ligne le dit.
- **L'effacement total** supprime aussi les photos de séance (iCloud compris) et le dossier des photos de corps. Le texte de confirmation le mentionne.

## 5. Règles métier

### 5.1 Photos de séance
- **Séances concernées** : toutes celles du magasin synchronisé, en musculation et en course : produites par Pulse (`.pulse`) ou importées de Hevy (`.hevy`), dont l'identifiant est stable. Les courses et vélos importés d'Apple Santé (`.appleHealth`) n'en ont pas. Leur identifiant change après une réinstallation (M8 §5) : la photo se retrouverait orpheline, et elle s'attacherait à une donnée qui ne vit que sur l'appareil.
- **Ordre** : les photos d'une séance s'affichent dans leur ordre d'ajout. L'ordre est gardé, sans réordonnancement manuel.
- **Pendant la séance live** : une photo ajoutée est écrite tout de suite et survit à un plantage, comme la séance. Si la séance est abandonnée sans enregistrement, ses photos sont supprimées. La séance live n'est qu'un instantané local jusqu'à la fin, mais la séance enregistrée garde le même identifiant : les photos se rangent par cet identifiant dès le début. Une photo dont la séance n'existe pas (encore) n'apparaît nulle part ailleurs que dans la séance live.
- **Suppression** : elle suit le modèle de `StoredRunTrack.markDeleted`. La suppression reste logique (règle V1), mais elle **vide l'image et la vignette** : aucune image ne reste dans iCloud. Quand une séance est supprimée, ses photos le sont de la même façon. La cascade se fait dans `SwiftDataWorkoutRepository.delete(id:)`, point de passage commun des suppressions (détail de séance, `RunSessionService.deleteRun`, `HevyImporter.removeImportedSessions`), à côté de `markRunTracksDeleted`.
- **Taille** :
  - l'image est réduite à 2 048 px sur le grand côté et réencodée en JPEG, pour viser environ 600 Ko ;
  - une vignette d'environ 400 px est produite en même temps ;
  - le réglage exact de compression est laissé au constructeur, sous cette cible.

### 5.2 Photos de corps
- **Poses** : face, profil, dos. Au plus une photo par pose et par jour local.
- **iPhone sans code** : la fonction reste disponible **(choix du constructeur)**. La protection de fichier ne chiffre rien sans code, et le verrou est impossible : l'écran et la politique le disent (« chiffrées dès qu'un code protège l'iPhone »), sans promettre plus.
- **Taille** : même traitement que §5.1 (2 048 px, JPEG, vignette).
- **Comparaison** : seulement entre deux dates différentes d'une même pose. La variation du poids est la différence de la tendance aux deux dates, ou rien si l'une des deux manque.

### 5.3 Traitement commun des images
Une fonction pure, testée, transforme les données reçues (appareil photo ou photothèque) en image finale :
- elle applique l'orientation EXIF aux pixels ;
- elle réduit l'image ;
- elle réencode **sans aucune métadonnée** : ni GPS, ni appareil, ni date EXIF.

Avant ce nettoyage, elle lit la date de prise de vue d'origine pour la proposer (§4.2). Elle s'appuie sur ImageIO, qui existe aussi sur macOS : les tests tournent avec `swift test`. Un test vérifie qu'une image de fixture avec position GPS en ressort sans aucune métadonnée de position.

## 6. Données, stockage et confidentialité

### 6.1 Où vit quoi

| Donnée | Où | Pourquoi |
| :--- | :--- | :--- |
| Photo de séance : image, vignette, identifiant de séance, ordre, dates | iCloud privé, nouveau modèle synchronisé `StoredSessionPhoto` (V6). Image et vignette en `externalStorage`, donc des pièces jointes CloudKit | Contenu créé par l'utilisateur, restauré avec la séance. Ce n'est pas une donnée lue dans Apple Santé : la règle M8 l'autorise. |
| Photo de corps : image et vignette | Fichiers dans un dossier dédié de l'app : protection `complete`, exclu des sauvegardes, hors de tout magasin SwiftData | La donnée la plus sensible de l'app. Elle reste sur l'iPhone, illisible quand il est verrouillé. |
| Index des photos de corps : identifiant, pose, date de prise, date d'ajout, noms des fichiers | Un fichier index (JSON) dans ce même dossier, avec la même protection | Même la liste des dates reste hors d'iCloud et des sauvegardes. Tout tient dans un seul dossier : facile à exclure, exporter, effacer. |
| Réglage « Verrouiller avec Face ID » | Préférences locales (`UserDefaults`, déjà déclaré `CA92.1`) | Réglage de l'appareil, pas une donnée. |

Un choix à noter : les photos de corps ne passent pas par SwiftData. Le magasin `local.store` est inclus dans les sauvegardes (décision M8). SwiftData range ses fichiers `externalStorage` à côté du magasin, sans qu'on puisse choisir leur protection ni les exclure de la sauvegarde un par un. D'où un dossier dédié, géré par un petit dépôt de fichiers (un acteur) derrière un protocole du domaine, que les tests remplacent par une doublure.

### 6.2 Schéma V6
- `PulseSchemaV6` ajoute `StoredSessionPhoto` aux modèles synchronisés. Aucun modèle existant ne change : migration légère V5 → V6.
- Avant d'ajouter V6, `PulseSchemaV5` doit figer sa propre liste de modèles. Aujourd'hui, comme V1 à V4 avant M8, elle lit `PersistenceStack.syncedModels + localModels`, c'est-à-dire la liste courante.
- Les champs sont tous optionnels ou ont une valeur par défaut, et aucun n'est unique, comme l'exige CloudKit. Le lien à la séance passe par un identifiant de séance, pas par une relation, comme `StoredRunTrack`.
- Requis : un test de migration V5 → V6 et le test d'empreinte mis à jour.
- Le schéma CloudKit V6 doit être déployé en production avant TestFlight. C'est laissé à Mathéo, après V5.

### 6.3 Autorisations et Info.plist
- **`NSCameraUsageDescription`** : « Pulse utilise l'appareil photo quand vous ajoutez une photo à une séance ou une photo de corps. Les photos prises ne sont pas enregistrées dans Photos. » Les textes d'autorisation vouvoient, comme ceux de l'Info.plist existant ; l'app tutoie.
- **`NSFaceIDUsageDescription`** : « Pulse utilise Face ID pour protéger vos photos de corps. »
- **`NSPhotoLibraryAddUsageDescription`** : la feuille de partage propose « Enregistrer l'image », et iOS exige ce texte. Il précise : « seulement l'image de séance que vous choisissez d'enregistrer ». Les photos de corps n'ont pas de feuille de partage, et leur export passe par le sélecteur de fichiers, sans « Enregistrer l'image ».
- **Pas de `NSPhotoLibraryUsageDescription`** : le sélecteur de photos du système ne donne à l'app que ce que l'utilisateur choisit.
- Les trois clés vont dans `Pulse/Info.plist`, le seul qui porte des textes d'autorisation (`PulseWidgets/Info.plist` n'en a aucun).
- **Ne jamais ajouter le mode d'arrière-plan `workout-processing`** : App Store Connect le refuse.

### 6.4 Arrière-plan et protection complète
Les fichiers des photos de corps sont illisibles quand l'iPhone est verrouillé. Aucun code qui peut tourner en arrière-plan ne doit les toucher : livraison Santé, course en poche, passage du jour, widgets. L'export, l'effacement et le nettoyage se font seulement au premier plan, depuis une action de l'utilisateur. Un échec de lecture parce que l'iPhone est verrouillé n'est pas une erreur à montrer, l'écran reste simplement masqué.

### 6.5 Textes publics
- **Politique de confidentialité** (`docs/confidentialite/index.html`) :
  - les photos de séance sont dans l'iCloud privé de l'utilisateur et dans l'export ;
  - les photos de corps ne quittent jamais l'iPhone (ni iCloud, ni sauvegarde, ni export général), sont chiffrées dès qu'un code protège l'iPhone, et l'utilisateur peut les exporter lui-même ;
  - Pulse n'enregistre rien dans Photos sans action de l'utilisateur ;
  - les métadonnées de position sont retirées ;
  - aucune image n'est envoyée au développeur ni à un tiers ;
  - la date de mise à jour change.
- **Fiche** (`docs/app-store/fiche.md`) :
  - la description mentionne les photos de progression privées ;
  - les notes de revue expliquent l'appareil photo, Face ID et l'absence de compte ;
  - le libellé « Données non collectées » reste vrai.
- **Manifeste de confidentialité** : aucune nouvelle API à raison déclarée n'est attendue. L'index sert justement à éviter de lire les dates des fichiers (raison `C617.1`). Le constructeur vérifie et déclare ce qu'il trouve.

## 7. Architecture

Elle suit la découpe existante : domaine pur, services, persistance, features.
- **PulseDomain** :
  - les types `SessionPhoto` et `BodyPhoto` (avec `BodyPose`) ;
  - le protocole `SessionPhotoRepository` ;
  - le protocole `BodyPhotoStore` (lire l'index, ajouter, remplacer, supprimer, tout supprimer, exporter vers un dossier) ;
  - le protocole `DeviceOwnerAuthenticating` (Face ID ou code).
- **PulseServices** (ou un petit module pur) : le traitement d'image (§5.3), la limite de 6, la règle « une pose par jour », le choix des dates de comparaison, la variation du poids entre deux dates (réutiliser la tendance existante) et les textes.
- **PulsePersistence** :
  - `StoredSessionPhoto` et le schéma V6 ;
  - le dépôt SwiftData des photos de séance ;
  - la suppression (logique, image vidée) en cascade avec la séance ;
  - l'export zip (dossier `photos/`) et l'effacement ;
  - le dépôt de fichiers des photos de corps, qui gère protection, exclusion de sauvegarde, index écrit de façon atomique et nettoyage des fichiers orphelins.
  - Le constructeur peut aussi le placer ailleurs si une meilleure place existe, tant qu'il reste derrière le protocole du domaine.
- **PulseDesignSystem** : la grille de vignettes, la visionneuse, la scène de comparaison et le cache de confidentialité, à partir des briques existantes.
- **Features** :
  - les sections Photos dans le récap de musculation (LiveSessionFeature), le récap de course (RunFeature), le détail des séances passées (`SessionDetailView`, TrainFeature) et le détail d'activité des courses Pulse (PlanningFeature) ;
  - le bouton de la séance live ;
  - l'écran Photos de corps, la comparaison et les réglages (ProfileFeature, ou une nouvelle cible si elle s'alourdit).
- **App** :
  - l'appareil photo du système (enveloppe de `UIImagePickerController`, ou équivalent iOS 26) ;
  - le sélecteur de photos (`PhotosPicker`) ;
  - LocalAuthentication ;
  - le branchement de l'environnement et les clés d'Info.plist.

**Accessibilité (règles M8b) :**
- Chaque vignette a une étiquette parlée construite par une fonction testée : « Photo 2 sur 4, ajoutée à 18 h 42 » ou « Photo de face, 1er août 2026 ».
- Une case vide se lit « Ajouter une photo de profil ».
- Le curseur de comparaison est un élément ajustable (« Avant, 1er août · Après, 28 octobre », valeur en pourcentage).
- Un bouton « Côte à côte » montre les deux photos sans superposition. C'est l'affichage par défaut avec VoiceOver ou aux tailles d'accessibilité, en colonne aux très grandes tailles.
- Les annonces VoiceOver couvrent « Photo ajoutée », « Photo supprimée » et « Photos de corps déverrouillées ».
- Les vignettes ont des cibles de 44 points ou plus, et chaque écran a un aperçu en `accessibility3`.

## 8. Contraintes et barre de qualité
- Mêmes exigences que V1, M8 et V2a :
  - `swift test --package-path Packages/<Nom>` vert sur tous les packages ;
  - `make lint` à 0 ;
  - `make build-app` et `make build-release` verts.
- Aucune dépendance nouvelle.
- Le simulateur n'est jamais lancé par l'agent. Les tests d'interface sont écrits mais lancés par Mathéo.
- **Tests requis :**
  - le traitement d'image (orientation, réduction, métadonnées retirées, date d'origine lue) ;
  - la limite de 6 ;
  - une pose par jour et le remplacement ;
  - le choix des dates de comparaison et la variation du poids ;
  - le dépôt de photos de séance (ajout, ordre, suppression qui vide l'image, cascade avec la séance par chacun des trois chemins de suppression) ;
  - le dépôt de fichiers des photos de corps sur un dossier temporaire : index, remplacement, suppression, tout supprimer, export, orphelins, et l'attribut d'exclusion de sauvegarde posé sur le dossier ;
  - l'export général, qui contient les photos de séance et aucune photo de corps ;
  - l'effacement, qui retire les deux ;
  - la migration V5 → V6 ;
  - les libellés parlés.
- **Test de frontière :**
  - ni l'export CSV ni l'export JSON ne contiennent de fichier ou de donnée issus du dossier des photos de corps ;
  - aucun modèle SwiftData ne contient de photo de corps.
- La saisie d'une série reste sous 4 secondes : le traitement d'image ne tourne jamais sur l'acteur principal.

## 9. Laissé au constructeur
- Le découpage en lots et en PR. Le plus probable : une PR empilée sur #22, en deux lots. Le lot 1 couvre traitement d'image, V6 et photos de séance. Le lot 2 couvre photos de corps, verrou, comparaison, textes publics.
- L'API exacte de l'appareil photo sur iOS 26 et le format de l'index.
- Le réglage de compression, sous la cible de §5.1.
- La présentation fine des écrans, dans le style argentique et la maquette.
- Les noms exacts des types et des fichiers.

## 10. Laissé à Mathéo (sur l'iPhone)
- **Déploiement** : le schéma CloudKit V6 en production avant TestFlight, après V5.
- **Photos de séance** :
  - en ajouter pendant une séance live sans gêner la saisie ;
  - en ajouter au récap de course ;
  - les retrouver après une réinstallation ;
  - en partager une et l'enregistrer dans Photos, avec la demande d'autorisation.
- **Photos de corps** :
  - Face ID à l'ouverture, et le cache dans le sélecteur d'apps ;
  - l'export vers Fichiers ;
  - après une réinstallation, l'écran est vide, ce qui est le comportement attendu et annoncé ;
  - aucune photo dans l'app Photos.
- **Un import depuis Photos d'une image géolocalisée** : l'export de Pulse ne doit plus contenir la position.

## 11. Risques

| Risque | Parade |
| :--- | :--- |
| Perte des photos de corps au changement d'iPhone (choix assumé, §3). | Phrase permanente en tête de l'écran, export dédié. Interrupteur iCloud possible plus tard si Mathéo le demande. |
| Quota iCloud de l'utilisateur rempli par les photos de séance. | Environ 600 Ko par photo, 6 au plus par séance. Par exemple, 3 séances par semaine avec 2 photos font environ 190 Mo par an. |
| `externalStorage` et CloudKit : une photo descend avec ses pièces jointes en un bloc, mais elle peut arriver avant ou après sa séance. | Les photos se cherchent par identifiant de séance : une photo sans séance n'apparaît nulle part, une séance sans ses photos montre une section vide, jamais une erreur. Image et vignette restent sur le même modèle (le schéma CloudKit ne se remodèle pas ensuite). |
| Fichiers protégés lus en arrière-plan, donc erreurs ou plantage. | Règle §6.4, accès seulement depuis les écrans au premier plan. |
| Une clé d'Info.plist oubliée (appareil photo, Face ID, ajout à Photos), ce qui fait planter l'app à la première utilisation. | Aucune vérification n'existe aujourd'hui. Le constructeur en ajoute une qui tourne sans simulateur (par exemple un script appelé par `make lint` qui lit `Pulse/Info.plist`), et la liste de Mathéo teste chaque autorisation. |
| Revue App Store : texte d'autorisation jugé vague (guideline 5.1.1). | Des textes précis (§6.3) et des notes de revue qui disent où l'appareil photo sert. |
