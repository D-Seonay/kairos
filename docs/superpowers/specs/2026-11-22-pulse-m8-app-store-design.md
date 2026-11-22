# Pulse M8 — App Store : spec complémentaire

Date : 22 novembre 2026
Statut : brouillon à valider par Mathéo (« continue de dev », « je te fais confiance »), relu par un agent constructeur
Auteur : Mathéo Delaunay, rédigé avec Claude
Complète : la spec V1 (`2026-10-31-pulse-v1-design.md`, §3, §4, §11, §12), la feuille de route (`2026-10-31-pulse-v1-roadmap.md`, M8), la spec M2 (persistance à deux magasins, export, suppression) et la spec M7 (Paramètres, Mes données, lien de politique prévu).

Les choix du constructeur sont marqués **(choix du constructeur)**. On peut les rouvrir, mais il faut une raison.

---

## 1. Intention

Pulse marche sur l'iPhone de Mathéo et part sur TestFlight à chaque jalon. Le dernier jalon de la V1 est de le faire accepter sur l'App Store (spec V1 §2) sans tricher sur ce que la revue vérifie : la confidentialité des données de santé, l'accessibilité de base et l'honnêteté des textes.

Un point bloque aujourd'hui : la règle App Store 5.1.3(ii) interdit de stocker dans iCloud des données de santé personnelles lues dans Apple Santé. Or le magasin synchronisé (`synced`, CloudKit privé) contient les valeurs brutes des nuits (VFC, FC repos, sommeil), les courses et vélos importés, et le poids et la masse grasse lus dans Apple Santé. Mathéo a choisi le 22 novembre 2026 de garder iCloud pour ce qu'il saisit et pour ce que Pulse calcule, et de garder tout ce qui vient d'Apple Santé sur l'appareil seulement.

## 2. Objectifs, non-objectifs, anti-objectifs

**Objectifs.**
- **Aucune valeur lue dans Apple Santé n'est écrite dans le magasin synchronisé**, et ce qui s'y trouve déjà en est retiré, y compris ce qu'iCloud redescend plus tard d'une ancienne version.
- Un manifeste de confidentialité exact pour l'app et l'extension widgets.
- Une politique de confidentialité et une page d'assistance publiques (GitHub Pages du dépôt), liées dans l'app.
- L'avertissement « pas un dispositif médical » dans les Paramètres, en plus de l'onboarding (spec V1 §11).
- Un document prêt à recopier pour App Store Connect : déclaration de confidentialité, classification, notes pour la revue, textes de la fiche.
- Une passe d'accessibilité sur chaque écran : VoiceOver, Dynamic Type jusqu'à « Accessibilité XL », contraste AA, « Réduire les animations », aucune information portée par la seule couleur.

**Non-objectifs.**
- Un mode démo pour la revue. Les notes de revue expliquent la calibration et l'absence de données ; un mode démo n'est fait que si Apple rejette l'app pour ça **(choix du constructeur)**.
- L'anglais : les chaînes sont externalisées, la V1 reste en français (spec V1 §11).
- Les captures d'écran, la fiche, les 14 jours d'usage, le test de restauration et la soumission : c'est le travail de Mathéo (§10). M8 lui prépare les textes et la liste des vérifications.
- Les questions ouvertes de M7 sans lien avec la revue (mise à jour atomique du profil, repos par défaut) restent ouvertes.

**Anti-objectifs.**
- Une politique de confidentialité qui promet plus que le code ne fait. Chaque phrase de la politique, du texte d'usage Apple Santé et du manifeste doit être vraie pour le build soumis.
- Perdre une donnée de Mathéo pendant le déplacement. Une valeur n'est retirée d'iCloud qu'une fois écrite dans le magasin local.
- Des étiquettes VoiceOver qui récitent l'interface (« bouton, image, cercle »). Une étiquette dit ce que la chose est et ce qu'elle vaut, en français.

