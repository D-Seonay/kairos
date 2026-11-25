# Pulse — Objectif de sommeil et rappel de coucher

Date : 2026-11-25. Branche : `sommeil-objectif-coucher`.

Références : spec V1 `2026-10-31-pulse-v1-design.md` (§6.1 score de sommeil), spec M2 `2026-10-31-pulse-m2-donnees-contenu-design.md` (schéma, déploiement CloudKit), spec M5 `2026-11-20-pulse-m5-complements-design.md` (§7 rappels de compléments), spec M8 `2026-11-22-pulse-m8-app-store-design.md` (frontière iCloud / appareil), spec sommeil `2026-11-24-pulse-sommeil-phases-design.md` (§6.3 écran Nuit).

## 1. Intention

Pulse mesure le sommeil mais n'aide pas à mieux dormir : il note la nuit le matin et ne dit rien le soir. Mathéo veut que l'app aide les gens à se coucher à temps, avec un objectif et une heure de réveil réglables, et un rappel le soir.

Un simple rappel à heure fixe existe déjà dans iOS (app Santé, « Sommeil »). Ce que Pulse apporte de plus, c'est le lien avec ce qu'il sait déjà : la nuit de la veille, la séance du lendemain et le score de récupération.

## 2. État actuel (ce que le code fait aujourd'hui)

- `SleepScorer` (`PulseRecoveryEngine`) note la durée contre une cible en dur de 480 min (`targetMinutes`). Avec des phases, la durée vaut 70 points et la part de profond, contre 20 %, en vaut 30 ; sans phases, la durée vaut les 100 points. Il a deux appelants : `RecoveryCalculator.sleepFactor` (score du jour) et `AntiInterference.needsRestDay` (moyenne des 7 dernières nuits).
- La lecture « Pourquoi » (`WhyReading`) dit « tu n'as dormi que… » sous un seuil en dur de 7 h (`shortSleepMinutes`).
- `DailyScoreService` ne calcule que le score du jour en cours, le recalcule jusqu'à midi et le fige à midi. Les scores des jours passés ne sont jamais recalculés.
- `HabitualBedtime` (`PulseServices/Supplements`) calcule la médiane des heures d'endormissement des 14 dernières nuits depuis le cache local d'Apple Santé, sans jamais l'enregistrer. Elle sert au rappel des compléments « au coucher ».
- Les rappels de compléments sont planifiés 14 jours à l'avance en notifications ponctuelles (`SupplementReminderPlanner`, `UserNotificationScheduler.replaceSupplementReminders`), au plus 48 sur les 64 qu'iOS garde en attente. Ils sont replanifiés par `supplementService.rescheduleReminders()`. `DayRefresher` ne replanifie rien lui-même : ce sont ses appelants dans l'app qui le font, au lancement et au retour au premier plan (`AppRootModel`), à la livraison d'Apple Santé en arrière-plan (`AppDelegate`), après un changement de planning ou la fin d'une séance (`MainTabView`). Le `onChange` de `SettingsService` (`AppDependencies`) ne replanifie que si `supplementRemindersEnabled` a changé.
- Les préférences de notification vivent dans `UserProfile` (`morningScoreNotification`, `morningScoreDeadlineMinutes`, `supplementRemindersEnabled`, `restTimerNotificationEnabled`), enregistrées dans `StoredProfile`, modèle synchronisé par CloudKit, et sorties dans l'export CSV.
- L'écran Nuit (`NightFeature`) montre la durée endormie, l'endormissement, le réveil, l'hypnogramme et les phases. Il ne compare la nuit à aucun objectif.
- `AppLink` n'a pas de lien vers l'écran Nuit. Celui-ci s'ouvre depuis Aujourd'hui (`TodayView`) et depuis Stats.

## 3. Objectifs, non-objectifs, anti-objectifs

### Objectifs

- Un **objectif de sommeil** réglable, de 6 h à 10 h, 8 h par défaut.
- Une **heure de réveil** pour la semaine et une pour le week-end, réglables ; sans réglage, Pulse suit les nuits mesurées.
- Un **coucher conseillé**, déduit du réveil et de l'objectif.
- Un **rappel de coucher**, un seul par soir, dont le texte tient compte de la nuit de la veille et de la séance du lendemain. Désactivé par défaut.
- L'objectif **entre dans le score de sommeil**, à partir du prochain calcul. L'historique ne change pas.
- L'écran Nuit montre **l'écart à l'objectif** et **la régularité du coucher**.

