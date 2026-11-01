# Pulse V1 — Feuille de route des plans d'implémentation

**Spec :** `docs/superpowers/specs/2026-10-31-pulse-v1-design.md`

La V1 est trop large pour un seul plan exécutable. Elle est découpée en huit jalons séquentiels. Chaque jalon livre un logiciel qui tourne et se teste seul, et reçoit son propre plan détaillé **au moment où il démarre**, pour qu'il parte du code réel et non d'hypothèses. Le plan du jalon 1 est écrit : `2026-10-31-pulse-m1-fondations-moteur.md`.

Environnement d'exécution : **macOS avec Xcode 26** (le dépôt est aujourd'hui ouvert depuis Windows ; tout le travail Swift se fait sur Mac). Un seul développeur assisté par IA ; les durées sont indicatives.

| # | Jalon | Livrable visible | Durée indicative |
| :-- | :--- | :--- | :--- |
| M1 | Fondations et moteur | App TestFlight qui lit Apple Santé, affiche par type la dernière valeur et sa source, et calcule un score de récupération provisoire. Moteur testé sur fixtures. CI en place. | 2 à 3 semaines |
| M2 | Données et contenu | Persistance SwiftData + iCloud, dépôts, 80 exercices et 4 modèles de programme en JSON, export et suppression totale. | 2 semaines |
| M3 | Onboarding et tableau de bord | Les six écrans du premier lancement, l'accueil complet (jauge, facteurs, séance du jour, Pourquoi, check-in, repos), livraison en arrière-plan, notification du matin, widget Récupération. | 3 semaines |
| M4 | Programmes et séance en direct | Onglet Entraîner, bibliothèque, fiche, routines, exercice perso, séance live, chrono de repos en Live Activity, disques, échauffement, remplacement, reprise, récap, écriture Apple Santé, records. | 4 semaines |
| M5 | Compléments | Liste, création, prise, stock et seuil, rappels avec action « Pris », écriture Apple Santé, régularité 30 jours, carte sur l'accueil et dans le récap. | 1 à 2 semaines |
| M6 | Planning, streak, anti-interférence | Calendrier mensuel, pilier de série, programme de la semaine par glisser-déposer, courses planifiées, import des courses, règles anti-interférence, décharge, détail d'une séance passée, widgets Série et Séance du jour. | 3 semaines |
| M7 | Stats et profil | Cinq vues de statistiques, profil et records, poids depuis Apple Santé, paramètres complets, écran Mes données. | 2 à 3 semaines |
| M8 | App Store | Accessibilité, politique de confidentialité, manifeste, trois tests d'interface, test de restauration iCloud, 14 jours d'usage réel, captures, soumission. | 2 semaines |

## Détail par jalon

### M1 — Fondations et moteur
Plan : `2026-10-31-pulse-m1-fondations-moteur.md`.
Contenu : projet Xcode, packages `PulseDomain`, `PulseRecoveryEngine`, `PulseHealth`, formules du §6 (VFC, FC repos, sommeil, global, check-in, ACWR), agrégation des nuits, lecture HealthKit, écran de diagnostic, SwiftLint, Xcode Cloud, TestFlight.
Fini quand : le score provisoire s'affiche sur l'iPhone de Mathéo à partir de ses vraies données, l'écran de diagnostic dit quels types Fitbit alimente, et `make test` est vert en CI.
Décision attendue en sortie : la SDNN nocturne est-elle exploitable ? Si non, le facteur VFC devient optionnel par défaut (déjà prévu par le moteur).

### M2 — Données et contenu
Contenu : package `PulsePersistence` (modèles SwiftData miroirs du §8, mapping domaine, conteneur CloudKit privé, suppression logique, export JSON et CSV, suppression totale), package `PulseContent` (schéma JSON des exercices et des modèles, 80 exercices, PPL 3 et 6 jours, Haut/Bas, Full Body, Renforcement coureur, validation du contenu par test), table `HealthSample` reconstructible.
Fini quand : les dépôts passent leurs tests, un écran de debug liste le contenu chargé, un export produit un fichier lisible, la suppression vide tout.

