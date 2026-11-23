/**
 * The six features, in the order of the spec (§6.3, point 4). Every sentence
 * is a short rewrite of the App Store description (docs/app-store/fiche.md,
 * §5): nothing here may promise more than the published build does.
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
    id: "seance",
    index: "02",
    eyebrow: "Séance live",
    title: "Chaque série compte.",
    body: "Chrono de repos, séries, records et récap : la séance se suit en direct. Tu peux aussi faire une séance libre, saisir une séance passée ou importer ton historique depuis Hevy.",
    screen: "/screens/workout.jpg",
    alt: "Le récap d'une séance Push dans Pulse : 1 h 15, 13 séries, 6 280 kg, un record, et les muscles sollicités sur la silhouette.",
  },
  {
    id: "programme",
    index: "03",
    eyebrow: "Programme",
    title: "Un programme à ta mesure.",
    body: "Adapté à ton niveau, ton matériel et tes douleurs ou limitations. Pulse ajuste la séance du jour selon ta récupération, et n'augmente les charges que lorsque ta ligne de base le permet.",
    screen: "/screens/planning.jpg",
    alt: "L'écran Planning de Pulse : la semaine du 16 novembre, avec la séance prévue chaque jour (Push, Pull, Legs).",
  },
  {
    id: "stats",
    index: "04",
    eyebrow: "Planning et statistiques",
    title: "Tes tendances, sans bruit.",
    body: "Ta charge d'entraînement sur 28 jours, tes courbes de variabilité et de fréquence cardiaque, tes muscles travaillés, ton assiduité et tes records. Tes courses et sorties à vélo d'Apple Santé comptent dans ta charge.",
    screen: "/screens/stats.jpg",
    alt: "L'écran Statistiques de Pulse, onglet Biométrie : fréquence cardiaque au repos de 68 bpm, sommeil moyen de 6 h 25 et récupération moyenne de 79.",
  },
  {
    id: "complements",
    index: "05",
    eyebrow: "Compléments",
    title: "Coché en une touche.",
    body: "Suis tes prises de vitamine D, de magnésium, de caféine et de protéines, ton stock et ta régularité, avec des rappels. Pulse ne conseille jamais de dose.",
    screen: null,
    alt: "Dessin de l'écran Compléments : 2 sur 4 pris aujourd'hui, la prochaine prise avec le bouton Pris, les prises cochées du matin, autour de la séance et du soir, et la régularité sur 30 jours.",
  },
  {
    id: "widgets",
    index: "06",
    eyebrow: "Widgets et Live Activity",
    title: "Sans ouvrir l'app.",
    body: "Ton score et ta séance du jour sur l'écran d'accueil et l'écran verrouillé, et ta séance en cours en Live Activity.",
    screen: null,
    alt: "Dessin d'un écran verrouillé : le widget du score de récupération, celui de la séance du jour, et la Live Activity d'une séance en cours pendant un repos.",
  },
];
