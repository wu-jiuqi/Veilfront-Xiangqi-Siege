# 关卡闯关 HUD ImageGen 提示词 V2

日期：2026-08-23
状态：`superseded_full_screen_reference / composition_only`
生成模式：Codex 内置 `image_gen`

## 输出

- `assets/art/ui/concepts/level_challenge_hud_ux_reference_v2.png`

## 输入图角色

1. 用户提供的联机对局 HUD：整体十区骨架、无香类计时、暗铁／旧金材质与信息密度基准。
2. `level_challenge_hud_ux_reference_v1.png`：T03 关卡内容、红相、田字区域、目标交点与步骤清单参考，不继承整体布局。
3. `tutorial_hud_concept_v4_multiplayer_style_reuse_objective_panel_t0.png`：关卡信息必须收纳在既有右栏的功能参考，不继承香柱、巨型底座或留白。

## 最终提示词

```text
Use case: ui-mockup
Asset type: one standalone high-fidelity 16:9 desktop game UI reference screen for Godot, active campaign challenge gameplay HUD
Primary request: Create a new layout reference for the in-level campaign challenge screen of 《雾疆：九路烽棋》. This is the player already inside level T03 and solving the tactical board objective. It is NOT the level-selection map, NOT a multiplayer lobby, and NOT a cinematic splash.
Input images:
- Image 1 is the definitive composition, material, spacing and visual-language reference. Keep its same full-screen ten-region HUD skeleton: red force plaque top-left, central phase bar, jade force plaque top-right, minimap upper-left, selected-unit card lower-left, dominant center board, single right-side information drawer, contextual rules/skill strip at bottom-center, stacked mode buttons, confirm/cancel area. Preserve its no-incense direction, slim blackened-iron frames, dark battlefield, antique-gold grid and restrained ornament density.
- Image 2 is content and interaction reference only. Reuse its T03 “田字封路” mission, red elephant unit, target intersection, teaching route and step checklist, but do not copy its different overall layout.
- Image 3 is legacy functional-information reference only. It demonstrates that all mission information must live inside the existing right information column. Do not reuse its incense sticks, oversized bronze base, blank gutters or sparse board.
Composition/framing: one true 16:9 screen, implementation-ready UI reference, matching Image 1 proportions. Keep the tactical 9-route by 24-line board as the dominant focal area, about 56–60% of the full canvas, with the same center placement and side-column widths as Image 1. Do not add any extra floating tutorial window. All tutorial content stays inside the existing right drawer.
Top center phase bar: replace multiplayer round/time with three clearly separated fields: “T03 · 田字封路” on the left, “步骤 2/3” in the center active red plaque, “目标：移动至标记点” on the right.
Top force plaques: keep the same compact red and dark-jade army summaries from Image 1. Render “赤方军势” and “玄方军势”; use three compact public indicators beneath each heading, visually similar to Image 1.
Left upper: “战场态势” minimap, matching Image 1 size and style, with the viewport rectangle and current red elephant position clear.
Left lower: selected-unit card titled “相”, showing the project’s armored red elephant/chariot unit from Image 2, with only two short readable lines: “相 · 特殊机动单位” and “以田字封锁敌军路线”. Do not show RPG health, armor or morale stats.
Center board gameplay state: a red elephant is already selected near the lower half. Give it one grounded antique-gold selection ring. Show a precise legal diagonal teaching path toward one softly pulsing gold target intersection inside a translucent 2×2 “田字区域”. Keep overlays under and around pieces, never covering them. Enemy and allied units remain readable. Dark observer-safe fog, no hidden information.
Right drawer: reuse the exact outer shell, position and width of Image 1’s “战局与行动” panel. Title it “关卡指引”. Internally organize it into four compact, highly readable zones without scrollbars:
1) “关卡目标” — “相象训练：田字封路”
2) “步骤 2/3” — three checklist rows: “✓ 选择红相” completed and quiet; “2 移动至目标点” active with dark-red and antique-gold backing; “3 判断敌卒停止点” pending and muted
3) “当前操作” — “请选择高亮目标交点”
4) “提示” — “田字区域将阻挡敌方车与兵卒”
At the bottom of the drawer place two small secondary buttons: “显示提示” and “重置步骤”. Include a small collapse chevron in the drawer header.
Bottom center: preserve Image 1’s two-part contextual description strip and stacked two-button mode selector. Left text block: “行动规则” and “相沿斜线进入目标交点，不可越过其他棋子。” then divider, “当前技能：田字封路” and “完成移动后，目标区域将限制敌军路线。” Right stacked buttons: “移动” selected with gold border, “标记” secondary.
Bottom right: preserve Image 1’s strong confirmation area. Large primary button “确认移动” with a continuous bright-gold keyboard focus ring; secondary button “取消”.
Bottom left: one compact quiet button “退出关卡”, visually subordinate to all other actions.
Information hierarchy: board and glowing target first; current operation and active step second; mission goal third; hint and reset actions fourth. The player must understand what to do in one second.
Style/medium: realistic shippable Chinese strategy-game UI mockup, dark Eastern military fantasy, matte forged iron, blackened steel, oxidized bronze, restrained antique gold, terracotta red and deep jade; thin reusable 9-slice rectangular frames, Control-node-friendly containers, minimal ornament, high contrast.
Typography: atmospheric Chinese calligraphy only for large section headings; clean legible simplified Chinese sans-serif for steps, instructions, numbers and buttons; warm ivory primary text, antique-gold emphasis, muted beige secondary text, neutral gray disabled text. Keep text large and clean, no tiny pseudo-text.
Text (verbatim, render these important labels clearly): “T03 · 田字封路”, “步骤 2/3”, “目标：移动至标记点”, “赤方军势”, “玄方军势”, “战场态势”, “相”, “相 · 特殊机动单位”, “以田字封锁敌军路线”, “关卡指引”, “关卡目标”, “相象训练：田字封路”, “✓ 选择红相”, “移动至目标点”, “判断敌卒停止点”, “当前操作”, “请选择高亮目标交点”, “提示”, “田字区域将阻挡敌方车与兵卒”, “显示提示”, “重置步骤”, “行动规则”, “当前技能：田字封路”, “移动”, “标记”, “确认移动”, “取消”, “退出关卡”.
Constraints: one screen only; exact 16:9 landscape; same overall composition and identity as Image 1; no incense, no incense burners, no timing candles, no oversized ornamental base, no second tutorial panel, no campaign map, no mission-node list, no lobby controls, no room code, no online readiness controls, no annotation callouts, no split-screen comparison, no fake logos, no watermark. Board must look like a precise 9-route by 24-line tactical lattice. All dynamic content remains visually separable for later implementation as Godot preset Control/Container/Theme nodes.
```

## 评审边界

- 项目所有者已明确不制作独立完整关卡 HUD；本图只保留为右侧`关卡指引`面板与既有战局骨架的组合关系参考。
- 当前独立面板审批资产见`docs/ui/level-guide-panel-approval-v1.md`与`assets/art/ui/level_guide_panel/`。
- 本图只冻结候选的信息层级和布局关系，不冻结生成式文字、棋盘线号、棋子位置或像素尺寸。
- 正式实现继续复用对局 HUD 的预置 `Control / Container / Theme` 骨架；不得把整张概念图直接作为交互背景。
- 棋盘必须继续使用项目精确 `9×24` 交点与安全可见数据。
- 项目所有者确认前，不替换当前正式 HUD，也不拆分生产资源。
