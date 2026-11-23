import type { Metadata } from "next";
import Link from "next/link";
import type { ReactNode } from "react";
import { Footer } from "@/components/sections/Footer";
import { Nav } from "@/components/sections/Nav";
import { Grain } from "@/components/visual/Grain";
import { CONTACT_EMAIL, PRIVACY_URL, STUDIO_URL } from "@/lib/config";

export const metadata: Metadata = {
  title: "Mentions légales",
  description: "Mentions légales du site et de l'application Pulse, édités par Seonay Studio.",
  alternates: { canonical: "/mentions-legales" },
};

const link =
  "focus-ring rounded-sm underline decoration-rule decoration-2 underline-offset-[5px] transition-colors hover:decoration-ink";

function ExternalLink({ href, children }: { href: string; children: ReactNode }) {
  return (
    <a href={href} target="_blank" rel="noopener noreferrer" className={link}>
      {children}
    </a>
  );
}

/** The address of the publisher, or an honest placeholder until CONTACT_EMAIL is set. */
function Email() {
  return CONTACT_EMAIL ? (
    <a href={`mailto:${CONTACT_EMAIL}`} className={link}>
      {CONTACT_EMAIL}
    </a>
  ) : (
    <span className="text-muted">adresse à venir</span>
  );
}

function Rubrique({ id, number, title, children }: { id: string; number: number; title: string; children: ReactNode }) {
  return (
    <section
      aria-labelledby={id}
      className="grid gap-5 border-t border-rule py-10 lg:grid-cols-[minmax(0,4fr)_minmax(0,8fr)] lg:gap-12 lg:py-12"
    >
      <h2
        id={id}
        className="font-display text-[1.6rem] leading-[1.05] font-black tracking-[-0.035em] text-balance sm:text-[1.9rem]"
      >
        <span aria-hidden="true" className="mr-3 font-mono text-[13px] font-medium tracking-normal text-muted">
          {number}
        </span>
        {title}
      </h2>
      <div className="max-w-[62ch] space-y-4 text-[16px] leading-[1.75] text-ink/90">{children}</div>
    </section>
  );
}

function Fact({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="grid gap-0.5 border-b border-rule/70 py-3 first:pt-0 last:border-b-0 sm:grid-cols-[13rem_1fr] sm:gap-6">
      <dt className="text-[14px] text-muted">{label}</dt>
      <dd>{children}</dd>
    </div>
  );
}

export default function MentionsLegales() {
  return (
    <>
      <Nav anchorBase="/" />
      <main id="contenu" className="relative isolate flex-1 overflow-clip">
        <Grain />
        <div className="relative mx-auto max-w-6xl px-4 pt-32 pb-20 sm:px-6 sm:pt-40 sm:pb-28">
          <header className="mb-12 sm:mb-16">
            <h1 className="font-display text-[clamp(2.75rem,0.5rem+7vw,6rem)] leading-[0.88] font-black tracking-[-0.05em] text-balance">
              Mentions légales
            </h1>
            <p className="mt-5 max-w-[52ch] text-[17px] leading-relaxed text-muted sm:text-lg">
              Ce qu&apos;il faut savoir sur qui édite ce site et l&apos;application Pulse, et où ils sont hébergés.
            </p>
            <div aria-hidden="true" className="legal-dots mt-10 h-3 sm:mt-12" />
          </header>

          <Rubrique id="editeur" number={1} title="Éditeur du site et de l'application">
            <dl>
              <Fact label="Éditeur">
                <ExternalLink href={STUDIO_URL}>Seonay Studio</ExternalLink> (seonay.com)
              </Fact>
              <Fact label="Nom commercial du service">Pulse</Fact>
              <Fact label="Siège social">France</Fact>
              <Fact label="Courrier électronique">
                <Email />
              </Fact>
              <Fact label="Directeur de la publication">Le représentant légal de Seonay Studio</Fact>
            </dl>
          </Rubrique>

          <Rubrique id="hebergement" number={2} title="Hébergement">
            <p>
              Le site est hébergé par Vercel Inc., 340 S Lemon Ave #4133, Walnut, CA 91789, États-Unis (
              <ExternalLink href="https://vercel.com">vercel.com</ExternalLink>).
            </p>
            <p>
              Les pages Confidentialité et Assistance sont servies par GitHub Pages (GitHub, Inc., 88 Colin P Kelly Jr
              St, San Francisco, CA 94107, États-Unis).
            </p>
            <p>L&apos;application Pulse n&apos;a aucun serveur : elle ne dépend d&apos;aucun hébergeur pour fonctionner.</p>
          </Rubrique>

          <Rubrique id="propriete" number={3} title="Propriété intellectuelle">
            <p>
              Le nom Pulse, le logo, les textes, les captures d&apos;écran et les visuels de ce site et de l&apos;application sont la
              propriété de Seonay Studio. Toute reproduction sans autorisation écrite est interdite.
            </p>
            <p>
              La carte musculaire de l&apos;application utilise MuscleMap, distribué sous licence MIT. Apple, iPhone, Apple
              Santé et App Store sont des marques d&apos;Apple Inc.
            </p>
          </Rubrique>

          <Rubrique id="donnees" number={4} title="Données personnelles et cookies">
            <p>
              Ce site ne dépose aucun cookie et ne mesure pas son audience : aucun outil d&apos;analyse, aucune publicité,
              aucun suivi.
            </p>
            <p>
              Comme tout hébergeur, Vercel peut conserver des journaux techniques de connexion, nécessaires au
              fonctionnement du serveur. Ce que l&apos;application fait des données de santé est décrit dans la{" "}
              <ExternalLink href={PRIVACY_URL}>politique de confidentialité de Pulse</ExternalLink>.
            </p>
          </Rubrique>

          <Rubrique id="contact" number={5} title="Contact">
            <p>
              Pour toute question sur le site, l&apos;application ou ces mentions : <Email />.
            </p>
          </Rubrique>

          <div className="border-t border-rule pt-8">
            <Link href="/" className={`${link} text-[15px] font-medium`}>
              Retour à l&apos;accueil
            </Link>
          </div>
        </div>
      </main>
      <Footer anchorBase="/" />
    </>
  );
}
