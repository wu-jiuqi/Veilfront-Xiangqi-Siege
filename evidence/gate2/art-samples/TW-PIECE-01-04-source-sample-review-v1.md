# “兵马俑”红黑步兵/骑兵单体源样片审查 v1

状态：`partial / design_sources_ready / alpha_and_runtime_blocked`

工作项：`ITERATION-3R-OBLIQUE-3D-VISUAL / TASK-ART-001 / DELIVERABLE-ART-001`

生产任务书：`evidence/gate2/art-samples/TW-PIECE-01-04-single-sample-production-brief-v1.md`

生成方式：Codex内置`image_gen`。步兵沿用项目所有者确认的R3/R2单体锚点；骑兵分别以V2轮廓页和对应阵营步兵为参考单独生成。未使用CLI/API回退，未使用脚本抠图或插值放大。

## 产物与机械校验

| ID | 文件 | 实际规格 | Alpha | SHA-256 | 状态 |
|---|---|---|---|---|---|
| VS-PIECE-01 | `evidence/gate2/art-samples/sources/vs-piece-01-red-infantry-source-v1.png` | 1024×1536 / 24bpp RGB | 无 | `9339bd785a359dbef5eecd5dd65e97bc344e25c8089bb47a061ca52b0fa6b8e7` | 设计源通过；待Alpha |
| VS-PIECE-02 | `evidence/gate2/art-samples/sources/vs-piece-02-black-infantry-source-v1.png` | 1024×1536 / 24bpp RGB | 无 | `3036d39c951ef3e747c2139a1db040623db9b8bdfc26393aa97fc5487af9c4d6` | 设计源通过；待Alpha |
| VS-PIECE-03 | `evidence/gate2/art-samples/sources/vs-piece-03-red-cavalry-source-v1.png` | 1254×1254 / 24bpp RGB | 无 | `ab1479ad5bbb43920e940932dc77a5b9cb874c87836277426ab77b40b7965aab` | 概念候选；待所有者审查、Alpha与源尺寸处理 |
| VS-PIECE-04 | `evidence/gate2/art-samples/sources/vs-piece-04-black-cavalry-source-v1.png` | 1254×1254 / 24bpp RGB | 无 | `5884ac62c03d3ce4cabadaf4e6323e1404c3c034c2c5c0b5f30603fb9be09176` | 概念候选；待所有者审查、Alpha与源尺寸处理 |

拒收的透明尝试：

- `evidence/gate2/art-samples/rejected/vs-piece-01-red-infantry-alpha-failure-r2.png`
- `1024×1536 / Format24bppRgb / Alpha=False / 四角Alpha=255`
- SHA-256：`6a8f480a9e7f1944cb74fa39430d4d6a0f04083c6810d6d5a9d9918fc31cfa29`
- 失败原因：生成器把棋盘格烘入RGB，未输出真实透明像素。该文件只作失败证据，不得进入运行时目录。

## 视觉初审

### 通过项

- 四个设计源保持统一的三分之四视角、左前上方主光、右后方边缘光和工作室曝光。
- 红方使用高明度冷银白钨钢、方冠方肩与锐利边缘；黑方使用近黑墨绿青铜、弯钩冠、圆弧叠甲与厚重铜边。
- 两名骑兵均为单马单骑、冲锋/半扬蹄动作，长枪形成清晰对角线；枪尖、冠饰、马耳、马尾和四蹄均未裁切。
- 红黑骑兵的冠形、肩甲、马面甲、马具、甲片边缘和腿部节奏存在结构差异，不是纯换色。
- 所有人形面具均无眼孔、鼻、嘴和裸露皮肤；金字`兵/马`在概念尺寸下准确可读。
- 一级轮廓足以支撑后续96px测试，微小铆钉和纹样没有被列为兵种识别必需条件。

### 未通过/阻断项

