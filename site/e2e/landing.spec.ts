import { expect, test, type Page } from "@playwright/test";
import { FEATURES } from "../src/components/sections/features-data";
import { FAQ } from "../src/components/sections/faq-data";

const ORIGIN = `http://localhost:${process.env.E2E_PORT ?? 3100}`;
const DISCLAIMER = "Pulse n'est pas un dispositif médical";

async function scrollToBottom(page: Page) {
  await page.evaluate(async () => {
    const step = Math.max(window.innerHeight / 2, 200);
    for (let y = 0; y < document.documentElement.scrollHeight; y += step) {
      window.scrollTo(0, y);
      await new Promise((resolve) => setTimeout(resolve, 60));
    }
    window.scrollTo(0, document.documentElement.scrollHeight);
  });
}

test.describe("privacy", () => {
  for (const path of ["/", "/mentions-legales"]) {
    test(`no third-party requests on ${path}`, async ({ page }) => {
      const urls: string[] = [];
      page.on("request", (request) => urls.push(request.url()));

      await page.goto(path);
      await page.waitForLoadState("networkidle");
      await scrollToBottom(page);
      await page.waitForLoadState("networkidle");

      expect(urls.length).toBeGreaterThan(0);
      const foreign = urls.filter(
        (url) => !url.startsWith(`${ORIGIN}/`) && !url.startsWith("data:") && !url.startsWith("blob:"),
      );
      expect(foreign).toEqual([]);
    });
  }

  test("sets no cookie", async ({ page, context }) => {
    await page.goto("/");
    await page.waitForLoadState("networkidle");
    expect(await context.cookies()).toEqual([]);
  });
});

