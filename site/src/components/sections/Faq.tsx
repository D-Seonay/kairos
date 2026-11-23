import { FaqCollapse } from "@/components/visual/FaqCollapse";
import { SUPPORT_URL } from "@/lib/config";
import { FAQ } from "./faq-data";

/** The plus of the icon, drawn with five halftone dots; the vertical ones go when it opens. */
function DotPlus() {
  return (
    <span aria-hidden="true" className="faq-plus">
      <i className="faq-dot faq-dot-v" style={{ gridArea: "1 / 2" }} />
      <i className="faq-dot" style={{ gridArea: "2 / 1" }} />
      <i className="faq-dot faq-dot-core" style={{ gridArea: "2 / 2" }} />
      <i className="faq-dot" style={{ gridArea: "2 / 3" }} />
      <i className="faq-dot faq-dot-v" style={{ gridArea: "3 / 2" }} />
    </span>
  );
}

/**
 * FAQ with native <details>. Answers are rendered open in the served HTML and
 * folded after hydration (see FaqCollapse), so they read without JavaScript.
 */
export function Faq() {
  return (
    <section id="faq" aria-labelledby="faq-title" className="relative isolate overflow-clip border-b border-rule">
      <div className="mx-auto grid max-w-6xl gap-12 px-4 py-24 sm:px-6 sm:py-28 lg:grid-cols-[minmax(0,4fr)_minmax(0,7fr)] lg:gap-20 lg:py-32">
        <div className="lg:sticky lg:top-28 lg:self-start">
          <p className="inline-flex items-center gap-2 font-mono text-[11px] tracking-[0.18em] text-muted uppercase">
            <span aria-hidden="true" className="size-2 rounded-full bg-signal" />
            Questions fréquentes
          </p>
          <h2
            id="faq-title"
            className="mt-5 font-display text-[clamp(2.5rem,1rem+5vw,4.75rem)] leading-[0.9] font-black tracking-[-0.05em] text-balance text-ink"
          >
            Tu te demandes peut-être.
          </h2>
          <p className="mt-6 max-w-[38ch] text-[17px] leading-relaxed text-muted">
            Les réponses courtes. Le reste est dans l&apos;assistance.
          </p>
          <a
            href={SUPPORT_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="focus-ring mt-7 inline-block rounded-sm text-[15px] font-medium text-ink underline decoration-rule decoration-2 underline-offset-[6px] transition-colors hover:decoration-ink"
          >
            Toute l&apos;assistance ↗
          </a>
        </div>

        <FaqCollapse className="faq-list">
          {FAQ.map((entry) => (
            <details key={entry.id} id={`faq-${entry.id}`} className="faq-item" open>
              <summary className="faq-summary">
                <span className="faq-question">{entry.question}</span>
                <DotPlus />
              </summary>
              <p className="faq-answer">{entry.answer}</p>
            </details>
          ))}
        </FaqCollapse>
      </div>
    </section>
  );
}
