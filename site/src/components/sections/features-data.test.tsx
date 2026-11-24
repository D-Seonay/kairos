import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { renderToStaticMarkup } from "react-dom/server";
import { CONTACT_FRAMES } from "@/components/visual/ContactSheet";
import { FEATURES, TODAY_SCREEN_ALT } from "./features-data";
import { Hero } from "./Hero";

const PUBLIC = path.resolve(import.meta.dirname, "../../../public");

/** Sentences of a body, split after . ! ? or … */
const sentences = (text: string) => text.split(/(?<=[.!?…])\s+/);

describe("FEATURES", () => {
  it("has eight entries, indexed 01 to 08, with unique ids", () => {
    expect(FEATURES).toHaveLength(8);
    expect(FEATURES.map((feature) => feature.index)).toEqual(["01", "02", "03", "04", "05", "06", "07", "08"]);
    expect(new Set(FEATURES.map((feature) => feature.id)).size).toBe(8);
  });

  it("follows the order of the spec, with the night after the score and the run after the session", () => {
    expect(FEATURES.map((feature) => feature.id)).toEqual([
      "score",
      "nuit",
      "seance",
      "course",
      "programme",
      "stats",
      "complements",
      "widgets",
    ]);
  });

  it("points every capture at a file that exists in public/", () => {
    for (const feature of FEATURES) {
      if (feature.screen === null) continue;
      expect(feature.screen.startsWith("/"), feature.id).toBe(true);
      expect(fs.existsSync(path.join(PUBLIC, feature.screen)), feature.screen).toBe(true);
    }
  });

  it("draws the night, the run, supplements and widgets instead of showing a capture", () => {
    const drawn = FEATURES.filter((feature) => feature.screen === null).map((feature) => feature.id);
    expect(drawn).toEqual(["nuit", "course", "complements", "widgets"]);
  });

  it("gives every entry an eyebrow, a title, a body and a description of its visual", () => {
    for (const feature of FEATURES) {
      expect(feature.eyebrow.trim(), feature.id).not.toBe("");
      expect(feature.title.trim(), feature.id).not.toBe("");
      expect(feature.body.trim(), feature.id).not.toBe("");
      expect(feature.alt.trim(), feature.id).not.toBe("");
    }
  });

  it("describes the score capture as it is: an estimated 58, with sleep and resting heart rate missing", () => {
    const score = FEATURES.find((feature) => feature.id === "score")!;
    expect(score.alt).toMatch(/58 sur 100/);
    expect(score.alt).toMatch(/estimé/);
    expect(score.alt).toMatch(/pas de donnée/);
    expect(score.alt).not.toMatch(/détail sommeil/);
  });

  it("gives today.jpg one alternative text everywhere, the accurate one", () => {
    const score = FEATURES.find((feature) => feature.id === "score")!;
    expect(score.alt).toBe(TODAY_SCREEN_ALT);
    expect(CONTACT_FRAMES.find((frame) => frame.src === "/screens/today.jpg")?.alt).toBe(TODAY_SCREEN_ALT);
    const hero = new DOMParser().parseFromString(renderToStaticMarkup(<Hero />), "text/html");
    expect(hero.querySelector('img[src*="today"]')?.getAttribute("alt")).toBe(TODAY_SCREEN_ALT);
  });

  it("describes the supplements drawing with what the app shows, regularity over 30 days", () => {
    const supplements = FEATURES.find((feature) => feature.id === "complements")!;
    expect(supplements.alt).toMatch(/30 jours/);
    expect(supplements.alt).not.toMatch(/pilulier|semaine/);
  });

  it("never uses an em dash as punctuation", () => {
    for (const feature of FEATURES) {
      for (const text of [feature.eyebrow, feature.title, feature.body, feature.alt]) {
        expect(text, feature.id).not.toContain("—");
      }
    }
  });

  it("only mentions a dose to say Pulse never advises one, in the same sentence", () => {
    for (const feature of FEATURES) {
      for (const sentence of sentences(feature.body)) {
        if (/\bdoses?\b/i.test(sentence)) expect(sentence, feature.id).toMatch(/\bjamais\b/i);
      }
    }
    // The supplements entry says it outright.
    const supplements = FEATURES.find((feature) => feature.id === "complements");
    expect(supplements?.body).toMatch(/ne conseille jamais de dose/);
  });
});
