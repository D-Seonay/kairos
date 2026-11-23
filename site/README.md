# Site vitrine de Pulse

Next.js 16 et Tailwind 4, dans `site/`. Aucun traceur, aucun cookie.

- `npm run dev` : serveur local. `npm run build` : build de production.
- `npm test` (Vitest), `npm run typecheck`, `npm run lint`, `npm run e2e` (Playwright).
- Vercel : dossier racine `site`. `vercel.json` saute le build si rien n'a changé ici.
- `APP_STORE_LIVE` dans `src/lib/config.ts` : passe à `true` quand Apple approuve l'app.
- `CONTACT_EMAIL` dans `src/lib/config.ts` : à renseigner, sinon le build de production échoue.
- `NEXT_PUBLIC_SITE_URL` (facultatif) fixe l'URL canonique du site.
