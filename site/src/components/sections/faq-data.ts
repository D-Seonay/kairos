/**
 * The questions of the FAQ. Answers are short and come from the support page
 * (docs/support/index.html) and the store sheet (docs/app-store/fiche.md): each
 * sentence has to stay true for the published build.
 */
export type FaqEntry = {
  id: string;
  question: string;
  answer: string;
};

export const FAQ: FaqEntry[] = [
  {
    id: "pas-de-score",
    question: "Pourquoi je n'ai pas de score ?",
    answer:
      "Pulse calcule ton score avec trois mesures lues dans Apple Santé : le sommeil, la variabilité cardiaque (VFC) et la fréquence cardiaque au repos. Il lui en faut au moins deux. Vérifie que Pulse a accès à ces données dans l'app Santé et porte ta montre pour dormir. Sinon, un check-in de trois questions te donne un score estimé.",
  },
  {
    id: "autre-montre",
    question: "Ma montre n'est pas une Apple Watch, ça marche ?",
    answer:
      "Pulse ne parle pas à ta montre : il lit ce qu'elle écrit dans Apple Santé. Si elle y enregistre ton sommeil, ta VFC et ta fréquence cardiaque au repos, Pulse peut les utiliser. La VFC est lue sous sa forme SDNN : avec une autre mesure, le score s'appuie sur le reste ou sur le check-in.",
  },
  {
    id: "calibration",
    question: "Combien de temps dure la calibration ?",
    answer:
      "Pulse construit ta ligne de base de VFC sur tes 14 dernières nuits. Le facteur VFC peut entrer dans ton score dès 5 nuits, la ligne de base est complète à 14. Jusque-là, l'app affiche « En calibration » et ne te propose pas d'augmenter tes charges.",
  },
  {
    id: "android",
    question: "Pulse existe-t-il sur Android ?",
    answer:
      "Non. Pulse n'existe que sur iPhone : il lit tes données dans Apple Santé. L'interface est uniquement en français.",
  },
  {
    id: "prix",
    question: "Combien ça coûte ?",
    answer: "Rien. Pulse est gratuit, sans compte, sans publicité et sans achat intégré.",
  },
  {
    id: "medical",
    question: "Pulse est-il un dispositif médical ?",
    answer:
      "Non. Pulse ne diagnostique rien. Le score et les ajustements sont des repères d'entraînement, pas un avis médical. Au moindre doute sur ta santé, parle à un professionnel.",
  },
  {
    id: "donnees",
    question: "Où vont mes données ?",
    answer:
      "Pulse n'a aucun serveur. Les valeurs lues dans Apple Santé restent sur ton iPhone, et dans sa sauvegarde si tu l'as activée. Ce que tu saisis et ce que Pulse calcule se synchronise dans ton iCloud privé. Tu peux tout exporter en JSON ou CSV, ou tout supprimer, depuis Profil, Mes données.",
  },
];
