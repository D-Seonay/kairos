import "@testing-library/jest-dom/vitest";
import { cleanup, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import { SupplementsScreen } from "./DrawnScreens";

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
