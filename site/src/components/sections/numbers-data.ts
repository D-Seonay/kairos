/**
 * The figures of the numbers band. Each one is true and checkable: `source` is a
 * path from the repository root to a file that proves it, and
 * numbers-data.test.ts reads those files (the exercise count and the baseline
 * window are recomputed from the catalogue and the calculator).
 */
export type NumberFigure = {
  value: string;
  label: string;
  source: string;
};

export const NUMBERS: NumberFigure[] = [
  { value: "0", label: "publicité", source: "docs/app-store/fiche.md" },
  { value: "0", label: "serveur Pulse", source: "docs/app-store/fiche.md" },
  {
    value: "14",
    label: "nuits pour ta ligne de base",
    source: "Packages/PulseRecoveryEngine/Sources/PulseRecoveryEngine/Recovery/RecoveryCalculator.swift",
  },
  { value: "3", label: "mesures lues chaque matin", source: "docs/app-store/fiche.md" },
  {
    value: "93",
    label: "exercices au catalogue",
    source: "Packages/PulseContent/Sources/PulseContent/Resources/exercises.json",
  },
];
