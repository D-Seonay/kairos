# Pulse V1 — Document de conception

Date : 31 octobre 2026
Statut : brouillon soumis à validation
Auteur : Mathéo Delaunay, rédigé avec Claude
Nom de travail : **Pulse** (nom utilisé par le prototype `maquette.html` ; à confirmer avant la fiche App Store)

Ce document remplace, pour la V1, le périmètre décrit dans `Cahier_des_Charges_Fitness_IA.md` et `Plan_Technique_Detaille_Avant_Dev.md`. Ces deux documents restent la référence pour la vision long terme (running GPS, social, abonnement, backend). Les références « §x.y » renvoient au cahier des charges. Le prototype `maquette.html` reste la référence visuelle et contient des notes de spécification par écran (objet `NOTES`), reprises ici quand elles concernent la V1.

---

## 1. Intention

Pulse est une application iPhone pour les pratiquants qui combinent musculation et course à pied, et qui veulent que leur séance du jour tienne compte de leur état réel du matin plutôt que d'un programme figé.

Elle accompagne trois moments de la journée :

1. **Le matin, avant l'entraînement.** L'app lit la nuit dans Apple Santé (sommeil, variabilité cardiaque, fréquence cardiaque au repos), calcule un score de récupération sur 100, et présente la séance prévue, allégée si nécessaire, avec l'explication en clair. L'utilisateur valide ou rétablit la séance d'origine.
2. **Pendant la séance.** Un carnet de musculation à une main : poids, répétitions, ressenti, chrono de repos automatique visible dans la Dynamic Island et sur l'écran verrouillé. Tout fonctionne sans réseau.
3. **Après la séance.** Récapitulatif, prise des compléments, calendrier et streak, statistiques, évolution des records et des données de santé.

**Pourquoi maintenant.** Mathéo s'entraîne en PPL, court, porte une montre Fitbit dont les données arrivent dans Apple Santé, et n'a aucune app qui relie ces trois choses. Il est le premier utilisateur. L'app est construite en solo avec l'aide d'IA, mais avec le niveau d'exigence d'une publication App Store dès la première version : c'est la discipline qui garde le projet propre.

**Ce qui la distingue** (§1.2) : Hevy et Strong ignorent la biométrie, Whoop et Oura ne tiennent pas de carnet, Fitbod devine la récupération au lieu de la mesurer. Pulse traduit les données de la nuit en modifications concrètes de la séance, et explique pourquoi.

---

## 2. Objectifs, non-objectifs, anti-objectifs

### Objectifs de la V1

- Mathéo utilise Pulse tous les jours d'entraînement, matin, séance et soir, à la place de toute autre app ou note.
- La V1 est acceptée sur l'App Store (revue Apple passée, fiche publiée), même si la diffusion reste confidentielle.
- Saisir une série prend moins de 4 secondes (§1.4). Un téléphone éteint en pleine séance ne perd aucune donnée.
- Le moteur de récupération donne des résultats identiques aux formules du §4 sur un jeu de cas de test, et chaque ajustement de séance est expliqué à l'utilisateur.
- L'architecture permet d'ajouter plus tard un backend (Rust + PostgreSQL), le running GPS, le social et l'Apple Watch sans réécrire le cœur.

### Non-objectifs de la V1 (prévus plus tard, hors périmètre maintenant)

- Tracking GPS de course dans l'app. Les courses enregistrées par la montre sont **lues** depuis Apple Santé et comptent dans la charge, le calendrier et les stats. Les courses peuvent en revanche être **planifiées** dans la semaine (voir §5.4), sans suivi en direct.
- Social : amis, flux, classements, défis, studio de partage 9:16.
- Photos de séance et photos de corps.
- Apple Watch, ceintures Bluetooth, coaching vocal.
- Abonnement et paywall. La V1 est gratuite et complète.
- Backend, comptes utilisateur, synchronisation multi-appareils autre qu'iCloud.
- Android.
- Visualiseur biomécanique 3D (une carte musculaire 2D face et dos suffit).

### Anti-objectifs (ce qui ferait de la V1 un échec même si elle « marche »)

- Une app qui dépend du réseau pour enregistrer une série.
- Un score de récupération affiché sans que l'utilisateur puisse voir d'où il vient.
- Une modification de séance imposée : l'utilisateur garde toujours le bouton « Séance d'origine ».
- Des données de santé brutes (VFC, FC) sur l'écran verrouillé ou dans un widget.
- Un conseil de dosage de complément. L'app ne donne jamais de dose conseillée.
- Une base de code que Mathéo ne comprend pas parce que l'IA l'a écrite trop vite : chaque module doit rester lisible et testé.

---

## 3. Contraintes

