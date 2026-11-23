"use client";

import { useRef, useState, useSyncExternalStore } from "react";
import { useInView } from "@/components/motion/useInView";
import { useReducedMotion } from "@/components/motion/useReducedMotion";

export type CounterFigure = { value: string; label: string };

/** Digits on a reel: two turns of 0 to 9, so a digit spins a full turn before it lands. */
const REEL = Array.from({ length: 20 }, (_, position) => position % 10);

const subscribe = () => () => {};
/** False in the served HTML and during hydration, true afterwards: the reels only exist on the client. */
const useHydrated = () =>
  useSyncExternalStore(
    subscribe,
    () => true,
    () => false,
  );

/** One digit. Served as plain text; on the client it becomes a reel that rolls to its value. */
function Digit({ digit, order, reel, landed }: { digit: number; order: number; reel: boolean; landed: boolean }) {
  if (!reel) return <span className="counter-digit">{digit}</span>;
  const style = { "--i": landed ? 10 + digit : 0, "--k": order } as React.CSSProperties;
  return (
    <span className="counter-digit" style={style}>
      <span className="counter-reel">
        {REEL.map((face, position) => (
          <span key={position}>{face}</span>
        ))}
      </span>
    </span>
  );
}

/**
 * The numbers band. Under the numerals sits a film counter: when the band
 * enters the screen each digit is a reel that spins from 0 and clicks into
 * place, the rightmost first. Reduced motion, no JavaScript, crawlers: the
 * numbers are plain text, already at their value (the served HTML has no reel).
 */
export function CounterBand({ figures }: { figures: CounterFigure[] }) {
  const ref = useRef<HTMLUListElement>(null);
  const hydrated = useHydrated();
  const reduced = useReducedMotion();
  const inView = useInView(ref, "0px 0px -18% 0px");
  const [seen, setSeen] = useState(false);
  if (inView && !seen) setSeen(true);

  const reel = hydrated && !reduced;

  return (
    <ul ref={ref} className="counter-band" data-roll={seen ? "on" : "off"}>
      {figures.map((figure, index) => {
        const digits = figure.value.split("");
        return (
          <li key={`${figure.label}-${index}`} className="counter-cell">
            <p className="counter-value">
              <span className="sr-only">{figure.value} </span>
              <span aria-hidden="true" className="counter-digits">
                {digits.map((char, position) => (
                  <Digit
                    key={position}
                    digit={Number(char)}
                    order={digits.length - 1 - position}
                    reel={reel}
                    landed={seen}
                  />
                ))}
              </span>
            </p>
            <p className="counter-label">{figure.label}</p>
          </li>
        );
      })}
    </ul>
  );
}