test.describe("reduced motion", () => {
  test.use({ reducedMotion: "reduce" });

  test("hero is developed at first paint, with no wait and no scroll", async ({ page }) => {
    await page.goto("/");

    const h1 = page.getByRole("heading", { level: 1 });
    // The App Store badge: a link once the app is live, otherwise its "coming soon" caption.
    const badge = page.locator("#top").getByText(/Bientôt sur l'App Store/).or(
      page.locator("#top").getByRole("link", { name: /App Store/ }),
    ).first();
    const firstScreen = page.getByRole("img", { name: /Aujourd'hui de Pulse/ }).first();

    await expect(h1).toBeInViewport({ timeout: 500 });
    await expect(h1).toBeVisible({ timeout: 500 });
    await expect(page.getByText(/(Bientôt|Disponible) sur iPhone/)).toBeVisible({ timeout: 500 });
    await expect(badge).toBeVisible({ timeout: 500 });
    await expect(firstScreen).toBeVisible({ timeout: 500 });

    // The h1 and every ancestor that could hide it, or the words inside it.
    const opacities = await h1.evaluate((node) => {
      const chain: number[] = [];
      for (let el: Element | null = node; el; el = el.parentElement) {
        chain.push(Number(getComputedStyle(el).opacity));
      }
      for (const child of node.querySelectorAll("*")) chain.push(Number(getComputedStyle(child).opacity));
      return chain;
    });
    expect(opacities.length).toBeGreaterThan(1);
    expect(opacities.every((opacity) => opacity === 1)).toBe(true);
    expect(
      await h1.evaluate((node) => Number(getComputedStyle(node).opacity)),
    ).toBe(1);
  });

  test("the hero screen and the badge have no running animation", async ({ page }) => {
    await page.goto("/");
    const running = await page.evaluate(() =>
      document
        .getAnimations()
        .filter((animation) => animation.playState === "running" && animation.effect?.getTiming().iterations !== Infinity)
        .map((animation) => animation.id || (animation as CSSAnimation).animationName || "?"),
    );
    expect(running).toEqual([]);
  });
});

test.describe("no JavaScript", () => {
  test.use({ javaScriptEnabled: false });

  test("the served HTML carries the content", async ({ page }) => {
    await page.goto("/");

    await expect(page.getByRole("heading", { level: 1 })).toContainText("Ta nuit décide de ta séance.");
    for (const feature of FEATURES) {
      await expect(page.getByRole("heading", { name: feature.title })).toHaveCount(1);
    }
    for (const item of FAQ) {
      await expect(page.getByText(item.question, { exact: true })).toHaveCount(1);
    }
    await expect(page.getByText(DISCLAIMER).first()).toBeAttached();
    await expect(
      page.getByText(/Bientôt sur l'App Store/).or(page.getByRole("link", { name: /App Store/ })).first(),
    ).toBeAttached();
  });

  test("the raw HTML has the h1 and the FAQ answers", async ({ request }) => {
    const html = await (await request.get("/")).text();
    expect(html).toContain("Ta nuit décide");
    expect(html).toContain(DISCLAIMER);
    expect(html).toContain(FAQ[0].question.replace(/'/g, "&#x27;"));
  });
});

test.describe("360 px", () => {
  test.use({ viewport: { width: 360, height: 740 } });

  for (const path of ["/", "/mentions-legales"]) {
    test(`no horizontal scroll on ${path}`, async ({ page }) => {
      await page.goto(path);
      await page.waitForLoadState("networkidle");

      const width = () => page.evaluate(() => document.documentElement.scrollWidth);
      const height = await page.evaluate(() => document.documentElement.scrollHeight);

      for (const fraction of [0, 0.5, 1]) {
        await page.evaluate(
          ({ y }) => window.scrollTo(0, y),
          { y: Math.max(0, (height - 740) * fraction) },
        );
        await page.waitForTimeout(150);
        expect(await width(), `at ${fraction * 100}% of ${path}`).toBeLessThanOrEqual(360);
      }
    });
  }

  test("no horizontal scroll with reduced motion either", async ({ browser }) => {
    const context = await browser.newContext({ viewport: { width: 360, height: 740 }, reducedMotion: "reduce" });
    const page = await context.newPage();
    await page.goto("/");
    await page.waitForLoadState("networkidle");
    await scrollToBottom(page);
    expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(360);
    await context.close();
  });
});

test("structure: one h1, every image described or hidden", async ({ page }) => {
  await page.goto("/");
  await page.waitForLoadState("networkidle");
  await scrollToBottom(page);

  await expect(page.locator("h1")).toHaveCount(1);

  const bad = await page.evaluate(() =>
    [...document.querySelectorAll("img")]
      .filter((img) => {
        const alt = img.getAttribute("alt");
        const hidden = img.getAttribute("aria-hidden") === "true" || img.closest("[aria-hidden='true']") !== null;
        return !hidden && (alt === null || alt.trim() === "");
      })
      .map((img) => img.outerHTML.slice(0, 120)),
  );
  expect(bad).toEqual([]);
});

test("simulator: the Sommeil slider changes the score from the keyboard", async ({ page }) => {
  await page.goto("/");
  await page.locator("#score").scrollIntoViewIfNeeded();

  const score = page.getByTestId("score-value");
  const sleep = page.getByRole("slider", { name: "Sommeil" });
  await expect(sleep).toBeVisible();
  await expect(score).toHaveText(/^\d+$/);

  const read = async () => Number(await score.textContent());

  const initial = await read();

  await sleep.focus();
  await page.keyboard.press("Home");
  // The dial follows with spring inertia: poll until it has moved.
  await expect.poll(read, { timeout: 10_000 }).toBeLessThan(initial);
  await expect(sleep).toHaveValue("3");
  const low = await read();

  for (let i = 0; i < 20; i += 1) await page.keyboard.press("ArrowRight");
  await expect.poll(read, { timeout: 10_000 }).toBeGreaterThan(low);
});

test("performance: Chrome reports a largest contentful paint on the home page", async ({ page }) => {
  // An element first painted at opacity 0 never counts as an LCP candidate. If
  // the hero reveal starts from 0 again, Lighthouse has no LCP and scores 0.
  await page.addInitScript(() => {
    const w = window as unknown as { __lcp: number[] };
    w.__lcp = [];
    new PerformanceObserver((list) => {
      for (const entry of list.getEntries()) w.__lcp.push(entry.startTime);
    }).observe({ type: "largest-contentful-paint", buffered: true });
  });
  await page.goto("/");
  await page.waitForLoadState("networkidle");
  await expect
    .poll(() => page.evaluate(() => (window as unknown as { __lcp: number[] }).__lcp.length))
    .toBeGreaterThan(0);
  const lcp = await page.evaluate(() => (window as unknown as { __lcp: number[] }).__lcp.at(-1) ?? Infinity);
  expect(lcp).toBeLessThan(1500);
});
