# Site vitrine de Pulse

Next.js 16 et Tailwind 4, dans `site/`. Aucun traceur, aucun cookie.

- `npm run dev` : serveur local. `npm run build` : build de production.
- `npm test` (Vitest), `npm run typecheck`, `npm run lint`, `npm run e2e` (Playwright).
- Vercel : dossier racine `site`. `vercel.json` saute le build si rien n'a changé ici.
- `APP_STORE_LIVE` dans `src/lib/config.ts` : à `true` depuis l'approbation d'Apple (2026-11-24).
- `CONTACT_EMAIL` dans `src/lib/config.ts` : à renseigner, sinon le build de production échoue.
- `NEXT_PUBLIC_SITE_URL` (facultatif) fixe l'URL canonique du site. Sans elle, l'URL vient de `VERCEL_PROJECT_PRODUCTION_URL`. Elle est figée au build (canonical, sitemap, robots, JSON-LD, og:image) : après avoir rattaché un domaine personnalisé, redéploie. Sur une préversion Vercel, l'og:image pointe vers l'hôte de production, pas vers la préversion.
- Badge App Store : `public/badges/app-store-fr.svg` est le badge officiel noir « Télécharger dans l'App Store » (fr-FR, `Download_on_the_App_Store_Badge_FR_RGB_blk_100517`), téléchargé tel quel le 23 novembre 2026 depuis les outils marketing d'Apple (https://toolbox.marketingtools.apple.com/app-store/, API `https://toolbox.marketingtools.apple.com/api/v2/badges/download-on-the-app-store/black/fr-fr`). Ne pas le modifier ; 40 px de haut minimum à l'écran, marge libre d'un quart de sa hauteur.
