/**
 * Film grain: a static feTurbulence noise tile laid over its parent at very low
 * opacity. The parent needs `position: relative` (or fixed). No animation, no
 * pointer events, nothing for assistive tech to read.
 */
const NOISE = encodeURIComponent(
  `<svg xmlns="http://www.w3.org/2000/svg" width="220" height="220">` +
    `<filter id="g" x="0" y="0" width="100%" height="100%">` +
    `<feTurbulence type="fractalNoise" baseFrequency="0.85" numOctaves="2" stitchTiles="stitch"/>` +
    `<feColorMatrix values="0 0 0 0 0.08  0 0 0 0 0.08  0 0 0 0 0.08  0 0 0 0.9 0"/>` +
    `</filter><rect width="100%" height="100%" filter="url(#g)"/></svg>`,
);

export function Grain({ className }: { className?: string }) {
  return (
    <div
      aria-hidden="true"
      className={["pointer-events-none absolute inset-0 opacity-[0.07] mix-blend-multiply", className]
        .filter(Boolean)
        .join(" ")}
      style={{ backgroundImage: `url("data:image/svg+xml,${NOISE}")`, backgroundSize: "220px 220px" }}
    />
  );
}
