# Pulse — carte musculaire : silhouette femme ou homme

Date : 2026-11-23. Taille : petit changement.

## Intention

La carte musculaire (zones travaillées) montre un corps qui correspond à la personne : femme ou homme, selon le sexe choisi
dans son profil.

## Constat

- `musclemap.json` (PulseDesignSystem) contient **le corps de femme** de MuscleMap (mêmes tracés que
  `FemaleFrontPaths.swift` / `FemaleBackPaths.swift`, `viewBox` 650 × 1450, dos décalé à x = 823). Il n'y a pas de corps
  d'homme dans l'app.
- MuscleMap (MIT, Melih Colpan) fournit aussi `MaleFrontPaths.swift` / `MaleBackPaths.swift` : même découpage en régions
  (`slug`), tracés en syntaxe SVG compacte (drapeaux d'arc collés : `a.89.89 0 01-.11-1.64`), `viewBox` 727 × 1280
  (face à (0, 95), dos à (718, 95)).
- `MuscleMapView` est utilisé à 7 endroits (séance du jour, récap, historique, fiche exercice, stats, widgets moyen et
  grand). Le profil porte `Sex` (`female`, `male`, `unspecified`).

## Objectifs

- Ajouter le corps d'homme, face et dos, avec les mêmes régions que le corps de femme.
- Femme → corps de femme ; Homme → corps d'homme ; Autre (`unspecified`) → corps de femme (rien ne change pour qui voit
  l'app aujourd'hui).
- L'app suit un changement de sexe dans le profil ; les widgets suivent au prochain rafraîchissement.

## Non-objectifs

- Un réglage de silhouette séparé du sexe.
- Toute retouche des dessins.

## Approches

1. **Valeur d'environnement SwiftUI** (retenue) : une valeur `muscleMapBody` posée à la racine à côté de `pulseTheme`, lue
   par `MuscleMapView`. Les 7 appelants ne changent pas. Les widgets la posent depuis l'instantané.
2. Paramètre explicite sur `MuscleMapView` : touche les 7 appelants et leurs modèles pour un même résultat.

## Conception

- **Ressource** : `musclemap.json` gagne les silhouettes d'homme (par exemple `female` / `male`, chacune avec `front` et
  `back` au format actuel : `viewBox`, `body`, `regions`, `layers` dans l'ordre de dessin). Les tracés d'homme sont
  convertis depuis les fichiers Swift amont par un script dans `scripts/`, sans modification. La mention de licence reste
  unique (même auteur, même licence).
- **Rendu** : `MuscleMapArtwork` charge les deux corps ; `MuscleMapView` choisit selon la valeur d'environnement. Les
  régions éteintes / allumées et les surimpressions suivent les règles actuelles.
- **Lecteur de tracés** : doit lire la syntaxe compacte des tracés d'homme ; des tests le prouvent sur des tracés réels.
- **Choix** : une fonction pure `Sex → corps` (Autre → femme), testée.
- **Widgets** : `WidgetSnapshot` porte le corps choisi (champ optionnel : un ancien fichier sans le champ donne le corps de
  femme).
- **Tests** : `swift test` sur les packages ; pas de simulateur. Vérifications sur iPhone par Mathéo.

## Laissé au constructeur

- Le nom exact de la valeur d'environnement et du type (`MuscleMapBody` ou équivalent).
- L'ordre des calques du corps d'homme (celui du fichier amont, comme pour le corps de femme).
- Le cadrage : chaque silhouette garde sa `viewBox` ; la carte garde sa hauteur.
