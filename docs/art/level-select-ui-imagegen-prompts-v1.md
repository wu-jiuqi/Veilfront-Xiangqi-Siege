# 关卡模式 UI ImageGen 提示词 v1

状态：`deprecated_for_level_select_runtime`。当前母版拆件提示词见 `docs/art/level-select-ui-imagegen-prompts-v2.md`。

生成模式：Codex 内置 `image_gen`。

## 1. 概念母稿

```text
Use case: ui-mockup
Asset type: 16:9 desktop game level-selection screen concept for a Godot strategy game, 1280x720 composition
Primary request: Create the first production concept for the level mode UI of 《雾疆：九路烽棋》, using the provided main-menu gate, battle HUD and battlefield images only as visual-language references. The screen is a bronze military-command campaign map, not a generic card grid.
Scene/backdrop: desaturated 90-degree top-down battlefield relief map under charcoal mist, heavily dimmed so UI stays readable.
Subject/layout: left narrow column with tutorial/challenge tabs and total progress; center large scrollable military route with tutorial mission nodes; right detail panel with mission code, title, objective, status and one enter button. Top header reads “关卡模式”, back button reads “返回”.
Style/medium: realistic polished raster-painted Chinese ancient war fantasy UI; dark neutral hammered metal, deep ink-green oxidized bronze, tungsten-silver worn edges, restrained old-gold highlights, muted vermilion only for danger.
Composition/framing: exact landscape 16:9 full-screen UI, front-facing orthographic interface, safe margins, no perspective distortion of panels.
Materials/textures: hammered black metal, aged bronze, shallow carved Qin geometric borders, worn stone-map surface; practical 9-slice-friendly rectangular panels.
Constraints: no logos; no watermark; no SVG; no flat vector art; no modern sci-fi; no bright blue; no mobile layout; no decorative chess-piece clutter; clear focus states; readable at 1280x720.
```

## 2. 战役地图背景

```text
Use case: stylized-concept
Asset type: raster game UI background for a Godot level selection screen, exact 16:9 landscape
Primary request: Extract the central campaign-map mood from the concept into a reusable background layer only. Show a desaturated top-down relief map of a ruined ancient Chinese battlefield and Great Wall switchbacks under charcoal mist.
Style/medium: realistic raster-painted game background, dark Chinese ancient war fantasy.
Composition/framing: 16:9 orthographic top-down map; center and right remain visually quiet for overlaid UI; no interface panels; no mission nodes; no route line; no buttons.
Lighting/mood: low-key smoky tactical mood, very subdued contrast, edges darker than center.
Color palette: charcoal black, dark stone brown, deep ink green, tiny restrained aged-bronze terrain accents.
Constraints: no text, symbols, logos, watermark, SVG, vector art, UI frames, chess pieces, bright blue or baked checkerboard; clean opaque raster TextureRect background.
```

## 3. 关卡节点五状态图集

```text
Use case: stylized-concept
Asset type: transparent raster sprite sheet for Godot level-selection mission nodes
Primary request: Create one clean horizontal sprite sheet containing exactly five isolated circular mission-node frames, left to right: available normal, hover/focused, selected, completed, locked. Match dark hammered metal, oxidized bronze, tungsten-silver edge and aged-gold highlights.
Composition/framing: one row of five equal-size circular medallions; identical diameter and silhouette; centered in equal cells; generous transparent spacing; no overlap.
State details: normal = dark bronze rim; hover/focused = thin pale-gold rim; selected = warm old-gold halo and top chevron; completed = gold check seal; locked = dark rim with chain-and-lock emblem. Keep centers empty for Godot labels.
Style/medium: realistic raster-painted game UI sprites, crisp at 96px, not vector art.
Constraints: genuine alpha transparency; no checkerboard; no text, numbers, letters, logos, watermark, SVG, vector art, square plates or extra objects; exactly five uniformly aligned nodes.
```

## 参考资源

- `assets/art/ui/concepts/main_menu_start_screen_v6_click_anywhere.png`
- `assets/art/ui/concepts/battle_hud_concept_v1.png`
- `assets/art/ui/lan_lobby/lan_lobby_board_backdrop_v1.png`
- `assets/art/ui/terracotta_hud_v2/action_button_states_v1.png`
