# Pulse — fiche App Store Connect

Document à recopier dans App Store Connect. Version de l'app : 1.0.5 (le numéro de build est attribué à l'envoi). Historique : 1.0.3 (3) soumise le 24 novembre 2026, puis 1.0.4 (3) soumise le même soir. Dernière relecture contre le code : 28 novembre 2026, `master` à `98ce71c` (jusqu'à la PR #114).

Si le code change (nouveau service, nouvelle donnée envoyée hors de l'iPhone, nouvelle analytics), reprends ce document et la politique de confidentialité avant de soumettre : chaque phrase doit rester vraie pour le build envoyé.

## 1. Confidentialité de l'app

**Réponse à donner : « Données non collectées »** (Data Not Collected).

Justification, en deux phrases : Pulse n'a aucun serveur et n'envoie aucune donnée à son développeur ni à un tiers, aucun SDK d'analyse ou de publicité n'est embarqué. Pulse n'écrit jamais dans iCloud les valeurs lues dans Apple Santé : elles restent dans un magasin local de l'iPhone, et ce que l'utilisateur saisit ou ce que Pulse calcule ne se synchronise que dans le CloudKit privé de l'utilisateur, que le développeur ne peut pas lire.

La position sert seulement pour une course que l'utilisateur lance : sur l'écran de départ, app ouverte, pour vérifier le signal GPS avant de partir, puis pendant la course. La distance et le tracé simplifié restent sur l'iPhone, dans son iCloud privé et dans Apple Santé. Ils ne sont envoyés ni au développeur ni à un tiers : la réponse « Données non collectées » reste vraie.

Les photos de séance sont du contenu créé par l'utilisateur : elles se synchronisent dans son iCloud privé avec la séance et font partie de son export CSV. Les photos de corps ne quittent jamais l'iPhone : ni iCloud, ni sauvegarde, ni export général ; seul l'utilisateur peut les exporter, vers Fichiers. Aucune image n'est envoyée au développeur ni à un tiers, et les métadonnées (dont la position) sont retirées de chaque image : la réponse « Données non collectées » reste vraie.

L'export GPX d'une course (1.0.5) est un fichier que l'utilisateur crée et partage lui-même par la feuille de partage : il contient la position GPS de la course, Pulse ne l'envoie nulle part et l'efface quand on quitte le détail de la course. Les raccourcis Siri (App Intents) s'exécutent sur l'iPhone, sans serveur de Pulse. La demande de note (`requestReview` de StoreKit) est affichée par iOS ; Pulse n'en reçoit rien. La réponse « Données non collectées » reste vraie.

Les rapports de plantage et de lenteur de MetricKit (livrés par iOS au lancement qui suit le problème) restent sur l'iPhone, hors sauvegarde, sans le texte libre des exceptions (`composedMessage`, `arguments`), dans Profil > Paramètres > À propos > Diagnostic. Pulse ne les envoie jamais : l'utilisateur peut en partager un lui-même, par la feuille de partage (un mail à l'assistance, par exemple). Cet envoi facultatif, ponctuel et fait par l'utilisateur entre dans les cas de divulgation facultative d'Apple : la réponse « Données non collectées » reste vraie.

À coller si le champ « Notes » existe : *Pulse has no server and no analytics SDK. Pulse never writes Apple Health values to iCloud: they stay in an on-device store that is never synced. User-entered data and scores computed by Pulse sync only to the user's own private iCloud (CloudKit private database), which the developer cannot access. Location is used only for a run the user starts: on the run's start screen, in the foreground, to check the GPS signal before the run, then during the run. The run's distance and simplified route stay on the iPhone, in the user's private iCloud and in Apple Health, and are never sent to the developer or a third party. Profile values proposed from Apple Health during onboarding (sex, birth date, height, weight) are saved only once the user validates them in the profile form, as user-entered data. Session photos sync only to the user's private iCloud with their workout and are part of the user's own CSV export. Body photos never leave the iPhone (no iCloud, no device backup, not in the app's general export); only the user can export them, to the Files app. No image is ever sent to the developer or a third party, and metadata such as location is removed from every image.*

Cohérence avec le build :
- `Pulse/PrivacyInfo.xcprivacy` et celui de l'extension widgets : `NSPrivacyTracking` faux, aucun domaine de suivi, `NSPrivacyCollectedDataTypes` vide, API `UserDefaults` avec la seule raison `CA92.1` : le code livré n'utilise que `UserDefaults.standard` (les suites nommées ne servent qu'aux tests d'interface en debug, hors groupe d'apps ; les réglages locaux de la 1.0.5, comme le coucher déduit des nuits, le rappel de photo ou la demande de note, sont aussi dans `UserDefaults.standard`), et les widgets lisent un fichier du groupe d'apps, pas des préférences partagées. Pas de `1C8F.1`.
- `PrivacyInfo.xcprivacy` relu pour la course GPS : la localisation, la voix et la séance d'entraînement ne sont pas des API à raison déclarée. Rien à ajouter.
- `PrivacyInfo.xcprivacy` relu pour les photos : l'appareil photo, le sélecteur de photos, Face ID et la protection des fichiers ne sont pas des API à raison déclarée. L'index JSON garde les dates des photos de corps ; seule sa réparation (index abîmé) lit la date de création des fichiers du conteneur de l'app, d'où `NSPrivacyAccessedAPICategoryFileTimestamp` avec la raison `C617.1`, déclarée dans le manifeste de l'app.
- `PrivacyInfo.xcprivacy` relu pour la 1.0.5 : les raccourcis Siri (App Intents), l'export GPX et `requestReview` ne sont pas des API à raison déclarée, et aucun ne demande de clé dans `Info.plist` (les App Shortcuts n'ont pas besoin de `NSSiriUsageDescription`). Rien à ajouter.
- `PrivacyInfo.xcprivacy` relu pour les rapports MetricKit : `MXMetricManager` n'est pas une API à raison déclarée, et la date de réception d'un rapport est lue dans le nom de son fichier, pas dans ses attributs. Aucune donnée collectée : rien à ajouter.
- `Pulse/Info.plist` : `NSCameraUsageDescription`, `NSFaceIDUsageDescription` et `NSPhotoLibraryAddUsageDescription` (enregistrer une photo de séance dans Photos, sur demande seulement). Pas de `NSPhotoLibraryUsageDescription` : le sélecteur de photos d'iOS ne donne à l'app que les images choisies. `make lint` vérifie ces clés et l'absence du mode `workout-processing` (`scripts/check-info-plist.sh`).
- Pas d'e-mail ni de compte : « Connexion requise » reste décoché.
- **URL de la politique de confidentialité** : `https://pulserecovery.app/confidentialite`

## 2. Classification (questionnaire de classification par âge)

Les intitulés d'Apple changent d'une année à l'autre : si un intitulé ne correspond pas, retiens l'intention. À contrôler sur le formulaire affiché.

| Thème | Réponse |
| :--- | :--- |
| Contrôles dans l'app (contrôle parental, vérification de l'âge) | Aucun |
| Accès illimité au web | Non |
| Contenu généré par les utilisateurs, messagerie, discussion | Non |
| Publicité | Non |
| Achats intégrés, loot boxes, jeux d'argent | Non (StoreKit ne sert qu'à la demande de note, aucun achat) |
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
Location ("While Using the App") is used only for a run the user starts from Pulse: on the run's start screen, in the foreground, to check the GPS signal before the run, then during the run to measure distance and draw the route. The "location" background mode keeps that run tracking while the screen is locked, from the start to the end of that run only; Pulse never tracks location outside a run's start screen and the run itself. The "audio" background mode is used only for the spoken kilometre announcements during a run. If location is denied, the run records time only. A run tracked with Pulse can be exported as a GPX file (route with GPS positions) from its detail screen, through the share sheet, only when the user taps "Exporter en GPX".

CAMERA, PHOTOS AND FACE ID
The camera is used only when the user takes a photo for a workout or a body progress photo; photos taken in Pulse are not saved to the Photos library. Importing goes through the system photo picker, so Pulse only receives the images the user picks (no NSPhotoLibraryUsageDescription). Pulse saves a workout photo to Photos only when the user chooses "Save Image" in the share sheet (NSPhotoLibraryAddUsageDescription). Body photos have no share sheet. Face ID (or the passcode) locks the body photo section; the lock can be turned off in that section's settings. On a device without a passcode, the section opens without a lock and says the photos are not encrypted. Metadata, including location, is removed from every image.

PRIVACY (guideline 5.1.3)
Values read from Apple Health are stored in an on-device store that is never synced: Pulse never writes them to iCloud. Like all of the app's local data, they are part of the iPhone's own backup if the user has turned it on (iCloud or computer backup), and of the exports the user makes. Values proposed from Apple Health at onboarding (height, weight, date of birth, sex) are saved, and synced, only once the user validates the profile step; they then count as user input. iCloud (the user's private CloudKit database) only holds what the user types and what Pulse computes (workouts logged in Pulse, runs recorded with Pulse and their simplified route, supplements, program, check-ins, recovery scores). Heart rate delivered by the run's workout session counts as read from Apple Health and stays on the device. Workout photos are user content: they sync to the user's private iCloud with the workout and are included in the CSV export. Body photos stay on the iPhone only, in a file-protected folder excluded from device backups and from the general export; the user can export them to the Files app. No image is sent to the developer or any third party. No analytics, no advertising, no third-party SDK. The privacy policy is at https://pulserecovery.app/confidentialite and support is at https://pulserecovery.app/support. Export and full erase are in Profile > Mes données (My data).

NOTIFICATIONS, SIRI AND RATINGS
Notifications are optional: end of rest, morning score, supplement reminders, a bedtime reminder (off by default, in Settings > Sommeil) and a body photo reminder (off by default, in the Body photos section; the notification only says it is time for a progress photo, with no image). Siri shortcuts (App Intents) give the recovery score, start today's workout, log a supplement intake ("J'ai pris ma créatine") and start a run; the score and the supplement intake require the device to be unlocked. Pulse asks for an App Store rating at most once per version, after the 5th strength workout or a new record, never during a workout or a run.

THE REVIEW DEVICE HAS NO HEALTH DATA, WHICH IS EXPECTED
The recovery score needs several nights of sleep, HRV and resting heart rate data from an Apple Watch or compatible device. On a device without them, Today shows a calibration or check-in state (three questions) instead of a measured score. This is normal behaviour, not an error. The measured score appears after a few nights of real data.

HOW TO SEE THE MAIN FEATURES WITHOUT HEALTH DATA
1. First launch: on the Health screen, tap "Continuer sans montre" (Continue without a watch), or "Autoriser dans Apple Santé" (Allow in Apple Health) and allow or deny as you wish. Then fill in the short profile and goals screens. Apple Health can be connected later from Profile > Paramètres > "Connecter Apple Santé".
2. Live workout: open the "Séance" tab, tap "Séance libre" (Free session), then add an exercise and log sets. The rest timer and the recap work without any Health data. Writing the finished workout to Apple Health is optional.
3. Supplements: Profile tab > "Compléments" (Supplements) > "+" / "Ajouter un complément" (Add a supplement), then mark it as taken ("Pris"). Pulse never suggests a dose.
4. Run: "Séance" tab > "Courir" (Run), allow location, then "Partir" (Go). Distance needs a GPS signal outdoors; "Pause" and "Terminer" (Finish) are on the run screen; the Live Activity has "Pause" and "Reprendre" (Resume).
5. Photos: during a live workout, the camera button in the header adds a photo; the recap and the workout detail have a "Photos" section. Body photos: Profile tab > "Photos de corps" (Body photos), unlock with Face ID or the passcode, then "Ajouter une photo" (Add a photo).
6. Export and delete: Profile tab > "Mes données" (My data).
7. Siri: Pulse's shortcuts are listed in the Shortcuts app without any setup; say for example "Mon score de récupération Pulse".

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
La localisation (« Lorsque l'app est active ») sert seulement pour une course que l'utilisateur lance depuis Pulse : sur l'écran de départ, app ouverte, pour vérifier le signal GPS avant de partir, puis pendant la course pour mesurer la distance et tracer le parcours. Le mode d'arrière-plan « location » garde ce suivi écran verrouillé, du départ à la fin de cette course seulement : Pulse ne suit jamais la position hors de l'écran de départ et de la course. Le mode « audio » sert seulement aux annonces vocales de chaque kilomètre pendant la course. Localisation refusée, la course enregistre seulement le temps. Une course suivie dans Pulse s'exporte en fichier GPX (tracé avec les positions GPS) depuis son détail, par la feuille de partage, seulement quand l'utilisateur touche « Exporter en GPX ».

APPAREIL PHOTO, PHOTOS ET FACE ID
L'appareil photo sert seulement quand l'utilisateur prend une photo de séance ou une photo de corps ; les photos prises dans Pulse ne sont pas enregistrées dans Photos. L'import passe par le sélecteur de photos du système : Pulse ne reçoit que les images choisies (pas de NSPhotoLibraryUsageDescription). Pulse enregistre une photo de séance dans Photos seulement quand l'utilisateur choisit « Enregistrer l'image » dans la feuille de partage (NSPhotoLibraryAddUsageDescription). Les photos de corps n'ont pas de feuille de partage. Face ID (ou le code) verrouille la section des photos de corps ; le verrou se coupe dans les réglages de la section. Sur un appareil sans code, la section s'ouvre sans verrou et dit que les photos ne sont pas chiffrées. Les métadonnées, dont la position, sont retirées de chaque image.

CONFIDENTIALITÉ (règle 5.1.3)
Les valeurs lues dans Apple Santé sont gardées dans un magasin de l'appareil qui ne se synchronise jamais : Pulse ne les écrit jamais dans iCloud. Comme toutes les données locales de l'app, elles font partie de la sauvegarde de l'iPhone si l'utilisateur l'a activée (iCloud ou ordinateur), et des exports qu'il fait lui-même. Les valeurs proposées depuis Apple Santé à l'accueil (taille, poids, date de naissance, sexe) ne sont enregistrées, et synchronisées, qu'une fois l'étape du profil validée ; elles comptent alors comme une saisie. iCloud (la base CloudKit privée de l'utilisateur) ne contient que ce que l'utilisateur saisit et ce que Pulse calcule (séances faites dans Pulse, courses faites avec Pulse et leur tracé simplifié, compléments, programme, check-ins, scores de récupération). La fréquence cardiaque livrée par la séance d'entraînement de la course compte comme lue dans Apple Santé et reste sur l'appareil. Les photos de séance sont du contenu de l'utilisateur : elles se synchronisent dans son iCloud privé avec la séance et font partie de l'export CSV. Les photos de corps restent sur l'iPhone seulement, dans un dossier protégé, exclu des sauvegardes de l'appareil et de l'export général ; l'utilisateur peut les exporter vers Fichiers. Aucune image n'est envoyée au développeur ni à un tiers. Aucune analytics, aucune publicité, aucun SDK tiers. Politique : https://pulserecovery.app/confidentialite ; assistance : https://pulserecovery.app/support. L'export et la suppression totale sont dans Profil > Mes données.

NOTIFICATIONS, SIRI ET NOTES
Les notifications sont facultatives : fin de repos, score du matin, rappels de compléments, rappel de coucher (désactivé par défaut, dans Paramètres > Sommeil) et rappel de photo de corps (désactivé par défaut, dans la section Photos de corps ; la notification dit seulement que c'est le moment de la photo de suivi, sans image). Les raccourcis Siri (App Intents) donnent le score de récupération, démarrent la séance du jour, notent une prise de complément (« J'ai pris ma créatine ») et lancent une course ; le score et la prise demandent le déverrouillage. Pulse demande une note App Store au plus une fois par version, après la 5e séance de musculation ou un nouveau record, jamais pendant une séance ou une course.

L'APPAREIL DE REVUE N'A PAS DE DONNÉES DE SANTÉ, C'EST NORMAL
Le score de récupération demande plusieurs nuits de sommeil, de VFC et de fréquence cardiaque au repos venues d'une Apple Watch ou d'une montre compatible. Sans elles, l'écran Aujourd'hui affiche la calibration ou un check-in de trois questions à la place du score mesuré. Ce n'est pas une erreur. Le score mesuré apparaît après quelques nuits de vraies données.

VOIR L'ESSENTIEL SANS DONNÉES DE SANTÉ
1. Premier lancement : sur l'écran Santé, touche « Continuer sans montre », ou « Autoriser dans Apple Santé » et accepte ou refuse. Remplis ensuite le profil et les objectifs. Apple Santé se connecte plus tard depuis Profil > Paramètres > « Connecter Apple Santé ».
2. Séance live : onglet « Séance », « Séance libre », ajoute un exercice et saisis des séries. Le chrono de repos et le récap marchent sans données de santé. L'écriture de la séance dans Apple Santé est facultative.
3. Compléments : onglet Profil > « Compléments » > « + » / « Ajouter un complément », puis « Pris ». Pulse ne propose jamais de dose.
4. Course : onglet « Séance » > « Courir », autorise la localisation, puis « Partir ». La distance demande un signal GPS en extérieur ; « Pause » et « Terminer » sont sur l'écran de course ; la Live Activity propose « Pause » et « Reprendre ».
5. Photos : pendant une séance live, le bouton appareil photo de l'en-tête ajoute une photo ; le récap et le détail de la séance ont une section « Photos ». Photos de corps : onglet Profil > « Photos de corps », déverrouille avec Face ID ou le code, puis « Ajouter une photo ».
6. Export et suppression : onglet Profil > « Mes données ».
7. Siri : les raccourcis de Pulse sont listés dans l'app Raccourcis sans réglage ; dis par exemple « Mon score de récupération Pulse ».

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
Nouveau : ton objectif de sommeil et un rappel du coucher. Un score de récupération chaque matin, des séances guidées, et tes données d'Apple Santé sur ton iPhone.
```

### Description

```
Pulse t'aide à décider comment t'entraîner aujourd'hui, à partir de ta nuit.

SCORE DE RÉCUPÉRATION
Chaque matin, Pulse lit ton sommeil, ta variabilité cardiaque (VFC) et ta fréquence cardiaque au repos dans Apple Santé, et les compare à ta propre ligne de base. Tu vois un score, ce qui l'explique, et ce qui manque quand une mesure est absente. Pas de montre ? Un check-in de trois questions prend le relais. L'écran Nuit détaille tes phases de sommeil (profond, paradoxal, léger et éveil), l'écart à ton objectif de sommeil et la régularité de ton coucher.

OBJECTIF DE SOMMEIL
Choisis ton objectif (de 6 h à 10 h) et ton heure de réveil, en semaine et le week-end. Pulse en déduit ton heure de coucher, peut te la rappeler chaque soir, et tient compte de ton objectif dans ton score.

SÉANCES DE MUSCULATION
Un programme adapté à ton niveau, ton matériel et tes douleurs ou limitations, une séance live avec chrono de repos, séries, records et récap. Pulse ajuste la séance du jour selon ta récupération, et n'augmente les charges que lorsque ta ligne de base le permet. Une charge changée en cours de séance se reporte sur les séries suivantes. Quand un exercice plafonne depuis plusieurs semaines, Pulse te le signale et te propose une variante. Tu peux aussi faire une séance libre, saisir une séance passée ou importer ton historique depuis Hevy.

PLANNING ET STATISTIQUES
Ton planning de la semaine, avec tes routines et tes jours de course, ta charge d'entraînement sur 28 jours, tes courbes de VFC et de fréquence cardiaque, tes muscles travaillés, ton assiduité et tes records. Tes courses et sorties à vélo d'Apple Santé comptent dans ta charge.

COURSE GPS
Lance ta course du jour depuis Pulse, avec son objectif ajusté à ta récupération : distance, allure et temps par kilomètre, annonces vocales à chaque kilomètre, suivi sur l'écran verrouillé, puis ton tracé, ton meilleur segment sur 5 km, 10 km et semi-marathon, et ta course comptée dans ta charge. Tu exportes ton tracé en GPX. Ta position ne sert qu'à la course que tu lances, et ton tracé reste sur ton iPhone, dans ton iCloud privé et dans Apple Santé.

PHOTOS DE PROGRESSION PRIVÉES
Ajoute des photos à tes séances et à tes courses : elles restent dans ton iCloud privé, avec la séance. Tes photos de corps (face, profil, dos) ne quittent jamais ton iPhone : ni iCloud, ni sauvegarde. Elles se verrouillent avec Face ID, et tu compares deux dates côte à côte ou en superposition, avec la variation de ton poids. Un rappel, toutes les deux semaines ou tous les mois, t'invite à reprendre ta photo.

PARTAGE
Partage ta séance, ta course, ta nuit ou tes records en une image prête pour une story ou une publication, ou en sticker sans fond à coller dans Instagram.

COMPLÉMENTS
Suis tes prises de vitamine D, de magnésium, de caféine et de protéines, ton stock et ta régularité, avec des rappels. Pulse ne conseille jamais de dose.

WIDGETS ET SIRI
Ton score et ta séance du jour sur l'écran d'accueil et l'écran verrouillé, et ta séance ou ta course en cours en Live Activity : tes séries s'y suivent et s'y valident. Demande ton score à Siri, démarre ta séance du jour, note ta créatine ou lance ta course d'un raccourci.

TES DONNÉES
Pas de compte, pas de serveur, pas de publicité, aucune analytics. Pulse n'écrit jamais dans iCloud les valeurs lues dans Apple Santé : elles restent sur ton iPhone (et dans sa sauvegarde, si tu l'as activée). Ce que tu saisis et ce que Pulse calcule se synchronise dans ton iCloud privé, auquel personne d'autre n'a accès. Tes photos de corps restent seulement sur ton iPhone. Tu exportes tout en JSON ou CSV, ou tu supprimes tout, depuis l'app.

Pulse n'est pas un dispositif médical. Le score et les ajustements sont des repères d'entraînement, pas un avis médical.
```

Points à contrôler avant de coller : chaque fonction citée existe dans le build soumis (widgets, écran verrouillé, Live Activity, import Hevy, rappels de compléments, course GPS et export GPX, photos de séance et photos de corps, objectif de sommeil et rappel de coucher, partage, plateau, raccourcis Siri). Le meilleur segment des records de course n'est calculé que pour les courses suivies dans Pulse (#88 partiel) : la phrase le dit à propos de la course GPS.

### Nouveautés de la version 1.0.5

À coller pour la 1.0.5. La 1.0.4 soumise est le build (3) du 24 novembre : le partage rapide, le bouton « Valider » de la Live Activity et les autres changements arrivés après ce build sont donc annoncés ici. Si la 1.0.4 a été resoumise avec un build plus récent (1.0.4 (7)), retire de cette liste ce que ses nouveautés annonçaient déjà.

```
Nouveautés de la 1.0.5

• Objectif de sommeil : choisis ton objectif et ton heure de réveil. Pulse en déduit ton heure de coucher, peut te la rappeler chaque soir, et en tient compte dans ton score. L'écran Nuit montre l'écart à ton objectif et la régularité de ton coucher.
• Partage rapide : ta séance, ta course, ta nuit ou tes records en image pour une story ou une publication, ou en sticker sans fond à coller dans Instagram.
• Raccourcis Siri : demande ton score, démarre ta séance du jour, note ta créatine ou lance ta course.
• Plateau : Pulse signale un exercice qui ne progresse plus et te propose une variante.
• Course : exporte ton tracé en GPX, et tes records gardent ton meilleur segment sur 5 km, 10 km et semi-marathon. Crée et modifie tes jours de course dans ton programme.
• Photos de corps : un rappel toutes les deux semaines ou tous les mois. Les compléments du coucher peuvent suivre l'heure de tes nuits.
• Séance : une charge changée se reporte sur les séries suivantes, l'incrément choisi est gardé, et la Live Activity permet de valider ta série.
• Apple Santé se connecte plus tard depuis les paramètres si tu l'avais passé à l'accueil.
• Statistiques plus précises au toucher, calendrier cliquable, et de nombreuses corrections.
```

### Nouveautés de la version 1.0.4 (pour mémoire)

Ce qui accompagnait le build 1.0.4 (3) du 24 novembre (PR #35 à #41).

```
Nouveautés de la 1.0.4

• Séance en direct repensée : la série à faire est mise en avant, chaque exercice a son anneau de progression, et la validation vibre et s'anime.
• Balaye une série vers la droite pour la valider, vers la gauche pour la supprimer.
• La Live Activity suit tes séries dans la Dynamic Island et sur l'écran verrouillé (4/15).
• Corrections d'affichage des statistiques et de l'écran Nuit.
```

### Captures d'écran à reprendre

Les captures de la fiche datent de la 1.0.3 (thème argentique, 22 et 23 novembre ; ce sont aussi celles du site, `site/public/screens/`). Celles-ci ne montrent plus l'interface actuelle, à reprendre sur l'iPhone :

- **Séance en direct** : refonte de la 1.0.4 (anneaux de progression, barre de segments, série à faire éclairée).
- **Détail ou récap de séance** : bouton Partager dans la barre d'outils (1.0.4), carte « Plateau possible » dans le récap (1.0.5). `workout.jpg` du site n'a pas le bouton Partager.
- **Nuit** : l'écart à l'objectif et la régularité du coucher (1.0.5).
- **Planning** : jours de course dans la semaine et calendrier cliquable ; l'éditeur de programme a « Ajouter une course ».
- **Live Activity et Dynamic Island** : anneau des séries « 4/15 » et bouton « Valider ».
- **Aujourd'hui** : la bannière du check-in propose « Connecter Apple Santé » ; à reprendre seulement si la capture montre l'état sans montre.
- **Profil › Paramètres** : section Sommeil, Diagnostic dans À propos, « Noter Pulse ».

À ajouter si la place le permet : une capture du partage (feuille de partage avec l'aperçu de la story).

### Mots-clés (100 caractères max, séparés par des virgules, sans espace)

```
VFC,HRV,sommeil,coucher,score,entraînement,séance,compléments,charge,programme,muscu,course,GPX
```

Les mots déjà présents dans le nom, le sous-titre ou la catégorie (« récupération », « musculation », « forme ») ne sont pas répétés : Apple les indexe déjà.

### Catégories

- Principale : **Forme et santé** (Health & Fitness).
- Secondaire : laisse vide, ou « Style de vie » si tu veux une seconde catégorie.

### URL

| Champ | Valeur |
| :--- | :--- |
| URL d'assistance | `https://pulserecovery.app/support` |
| URL de la politique de confidentialité | `https://pulserecovery.app/confidentialite` |
| URL marketing | facultative, laisse vide |

Vérifié le 28 novembre 2026 : les deux adresses répondent (HTTP 200) après redirection vers `https://d-seonay.github.io/pulse/confidentialite/` et `https://d-seonay.github.io/pulse/support/`, et ce sont celles de `PulsePrivacyPolicyURL` (`Pulse/Info.plist`) et de l'app (lien « Politique de confidentialité » de Mes données).

Contact de la revue : le contact public est la page des issues du dépôt, `https://github.com/D-Seonay/pulse/issues`. App Store Connect demande un nom, un téléphone et un e-mail pour la revue elle-même (non publiés sur la fiche) : ce sont les tiens, ils ne sont pas dans ce dépôt.

## 6. Avant de soumettre

À cocher par Mathéo (spec M8 §10).

- [ ] La branche `m8-confidentialite` est fusionnée dans `master`.
- [ ] GitHub Pages est activé : dépôt, Settings, Pages, source `master`, dossier `/docs`.
- [ ] `https://pulserecovery.app/confidentialite` et `https://pulserecovery.app/support` répondent, sans erreur 404, et le lien « Politique de confidentialité » de Profil, Mes données ouvre bien la première.
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
