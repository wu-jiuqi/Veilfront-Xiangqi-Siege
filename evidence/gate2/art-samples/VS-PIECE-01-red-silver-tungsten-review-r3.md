# VS-PIECE-01红方银白钨钢步兵概念样片R3

状态：`candidate / awaiting_project_owner_visual_review / runtime_alpha_not_started`

生成方式：Codex内置`image_gen`精确对象编辑；编辑目标为红方土黄钨钢R2，未使用CLI/API回退。

## 修订要求

只把红方主金属从土黄钨钢改为钨钢式银白色，保留兵马俑造型、光滑面具、姿势、构图、盾牌和金色`兵`字。

## 产物

- 文件：`evidence/gate2/art-samples/vs-piece-01-red-silver-tungsten-infantry-concept-r3.png`
- SHA-256：`9339bd785a359dbef5eecd5dd65e97bc344e25c8089bb47a061ca52b0fa6b8e7`
- 规格：`1024×1536 / Format24bppRgb`，浅灰概念审查背景，不是运行时透明纹理。
- 配对黑方：`evidence/gate2/art-samples/vs-piece-02-black-terracotta-infantry-concept-r2.png`

## 初审

- 主甲、面具、头盔、护胫、靴、长矛和盾体已经统一为冷银白钨钢。
- 深灰缝隙、浅银高光、蓝灰反射和磨边共同形成金属质感，没有继续呈现土黄或青铜色。
- 光滑面具仍无眼、鼻、嘴和孔洞。
- 盾面仍只有一个金色`兵`字，字形、位置和比例没有改变。
- 小面积暗朱系绳被保留为红方辅助识别，但不破坏银白钨钢主材质。

## 仍待验证

- 项目所有者需确认银白程度、金属粗糙度和与墨绿青铜黑方的整体搭配。
- 正式盾面仍需换成经校对和授权的秦小篆`兵`字矢量。
- 当前仍需制作真实Alpha与512×768运行时版本，并在土色棋盘上检查银白高光是否过曝。

## 最终编辑提示词

```text
Use case: precise-object-edit
Asset type: Veilfront Xiangqi Siege red-faction metallic Terracotta Army infantry concept R3
Input images: Image 1 is the edit target.
Primary request: Change only the red-faction warrior's main metal material from earthy ochre/yellow metal to silver-white tungsten steel.
Material change: armor plates, smooth featureless face mask, helmet, greaves, boots, spear blade and shaft fittings, and shield body should become dense cool silver-white tungsten steel with polished pale-silver highlights, cool charcoal seams, subtle blue-gray reflections, fine brushed metal grain, restrained edge wear, and strong realistic metallic specular response. It must read as heavy silver-white tungsten steel, not chrome, aluminum, stone, clay, plastic, bronze, brass, or gold.
Text invariant: keep the single shield character "兵" exactly once, in raised antique gold, unchanged in shape, scale, position, and legibility. No other text or glyphs.
Preserve exactly: the full character design, Qin terracotta-warrior form, pose, proportions, smooth mask with no eyes/nose/mouth, armor construction, square crown, shield shape and border structure, spear, hands, foot line, framing, lighting direction, plain warm light-gray background, and image dimensions. Keep the small dark cinnabar fastening cords as subtle red-faction accents.
Constraints: change only the main material color and metallic surface response; do not redesign, add, remove, crop, or move anything; no human skin; no facial features; no extra symbols; no watermark; no checkerboard.
```
