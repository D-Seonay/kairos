# Pulse M5 — Compléments : spec complémentaire

Date : 20 novembre 2026
Statut : écrite sans séance de conception ; Mathéo a délégué les choix (« je te fais confiance »)
Auteur : Mathéo Delaunay, rédigé avec Claude
Complète : la spec V1 (`2026-10-31-pulse-v1-design.md`, §5.2, §5.3, §5.6, §6.2), la spec M2 (modèles `Supplement` et `SupplementIntake`, dépôt, export, effacement) et la maquette (`maquette.html`, écrans `supplements` et `supplement-new`).

Les choix du constructeur sont marqués **(choix du constructeur)**. Ils peuvent être rouverts, mais pas sans raison.

---

## 1. Intention

Pulse tient déjà le sommeil, la récupération et les séances. M5 y ajoute les compléments que l'utilisateur prend : savoir ce qui est dû aujourd'hui, le cocher en une touche (depuis l'app ou depuis la notification), voir son stock baisser, et suivre sa régularité sur 30 jours. Les prises de vitamine D, magnésium, caféine et protéines vont aussi dans Apple Santé.

**Ce que Pulse ne fait jamais** : conseiller une dose. Les suggestions préremplissent le nom, la forme, l'unité, le moment et le type Apple Santé, mais jamais la dose (spec V1 §2, §5.3, §8). Les conseils portent sur le moment de prise uniquement, et sont factuels.

## 2. Découpage

Une branche `m5-complements` depuis `master` (0a2cf3e), trois lots, une PR :

| Lot | Contenu |
| :--- | :--- |
| 1 — Moteur | unité µg, catalogue des suggestions et des conseils, plan du jour, régularité, rappels à planifier, conversion vers Apple Santé, `SupplementService` (prise, décoche, stock, écriture Apple Santé, replanification). Tout testé par `swift test`. |
| 2 — Écrans | cible `SupplementsFeature` : écran Compléments, formulaire de création et de modification, carte de l'accueil, carte du récap. |
| 3 — App | notifications avec l'action « Pris », écriture HealthKit des quatre types, effacement, branchements de l'app, lien depuis le Profil, test d'interface (compilé seulement). |

## 3. Modèle

Les modèles de M2 suffisent. Un seul ajout : `DoseUnit.microgram` (valeur brute `"mcg"`), pour la vitamine D en µg, comme la maquette. Le magasin stocke l'unité en texte avec repli sur `g` : aucune migration **(choix du constructeur)**.

`stockDoses` et `lowStockThreshold` comptent des **prises**, pas des grammes : une prise retire 1, une décoche rend 1 (« 38 doses » dans la maquette) **(choix du constructeur)**.

`healthKitType` vaut `dietaryVitaminD`, `dietaryMagnesium`, `dietaryCaffeine`, `dietaryProtein` ou `nil`.

## 4. Le plan du jour

Un complément est **dû** un jour donné selon `days` :

- `everyDay` : tous les jours ;
- `custom` : les jours de `customWeekdays` ;
- `trainingDays` : les jours où le programme actif place une routine (`weekLayout`), plus tout jour où une séance Pulse terminée existe déjà (une séance libre un samedi compte) **(choix du constructeur)**.

Un complément archivé, ou créé après le jour donné, n'est pas dû.

**Heure prévue**, selon `timing` :

- `fixedTime` : `timeOfDayMinutes` (8:00 par défaut dans le formulaire) ;
- `bedtime` : `timeOfDayMinutes`, réglé dans le formulaire (22:30 par défaut). La spec V1 dit « selon l'heure de coucher habituelle » ; la déduire des nuits Apple Santé est remis à plus tard **(choix du constructeur)** ;
- `beforeWorkout` : 30 minutes avant l'**heure habituelle de séance** ;
- `afterWorkout` : la fin de la séance du jour si elle est terminée, sinon l'heure habituelle de séance plus une heure (heure affichée seulement, aucun rappel avant la fin réelle).

**Heure habituelle de séance** : le planning daté arrive en M6. D'ici là, c'est la médiane des heures de début des 10 dernières séances de musculation terminées (Pulse et import Hevy) sur 60 jours, arrondie au quart d'heure ; 18:00 sans historique **(choix du constructeur)**. Si une séance est en cours ou terminée aujourd'hui, son heure de début remplace l'heure habituelle pour ce jour-là.

**Moments d'affichage**, dans l'ordre : *Matin* (heure fixe avant 12:00), *Après-midi* (heure fixe de 12:00 à 17:59), *Autour de la séance* (avant et après la séance), *Soir* (heure fixe à partir de 18:00, et au coucher). Un moment vide est caché ; avec les compléments courants, on retrouve les trois moments de la spec V1 **(choix du constructeur)**.

**Pris** : un complément est pris ce jour-là s'il a au moins une prise dans la journée locale. Chaque ligne est cochée ou décochée en une touche ; décocher supprime la dernière prise du jour. On ne peut cocher que le jour même.

**Prochaine prise** : le premier complément dû et non pris, par heure prévue ; à heure égale, par `order`.

## 5. Prise et décoche

`SupplementService.take(supplementID:at:)` :

1. refuse si une prise existe déjà ce jour-là (une notification touchée deux fois ne compte pas double) ;
2. enregistre la prise avec la dose du complément ;
3. baisse `stockDoses` de 1 (jamais sous 0) si le stock est suivi ;
4. écrit dans Apple Santé si le complément a un type et une unité convertible, et si l'accès est accordé ; l'identifiant écrit est gardé sur la prise ;
5. retire les rappels de ce complément pour aujourd'hui (replanification).

`untake(supplementID:day:)` supprime la dernière prise du jour, rend 1 au stock, supprime l'échantillon Apple Santé, et replanifie.

Une écriture Apple Santé qui échoue (iPhone verrouillé, la prise venant de la notification) laisse `writtenToHealthKit` à faux. Au retour au premier plan, le service réécrit les prises non écrites des 7 derniers jours **(choix du constructeur)**.

## 6. Apple Santé

Conversion de la dose vers l'unité du type :

| Type | Unité Apple Santé | Unités acceptées |
| :--- | :--- | :--- |
| Vitamine D | µg | µg, mg (× 1 000), UI (÷ 40) |
| Magnésium | mg | mg, g (× 1 000), µg (÷ 1 000) |
| Caféine | mg | mg, g, µg |
| Protéines | g | g, mg (÷ 1 000) |

Avec `ml` ou `dose`, rien n'est écrit : la quantité est inconnue. Le formulaire le dit sous l'interrupteur.

L'accès en écriture se demande au premier enregistrement d'un complément qui a un type Apple Santé, par la feuille système (pas d'écran d'explication à part : le formulaire dit déjà ce qui sera écrit) **(choix du constructeur)**. La suppression totale efface aussi ces quatre types écrits par Pulse.

## 7. Rappels

Un complément a un rappel si `reminderEnabled` et si le réglage du profil `supplementRemindersEnabled` est vrai. Les rappels sont des notifications **ponctuelles** planifiées pour les 14 prochains jours, une par complément et par jour dû, identifiant `fr.seonay.pulse.supplement.<id>.<AAAA-MM-JJ>`, au plus 48 à la fois (iOS en garde 64) **(choix du constructeur)** :

- `fixedTime` et `bedtime` : à l'heure prévue ;
- `beforeWorkout` : 30 min avant l'heure habituelle de séance, les jours d'entraînement ;
- `afterWorkout` : 45 min après la fin de la séance du jour, si elle n'est pas prise ; aucun rappel tant que la séance n'est pas finie (le récap le montre déjà) ;
- rien pour une heure déjà passée, ni pour un complément déjà pris ce jour-là.

La liste est recalculée entière (retrait des anciens, ajout des nouveaux) après chaque création, modification, suppression, prise ou décoche, au retour au premier plan et à la fin d'une séance. Sans app ouverte pendant 14 jours, les rappels s'arrêtent : c'est acceptable en V1.

Texte : titre « Vitamine D3 », corps « 1 000 UI · c'est l'heure de ta prise ». Catégorie avec une action **« Pris »** qui ne rouvre pas l'app et marche écran verrouillé. Toucher la notification ouvre l'écran Compléments. L'action « Pris » enregistre la prise à l'heure de l'action, pour le jour du rappel.

L'autorisation des notifications se demande au premier enregistrement d'un complément avec rappel (sans effet si l'onboarding l'a déjà demandée).

## 8. Régularité

Pour chaque complément, sur les 30 derniers jours (aujourd'hui compris s'il est déjà pris, sinon exclu), à partir de sa création : jours pris ÷ jours dus. « — » quand aucun jour n'était dû. Les jours d'entraînement passés sont ceux du programme actif ou ceux d'une séance terminée.

## 9. Conseils

Factuels, sur le moment de prise seulement, sans dose. Un conseil s'affiche sur l'écran Compléments quand sa condition est vraie :

- **Caféine** (type caféine, ou nom contenant « caféine » ou « café ») prise à 16:00 ou plus tard : « La caféine prise après 16 h peut réduire ton sommeil profond, qui compte dans ton score du lendemain. »
- **Vitamine D** : « La vitamine D s'absorbe mieux avec un repas qui contient des graisses. »
- **Fer** : « Le café et le thé réduisent l'absorption du fer : espace-les d'une heure. »
- **Créatine** : « La créatine agit par accumulation : la régularité compte plus que le moment. »

Le pied de l'écran et du formulaire rappelle : « Pulse ne propose pas de dose. Suis la notice du produit ou l'avis d'un professionnel de santé. »

## 10. Écrans

**Écran Compléments** (poussé depuis la carte de l'accueil et depuis le Profil) : en-tête avec la date et « + » ; carte de synthèse « 2 sur 5 pris », segments, prochaine prise avec « Pris » ; les moments et leurs lignes (nom, heure prévue et moment, dose, coche) ; les conseils ; le stock (barres, alerte sous le seuil) ; la régularité 30 jours ; l'avertissement. Toucher une ligne ouvre le formulaire en modification ; glisser propose « Archiver ». Sans complément : un état vide avec « Ajouter un complément ».

**Formulaire** (feuille) : suggestions en pastilles (Créatine, Whey, Vitamine D3, Magnésium, Caféine, Oméga-3, Fer, Zinc, Électrolytes) qui préremplissent sans dose ; nom, forme, dose et unité, moment (avec heure pour heure fixe et coucher), jours (avec les sept jours en personnalisé), rappel, type Apple Santé et écriture, stock et seuil. « Enregistrer » est actif quand le nom et une dose positive sont remplis. En modification : « Archiver ».

**Carte de l'accueil** : sous la carte séance, « Compléments », « 2 sur 5 », la prochaine prise avec « Pris », une pastille d'alerte de stock. Masquée quand aucun complément n'est dû aujourd'hui et qu'aucun n'existe ; sinon « Ajouter un complément » quand la liste est vide.

**Carte du récap** : pour une séance en direct (pas pour une séance saisie après coup), les compléments « avant » et « après la séance » dus aujourd'hui, cochables. Masquée s'il n'y en a pas.

## 11. Ce qui n'est pas fait

- Heure de coucher déduite des nuits (§4) ; planning daté (M6).
- Réglage global des rappels dans un écran Paramètres (M7) : le champ du profil est respecté, mais ne se change pas encore dans l'app.
- Historique détaillé des prises par complément.
- Test d'interface avec la notification réelle : le test compile, Mathéo le lance et vérifie l'action « Pris » à la main.

## 12. Vérification

`swift test` sur chaque package touché, `swiftlint lint --strict` à 0, `make build-app` et `make build-release`. Le simulateur n'est pas lancé. Restent à Mathéo : la création sur iPhone, une notification réelle avec « Pris » écran verrouillé, l'écriture dans Apple Santé de la vitamine D, la suppression d'une prise, et le déploiement du schéma CloudKit (inchangé ici).
