/**
 * Print registration marks in the four corners of a section: an L-shaped crop
 * mark and a small target with crosshair, like the edge of a press sheet.
 * The parent needs `position: relative`.
 */
const CORNERS = [
  { id: "top-left", position: "left-3 top-3", flip: "" },
  { id: "top-right", position: "right-3 top-3", flip: "-scale-x-100" },
  { id: "bottom-left", position: "bottom-3 left-3", flip: "-scale-y-100" },
  { id: "bottom-right", position: "bottom-3 right-3", flip: "-scale-100" },
] as const;

function Mark({ flip }: { flip: string }) {
  return (
    <svg viewBox="0 0 28 28" width="28" height="28" fill="none" stroke="currentColor" strokeWidth="1" className={flip}>
      <path d="M0 14V0H14" strokeWidth="1.25" />
      <circle cx="19" cy="19" r="4.5" />
      <path d="M19 11.5v15M11.5 19h15" />
    </svg>
  );
}

export function RegistrationMarks({ className }: { className?: string }) {
  return (
    <div
      aria-hidden="true"
      className={["pointer-events-none absolute inset-0 text-ink/40", className].filter(Boolean).join(" ")}
    >
      {CORNERS.map((corner) => (
        <span key={corner.id} className={`absolute ${corner.position}`}>
          <Mark flip={corner.flip} />
        </span>
      ))}
    </div>
  );
}
