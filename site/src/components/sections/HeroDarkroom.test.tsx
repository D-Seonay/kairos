import { cleanup, render } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { HeroDarkroom, fieldAt } from "./HeroDarkroom";

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
  // Frames never run: anything that only happens in a frame does not happen here.
  vi.stubGlobal("requestAnimationFrame", vi.fn(() => 1));
  vi.stubGlobal("cancelAnimationFrame", vi.fn());
  vi.spyOn(HTMLCanvasElement.prototype, "getContext").mockReturnValue(null);
});

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

const fieldLayer = (container: HTMLElement) => container.querySelector("[data-canvas]");

describe("HeroDarkroom", () => {
  it("under reduced motion, renders the finished print at once, without waiting for a frame", () => {
    reducedMotion = true;
    const { container } = render(<HeroDarkroom />);
    expect(fieldLayer(container)).toHaveAttribute("data-canvas", "live");
  });

  it("keeps the static halftone fallback until the canvas has something to draw", () => {
    const { container } = render(<HeroDarkroom />);
    expect(fieldLayer(container)).toHaveAttribute("data-canvas", "fallback");
    expect(container.querySelector(".hero-field-fallback")).toBeInTheDocument();
  });
});

describe("fieldAt", () => {
  it("starts with nothing developed", () => {
    expect(fieldAt(0)).toEqual({ ink: 0, light: 0 });
  });

  it("ends on the finished print, light 0.8, about 2 s in", () => {
    expect(fieldAt(2)).toEqual({ ink: 1, light: 0.8 });
    expect(fieldAt(10)).toEqual({ ink: 1, light: 0.8 });
  });

  it("only ever develops forward", () => {
    let previous = fieldAt(0);
    for (let t = 0.05; t <= 2.2; t += 0.05) {
      const next = fieldAt(t);
      expect(next.ink).toBeGreaterThanOrEqual(previous.ink);
      expect(next.light).toBeGreaterThanOrEqual(previous.light);
      previous = next;
    }
  });
});