### M3 — Onboarding et tableau de bord
Découpage : M3 est scindé en M3a (plan `2026-11-01-pulse-m3a-onboarding-score.md`, fait) et M3b (plan à écrire au démarrage), tous deux sous la spec `2026-11-01-pulse-m3-onboarding-tableau-de-bord-design.md`. M3a a livré le design system, l'onboarding jusqu'au premier score, le cycle de vie du score du jour, le check-in, l'accueil simple, la fausse source Apple Santé à scénarios et le test d'interface ; M3b reprend les ajustements de séance, le Pourquoi, l'arrière-plan, la notification du matin et les widgets.
Contenu : `PulseDesignSystem` (tokens, carte opale, carte obsidienne, jauge filaire, pilules, sparkline, carte musculaire face et dos), feature Onboarding (6 écrans, reprise, calibration 60 jours), feature Today (jauge, facteurs, carte séance avec Ajustée / Pourquoi / Séance d'origine, ACWR masqué sous 28 jours, check-in, jour de repos, mobilité 20 min), livraison HealthKit en arrière-plan et lecture ancrée, figement du score à midi, notification « score prêt », widget petit Récupération et widget d'écran verrouillé, fournisseur HealthKit factice avec scénarios pour le simulateur.
Fini quand : parcours d'onboarding en test d'interface jusqu'au premier score avec données simulées ; l'accueil affiche le score réel chaque matin.

### M4 — Programmes et séance en direct
Contenu : extension du moteur (ajustements nommés du §6.5, règle de progression, charge équivalente au remplacement), feature Train (séance du jour, routines, bibliothèque, fiche à trois onglets, exercice perso, séance libre, saisie a posteriori), séance live (clavier numérique, types de série, valeurs proposées en accent, échauffement automatique, calculateur de disques, chrono de repos, Live Activity avec App Intents, remplacement, ajout et réordonnancement, persistance à chaque validation, bandeau Reprendre), récap (bilan, carte musculaire, RPE global, note, écriture HealthKit), records personnels.
Fini quand : test d'interface « séance complète avec arrêt forcé et reprise » passe ; Mathéo fait ses séances PPL dans Pulse.

### M5 — Compléments
Contenu : feature Supplements (liste par moment, création avec suggestions, prise et décoche, stock et seuil, régularité 30 jours, rappels avec action « Pris », écriture HealthKit pour vitamine D, magnésium, caféine, protéines, conseils factuels sur le moment), carte Compléments sur l'accueil et dans le récap.
Fini quand : test d'interface « créer un complément et le prendre depuis la notification » passe.

### M6 — Planning, streak, anti-interférence
Contenu : feature Plan (calendrier mensuel, pastilles et icônes, pilier de série, semaine courante, détail d'une séance passée modifiable), programme de la semaine (glisser-déposer, jours de course planifiés avec type et cible, validation automatique par une course Apple Santé), import des courses et vélos avec RPE estimé depuis la FC, règles anti-interférence désactivables et explication du déplacement, proposition de décharge sur ACWR ≥ 1,5 deux jours de suite, widgets Série et Séance du jour, enregistrement des refus d'ajustement.
Fini quand : les règles sont testées sur fixtures de semaines types ; le calendrier reflète un mois réel d'usage.

### M7 — Stats et profil
Contenu : feature Stats (charge, biométrie, muscles avec carte de chaleur et équilibres, assiduité 7 × 16, records avec chronos lus d'Apple Santé), feature Profile (identité, poids lissé 7 jours et masse grasse depuis Apple Santé, saisie manuelle du poids, badges, mur des records), paramètres complets du §5.9, écran Mes données (export, iCloud, suppression, politique, licences dont MuscleMap), ambiance améthyste.
Fini quand : chaque vue a un test de calcul sur fixtures et un aperçu SwiftUI.

### M8 — App Store
Contenu : passe VoiceOver et Dynamic Type sur chaque écran, contraste, « Réduire les animations », politique de confidentialité sur GitHub Pages, manifeste de confidentialité, textes HealthKit relus, déclaration App Store, avertissement « pas un dispositif médical », test de restauration iCloud, 14 jours d'usage sans perte ni crash, captures d'écran, fiche, soumission, correction des retours de revue.
Fini quand : l'app est disponible sur l'App Store.

## Ordre et dépendances

M1 → M2 → M3 → M4 → M5 → M6 → M7 → M8. M5 peut être intercalé plus tôt (après M3) si Mathéo veut les rappels de compléments avant la séance live ; il ne dépend que de M2 et M3.

## Hors V1

Running GPS, Apple Watch, photos, abonnement, social, backend Rust, Android : voir §15 de la spec.
