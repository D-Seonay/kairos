import { describe, expect, it } from "vitest";
import fs from "node:fs";
import path from "node:path";
import { FAQ } from "@/components/sections/faq-data";
import { appleItunesMeta, homeJsonLd, jsonLdScript, PAGE_DESCRIPTION, PAGE_TITLE } from "./seo";

const PUBLIC = path.resolve(import.meta.dirname, "../../public");

describe("homeJsonLd", () => {
  const graph = (homeJsonLd("https://pulse.example") as { "@graph": Record<string, unknown>[] })["@graph"];
  const byType = (type: string) => graph.find((node) => node["@type"] === type)!;

  it("describes a free iOS health application in French, with its App Store page", () => {
    const app = byType("MobileApplication");
    expect(app.name).toBe("Pulse — Récupération & Muscu");
    expect(app.operatingSystem).toBe("iOS 26");
    expect(app.applicationCategory).toBe("HealthApplication");
    expect(app.inLanguage).toBe("fr");
    expect(app.offers).toEqual({ "@type": "Offer", price: "0", priceCurrency: "EUR" });
    expect(app.installUrl).toMatch(/^https:\/\/apps\.apple\.com\/fr\/app\/.+\/id6829265826$/);
    expect(app.url).toBe("https://pulse.example");
  });

  it("claims no rating, since the page shows no reviews", () => {
    expect(JSON.stringify(graph)).not.toMatch(/Rating|Review/);
  });

  it("names the publisher once and links the site and the app to it", () => {
    const publisher = byType("Organization");
    expect(publisher).toMatchObject({ name: "Seonay Studio", url: "https://seonay.com" });
    expect(byType("WebSite").publisher).toEqual({ "@id": publisher["@id"] });
    expect(byType("MobileApplication").publisher).toEqual({ "@id": publisher["@id"] });
  });

  it("marks up the FAQ the page shows, question for question", () => {
    const faq = byType("FAQPage").mainEntity as { name: string; acceptedAnswer: { text: string } }[];
    expect(faq.map((entry) => entry.name)).toEqual(FAQ.map((entry) => entry.question));
    expect(faq.map((entry) => entry.acceptedAnswer.text)).toEqual(FAQ.map((entry) => entry.answer));
  });

  it("points every screenshot at a file that exists", () => {
    for (const url of byType("MobileApplication").screenshot as string[]) {
      const file = path.join(PUBLIC, url.replace("https://pulse.example", ""));
      expect(fs.existsSync(file), url).toBe(true);
    }
    const icon = (byType("MobileApplication").image as string).replace("https://pulse.example", "");
    expect(fs.existsSync(path.join(PUBLIC, icon))).toBe(true);
  });
});

describe("appleItunesMeta", () => {
  it("returns the Smart App Banner tag once the app is live", () => {
    expect(appleItunesMeta(true)).toEqual({ "apple-itunes-app": "app-id=6829265826" });
  });
  it("returns nothing before the release", () => {
    expect(appleItunesMeta(false)).toEqual({});
  });
});

describe("page metadata", () => {
  it("keeps the title under 60 characters and the description under 160, so neither is cut", () => {
    expect(PAGE_TITLE.length).toBeLessThanOrEqual(60);
    expect(PAGE_DESCRIPTION.length).toBeLessThanOrEqual(160);
  });

  it("says what the app is in the words people search for", () => {
    expect(PAGE_TITLE).toMatch(/^Pulse/);
    for (const word of ["récupération", "musculation", "iPhone"]) expect(PAGE_TITLE).toContain(word);
    for (const word of ["gratuite", "VFC", "Sans abonnement"]) expect(PAGE_DESCRIPTION).toContain(word);
  });
});

describe("jsonLdScript", () => {
  it("never lets a < close the script tag", () => {
    const out = jsonLdScript({ a: "</script><b>" });
    expect(out).not.toContain("<");
    expect(JSON.parse(out)).toEqual({ a: "</script><b>" });
  });
});
