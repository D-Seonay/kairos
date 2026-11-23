import { Hero } from "@/components/sections/Hero";
import { Nav } from "@/components/sections/Nav";

export default function Home() {
  return (
    <>
      <Nav />
      <main id="contenu" className="flex-1">
        <Hero />
        {/* Following sections, in order: #score, #fonctionnalites, #confidentialite, chiffres, #faq, appel final. */}
      </main>
    </>
  );
}