## 3. Découpage

Deux PR, comme M6 et M7 **(choix du constructeur)** :

| Partie | Branche | Contenu |
| :--- | :--- | :--- |
| **M8a** | `m8-confidentialite` | frontière iCloud / appareil, déplacement des données existantes, manifeste, pages publiques, avertissement, textes, document App Store Connect. |
| **M8b** | `m8-accessibilite` | passe d'accessibilité écran par écran, test de contraste, audit automatique en test d'interface, liste de vérification VoiceOver pour Mathéo. |

M8a passe en premier : c'est elle qui conditionne la revue. M8b part de master une fois M8a fusionnée.

| Lot | M8a | M8b |
| :--- | :--- | :--- |
| 1 | stockage : modèles locaux, dépôts qui routent, déplacement, poids du profil, export, tests | design system : contraste, animations, composants partagés |
| 2 | app et publication : manifeste, pages, Info.plist, Paramètres, document App Store Connect | écrans : Aujourd'hui, Entraîner, séance live, récap, compléments |
| 3 | — | écrans : Planning, Stats, Profil, onboarding, widgets ; audit en test d'interface |

## 4. Approches envisagées (frontière iCloud)

1. **Séparer dans la couche de stockage (retenue).** Les types du domaine (`DailyRecovery`, `WorkoutSession`, `BodyMeasurement`) et les services ne changent pas. Les dépôts SwiftData rangent les champs et les lignes venus d'Apple Santé dans de nouveaux modèles du magasin local, et les recomposent à la lecture. La frontière tient dans un seul package, elle se teste sur le magasin lui-même, et elle s'explique simplement à la revue.
2. **Ne plus stocker ces valeurs et les relire du cache Apple Santé à chaque usage.** Plus pur, mais il faut retoucher le moteur, le Pourquoi, les Stats, l'import des courses et le poids : beaucoup de code testé pour un résultat identique côté revue.
3. **Tout passer en local, sans iCloud.** Plus simple, mais la restauration après réinstallation, promise par la spec V1 §4, disparaît.

Mathéo a choisi la frontière « saisi ou calculé par Pulse → iCloud, lu d'Apple Santé → appareil », puis m'a laissé le comment ; l'approche 1 est mon choix **(choix du constructeur)**.

## 5. M8a — Ce qui reste dans iCloud et ce qui passe sur l'appareil

**Règle.** Est « lue d'Apple Santé » toute valeur obtenue par une requête HealthKit, ou recopiée d'une telle valeur sans que l'utilisateur la saisisse ou la valide. Elle vit dans le magasin `local` (jamais synchronisé) ou dans le cache Apple Santé, déjà local.

| Donnée | Aujourd'hui | Après M8a |
| :--- | :--- | :--- |
| Score du jour, catégorie, estimé ou non, sous-scores VFC / FC repos / sommeil, facteurs manquants, calibration, ajustements, figement, choix de la séance d'origine | iCloud | iCloud (calculé par Pulse) |
| SDNN et sa référence, FC repos et sa référence, minutes de sommeil et de sommeil profond | iCloud (`StoredDailyRecovery`) | appareil : nouveau modèle `StoredRecoveryReading`, un par jour |
| Courses et vélos importés (`WorkoutSession.source == .appleHealth`) avec durée, distance, FC moyenne, RPE estimé, RPE corrigé et note | iCloud (`StoredWorkoutSession`) | appareil : nouveau modèle `StoredImportedWorkout` |
| Pesées et masse grasse lues dans Apple Santé (`BodyMeasurement.source == .appleHealth`) | iCloud (`StoredBodyMeasurement`) | appareil : nouveau modèle `StoredImportedBodyMeasurement` |
| Pesées saisies dans Pulse | iCloud | iCloud |
| `UserProfile.weightKg` | iCloud, recopié de la tendance de toutes les pesées | iCloud, seulement depuis les pesées saisies dans Pulse (§5.3) |
| Séances enregistrées dans Pulse (même écrites ensuite dans Apple Santé), séries, records, check-ins, compléments et prises, programme, planning, réglages | iCloud | iCloud (saisis dans Pulse) |
| Valeurs proposées à l'onboarding depuis Apple Santé (poids, date de naissance, sexe) puis validées par l'utilisateur dans le formulaire | iCloud | iCloud : une valeur montrée et validée est une saisie **(choix du constructeur)** |

