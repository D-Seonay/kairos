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
