/**
 * Two app screens drawn in HTML and CSS, for the features that have no raw
 * capture. They sit in a PhoneFrame screen and size everything in em from a
 * root of 3.4cqw (the phone's width), so they scale with the frame. They only
 * show what the published build has: the Compléments screen (count of the day,
 * next intake with « Pris », the checklist, regularity) and the lock screen
 * widgets (score, séance du jour) with the session Live Activity.
 */

type DrawnProps = { label: string; className?: string };

function StatusBar({ dark = false, time = true }: { dark?: boolean; time?: boolean }) {
  return (
    <div className={["flex items-center justify-between px-[1.6em] pt-[1.05em] text-[0.95em] font-semibold", dark ? "text-paper" : "text-ink"].join(" ")}>
      <span className={time ? "" : "invisible"}>10:24</span>
      <span className="flex items-center gap-[0.35em]">
        {/* Signal bars, Wi-Fi arc, battery. */}
        <span className="flex items-end gap-[0.12em]">
          {[0.35, 0.5, 0.65, 0.8].map((h) => (
            <span key={h} className="w-[0.2em] rounded-[0.05em] bg-current" style={{ height: `${h}em` }} />
          ))}
        </span>
        <span className="size-[0.85em] rounded-t-full border-[0.18em] border-current border-b-transparent [clip-path:inset(0_0_35%_0)]" />
        <span className="relative h-[0.7em] w-[1.45em] rounded-[0.22em] border-[0.09em] border-current/50 p-[0.09em]">
          <span className="block h-full w-[80%] rounded-[0.1em] bg-current" />
        </span>
      </span>
    </div>
  );
}

const Eyebrow = ({ children, className }: { children: React.ReactNode; className?: string }) => (
  <p className={["font-mono text-[0.56em] tracking-[0.16em] uppercase", className].filter(Boolean).join(" ")}>
    {children}
  </p>
);

function Check({ taken }: { taken: boolean }) {
  return taken ? (
    <svg viewBox="0 0 20 20" className="size-[1.55em] shrink-0 text-ink">
      <circle cx="10" cy="10" r="10" fill="currentColor" />
      <path d="M5.6 10.4l2.9 2.9 5.9-6.2" fill="none" stroke="#efece5" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  ) : (
    <span className="size-[1.55em] shrink-0 rounded-full border-[0.12em] border-muted" />
  );
}

const INTAKES = [
  { name: "Vitamine D", when: "8:00", taken: true },
  { name: "Caféine", when: "17:30, avant la séance", taken: true },
  { name: "Protéines", when: "Après la séance", taken: false },
  { name: "Magnésium", when: "22:30, au coucher", taken: false },
];

/** Monday to Sunday; Thursday was missed, today (Sunday) is half done. */
const WEEK = [
  { day: "L", fill: 1 },
  { day: "M", fill: 1 },
  { day: "M", fill: 1 },
  { day: "J", fill: 0 },
  { day: "V", fill: 1 },
  { day: "S", fill: 1 },
  { day: "D", fill: 0.5 },
];

/** The app's floating tab bar; the Compléments screen opens from Aujourd'hui. */
function TabBar() {
  const tabs = [
    { label: "Aujourd'hui", icon: <circle cx="12" cy="12" r="4.2" />, rays: true },
    { label: "Planning", icon: <rect x="4" y="5.5" width="16" height="14" rx="2.5" fill="none" stroke="currentColor" strokeWidth="2" /> },
    { label: "Séance", icon: <path d="M3 9.5h2v5H3zM6 7h3v10H6zM9 11h6v2H9zM15 7h3v10h-3zM19 9.5h2v5h-2z" /> },
    { label: "Stats", icon: <path d="M4 13h4v7H4zM10 8h4v12h-4zM16 4h4v16h-4z" /> },
    { label: "Profil", icon: <path d="M12 4a4 4 0 1 1 0 8 4 4 0 0 1 0-8zm-7.5 16c.6-3.6 3.6-6 7.5-6s6.9 2.4 7.5 6z" /> },
  ];
  return (
    <div className="absolute inset-x-[0.9em] bottom-[1.1em] grid grid-cols-5 rounded-full bg-[#fbfaf7]/95 p-[0.3em] shadow-[0_0.3em_1.2em_rgb(20_20_20/0.12)]">
      {tabs.map((tab, index) => (
        <span
          key={tab.label}
          className={["flex flex-col items-center gap-[0.15em] rounded-full py-[0.4em]", index === 0 ? "bg-ink/8" : ""].join(" ")}
        >
          <svg viewBox="0 0 24 24" className="size-[1.25em]" fill="currentColor">
            {tab.icon}
            {tab.rays &&
              [0, 45, 90, 135, 180, 225, 270, 315].map((angle) => (
                <rect key={angle} x="11.2" y="1.5" width="1.6" height="3" rx="0.8" transform={`rotate(${angle} 12 12)`} />
              ))}
          </svg>
          <span className="text-[0.5em] font-medium">{tab.label}</span>
        </span>
      ))}
    </div>
  );
}

