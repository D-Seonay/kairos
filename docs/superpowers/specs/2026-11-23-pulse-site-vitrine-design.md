# Pulse — site vitrine (landing page)

Date : 23 novembre 2026. Statut : validé par Mathéo le 23 novembre 2026 (« Yes et soit ultra créatif sur le style et les animations »).

Éditeur : Seonay Studio (réponse de Mathéo, 23 novembre 2026).

## 1. Intention

Pulse (iOS, « Pulse — Récupération & Muscu » sur l'App Store, app id `6829265826`) est en revue chez Apple, avec publication automatique dès l'approbation. Mathéo veut **une page de communication pour l'app**, sur le modèle de son autre produit, [abecedate.app](https://www.abecedate.app) (Seonay Studio, Next.js sur Vercel) : une page qui donne envie à quelqu'un qui ne connaît pas Pulse et l'envoie vers l'App Store.

Aujourd'hui, seules existent les pages légales servies par GitHub Pages depuis `docs/` (`https://d-seonay.github.io/kairos/confidentialite/` et `/support/`). La racine de ce site est vide.

## 2. Décisions de Mathéo

- **Même dépôt** que l'app (`D-Seonay/kairos`).
- **Next.js + Tailwind.**
- **Éditeur : Seonay Studio**, comme Abécédate.
- **Hébergement Vercel**, avec `site/` comme dossier racine du projet Vercel (option 1). GitHub Pages reste en place et continue de servir la confidentialité et l'assistance, **sans aucun changement**.

## 3. Approches envisagées

| Approche | Pour | Contre | Verdict |
| :--- | :--- | :--- | :--- |
| 1. Next.js dans `site/`, déployé par Vercel | Même méthode qu'Abécédate, aperçu par PR, domaine perso en deux clics, ne touche pas GitHub Pages | Deux hébergeurs tant que les pages légales restent sur Pages | **Choisie par Mathéo** |
| 2. Export statique Next publié sur GitHub Pages par une Action | Un seul hébergeur, gratuit | Il faut changer la source de Pages (dossier → Action) : une construction ratée fait tomber la politique de confidentialité, peut-être pendant la revue Apple. Préfixe `/kairos` à gérer, pas d'aperçu par PR | Écartée |
| 3. HTML généré et commité dans `docs/` | Rien à configurer | Mélange les fichiers construits et la source, casse au premier oubli de reconstruction | Écartée |

## 4. Objectifs, non-objectifs, anti-objectifs

**Objectifs**
- Faire comprendre en dix secondes ce que fait Pulse : un score de récupération chaque matin, qui décide de la séance du jour.
- Mener au téléchargement (bouton App Store).
- Rassurer sur la vie privée : c'est un vrai argument de Pulse (pas de compte, pas de serveur, les données Santé restent sur l'iPhone).
- Avoir l'air du même produit que l'app : direction « Argentique ».
- Bien s'afficher en partage (aperçu Open Graph) et être correctement référencée.

