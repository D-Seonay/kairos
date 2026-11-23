import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { NUMBERS } from "./numbers-data";

/** The worktree root: this file lives in site/src/components/sections. */
const ROOT = path.resolve(import.meta.dirname, "../../../..");
const read = (relative: string) => fs.readFileSync(path.join(ROOT, relative), "utf8");

const EXERCISES_JSON = "Packages/PulseContent/Sources/PulseContent/Resources/exercises.json";
const RECOVERY_CALCULATOR =
  "Packages/PulseRecoveryEngine/Sources/PulseRecoveryEngine/Recovery/RecoveryCalculator.swift";
const FICHE = "docs/app-store/fiche.md";

const find = (pattern: RegExp) => NUMBERS.filter((entry) => pattern.test(entry.label));

describe("NUMBERS", () => {
  it("only holds whole numbers, each with a label and a source", () => {
    expect(NUMBERS.length).toBeGreaterThanOrEqual(4);
    for (const entry of NUMBERS) {
      expect(entry.value, entry.label).toMatch(/^\d+$/);
      expect(entry.label.trim(), entry.value).not.toBe("");
      expect(entry.source.trim(), entry.label).not.toBe("");
    }
  });

  it("proves every number with a file of the repository", () => {
    for (const entry of NUMBERS) {
      expect(fs.existsSync(path.join(ROOT, entry.source)), entry.source).toBe(true);
    }
  });

  it("announces as many exercises as the catalogue holds", () => {
    const catalogue = JSON.parse(read(EXERCISES_JSON)) as { exercises: unknown[] };
    expect(Array.isArray(catalogue.exercises)).toBe(true);
    const entries = find(/exercices/i);
    expect(entries).toHaveLength(1);
    expect(Number(entries[0].value)).toBe(catalogue.exercises.length);
    expect(entries[0].source).toBe(EXERCISES_JSON);
  });

  it("announces the baseline window the recovery calculator uses", () => {
    const match = read(RECOVERY_CALCULATOR).match(/hrvWindowDays\s*=\s*(\d+)/);
    expect(match, "hrvWindowDays in RecoveryCalculator.swift").not.toBeNull();
    const entries = find(/nuits/i);
    expect(entries).toHaveLength(1);
    expect(entries[0].value).toBe(match![1]);
    expect(entries[0].source).toBe(RECOVERY_CALCULATOR);
  });

  it("backs the zero advertising and zero server claims with the store sheet", () => {
    const fiche = read(FICHE);
    expect(fiche).toMatch(/aucun serveur/i);
    expect(fiche).toMatch(/Publicité \| Non/);
    for (const entry of [...find(/publicité/i), ...find(/serveur/i)]) {
      expect(entry.value).toBe("0");
      expect(entry.source).toBe(FICHE);
    }
  });

  it("counts the three measures read every morning from the store sheet", () => {
    const entries = find(/mesures/i);
    expect(entries).toHaveLength(1);
    expect(entries[0].value).toBe("3");
    expect(read(entries[0].source)).toMatch(/sommeil, ta variabilité cardiaque \(VFC\) et ta fréquence cardiaque au repos/);
  });
});
