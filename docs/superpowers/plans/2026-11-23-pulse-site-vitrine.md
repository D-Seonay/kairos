# Pulse — site vitrine : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. For every UI task (4 to 8), also load the `frontend-design:frontend-design` skill before writing markup or styles.

**Goal:** Une landing page Next.js + Tailwind pour Pulse dans `site/`, déployable sur Vercel, au style « Argentique » très travaillé et animé, avec un simulateur de score fidèle au moteur Swift.

**Architecture:** Next.js App Router entièrement statique dans `site/` (aucune route serveur). La logique pure (config, moteur de score, géométrie de la trame) vit dans `site/src/lib/` et est testée avec Vitest. Les sections sont des composants dans `site/src/components/sections/`, les primitives visuelles et d'animation dans `site/src/components/visual/` et `site/src/components/motion/`. Un test Playwright vérifie la page construite (pas de requête tierce, mouvement réduit, mobile 360 px).

**Tech Stack:** Next.js 16.4.6, React (version tirée par Next), TypeScript, Tailwind CSS 4.3.5 (`@tailwindcss/postcss`), Motion 14.14.0 (`motion/react`), Vitest 5.1.1 + Testing Library + jsdom, Playwright 1.65.1, npm. Node 23 en local.

**Spec:** `docs/superpowers/specs/2026-11-23-pulse-site-vitrine-design.md` (lire §4, §6.2, §6.2 bis, §6.4 en entier avant toute tâche UI).

## Global Constraints

