/**
 * App screens drawn in HTML and CSS, for the features that have no raw
 * capture. They sit in a PhoneFrame screen and size everything in em from a
 * root of 3.4cqw (the phone's width), so they scale with the frame. They only
 * show what the published build has: the Compléments screen (count of the day,
 * next intake with « Pris », the moments and their checks, 30-day regularity)
 * the lock screen widgets (score, séance du jour) with the session Live
 * Activity, a run in progress and the Nuit screen.
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

/**
 * Four supplements, grouped by moment as SupplementsView does, each with the
 * planned part of its row detail (SupplementText.planned). The row detail in
 * the app also starts with the dose the user typed: left out here, the site
 * shows no dose at all.
 */
type Intake = { name: string; planned: string; taken: boolean };
type Moment = { title: string; icon: "sunrise" | "dumbbell" | "moon"; items: Intake[] };

const MOMENTS: Moment[] = [
  { title: "Matin", icon: "sunrise", items: [{ name: "Vitamine D", planned: "8:00", taken: true }] },
  {
    title: "Autour de la séance",
    icon: "dumbbell",
    items: [
      { name: "Caféine", planned: "17:30 · 30 min avant la séance", taken: true },
      { name: "Protéines", planned: "Après la séance", taken: false },
    ],
  },
  { title: "Soir", icon: "moon", items: [{ name: "Magnésium", planned: "22:30 · au coucher", taken: false }] },
];

const INTAKES = MOMENTS.flatMap((moment) => moment.items);

/** « Régularité, 30 jours »: days taken over days planned, as a percentage (SupplementsModel.rateText). */
const REGULARITY = [
  { name: "Vitamine D", rate: 0.93 },
  { name: "Caféine", rate: 0.8 },
  { name: "Protéines", rate: 0.87 },
  { name: "Magnésium", rate: 0.7 },
];

function MomentIcon({ icon }: { icon: Moment["icon"] }) {
  if (icon === "dumbbell") return <Dumbbell className="h-[0.6em] w-[1.15em]" />;
  return (
    <svg viewBox="0 0 16 16" className="size-[0.9em]" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round">
      {icon === "sunrise" ? (
        <>
          <path d="M3.5 11.5a4.5 4.5 0 0 1 9 0M1 11.5h14M8 2.5v2.5M3 5l1.4 1.4M13 5l-1.4 1.4" />
        </>
      ) : (
        <path d="M13 10.2A5.5 5.5 0 0 1 5.8 3a5.5 5.5 0 1 0 7.2 7.2z" />
      )}
    </svg>
  );
}

/** The IconChip of a row: a capsule glyph on a soft chip. */
function PillChip() {
  return (
    <span className="grid size-[2.1em] shrink-0 place-items-center rounded-full bg-ink/6 text-ink/70">
      <svg viewBox="0 0 16 16" className="size-[1.1em]">
        <g transform="rotate(-40 8 8)">
          <path d="M8 4.6H4.6a3.4 3.4 0 0 0 0 6.8H8z" fill="currentColor" />
          <rect x="1.2" y="4.6" width="13.6" height="6.8" rx="3.4" fill="none" stroke="currentColor" strokeWidth="1.3" />
        </g>
      </svg>
    </span>
  );
}

const card = "rounded-[1.25em] bg-card shadow-[0_0.1em_0.6em_rgb(20_20_20/0.06)]";

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
    <div className="absolute inset-x-[0.9em] bottom-[1.1em] grid grid-cols-5 rounded-full bg-card/95 p-[0.3em] shadow-[0_0.3em_1.2em_rgb(20_20_20/0.12)]">
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

/**
 * The Compléments screen, top to bottom as SupplementsView lays it out: the
 * summary card (date, « 2 sur 4 pris », the day's segments, the next intake
 * with « Pris »), the moments with their check rows, and « Régularité, 30
 * jours ». Every string is the app's own.
 */
