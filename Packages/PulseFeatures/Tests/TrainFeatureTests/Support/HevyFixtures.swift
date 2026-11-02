// swiftlint:disable line_length
/// Extrait inventé au format réel de l'export CSV de Hevy : champs entre guillemets, guillemets doublés, virgules et retours à
/// la ligne dans les notes, émoji, champs vides, dates françaises et anglaises.
enum HevyFixtures {
    static let csv = """
"title","start_time","end_time","description","exercise_title","superset_id","exercise_notes","set_index","set_type","weight_kg","reps","distance_km","duration_seconds","rpe"
"Push 🫷🫸","26 oct. 2026, 07:00","26 oct. 2026, 08:06","Note, avec ""guillemets""
et retour","Développé Couché (Barre)",,"",0,"warmup",,20,,,6
"Push 🫷🫸","26 oct. 2026, 07:00","26 oct. 2026, 08:06","Note, avec ""guillemets""
et retour","Développé Couché (Barre)",,"",1,"normal",60,12,,,7.5
"Push 🫷🫸","26 oct. 2026, 07:00","26 oct. 2026, 08:06","Note, avec ""guillemets""
et retour","Écarté (Machine)",,"Siège cran 4 — l’épaule ok",0,"dropset",72.5,5,,,
"Push 🫷🫸","26 oct. 2026, 07:00","26 oct. 2026, 08:06","Note, avec ""guillemets""
et retour","Tapis de Course",,"",0,"normal",,,1.4,600,
"Pull","27 Oct 2026, 07:17","27 Oct 2026, 07:59","","Extension Triceps Poulie Haute",0,"",0,"failure",30.5,3,,,9.5
"Pull","27 Oct 2026, 07:17","27 Oct 2026, 07:59","","Avant Bras Poulie Barre Droite",0,"",0,"normal",27,12,,,
"""
}
// swiftlint:enable line_length
