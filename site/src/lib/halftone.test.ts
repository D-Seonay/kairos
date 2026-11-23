import { describe, expect, it } from "vitest";
import { cellForViewport, dotRadius, gridFor } from "./halftone";

const CELL = 10;
const LIGHTS = [0, 0.25, 0.5, 0.75, 1];
const INKS = [0, 0.3, 0.6, 1];
const DISTANCES = [null, 0, 5, 40, 80, 500];

describe("dotRadius", () => {
  it("stays within 0 and cell / 2 across the parameter grid", () => {
    for (const light of LIGHTS) {
      for (const ink of INKS) {
        for (const pointerDistance of DISTANCES) {
          const r = dotRadius({ cell: CELL, light, pointerDistance, ink });
          expect(r).toBeGreaterThanOrEqual(0);
          expect(r).toBeLessThanOrEqual(CELL / 2);
        }
      }
    }
  });

  it("is bigger in the dark (light = 0) than in the light (light = 1)", () => {
    const dark = dotRadius({ cell: CELL, light: 0, pointerDistance: null, ink: 1 });
    const bright = dotRadius({ cell: CELL, light: 1, pointerDistance: null, ink: 1 });
    expect(dark).toBeGreaterThan(bright);
  });

  it("is bigger with the pointer on the dot than without a pointer", () => {
    const near = dotRadius({ cell: CELL, light: 0.5, pointerDistance: 0, ink: 1 });
    const none = dotRadius({ cell: CELL, light: 0.5, pointerDistance: null, ink: 1 });
    expect(near).toBeGreaterThan(none);
  });

  it("has no pointer influence beyond cell * 8", () => {
    const far = dotRadius({ cell: CELL, light: 0.5, pointerDistance: CELL * 8, ink: 1 });
    const none = dotRadius({ cell: CELL, light: 0.5, pointerDistance: null, ink: 1 });
    expect(far).toBe(none);
  });

  it("is 0 when ink = 0, pointer or not", () => {
    expect(dotRadius({ cell: CELL, light: 0, pointerDistance: null, ink: 0 })).toBe(0);
    expect(dotRadius({ cell: CELL, light: 0, pointerDistance: 0, ink: 0 })).toBe(0);
  });

  it("grows with ink", () => {
    const low = dotRadius({ cell: CELL, light: 0.3, pointerDistance: null, ink: 0.3 });
    const high = dotRadius({ cell: CELL, light: 0.3, pointerDistance: null, ink: 0.9 });
    expect(high).toBeGreaterThan(low);
  });

  it("clamps out-of-range inputs instead of returning NaN", () => {
    const r = dotRadius({ cell: CELL, light: -3, pointerDistance: -5, ink: 9 });
    expect(r).toBeGreaterThanOrEqual(0);
    expect(r).toBeLessThanOrEqual(CELL / 2);
  });
});

describe("gridFor", () => {
  it("adds one cell of overflow", () => {
    expect(gridFor(1000, 500, 10)).toEqual({ cols: 101, rows: 51 });
  });
});

describe("cellForViewport", () => {
  it("uses fewer, bigger cells on mobile", () => {
    expect(cellForViewport(375)).toBe(14);
    expect(cellForViewport(639)).toBe(14);
    expect(cellForViewport(640)).toBe(10);
    expect(cellForViewport(1440)).toBe(10);
  });
});
