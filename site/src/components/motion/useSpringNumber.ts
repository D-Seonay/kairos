"use client";

import { useMotionValueEvent, useSpring } from "motion/react";
import { useEffect, useState } from "react";

export type SpringConfig = { stiffness: number; damping: number; mass?: number };

/**
 * A number that follows `target` with spring inertia, re-rendering on each
 * frame of the spring. Under reduced motion it is `target` itself, at once.
 * The first render is already at `target`: nothing springs in on mount.
 */
export function useSpringNumber(target: number, reduced: boolean, config: SpringConfig): number {
  const spring = useSpring(target, config);
  const [shown, setShown] = useState(target);
  useMotionValueEvent(spring, "change", setShown);

  useEffect(() => {
    if (reduced) spring.jump(target);
    else spring.set(target);
  }, [spring, target, reduced]);

  return reduced ? target : shown;
}
