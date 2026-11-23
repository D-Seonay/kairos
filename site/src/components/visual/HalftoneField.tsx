"use client";

import { useEffect, useRef } from "react";
import { useInView } from "@/components/motion/useInView";
import { useReducedMotion } from "@/components/motion/useReducedMotion";
import { cellForViewport, dotRadius, gridFor } from "@/lib/halftone";

const INK = "#141414";
const MAX_DPR = 2;
const POINTER_REACH_IN_CELLS = 8;
/** Dots thinner than this are not worth a path segment. */
const MIN_RADIUS = 0.15;

type FieldState = {
  width: number;
  height: number;
  dpr: number;
  cell: number;
  light: number;
  ink: number;
  /** Where the pointer is, in canvas CSS px, or null. */
  target: { x: number; y: number } | null;
  /** Eased copy of `target`, so the ink follows with a little inertia. */
  eased: { x: number; y: number };
  /** 0 (pointer gone) to 1 (pointer here), eased. */
  presence: number;
};

const clamp01 = (value: number) => Math.min(1, Math.max(0, value));

/** Deterministic 0–1 noise per cell, so the developer front is not a clean wipe. */
function hash(col: number, row: number) {
  const n = Math.sin(col * 127.1 + row * 311.7) * 43758.5453;
  return n - Math.floor(n);
}

/** Soft, slowly drifting luminance, 0 (dark) to 1 (bright). Two crossed waves, like uneven exposure. */
function exposure(x: number, y: number, t: number) {
  const a = Math.sin(x * 0.0045 + 0.9 * Math.sin(y * 0.0031 + t * 0.21) + t * 0.17);
  const b = Math.sin(y * 0.006 - x * 0.0017 + t * 0.13);
  return 0.5 + 0.25 * a + 0.25 * b;
}

function paint(ctx: CanvasRenderingContext2D, s: FieldState, t: number) {
  const { width, height, dpr, cell, light, ink } = s;
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.clearRect(0, 0, width, height);
  if (ink <= 0) return;

  const { cols, rows } = gridFor(width, height, cell);
  const reach = cell * POINTER_REACH_IN_CELLS;
  // Exposure swings most at mid light and stays gentle at the extremes.
  const swing = 0.2 + 2.8 * light * (1 - light);
  const hasPointer = s.target !== null && s.presence > 0.001;

  ctx.fillStyle = INK;
  ctx.beginPath();
  for (let row = 0; row < rows; row++) {
    const y = row * cell;
    const offset = row % 2 === 0 ? 0 : cell / 2;
    for (let col = 0; col < cols; col++) {
      const x = col * cell + offset;

      const local = clamp01(light + (exposure(x, y, t) - 0.5) * swing);
      // The developer front crosses the frame diagonally, with some grain.
      const delay = 0.5 * ((x / (width || 1)) * 0.5 + (y / (height || 1)) * 0.5) + 0.1 * hash(col, row);
      const developed = clamp01(ink * 1.6 - delay);

      let pointerDistance: number | null = null;
      if (hasPointer) {
        const d = Math.hypot(x - s.eased.x, y - s.eased.y);
        pointerDistance = d + (1 - s.presence) * reach;
      }

      const r = dotRadius({ cell, light: local, pointerDistance, ink: developed });
      if (r < MIN_RADIUS) continue;
      ctx.moveTo(x + r, y);
      ctx.arc(x, y, r, 0, Math.PI * 2);
    }
  }
  ctx.fill();
}

export type HalftoneFieldProps = {
  /** 0 (dark, big dots) to 1 (bright, tiny dots). */
  light: number;
  /** 0 (nothing developed) to 1 (fully developed). */
  ink: number;
  /** Dots swell under the pointer. Ignored under reduced motion. */
  interactive?: boolean;
  className?: string;
};

/**
 * Full-frame halftone, drawn on a canvas. The frame loop only runs while the
 * field is on screen and the tab is visible; under reduced motion it paints
 * one static frame and never loops.
 */
