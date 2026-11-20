# Pulse M6 — Planning, série, anti-interférence : spec complémentaire

Date : 20 novembre 2026
Statut : écrite sans séance de conception ; Mathéo a délégué les choix (« je te fais confiance »)
Auteur : Mathéo Delaunay, rédigé avec Claude
Complète : la spec V1 (`2026-10-31-pulse-v1-design.md`, §5.7, §5.10, §6.4, §6.5, §8), la spec M2 (modèle `ScheduledDay`, cache `HealthSample`) et la maquette (`maquette.html`, écrans `planning` et `seance-passee`).

Les choix du constructeur sont marqués **(choix du constructeur)**. On peut les rouvrir, mais il faut une raison.

---

## 1. Intention

L'onglet Planning est vide depuis M3. M6 y met la semaine en cours, le mois et la série. Pulse y montre ce qui a été fait, ce qui reste et ce qui a bougé, et pourquoi. Les courses enregistrées par la montre arrivent dans Apple Santé. Pulse les lit et les compte, comme une séance de musculation, dans la série et dans la charge d'entraînement.

La série récompense la **régularité sur la semaine**, pas chaque jour. Une semaine réussie est une semaine où le nombre de séances prévu est atteint. Rater un jour n'est pas une faute, rater la semaine casse la série.

## 2. Découpage

M6 représente trois semaines dans la feuille de route. Il est coupé en deux PR **(choix du constructeur)** :

| Partie | Branche | Contenu |
| :--- | :--- | :--- |
| **M6a** | `m6-planning` | courses et vélos lus d'Apple Santé, semaine datée et déplacements, série, calendrier du mois, onglet Planning, détail d'une séance modifiable. |
| **M6b** | `m6-anti-interference` | les trois règles anti-interférence, proposition de décharge, refus enregistrés, widgets Série / Semaine / Séance du jour sur données réelles. |

M6a se fait en trois lots, comme M5 :

| Lot | Contenu |
| :--- | :--- |
| 1 — Moteur | lecture ancrée des entraînements, import en séances, RPE estimé, semaine datée, série, mois, double en mémoire du dépôt `ScheduledDay`. Tout testé par `swift test`. |
| 2 — Écrans | cible `PlanningFeature` : onglet Planning, mois et série, déplacement, détail d'une course. Modification du détail d'une séance dans `TrainFeature`. |
| 3 — App | lecture des courses dans le passage du jour, branchement de l'onglet, semaine datée lue par l'accueil et l'onglet Séance. |

---

# M6a

## 3. Courses et vélos lus d'Apple Santé

**Lecture.** `HealthSampleSource` gagne `workoutChanges(of:since:from:)` pour deux types : `.run` (course à pied) et `.ride` (vélo). C'est une lecture ancrée, comme les nuits, qui part de 60 jours avant aujourd'hui. Chaque entraînement devient un `CachedHealthSample` avec début, fin, durée, distance, fréquence cardiaque moyenne (quand Apple Santé l'a), identifiant HealthKit et application source. Les marches, la natation et les autres activités ne sont pas lues (spec V1 §5.7 : « une marche ou un vélo non » pour la série ; le vélo est lu pour la charge seulement).

**Import.** Après chaque lecture réussie d'un type, `HealthWorkoutImporter` aligne les séances sur le cache :

- un entraînement du cache sans séance au même `healthKitUUID` devient une `WorkoutSession` : `source = .appleHealth`, `status = .completed`, `kind = .run` ou `.ride`, titre « Course » ou « Vélo », durée, distance, FC moyenne, RPE estimé ;
- une séance `.appleHealth` commencée dans la fenêtre lue, dont l'entraînement a disparu du cache, est supprimée : il a été effacé dans Apple Santé ;
- une séance existante garde son `overallRPE` et sa `note`, saisis dans Pulse ; seuls les champs lus sont mis à jour.

Une lecture qui échoue laisse les séances telles quelles. Un entraînement écrit par Pulse lui-même (musculation) n'est jamais lu, puisque seuls la course et le vélo le sont.

**RPE estimé** (spec V1 §6.4 : charge = minutes × RPE). FC max = 208 − 0,7 × âge (Tanaka), ou 190 sans date de naissance. Avec p = FC moyenne / FC max :

| p | RPE |
| :--- | :--- |
| ≤ 0,50 | 2 |
| 0,50 à 0,60 | 2 + (p − 0,50) × 10 |
| 0,60 à 0,95 | 3 + (p − 0,60) × 20 |
| ≥ 0,95 | 10 |

La valeur est arrondie au demi-point. Sans FC moyenne, pas de RPE estimé : la charge prend le RPE par défaut (6) **(choix du constructeur)**. Le vélo reste plafonné à 5 dans la charge (M4).

**Où.** Le passage du jour (`DayRefresher`) lit les entraînements après les nuits, au premier plan comme en arrière-plan. La livraison en arrière-plan n'observe toujours que les trois signaux de la nuit : une course est vue au plus tard au prochain passage **(choix du constructeur)**.

## 4. La semaine datée

Le programme donne une semaine type (`weekLayout`, lundi à dimanche). La semaine datée lui ajoute ce qui change **pour une date précise** : des lignes `ScheduledDay`.

**Règle de lecture.** Pour une date, une ligne `ScheduledDay` non supprimée remplace la semaine type. Sans ligne, c'est la semaine type. Une ligne `kind = .rest` vide le jour, une ligne `.strength` ou `.run` y met `routineDayID`.

**Déplacer (M6a).** Depuis la semaine en cours, une séance prévue aujourd'hui ou plus tard peut être **échangée** avec un autre jour de la même semaine, lui aussi aujourd'hui ou plus tard et non validé. L'échange écrit deux lignes (`moveReason = .user`, `movedFromDate` = la date d'origine). Un jour vide échangé devient un repos. « Rétablir la semaine type » supprime les lignes `.user` de la semaine. L'échange plutôt que le glisser-déposer libre garde toujours le même nombre de séances dans la semaine, et marche aussi avec VoiceOver **(choix du constructeur)**.

