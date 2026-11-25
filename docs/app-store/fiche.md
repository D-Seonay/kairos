# Pulse — fiche App Store Connect

Document à recopier dans App Store Connect. Version de l'app : 1.0.3 (le numéro de build est attribué à l'envoi ; 1.0.3 (3) soumise le 24 novembre 2026). Dernière relecture contre le code : 24 novembre 2026, branche `v2b-photos` (photos de séance et photos de corps).

Si le code change (nouveau service, nouvelle donnée envoyée hors de l'iPhone, nouvelle analytics), reprends ce document et la politique de confidentialité avant de soumettre : chaque phrase doit rester vraie pour le build envoyé.

## 1. Confidentialité de l'app

**Réponse à donner : « Données non collectées »** (Data Not Collected).

Justification, en deux phrases : Pulse n'a aucun serveur et n'envoie aucune donnée à son développeur ni à un tiers, aucun SDK d'analyse ou de publicité n'est embarqué. Pulse n'écrit jamais dans iCloud les valeurs lues dans Apple Santé : elles restent dans un magasin local de l'iPhone, et ce que l'utilisateur saisit ou ce que Pulse calcule ne se synchronise que dans le CloudKit privé de l'utilisateur, que le développeur ne peut pas lire.

La position sert seulement pour une course que l'utilisateur lance : sur l'écran de départ, app ouverte, pour vérifier le signal GPS avant de partir, puis pendant la course. La distance et le tracé simplifié restent sur l'iPhone, dans son iCloud privé et dans Apple Santé. Ils ne sont envoyés ni au développeur ni à un tiers : la réponse « Données non collectées » reste vraie.

Les photos de séance sont du contenu créé par l'utilisateur : elles se synchronisent dans son iCloud privé avec la séance et font partie de son export CSV. Les photos de corps ne quittent jamais l'iPhone : ni iCloud, ni sauvegarde, ni export général ; seul l'utilisateur peut les exporter, vers Fichiers. Aucune image n'est envoyée au développeur ni à un tiers, et les métadonnées (dont la position) sont retirées de chaque image : la réponse « Données non collectées » reste vraie.

Les rapports de plantage et de lenteur de MetricKit restent sur l'iPhone, hors sauvegarde, dans l'écran Diagnostic du profil. Pulse ne les envoie jamais : l'utilisateur peut en partager un lui-même, par la feuille de partage (un mail à l'assistance, par exemple). Cet envoi facultatif, ponctuel et fait par l'utilisateur entre dans les cas de divulgation facultative d'Apple : la réponse « Données non collectées » reste vraie.

