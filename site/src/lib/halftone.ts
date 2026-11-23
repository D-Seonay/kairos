/**
 * Halftone maths, kept pure so the canvas component stays a thin renderer.
 * Dots grow toward dark areas, near the pointer, and with the darkroom
 * "developer" progress (`ink`).
 */

/** Pointer influence reaches this many cells away, then drops to zero. */
const POINTER_REACH_IN_CELLS = 8;
/** Largest share of the half-cell a dot reaches from darkness alone. */
const DARK_FILL = 0.84;
/** Extra share of the half-cell the pointer can add at distance 0. */
const POINTER_BOOST = 0.5;

const clamp01 = (value: number) =>
  Number.isFinite(value) ? Math.min(1, Math.max(0, value)) : 0;

export type DotParams = {
  cell: number;
  /** 0 (dark, large dots) to 1 (bright, no dots). */
  light: number;
  /** Distance in px to the pointer, or null when there is none. */
  pointerDistance: number | null;
  /** 0 (nothing developed, no dots) to 1 (fully developed). */
  ink: number;
};

export function dotRadius({ cell, light, pointerDistance, ink }: DotParams): number {
  const half = cell / 2;
  const developed = clamp01(ink);
  if (developed === 0) return 0;

  const darkness = Math.pow(1 - clamp01(light), 1.15);

  let pointer = 0;
  if (pointerDistance !== null && Number.isFinite(pointerDistance)) {
    const reach = cell * POINTER_REACH_IN_CELLS;
    const closeness = 1 - Math.min(Math.max(pointerDistance, 0), reach) / reach;
    // Smooth falloff: ink rising under the finger, not a hard disc.
    pointer = closeness * closeness * (3 - 2 * closeness);
  }

  const share = (darkness * DARK_FILL + pointer * POINTER_BOOST) * developed;
  return Math.min(half, Math.max(0, share * half));
}

/** Cells needed to cover the area, with one cell of overflow on each axis. */
export function gridFor(width: number, height: number, cell: number): { cols: number; rows: number } {
  return {
    cols: Math.ceil(width / cell) + 1,
    rows: Math.ceil(height / cell) + 1,
  };
}

/** Fewer, bigger cells on phones. */
export function cellForViewport(width: number): number {
  return width < 640 ? 14 : 10;
}
