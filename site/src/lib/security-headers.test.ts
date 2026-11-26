import { describe, expect, it } from "vitest";
import { UMAMI_COLLECT_ORIGIN, UMAMI_SCRIPT_ORIGIN, UMAMI_SCRIPT_URL } from "./config";
import { contentSecurityPolicy, securityHeaders } from "./security-headers";

function directive(csp: string, name: string): string[] {
  const found = csp.split("; ").find((part) => part.startsWith(`${name} `));
  return found ? found.split(" ").slice(1) : [];
}

describe("contentSecurityPolicy", () => {
  const csp = contentSecurityPolicy({ dev: false });

  it("lets the Umami script load and post page views, and nothing else from outside", () => {
    expect(UMAMI_SCRIPT_URL.startsWith(`${UMAMI_SCRIPT_ORIGIN}/`)).toBe(true);
    expect(directive(csp, "script-src")).toEqual(["'self'", "'unsafe-inline'", UMAMI_SCRIPT_ORIGIN]);
    expect(directive(csp, "connect-src")).toEqual(["'self'", UMAMI_COLLECT_ORIGIN]);
    expect(directive(csp, "default-src")).toEqual(["'self'"]);
  });

  it("forbids framing, plugins and base or form hijacking", () => {
    expect(directive(csp, "frame-ancestors")).toEqual(["'none'"]);
    expect(directive(csp, "object-src")).toEqual(["'none'"]);
    expect(directive(csp, "base-uri")).toEqual(["'self'"]);
    expect(directive(csp, "form-action")).toEqual(["'self'"]);
  });

  it("allows eval and the HMR socket only in development", () => {
    expect(csp).not.toContain("'unsafe-eval'");
    expect(csp).not.toContain("ws:");
    const dev = contentSecurityPolicy({ dev: true });
    expect(directive(dev, "script-src")).toContain("'unsafe-eval'");
    expect(directive(dev, "connect-src")).toContain("ws:");
  });
});

describe("securityHeaders", () => {
  it("sends the policy and the usual hardening headers", () => {
    const keys = securityHeaders({ dev: false }).map((header) => header.key);
    expect(keys).toEqual(
      expect.arrayContaining([
        "Content-Security-Policy",
        "Strict-Transport-Security",
        "X-Content-Type-Options",
        "X-Frame-Options",
        "Referrer-Policy",
        "Permissions-Policy",
      ]),
    );
  });
});