À coller si le champ « Notes » existe : *Pulse has no server and no analytics SDK. Pulse never writes Apple Health values to iCloud: they stay in an on-device store that is never synced. User-entered data and scores computed by Pulse sync only to the user's own private iCloud (CloudKit private database), which the developer cannot access. Location is used only for a run the user starts: on the run's start screen, in the foreground, to check the GPS signal before the run, then during the run. The run's distance and simplified route stay on the iPhone, in the user's private iCloud and in Apple Health, and are never sent to the developer or a third party. Profile values proposed from Apple Health during onboarding (sex, birth date, height, weight) are saved only once the user validates them in the profile form, as user-entered data. Session photos sync only to the user's private iCloud with their workout and are part of the user's own CSV export. Body photos never leave the iPhone (no iCloud, no device backup, not in the app's general export); only the user can export them, to the Files app. No image is ever sent to the developer or a third party, and metadata such as location is removed from every image.*

Cohérence avec le build :
- `Pulse/PrivacyInfo.xcprivacy` et celui de l'extension widgets : `NSPrivacyTracking` faux, aucun domaine de suivi, `NSPrivacyCollectedDataTypes` vide, API `UserDefaults` avec la seule raison `CA92.1` : le code livré n'utilise que `UserDefaults.standard` (les suites nommées ne servent qu'aux tests d'interface en debug, hors groupe d'apps), et les widgets lisent un fichier du groupe d'apps, pas des préférences partagées. Pas de `1C8F.1`.
- `PrivacyInfo.xcprivacy` relu pour la course GPS : la localisation, la voix et la séance d'entraînement ne sont pas des API à raison déclarée. Rien à ajouter.
- `PrivacyInfo.xcprivacy` relu pour les photos : l'appareil photo, le sélecteur de photos, Face ID et la protection des fichiers ne sont pas des API à raison déclarée. Les photos de corps ne lisent jamais la date des fichiers (l'index JSON garde les dates), donc pas de `C617.1`. Rien à ajouter.
- `PrivacyInfo.xcprivacy` relu pour les rapports MetricKit : `MXMetricManager` n'est pas une API à raison déclarée, et la date de réception d'un rapport est lue dans le nom de son fichier, pas dans ses attributs. Aucune donnée collectée : rien à ajouter.
- `Pulse/Info.plist` : `NSCameraUsageDescription`, `NSFaceIDUsageDescription` et `NSPhotoLibraryAddUsageDescription` (enregistrer une photo de séance dans Photos, sur demande seulement). Pas de `NSPhotoLibraryUsageDescription` : le sélecteur de photos d'iOS ne donne à l'app que les images choisies. `make lint` vérifie ces clés et l'absence du mode `workout-processing` (`scripts/check-info-plist.sh`).
- Pas d'e-mail ni de compte : « Connexion requise » reste décoché.
- **URL de la politique de confidentialité** : `https://d-seonay.github.io/kairos/confidentialite/`

## 2. Classification (questionnaire de classification par âge)

Les intitulés d'Apple changent d'une année à l'autre : si un intitulé ne correspond pas, retiens l'intention. À contrôler sur le formulaire affiché.

| Thème | Réponse |
| :--- | :--- |
| Contrôles dans l'app (contrôle parental, vérification de l'âge) | Aucun |
| Accès illimité au web | Non |
| Contenu généré par les utilisateurs, messagerie, discussion | Non |
| Publicité | Non |
| Achats intégrés, loot boxes, jeux d'argent | Non (aucun StoreKit dans l'app) |
| Violence, contenu sexuel, nudité, horreur, alcool, tabac, drogues | Aucun |
| Humour cru, thèmes matures, simulation de jeux d'argent | Aucun |
| Informations médicales ou de traitement | Non : Pulse ne diagnostique rien et n'est pas un dispositif médical |
| Santé et bien-être (sujets) | Oui, à titre de suivi de forme physique : entraînement, récupération, compléments sans dose conseillée |

Apple en déduit la tranche d'âge : accepte celle qu'il calcule (ne la force pas à la baisse). L'app n'est pas un dispositif médical, ne se présente pas comme tel et le dit à l'onboarding et dans Paramètres.

Autres cases :
- Cible : iPhone.
- Tarif et disponibilité : à décider par Mathéo.
- Statut d'opérateur au titre du règlement européen sur les services numériques (DSA) : à déclarer dans App Store Connect avant de proposer l'app dans l'Union européenne. Les coordonnées d'un opérateur sont affichées publiquement sur la fiche : choisis ce que tu acceptes d'y montrer.

## 3. Chiffrement

**Exempt.** `ITSAppUsesNonExemptEncryption` vaut `false` dans `Pulse/Info.plist` : Pulse n'utilise que le chiffrement fourni par le système (HTTPS d'iOS, CloudKit). À la question d'App Store Connect sur le chiffrement, la réponse découle de cette clé et aucun document de conformité n'est à fournir.

## 4. Notes pour la revue

À coller dans « Notes » de la section Informations de revue. Laisser « Connexion requise » décoché : il n'y a pas de compte.

### English (pasted in App Review notes)

