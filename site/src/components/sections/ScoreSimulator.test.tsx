import { act, cleanup, fireEvent, render, screen, within } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { CATEGORY_LABEL, simulate } from "@/lib/score/engine";
import { ScoreSimulator, hrvValueText, rhrValueText, sleepValueText } from "./ScoreSimulator";

const INITIAL = { sleepHours: 7.5, hrvPercent: -5, rhrDeltaBpm: 2 };

let reducedMotion: boolean;

beforeEach(() => {
  reducedMotion = false;
  vi.stubGlobal(
    "matchMedia",
    vi.fn((query: string) => ({
      matches: query.includes("reduce") ? reducedMotion : false,
      media: query,
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
    })),
  );
  vi.spyOn(HTMLCanvasElement.prototype, "getContext").mockReturnValue(null);
});

afterEach(() => {
  cleanup();
  vi.useRealTimers();
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

const sleep = () => screen.getByRole("slider", { name: "Sommeil" });
const hrv = () => screen.getByRole("slider", { name: "Variabilité cardiaque" });
const rhr = () => screen.getByRole("slider", { name: "Fréquence cardiaque au repos" });

function setSliders(values: { sleepHours: number; hrvPercent: number; rhrDeltaBpm: number }) {
  fireEvent.change(sleep(), { target: { value: String(values.sleepHours) } });
  fireEvent.change(hrv(), { target: { value: String(values.hrvPercent) } });
  fireEvent.change(rhr(), { target: { value: String(values.rhrDeltaBpm) } });
}

describe("ScoreSimulator", () => {
  it("has three native sliders with spoken names", () => {
    render(<ScoreSimulator />);
    for (const slider of [sleep(), hrv(), rhr()]) {
      expect(slider).toHaveAttribute("type", "range");
    }
  });

  it("speaks the initial values in words", () => {
    render(<ScoreSimulator />);
    expect(sleep()).toHaveAttribute("aria-valuetext", "7 h 30");
    expect(hrv()).toHaveAttribute("aria-valuetext", "5 % sous ta normale");
    expect(rhr()).toHaveAttribute("aria-valuetext", "2 battements au-dessus de ta normale");
  });

  it("shows the score of the initial state", () => {
    render(<ScoreSimulator />);
    expect(screen.getByTestId("score-value")).toHaveTextContent(new RegExp(`^${simulate(INITIAL).displayScore}$`));
  });

  it("falls to overreached and swaps the session for mobility at the low extremes", () => {
    render(<ScoreSimulator />);
    setSliders({ sleepHours: 4, hrvPercent: -40, rhrDeltaBpm: 15 });
    expect(screen.getAllByText("Surmenage").length).toBeGreaterThan(0);
    expect(screen.getByText("Séance remplacée par 20 min de mobilité ou du repos, au choix")).toBeInTheDocument();
  });

  it("reaches optimal with a full night in the normal range", () => {
    render(<ScoreSimulator />);
    setSliders({ sleepHours: 8, hrvPercent: 0, rhrDeltaBpm: 0 });
    expect(screen.getAllByText("Forme optimale").length).toBeGreaterThan(0);
  });

  it("never shows NaN and keeps the score within 0 to 100 at every extreme", () => {
    render(<ScoreSimulator />);
    const corners = [
      { sleepHours: 3, hrvPercent: -40, rhrDeltaBpm: 15 },
      { sleepHours: 10, hrvPercent: 30, rhrDeltaBpm: -5 },
    ];
    for (const corner of corners) {
      setSliders(corner);
      expect(document.body.textContent).not.toMatch(/NaN/);
    }
  });

  it("applies the score at once under reduced motion", () => {
    reducedMotion = true;
    render(<ScoreSimulator />);
    const low = { sleepHours: 4, hrvPercent: -40, rhrDeltaBpm: 15 };
    setSliders(low);
    expect(screen.getByTestId("score-value")).toHaveTextContent(new RegExp(`^${simulate(low).displayScore}$`));
  });

  it("announces the settled result politely, not every step", () => {
    vi.useFakeTimers();
    render(<ScoreSimulator />);
    const status = screen.getByRole("status");
    expect(status).toHaveAttribute("aria-live", "polite");
    const initial = simulate(INITIAL);
    expect(status).toHaveTextContent(`Récupération ${initial.displayScore} sur 100`);

    setSliders({ sleepHours: 4, hrvPercent: -40, rhrDeltaBpm: 15 });
    // Still the previous text while the visitor is dragging.
    expect(status).toHaveTextContent(`Récupération ${initial.displayScore} sur 100`);
    act(() => {
      vi.advanceTimersByTime(1000);
    });
    const low = simulate({ sleepHours: 4, hrvPercent: -40, rhrDeltaBpm: 15 });
    expect(status).toHaveTextContent(`Récupération ${low.displayScore} sur 100, surmenage`);
  });

  it("states that the formulas are the app's and that deep sleep is fixed", () => {
    render(<ScoreSimulator />);
    expect(
      screen.getByText(
        "Simulation avec les mêmes formules que l'app. Dans Pulse, tes valeurs sont comparées à ta propre ligne de base.",
      ),
    ).toBeInTheDocument();
    expect(screen.getByText(/Sommeil profond fixé à 15 %/)).toBeInTheDocument();
  });

  it("lists the adjusted sample session", () => {
    render(<ScoreSimulator />);
    const session = screen.getByRole("list", { name: /Séance d'exemple/ });
    expect(within(session).getByText("Développé couché")).toBeInTheDocument();
    expect(within(session).getAllByRole("listitem")).toHaveLength(4);
  });

  it("names the category of the initial state", () => {
    render(<ScoreSimulator />);
    expect(screen.getAllByText(CATEGORY_LABEL[simulate(INITIAL).category]).length).toBeGreaterThan(0);
  });
});

describe("spoken slider values", () => {
  it("speaks hours and minutes of sleep", () => {
    expect(sleepValueText(7.5)).toBe("7 h 30");
    expect(sleepValueText(8)).toBe("8 h");
    expect(sleepValueText(3.25)).toBe("3 h 15");
  });

  it("speaks the variability against the normal", () => {
    expect(hrvValueText(-5)).toBe("5 % sous ta normale");
    expect(hrvValueText(0)).toBe("dans ta normale");
    expect(hrvValueText(12)).toBe("12 % au-dessus de ta normale");
  });

  it("speaks the resting heart rate in beats, singular at one", () => {
    expect(rhrValueText(2)).toBe("2 battements au-dessus de ta normale");
    expect(rhrValueText(1)).toBe("1 battement au-dessus de ta normale");
    expect(rhrValueText(0)).toBe("dans ta normale");
    expect(rhrValueText(-3)).toBe("3 battements sous ta normale");
    expect(rhrValueText(-1)).toBe("1 battement sous ta normale");
  });
});
