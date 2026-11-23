"use client";

import { useEffect, useRef, useState } from "react";
import { useReducedMotion } from "@/components/motion/useReducedMotion";
import { HalftoneField } from "@/components/visual/HalftoneField";

/** Light of the finished print: small dots, mostly paper. */
const FINAL = { ink: 1, light: 0.8 };
/** Seconds on the hero clock after which the field holds its final values. */
const SETTLED_AT = 2;

const clamp01 = (value: number) => Math.min(1, Math.max(0, value));
const easeInOut = (x: number) => (x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2);

/**
 * The developer acting on the field, in seconds since the hero sequence began:
 * the dots come up from 0.5 s, then the print clears toward paper until ~1.95 s.
 */
export function fieldAt(t: number): { ink: number; light: number } {
  return {
    ink: easeInOut(clamp01((t - 0.5) / 1.1)),
    light: FINAL.light * easeInOut(clamp01((t - 0.6) / 1.35)),
  };
}

/**
 * The darkroom behind the hero: the night (an ink sheet that a CSS animation
 * fades out from first paint, see `.dev-night` in globals.css) and the living
 * halftone field. The CSS animation is the clock, so the page develops on time
 * even if hydration is late, and this component only syncs the canvas to it.
 * Under reduced motion there is no animation and no frame loop: the field is
 * final from the first client render.
 *
 * Until the canvas has dots to draw (server HTML, JavaScript off, late
 * hydration), a static CSS halftone stands in for it, so the developed print
 * never depends on the canvas.
 */
export function HeroDarkroom() {
  const nightRef = useRef<HTMLDivElement>(null);
  const reduced = useReducedMotion();
  const [developing, setDeveloping] = useState({ ink: 0, light: 0 });
  const field = reduced ? FINAL : developing;
  const live = field.ink > 0;

  useEffect(() => {
    if (reduced) return;
    const night = nightRef.current;
    const animation =
      night && typeof night.getAnimations === "function" ? night.getAnimations()[0] : undefined;

    if (!animation) {
      // No clock to follow: show the finished print.
      const id = requestAnimationFrame(() => setDeveloping(FINAL));
      return () => cancelAnimationFrame(id);
    }

    let frame = 0;
    const tick = () => {
      const t = Number(animation.currentTime ?? 0) / 1000;
      if (t >= SETTLED_AT || animation.playState === "finished") {
        setDeveloping(FINAL);
        return;
      }
      setDeveloping(fieldAt(t));
      frame = requestAnimationFrame(tick);
    };
    frame = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frame);
  }, [reduced]);

  return (
    <div aria-hidden="true" className="pointer-events-none absolute inset-0">
      <div ref={nightRef} className="dev-night absolute inset-0 bg-ink" />
      <div className="hero-field-mask absolute inset-0" data-canvas={live ? "live" : "fallback"}>
        <div className="hero-field-fallback absolute inset-0" />
        <HalftoneField ink={field.ink} light={field.light} interactive />
      </div>
    </div>
  );
}
