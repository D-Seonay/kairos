/**
 * The eight features: the six of the spec (§6.3, point 4), with the Nuit
 * screen after the score and the GPS run after the session (version 1.0.3), and the news of
 * 1.0.4 and 1.0.5 in a sentence each. Every sentence is a short rewrite of the App Store
 * description (docs/app-store/fiche.md, §5): nothing here may promise more than the
 * published build does.
 */
export type Feature = {
  id: string;
  index: string;
  /** Monospace caption above the title, like the legend of a print. */
  eyebrow: string;
  title: string;
  body: string;
  /** A raw capture in public/, or null when the visual is drawn in HTML and CSS. */
  screen: string | null;
  /** What the visual shows, for the image's alternative text. */
  alt: string;
};

/**
 * The one alternative text of public/screens/today.jpg, shared by the hero, the
 * contact sheet and the feature list: the score is an estimate, and the screen
 * names what is missing.
 */
export const TODAY_SCREEN_ALT =
  "L'écran Aujourd'hui de Pulse : un score de récupération de 58 sur 100, en fatigue modérée, estimé. Sous le score, ce qui manque : pas de donnée de sommeil ni de FC repos cette nuit, et la ligne de base de variabilité en cours.";

export const FEATURES: Feature[] = [
  {
    id: "score",
    index: "01",
    eyebrow: "Récupération",
    title: "Ton score, chaque matin.",
    body: "Pulse lit ton sommeil, ta variabilité cardiaque et ta fréquence cardiaque au repos dans Apple Santé, et les compare à ta propre ligne de base. Tu vois ce qui explique le score, et ce qui manque quand une mesure est absente. Pas de montre ? Un check-in de trois questions prend le relais.",
    screen: "/screens/today.jpg",
    alt: TODAY_SCREEN_ALT,
  },
  {
    id: "nuit",
    index: "02",
    eyebrow: "Sommeil",
    title: "Ta nuit, phase par phase.",
    body: "L'écran Nuit montre ton hypnogramme et ta répartition entre sommeil profond, paradoxal, léger et éveil, à côté de ta moyenne. Tu passes d'une nuit à l'autre, et tes statistiques empilent chaque nuit par phase. Choisis ton objectif de sommeil : Pulse en déduit ton heure de coucher et peut te la rappeler.",
    screen: null,
    alt: "Dessin de l'écran Nuit : la nuit du 23 au 24 novembre, 7 h 12 endormi, de 23:10 à 06:50 avec 2 réveils. L'hypnogramme alterne les phases, puis la répartition : profond 1 h 25, léger 4 h 02, paradoxal 1 h 45, éveil 28 min.",
  },
  {
    id: "seance",
    index: "03",
    eyebrow: "Musculation",
    title: "Chaque série compte.",
    body: "Chrono de repos, séries, records et récap : la séance se suit en direct. Ajoute jusqu'à six photos à une séance. Tu peux aussi faire une séance libre, saisir une séance passée ou importer ton historique depuis Hevy. Pulse repère un exercice qui plafonne, et ta séance se partage en story en une touche.",
    screen: "/screens/workout.jpg",
    alt: "Le récap d'une séance Push dans Pulse : 1 h 15, 13 séries, 6 280 kg, un record, et les muscles sollicités sur la silhouette.",
  },
  {
    id: "course",
    index: "04",
    eyebrow: "Course GPS",
    title: "Cours, téléphone en poche.",
    body: "Lance ta course depuis Pulse : temps, distance et allure en direct, une annonce vocale à chaque kilomètre, et la course sur l'écran verrouillé. Le récap montre ton tracé et tes temps au kilomètre. La course part dans Apple Santé avec son parcours et compte dans ta charge, et ton tracé s'exporte en GPX.",
    screen: null,
    alt: "Dessin de l'écran Course : footing facile avec un objectif de 30 minutes, 24:13 de course, 4,38 km, une allure de 5'31\" au kilomètre en cours et 5'32\" en moyenne, l'objectif atteint à 81 %, les annonces vocales activées, et les boutons Pause et Terminer.",
  },
  {
    id: "programme",
    index: "05",
    eyebrow: "Programme",
    title: "Un programme à ta mesure.",
    body: "Adapté à ton niveau, ton matériel et tes douleurs ou limitations. Pulse ajuste la séance du jour selon ta récupération, et n'augmente les charges que lorsque ta ligne de base le permet.",
    screen: "/screens/planning.jpg",
    alt: "L'écran Planning de Pulse : la semaine du 16 novembre, avec la séance prévue chaque jour (Push, Pull, Legs).",
  },
  {
    id: "stats",
    index: "06",
    eyebrow: "Planning et statistiques",
    title: "Tes tendances, sans bruit.",
    body: "Ta charge d'entraînement sur 28 jours, tes courbes de variabilité et de fréquence cardiaque, tes muscles travaillés, ton assiduité et tes records. Tes courses et sorties à vélo d'Apple Santé comptent dans ta charge.",
    screen: "/screens/stats.jpg",
    alt: "L'écran Statistiques de Pulse, onglet Biométrie : fréquence cardiaque au repos de 68 bpm, sommeil moyen de 6 h 25 et récupération moyenne de 79.",
  },
  {
    id: "complements",
    index: "07",
    eyebrow: "Compléments",
    title: "Coché en une touche.",
    body: "Suis tes prises de vitamine D, de magnésium, de caféine et de protéines, ton stock et ta régularité, avec des rappels. Pulse ne conseille jamais de dose.",
    screen: null,
    alt: "Dessin de l'écran Compléments : 2 sur 4 pris aujourd'hui, la prochaine prise avec le bouton Pris, les prises cochées du matin, autour de la séance et du soir, et la régularité sur 30 jours.",
  },
  {
    id: "widgets",
    index: "08",
    eyebrow: "Widgets et Live Activity",
    title: "Sans ouvrir l'app.",
    body: "Ton score et ta séance du jour sur l'écran d'accueil et l'écran verrouillé, et ta séance ou ta course en cours en Live Activity, où tu valides tes séries. Demande ton score à Siri, ou lance ta séance et ta course d'un raccourci.",
    screen: null,
    alt: "Dessin d'un écran verrouillé : le widget du score de récupération, celui de la séance du jour, et la Live Activity d'une séance en cours pendant un repos.",
  },
];
