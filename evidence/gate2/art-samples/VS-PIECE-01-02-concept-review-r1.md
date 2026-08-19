# VS-PIECE-01/02红黑步兵概念样片R1

状态：`revise / concept_readability_ready / runtime_alpha_blocked`

生成方式：Codex内置`image_gen`，使用项目所有者提供的甲士图片作为风格参考；未使用CLI/API回退。

## 输入与产物

- 参考图：`evidence/gate2/art-references/owner-supplied-armored-shield-soldier.png`
- 红方概念：`evidence/gate2/art-samples/vs-piece-01-red-infantry-concept-r1.png`
  - SHA-256：`07bfc76d73c7f396b8ec114e246b8cb425d3fd289808489fcb8d3d75b69851b6`
- 黑方概念：`evidence/gate2/art-samples/vs-piece-02-black-infantry-concept-r1.png`
  - SHA-256：`4a3d05d9a27c019c16f5e0b008cb3b706f6ba804eb41c3b36546463e2f81cba4`
- 两张尺寸均为`1024×1536`，PixelFormat均为`Format24bppRgb`。

## 概念审查

### 已成立

- 红方赭红布面形成足够大的阵营识别块，深色札甲和暗金包边继承参考图的厚重气质。
- 黑方使用蓝黑/冷灰大色块，并通过低冠头盔、肩甲和盾顶差异避免只换颜色。
- 两者全身、脚底线、比例和细节密度基本一致，适合作为红黑步兵配对方向。
- 盾牌、长兵器、肩宽和布甲下摆形成远距离仍有机会保留的轮廓锚点。
- 没有继承参考图的盾面文字或具体纹样排布。

### 必须修订

- 背景中的灰白棋盘格被烘入RGB像素，不是真实透明Alpha；当前文件不得进入`assets/art/pieces`或Godot Sprite3D。
- 盾与兵器使横向包围盒偏宽，仍需在棋盘96～180px屏幕高度下测试是否遮挡相邻交点。
- 黑方整体明度偏低，需要放入战场材质和迷雾后检查躯干/盾牌是否糊成一块。
- 当前只完成概念可读性，不代表透明边缘、mipmap、Opaque Pre-Pass、前后遮挡或显存验收通过。

## 透明底失败记录

生成时已经要求“genuinely transparent background”，但输出仍为24bpp RGB。随后对红方样片执行一次内置`background-extraction`，再次得到24bpp RGB，因此停止继续重试。

按`imagegen`工作流，未擅自切换到需要`OPENAI_API_KEY`的CLI/API回退，也未用脚本删除背景后宣称生成器通过。若要继续取得运行时透明源图，需要项目所有者明确选择CLI/API回退，或提供人工抠图/可编辑源文件。

## 红方最终生成提示词

```text
Use case: stylized-concept
Asset type: Veilfront Xiangqi Siege Sprite3D game character source art, VS-PIECE-01 red faction infantry sample
Primary request: Generate a new, original full-body red-faction frontier infantry guard for an Eastern war-fantasy strategy board game. This is not an edit or copy of the supplied image.
Input images: Image 1 is reference only for the visual weight of layered lamellar armor, dark oxidized metal, restrained antique-gold edging, and a sturdy shield-bearing silhouette.
Subject: one adult infantry guard in a grounded defensive stance, layered lamellar armor, broad shoulder silhouette, one practical shield held slightly to the side so the torso remains readable, one short spear; large muted cinnabar-red cloth panels and shoulder accents clearly identify the red faction at small scale; face partially visible or protected by an original helmet, not a faceless duplicate of the reference.
Style/medium: polished hand-painted game character concept, stylized realism, crisp readable silhouette, controlled detail grouping suitable for downscaling to a 512x768 runtime sprite.
Composition/framing: portrait 2:3, entire character and both feet visible, centered, consistent foot line, 8-16px-equivalent safe margin, front three-quarter presentation designed to remain readable on a Fixed-Y billboard viewed by a 50-degree oblique board camera.
Lighting/mood: soft neutral studio key light, restrained heroic military mood, clear separation of armor plates and cloth masses.
Color palette: dark blue-green oxidized iron, muted cinnabar red as the largest faction color block, restrained antique gold trim, low-saturation leather.
Materials/textures: worn lamellar plates, hammered metal, aged leather, coarse woven cloth; simplify micro-detail in the lower body and shield for board-scale readability.
Background: genuinely transparent background with clean alpha edges; no floor, no scenery, no painted shadow.
Constraints: original design; no Chinese characters, letters, numbers, emblems, logos, seals, watermarks, or decorative text; do not reproduce the reference shield shape, reference ornament layout, exact armor arrangement, pose, or facial covering; no extra people, no detached props, no cropped feet, no glow, no particles.
```

## 黑方最终生成提示词

```text
Use case: stylized-concept
Asset type: Veilfront Xiangqi Siege Sprite3D game character source art, VS-PIECE-02 black faction infantry sample
Primary request: Generate a new, original full-body black-faction frontier infantry guard as the paired counterpart to the red infantry sample.
Input images: Image 1 is reference only for layered lamellar armor, dark oxidized metal, restrained antique-gold edging, and sturdy military weight. Image 2 is a consistency anchor for rendering finish, body scale, foot line, detail grouping, and portrait framing; do not merely recolor or duplicate it.
Subject: one adult infantry guard in a grounded defensive stance, layered armor, broad but slightly more angular shoulder silhouette, a practical clipped-corner hexagonal shield held slightly to the side, and a short spear; large cold blue-black cloth and charcoal-gray panels identify the black faction; an original lower-crested helmet and shield-top shape make the faction silhouette visibly different from Image 2 while preserving the same infantry class and footprint.
Style/medium: polished hand-painted game character concept, stylized realism, crisp readable silhouette, controlled detail grouping suitable for downscaling to a 512x768 runtime sprite; match Image 2's level of finish and proportions.
Composition/framing: portrait 2:3, entire character and both feet visible, centered, same approximate scale and foot line as Image 2, 8-16px-equivalent safe margin, front three-quarter presentation designed for a Fixed-Y billboard viewed by a 50-degree oblique board camera.
Lighting/mood: same soft neutral studio key light as Image 2, restrained military mood, armor plates and cloth masses clearly separated.
Color palette: cold blue-black oxidized iron, charcoal and desaturated blue cloth as large faction color blocks, restrained dark silver and minimal antique-gold trim, low-saturation leather; keep it clearly distinguishable from the red sample at small scale.
Materials/textures: worn lamellar plates, hammered metal, aged leather, coarse woven cloth; simplify micro-detail in lower body and shield.
Background: genuinely transparent background with clean alpha edges; no floor, no scenery, no painted shadow.
Constraints: original design; no Chinese characters, letters, numbers, emblems, logos, seals, watermarks, or decorative text; do not reproduce the reference shield shape, ornament layout, exact armor arrangement, pose, or facial covering; do not simply recolor Image 2; no extra people, detached props, cropped feet, glow, or particles.
```

## 下一步

1. 获得真实Alpha的红黑步兵源图。
2. 生成最大`512×768`运行时版本并记录导入设置。
3. 放入预置`Piece3D`场景，在近/中/远三段和红黑视角下验证遮挡、排序与明度。
4. 通过后再开始红黑骑兵样片，避免在基础透明管线未通时扩大产出。
