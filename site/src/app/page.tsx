import { Faq } from "@/components/sections/Faq";
import { Features } from "@/components/sections/Features";
import { FinalCta } from "@/components/sections/FinalCta";
import { Footer } from "@/components/sections/Footer";
import { Hero } from "@/components/sections/Hero";
import { Nav } from "@/components/sections/Nav";
import { Numbers } from "@/components/sections/Numbers";
import { Privacy } from "@/components/sections/Privacy";
import { ScoreSimulator } from "@/components/sections/ScoreSimulator";

export default function Home() {
  return (
    <>
      <Nav />
      <main id="contenu" className="flex-1">
        <Hero />
        <ScoreSimulator />
        <Features />
        <Privacy />
        <Numbers />
        <Faq />
        <FinalCta />
      </main>
      <Footer />
    </>
  );
}
