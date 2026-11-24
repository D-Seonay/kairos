import { FAQ } from "@/components/sections/faq-data";
import { APP_STORE_ID, APP_STORE_URL, STUDIO_URL } from "./config";

/** The App Store name of the app (docs/app-store/fiche.md §5). */
export const APP_NAME = "Pulse — Récupération & Muscu";

/**
 * The page title: what people type into a search engine (score de
 * récupération, musculation, iPhone), under 60 characters so it is not cut.
 */
export const PAGE_TITLE = "Pulse : score de récupération et musculation sur iPhone";

/**
 * The meta description: every claim is true for the published build (free,
 * no subscription and no account, the three readings behind the score, the
 * GPS run of version 1.0.3). Under 160 characters.
 */
export const PAGE_DESCRIPTION =
  "App iPhone gratuite : un score de récupération chaque matin (sommeil, VFC, FC au repos), des séances de muscu ajustées et la course GPS. Sans abonnement.";

/** What the app does, one line each, for the structured data. Each line is on the page too. */
const FEATURE_LIST = [
  "Score de récupération chaque matin, à partir du sommeil, de la variabilité cardiaque (VFC) et de la fréquence cardiaque au repos lus dans Apple Santé",
  "Check-in de trois questions sans montre",
  "Écran Nuit avec les phases de sommeil",
  "Programme et séances de musculation ajustés à la récupération",
  "Course GPS avec annonces vocales et tracé",
  "Photos de séance et photos de corps privées",
  "Suivi des compléments, sans conseil de dose",
  "Widgets et Live Activity",
  "Sans compte, sans serveur, sans publicité",
];

/**
 * The structured data of the home page, as one schema.org graph: the
 * publisher, the site and the app, then the FAQ that the page shows. Only
 * what is visible on the page and true: no rating, since the site shows no
 * reviews.
 */
export function homeJsonLd(siteUrl: string): object {
  const publisher = { "@type": "Organization", "@id": `${STUDIO_URL}/#organization`, name: "Seonay Studio", url: STUDIO_URL };
  return {
    "@context": "https://schema.org",
    "@graph": [
      publisher,
      {
        "@type": "WebSite",
        "@id": `${siteUrl}/#website`,
        url: siteUrl,
        name: "Pulse",
        alternateName: [APP_NAME, "Pulse Récupération"],
        inLanguage: "fr",
        publisher: { "@id": publisher["@id"] },
      },
      {
        "@type": "MobileApplication",
        "@id": `${siteUrl}/#app`,
        name: APP_NAME,
        alternateName: "Pulse",
        description: PAGE_DESCRIPTION,
        url: siteUrl,
        installUrl: APP_STORE_URL,
        sameAs: [APP_STORE_URL],
        identifier: APP_STORE_ID,
        operatingSystem: "iOS 26",
        applicationCategory: "HealthApplication",
        applicationSubCategory: "Fitness",
        inLanguage: "fr",
        isAccessibleForFree: true,
        offers: { "@type": "Offer", price: "0", priceCurrency: "EUR" },
        featureList: FEATURE_LIST,
        image: `${siteUrl}/icon/light-1024.png`,
        screenshot: ["today", "workout", "planning", "stats", "profile"].map((name) => `${siteUrl}/screens/${name}.jpg`),
        publisher: { "@id": publisher["@id"] },
      },
      {
        "@type": "FAQPage",
        "@id": `${siteUrl}/#faq`,
        inLanguage: "fr",
        mainEntity: FAQ.map((entry) => ({
          "@type": "Question",
          name: entry.question,
          acceptedAnswer: { "@type": "Answer", text: entry.answer },
        })),
      },
    ],
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
