# Carte musculaire femme / homme — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** la carte musculaire dessine le corps de femme ou d'homme selon le sexe du profil (Autre → femme).

**Architecture :** un type de domaine `MuscleMapFigure` (`female`, `male`) tiré de `Sex`. `musclemap.json` contient les deux
corps, produits par un seul script depuis les fichiers Swift de MuscleMap. `MuscleMapView` lit la silhouette dans une valeur
d'environnement posée à la racine de l'app ; les widgets la reçoivent par `WidgetSnapshot`.

**Tech Stack :** Swift 6, SwiftUI, Swift Testing, Python 3 (script de conversion, sans dépendance).

**Spec :** `docs/superpowers/specs/2026-11-23-pulse-silhouette-homme-femme-design.md`

## Global Constraints

- Femme → `female` ; Homme → `male` ; Autre (`Sex.unspecified`) → `female`.
- Tracés MuscleMap (MIT, Melih Colpan) repris sans modification, depuis le commit amont
  `d53ddf4d480b65979f1008b203e6b6eda0e67e54` (`Sources/MuscleMap/Data/`). Une seule mention de licence, celle déjà dans
  `musclemap.json`.
- Aucune dépendance nouvelle. Pas de simulateur, pas de `xcodebuild test` : seulement `swift test --package-path …`,
  `swiftlint lint --strict`, et `make build-release` pour vérifier que l'app compile en Release.
- Un instantané de widget écrit avant ce changement (sans le champ) se lit toujours et donne `female`.

## Review Focus

1. **Tracé d'homme illisible :** `MuscleMapArtwork` avale les erreurs (`try? … compactMap`), donc un tracé compact mal lu
   disparaît sans bruit. Comptes exacts de tracés lus, par corps et par côté (Task 2).
2. **Ancien fichier de widget :** le fichier `recovery-widget.json` déjà sur l'iPhone n'a pas `muscleMapFigure`. Il doit
   se décoder et donner `female` (Task 1).
3. **Le corps d'homme est plus large** (727 × 1280 contre 650 × 1450) : à hauteur égale, la carte prend environ 25 % de
   largeur en plus. Vérifier à l'œil la carte de séance (110 pt) et les widgets moyen (98 pt) et grand (74 pt) sur
   iPhone ; aucun code n'est prévu tant que rien ne déborde.
4. **Changement de sexe dans le profil :** la racine relit le profil par le rappel de `ProfileModel`. La carte doit changer
   sans relancer l'app, y compris dans les feuilles (fiche exercice, récap), qui héritent de l'environnement comme
   `pulseTheme`. Vérification sur iPhone.
5. **Refresher sans profil lisible :** `snapshot` reçoit `nil` et doit publier `female`, jamais échouer (Task 3).

---

### Task 1 : type de domaine et instantané de widget

**Files :**
- Create : `Packages/PulseDomain/Sources/PulseDomain/Training/MuscleMapFigure.swift`
- Modify : `Packages/PulseDomain/Sources/PulseDomain/Widgets/WidgetSnapshot.swift`
- Test : `Packages/PulseDomain/Tests/PulseDomainTests/MuscleMapFigureTests.swift`

**Interfaces :**
- Produces : `public enum MuscleMapFigure: String, Sendable, Codable, CaseIterable { case female, male }` avec
  `public init(sex: Sex)` ; `WidgetSnapshot.muscleMapFigure: MuscleMapFigure?`, paramètre d'init
  `muscleMapFigure: MuscleMapFigure? = nil` placé en dernier.

- [ ] **Step 1 : écrire les tests qui échouent**

```swift
@Test func figureFollowsTheProfileSex() {
    #expect(MuscleMapFigure(sex: .female) == .female)
    #expect(MuscleMapFigure(sex: .male) == .male)
    #expect(MuscleMapFigure(sex: .unspecified) == .female)
}

@Test func snapshotWithoutFigureStillDecodes() throws {
    // Encode un instantané, retire la clé `muscleMapFigure` du JSON, redécode : `muscleMapFigure == nil`.
}

@Test func snapshotKeepsItsFigure() throws {
    // Aller-retour JSON (dates en ISO 8601) d'un instantané `muscleMapFigure: .male` : égal à l'original.
}
```

