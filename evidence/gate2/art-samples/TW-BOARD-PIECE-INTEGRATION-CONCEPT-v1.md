# 兵马俑棋子与棋盘融合概念图 V1

日期：2026-08-20  
状态：`awaiting_owner_visual_review / concept_only / not_geometry_evidence`

参考图：`evidence/gate2/art-samples/review/TW-BOARD-PIECE-INTEGRATION-CONCEPT-v1.png`

## 本轮目标

把现有银白钨钢与深墨绿青铜14类静态棋子母版放入同一块完整长棋盘构图中，先审查“兵马俑”专属棋盘的材质、包边、网格、灯光和整体气质，不批准正式棋盘资产。

## 候选美术方向

- 棋盘主体使用低反射压实黑土与炭黑石材，保留轻微尘土、磨损和车辙，避免与高光金属棋子竞争。
- 九路网格使用内嵌旧金/青铜线；外框采用深色氧化青铜、细旧金边、秦式几何回纹、角部甲片与克制铆钉。
- 总体保持50°～55°低FOV斜俯视；银白钨钢方位于近端，深墨绿青铜方位于远端。
- 光照以冷色柔光托起银白阵营，以克制的暖金边光强化网格和包边，以深绿青铜轮廓光分离远端阵营。
- 不设置传统象棋河界；大本营、缓冲区和中央战区只能通过极轻微材质明度变化表达，不增加粗分割线和区域大字。

## 使用边界

本图只用于美术方向审查。生成式图像不能作为以下事实的验收证据：

- 精确24×9交点数量、直线度、间距和一基逻辑映射；
- 32枚实例的精确棋种数量、标准落位和交点锚定；
- 金色职位字的正式小篆字形、字源与授权；
- Sprite3D真实尺寸、遮挡、双方180°视角、96px可读性与信息边界。

正式实现必须继续使用Godot预置24×9网格、已批准的14张运行时纹理与14个棋子预置，不从本图反向切割或重建棋子资源。

## 生成输入

- `evidence/gate2/art-samples/review/TW-PIECE-01-14-runtime-alpha-review-v2.png`：14枚棋子造型、阵营材质与角色道具参考。
- `evidence/gate2/art-samples/review/piece-art-test-3d-full-formation-v1.png`：24×9长棋盘比例与32实例阵型参考。

## 最终生成提示词

```text
Use case: compositing
Asset type: full-board game environment concept art / art-direction reference for the “兵马俑” style pipeline

Input images:
- Image 1: authoritative visual reference for the existing fourteen chess-piece masters. Preserve their silhouettes, Qin terracotta-warrior armor language, smooth featureless masks, role props, gold role glyphs, and the two faction materials.
- Image 2: spatial and formation reference for the project's long 24×9 intersection board and thirty-two-piece deployment. Improve the board art completely; do not copy the plain prototype surface or HUD.

Primary request:
Create one polished complete reference image showing the existing pieces fully integrated into a purpose-designed Chinese strategic chess battlefield board. This is not a conventional 9×10 Xiangqi board: preserve the project’s long 24 rows × 9 files intersection layout. Show all thirty-two pieces in the established deployment: each faction has 5 infantry, 2 trebuchets, 2 chariots, 2 cavalry, 2 ministers, 2 guards, and 1 general. Near side is the bright silver-white tungsten-steel faction; far side is the deep ink-green bronze faction.

Board art direction:
- A long, thick, premium battlefield slab combining matte compacted dark earth and charcoal stone, with subtle dust, wear, wheel ruts and restrained scorch marks.
- The playing surface must remain low-reflectance so the metallic pieces remain dominant and readable.
- Exactly nine vertical files and twenty-four horizontal intersection rows, rendered as precise recessed aged-gold / bronze inlay lines; straight, evenly spaced, complete, and easy to read.
- No traditional river break. Suggest headquarters, buffer and central war zone only through extremely subtle material value changes; no thick zone dividers and no large area labels.
- Substantial dark patinated-bronze outer frame, thin aged-gold edge, Qin-inspired geometric key patterns, corner armor plates and restrained rivets. Historically inspired, not futuristic.
- Low stepped end platforms may subtly suggest Qin military command terraces, but must not obstruct grid intersections or pieces.
- No tall scenery, walls, props, smoke, fog, fire, UI or decoration that blocks chess readability.

Piece invariants:
- Preserve the exact piece families and faction pairing from Image 1.
- Silver side: high-value cool silver-white tungsten steel, crisp cold highlights, small dark-red cords.
- Green side: near-black deep ink-green bronze, restrained verdigris, warm worn bronze edges.
- All humanoid faces remain completely smooth featureless metal masks.
- Trebuchets remain Chinese traction trebuchets with A-frame, long beam, flexible sling pouch and multiple pull ropes; no cannon, rigid spoon, torsion bundle or European counterweight box.
- Chariots remain dynamic three-horse Qin chariots with tall complete banners.
- Do not turn pieces into round tokens, statues on circular chess discs, or generic European fantasy miniatures.
- Do not add or substitute text. Existing gold role glyphs may remain as part of the referenced pieces; no other writing.

Composition/framing:
Wide landscape 16:9, centered symmetrical 50–55 degree oblique overhead camera with low-FOV strategy-game presentation. Entire long board and all thirty-two pieces visible inside frame. Near camp large enough to read, far camp still recognizable. Strong depth but not extreme fisheye distortion. Clean dark neutral environment outside the slab.

Lighting/mood:
Cinematic museum-diorama lighting: cool soft key light over the silver camp, restrained warm-gold rim light along the board inlay, subtle green-bronze rim on the far camp. Metallic highlights clear but controlled; no mirror-chrome bloom. Solemn, ancient Qin military atmosphere, premium game key visual.

Constraints:
Board grid geometry must be exact and unobstructed; pieces must sit on intersections; no missing or duplicated role families; no logos, watermark, captions, HUD, floating labels, extra text, futuristic neon, oversized palace buildings, heavy fog, or baked checkerboard transparency.
```

## 待项目所有者判断

- 是否接受“黑土/炭黑石面 + 旧金嵌线 + 深青铜秦式包边”作为兵马俑棋盘的下一轮样片方向；
- 棋盘是否需要更明显的战场泥土感，或更偏礼器/军阵沙盘的精致质感；
- 包边纹样和角件密度是否需要进一步降低。
