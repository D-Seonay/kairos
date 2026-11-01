# Pulse M3 — Onboarding et tableau de bord : spec complémentaire

Date : 1er novembre 2026
Statut : brouillon soumis à validation
Auteur : Mathéo Delaunay, rédigé avec Claude
Complète : `2026-10-31-pulse-v1-design.md` (la « spec V1 », qui reste l'autorité pour le périmètre) et `2026-10-31-pulse-m2-donnees-contenu-design.md` (la « spec M2 », modèle de données réel). Ce document précise ce que la spec V1 laisse ouvert pour le jalon M3 de la feuille de route : design system, contenu des six écrans du premier lancement, détail de l'accueil, cycle de vie du score du jour, widgets, et découpage en deux plans.

Les décisions prises par Mathéo pendant la conception sont marquées **(Mathéo)**. Les choix faits par le constructeur sont marqués **(choix du constructeur)** : ils peuvent être rouverts, mais pas sans raison.

---

## 1. Intention

Après M3, Mathéo installe Pulse, passe le premier lancement en moins de 90 secondes, et chaque matin l'onglet **Aujourd'hui** affiche son vrai score de récupération, comme sur la maquette : la jauge sur la carte opale, les trois facteurs, la séance du jour de son programme, allégée si besoin, avec l'explication en clair et le bouton « Séance d'origine ». Le score apparaît aussi dans un widget d'écran d'accueil et sur l'écran verrouillé, et une notification prévient quand il est prêt.

M1 a livré le moteur et la lecture d'Apple Santé, M2 la mémoire et le contenu. M3 est le premier jalon que Mathéo **utilise** : c'est là que l'app passe de l'écran de debug à l'app.

**Référence visuelle (Mathéo).** `maquette.html` (à la racine du dépôt) et `assets/maquette_v2_planche.png` sont la référence d'apparence ; les notes de chaque écran sont dans l'objet `NOTES` du HTML, les couleurs dans son `:root`. `mockup.html` (« Fitness & Biométrie IA ») et les autres images de `assets/` (`mockup_apple_2030_*`, `mockup_health_karma_faithful.png`, `design_mockup_mobile.jpg`, `html_mockup_preview.png`, `mockup_screen_*.png`) sont des pistes plus anciennes (« Health Karma ») **à ignorer**. Tous ces fichiers ont été ajoutés au dépôt par Mathéo (commit `659c152`). En cas de conflit, la spec V1 prime pour le périmètre, la maquette pour l'apparence (spec V1 §10).

**Données Apple Santé (Mathéo).** D'après Mathéo, les trois signaux (VFC SDNN de nuit, phases de sommeil, FC au repos) arrivent bien de sa montre Fitbit, « comme sur la maquette ». L'accueil est donc conçu pour trois facteurs présents, avec un état propre quand un facteur manque une nuit. Le tableau « Résultat du diagnostic » du plan M1 reste vide : ce choix repose sur la parole de Mathéo, pas sur une mesure. Si les premiers matins réels montrent une VFC souvent absente, rien n'est à refaire : le moteur renormalise déjà les poids, et l'accueil montre déjà le facteur manquant (§10.2).

---

## 2. Découpage (Mathéo)

M3 est trop large pour un seul plan. **Une spec (ce document), deux plans, une PR chacun**, exécutés l'un après l'autre. Chaque plan est écrit au moment où il démarre, à partir du code réel (principe de la feuille de route).

| Partie | Contenu | Branche (choix du constructeur) |
| :--- | :--- | :--- |
| **M3a — Design system, onboarding, score du jour** | package `PulseDesignSystem` (§6) ; package `PulseFeatures` avec la feature Onboarding (§7) ; adoption d'un modèle de programme (§8) ; import de 60 jours, calcul et cycle de vie du score du jour (4 h, recalcul avant midi, figement) (§9.1, §9.2) ; check-in (§12.1) ; accueil simple (§10, début) ; schéma V2 (§15) ; fausse source Apple Santé à scénarios et test d'interface (§16.1, §16.2) ; barre d'onglets et écrans de debug sous Profil (§17) ; mineurs différés touchés (§19). | `m3-onboarding-tableau-de-bord` |
| **M3b — Accueil complet, arrière-plan, widgets** | ajustements de séance par catégorie (§9.3) ; accueil complet : carte séance ajustée, Pourquoi, repos, course, mobilité, charge, tendances (§10 à §12.2) ; lecture ancrée et livraison en arrière-plan (§13) ; notification du matin (§14) ; cible widgets (§16.3). | `m3b-accueil-widgets`, créée depuis `master` après fusion de M3a |

Fin de M3a : Mathéo peut installer l'app, faire l'onboarding, voir son premier score sur l'écran de calibration, puis chaque matin le score du jour (mesuré ou par check-in) et la séance prévue sur l'accueil simple, sans encore les ajustements, le Pourquoi ni l'arrière-plan. En M3a, chaque ouverture relit les 60 derniers jours d'Apple Santé en entier et remplace le cache ; M3b remplace cette relecture par la lecture ancrée **(choix du constructeur : M3a doit être utilisable seul au quotidien)**.

---

## 3. Objectifs, non-objectifs, anti-objectifs

### Objectifs

- Le premier lancement tient en moins de 90 secondes jusqu'au premier score, reprend à l'étape en cours si l'app est quittée, et ne demande rien avant « Commencer ».
- L'accueil reproduit la maquette (`today`, `pourquoi`, `checkin`) et couvre tous les états : score mesuré, score en calibration, facteur manquant, check-in, jour de repos, jour de course, surmenage, absence de programme.
- Le score du jour suit les règles de la spec V1 §6.3 : calculé à la première ouverture après 4 h ou à la livraison en arrière-plan, recalculé si de nouvelles données arrivent avant midi, figé à midi.
- Chaque ajustement affiché est nommé et expliqué ; « Séance d'origine » reste toujours possible.
- Toute la logique (étapes d'onboarding, adoption de programme, ajustements, cycle de vie du score, états de l'accueil, données du widget) est testée par `swift test` sur le Mac, sans simulateur.

### Non-objectifs (jalons suivants)

- Séance en direct, bibliothèque, éditeur de routines, règle de progression, charges de la dernière fois (M4). Le bouton « Démarrer » existe mais ouvre un écran d'attente (§10.3).
- Carte Compléments de l'accueil (M5).
- Planning, streak, anti-interférence, widgets Série et Séance du jour, import des courses (M6).
- Stats, Profil final, Paramètres, écran Mes données, changement d'ambiance améthyste (M7). Les tokens améthyste existent dès M3 (§6.1), sans réglage pour les choisir.
- Écran Connexion de la maquette : la V1 n'a pas de compte **(Mathéo)**.
- Thème clair de la maquette : l'app est forcée en sombre **(choix du constructeur)**.

### Anti-objectifs

- Une donnée de santé brute (VFC, FC, durée de sommeil) dans un widget, une notification, l'écran verrouillé ou un journal. Seuls le score, sa catégorie et le titre de séance en sortent.
- Un score sans son explication, ou un ajustement imposé.
- Une feature qui importe `SwiftData`, `HealthKit` ou `PulsePersistence` (spec V1 §9).
- Une logique qui ne peut être vérifiée qu'en lançant l'app : Mathéo teste l'app à la main et le simulateur n'est jamais lancé depuis une session (§4).
- Un onboarding qui demande un compte, un e-mail, ou une donnée inutile au score.

---

## 4. Contraintes

- Celles de la spec V1 §3 et §4 et de la spec M2 §3. Environnement vérifié : Xcode 27.0, Swift 6.4, cible iOS 26, `swift-tools-version: 6.2`, mode de langage Swift 6 sur chaque cible, SwiftLint strict (fichiers ≤ 400 lignes, corps de fonction ≤ 50 lignes, lignes ≤ 140), avertissements traités comme des erreurs.
- **Simulateur interdit (Mathéo).** Le constructeur ne lance jamais `xcodebuild test`, `test-without-building`, `make test`, `make test-app`, `simctl boot/install/launch` ni d'outil d'appareil. Il vérifie par `swift test --package-path Packages/<Nom>`, `swiftlint lint --strict`, et pour l'app au plus `xcodebuild build` et `build-for-testing` (bac à sable du shell désactivé pour `xcodebuild`). Conséquence de conception : la logique vit dans les packages, l'app reste un assemblage mince ; les tests de la cible app (`PulseTests`) et le test d'interface sont écrits et compilés, et Mathéo les lance.
- **Test d'interface (Mathéo).** Le critère de la feuille de route « parcours d'onboarding en test d'interface » est conservé : le test est écrit et compilé par le constructeur, exécuté par Mathéo.
- Projet à **dossiers synchronisés** : tout fichier sous `Pulse/` ou `PulseTests/` est compilé sans toucher au `pbxproj`. Les nouveaux packages locaux, la cible de test d'interface et la cible widgets exigent une modification du projet, à la main sur le modèle des références existantes, ou par une régénération unique avec XcodeGen 2.46 (`type: syncedFolder`) à partir de `git show 0a30786:project.yml` en conservant tout ce que contient le projet actuel (cinq packages, `DEVELOPMENT_TEAM = UP9NVJDBKA`, icône, `ITSAppUsesNonExemptEncryption`, orientations iPad, `UIBackgroundModes` remote-notification, `LSApplicationCategoryType` sports, entitlements HealthKit et iCloud), puis suppression de `project.yml`. Toujours vérifié par `xcodebuild build`.
- Toutes les chaînes visibles en français via `String(localized:)` (avec `bundle: .module` dans les packages) ; catalogue `Localizable.xcstrings` par package qui a des chaînes.
- Commits `type(scope): description` en anglais, sans trailer de co-auteur ; aucun push sans l'accord de Mathéo.

---

## 5. Architecture

### 5.1 Packages

Deux nouveaux packages, conformes à la spec V1 §9 :

- **`PulseDesignSystem`** (dépend de `PulseDomain` pour les énumérations `Muscle` et `RecoveryCategory`) : tokens, composants, carte musculaire (§6). Plateformes `.iOS(.v26)` et `.macOS(.v26)` pour que `swift test` tourne sur le Mac ; tout appel propre à UIKit (haptique) est isolé derrière `#if canImport(UIKit)`.
- **`PulseFeatures`** (dépend de `PulseDomain`, `PulseRecoveryEngine`, `PulseContent`, `PulseDesignSystem`) avec une cible par feature : `PulseServices` (logique partagée sans interface : adoption de programme, service du score du jour, planification de la séance du jour, données du widget), `OnboardingFeature`, `TodayFeature`. Mêmes plateformes. Chaque feature expose un modèle `@Observable` testable et ses vues.

`PulseContent` n'est ni la persistance ni HealthKit : les features peuvent l'importer pour résoudre les noms et muscles des exercices.

### 5.2 Frontière avec Apple Santé et le stockage

Les features ne voient que des protocoles Foundation définis dans **`PulseDomain`** **(choix du constructeur)** :

- `HealthAuthorizing` : demander l'autorisation de lecture, savoir si Apple Santé est disponible sur l'appareil.
- `HealthSyncing` : importer l'historique (60 jours) avec progression, lire les nouveautés de façon incrémentale, et rendre des `NightSample` par jour. Implémenté dans `PulseHealth` au-dessus de `HealthKitReader` et du `HealthSampleCache` de M2.
- `HealthProfileReading` : sexe, date de naissance, taille, dernier poids, pour pré-remplir le profil.
- `NotificationScheduling` (M3b) et `WidgetPublishing` (M3b) : planifier ou annuler la notification du matin ; écrire l'instantané du widget et recharger ses timelines.
- Les dépôts de M2 (`ProfileRepository`, `ProgramRepository`, `RecoveryRepository`, `HealthSampleCache`, `WorkoutRepository`).

Le protocole `HealthReading` de M1 reste dans `PulseHealth` pour l'écran de diagnostic ; il n'est pas exposé aux features. Le constructeur choisit la forme exacte des protocoles ; la règle est que `PulseFeatures` ne dépend ni de `PulsePersistence` ni de `PulseHealth`.

### 5.3 Assemblage

`AppDependencies` (dans `Pulse/`) construit les implémentations concrètes et les passe aux modèles des features. La racine de l'app choisit entre l'onboarding et la barre d'onglets selon `UserProfile.onboardingCompletedAt` (§7.7).

Arguments de lancement reconnus en build Debug seulement **(choix du constructeur)** : `-PulseStore inMemory` (conteneur en mémoire, préférences dans une suite dédiée), `-PulseHealthScenario <nom>` (fausse source Apple Santé, §16), `-PulseNow <ISO 8601>` (horloge fixe, pour tester 4 h et midi à la main). Ils servent au test d'interface et aux essais de Mathéo.

---

## 6. Design system (`PulseDesignSystem`)

### 6.1 Tokens

Repris du `:root` de `maquette.html`, thème sombre, en `Color` et constantes Swift :

| Groupe | Valeurs |
| :--- | :--- |
| Fonds | `page` #050608, `background` #0B0C10, `surface` #13151C, `surface2` #1B1E27, `line` blanc 8 % |
| Texte | `text` #F4F5F7, `text2` #A3A9B7, `muted` #6C7383 |
| Opale | `opal` #FFFFFF, `opalInk` #0A0B0F, `opalMuted` #6B7280, `opalLine` #0A0B0F 8 % ; sur opale, `opalOK` #047857, `opalWarn` #B45309, `opalBad` #DC2626 |
| États | `ok` #10B981, `warn` #F59E0B, `bad` #EF4444, `run` #06B6D4, `gold` #F5C518, et leurs versions douces à 16 % |
| Ambiance ambre (défaut) | `accent` #F59E0B, `accent2` #EA580C, `accentInk` #1A1206, `accentSoft` 16 %, aura : dégradé radial ambre puis orange en haut à droite, comme `--aura` |
| Ambiance améthyste (tokens seulement en M3) | `accent` #A855F7, `accent2` #6366F1, `accentInk` #FFFFFF, `accentSoft` 18 % |
| Rayons | 22 / 14 / 10 pt, coins continus |

L'ambiance active vient de `UserProfile.theme`, injectée par l'environnement SwiftUI. La maquette fait foi sur la spec V1 qui parlait de squircles de 28 pt **(choix du constructeur, conformément à spec V1 §10)**.

Typographie : SF Pro ; titres d'écran en graisse très forte (heavy / black) comme la maquette ; chiffres tabulaires (`monospacedDigit`) pour toute valeur ; tailles relatives aux styles de texte pour respecter Dynamic Type jusqu'à « Accessibilité XL » au minimum. Les grands chiffres (score) utilisent `@ScaledMetric`.

### 6.2 Composants

Chacun a un aperçu SwiftUI (`#Preview`) et une étiquette VoiceOver.

- **Carte opale** : fond blanc, encre sombre, rayon 22. Pour les métriques clés (score).
- **Carte obsidienne** : surface sombre en verre (matériau verre d'iOS 26, `glassEffect`, teinté sur `surface`), bord `line`. Pour tout le reste.
- **Jauge de récupération** : arc filaire façon tachymètre (maquette `today` et widget), dégradé rouge → ambre → vert, seuils 40 / 65 / 90, repère circulaire à la position du score, score au centre avec « sur 100 ». Pas d'aiguille. Animée à l'apparition sauf si « Réduire les animations » est actif. Variante compacte pour le widget.
- **Pastille de catégorie** : texte de la catégorie toujours écrit, couleur en plus (optimal et normal en vert, fatigue modérée en ambre, surmenage en rouge). Variantes « Estimé » et « En calibration ».
- **Boutons** : principal plein ambre (texte `accentInk`), secondaire obsidienne, lien texte ambre. Hauteur minimale 50 pt, pleine largeur.
- **Pilules de choix** : simple ou multiple, sélection en blanc plein comme la maquette, haptique légère.
- **Rangée de jours** L M M J V S D, bascule par jour (contour rouge pour un jour de repos imposé, comme `objectifs`).
- **Curseur force / endurance** avec le libellé « 60 / 40 ».
- **Barre d'étapes** de l'onboarding (segments ambre).
- **Sparkline** : 14 points, trous pour les jours sans valeur, dernier point marqué.
- **Jauge linéaire de charge** (M3b) : bandes sous-entraînement / optimal 0,8 à 1,3 / élevé / risque > 1,5, repère.
- **Carte musculaire** face et dos (§6.3).

### 6.3 Carte musculaire

Les silhouettes MuscleMap (licence MIT, Melih Colpan) sont dans `maquette.html` (symboles `body-front` et `body-back`, `viewBox` 650 × 1450, un groupe par région). Le constructeur extrait les tracés dans une ressource du package et les rend en `Shape` SwiftUI par un petit lecteur de tracés SVG (commandes `M m L l H h V v C c Q q A a Z z`), testé sur des tracés connus. Aucune dépendance externe. La mention de licence est conservée dans la ressource ; son affichage dans l'app arrive avec l'écran des licences (M7).

Correspondance `Muscle` → régions MuscleMap **(choix du constructeur)** : `chest` → chest ; `frontDelts` → frontDeltoid ; `sideDelts` → deltoids ; `rearDelts` → rearDeltoid ; `traps` → trapezius ; `lats` et `upperBack` → upperBack ; `lowerBack` → lowerBack ; `biceps` → biceps ; `triceps` → triceps ; `forearms` → forearm ; `abs` → abs ; `obliques` → obliques ; `quads` → quadriceps ; `hamstrings` → hamstring ; `glutes` et `abductors` → gluteal ; `adductors` → adductors ; `calves` → calves ; `hipFlexors` → hipFlexors.

Intensité en quatre niveaux, comme `--h1` à `--h4` (accent mélangé à 32, 56, 80 et 100 % avec la couleur « muscle éteint ») : pour une séance, chaque série de travail compte 1 pour ses muscles principaux et 0,5 pour les secondaires ; le niveau d'un muscle est sa part du maximum, découpée en quarts. Une fonction pure, testée.

---

## 7. Onboarding (M3a)

Six écrans, dans l'ordre de la spec V1 §5.1, sur fond `background` avec l'aura en haut, barre d'étapes à partir de l'écran 2, bouton principal en bas. Les textes de la maquette sont repris, corrigés quand ils contredisent la V1 (pas d'Android, pas de compte, pas d'article sur la synchronisation à activer : la sauvegarde iCloud est automatique et le cache Apple Santé n'est pas synchronisé).

### 7.1 Bienvenue (`bienvenue`)

Logo, « Ton corps décide de la séance du jour. », sous-titre, trois bénéfices (score du matin, séances qui s'adaptent, muscu et course réconciliées), bouton « Commencer ». Pas de lien « J'ai déjà un compte » : une réinstallation restaure par iCloud (§7.7). Mention « Pulse n'est pas un dispositif médical » en pied d'écran (spec V1 §11).

### 7.2 Apple Santé (`sante`)

« Pulse a besoin de lire tes nuits », les quatre lignes de la maquette (VFC nocturne, en disant honnêtement que l'iPhone fournit la SDNN ; phases de sommeil ; FC au repos ; entraînements passés), la mention « données de santé au sens de l'article 9 du RGPD », boutons « Autoriser dans Apple Santé » (modale native, lecture seulement : sommeil, VFC SDNN, FC repos, FC, entraînements, poids, masse grasse, taille, date de naissance, sexe) et « Continuer sans montre ». L'écriture sera demandée en M4 et M5, au premier besoin **(choix du constructeur)**. iOS ne dit pas si la lecture a été refusée : l'app le découvre à l'absence de données et bascule sur le check-in.

### 7.3 Profil (`profil-init`)

Prénom (facultatif, nouveau champ §15), sexe (Femme / Homme / Autre → `female` / `male` / `unspecified`), date de naissance, taille, poids, unités (kg ou lb), expérience en musculation et en course. Pré-rempli depuis Apple Santé quand c'est autorisé. Niveaux **(choix du constructeur)**, trois pilules chacun pour correspondre aux trois niveaux du domaine : musculation « Moins d'un an » / « 1 à 3 ans » / « Plus de 3 ans » ; course « Je débute » / « Je cours régulièrement » / « Je prépare des courses ». Le niveau de musculation fixe les incréments par défaut du profil : débutant et intermédiaire 2,5 kg haut / 5 kg bas, confirmé 1,25 / 2,5. Tous les champs sauf les niveaux sont facultatifs : « Continuer » n'est jamais bloqué.

### 7.4 Objectifs (`objectifs`)

Curseur force / endurance (`focus`, pas de 0,1, libellés « 100 % musculation », « Hybride », « 100 % running ») avec la ligne de proposition en dessous ; nombre de séances par semaine (pilules 2 à 6, absent de la maquette, exigé par la spec V1) ; jours de repos imposés (rangée L à D) ; matériel (trois cartes : salle complète, home gym, poids du corps) ; douleurs (épaules, lombaires, genoux, poignets, aucune : les quatre valeurs du domaine, pas « hanches » ni « genou gauche » de la maquette) avec la phrase « Les mouvements à risque pour les zones cochées sont remplacés par leur alternative. » Bouton « Continuer ».

### 7.5 Programme (pas de maquette)

Écran conçu par le constructeur dans le style de la maquette : liste des cinq modèles en cartes obsidienne (nom, résumé, séances par semaine, aperçu de la semaine L à D), le modèle recommandé en tête avec un badge « Recommandé » et présélectionné, puis une carte « Je construis le mien ». Bouton « Adopter ce programme ». Recommandation : focus `strength` si `focus` < 0,35, `endurance` au-delà de 0,65, sinon `balanced` ; parmi les modèles de ce focus, celui dont `daysPerWeek` contient le nombre de séances choisi, sinon le plus proche ; sinon le premier modèle **(choix du constructeur)**. « Je construis le mien » laisse `activeProgramID` vide : l'éditeur de routines arrive en M4, et l'accueil le dit (§10.3).

### 7.6 Calibration (`calibration`)

Import de 60 jours (§9.1) avec progression (« Lecture de tes nuits… »). Puis, comme la maquette : pastille « N nuits analysées », « Ta récupération ce matin », score et catégorie, « Ta ligne de base » (VFC moyenne ± écart-type, FC repos moyenne ± écart-type, sommeil moyen ; pas de ligne « charge des 28 jours » tant qu'il n'y a pas de séances), texte sur la ligne de base qui se précise, puis une carte « Me prévenir quand mon score est prêt » (interrupteur, activé par défaut, qui déclenche la demande d'autorisation des notifications ; utile à M3b) et le bouton « Voir ma séance du jour ».

Cas, selon le résultat du moteur tel quel (§9.1) : score mesuré avec ligne de base VFC en cours (5 à 13 nuits avec SDNN), marqué « en calibration » ; score mesuré sans VFC (moins de 5 nuits avec SDNN), la VFC apparaît comme facteur en attente de ligne de base ; check-in demandé par le moteur, ou Apple Santé ignoré : l'écran l'explique et propose le check-in (§12.1) à la place du score.

### 7.7 Reprise et fin

- L'étape courante est enregistrée dans les préférences de l'app (effacées par la suppression totale). Le profil est enregistré en brouillon (`onboardingCompletedAt` vide) à la fin de chaque étape, le programme à l'étape 5. Quitter l'app ramène à l'étape en cours, champs remplis.
- `onboardingCompletedAt` est posé en quittant la calibration ; la racine bascule sur la barre d'onglets.
- Réinstallation : si un profil terminé arrive d'iCloud pendant l'onboarding, l'app bascule sur l'accueil sans finir le parcours **(choix du constructeur)**. Le profil le plus ancien gagne (spec M2 §5.3) ; le brouillon local, plus récent, est ignoré puis supprimé logiquement.

---

## 8. Adoption d'un modèle de programme (M3a)

Une fonction pure dans `PulseServices` copie un `ProgramTemplate` en `Program` (spec M2 §4.3 : la copie appartient à l'utilisateur), avec deux adaptations **(choix du constructeur, nécessaires pour que l'étape Objectifs serve à quelque chose)** :

1. **Matériel et douleurs.** Un exercice dont le matériel n'est pas accessible, ou qui présente un risque pour une zone déclarée, est remplacé par la première de ses alternatives acceptable, sinon par le premier exercice actif du même plan de mouvement acceptable, sinon gardé. Matériel accessible : salle complète = tout ; home gym = haltères, kettlebell, élastique, poids du corps ; poids du corps = poids du corps seulement. Le risque vient d'un nouveau champ de contenu `riskAreas: [PainArea]` sur chaque exercice (facultatif, vide par défaut), renseigné par le constructeur pour les 84 exercices selon des règles prudentes (épaules : développés au-dessus de la tête, dips, écartés profonds ; lombaires : soulevés de terre, rowing à la barre, squats à la barre ; genoux : sissy squat, fentes, extension des jambes ; poignets : pompes, squat avant, curls et extensions à la barre droite). Validé par un test de contenu.
2. **Jours de repos imposés.** La semaine vient de `suggestedWeek` ; une séance qui tombe sur un jour de repos imposé glisse au jour libre suivant (en bouclant sur la semaine), dans l'ordre. Si la semaine n'a pas assez de jours libres, les séances en trop sont retirées de la semaine (elles restent dans le programme).

Le programme adopté devient `activeProgramID`. Testé sur des cas types (PPL 3 sans contrainte = copie exacte ; home gym ; épaules ; dimanche et mercredi imposés).

---

## 9. Score du jour

### 9.1 Premier import et premier score (M3a)

`HealthSyncing` lit 60 jours (SDNN, FC repos, sommeil), remplit le cache (spec M2 §5.4), et rend les nuits par jour via `NightAggregator`. Le service du score du jour (`PulseServices`) appelle `RecoveryCalculator`, puis enregistre un `DailyRecovery` (mesuré) ou rien (check-in demandé). Le jour d'un score est minuit local du jour de réveil.

**Le résultat du moteur M1 est utilisé tel quel, sans règle ajoutée (choix du constructeur).** Le moteur décide déjà : score mesuré dès que deux facteurs sont présents, check-in sinon. La règle « sous 5 nuits, check-in » de la spec V1 §6.3 porte sur la ligne de base VFC : sous 5 nuits avec SDNN valide, le facteur VFC est simplement absent, et le score repose sur la FC repos (qui demande 3 valeurs sur 7 jours) et le sommeil. Ainsi, une montre qui envoie rarement la SDNN donne quand même un score mesuré chaque matin (§1). Conséquences d'affichage : « En calibration (N nuits) » n'apparaît que lorsque la VFC compte dans le score avec une ligne de base de 5 à 13 nuits ; sous 5 nuits, la colonne VFC dit « ligne de base en cours, N sur 5 nuits » au lieu de « pas de donnée cette nuit ». La pastille « N nuits analysées » de la calibration compte les nuits des 60 jours où au moins un facteur existe. Que la surcharge progressive reste fermée sans VFC (`allowsProgressiveOverload`) est une question de M4.

### 9.2 Cycle de vie (M3a)

Règles de la spec V1 §6.3, précisées **(choix du constructeur)** :

- **Avant 4 h** : pas de score du jour ; l'accueil montre celui de la veille, marqué « Score d'hier », avec « Le score du jour se calcule après 4 h ».
- **Entre 4 h et midi** : le score est calculé à l'ouverture et à chaque livraison en arrière-plan, et **recalculé** si de nouvelles données arrivent. Un check-in fait le matin est remplacé par un score mesuré dès qu'au moins deux facteurs arrivent (pas de score hybride, spec V1 §5.2).
- **À partir de midi** : le score du jour est figé (`frozenAt`). S'il n'existait pas encore, le premier score obtenu après midi, mesuré à une ouverture ou issu d'un check-in, est enregistré et figé immédiatement ; tant qu'aucun score n'existe, le check-in reste proposé, sans limite d'heure. Après le figement, plus aucun recalcul ni check-in pour ce jour. Aucun état « figé sans score » n'est stocké.
- Toutes les heures viennent d'une horloge injectée (`now`) et du calendrier injecté, jamais de `Date()` ni de `Calendar.current` dans la logique.

### 9.3 Ajustements de séance par catégorie (M3b)

Une fonction pure dans `PulseRecoveryEngine` (`SessionAdjuster`) applique la table de la spec V1 §6.5 à un `RoutineDay`, et rend la séance ajustée et la liste de `SessionAdjustment` (format de la spec M2 §5.3, raison en français) :

| Catégorie | Ajustements M3 |
| :--- | :--- |
| Optimal | aucun. La surcharge progressive arrive en M4. |
| Normal | repos +15 s sur chaque exercice. |
| Fatigue modérée | volume −20 %, RPE plafonné à 7,5, repos +45 s ; jour de course de type fractionné : suggestion de sortie facile. |
| Surmenage | séance remplacée par 20 min de mobilité ou repos, au choix ; jour de course : suggestion de repos. |

**Volume −20 %** **(choix du constructeur, fidèle à la maquette « 18 → 14 séries, une de moins sur quatre exercices »)** : retirer `round(total × 0,2)` séries, une par exercice à la fois, en commençant par les exercices qui ont le plus de séries puis dans l'ordre de la séance, sans jamais descendre sous une série ; recommencer un tour si nécessaire. Les deux exercices d'un super set perdent une série ensemble ou pas du tout.

Un score **estimé** ou **en calibration** applique la même table (il n'autorise simplement jamais la surcharge, sans effet en M3). Les ajustements générés sont enregistrés dans `DailyRecovery.adjustments`. La règle de progression et les charges de la dernière séance arrivent en M4 **(Mathéo)**.

Durée estimée d'une séance **(choix du constructeur)** : 45 s d'effort par série, plus le repos après chaque série sauf la dernière ; un super set compte un seul repos par tour ; arrondi aux 5 minutes.

---

## 10. Accueil (feature Today)

En M3a, l'onglet Aujourd'hui affiche une version simple : en-tête (§10.1), carte Récupération complète (§10.2) ou check-in à sa place (§12.1), et la carte de la séance prévue sans ajustement ni Pourquoi (jour de musculation, de course, de repos ou sans programme, en texte simple). Le reste de cette section est M3b.

### 10.1 En-tête

« Bonjour {prénom} » (ou « Bonjour »), date longue, pastille « Synchro HH:MM » (dernière lecture Apple Santé réussie ; un toucher relance une lecture), bouton profil qui ouvre l'onglet Profil.

### 10.2 Carte Récupération (opale)

Titre « Récupération », pastille de catégorie, jauge, score « sur 100 », marqueur « Estimé » ou « En calibration (N nuits) » quand c'est le cas. Trois colonnes comme la maquette :

- **Sommeil** : durée (« 5 h 10 ») et « profond 7 % » (ou « phases inconnues »).
- **Variabilité** : SDNN de la nuit (« 44 ms ») et écart à la ligne de base 14 jours (« −18 % vs 14 j »).
- **FC repos** : valeur (« 54 ») et écart à la moyenne 7 jours (« +5 bpm »).

Un facteur absent affiche « — » et « pas de donnée cette nuit ». Toucher la carte ouvre Pourquoi. Aux tailles de texte d'accessibilité, les trois colonnes passent l'une sous l'autre.

### 10.3 Carte Séance du jour (obsidienne)

La séance du jour est le `RoutineDay` placé sur le jour de la semaine dans `weekLayout` du programme actif (le planning daté `ScheduledDay` arrive en M6).

- **Jour de musculation** : « Séance du jour », titre (nom du jour, plus « volume allégé » quand le volume est réduit), badge « Ajustée » ou « Planifiée », mini-carte musculaire face et dos, nombre de séries, durée estimée, RPE maximum, trois muscles principaux. Boutons « Pourquoi ? » et « Séance d'origine », bouton principal « Démarrer la séance ».
- **Séance d'origine** : la carte passe à l'état « Planifiée » de la maquette (séries, durée et RPE d'origine) avec « Revenir à l'ajustée » et « Démarrer quand même ». Le choix est enregistré pour le jour (§15) et la carte musculaire est recalculée.
- **Démarrer** : en M3, ouvre une feuille « La séance en direct arrive bientôt » qui résume la séance à faire (exercices, séries × répétitions, repos ajusté), pour que Mathéo puisse la suivre en salle **(choix du constructeur)**.
- **Jour de course** (modèle Renforcement coureur) : type et cible (« Sortie facile, 40 min »), suggestion de la catégorie, pas de bouton Démarrer.
- **Jour de repos** : carte « Repos », prochaine séance (« Pull, mercredi »), et si le score est sous 65, une suggestion « 20 min de mobilité » (§12.2).
- **Surmenage un jour de musculation** : la carte propose « 20 min de mobilité » ou « Repos », et garde « Séance d'origine ».
- **Pas de programme** (« Je construis le mien ») : « Aucune séance prévue. L'éditeur de routines arrive avec la séance en direct. »

### 10.4 Charge d'entraînement

Jauge linéaire ACWR de la maquette. Masquée sans 28 jours d'historique (début de l'historique : date de fin d'onboarding ou première séance enregistrée, la plus ancienne) ; à la place, une carte « La jauge de charge apparaîtra après 28 jours d'entraînement : elle compare ta dernière semaine à ton mois. » Les séances comptées sont celles du `WorkoutRepository` (aucune avant M4, les courses importées arrivent en M6).

### 10.5 Tendances

Trois tuiles sparkline sur 14 jours, calculées depuis les nuits du cache : « Variabilité, 14 jours » (dernière valeur en ms), « FC repos, 14 jours », « Sommeil, 14 jours » (moyenne). La maquette en montre deux ; la spec V1 demande une sparkline par facteur **(choix du constructeur)**.

---

## 11. Pourquoi (M3b, `pourquoi`)

Écran poussé depuis la carte Récupération ou « Pourquoi ? » :

1. **Lecture de ce matin** (carte opale) : une ou deux phrases en français courant générées à partir des écarts (« Ta variabilité cardiaque est 18 % sous ta moyenne de 14 jours, ta fréquence au repos a pris 5 bpm et tu n'as dormi que 5 h 10. »), plus une phrase de conclusion selon la catégorie. Un facteur manquant est dit (« Pas de variabilité cette nuit : le score repose sur le sommeil et la fréquence au repos. »).
2. **Ce que le moteur a changé** : une ligne par ajustement, avec sa pastille (« −4 », « 7,5 », « +45 », « = ») et sa raison, comme la maquette, plus la ligne « Charges inchangées : celles de ta dernière séance, sans surcharge progressive aujourd'hui » pour les catégories normal et fatigue. Score optimal : « Rien à alléger aujourd'hui. »
3. **Les trois signaux** : barre et sous-score par facteur, puis la formule avec les poids réellement appliqués (« Score = 50 % × 59 + 25 % × 58 + 25 % × 56 = 58 », poids renormalisés si un facteur manque), puis la règle de la catégorie.
4. Boutons « Valider et démarrer » et « Rétablir la séance d'origine », phrase « Tu gardes toujours le dernier mot. »

Score estimé : la section 3 montre les trois réponses du check-in et la pondération 40 / 35 / 25.

Les textes sont produits par une fonction pure testée (cas : trois facteurs, un manquant, estimé, en calibration, chaque catégorie).

---

## 12. Check-in (M3a), mobilité (M3b)

### 12.1 Check-in (`checkin`)

Affiché à la place de la carte Récupération quand le calcul demande un check-in, et depuis la calibration. Bandeau « Pas de données de nuit », trois questions, score recalculé en direct sur une carte opale « Estimation », bouton « Utiliser ce score aujourd'hui », mention « Un score estimé n'autorise jamais de surcharge progressive. » Enregistre un `CheckIn` et un `DailyRecovery` avec `isEstimated`.

Le moteur attend des réponses de 0 à 4 ; la maquette montre quatre pilules par question. Cinq pilules par question, pour garder le moteur testé de M1 **(choix du constructeur)** :

- Sommeil : Mauvais, Moyen, Correct, Bon, Excellent (0 à 4).
- Courbatures et douleurs : Aucune, Légères, Modérées, Marquées, Douleur aiguë (4 à 0).
- Motivation : Zéro, Faible, Moyenne, Bonne, À fond (0 à 4).

### 12.2 Mobilité

Une feuille « 20 min de mobilité » : minuteur de 20 minutes (démarrer, pause, terminer), cinq consignes simples (hanches, chevilles, colonne thoracique, épaules, respiration). Rien n'est enregistré : la mobilité n'entre ni dans la charge, ni dans le streak, ni dans le calendrier (spec V1 §5.2).

---

## 13. Apple Santé : lecture incrémentale et arrière-plan (M3b)

- **Lecture ancrée** : `HKAnchoredObjectQuery` par type (sommeil, SDNN, FC repos), ancres dans `HealthSampleCache`, suppressions appliquées au cache. Chaque ouverture et chaque retour au premier plan déclenchent une lecture incrémentale.
- **Livraison en arrière-plan** : `HKObserverQuery` et `enableBackgroundDelivery` pour ces trois types, enregistrés au lancement (avant la fin de `application(_:didFinishLaunchingWithOptions:)`), l'entitlement `com.apple.developer.healthkit.background-delivery` étant déjà présent. Au réveil : lecture ancrée, recalcul selon §9.2, instantané du widget, notification éventuelle (§14), puis appel du gestionnaire de fin de l'observateur.
- **iPhone verrouillé** : les données Apple Santé sont protégées tant que l'iPhone n'a pas été déverrouillé ; une lecture peut échouer en arrière-plan. L'échec est silencieux, et la lecture est refaite au prochain réveil ou dès que les données protégées redeviennent disponibles.
- Le score ne dépend jamais de l'arrière-plan pour exister (spec V1 §13) : l'ouverture de l'app suffit.

---

## 14. Notification du matin (M3b)

« Ton score du matin est prêt » avec le score et la catégorie dans le corps (« 58 · fatigue modérée, séance allégée »), rien d'autre. Envoyée une seule fois par jour, quand un score **mesuré** est calculé en arrière-plan, si `morningScoreNotification` est vrai, si l'app n'a pas encore été ouverte ce jour-là, et avant l'heure plafond `morningScoreDeadlineMinutes` (défaut 10 h 00 quand le champ est vide) **(choix du constructeur)**. Toucher la notification ouvre l'accueil. Le réglage de l'heure arrive en M7. La décision d'envoyer est une fonction pure testée.

---

## 15. Données : schéma V2 (M3a)

Première migration, légère (`PulseSchemaV2` et une étape dans `PulseMigrationPlan`), uniquement des attributs facultatifs :

- `UserProfile.firstName: String?` **(Mathéo)**.
- `DailyRecovery.originalSessionChosen: Bool?` : vrai quand l'utilisateur a rétabli la séance d'origine ce jour-là. M4 recopiera le choix dans `WorkoutSession.refusedAdjustments` ; M6 s'en servira pour les statistiques d'adhésion **(choix du constructeur)**.
- `createdAt` et `updatedAt` facultatifs sur `StoredRoutineDay`, `StoredRoutineExercise` et `StoredWorkoutSet` (mineur différé de M2, regroupé dans la même migration).

Export JSON et CSV mis à jour pour les nouveaux champs. Un test construit un magasin V1 sur disque, l'ouvre avec le plan de migration en V2 et relit les données. Mathéo doit redéployer le schéma CloudKit en production avant le premier TestFlight qui synchronise (§20).

Le contenu (`exercises.json`) gagne `riskAreas` (§8) ; c'est un changement de contenu, sans effet sur le schéma SwiftData.

---

## 16. Fausse source Apple Santé, widget, test d'interface

### 16.1 Scénarios (M3a)

Une implémentation de `HealthSyncing` et `HealthProfileReading` (dans `PulseHealth` ou `PulseServices`, au choix du constructeur) qui génère 60 jours synthétiques déterministes à partir d'un scénario : `goodNight` (ligne de base stable, nuit du jour bonne, score optimal), `badNight` (VFC −20 %, FC +6, sommeil 5 h, fatigue modérée), `missingHRV` (pas de SDNN cette nuit), `threeNights` (3 nuits seulement → check-in), `noData`. Utilisée par le test d'interface, par les aperçus SwiftUI, et par l'argument `-PulseHealthScenario` en Debug. Les scénarios et leur score attendu sont testés.

### 16.2 Test d'interface (M3a)

Nouvelle cible `PulseUITests`. Un test lance l'app avec `-PulseStore inMemory -PulseHealthScenario goodNight`, passe les six écrans (identifiants d'accessibilité sur les boutons et champs clés), et vérifie que le score attendu s'affiche sur la calibration puis sur l'accueil. Le constructeur le compile (`build-for-testing`) ; Mathéo l'exécute.

### 16.3 Widgets (M3b)

Nouvelle cible d'extension `PulseWidgets` et App Group `group.fr.seonay.pulse` sur l'app et l'extension.

- L'app écrit après chaque calcul un **instantané** JSON dans le conteneur du groupe : jour, score arrondi, catégorie, estimé ou non, titre de la séance du jour, séance allégée ou non. **Aucune valeur brute.** Puis `WidgetCenter` recharge les timelines. La suppression totale efface l'instantané.
- **Petit widget « Récupération »** (maquette `ios-accueil` et `veille-widgets`) : jauge compacte, score, catégorie, « Séance allégée » ou « Séance normale ». Lisible en monochrome (veille de nuit en rouge).
- **Écran verrouillé** : `accessoryCircular` (jauge et score) et `accessoryInline` (« 58 · fatigue modérée »).
- Instantané d'un autre jour que aujourd'hui : « — » et « Score pas encore prêt ». Toucher un widget ouvre l'accueil.
- Les widgets Série et Séance du jour, et le widget interactif « Démarrer », arrivent en M6 et M4.

---

## 17. Onglets et écrans de debug (M3a)

Barre d'onglets de la maquette : **Aujourd'hui**, **Planning**, **Séance**, **Stats**, **Profil** (libellés de la maquette plutôt que « Entraîner » de la spec V1 : **choix du constructeur**). Planning, Séance et Stats restent vides **(Mathéo)** et affichent un écran d'attente (« Arrive avec le jalon M6 / M4 / M7 »). Profil, en attendant M7, liste le prénom et deux liens vers les écrans de debug existants « Santé » (diagnostic M1) et « Données » (M2), qui ne sont plus des onglets. L'app est forcée en thème sombre.

---

## 18. Tests et qualité

- **`swift test` sur le Mac** pour chaque package : `PulseDesignSystem` (lecteur de tracés SVG, géométrie de la jauge, niveaux d'intensité musculaire, correspondance `Muscle` → régions), `PulseFeatures` (machine à étapes de l'onboarding et reprise, recommandation de modèle, adoption avec matériel / douleurs / jours de repos, service du score du jour avec horloge fixe : avant 4 h, recalcul avant midi, figement, check-in remplacé ; états de l'accueil ; textes de Pourquoi ; décision de notification ; instantané du widget sans valeur brute), `PulseRecoveryEngine` (`SessionAdjuster` sur chaque catégorie, arrondi du volume, super sets, durée estimée), `PulseContent` (`riskAreas` valides), `PulsePersistence` (migration V1 → V2, nouveaux champs en aller-retour et dans l'export), `PulseHealth` (scénarios).
- **Cible app** : tests de modèles restants dans `PulseTests`, compilés par `build-for-testing`, lancés par Mathéo.
- **Aperçus SwiftUI** pour chaque écran et composant, avec les scénarios.
- **Lint** : `swiftlint lint --strict` vert ; `PulseWidgets` est déjà dans `included` de `.swiftlint.yml`.
- **Makefile** : `test-packages` gagne les nouveaux packages.
- **Accessibilité** : étiquettes VoiceOver sur chaque contrôle et sur la jauge (« Récupération 58 sur 100, fatigue modérée »), catégorie toujours écrite, Dynamic Type jusqu'à « Accessibilité XL », « Réduire les animations » respecté. La passe complète reste en M8.

---

## 19. Mineurs différés de M2 traités en M3

Parce que M3 touche ces fichiers :

- `SwiftDataRecoveryRepository` : calendrier injecté (celui d'`AppDependencies`) au lieu de `Calendar.current`.
- `ProfileRepository.load()` : départage par `id` à `createdAt` égal.
- `AppDependencies.testing()` : suite `UserDefaults` dédiée pour l'effaceur.
- Mode iCloud choisi par la présence de l'entitlement (ou d'un réglage de build qui la reflète) et non par `targetEnvironment(simulator)`.
- `DataDebugModel.erase` : comptes rafraîchis même si l'effacement Apple Santé échoue ; feuille de suppression non fermable pendant l'opération.
- Enfants SwiftData sans `createdAt` / `updatedAt` : dans la migration V2 (§15).
- `PulseContent` : `.process("Resources")` qui aplatit `Programs/` corrigé ; règle de validation contre un même exercice deux fois dans un jour ; alternatives du curl pupitre machine sans la barre EZ avant la poulie.

Ne sont **pas** traités en M3 : la suppression d'un complément qui laisse ses prises dans l'export (M5), l'optimisation de `WorkoutRepository.lastSets(for:)` et l'implémentation de `HealthErasing` côté HealthKit (M4).

---

## 20. Ce qui revient à Mathéo

- Exécuter le test d'interface et les tests de la cible app (`make test-app`) sur son Mac.
- Installer l'app sur son iPhone, faire l'onboarding avec ses vraies données, vérifier le premier score ; remplir à cette occasion le tableau « Résultat du diagnostic » du plan M1 (l'écran Santé reste accessible depuis Profil).
- M3b : vérifier sur quelques matins réels le score à l'ouverture, la notification, le widget, le figement à midi.
- Activer l'App Group `group.fr.seonay.pulse` sur le compte développeur si la signature automatique ne le fait pas.
- Déployer le schéma CloudKit V2 en production avant le premier TestFlight qui synchronise (spec M2 §11).
- Pousser `master`, qui contient le commit `659c152` (maquettes) en avance sur `origin/master`, ou le laisser partir avec la PR M3a.

---

## 21. Laissé au constructeur

- La forme exacte des protocoles du §5.2, l'organisation interne des packages, le nommage des fichiers.
- Les textes exacts des écrans dans l'esprit de la maquette, tutoiement, sans jargon non expliqué.
- Le choix entre édition manuelle du `pbxproj` et régénération XcodeGen unique.
- Les règles exactes de `riskAreas` dans le cadre du §8.
- Les animations et micro-interactions, dans le respect de la maquette et de « Réduire les animations ».

---

## 22. Critères de fin

**M3a** : `swift test` vert sur tous les packages ; `swiftlint lint --strict` vert ; `xcodebuild build` et `build-for-testing` réussis (app, `PulseTests`, `PulseUITests`) ; PR `m3-onboarding-tableau-de-bord` ouverte vers `master` avec l'accord de Mathéo pour pousser. Côté Mathéo : test d'interface vert, onboarding fait sur son iPhone, premier score affiché.

**M3b** : mêmes vérifications, cible `PulseWidgets` comprise ; PR `m3b-accueil-widgets`. Côté Mathéo : l'accueil affiche le score réel chaque matin (critère de la feuille de route), la notification et le widget fonctionnent.
