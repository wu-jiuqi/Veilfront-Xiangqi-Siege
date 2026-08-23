# 关卡指引面板 V1 审批说明

日期：2026-08-23
状态：`approval_candidate / purple_keyed / not_integrated`
生成模式：Codex 内置 `image_gen`

## 目标

关卡模式继续复用正式战局 HUD，只新增一个可替换右侧信息栏内容的独立`关卡指引`面板。本轮只生产紫幕母图与透明 PNG，禁止接入 Godot 场景。

## 交付物

- 紫幕母图：`assets/art/ui/level_guide_panel/source_chroma/level_guide_panel_chroma_v1.png`
- 透明审批图：`assets/art/ui/level_guide_panel/level_guide_panel_v1.png`
- 资产说明：`assets/art/ui/level_guide_panel/README.md`

## ImageGen 最终提示词

```text
Use case: ui-mockup
Asset type: one isolated production game UI component on a purple chroma screen, vertical Level Guide Panel for Godot
Primary request: Create ONLY one standalone vertical “LevelGuidePanel” artwork for the campaign challenge mode of 《雾疆：九路烽棋》. This is a reusable empty panel shell to be placed in the existing match HUD right column later. Do not create a full game screen and do not show the board, soldiers, minimap, faction plaques or bottom action bar.
Input images:
- Image 1 is a layout-and-material reference only. Study only its right-side “关卡指引” drawer: the hierarchy of mission goal, three-step checklist, current operation, hint and two secondary actions. Do not copy any of the rest of the full-screen HUD.
- Image 2 is the project’s current purple-screen objective panel and defines the exact production identity: front-facing geometry, thin blackened forged-iron frame, oxidized bronze, restrained aged-gold trim, subtle rivets, low-reflection dark interior, closed silhouette and clean chroma-key margin. It is a style and technical reference, not an edit target.
Canvas and framing: portrait 2:3 purple-screen canvas. Center one tall narrow panel with generous uniform purple margin on all four sides. The panel occupies about 72–78% of the canvas width and 82–88% of the canvas height. Perfectly front-facing orthographic view; straight vertical and horizontal edges; symmetrical outer frame; no perspective tilt.
Panel structure, top to bottom:
1. A compact header plaque with an empty title area and one small separate square collapse-button recess on the upper right.
2. A medium mission-goal compartment with ample empty safe area for two lines of dynamic text.
3. A grouped three-row checklist compartment. Three equal horizontal rows, each with one small diamond-shaped status well on the left and a wide empty text region on the right. Keep the three rows visually related as one section.
4. A compact current-operation compartment with a subtle inner separator and generous empty text area.
5. A compact contextual-hint compartment, slightly quieter and darker than the current-operation section.
6. A bottom action strip with exactly two equal empty rectangular button recesses side by side, reserved for dynamic “显示提示” and “重置步骤” controls.
Production content rule: this asset must contain NO baked text, NO Chinese characters, NO Latin letters, NO numbers, NO checkmarks, NO arrows, NO icons, NO mission emblems, NO active-step red highlight and NO button labels. All information and interaction states will be overlaid later with Godot preset Label/Button nodes.
Style/medium: realistic shippable painted raster game UI; dark Eastern military fantasy; matte forged black iron, deep charcoal steel, subtle oxidized bronze, restrained antique-gold bevels; thin reusable 9-slice-friendly rectangular framing; sparse rivets; low ornament density; high-value separation between frame and dark interior; match Image 2 closely.
Silhouette and extraction: one single closed, continuous, fully opaque panel silhouette. Keep all decorative metal, bevels and shadows inside the panel’s outer boundary. No detached ornaments, no hanging chains, no smoke, no glow spilling outside, no semi-transparent shadow outside the silhouette.
Background: one single perfectly flat, perfectly uniform chroma-key magenta-purple color #FF00FF covering every pixel outside the panel. No checkerboard, no transparent preview, no texture, no gradient, no vignette, no lighting variation, no noise, no shadow and no purple reflection in the background.
Constraints: only the isolated panel; exact front view; clean generous purple border; crisp closed edges; dark interior remains fully opaque; no extra UI components outside the panel; no board; no characters; no environment; no logos; no watermark; no SVG/vector look; no text anywhere.
```

## 抠图验证

- 输出：`746×1413` RGBA。
- 四角 Alpha：`0 / 0 / 0 / 0`。
- 中心 Alpha：`255`。
- Alpha 范围：`0–255`，保留抗锯齿边缘。
- 可见区域紫色优势超过 40 的像素：`0`。
- 已改用距离色键与边缘去紫流程；未采用右缘残紫的第一次通用抠图结果。

## 审批边界

- 审批内容：外框比例、暗铁／旧金材质、六段信息结构、留白和按钮槽关系。
- 不审批：具体关卡文字、图标、步骤状态、Hover／Pressed／Disabled、九宫格边距、实际右栏尺寸。
- 未经项目所有者确认，不接入任何 `.tscn`、`.tres`、Theme 或运行时脚本。
