// Port of Adjustments/SessionAdjuster.swift and VolumeReducer.swift (without super sets).
import type { Category } from "./engine";

export type Exercise = { name: string; sets: number; reps: number; rpe: number; restSeconds: number };

export type Adjusted = { exercises: Exercise[]; reasons: string[]; mobility: boolean };

export const SAMPLE_PUSH: Exercise[] = [
  { name: "Développé couché", sets: 4, reps: 8, rpe: 8, restSeconds: 120 },
  { name: "Développé militaire", sets: 3, reps: 10, rpe: 8, restSeconds: 90 },
  { name: "Écarté à la poulie", sets: 3, reps: 12, rpe: 8.5, restSeconds: 60 },
  { name: "Dips", sets: 3, reps: 10, rpe: 8, restSeconds: 90 },
];

const NORMAL_EXTRA_REST = 15;
const FATIGUE_EXTRA_REST = 45;
const FATIGUE_RPE_CAP = 7.5;
const VOLUME_REDUCTION = 0.2;
const MOBILITY_MINUTES = 20;

/** Retire environ 20 % des séries : séries décroissantes puis ordre, jamais sous 1 série. */
function reduceVolume(exercises: Exercise[], ratio: number): { exercises: Exercise[]; removedSets: number } {
  const total = exercises.reduce((sum, e) => sum + e.sets, 0);
  const target = Math.round(total * ratio);
  const remaining = exercises.map((e) => ({ ...e }));
  let removed = 0;
  let removedThisRound = true;
  while (removed < target && removedThisRound) {
    removedThisRound = false;
    const order = remaining
      .map((e, index) => ({ index, sets: e.sets }))
      .sort((a, b) => (a.sets !== b.sets ? b.sets - a.sets : a.index - b.index));
    for (const { index } of order) {
      if (remaining[index].sets > 1 && removed + 1 <= target) {
        remaining[index].sets -= 1;
        removed += 1;
        removedThisRound = true;
      }
    }
  }
  return { exercises: remaining, removedSets: removed };
}

function withRest(exercises: Exercise[], seconds: number): Exercise[] {
  return exercises.map((e) => ({ ...e, restSeconds: e.restSeconds + seconds }));
}

function restReason(seconds: number): string {
  return `Repos rallongés de ${seconds} secondes`;
}

export function adjustSession(day: Exercise[], category: Category): Adjusted {
  switch (category) {
    case "optimal":
      return { exercises: day.map((e) => ({ ...e })), reasons: [], mobility: false };
    case "normal":
      return {
        exercises: withRest(day, NORMAL_EXTRA_REST),
        reasons: [restReason(NORMAL_EXTRA_REST)],
        mobility: false,
      };
    case "moderateFatigue": {
      const reasons: string[] = [];
      const before = day.reduce((sum, e) => sum + e.sets, 0);
      const reduced = reduceVolume(day, VOLUME_REDUCTION);
      if (reduced.removedSets > 0) {
        reasons.push(`Volume réduit de ${before} à ${before - reduced.removedSets} séries`);
      }
      let exercises = reduced.exercises;
      if (exercises.some((e) => e.rpe > FATIGUE_RPE_CAP)) {
        exercises = exercises.map((e) => ({ ...e, rpe: Math.min(e.rpe, FATIGUE_RPE_CAP) }));
        reasons.push("Effort plafonné à RPE 7,5");
      }
      reasons.push(restReason(FATIGUE_EXTRA_REST));
      return { exercises: withRest(exercises, FATIGUE_EXTRA_REST), reasons, mobility: false };
    }
    case "overreached":
      return {
        exercises: day.map((e) => ({ ...e })),
        reasons: [`Séance remplacée par ${MOBILITY_MINUTES} min de mobilité ou du repos, au choix`],
        mobility: true,
      };
  }
}
