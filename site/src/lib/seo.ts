import { APP_STORE_ID, STUDIO_URL } from "./config";

export const PAGE_TITLE = "Pulse — Récupération & Muscu";

/** Texte promotionnel de la fiche App Store (docs/app-store/fiche.md §5). */
export const PAGE_DESCRIPTION =
  "Un score de récupération chaque matin, des séances de muscu guidées et tes compléments au même endroit. Tes données d'Apple Santé restent sur ton iPhone.";

export function softwareApplicationJsonLd(siteUrl: string): object {
  return {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    name: "Pulse",
    description: PAGE_DESCRIPTION,
    url: siteUrl,
    operatingSystem: "iOS",
    applicationCategory: "HealthApplication",
    inLanguage: "fr",
    offers: { "@type": "Offer", price: "0", priceCurrency: "EUR" },
    publisher: { "@type": "Organization", name: "Seonay Studio", url: STUDIO_URL },
  };
}

/** Bannière Smart App Banner de Safari : seulement une fois l'app disponible. */
export function appleItunesMeta(live: boolean): Record<string, string> {
  return live ? { "apple-itunes-app": `app-id=${APP_STORE_ID}` } : {};
}

/** JSON sérialisé pour un <script type="application/ld+json"> : `<` est échappé pour ne jamais fermer la balise. */
export function jsonLdScript(data: object): string {
  return JSON.stringify(data).replace(/</g, "\\u003c");
}
