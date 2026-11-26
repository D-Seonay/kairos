import { UMAMI_COLLECT_ORIGIN, UMAMI_SCRIPT_ORIGIN } from "./config";

type Header = { key: string; value: string };

/**
 * The Content-Security-Policy of the site. Only two third parties are allowed:
 * Umami's script host and the gateway its script posts page views to.
 *
 * Scripts keep 'unsafe-inline' because Next.js inlines its hydration payload and
 * the pages are prerendered: a nonce would force every request to render on the
 * server. Development adds what the dev server needs (eval and the HMR socket).
 */
export function contentSecurityPolicy({ dev }: { dev: boolean }): string {
  const directives: Record<string, string[]> = {
    "default-src": ["'self'"],
    "script-src": ["'self'", "'unsafe-inline'", UMAMI_SCRIPT_ORIGIN, ...(dev ? ["'unsafe-eval'"] : [])],
    "style-src": ["'self'", "'unsafe-inline'"],
    "img-src": ["'self'", "data:", "blob:"],
    "font-src": ["'self'"],
    "connect-src": ["'self'", UMAMI_COLLECT_ORIGIN, ...(dev ? ["ws:"] : [])],
    "object-src": ["'none'"],
    "base-uri": ["'self'"],
    "form-action": ["'self'"],
    "frame-ancestors": ["'none'"],
  };
  return Object.entries(directives)
    .map(([name, sources]) => `${name} ${sources.join(" ")}`)
    .join("; ");
}

/** Headers sent with every response of the site. */
export function securityHeaders({ dev }: { dev: boolean }): Header[] {
  return [
    { key: "Content-Security-Policy", value: contentSecurityPolicy({ dev }) },
    { key: "Strict-Transport-Security", value: "max-age=63072000; includeSubDomains" },
    { key: "X-Content-Type-Options", value: "nosniff" },
    { key: "X-Frame-Options", value: "DENY" },
    { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
    {
      key: "Permissions-Policy",
      value: "camera=(), microphone=(), geolocation=(), payment=(), usb=()",
    },
    { key: "Cross-Origin-Opener-Policy", value: "same-origin" },
  ];
}
