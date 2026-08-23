# 联机对局与关卡闯关 HUD ImageGen 提示词 V1

日期：2026-08-23
模式：内置 `image_gen`，两张图片分别生成

## 联机对局 HUD

```text
Use case: ui-mockup
Asset type: one standalone high-fidelity 16:9 desktop game screen
Primary request: Redesign only the active LAN multiplayer match HUD for 《雾疆：九路烽棋》. This is the in-match tactical board interface after both players have started the game, not the multiplayer room/lobby and not the level-select screen. Produce one full-screen, implementation-ready UI reference.
Input images: Image 1 is the current functional LAN match screen and defines the exact overall identity, battlefield board, fog, red/black force summaries, minimap, selected-piece card, objective/event panel, action confirmation and bronze base. Image 2 is an earlier battle HUD concept and defines a useful larger-board hierarchy and compact corner panels. Preserve the current project identity while substantially improving layout density and readability.
Composition/framing: true single 16:9 game screen at 1280×720-safe proportions. The tactical 9×24 board is the dominant focal area, about 68–72% of the usable canvas, centered and tall, with all nine routes readable. Use thin safe margins and reduce the oversized empty side gutters and decorative bronze base. A slim top-center turn bar shows round, active side and remaining time. Compact red and dark-jade force-summary plaques sit in the top corners. Left upper side: compact minimap panel. Left lower side: selected-unit card that visually supports a collapsed empty state and an expanded selected state. Right side: one clean objective-and-public-events drawer with no more than five readable rows. Bottom center: reusable action bar with five clear mode buttons and a contextual description strip. Put “确认行动” as the unmistakable primary action and “取消” as secondary.
Gameplay state shown: local red-side turn, one red soldier selected, legal movement cells and one intended path highlighted in restrained antique gold. Fog remains dark and observer-safe. No opponent cursor, target preview, hidden piece, or private marker is visible. Show one small local marker button without opening its menu.
Interaction cues: gold keyboard focus ring on “确认行动”; selected piece has a grounded ring and path pulse; current action mode is visibly selected; unavailable modes are clearly disabled; right drawer may be collapsed by a small chevron; minimap camera viewport is obvious. No annotation numbers, no comparison board, no explanatory callouts.
Style/medium: realistic shippable game UI mockup; dark Chinese military fantasy; matte forged iron, oxidized bronze, restrained antique gold, terracotta red and deep jade. Thin reusable 9-slice panels and Control-node-friendly rectangular containers. Lower ornament density than the current screenshot, higher text contrast, no cinematic concept-art layout.
Typography: expressive Chinese calligraphy only for atmospheric headings; clean legible simplified Chinese sans-serif for status, objective rows, action labels, numbers and buttons; warm ivory primary text; muted beige secondary text; disabled neutral gray.
Text (verbatim, render these important labels clearly): “第 18 回合”, “赤方行动”, “剩余 72 秒”, “赤方军势”, “玄方军势”, “战场态势”, “兵”, “战局与行动”, “我方已发现旗帜 1/3”, “我方阵亡：兵 ×1”, “敌方阵亡：炮 ×1”, “移动”, “炮击”, “士献祭”, “标记”, “跳过”, “确认行动”, “取消”, “兵：沿直线前进一格”.
Constraints: one screen only; in-match HUD only; no lobby controls, no room code, no campaign map, no level-selection categories; board grid must remain a precise-looking 9-route by 24-line tactical lattice; body text visually equivalent to at least 16 px at 1280×720; secondary text at least 14 px; buttons at least 48 px high; strong contrast; no tiny pseudo-text; no real-world brand logos; no watermark.
Avoid: multiplayer lobby, level-select page, split-screen comparison, cinematic splash art, giant empty borders, oversized bronze ornament, tall incense decorations consuming side space, tiny low-contrast text, cramped right panel, generated filler paragraphs, sci-fi neon, mobile-app styling.
```

参考输入：

- `evidence/gate2/v3-candidate-419e2ce/screenshots/match-1920x1080-red.png`
- `assets/art/ui/concepts/battle_hud_concept_v1.png`

## 关卡闯关 HUD

