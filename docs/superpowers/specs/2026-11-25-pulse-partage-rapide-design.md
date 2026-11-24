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
