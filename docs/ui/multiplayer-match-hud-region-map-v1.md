# 联机对局 HUD 十区抽象 V1

日期：2026-08-23
状态：`layout_abstraction / pending_owner_review`

参考图：`assets/art/ui/concepts/multiplayer_match_hud_region_map_v1.png`

当前装配效果图：`assets/art/ui/concepts/multiplayer_match_hud_ux_reference_v2_no_incense.png`。V2 禁用全部香类计时组件，区域 02 是唯一回合／计时入口；区域 01 与 03 各承载三项公开旗帜／损失信息；区域 05 只显示棋子身份与定位简介；区域 09 改为左侧规则／技能说明、右侧上下两个模式按钮。

## 目的

将高细节对局效果图压缩为可实现的 UI 区域，只描述区域职责、层级和相对比例，不绑定最终皮肤、像素坐标或运行时数据。

## 区域映射

| ID | 区域 | 主要职责 | 推荐预置根节点 |
|---|---|---|---|
| 01 | `RedForceSummary` | 赤方头像、军势、公开旗／损失摘要 | `PanelContainer → HBoxContainer` |
| 02 | `TurnStatusBar` | 回合、行动方、剩余时间、网络提交状态 | `CenterContainer → PanelContainer` |
| 03 | `BlackForceSummary` | 玄方头像、军势、公开旗／损失摘要 | `PanelContainer → HBoxContainer` |
| 04 | `TacticalMinimap` | 观察者安全小地图与当前镜头框 | `PanelContainer → AspectRatioContainer` |
| 05 | `SelectedUnitCard` | 当前选中单位名称、立绘与简短定位；无兵力／士气／放大操作；空状态可折叠 | `PanelContainer → VBoxContainer` |
| 06 | `BoardViewport` | 主棋盘、雾、棋子、合法点、路径与输入层 | `AspectRatioContainer → BoardHost` |
| 07 | `ObjectiveEventsDrawer` | 当前玩家可见的战局目标、公开事件与当前选中坐标，最多五行 | `PanelContainer → VBoxContainer` |
| 08 | `MarkerTool` | 私有标记入口与局部工具状态 | `PanelContainer → CenterContainer` |
| 09 | `ActionModeBar` | 左侧行动规则／技能说明，右侧上下排列的`移动 / 技能`模式按钮 | `PanelContainer → HBoxContainer` |
| 10 | `ConfirmationActions` | 确认、取消、提交锁和错误恢复入口 | `PanelContainer → HBoxContainer` |

## 推荐容器骨架

```text
MatchHudRoot (Control, Full Rect)
└─ SafeMargin (MarginContainer)
   └─ ScreenRows (VBoxContainer)
      ├─ TopBand (HBoxContainer)
      │  ├─ RedForceSummary [01]
      │  ├─ TurnStatusBar [02, expand]
      │  └─ BlackForceSummary [03]
      └─ BodyBand (HBoxContainer, expand)
         ├─ LeftRail (VBoxContainer)
         │  ├─ TacticalMinimap [04]
         │  └─ SelectedUnitCard [05, expand]
         ├─ CenterColumn (VBoxContainer, expand)
         │  ├─ BoardViewport [06, expand]
         │  └─ ActionModeBar [09]
         └─ RightRail (VBoxContainer)
            ├─ ObjectiveEventsDrawer [07, expand]
            ├─ MarkerTool [08]
            └─ ConfirmationActions [10]
```

固定结构全部优先预置在 `.tscn`；只有棋子、事件行和数据驱动覆盖层按对局状态更新或实例化。

## 建议比例

- 顶部状态带：总高度约 `14%–16%`。
- 主体三列：左轨约 `20%`、中央约 `60%`、右轨约 `20%`。
- 中央底部行动区：主体高度约 `17%–19%`，其余交给棋盘。
- 左侧小地图与单位卡约 `1:1.5`；右侧战局抽屉优先扩展，工具与确认区保持固定高度。
- 比例用于容器 `stretch_ratio` 初始值，不应转成全屏硬编码坐标。

## 响应式规则

- `1280×720`：完整十区布局基准。
- `960×540`：减少外边距；单位未选中时折叠 05；07 只保留三条最高优先级信息；正文不得按整体缩放降到不可读。
- `1920×1080` 及以上：保持核心安全画布比例，优先扩大 06；不要等比放大边框厚度。
- 超宽屏：只延展背景与非交互装饰，左右信息轨不得被拉到远离棋盘。

## 信息边界

- 01、03、07 只消费公开或当前观察者获授权的数据。
- 04 与 06 必须使用同一观察者、同一 `action_index` 的 `PlayerView`。
- 08 为本地私有标记，不发送给对手或规则核心。
- 10 只提交规范化意图；确认面板默认焦点应落在取消，避免误提交。

## ImageGen 最终提示词

```text
Use case: ui-mockup
Asset type: low-fidelity annotated UI region map for Godot implementation, one standalone 16:9 desktop screen
Primary request: Abstract the supplied detailed multiplayer match screenshot into a clean UI region blueprint. Preserve the exact overall layout proportions and anchors of the original screen, but remove all illustrative detail. The output should explain the screen as reusable UI areas, not redesign it and not render a polished game scene.
Input images: Image 1 is the layout reference. Preserve its top/left/center/right/bottom region placement and relative sizes. Do not preserve its characters, pieces, textures, icons, battlefield art, ornaments, or small text.
Composition/framing: one true 16:9 full-screen layout diagram. Flat charcoal background. Use ten large rectangular regions with thin high-contrast outlines, restrained muted fill colors, generous padding, and exact alignment. Each region contains one large number and one clear bilingual label. The central board region is the largest. Do not add a separate legend outside the regions.
Regions: 01 RedForceSummary, 02 TurnStatusBar, 03 BlackForceSummary, 04 TacticalMinimap, 05 SelectedUnitCard, 06 BoardViewport, 07 ObjectiveEventsDrawer, 08 MarkerTool, 09 ActionModeBar, 10 ConfirmationActions.
Style/medium: low-fi vector-like UI wireframe, flat fills, crisp geometry, no cinematic art. Retain only a subtle dark-iron and antique-gold project flavor in the outlines.
Constraints: preserve the reference's region proportions closely; exactly ten numbered regions; every label must be inside its own region; no overlap; no screenshots nested inside the diagram; no watermark; no logos.
Avoid: characters, soldiers, chess pieces, minimap dots, battlefield texture, ornate frames, bronze statues, realistic lighting, decorative icons, generated filler text, extra callouts, arrows, detailed wireframe controls, comparison views, mobile layout.
```
