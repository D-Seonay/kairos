import "@testing-library/jest-dom/vitest";
import { cleanup, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import { NIGHT_BREAKDOWN, NIGHT_SEGMENTS, NightScreen, RunScreen, SupplementsScreen } from "./DrawnScreens";

afterEach(cleanup);

describe("SupplementsScreen", () => {
  it("is one image with its description", () => {
    render(<SupplementsScreen label="Dessin de l'écran Compléments" />);
    expect(screen.getByRole("img", { name: "Dessin de l'écran Compléments" })).toBeInTheDocument();
  });

  it("uses the app's own strings: moments, planned times (SupplementText.planned) and 30-day regularity", () => {
    const { container } = render(<SupplementsScreen label="Compléments" />);
    const text = container.textContent ?? "";
    for (const expected of [
      "Compléments",
      "sur 4 pris",
      "Prochaine prise",
      "Pris",
      "Matin",
      "Autour de la séance",
      "Soir",
      "8:00",
      "17:30 · 30 min avant la séance",
      "Après la séance",
      "22:30 · au coucher",
      "Régularité, 30 jours",
      "Jours pris sur jours prévus, depuis la création du complément.",
    ]) {
      expect(text).toContain(expected);
    }
  });

  it("shows nothing the app does not have, and no dose", () => {
    const { container } = render(<SupplementsScreen label="Compléments" />);
    const text = container.textContent ?? "";
    expect(text).not.toMatch(/7 jours|sur 7/);
    expect(text).not.toMatch(/\d\s?(UI|mg|µg|g|ml)\b|\bdoses?\b/);
  });
});

describe("RunScreen", () => {
  it("is one image with its description", () => {
    render(<RunScreen label="Dessin de l'écran Course" />);
    expect(screen.getByRole("img", { name: "Dessin de l'écran Course" })).toBeInTheDocument();
  });

  it("uses the app's own strings (RunView, RunText) and figures that agree with each other", () => {
    const { container } = render(<RunScreen label="Course" />);
    const text = container.textContent ?? "";
    for (const expected of [
      "Course",
      "Footing facile · obj. 30 min",
      "24:13",
      "4,38 km",
      "5'31\"/km",
      "allure km",
      "5'32\"/km",
      "moyenne",
      "81",
      "Annonces vocales",
      "Distance, temps et allure à chaque kilomètre",
      "Pause",
      "Terminer",
    ]) {
      expect(text).toContain(expected);
    }
    // 4,38 km in 24:13 is an average of 5'32"/km; 24:13 of a 30 min goal is 81 %.
    const seconds = 24 * 60 + 13;
    const average = Math.round(seconds / 4.38);
    expect(`${Math.floor(average / 60)}'${average % 60}`).toBe("5'32");
    expect(Math.round((seconds / (30 * 60)) * 100)).toBe(81);
  });

  it("shows no live map and no heart rate, which the run screen does not promise", () => {
    const { container } = render(<RunScreen label="Course" />);
    expect(container.textContent).not.toMatch(/bpm|carte/i);
  });
});

describe("NightScreen", () => {
  it("is one image with its description", () => {
    render(<NightScreen label="Dessin de l'écran Nuit" />);
    expect(screen.getByRole("img", { name: "Dessin de l'écran Nuit" })).toBeInTheDocument();
  });

  it("uses the app's own strings (NightScreen, NightText)", () => {
    const { container } = render(<NightScreen label="Nuit" />);
    const text = container.textContent ?? "";
    for (const expected of [
      "Nuit du 23 au 24 nov.",
      "Temps endormi",
      "7 h 12",
      "Endormi à 23:10 · Réveillé à 06:50 · 2 réveils",
      "Phases de la nuit",
      "Répartition",
      "Profond",
      "Léger",
      "Paradoxal",
      "Éveil",
    ]) {
      expect(text).toContain(expected);
    }
  });

  it("fills 23:10 to 06:50 exactly, with two awakenings before the last one", () => {
    expect(NIGHT_SEGMENTS.reduce((sum, segment) => sum + segment.minutes, 0)).toBe(460);
    const awake = NIGHT_SEGMENTS.map((segment, index) => (segment.stage === "awake" ? index : -1)).filter((index) => index >= 0);
    expect(awake.filter((index) => index < NIGHT_SEGMENTS.length - 1)).toHaveLength(2);
  });

  it("breaks the night down in the app's order, with shares that add up to 100", () => {
    expect(NIGHT_BREAKDOWN.map((row) => [row.name, row.minutes, row.share])).toEqual([
      ["Profond", 85, 18],
      ["Léger", 242, 53],
      ["Paradoxal", 105, 23],
      ["Éveil", 28, 6],
    ]);
  });
});
