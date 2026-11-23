import Image from "next/image";
import { APP_STORE_LIVE, APP_STORE_URL } from "@/lib/config";

/** Apple's official French black badge, embedded unmodified (see site/README.md). */
const BADGE_SRC = "/badges/app-store-fr.svg";
const BADGE_RATIO = 126.50751 / 40;

export type AppStoreBadgeProps = {
  /** Defaults to APP_STORE_LIVE: a real link once Apple has approved the app. */
  live?: boolean;
  /** On-screen height in px. Apple's minimum is 40. */
  height?: 40 | 48 | 56;
  className?: string;
  /** Extra classes for the "coming soon" caption, e.g. to hide it visually in a tight nav. */
  captionClassName?: string;
};

/**
 * The App Store badge. Apple asks for a clear space of a quarter of the badge
 * height on every side: the wrapper pads by that much, so neighbours never
 * crowd it, and the artwork itself is never altered.
 */
export function AppStoreBadge({
  live = APP_STORE_LIVE,
  height = 48,
  className,
  captionClassName,
}: AppStoreBadgeProps) {
  const width = Math.round(height * BADGE_RATIO);
  const image = (
    <Image
      src={BADGE_SRC}
      alt=""
      width={width}
      height={height}
      unoptimized
      className="block max-w-none"
      style={{ width, height }}
    />
  );
  const clearSpace = { padding: height / 4, margin: -height / 4 };

  if (live) {
    return (
      <a
        href={APP_STORE_URL}
        aria-label="Télécharger Pulse dans l'App Store"
        className={[
          "inline-flex shrink-0 rounded-[12px] focus-visible:outline-2 focus-visible:outline-offset-[-6px] focus-visible:outline-signal",
          className,
        ]
          .filter(Boolean)
          .join(" ")}
        style={clearSpace}
      >
        {image}
      </a>
    );
  }

  return (
    <div className={["inline-flex shrink-0 items-center", className].filter(Boolean).join(" ")} style={clearSpace}>
      {/* Dimmed and inert until release: the caption says why. */}
      <span className="opacity-45" aria-hidden="true">
        {image}
      </span>
      <span
        className={[
          "font-mono text-[11px] leading-tight uppercase tracking-[0.14em] text-muted",
          captionClassName,
        ]
          .filter(Boolean)
          .join(" ")}
        style={{ marginLeft: height / 4 }}
      >
        Bientôt sur l&apos;App Store
      </span>
    </div>
  );
}