**Non-objectifs (pour cette version)**
- Blog, guide ou journal (Abécédate en a un ; on pourra l'ajouter plus tard, c'est une des raisons du choix de Next.js).
- Tarifs (l'app est gratuite), liste d'attente (l'app sort dans quelques jours), comptes.
- Version anglaise : l'app n'existe qu'en français.
- Rapatrier la confidentialité et l'assistance dans le site Next.
- Nom de domaine : Mathéo le choisira plus tard. Le site doit fonctionner sur l'adresse `*.vercel.app` et sur un domaine branché ensuite, sans modification de code (pas d'URL absolue codée en dur sauf via une seule constante de configuration).

**Anti-objectifs (ce qui ferait échouer la page même si elle « marche »)**
- **Tout traceur** : analytics (y compris Vercel Analytics et Speed Insights), pixels, polices ou scripts chargés depuis un tiers au moment de la visite. La page dit « aucune analytics » : elle doit l'être aussi. Conséquence : pas de bandeau cookies, puisqu'il n'y a pas de cookie.
- Une phrase fausse sur l'app. Chaque fonction citée doit exister dans la build publiée ; le texte de référence est la fiche App Store (`docs/app-store/fiche.md`, §5) et la page d'assistance.
- Laisser croire que Pulse est un dispositif médical. L'avertissement « Pulse n'est pas un dispositif médical » figure sur la page.
- Un site lourd ou lent sur mobile : la plupart des visites viendront d'un iPhone.
- Toucher à quoi que ce soit dans `docs/` publié, au projet Xcode, à `ci_scripts/` ou aux packages Swift.

## 5. Contraintes

- L'adresse `https://d-seonay.github.io/kairos/confidentialite/` est inscrite dans la build en revue et dans App Store Connect : elle ne bouge pas. Le site y renvoie par lien.
- Le dossier `site/` ne doit pas gêner Xcode Cloud ni la construction de l'app.
- Vercel ne doit reconstruire le site que si `site/` change (étape « Ignored Build Step » du projet, par exemple `git diff --quiet HEAD^ HEAD -- .`), pour ne pas déclencher un déploiement à chaque commit Swift.
- Le checkout principal est partagé avec d'autres sessions : tout le travail se fait sur la branche `site-vitrine` (worktree `../kairos-site`), avec une PR vers `master`. Pas de TestFlight : rien ne change dans l'app.
- Langue : français, tutoiement, comme l'app et la page d'assistance. Pas de tiret cadratin comme ponctuation de phrase.

## 6. Le site

### 6.1 Pile technique

- Next.js (dernière version stable, App Router, TypeScript), Tailwind CSS (dernière version stable), npm avec `package-lock.json` commité. Tout est statique (aucune route serveur, aucune variable d'environnement secrète).
- Polices auto-hébergées (fichiers servis par le site lui-même, via `next/font`), aucune requête vers Google Fonts au chargement.
- Images servies par `next/image` (formats modernes, tailles adaptées).
- Clair uniquement (`color-scheme: light`), comme l'app, qui force le thème clair.

### 6.2 Direction visuelle « Argentique »

Reprendre les jetons de `Packages/PulseDesignSystem/Sources/PulseDesignSystem/Tokens/` (version claire) :
- Papier chaud (#EFECE5 dans l'app ; les pages légales utilisent #F4F1EA), encre presque noire, gris « muted » AA (0x68655F), **une seule couleur vive**, le signal #FF4F2E, réservée aux accents (pastille, point de l'eyebrow, trait). Pas de texte courant dans cette couleur s'il n'atteint pas le contraste AA.
- Trame halftone (points) en motif de fond et sur les visuels, comme dans l'app et sur les captures marketing.
- Grands chiffres fins (le score) et petites étiquettes en majuscules monospaces (`pulseEyebrow`), titres en sans-serif très gras serrés, comme sur les captures m01–m05.
- Référence visuelle : les captures marketing et bannières déjà faites pour App Store Connect (voir §6.5) et l'icône halftone (tracé de pouls).

### 6.2 bis Ambition créative et animations

Mathéo, en validant ce document : « sois ultra créatif sur le style et les animations ». La page doit être mémorable, pas un gabarit de landing page. Fil conducteur proposé (choix de Claude, le constructeur peut aller plus loin dans cet esprit) : **l'argentique, la chambre noire et la nuit qui se révèle au matin**, en écho à « ta nuit décide de ta séance ».

- **Le hero se développe comme un tirage.** À l'arrivée, l'écran est de l'encre (la nuit, la chambre noire). Le tracé de pouls de l'icône se dessine comme un ECG, puis la page « se révèle » : la trame halftone apparaît, s'épaissit et vire au papier clair du matin, et le titre et les captures émergent du révélateur. Durée totale courte (≈ 2 s), sans bloquer la lecture ni le clic.
- **Une trame vivante.** Un champ de points halftone dessiné en canvas (ou WebGL léger) sert de matière à toute la page : les points grossissent sous le pointeur et au défilement, comme de l'encre qui monte, et la lumière du champ suit le score (plus le score est haut, plus la zone est claire, comme la dalle du score dans l'app).
- **Le simulateur est l'instrument central.** Un vrai cadran à graduations comme dans l'app : l'aiguille et le chiffre fin suivent les curseurs avec une inertie de ressort, les points de la jauge s'allument un à un, la catégorie change avec une transition de trame, et la séance d'exemple se recompose sous les yeux (séries qui disparaissent, repos qui s'allonge, bascule vers la mobilité en surmenage).
- **Un téléphone épinglé pendant les fonctionnalités.** L'iPhone reste fixe pendant qu'on fait défiler les six fonctionnalités, et l'écran change avec un fondu en trame (les points se dissolvent puis se recomposent).
- **Une planche contact.** Les captures sont aussi présentées comme une planche contact de pellicule 35 mm : bords perforés, numéros d'image (« 12A → »), mention « PULSE 400 », repères de coupe, une vue entourée au feutre de la couleur signal.
- **Des détails d'impression.** Repères de repérage dans les coins des sections, grain de film très léger, eyebrows monospaces comme des légendes de tirage, chiffres du bandeau qui défilent comme un compteur de pellicule.

Garde-fous, non négociables :
- `prefers-reduced-motion` : aucune animation de défilement, de ressort ni de révélation. Le hero s'affiche directement développé et le champ de points reste fixe. Le contenu est identique.
- Le texte et les boutons sont utilisables avant la fin de toute animation. Rien n'est caché derrière une animation pour un robot d'indexation ou un lecteur d'écran.
- Performance : animations sur `transform` et `opacity` ou en canvas, boucle mise en pause hors de l'écran et onglet caché, densité de points réduite sur mobile, objectif de §6.8 maintenu.
- Les bibliothèques d'animation éventuelles (Motion, GSAP…) sont installées par npm et servies par le site, jamais chargées depuis un CDN. Pas de défilement « lissé » qui détourne la molette ou le geste natif.
- Le mode « clair uniquement » du §6.1 veut dire : pas de bascule selon le thème du système. Le passage nuit → matin du hero est une animation, pas un thème.

La structure et le rythme s'inspirent d'Abécédate (nav fixe avec bouton d'action, hero centré avec pastille d'état, sections numérotées 01…06, bandeau de chiffres, FAQ dépliable, grand pied de page en colonnes), **pas sa palette rose ni sa typo serif**.

### 6.3 Une seule page, sections dans l'ordre

1. **Nav** : logo (icône + « Pulse »), ancres Fonctionnalités, Le score, Confidentialité, FAQ, et le bouton App Store. Sur mobile, menu compact.
2. **Hero** : pastille d'état (« Bientôt sur iPhone » puis « Disponible sur iPhone »), titre (direction : *« Ta nuit décide de ta séance. »*, à affiner par le constructeur), une phrase d'accroche reprise de la fiche, badge App Store, lien secondaire « Voir comment marche le score ↓ », trois puces courtes (gratuit, sans compte, données Santé sur l'iPhone), et deux ou trois captures dans un cadre d'iPhone.
3. **Le score, en direct** (l'équivalent de l'explorateur A-Z d'Abécédate) : le visiteur règle trois curseurs (sa nuit de sommeil, sa variabilité cardiaque par rapport à sa normale, sa fréquence cardiaque au repos par rapport à sa normale) et voit le score sur 100, sa catégorie et ce que Pulse fait de la séance du jour. Détails en §6.4.
4. **Fonctionnalités** (01 à 06) : score du matin et son explication, séance live (chrono de repos, séries, records, récap), programme adapté et ajusté selon la récupération, planning et statistiques (charge, VFC, muscles travaillés, assiduité, records, courses et vélo d'Apple Santé), compléments avec rappels et sans dose conseillée, widgets et Live Activity. Chaque bloc avec une capture ou un visuel.
5. **Pourquoi Pulse / tes données** : pas de compte, pas de serveur, pas de pub, aucune analytics ; les valeurs d'Apple Santé ne quittent pas l'iPhone ; ce que tu saisis se synchronise dans ton iCloud privé ; export JSON ou CSV et suppression complète depuis l'app. Lien vers la politique de confidentialité.
6. **Bandeau de chiffres** : uniquement des chiffres vrais et vérifiables dans le code ou la fiche (par exemple 0 publicité, 0 serveur, 14 nuits de ligne de base, 3 mesures lues chaque matin, 84 exercices au catalogue : à vérifier dans `Packages/PulseContent` avant d'écrire le chiffre).
7. **FAQ** : 5 à 7 questions reprises de la page d'assistance et de la fiche (pourquoi pas de score, montre autre qu'Apple Watch, durée de calibration, Android, prix, dispositif médical, où vont mes données). Réponses courtes avec lien vers l'assistance complète.
8. **Appel final** : badge App Store et icône.
9. **Pied de page** : « Pulse par Seonay Studio ↗ » (lien seonay.com), liens Confidentialité et Assistance (GitHub Pages), Mentions légales (§6.7), contact par e-mail (constante `CONTACT_EMAIL`, §6.7), avertissement médical, « © 2026 Pulse par Seonay Studio ».

### 6.4 Le simulateur de score

- Il reprend **les formules exactes du moteur** (`Packages/PulseRecoveryEngine/Sources/PulseRecoveryEngine/`) portées en TypeScript dans un module pur et testé :
  - `HRVScorer` (paliers du z-score), `RHRScorer` (écart en bpm à la moyenne sur 7 jours), `SleepScorer` (durée sur 480 min pour 70, part de profond sur 20 % pour 30) ;
  - pondération nominale VFC 0,50, FC repos 0,25, sommeil 0,25 (`RecoveryCalculator.nominalWeight`) ;
  - catégories : optimal ≥ 90, normal ≥ 65, fatigue modérée ≥ 40, surmenage sinon (`PulseDomain/Recovery/RecoveryCategory.swift`) ; libellés repris du catalogue de chaînes de l'app ;
  - ajustement d'une séance de force d'exemple selon la catégorie (`SessionAdjuster` : repos +15 s en normal ; −20 % de volume, RPE plafonné à 7,5 et repos +45 s en fatigue modérée ; 20 min de mobilité ou repos en surmenage).
- Les tests du module reprennent les cas des tests Swift des scorers et de la catégorie, pour garantir que le site dit la même chose que l'app.
- Sommeil (choix du constructeur, validé par Claude) : un seul curseur, la durée. La part de sommeil profond est fixée à une valeur typique (15 %) et le dit en petit sous le curseur, pour rester sur la formule avec phases qu'utilise une Apple Watch.
- Côté visiteur, les curseurs parlent en mots simples (heures de sommeil, « VFC plus basse / dans ta normale / plus haute », « FC repos +X bpm »). Le passage du curseur VFC au z-score est un choix du constructeur, documenté dans le code.
- Mention visible : « Simulation avec les mêmes formules que l'app. Dans Pulse, tes valeurs sont comparées à ta propre ligne de base. »
- Rendu : grand chiffre fin, jauge en points façon halftone, catégorie, liste des ajustements. Accessible au clavier et à VoiceOver (curseurs natifs `input type=range` avec libellés et valeurs parlées, résultat annoncé poliment).

### 6.5 Visuels

- Captures brutes de l'app (1320 × 2868) et captures marketing m01–m05, l01–l05 (1206 × 2622), bannières : actuellement dans le dossier temporaire d'une session précédente, `/private/tmp/claude-501/-Users-seonay-Repositories-fitness/952123ad-0b01-4414-97fe-9e8c006fb9d5/scratchpad/` (`screens/`, `final/`, avec les sources `shot.html` et `banner.html`). **À copier dans `site/public/` tôt**, ce dossier peut disparaître. Les captures affichent le prénom de Mathéo, déjà public sur la fiche App Store.
- Icône : les PNG 1024 de `Pulse/Assets.xcassets/AppIcon.appiconset/` (variante claire) servent de logo, favicon et `apple-touch-icon`.
- Cadre d'iPhone dessiné en CSS (pas d'image Apple officielle de l'appareil).

### 6.6 Bouton App Store et état de sortie

- Badge officiel « Télécharger dans l'App Store » en français, tiré des outils marketing d'Apple et embarqué en SVG dans le site, en respectant les règles d'usage d'Apple (taille minimale, marge, pas de modification).
- Lien : `https://apps.apple.com/fr/app/id6829265826`.
- Une seule constante (`APP_STORE_LIVE`) bascule entre « Bientôt sur l'App Store » (pastille, badge non cliquable ou grisé) et « Disponible » (badge cliquable). Elle démarre selon l'état réel de la revue au moment de la mise en ligne.
- Balise `<meta name="apple-itunes-app" content="app-id=6829265826">` pour la bannière Safari, active seulement une fois l'app disponible.

### 6.7 Référencement et pages annexes

- Métadonnées françaises (titre, description, canonical depuis la constante d'URL du site), image Open Graph 1200 × 630 générée au build (`next/og`) ou tirée des bannières, `sitemap.xml`, `robots.txt`, données structurées `SoftwareApplication` (gratuit, iOS, catégorie santé et forme).
- Page `/mentions-legales` (LCEN), **sur le modèle de https://www.abecedate.app/mentions-legales** :
  1. Éditeur du site et de l'application : Seonay Studio (seonay.com), nom commercial du service : Pulse, siège social : France, courrier électronique : `CONTACT_EMAIL`, directeur de la publication : le représentant légal de Seonay Studio.
  2. Hébergement : Vercel Inc., 340 S Lemon Ave #4133, Walnut, CA 91789, USA, vercel.com. Les pages Confidentialité et Assistance sont servies par GitHub Pages (GitHub, Inc., 88 Colin P Kelly Jr St, San Francisco, CA 94107, USA). L'app n'a aucun serveur.
  3. Propriété intellectuelle : Seonay Studio, avec la mention de la carte musculaire MuscleMap (licence MIT) déjà déclarée sur App Store Connect.
  4. Données personnelles et cookies : le site ne dépose aucun cookie et ne mesure pas l'audience ; lien vers la politique de confidentialité de l'app.
  5. Contact : `CONTACT_EMAIL`.
- `CONTACT_EMAIL` et l'éventuel SIRET sont des constantes uniques. Abécédate n'affiche pas de SIRET : on fait pareil, sauf demande contraire de Mathéo. **Adresse e-mail à fournir par Mathéo** ; tant qu'elle manque, le build échoue en production plutôt que de publier une adresse fictive.
- Page 404 sobre dans le même style.

### 6.8 Accessibilité et performance

- Contraste AA partout, navigation clavier, focus visible, une seule balise `h1`, hiérarchie de titres propre, textes alternatifs des captures qui disent ce qu'elles montrent.
- `prefers-reduced-motion` respecté : pas d'animation de défilement ni de jauge animée dans ce cas.
- Lisible de 360 px à grand écran, sans défilement horizontal.
- Objectif Lighthouse mobile ≥ 90 en performance et 100 en accessibilité, bonnes pratiques et SEO.

## 7. Livraison et vérification

- Branche `site-vitrine`, PR vers `master`. Vercel fournit l'aperçu de la PR une fois le projet relié.
- Création du projet Vercel dans l'équipe « Seonay » (`team_NMyd7G2WJKdkhKLq165tqwx5`, la seule que voit le connecteur) : relier `D-Seonay/kairos`, dossier racine `site`, étape « Ignored Build Step ». Action sur le compte de Mathéo, faite seulement avec son accord explicite. Sans accord, le plan s'arrête à une construction locale vérifiée, et l'URL du site vient de `VERCEL_PROJECT_PRODUCTION_URL` avec repli sur une constante.
- Vérifications avant de dire que c'est prêt : `npm run lint`, vérification des types, tests du module de score, `npm run build` sans erreur ; captures de la page en largeur mobile et bureau regardées ; contrôle qu'aucune requête ne part vers un tiers au chargement (onglet réseau ou équivalent).

## 8. Laissé au constructeur / questions ouvertes

**Au constructeur :** le texte exact (dans le respect du §4), le choix des polices (proches de SF et d'une mono, auto-hébergées), le détail de la mise en page, les animations légères, le passage curseur VFC → z-score, la séance d'exemple du simulateur, la structure des composants.

**Choix de Claude :** curseur de sommeil unique avec 15 % de profond fixe (§6.4) ; mentions légales calquées sur celles d'Abécédate, sans SIRET (§6.7).

**Reste à fournir par Mathéo :** l'adresse e-mail de contact (§6.7) ; son accord pour créer le projet Vercel dans l'équipe « Seonay » (§7).
