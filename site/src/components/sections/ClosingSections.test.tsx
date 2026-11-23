import "@testing-library/jest-dom/vitest";
import { act, cleanup, render, screen, within } from "@testing-library/react";
import { renderToStaticMarkup } from "react-dom/server";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { CounterBand } from "@/components/visual/CounterBand";
import { PRIVACY_URL, STUDIO_URL, SUPPORT_URL } from "@/lib/config";
import { Faq } from "./Faq";
import { FAQ } from "./faq-data";
import { Footer, MEDICAL_DISCLAIMER } from "./Footer";
import { NUMBERS } from "./numbers-data";
import { Privacy } from "./Privacy";

let reducedMotion: boolean;
let observerCallbacks: IntersectionObserverCallback[];

beforeEach(() => {
  reducedMotion = false;
  observerCallbacks = [];
  vi.stubGlobal(
    "matchMedia",
    vi.fn((query: string) => ({
      matches: query.includes("reduce") ? reducedMotion : false,
      media: query,
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
    })),
  );
  vi.stubGlobal(
    "IntersectionObserver",
    class {
      constructor(callback: IntersectionObserverCallback) {
        observerCallbacks.push(callback);
      }
      observe() {}
      unobserve() {}
      disconnect() {}
    },
  );
});

afterEach(() => {
  cleanup();
  vi.useRealTimers();
  vi.unstubAllGlobals();
  vi.doUnmock("@/lib/config");
  vi.resetModules();
});

describe("Privacy", () => {
  it("is the confidentialite anchor, with a link to the privacy policy", () => {
    const { container } = render(<Privacy />);
    expect(container.querySelector("section#confidentialite")).not.toBeNull();
    expect(screen.getByRole("link", { name: /politique de confidentialité/i })).toHaveAttribute("href", PRIVACY_URL);
  });
});

describe("Faq", () => {
  it("serves every question and answer open, so they read without JavaScript", () => {
    const html = renderToStaticMarkup(<Faq />);
    const doc = new DOMParser().parseFromString(html, "text/html");
    const details = doc.querySelectorAll("details");
    expect(details).toHaveLength(FAQ.length);
    for (const [index, element] of details.entries()) {
      expect(element.hasAttribute("open")).toBe(true);
      expect(element.textContent).toContain(FAQ[index].question);
      expect(element.textContent).toContain(FAQ[index].answer);
    }
    expect(doc.querySelector(`a[href="${SUPPORT_URL}"]`)?.textContent).toContain("Toute l'assistance");
  });

  it("folds the answers after hydration, and still opens them on click", () => {
    vi.useFakeTimers();
    const { container } = render(<Faq />);
    act(() => void vi.advanceTimersByTime(100));
    const first = container.querySelector("details")!;
    expect(first).not.toHaveAttribute("open");
    expect(container.querySelector(".faq-list")).toHaveAttribute("data-ready", "true");
    first.setAttribute("open", "");
    expect(first).toHaveAttribute("open");
  });

  it("keeps everything open under reduced motion", () => {
    reducedMotion = true;
    vi.useFakeTimers();
    const { container } = render(<Faq />);
    act(() => void vi.advanceTimersByTime(100));
    expect(container.querySelectorAll("details[open]")).toHaveLength(FAQ.length);
  });
});

describe("CounterBand", () => {
  const figures = NUMBERS.map(({ value, label }) => ({ value, label }));

  it("reads every figure and label, and rolls reels once on the client", () => {
    const { container } = render(<CounterBand figures={figures} />);
    for (const figure of figures) {
      expect(screen.getByText(figure.label)).toBeInTheDocument();
    }
    expect(container.querySelector(".counter-band")).toHaveTextContent("93");
    expect(container.querySelectorAll(".counter-reel").length).toBe(figures.reduce((n, f) => n + f.value.length, 0));
    expect(container.querySelector(".counter-band")).toHaveAttribute("data-roll", "off");
  });

  it("shows plain fixed digits, with no reel, under reduced motion", () => {
    reducedMotion = true;
    const { container } = render(<CounterBand figures={figures} />);
    expect(container.querySelectorAll(".counter-reel")).toHaveLength(0);
    expect(container.querySelector(".counter-band")).toHaveTextContent("93");
  });

  it("lands the reels on their values when the band is seen", () => {
    const { container } = render(<CounterBand figures={[{ value: "93", label: "exercices" }]} />);
    const digits = () => [...container.querySelectorAll<HTMLElement>(".counter-digit")].map((d) => d.style.getPropertyValue("--i"));
    expect(digits()).toEqual(["0", "0"]);
    act(() => {
      for (const callback of observerCallbacks) {
        callback([{ isIntersecting: true } as IntersectionObserverEntry], {} as IntersectionObserver);
      }
    });
    expect(digits()).toEqual(["19", "13"]);
    expect(container.querySelector(".counter-band")).toHaveAttribute("data-roll", "on");
  });
});

describe("Footer", () => {
  it("carries the studio signature, the legal links, the medical notice and the copyright", () => {
    render(<Footer />);
    expect(screen.getByRole("link", { name: /Pulse par Seonay Studio/ })).toHaveAttribute("href", STUDIO_URL);
    const footer = screen.getByRole("contentinfo");
    expect(within(footer).getByRole("link", { name: "Mentions légales" })).toHaveAttribute("href", "/mentions-legales");
    const privacy = within(footer).getAllByRole("link", { name: "Confidentialité" });
    expect(privacy.map((link) => link.getAttribute("href"))).toEqual(["#confidentialite", PRIVACY_URL]);
    expect(within(footer).getByRole("link", { name: "Assistance" })).toHaveAttribute("href", SUPPORT_URL);
    expect(footer).toHaveTextContent(MEDICAL_DISCLAIMER);
    expect(MEDICAL_DISCLAIMER).toBe(
      "Pulse n'est pas un dispositif médical. Le score et les ajustements sont des repères d'entraînement, pas un avis médical.",
    );
    expect(footer).toHaveTextContent("© 2026 Pulse par Seonay Studio");
  });

  it("has no contact item, and no mailto link, while CONTACT_EMAIL is empty", () => {
    render(<Footer />);
    expect(screen.queryByText("Contact")).not.toBeInTheDocument();
    expect(document.querySelector('a[href^="mailto:"]')).toBeNull();
  });

  it("links the contact address once CONTACT_EMAIL is set", async () => {
    vi.resetModules();
    vi.doMock("@/lib/config", async (importOriginal) => ({
      ...(await importOriginal<typeof import("@/lib/config")>()),
      CONTACT_EMAIL: "bonjour@example.test",
    }));
    const { Footer: ConfiguredFooter } = await import("./Footer");
    render(<ConfiguredFooter />);
    expect(screen.getByRole("link", { name: "bonjour@example.test" })).toHaveAttribute(
      "href",
      "mailto:bonjour@example.test",
    );
    expect(screen.getByText("Contact")).toBeInTheDocument();
  });
});
