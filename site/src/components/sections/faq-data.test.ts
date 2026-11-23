import { describe, expect, it } from "vitest";
import { FAQ } from "./faq-data";

describe("FAQ", () => {
  it("has six or seven entries with unique ids", () => {
    expect(FAQ.length).toBeGreaterThanOrEqual(6);
    expect(FAQ.length).toBeLessThanOrEqual(7);
    expect(new Set(FAQ.map((entry) => entry.id)).size).toBe(FAQ.length);
  });

  it("covers the questions of the spec", () => {
    expect(FAQ.map((entry) => entry.id)).toEqual([
      "pas-de-score",
      "autre-montre",
      "calibration",
      "android",
      "prix",
      "medical",
      "donnees",
    ]);
  });

  it("asks questions and answers in short, plain French", () => {
    for (const entry of FAQ) {
      expect(entry.question.endsWith("?"), entry.id).toBe(true);
      expect(entry.answer.length, entry.id).toBeGreaterThan(40);
      expect(entry.answer.length, entry.id).toBeLessThan(560);
      expect(`${entry.question} ${entry.answer}`, entry.id).not.toMatch(/[—–]/);
    }
  });

  it("states the calibration figures of the support page", () => {
    const calibration = FAQ.find((entry) => entry.id === "calibration")!;
    expect(calibration.answer).toContain("14");
    expect(calibration.answer).toContain("5 nuits");
  });

  it("says Pulse is not a medical device, in the words of the store sheet", () => {
    const medical = FAQ.find((entry) => entry.id === "medical")!;
    expect(medical.answer).toContain("repères d'entraînement, pas un avis médical");
  });
});
