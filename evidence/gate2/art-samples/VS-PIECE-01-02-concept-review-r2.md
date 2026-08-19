# VS-PIECE-01/02金属兵马俑步兵概念样片R2

状态：`partially_superseded / black_r2_current / red_r2_superseded_by_r3`

生成方式：Codex内置`image_gen`，每个资产单独生成；未使用CLI/API回退。

## 项目所有者修订要求

- 红黑步兵统一改为兵马俑形式。
- 脸部使用没有五官和孔洞的光滑面具。
- 盾牌中央只出现一个金色`兵`字，采用秦小篆风格。
- 黑方使用墨绿青铜色。
- 红方使用土黄钨钢色。
- 两方都必须有清楚的金属质感。

## 产物

- 红方R2：`evidence/gate2/art-samples/vs-piece-01-red-terracotta-infantry-concept-r2.png`
  - SHA-256：`94fe9dee6976567e9661ae4e3cba9faca67e23f05684f55d90efa0a5d975a4f9`
- 黑方R2：`evidence/gate2/art-samples/vs-piece-02-black-terracotta-infantry-concept-r2.png`
  - SHA-256：`3036d39c951ef3e747c2139a1db040623db9b8bdfc26393aa97fc5487af9c4d6`
- 两张均为`1024×1536 / Format24bppRgb`，使用浅灰概念审查背景，不是运行时透明纹理。
- R1保留为被本次方向修订取代的历史概念，不删除、不冒充当前方案。
- 红方土黄钨钢R2随后被银白钨钢R3取代；黑方墨绿青铜R2仍为当前候选。

## 初审

### 符合要求

- 两方均形成秦俑式站姿、秦甲结构和整体金属雕像感，没有裸露皮肤。
- 面具为完整光滑曲面，没有眼、鼻、嘴或表情浮雕。
- 盾面只出现一个金色`兵`字，没有额外文本、旗号或印章。
- 黑方为近黑墨绿青铜，具有铜绿缝隙、青铜磨边和明确镜面高光。
- 红方为土黄/赭黄钨钢，具有深钢底、浅金钢高光和少量暗朱系绳。
- 两方冠形、肩甲、盾缘和腿甲轮廓不同，不是简单换色。

### 进入运行时前必须处理

- 当前`兵`字是生成式小篆风格近似，只通过“单字可辨”概念检查；最终盾面必须换成经校对、授权、可追踪的矢量秦小篆字形。
- 两张仍带浅灰背景。只有项目所有者确认R2方向后，才制作真实Alpha源图和最大`512×768`运行时版本。
- 需在96～180px屏幕高度检查光滑面具、盾面单字和两方材质是否仍可区分。
- 黑方入雾后的墨绿暗部、红方在土色棋盘上的土黄轮廓都可能降低对比度，必须依靠阵营底座、轮廓差和受控边缘光复核。

## 黑方最终生成提示词

```text
Use case: stylized-concept
Asset type: Veilfront Xiangqi Siege game character concept, VS-PIECE-02 black faction infantry R2
Primary request: Create a completely redesigned black-faction infantry as a metallic Terracotta Army–inspired Qin guardian statue for an Eastern war-fantasy strategy board game.
Input images: Image 1 is reference only for heavy armor weight and shield-bearing presence. Image 2 is reference only for portrait framing, full-body scale, foot line, and game-concept rendering finish. Do not preserve the human face or copy either design.
Subject: one full-body Qin-era terracotta-warrior-inspired infantry statue, strong compact defensive stance, layered Qin lamellar armor, broad shoulders, one long spear and one large upright shield. The entire figure is constructed as a living metal statue; no exposed human skin. The face is covered by a perfectly smooth, featureless metal mask: no eyes, no eye holes, no nose, no mouth, no facial relief, only a calm curved faceplate and a clean helmet rim.
Faction design: black faction. Dominant material is deep ink-green patinated bronze (墨绿青铜色), near-black green recesses, subtle verdigris in seams, polished bronze highlights on worn edges. Strong metallic reflections and clear roughness variation; it must read as metal, not stone, clay, plastic, or cloth.
Shield: broad Qin-style shield with simple geometric border. At the exact visual center place one and only one large raised golden Chinese character: "兵". The character must be recognizable as 兵, styled as Qin small-seal script / 秦小篆 inspired calligraphy, embossed metal, bright antique gold, high contrast. No other writing, glyphs, runes, stamps, numbers, or emblems anywhere.
Style/medium: polished hand-painted game character concept, stylized realism, original design, monumental archaeological-fantasy feeling, simplified large forms suitable for downscaling.
Composition/framing: portrait 2:3, entire figure and both feet visible, centered, front three-quarter view, shield inscription fully visible and not occluded, consistent foot line, generous safe margin, suitable for a Fixed-Y Sprite3D billboard viewed from a 50-degree oblique board camera.
Lighting/mood: neutral studio key and rim light that reveal metallic specular highlights, solemn and intimidating, no glow effects.
Background: plain uniform warm light-gray studio background, no checkerboard, no scenery, no floor props, no text outside the shield.
Constraints: exact shield text is "兵" once; smooth featureless mask; no human face; no exposed skin; no extra people; no banners; no watermark; no copied shield shape or ornament layout from the references; no excessive tiny decoration; no cropped weapon or feet.
```