```text
Use case: ui-mockup
Asset type: one standalone high-fidelity 16:9 desktop game screen
Primary request: Redesign only the active campaign level gameplay HUD for 《雾疆：九路烽棋》, specifically the in-level T03 challenge/tutorial screen while the player is solving the board objective. This is not the level-select map and not a multiplayer lobby. Produce one full-screen implementation-ready UI reference.
Input images: Image 1 is the current level gameplay HUD direction and defines the multiplayer-style board shell with the right-side level information panel. Image 2 is the current functional match screen and defines the actual board, minimap, unit card and bronze/iron identity. Image 3 is an earlier T03 gameplay concept and defines the “田字封路” objective, selected elephant, target path and step checklist. Preserve the project identity but improve spacing, typography, focus and interaction flow.
Composition/framing: true single 16:9 game screen at 1280×720-safe proportions. The tactical 9×24 board is the dominant focal area, about 66–70% of usable canvas, centered and tall. A slim top-center level bar shows level title and progress instead of network round time. Compact red and dark-jade force-summary plaques remain in the top corners. Left upper side: compact minimap. Left lower side: selected-unit card with a clear collapse chevron and only essential stats/ability. Right side: one 360–400 px structured challenge drawer, using the same panel shell as the multiplayer objective drawer but internally reorganized into four readable zones: level objective, three-step checklist, current operation, and contextual hint. At the bottom of that drawer place “显示提示” and “重置步骤” as secondary actions. Bottom center: contextual action strip and large “确认移动” primary button plus “取消”.
Gameplay state shown: level “T03 · 田字封路”, step 1 of 3. A red elephant piece is selected. A legal L-shaped or diagonal teaching path toward a highlighted target intersection is clearly shown in restrained antique gold. The first checklist row is active, later rows are pending. Board overlays are precise and do not cover pieces. Fog remains dark and observer-safe.
Information hierarchy: first the board and target path, second the current step, third the goal summary, fourth optional hint. The player should be able to answer “what do I do now?” within one second. Avoid long prose. Do not place tutorial text over the board.
Interaction cues: gold keyboard focus ring on “确认移动”; current checklist row has a subtle red-and-gold active backing; target intersection pulses softly; “显示提示” shows a slight hover lift; “重置步骤” is secondary and visually quiet; right drawer has a small collapse chevron; unavailable actions are clearly disabled. No annotation numbers, no comparison board, no explanatory callouts.
Style/medium: realistic shippable game UI mockup; dark Chinese military fantasy; matte forged iron, oxidized bronze, restrained antique gold, terracotta red and deep jade; thin reusable 9-slice frames; Control-node-friendly rectangular containers; reduced ornament density and higher contrast than the references.
Typography: expressive Chinese calligraphy only for atmospheric panel headings; clean legible simplified Chinese sans-serif for objectives, steps, hints, numbers and buttons; warm ivory primary text, antique-gold emphasis, muted beige secondary text, neutral gray disabled text.
Text (verbatim, render these important labels clearly): “T03 · 田字封路”, “步骤 1/3”, “赤方军势”, “玄方军势”, “战场态势”, “相”, “关卡目标”, “相象训练：田字封路”, “选择红相”, “移动至目标点”, “判断敌卒停止点”, “当前操作”, “请选择目标交点”, “提示”, “田字区域将阻挡敌方车与兵卒”, “显示提示”, “重置步骤”, “移动”, “标记”, “确认移动”, “取消”, “退出关卡”.
Constraints: one screen only; in-level challenge gameplay only; no campaign route map, no T01–T11 node list, no lobby room code, no online readiness controls; board grid must remain a precise-looking 9-route by 24-line tactical lattice; body text visually equivalent to at least 16 px at 1280×720; secondary text at least 14 px; buttons at least 48 px high; strong contrast; no tiny pseudo-text; no real-world brand logos; no watermark.
Avoid: level-select page, multiplayer lobby, split-screen comparison, cinematic splash art, huge empty side gutters, oversized decorative base, tall incense decorations consuming side space, tiny tutorial copy, cramped right panel, scrollbars inside narrow text boxes, generated filler paragraphs, sci-fi neon, mobile-app styling.
```

参考输入：

- `assets/art/ui/concepts/tutorial_hud_concept_v4_multiplayer_style_reuse_objective_panel_t0.png`
- `evidence/gate2/v3-candidate-419e2ce/screenshots/match-1920x1080-red.png`
- `assets/art/ui/concepts/level_gameplay_hud_concept_v1_t03_field_lattice.png`
