import type { Metadata } from "next";
import Link from "next/link";
import { Footer } from "@/components/sections/Footer";
import { Nav } from "@/components/sections/Nav";
import { Grain } from "@/components/visual/Grain";
import { PulseTrace } from "@/components/visual/PulseTrace";
import { RegistrationMarks } from "@/components/visual/RegistrationMarks";

export const metadata: Metadata = {
  title: "Page introuvable",
  alternates: { canonical: null },
  robots: { index: false },
};

/** The 404: the number in ink dots, a pulse line that stays flat on both sides, and the way home. */
export default function NotFound() {
  return (
    <>
      <Nav anchorBase="/" />
      <main id="contenu" className="relative isolate flex flex-1 flex-col justify-center overflow-clip border-b border-rule">
        <Grain />
        <RegistrationMarks className="top-16 sm:top-20" />
        <div className="relative mx-auto w-full max-w-6xl px-4 pt-32 pb-20 sm:px-6 sm:pt-40 sm:pb-28">
          <p aria-hidden="true" className="dot-numeral text-[clamp(9.5rem,2rem+30vw,24rem)]">
            404
          </p>
          <div aria-hidden="true" className="mt-4 flex items-center gap-4 sm:mt-6">
            <span className="h-px flex-1 bg-ink/50" />
            <PulseTrace progress={1} dot className="h-14 w-auto text-ink sm:h-20" />
            <span className="h-px flex-1 bg-ink/50" />
          </div>
          <h1 className="mt-8 font-display text-[clamp(2.25rem,1rem+4vw,4rem)] leading-[0.95] font-black tracking-[-0.045em] text-balance sm:mt-10">
            Pas de pouls sur cette page.
          </h1>
          <p className="mt-4 max-w-[46ch] text-[17px] leading-relaxed text-muted sm:text-lg">
            Le lien est cassé ou la page a changé d&apos;adresse. L&apos;accueil, lui, est bien là.
          </p>
          <Link
            href="/"
            className="mt-8 inline-flex h-12 items-center rounded-full bg-ink px-6 text-[15px] font-medium text-paper transition-colors hover:bg-ink/85 focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-signal"
          >
            Retour à l&apos;accueil
          </Link>
        </div>
      </main>
      <Footer anchorBase="/" />
    </>
  );
}