```
Pulse is a French-language fitness and recovery app. There is no account, no sign-in and no server.

HOW THE APP USES HEALTH DATA
Pulse reads from Apple Health: sleep, heart rate variability (SDNN), resting heart rate, heart rate, running and cycling workouts, body mass, body fat percentage, and (once, at onboarding, to prefill the profile form) height, date of birth and biological sex. It writes to Apple Health: strength training workouts (with estimated active energy), runs recorded with Pulse (GPS distance and route) and supplement intakes (vitamin D, magnesium, caffeine, protein). Every permission is optional and can be refused separately.

LOCATION AND BACKGROUND MODES
Location ("While Using the App") is used only for a run the user starts from Pulse: on the run's start screen, in the foreground, to check the GPS signal before the run, then during the run to measure distance and draw the route. The "location" background mode keeps that run tracking while the screen is locked, from the start to the end of that run only; Pulse never tracks location outside a run's start screen and the run itself. The "audio" background mode is used only for the spoken kilometre announcements during a run. If location is denied, the run records time only.

CAMERA, PHOTOS AND FACE ID
The camera is used only when the user takes a photo for a workout or a body progress photo; photos taken in Pulse are not saved to the Photos library. Importing goes through the system photo picker, so Pulse only receives the images the user picks (no NSPhotoLibraryUsageDescription). Pulse saves a workout photo to Photos only when the user chooses "Save Image" in the share sheet (NSPhotoLibraryAddUsageDescription). Body photos have no share sheet. Face ID (or the passcode) locks the body photo section; the lock can be turned off in that section's settings. On a device without a passcode, the section opens without a lock and says the photos are not encrypted. Metadata, including location, is removed from every image.

PRIVACY (guideline 5.1.3)
Values read from Apple Health are stored in an on-device store that is never synced: Pulse never writes them to iCloud. Like all of the app's local data, they are part of the iPhone's own backup if the user has turned it on (iCloud or computer backup), and of the exports the user makes. Values proposed from Apple Health at onboarding (height, weight, date of birth, sex) are saved, and synced, only once the user validates the profile step; they then count as user input. iCloud (the user's private CloudKit database) only holds what the user types and what Pulse computes (workouts logged in Pulse, runs recorded with Pulse and their simplified route, supplements, program, check-ins, recovery scores). Heart rate delivered by the run's workout session counts as read from Apple Health and stays on the device. Workout photos are user content: they sync to the user's private iCloud with the workout and are included in the CSV export. Body photos stay on the iPhone only, in a file-protected folder excluded from device backups and from the general export; the user can export them to the Files app. No image is sent to the developer or any third party. No analytics, no advertising, no third-party SDK. The privacy policy is at https://d-seonay.github.io/kairos/confidentialite/ and support is at https://d-seonay.github.io/kairos/support/. Export and full erase are in Profile > Mes données (My data).

THE REVIEW DEVICE HAS NO HEALTH DATA, WHICH IS EXPECTED
The recovery score needs several nights of sleep, HRV and resting heart rate data from an Apple Watch or compatible device. On a device without them, Today shows a calibration or check-in state (three questions) instead of a measured score. This is normal behaviour, not an error. The measured score appears after a few nights of real data.

HOW TO SEE THE MAIN FEATURES WITHOUT HEALTH DATA
1. First launch: on the Health screen, tap "Continuer sans montre" (Continue without a watch), or "Autoriser dans Apple Santé" (Allow in Apple Health) and allow or deny as you wish. Then fill in the short profile and goals screens.
2. Live workout: open the "Séance" tab, tap "Séance libre" (Free session), then add an exercise and log sets. The rest timer and the recap work without any Health data. Writing the finished workout to Apple Health is optional.
3. Supplements: Profile tab > "Compléments" (Supplements) > "+" / "Ajouter un complément" (Add a supplement), then mark it as taken ("Pris"). Pulse never suggests a dose.
4. Run: "Séance" tab > "Courir" (Run), allow location, then "Partir" (Go). Distance needs a GPS signal outdoors; "Pause" and "Terminer" (Finish) are on the run screen; the Live Activity has "Pause" and "Reprendre" (Resume).
5. Photos: during a live workout, the camera button in the header adds a photo; the recap and the workout detail have a "Photos" section. Body photos: Profile tab > "Photos de corps" (Body photos), unlock with Face ID or the passcode, then "Ajouter une photo" (Add a photo).
6. Export and delete: Profile tab > "Mes données" (My data).

MEDICAL DISCLAIMER
Pulse is not a medical device. The score and adjustments are training indicators, not medical advice. The notice appears at onboarding and in Settings.

The interface is in French only (version 1).
```

### Français (même contenu, pour mémoire)

