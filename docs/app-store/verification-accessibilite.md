# Pulse — vérification d'accessibilité à la main

Liste à passer sur un iPhone avec le build TestFlight, avant de soumettre. L'audit automatique (`AccessibilityAuditUITests`) attrape les étiquettes manquantes, les cibles trop petites, les textes coupés et les contrastes ; il n'entend pas la voix, ne juge pas l'ordre de lecture ni la qualité des phrases. Tout ce qui suit se vérifie donc à l'oreille et à l'œil.

Les phrases entre guillemets sont celles que VoiceOver doit dire (les nombres en toutes lettres : « 58 sur 100 », « 80 kilos », « 5 minutes 29 par kilomètre »). Jamais « tiret », « barre oblique », « deux-points », « kg », « bpm », « ms », « reps », « 1RM » ni un mois abrégé.

## 0. Préparer l'iPhone

- [ ] Réglages → Accessibilité → VoiceOver activé, voix française, débit confortable. Triple clic sur le bouton latéral réglé pour l'activer et le couper vite (Réglages → Accessibilité → Raccourci d'accessibilité).
- [ ] Un profil avec de l'historique (au moins quelques séances, des nuits Santé, un poids), pas seulement le jeu d'exemple vide.
- [ ] Une installation neuve disponible pour l'onboarding (supprimer l'app puis la réinstaller).
- [ ] Rotor VoiceOver réglé sur « En-têtes » et « Actions » : les deux servent plusieurs fois plus bas.

## 1. Lancer les tests d'interface

- [ ] Dans Xcode, lancer `AccessibilityAuditUITests` (cible `PulseUITests`) : l'audit passe sur Aujourd'hui, Séance, Planning, Stats, Profil, la séance en direct et le récap. Chaque échec nomme l'écran. Seul le contraste d'un élément décoratif sans texte (la trame de points) est écarté ; un contraste de texte ou de bouton signalé est un vrai défaut.
- [ ] Lancer aussi les trois tests d'interface existants : `OnboardingFlowUITests`, `LiveSessionResumeUITests`, `SupplementsUITests`.
- [ ] `OnboardingFlowUITests` a été modifié : il lit le libellé du cadran de calibration (« forme optimale ») au lieu de l'ancien identifiant de catégorie. Vérifier qu'il passe.

## 2. VoiceOver, écran par écran

Pour chaque écran : balayer de gauche à droite du début à la fin. L'ordre doit suivre la lecture visuelle, chaque élément se dit une seule fois (pas de doublon titre + valeur), et rien de purement décoratif ne doit être lu (trame de points, halo, pictogrammes de fond).

### Onboarding

- [ ] Bienvenue : le titre, puis « Commencer » ; l'ordre est naturel.
- [ ] Apple Santé : l'explication se lit en entier, puis le bouton d'autorisation.
- [ ] Profil : le bouton de la date de naissance dit « Renseigner la date de naissance ».
- [ ] Profil : les champs disent « Taille, en centimètres » et « Poids actuel, en kilos » (ou « en livres ») ; l'unité visible n'est pas lue en plus.
- [ ] Profil : le sélecteur d'unités (segments kg et lb) dit « kilos » et « livres » avec l'état sélectionné. Le sélecteur segmenté est le point à surveiller : s'il dit encore « kg », le signaler.
- [ ] Objectifs : les pastilles disent « 3 séances par semaine », avec l'état sélectionné ; les niveaux sont dans un groupe nommé.
- [ ] Programme : chaque jour du programme se lit une fois (le pictogramme, le repos en pointillés et la légende ne sont pas lus en double).
- [ ] Calibration : les trois questions du check-in ont leur titre comme nom de groupe ; l'estimation dit « Estimation : 58 sur 100, fatigue modérée » dès la troisième réponse, sans interrompre la saisie.
- [ ] Score prêt : à l'arrivée du cadran, VoiceOver annonce « Ton score est prêt : … » une seule fois. Le cadran est un seul élément : le titre, le score, la catégorie et « estimé » ou « en calibration, N nuits ».
- [ ] Erreur de pied de page (par exemple en coupant Apple Santé en cours de route) : le message est annoncé sans qu'on le cherche.