export function SupplementsScreen({ label, className }: DrawnProps) {
  const taken = INTAKES.filter((intake) => intake.taken).length;
  return (
    <div
      role="img"
      aria-label={label}
      className={["drawn-screen drawn-paper absolute inset-0 overflow-hidden text-ink", className].filter(Boolean).join(" ")}
      style={{ fontSize: "3.55cqw" }}
    >
      <StatusBar />

      {/* Inline navigation title, pushed from Aujourd'hui, with « + » to add a supplement. */}
      <div className="mt-[0.9em] grid grid-cols-[2.2em_1fr_2.2em] items-center px-[1.1em]">
        <span className="grid size-[2.2em] place-items-center rounded-full bg-card shadow-[0_0.1em_0.5em_rgb(20_20_20/0.08)]">
          <svg viewBox="0 0 10 16" className="h-[0.85em]" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
            <path d="M8 2L2 8l6 6" />
          </svg>
        </span>
        <p className="text-center text-[1em] font-semibold">Compléments</p>
        <span className="grid size-[2.2em] place-items-center rounded-full bg-card text-[1.2em] leading-none shadow-[0_0.1em_0.5em_rgb(20_20_20/0.08)]">
          +
        </span>
      </div>

      <div className="px-[1.1em] pt-[0.9em]">
        {/* Summary card */}
        <div className={`${card} p-[1em]`}>
          <Eyebrow className="text-muted">dimanche 22 novembre</Eyebrow>
          <p className="mt-[0.2em] flex items-baseline gap-[0.3em]">
            <span className="text-[2.5em] leading-none font-extralight tracking-[-0.04em]">{taken}</span>
            <span className="text-[0.9em] text-muted">sur {INTAKES.length} pris</span>
          </p>
          <div className="mt-[0.6em] flex gap-[0.25em]">
            {INTAKES.map((intake) => (
              <span key={intake.name} className={["h-[0.3em] flex-1 rounded-full", intake.taken ? "bg-ink" : "bg-ink/12"].join(" ")} />
            ))}
          </div>
          <div className="mt-[0.85em] flex items-center gap-[0.7em]">
            <div className="min-w-0 flex-1">
              <Eyebrow className="text-muted">Prochaine prise</Eyebrow>
              <p className="mt-[0.1em] text-[1em] font-semibold">Protéines</p>
              <p className="text-[0.78em] text-muted">Après la séance</p>
            </div>
            <span className="inline-flex items-center gap-[0.35em] rounded-full bg-ink px-[0.95em] py-[0.5em] text-[0.85em] font-semibold text-paper">
              <svg viewBox="0 0 12 12" className="size-[0.85em]">
                <path d="M2 6.4l2.6 2.5L10 3.3" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
              Pris
            </span>
          </div>
        </div>

        {/* Moments and their check rows */}
        {MOMENTS.map((moment) => (
          <div key={moment.title} className="mt-[0.75em]">
            <p className="flex items-center gap-[0.4em] px-[0.2em] text-[0.82em] font-semibold text-muted">
              <MomentIcon icon={moment.icon} />
              {moment.title}
            </p>
            <ul className={`${card} mt-[0.35em] divide-y divide-ink/8 px-[0.95em]`}>
              {moment.items.map((intake) => (
                <li key={intake.name} className="flex items-center gap-[0.7em] py-[0.5em]">
                  <PillChip />
                  <span className="min-w-0 flex-1">
                    <span className={["block text-[0.92em] font-semibold", intake.taken ? "text-muted line-through" : ""].join(" ")}>
                      {intake.name}
                    </span>
                    <span className="block text-[0.72em] text-muted">{intake.planned}</span>
                  </span>
                  <Check taken={intake.taken} />
                </li>
              ))}
            </ul>
          </div>
        ))}

        {/* Régularité, 30 jours */}
        <p className="mt-[0.75em] px-[0.2em] text-[0.82em] font-semibold text-muted">Régularité, 30 jours</p>
        <div className={`${card} mt-[0.35em] p-[0.95em]`}>
          <div className="flex flex-col gap-[0.55em]">
            {REGULARITY.map((row) => (
              <div key={row.name} className="flex items-center gap-[0.6em] text-[0.8em]">
                <span className="w-[6.2em] shrink-0 truncate">{row.name}</span>
                <span className="h-[0.45em] flex-1 overflow-hidden rounded-full bg-ink/10">
                  <span className="block h-full rounded-full bg-ink" style={{ width: `${row.rate * 100}%` }} />
                </span>
                <span className="w-[3em] shrink-0 text-right font-semibold tabular-nums">{`${Math.round(row.rate * 100)}\u202f%`}</span>
              </div>
            ))}
          </div>
          <p className="mt-[0.6em] text-[0.62em] text-muted">Jours pris sur jours prévus, depuis la création du complément.</p>
        </div>
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

/** The inline navigation bar of a pushed or presented screen: a round button on the left, the title in the middle. */
function NavBar({ title, glyph }: { title: string; glyph: "back" | "down" }) {
  return (
    <div className="mt-[0.9em] grid grid-cols-[2.2em_1fr_2.2em] items-center px-[1.1em]">
      <span className="grid size-[2.2em] place-items-center rounded-full bg-card shadow-[0_0.1em_0.5em_rgb(20_20_20/0.08)]">
        <svg viewBox="0 0 16 16" className="h-[0.85em]" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          {glyph === "back" ? <path d="M11 2L5 8l6 6" /> : <path d="M2.5 5.5L8 11l5.5-5.5" />}
        </svg>
      </span>
      <p className="text-center text-[1em] font-semibold">{title}</p>
      <span />
    </div>
  );
}

/**
 * A run in progress, as RunView lays it out: the goal line (RunText.goalLine),
 * the moving time in big, the distance at two decimals, the pace of the
 * current kilometre and the average, the goal's progress, the « Annonces
 * vocales » switch, then « Pause » and « Terminer ». No live map: the app has
 * none. No heart rate either: it only shows when the workout session gives one.
 * The figures agree: 4,38 km in 24:13 is 5'32"/km, and 24:13 of 30 min is 81 %.
 */
export function RunScreen({ label, className }: DrawnProps) {
  return (
    <div
      role="img"
      aria-label={label}
      className={["drawn-screen drawn-paper absolute inset-0 overflow-hidden text-ink", className].filter(Boolean).join(" ")}
      style={{ fontSize: "3.55cqw" }}
    >
      <StatusBar />
      <NavBar title="Course" glyph="down" />

      <div className="flex flex-col items-center px-[1.1em] pt-[1.3em] text-center">
        <p className="text-[1.02em] font-semibold">Footing facile · obj. 30 min</p>
        <p className="mt-[0.9em] text-[5.6em] leading-[1] font-extralight tracking-[-0.05em] tabular-nums">24:13</p>
        <p className="text-[2.6em] leading-[1.05] font-light tracking-[-0.04em] text-ink/70 tabular-nums">4,38 km</p>

        <div className="mt-[1em] grid w-full grid-cols-2 gap-[0.7em]">
          {[
            { value: "5'31\"/km", name: "allure km" },
            { value: "5'32\"/km", name: "moyenne" },
          ].map((pace) => (
            <div key={pace.name}>
              <p className="text-[1.45em] font-semibold tracking-[-0.02em] tabular-nums">{pace.value}</p>
              <Eyebrow className="mt-[0.15em] text-muted">{pace.name}</Eyebrow>
            </div>
          ))}
        </div>

        <div className="mt-[1.1em] flex w-full items-center gap-[0.7em]">
          <span className="h-[0.45em] flex-1 overflow-hidden rounded-full bg-ink/12">
            <span className="block h-full rounded-full bg-ink/70" style={{ width: "81%" }} />
          </span>
          <span className="text-[0.95em] font-semibold tabular-nums">81&nbsp;%</span>
        </div>

        <div className={`${card} mt-[1.2em] flex w-full items-center gap-[0.8em] p-[0.95em] text-left`}>
          <span className="min-w-0 flex-1">
            <span className="block text-[0.95em] font-semibold">Annonces vocales</span>
            <span className="mt-[0.1em] block text-[0.72em] text-muted">Distance, temps et allure à chaque kilomètre</span>
          </span>
          <span className="relative h-[1.55em] w-[2.6em] shrink-0 rounded-full bg-ink/70">
            <span className="absolute top-[0.15em] right-[0.15em] size-[1.25em] rounded-full bg-card" />
          </span>
        </div>
      </div>

      <div className="absolute inset-x-[1.1em] bottom-[1.6em] grid grid-cols-2 gap-[0.6em] text-center text-[0.95em] font-semibold">
        <span className="rounded-full bg-card py-[0.85em] shadow-[0_0.1em_0.5em_rgb(20_20_20/0.08)]">Pause</span>
        <span className="rounded-full bg-ink py-[0.85em] text-paper">Terminer</span>
      </div>
    </div>
  );
}

/** The four rows of the hypnogram, top to bottom (SleepStage.chartOrder), with their ink on the print. */
const STAGE_ROWS = [
  { stage: "awake", name: "Éveil", tone: "bg-signal" },
  { stage: "rem", name: "Paradoxal", tone: "bg-ink/45" },
  { stage: "core", name: "Léger", tone: "bg-ink/70" },
  { stage: "deep", name: "Profond", tone: "bg-ink" },
] as const;

type Stage = (typeof STAGE_ROWS)[number]["stage"];

/**
 * One night, 23:10 to 06:50 (460 minutes), cycle by cycle. The segments add up
 * to the breakdown below: 85 min of deep, 242 of light, 105 of REM, 28 awake,
 * and two awakenings before the last one.
 */
export const NIGHT_SEGMENTS: { stage: Stage; minutes: number }[] = [
  { stage: "core", minutes: 15 },
  { stage: "deep", minutes: 35 },
  { stage: "core", minutes: 35 },
  { stage: "rem", minutes: 15 },
  { stage: "awake", minutes: 6 },
  { stage: "core", minutes: 40 },
  { stage: "deep", minutes: 30 },
  { stage: "core", minutes: 30 },
  { stage: "rem", minutes: 25 },
  { stage: "core", minutes: 45 },
  { stage: "deep", minutes: 20 },
  { stage: "rem", minutes: 30 },
  { stage: "awake", minutes: 10 },
  { stage: "core", minutes: 50 },
  { stage: "rem", minutes: 35 },
  { stage: "core", minutes: 27 },
  { stage: "awake", minutes: 12 },
];

const NIGHT_MINUTES = NIGHT_SEGMENTS.reduce((sum, segment) => sum + segment.minutes, 0);

/** Where each segment starts, in minutes after 23:10. */
const NIGHT_STARTS = NIGHT_SEGMENTS.map((_, index) =>
  NIGHT_SEGMENTS.slice(0, index).reduce((sum, segment) => sum + segment.minutes, 0),
);

/** The hour marks of the axis, in minutes after 23:10. */
const NIGHT_TICKS = [
  { label: "00:00", minute: 50 },
  { label: "02:00", minute: 170 },
  { label: "04:00", minute: 290 },
  { label: "06:00", minute: 410 },
];

/** « 1 h 25 », « 28 min » (PulseFormat.duration). */
const duration = (minutes: number) => {
  const hours = Math.floor(minutes / 60);
  const rest = minutes % 60;
  if (hours === 0) return `${rest} min`;
  if (rest === 0) return `${hours} h`;
  return `${hours} h ${String(rest).padStart(2, "0")}`;
};

/** The breakdown, in the order of NightText.breakdownRows: deep, light, REM, awake. */
export const NIGHT_BREAKDOWN = (["deep", "core", "rem", "awake"] as const).map((stage) => {
  const minutes = NIGHT_SEGMENTS.filter((segment) => segment.stage === stage).reduce((sum, segment) => sum + segment.minutes, 0);
  const row = STAGE_ROWS.find((entry) => entry.stage === stage)!;
  return { stage, name: row.name, tone: row.tone, minutes, share: Math.round((minutes / NIGHT_MINUTES) * 100) };
});

/**
 * The Nuit screen, top to bottom as NightScreen lays it out: « Nuit du 23 au
 * 24 nov. » between ‹ and ›, « Temps endormi » with the times and awakenings
 * (NightText.times), « Phases de la nuit » with the hypnogram, then
 * « Répartition ». The app colours each stage; the print keeps to ink, with
 * the signal for the awake minutes.
 */
export function NightScreen({ label, className }: DrawnProps) {
  const asleep = NIGHT_BREAKDOWN.filter((row) => row.stage !== "awake").reduce((sum, row) => sum + row.minutes, 0);
  return (
    <div
      role="img"
      aria-label={label}
      className={["drawn-screen drawn-paper absolute inset-0 overflow-hidden text-ink", className].filter(Boolean).join(" ")}
      style={{ fontSize: "3.55cqw" }}
    >
      <StatusBar />
      <NavBar title="Nuit" glyph="back" />

      <div className="px-[1.1em] pt-[0.7em]">
        <div className="flex items-center justify-between px-[0.3em] text-[1.25em] font-semibold">
          <span aria-hidden="true" className="text-[0.8em]">‹</span>
          <span>Nuit du 23 au 24 nov.</span>
          <span aria-hidden="true" className="text-[0.8em] text-ink/30">›</span>
        </div>

        <div className={`${card} mt-[0.7em] p-[1em]`}>
          <Eyebrow className="text-muted">Temps endormi</Eyebrow>
          <p className="mt-[0.15em] text-[2.3em] leading-none font-light tracking-[-0.04em]">{duration(asleep)}</p>
          <p className="mt-[0.4em] text-[0.74em] text-muted">Endormi à 23:10 · Réveillé à 06:50 · 2 réveils</p>
        </div>

        <div className={`${card} mt-[0.7em] p-[1em]`}>
          <Eyebrow className="text-muted">Phases de la nuit</Eyebrow>
          {/* Rows of 1.3em: the stage name on the left, the plot on the right with one block per segment. */}
          <div className="relative mt-[0.6em] h-[5.2em]">
            {STAGE_ROWS.map((row, index) => (
              <span
                key={row.stage}
                className="absolute left-0 flex items-center text-[0.68em] text-muted"
                style={{ top: `${(index * 1.3) / 0.68}em`, height: `${1.3 / 0.68}em` }}
              >
                {row.name}
              </span>
            ))}
            <div className="absolute inset-y-0 right-0 left-[4.4em]">
              {STAGE_ROWS.map((row, index) => (
                <span
                  key={row.stage}
                  className="absolute inset-x-0 border-b border-dashed border-ink/10"
                  style={{ top: `${index * 1.3}em`, height: "1.3em" }}
                />
              ))}
              {NIGHT_SEGMENTS.map((segment, index) => {
                const row = STAGE_ROWS.findIndex((entry) => entry.stage === segment.stage);
                const left = (NIGHT_STARTS[index] / NIGHT_MINUTES) * 100;
                return (
                  <span
                    key={index}
                    className={`absolute h-[0.95em] rounded-[0.15em] ${STAGE_ROWS[row].tone}`}
                    style={{ left: `${left}%`, width: `${(segment.minutes / NIGHT_MINUTES) * 100}%`, top: `${row * 1.3 + 0.17}em` }}
                  />
                );
              })}
            </div>
          </div>
          {/* Hour marks where they fall: 23:10 is minute 0, so 00:00 is minute 50, 02:00 is 170 and so on. */}
          <div className="relative mt-[0.35em] ml-[4.4em] h-[0.7em]">
            {NIGHT_TICKS.map((tick) => (
              <span
                key={tick.label}
                className="absolute -translate-x-1/2 text-[0.58em] text-muted tabular-nums"
                style={{ left: `${(tick.minute / NIGHT_MINUTES) * 100}%` }}
              >
                {tick.label}
              </span>
            ))}
          </div>
        </div>

        <div className={`${card} mt-[0.7em] p-[1em]`}>
          <Eyebrow className="text-muted">Répartition</Eyebrow>
          <div className="mt-[0.5em] flex flex-col gap-[0.6em]">
            {NIGHT_BREAKDOWN.map((row) => (
              <div key={row.stage}>
                <p className="flex items-baseline gap-[0.45em] text-[0.8em]">
                  <span className="font-semibold">{row.name}</span>
                  <span className="tabular-nums">{duration(row.minutes)}</span>
                  <span className="text-muted tabular-nums">{row.share}&nbsp;%</span>
                </p>
                <span className="mt-[0.25em] block h-[0.4em] overflow-hidden rounded-full bg-ink/10">
                  <span className={`block h-full rounded-full ${row.tone}`} style={{ width: `${row.share}%` }} />
                </span>
              </div>
            ))}
          </div>
        </div>
      </div>
      <TabBar />
    </div>
  );
}
