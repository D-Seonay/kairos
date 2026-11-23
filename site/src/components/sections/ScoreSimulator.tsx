"use client";

import { useEffect, useId, useMemo, useRef, useState, type CSSProperties, type RefObject } from "react";
import { usePresence } from "@/components/motion/usePresence";
import { useReducedMotion } from "@/components/motion/useReducedMotion";
import { useSpringNumber, type SpringConfig } from "@/components/motion/useSpringNumber";
import { Grain } from "@/components/visual/Grain";
import { HalftoneField } from "@/components/visual/HalftoneField";
import { RegistrationMarks } from "@/components/visual/RegistrationMarks";
import { ScoreDial, clampScore } from "@/components/visual/ScoreDial";
import {
  CATEGORY_LABEL,
  DEEP_SHARE,
  HRV_RANGE,
  RHR_RANGE,
  SLEEP_RANGE,
  WEIGHTS,
  simulate,
  type Category,
  type SimulatorInput,
} from "@/lib/score/engine";
import { SAMPLE_PUSH, adjustSession, type Exercise } from "@/lib/score/session";

const INITIAL: SimulatorInput = { sleepHours: 7.5, hrvPercent: -5, rhrDeltaBpm: 2 };

/** The needle: a quick spring with a little overshoot, like RecoveryGauge's reveal but snappier for dragging. */
const NEEDLE_SPRING: SpringConfig = { stiffness: 90, damping: 13 };
/** Counters in the session: no overshoot, a rest time never goes backwards past its target. */
const COUNTER_SPRING: SpringConfig = { stiffness: 140, damping: 24 };
/** The live region waits for the visitor to let go before speaking. */
const ANNOUNCE_DELAY_MS = 700;

const MINUS = "−";

// ---------- Spoken values ----------

export function sleepValueText(hours: number): string {
  const whole = Math.floor(hours);
  const minutes = Math.round((hours - whole) * 60);
  return minutes === 0 ? `${whole} h` : `${whole} h ${String(minutes).padStart(2, "0")}`;
}

function relation(value: number): string {
  if (value === 0) return "dans ta normale";
  return value < 0 ? "sous ta normale" : "au-dessus de ta normale";
}

export function hrvValueText(percent: number): string {
  if (percent === 0) return relation(0);
  return `${Math.abs(percent)} % ${relation(percent)}`;
}

export function rhrValueText(delta: number): string {
  if (delta === 0) return relation(0);
  const beats = Math.abs(delta);
  return `${beats} ${beats === 1 ? "battement" : "battements"} ${relation(delta)}`;
}

const signed = (value: number) => (value > 0 ? `+${value}` : value < 0 ? `${MINUS}${Math.abs(value)}` : "0");

function announcement(displayScore: number, category: Category, reasons: string[]): string {
  const head = `Récupération ${displayScore} sur 100, ${CATEGORY_LABEL[category].toLowerCase()}.`;
  return reasons.length === 0 ? `${head} Séance sans changement.` : `${head} ${reasons.join(". ")}.`;
}

// ---------- Motion helpers ----------

/** A number that rolls to its new value, like a film counter. */
function Counter({ value, reduced, format }: { value: number; reduced: boolean; format: (value: number) => string }) {
  const shown = useSpringNumber(value, reduced, COUNTER_SPRING);
  return <>{format(shown)}</>;
}

