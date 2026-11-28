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

À coller dans « Notes » de la section Informations de revue. Laisser « Connexion requise » décoché : il n'y a pas de compte. Le bloc anglais fait 3 288 caractères (limite d'App Store Connect : 4 000) ; garder cette marge en le modifiant.

### English (pasted in App Review notes)

```
Pulse is a French-language fitness and recovery app. There is no account, no sign-in and no server.

HEALTH DATA
Pulse reads from Apple Health: sleep, HRV (SDNN), resting heart rate, heart rate, workouts (all activity types, counted in training load), body mass, body fat and, once at onboarding to prefill the profile, height, date of birth and sex. It writes: strength workouts (with estimated active energy), runs recorded with Pulse (GPS distance and route) and supplement intakes. Every permission is optional.

LOCATION AND BACKGROUND MODES
Location ("While Using the App") is used only for a run the user starts in Pulse: to check GPS on the run's start screen, then to measure distance and draw the route. The "location" background mode keeps that run tracking while the screen is locked, until the run ends. The "audio" mode is only for spoken kilometre announcements during a run. Without location, a run records time only. GPX export happens only when the user taps "Exporter en GPX".

CAMERA, PHOTOS AND FACE ID
Camera on demand only; imports use the system photo picker. A workout photo is saved to Photos only via "Save Image" in the share sheet. Body photos stay on the device, locked by Face ID or the passcode. Metadata, including location, is removed from every image.

PRIVACY (guideline 5.1.3)
Values read from Apple Health stay in an on-device store and are never written to iCloud. The user's private iCloud database only holds what the user types and what Pulse computes (workouts, runs and their simplified route, supplements, program, check-ins, scores, workout photos). Body photos never leave the iPhone. No analytics, no advertising, no third-party SDK, nothing sent to the developer. Details: https://pulserecovery.app/confidentialite. Support: https://pulserecovery.app/support. Export and full erase: Profile > Mes données.

NOTIFICATIONS, SIRI AND RATINGS
All notifications are optional (rest timer, morning score, check-in reminder, supplement, bedtime and body photo reminders). Siri shortcuts give the score, start a workout or a run and log a supplement; the score and the supplement intake require the device to be unlocked. Pulse asks for a rating at most once per version, after the 5th workout or a new record, never during a workout or a run.

THE REVIEW DEVICE HAS NO HEALTH DATA, WHICH IS EXPECTED
The recovery score needs several nights of sleep, HRV and resting heart rate from an Apple Watch or similar. Without them, Today shows a calibration or check-in state (three questions) instead of a measured score. This is normal, not an error.

HOW TO SEE THE MAIN FEATURES WITHOUT HEALTH DATA
1. First launch: tap "Continuer sans montre" (Continue without a watch) or allow Apple Health as you wish, then fill in the short profile and goals screens.
2. Live workout: "Séance" tab > "Séance libre" (Free session), add an exercise and log sets. Rest timer and recap work without Health data.
3. Supplements: Profile > "Compléments" > "Ajouter un complément", then "Pris" (Taken). Pulse never suggests a dose.
4. Run: "Séance" > "Courir" (Run), allow location, then "Partir" (Go). Distance needs GPS outdoors.
5. Export and delete: Profile > "Mes données" (My data).

Pulse is not a medical device; the notice appears at onboarding and in Settings.
```

### Français (même contenu, pour mémoire)

```
Pulse est une app de forme et de récupération en français. Il n'y a ni compte, ni connexion, ni serveur.

DONNÉES DE SANTÉ
Pulse lit dans Apple Santé : le sommeil, la VFC (SDNN), la fréquence cardiaque au repos, la fréquence cardiaque, les entraînements (tous types, comptés dans la charge), le poids, la masse grasse et, une seule fois à l'accueil pour préremplir le profil, la taille, la date de naissance et le sexe. Pulse écrit : les séances de musculation (avec l'énergie active estimée), les courses faites avec Pulse (distance GPS et tracé) et les prises de compléments. Chaque autorisation est facultative.

LOCALISATION ET MODES D'ARRIÈRE-PLAN
La localisation (« Lorsque l'app est active ») ne sert qu'à une course lancée dans Pulse : vérifier le GPS sur l'écran de départ, puis mesurer la distance et tracer le parcours. Le mode d'arrière-plan « location » garde le suivi écran verrouillé jusqu'à la fin de la course. Le mode « audio » ne sert qu'aux annonces vocales des kilomètres. Sans localisation, la course n'enregistre que le temps. L'export GPX n'a lieu que si l'utilisateur touche « Exporter en GPX ».

CAMÉRA, PHOTOS ET FACE ID
Caméra seulement à la demande ; l'import passe par le sélecteur de photos du système. Une photo de séance n'est enregistrée dans Photos que par « Enregistrer l'image » dans la feuille de partage. Les photos de corps restent sur l'appareil, verrouillées par Face ID ou le code. Les métadonnées, dont la position, sont retirées de chaque image.

CONFIDENTIALITÉ (règle 5.1.3)
Les valeurs lues dans Apple Santé restent dans un stockage local et ne sont jamais écrites dans iCloud. La base iCloud privée de l'utilisateur ne contient que ce qu'il saisit et ce que Pulse calcule (séances, courses et leur tracé simplifié, compléments, programme, check-ins, scores, photos de séance). Les photos de corps ne quittent jamais l'iPhone. Aucune mesure d'audience, aucune publicité, aucun SDK tiers, rien n'est envoyé au développeur. Détails : https://pulserecovery.app/confidentialite. Assistance : https://pulserecovery.app/support. Export et effacement complet : Profil > Mes données.

NOTIFICATIONS, SIRI ET NOTES
Toutes les notifications sont facultatives (fin de repos, score du matin, rappel de check-in, rappels de compléments, du coucher et des photos de corps). Les raccourcis Siri donnent le score, lancent une séance ou une course et enregistrent une prise de complément ; le score et la prise demandent un appareil déverrouillé. Pulse demande une note au plus une fois par version, après la 5e séance ou un nouveau record, jamais pendant une séance ou une course.

L'APPAREIL DE REVUE N'A PAS DE DONNÉES DE SANTÉ, C'EST NORMAL
Le score de récupération demande plusieurs nuits de sommeil, de VFC et de FC au repos venant d'une Apple Watch ou équivalent. Sans elles, Aujourd'hui affiche un état de calibration ou de check-in (trois questions) au lieu d'un score mesuré. C'est normal, pas une erreur.

VOIR LES FONCTIONS PRINCIPALES SANS DONNÉES DE SANTÉ
1. Premier lancement : toucher « Continuer sans montre » ou autoriser Apple Santé au choix, puis remplir les courts écrans de profil et d'objectifs.
2. Séance en direct : onglet « Séance » > « Séance libre », ajouter un exercice et noter des séries. Le minuteur de repos et le récap fonctionnent sans données de santé.
3. Compléments : Profil > « Compléments » > « Ajouter un complément », puis « Pris ». Pulse ne propose jamais de dose.
4. Course : « Séance » > « Courir », autoriser la localisation, puis « Partir ». La distance demande le GPS en extérieur.
5. Export et suppression : Profil > « Mes données ».

Pulse n'est pas un dispositif médical ; l'avertissement apparaît à l'accueil et dans les Réglages.
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
