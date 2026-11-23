import type { CSSProperties } from "react";
import { AppStoreBadge } from "@/components/AppStoreBadge";
import { TODAY_SCREEN_ALT } from "./features-data";
import { Grain } from "@/components/visual/Grain";
import { PhoneFrame } from "@/components/visual/PhoneFrame";
import { PulseTrace } from "@/components/visual/PulseTrace";
import { RegistrationMarks } from "@/components/visual/RegistrationMarks";
import { APP_STORE_LIVE } from "@/lib/config";
import { HeroDarkroom } from "./HeroDarkroom";

/** Delay before an element starts to emerge, on the hero clock (see globals.css). */
const at = (seconds: number) => ({ "--d": `${seconds}s` }) as CSSProperties;

const BULLETS = ["Gratuit", "Sans compte", "Tes données Santé restent sur ton iPhone"];

/**
 * The pulse line across the hero. Two copies share the geometry: a pale
 * oscilloscope line that draws itself in the dark and fades with the night,
 * and the halftone trace of the icon, already there in ink, that the
 * developing print reveals.
 */
function HeroTrace() {
  return (
    <div aria-hidden="true" className="hero-trace relative grid grid-cols-[1fr_auto_1fr]">
      {/* Final print: dotted ink, like the icon. */}
      <span className="trace-flank trace-flank-dots" />
      <PulseTrace progress={1} variant="dots" dot className="trace-motif text-ink" dotClassName="dev-dot" />
      <span className="trace-flank trace-flank-dots" />

      {/* In the dark: a pale line drawn left to right, under the red safelight. */}
      <div className="dev-night absolute inset-0 grid grid-cols-[1fr_auto_1fr]">
        <span className="trace-flank trace-flank-line dev-draw-x" style={at(0.1)} />
        <span className="relative">
          <span className="trace-glow dev-glow" />
          <PulseTrace progress={1} className="trace-motif relative text-paper" pathClassName="dev-draw-path" />
        </span>
        <span className="trace-flank trace-flank-line dev-draw-x" style={at(0.62)} />
      </div>
    </div>
  );
}

function PhoneFan() {
  return (
    <div className="hero-fan relative mx-auto flex items-start justify-center">
      <PhoneFrame
        src="/screens/stats.jpg"
        alt="L'écran Statistiques de Pulse, onglet Biométrie : fréquence cardiaque au repos de 68 bpm, sommeil moyen de 6 h 25 et récupération moyenne de 79."
        sizes="(min-width: 1024px) 270px, 45vw"
        className="fan-side dev-fan"
        style={{ "--fan": "translateX(calc(var(--w) * -0.64)) rotate(-7deg)", ...at(1.3) } as CSSProperties}
      />
      <PhoneFrame
        src="/screens/planning.jpg"
        alt="L'écran Planning de Pulse : la semaine du 16 novembre, jour par jour, avec la séance prévue chaque jour."
        sizes="(min-width: 1024px) 270px, 45vw"
        className="fan-side dev-fan"
        style={{ "--fan": "translateX(calc(var(--w) * 0.64)) rotate(7deg)", ...at(1.42) } as CSSProperties}
      />
      <PhoneFrame
        src="/screens/today.jpg"
        alt={TODAY_SCREEN_ALT}
        priority
        sizes="(min-width: 1024px) 320px, 55vw"
        className="fan-center dev-fan"
        style={{ "--fan": "none", ...at(1.18) } as CSSProperties}
      />
    </div>
  );
}

/**
 * The hero develops like a print: ink first (night, the darkroom), the pulse
 * trace drawn like an ECG, then the halftone comes up and clears to the paper
 * of the morning while the title and the captures emerge. All the text is in
 * the served HTML; the sequence is CSS (opacity, filter, transform), skipped
 * entirely under reduced motion.
 */
export function Hero() {
  return (
    <section id="top" aria-labelledby="hero-title" className="hero relative isolate overflow-clip border-b border-rule">
      <HeroDarkroom />
      <Grain />
      <RegistrationMarks className="top-16 sm:top-20" />

      <div className="relative z-10 mx-auto max-w-6xl px-4 pt-28 text-center sm:px-6 sm:pt-32 lg:pt-24">
        <p
          className="dev-emerge inline-flex items-center gap-2 rounded-full border border-rule bg-paper/70 px-3 py-1.5 font-mono text-[11px] uppercase tracking-[0.18em] text-muted"
          style={at(0.9)}
        >
          <span aria-hidden="true" className="size-2 rounded-full bg-signal" />
          {APP_STORE_LIVE ? "Disponible sur iPhone" : "Bientôt sur iPhone"}
        </p>

        <h1
          id="hero-title"
          className="mx-auto mt-6 font-display text-[clamp(3rem,0.4rem+8vw,7.25rem)] leading-[0.86] font-black tracking-[-0.05em] text-balance text-ink"
        >
          <span className="dev-emerge inline-block" style={at(0.86)}>
            Ta nuit décide
          </span>{" "}
          <span className="dev-emerge inline-block" style={at(1.0)}>
            de ta séance.
          </span>
        </h1>

        <p
          className="dev-emerge mx-auto mt-6 max-w-[36ch] text-[17px] leading-relaxed text-muted sm:mt-7 sm:max-w-[46ch] sm:text-xl"
          style={at(1.12)}
        >
          Un score de récupération chaque matin, des séances de muscu guidées et tes compléments au même
          endroit.
        </p>

        <div
          className="dev-emerge mt-7 flex flex-col items-center justify-center gap-x-9 gap-y-5 sm:mt-8 sm:flex-row"
          style={at(1.22)}
        >
          <AppStoreBadge height={48} />
          <a
            href="#score"
            className="focus-ring rounded-sm text-[15px] font-medium text-ink underline decoration-rule decoration-2 underline-offset-[6px] transition-colors hover:decoration-ink"
          >
            Voir comment marche le score ↓
          </a>
        </div>

        <ul
          className="dev-emerge mx-auto mt-7 flex max-w-sm flex-wrap items-center justify-center gap-x-6 gap-y-2 text-[15px] text-ink sm:mt-8 sm:max-w-none"
          style={at(1.32)}
        >
          {BULLETS.map((bullet) => (
            <li key={bullet} className="flex items-center gap-2.5">
              <span aria-hidden="true" className="size-1.5 rounded-full bg-ink" />
              {bullet}
            </li>
          ))}
        </ul>
      </div>

      <div className="relative z-0 mt-8 sm:mt-10">
        <HeroTrace />
      </div>
      <div className="relative z-10">
        <PhoneFan />
      </div>
    </section>
  );
}