export function HalftoneField({ light, ink, interactive = false, className }: HalftoneFieldProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const stateRef = useRef<FieldState>({
    width: 0,
    height: 0,
    dpr: 1,
    cell: 10,
    light,
    ink,
    target: null,
    eased: { x: 0, y: 0 },
    presence: 0,
  });
  const timeRef = useRef(0);
  const inView = useInView(canvasRef, "100px");
  const reduced = useReducedMotion();

  // Size the backing store to the layout box, capped at DPR 2.
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const resize = () => {
      const s = stateRef.current;
      s.width = canvas.clientWidth;
      s.height = canvas.clientHeight;
      s.dpr = Math.min(window.devicePixelRatio || 1, MAX_DPR);
      s.cell = cellForViewport(window.innerWidth);
      canvas.width = Math.round(s.width * s.dpr);
      canvas.height = Math.round(s.height * s.dpr);
    };

    const redraw = () => {
      resize();
      const ctx = canvas.getContext("2d");
      if (ctx) paint(ctx, stateRef.current, timeRef.current);
    };

    resize();
    if (typeof ResizeObserver !== "undefined") {
      const observer = new ResizeObserver(redraw);
      observer.observe(canvas);
      return () => observer.disconnect();
    }
    window.addEventListener("resize", redraw);
    return () => window.removeEventListener("resize", redraw);
  }, []);

  // One paint whenever the inputs change. While looping, the loop repaints anyway.
  useEffect(() => {
    const s = stateRef.current;
    s.light = light;
    s.ink = ink;
    const ctx = canvasRef.current?.getContext("2d");
    if (ctx) paint(ctx, s, timeRef.current);
  }, [light, ink, reduced]);

  // Pointer, read passively. Skipped entirely under reduced motion.
  useEffect(() => {
    if (!interactive || reduced) return;
    const canvas = canvasRef.current;
    const s = stateRef.current;
    if (!canvas) return;

    const onMove = (event: PointerEvent) => {
      const rect = canvas.getBoundingClientRect();
      const x = event.clientX - rect.left;
      const y = event.clientY - rect.top;
      if (s.target === null) s.eased = { x, y };
      s.target = { x, y };
    };
    const onLeave = () => {
      s.target = null;
    };

    window.addEventListener("pointermove", onMove, { passive: true });
    window.addEventListener("pointercancel", onLeave, { passive: true });
    document.documentElement.addEventListener("pointerleave", onLeave, { passive: true });
    return () => {
      window.removeEventListener("pointermove", onMove);
      window.removeEventListener("pointercancel", onLeave);
      document.documentElement.removeEventListener("pointerleave", onLeave);
      s.target = null;
    };
  }, [interactive, reduced]);

  // The frame loop: only while on screen, tab visible and motion allowed.
  useEffect(() => {
    if (reduced || !inView) return;
    const canvas = canvasRef.current;
    const ctx = canvas?.getContext("2d");
    if (!canvas || !ctx) return;

    let frame = 0;
    let last = 0;

    const tick = (now: number) => {
      const s = stateRef.current;
      const dt = last === 0 ? 0 : Math.min((now - last) / 1000, 0.1);
      last = now;
      timeRef.current += dt;

      // Ease the pointer: position follows with inertia, presence fades in and out.
      const follow = 1 - Math.exp(-dt * 14);
      if (s.target) {
        s.eased.x += (s.target.x - s.eased.x) * follow;
        s.eased.y += (s.target.y - s.eased.y) * follow;
      }
      s.presence += ((s.target ? 1 : 0) - s.presence) * (1 - Math.exp(-dt * 6));

      paint(ctx, s, timeRef.current);
      frame = requestAnimationFrame(tick);
    };

    const start = () => {
      if (frame === 0 && document.visibilityState === "visible") {
        last = 0;
        frame = requestAnimationFrame(tick);
      }
    };
    const stop = () => {
      if (frame !== 0) cancelAnimationFrame(frame);
      frame = 0;
    };
    const onVisibility = () => {
      if (document.visibilityState === "visible") start();
      else stop();
    };

    document.addEventListener("visibilitychange", onVisibility);
    start();
    return () => {
      document.removeEventListener("visibilitychange", onVisibility);
      stop();
    };
  }, [reduced, inView]);

  return (
    <canvas
      ref={canvasRef}
      aria-hidden="true"
      className={["pointer-events-none block h-full w-full", className].filter(Boolean).join(" ")}
    />
  );
}
