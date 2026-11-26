<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/logo-dark.png">
    <img src="assets/logo.png" width="128" height="128" alt="Logo de Pulse : tracé de pouls en trame de points">
  </picture>
</p>

<h1 align="center">Pulse</h1>

<p align="center">
  <strong>L'application iOS native pour les athlètes hybrides musculation & course à pied.</strong><br>
  Adapte automatiquement la séance du jour à la récupération physiologique réelle mesurée par Apple Santé (HealthKit).
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-iOS%2026%2B-black?style=flat-square&logo=apple" alt="iOS 26+">
  <img src="https://img.shields.io/badge/Swift-6.0-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift 6">
  <img src="https://img.shields.io/badge/UI-SwiftUI-007AFF?style=flat-square" alt="SwiftUI">
  <img src="https://img.shields.io/badge/HealthKit-Biom%C3%A9trie-red?style=flat-square" alt="HealthKit">
  <img src="https://img.shields.io/badge/Storage-SwiftData%20%2B%20CloudKit-34C759?style=flat-square" alt="SwiftData">
  <img src="https://img.shields.io/badge/Privacy-100%25%20Local--First-8E8E93?style=flat-square" alt="Privacy First">
  <a href="https://github.com/D-Seonay/pulse/actions/workflows/ci.yml"><img src="https://github.com/D-Seonay/pulse/actions/workflows/ci.yml/badge.svg?branch=master" alt="CI"></a>
</p>

<p align="center">
  <a href="https://apps.apple.com/fr/app/pulse-r%C3%A9cup%C3%A9ration-muscu/id6829265826">
    <img src="site/public/badges/app-store-fr.svg" height="48" alt="Télécharger Pulse - Récupération &amp; Muscu dans l'App Store">
  </a>
</p>

---

## 📑 Sommaire

