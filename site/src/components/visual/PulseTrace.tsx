import { useId } from "react";

/**
 * The pulse trace of the app icon (P wave, sharp R spike, S dip, back to the
 * baseline), in the icon's own 1024 px grid. The signal dot sits on the R peak.
 */
export const TRACE_PATH =
  "M250 575H292C312 575 322 505 346 505C372 505 384 650 404 650L500 252L590 770L652 590C658 577 664 575 676 575H730";
/** Share of the path length at which the line reaches the R peak. */
export const TRACE_PEAK = 0.47;
/** Where the baseline sits, as a share of the viewBox height (for flanking lines). */
export const TRACE_BASELINE = (575 - 200) / 600;

const VIEW_BOX = "250 200 480 600";
const PEAK = { x: 500, y: 252 };

const clamp01 = (value: number) => (Number.isFinite(value) ? Math.min(1, Math.max(0, value)) : 0);

export type PulseTraceProps = {
  /** 0 (nothing drawn) to 1 (whole trace). */
  progress: number;
  /** A solid line, or a row of halftone dots like the icon. */
  variant?: "line" | "dots";
  /** The signal dot on the R peak, shown once the line has reached it. */
  dot?: boolean;
  className?: string;
  /** Hooks for a CSS draw animation, which overrides the inline progress while it runs. */
  pathClassName?: string;
  dotClassName?: string;
};

/**
 * Drawn with `pathLength="1"`, so `progress` maps straight onto the dash
 * offset. Colour comes from `currentColor`; the dot is always the signal colour.
 * Decorative: hidden from assistive tech.
 */
export function PulseTrace({
  progress,
  variant = "line",
  dot = false,
  className,
  pathClassName,
  dotClassName,
}: PulseTraceProps) {
  const maskId = useId();
  const drawn = clamp01(progress);
  const draw = { strokeDasharray: 1, strokeDashoffset: 1 - drawn };

  return (
    <svg
      viewBox={VIEW_BOX}
      aria-hidden="true"
      focusable="false"
      overflow="visible"
      className={className}
    >
      {variant === "line" ? (
        <path
          d={TRACE_PATH}
          pathLength={1}
          fill="none"
          stroke="currentColor"
          strokeWidth={6}
          strokeLinecap="round"
          strokeLinejoin="round"
          className={pathClassName}
          style={draw}
        />
      ) : (
        <>
          <mask id={maskId} maskUnits="userSpaceOnUse" x="200" y="150" width="580" height="700">
            <path
              d={TRACE_PATH}
              pathLength={1}
              fill="none"
              stroke="#fff"
              strokeWidth={40}
              strokeLinejoin="round"
              className={pathClassName}
              style={draw}
            />
          </mask>
          <path
            d={TRACE_PATH}
            pathLength={1}
            fill="none"
            stroke="currentColor"
            strokeWidth={13}
            strokeLinecap="round"
            strokeDasharray="0 0.0165"
            mask={`url(#${maskId})`}
          />
        </>
      )}
      {dot ? (
        <circle
          cx={PEAK.x}
          cy={PEAK.y}
          r={34}
          fill="var(--color-signal)"
          className={dotClassName}
          style={{
            opacity: drawn >= TRACE_PEAK ? 1 : 0,
            transformBox: "fill-box",
            transformOrigin: "center",
          }}
        />
      ) : null}
    </svg>
  );
}
