"use client";

import { useEffect, useRef, useState } from "react";

export type SpringConfig = { stiffness: number; damping: number; mass?: number };

/** Longest step the integrator takes in one frame (a backgrounded tab must not fling the value). */
const MAX_FRAME_S = 0.064;
/** Integration sub-step, small enough for the stiffest spring we use. */
const SUBSTEP_S = 0.004;
const REST = 0.005;

/**
 * A number that follows `target` with spring inertia (a damped spring,
 * integrated per animation frame), re-rendering on each frame. Under reduced
 * motion it is `target` itself, at once. The first render is already at
 * `target`: nothing springs in on mount.
 */
export function useSpringNumber(target: number, reduced: boolean, config: SpringConfig): number {
  const { stiffness, damping, mass = 1 } = config;
  const [shown, setShown] = useState(target);
  const motion = useRef({ x: target, v: 0 });

  useEffect(() => {
    if (reduced) {
      motion.current = { x: target, v: 0 };
      return;
    }
    let frame = 0;
    let last = performance.now();
    const step = (now: number) => {
      const dt = Math.min((now - last) / 1000, MAX_FRAME_S);
      last = now;
      const steps = Math.max(1, Math.ceil(dt / SUBSTEP_S));
      const h = dt / steps;
      let { x, v } = motion.current;
      for (let i = 0; i < steps; i += 1) {
        v += ((-stiffness * (x - target) - damping * v) / mass) * h;
        x += v * h;
      }
      if (Math.abs(x - target) < REST && Math.abs(v) < REST) {
        motion.current = { x: target, v: 0 };
        setShown(target);
        return;
      }
      motion.current = { x, v };
      setShown(x);
      frame = requestAnimationFrame(step);
    };
    frame = requestAnimationFrame(step);
    return () => cancelAnimationFrame(frame);
  }, [target, reduced, stiffness, damping, mass]);

  return reduced ? target : shown;
}