- **Équipe** : une personne, peu d'expérience Swift, forte expérience TypeScript, assistée par IA. Les modules doivent être petits, testables sans simulateur, et le code lisible.
- **Plateforme** : iPhone uniquement, Swift et SwiftUI natifs. Compte développeur Apple disponible.
- **Source de données** : Apple Santé (HealthKit) est la seule source biométrique. Les données proviennent d'une montre Fitbit via l'app Google, puis Apple Santé. Pulse ne parle jamais directement à Fitbit.
- **Limite connue** : Apple Santé expose la VFC en **SDNN**, pas en rMSSD. Le moteur travaille donc sur la SDNN et compare l'utilisateur à sa propre ligne de base. Le cahier des charges parle de rMSSD ; la V1 adopte la SDNN sans changer les formules (transformation log, z-score, seuils).
- **Pas de serveur en V1**. Toutes les données restent sur l'appareil, sauvegardées et synchronisées via iCloud (CloudKit privé). Conséquence : aucune obligation d'hébergement de données de santé, pas de compte à créer, pas d'authentification.
- **App Store dès la V1** : politique de confidentialité publiée, manifeste de confidentialité, textes d'usage HealthKit, suppression et export des données depuis l'app, accessibilité de base.
- **Qualité** : tests automatisés sur le moteur et le domaine, intégration continue, TestFlight régulier.

---

## 4. Décisions techniques prises

Ces choix sont faits. Ils sont justifiés brièvement pour que le constructeur ne les rouvre pas sans raison.