### Aujourd'hui

- [ ] L'ordre : réglage Profil, pastille de synchro, carte de récupération, séance du jour, charge, tuiles de tendance.
- [ ] La pastille de synchro dit « Synchro, 8 heures 30 » (ou « Synchro, pas encore »).
- [ ] La jauge de récupération est un seul élément : « … sur 100 », la catégorie, le marqueur « estimé » ou « en calibration, N nuits ». Le badge de l'en-tête n'est pas lu en double.
- [ ] Les facteurs de la carte se lisent un par un avec leur valeur (« 44 millisecondes », « 54 battements par minute »), sans « ms » ni « bpm ».
- [ ] Les tuiles de tendance disent le nom, la valeur et « tendance en hausse », « en baisse » ou « stable ».
- [ ] La carte de séance se lit en une phrase (titre, durée, trois muscles principaux). La carte musculaire est masquée ici : c'est voulu. Vérifier que l'intensité par muscle ne manque pas.
- [ ] Le titre de séance est repérable avec le rotor « En-têtes ».
- [ ] « Démarrer » est annoncé comme bouton ; une fois la séance faite, la carte dit « Séance faite, 55 minutes, 18 séries, 6 420 kilos, 2 records ».
- [ ] Score annoncé alors qu'un autre onglet est affiché : ouvrir Stats ou Planning, puis laisser le score changer (retour de l'app au premier plan, nuit Santé qui arrive). Noter si « Score mis à jour : … » ou « Ton score est prêt : … » est annoncé hors de l'onglet Aujourd'hui, et si c'est gênant.
- [ ] Après une nouvelle saisie du check-in qui change la note ou la catégorie : « Score mis à jour : … ». Sans changement : aucune annonce.
- [ ] Une erreur de check-in est annoncée, et l'est de nouveau si le même échec se répète.
- [ ] Écran « Pourquoi » : la lecture de ce matin dit « 5 battements par minute », « 5 heures 10 minutes » (pas « bpm », pas « 5 h 10 »). Les signaux se lisent avec leur nom complet (« Fréquence cardiaque au repos »).
- [ ] Écran « Pourquoi », titres produits par le moteur : « Effort plafonné à RPE 7,5 », « +2,5 kg », « volume −40 % », « 20 min de mobilité » restent lus tels qu'écrits. Vérifier qu'ils restent compréhensibles à l'oreille ; sinon, prévoir des variantes parlées dans `PulseRecoveryEngine` (décision reportée).
- [ ] Mobilité : le chrono est lu comme un compteur (pas à chaque seconde, mais à la demande) ; en fin de minuterie : « Mobilité terminée ».
- [ ] Bandeau « Reprendre la séance » : le chrono n'inonde pas VoiceOver.

### Séance (onglet)

- [ ] Les tuiles Force et Course, les routines et « Séance libre » sont des boutons avec un nom et un détail clairs.
- [ ] Bibliothèque : chaque exercice se lit avec son groupe musculaire ; la recherche et les filtres sont annoncés.
- [ ] Fiche d'un exercice : le graphique du maximum estimé se parcourt point par point (« 12 octobre, 80 kilos »), sans « 1RM » ni « kg ». Le résumé du graphique donne la tendance. Voir aussi la section Graphiques plus bas.
- [ ] Sélecteur RPE : dit la valeur (« 7,5 » ou « Aucun »).
- [ ] Éditeur de programme et de routine : les rangées se lisent en une phrase (jour, séance, détail) ; la rangée de course, qui n'est pas un bouton, dit son libellé.
- [ ] Historique : la date de chaque séance se lit en toutes lettres.
- [ ] Import Hevy : chaque étape est lue, l'erreur d'import est annoncée, et se réannonce à la répétition.
- [ ] Saisie d'une séance passée : la date dit « Mercredi 28 octobre, de 18 heures à 19 heures 5 ».
- [ ] Vérifier que la création d'une routine qui échoue puis réussit n'affiche plus l'ancien message.

### Séance en direct