/** Compléments: today's count, the next intake with « Pris », a pill organiser of the week in halftone, the checklist. */
export function SupplementsScreen({ label, className }: DrawnProps) {
  return (
    <div
      role="img"
      aria-label={label}
      className={["drawn-screen drawn-paper absolute inset-0 overflow-hidden text-ink", className].filter(Boolean).join(" ")}
      style={{ fontSize: "3.75cqw" }}
    >
      <StatusBar />
      <div className="px-[1.25em] pt-[1.9em]">
        <Eyebrow className="text-muted">Dimanche 22 novembre</Eyebrow>
        <p className="mt-[0.15em] text-[1.85em] leading-tight font-semibold tracking-[-0.02em]">Compléments</p>

        {/* Summary card */}
        <div className="mt-[0.9em] rounded-[1.25em] bg-[#fbfaf7] p-[1.05em] shadow-[0_0.1em_0.6em_rgb(20_20_20/0.06)]">
          <Eyebrow className="text-muted">Aujourd&apos;hui</Eyebrow>
          <p className="mt-[0.2em] flex items-baseline gap-[0.3em]">
            <span className="text-[2.6em] leading-none font-extralight tracking-[-0.04em]">2</span>
            <span className="text-[0.9em] text-muted">sur 4 pris</span>
          </p>
          <div className="mt-[0.7em] grid grid-cols-4 gap-[0.3em]">
            {INTAKES.map((intake) => (
              <span key={intake.name} className={["h-[0.32em] rounded-full", intake.taken ? "bg-ink" : "bg-ink/12"].join(" ")} />
            ))}
          </div>
          <div className="mt-[0.95em] flex items-center gap-[0.7em] border-t border-ink/10 pt-[0.85em]">
            <div className="min-w-0 flex-1">
              <Eyebrow className="text-muted">Prochaine prise</Eyebrow>
              <p className="mt-[0.15em] text-[1.02em] font-semibold">Protéines</p>
              <p className="text-[0.78em] text-muted">Après la séance</p>
            </div>
            <span className="drawn-pris inline-flex items-center gap-[0.35em] rounded-full bg-ink px-[0.95em] py-[0.5em] text-[0.85em] font-semibold text-paper">
              <svg viewBox="0 0 12 12" className="size-[0.85em]">
                <path d="M2 6.4l2.6 2.5L10 3.3" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
              Pris
            </span>
          </div>
        </div>

        {/* The week as a pill organiser: a compartment per day, filled with halftone ink when taken. */}
        <div className="mt-[0.8em] rounded-[1.25em] bg-[#fbfaf7] p-[1.05em] shadow-[0_0.1em_0.6em_rgb(20_20_20/0.06)]">
          <div className="flex items-baseline justify-between">
            <Eyebrow className="text-muted">Régularité, 7 jours</Eyebrow>
            <span className="text-[0.8em] font-medium tabular-nums">6 sur 7</span>
          </div>
          <div className="mt-[0.7em] grid grid-cols-7 gap-[0.3em]">
            {WEEK.map((cell, index) => (
              <div key={index} className="text-center">
                <span className="pill-box block" style={{ "--fill": cell.fill } as React.CSSProperties} />
                <span className="mt-[0.3em] block font-mono text-[0.55em] text-muted">{cell.day}</span>
              </div>
            ))}
          </div>
        </div>

        {/* Checklist */}
        <ul className="mt-[0.8em] divide-y divide-ink/8 rounded-[1.25em] bg-[#fbfaf7] px-[1.05em] shadow-[0_0.1em_0.6em_rgb(20_20_20/0.06)]">
          {INTAKES.map((intake) => (
            <li key={intake.name} className="flex items-center gap-[0.7em] py-[0.62em]">
              <span className="pill-chip" />
              <span className="min-w-0 flex-1">
                <span className={["block text-[0.92em] font-semibold", intake.taken ? "text-muted line-through" : ""].join(" ")}>
                  {intake.name}
                </span>
                <span className="block text-[0.72em] text-muted">{intake.when}</span>
              </span>
              <Check taken={intake.taken} />
            </li>
          ))}
        </ul>
      </div>
      <TabBar />
    </div>
  );
}

function Dumbbell({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 12" className={className} fill="currentColor">
      <rect x="0" y="3.5" width="2.4" height="5" rx="0.8" />
      <rect x="3" y="1" width="3.2" height="10" rx="1" />
      <rect x="6" y="5" width="12" height="2" />
      <rect x="17.8" y="1" width="3.2" height="10" rx="1" />
      <rect x="21.6" y="3.5" width="2.4" height="5" rx="0.8" />
    </svg>
  );
}