### Non-objectifs

- Pas de réveil ni d'alarme.
- Pas de pilotage du mode Concentration « Sommeil » d'iOS, et pas d'écriture d'un horaire de sommeil dans Apple Santé : iOS ne le permet pas aux apps.
- Pas d'horaire par jour de la semaine (sept heures différentes), ni d'horaires décalés (travail de nuit).
- Pas d'étape dans l'onboarding, pas de widget, pas de tuile nouvelle sur Aujourd'hui.
- Pas de dette de sommeil cumulée, pas de rappel « dernière caféine », pas de sieste.
- La part de sommeil profond du score (30 points, cible 20 %) ne change pas.
- Pas de version anglaise (issue #95), pas d'Apple Watch (issue #90).

### Anti-objectifs (ce qui serait un échec même si ça marche)

- **Harceler** : plus d'un rappel par soir, un rappel qui tombe après le coucher conseillé, ou un ton culpabilisant.
- **Notifier sans l'avoir demandé** : un utilisateur existant qui reçoit un rappel après la mise à jour sans avoir rien activé.
- **Un score qu'on fabrique** : un objectif assez bas pour qu'une nuit de 4 h vaille 100.
- **Réécrire l'historique** : un score passé qui change parce que l'objectif a changé.
- **Sortir une donnée de santé de l'iPhone** : une heure tirée d'Apple Santé enregistrée dans le profil synchronisé sans que l'utilisateur l'ait choisie.
- **Une promesse médicale** : un texte qui affirme un effet sur la santé. L'app conseille, elle ne prescrit pas.

## 4. Contraintes

- SwiftUI, iOS 26 minimum, architecture existante en paquets, textes en français dans les `Localizable.xcstrings` des modules, `swiftlint --strict`.
- Logique pure dans `PulseRecoveryEngine` et `PulseServices`, testée avec Swift Testing.
- `StoredProfile` est un modèle synchronisé. Y ajouter des attributs demande une version de schéma V8 : figer la copie V7 du modèle, ajouter `PulseSchemaV8` et l'étape légère dans `PulseMigrationPlan` (le test d'empreinte échoue sinon). Les attributs ajoutés sont optionnels ou ont une valeur par défaut, comme l'exige CloudKit.
- **Le schéma CloudKit doit être redéployé en production** depuis la console (« Deploy Schema Changes ») avant le build TestFlight, sinon la synchronisation du profil s'arrête sans erreur visible (spec M2). C'est une étape manuelle de Mathéo ; le plan doit la rappeler.
- Frontière M8 : une valeur tirée d'Apple Santé ne quitte pas l'iPhone. Une heure que l'utilisateur choisit lui-même est une préférence, au même titre que l'heure plafond du score du matin.
- iOS garde 64 notifications en attente. Les compléments en prennent au plus 48, les rappels de photos 3, la fin de repos et la course oubliée une chacune. Le score du matin part tout de suite : il n'est jamais en attente.
- Le simulateur n'est jamais lancé par le constructeur : Mathéo essaie l'app à la main sur son iPhone.

## 5. Approches envisagées

Mathéo a choisi la direction en conversation : un objectif et une heure de réveil dont Pulse déduit le coucher, plutôt qu'une heure de coucher fixe (doublon d'iOS). Pour la construction, il a laissé la main au constructeur (« je te fais confiance ») ; les choix ci-dessous sont donc ceux du constructeur.

**L'objectif et le score**

