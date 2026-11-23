import "@testing-library/jest-dom/vitest";
import { act, cleanup, render, screen } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { CONTACT_FRAMES, ContactSheet } from "./ContactSheet";

let reducedMotion: boolean;
let observerCallbacks: IntersectionObserverCallback[];

beforeEach(() => {
  reducedMotion = false;
  observerCallbacks = [];
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
      constructor(callback: IntersectionObserverCallback) {
        observerCallbacks.push(callback);
      }
      observe() {}
      unobserve() {}
      disconnect() {}
    },
  );
});

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

describe("ContactSheet", () => {
  it("is a labelled region that scrolls on its own and takes keyboard focus", () => {
    render(<ContactSheet />);
    const region = screen.getByRole("region", { name: /planche contact/i });
    expect(region).toHaveAttribute("tabindex", "0");
    expect(region.className).toMatch(/overflow-x-auto/);
  });

  it("shows the five captures, each with its alternative text and its frame number 1A to 5A", () => {
    render(<ContactSheet />);
    expect(CONTACT_FRAMES).toHaveLength(5);
    for (const frame of CONTACT_FRAMES) {
      expect(screen.getByAltText(frame.alt)).toBeInTheDocument();
    }
    for (const number of ["1A", "2A", "3A", "4A", "5A"]) {
      expect(screen.getAllByText(new RegExp(`${number}$`)).length).toBeGreaterThan(0);
    }
    expect(screen.getAllByText("PULSE 400").length).toBeGreaterThan(0);
  });

  it("circles exactly one frame in signal felt", () => {
    const { container } = render(<ContactSheet />);
    expect(container.querySelectorAll("[data-circled]")).toHaveLength(1);
  });

  it("draws the circle once the strip comes into view", () => {
    const { container } = render(<ContactSheet />);
    const circle = container.querySelector("[data-felt]")!;
    expect(circle).toHaveAttribute("data-drawn", "false");
    act(() => {
      for (const callback of observerCallbacks) {
        callback([{ isIntersecting: true } as IntersectionObserverEntry], {} as IntersectionObserver);
      }
    });
    expect(circle).toHaveAttribute("data-drawn", "true");
  });

  it("under reduced motion, shows the circle already drawn", () => {
    reducedMotion = true;
    const { container } = render(<ContactSheet />);
    expect(container.querySelector("[data-felt]")).toHaveAttribute("data-drawn", "true");
  });
});