const formatRest = (seconds: number) => {
  const total = Math.max(0, Math.round(seconds));
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, "0")}`;
};

const formatRpe = (rpe: number) => {
  const tenth = Math.round(rpe * 10) / 10;
  return Number.isInteger(tenth) ? String(tenth) : tenth.toFixed(1).replace(".", ",");
};

// ---------- Sliders ----------

type Range = { min: number; max: number; step: number };

type SliderProps = {
  label: string;
  hint: string;
  range: Range;
  value: number;
  onChange: (value: number) => void;
  valueText: string;
  /** What the eye reads next to the label: the value, then its meaning. */
  display: { value: string; meaning?: string };
  /** The fill grows from here to the thumb. */
  origin: number;
  marks: { at: number; label: string }[];
};

const share = (value: number, range: Range) => (value - range.min) / (range.max - range.min);

function Slider({ label, hint, range, value, onChange, valueText, display, origin, marks }: SliderProps) {
  const id = useId();
  const hintId = `${id}-hint`;
  const a = Math.min(share(origin, range), share(value, range));
  const b = Math.max(share(origin, range), share(value, range));

  return (
    <div className="sim-slider">
      <div className="flex items-end justify-between gap-4">
        <div className="min-w-0">
          <label htmlFor={id} className="block text-[17px] font-semibold tracking-[-0.01em] text-ink">
            {label}
          </label>
          <p id={hintId} className="mt-0.5 text-[13px] leading-snug text-muted">
            {hint}
          </p>
        </div>
        <p aria-hidden="true" className="shrink-0 text-right whitespace-nowrap">
          <span className="block font-sans text-[30px] leading-none font-extralight tracking-[-0.03em] text-ink tabular-nums">
            {display.value}
          </span>
          {display.meaning && <span className="mt-1 block text-[12px] text-muted">{display.meaning}</span>}
        </p>
      </div>

      <div className="relative mt-3" style={{ "--a": a, "--b": b } as CSSProperties}>
        <input
          id={id}
          type="range"
          className="sim-range"
          min={range.min}
          max={range.max}
          step={range.step}
          value={value}
          aria-valuetext={valueText}
          aria-describedby={hintId}
          onChange={(event) => {
            const next = Number(event.currentTarget.value);
            if (Number.isFinite(next)) onChange(next);
          }}
        />
        <div aria-hidden="true" className="sim-marks relative h-5 font-mono text-[10.5px] text-muted">
          <span className="absolute left-0">{marks[0]?.label}</span>
          {marks.slice(1, -1).map((mark) => (
            <span
              key={mark.at}
              className="sim-mark absolute -translate-x-1/2 whitespace-nowrap"
              style={{ "--at": share(mark.at, range) } as CSSProperties}
            >
              {mark.label}
            </span>
          ))}
          <span className="absolute right-0">{marks[marks.length - 1]?.label}</span>
        </div>
      </div>
    </div>
  );
}

// ---------- Dial card ----------

const FACTORS = [
  { key: "sleep", label: "Sommeil", weight: WEIGHTS.sleep },
  { key: "hrv", label: "Variabilité", weight: WEIGHTS.hrv },
  { key: "restingHeartRate", label: "FC repos", weight: WEIGHTS.restingHeartRate },
] as const;

/** The category name, changing through a halftone dissolve: the old word breaks into dots as the new one fills in. */
function CategoryWord({ category, reduced }: { category: Category; reduced: boolean }) {
  const words = usePresence([category], (value) => value, reduced, 500);
  return (
    <div aria-hidden="true" className="grid justify-items-center">
      {words.map(({ key, item, phase }) => (
        <p
          key={key}
          data-phase={phase}
          className="sim-trame col-start-1 row-start-1 font-display text-[clamp(2rem,1.2rem+3vw,3.1rem)] leading-none font-black tracking-[-0.045em] whitespace-nowrap text-ink"
        >
          {item === "overreached" && (
            <span className="mr-[0.22em] mb-[0.1em] inline-block size-[0.24em] rounded-full bg-signal align-middle" />
          )}
          {CATEGORY_LABEL[item]}
        </p>
      ))}
    </div>
  );
}

// ---------- Session ----------

function SetDot({ index, filled, reduced }: { index: number; filled: boolean; reduced: boolean }) {
  const marks = usePresence(filled ? ["set"] : [], (value) => value, reduced, 200);
  return (
    <span className="relative grid size-3 place-items-center rounded-full border border-ink/30">
      {marks.map(({ key, phase }) => (
        <span
          key={key}
          data-phase={phase}
          className="sim-set absolute inset-[-1px] rounded-full bg-ink"
          style={{ "--i": index } as CSSProperties}
        />
      ))}
    </span>
  );
}

function SetDots({ planned, kept, reduced }: { planned: number; kept: number; reduced: boolean }) {
  return (
    <span aria-hidden="true" className="flex gap-1.5">
      {Array.from({ length: planned }, (_, index) => (
        <SetDot key={index} index={index} filled={index < kept} reduced={reduced} />
      ))}
    </span>
  );
}

function SessionRow({ planned, exercise, reduced }: { planned: Exercise; exercise: Exercise; reduced: boolean }) {
  return (
    <li className="py-3.5 sm:grid sm:grid-cols-[minmax(0,1fr)_7.5rem_4.5rem_5rem] sm:items-center sm:gap-x-4">
      <span className="block text-[16px] font-medium text-ink">{exercise.name}</span>
      <span className="mt-2 flex items-center justify-between gap-4 font-mono text-[12.5px] tabular-nums sm:contents">
        <span className="flex items-center gap-2.5">
          <SetDots planned={planned.sets} kept={exercise.sets} reduced={reduced} />
          <span className="text-muted">
            <span className="sr-only">
              {exercise.sets} séries de {exercise.reps} répétitions
            </span>
            <span aria-hidden="true">
              {exercise.sets}×{exercise.reps}
            </span>
          </span>
        </span>
        <span className="text-ink">
          <span className="text-muted">RPE </span>
          <Counter value={exercise.rpe} reduced={reduced} format={formatRpe} />
        </span>
        <span className="text-ink sm:text-right">
          <span className="text-muted">repos </span>
          <Counter value={exercise.restSeconds} reduced={reduced} format={formatRest} />
        </span>
      </span>
    </li>
  );
}

/** Size of an element's box, kept current. */
function useBoxSize(ref: RefObject<Element | null>) {
  const [size, setSize] = useState({ width: 0, height: 0 });
  useEffect(() => {
    const element = ref.current;
    if (!element) return;
    const read = () => setSize({ width: element.clientWidth, height: element.clientHeight });
    read();
    if (typeof ResizeObserver === "undefined") return;
    const observer = new ResizeObserver(read);
    observer.observe(element);
    return () => observer.disconnect();
  }, [ref]);
  return size;
}

/**
 * Felt-pen cross over the session when Pulse swaps it for mobility. The
 * strokes are drawn in the list's own pixels (no stretched view box), so the
 * pen keeps an even width at any aspect ratio.
 */
function FeltCross({ phase }: { phase: "static" | "enter" | "exit" }) {
  const ref = useRef<SVGSVGElement>(null);
  const { width: w, height: h } = useBoxSize(ref);
  const strokes =
    w > 0 && h > 0
      ? [
          `M${w * 0.03} ${h * 0.14} C ${w * 0.3} ${h * 0.26}, ${w * 0.62} ${h * 0.66}, ${w * 0.97} ${h * 0.88}`,
          `M${w * 0.05} ${h * 0.9} C ${w * 0.36} ${h * 0.7}, ${w * 0.6} ${h * 0.34}, ${w * 0.96} ${h * 0.1}`,
        ]
      : [];
  return (
    <svg
      ref={ref}
      aria-hidden="true"
      data-phase={phase}
      className="sim-cross pointer-events-none absolute inset-0 h-full w-full overflow-visible"
    >
      {strokes.map((d, index) => (
        <path
          key={index}
          d={d}
          pathLength={1}
          fill="none"
          stroke="#ff4f2e"
          strokeWidth={4.5}
          strokeLinecap="round"
          style={{ "--i": index } as CSSProperties}
        />
      ))}
    </svg>
  );
}

/**
 * The reasons Pulse adjusted the session. A reason that leaves fades out
 * where it stood (out of the flow, like popLayout) while the new ones enter.
 */
function Reasons({ reasons, reduced }: { reasons: string[]; reduced: boolean }) {
  const list = useRef<HTMLUListElement>(null);
  const tops = useRef(new Map<string, number>());
  const entries = usePresence(reasons, (reason) => reason, reduced, 180);

  // Remember where each reason stands, so one that leaves can stay put.
  useEffect(() => {
    for (const child of list.current?.children ?? []) {
      const key = child.getAttribute("data-key");
      if (key && child.getAttribute("data-phase") !== "exit") tops.current.set(key, (child as HTMLElement).offsetTop);
    }
  });

  return (
    <ul ref={list} className="relative mt-4 flex flex-col gap-3">
      {entries.map(({ key, item, phase }) => (
        <li
          key={key}
          data-key={key}
          data-phase={phase}
          ref={(element) => {
            const top = tops.current.get(key);
            if (element && phase === "exit" && top !== undefined) element.style.top = `${top}px`;
          }}
          className="sim-reason flex gap-3 text-[17px] leading-snug text-ink"
        >
          <span aria-hidden="true" className="mt-[0.6em] h-[2px] w-3 shrink-0 bg-ink" />
          <span>{item}</span>
        </li>
      ))}
    </ul>
  );
}

// ---------- Section ----------

/**
 * « Le score, en direct »: three native sliders drive the app's own formulas
 * (lib/score), the dial follows with spring inertia, the category changes
 * through a halftone dissolve and the sample session is rebuilt in place.
 * The section's halftone field gets lighter as the score rises, like the
 * score slab in the app. Under reduced motion every value lands at once.
 */
export function ScoreSimulator() {
  const reduced = useReducedMotion();
  const [input, setInput] = useState<SimulatorInput>(INITIAL);
  const result = useMemo(() => simulate(input), [input]);
  const session = useMemo(() => adjustSession(SAMPLE_PUSH, result.category), [result.category]);

  const cross = usePresence(session.mobility ? ["cross"] : [], (value) => value, reduced, 300);

  const shown = useSpringNumber(result.score, reduced, NEEDLE_SPRING);
  const light = clampScore(shown) / 100;

  // The live region speaks the settled result once the visitor stops moving.
  const settled = announcement(result.displayScore, result.category, session.reasons);
  const [announced, setAnnounced] = useState(settled);
  useEffect(() => {
    const id = window.setTimeout(() => setAnnounced(settled), ANNOUNCE_DELAY_MS);
    return () => window.clearTimeout(id);
  }, [settled]);

  const set = (key: keyof SimulatorInput) => (value: number) => setInput((current) => ({ ...current, [key]: value }));

  return (
    <section id="score" aria-labelledby="score-title" className="relative isolate overflow-clip border-b border-rule">
      <Grain />
      <RegistrationMarks />

      <div className="relative mx-auto max-w-6xl px-4 py-24 sm:px-6 sm:py-28 lg:py-32">
        <header className="grid gap-6 lg:grid-cols-[minmax(0,7fr)_minmax(0,5fr)] lg:items-end lg:gap-14">
          <div>
            <p className="inline-flex items-center gap-2 font-mono text-[11px] tracking-[0.18em] text-muted uppercase">
              <span aria-hidden="true" className="size-2 rounded-full bg-signal" />
              Le score, en direct
            </p>
            <h2
              id="score-title"
              className="mt-5 font-display text-[clamp(2.5rem,1rem+5vw,4.75rem)] leading-[0.9] font-black tracking-[-0.05em] text-balance text-ink"
            >
              Règle ta nuit. Regarde ta séance changer.
            </h2>
          </div>
          <p className="max-w-[54ch] text-[17px] leading-relaxed text-muted lg:pb-2">
            Chaque matin, Pulse compare ton sommeil, ta variabilité cardiaque et ta fréquence cardiaque au repos à ta
            normale. Bouge les curseurs : le score sur 100 se recalcule et la séance du jour s&apos;ajuste.
          </p>
        </header>

        <div className="mt-14 grid gap-10 lg:mt-16 lg:grid-cols-[minmax(0,5fr)_minmax(0,7fr)] lg:gap-14">
          {/* Controls */}
          <div className="flex flex-col gap-9 lg:pt-4" role="group" aria-label="Ta nuit et ton matin">
            <Slider
              label="Sommeil"
              hint={`Sommeil profond fixé à ${Math.round(DEEP_SHARE * 100)} % de la nuit.`}
              range={SLEEP_RANGE}
              value={input.sleepHours}
              onChange={set("sleepHours")}
              valueText={sleepValueText(input.sleepHours)}
              display={{ value: sleepValueText(input.sleepHours) }}
              origin={SLEEP_RANGE.min}
              marks={[
                { at: 3, label: "3 h" },
                { at: 8, label: "cible 8 h" },
                { at: 10, label: "10 h" },
              ]}
            />
            <Slider
              label="Variabilité cardiaque"
              hint="Ta VFC du matin, par rapport à ta normale."
              range={HRV_RANGE}
              value={input.hrvPercent}
              onChange={set("hrvPercent")}
              valueText={hrvValueText(input.hrvPercent)}
              display={{ value: `${signed(input.hrvPercent)} %`, meaning: relation(input.hrvPercent) }}
              origin={0}
              marks={[
                { at: -40, label: `${MINUS}40 %` },
                { at: 0, label: "ta normale" },
                { at: 30, label: "+30 %" },
              ]}
            />
            <Slider
              label="Fréquence cardiaque au repos"
              hint="Ta FC au repos du matin, par rapport à ta normale."
              range={RHR_RANGE}
              value={input.rhrDeltaBpm}
              onChange={set("rhrDeltaBpm")}
              valueText={rhrValueText(input.rhrDeltaBpm)}
              display={{ value: `${signed(input.rhrDeltaBpm)} bpm`, meaning: relation(input.rhrDeltaBpm) }}
              origin={0}
              marks={[
                { at: -5, label: `${MINUS}5` },
                { at: 0, label: "ta normale" },
                { at: 15, label: "+15 bpm" },
              ]}
            />

            <p className="flex gap-3 border-t border-rule pt-5 text-[13.5px] leading-relaxed text-muted">
              <span aria-hidden="true" className="mt-[0.55em] size-1.5 shrink-0 rounded-full bg-signal" />
              <span>
                Simulation avec les mêmes formules que l&apos;app. Dans Pulse, tes valeurs sont comparées à ta propre
                ligne de base.
              </span>
            </p>
          </div>

          {/* The slab: dial, category, factors */}
          <div className="sim-slab relative isolate overflow-hidden rounded-[30px] border border-rule bg-card px-5 pt-8 pb-6 sm:px-10 sm:pt-10">
            <div aria-hidden="true" className="sim-slab-field pointer-events-none absolute inset-0 -z-10">
              <HalftoneField light={light} ink={1} interactive />
            </div>

            <p
              aria-hidden="true"
              className="inline-flex items-center rounded-full border border-ink/10 bg-card px-3 py-1.5 font-mono text-[11px] tracking-[0.18em] text-muted uppercase"
            >
              Récupération
            </p>

            <ScoreDial value={shown} category={result.category} className="mx-auto mt-3 max-w-[400px]" />

            <div role="status" aria-live="polite" aria-atomic="true" className="sr-only">
              {announced}
            </div>

            <div className="mt-1 sm:mt-2">
              <CategoryWord category={result.category} reduced={reduced} />
            </div>

            <dl className="mt-8 grid grid-cols-3 gap-3 border-t border-ink/10 pt-5">
              {FACTORS.map((factor) => (
                <div key={factor.key} className="min-w-0">
                  <dt className="font-mono text-[10.5px] tracking-[0.14em] text-muted uppercase">{factor.label}</dt>
                  <dd className="mt-1.5 text-[26px] leading-none font-light tracking-[-0.03em] text-ink tabular-nums">
                    <Counter
                      value={result.factors[factor.key]}
                      reduced={reduced}
                      format={(v) => String(Math.round(clampScore(v)))}
                    />
                    <span className="sr-only"> sur 100</span>
                  </dd>
                  <dd className="mt-1.5 text-[12px] text-muted">{Math.round(factor.weight * 100)} % du score</dd>
                </div>
              ))}
            </dl>
          </div>
        </div>

        {/* The sample session, rebuilt for the category */}
        <div className="mt-12 grid gap-10 border-t-2 border-ink pt-8 lg:mt-16 lg:grid-cols-[minmax(0,7fr)_minmax(0,5fr)] lg:gap-14">
          <div>
            <h3 className="flex items-baseline justify-between gap-4">
              <span className="font-display text-[26px] leading-none font-black tracking-[-0.035em] text-ink">
                Séance d&apos;exemple : Push
              </span>
              <span className="font-mono text-[11px] tracking-[0.14em] text-muted uppercase">
                {session.mobility ? "remplacée" : `${session.exercises.reduce((n, e) => n + e.sets, 0)} séries`}
              </span>
            </h3>
            <div className="relative mt-3">
              <ul
                aria-label="Séance d'exemple : Push"
                className={[
                  "divide-y divide-rule border-y border-rule transition-opacity duration-500 motion-reduce:transition-none",
                  session.mobility ? "opacity-35" : "",
                ].join(" ")}
              >
                {session.exercises.map((exercise, index) => (
                  <SessionRow key={exercise.name} planned={SAMPLE_PUSH[index]} exercise={exercise} reduced={reduced} />
                ))}
              </ul>
              {cross.map(({ key, phase }) => (
                <FeltCross key={key} phase={phase} />
              ))}
            </div>
          </div>

          <div>
            <h3 className="font-mono text-[11px] tracking-[0.18em] text-muted uppercase">Ce que Pulse change</h3>
            <Reasons
              reasons={session.reasons.length > 0 ? session.reasons : ["Rien : la séance reste telle que prévue."]}
              reduced={reduced}
            />
          </div>
        </div>
      </div>
    </section>
  );
}