```
Pulse est une app de forme et de récupération en français. Il n'y a ni compte, ni connexion, ni serveur.

USAGE DES DONNÉES DE SANTÉ
Pulse lit dans Apple Santé : le sommeil, la variabilité cardiaque (SDNN), la fréquence cardiaque au repos, la fréquence cardiaque, les entraînements de course et de vélo, le poids, la masse grasse, et (une seule fois, à l'accueil, pour préremplir le profil) la taille, la date de naissance et le sexe. Pulse écrit dans Apple Santé : les séances de musculation (avec l'énergie active estimée), les courses faites avec Pulse (distance GPS et tracé) et les prises de compléments (vitamine D, magnésium, caféine, protéines). Chaque autorisation est facultative et se refuse séparément.

LOCALISATION ET MODES D'ARRIÈRE-PLAN
La localisation (« Lorsque l'app est active ») sert seulement pour une course que l'utilisateur lance depuis Pulse : sur l'écran de départ, app ouverte, pour vérifier le signal GPS avant de partir, puis pendant la course pour mesurer la distance et tracer le parcours. Le mode d'arrière-plan « location » garde ce suivi écran verrouillé, du départ à la fin de cette course seulement : Pulse ne suit jamais la position hors de l'écran de départ et de la course. Le mode « audio » sert seulement aux annonces vocales de chaque kilomètre pendant la course. Localisation refusée, la course enregistre seulement le temps.

APPAREIL PHOTO, PHOTOS ET FACE ID
L'appareil photo sert seulement quand l'utilisateur prend une photo de séance ou une photo de corps ; les photos prises dans Pulse ne sont pas enregistrées dans Photos. L'import passe par le sélecteur de photos du système : Pulse ne reçoit que les images choisies (pas de NSPhotoLibraryUsageDescription). Pulse enregistre une photo de séance dans Photos seulement quand l'utilisateur choisit « Enregistrer l'image » dans la feuille de partage (NSPhotoLibraryAddUsageDescription). Les photos de corps n'ont pas de feuille de partage. Face ID (ou le code) verrouille la section des photos de corps ; le verrou se coupe dans les réglages de la section. Sur un appareil sans code, la section s'ouvre sans verrou et dit que les photos ne sont pas chiffrées. Les métadonnées, dont la position, sont retirées de chaque image.

CONFIDENTIALITÉ (règle 5.1.3)
Les valeurs lues dans Apple Santé sont gardées dans un magasin de l'appareil qui ne se synchronise jamais : Pulse ne les écrit jamais dans iCloud. Comme toutes les données locales de l'app, elles font partie de la sauvegarde de l'iPhone si l'utilisateur l'a activée (iCloud ou ordinateur), et des exports qu'il fait lui-même. Les valeurs proposées depuis Apple Santé à l'accueil (taille, poids, date de naissance, sexe) ne sont enregistrées, et synchronisées, qu'une fois l'étape du profil validée ; elles comptent alors comme une saisie. iCloud (la base CloudKit privée de l'utilisateur) ne contient que ce que l'utilisateur saisit et ce que Pulse calcule (séances faites dans Pulse, courses faites avec Pulse et leur tracé simplifié, compléments, programme, check-ins, scores de récupération). La fréquence cardiaque livrée par la séance d'entraînement de la course compte comme lue dans Apple Santé et reste sur l'appareil. Les photos de séance sont du contenu de l'utilisateur : elles se synchronisent dans son iCloud privé avec la séance et font partie de l'export CSV. Les photos de corps restent sur l'iPhone seulement, dans un dossier protégé, exclu des sauvegardes de l'appareil et de l'export général ; l'utilisateur peut les exporter vers Fichiers. Aucune image n'est envoyée au développeur ni à un tiers. Aucune analytics, aucune publicité, aucun SDK tiers. Politique : https://d-seonay.github.io/kairos/confidentialite/ ; assistance : https://d-seonay.github.io/kairos/support/. L'export et la suppression totale sont dans Profil > Mes données.

L'APPAREIL DE REVUE N'A PAS DE DONNÉES DE SANTÉ, C'EST NORMAL
Le score de récupération demande plusieurs nuits de sommeil, de VFC et de fréquence cardiaque au repos venues d'une Apple Watch ou d'une montre compatible. Sans elles, l'écran Aujourd'hui affiche la calibration ou un check-in de trois questions à la place du score mesuré. Ce n'est pas une erreur. Le score mesuré apparaît après quelques nuits de vraies données.

VOIR L'ESSENTIEL SANS DONNÉES DE SANTÉ
1. Premier lancement : sur l'écran Santé, touche « Continuer sans montre », ou « Autoriser dans Apple Santé » et accepte ou refuse. Remplis ensuite le profil et les objectifs.
2. Séance live : onglet « Séance », « Séance libre », ajoute un exercice et saisis des séries. Le chrono de repos et le récap marchent sans données de santé. L'écriture de la séance dans Apple Santé est facultative.
3. Compléments : onglet Profil > « Compléments » > « + » / « Ajouter un complément », puis « Pris ». Pulse ne propose jamais de dose.
4. Course : onglet « Séance » > « Courir », autorise la localisation, puis « Partir ». La distance demande un signal GPS en extérieur ; « Pause » et « Terminer » sont sur l'écran de course ; la Live Activity propose « Pause » et « Reprendre ».
5. Photos : pendant une séance live, le bouton appareil photo de l'en-tête ajoute une photo ; le récap et le détail de la séance ont une section « Photos ». Photos de corps : onglet Profil > « Photos de corps », déverrouille avec Face ID ou le code, puis « Ajouter une photo ».
6. Export et suppression : onglet Profil > « Mes données ».

AVERTISSEMENT MÉDICAL
Pulse n'est pas un dispositif médical. Le score et les ajustements sont des repères d'entraînement, pas un avis médical. L'avertissement figure à l'accueil et dans Paramètres.

L'interface est uniquement en français (version 1).
```

