# 关卡模式 UI 母版拆件提示词 v2

生成模式：Codex 内置 `image_gen`。

输入图：`assets/art/ui/level_select/source/level_select_approved_master_v2.png`，角色为唯一视觉母版与编辑目标。

## 空界面底板

```text
Use case: precise-object-edit
Input image: Image 1 is the approved final level-select UI master and the sole visual source.
Asset type: production game UI background plate, 16:9 landscape.
Primary request: Create a clean EMPTY BACKGROUND PLATE from Image 1. Preserve the complete blackened bronze/iron Chinese war-fantasy screen background, every large ornamental rectangular frame, the top title plaque frame, left column panel frames, central campaign-map frame and monochrome city map, the glowing route lines and route dots, the right detail panel frames, the bottom footer strip, all lighting, materials, texture, layout, camera framing and proportions.
Remove only all interactive control faces and all dynamic content: remove the back-button face and arrow/text, remove both left category-button inner illustrations and their labels while keeping their outer slots as empty dark framed recesses, remove every circular mission node including locks/checkmarks/arrows while reconstructing the map underneath, remove all dynamic title/detail/progress/reward/keyboard text and symbols, remove the enter-button face and label while keeping an empty dark framed recess in its exact location. The top title plaque should remain as an empty ornamental plaque with no text.
Constraints: exact same 16:9 composition and layout; preserve surrounding pixels and visual identity as faithfully as possible; no redesign; no new ornaments; no extra objects; no text anywhere; no SVG/vector look; raster painted texture; no watermark.
```

## 紫幕控件图集

```text
Use case: background-extraction with chroma screen
Input image: Image 1 is the approved final level-select UI master and the sole visual source.
Asset type: production game UI component atlas on a SOLID PURPLE CHROMA SCREEN.
Primary request: Extract and faithfully reconstruct the reusable control faces from Image 1. Arrange components in a strict orthogonal atlas with generous separation and no overlaps.
Row 1: compact back-button plate with arrow/text removed; wide bright-gold enter-button plate with text removed.
Row 2: large selected category-card face matching the glowing tutorial card with illustration/emblem/text removed; large unselected category-card face matching the challenge card with illustration/emblem/text removed.
Row 3: five equal circular mission-node faces: available dark-bronze; completed with gold check mark; selected glowing gold with top pointer; locked with chains and padlock; disabled/dim locked. Remove all mission-node text.
Row 4: small square reward-slot frame; small square keyboard-key frame; circular bronze progress-ring with no number; small empty secondary rectangular button plate.
Background: one single perfectly flat, perfectly uniform chroma-key purple color #7B00FF covering every pixel outside the components. No checkerboard. No texture, gradient, vignette, light spill, shadow, noise or color variation in the purple background.
Style/medium: exact source blackened iron, engraved bronze, worn gold leaf, low-saturation Eastern war-fantasy painted raster UI.
Constraints: front-facing; preserve crisp isolated silhouettes and source materials; no map; no panel background; no labels, letters or numbers; no extra symbols except requested check mark, pointer, chains and locks; no SVG/vector look; no watermark. Keep all components separated from one another for clean chroma-key extraction.
```
