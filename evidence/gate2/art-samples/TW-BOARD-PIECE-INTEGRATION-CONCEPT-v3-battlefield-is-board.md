# 兵马俑“战场即棋盘”概念图 V3

日期：2026-08-20

状态：`awaiting_owner_visual_review / concept_only / not_geometry_evidence`

参考图：`evidence/gate2/art-samples/review/TW-BOARD-PIECE-INTEGRATION-CONCEPT-v3-battlefield-is-board.png`

## 核心方向

不再把棋盘表现为“摆在战场上的完整矩形物体”，而是让战场本身承担棋盘规则：

- 取消完整矩形外框、台面、角柱和方形铺装；可玩区域的外形由壕沟、残垣、土垒、断崖、车辙和秦军残破工事自然收口。
- 24×9规则意图改由埋入焦土的细青铜军阵轨迹与交点阵钉表达，形成“秦军测绘阵列/军阵工程”语言，而非桌面棋盘语言。
- 交点使用浅金属承托窝或阵钉，使金属棋子看起来真正落在战场规则节点上，同时避免圆形棋子底座。
- 地表以低反射焦土为主，青铜阵轨、阵钉、破损甲片和两方材质碎片只提供克制金属高光，用材质呼应银白钨钢与墨绿青铜棋子。

## 相对V2的变化

- V2的战损矩形石框和规则台面被完全取消。
- 规则区域与外围环境使用同一连续地形，不设传统河界、区域标签或完整边界线。
- 近端通过冷银钢片和低矮指挥土工呼应银白方；远端通过氧化墨绿青铜残片和土垒呼应墨绿方；中央保持连续焦土无人地带。
- 外围轮廓改为不规则战地结构，因此远看先读作战场，细看才发现军阵网格。

## Godot生产转译

- 权威规则仍为预置节点承载的精确24×9交点，共216点；生成图中的格数、比例和棋子数量不作为生产事实。
- 在不规则地形Mesh上方预置216个低矮青铜阵钉，并用细青铜轨连接；规则坐标、点击和落位继续使用既有一基`Vector2i`事实源。
- 地形Mesh可以越过规则区域自由延伸，但任何残垣、旗帜、火盆或车辙都不得遮挡交点和棋子轮廓。
- 棋子脚底/马蹄/器械接地点对齐交点承托窝；不新增会改变既有透明棋子轮廓的大型圆底座。
- 地面保持粗糙、低亮度；只有阵轨、阵钉、两方残片和金色职位字承担金属高光，确保棋子仍是视觉主体。

## 使用边界

本图只用于“兵马俑”管线的审美方向评审，不批准正式棋盘生产，也不证明精确24×9几何、32枚落位、双方180°视角、96px可读性、遮挡、点击或PlayerView信息安全。正式实现必须在Godot预置场景中确定性完成。

## 最终编辑提示词

```text
Use case: precise object edit and environment redesign for a game art direction review.

Reference roles:
- Reference image 1 is the edit target. Preserve its wide cinematic oblique camera, overall opposing army layout, readable battlefield scale, and the placement logic of the metallic chess armies.
- Reference image 2 is the authoritative character/piece design sheet. Preserve the two factions and piece identities: near faction bright silver-white tungsten-steel terracotta-warrior pieces; far faction very dark ink-green patinated-bronze terracotta-warrior pieces; smooth featureless masks, Qin armor language, restrained gold Qin small-seal-script role glyphs, metallic material response. Preserve the distinctive traction trebuchets, cavalry, chariots, officials, attendants and generals. Do not replace them with generic chess tokens.

Primary redesign — “the battlefield itself is the board”:
Transform the complete rectangular board/slab in reference image 1 into a continuous natural battlefield. Remove the full rectangular outer stone frame, raised tabletop slab, conventional chessboard silhouette, decorative corner blocks, and all obvious board borders. The playable area must have an organic irregular elongated landform whose visible outer contour is naturally created by trenches, collapsed earthen ramparts, eroded escarpments, wheel ruts, ruined Qin palisades, burned timber and broken fieldworks.

Keep the intended game-rule structure legible as a long, straight, precise 24-by-9 intersection formation embedded within the terrain, but express it as thin patinated-bronze military survey rails set flush into compacted scorched earth. Put a small metal formation stud / military survey nail at every intended intersection, with shallow bronze sockets or contact pads that visually seat the metal pieces. The rails and studs should feel like Qin military engineering and a ritual campaign map made real, not like painted chessboard lines. No square tiles. No solid rectangular floor. No conventional river band. Terrain, ash, cracks and wheel tracks flow continuously through the formation.

Material integration:
Let the battlefield carry selective metal elements that harmonize with the pieces: buried and shattered dark-bronze armor plates at terrain transitions, thin bronze rails, worn metal studs, cold steel fragments near the silver side, oxidized green-bronze fragments near the dark side. Keep most earth matte and low-contrast so the highly reflective metallic pieces remain readable. Metallic highlights should be clear but controlled.
- Near end: a low, irregular silver-side command earthwork with cold pale steel debris and cool highlights.
- Far end: a low, irregular ink-green-bronze earthen fortification with oxidized bronze debris.
- Center: continuous scorched no-man's-land, no artificial dividing stripe.

Composition:
Wide 16:9 key art, about 50–55 degree oblique tactical view, low field-of-view / near-orthographic clarity. Show the entire elongated formation and enough irregular surrounding battlefield to prove there is no rectangular board. Keep both armies in Chinese-chess-inspired opposing deployment. Maintain generous spacing and strong silhouettes; do not let any terrain prop cover an intersection or overlap a piece. The formation rails can fade subtly into dirt near the organic edges but must remain readable across the active area.

Lighting and mood:
Cinematic overcast Qin battlefield after a siege, restrained smoke on the far horizon only, warm grazing light catching bronze rails and gold glyphs, cooler reflection on the silver-white pieces, rich dark green-black response on bronze pieces. Premium realistic game concept art, physically based metal, grounded dirt, ash and weathering.

Hard constraints:
- No complete rectangular frame, no table, no board slab, no checkerboard tiles.
- No giant literal chessboard, no conventional river, no region labels, no coordinate text, no UI.
- No extra infantry, no bodies, no gore, no heavy foreground smoke.
- Do not turn pieces into round tokens or statues on large circular bases.
- Do not alter faction colors or swap sides.
- Preserve the distinctive existing piece designs and readable gold role glyph accents.
- Avoid sci-fi neon, blue emissive strips, purple glow, excessive fantasy ornament.
- This is a single complete environmental concept image, not a contact sheet, diagram, poster, or annotated presentation.
```

## 待项目所有者判断

- 是否接受“战场即棋盘”作为下一轮正式Godot样片方向；
- 青铜阵轨是否仍显得过于规则，是否要在不损害读格的前提下进一步压入泥土；
- 外围残垣和旗帜密度是否需要再减一档，让棋子与阵轨更突出。
