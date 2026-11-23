import { CounterBand } from "@/components/visual/CounterBand";
import { Grain } from "@/components/visual/Grain";
import { NUMBERS } from "./numbers-data";

/**
 * Les chiffres: five figures that can all be checked in the app's code or the
 * store sheet (numbers-data.ts says where). They roll like a film counter when
 * the band comes into view; the figures are in the served HTML.
 */
export function Numbers() {
  return (
    <section id="chiffres" aria-labelledby="numbers-title" className="relative isolate overflow-clip border-b border-rule">
      <Grain />
      <div className="relative mx-auto max-w-6xl px-4 py-24 sm:px-6 sm:py-28 lg:py-32">
        <header className="grid gap-5 lg:grid-cols-[minmax(0,7fr)_minmax(0,5fr)] lg:items-end lg:gap-14">
          <div>
            <p className="inline-flex items-center gap-2 font-mono text-[11px] tracking-[0.18em] text-muted uppercase">
              <span aria-hidden="true" className="size-2 rounded-full bg-signal" />
              Les chiffres
            </p>
            <h2
              id="numbers-title"
              className="mt-5 font-display text-[clamp(2.5rem,1rem+5vw,4.75rem)] leading-[0.9] font-black tracking-[-0.05em] text-balance text-ink"
            >
              Pulse en cinq chiffres.
            </h2>
          </div>
          <p className="max-w-[44ch] text-[17px] leading-relaxed text-muted lg:pb-2">
            Chacun se vérifie dans le code de l&apos;app ou dans sa fiche App Store. Aucun n&apos;est arrondi pour faire
            joli.
          </p>
        </header>

        <CounterBand figures={NUMBERS.map(({ value, label }) => ({ value, label }))} />
      </div>
    </section>
  );
}
