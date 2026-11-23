import Image from "next/image";
import type { ReactNode } from "react";

/** The raw app captures in public/screens (iPhone 6.7", 1290 × 2796). */
const SCREEN = { width: 1290, height: 2796 };
/** Titanium band plus black bezel, as a share of the frame width (in cqw). */
const BEZEL = 3.2;
/** Outer height over width, once the bezel is added on all four sides. */
const FRAME_RATIO = ((100 - 2 * BEZEL) * SCREEN.height) / SCREEN.width / 100 + (2 * BEZEL) / 100;

type Screen =
  | { src: string; alt: string; children?: never }
  /** Anything drawn in place of a capture (it fills the screen; size it in cqw or em). */
  | { children: ReactNode; src?: never; alt?: never };

export type PhoneFrameProps = Screen & {
  /** Load eagerly at high priority (the hero's main capture). */
  priority?: boolean;
  /** Width hint for the responsive image. */
  sizes?: string;
  className?: string;
  style?: React.CSSProperties;
};

/**
 * A dark titanium iPhone drawn in CSS (no Apple device artwork) around a
 * capture. Every measure is in container-query units, so the frame scales with
 * whatever width the parent gives it.
 */
export function PhoneFrame({
  src,
  alt,
  children,
  priority = false,
  sizes = "(min-width: 1024px) 320px, 50vw",
  className,
  style,
}: PhoneFrameProps) {
  return (
    <div
      className={["relative [container-type:inline-size]", className].filter(Boolean).join(" ")}
      style={{ aspectRatio: `1 / ${FRAME_RATIO}`, ...style }}
    >
      {/* Side buttons: action and volume on the left, side button on the right. */}
      <span aria-hidden="true" className="phone-button left-[-0.9cqw] top-[18%] h-[5%]" />
      <span aria-hidden="true" className="phone-button left-[-0.9cqw] top-[26%] h-[9%]" />
      <span aria-hidden="true" className="phone-button left-[-0.9cqw] top-[37%] h-[9%]" />
      <span aria-hidden="true" className="phone-button right-[-0.9cqw] top-[29%] h-[14%]" />

      {/* Titanium band. */}
      <div aria-hidden="true" className="phone-titanium absolute inset-0 rounded-[17cqw]" />
      {/* Black bezel. */}
      <div aria-hidden="true" className="absolute inset-[1.1cqw] rounded-[15.8cqw] bg-[#050505]" />

      {/* Screen. */}
      <div className="absolute overflow-hidden rounded-[13.6cqw] bg-ink" style={{ inset: `${BEZEL}cqw` }}>
        {src === undefined ? (
          children
        ) : (
          <Image
            src={src}
            alt={alt ?? ""}
            width={SCREEN.width}
            height={SCREEN.height}
            sizes={sizes}
            loading={priority ? "eager" : "lazy"}
            fetchPriority={priority ? "high" : "auto"}
            className="block h-full w-full object-cover"
          />
        )}
        {/* Dynamic Island. */}
        <span
          aria-hidden="true"
          className="absolute left-1/2 top-[2.7cqw] h-[8.8cqw] w-[30cqw] -translate-x-1/2 rounded-full bg-black"
        />
        {/* A faint glass sheen across the top corner. */}
        <span aria-hidden="true" className="phone-glass absolute inset-0" />
      </div>
    </div>
  );
}
