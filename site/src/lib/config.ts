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

type Env = Record<string, string | undefined>;

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
