# Pulse — fiche App Store Connect

Document à recopier dans App Store Connect. Version de l'app : 1.0.2 (le numéro de build est attribué à l'envoi). Dernière relecture contre le code : 22 novembre 2026, branche `m8-confidentialite`, commit `deff2ec`.

Si le code change (nouveau service, nouvelle donnée envoyée hors de l'iPhone, nouvelle analytics), reprends ce document et la politique de confidentialité avant de soumettre : chaque phrase doit rester vraie pour le build envoyé.

## 1. Confidentialité de l'app

**Réponse à donner : « Données non collectées »** (Data Not Collected).

Justification, en deux phrases : Pulse n'a aucun serveur et n'envoie aucune donnée à son développeur ni à un tiers, aucun SDK d'analyse ou de publicité n'est embarqué. Pulse n'écrit jamais dans iCloud les valeurs lues dans Apple Santé : elles restent dans un magasin local de l'iPhone, et ce que l'utilisateur saisit ou ce que Pulse calcule ne se synchronise que dans le CloudKit privé de l'utilisateur, que le développeur ne peut pas lire.

À coller si le champ « Notes » existe : *Pulse has no server and no analytics SDK. Pulse never writes Apple Health values to iCloud: they stay in an on-device store that is never synced. User-entered data and scores computed by Pulse sync only to the user's own private iCloud (CloudKit private database), which the developer cannot access. Profile values proposed from Apple Health during onboarding (sex, birth date, height, weight) are saved only once the user validates them in the profile form, as user-entered data.*

Cohérence avec le build :
- `Pulse/PrivacyInfo.xcprivacy` et celui de l'extension widgets : `NSPrivacyTracking` faux, aucun domaine de suivi, `NSPrivacyCollectedDataTypes` vide, API `UserDefaults` avec la seule raison `CA92.1` : le code livré n'utilise que `UserDefaults.standard` (les suites nommées ne servent qu'aux tests d'interface en debug, hors groupe d'apps), et les widgets lisent un fichier du groupe d'apps, pas des préférences partagées. Pas de `1C8F.1`.
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
Pulse reads from Apple Health: sleep, heart rate variability (SDNN), resting heart rate, heart rate, running and cycling workouts, body mass, body fat percentage, and (once, at onboarding, to prefill the profile form) height, date of birth and biological sex. It writes to Apple Health: strength training workouts (with estimated active energy) and supplement intakes (vitamin D, magnesium, caffeine, protein). Every permission is optional and can be refused separately.

PRIVACY (guideline 5.1.3)
Values read from Apple Health are stored in an on-device store that is never synced: Pulse never writes them to iCloud. Like all of the app's local data, they are part of the iPhone's own backup if the user has turned it on (iCloud or computer backup), and of the exports the user makes. Values proposed from Apple Health at onboarding (height, weight, date of birth, sex) are saved, and synced, only once the user validates the profile step; they then count as user input. iCloud (the user's private CloudKit database) only holds what the user types and what Pulse computes (workouts logged in Pulse, supplements, program, check-ins, recovery scores). No analytics, no advertising, no third-party SDK. The privacy policy is at https://d-seonay.github.io/kairos/confidentialite/ and support is at https://d-seonay.github.io/kairos/support/. Export and full erase are in Profile > Mes données (My data).

THE REVIEW DEVICE HAS NO HEALTH DATA, WHICH IS EXPECTED
The recovery score needs several nights of sleep, HRV and resting heart rate data from an Apple Watch or compatible device. On a device without them, Today shows a calibration or check-in state (three questions) instead of a measured score. This is normal behaviour, not an error. The measured score appears after a few nights of real data.

HOW TO SEE THE MAIN FEATURES WITHOUT HEALTH DATA
1. First launch: on the Health screen, tap "Continuer sans montre" (Continue without a watch), or "Autoriser dans Apple Santé" (Allow in Apple Health) and allow or deny as you wish. Then fill in the short profile and goals screens.
2. Live workout: open the "Séance" tab, tap "Séance libre" (Free session), then add an exercise and log sets. The rest timer and the recap work without any Health data. Writing the finished workout to Apple Health is optional.
3. Supplements: Profile tab > "Compléments" (Supplements) > "+" / "Ajouter un complément" (Add a supplement), then mark it as taken ("Pris"). Pulse never suggests a dose.
4. Export and delete: Profile tab > "Mes données" (My data).

MEDICAL DISCLAIMER
Pulse is not a medical device. The score and adjustments are training indicators, not medical advice. The notice appears at onboarding and in Settings.

The interface is in French only (version 1).
```

### Français (même contenu, pour mémoire)

```
Pulse est une app de forme et de récupération en français. Il n'y a ni compte, ni connexion, ni serveur.

USAGE DES DONNÉES DE SANTÉ
Pulse lit dans Apple Santé : le sommeil, la variabilité cardiaque (SDNN), la fréquence cardiaque au repos, la fréquence cardiaque, les entraînements de course et de vélo, le poids, la masse grasse, et (une seule fois, à l'accueil, pour préremplir le profil) la taille, la date de naissance et le sexe. Pulse écrit dans Apple Santé : les séances de musculation (avec l'énergie active estimée) et les prises de compléments (vitamine D, magnésium, caféine, protéines). Chaque autorisation est facultative et se refuse séparément.

CONFIDENTIALITÉ (règle 5.1.3)
Les valeurs lues dans Apple Santé sont gardées dans un magasin de l'appareil qui ne se synchronise jamais : Pulse ne les écrit jamais dans iCloud. Comme toutes les données locales de l'app, elles font partie de la sauvegarde de l'iPhone si l'utilisateur l'a activée (iCloud ou ordinateur), et des exports qu'il fait lui-même. Les valeurs proposées depuis Apple Santé à l'accueil (taille, poids, date de naissance, sexe) ne sont enregistrées, et synchronisées, qu'une fois l'étape du profil validée ; elles comptent alors comme une saisie. iCloud (la base CloudKit privée de l'utilisateur) ne contient que ce que l'utilisateur saisit et ce que Pulse calcule (séances faites dans Pulse, compléments, programme, check-ins, scores de récupération). Aucune analytics, aucune publicité, aucun SDK tiers. Politique : https://d-seonay.github.io/kairos/confidentialite/ ; assistance : https://d-seonay.github.io/kairos/support/. L'export et la suppression totale sont dans Profil > Mes données.

L'APPAREIL DE REVUE N'A PAS DE DONNÉES DE SANTÉ, C'EST NORMAL
Le score de récupération demande plusieurs nuits de sommeil, de VFC et de fréquence cardiaque au repos venues d'une Apple Watch ou d'une montre compatible. Sans elles, l'écran Aujourd'hui affiche la calibration ou un check-in de trois questions à la place du score mesuré. Ce n'est pas une erreur. Le score mesuré apparaît après quelques nuits de vraies données.

VOIR L'ESSENTIEL SANS DONNÉES DE SANTÉ
1. Premier lancement : sur l'écran Santé, touche « Continuer sans montre », ou « Autoriser dans Apple Santé » et accepte ou refuse. Remplis ensuite le profil et les objectifs.
2. Séance live : onglet « Séance », « Séance libre », ajoute un exercice et saisis des séries. Le chrono de repos et le récap marchent sans données de santé. L'écriture de la séance dans Apple Santé est facultative.
3. Compléments : onglet Profil > « Compléments » > « + » / « Ajouter un complément », puis « Pris ». Pulse ne propose jamais de dose.
4. Export et suppression : onglet Profil > « Mes données ».

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
Chaque matin, Pulse lit ton sommeil, ta variabilité cardiaque (VFC) et ta fréquence cardiaque au repos dans Apple Santé, et les compare à ta propre ligne de base. Tu vois un score, ce qui l'explique, et ce qui manque quand une mesure est absente. Pas de montre ? Un check-in de trois questions prend le relais.

SÉANCES DE MUSCULATION
Un programme adapté à ton niveau, ton matériel et tes douleurs ou limitations, une séance live avec chrono de repos, séries, records et récap. Pulse ajuste la séance du jour selon ta récupération, et n'augmente les charges que lorsque ta ligne de base le permet. Tu peux aussi faire une séance libre, saisir une séance passée ou importer ton historique depuis Hevy.

PLANNING ET STATISTIQUES
Ton planning de la semaine, ta charge d'entraînement sur 28 jours, tes courbes de VFC et de fréquence cardiaque, tes muscles travaillés, ton assiduité et tes records. Tes courses et sorties à vélo d'Apple Santé comptent dans ta charge.

COMPLÉMENTS
Suis tes prises de vitamine D, de magnésium, de caféine et de protéines, ton stock et ta régularité, avec des rappels. Pulse ne conseille jamais de dose.

WIDGETS
Ton score et ta séance du jour sur l'écran d'accueil et l'écran verrouillé, et ta séance en cours en Live Activity.

TES DONNÉES
Pas de compte, pas de serveur, pas de publicité, aucune analytics. Pulse n'écrit jamais dans iCloud les valeurs lues dans Apple Santé : elles restent sur ton iPhone (et dans sa sauvegarde, si tu l'as activée). Ce que tu saisis et ce que Pulse calcule se synchronise dans ton iCloud privé, auquel personne d'autre n'a accès. Tu exportes tout en JSON ou CSV, ou tu supprimes tout, depuis l'app.

Pulse n'est pas un dispositif médical. Le score et les ajustements sont des repères d'entraînement, pas un avis médical.
```

Points à contrôler avant de coller : chaque fonction citée existe dans le build soumis (widgets, écran verrouillé, Live Activity, import Hevy, rappels de compléments).

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