Les sous-scores restent dans iCloud parce qu'ils expliquent un score passé après une restauration sans révéler la mesure (un 0–100 calculé par Pulse, comme le score) **(choix du constructeur)**.

`StoredScheduledDay.sessionID` peut désigner une course importée : c'est un identifiant, pas une mesure, il reste dans iCloud. Une séance cherchée par identifiant est cherchée dans les deux magasins. Après une désinstallation, la course est réimportée sous un nouvel identifiant et ce lien ne retrouve rien ; la validation du jour est recalculée depuis les séances, donc le planning reste juste.

Le RPE corrigé et la note saisis sur une course importée suivent la course sur l'appareil. C'est la seule saisie de l'utilisateur qui ne passe pas par iCloud **(choix du constructeur)** : la garder dans iCloud demanderait un enregistrement lié à la séance Apple Santé, ce qui rouvre la question 5.1.3(ii). La perte n'arrive qu'en cas de désinstallation, voir §11.

### 5.1 Stockage

- **Schéma V4.** Les trois nouveaux modèles s'ajoutent à `PersistenceStack.localModels`. Les modèles synchronisés ne changent pas : CloudKit en production n'accepte que des ajouts, donc les champs bruts de `StoredDailyRecovery` restent dans le schéma, documentés « plus jamais écrits (M8a) », et ne sont plus remplis. Aucun déploiement de schéma CloudKit n'est nécessaire. Attention : `PulseSchemaV1`, `V2` et `V3` construisent aujourd'hui leur liste avec `PersistenceStack.localModels`, qui lit la liste courante. Ces trois versions doivent donc écrire explicitement l'ancienne liste locale (`StoredCachedHealthSample`, `StoredHealthQueryAnchor`, `StoredActiveSessionSnapshot`), sinon leurs empreintes changent et V3 devient identique à V4. Puis une étape légère V3 → V4 s'ajoute.
- **`StoredRecoveryReading`** : `day` (début du jour local, unique), les six valeurs brutes, `createdAt`, `updatedAt`.
- **`StoredImportedWorkout`** : les champs de `StoredWorkoutSession` utiles à une séance sans séries (identifiant, dates, type, statut, titre, RPE global, note, durée, distance, FC moyenne, RPE estimé, `healthKitUUID`, dates, suppression logique). Le constructeur peut aussi reprendre tous les champs pour garder un seul mapping ; le domaine ne voit pas la différence.
- **`StoredImportedBodyMeasurement`** : mêmes champs que `StoredBodyMeasurement`.
- **Dépôts.**
  - `SwiftDataRecoveryRepository.save` écrit le score sans valeurs brutes dans `StoredDailyRecovery`, et les valeurs brutes dans `StoredRecoveryReading` du même jour (créé, mis à jour, ou supprimé si toutes sont nulles). `dailyRecoveries(from:to:)` recompose chaque jour à partir des deux.
  - `SwiftDataWorkoutRepository` route `save` et `delete` selon `source` ; `sessions(from:to:)` fusionne les deux magasins dans le même ordre qu'aujourd'hui (`startedAt`, puis `createdAt`) ; `session(id:)` cherche dans les deux. `lastSets` ne change pas (une course n'a pas de séries).
  - `SwiftDataBodyMeasurementRepository` route de même selon `source`.
  - Un changement de `source` sur une ligne existante n'arrive pas dans l'app ; s'il arrivait, la ligne est déplacée (écrite d'un côté, supprimée de l'autre).
- **Ordre d'écriture.** Un `save()` qui touche les deux magasins n'est pas garanti atomique entre les deux fichiers. Le déplacement (§5.2) écrit donc en deux temps : il enregistre d'abord les copies locales, puis il vide ou supprime côté synchronisé dans un second `save()` (corrigé après la relecture finale de M8a).

### 5.2 Déplacement de l'existant

Un service `HealthDataRelocation` dans `PulsePersistence` (acteur sur le même conteneur) :

1. Les `StoredDailyRecovery` dont une valeur brute n'est pas nulle : la valeur passe dans `StoredRecoveryReading` du jour (une valeur locale déjà présente l'emporte, elle est plus récente), puis les champs bruts sont mis à nul côté synchronisé.
2. Les `StoredWorkoutSession` avec `source == appleHealth` : une ligne non supprimée est copiée dans `StoredImportedWorkout` si son identifiant n'y est pas déjà ; puis **toutes** ces lignes sont supprimées pour de vrai du magasin synchronisé, y compris celles marquées supprimées (une suppression logique laisse les valeurs dans iCloud). Leurs séries éventuelles partent en cascade.
3. Les `StoredBodyMeasurement` avec `source == appleHealth` : même traitement.
4. Deux `save()` par étape, car un seul n'est pas garanti atomique entre les deux fichiers SQLite : d'abord les copies locales, puis le retrait côté synchronisé. Si le second échoue, il est annulé : rien n'a quitté iCloud, et le passage suivant trouve la copie déjà locale et ne fait plus que vider ou supprimer (relecture finale M8a). Les clés `StoredRecoveryReading.day`, `StoredImportedWorkout.id` et `StoredImportedBodyMeasurement.id` sont uniques.

