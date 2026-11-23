import Link from "next/link";
import { CONTACT_EMAIL, PRIVACY_URL, STUDIO_URL, SUPPORT_URL } from "@/lib/config";

export const MEDICAL_DISCLAIMER =
  "Pulse n'est pas un dispositif médical. Le score et les ajustements sont des repères d'entraînement, pas un avis médical.";

const linkClass =
  "rounded-sm text-[15px] text-paper/80 underline decoration-transparent decoration-2 underline-offset-[6px] transition-colors hover:text-paper hover:decoration-paper/60 focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-signal";

const PRODUCT = [
  { href: "#score", label: "Le score" },
  { href: "#fonctionnalites", label: "Fonctionnalités" },
  { href: "#confidentialite", label: "Confidentialité" },
  { href: "#faq", label: "FAQ" },
];

function Column({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div>
      <h2 className="font-mono text-[11px] tracking-[0.18em] text-paper/60 uppercase">{title}</h2>
      <ul className="mt-4 grid gap-2.5">{children}</ul>
    </div>
  );
}

/**
 * Footer, outside <main>. It continues the ink of the final call: the studio
 * signature, three columns (the contact one only exists when CONTACT_EMAIL is
 * set, never a made-up address), the medical notice, and the name of the app
 * as an end title in halftone dots, cropped by the edge of the page.
 * `anchorBase="/"` makes the section links work from the other pages.
 */
export function Footer({ anchorBase = "" }: { anchorBase?: string } = {}) {
  return (
    <footer className="relative isolate overflow-clip border-t border-paper/15 bg-ink text-paper">
      <div className="relative mx-auto max-w-6xl px-4 pt-16 sm:px-6 sm:pt-20">
        <div className="grid gap-14 lg:grid-cols-[minmax(0,5fr)_minmax(0,7fr)] lg:gap-20">
          <div>
            <a
              href={STUDIO_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-block rounded-sm font-display text-[clamp(1.6rem,1.2rem+1.6vw,2.4rem)] leading-[1] font-black tracking-[-0.04em] text-balance underline decoration-paper/25 decoration-2 underline-offset-[8px] transition-colors hover:decoration-paper focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-signal"
            >
              Pulse par Seonay Studio ↗
            </a>
            <p className="mt-6 max-w-[46ch] text-[14px] leading-relaxed text-paper/70">{MEDICAL_DISCLAIMER}</p>
          </div>

          <nav
            aria-label="Pied de page"
            className={["grid gap-10 sm:gap-8", CONTACT_EMAIL ? "sm:grid-cols-3" : "sm:grid-cols-2"].join(" ")}
          >
            <Column title="Produit">
              {PRODUCT.map((link) => (
                <li key={link.href}>
                  <a href={`${anchorBase}${link.href}`} className={linkClass}>
                    {link.label}
                  </a>
                </li>
              ))}
            </Column>
            <Column title="Légal">
              <li>
                <Link href="/mentions-legales" className={linkClass}>
                  Mentions légales
                </Link>
              </li>
              <li>
                <a href={PRIVACY_URL} target="_blank" rel="noopener noreferrer" className={linkClass}>
                  Confidentialité
                </a>
              </li>
              <li>
                <a href={SUPPORT_URL} target="_blank" rel="noopener noreferrer" className={linkClass}>
                  Assistance
                </a>
              </li>
            </Column>
            {CONTACT_EMAIL ? (
              <Column title="Contact">
                <li>
                  <a href={`mailto:${CONTACT_EMAIL}`} className={linkClass}>
                    {CONTACT_EMAIL}
                  </a>
                </li>
              </Column>
            ) : null}
          </nav>
        </div>

        <p className="mt-14 text-[13px] text-paper/60">© 2026 Pulse par Seonay Studio</p>
      </div>

      <p aria-hidden="true" className="footer-wordmark">
        Pulse
      </p>
    </footer>
  );
}
