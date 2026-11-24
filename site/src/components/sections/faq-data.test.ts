import { describe, expect, it } from "vitest";
import { FAQ } from "./faq-data";

describe("FAQ", () => {
  it("has six to nine entries with unique ids", () => {
    expect(FAQ.length).toBeGreaterThanOrEqual(6);
    expect(FAQ.length).toBeLessThanOrEqual(9);
    expect(new Set(FAQ.map((entry) => entry.id)).size).toBe(FAQ.length);
  });

  it("covers the questions of the spec, then the run and the photos of version 1.0.3", () => {
    expect(FAQ.map((entry) => entry.id)).toEqual([
      "pas-de-score",
      "autre-montre",
      "calibration",
      "course",
      "photos",
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

  it("says the position is only used during a run, and what happens without it", () => {
    const run = FAQ.find((entry) => entry.id === "course")!;
    expect(run.answer).toContain("que pendant une course que tu as lancée");
    expect(run.answer).toContain("seul le temps est enregistré");
  });

  it("keeps body photos on the iPhone, out of iCloud and the backup", () => {
    const photos = FAQ.find((entry) => entry.id === "photos")!;
    expect(photos.answer).toMatch(/ne quittent jamais ton iPhone/);
    expect(photos.answer).toMatch(/ni dans iCloud, ni dans la sauvegarde/);
  });
});