Le poids du profil (§5.3) a besoin de la tendance, qui vit dans `PulseServices` : ce n'est pas une étape de `HealthDataRelocation` (`PulsePersistence` ne dépend pas de `PulseFeatures`). Le passage du jour appelle `ProfileWeightSync` juste après le déplacement **(choix du constructeur)**.

**Quand ?** Au lancement, avant le premier passage du jour, **et à chaque passage du jour** : iCloud peut redescendre d'anciennes lignes après le lancement (réinstallation, autre appareil encore sur un ancien build). Chaque étape commence par une requête filtrée (champs non nuls, `source`), donc un passage sans rien à déplacer coûte quatre requêtes vides **(choix du constructeur)**. Le service ne garde aucun drapeau « déjà fait ».

**Gardes Apple Santé.** `WorkoutHistory` et `BodyHistory` refusent aujourd'hui une lecture complète vide quand le cache **ou le magasin synchronisé** contient des imports (cas réinstallation). Les imports étant désormais locaux, la garde regarde le cache et les nouveaux modèles locaux. Après une réinstallation, le magasin local est vide, la lecture complète s'applique normalement.

### 5.3 Poids du profil

- `ProfileWeightSync` ne calcule plus la tendance que sur les pesées saisies dans Pulse. Si aucune pesée saisie ne tombe dans sa fenêtre de 30 jours, il prend la dernière pesée saisie. Sans pesée saisie du tout, il ne touche pas au profil, sauf le cas de déplacement ci-dessous.
- Le poids utilisé par l'app (export d'une séance vers Apple Santé, affichage du profil) devient : la tendance de toutes les pesées des 30 derniers jours si elle existe, sinon la dernière pesée, quelles que soient sa source et sa date, sinon `UserProfile.weightKg` (relecture finale M8a). Ce calcul vit dans un endroit unique (`BodyService` ou un petit type pur), appelé par `HealthWorkoutExporter` et l'écran Profil.
- **Déplacement :** s'il existe des pesées Apple Santé et aucune pesée saisie, `UserProfile.weightKg` est mis à nul (la tendance Apple Santé, locale, prend le relais). S'il existe des pesées saisies, il prend leur tendance. Sans pesée du tout, la valeur de l'onboarding reste **(choix du constructeur)**.