## 5. Fiche

**Langue principale : français.**

### Nom

| Choix | Texte | Caractères (30 max) |
| :--- | :--- | :--- |
| 1 (préféré) | Pulse | 5 |
| 2 | Pulse — Récupération & Muscu | 28 |
| 3 | Pulse Training | 14 |

Si « Pulse » est déjà pris, passe au choix 2 ou 3 ; le nom affiché sous l'icône (`CFBundleDisplayName`) peut rester « Pulse ».

### Sous-titre (30 caractères max)

```
Récupération et musculation
```

27 caractères.

### Texte promotionnel (170 caractères max, modifiable sans nouvelle version)

```
Un score de récupération chaque matin, des séances de muscu guidées et tes compléments au même endroit. Tes données d'Apple Santé restent sur ton iPhone.
```

### Description

```
Pulse t'aide à décider comment t'entraîner aujourd'hui, à partir de ta nuit.

SCORE DE RÉCUPÉRATION
Chaque matin, Pulse lit ton sommeil, ta variabilité cardiaque (VFC) et ta fréquence cardiaque au repos dans Apple Santé, et les compare à ta propre ligne de base. Tu vois un score, ce qui l'explique, et ce qui manque quand une mesure est absente. Pas de montre ? Un check-in de trois questions prend le relais. L'écran Nuit détaille tes phases de sommeil : profond, paradoxal, léger et éveil.

SÉANCES DE MUSCULATION
Un programme adapté à ton niveau, ton matériel et tes douleurs ou limitations, une séance live avec chrono de repos, séries, records et récap. Pulse ajuste la séance du jour selon ta récupération, et n'augmente les charges que lorsque ta ligne de base le permet. Tu peux aussi faire une séance libre, saisir une séance passée ou importer ton historique depuis Hevy.

PLANNING ET STATISTIQUES
Ton planning de la semaine, ta charge d'entraînement sur 28 jours, tes courbes de VFC et de fréquence cardiaque, tes muscles travaillés, ton assiduité et tes records. Tes courses et sorties à vélo d'Apple Santé comptent dans ta charge.

COURSE GPS
Lance ta course du jour depuis Pulse, avec son objectif ajusté à ta récupération : distance, allure et temps par kilomètre, annonces vocales à chaque kilomètre, suivi sur l'écran verrouillé, puis ton tracé et ta course comptée dans ta charge. Ta position ne sert qu'à la course que tu lances, et ton tracé reste sur ton iPhone, dans ton iCloud privé et dans Apple Santé.

PHOTOS DE PROGRESSION PRIVÉES
Ajoute des photos à tes séances et à tes courses : elles restent dans ton iCloud privé, avec la séance. Tes photos de corps (face, profil, dos) ne quittent jamais ton iPhone : ni iCloud, ni sauvegarde. Elles se verrouillent avec Face ID, et tu compares deux dates côte à côte ou en superposition, avec la variation de ton poids.

COMPLÉMENTS
Suis tes prises de vitamine D, de magnésium, de caféine et de protéines, ton stock et ta régularité, avec des rappels. Pulse ne conseille jamais de dose.

WIDGETS
Ton score et ta séance du jour sur l'écran d'accueil et l'écran verrouillé, et ta séance ou ta course en cours en Live Activity.

TES DONNÉES
Pas de compte, pas de serveur, pas de publicité, aucune analytics. Pulse n'écrit jamais dans iCloud les valeurs lues dans Apple Santé : elles restent sur ton iPhone (et dans sa sauvegarde, si tu l'as activée). Ce que tu saisis et ce que Pulse calcule se synchronise dans ton iCloud privé, auquel personne d'autre n'a accès. Tes photos de corps restent seulement sur ton iPhone. Tu exportes tout en JSON ou CSV, ou tu supprimes tout, depuis l'app.

Pulse n'est pas un dispositif médical. Le score et les ajustements sont des repères d'entraînement, pas un avis médical.
```

