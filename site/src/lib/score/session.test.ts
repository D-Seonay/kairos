import { describe, expect, it } from "vitest";
import { SAMPLE_PUSH, adjustSession } from "./session";

describe("adjustSession", () => {
  it("leaves the session unchanged when optimal", () => {
    const result = adjustSession(SAMPLE_PUSH, "optimal");
    expect(result.exercises).toEqual(SAMPLE_PUSH);
    expect(result.reasons).toEqual([]);
    expect(result.mobility).toBe(false);
  });

  it("adds 15 seconds of rest when normal", () => {
    const result = adjustSession(SAMPLE_PUSH, "normal");
    expect(result.exercises.map((e) => e.restSeconds)).toEqual(
      SAMPLE_PUSH.map((e) => e.restSeconds + 15),
    );
    expect(result.exercises.map((e) => e.sets)).toEqual(SAMPLE_PUSH.map((e) => e.sets));
    expect(result.reasons).toEqual(["Repos rallongés de 15 secondes"]);
    expect(result.mobility).toBe(false);
  });

  it("reduces volume, caps RPE and adds 45 seconds when moderately fatigued", () => {
    const result = adjustSession(SAMPLE_PUSH, "moderateFatigue");
    expect(result.exercises.map((e) => e.sets)).toEqual([3, 2, 2, 3]);
    expect(result.exercises.every((e) => e.rpe <= 7.5)).toBe(true);
    expect(result.exercises.map((e) => e.restSeconds)).toEqual(
      SAMPLE_PUSH.map((e) => e.restSeconds + 45),
    );
    expect(result.reasons).toEqual([
      "Volume réduit de 13 à 10 séries",
      "Effort plafonné à RPE 7,5",
      "Repos rallongés de 45 secondes",
    ]);
    expect(result.mobility).toBe(false);
  });

  it("never drops below one set", () => {
    const day = [
      { name: "A", sets: 1, reps: 5, rpe: 7, restSeconds: 60 },
      { name: "B", sets: 1, reps: 5, rpe: 7, restSeconds: 60 },
    ];
    const result = adjustSession(day, "moderateFatigue");
    expect(result.exercises.map((e) => e.sets)).toEqual([1, 1]);
    expect(result.reasons).toEqual(["Repos rallongés de 45 secondes"]);
  });

  it("replaces the session with mobility when overreached", () => {
    const result = adjustSession(SAMPLE_PUSH, "overreached");
    expect(result.mobility).toBe(true);
    expect(result.reasons).toEqual(["Séance remplacée par 20 min de mobilité ou du repos, au choix"]);
  });

  it("does not mutate the input", () => {
    const copy = structuredClone(SAMPLE_PUSH);
    adjustSession(SAMPLE_PUSH, "moderateFatigue");
    expect(SAMPLE_PUSH).toEqual(copy);
  });
});