- 内置图像生成器连续两次透明背景请求都返回24bpp RGB烘焙棋盘格，因此四张设计源均未进入`runtime/`目录。
- 两张骑兵实际为1254×1254，低于管线目标1536×1536。当前不做插值放大，不把1254冒充1536原生细节；正式源尺寸需在可控导出/可编辑源阶段补齐。
- 由于没有真实Alpha和运行时候选，512×768/768×768派生、透明边缘检查和96px盘内截图尚不能形成有效证据。
- 金色`兵/马`仍是概念图像素字。正式生产必须替换为经字源校对的统一矢量字稿。

## 下一合法步骤

1. 项目所有者审查两张骑兵设计源的姿态、结构差异和材质。
2. 若需要继续自动抠图，项目所有者需明确授权使用`imagegen`的CLI/API回退；该路径要求本机设置`OPENAI_API_KEY`。没有授权前不得切换。
3. 获得真实Alpha后，按任务书脚底/马蹄锚点和安全框校正，再等比派生512×768与768×768运行时候选。
4. 最后在预置三维棋盘中记录96px近中远、红黑双方视角、遮挡和雾中对照；不以本页视觉初审代替独立QA或GATE-2。

## 最终提示词记录

### VS-PIECE-03 红方骑兵

```text
Use case: stylized-concept
Asset type: Veilfront Xiangqi Siege VS-PIECE-03 red-faction cavalry single-character source sample
Input images: approved V2 silhouette page as the top-row 马 design reference; red-faction R3 infantry as the material, square-crown, lighting and smooth-mask anchor.
Primary request: one isolated Qin-inspired metallic terracotta-warrior cavalry unit, one armored horse and one mounted rider, charging/controlled half-rearing, full body and diagonal spear visible.
Faction/material: angular rectangular crown, squared shoulder plates, crisp horse armor, restrained dark-cinnabar cords; bright cool silver-white tungsten steel with controlled specular highlights, not chrome.
Text (verbatim): exactly one raised antique-gold "马" on a large horse barding plaque; no other text.
Composition: square source intended for 1536×1536; entire spear, crown, ears, tail and hooves visible; ≥5% safe margins; hoof baseline y≈0.92; no crop.
Background: perfectly uniform warm light gray, no checkerboard, scenery, props, horizon or cast shadow.
Constraints: exactly one horse and rider; smooth featureless human mask; no skin, extra units, glow, neon, modern hardware or watermark.
```

### VS-PIECE-04 黑方骑兵

```text
Use case: stylized-concept
Asset type: Veilfront Xiangqi Siege VS-PIECE-04 black-faction cavalry single-character source sample
Input images: approved V2 silhouette page as the bottom-row 马 direction; black-faction R2 infantry as the material and curved-crest anchor; red cavalry only as scale, camera, safe-margin and detail-density reference.
Primary request: one isolated Qin-inspired metallic terracotta-warrior cavalry unit, one armored horse and one mounted rider, related but structurally different from the silver unit.
Faction/material: curved hooked crest, rounder shoulder plates, heavier patinated borders, rounded horse armor, different harness and leg rhythm; deep near-black ink-green bronze with readable green midtones, warm bronze edge highlights and subtle seam verdigris.
Text (verbatim): exactly one raised antique-gold "马" on a large horse barding plaque; no other text.
Composition: square source intended for 1536×1536; all parts visible; ≥5% safe margins; hoof baseline y≈0.92; canvas area within 10% of red cavalry; no crop.
Background: perfectly uniform warm light gray matching the paired source, no checkerboard, scenery, props, horizon or cast shadow.
Constraints: exactly one horse and rider; smooth featureless human mask; no skin, extra units, glow, neon, modern hardware, copied silver geometry or watermark.
```

### 透明背景失败重试

```text
Use case: background-extraction
Primary request: preserve the silver infantry design exactly and change only the baked checkerboard background to genuine PNG alpha=0 outside the warrior, with partial alpha only on antialiased edges.
Constraints: do not redraw, recolor, resize, crop or move the subject; no halo, matte, shadow, checkerboard artwork, extra object, text or watermark.
```
