"use client";

import { useEffect, useRef, type ReactNode } from "react";

/**
 * Wraps the FAQ's <details>. The server HTML has every answer open, so they
 * read without JavaScript (and for crawlers). Once hydrated this folds them,
 * unless the visitor asked for reduced motion: then everything stays open and
 * visible at once, the toggles still work. The panel transition only switches
 * on afterwards, so the folding itself is never animated.
 */
export function FaqCollapse({ children, className }: { children: ReactNode; className?: string }) {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const element = ref.current;
    if (!element) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    for (const details of element.querySelectorAll("details[open]")) details.removeAttribute("open");
    const id = window.setTimeout(() => element.setAttribute("data-ready", "true"), 60);
    return () => window.clearTimeout(id);
  }, []);

  return (
    <div ref={ref} className={className}>
      {children}
    </div>
  );
}
