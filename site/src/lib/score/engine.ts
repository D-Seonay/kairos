// Port of Scoring/HRVScorer.swift, RHRScorer.swift, SleepScorer.swift, Recovery/RecoveryCalculator.swift and PulseDomain RecoveryCategory.swift.

export type Category = "optimal" | "normal" | "moderateFatigue" | "overreached";

export const CATEGORY_LABEL: Record<Category, string> = {
  optimal: "Forme optimale",
  normal: "Forme normale",
  moderateFatigue: "Fatigue modérée",
  overreached: "Surmenage",
};

export const WEIGHTS = { hrv: 0.5, restingHeartRate: 0.25, sleep: 0.25 } as const;

/** Part de sommeil profond supposée par le simulateur. */
export const DEEP_SHARE = 0.15;
/** Écart-type de ln(SDNN) supposé par le simulateur. */
export const HRV_LOG_SD = 0.12;

const TARGET_SLEEP_MINUTES = 480;
const TARGET_DEEP_RATIO = 0.2;

export const SLEEP_RANGE = { min: 3, max: 10, step: 0.25 } as const;
export const HRV_RANGE = { min: -40, max: 30, step: 1 } as const;
export const RHR_RANGE = { min: -5, max: 15, step: 1 } as const;

export function hrvScore(z: number): number {
  if (z >= 0.5) return 100;
  if (z >= -0.5) return 80 + (z + 0.5) * 20;
  if (z >= -1.5) return 50 + (z + 1.5) * 30;
  return Math.max(10, 50 + (z + 1.5) * 25);
}

export function rhrScore(todayBpm: number, baselineBpm: number): number {
  const delta = todayBpm - baselineBpm;
  if (delta <= 0) return 100;
  if (delta <= 7) return 100 - delta * 8.5;
  return Math.max(0, 40 - (delta - 7) * 10);
}

export function sleepScore(asleepMinutes: number, deepMinutes: number | null): number {
  if (asleepMinutes <= 0) return 0;
  const duration = Math.min(1, asleepMinutes / TARGET_SLEEP_MINUTES);
  if (deepMinutes === null) return duration * 100;
  const deepRatio = deepMinutes / asleepMinutes;
  return duration * 70 + Math.min(1, deepRatio / TARGET_DEEP_RATIO) * 30;
}

export function category(score: number): Category {
  if (score >= 90) return "optimal";
  if (score >= 65) return "normal";
  if (score >= 40) return "moderateFatigue";
  return "overreached";
}

export function hrvZFromPercent(percent: number): number {
  return Math.log(1 + percent / 100) / HRV_LOG_SD;
}

export type SimulatorInput = { sleepHours: number; hrvPercent: number; rhrDeltaBpm: number };

export type SimulatorResult = {
  score: number;
  displayScore: number;
  category: Category;
  factors: { hrv: number; restingHeartRate: number; sleep: number };
};

const BASELINE_RHR_BPM = 50;

export function simulate(input: SimulatorInput): SimulatorResult {
  const asleepMinutes = Math.round(input.sleepHours * 60);
  const deepMinutes = Math.round(input.sleepHours * 60 * DEEP_SHARE);
  const factors = {
    hrv: hrvScore(hrvZFromPercent(input.hrvPercent)),
    restingHeartRate: rhrScore(BASELINE_RHR_BPM + input.rhrDeltaBpm, BASELINE_RHR_BPM),
    sleep: sleepScore(asleepMinutes, deepMinutes),
  };
  const raw =
    factors.hrv * WEIGHTS.hrv +
    factors.restingHeartRate * WEIGHTS.restingHeartRate +
    factors.sleep * WEIGHTS.sleep;
  const score = Number.isFinite(raw) ? Math.min(100, Math.max(0, raw)) : 0;
  return { score, displayScore: Math.round(score), category: category(score), factors };
}