1. **L'objectif entre dans le score, à partir du prochain calcul (retenue).** Le score devient juste pour quelqu'un à qui 7 h suffisent. L'historique ne bouge pas, parce que seul le jour en cours est calculé.
2. L'objectif ne sert qu'au rappel et à l'écran Nuit. Le score reste identique pour tous, mais l'app affiche deux objectifs différents (8 h dans le score, celui de l'utilisateur ailleurs).

**Où vivent les réglages**

1. **Dans le profil (retenue).** Ils suivent iCloud et l'export, et survivent à une réinstallation. Coût : le schéma V8 et le déploiement CloudKit.
2. Sur l'appareil seulement (`UserDefaults`, comme « Suivre mes nuits »). Pas de migration, mais une réinstallation remettrait l'objectif à 8 h et changerait le score sans prévenir.

**Comment part le rappel**

1. **Un rappel ponctuel par soir, planifié 7 soirs à l'avance et réécrit à chaque passage (retenue).** C'est le mécanisme des rappels de compléments. Le texte du soir même connaît la nuit de la veille et la séance du lendemain.
2. Une notification répétée chaque jour à heure fixe. Plus simple, mais le texte ne change jamais : c'est le doublon d'iOS.
3. Calculer le texte le soir même en arrière-plan. iOS ne garantit pas de réveiller l'app à une heure donnée.

## 6. Conception

### 6.1 Les réglages (`PulseDomain`, `PulsePersistence`)

`UserProfile` gagne cinq champs, repris dans `StoredProfile` (schéma V8) et dans l'export CSV du profil :

| Champ | Type | Sans valeur |
|---|---|---|
| `sleepGoalMinutes` | `Int?` | 480 |
| `weekdayWakeMinutes` | `Int?` | suit les nuits (§6.2) |
| `weekendWakeMinutes` | `Int?` | suit les nuits (§6.2) |
| `bedtimeReminderEnabled` | `Bool` | `false` |
| `bedtimeReminderLeadMinutes` | `Int?` | 30 |

- Les heures de réveil sont en minutes après minuit, comme `morningScoreDeadlineMinutes`.
- Bornes, vérifiées dans `SettingsService` comme l'heure plafond : objectif de 360 à 600 par pas de 15 ; réveil de 4 h à 12 h par pas de 5 ; avance du rappel parmi 15, 30, 45 et 60.
- « Week-end » veut dire un réveil le samedi ou le dimanche. Le coucher du vendredi soir et celui du samedi soir suivent donc le réveil du week-end.
- Un changement de l'un de ces champs passe par le `onChange` de `SettingsService`, qui replanifie le rappel (§6.4).

### 6.2 Le coucher conseillé (`PulseServices`, logique pure)

Un nouveau type pur, à côté de `HabitualBedtime`, calcule pour un soir donné :

- **le réveil du lendemain** : l'heure choisie pour ce type de jour (semaine ou week-end) ; sinon l'heure habituelle de réveil ;
- **le coucher conseillé** : réveil − objectif − 15 min. Les 15 minutes sont le temps de s'endormir, une constante ;
- **l'heure du rappel** : coucher conseillé − avance.

**L'heure habituelle de réveil** est la médiane des réveils (`NightSleep.wokeUp`) des 14 dernières nuits, calculée comme `HabitualBedtime` : depuis le cache local, arrondie à 5 minutes, jamais enregistrée. Elle est calculée séparément pour les réveils de semaine et de week-end. Un groupe qui compte moins de 3 nuits prend la médiane de toutes les nuits, qui demande au moins 5 nuits.

**Pas de coucher conseillé** quand le réveil n'est ni choisi ni mesurable (moins de 5 nuits, pas de source de sommeil). Dans ce cas aucun rappel n'est planifié, et les réglages invitent à choisir une heure de réveil.

**Un rappel hors plage n'est pas planifié** : l'heure du rappel doit tomber entre 18 h le soir même et 3 h le lendemain. Un rappel après minuit appartient au soir de la veille.

### 6.3 L'objectif dans le score (`PulseRecoveryEngine`, `PulseServices`)

- `SleepScorer.score` prend la cible de durée en paramètre, 480 par défaut. La formule ne change pas.
- `RecoveryCalculator.compute` et `AntiInterference.needsRestDay` reçoivent l'objectif du profil et le passent au scoreur.
- `DailyScoreService.update` reçoit l'objectif comme il reçoit `plannedDay` : `nil` veut dire « profil illisible ». Dans ce cas un score déjà enregistré pour le jour est gardé tel quel ; sans score enregistré, le calcul prend 480. Un profil qu'on n'arrive pas à lire ne fait donc pas retomber le score sur 8 h.
- Effet d'un changement d'objectif :
  - avant midi, le score du jour est recalculé au passage suivant ;
  - après midi, le score du jour est figé : l'objectif vaut à partir du lendemain ;
  - les jours passés ne changent jamais.
- Un changement d'objectif dans les Réglages relance tout de suite le passage du jour : le score bouge sans attendre le prochain retour au premier plan.
- La règle de repos complet (`needsRestDay`) relit les 7 dernières nuits avec l'objectif courant. C'est voulu : elle décide pour aujourd'hui.
- **Une seule définition de « nuit courte »** : au moins une heure de moins que l'objectif (7 h pour l'objectif par défaut, comme aujourd'hui). La lecture « Pourquoi » la prend à la place de son seuil en dur, et le rappel de coucher (§6.4) prend la même. Sans cela, une nuit de 6 h 30 vaudrait tous ses points de durée pour un objectif de 6 h tout en étant dite courte.
- La tuile « Sommeil, 14 jours » d'Aujourd'hui et Stats > Biométrie montrent des durées, pas des scores : elles ne changent pas.

### 6.4 Le rappel de coucher (`PulseDomain`, `PulseServices`, app)

**Planification.** Un planificateur pur produit les rappels des 7 prochains soirs, à partir du profil, des nuits, du planning et de l'heure courante. Un service les remet à `UserNotificationScheduler` par un nouveau protocole de `PulseDomain` (« remplacer tous les rappels de coucher par ceux-ci », avec sa doublure), sur le modèle de `SupplementReminderScheduling`. Chaque rappel est une notification ponctuelle, identifiée par son soir (« fr.seonay.pulse.bedtime.2026-11-25 »).

Entre minuit et 3 h, le soir de la veille reste planifié tant que son rappel n'est pas parti : une replanification à 00:05 ne retire pas le rappel prévu à 00:15. Il peut donc y avoir huit rappels en attente juste après minuit.

- Rien n'est planifié si `bedtimeReminderEnabled` est faux, si les notifications sont refusées, ou sans coucher conseillé.
- Un rappel dont l'heure est déjà passée n'est pas planifié.
- Le service replanifie partout où l'app replanifie déjà les rappels de compléments (les appelants cités au §2). Dans le `onChange` des réglages, il replanifie quand l'un des cinq champs de §6.1 a changé.
- Huit rappels de coucher au plus portent le pire cas à 48 + 3 + 1 + 1 + 8 = 61 notifications en attente, sous les 64 d'iOS.
- **Les rappels de compléments « au coucher » ne changent pas.** Ils restent calés sur l'heure habituelle d'endormissement (mesurée), et le rappel de coucher sur le coucher conseillé. Quelqu'un qui a activé les deux reçoit donc deux notifications le soir, pour deux choses différentes. « Un seul par soir » vaut pour le rappel de coucher. Les coordonner est hors de ce lot.

**Texte.** Le titre donne l'heure, le corps donne la raison. Textes de référence :

| Situation | Titre | Corps |
|---|---|---|
| Nuit courte la veille et séance le lendemain | Au lit avant 22:45 | Nuit courte hier (6 h 10) et séance Jambes demain : vise tes 8 h. |
| Séance le lendemain | Au lit avant 22:45 | Séance Jambes demain : vise tes 8 h de sommeil. |
| Nuit courte la veille | Au lit avant 22:45 | Nuit courte hier (6 h 10) : vise tes 8 h cette nuit. |
| Sinon | Au lit avant 22:45 | Pour tes 8 h de sommeil avant le réveil de 07:00. |

- **Nuit courte** : la nuit qui s'est terminée le matin même répond à la définition de §6.3. Seul le rappel du soir même peut le dire ; les six suivants ne connaissent pas encore leur veille.
- **Séance le lendemain** : la séance prévue par le Planning après déplacements, musculation (le nom du jour de routine) ou course (le nom du type de course). Un jour de repos ne donne pas de séance.
- Le ton reste celui du conseil : « vise », jamais « il faut ».

**Au toucher**, la notification ouvre l'écran Nuit sur la nuit la plus récente, par un nouveau lien `AppLink.night`. L'app ouverte affiche la bannière, comme pour les compléments.

### 6.5 Réglages : la section « Sommeil » (`ProfileFeature`)

Une nouvelle section, placée juste avant « Notifications » :

```
SOMMEIL
Objectif de sommeil            8 h
Réveil en semaine              Selon mes nuits (07:00)
Réveil le week-end             09:00
Rappel de coucher              ( activé )
Prévenir                       30 min avant
Coucher conseillé : 22:45 en semaine, 00:45 le week-end.
L'objectif compte dans le score de sommeil dès le prochain calcul.
```

- Chaque réveil propose « Selon mes nuits », suivi de l'heure mesurée quand elle existe, puis les heures à choisir. « Selon mes nuits » laisse le champ à `nil` : l'heure mesurée n'est jamais écrite dans le profil. « Heure choisie » part toujours de 07:00 en semaine et de 09:00 le week-end, jamais de l'heure mesurée.
- L'interrupteur du rappel demande l'autorisation des notifications comme les autres (`model.notificationBinding`). « Prévenir » n'apparaît que rappel activé.
- La ligne « Coucher conseillé » est recalculée à chaque changement. Sans coucher conseillé, elle devient : « Choisis une heure de réveil pour obtenir un coucher conseillé. »
- VoiceOver lit les heures en mots, comme le fait déjà l'heure plafond (`ProfileText.clockSpoken`).

### 6.6 Écran Nuit (`NightFeature`)

Deux informations en plus, calculées depuis le cache local et jamais enregistrées :

- **L'écart à l'objectif**, dans la carte de résumé : « Objectif 8 h · 50 min de moins », ou « Objectif 8 h atteint ». L'objectif n'a pas d'historique : toutes les nuits sont comparées à l'objectif courant.
- **La régularité du coucher** : « Coucher régulier, à ± 25 min sur 14 nuits ». C'est l'écart moyen des heures d'endormissement à leur médiane, sur les 14 nuits qui se terminent à la nuit affichée, arrondi à 5 minutes. Il demande au moins 5 nuits, sinon la ligne n'apparaît pas. Le mot suit l'écart : « régulier » jusqu'à 30 min, « assez régulier » jusqu'à 60 min, « irrégulier » au-delà.

Chaque ligne a son libellé VoiceOver en mots. La carte de partage de la nuit ne change pas.

### 6.7 Confidentialité

- L'objectif, les heures de réveil choisies et les réglages du rappel sont des préférences : elles rejoignent le profil synchronisé et l'export.
- L'heure habituelle de réveil, l'écart à l'objectif et la régularité sont tirés d'Apple Santé : ils sont recalculés sur l'iPhone à chaque affichage et ne sont enregistrés nulle part.
- Les rappels sont des notifications locales : rien ne part vers un serveur.

## 7. Laissé au constructeur

- Les noms des types et des fichiers, et le découpage en étapes vérifiables une à une.
- Le contrôle de saisie des heures et de l'objectif (menu, roue, sélecteur d'heure), tant que les bornes et les pas de §6.1 tiennent.
- La place exacte des deux lignes sur l'écran Nuit, et leur mise en forme dans le style « Argentique ».
- La formulation finale des textes, tant que le sens et le ton de §6.4 tiennent.
- Le chemin de navigation de `AppLink.night` (onglet et écran d'arrivée).
- Vérifier si la page de confidentialité (`docs/confidentialite`) et la fiche App Store doivent mentionner les nouvelles préférences, et les mettre à jour si oui.

## 8. Laissé à vérifier sur iPhone (Mathéo)

- Le rappel arrive bien à l'heure annoncée dans les réglages, un seul par soir.
- Le texte du soir même cite la séance du lendemain, et la nuit courte quand il y en a une.
- Toucher le rappel ouvre l'écran Nuit.
- Changer l'objectif avant midi fait bouger le score du jour au retour sur Aujourd'hui ; après midi, il ne bouge pas.
- « Pourquoi » ne dit plus « tu n'as dormi que… » pour une nuit à moins d'une heure de l'objectif.
- « Selon mes nuits » affiche une heure plausible pour la semaine et pour le week-end.
- Le profil se synchronise encore après le déploiement du schéma CloudKit en production.
