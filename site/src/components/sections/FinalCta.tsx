import Image from "next/image";
import { AppStoreBadge } from "@/components/AppStoreBadge";
import { RegistrationMarks } from "@/components/visual/RegistrationMarks";

/**
 * Appel final: the night is over. The icon, a print of paper on the dark table,
 * with a sun of halftone dots rising behind it as the section scrolls in
 * (CSS scroll-driven, so it needs no JavaScript and is simply risen where the
 * browser cannot do that, or under reduced motion). The badge sits on ink.
 */
export function FinalCta() {
  return (
    <section
      aria-labelledby="final-title"
      className="focus-on-ink relative isolate overflow-clip bg-ink text-paper"
    >
      <RegistrationMarks className="text-paper/35!" />

      <div className="relative mx-auto flex max-w-6xl flex-col items-center px-4 pt-24 pb-24 text-center sm:px-6 sm:pt-28 sm:pb-28 lg:pt-32">
        <div className="final-stage">
          <div aria-hidden="true" className="final-glow" />
          <div aria-hidden="true" className="final-sun" />
          <Image
            src="/icon/light-1024.png"
            alt="L'icône de Pulse : un tracé de pouls en points de trame, et un point rouge."
            width={512}
            height={512}
            sizes="(min-width: 640px) 208px, 176px"
            className="final-icon"
          />
        </div>

        <h2
          id="final-title"
          className="mt-10 max-w-[14ch] font-display text-[clamp(2.75rem,1rem+6.5vw,6rem)] leading-[0.88] font-black tracking-[-0.05em] text-balance"
        >
          Demain matin, laisse ta nuit décider.
        </h2>
        <p className="mt-6 max-w-[40ch] text-[17px] leading-relaxed text-paper/75 sm:text-lg">
          Gratuit, sans compte, et tes données Santé restent sur ton iPhone.
        </p>
        <div className="mt-9">
          <AppStoreBadge
            height={56}
            className="max-sm:flex-col max-sm:[&>span:last-child]:mt-4 max-sm:[&>span:last-child]:ml-0!"
            captionClassName="text-paper/70!"
          />
        </div>
      </div>
    </section>
  );
}
