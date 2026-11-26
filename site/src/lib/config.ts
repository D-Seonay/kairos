export const APP_STORE_ID = "6829265826";
export const APP_STORE_URL = `https://apps.apple.com/fr/app/pulse-r%C3%A9cup%C3%A9ration-muscu/id${APP_STORE_ID}`;

// Apple a approuvé l'app le 2026-11-24 : le badge est un vrai lien vers la fiche.
export const APP_STORE_LIVE = true;

// À renseigner avant la mise en production : le build Vercel de production échoue tant que c'est null.
export const CONTACT_EMAIL: string | null = "contact@seonay.com";

// Les pages publiques (docs/) sont servies par GitHub Pages, sous le nom du dépôt : le renommer casse ces adresses.
export const PAGES_BASE_URL = "https://d-seonay.github.io/pulse";
export const PRIVACY_URL = `${PAGES_BASE_URL}/confidentialite/`;
export const SUPPORT_URL = `${PAGES_BASE_URL}/support/`;

// Les adresses stables, inscrites dans l'app et dans la fiche App Store : le site y redirige vers les pages ci-dessus
// (next.config.ts). Si le dépôt change encore de nom, seule PAGES_BASE_URL est à corriger.
export const PUBLIC_PAGE_REDIRECTS = [
  { source: "/confidentialite", destination: PRIVACY_URL },
  { source: "/support", destination: SUPPORT_URL },
] as const;
export const STUDIO_URL = "https://seonay.com";

// Mesure d'audience Umami Cloud : sans cookie, chargée seulement sur le site de production.
export const UMAMI_WEBSITE_ID = "f388ea38-0747-4e48-8082-887e7f149352";
export const UMAMI_SCRIPT_ORIGIN = "https://cloud.umami.is";
export const UMAMI_SCRIPT_URL = `${UMAMI_SCRIPT_ORIGIN}/script.js`;
/** Where the Umami script posts page views (read in its source: gateway.umami.is/api/send). */
export const UMAMI_COLLECT_ORIGIN = "https://gateway.umami.is";

type Env = Record<string, string | undefined>;

/** Previews, local builds and e2e runs load no analytics: only Vercel production counts visits. */
export function analyticsEnabled(env: Env): boolean {
  return env.VERCEL_ENV === "production";
}

export function resolveSiteUrl(env: Env): string {
  if (env.NEXT_PUBLIC_SITE_URL) {
    return env.NEXT_PUBLIC_SITE_URL.replace(/\/+$/, "");
  }
  if (env.VERCEL_PROJECT_PRODUCTION_URL) {
    return `https://${env.VERCEL_PROJECT_PRODUCTION_URL}`;
  }
  return "http://localhost:3000";
}

export function assertPublishable(env: Env, contactEmail: string | null): void {
  if (env.VERCEL_ENV === "production" && !contactEmail) {
    throw new Error(
      "CONTACT_EMAIL est vide dans src/lib/config.ts : renseigne-le avant de publier en production.",
    );
  }
}

export const SITE_URL = resolveSiteUrl(process.env);