/** A lock screen at night: the score and today's session as widgets, a session in progress as a Live Activity. */
export function WidgetsScreen({ label, className }: DrawnProps) {
  // Score widget: the arc covers the score's share of the circle, like RecoveryGauge in compact style.
  const score = 58;
  const arc = 2 * Math.PI * 15;
  return (
    <div
      role="img"
      aria-label={label}
      className={["drawn-screen drawn-night absolute inset-0 overflow-hidden text-paper", className].filter(Boolean).join(" ")}
    >
      <StatusBar dark time={false} />

      {/* Lock */}
      <svg viewBox="0 0 14 18" className="mx-auto mt-[1.4em] block h-[1.1em] w-[0.9em] text-paper/85" fill="currentColor">
        <path d="M3 8V5.2a4 4 0 0 1 8 0V8" fill="none" stroke="currentColor" strokeWidth="1.8" />
        <rect x="0.5" y="7.6" width="13" height="10" rx="2.2" />
      </svg>

      {/* Date with the inline score widget, then the clock */}
      <p className="mt-[0.75em] flex items-center justify-center gap-[0.45em] text-[1.02em] font-semibold text-paper/85">
        <span>dim. 22 nov.</span>
        <span className="flex items-center gap-[0.25em]">
          <svg viewBox="0 0 16 14" className="size-[0.8em]" fill="currentColor">
            <path d="M8 13.5S0.5 9 0.5 4.3A3.8 3.8 0 0 1 8 2.6a3.8 3.8 0 0 1 7.5 1.7C15.5 9 8 13.5 8 13.5z" />
          </svg>
          {score} · fatigue modérée
        </span>
      </p>
      <p className="text-center text-[6.3em] leading-[0.95] font-semibold tracking-[-0.03em] text-paper/95">10:24</p>

      {/* Widgets: score (circular), séance du jour (rectangular) */}
      <div className="mt-[0.9em] flex items-stretch justify-center gap-[0.7em] px-[1.6em]">
        <div className="relative grid size-[5.1em] shrink-0 place-items-center rounded-full bg-paper/14 backdrop-blur-sm">
          <svg viewBox="0 0 36 36" className="absolute inset-[0.4em] -rotate-90">
            <circle cx="18" cy="18" r="15" fill="none" stroke="currentColor" strokeOpacity="0.25" strokeWidth="3" />
            <circle
              cx="18"
              cy="18"
              r="15"
              fill="none"
              stroke="currentColor"
              strokeWidth="3"
              strokeLinecap="round"
              strokeDasharray={`${(arc * score) / 100} ${arc}`}
            />
          </svg>
          <span className="text-[1.55em] font-light tracking-[-0.03em] tabular-nums">{score}</span>
        </div>
        <div className="flex min-w-0 flex-1 flex-col justify-center rounded-[1.1em] bg-paper/14 px-[0.85em] py-[0.6em] backdrop-blur-sm">
          <p className="flex items-center gap-[0.35em] text-[0.88em] font-bold">
            <Dumbbell className="h-[0.7em] w-[1.3em] shrink-0" />
            <span className="truncate">Pectoraux et triceps</span>
          </p>
          <p className="mt-[0.15em] text-[0.78em] text-paper/65">14 séries · allégée</p>
          <p className="text-[0.78em] text-paper/65">RPE max 7,5</p>
        </div>
      </div>

      {/* Live Activity: a rest between two sets */}
      <div className="absolute inset-x-[0.8em] bottom-[5.6em] rounded-[1.7em] bg-black/72 p-[1em] backdrop-blur-md">
        <div className="flex items-center gap-[0.75em]">
          <span className="relative grid size-[2.9em] shrink-0 place-items-center">
            <svg viewBox="0 0 36 36" className="absolute inset-0 -rotate-90">
              <circle cx="18" cy="18" r="15" fill="none" stroke="currentColor" strokeOpacity="0.2" strokeWidth="3.4" />
              <circle
                cx="18"
                cy="18"
                r="15"
                fill="none"
                stroke="currentColor"
                strokeWidth="3.4"
                strokeLinecap="round"
                strokeDasharray={`${arc * 0.62} ${arc}`}
                className="live-ring"
              />
            </svg>
          </span>
          <span className="min-w-0 flex-1">
            <span className="block text-[1em] font-semibold">Repos</span>
            <span className="mt-[0.1em] block text-[0.66em] font-semibold text-paper/60">Série suivante</span>
            <span className="block text-[0.74em] leading-snug font-semibold text-balance">
              Développé couché à la barre · série 2 · 70 kg × 5
            </span>
          </span>
          <span className="text-[2.1em] font-light tracking-[-0.03em] tabular-nums">1:24</span>
        </div>
        <div className="mt-[0.8em] grid grid-cols-3 gap-[0.45em] text-center text-[0.85em] font-bold">
          <span className="rounded-full bg-paper/14 py-[0.55em]">−30 s</span>
          <span className="rounded-full bg-paper/14 py-[0.55em]">+30 s</span>
          <span className="rounded-full bg-paper py-[0.55em] text-ink">Passer</span>
        </div>
      </div>

      {/* Flashlight, camera, home indicator */}
      <span className="absolute bottom-[2em] left-[2.2em] size-[2.6em] rounded-full bg-paper/14 backdrop-blur-sm" />
      <span className="absolute right-[2.2em] bottom-[2em] size-[2.6em] rounded-full bg-paper/14 backdrop-blur-sm" />
      <span className="absolute bottom-[0.55em] left-1/2 h-[0.3em] w-[8.5em] -translate-x-1/2 rounded-full bg-paper/80" />
    </div>
  );
}
