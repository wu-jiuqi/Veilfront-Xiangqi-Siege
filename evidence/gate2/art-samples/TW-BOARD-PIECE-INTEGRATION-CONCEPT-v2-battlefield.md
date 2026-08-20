# 兵马俑棋盘战场化概念图 V2

日期：2026-08-20  
状态：`awaiting_owner_visual_review / concept_only / not_geometry_evidence`

参考图：`evidence/gate2/art-samples/review/TW-BOARD-PIECE-INTEGRATION-CONCEPT-v2-battlefield.png`

## 相对V1的单项修订

保留V1的完整棋子、阵营、镜头和长棋盘构图，只把棋盘表面、外围框架与环境从“精致秦式礼器沙盘”改成“战损秦军阵地”。

- 棋盘表面：压实焦土、干裂泥地、碎石、车辙、马蹄印、浅弹坑和克制焦痕。
- 网格：继续使用连续旧金/青铜嵌线，必须压在战场纹理之上保持清晰。
- 外围：华丽包边降级为低矮战损青铜护板、焦木梁、土垒和磨损角件。
- 场外：断旗、箭簇、残盾、低矮栅栏、远处烟柱和地表扬尘，只提供战场气氛，不进入交点区域。
- 灯光：烟尘阴天下的低角度战场暖光，银白阵营保持亮度，远端墨绿阵营保持轮廓分离。

## 使用边界

本图仍只用于美术方向审查。正式24×9网格、32枚棋子落位、Sprite3D锚点、双方视角、遮挡与信息边界必须在Godot预置场景中确定性实现。本图中的外围旗帜文字、阵地细节和生成式几何不能直接切出作为交付资产。

## 最终编辑提示词

```text
Use case: precise-object-edit
Asset type: V2 game environment concept art for the “兵马俑” board

Input images:
- Image 1: edit target. Preserve the complete camera angle, long-board framing, all existing chess pieces, faction placement, piece silhouettes, scale hierarchy and readable gold role glyphs.
- Image 2: authoritative supporting reference for the existing piece designs and faction materials. Do not redesign the pieces.

Primary request:
Change only the board surface, board perimeter and surrounding environment so the entire board feels like an active ancient Qin battlefield rather than a pristine ceremonial museum game board.

Battlefield transformation:
- Replace the clean charcoal slab surface with layered compacted dark battlefield earth: dry cracked mud, embedded gravel, trampled dust, subtle wheel ruts, hoof marks, shallow impact scars, restrained blackened scorch patches and sparse dead grass.
- Keep every grid line completely visible. The precise aged-bronze/gold intersection grid must remain straight, continuous, evenly spaced and unobstructed, but make it feel physically hammered or inlaid into the packed earth.
- Reduce the elegant ornamental frame. Transform it into a low, practical Qin field-fortification perimeter made from battered dark bronze armor plates, charred timber beams, compacted earth berms and worn corner guards. Keep only sparse Qin geometric motifs as military identification.
- Add restrained battle evidence only outside the playable intersections: several broken spear shafts, a few arrows embedded in the outer berm, torn dark-red and ink-green banner fragments, discarded shield fragments, distant low watchfires and windblown dust.
- Beyond the board, extend into a bleak ancient battlefield: low earthen ridges, faint palisade silhouettes, distant army banners and thin smoke columns. Keep all background elements low and soft so the board and pieces remain dominant.
- Suggest that both armies have fought across this ground, but no gore, bodies or active soldiers outside the chess pieces.

Lighting and mood:
Late-afternoon war light under a smoky overcast sky. Warm dusty side light catches the aged grid and silver pieces; cool green-black shadows separate the far bronze camp. Stronger atmospheric depth, drifting dust near ground level, restrained ember glow at the far edges. Gritty, solemn, tense, campaign-worn—not apocalyptic and not fantasy spectacle.

Critical invariants:
- Change only the environment, surface treatment and frame language.
- Preserve the Image 1 composition, 50–55 degree oblique strategy camera, long 24×9 board intent, all chess pieces, near silver-white tungsten faction, far deep ink-green bronze faction, traction trebuchets, chariots, cavalry, ministers, guards, infantry and generals.
- Do not add, remove, duplicate, replace, resize or restyle any chess piece.
- Do not place debris, smoke, flames, trenches, walls or props over grid intersections or behind pieces in a way that harms silhouettes.
- No traditional river, no large zone labels, no new text, no HUD, no logos, no watermark, no futuristic elements, no giant palace, no high walls, no gore, no bodies, no heavy fog.
- Maintain premium game concept-art finish and clear tactical readability.
```

## 待项目所有者判断

- 战场破损和外围场景密度是否合适；
- 是否保留远景烟火与栅栏，还是进一步收敛为更克制的军阵场；
- 是否接受V2取代V1成为后续Godot棋盘材质样片方向。
