import { useId, type CSSProperties } from "react";
import type { Category } from "@/lib/score/engine";

/*
 * Port of RecoveryGauge (large style) and GaugeGeometry from PulseDesignSystem:
 * a chronograph bezel of 41 ticks over 240° starting at 150°, lit up to the
 * score like a light trail, a short needle at the score and the score in thin
 * figures with « sur 100 » underneath. The site adds a row of halftone dots
 * just outside the ticks: each one swells as its tick lights, darker (bigger)
 * toward the needle.
 */

const SIDE = 240;
/** Room around the 240 × 180 dial for the dot ring. */
const MARGIN = 14;
const VIEW_W = SIDE + MARGIN * 2;
const VIEW_H = SIDE * 0.75 + MARGIN * 2;
const CENTER = SIDE / 2;

const START_DEGREES = 150;
const SWEEP_DEGREES = 240;
const TICK_COUNT = 41;
const LINE_WIDTH = 3;
const TICK_LENGTH = SIDE * 0.075;
const NEEDLE_LENGTH = TICK_LENGTH * 2.1;
const OUTER = SIDE / 2 - LINE_WIDTH / 2;
const INNER = OUTER - TICK_LENGTH;
const DOT_RING = OUTER + 8.5;
const DOT_MAX = 2.6;
/** A disc of card colour under the bezel, fading out past the dots: the halftone around never crosses the ticks. */
const LENS = DOT_RING + 16;

/** Category thresholds (40 / 65 / 90) as fractions of the arc, from GaugeGeometry. */
const THRESHOLDS = [0.4, 0.65, 0.9];

/** Category tone on paper, from PulsePalette: ink when fit, grey in fatigue, the signal when overreached. */
export const TONE: Record<Category, string> = {
  optimal: "#141414",
  normal: "#141414",
  moderateFatigue: "#6d6a64",
  overreached: "#ff4f2e",
};

/** Score clamped to 0–100, NaN counts as 0 (GaugeGeometry.fraction). */
export function clampScore(value: number): number {
  return Number.isFinite(value) ? Math.min(100, Math.max(0, value)) : 0;
}

function point(fraction: number, radius: number) {
  const radians = ((START_DEGREES + SWEEP_DEGREES * fraction) * Math.PI) / 180;
  return { x: CENTER + radius * Math.cos(radians), y: CENTER + radius * Math.sin(radians) };
}

/** The trail: faint at the start of the arc, half strength at 60 % of the way, full tone at the score. */
function trailOpacity(tickFraction: number, end: number) {
  const t = end <= 0 ? 1 : tickFraction / end;
  return t <= 0.6 ? 0.18 + (t / 0.6) * (0.55 - 0.18) : 0.55 + ((t - 0.6) / 0.4) * (1 - 0.55);
}

const TICKS = Array.from({ length: TICK_COUNT }, (_, index) => {
  const fraction = index / (TICK_COUNT - 1);
  return { fraction, outer: point(fraction, OUTER), inner: point(fraction, INNER), dot: point(fraction, DOT_RING) };
});

/** Share of the view width, as a container query length. */
const cqw = (units: number) => `${(units / VIEW_W) * 100}cqw`;

export type ScoreDialProps = {
  /** The score where the needle sits, possibly mid-spring (not rounded). */
  value: number;
  category: Category;
  /** Colour under the needle, to detour it from the ticks. */
  cardColor?: string;
  className?: string;
};

/**
 * Decorative: the simulator speaks the score in its own live region, so the
 * dial is hidden from assistive tech. The number is the rounded value, as
 * RecoveryGauge.roundedScore.
 */
export function ScoreDial({ value, category, cardColor = "var(--color-card)", className }: ScoreDialProps) {
  const score = clampScore(value);
  const fraction = score / 100;
  const tone = TONE[category];
  const needle = { outer: point(fraction, OUTER), inner: point(fraction, OUTER - NEEDLE_LENGTH) };
  const lensId = `lens${useId().replace(/[^a-zA-Z0-9_-]/g, "")}`;

  return (
    <div
      aria-hidden="true"
      className={["relative w-full [container-type:inline-size]", className].filter(Boolean).join(" ")}
      style={{ aspectRatio: `${VIEW_W} / ${VIEW_H}` }}
    >
      <svg
        viewBox={`${-MARGIN} ${-MARGIN} ${VIEW_W} ${VIEW_H}`}
        className="absolute inset-0 h-full w-full overflow-visible"
      >
        <defs>
          <radialGradient id={lensId}>
            <stop offset="0.8" stopColor={cardColor} />
            <stop offset="1" stopColor={cardColor} stopOpacity={0} />
          </radialGradient>
        </defs>
        <circle cx={CENTER} cy={CENTER} r={LENS} fill={`url(#${lensId})`} />

        <g strokeLinecap="round" strokeWidth={LINE_WIDTH}>
          {TICKS.map((tick, index) => {
            const lit = tick.fraction <= fraction + 1e-6 && score > 0;
            return (
              <line
                key={index}
                className="dial-tick"
                x1={tick.outer.x}
                y1={tick.outer.y}
                x2={tick.inner.x}
                y2={tick.inner.y}
                stroke={lit ? tone : "#141414"}
                strokeOpacity={lit ? trailOpacity(tick.fraction, fraction) : 0.16}
              />
            );
          })}
        </g>

        {/* Halftone dots: off they are specks, lit they swell with the trail. */}
        <g>
          {TICKS.map((tick, index) => {
            const lit = tick.fraction <= fraction + 1e-6 && score > 0;
            const strength = lit ? trailOpacity(tick.fraction, fraction) : 0;
            return (
              <circle
                key={index}
                className="dial-dot"
                cx={tick.dot.x}
                cy={tick.dot.y}
                r={DOT_MAX}
                fill={lit ? tone : "#141414"}
                style={{ "--s": lit ? 0.35 + 0.65 * strength : 0.22, opacity: lit ? 1 : 0.28 } as CSSProperties}
              />
            );
          })}
        </g>

        {/* Category thresholds, as three fine inner pips. */}
        <g fill="#141414" fillOpacity={0.35}>
          {THRESHOLDS.map((threshold) => {
            const p = point(threshold, INNER - 7);
            return <circle key={threshold} cx={p.x} cy={p.y} r={1.3} />;
          })}
        </g>

        {score > 0 && (
          <g strokeLinecap="round">
            <line
              x1={needle.outer.x}
              y1={needle.outer.y}
              x2={needle.inner.x}
              y2={needle.inner.y}
              stroke={cardColor}
              strokeOpacity={0.7}
              strokeWidth={LINE_WIDTH * 3.2}
            />
            <line
              x1={needle.outer.x}
              y1={needle.outer.y}
              x2={needle.inner.x}
              y2={needle.inner.y}
              stroke="#141414"
              strokeWidth={LINE_WIDTH * 1.6}
            />
          </g>
        )}
      </svg>

      <div
        className="absolute inset-x-0 flex flex-col items-center"
        style={{ top: cqw(MARGIN + SIDE * 0.15), gap: cqw(SIDE * 0.026) }}
      >
        <span
          data-testid="score-value"
          className="font-sans leading-none font-thin tracking-[-0.04em] text-ink tabular-nums"
          style={{ fontSize: cqw(SIDE * 0.32) }}
        >
          {Math.round(score)}
        </span>
        <span
          className="font-mono font-medium tracking-[0.16em] text-muted uppercase"
          style={{ fontSize: `max(10px, ${cqw(SIDE * 0.045)})` }}
        >
          sur 100
        </span>
      </div>
    </div>
  );
}