**Qui lit la semaine datée.** `TodayPlanner.plan(program:on:calendar:overrides:)` : la séance du jour et la prochaine séance (les 7 jours suivants) passent par les lignes. Le passage du jour, l'accueil et l'onglet Séance s'en servent. Les compléments « jours d'entraînement » lisent encore la semaine type **(choix du constructeur, à revoir en M6b)**.

**Validation automatique.**

- Un jour prévu en musculation est **validé** dès qu'une séance de musculation terminée (Pulse ou Hevy, pas abandonnée) existe ce jour-là, quelle que soit la routine. Faire Pull le jour de Push, c'est avoir fait sa séance **(choix du constructeur)**.
- Un jour prévu en course est validé par une course lue d'Apple Santé ce jour-là.
- Un jour passé, prévu et non validé est **manqué**.
- Un jour de repos où une séance a eu lieu est validé, avec une séance « en plus ».
- `ScheduledDay.status` n'est pas écrit pour la validation : elle se recalcule toujours depuis les séances. Il n'y a ainsi rien à rattraper quand une séance est supprimée ou importée après coup **(choix du constructeur)**.

## 5. La série

**Ce qui compte.** Une séance de musculation terminée (toutes sources, abandons exclus) et toute course lue d'Apple Santé, planifiée ou non. Le vélo et la marche ne comptent pas (spec V1 §5.7). Deux séances le même jour comptent deux fois.

**Objectif de la semaine.** `program.sessionsPerWeek`, recalculé depuis la semaine type par l'éditeur. Sans programme, c'est `profile.trainingDaysPerWeek`. Il est toujours d'au moins 1. On l'ajuste en changeant la semaine type du programme : il n'y a pas de réglage à part en M6a **(choix du constructeur)**. L'objectif courant vaut pour toutes les semaines, passées comprises **(choix du constructeur)**.

**Calcul.** Les semaines vont du lundi au dimanche. La série est le nombre de semaines réussies consécutives qui se terminent la semaine dernière, plus un si la semaine en cours est déjà réussie. Une semaine en cours pas encore réussie ne casse rien. La série remonte au plus jusqu'à la semaine de la première séance ou de la fin de l'onboarding, la plus ancienne des deux.

**Pilier.** Les 12 dernières semaines, de la plus ancienne à la plus récente : coche (réussie), vide (ratée), anneau avec progression (en cours), et la flamme avec le compteur **(choix du constructeur pour 12)**.

## 6. Le mois

Une grille lundi à dimanche, semaines entières, avec les jours des mois voisins en retrait. Pour chaque jour :

