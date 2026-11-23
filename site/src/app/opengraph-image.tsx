import { readFile } from "node:fs/promises";
import path from "node:path";
import { cacheLife } from "next/cache";
import { ImageResponse } from "next/og";

export const alt = "Pulse : ta nuit décide de ta séance. Un score de récupération chaque matin.";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

const PAPER = "#efece5";
const INK = "#141414";
const MUTED = "#68655f";
const SIGNAL = "#ff4f2e";

/**
 * Open Graph card, drawn at build time. No remote font or image: the icon is
 * read from public/ and the type is the default face bundled with next/og.
 * Paper, a halftone screen swelling toward the right, the icon, the hero title.
 */
const CELL = 24;
const DOTS = (() => {
  const dots: { key: string; x: number; y: number; r: number }[] = [];
  const cols = Math.ceil(size.width / CELL) + 1;
  const rows = Math.ceil(size.height / CELL) + 1;
  for (let row = 0; row < rows; row++) {
    for (let col = 0; col < cols; col++) {
      const x = col * CELL + (row % 2 === 0 ? 0 : CELL / 2);
      const y = row * CELL;
      // Darkness grows from x = 720 to the right edge, and a little toward the bottom.
      const dark = Math.min(1, Math.max(0, (x - 720) / 480)) * (0.55 + 0.45 * (y / size.height));
      const r = Math.pow(dark, 1.1) * (CELL / 2) * 0.82;
      if (r >= 0.8) dots.push({ key: `${row}-${col}`, x, y, r });
    }
  }
  return dots;
})();

async function readIcon() {
  "use cache";
  cacheLife("max");
  const icon = await readFile(path.join(process.cwd(), "public/icon/light-1024.png"));
  return `data:image/png;base64,${icon.toString("base64")}`;
}

export default async function Image() {
  const iconSrc = await readIcon();

  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          position: "relative",
          background: PAPER,
          color: INK,
        }}
      >
        {/* Halftone screen: dots swell toward the right edge and the bottom, like a print left in the developer. */}
        {DOTS.map((dot) => (
          <div
            key={dot.key}
            style={{
              position: "absolute",
              left: dot.x - dot.r,
              top: dot.y - dot.r,
              width: dot.r * 2,
              height: dot.r * 2,
              borderRadius: dot.r,
              background: INK,
            }}
          />
        ))}

        <div
          style={{
            position: "relative",
            display: "flex",
            flexDirection: "column",
            justifyContent: "space-between",
            width: "100%",
            height: "100%",
            padding: "64px 72px",
          }}
        >
          <div style={{ display: "flex", alignItems: "center", gap: 20 }}>
            <img src={iconSrc} width={88} height={88} alt="" style={{ borderRadius: 20 }} />
            <div style={{ display: "flex", fontSize: 52, letterSpacing: -2, WebkitTextStroke: `1.5px ${INK}` }}>
              Pulse
            </div>
          </div>

          <div style={{ display: "flex", flexDirection: "column" }}>
            <div
              style={{
                display: "flex",
                flexDirection: "column",
                fontSize: 120,
                lineHeight: 0.95,
                letterSpacing: -6,
                WebkitTextStroke: `3px ${INK}`,
              }}
            >
              <div style={{ display: "flex" }}>Ta nuit décide</div>
              <div style={{ display: "flex" }}>de ta séance.</div>
            </div>
            <div style={{ display: "flex", alignItems: "center", gap: 14, marginTop: 36, fontSize: 30, color: MUTED }}>
              <div style={{ display: "flex", width: 16, height: 16, borderRadius: 8, background: SIGNAL }} />
              <div style={{ display: "flex" }}>Ton score de récupération, chaque matin.</div>
            </div>
          </div>
        </div>
      </div>
    ),
    { ...size },
  );
}