- [ ] L'ordre : titre, « Terminer », menu, durée, tonnage, séries, puis les exercices dans l'ordre. Le menu dit « Abandonner » et « Annuler la saisie » pour une séance passée.
- [ ] Taille de texte par défaut, sur un petit iPhone (375 pt de large) : durée, tonnage et séries de l'en-tête s'affichent en entier. La limite de lignes a été retirée : une valeur longue passe à la ligne au lieu d'être coupée, vérifier que l'en-tête ne déborde pas ni ne se chevauche.
- [ ] Les trois stats du bandeau se disent « Durée … », « Tonnage … kilos », « Séries, 3 sur 12 ». Elles roulent sans spam VoiceOver.
- [ ] Une rangée de série se lit en une phrase : numéro, charge, répétitions, « Précédent : 70 kilos, 5 répétitions », état « validée » ou « non validée ». Pas de « 70 × 5 ».
- [ ] La coche dit « validée » après le toucher ; l'action « Passer le repos » n'est proposée que pendant un repos qui court.
- [ ] Clavier de séance : à l'ouverture, le focus VoiceOver va au champ en cours de saisie. C'est un délai de 300 ms réglé à l'estime : à contrôler sur l'iPhone. Si le focus arrive trop tôt (il reste sur la coche) ou trop tard, le signaler.
- [ ] Clavier de séance : chaque touche dit son chiffre ; la valeur saisie est annoncée à basse priorité, sans couper « Repos de … » ni « Repos terminé… ».
- [ ] Le champ RPE : les pilules disent leur valeur et l'état sélectionné.
- [ ] Repos : « Repos de 1 minute 30 » (pas « 90 s ») ; les boutons « moins 30 secondes », « plus 30 secondes », « Passer le repos ».
- [ ] Fin du repos : VoiceOver annonce « Repos terminé. Série suivante : Développé couché à la barre, 70 kilos, 5 répétitions ».
- [ ] Menu d'incrément de charge : les choix du menu disent « 2,5 kg ». Le menu système ignore les étiquettes parlées ; iOS lit « kg » en « kilogrammes » en français. À contrôler à l'oreille, c'est un compromis assumé.
- [ ] « Terminer » avec des séries restantes : la confirmation « Il reste N séries » est lue, « Terminer quand même » et « Continuer » sont des boutons.
- [ ] Séance oubliée (reprise après plus de 3 h) : l'alerte propose l'heure et les deux choix, lus clairement.
- [ ] Dernière fois (carte de l'exercice) : « Dernière fois : lest de 10 kilos, 8 répétitions, puis … » (pas de point médian).

### Récap

- [ ] À l'ouverture : « Nouveau record ! » (ou la liste des records en toutes lettres : « maximum estimé sur une répétition », « kilos »), annoncé une fois, y compris quand le récap était déjà chargé à l'apparition.
- [ ] Les tuiles disent « Durée, 55 minutes », « Tonnage, 12 450 kilos », « Séries, 14 séries ».
- [ ] La carte « Muscles travaillés » se lit en un bloc (groupes et séries), sans doublon d'en-tête ; « Compléments de la séance, 1 sur 2 » se lit une fois.
- [ ] Le trophée et le cœur barré ne sont pas lus.
- [ ] Le sélecteur RPE global dit la valeur et le mot (« 7 », « difficile »).
- [ ] Erreur d'enregistrement : « Pulse n'a pas pu enregistrer la séance. Elle est gardée : tu peux réessayer. » est annoncée à l'apparition de l'erreur. Réserve connue : une erreur déjà présente à l'ouverture du récap n'est pas annoncée, mais le texte visible et « Réessayer » restent lisibles.
- [ ] Explication Apple Santé : se lit en entier, « Continuer » reste atteignable, le défilement fonctionne.
- [ ] Après « Enregistrer » ou « Plus tard » : le récap se ferme et l'accueil affiche la séance faite.

### Planning

- [ ] La bande de la semaine : chaque jour dit « lundi 2, séance Push, à venir » ; le jour courant dit « aujourd'hui » et porte l'état sélectionné.
- [ ] Les rangées de la semaine : « Validée, 11 240 kilos », « Sortie facile, 45 minutes » ; l'activation du bouton fonctionne toujours.
- [ ] La carte du jour dit « Aujourd'hui, mercredi 18 » sans point médian.
- [ ] Détail d'une course : l'allure se dit « 5 minutes 29 par kilomètre », la distance en kilomètres, la fréquence « battements par minute » ; une valeur absente dit « Non renseigné », pas « tiret ».
- [ ] Mois et série : la légende se lit ; la rangée « Mois et série » et la carte de série disent « 1 semaine » (singulier) et non « 1 semaines », visible comme dit, et la rangée est lue sans point médian.
- [ ] Une séance déplacée : la raison dit « 36 heures » et non « 36 h » (écart reporté : à contrôler).
- [ ] Erreurs de chargement annoncées.

### Stats

- [ ] Le sélecteur de vue de l'écran dit son nom de groupe et l'état sélectionné.
- [ ] Charge : le total de chaque ligne est un seul élément (« Séances, 12 »), les barres à zéro restent présentes avec leur étiquette.
- [ ] Biométrie : la fréquence cardiaque au repos et le rapport aiguë sur chronique ont un résumé, un parcours point par point et le dernier point dit « 58 battements par minute ». Le nom de l'axe dit « Nuit » ou « Semaine ».
- [ ] « Récupération moyenne » dit « 64 sur 100 ».
- [ ] Muscles : la carte musculaire se lit par résumé (« Pectoraux, … ») ; la liste des négligés dit ses phrases (les phrases visibles ont encore un tiret cadratin : c'est visuel seulement).
- [ ] Records : chaque record dit « 80 kilos » et sa date en toutes lettres.
- [ ] Assiduité : chaque semaine se lit avec son nombre de séances.
- [ ] Le texte visible garde « kg », « ms », « bpm », « sept. » : seule la voix doit être développée.

### Profil

- [ ] L'ordre suit la lecture visuelle de haut en bas : l'en-tête, puis chaque section dans l'ordre affiché.
- [ ] Poids : le résumé du graphique dit « à 78 kilos » (sans plage si le minimum et le maximum sont égaux), les points se parcourent un par un avec leur date et leur valeur.
- [ ] Ligne de pesée et lignes de paramètres : activées par un toucher, mais VoiceOver ne doit pas annoncer un « bouton » en trop. Ces rangées utilisent un geste de toucher : si un bouton fantôme s'annonce ou si l'activation par double toucher échoue, le signaler.
- [ ] Paramètres : chaque interrupteur dit son nom et « activé » ou « désactivé » ; les actions nommées (supprimer une pesée) sont dans le rotor « Actions ».
- [ ] « Version 1.0.2 (numéro de build) » est lue avec sa ponctuation : à écouter ; écart connu, hors audit.
- [ ] Mes données : l'écran de suppression se lit en entier, la confirmation est une alerte claire.
- [ ] Apple Santé (relecture) : « Relire maintenant » annonce son résultat une seule fois, pas une fois par ligne de la section.
- [ ] Licences : la liste se lit rangée par rangée.

### Compléments

- [ ] Chaque rangée de prise se lit avec la dose en toutes lettres et l'état « pris » ou « à prendre », sous forme d'interrupteur (« activé » / « désactivé ») plutôt que de bouton.
- [ ] Les compléments « pas pour aujourd'hui » et leur prochaine prise se lisent en une seule phrase, avec un jour en toutes lettres.
- [ ] Un échec d'enregistrement d'une prise est annoncé une seule fois : ni l'échec du rechargement qui suit, ni la carte de l'accueil ne doivent parler en plus.
- [ ] Le rappel du matin (notification) et son action « Pris » : l'action est nommée et fonctionne.

### Widgets et Live Activity

- [ ] Écran verrouillé et écran d'accueil, VoiceOver actif : chaque widget (récupération, charge, série, prochaine séance, semaine) dit une phrase complète.
- [ ] Live Activity : la série suivante dit « Développé couché à la barre, série 2, 70 kilos, 5 répétitions », et les charges relatives « plus 10 kilos », « moins 20 kilos ».
- [ ] Widget semaine : le jour courant dit « aujourd'hui mercredi, fait » (ou « à venir », « repos »).
- [ ] Widgets de distance : « 1,5 kilomètre » au singulier sous 2, « 2 kilomètres » au pluriel.

### Graphiques et Audio Graphs

Ordre de lecture et Audio Graphs (rotor « Audio Graph » ou « Graphique audio ») : jamais testés à la main.

- [ ] Fiche d'exercice, poids (Profil), fréquence cardiaque au repos et rapport de charge (Stats) : l'élément du graphique dit son résumé, puis un balayage entre dans les points, dans l'ordre chronologique.
- [ ] Chaque point dit sa date et sa valeur, une seule fois (pas de doublon ligne + point). Les lignes et aires sont masquées, c'est voulu.
- [ ] Le rotor propose « Graphique audio » : la lecture joue une tonalité qui suit la courbe, avec les noms d'axe en français (« Date », « Maximum estimé en kilos », « Nuit »).
- [ ] Dans les graphiques dont seul le dernier point est étiqueté (fréquence cardiaque au repos, rapport), la navigation fine passe par le graphique audio : c'est le comportement voulu.
- [ ] Rien n'est lu deux fois, ni dans un ordre incohérent avec la lecture visuelle.

## 3. Dynamic Type au maximum

Réglages → Accessibilité → Affichage et taille du texte → Police plus grande → Tailles d'accessibilité plus grandes activées, curseur tout à droite. Relancer Pulse. Rien ne doit être tronqué (pas de « … » sur une valeur), rien ne doit se chevaucher, tout reste atteignable par défilement.

- [ ] Onboarding : les paires de champs passent en colonne, le pied (bouton) est atteignable en bas de page, les sélecteurs Sexe et Unités passent en menu, la date de naissance reste touchable (48 pt).
- [ ] Calibration : le titre, l'explication et le check-in défilent ensemble ; le grand score se réduit sans être coupé. La ligne de base passe en colonne.
- [ ] Aujourd'hui : la carte de récupération se met en pile, les tuiles de tendance passent à une colonne, la carte de charge n'est plus tronquée, la pastille de synchro garde une cible de 44 pt.
- [ ] Séance (onglet) : les rangées et les tuiles se lisent en entier.
- [ ] Séance en direct : le clavier, les pilules RPE et les rangées de série restent utilisables (plafond volontaire à accessibilité 3 pour ces éléments). À xLarge sur un écran de 375 pt, la colonne « Précédent » est étroite : vérifier qu'elle passe sur deux lignes sans couper. Dès xLarge, les rangées passent sur deux lignes.
- [ ] Récap : les noms de groupes musculaires passent en colonne, l'en-tête des cartes aussi, l'explication Apple Santé défile avec « Continuer » ancré en bas.
- [ ] Planning : la bande de la semaine garde des colonnes de 44 pt minimum (plafond à xxxLarge), les rangées empilent la date au-dessus, le badge « Ajustée » passe sous le titre, la légende du mois se réorganise, la carte de série passe en colonne avec son grand chiffre.
- [ ] Stats : les lignes de totaux passent en pile, les étiquettes d'axe restent lisibles, les tuiles ne se coupent pas.
- [ ] Profil : les rangées passent en colonne (valeur sous le libellé), les paramètres restent lisibles, les formulaires se saisissent.
- [ ] Compléments : les rangées passent en colonne, les doses ne sont jamais tronquées.
- [ ] Widgets : le plafond est xxxLarge. Les widgets de 158 pt et le rectangle de 66 pt reposent sur une réduction automatique du texte : aucune capture n'a été faite. Regarder chacun à xxxLarge sur l'iPhone, sur l'écran d'accueil et l'écran verrouillé, et noter tout texte coupé en haut ou en bas.
- [ ] Live Activity et Dynamic Island : le texte reste entier au plus grand réglage.
- [ ] Pilules de choix (objectifs, période des Stats, réglages) dans une rangée serrée, **à la taille par défaut** : un libellé long peut passer sur deux lignes. Vérifier qu'il n'est jamais coupé et que la rangée garde une cible de 44 pt.
- [ ] Retour à la taille par défaut en fin de passe.

## 4. Réduire les animations

Réglages → Accessibilité → Mouvement → Réduire les animations activé. Relancer Pulse.

- [ ] Aujourd'hui : la barre « Démarrer » ancrée apparaît et disparaît sans glisser (fondu seulement).
- [ ] Le halo d'arrière-plan ne dérive plus ; activer puis désactiver le réglage pendant que l'écran est affiché : le halo s'arrête sans relancer l'app.
- [ ] La jauge de récupération apparaît posée (graduations et aiguille sans balayage), le score ne fait plus rouler ses chiffres.
- [ ] Le check-in : l'estimation change sans roulement de chiffres.
- [ ] Séance en direct : la coche de série ne rebondit plus, le tonnage et le compte des séries changent sans rouler.
- [ ] Boutons : l'effet d'échelle à l'appui reste (le bouton se réduit toujours sous le doigt), mais il s'applique d'un coup, sans animation.
- [ ] Planning : le seul mouvement animé est le défilement vers un jour ; il passe par `PulseMotion` et saute directement au jour, sans défiler, quand le réglage est activé.
- [ ] Onboarding : le passage d'une étape à l'autre se fait en fondu.
- [ ] Stats et Profil : aucune barre ni courbe ne se dessine en s'animant.

## 5. Animations système non pilotables

Ces animations ne dépendent pas de Pulse et ne répondent pas à « Réduire les animations » (audit A §4). À vérifier une fois qu'elles restent acceptables, et à ne pas compter comme des défauts de l'app.

- [ ] Barre d'onglets qui se replie au défilement (`tabBarMinimizeBehavior(.onScrollDown)`, `MainTabView`). Le système la gère : vérifier qu'avec VoiceOver les onglets restent atteignables après un défilement.
- [ ] Effet de verre liquide (`GlassEffectContainer`, `Interaction.swift`) sur la barre ancrée et les contrôles : le système anime les reflets et les fusions.
- [ ] Anneau du repos de la Live Activity (`ProgressView(timerInterval:)`, `SessionLiveActivityViews`) : l'anneau se remplit en continu, sans contrôle de l'app. Le chrono du repos y est aussi lu par VoiceOver : vérifier qu'il ne parle pas chaque seconde.
- [ ] Transitions de navigation, feuilles et plein écrans (séance, récap) : animées par le système.
- [ ] Retours haptiques (appui des boutons) : ce ne sont pas des mouvements, rien à régler.

## 6. Contrastes et couleurs à confirmer sur l'appareil

- [ ] Carte de récupération : le texte « opalMuted » posé sur la trame de points reste lisible à pleine luminosité et en plein soleil. Aucune capture n'a été prise (interdit de lancer le simulateur) : c'est la seule vérification de contraste non couverte par le test unitaire de la palette. Si le texte est difficile à lire, ajuster `OpalCard` (design system, `Cards.swift`).
- [ ] Séance en direct, récap et Live Activity (forcés en sombre) : le texte secondaire (gris « muted » sombre) reste lisible.
- [ ] Réglages → Accessibilité → Affichage et taille du texte → Augmenter le contraste activé : rien ne disparaît.
- [ ] Réglages → Accessibilité → Affichage et taille du texte → Différencier sans la couleur activé : les états (validé, repos, manqué) se distinguent par le pictogramme ou le motif, pas seulement par la couleur.
- [ ] Widgets en mode sombre (ils suivent l'apparence du système) : tous les textes restent lisibles.

## 7. Autres contrôles

- [ ] Contrôle de la voix : « Appuyer sur Démarrer », « Appuyer sur Terminer », « Appuyer sur Renseigner la date de naissance » fonctionnent (les mots visibles sont gardés dans les étiquettes, comme « Synchro »).
- [ ] Accès par clavier / commutateur : tous les boutons de la séance sont atteignables.
- [ ] Texte en gras activé : aucune mise en page ne casse.

## 8. Fin de passe

- [ ] Les écarts sont notés avec l'écran, la phrase entendue et la phrase attendue.
- [ ] Les réglages d'accessibilité de l'iPhone sont remis à leurs valeurs d'origine.
- [ ] `AccessibilityAuditUITests` et les trois tests d'interface existants repassent après chaque correction.
