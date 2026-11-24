import type { ReactNode } from "react";
import { RegistrationMarks } from "@/components/visual/RegistrationMarks";
import { PRIVACY_URL } from "@/lib/config";

type Stop = {
  id: string;
  where: string;
  title: ReactNode;
  body: string;
  /** The stop where nothing arrives: a hollow node and a struck title. */
  none?: boolean;
};

/** The route a night's data takes (or does not take). Each line follows the store sheet, section 1. */
const ROUTE: Stop[] = [
  {
    id: "iphone",
    where: "Sur ton iPhone",
    title: "Apple Santé",
    body: "Ton sommeil, ta variabilité cardiaque et ta fréquence cardiaque au repos sont lus sur ton iPhone. Pulse ne les écrit jamais dans iCloud. Tes photos de corps restent aussi sur ton iPhone, hors sauvegarde, derrière Face ID.",
  },
  {
    id: "icloud",
    where: "Dans ton iCloud privé",
    title: "Ce que tu saisis",
    body: "Tes séances et leurs photos, tes courses et leur tracé, tes compléments et les scores que Pulse calcule se synchronisent dans ton iCloud privé, auquel personne d'autre n'a accès.",
  },
  {
    id: "serveur",
    where: "Chez nous",
    title: <span className="privacy-strike">Un serveur Pulse</span>,
    body: "Il n'y en a pas. Rien ne part vers le développeur, ni vers un tiers.",
    none: true,
  },
  {
    id: "export",
    where: "Quand tu veux",
    title: "Tout emporter, ou tout effacer",
    body: "Tu exportes tes données en JSON ou CSV, ou tu supprimes tout, directement depuis l'app.",
  },
];

/**
 * Confidentialité: the negative of the page. The section is ink with a paper
 * halftone, like a print held up as its own negative, and the data's route
 * reads top to bottom with the one stop that stays empty struck out. All the
 * text is in the served HTML.
 */
export function Privacy() {
  return (
    <section
      id="confidentialite"
      aria-labelledby="privacy-title"
      className="focus-on-ink relative isolate overflow-clip bg-ink text-paper"
    >
      <div aria-hidden="true" className="privacy-field" />
      <RegistrationMarks className="text-paper/35!" />

      <div className="relative mx-auto grid max-w-6xl gap-14 px-4 py-24 sm:px-6 sm:py-28 lg:grid-cols-[minmax(0,5fr)_minmax(0,6fr)] lg:gap-20 lg:py-32">
        <div className="lg:sticky lg:top-28 lg:self-start lg:pt-2">
          <p className="inline-flex items-center gap-2 font-mono text-[11px] tracking-[0.18em] text-paper/65 uppercase">
            <span aria-hidden="true" className="size-2 rounded-full bg-signal" />
            Confidentialité
          </p>
          <h2
            id="privacy-title"
            className="mt-5 font-display text-[clamp(2.5rem,1rem+5vw,4.75rem)] leading-[0.9] font-black tracking-[-0.05em] text-balance"
          >
            Ta nuit reste sur ton iPhone.
          </h2>
          <p className="mt-6 max-w-[44ch] text-[17px] leading-relaxed text-paper/75">
            Pas de compte à créer, aucun serveur Pulse où envoyer tes données, pas de publicité, aucune analytics.
          </p>
          <a
            href={PRIVACY_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="focus-ring mt-8 inline-block rounded-sm text-[15px] font-medium text-paper underline decoration-paper/30 decoration-2 underline-offset-[6px] transition-colors hover:decoration-paper"
          >
            Lire la politique de confidentialité ↗
          </a>
        </div>

        <ul className="privacy-route">
          {ROUTE.map((stop) => (
            <li key={stop.id} className="privacy-stop" data-none={stop.none ? "true" : undefined}>
              <p className="font-mono text-[11px] tracking-[0.18em] text-paper/60 uppercase">{stop.where}</p>
              <h3 className="mt-2 font-display text-[clamp(1.6rem,1.2rem+1.6vw,2.4rem)] leading-[1] font-black tracking-[-0.04em] text-balance">
                {stop.title}
              </h3>
              <p className="mt-2.5 max-w-[48ch] text-[16px] leading-relaxed text-paper/75">{stop.body}</p>
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}
