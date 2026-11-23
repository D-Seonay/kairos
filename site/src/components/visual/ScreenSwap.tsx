"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type CSSProperties,
  type ReactNode,
} from "react";
import { useInView } from "@/components/motion/useInView";
import { useReducedMotion } from "@/components/motion/useReducedMotion";
import { PhoneFrame } from "./PhoneFrame";

export type SwapLayer = { key: string; node: ReactNode };

/**
 * still: shown, no animation (first paint, or reduced motion)
 * in:    dots open over the screen until they cover it
 * out:   dots close to nothing, letting the dark glass through
 * idle:  hidden
 */
type LayerState = "still" | "in" | "out" | "idle";

/**
 * The screen of a phone that changes with a halftone dissolve: the old screen
 * breaks into dots that shrink away, the new one comes up through dots that
 * grow until they touch. All of it is an animated `mask-image` (globals.css,
 * `.swap-layer`). Under reduced motion the screen simply changes.
 */
export function ScreenSwap({ layers, active, className }: { layers: SwapLayer[]; active: number; className?: string }) {
  const reduced = useReducedMotion();
  // The previous screen is kept for the length of its dissolve: state derived from the `active` prop.
  const [shown, setShown] = useState<{ active: number; previous: number | null }>({ active, previous: null });
  if (shown.active !== active) setShown({ active, previous: shown.active });

  const stateOf = (index: number): LayerState => {
    if (reduced || shown.previous === null) return index === active ? "still" : "idle";
    if (index === active) return "in";
    return index === shown.previous ? "out" : "idle";
  };

  return (
    <PhoneFrame className={className}>
      {layers.map((layer, index) => (
        <div
          key={layer.key}
          data-swap-layer=""
          data-state={stateOf(index)}
          aria-hidden={index === active ? undefined : true}
          className="swap-layer absolute inset-0"
        >
          {layer.node}
        </div>
      ))}
    </PhoneFrame>
  );
}

// ---------- The pinned stage ----------

type Stage = { active: number; select: (index: number) => void };

const StageContext = createContext<Stage>({ active: 0, select: () => {} });

/**
 * Two columns from 1024 px (with motion allowed): a phone pinned on the left
 * and the blocks scrolling on the right. Whichever block crosses the middle of
 * the viewport puts its screen on the phone. Below 1024 px, or under reduced
 * motion, the pinned column is hidden by CSS and each block shows its own
 * visual (`.feature-visual`), so the served HTML is the same for everyone.
 */
export function FeaturesStage({
  layers,
  captions,
  children,
}: {
  layers: SwapLayer[];
  /** One short caption per layer, printed under the phone like the legend of a print. */
  captions: string[];
  children: ReactNode;
}) {
  const [active, setActive] = useState(0);
  const select = useCallback((index: number) => setActive(index), []);
  const stage = useMemo(() => ({ active, select }), [active, select]);
  const count = String(layers.length).padStart(2, "0");

  return (
    <StageContext.Provider value={stage}>
      <div className="features-stage">
        <div className="features-pin">
          <div className="features-pin-inner">
            <div aria-hidden="true" className="feature-disc" />
            <ScreenSwap layers={layers} active={active} className="features-pin-phone relative" />
            <p
              data-pin-caption=""
              aria-hidden="true"
              className="mt-7 flex items-center gap-3 font-mono text-[11px] tracking-[0.18em] text-muted uppercase"
            >
              <span className="film-counter text-ink tabular-nums" style={{ "--i": active } as CSSProperties}>
                <span className="film-counter-reel">
                  {layers.map((layer, index) => (
                    <span key={layer.key}>{String(index + 1).padStart(2, "0")}</span>
                  ))}
                </span>
              </span>
              <span>/ {count}</span>
              <span aria-hidden="true" className="h-px w-6 bg-rule" />
              <span className="text-ink">{captions[active]}</span>
            </p>
          </div>
        </div>
        <div className="features-steps">{children}</div>
      </div>
    </StageContext.Provider>
  );
}

/** One block of the stage: reports itself when it crosses the middle of the viewport. */
export function FeatureStep({ index, children, className }: { index: number; children: ReactNode; className?: string }) {
  const { active, select } = useContext(StageContext);
  const ref = useRef<HTMLElement>(null);
  // A one-pixel band across the middle of the viewport: only one block can be in it at a time.
  const centred = useInView(ref, "-50% 0px -50% 0px");

  useEffect(() => {
    if (centred) select(index);
  }, [centred, index, select]);

  return (
    <article ref={ref} data-step="" data-active={active === index} className={className}>
      {children}
    </article>
  );
}
