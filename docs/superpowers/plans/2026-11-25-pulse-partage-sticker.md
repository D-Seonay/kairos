# Partage : l'image sans fond (sticker) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Offer a transparent PNG of the share card ("Sans fond") that can be copied and pasted as a sticker on one's own story photo.

**Architecture:** `ShareCardView` gains a sticker mode (no background, white ink with a soft shadow, height fitted to the content). `ShareCardRenderer.stickerImage` renders it non-opaque at 1 080 px wide. The sheet gets a "Sans fond" background tile, hides the format picker in that mode, previews over a checkerboard and adds a "Copier" button backed by `ShareCardPasteboard`.

**Tech Stack:** SwiftUI `ImageRenderer`, ImageIO, `UIPasteboard` (iOS) / `NSPasteboard` (macOS, for the package tests), Swift Testing.

**Spec:** `docs/superpowers/specs/2026-11-25-pulse-partage-rapide-design.md`, section « Lot 3 ».

## Global Constraints

- Package `Packages/PulseDesignSystem`, Swift 6 language mode, iOS 26 / macOS 26; the package must still build and test on macOS (`#if os(iOS)` around UIKit).
- Copy is French, `String(localized:bundle: .module)`: « Sans fond », « Copier », « Copiée, colle-la dans ta story ».
- Sticker width is 1 080 px (`360 pt × ShareCardFormat.scale`); height follows the content.
- White ink and a shadow only, no black-ink option.
- Never launch the simulator: verify with `swift test --package-path Packages/PulseDesignSystem`, `swiftlint lint --strict`, and `xcodebuild build` (Debug and Release, generic iOS).

## Review Focus

- A record (`.hero`) or a night (`.hypnogram`) sticker: both must render with ink inside and transparent edges, not just the session card (Task 1, test `everyVisualRendersASticker`).
- A card with no drawing (`.none`) and one metric: the sticker shrinks to its text, with no empty block (Task 1, test `stickerHeightFollowsTheContent`).
- Switching Story ↔ Publication while « Sans fond » is selected must not render twice or show a different image (Task 2, test `stickerKeyIgnoresTheFormat`).
- A sheet opened without session photos (records, night, run) must still show the background row with « Trame Pulse » and « Sans fond » (Task 2, by construction; check in the code review).
- The shared file name must not clash with the card's: « Pulse - Push (sans fond).png » (Task 1, test `stickerFileNameSaysSansFond`).

---

### Task 1: Sticker rendering

**Files:**
- Modify: `Packages/PulseDesignSystem/Sources/PulseDesignSystem/Share/ShareCardView.swift`
- Modify: `Packages/PulseDesignSystem/Sources/PulseDesignSystem/Share/ShareCardRenderer.swift`
- Modify: `Packages/PulseDesignSystem/Sources/PulseDesignSystem/Share/ShareCardContent.swift`
- Test: `Packages/PulseDesignSystem/Tests/PulseDesignSystemTests/ShareCardTests.swift`

**Interfaces:**
- Produces: `ShareCardView.init(content:format:photo:isSticker: Bool = false)`; `ShareCardRenderer.stickerImage(content: ShareCardContent, theme: Theme = .amber, figure: MuscleMapFigure = .female) -> CGImage?` (`@MainActor`); `ShareCardContent.stickerFileName: String`.

- [ ] **Step 1: Write the failing tests** in `ShareCardTests.swift`, with a test helper `alpha(of image: CGImage, x: Int, y: Int) -> UInt8` that draws the image into a premultiplied RGBA `CGContext` and reads the byte.

```swift
@MainActor
@Test func stickerIsTenEightyWideWithTransparentEdges() throws {
    let image = try #require(ShareCardRenderer.stickerImage(content: .previewSession))
    #expect(image.width == 1_080)
    #expect(image.height > 0 && image.height < 1_920)
    #expect(alpha(of: image, x: 0, y: 0) == 0)
    #expect(alpha(of: image, x: image.width - 1, y: image.height - 1) == 0)
    let png = try #require(ShareCardRenderer.png(image))
    #expect(png.starts(with: [0x89, 0x50, 0x4E, 0x47]))
}

@MainActor
@Test func everyVisualRendersASticker() throws {
    for card in [ShareCardContent.previewSession, .previewRun, .previewRecord, .previewNight] {
        let image = try #require(ShareCardRenderer.stickerImage(content: card))
        #expect(image.width == 1_080)
        #expect(alpha(of: image, x: 0, y: 0) == 0)
        // Some ink somewhere: scan a column through the middle.
        #expect((0..<image.height).contains { alpha(of: image, x: image.width / 2, y: $0) > 0 })
    }
}

@MainActor
@Test func stickerHeightFollowsTheContent() throws {
    let small = content(metrics: [ShareCardMetric(value: "18", label: "Séries")], visual: .none)
    let tall = try #require(ShareCardRenderer.stickerImage(content: .previewSession))
    let short = try #require(ShareCardRenderer.stickerImage(content: small))
    #expect(short.height < tall.height)
}

@Test func stickerFileNameSaysSansFond() {
    #expect(ShareCardContent.previewSession.stickerFileName == "Pulse - Push (sans fond).png")
}
```

(`content(metrics:visual:)` is the helper already at the top of the file; adjust its call if its parameters differ.)

- [ ] **Step 2: Run them and see them fail**

Run: `swift test --package-path Packages/PulseDesignSystem --filter ShareCardTests`
Expected: compile error, `stickerImage` / `stickerFileName` not found.

