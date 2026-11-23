import { describe, expect, it } from "vitest";
import {
  CATEGORY_LABEL,
  HRV_LOG_SD,
  category,
  hrvScore,
  hrvZFromPercent,
  rhrScore,
  simulate,
  sleepScore,
  WEIGHTS,
} from "./engine";

describe("hrvScore", () => {
  it.each([
    [2, 100],
    [0.5, 100],
    [0, 90],
    [-0.5, 80],
    [-1, 65],
    [-1.5, 50],
    [-2, 37.5],
    [-3.5, 10],
    [-10, 10],
  ])("z=%s gives %s", (z, expected) => {
    expect(hrvScore(z)).toBeCloseTo(expected, 9);
  });
});

describe("rhrScore", () => {
  it.each([
    [48, 100],
    [50, 100],
    [52, 83],
    [57, 40.5],
    [59, 20],
    [62, 0],
    [70, 0],
  ])("today=%s bpm gives %s", (today, expected) => {
    expect(rhrScore(today, 50)).toBeCloseTo(expected, 9);
  });
});

describe("sleepScore", () => {
  it("scores duration and deep share", () => {
    expect(sleepScore(480, 96)).toBeCloseTo(100, 9);
    expect(sleepScore(360, 36)).toBeCloseTo(67.5, 9);
    expect(sleepScore(540, 162)).toBeCloseTo(100, 9);
  });
  it("scores duration only without phases", () => {
    expect(sleepScore(360, null)).toBeCloseTo(75, 9);
  });
  it("gives 0 for no sleep", () => {
    expect(sleepScore(0, null)).toBe(0);
  });
});

describe("category", () => {
  it.each([
    [100, "optimal"],
    [90, "optimal"],
    [89.99, "normal"],
    [65, "normal"],
    [64.99, "moderateFatigue"],
    [40, "moderateFatigue"],
    [39.99, "overreached"],
    [0, "overreached"],
  ] as const)("score %s is %s", (score, expected) => {
    expect(category(score)).toBe(expected);
  });

  it("has French labels", () => {
    expect(CATEGORY_LABEL).toEqual({
      optimal: "Forme optimale",
      normal: "Forme normale",
      moderateFatigue: "Fatigue modérée",
      overreached: "Surmenage",
    });
  });
});

describe("constants", () => {
  it("exposes the nominal weights", () => {
    expect(WEIGHTS).toEqual({ hrv: 0.5, restingHeartRate: 0.25, sleep: 0.25 });
  });
  it("converts a percent to a z-score", () => {
    expect(hrvZFromPercent(0)).toBe(0);
    expect(hrvZFromPercent(10)).toBeCloseTo(Math.log(1.1) / HRV_LOG_SD, 12);
  });
});

describe("simulate", () => {
  it("matches the hand computed neutral case", () => {
    const result = simulate({ sleepHours: 8, hrvPercent: 0, rhrDeltaBpm: 0 });
    expect(result.score).toBeCloseTo(0.5 * 90 + 0.25 * 100 + 0.25 * (70 + 0.75 * 30), 9);
    expect(result.category).toBe("optimal");
    expect(result.displayScore).toBe(93);
  });

  it.each([
    [{ sleepHours: 3, hrvPercent: -40, rhrDeltaBpm: 15 }],
    [{ sleepHours: 10, hrvPercent: 30, rhrDeltaBpm: -5 }],
  ])("stays finite and within 0 to 100 at extremes %j", (input) => {
    const result = simulate(input);
    expect(Number.isFinite(result.score)).toBe(true);
    expect(result.score).toBeGreaterThanOrEqual(0);
    expect(result.score).toBeLessThanOrEqual(100);
    expect(Number.isFinite(result.displayScore)).toBe(true);
  });

  it("falls back to a finite score when the HRV percent makes the log undefined", () => {
    const result = simulate({ sleepHours: 8, hrvPercent: -150, rhrDeltaBpm: 0 });
    expect(Number.isFinite(result.score)).toBe(true);
    expect(result.score).toBeGreaterThanOrEqual(0);
    expect(result.score).toBeLessThanOrEqual(100);
    expect(Number.isFinite(result.displayScore)).toBe(true);
  });

  it("categorises the unrounded score: displays 90 yet stays normal", () => {
    const result = simulate({ sleepHours: 8, hrvPercent: 1, rhrDeltaBpm: 2 });
    expect(result.score).toBeGreaterThanOrEqual(89.5);
    expect(result.score).toBeLessThan(90);
    expect(result.displayScore).toBe(90);
    expect(result.category).toBe("normal");
  });
});
