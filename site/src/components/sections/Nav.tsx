"use client";

import Image from "next/image";
import { useEffect, useId, useRef, useState } from "react";
import { AppStoreBadge } from "@/components/AppStoreBadge";

const LINKS = [
  { href: "#score", label: "Le score" },
  { href: "#fonctionnalites", label: "Fonctionnalités" },
  { href: "#confidentialite", label: "Confidentialité" },
  { href: "#faq", label: "FAQ" },
];

const focusRing =
  "rounded-sm focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-signal";

/**
 * Fixed nav. Transparent over the top of the hero, then translucent paper with
 * a blur once the page scrolls. Under 768 px the links fold into a disclosure
 * menu (button with aria-expanded, Escape closes it and returns focus).
 * `anchorBase="/"` is for the other pages (legal notice, 404): the links lead
 * back to the home sections, and the nav is there at once, no hero sequence.
 */
export function Nav({ anchorBase = "" }: { anchorBase?: string } = {}) {
  // On other pages than the home, section links and the logo go back to the home page.
  const onHome = anchorBase === "";
  const [scrolled, setScrolled] = useState(false);
  const [open, setOpen] = useState(false);
  const menuId = useId();
  const buttonRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 8);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  useEffect(() => {
    if (!open) return;
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        setOpen(false);
        buttonRef.current?.focus();
      }
    };
    const desktop = window.matchMedia("(min-width: 768px)");
    const onWide = () => desktop.matches && setOpen(false);
    window.addEventListener("keydown", onKey);
    desktop.addEventListener("change", onWide);
    return () => {
      window.removeEventListener("keydown", onKey);
      desktop.removeEventListener("change", onWide);
    };
  }, [open]);


  return (
    <header
      className={[
        "fixed inset-x-0 top-0 z-50 border-b transition-[background-color,border-color,backdrop-filter] duration-300 motion-reduce:transition-none",
        // Opening the menu is instant: a fading backdrop would let the hero show through the links.
        open
          ? "border-rule/70 bg-paper transition-none"
          : scrolled
            ? "border-rule/70 bg-paper/80 backdrop-blur-md"
            : "border-transparent bg-transparent",
      ].join(" ")}
    >
      <a
        href="#contenu"
        className="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-3 focus:z-10 focus:rounded-md focus:bg-ink focus:px-3 focus:py-2 focus:text-sm focus:text-paper"
      >
        Aller au contenu
      </a>

      <nav
        aria-label="Navigation principale"
        className={`${onHome ? "dev-emerge " : ""}mx-auto flex h-16 max-w-6xl items-center justify-between gap-6 px-4 sm:px-6 md:h-[4.5rem]`}
        style={onHome ? ({ "--d": "0.95s" } as React.CSSProperties) : undefined}
      >
        <a href={`${anchorBase}#top`} className={`flex items-center gap-2.5 ${focusRing}`}>
          <Image
            src="/icon/light-1024.png"
            alt=""
            aria-hidden="true"
            width={64}
            height={64}
            className="size-8 rounded-[9px] shadow-[0_0_0_1px_rgb(20_20_20/0.08)]"
          />
          <span className="font-display text-xl font-black tracking-[-0.04em]">Pulse</span>
        </a>

        <ul className="hidden items-center gap-7 text-[14px] md:flex">
          {LINKS.map((link) => (
            <li key={link.href}>
              <a href={`${anchorBase}${link.href}`} className={`text-ink/80 transition-colors hover:text-ink ${focusRing}`}>
                {link.label}
              </a>
            </li>
          ))}
        </ul>

        <div className="hidden md:block">
          <AppStoreBadge height={40} captionClassName="max-xl:sr-only" />
        </div>

        <button
          ref={buttonRef}
          type="button"
          aria-expanded={open}
          aria-controls={menuId}
          onClick={() => setOpen((value) => !value)}
          className={`-mr-2 flex h-11 items-center gap-2 px-2 font-mono text-[11px] uppercase tracking-[0.18em] md:hidden ${focusRing}`}
        >
          {open ? "Fermer" : "Menu"}
          <span aria-hidden="true" className="relative block h-3 w-5">
            <span
              className={`absolute left-0 h-[1.5px] w-full bg-ink transition-transform duration-200 motion-reduce:transition-none ${open ? "top-[5px] rotate-45" : "top-0.5"}`}
            />
            <span
              className={`absolute left-0 h-[1.5px] w-full bg-ink transition-transform duration-200 motion-reduce:transition-none ${open ? "top-[5px] -rotate-45" : "top-2"}`}
            />
          </span>
        </button>
      </nav>

      <div id={menuId} hidden={!open} className="border-t border-rule/70 px-4 pb-6 pt-2 md:hidden">
        <ul>
          {LINKS.map((link) => (
            <li key={link.href} className="border-b border-rule/70">
              <a
                href={`${anchorBase}${link.href}`}
                onClick={() => setOpen(false)}
                className={`block py-3.5 font-display text-2xl font-black tracking-[-0.03em] ${focusRing}`}
              >
                {link.label}
              </a>
            </li>
          ))}
        </ul>
        <div className="mt-6">
          <AppStoreBadge height={48} />
        </div>
      </div>
    </header>
  );
}