- **validé** : pastille pleine avec l'icône de la discipline (haltère, chaussure ; vélo pour un vélo seul) ;
- **point** : deux séances ou plus, ou un record battu ce jour-là (`WorkoutSet.isPersonalRecord`) ;
- **aujourd'hui** : cerclé ;
- **prévu** (aujourd'hui et après) : pastille creuse de la discipline prévue ;
- **manqué** : rien de plus qu'un jour vide. Le planning ne fait pas de reproche (spec V1 §2, anti-objectifs).

On navigue de mois en mois, du mois de la première séance jusqu'au mois suivant le mois courant.

## 7. L'onglet Planning

D'après la maquette (`planning`) :

1. **En-tête** : « Planning » et « semaine du 16 novembre ».
2. **Bande des 7 jours**, aujourd'hui plein. Une touche sur un jour validé ouvre sa séance, sur un autre jour fait défiler la liste jusqu'à lui.
3. **Carte du jour** : titre de la séance, nombre de séries, durée estimée, « Ajustée » si le score l'a allégée. Le bouton « Lancer la séance » lance la même séance que l'accueil. La carte affiche « Séance faite » une fois validée, et propose « Reprendre » si une séance est en cours. Un jour de course, elle montre le type et l'objectif. Un jour de repos, elle annonce la prochaine séance.
4. **Cette semaine** : une ligne par jour avec la date, le titre et le détail. Le détail vaut « Validée · 11 240 kg », « Validée · 8,2 km », « Manquée », « Repos », « Repos obligatoire » (jour de `restWeekdays`), ou « Déplacée de mardi » pour une séance déplacée. Le menu contextuel « Déplacer à… » apparaît sur les jours déplaçables, et le bouton « Rétablir la semaine type » sous la liste quand un déplacement existe.
5. **Mois et série**, en bas : ouvre l'écran du mois (calendrier, légende, pilier de série).

Une séance de musculation validée ouvre le détail de séance de l'onglet Séance. Une course ouvre le détail de course : distance, durée, allure, FC moyenne, RPE estimé, avec RPE et note modifiables.

## 8. Détail d'une séance, modifiable

La spec V1 §5.7 demande un détail « modifiable ». Le détail de M4a gagne « Modifier ». On peut y modifier :

- la note et le RPE global ;
- pour chaque série hors échauffement, la charge, les répétitions (ou la durée tenue) et le RPE ;
- supprimer une série.

À l'enregistrement : la séance est sauvée, le tonnage est recalculé et les records sont recalculés (`RecordsService.recomputeAll`). La date, l'heure et l'entraînement écrit dans Apple Santé ne changent pas **(choix du constructeur)**.

Une course lue d'Apple Santé ne se supprime pas depuis Pulse : elle reviendrait au passage suivant. On la supprime dans Apple Santé.

---

# M6b (à faire après M6a)

## 9. Règles anti-interférence

Elles sont calculées sur la semaine datée en cours, à chaque passage du jour, depuis aujourd'hui. Chacune est désactivable (`profile.antiInterferenceRulesDisabled`).

1. **Jambes lourdes → course intense.** Un fractionné ou une sortie longue prévu moins de 36 h après une séance de jambes lourde, faite ou prévue, est déplacé au premier jour libre qui respecte les 36 h dans la semaine. Sans jour libre, il devient une sortie facile. Une séance est « jambes lourdes » quand plus de la moitié de ses séries de travail visent les quadriceps, les ischios ou les fessiers **(choix du constructeur)**.
2. **Même jour.** Une course et une séance de musculation le même jour : un rappel « au moins 6 h entre les deux, la plus technique le matin ». Pulse ne connaît pas les heures prévues, donc la règle ne déplace rien **(choix du constructeur)**.
3. **Repos complet.** Sans jour de repos depuis 7 jours, et avec une moyenne de sommeil sur 7 jours sous le seuil de la catégorie « fatigue modérée » du sous-score sommeil, le prochain jour prévu devient un repos.

Chaque déplacement écrit une ligne `ScheduledDay` avec le `moveReason` de la règle et un `moveReasonText` en clair, que la semaine affiche. Un déplacement refusé est enregistré dans `refusedAdjustments` de la séance du jour et n'est plus proposé pour cette date.

## 10. Décharge

Quand l'ACWR est ≥ 1,5 deux jours de suite (avec 28 jours d'historique), l'accueil propose une semaine de décharge : volume −40 %, charges −10 %, jusqu'au dimanche suivant. On peut l'accepter ou la refuser. Elle est enregistrée comme ajustement `.deload` (refusé ou appliqué) **(choix du constructeur pour la durée)**.

## 11. Widgets

Les widgets Série, Semaine, Séance du jour et Prochaine séance existent (travail de Mathéo) avec des données d'exemple. M6b ajoute à `WidgetSnapshot` la série, la semaine en cours et la prochaine séance, publiés par le passage du jour, et les widgets les lisent. Comme pour le score, rien de sensible sur l'écran verrouillé.

---

## 12. Qualité

Comme pour les jalons précédents :

- `swift test` vert sur chaque package touché ;
- `swiftlint lint --strict` à 0 ;
- `make build-app` et `make build-release` verts ;
- chaque règle de calcul (RPE estimé, import, semaine datée, validation, série, mois) testée sur fixtures de semaines types.

Le simulateur n'est jamais lancé par la session. Les vérifications sur iPhone reviennent à Mathéo : une vraie course qui arrive d'Apple Santé, la série sur un mois réel, un déplacement.
