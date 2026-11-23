"use client";

import Image from "next/image";
import { useRef, useState, type PointerEvent } from "react";
import { useInView } from "@/components/motion/useInView";
import { useReducedMotion } from "@/components/motion/useReducedMotion";

/** The five raw captures, in the order of the roll. */
export const CONTACT_FRAMES = [
  {
    src: "/screens/today.jpg",
    alt: "Aujourd'hui : le score de récupération du matin, 58 sur 100, en fatigue modérée.",
  },
  {
    src: "/screens/workout.jpg",
    alt: "Le récap d'une séance Push : durée, séries, volume, record et muscles sollicités.",
  },
  {
    src: "/screens/planning.jpg",
    alt: "Le planning de la semaine, avec la séance prévue chaque jour.",
  },
  {
    src: "/screens/stats.jpg",
    alt: "Les statistiques de biométrie sur 90 jours : FC au repos, sommeil moyen et récupération moyenne.",
  },
  {
    src: "/screens/profile.jpg",
    alt: "Le profil : séances, score du matin, poids et records.",
  },
] as const;

/** The frame the editor picked: the morning score. */
const CIRCLED = 0;

/**
 * A felt-tip loop, a little more than one turn, in a 100 × 190 box: the shape
 * of the overlay (132 % × 116 % of a 1290 × 2796 frame), so it scales evenly
 * and its length can be normalised with pathLength.
 */
const FELT_PATH =
  "M72 9C34 1 5 28 6 95C7 160 31 187 56 185C86 183 98 153 96 94C94 36 79 9 44 12C34 13 27 17 20 22";

/**
 * A strip of 35 mm film printed as a contact sheet: perforations, edge
 * printing (« PULSE 400 »), frame numbers 1A to 5A, crop marks, and the best
 * frame circled in signal felt, drawn once the strip comes into view. On a
 * mouse, hovering a frame brings a loupe over it, as on a light table. The
 * strip scrolls inside its own box, by keyboard, wheel or finger, never the page.
 */
export function ContactSheet({ className }: { className?: string }) {
  const reduced = useReducedMotion();
  const ref = useRef<HTMLDivElement>(null);
  const inView = useInView(ref, "0px 0px -25% 0px");
  const [seen, setSeen] = useState(false);
  const [loupe, setLoupe] = useState<number | null>(null);

  // Once seen, the circle stays drawn: state latched from `inView` during render.
  if (inView && !seen) setSeen(true);

  const drawn = reduced || seen;

  const moveLoupe = (index: number) => (event: PointerEvent<HTMLElement>) => {
    if (event.pointerType !== "mouse") return;
    const box = event.currentTarget.getBoundingClientRect();
    event.currentTarget.style.setProperty("--lx", String((event.clientX - box.left) / box.width));
    event.currentTarget.style.setProperty("--ly", String((event.clientY - box.top) / box.height));
    if (loupe !== index) setLoupe(index);
  };

  return (
    <div
      ref={ref}
      role="region"
      aria-label="Planche contact : cinq écrans de Pulse"
      tabIndex={0}
      className={[
        "contact-scroller overflow-x-auto overscroll-x-contain rounded-sm focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-signal",
        className,
      ]
        .filter(Boolean)
        .join(" ")}
    >
      <div className="contact-sheet relative mx-auto w-max">
        {/* Crop marks at the four corners of the strip. */}
        <span aria-hidden="true" className="crop-mark -top-4 -left-4" />
        <span aria-hidden="true" className="crop-mark -top-4 -right-4 -scale-x-100" />
        <span aria-hidden="true" className="crop-mark -bottom-4 -left-4 -scale-y-100" />
        <span aria-hidden="true" className="crop-mark -right-4 -bottom-4 -scale-100" />

        <div className="film-strip">
          <div aria-hidden="true" className="film-perfs" />
          <ol className="film-frames">
            {CONTACT_FRAMES.map((frame, index) => {
              const number = index + 1;
              return (
                <li key={frame.src} className="film-cell">
                  <p aria-hidden="true" className="film-edge">
                    <span>PULSE 400</span>
                    <span>{number}</span>
                  </p>
                  <figure
                    className="film-frame"
                    data-circled={index === CIRCLED ? "" : undefined}
                    onPointerMove={moveLoupe(index)}
                    onPointerLeave={() => setLoupe(null)}
                  >
                    <Image
                      src={frame.src}
                      alt={frame.alt}
                      width={1290}
                      height={2796}
                      sizes="220px"
                      className="block h-auto w-full"
                    />
                    {loupe === index && (
                      <span aria-hidden="true" className="loupe">
                        <Image src={frame.src} alt="" width={1290} height={2796} sizes="560px" className="loupe-image" />
                      </span>
                    )}
                    {index === CIRCLED && (
                      <svg
                        aria-hidden="true"
                        data-felt=""
                        data-drawn={drawn}
                        viewBox="0 0 100 190"
                        preserveAspectRatio="none"
                        className="felt-circle"
                      >
                        <path d={FELT_PATH} pathLength={1} />
                      </svg>
                    )}
                  </figure>
                  <p aria-hidden="true" className="film-edge">
                    <span>→{number}A</span>
                    <span className="film-edge-mark">▲</span>
                  </p>
                </li>
              );
            })}
          </ol>
          <div aria-hidden="true" className="film-perfs" />
        </div>
      </div>
    </div>
  );
}
