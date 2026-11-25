import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";
import { assertPublishable, PRIVACY_URL, PUBLIC_PAGE_REDIRECTS, resolveSiteUrl, SUPPORT_URL } from "./config";

describe("public page redirects", () => {
  it("serves the privacy and support addresses the app and the App Store listing know", () => {
    expect(PUBLIC_PAGE_REDIRECTS.map((redirect) => redirect.source)).toEqual(["/confidentialite", "/support"]);
    expect(PUBLIC_PAGE_REDIRECTS.map((redirect) => redirect.destination)).toEqual([PRIVACY_URL, SUPPORT_URL]);
  });
  it("matches the privacy address written in the app's Info.plist", () => {
    const plist = readFileSync(resolve(__dirname, "../../../Pulse/Info.plist"), "utf8");
    const address = /<key>PulsePrivacyPolicyURL<\/key>\s*<string>([^<]+)<\/string>/.exec(plist)?.[1];
    expect(address).toBe("https://pulserecovery.app/confidentialite");
  });
  it("points at the repository's current GitHub Pages path", () => {
    expect(PRIVACY_URL).toBe("https://d-seonay.github.io/pulse/confidentialite/");
    expect(SUPPORT_URL).toBe("https://d-seonay.github.io/pulse/support/");
  });
});

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
