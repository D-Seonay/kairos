import type { NextConfig } from "next";
import { assertPublishable, CONTACT_EMAIL, PUBLIC_PAGE_REDIRECTS } from "./src/lib/config";

// Fait échouer le build de production Vercel tant que CONTACT_EMAIL est vide.
assertPublishable(process.env, CONTACT_EMAIL);

const nextConfig: NextConfig = {
  cacheComponents: true,
  images: {
    // AVIF first: the raw captures are big, and the hero loads three of them.
    formats: ["image/avif", "image/webp"],
  },
  partialPrefetching: true,
  // pulserecovery.app/confidentialite et /support : les adresses que l'app et la fiche App Store connaissent.
  async redirects() {
    return PUBLIC_PAGE_REDIRECTS.map((redirect) => ({ ...redirect, permanent: false }));
  },
  turbopack: {
    rules: {
      "*.css": {
        loaders: ["@tailwindcss/turbopack"],
        as: "*.css",
      },
    },
  },
};

export default nextConfig;