| Sujet | Décision | Pourquoi |
| :--- | :--- | :--- |
| Langage, UI | Swift 6, SwiftUI | HealthKit, Live Activities, WidgetKit, future Watch : tout est natif. Choisi par Mathéo. |
| iOS minimum | iOS 26 | Permet le matériau verre natif voulu par la direction artistique. Mathéo est le premier utilisateur et son iPhone le supporte. |
| Persistance | SwiftData avec conteneur CloudKit privé | Sauvegarde et restauration sans serveur. Modèles de domaine **séparés** des modèles SwiftData pour permettre un backend plus tard. |
| Architecture | App fine + packages Swift locaux (voir §9) | Les packages se testent sans simulateur et obligent à des frontières claires. |
| État et injection | `@Observable`, protocoles pour chaque dépendance externe (HealthKit, notifications, horloge, stockage) | Testabilité : le moteur et les écrans se testent avec des doublures. |
| Tests | Swift Testing pour l'unitaire, XCUITest pour un petit nombre de parcours critiques | Standard Apple actuel. |
| Intégration continue | Xcode Cloud (inclus avec le compte développeur) : build + tests à chaque push, TestFlight sur `master` | Zéro infrastructure à maintenir. |
| Lint | SwiftLint avec une configuration stricte mais courte | Garde-fou pour du code écrit par IA. |
| Projet Xcode | Projet unique `Pulse.xcodeproj` avec des packages locaux dans `Packages/`, aucun générateur | Simplicité pour un solo ; le projet change rarement, les packages souvent. |
| Carte musculaire | Silhouettes SVG MuscleMap (licence MIT, mention dans l'app) rendues en SwiftUI `Shape` | Déjà retenu par le prototype. |
| Contenu exercices | Fichier JSON embarqué, versionné, avec identifiants stables. Il **reste dans le bundle** et n'est jamais copié dans SwiftData ; seuls les exercices créés par l'utilisateur sont stockés et synchronisés. Les séries référencent un exercice par identifiant stable (contenu) ou UUID (utilisateur). | Pas de serveur ; le contenu évolue avec l'app ; évite les doublons CloudKit à la restauration. |
| iCloud | Sauvegarde et restauration (nouvel iPhone, réinstallation), pas d'usage simultané sur deux appareils. Résolution « dernier écrit gagne ». Le cache Apple Santé et la séance en cours ne sont pas synchronisés. | Pulse est iPhone seul en V1 ; évite la gestion de conflits. Un test de restauration fait partie de la définition de fini. |
| Télémétrie | Aucune analytics tierce en V1. Crash reports Apple uniquement | Données de santé, un seul utilisateur, moins de déclarations App Store. |

---

## 5. Fonctionnalités V1, écran par écran

L'app a cinq onglets, comme le prototype : **Aujourd'hui**, **Entraîner**, **Planning**, **Stats**, **Profil**. Les noms d'écrans entre crochets sont ceux du prototype (`data-screen`).

### 5.1 Premier lancement [bienvenue, sante, profil-init, objectifs, programme, calibration]

Objectif : moins de 90 secondes jusqu'au premier score.

1. **Bienvenue** : promesse en une phrase, trois bénéfices. Aucune donnée demandée avant « Commencer ».
2. **Apple Santé** : écran d'explication (quelles données, pourquoi, où elles restent) puis la modale native HealthKit. L'écran dit honnêtement que l'iPhone fournit la SDNN. Refus possible : l'app fonctionne alors avec le check-in à trois questions (§5.2).
3. **Profil** : sexe, date de naissance, taille, poids (pré-rempli depuis Apple Santé si disponible). Niveau en musculation et en course (débutant, intermédiaire, confirmé) : fixe les incréments de progression par défaut.
4. **Objectifs** : curseur force / endurance, nombre de jours d'entraînement par semaine, jours de repos imposés, matériel (salle complète, home gym, poids du corps), zones douloureuses (épaules, lombaires, genoux, poignets) qui masquent les mouvements à risque.
5. **Programme** : choix d'un modèle (voir §5.4) ou « je construis le mien ». Le modèle est pré-sélectionné à partir du curseur et des jours disponibles.
6. **Calibration** : import des 60 derniers jours d'Apple Santé, calcul de la ligne de base, premier score affiché avec ses trois facteurs. Si moins de 5 nuits exploitables, l'écran l'explique et propose le check-in.

Le parcours est reprenable : quitter l'app au milieu ramène à l'étape en cours.

### 5.2 Tableau de bord du matin [today, pourquoi, checkin, supplements]

- **Jauge de récupération** sur carte blanche opale, score 0 à 100, catégories et couleurs : optimal 90+, normal 65 à 89, fatigue modérée 40 à 64, surmenage sous 40 (§4.5). Sous la jauge, trois facteurs : sommeil (durée, part de sommeil profond), VFC vs ligne de base 14 jours, FC repos vs 7 jours, chacun avec une sparkline de 14 jours.
- **Carte séance du jour** : titre, muscles ciblés sur une mini-carte face et dos, durée estimée, nombre de séries. Si le moteur a modifié la séance : badge « Ajustée », bouton « Pourquoi ? », bouton « Séance d'origine ». Bouton principal « Démarrer ».
- **Écran Pourquoi** : les trois sous-scores avec la pondération 50 / 25 / 25, puis chaque modification nommée avec sa raison (volume, plafond de RPE, repos, charges). Texte en français courant, pas de jargon sans explication.
- **Jauge de charge ACWR** linéaire : sous-entraînement, zone optimale 0,8 à 1,3, risque au-delà de 1,5 (voir §6.4). Masquée tant qu'il n'y a pas 28 jours d'historique ; un texte explique ce qu'elle deviendra.
- **Carte compléments** : prises du jour et prochaine prise, cochables sans quitter l'accueil.
- **Check-in** (affiché à la place de la jauge quand aucune donnée de nuit n'est disponible) : trois questions, sommeil, douleurs, motivation, pondération 40 / 35 / 25, score recalculé en direct, marqué « estimé ». Un score estimé n'autorise jamais la surcharge progressive.
- **Jour de repos** : la carte séance devient une carte repos avec la prochaine séance et, si le score est bas, une suggestion de mobilité.
- **Check-in et mesures sont exclusifs** : dès qu'au moins deux facteurs mesurés existent, le score est mesuré (poids renormalisés si un facteur manque). Le check-in ne sert que lorsque moins de deux facteurs sont disponibles ; il produit alors seul le score, marqué « estimé ». Pas de score hybride.
- **Mobilité** : en V1, c'est une suggestion textuelle avec un minuteur simple de 20 minutes et quelques consignes, pas une routine tracée. Elle n'entre ni dans la charge, ni dans le streak, ni dans le calendrier.

### 5.3 Compléments [supplements, supplement-new]

- Liste des compléments de l'utilisateur, groupés pour la journée en trois moments : matin, autour de la séance, soir. Le moment « séance » suit l'heure de la séance planifiée, ou l'heure habituelle si rien n'est planifié.
- **Création** : suggestions courantes (créatine, whey, vitamine D3, magnésium, caféine, oméga-3) pré-remplies en deux touches, ou saisie libre. Champs : nom, forme (poudre, gélule, comprimé, liquide), dose et unité (g, mg, UI, ml, dose), moment (heure fixe, avant la séance, après la séance, au coucher), jours (tous, jours d'entraînement, personnalisé), stock en doses et seuil d'alerte, rappel activé ou non.
- **Prise** : une touche coche et horodate. Décoche possible dans la journée. Le stock diminue de la dose. Sous le seuil : pastille d'alerte sur la carte et sur la ligne du complément.
- **Régularité** : taux de prise sur 30 jours par complément, affiché sur la fiche du complément.
- **Rappels** : notification locale à l'heure prévue avec action « Pris » directement depuis la notification.
- **Apple Santé** : écriture des prises quand le type HealthKit existe (vitamine D, magnésium, caféine, protéines). Les autres restent dans Pulse.
- **Conseils** : uniquement sur le moment de prise, factuels, par exemple « la caféine après 16 h réduit le sommeil profond, qui compte dans ton score ». Jamais de dose conseillée. Un rappel discret renvoie à la notice du produit ou à un professionnel de santé.

### 5.4 Programmes et routines [seance, programme, biblio, fiche]

- **Modèles fournis en V1** : PPL (Push / Pull / Legs, 3 ou 6 jours), Haut / Bas (4 jours), Full Body (3 jours), Renforcement coureur (2 jours de musculation orientés jambes, tronc et hanches). Chaque modèle définit ses journées, leurs exercices, le nombre de séries, la fourchette de répétitions, le RPE cible et le repos par exercice.
- **Custom** : création d'une routine à partir de la bibliothèque, réordonnable, avec les mêmes paramètres par exercice. Une routine custom peut être placée dans le cycle hebdomadaire.
- **Changement de programme** : possible à tout moment ; l'historique des séances reste attaché aux exercices, pas au programme.
- **Courses planifiées** : un programme peut contenir des jours de course, définis par un type (facile, fractionné, sortie longue) et une durée ou une distance cible. Pulse ne les suit pas en direct : un jour de course planifié est validé automatiquement quand une course d'Apple Santé tombe ce jour-là, ou à la main. C'est sur ces jours planifiés que les règles anti-interférence agissent. Le modèle Renforcement coureur en contient par défaut ; les autres modèles peuvent en recevoir par glisser-déposer.
- **Programme de la semaine** : vue des sept jours avec les séances et les courses placées, modifiable par glisser-déposer. Les courses lues depuis Apple Santé mais non planifiées apparaissent aussi. Les règles anti-interférence (§6.5) sont affichées, chacune désactivable, et la séance en conflit est surlignée avec la raison.
- **Bibliothèque** : environ 80 exercices en V1, suffisants pour couvrir les modèles et leurs alternatives. Filtres muscle et matériel, récents en tête, recherche insensible aux accents. Chaque exercice : nom FR et EN, muscles moteurs et stabilisateurs, matériel, plan de mouvement, trois consignes, erreurs fréquentes, trois alternatives, incrément de charge par défaut.
- **Exercice personnalisé** : création minimale depuis la bibliothèque (nom, muscle principal, muscles secondaires, matériel, plan de mouvement, haut ou bas du corps). Pas de consignes ni d'alternatives obligatoires. Nécessaire pour que le programme custom ne soit pas bloqué par la bibliothèque de 80.
- **Fiche exercice** : trois onglets, technique (carte musculaire, consignes, erreurs, rappel des limitations déclarées), progression (historique des charges, 1RM estimé par Brzycki §4.6), alternatives.
- **Onglet Entraîner** : séance du jour, routines, bibliothèque, séance libre, saisie d'une séance passée.

### 5.5 Séance en direct [live, remplacer]

- **En-tête** : durée, tonnage cumulé, séries faites sur séries prévues. Écran forcé en noir OLED pendant la séance, luminosité normale.
- **Liste des exercices** dans l'ordre, chaque exercice avec ses lignes de séries : numéro (type échauffement, normale, drop, échec par touche sur le numéro), précédent (poids × reps de la dernière fois), poids, reps, RPE facultatif, bouton de validation d'au moins 56 pt.
- **Valeurs proposées** par le moteur en couleur d'accent ; une valeur modifiée repasse en couleur neutre. Clavier numérique grand format intégré, pas de clavier système.
- **Échauffement automatique** activable sur les exercices de base : deux ou trois séries progressives (barre seule, 60 %, 80 %) arrondies aux disques disponibles, repos 60 s, hors volume et hors records. Pas d'échauffement si le muscle vient d'être travaillé.
- **Calculateur de disques** sur les exercices à la barre : disques par côté pour la prochaine série, selon la barre et les disques déclarés dans les paramètres.
- **Chrono de repos** : part à la validation d'une série, durée propre à l'exercice, −30 s, +30 s, Passer. Visible dans l'app, dans la Dynamic Island, sur l'écran verrouillé (Live Activity) avec les mêmes boutons. Haptique longue et notification au terme, même app en arrière-plan.
- **Remplacer** : trois alternatives conservant le plan de mouvement, avec charge équivalente proposée. Le repos et le plafond RPE du jour sont conservés. Raisons : machine occupée, douleur, autre.
- **Ajouter un exercice** en cours de séance, supprimer, réordonner.
- **Persistance** : chaque validation est écrite localement immédiatement. Si l'app est tuée, un bandeau « Reprendre la séance » s'affiche à la réouverture avec le temps écoulé correct.
- **Terminer** : passe au récapitulatif. Abandonner garde les séries faites et marque la séance incomplète.

### 5.6 Récapitulatif [recap]

- Durée, tonnage, séries, records battus (poids max, 1RM estimé, reps à charge donnée).
- Carte des muscles travaillés avec intensité selon les séries.
- RPE global par curseur de 1 à 10, avec la phrase qui explique l'effet sur la charge et sur demain.
- Rappel des compléments « après la séance », cochables ici.
- Note libre. Bouton Enregistrer. La séance est écrite dans Apple Santé comme entraînement de musculation (durée, calories estimées).

### 5.7 Planning et streak [planning, seance-passee]

- Calendrier mensuel lundi à dimanche. Jour validé : pastille blanche avec l'icône de la discipline (haltère, chaussure pour les courses lues d'Apple Santé). Point pour double séance ou record. Cerclage « aujourd'hui ».
- Pilier vertical de série à droite : une coche par semaine réussie, anneau pour la semaine en cours, flamme avec le compteur. Une semaine est réussie quand le nombre de séances prévues est atteint (défini par le programme, ajustable). Les courses planifiées comptent dans ce total ; une course non planifiée lue d'Apple Santé compte aussi, mais une marche ou un vélo non.
- Semaine courante en liste dessous, avec les déplacements décidés par les règles anti-interférence.
- Détail d'une séance passée : exercices, séries, records, note, carte musculaire. Modifiable.

### 5.8 Statistiques [stats]

Cinq vues avec une période commune (semaine, mois, trois mois, année) :

- **Charge** : courbe ACWR avec bande optimale et seuil de risque, charge hebdomadaire muscu et course.
- **Biométrie** : VFC vs ligne de base, FC repos, sommeil, répartition des journées par catégorie de forme.
- **Muscles** : carte de chaleur face et dos sur la période (moteur compte 1, stabilisateur 0,5), muscles les plus travaillés, muscles délaissés, équilibre pousser / tirer et haut / bas.
- **Assiduité** : matrice 7 jours × 16 semaines à cinq niveaux, streak actuel et record, séances totales.
- **Records** : 1RM estimés sur squat, développé couché, soulevé de terre, développé militaire, plus tout exercice avec au moins cinq séances ; meilleurs chronos 5 km, 10 km, semi, lus depuis Apple Santé.

### 5.9 Profil, paramètres, données [profil, parametres, donnees, corps]

- **Profil** : identité, poids actuel (depuis Apple Santé, tendance lissée sur 7 jours), badges de régularité, mur des records, accès stats et paramètres. Le suivi du corps en V1 se limite au poids et à la masse grasse lus depuis Apple Santé, avec saisie manuelle possible du poids ; pas de mensurations ni de photos.
- **Paramètres** : Apple Santé (état des autorisations, dernière lecture, relire maintenant) ; moteur d'adaptation (activé, règles anti-interférence une par une, incréments de progression) ; séance (échauffement automatique, repos par défaut 60 / 90 / 120 / 180 s, barre et disques disponibles, unités kg ou lb) ; affichage (ambiance ambre ou améthyste) ; notifications (score du matin, rappels compléments, fin de repos).
- **Mes données** : export JSON et CSV de tout (séances, séries, scores, compléments), état iCloud, suppression totale des données locales et iCloud avec confirmation, liens vers la politique de confidentialité et les licences.

### 5.10 Widgets et Live Activity [ios-accueil, ios-verrouille, ios-island]

- Widgets écran d'accueil : petit « Récupération » (score et catégorie), petit « Série » (streak), moyen « Séance du jour » (titre, muscles, séries). Écran verrouillé : jauge circulaire du score, texte en ligne. Données via App Group, timeline rechargée après le calcul du matin.
- Live Activity de séance : compacte (icône, repos restant), étendue (anneau, série suivante, −30 s, +30 s, Passer, Pause). Le compte à rebours utilise un minuteur système, sans mise à jour par seconde.
- Rien de plus sensible que le score et le titre de séance sur l'écran verrouillé.

### 5.11 Notifications

- « Ton score du matin est prêt » quand les données de la nuit ont été traitées (optionnel, heure plafond configurable).
- Rappels de compléments avec action « Pris ».
- Fin du repos.
- Aucune notification marketing.

---

## 6. Moteur d'adaptation physiologique

Le moteur est un package Swift pur, sans dépendance à SwiftUI ni HealthKit, déterministe, testé sur des fixtures. Il prend des séries de valeurs datées et rend un score, une catégorie, un détail par facteur et une liste d'ajustements à appliquer à une séance.

### 6.1 Entrées

- VFC nocturne : pour chaque nuit, moyenne des échantillons SDNN entre le coucher et le lever. Si aucune nuit délimitée, moyenne des échantillons entre 0 h et 8 h.
- FC repos : valeur quotidienne Apple Santé « fréquence cardiaque au repos ».
- Sommeil : durée totale endormie et durée de sommeil profond, à partir des phases. Si la source ne fournit pas de phases, la part profonde est considérée inconnue et le score sommeil repose sur la durée seule (poids 100 au lieu de 70 / 30).
- Séances : durée et RPE de chaque séance de musculation (Pulse) et de chaque **course** lue dans Apple Santé. Les marches ne comptent jamais dans la charge. Les sorties vélo comptent avec un RPE plafonné à 5. RPE d'une course importée : estimé depuis la FC moyenne rapportée à la FC max théorique (sous 70 % : 4, 70 à 80 % : 6, 80 à 90 % : 8, au-delà : 9), sinon 6 par défaut. Une course est dite **intense** pour les règles anti-interférence si son RPE estimé est d'au moins 8 ou si elle est planifiée comme fractionné.

### 6.2 Formules (reprises du §4 du cahier des charges)

- VFC : transformation ln, moyenne et écart-type échantillon sur 14 jours glissants (nuit du jour exclue), z-score, puis score par paliers du §4.2.
- FC repos : écart à la moyenne 7 jours, score par paliers du §4.3.
- Sommeil : `min(1, H/8) × 70 + min(1, Rprofond/0,20) × 30` (§4.4).
- Score global : `0,50 × VFC + 0,25 × FC + 0,25 × Sommeil` (§4.5).

### 6.3 Cas limites (décisions de ce document)

- **Moins de 14 nuits** : la ligne de base se calcule dès 5 nuits sur la fenêtre disponible, le score est marqué « en calibration » et n'autorise pas la surcharge progressive. Sous 5 nuits, check-in.
- **Écart-type nul ou très faible** : plancher de 0,05 en unités log pour éviter un z-score explosif.
- **Facteur manquant** (par exemple pas de VFC cette nuit mais sommeil et FC présents) : le score se calcule sur les facteurs présents avec les poids renormalisés, et l'écran Pourquoi indique le facteur manquant. Si deux facteurs sur trois manquent, check-in.
- **Nuit en cours** : le score du jour se calcule à la première ouverture après 4 h du matin, ou à la livraison en arrière-plan des données, et se recalcule si de nouvelles données arrivent avant midi. Il est figé à midi.

### 6.4 Charge et ACWR (§2.5 du plan technique)

- Charge d'une séance = durée en minutes × RPE. Charge aiguë = somme 7 jours, chronique = moyenne des quatre dernières semaines. ACWR = aiguë / chronique.
- Zone optimale 0,8 à 1,3, risque au-delà de 1,5. Au-delà de 1,5 deux jours de suite : proposition d'une semaine de décharge (volume −40 %, charges −10 %), acceptable ou refusable.
- Affiché seulement avec 28 jours d'historique.

### 6.5 Ajustements de séance

À partir de la catégorie du jour, le moteur produit des **ajustements nommés**, chacun avec une raison :

| Catégorie | Musculation | Course lue ou planifiée |
| :--- | :--- | :--- |
| Optimal 90+ | Volume 100 %. Surcharge progressive proposée si la règle de progression est satisfaite. | Rien à signaler. |
| Normal 65 à 89 | Volume 100 %, charges de la dernière fois, repos +15 s. | Rien. |
| Fatigue modérée 40 à 64 | −20 % de séries (arrondi, au moins une série par exercice), RPE plafonné à 7,5, repos +45 s. | Suggestion de remplacer un fractionné planifié par une sortie facile. |
| Surmenage sous 40 | Séance lourde remplacée par 20 min de mobilité ou repos, au choix. | Suggestion de repos. |

**Règle de progression** (double progression) : quand toutes les séries de travail d'un exercice ont atteint le haut de la fourchette de répétitions à RPE ≤ 8 lors de la dernière séance, la charge proposée augmente de l'incrément de l'exercice (par défaut 2,5 kg haut du corps, 5 kg bas du corps, arrondi aux disques disponibles). Sinon la charge reste et les répétitions cibles montent d'une.

**Règles anti-interférence** (§3.5), chacune désactivable dans les paramètres :

1. Pas de fractionné ou de sortie intense dans les 36 h après une séance de jambes lourde. L'app déplace la séance et dit pourquoi.
2. Musculation et course le même jour : la plus technique le matin, au moins 6 h entre les deux.
3. Un jour de repos complet tous les 7 à 10 jours si le score de sommeil cumulé est bas.

L'utilisateur peut toujours refuser un ajustement. Les refus sont enregistrés pour les statistiques d'adhésion (donnée locale, non envoyée).

---

## 7. Apple Santé (HealthKit)

- **Lecture** : analyse du sommeil (phases), VFC SDNN, FC repos, FC (pour les courses), entraînements de type course et vélo (la marche n'est pas importée en V1), poids, masse grasse, taille, date de naissance, sexe.
- **Écriture** : entraînements de musculation (type traditionalStrengthTraining, durée, énergie estimée), compléments quand le type existe (vitamine D, magnésium, caféine, protéines), poids si saisi manuellement.
- **Arrière-plan** : livraison en arrière-plan activée pour le sommeil, la VFC et la FC repos, avec requêtes d'observation et ancres pour ne lire que les nouveautés. Toute ouverture de l'app déclenche aussi une lecture incrémentale.
- **Première lecture** : 60 jours d'historique, affichée avec progression.
- **Honnêteté** : l'écran Apple Santé des paramètres montre, par type de donnée, la dernière valeur reçue et sa source (nom de l'app émettrice), pour que l'utilisateur voie si Fitbit alimente bien tout.
- **Autorisation refusée ou partielle** : l'app fonctionne, le check-in remplace les facteurs manquants, et l'écran explique comment réactiver dans Réglages.

---

## 8. Modèle de données

Entités de domaine (types Swift purs). Les modèles SwiftData correspondants portent les mêmes champs plus `createdAt`, `updatedAt`, `deletedAt` (suppression logique), pour préparer une synchronisation serveur ultérieure. Tous les identifiants sont des UUID générés côté appareil.

- **UserProfile** : sexe, date de naissance, taille, niveau muscu, niveau course, curseur force / endurance, jours d'entraînement, jours de repos imposés, matériel, zones douloureuses, unités, préférences moteur, barre et disques.
- **Exercise** (contenu embarqué, non modifiable sauf exercices créés par l'utilisateur) : noms, muscles moteurs, stabilisateurs, matériel, plan de mouvement, consignes, erreurs, alternatives, incrément par défaut, repos par défaut, catégorie haut / bas, drapeau « base » pour l'échauffement.
- **Program** : nom, origine (modèle ou custom), liste de **RoutineDay** ordonnés, séances par semaine attendues.
- **RoutineDay** : nom, nature (musculation ou course), et selon la nature : liste de **RoutineExercise** (exercice, séries, fourchette de reps, RPE cible, repos) ou paramètres de course (type facile / fractionné / longue, durée ou distance cible).
- **UserExercise** : exercice créé par l'utilisateur, champs minimaux du §5.4, stocké et synchronisé.
- **WorkoutSession** : date de début, fin, routine d'origine, statut (en cours, terminée, abandonnée), ajustements appliqués et refusés, RPE global, note, tonnage, source (Pulse ou Apple Santé pour les courses importées), identifiant HealthKit si écrit.
- **WorkoutSet** : séance, exercice, ordre, type, poids et reps proposés, poids et reps réalisés, RPE, repos, horodatage de validation, record battu.
- **DailyRecovery** : date, score, catégorie, sous-scores, valeurs brutes (SDNN nuit, ligne de base, FC repos, durée et profond), estimé ou mesuré, facteurs manquants, ajustements générés.
- **CheckIn** : date, trois réponses.
- **Supplement** : nom, forme, dose, unité, moment, heure, jours, stock, seuil, rappel, type HealthKit éventuel, archivé.
- **SupplementIntake** : complément, horodatage, dose, écrit dans Apple Santé ou non.
- **BodyMeasurement** : date, poids, masse grasse, source.
- **PersonalRecord** : exercice, type (poids max, 1RM estimé, reps à charge), valeur, date, séance.

Le cache des données Apple Santé (nuits, FC repos, courses) est une table locale **HealthSample** reconstructible : on peut la vider et relire Apple Santé sans perdre de donnée propre à Pulse.

---

## 9. Structure du code

```
Pulse.xcodeproj
Pulse/                      app : composition, navigation, onglets
PulseWidgets/               widgets + Live Activity
Packages/
  PulseDomain/              entités, règles métier, protocoles de dépôt. Zéro import Apple hors Foundation.
  PulseRecoveryEngine/      scores, ACWR, ajustements, progression, anti-interférence. Pur, testé sur fixtures.
  PulsePersistence/         SwiftData + CloudKit, mapping domaine, migrations, export, suppression.
  PulseHealth/              HealthKit : autorisations, lectures ancrées, écriture, arrière-plan.
  PulseContent/             JSON des exercices et des modèles de programme, chargement, versions.
  PulseDesignSystem/        tokens (§7.2), composants (carte opale, carte obsidienne, jauge, pilules, clavier numérique, carte musculaire).
  PulseFeatures/            un module par onglet : Today, Train, Plan, Stats, Profile, Onboarding, Supplements.
docs/superpowers/specs/     ce document
docs/superpowers/plans/     plan d'implémentation
```

Règles : les features dépendent du domaine, du moteur, du design system et des protocoles, jamais de la persistance ni de HealthKit directement. L'app assemble les implémentations concrètes.

---

## 10. Design

- Direction artistique du §7.1 : fond noir profond, aura ambrée, cartes opale blanches pour les métriques clés, cartes obsidienne en verre pour le reste, squircles 28 pt, pilules, sparklines. Ambiance améthyste en option.
- Tokens du §7.2 traduits en Swift dans `PulseDesignSystem`.
- Typographie : SF Pro, chiffres tabulaires pour toute valeur numérique, Dynamic Type respecté jusqu'à la taille accessibilité « XL » au minimum.
- Mode séance : noir pur, contrastes maximaux, cibles de 56 pt.
- Haptiques : léger à la modification d'une valeur, double à la validation d'une série, long à la fin du repos.
- Animations : réduites si « Réduire les animations » est activé.
- Le prototype `maquette.html` et `assets/maquette_v2_planche.png` sont la référence de mise en page. En cas de conflit entre le prototype et ce document, ce document prime pour le périmètre, le prototype pour l'apparence.

---

## 11. Confidentialité, App Store, accessibilité

- **Données** : tout reste sur l'appareil et dans l'iCloud privé de l'utilisateur. Aucun serveur Pulse, aucune analytics tierce.
- **Politique de confidentialité** : page publique hébergée (GitHub Pages du dépôt), liée dans l'app et dans la fiche App Store.
- **HealthKit** : textes d'usage explicites pour lecture et écriture ; l'app ne lit que les types nécessaires ; aucune donnée de santé dans les widgets au-delà du score.
- **Manifeste de confidentialité** et déclaration « Nutrition Labels » App Store à jour.
- **Suppression** : bouton de suppression totale (local + CloudKit) et export JSON / CSV, tous deux sans contact support.
- **Accessibilité** : étiquettes VoiceOver sur chaque contrôle, Dynamic Type, contraste AA sur le texte, pas d'information portée par la seule couleur (catégorie toujours nommée).
- **Avertissement santé** : l'app n'est pas un dispositif médical, mention à l'onboarding et dans les paramètres. Pas de dose de complément conseillée.
- **Localisation** : français en V1, chaînes externalisées dès le départ pour un anglais ultérieur.

---

## 12. Qualité et livraison

- **Tests unitaires** (Swift Testing) : moteur (chaque formule, chaque palier, chaque cas limite du §6.3, fixtures de 30 jours synthétiques), progression, anti-interférence, mapping domaine / persistance, export.
- **Tests d'interface** (XCUITest), trois parcours : onboarding jusqu'au premier score avec données simulées ; séance complète avec arrêt forcé de l'app et reprise ; création d'un complément et prise depuis la notification.
- **Données simulées** : un fournisseur HealthKit factice pilotable pour le simulateur et les tests, avec des scénarios (bonne nuit, mauvaise nuit, données manquantes, 3 nuits seulement).
- **CI** : Xcode Cloud, build + tests sur chaque push, TestFlight interne à chaque merge sur `main`.
- **Définition de fini pour la V1** : les trois parcours passent, l'app tourne 14 jours sur le téléphone de Mathéo sans perte de donnée ni crash, une désinstallation puis réinstallation restaure tout depuis iCloud, la revue App Store est passée.

---

## 13. Risques et vérifications à faire en premier

| Risque | Vérification |
| :--- | :--- |
| La chaîne Fitbit → app Google → Apple Santé n'écrit pas tous les types attendus (phases de sommeil, SDNN nocturne, FC repos) ou avec un délai. | **Semaine 1** : petite app de diagnostic qui liste par type la dernière valeur, sa source et son heure. Décide si la SDNN nocturne est exploitable ou si le score VFC passe en facteur optionnel. |
| Livraison en arrière-plan HealthKit irrégulière. | Lecture incrémentale à chaque ouverture ; le score ne dépend jamais de l'arrière-plan pour exister. |
| Live Activity et budget de mises à jour. | Minuteur système, mises à jour seulement sur action utilisateur. |
| SwiftData + CloudKit : contraintes (pas d'unicité, relations optionnelles) et migrations. | Modèles SwiftData simples, logique dans le domaine, test de migration dès le premier changement de schéma. |
| Courbe d'apprentissage Swift. | Packages petits, un seul concept nouveau par étape du plan, tests avant interface. |
| Dérive de périmètre vers le running, le social, les photos. | Ce document : tout ce qui est dans « non-objectifs » attend la V2. |

---

## 14. Laissé au constructeur

- Détail des 80 exercices et des modèles de programme (contenu), tant que les champs du §5.4 sont remplis.
- Découpage fin de la navigation, animations, micro-interactions, dans le respect du prototype.
- Choix des composants SwiftUI, stratégie de prévisualisation, organisation interne de chaque package.
- Format exact de l'export CSV.
- Calendrier détaillé : il sera produit dans le plan d'implémentation.

---

## 15. Après la V1 (pour mémoire, hors périmètre)

V2 : running GPS natif avec Live Activity et annonces vocales, Apple Watch (miroir du repos, FC en direct), photos de séance et de corps, abonnement via StoreKit 2.
V3 : backend Rust + PostgreSQL (comptes, sync multi-appareils, social, classements), export vers Strava et Garmin, Android.

L'architecture de la V1 prépare cela par : identifiants UUID côté client, horodatages et suppression logique sur toutes les entités, domaine indépendant de la persistance, moteur pur portable (réécrivable en Rust à l'identique grâce aux fixtures partagées).