### 5.4 Export, suppression, inspection

- L'export JSON et CSV (« tout ») inclut les trois nouveaux modèles : les valeurs brutes reviennent dans les colonnes de score du jour, les courses importées dans les séances, les pesées Apple Santé dans les mesures. Le format de sortie ne change pas pour l'utilisateur.
- `StoreWiper` et l'inspecteur de magasin (écran de debug) couvrent les nouveaux modèles.
- Le jeu d'exemple du debug passe par les dépôts, donc respecte la frontière sans changement.

### 5.5 Tests (M8a lot 1)

- Dépôts : un score enregistré laisse les six champs bruts nuls dans `StoredDailyRecovery` et les retrouve à la lecture ; une course importée n'existe que dans `StoredImportedWorkout` ; une séance Pulse que dans `StoredWorkoutSession` ; `sessions(from:to:)` fusionne et trie ; `session(id:)` trouve les deux ; idem pour les pesées.
- Déplacement : données mixtes avant / après ; lignes supprimées logiquement retirées ; rejouer ne change rien ; une valeur locale existante l'emporte ; le poids du profil dans les trois cas du §5.3.
- **Test de frontière** : après une série d'écritures par tous les dépôts avec des données « Apple Santé », une lecture directe des modèles synchronisés ne trouve aucune valeur brute non nulle, aucune ligne `appleHealth`, et un `weightKg` qui vient d'une pesée saisie.
- Migration V3 → V4 sur un magasin V3 de fixture, test d'empreinte mis à jour.
- Export : les valeurs locales apparaissent dans le JSON et le CSV.

## 6. M8a — Publication et textes

### 6.1 Manifeste de confidentialité

