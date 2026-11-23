import Image from "next/image";
import type { ReactNode } from "react";
import { ContactSheet } from "@/components/visual/ContactSheet";
import { SupplementsScreen, WidgetsScreen } from "@/components/visual/DrawnScreens";
import { Grain } from "@/components/visual/Grain";
import { PhoneFrame } from "@/components/visual/PhoneFrame";
import { RegistrationMarks } from "@/components/visual/RegistrationMarks";
import { FeatureStep, FeaturesStage, type SwapLayer } from "@/components/visual/ScreenSwap";
import { FEATURES, type Feature } from "./features-data";

const DRAWN: Record<string, (props: { label: string }) => ReactNode> = {
  complements: SupplementsScreen,
  widgets: WidgetsScreen,
};

/** What fills the phone's screen for a feature: its capture, or the drawing that stands in for it. */
function Drawn({ feature }: { feature: Feature }) {
  const Screen = DRAWN[feature.id];
  return Screen ? <Screen label={feature.alt} /> : null;
}

/** The phone each block carries when nothing is pinned (below 1024 px, or reduced motion). */
function BlockPhone({ feature }: { feature: Feature }) {
  return feature.screen ? (
    <PhoneFrame
      src={feature.screen}
      alt={feature.alt}
      sizes="(min-width: 768px) 280px, 68vw"
      className="feature-visual-phone"
    />
  ) : (
    <PhoneFrame className="feature-visual-phone">
      <Drawn feature={feature} />
    </PhoneFrame>
  );
}

/** The pinned phone's screens, one layer per feature. */
const LAYERS: SwapLayer[] = FEATURES.map((feature) => ({
  key: feature.id,
  node: feature.screen ? (
    <Image src={feature.screen} alt={feature.alt} fill sizes="300px" className="object-cover" />
  ) : (
    <Drawn feature={feature} />
  ),
}));

/**
 * Fonctionnalités, 01 to 06. From 1024 px (motion allowed) an iPhone stays
 * pinned on the left while the six blocks scroll by, and its screen changes
 * through a halftone dissolve; a film counter under it rolls to the frame in
 * view. Elsewhere each block carries its own phone. Then the contact sheet:
 * the five captures on a strip of 35 mm film. Every title and body is in the
 * served HTML.
 */
export function Features() {
  return (
    <section
      id="fonctionnalites"
      aria-labelledby="features-title"
      className="relative isolate overflow-clip border-b border-rule"
    >
      <Grain />
      <RegistrationMarks />

      <div className="relative mx-auto max-w-6xl px-4 pt-24 sm:px-6 sm:pt-28 lg:pt-32">
        <header className="grid gap-6 lg:grid-cols-[minmax(0,7fr)_minmax(0,5fr)] lg:items-end lg:gap-14">
          <div>
            <p className="inline-flex items-center gap-2 font-mono text-[11px] tracking-[0.18em] text-muted uppercase">
              <span aria-hidden="true" className="size-2 rounded-full bg-signal" />
              Fonctionnalités
            </p>
            <h2
              id="features-title"
              className="mt-5 font-display text-[clamp(2.5rem,1rem+5vw,4.75rem)] leading-[0.9] font-black tracking-[-0.05em] text-balance text-ink"
            >
              Du réveil à la dernière série.
            </h2>
          </div>
          <p className="max-w-[54ch] text-[17px] leading-relaxed text-muted lg:pb-2">
            Le score du matin décide, le reste suit : ta séance, ton programme, tes statistiques, tes compléments et tes
            widgets.
          </p>
        </header>

        <div className="mt-12 lg:mt-8">
          <FeaturesStage layers={LAYERS} captions={FEATURES.map((feature) => feature.eyebrow)}>
            {FEATURES.map((feature, index) => (
              <FeatureStep key={feature.id} index={index} className="feature-step">
                <div className="feature-copy">
                  <p aria-hidden="true" className="feature-index">
                    {feature.index}
                  </p>
                  <p className="mt-5 font-mono text-[11px] tracking-[0.18em] text-muted uppercase">
                    <span className="sr-only">{feature.index}. </span>
                    {feature.eyebrow}
                  </p>
                  <h3 className="mt-3 font-display text-[clamp(2rem,1.2rem+2.6vw,3.25rem)] leading-[0.95] font-black tracking-[-0.045em] text-balance text-ink">
                    {feature.title}
                  </h3>
                  <p className="mt-4 max-w-[46ch] text-[17px] leading-relaxed text-muted">{feature.body}</p>
                </div>
                <div className="feature-visual">
                  <div aria-hidden="true" className="feature-disc" />
                  <BlockPhone feature={feature} />
                </div>
              </FeatureStep>
            ))}
          </FeaturesStage>
        </div>

        <div className="mt-20 grid gap-4 border-t-2 border-ink pt-8 sm:mt-24 md:grid-cols-[minmax(0,1fr)_minmax(0,1fr)] md:items-end md:gap-14">
          <div>
            <p className="font-mono text-[11px] tracking-[0.18em] text-muted uppercase">Planche contact</p>
            <h3 className="mt-3 font-display text-[clamp(2rem,1.2rem+2.6vw,3.25rem)] leading-[0.95] font-black tracking-[-0.045em] text-ink">
              Toute la pellicule.
            </h3>
          </div>
          <p className="max-w-[46ch] text-[15px] leading-relaxed text-muted md:pb-1">
            Cinq écrans de l&apos;app, posés sur la table lumineuse.{" "}
            <span className="[@media(hover:hover)]:hidden">Fais glisser la bande pour tout voir.</span>
            <span className="hidden [@media(hover:hover)]:inline">Survole une vue pour la regarder à la loupe.</span>
          </p>
        </div>
      </div>

      <ContactSheet className="mt-6 pb-24 sm:pb-28 lg:pb-32" />
    </section>
  );
}
