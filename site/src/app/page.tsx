import { Features } from "@/components/sections/Features";
import { Hero } from "@/components/sections/Hero";
import { Nav } from "@/components/sections/Nav";
import { ScoreSimulator } from "@/components/sections/ScoreSimulator";

export default function Home() {
  return (
    <>
      <Nav />
      <main id="contenu" className="flex-1">
        <Hero />
        <ScoreSimulator />
        <Features />
        {/* Following sections, in order: #confidentialite, chiffres, #faq, appel final. */}
      </main>
    </>
  );
}