- [ ] **Step 2 : lancer, constater l'échec**

Run : `swift test --package-path Packages/PulseDomain --filter MuscleMapFigure`
Expected : échec de compilation, `MuscleMapFigure` inconnu.

- [ ] **Step 3 : implémenter `MuscleMapFigure` et le champ de `WidgetSnapshot`**

Commentaires en français, comme le reste du package (« La silhouette de la carte musculaire : … Autre donne la
silhouette de femme, celle que l'app montrait avant le choix. »).

- [ ] **Step 4 : lancer tout le package**

Run : `swift test --package-path Packages/PulseDomain`
Expected : tout passe.

- [ ] **Step 5 : commit**

```bash
git add Packages/PulseDomain
git commit -m "feat(domain): muscle map figure from the profile sex, carried by the widget snapshot"
```

### Task 2 : les deux corps dans l'artwork et la vue

**Files :**
- Create : `scripts/musclemap_from_swift.py`
- Delete : `scripts/extract_musclemap.py` (il lit `maquette.html` et ne connaît qu'un corps)
- Modify : `Packages/PulseDesignSystem/Sources/PulseDesignSystem/Resources/musclemap.json` (régénéré)
- Modify : `Packages/PulseDesignSystem/Sources/PulseDesignSystem/MuscleMap/MuscleMapArtwork.swift`
- Modify : `Packages/PulseDesignSystem/Sources/PulseDesignSystem/MuscleMap/MuscleMapView.swift`
- Modify : `Packages/PulseDesignSystem/Sources/PulseDesignSystem/Theme/PulseThemeKey.swift` (ou un fichier voisin
  `MuscleMapFigureKey.swift` dans `MuscleMap/`)
- Test : `Packages/PulseDesignSystem/Tests/PulseDesignSystemTests/MuscleMapTests.swift`

**Interfaces :**
- Consumes : `MuscleMapFigure` (Task 1).
- Produces :
  - JSON : `{"license": …, "female": {"front": Side, "back": Side}, "male": {"front": Side, "back": Side}}`, `Side`
    inchangé (`viewBox`, `body`, `regions`, `layers`).
  - `MuscleMapArtwork` : `body(_:figure:)`, `regions(_:figure:)`, `layers(_:figure:)`, `viewBox(_:figure:)`, chacun
    `(_ side: MuscleMapSide, figure: MuscleMapFigure)`, sans valeur par défaut.
  - `EnvironmentValues.muscleMapFigure: MuscleMapFigure`, `@Entry`, défaut `.female`.
  - `MuscleMapView` : même init qu'aujourd'hui ; lit `@Environment(\.muscleMapFigure)`.

- [ ] **Step 1 : écrire le script `scripts/musclemap_from_swift.py`**

Usage : `python3 -I scripts/musclemap_from_swift.py <dossier Data amont> <musclemap.json>`. Il garde `license` du JSON
existant et réécrit le fichier (`indent=1`, `ensure_ascii=False`, saut de ligne final, comme l'ancien script). Pour chaque
fichier `{Female,Male}{Front,Back}Paths.swift` :
- chaque `BodyPartPathData(slug: .x, …)` donne un calque ; ses tracés sont `common`, puis `left`, puis `right` ;
- un `slug` absent de `MuscleMapRegion` (neck, head, hair, hands, knees, ankles, feet) devient `"body"` ;
- ordre de dessin : d'abord les calques qui ne sont pas en surimpression, dans l'ordre du fichier, puis les 13 régions en
  surimpression (`isOverlay`), dans l'ordre du fichier. Cette règle reproduit exactement le corps de femme actuel
  (vérifié) ;
- `body` et `regions` sont les mêmes tracés, regroupés ;
- `viewBox` en dur, d'après `BodyPathData.swift` amont : femme face `[0, 0, 650, 1450]`, dos `[823, 0, 650, 1450]` ;
  homme face `[0, 95, 727, 1280]`, dos `[718, 95, 727, 1280]`.

- [ ] **Step 2 : régénérer et vérifier le corps de femme**

Télécharger les 4 fichiers Swift du commit amont épinglé dans un dossier neuf du scratchpad (avec `gh api …/contents/…?ref=<sha>`),
lancer le script, puis :

Run : `python3 -I -c "import json,subprocess; old=json.loads(subprocess.check_output(['git','show','HEAD:Packages/PulseDesignSystem/Sources/PulseDesignSystem/Resources/musclemap.json'])); new=json.load(open('Packages/PulseDesignSystem/Sources/PulseDesignSystem/Resources/musclemap.json')); print(old['front']==new['female']['front'], old['back']==new['female']['back'], old['license']==new['license'])"`
Expected : `True True True`

- [ ] **Step 3 : écrire les tests qui échouent**

Les tests existants passent `figure: .female` (valeurs inchangées). Nouveaux tests :

```swift
@Test(arguments: MuscleMapFigure.allCases)
func eachFigureDrawsEveryRegion(_ figure: MuscleMapFigure) {
    let art = MuscleMapArtwork.bundled
    let drawn = Set(art.regions(.front, figure: figure).keys).union(art.regions(.back, figure: figure).keys)
    #expect(Set(MuscleMapRegion.allCases) == drawn)
    #expect(!art.body(.front, figure: figure).isEmpty && !art.body(.back, figure: figure).isEmpty)
}

@Test func maleViewBoxesKeepTheirOrigin() {
    let art = MuscleMapArtwork.bundled
    #expect(art.viewBox(.front, figure: .male) == CGRect(x: 0, y: 95, width: 727, height: 1280))
    #expect(art.viewBox(.back, figure: .male) == CGRect(x: 718, y: 95, width: 727, height: 1280))
}

/// Un tracé illisible serait avalé par `try?` : on compte ce qui a été lu.
@Test func everyPathParses() {
    let art = MuscleMapArtwork.bundled
    func count(_ side: MuscleMapSide, _ figure: MuscleMapFigure) -> Int {
        art.layers(side, figure: figure).reduce(0) { $0 + $1.paths.count }
    }
    #expect(count(.front, .female) == 124 && count(.back, .female) == 78)
    #expect(count(.front, .male) == 123 && count(.back, .male) == 78)
}

@Test func maleLayersFollowTheDrawRule() {
    let art = MuscleMapArtwork.bundled
    #expect(art.layers(.front, figure: .male).count == 29)
    #expect(art.layers(.back, figure: .male).count == 21)
    // Pour les deux côtés : aucune région en surimpression avant la dernière région de base,
    // et `layered == flat` comme dans layerCountMatchesTheSvgGroups.
}
```

`backPathsLieInsideTheBackViewBox` devient paramétré sur `MuscleMapFigure.allCases`.

- [ ] **Step 4 : lancer, constater l'échec**

Run : `swift test --package-path Packages/PulseDesignSystem --filter MuscleMap`
Expected : échec de compilation sur `figure:`.

- [ ] **Step 5 : implémenter**

`MuscleMapArtwork` décode `female` et `male` (chacun `front` / `back`) et garde quatre `Silhouette`. Une ressource
illisible donne toujours des silhouettes vides. `MuscleMapView` passe la silhouette de l'environnement à `viewBox` et
`layers`. Mettre à jour le commentaire de `MuscleMapArtwork` (« Les silhouettes MuscleMap de femme et d'homme… ») et
ajouter un aperçu `#Preview("Silhouette d'homme")` avec `.environment(\.muscleMapFigure, .male)`.

- [ ] **Step 6 : lancer le package et le lint**

Run : `swift test --package-path Packages/PulseDesignSystem && swiftlint lint --strict`
Expected : tout passe, 0 violation.

- [ ] **Step 7 : commit** (vérifier la branche et `git status` : le script est un fichier nouveau)

```bash
git add scripts/musclemap_from_swift.py Packages/PulseDesignSystem && git rm -q scripts/extract_musclemap.py
git commit -m "feat(design): male muscle map silhouette next to the female one"
```

### Task 3 : brancher le profil, le refresher et les widgets

**Files :**
- Modify : `Pulse/Root/AppRootModel.swift`, `Pulse/Root/AppRootView.swift`
- Modify : `Packages/PulseFeatures/Sources/PulseServices/Refresh/DayRefresher.swift`
- Modify : `Packages/PulseFeatures/Sources/WidgetFeature/TodaySessionWidgetContent.swift`,
  `WeekWidgetContent.swift`, `Views/TodaySessionWidgetMediumView.swift`, `Views/WeekWidgetLargeView.swift`
- Test : `Packages/PulseFeatures/Tests/PulseServicesTests/DayRefresherTests.swift`,
  `Packages/PulseFeatures/Tests/WidgetFeatureTests/TodaySessionWidgetContentTests.swift`,
  `Packages/PulseFeatures/Tests/WidgetFeatureTests/PlanningWidgetsContentTests.swift` (celui qui couvre `WeekWidgetContent`)

**Interfaces :**
- Consumes : `MuscleMapFigure`, `WidgetSnapshot.muscleMapFigure` (Task 1) ; `\.muscleMapFigure` (Task 2).
- Produces :
  - `AppRootModel.muscleMapFigure: MuscleMapFigure` = `MuscleMapFigure(sex: profile?.sex ?? .unspecified)`.
  - `DayRefresher.snapshot(_:session:profile: UserProfile?)` remplit `muscleMapFigure` ; `publish(_:plan:)` passe le
    profil chargé par `loadProfile()`.
  - `TodaySessionWidgetContent.muscleMapFigure` et `WeekWidgetContent.muscleMapFigure: MuscleMapFigure`
    (`snapshot?.muscleMapFigure ?? .female` ; paramètre d'init `= .female` placé en dernier).

- [ ] **Step 1 : écrire les tests qui échouent**

```swift
// DayRefresherTests
@Test func publishedSnapshotCarriesTheProfileFigure() async throws {
    // Profil enregistré avec `sex: .male`, passage au premier plan qui publie : `published.last?.muscleMapFigure == .male`.
}
// Le test existant foregroundRefreshScoresPlansAndPublishes attend désormais `muscleMapFigure: .female`
// (profil de la fixture en `.unspecified`).

// TodaySessionWidgetContentTests et le test de WeekWidgetContent
@Test func contentFollowsTheSnapshotFigure() {
    // Instantané du jour avec `.male` → `content.muscleMapFigure == .male` ; même instantané avec `nil` → `.female`.
}
```

- [ ] **Step 2 : lancer, constater l'échec**

Run : `swift test --package-path Packages/PulseFeatures --filter "DayRefresher|WidgetContent"`
Expected : échec de compilation.

- [ ] **Step 3 : implémenter**

Racine : `.environment(\.muscleMapFigure, model.muscleMapFigure)` juste sous `.environment(\.pulseTheme, …)`. Widgets :
`.environment(\.muscleMapFigure, content.muscleMapFigure)` sur la `MuscleMapView` de chaque vue.

- [ ] **Step 4 : lancer les packages, le lint et la compilation Release**

Run : `make test-packages && swiftlint lint --strict && make build-release`
Expected : tout passe ; `make build-release` sans erreur (avec Xcode 27, `-quiet` n'affiche pas de bannière SUCCEEDED :
juger au code de sortie).

- [ ] **Step 5 : commit** (vérifier la branche d'abord)

```bash
git add Pulse/Root Packages/PulseFeatures
git commit -m "feat: muscle map follows the profile sex in the app and widgets"
```
