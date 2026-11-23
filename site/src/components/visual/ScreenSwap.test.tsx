import "@testing-library/jest-dom/vitest";
import { act, cleanup, render, screen } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { FeatureStep, FeaturesStage, ScreenSwap } from "./ScreenSwap";

let reducedMotion: boolean;
/** Every observer created, with the elements it watches. */
let observers: { callback: IntersectionObserverCallback; elements: Element[] }[];

beforeEach(() => {
  reducedMotion = false;
  observers = [];
  vi.stubGlobal(
    "matchMedia",
    vi.fn((query: string) => ({
      matches: query.includes("reduce") ? reducedMotion : false,
      media: query,
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
    })),
  );
  vi.stubGlobal(
    "IntersectionObserver",
    class {
      entry: { callback: IntersectionObserverCallback; elements: Element[] };
      constructor(callback: IntersectionObserverCallback) {
        this.entry = { callback, elements: [] };
        observers.push(this.entry);
      }
      observe(element: Element) {
        this.entry.elements.push(element);
      }
      unobserve() {}
      disconnect() {
        this.entry.elements = [];
      }
    },
  );
});

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

const LAYERS = ["un", "deux", "trois"].map((word) => ({
  key: word,
  node: <p>Écran {word}</p>,
}));

const states = (container: HTMLElement) =>
  Array.from(container.querySelectorAll("[data-swap-layer]")).map((layer) => layer.getAttribute("data-state"));

/** Tells every observer watching `element` that it crossed the middle of the viewport. */
function cross(element: Element, isIntersecting: boolean) {
  for (const observer of observers) {
    if (!observer.elements.includes(element)) continue;
    act(() => {
      observer.callback([{ isIntersecting, target: element } as IntersectionObserverEntry], {} as IntersectionObserver);
    });
  }
}

describe("ScreenSwap", () => {
  it("shows the active screen at once on first paint, and hides the others from assistive tech", () => {
    const { container } = render(<ScreenSwap layers={LAYERS} active={0} />);
    expect(states(container)).toEqual(["still", "idle", "idle"]);
    const layers = container.querySelectorAll("[data-swap-layer]");
    expect(layers[0]).not.toHaveAttribute("aria-hidden");
    expect(layers[1]).toHaveAttribute("aria-hidden", "true");
    expect(layers[2]).toHaveAttribute("aria-hidden", "true");
  });

  it("dissolves the old screen out and the new one in when the active screen changes", () => {
    const { container, rerender } = render(<ScreenSwap layers={LAYERS} active={0} />);
    rerender(<ScreenSwap layers={LAYERS} active={2} />);
    expect(states(container)).toEqual(["out", "idle", "in"]);
    rerender(<ScreenSwap layers={LAYERS} active={1} />);
    expect(states(container)).toEqual(["idle", "in", "out"]);
  });

  it("under reduced motion, swaps the screen without any dissolve", () => {
    reducedMotion = true;
    const { container, rerender } = render(<ScreenSwap layers={LAYERS} active={0} />);
    rerender(<ScreenSwap layers={LAYERS} active={2} />);
    expect(states(container)).toEqual(["idle", "idle", "still"]);
  });
});

describe("FeaturesStage", () => {
  function Stage() {
    return (
      <FeaturesStage layers={LAYERS} captions={["Un", "Deux", "Trois"]}>
        {["un", "deux", "trois"].map((word, index) => (
          <FeatureStep key={word} index={index}>
            <h3>Bloc {word}</h3>
          </FeatureStep>
        ))}
      </FeaturesStage>
    );
  }

  it("renders every block's content, the first one active", () => {
    const { container } = render(<Stage />);
    expect(screen.getByRole("heading", { name: "Bloc un" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Bloc trois" })).toBeInTheDocument();
    expect(states(container)).toEqual(["still", "idle", "idle"]);
    expect(screen.getByRole("heading", { name: "Bloc un" }).closest("[data-step]")).toHaveAttribute(
      "data-active",
      "true",
    );
  });

  it("follows the block that crosses the middle of the viewport, and keeps it when nothing does", () => {
    const { container } = render(<Stage />);
    const third = screen.getByRole("heading", { name: "Bloc trois" }).closest("[data-step]")!;

    cross(third, true);
    expect(states(container)).toEqual(["out", "idle", "in"]);
    expect(third).toHaveAttribute("data-active", "true");

    cross(third, false);
    expect(states(container)).toEqual(["out", "idle", "in"]);
  });

  it("keeps the pinned phone out of the accessibility tree's reading order duplicates", () => {
    const { container } = render(<Stage />);
    // The caption under the phone repeats the eyebrow of the active block: decorative.
    expect(container.querySelector("[data-pin-caption]")).toHaveAttribute("aria-hidden", "true");
  });
});