Un `PrivacyInfo.xcprivacy` dans la cible app et un dans l'extension widgets (les packages locaux sont compilés dans ces deux cibles) :
- `NSPrivacyTracking` faux, aucun domaine de suivi.
- `NSPrivacyCollectedDataTypes` vide : Pulse n'envoie rien à son développeur. Le CloudKit privé de l'utilisateur et HealthKit ne sont pas une collecte au sens d'Apple.
- `NSPrivacyAccessedAPITypes` : `UserDefaults` avec la raison `CA92.1` (préférences de l'app). Pas de `1C8F.1` : aucun code livré n'ouvre `UserDefaults(suiteName:)` sur le groupe d'apps, les widgets lisent un fichier du groupe (relecture finale M8a). Le constructeur cherche dans tout le code les autres API à raison déclarée (dates de fichier, temps de démarrage, espace disque, clavier actif) et ajoute ce qu'il trouve avec la bonne raison, ou rien.

### 6.2 Pages publiques

- `docs/confidentialite/index.html` : politique de confidentialité en français, page statique autonome (pas de script, pas de police distante, style papier monochrome de l'app). Contenu : ce que Pulse lit dans Apple Santé et pourquoi ; ce qu'il y écrit ; où vivent les données (appareil ; iCloud privé de l'utilisateur pour ce qu'il saisit et les scores calculés ; les valeurs d'Apple Santé ne sont jamais écrites dans la synchronisation iCloud ; comme toutes les données locales de l'app, elles font partie de la sauvegarde de l'iPhone si elle est activée, et des exports) ; aucun serveur, aucune analytics, aucun tiers, aucune publicité ; rapports de plantage d'Apple seulement si l'utilisateur les partage ; export et suppression depuis l'app ; « pas un dispositif médical » ; date de mise à jour ; contact.
- `docs/support/index.html` : page d'assistance (questions fréquentes : score absent, montre non Apple, calibration, export, suppression ; contact).
- **Contact** : les issues GitHub du dépôt **(choix du constructeur)**. Une adresse e-mail n'est publiée que si Mathéo en donne une.
- **Publication** : GitHub Pages sur `master`, dossier `/docs`, ce qui donne `https://d-seonay.github.io/kairos/confidentialite/` et `/support/`. Un fichier `docs/.nojekyll` empêche Jekyll de transformer les specs et plans en pages (le dépôt est déjà public, rien de nouveau n'est exposé). Activer Pages est une action sur le dépôt : faite par Mathéo, ou par moi avec son accord explicite.
- `PulsePrivacyPolicyURL` dans `Pulse/Info.plist` reçoit l'URL de la politique, ce qui fait apparaître la ligne déjà prévue dans Mes données (M7).

### 6.3 Textes dans l'app

- **Paramètres** : une section « À propos » en bas, avec la version et le build, et la phrase « Pulse n'est pas un dispositif médical. Le score et les ajustements sont des repères d'entraînement, pas un avis médical. » La phrase vit dans une seule chaîne réutilisée par l'onboarding **(choix du constructeur)**.
- **`NSHealthShareUsageDescription`** devient vrai après M8a : « … Ces données restent sur votre iPhone : elles ne sont ni synchronisées ni partagées. » Le texte d'écriture ne change pas. Le texte affiché à l'onboarding (écran Santé) et dans Mes données (état iCloud) est relu dans le même sens.
- **Compléments** : vérifier qu'aucun écran ni aucune suggestion ne propose de dose (spec V1 §11) ; corriger s'il y en a.

### 6.4 Document App Store Connect

`docs/app-store/fiche.md`, à recopier par Mathéo :
- **Confidentialité de l'app** : « Données non collectées », avec la raison.
- **Classification** : questionnaire rempli (pas de contenu sensible ; usage médical : non, l'app n'est pas un dispositif médical).
- **Chiffrement** : déjà déclaré exempt dans l'Info.plist.
- **Notes pour la revue** : pas de compte ; l'app lit Apple Santé ; sans données de sommeil et de VFC, le score affiche la calibration (normal) ; comment voir une séance live et un complément sans données ; aucune donnée de santé dans iCloud.
- **Textes de la fiche** en français : nom (avec une alternative si « Pulse » est pris), sous-titre, description, mots-clés, URL de politique et d'assistance, catégorie (Forme et santé).

## 7. M8b — Accessibilité

### 7.1 Règles pour chaque écran

- **VoiceOver.** Chaque contrôle a une étiquette en français, surtout les boutons à icône seule. Une valeur composée (jauge, tuile, ligne de série, pastille de jour, case de la grille d'assiduité) est un seul élément avec étiquette et valeur (« Récupération, 58 sur 100, fatigue modérée »). Les images décoratives (trame, aura, motifs) sont masquées. La carte musculaire a un résumé (« Travaillés cette semaine : pectoraux, triceps… »). Chaque graphique Swift Charts a une description courte et, si possible, son graphique audio. L'ordre de lecture suit l'ordre visuel.
- **Annonces.** Fin du repos en séance live, record battu au récap, score prêt quand l'accueil se met à jour : une annonce VoiceOver.
- **Dynamic Type jusqu'à Accessibilité XL** (`accessibility3`). Aucun texte tronqué sur une valeur ; les rangées passent en colonne aux tailles d'accessibilité ; les tailles fixes passent par `@ScaledMetric` ; pas de hauteur fixe sur du texte. Le clavier numérique de la séance live et les widgets ont le droit de plafonner leur taille (`dynamicTypeSize(...accessibility3)`) si la mise en page casse au-delà.
- **Contraste AA** sur tout le texte dans le thème clair (seul thème actif) : un test du design system vérifie chaque paire texte / fond des jetons (4,5:1 pour le texte normal, 3:1 pour les grands chiffres et les éléments graphiques porteurs d'information). Le test de palette existant est étendu.
- **Réduire les animations.** Toute animation passe par un utilitaire du design system qui la remplace par un fondu ou rien quand le réglage est actif (jauge, aura, transitions, chrono).
- **Couleur.** La couleur de signal est toujours doublée d'un texte ou d'une forme (catégorie écrite, zone de charge nommée, statut de jour en icône).
- **Cibles tactiles** d'au moins 44 × 44 points.

### 7.2 Vérification

- Les textes d'accessibilité composés sont construits par des fonctions pures, testées comme les autres textes (`StatsText`, `ProfileText`…).
- Chaque écran a un aperçu SwiftUI à `accessibility3`.
- Un test d'interface `AccessibilityAuditUITests` parcourt les cinq onglets, une séance live et le récap avec `performAccessibilityAudit()`. Il est écrit et compilé (`build-for-testing`) ; c'est Mathéo qui le lance (on ne lance jamais le simulateur depuis la session).
- `docs/app-store/verification-accessibilite.md` : la liste de vérification à la main pour Mathéo (VoiceOver écran par écran, Dynamic Type au maximum, Réduire les animations).

## 8. Contraintes et barre de qualité

- Comme chaque jalon : `swift test` vert sur les six packages, `swiftlint lint --strict` à 0, `make build-app` et `make build-release` verts.
- Aucune dépendance nouvelle.
- Pas de simulateur depuis la session ; les vérifications sur iPhone sont listées pour Mathéo.

## 9. Laissé au constructeur

- Le détail des champs de `StoredImportedWorkout` (§5.1) et le nom exact des nouveaux types.
- L'endroit du calcul du poids utilisé (§5.3).
- Le texte exact de la politique, de l'assistance et de la fiche, dans le respect du §6.
- La forme de l'utilitaire d'animation et l'ordre des écrans dans M8b.

## 10. Laissé à Mathéo

- Activer GitHub Pages (ou me donner son accord pour le faire), et une adresse de contact s'il en veut une.
- Remplir App Store Connect à partir de `docs/app-store/fiche.md`, captures d'écran comprises.
- Lancer `AccessibilityAuditUITests` et la liste de vérification VoiceOver sur l'iPhone.
- Vérifier sur l'iPhone, après installation du build M8a, que l'historique (scores, courses, poids) est intact.
- Le test de restauration : désinstaller, réinstaller, retrouver séances, compléments, programme et scores depuis iCloud ; les courses et le poids reviennent par une nouvelle lecture d'Apple Santé (un an) ; le détail brut des nuits passées ne revient pas (§11).
- Les 14 jours d'usage sans perte ni plantage, puis la soumission et les retours de revue.

## 11. Risques

- **Désinstallation puis réinstallation.** Le magasin local repart vide. Les scores passés reviennent d'iCloud, mais sans leur détail brut : Pulse n'écrit le score que du jour, et ne recalcule pas les jours passés depuis le cache des nuits. Les courbes de biométrie des Stats repartent donc du jour de la réinstallation. Les courses et le poids reviennent par la lecture d'Apple Santé sur un an, sans le RPE corrigé ni la note des courses. Accepté sans reconstruction **(choix du constructeur)** : un nouvel iPhone restauré depuis une sauvegarde ou un transfert direct garde le magasin local, donc la perte ne touche que la désinstallation. C'est le prix de la règle 5.1.3(ii).
- **Appareil encore sur un ancien build.** Un appareil resté sur un build d'avant M8a peut réimporter des courses (et des pesées) dans iCloud. Cet appareil-ci les déplace en local et les supprime d'iCloud à chaque passage du jour. Accepté jusqu'à ce que tous les appareils soient à jour.
- **Revue sans données de santé** : le relecteur Apple n'a pas de nuits. Les notes de revue l'expliquent ; un mode démo reste le plan B (§2).
- **Nom « Pulse » déjà pris** sur l'App Store : la fiche propose une alternative, le nom affiché sous l'icône peut rester « Pulse ».