Points à contrôler avant de coller : chaque fonction citée existe dans le build soumis (widgets, écran verrouillé, Live Activity, import Hevy, rappels de compléments, course GPS, photos de séance et photos de corps).

### Nouveautés de la version 1.0.3

```
Nouveautés de la 1.0.3

• Course GPS : lance ta course depuis Pulse. Temps, distance et allure en direct, une annonce vocale à chaque kilomètre, la course sur l'écran verrouillé en Live Activity, puis un récap avec ton tracé et tes temps au kilomètre. La course part dans Apple Santé avec son parcours et compte dans ta charge.
• Photos : ajoute jusqu'à six photos à une séance. Tes photos de corps (face, profil, dos) restent sur ton iPhone, protégées par Face ID.
• Sommeil : un nouvel écran Nuit montre tes phases (profond, paradoxal, léger, éveil) et ton hypnogramme. Les stats empilent tes nuits par phase.
• Carte des muscles en version homme ou femme.
• De nombreuses corrections et améliorations d'interface.
```

### Mots-clés (100 caractères max, séparés par des virgules, sans espace)

```
VFC,HRV,sommeil,score,entraînement,séance,compléments,charge,programme,muscu,course,vélo,fatigue
```

Les mots déjà présents dans le nom, le sous-titre ou la catégorie (« récupération », « musculation », « forme ») ne sont pas répétés : Apple les indexe déjà.

### Catégories

- Principale : **Forme et santé** (Health & Fitness).
- Secondaire : laisse vide, ou « Style de vie » si tu veux une seconde catégorie.

### URL

| Champ | Valeur |
| :--- | :--- |
| URL d'assistance | `https://d-seonay.github.io/kairos/support/` |
| URL de la politique de confidentialité | `https://d-seonay.github.io/kairos/confidentialite/` |
| URL marketing | facultative, laisse vide |

Contact de la revue : le contact public est la page des issues du dépôt, `https://github.com/D-Seonay/kairos/issues`. App Store Connect demande un nom, un téléphone et un e-mail pour la revue elle-même (non publiés sur la fiche) : ce sont les tiens, ils ne sont pas dans ce dépôt.

## 6. Avant de soumettre

À cocher par Mathéo (spec M8 §10).

- [ ] La branche `m8-confidentialite` est fusionnée dans `master`.
- [ ] GitHub Pages est activé : dépôt, Settings, Pages, source `master`, dossier `/docs`.
- [ ] `https://d-seonay.github.io/kairos/confidentialite/` et `https://d-seonay.github.io/kairos/support/` répondent, sans erreur 404, et le lien « Politique de confidentialité » de Profil, Mes données ouvre bien la première.
- [ ] Un build contenant M8a (manifestes de confidentialité, déplacement des données Apple Santé) est installé sur l'iPhone, et l'historique (scores, courses, pesées) est intact après la mise à jour.
- [ ] Le test de restauration est fait : désinstaller, réinstaller, retrouver séances, compléments, programme et scores depuis iCloud. Les courses et le poids reviennent par une nouvelle lecture d'Apple Santé ; le détail brut des nuits passées ne revient pas (attendu).
- [ ] 14 jours d'usage sans perte de donnée ni plantage.
- [ ] M8b (accessibilité) fusionnée, `AccessibilityAuditUITests` lancé sur l'iPhone et la liste de vérification VoiceOver passée (`docs/app-store/verification-accessibilite.md`, ajouté par M8b).
- [ ] App Store Connect : « Données non collectées » (§1), questionnaire de classification (§2), chiffrement exempt (§3), notes pour la revue (§4), textes et URL de la fiche (§5).
- [ ] Les captures d'écran sont prises (iPhone) et chargées.
- [ ] Statut d'opérateur DSA renseigné si l'app est proposée dans l'Union européenne.
- [ ] Tarif et pays de disponibilité choisis.
- [ ] Un build TestFlight récent est sélectionné pour la soumission, puis soumission à la revue.
- [ ] Si la revue rejette l'app faute de données de santé de test : plan B, un mode démo (hors périmètre de M8).