- [1. Intention & Philosophie](#1-intention--philosophie)
- [2. Les 3 Moments Clés](#2-les-3-moments-clés)
- [3. Moteur Physiologique (PulseRecoveryEngine)](#3-moteur-physiologique-pulserecoveryengine)
- [4. Architecture Technique & Modularisation](#4-architecture-technique--modularisation)
- [5. Arborescence du Projet](#5-arborescence-du-projet)
- [6. Feuille de Route & Reste à Faire](#6-feuille-de-route--reste-à-faire)
- [7. Démarrage Rapide & Développement](#7-démarrage-rapide--développement)
- [8. Tests & Qualité](#8-tests--qualité)
- [9. Confidentialité & Données Santé](#9-confidentialité--données-santé)
- [10. Crédits & Licence](#10-crédits--licence)

---

## 1. Intention & Philosophie

Les pratiquants qui combinent la musculation intensive (programmes Push/Pull/Legs, Haut/Bas, Full Body) et la course à pied font face à un vide d'outillage majeur :
- **Hevy et Strong** ignorent totalement la biométrie et imposent un volume figé.
- **Whoop et Oura** mesurent la récupération mais ne proposent aucun carnet d'entraînement en musculation.
- **Fitbod** tente de deviner la fatigue musculaire sans exploiter les données physiologiques réelles.

**Pulse** fait le pont entre ces mondes : l'application lit les biométries nocturnes issues d'Apple Santé (provenant par exemple d'une Apple Watch ou d'une montre Fitbit synchronisée), calcule un score de récupération scientifiquement éprouvé, et ajuste concrètement la séance de musculation prévue (volume, plafond de RPE, temps de repos, charges).

### Principes Directeurs
- **Transparence totale** : Aucun score magique. L'écran *« Pourquoi ? »* détaille chaque pondération et explicite chaque modification suggérée.
- **Souveraineté de l'athlète** : Une adaptation n'est jamais imposée. L'utilisateur peut à tout instant rétablir la *« Séance d'origine »* en un geste.
- **100% Hors-ligne & Zéro Télémétrie** : Vos données de santé restent sur votre appareil et dans votre conteneur privé iCloud. Aucun serveur tiers, aucun tracker d'analytics.
- **Performance & Clarté** : Saisie d'une série en moins de 4 secondes, interface OLED à contraste élevé, clavier numérique dédié, chrono en Live Activity & Dynamic Island.

---

## 2. Les 3 Moments Clés

```mermaid
flowchart LR
    A["🌅 MATIN<br>Lecture biométrique & Score"] --> B["🏋️‍♂️ SÉANCE<br>Carnet rapide & Live Activity"]
    B --> C["🌙 SOIR<br>Compléments, Calendrier & ACWR"]
```

### 🌅 1. Le Matin (Avant l'entraînement)
- Lecture automatique de la nuit : Variabilité de la Fréquence Cardiaque (VFC / SDNN), Fréquence Cardiaque au repos (FCR) et stades de sommeil (profond, paradoxal / REM).
- Calcul du score de récupération (0 à 100) et classement en 4 états :
  - **Optimal (90–100)** : Pleine forme, surcharge progressive encouragée (+1 répétition ou charge).
  - **Normal (65–89)** : Séance standard conforme à la programmation.
  - **Fatigue modérée (40–64)** : Séance allégée (suppression de la dernière série des exercices d'assistance, RPE max 8, repos prolongé de 30 s).
  - **Surentraînement (< 40)** : Proposition de jour de repos actif ou routine de mobilité douce.
- Mode **Check-in subjectif** : Si moins de deux métriques biométriques sont disponibles, un formulaire rapide (qualité du sommeil, courbatures, motivation) produit un score estimé.

### 🏋️‍♂️ 2. Pendant la Séance (Le Carnet Live)
- Saisie à une main ultra-rapide avec clavier numérique personnalisé intégré.
- Chrono de repos automatisé visible dans la **Dynamic Island** et sur l'écran verrouillé (**Live Activity**).
- Calculateur de disques de fonte instantané selon le matériel déclaré.
- Remplacement d'exercices intelligent (machine occupée, gêne ou douleur) conservant le même plan de mouvement et adaptant la charge équivalente.
- Persistance immédiate : aucune donnée perdue en cas d'extinction inattendue ou de fermeture d'app (bandeau *« Reprendre la séance »*).

### 🌙 3. Après la Séance & Suivi Continu
- Récapitulatif : tonnage total, volume par groupe musculaire sur carte 2D face/dos, estimation du 1RM (formule Brzycki).
- Gestionnaire de compléments (créatine, oméga-3, whey, etc.) : suivi des prises par moment de la journée, suivi du stock restant et rappels locaux.
- **Jauge ACWR** (*Acute:Chronic Workload Ratio*) : ratio de charge aiguë (7 jours) sur charge chronique (28 jours) pour prévenir les blessures (zone optimale entre 0.8 et 1.3).
- **Règles anti-interférence** : prévention des conflits biomécaniques entre les séances lourdes pour les jambes et les sorties de course à pied intenses ou longues.

---

## 3. Moteur Physiologique (`PulseRecoveryEngine`)

Le moteur de calcul est un package Swift pur, déterministe et entièrement testable sans environnement d'exécution complexe.

### Formule du Score Physiologique
Le score global pondère trois piliers dès lors qu'ils sont disponibles :

$$\text{Score} = 0.50 \times \text{Score}_{\text{VFC}} + 0.25 \times \text{Score}_{\text{Sommeil}} + 0.25 \times \text{Score}_{\text{FCR}}$$

- **VFC ($\text{SDNN}$)** : Traitée sous transformation logarithmique naturelle $\ln(\text{SDNN})$ pour normaliser sa distribution. Comparée à la ligne de base mobile de l'utilisateur (médiane et écart-type sur 60 jours, minimum 5 nuits). Un $z\text{-score} \ge 0.5$ donne 100/100 ; un $z\text{-score} \le -3.5$ donne 10/100.
- **Sommeil** : Combine la durée totale par rapport au besoin de référence (70%) et la qualité des stades profond + REM (30%).
- **Fréquence cardiaque au repos (FCR)** : Comparée à la médiane sur 60 jours. Une augmentation anormale au-delà de la ligne de base pénalise rapidement le score (chute à 0 si élévation $\ge 12\text{ bpm}$).
- **Renormalisation dynamique** : Si un seul facteur manque (ex. pas de VFC cette nuit-là), les poids restants sont recalculés proportionnellement (50% / 50%).

---

## 4. Architecture Technique & Modularisation

Le projet applique une séparation stricte des responsabilités. Le cœur métier et le moteur d'adaptation ne dépendent d'aucun framework d'UI ou de stockage externe.

```mermaid
graph TD
    PulseApp["📱 App Pulse (SwiftUI)"]
    PulseWidgets["🔲 PulseWidgets (Live Activities / Widgets)"]
    PulseFeatures["🧩 PulseFeatures (Today, Train, Plan, Stats, Supplements)"]
    PulseDesignSystem["🎨 PulseDesignSystem (Tokens, Cartes, SVG MuscleMap)"]
    PulsePersistence["💾 PulsePersistence (SwiftData + CloudKit)"]
    PulseContent["📚 PulseContent (80 Exercices & Programmes JSON)"]
    PulseHealth["❤️ PulseHealth (HealthKit / Reader / Mocks)"]
    PulseRecoveryEngine["⚙️ PulseRecoveryEngine (Moteur de calcul & ACWR)"]
    PulseDomain["🧱 PulseDomain (Entités pures, Value Types)"]

    PulseApp --> PulseFeatures
    PulseApp --> PulseHealth
    PulseApp --> PulsePersistence
    PulseApp --> PulseContent
    PulseWidgets --> PulseDomain
    PulseWidgets --> PulseDesignSystem
    PulseFeatures --> PulseDesignSystem
    PulseFeatures --> PulseDomain
    PulseFeatures --> PulseRecoveryEngine
    PulseHealth --> PulseDomain
    PulseRecoveryEngine --> PulseDomain
    PulsePersistence --> PulseDomain
    PulseContent --> PulseDomain
```

| Module / Package | Rôle & Dépendances |
| :--- | :--- |
| **`PulseDomain`** | Définitions pures (aucun import Apple sauf `Foundation`). Entités : `NightSample`, `Factor`, `RecoveryCategory`, `TimedSample`. |
| **`PulseRecoveryEngine`** | Algorithmes physiologiques purs, calculs ACWR, scénarios de charge, ajustements de volume. Testé sur fixtures JSON. |
| **`PulseHealth`** | Abstraction d'Apple Santé via le protocole `HealthReading`. Fournit `HealthKitReader` (production) et `StubHealthReader` (développement & tests). |
| **`PulsePersistence`** | Modèles SwiftData, synchronisation CloudKit privée, export de données (JSON / CSV), purge complète. |
| **`PulseContent`** | 80 exercices et 4 programmes types intégrés au bundle en JSON statique bilingue (FR/EN) avec versionnage stable. |
| **`PulseDesignSystem`** | Système de design natif : thèmes noir profond et ambre/opale, cartes verre obsidienne, silhouettes musculaires vectorielles SVG 2D. |
| **`PulseFeatures`** | Écrans SwiftUI modulaires assemblés par onglets : *Aujourd'hui*, *Entraîner*, *Planning*, *Statistiques*, *Profil*. |
| **`Pulse` (App)** | Point d'entrée de l'application, injection de dépendances racine (`AppDependencies`), navigation. |

---

## 5. Arborescence du Projet

```text
fitness/
├── Makefile                          # Commandes standardisées de test et lint
├── .swiftlint.yml                    # Règles strictes SwiftLint
├── Pulse.xcodeproj                   # Projet principal Xcode
├── Pulse/                            # Cœur de l'application iOS
│   ├── PulseApp.swift                # Point d'entrée (@main)
│   ├── AppDependencies.swift         # Composition root & injection de dépendances
│   ├── Diagnostics/                  # Écran de diagnostic HealthKit & état initial
│   └── Assets.xcassets/              # Ressources graphiques & icône d'app
├── Packages/
│   ├── PulseDomain/                  # Entités et règles métier pures
│   ├── PulseRecoveryEngine/          # Moteur de score, ACWR, fixtures de test
│   └── PulseHealth/                  # Abstraction et implémentation HealthKit
├── PulseTests/                       # Tests d'intégration et modèles d'application
├── docs/
│   └── superpowers/
│       ├── specs/                    # Spécifications de conception (V1, M2...)
│       └── plans/                    # Plans d'implémentation détaillés par jalon
├── ci_scripts/
│   └── ci_post_clone.sh              # Script de configuration pour Xcode Cloud
└── assets/                           # Maquettes et vecteurs graphiques
```

---

## 6. Feuille de Route & Reste à Faire

### Où en est l'app

**1.0.3** est en ligne sur l'App Store. **1.0.4** (Live Activity, balayage des séries, vibrations et animations) attend la revue d'Apple depuis le 24/11/2026.

| Jalon | Intitulé | Statut | Ce qui est livré |
| :---: | :--- | :---: | :--- |
| **M1** | Fondations et moteur | ✅ | Packages, moteur physiologique, lecture Apple Santé, agrégateur nocturne, diagnostics, CI Xcode Cloud. |
| **M2** | Données et contenu | ✅ | SwiftData + CloudKit, 84 exercices et 4 programmes en JSON, export et suppression RGPD. |
| **M3** | Onboarding et accueil | ✅ | Design system, onboarding, score du jour, check-in, écran Pourquoi, ajustements de séance, notification du matin, widgets. |
| **M4** | Programmes et séance live | ✅ | Bibliothèque, éditeur de programmes, import Hevy, records, carnet live, chrono, Live Activity, échauffement, disques, remplacement, séance passée, écriture dans Santé. |
| **M5** | Compléments | ✅ | Prises par moment, stock, rappels avec « Pris », écriture dans Santé. |
| **M6** | Planning et anti-interférence | ✅ | Courses lues depuis Santé, semaine datée, série, calendrier, 3 règles jambes / course, décharge ACWR, widgets sur données réelles. |
| **M7** | Statistiques et profil | ✅ | Onglet Stats (charge, biométrie, muscles, assiduité, records), profil, poids, réglages, Mes données. |
| **M8** | App Store | ✅ | Données Santé gardées sur l'iPhone, manifestes de confidentialité, pages publiques, passe d'accessibilité, icône, publication. |
| **V2a** | Course GPS | ✅ | Course suivie dans l'app, tracé, annonces vocales, Live Activity. |
| **V2b** | Photos | ✅ | Photos de séance (iCloud), photos de corps sous Face ID (iPhone seulement). |
| **V2** | Sommeil et finitions | ✅ | Phases de sommeil et écran Nuit, passe UI/UX, silhouette homme / femme, séries dans la Dynamic Island. |

### Reste à développer

Relevé des « suivis connus » des PR et des revues. Chaque point est à revérifier avant d'être pris.

**Fonctionnalités laissées pour une passe suivante**
- [x] Valider une série depuis la Live Activity.
- [x] Appliquer le thème choisi aux widgets.
- [x] Barre de reprise compacte en `tabViewBottomAccessory`.
- [x] Sélection au doigt dans les graphiques des Stats.
- [x] Cases du calendrier mensuel cliquables.
- [x] Désarchiver un complément.
- [x] L'incrément choisi en séance est enregistré dans les réglages de l'exercice, comme l'échauffement : il vaut pour les séances suivantes.

**Course GPS**
- [x] Double écriture possible dans Santé quand `finishWorkout` renvoie nil, iPhone verrouillé.
- [x] Une course interrompue sans aucun point GPS retenu est enregistrée avec environ 0 min.
- [x] Le compteur d'annonces vocales ne revient pas à zéro si iOS perd un rappel de fin de parole.
- [x] Le sous-titre « · aujourd'hui » de la tuile course suit la semaine type, pas les déplacements.
- [x] Localisation approximative : l'écran affiche « Signal faible » sans dire pourquoi.
- [x] La flèche de localisation peut rester dans la barre d'état hors course (session d'arrière-plan à vérifier).

**Photos**
- [x] Un index de photos de corps abîmé donne un écran vide, sans moyen de le réparer (rien n'est perdu).
- [x] Les photos d'une séance abandonnée pendant l'ajout restent dans iCloud.
- [x] L'export général charge toutes les images dans un même contexte SwiftData (mémoire).
- [x] Doublure de Face ID pour les tests d'interface.

**Sommeil et écran Nuit**
- [x] La légende des Stats liste Profond / Léger / Paradoxal dès qu'une barre a des phases.
- [x] Une ligne de répartition à 0 min garde une petite barre.
- [x] Le reste « sans phase » d'une nuit à phases est dessiné dans la rangée Léger.
- [x] Le résumé VoiceOver du graphique ne cite que la part de profond.
- [x] Le rattrapage fait une lecture SwiftData par nuit.
- [x] La tuile Sommeil suit 14 jours, pas les 60 du cache.

**Planning, décharge et séance**
- [x] Un déplacement ou un refus dans le Planning peut croiser le passage du jour (pas de file d'attente).
- [x] Les exercices ajoutés ou remplacés pendant une décharge ne prennent pas les −10 %.
- [x] Les rappels de compléments lisent la semaine type, pas les déplacements.
- [x] Le texte de zone du widget Semaine est toujours vert.
- [x] Deux bandeaux « Reprendre » peuvent s'afficher sur l'onglet Séance.
- [x] Après « Continuer », un second oubli dans la même ouverture de l'app ne redemande rien.
- [x] Les sorties vélo n'apparaissent pas dans la grille d'assiduité.

**Technique**
- [x] `ProfileRepository.update` atomique pour les six écritures du profil.
- [x] Remplir les catalogues `Localizable.xcstrings` : Stats, Planning, Compléments et Nuit, synchronisés depuis les chaînes extraites par le compilateur.
- [x] Test instable : `BodyPhotosModelActionsTests.relockWhileTheArchiveIsWrittenDiscardsIt`.
- [x] Petits nettoyages : boutons et sélecteurs en double, tests de câblage de la course côté app, libellés absents du catalogue ProfileFeature, `TestImages` copié dans plusieurs cibles.

### Hors code

- [ ] Déployer les schémas CloudKit **V5** (tracés de course) et **V6** (photos de séance) en production. V7 (sommeil) est local et n'a rien à déployer.
- [ ] Lancer les tests jamais exécutés : les tests d'interface `LiveSessionResumeUITests`, `SupplementsUITests`, `AccessibilityAuditUITests`, et dans `PulseTests` les tests de câblage de la course (`SessionIntentWiringTests`, fin d'`AppRootModelTests`), compilés mais lancés seulement sur simulateur.
- [ ] Faire les vérifications sur iPhone listées dans les PR #22 (course), #23 (photos), #24 (passe UI/UX), #26 (Nuit), #40 (Dynamic Island), #43 et #78 (partage) et #79 à #84 (passe « reste à faire »).
- [ ] Faire pointer les épingles Pinterest vers la fiche App Store au lieu de la page support.

---

## 7. Démarrage Rapide & Développement

### Prérequis
- **macOS** avec **Xcode 26+** installé.
- **Swift 6** activé.
- [SwiftLint](https://github.com/realm/SwiftLint) pour la vérification du style de code :
  ```bash
  brew install swiftlint
  ```

### Installation
1. Clonez le dépôt :
   ```bash
   git clone https://github.com/D-Seonay/fitness.git
   cd fitness
   ```
2. Ouvrez le projet dans Xcode :
   ```bash
   open Pulse.xcodeproj
   ```

### Commandes Utiles (`Makefile`)

Le projet inclut un `Makefile` à la racine pour automatiser les tâches régulières :

```bash
# Lancer l'ensemble des validations (lint + tests packages + tests app)
make test

# Lancer uniquement les tests unitaires ultra-rapides des packages Swift (sans simulateur)
make test-packages

# Lancer les tests de l'application sur le simulateur iPhone
make test-app

# Vérifier la conformité du code avec SwiftLint en mode strict
make lint
```

### Développement sans Apple Watch ni Montre Connectée
Pour tester le comportement de l'application sur simulateur ou sans capteur réel, `AppDependencies.preview()` et `StubHealthReader` injectent des profils de données pré-enregistrés :
- `typicalNight` (nuit complète, récupération optimale).
- `outOfRangeSDNN` (valeurs atypiques).
- Scénarios de tests disponibles dans `PulseRecoveryEngine/Tests/.../Fixtures/`.

---

## 8. Tests & Qualité

Pulse applique les plus hauts standards de rigueur logicielle :
- **Swift Testing (`import Testing`)** : Utilisation exclusive du nouveau framework de test natif Swift (`@Test`, `@Suite`, tests paramétrés `#expect`).
- **Fixtures Physiologiques** : Le moteur est validé contre des jeux de données réels sérialisés au format JSON (`bonne-nuit.json`, `mauvaise-nuit.json`, `vfc-manquante.json`, `huit-nuits.json`, etc.).
- **Intégration Continue (CI)** : À chaque pull request et à chaque push sur `master`, **GitHub Actions** (`.github/workflows/ci.yml`) lance `make lint`, `make test-packages` et `make build-release`, sur le même Xcode que les builds envoyés à TestFlight. Les tests de la cible app et les tests d'interface demandent un simulateur : ils ne tournent pas encore en CI (issue #97). Les builds TestFlight sont archivés et envoyés depuis le poste de développement.

---

## 9. Confidentialité & Données Santé

- **Local-First** : Pulse est conçu pour être utilisable à 100% sans connexion réseau.
- **Zéro Serveur / Zéro Tiers** : Aucune donnée biométrique ne transite sur des serveurs privés ou des plateformes tierces d'analytics.
- **Sauvegarde Chiffrée** : Si iCloud est activé, la synchronisation s'effectue exclusivement dans le conteneur CloudKit privé de l'utilisateur, inaccessible aux tiers et aux créateurs de l'application.
- **Droit à l'oubli** : Un bouton de purge totale permet d'effacer immédiatement l'intégralité des données locales et synchronisées en conformité avec le RGPD.

> [!NOTE]  
> **Avertissement de non-dispositif médical :** Pulse est un outil d'assistance à la planification sportive et de bien-être physique. Il ne constitue pas un dispositif médical et ne fournit aucun diagnostic, traitement ou conseil de posologie médicamenteuse.

---

## 10. Crédits & Licence

- **Conception et Développement** : Mathéo Delaunay.
- **Cartographie Musculaire** : Silhouettes vectorielles adaptées de [MuscleMap](https://github.com/musclemap) (Licence MIT).
- **Environnement de développement** : Conçu avec [T3 Code](https://t3.codes).

*Projet sous licence propriétaire — Tous droits réservés.*