## 红方最终生成提示词

```text
Use case: stylized-concept
Asset type: Veilfront Xiangqi Siege game character concept, VS-PIECE-01 red faction infantry R2
Primary request: Create a completely redesigned red-faction infantry as a metallic Terracotta Army–inspired Qin guardian statue, paired with the black-faction R2 character.
Input images: Image 1 is reference only for heavy armor weight and shield-bearing presence. Image 2 is the pairing anchor for full-body scale, foot line, pose readability, smooth mask concept, shield inscription placement, and rendering finish. Do not merely recolor or duplicate Image 2.
Subject: one full-body Qin-era terracotta-warrior-inspired infantry statue, strong compact defensive stance, layered Qin lamellar armor, broad shoulders, one long spear and one large upright shield. The entire figure is constructed as a living metal statue; no exposed human skin. The face is covered by a perfectly smooth, featureless metal mask: no eyes, no eye holes, no nose, no mouth, no facial relief, only a calm curved faceplate and clean helmet rim. Use a lower squared Qin-style crown and a subtly different shoulder/greave silhouette from Image 2 while preserving the same infantry class and footprint.
Faction design: red faction. Dominant material is earthy ochre tungsten steel (土黄钨钢色): warm soil-yellow and muted ochre metal plates over dense dark steel, with polished pale-gold steel highlights, brown heat tint in recesses, and restrained dark cinnabar fastening cords only as small accents. Strong metallic reflections and clear roughness variation; it must read as heavy tungsten-like steel, not bronze, clay, stone, brass, plastic, or cloth.
Shield: broad Qin-style shield with an angular stepped border distinct from Image 2. At the exact visual center place one and only one large raised golden Chinese character: "兵". The character must be recognizable as 兵, styled as Qin small-seal script / 秦小篆 inspired calligraphy, embossed metal, luminous antique gold, high contrast. No other writing, glyphs, runes, stamps, numbers, or emblems anywhere.
Style/medium: polished hand-painted game character concept, stylized realism, original design, monumental archaeological-fantasy feeling, simplified large forms suitable for downscaling; match Image 2's finish and proportions.
Composition/framing: portrait 2:3, entire figure and both feet visible, centered, front three-quarter view, shield inscription fully visible and not occluded, same approximate scale and foot line as Image 2, generous safe margin, suitable for a Fixed-Y Sprite3D billboard viewed from a 50-degree oblique board camera.
Lighting/mood: neutral studio key and rim light that reveal metallic specular highlights, solemn and resolute, no glow effects.
Background: plain uniform warm light-gray studio background matching Image 2, no checkerboard, no scenery, no floor props, no text outside the shield.
Constraints: exact shield text is "兵" once; smooth featureless mask; no human face; no exposed skin; no extra people; no banners; no watermark; do not simply recolor Image 2; no copied shield shape or ornament layout from the references; no excessive tiny decoration; no cropped weapon or feet.
```

## 下一步

1. 项目所有者确认或退回R2视觉方向。
2. 确认后制作经校对的小篆`兵`字矢量源并替换生成字形。
3. 制作真实Alpha源图、512×768运行时版本和Godot导入设置。
4. 在预置`Piece3D`场景完成近/中/远、红黑视角、雾中和色觉弱化检查。
