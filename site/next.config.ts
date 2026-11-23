import type { NextConfig } from "next";
import { assertPublishable, CONTACT_EMAIL } from "./src/lib/config";

// Fait échouer le build de production Vercel tant que CONTACT_EMAIL est vide.
assertPublishable(process.env, CONTACT_EMAIL);

const nextConfig: NextConfig = {
  cacheComponents: true,
  partialPrefetching: true,
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
