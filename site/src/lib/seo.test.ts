import { describe, expect, it } from "vitest";
import { appleItunesMeta, jsonLdScript, PAGE_DESCRIPTION, PAGE_TITLE, softwareApplicationJsonLd } from "./seo";

describe("softwareApplicationJsonLd", () => {
  const ld = softwareApplicationJsonLd("https://pulse.example") as Record<string, unknown>;

  it("describes a free iOS health application in French", () => {
    expect(ld["@context"]).toBe("https://schema.org");
    expect(ld["@type"]).toBe("SoftwareApplication");
    expect(ld.name).toBe("Pulse");
    expect(ld.operatingSystem).toBe("iOS");
    expect(ld.applicationCategory).toBe("HealthApplication");
    expect(ld.inLanguage).toBe("fr");
    expect(ld.offers).toEqual({ "@type": "Offer", price: "0", priceCurrency: "EUR" });
  });

  it("points at the site and names the publisher", () => {
    expect(ld.url).toBe("https://pulse.example");
    expect(ld.publisher).toEqual({ "@type": "Organization", name: "Seonay Studio", url: "https://seonay.com" });
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
  it("uses the exact title and the promotional text", () => {
    expect(PAGE_TITLE).toBe("Pulse — Récupération & Muscu");
    expect(PAGE_DESCRIPTION).toBe(
      "Un score de récupération chaque matin, des séances de muscu guidées et tes compléments au même endroit. Tes données d'Apple Santé restent sur ton iPhone.",
    );
    expect(PAGE_DESCRIPTION.length).toBeLessThanOrEqual(170);
  });
});

describe("jsonLdScript", () => {
  it("never lets a < close the script tag", () => {
    const out = jsonLdScript({ a: "</script><b>" });
    expect(out).not.toContain("<");
    expect(JSON.parse(out)).toEqual({ a: "</script><b>" });
  });
});
