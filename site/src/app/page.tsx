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
        {/* Following sections, in order: #fonctionnalites, #confidentialite, chiffres, #faq, appel final. */}
      </main>
    </>
  );
}
