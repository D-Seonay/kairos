# Partage rapide sur les réseaux

## Intention

À la fin d'une séance ou d'une course, l'utilisateur partage son résultat en deux gestes (story Instagram, WhatsApp, Snapchat, Messages, Photos…). La carte montre d'abord la performance. La marque Pulse reste discrète mais présente, et le texte joint renvoie vers l'App Store. Chaque partage fait donc aussi connaître l'app.

## Objectifs

- Un bouton « Partager » sur le récap de séance, le récap de course et le détail d'une séance passée (historique, planning).
- Une image prête pour les réseaux, en deux formats : story 9:16 (1080 × 1920) et publication 4:5 (1080 × 1350).
- Le texte joint : « Push · 1 h 05 · 18 séries · 4 250 kg », puis « Suivi avec Pulse : <lien App Store> ».

## Non-objectifs

- Pas de SDK Instagram ni Facebook (« Share to Stories ») : il faudrait un identifiant d'app Meta. La feuille de partage du système propose déjà Instagram.
- Pas de photo du corps sur la carte : ces photos restent privées, sur l'iPhone seulement.
- Pas de partage de records isolés, du score ou de la nuit pour l'instant.

## Approche

- **Retenue** : une carte SwiftUI dessinée hors écran avec `ImageRenderer`, puis transmise en PNG à `ShareLink` (`Transferable`). Aucune dépendance, rien ne sort de l'iPhone sans le geste de l'utilisateur.
- **Écartée** : partager une capture du récap. Le récap est trop long, il contient les réglages (RPE, note) et ne tient pas au format story.
- **Écartée** : dessiner la carte du tracé avec MapKit. `Map` ne se dessine pas dans `ImageRenderer`. Le tracé est donc projeté à plat (`ShareRoute.normalized`, corrigé de la latitude) et tracé en filet blanc.

## Conception

- `PulseDesignSystem/Share` contient :
  - `ShareCardContent` : les données de la carte, le texte joint et le nom de fichier ;
  - `ShareCardView` : le dessin « Argentique », toujours sombre, avec des couleurs fixes ;
  - `ShareCardRenderer` et `ShareCardImage` : le rendu PNG ;
  - `ShareCardSheet` et `ShareCardButton` : l'aperçu, le choix du format et le bouton Partager.
- Les features construisent le contenu :
  - `RecapModel.shareContent` : durée, tonnage, séries, records, carte musculaire, et un record par exercice sans « nouveau record » (`BeatenRecord.headline`) ;
  - `RunRecapModel.shareContent` : distance, temps, allure, dénivelé ou FC, et le tracé ;
  - `SessionDetailModel.shareContent` : la musculation comme le récap, la course et le vélo avec la distance, la durée et l'allure ou la vitesse.
- Le thème et la silhouette du profil sont passés au rendu à la main, car la carte se dessine hors de l'environnement de l'écran.

## Laissé à vérifier sur iPhone

- Le partage vers Instagram (story et publication), WhatsApp et Photos.
- La lisibilité de la carte sur un vrai écran, et le rendu de la silhouette homme.

## Lot 2 : photo en fond, records, nuit

- **Photo de la séance en fond** : la feuille propose une rangée de fonds, la « Trame Pulse » ou une vignette par photo de la séance (`SessionPhotosModel.shareCardPhotos`).
  - L'image entière n'est lue et décodée (redressée, 2 048 px max) que si on la choisit, hors de l'acteur principal.
  - Sur une photo, le dessin s'efface. Un dégradé noir garde les chiffres lisibles et une trame légère couvre la partie sombre.
  - Les photos du corps restent exclues.
- **Records** : un appui long sur une ligne de Stats → Records (force et chronos 5 km, 10 km, semi) ou du mur des records du profil propose « Partager ce record ». La même action existe pour VoiceOver.
  - La carte met la valeur en très grand (`Visual.hero`), avec la série d'origine, le gain ou l'allure.
  - Le texte joint reprend la valeur juste après le titre.
- **Nuit** : un bouton Partager dans la barre de l'écran Nuit.
  - Avec des phases, la carte dessine l'hypnogramme en blanc (`Visual.hypnogram`) : une barre fine par tranche, des liaisons verticales et l'encre plus forte vers le profond. Elle donne aussi le temps endormi, le profond, le paradoxal et le léger.
  - Sans phases, elle montre le temps endormi en très grand, avec les réveils.
- Restent à faire : le score de récupération du jour, et une semaine d'entraînement résumée.

## Lot 3 : l'image sans fond (sticker)

- **Intention** : poser ses chiffres sur sa propre photo en story, comme un sticker Strava. L'image ne garde que le contenu de la carte, sans aucun fond.
- **Approches** :
  - **Retenue** : un PNG transparent, avec un bouton « Copier » ; on le colle ensuite dans l'éditeur de story d'Instagram, où il devient un sticker. On peut aussi l'enregistrer dans Photos, le PNG garde sa transparence.
  - **Écartée** : « Partager » seul. Instagram fait du PNG le fond de la story et remplit le transparent d'une couleur.
  - **Écartée** : l'API « Share to Stories » d'Instagram (`stickerImage`), qui demande un identifiant d'app Meta.
- **Conception** :
  - La rangée « Fond » gagne une tuile « Sans fond » (damier), toujours là, même sans photos de séance. La rangée s'affiche donc toujours.
  - Le rendu reprend l'étiquette, la marque PULSE, le titre, la date, le dessin, les chiffres et les records. Tout passe à l'encre blanche (plus de gris), les chiffres un peu plus épais, avec un liseré sombre serré et un halo, pour rester lisible sur une photo claire. La carte musculaire prend sa palette claire (corps clair, muscles travaillés à l'encre). Le pied « Suivi avec Pulse » saute et deux records au plus sont écrits : la marque en haut suffit et l'image reste plus basse qu'une story.
  - L'image est recadrée au contenu (1 080 px de large, hauteur selon le contenu), sans le vide d'une story ; le choix story / publication est masqué dans ce mode.
  - L'aperçu pose l'image sur un damier.
  - « Copier » met le PNG dans le presse-papiers (`UIPasteboard`, type PNG) et confirme « Copiée, colle-la dans ta story ». « Partager » reste à côté.
  - Pas d'option d'encre noire : blanc et ombre seulement.
- **Laissé à vérifier sur iPhone** : le collage dans une story Instagram, la lisibilité sur une photo claire.