- [ ] **Step 3: Implement**
  - `ShareCardContent.stickerFileName`: `fileName` with `.png` replaced by ` (sans fond).png` (« Pulse (sans fond).png » for an empty title).
  - `ShareCardView`, when `isSticker`:
    - no `.background`; the frame is `width: format.size.width` with no fixed height (`fixedSize(horizontal: false, vertical: true)`), so the height is the content's;
    - the drawing gets a fixed height instead of `maxHeight: .infinity`: muscles 240, route 220, hypnogram 170, hero its own size (`fixedSize(vertical)`), `.none` nothing at all (no spacer, no vertical padding);
    - the whole content gets `.compositingGroup().shadow(color: .black.opacity(0.5), radius: 6, y: 1)`, so the shadow lines the ink without doubling on overlaps;
    - topBar, title, metrics, highlights and footer stay as they are; `format` is ignored for sizes (use the story sizes, `isStory` true).
  - `ShareCardRenderer.stickerImage`: `ShareCardView(content:format: .story, isSticker: true)` with the same theme and figure environment as `cgImage`, `renderer.isOpaque = false`, `renderer.proposedSize = ProposedViewSize(width: ShareCardFormat.story.size.width, height: nil)`, `renderer.scale = ShareCardFormat.scale`.
  - Add a `#Preview("Sticker, séance")` over a dark grey background.

- [ ] **Step 4: Run the tests and see them pass**

Run: `swift test --package-path Packages/PulseDesignSystem --filter ShareCardTests`
Expected: all ShareCardTests pass, the existing ones included.

- [ ] **Step 5: Commit**

```bash
git add Packages/PulseDesignSystem/Sources/PulseDesignSystem/Share Packages/PulseDesignSystem/Tests/PulseDesignSystemTests/ShareCardTests.swift
git commit -m "feat(design): transparent sticker version of the share card, fitted to its content"
```

### Task 2: « Sans fond » in the sheet, and « Copier »

**Files:**
- Create: `Packages/PulseDesignSystem/Sources/PulseDesignSystem/Share/ShareCardPasteboard.swift`
- Modify: `Packages/PulseDesignSystem/Sources/PulseDesignSystem/Share/ShareCardSheet.swift`
- Test: `Packages/PulseDesignSystem/Tests/PulseDesignSystemTests/ShareCardTests.swift`

**Interfaces:**
- Consumes: `ShareCardRenderer.stickerImage(content:theme:figure:)`, `ShareCardContent.stickerFileName` (Task 1).
- Produces: `ShareCardBackground.transparent`; `RenderKey` becomes internal with `init(format: ShareCardFormat, background: ShareCardBackground)` that stores `.story` whenever the background is `.transparent`; `ShareCardPasteboard.copy(png: Data)` (`@MainActor`); `ShareCardIdentifiers.copy = "share.card.copy"`.

- [ ] **Step 1: Write the failing test**

```swift
@Test func stickerKeyIgnoresTheFormat() {
    #expect(RenderKey(format: .story, background: .transparent) == RenderKey(format: .post, background: .transparent))
    #expect(RenderKey(format: .story, background: .pattern) != RenderKey(format: .post, background: .pattern))
}
```

- [ ] **Step 2: Run it and see it fail**

Run: `swift test --package-path Packages/PulseDesignSystem --filter stickerKeyIgnoresTheFormat`
Expected: compile error (`RenderKey` is private, `.transparent` does not exist).

- [ ] **Step 3: Implement**
  - `ShareCardPasteboard.copy(png:)`: iOS `UIPasteboard.general.setData(png, forPasteboardType: UTType.png.identifier)`; macOS `NSPasteboard.general.clearContents()` then `setData(png, forType: .png)`.
  - `ShareCardSheet`:
    - `render` uses `stickerImage` and `stickerFileName` for `.transparent`;
    - the format `Picker` shows only when `background != .transparent`;
    - `ShareBackgroundPicker` always shows; its tiles: « Trame Pulse », « Sans fond » (a checkerboard tile), then the photos;
    - the preview of a sticker sits on a checkerboard (`ShareCheckerboard`, a `Canvas` of 8 pt squares in `PulsePalette.surface2` / `PulsePalette.surface`), keeps `scaledToFit` and the rounded clip;
    - in sticker mode, the button row is `HStack { Copier ; Partager }`. « Copier » (`doc.on.doc`, `SecondaryButtonStyle` if it exists, else the bordered style the design system uses) calls `ShareCardPasteboard.copy`, then `PulseHaptics.success()` if that exists (else `selection()`), shows « Copiée, colle-la dans ta story » under the buttons for 2 s, and posts it with `PulseAnnouncement.post`. Disabled until the sticker is rendered.

- [ ] **Step 4: Run the package tests and the lint**

Run: `swift test --package-path Packages/PulseDesignSystem` then `swiftlint lint --strict`
Expected: all tests pass, 0 violations.

- [ ] **Step 5: Build the app, Debug and Release**

Run: `xcodebuild build -scheme Pulse -destination 'generic/platform=iOS' -configuration Debug -quiet` then the same with `-configuration Release`
Expected: exit code 0 both times.

- [ ] **Step 6: Commit**

```bash
git add Packages/PulseDesignSystem/Sources/PulseDesignSystem/Share Packages/PulseDesignSystem/Tests/PulseDesignSystemTests/ShareCardTests.swift
git commit -m "feat(share): Sans fond background with a Copier button to paste the card as a story sticker"
```