- Tout le code du site est dans `site/`. Ne rien modifier dans `docs/` publié, `Pulse/`, `Packages/`, `PulseWidgets/`, `ci_scripts/`, `Pulse.xcodeproj/`.
- Branche `site-vitrine`, worktree `/Users/seonay/Repositories/kairos-site`. Commits en anglais au format `feat(site): …` / `test(site): …`, sans trailer Co-Authored-By.
- Français, tutoiement. Pas de tiret cadratin comme ponctuation de phrase.
- Aucune requête vers un domaine tiers au chargement : pas d'analytics (ni Vercel Analytics ni Speed Insights), pas de CDN, polices via `next/font/google` (auto-hébergées au build) ou `next/font/local`.
- Aucun cookie. Pas de bandeau cookies.
- Clair uniquement : `color-scheme: light`, pas de variante `dark:`.
- Couleurs (version claire de l'app) : papier `#EFECE5`, encre `#141414`, muted `#68655F`, filet `#CFC9BC`, signal `#FF4F2E` (accents seulement, jamais du texte courant).
- `prefers-reduced-motion: reduce` : aucune animation de défilement, de ressort ni de révélation ; contenu identique.
- App Store : id `6829265826`, lien `https://apps.apple.com/fr/app/id6829265826`.
- Liens légaux : `https://d-seonay.github.io/kairos/confidentialite/` et `https://d-seonay.github.io/kairos/support/`.
- Avertissement : « Pulse n'est pas un dispositif médical. Le score et les ajustements sont des repères d'entraînement, pas un avis médical. »
- Chaque phrase sur l'app doit être vraie pour la build publiée : texte de référence `docs/app-store/fiche.md` §5 et `docs/support/index.html`.

## Review Focus

1. Visiteur avec « Réduire les animations » : tout le texte, les captures et les boutons sont visibles immédiatement, le hero déjà « développé » (test e2e, Tâche 9).
2. JavaScript désactivé ou robot d'indexation : le `h1`, le texte des sections, la FAQ et le badge App Store sont dans le HTML servi (test e2e, Tâche 9).
3. iPhone SE / 360 px de large : aucun défilement horizontal, le téléphone épinglé et la planche contact ne débordent pas (test e2e, Tâche 9).
4. Curseurs du simulateur aux extrêmes : jamais de `NaN`, score borné à 0–100, catégorie calculée sur la valeur non arrondie comme dans l'app (`RecoveryCategory(score:)`), affichage arrondi comme `RecoveryGauge` (tests unitaires, Tâche 2 ; test composant, Tâche 5).
5. Onglet caché ou trame hors écran : la boucle d'animation du canvas s'arrête (test composant, Tâche 3).

---

### Task 1: Socle Next.js, configuration et ressources

**Files:**
- Create: `site/package.json`, `site/package-lock.json`, `site/next.config.ts`, `site/tsconfig.json`, `site/postcss.config.mjs`, `site/eslint.config.mjs`, `site/vitest.config.ts`, `site/vitest.setup.ts`, `site/.gitignore`, `site/vercel.json`, `site/README.md`
- Create: `site/src/app/layout.tsx`, `site/src/app/page.tsx` (vide pour l'instant : un `h1` provisoire), `site/src/app/globals.css`
- Create: `site/src/lib/config.ts`, `site/src/lib/config.test.ts`
- Create: `site/public/screens/{today,planning,workout,stats,profile}.jpg`, `site/public/marketing/{m01..m05}.jpg`, `site/public/icon/{light,dark,tinted}-1024.png`

**Interfaces:**
- Produces: `site/src/lib/config.ts`
  - `APP_STORE_ID = "6829265826"`, `APP_STORE_URL = "https://apps.apple.com/fr/app/id6829265826"`
  - `APP_STORE_LIVE: boolean` (démarre à `false` ; une ligne à changer à l'approbation)
  - `CONTACT_EMAIL: string | null` (démarre à `null`)
  - `PRIVACY_URL`, `SUPPORT_URL`, `STUDIO_URL = "https://seonay.com"`
  - `resolveSiteUrl(env: Record<string, string | undefined>): string`
  - `assertPublishable(env: Record<string, string | undefined>, contactEmail: string | null): void`
  - `SITE_URL = resolveSiteUrl(process.env)`
- Produces: les variables CSS / thème Tailwind `--color-paper`, `--color-ink`, `--color-muted`, `--color-rule`, `--color-signal`, et les polices `--font-sans`, `--font-mono`, `--font-display` dans `globals.css` (`@theme`).

- [ ] **Step 1: Créer le projet.** Dans le worktree : `npx create-next-app@16.4.6 site --ts --tailwind --eslint --app --src-dir --import-alias "@/*" --use-npm --skip-install` (garder les autres réglages par défaut), puis `cd site && npm install`, puis `npm install motion@14.14.0` et `npm install -D vitest@5.1.1 @vitejs/plugin-react jsdom @testing-library/react @testing-library/user-event @testing-library/jest-dom @playwright/test@1.65.1`. Vérifier que `tailwindcss` résolu est 4.3.5 (`npm ls tailwindcss`). Ajouter les scripts `"test": "vitest run"`, `"typecheck": "tsc --noEmit"`, `"e2e": "playwright test"`.

- [ ] **Step 2: Copier les ressources** (le dossier source est temporaire, c'est la première chose à sauver) :
  - `/private/tmp/claude-501/-Users-seonay-Repositories-fitness/952123ad-0b01-4414-97fe-9e8c006fb9d5/scratchpad/screens/01.jpg…05.jpg` → `site/public/screens/today.jpg`, `planning.jpg`, `workout.jpg`, `stats.jpg`, `profile.jpg` (01 Aujourd'hui, 02 Planning, 03 détail de séance Push, 04 Stats Biométrie, 05 Profil et records).
  - `…/scratchpad/final/m01.jpg…m05.jpg` → `site/public/marketing/`.
  - `Pulse/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`, `AppIcon-Dark-1024.png`, `AppIcon-Tinted-1024.png` → `site/public/icon/light-1024.png`, `dark-1024.png`, `tinted-1024.png`. Générer aussi `site/src/app/icon.png` (512) et `site/src/app/apple-icon.png` (180) avec `sips -Z`.

- [ ] **Step 3: Écrire `site/src/lib/config.test.ts`** :

```ts
import { describe, expect, it } from "vitest";
import { assertPublishable, resolveSiteUrl } from "./config";

describe("resolveSiteUrl", () => {
  it("prefers NEXT_PUBLIC_SITE_URL without trailing slash", () => {
    expect(resolveSiteUrl({ NEXT_PUBLIC_SITE_URL: "https://pulse.example/" })).toBe("https://pulse.example");
  });
  it("falls back on the Vercel production host", () => {
    expect(resolveSiteUrl({ VERCEL_PROJECT_PRODUCTION_URL: "pulse-seonay.vercel.app" })).toBe("https://pulse-seonay.vercel.app");
  });
  it("defaults to localhost", () => {
    expect(resolveSiteUrl({})).toBe("http://localhost:3000");
  });
});

describe("assertPublishable", () => {
  it("throws in Vercel production without a contact e-mail", () => {
    expect(() => assertPublishable({ VERCEL_ENV: "production" }, null)).toThrow(/CONTACT_EMAIL/);
  });
  it("accepts previews and local builds without e-mail", () => {
    expect(() => assertPublishable({ VERCEL_ENV: "preview" }, null)).not.toThrow();
    expect(() => assertPublishable({}, null)).not.toThrow();
  });
  it("accepts production with an e-mail", () => {
    expect(() => assertPublishable({ VERCEL_ENV: "production" }, "contact@example.com")).not.toThrow();
  });
});
```

- [ ] **Step 4: Lancer `npm test`**, attendu : FAIL (module `./config` introuvable).

- [ ] **Step 5: Implémenter `site/src/lib/config.ts`** selon l'Interfaces block. Appeler `assertPublishable(process.env, CONTACT_EMAIL)` dans `next.config.ts` pour que le build de production échoue sans e-mail.

- [ ] **Step 6: Thème et mise en page de base.**
  - `globals.css` : `@import "tailwindcss";`, un bloc `@theme` avec les couleurs des Global Constraints, `color-scheme: light`, fond papier sur `body`.
  - `layout.tsx` : `<html lang="fr">`, polices via `next/font` exposées en variables CSS (choix du constructeur : un sans-serif proche de SF pour le texte, un display très gras et serré pour les titres, une mono pour les eyebrows), `metadataBase: new URL(SITE_URL)`.
  - `vitest.config.ts` : environnement `jsdom`, alias `@`, fichier de setup qui importe `@testing-library/jest-dom/vitest`. Exclure `e2e/` de Vitest.

- [ ] **Step 7: Vercel et dépôt.**
  - `site/vercel.json` : `{ "ignoreCommand": "git diff --quiet HEAD^ HEAD -- ." }`.
  - `site/.gitignore` : `node_modules`, `.next`, `out`, `test-results`, `playwright-report`, `next-env.d.ts`.
  - `site/README.md` : 10 lignes maximum, en français. Il couvre les commandes, le dossier racine Vercel `site`, la constante `APP_STORE_LIVE` à basculer et `CONTACT_EMAIL` à remplir.

- [ ] **Step 8: Vérifier.**
  - `npm test` : PASS (6 tests).
  - `npm run lint`, `npm run typecheck` et `npm run build` : sans erreur. Le build se fait en local, sans `VERCEL_ENV`.

- [ ] **Step 9: Commit**

```bash
git add site
git commit -m "feat(site): Next.js and Tailwind scaffold with config, theme and app assets"
```

---

### Task 2: Moteur de score en TypeScript

**Files:**
- Create: `site/src/lib/score/engine.ts`, `site/src/lib/score/engine.test.ts`
- Create: `site/src/lib/score/session.ts`, `site/src/lib/score/session.test.ts`

**Interfaces:**
- Produces (`engine.ts`), copie fidèle de `Packages/PulseRecoveryEngine/Sources/PulseRecoveryEngine/Scoring/*.swift`, `Recovery/RecoveryCalculator.swift` et `Packages/PulseDomain/Sources/PulseDomain/Recovery/RecoveryCategory.swift` :
  - `hrvScore(z: number): number`
  - `rhrScore(todayBpm: number, baselineBpm: number): number`
  - `sleepScore(asleepMinutes: number, deepMinutes: number | null): number`
  - `type Category = "optimal" | "normal" | "moderateFatigue" | "overreached"`
  - `category(score: number): Category`
  - `CATEGORY_LABEL: Record<Category, string>` = Forme optimale, Forme normale, Fatigue modérée, Surmenage
  - `WEIGHTS = { hrv: 0.5, restingHeartRate: 0.25, sleep: 0.25 }`
  - `DEEP_SHARE = 0.15`, `HRV_LOG_SD = 0.12`
  - `hrvZFromPercent(percent: number): number` = `Math.log(1 + percent / 100) / HRV_LOG_SD`
  - `type SimulatorInput = { sleepHours: number; hrvPercent: number; rhrDeltaBpm: number }`
  - `type SimulatorResult = { score: number; displayScore: number; category: Category; factors: { hrv: number; restingHeartRate: number; sleep: number } }`
  - `simulate(input: SimulatorInput): SimulatorResult`. Le sommeil vaut `sleepScore(round(sleepHours*60), round(sleepHours*60*DEEP_SHARE))`, la FC repos vaut `rhrScore(50 + rhrDeltaBpm, 50)`. Le `score` est borné à 0–100, `displayScore = Math.round(score)`, et la catégorie est calculée sur `score` non arrondi.
  - Plages des curseurs exportées : `SLEEP_RANGE = { min: 3, max: 10, step: 0.25 }`, `HRV_RANGE = { min: -40, max: 30, step: 1 }`, `RHR_RANGE = { min: -5, max: 15, step: 1 }`
- Produces (`session.ts`), copie de `Adjustments/SessionAdjuster.swift` et `VolumeReducer.swift` (sans super sets) :
  - `type Exercise = { name: string; sets: number; reps: number; rpe: number; restSeconds: number }`
  - `SAMPLE_PUSH: Exercise[]` : Développé couché 4×8 RPE 8 repos 120 ; Développé militaire 3×10 RPE 8 repos 90 ; Écarté à la poulie 3×12 RPE 8,5 repos 60 ; Dips 3×10 RPE 8 repos 90
  - `type Adjusted = { exercises: Exercise[]; reasons: string[]; mobility: boolean }`
  - `adjustSession(day: Exercise[], category: Category): Adjusted`

- [ ] **Step 1: Écrire `engine.test.ts`** avec les cas exacts des tests Swift :
  - `hrvScore` : (2,100), (0.5,100), (0,90), (−0.5,80), (−1,65), (−1.5,50), (−2,37.5), (−3.5,10), (−10,10), à 1e-9 près.
  - `rhrScore(today, 50)` : 48→100, 50→100, 52→83, 57→40.5, 59→20, 62→0, 70→0.
  - `sleepScore` : (480,96)→100 ; (360,36)→67.5 ; (540,162)→100 ; (360,null)→75 ; (0,null)→0.
  - `category` : 100 et 90 → optimal ; 89.99 et 65 → normal ; 64.99 et 40 → moderateFatigue ; 39.99 et 0 → overreached.
  - `simulate` : pour `{ sleepHours: 8, hrvPercent: 0, rhrDeltaBpm: 0 }`, attendre `score` ≈ 0.5×90 + 0.25×100 + 0.25×(70 + 0.75×30) = 93.125 et `category` optimal. Aux extrêmes `{ 3, -40, 15 }` et `{ 10, 30, -5 }`, le score est fini et compris dans [0, 100]. Cas de bord d'arrondi : construire une entrée dont le score vaut entre 89.5 et 90 et attendre `displayScore` 90 avec `category` normal, comme dans l'app.

- [ ] **Step 2: Écrire `session.test.ts`** :
  - optimal : `SAMPLE_PUSH` inchangé, `reasons` vide.
  - normal : chaque `restSeconds` + 15, `reasons` = `["Repos rallongés de 15 secondes"]`.
  - moderateFatigue : séries 4,3,3,3 → 3,2,2,3 (13 → 10, cible `Math.round(13 × 0.2)` = 3). Les unités sont prises par séries décroissantes puis dans l'ordre, et on ne descend jamais sous 1 série. Le RPE est plafonné à 7,5 et chaque repos prend + 45. `reasons` = `["Volume réduit de 13 à 10 séries", "Effort plafonné à RPE 7,5", "Repos rallongés de 45 secondes"]`.
  - overreached : `mobility: true`, `reasons` = `["Séance remplacée par 20 min de mobilité ou du repos, au choix"]`.

- [ ] **Step 3: Lancer `npm test -- score`**, attendu : FAIL (modules introuvables).

- [ ] **Step 4: Implémenter `engine.ts` et `session.ts`.** En tête de chaque fichier, un commentaire d'une ligne qui renvoie au fichier Swift copié.

- [ ] **Step 5: Lancer `npm test -- score`**, attendu : PASS.

- [ ] **Step 6: Commit**

```bash
git add site/src/lib/score
git commit -m "feat(site): recovery score and session adjustment ported from the Swift engine"
```

---

### Task 3: Trame halftone vivante et primitives de mouvement

**Files:**
- Create: `site/src/lib/halftone.ts`, `site/src/lib/halftone.test.ts`
- Create: `site/src/components/motion/useReducedMotion.ts`, `site/src/components/motion/useInView.ts`
- Create: `site/src/components/visual/HalftoneField.tsx`, `site/src/components/visual/HalftoneField.test.tsx`
- Create: `site/src/components/visual/Grain.tsx`, `site/src/components/visual/RegistrationMarks.tsx`

**Interfaces:**
- Produces: `halftone.ts`
  - `dotRadius(params: { cell: number; light: number; pointerDistance: number | null; ink: number }): number`. Le rayon est compris entre 0 et `cell / 2`. Il décroît quand `light` (0–1) monte, grossit près du pointeur (influence nulle au-delà de `cell * 8`) et monte avec `ink` (0–1, progression du « révélateur »).
  - `gridFor(width: number, height: number, cell: number): { cols: number; rows: number }`
  - `cellForViewport(width: number): number`, qui donne 14 sous 640 px de large et 10 au-delà, pour avoir moins de points sur mobile.
- Produces: `useReducedMotion(): boolean`, qui vaut `false` au rendu serveur puis suit `matchMedia("(prefers-reduced-motion: reduce)")`.
- Produces: `useInView(ref: RefObject<Element | null>, rootMargin?: string): boolean`.
- Produces: `<HalftoneField light={number} ink={number} interactive?={boolean} className?={string} />`. C'est un `<canvas aria-hidden>` plein cadre. La boucle `requestAnimationFrame` tourne seulement si le champ est visible et que `document.visibilityState === "visible"`. Avec le mouvement réduit, le champ dessine une seule image statique.
- Produces: `<Grain />` (bruit SVG en `feTurbulence`, à très faible opacité, `pointer-events: none`) et `<RegistrationMarks />` (repères de coupe aux quatre coins d'une section).

- [ ] **Step 1: Écrire `halftone.test.ts`** :
  - `dotRadius` ne dépasse jamais `cell / 2` et ne descend jamais sous 0, sur une grille de `light`, `ink` et distance.
  - Il est plus grand pour `light` = 0 que pour `light` = 1.
  - Il est plus grand avec un pointeur à 0 px que sans pointeur.
  - Avec `ink` = 0, il vaut 0.
  - `gridFor(1000, 500, 10)` donne `{ cols: 101, rows: 51 }` (une cellule de débord).
  - `cellForViewport(375)` vaut 14 et `cellForViewport(1440)` vaut 10.

- [ ] **Step 2: Écrire `HalftoneField.test.tsx`** avec jsdom :
  - Bouchonner `getContext`, `requestAnimationFrame`, `cancelAnimationFrame`, `IntersectionObserver` et `matchMedia`.
  - Vérifier que `requestAnimationFrame` n'est plus rappelé après l'émission de `visibilitychange` avec `visibilityState = "hidden"`.
  - Vérifier qu'avec `matchMedia` qui répond au mouvement réduit, un seul dessin est fait et aucune boucle n'est lancée.

- [ ] **Step 3: Lancer `npm test -- halftone HalftoneField`**, attendu : FAIL.

- [ ] **Step 4: Implémenter.** Le canvas est dimensionné au `devicePixelRatio` plafonné à 2. Le pointeur est lu en `pointermove` passif. Il n'y a ni dépendance WebGL ni bibliothèque.

- [ ] **Step 5: Lancer les tests**, attendu : PASS. Puis faire un commit.

```bash
git add site/src/lib/halftone.ts site/src/lib/halftone.test.ts site/src/components/motion site/src/components/visual
git commit -m "feat(site): living halftone field, film grain and motion hooks"
```

---

### Task 4: Nav, hero « tirage qui se développe », cadre d'iPhone et badge App Store

**Files:**
- Create: `site/src/components/sections/Nav.tsx`, `site/src/components/sections/Hero.tsx`
- Create: `site/src/components/visual/PhoneFrame.tsx`, `site/src/components/visual/PulseTrace.tsx`
- Create: `site/src/components/AppStoreBadge.tsx`, `site/src/components/AppStoreBadge.test.tsx`, `site/public/badges/app-store-fr.svg`
- Modify: `site/src/app/page.tsx`

**Interfaces:**
- Consumes: `APP_STORE_URL`, `APP_STORE_LIVE` (Tâche 1) ; `HalftoneField`, `useReducedMotion`, `Grain` (Tâche 3).
- Produces: `<AppStoreBadge live?={boolean} />`. La valeur par défaut est `APP_STORE_LIVE`. Quand l'app est disponible, c'est un lien vers `APP_STORE_URL` avec le libellé « Télécharger Pulse dans l'App Store ». Sinon, ce n'est pas un lien : le badge est atténué et accompagné de « Bientôt sur l'App Store ».
- Produces: `<PhoneFrame src={string} alt={string} priority?={boolean} className?={string} />`, un cadre de titane sombre avec Dynamic Island, dessiné en CSS autour d'un `next/image` au format 1320 × 2868.
- Produces: `<PulseTrace progress={number} />`, le tracé de pouls de l'icône en SVG `pathLength`. Il se dessine de 0 à 1.

- [ ] **Step 1: Récupérer le badge officiel français** « Télécharger dans l'App Store » (noir) sur https://tools.applemarketingtools.com, l'enregistrer dans `site/public/badges/app-store-fr.svg` et noter sa source dans `site/README.md`. Respecter les règles d'Apple : 40 px de haut minimum à l'écran, marge libre d'un quart de sa hauteur, aucune modification.

- [ ] **Step 2: Écrire `AppStoreBadge.test.tsx`** :
  - Avec `live`, un lien existe avec le nom accessible « Télécharger Pulse dans l'App Store » et un `href` égal à `https://apps.apple.com/fr/app/id6829265826`.
  - Sans `live`, aucun rôle `link` n'est présent et le texte « Bientôt sur l'App Store » est visible.

- [ ] **Step 3: Lancer le test**, attendu : FAIL. Implémenter `AppStoreBadge`, relancer, attendu : PASS.

- [ ] **Step 4: Nav et Hero** (charger d'abord `frontend-design:frontend-design`).
  - **Nav** : fixe, sur fond papier translucide flouté au défilement. On y trouve le logo (icône `light-1024.png` et « Pulse »), les ancres `#score`, `#fonctionnalites`, `#confidentialite` et `#faq`, et le badge. Sous 768 px, un menu compact accessible au clavier, avec `aria-expanded`.
  - **Hero** : une séquence « tirage » inspirée de la spec §6.2 bis.
    1. Le fond démarre encre et `PulseTrace` se dessine en 0,6 s.
    2. `HalftoneField` voit son `ink` passer de 0 à 1 et son `light` de 0 à 0,8 en environ 1,4 s. Le fond vire au papier.
    3. Le titre, la phrase et les trois puces émergent avec un flou et un contraste qui se règlent.
    4. Deux ou trois `PhoneFrame` (today, stats, planning) arrivent en léger éventail.

    Avec le mouvement réduit, l'état final s'affiche directement. Le HTML servi contient toujours le texte final, et l'animation ne joue que sur l'opacité, le filtre et la transformation via des classes posées après l'hydratation. Il y a un seul `h1`, le titre. Les puces sont : Gratuit, Sans compte, Tes données Santé restent sur ton iPhone.

- [ ] **Step 5: Assembler dans `page.tsx`**, puis lancer `npm run build` (attendu : succès) et `npm test` (attendu : PASS).

- [ ] **Step 6: Commit**

```bash
git add site
git commit -m "feat(site): nav, developing-print hero, phone frame and App Store badge"
```

---

### Task 5: Le simulateur de score

**Files:**
- Create: `site/src/components/sections/ScoreSimulator.tsx`, `site/src/components/sections/ScoreSimulator.test.tsx`
- Create: `site/src/components/visual/ScoreDial.tsx`

**Interfaces:**
- Consumes: `simulate`, `CATEGORY_LABEL`, `SLEEP_RANGE`, `HRV_RANGE`, `RHR_RANGE`, `adjustSession`, `SAMPLE_PUSH` (Tâche 2) ; `HalftoneField`, `useReducedMotion` (Tâche 3).
- Produces: `<ScoreSimulator />`, rendu dans la section `id="score"`. L'état initial est `{ sleepHours: 7.5, hrvPercent: -5, rhrDeltaBpm: 2 }`.
- Produces: `<ScoreDial value={number} category={Category} />`. Le cadran à graduations reprend `RecoveryGauge` de l'app : chiffre fin et « sur 100 ».

- [ ] **Step 1: Écrire `ScoreSimulator.test.tsx`** :
  - Il y a trois `slider` nommés « Sommeil », « Variabilité cardiaque » et « Fréquence cardiaque au repos ».
  - L'`aria-valuetext` parle en mots : « 7 h 30 », « 5 % sous ta normale », « 2 battements au-dessus de ta normale ».
  - Le texte affiché du score est égal à `simulate(initial).displayScore`.
  - Mettre les trois curseurs à `{ 4, -40, 15 }` (avec `fireEvent.change`) fait afficher « Surmenage » et « Séance remplacée par 20 min de mobilité ou du repos, au choix ».
  - Les mettre à `{ 8, 0, 0 }` fait afficher « Forme optimale ».
  - La zone de résultat a `aria-live="polite"`.
  - La mention « Simulation avec les mêmes formules que l'app. Dans Pulse, tes valeurs sont comparées à ta propre ligne de base. » est présente, ainsi que « Sommeil profond fixé à 15 % ».

- [ ] **Step 2: Lancer le test**, attendu : FAIL.

- [ ] **Step 3: Implémenter** en suivant la spec §6.4 et §6.2 bis.
  - Ce sont des `input type="range"` natifs, restylés.
  - L'aiguille et le chiffre suivent la valeur avec un ressort `motion/react` (`useSpring`) ; avec le mouvement réduit, la valeur est appliquée directement.
  - Les points de la jauge s'allument un à un.
  - Le `light` du `HalftoneField` de la section vaut `score / 100`.
  - La séance d'exemple affiche ses exercices : les séries retirées disparaissent avec `AnimatePresence`, et les repos et le RPE changent avec un compteur.

- [ ] **Step 4: Lancer `npm test`**, attendu : PASS. Puis faire un commit.

```bash
git add site/src/components
git commit -m "feat(site): interactive recovery score simulator with dial and adjusted session"
```

---

### Task 6: Fonctionnalités, téléphone épinglé et planche contact

**Files:**
- Create: `site/src/components/sections/Features.tsx`, `site/src/components/sections/features-data.ts`, `site/src/components/sections/features-data.test.ts`
- Create: `site/src/components/visual/ContactSheet.tsx`, `site/src/components/visual/ScreenSwap.tsx`

**Interfaces:**
- Consumes: `PhoneFrame` (Tâche 4), `useReducedMotion`, `useInView`, `RegistrationMarks` (Tâche 3).
- Produces: `FEATURES: { id: string; index: string; eyebrow: string; title: string; body: string; screen: string | null }[]`, six entrées dans l'ordre de la spec §6.3 point 4 :
  - `01 score` → `/screens/today.jpg`
  - `02 seance` → `/screens/workout.jpg`
  - `03 programme` → `/marketing/m03.jpg` ou un visuel dessiné (choix du constructeur après avoir regardé m01–m05)
  - `04 stats` → `/screens/stats.jpg`
  - `05 complements` → `null`, avec un visuel dessiné : pilulier en trame, coche « Pris »
  - `06 widgets` → `null`, avec des widgets et une Live Activity dessinés en HTML et CSS
- Les textes `body` sont tirés de la fiche App Store §5, reformulés court.

- [ ] **Step 1: Écrire `features-data.test.ts`** :
  - Il y a 6 entrées, les `index` vont de « 01 » à « 06 » et les `id` sont uniques.
  - Chaque `screen` non nul existe dans `site/public` (avec `fs.existsSync`).
  - Aucun `body` ne contient « — » ni le mot « dose » sans « jamais » dans la même phrase. Pulse ne conseille jamais de dose.

- [ ] **Step 2: Lancer le test**, attendu : FAIL. Écrire `features-data.ts`, relancer, attendu : PASS.

- [ ] **Step 3: Sections.**
  - **Sur grand écran** : `Features` en deux colonnes. Un `PhoneFrame` épinglé en `position: sticky` à gauche, six blocs qui défilent à droite. Le bloc actif est détecté avec `useInView`, et `ScreenSwap` change l'écran avec une dissolution en trame : un masque de points qui s'ouvre et se referme en `mask-image` animé.
  - **Sous 1024 px** : pas d'épinglage. Chaque bloc a sa propre capture.
  - **`ContactSheet`** : une bande de pellicule 35 mm avec les cinq captures. On y trouve les perforations, les numéros « 1A → 5A », la mention « PULSE 400 » sur le bord et une vue entourée au trait signal. Elle défile horizontalement en interne (`overflow-x: auto`, sans débordement de page), au clavier comme au doigt.
  - **Avec le mouvement réduit** : pas d'épinglage animé ni de dissolution.

- [ ] **Step 4: Lancer `npm run build` et `npm test`**, attendu : succès. Puis faire un commit.

```bash
git add site
git commit -m "feat(site): features with pinned phone, halftone screen swap and contact sheet"
```

---

### Task 7: Données, chiffres, FAQ, appel final et pied de page

**Files:**
- Create: `site/src/components/sections/Privacy.tsx`, `site/src/components/sections/Numbers.tsx`, `site/src/components/sections/Faq.tsx`, `site/src/components/sections/faq-data.ts`, `site/src/components/sections/FinalCta.tsx`, `site/src/components/sections/Footer.tsx`
- Create: `site/src/components/sections/numbers-data.ts`, `site/src/components/sections/numbers-data.test.ts`

**Interfaces:**
- Consumes: `PRIVACY_URL`, `SUPPORT_URL`, `STUDIO_URL`, `CONTACT_EMAIL` (Tâche 1) ; `AppStoreBadge` (Tâche 4).
- Produces: `NUMBERS: { value: string; label: string; source: string }[]`. `source` est un chemin de fichier du dépôt qui prouve le chiffre.
- Produces: `FAQ: { id: string; question: string; answer: string }[]`, avec 6 ou 7 entrées couvrant : pas de score, montre autre qu'Apple Watch, durée de calibration, Android, prix, dispositif médical, où vont mes données. Les réponses sont reprises de `docs/support/index.html` et de la fiche.

- [ ] **Step 1: Écrire `numbers-data.test.ts`**. Chaque `source` existe dans le dépôt (chemin relatif à la racine du worktree). Deux contrôles sont faits sur le contenu :
  - si une entrée annonce un nombre d'exercices, il est égal au nombre d'exercices de `Packages/PulseContent/Sources/PulseContent/Resources/exercises.json`, compté par le test ;
  - « 14 » nuits de ligne de base correspond à `hrvWindowDays = 14` dans `RecoveryCalculator.swift`.

- [ ] **Step 2: Lancer le test**, attendu : FAIL. Écrire `numbers-data.ts`, relancer, attendu : PASS.

- [ ] **Step 3: Sections.**
  - **`Privacy`** (`id="confidentialite"`) : le texte de la spec §6.3 point 5, avec un lien vers `PRIVACY_URL`.
  - **`Numbers`** : les chiffres défilent comme un compteur de pellicule à l'entrée dans l'écran. Avec le mouvement réduit, ils s'affichent fixes.
  - **`Faq`** (`id="faq"`) : des `<details>`/`<summary>` natifs, ouverts par défaut si JavaScript est absent, avec un lien « Toute l'assistance » vers `SUPPORT_URL`.
  - **`FinalCta`** : grande icône et badge.
  - **`Footer`** :
    - « Pulse par Seonay Studio ↗ » vers `STUDIO_URL` ;
    - les colonnes Produit (ancres), Légal (Mentions légales `/mentions-legales`, Confidentialité, Assistance) et Contact (`mailto:` si `CONTACT_EMAIL`, sinon rien) ;
    - l'avertissement médical exact des Global Constraints ;
    - « © 2026 Pulse par Seonay Studio ».

- [ ] **Step 4: Lancer `npm run build` et `npm test`**, attendu : succès. Puis faire un commit.

```bash
git add site
git commit -m "feat(site): privacy, film-counter numbers, FAQ, final call and footer"
```

---

### Task 8: Mentions légales, 404 et référencement

**Files:**
- Create: `site/src/app/mentions-legales/page.tsx`, `site/src/app/not-found.tsx`
- Create: `site/src/app/opengraph-image.tsx`, `site/src/app/sitemap.ts`, `site/src/app/robots.ts`
- Create: `site/src/lib/seo.ts`, `site/src/lib/seo.test.ts`
- Modify: `site/src/app/layout.tsx`, `site/src/app/page.tsx`

**Interfaces:**
- Consumes: `SITE_URL`, `APP_STORE_ID`, `APP_STORE_LIVE`, `CONTACT_EMAIL` (Tâche 1).
- Produces: `softwareApplicationJsonLd(siteUrl: string): object`. Le type est `SoftwareApplication`, avec `operatingSystem: "iOS"`, `applicationCategory: "HealthApplication"`, `offers: { price: "0", priceCurrency: "EUR" }`, `inLanguage: "fr"` et `publisher: { "@type": "Organization", name: "Seonay Studio", url: "https://seonay.com" }`.
- Produces: `appleItunesMeta(live: boolean): Record<string, string>`. Il renvoie `{ "apple-itunes-app": "app-id=6829265826" }` si `live`, sinon `{}`.

- [ ] **Step 1: Écrire `seo.test.ts`** :
  - Les champs du JSON-LD sont exactement ceux ci-dessus, et son `url` vaut `siteUrl`.
  - `appleItunesMeta(true)` renvoie la balise et `appleItunesMeta(false)` renvoie `{}`.

- [ ] **Step 2: Lancer le test**, attendu : FAIL. Implémenter `seo.ts`, relancer, attendu : PASS.

- [ ] **Step 3: Pages et métadonnées.**
  - **Métadonnées de `layout.tsx`** :
    - titre « Pulse — Récupération & Muscu » ;
    - description reprise du texte promotionnel de la fiche ;
    - `alternates.canonical` en `/` ;
    - `other: appleItunesMeta(APP_STORE_LIVE)`.
  - **JSON-LD** injecté dans `page.tsx`.
  - **`opengraph-image.tsx`** (`next/og`, 1200 × 630) : papier, trame, icône, titre du hero.
  - **`sitemap.ts`** : `/` et `/mentions-legales`. **`robots.ts`** : tout est autorisé, avec le sitemap.
  - **`mentions-legales`** : contenu exact de la spec §6.7, rubriques 1 à 5. Le contact affiche `CONTACT_EMAIL` ; tant qu'il est `null`, il affiche « adresse à venir », et seul le build de production est bloqué (Tâche 1).
  - **`not-found.tsx`** : dans le style, avec un lien vers l'accueil.

- [ ] **Step 4: Lancer `npm run build` et `npm test`**, attendu : succès. Puis faire un commit.

```bash
git add site
git commit -m "feat(site): legal notice, 404, Open Graph image, sitemap and structured data"
```

---

### Task 9: Vérification de bout en bout et livraison

**Files:**
- Create: `site/playwright.config.ts`, `site/e2e/landing.spec.ts`

**Interfaces:**
- Consumes: la page construite (`npm run build && npm run start`, lancée par le `webServer` de Playwright sur le port 3100).

- [ ] **Step 1: Écrire `e2e/landing.spec.ts`**, sur Chromium uniquement (`npx playwright install chromium`) :
  - **no third-party requests** : enregistrer chaque requête de `/` et `/mentions-legales` jusqu'à `networkidle`, puis faire défiler jusqu'en bas. Toutes les URLs ont l'origine `http://localhost:3100`, à l'exception des liens jamais suivis.
  - **reduced motion** : avec `reducedMotion: "reduce"`, le `h1`, le badge et la première capture sont visibles sans attente ni défilement, et le `h1` a une opacité calculée de 1.
  - **no JavaScript** : avec `javaScriptEnabled: false`, le `h1`, les six titres de fonctionnalités, les questions de la FAQ et le texte « Pulse n'est pas un dispositif médical » sont présents.
  - **360 px** : à `{ width: 360, height: 740 }`, `document.documentElement.scrollWidth <= 360` en haut, au milieu et en bas de page.
  - **structure** : un seul `h1`, et chaque `img` a un `alt` non vide ou est `aria-hidden`.
  - **simulator** : dans un vrai navigateur, régler le curseur Sommeil au clavier (flèches) change le score affiché.

- [ ] **Step 2: Lancer `npm run e2e`**, attendu : tous PASS. Corriger dans la tâche fautive si besoin.

- [ ] **Step 3: Regarder la page.** Capturer des images pleine page à 390 × 844 et à 1440 × 900, avec et sans mouvement réduit, et à mi-animation du hero. Les enregistrer dans le scratchpad de la session (pas dans le dépôt) et les regarder vraiment. Vérifier :
  - la hiérarchie ;
  - le contraste ;
  - la trame qui ne gêne pas la lecture ;
  - l'absence de chevauchement ;
  - l'absence de défaut visible de la planche contact et du téléphone épinglé.

  Corriger, puis faire un commit des corrections.

- [ ] **Step 4: Lighthouse.** Serveur de production local lancé, `npx lighthouse http://localhost:3100 --form-factor=mobile --screenEmulation.mobile --quiet --output=json --output-path=<scratchpad>/lh.json`. Attendu : performance ≥ 90, accessibilité, bonnes pratiques et SEO à 100 (spec §6.8). Sinon corriger et commiter.

- [ ] **Step 5: Vérification finale.**
  - Lancer `npm run lint`, `npm run typecheck`, `npm test`, `npm run build` et `npm run e2e` : tout est vert, sortie lue.
  - `git status` ne montre rien hors de `site/` et `docs/superpowers/`.

- [ ] **Step 6: Commit et livraison.**

```bash
git add site
git commit -m "test(site): end-to-end checks for privacy, reduced motion, no-JS and small screens"
git push -u origin site-vitrine:site-vitrine
```

Ouvrir la PR vers `master` (`gh pr create`) avec un résumé, les captures et la liste de ce qui reste à Mathéo. Ce qui reste à Mathéo :
- l'e-mail de contact ;
- l'accord pour créer le projet Vercel (équipe « Seonay », dossier racine `site`) ;
- `APP_STORE_LIVE` à passer à `true` à l'approbation.

Terminer la description par la ligne d'attribution demandée. Relier la PR au fil.
