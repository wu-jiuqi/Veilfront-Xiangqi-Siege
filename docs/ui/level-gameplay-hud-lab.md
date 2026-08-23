# 关卡场景 HUD 测试场景

日期：2026-08-23
状态：`approved_reference / formal_integrated_T0-T10`

## 运行入口

- 测试场景：`res://scenes/dev/ui/level_gameplay_hud_lab.tscn`
- 关卡指引组件：`res://scenes/game/ui/level_guide_panel.tscn`
- 结构测试：`res://tests/game/ui/run_level_gameplay_hud_lab_contract.gd`
- 审批截图：`res://evidence/ui/level-gameplay-hud-lab-1280x720.png`
- 正式关卡入口：`res://scenes/game/tutorial/tutorial_level.tscn`
- 正式关卡指引组合：`res://scenes/game/ui/level_guide_overlay.tscn`
- 正式效果截图：`res://evidence/ui/formal-level-t3-hud-1280x720.png`

## 复用边界

测试场景直接实例化正式联机场景 `online_match_screen.tscn`，因此顶部军势、回合条、左侧小地图与单位卡、中部棋盘、底部行动规则全部继续使用正式 `MatchHudV3`。正式 `RightRail` 容器继续保留 `284px` 布局占位，只隐藏其内部的 `ObjectiveEvents / Confirmation` 内容，再在相同容器坐标覆盖独立 `LevelGuidePanel`。不能隐藏 `RightRail` 本身，否则 `HBoxContainer` 会释放右栏宽度并让棋盘扩张到关卡指引下方。

`LevelGuidePanel` 的背景使用已审批的 `level_guide_panel_v1.png`，标题、目标、三步状态、当前操作、提示和按钮文字均由预置 `Label/Button` 节点承载，没有烘焙进图片。

## 正式接入映射

- `TutorialLevel` 继续拥有本地权威会话、`TutorialDirector`、进度存档和终局导航，不复制规则状态。
- `MatchScreen` 改为实例化正式 `online_match_screen.tscn / MatchHudV3`；`RightRail` 始终保留 `284px` 布局占位，只隐藏联机战局内容。
- `LevelGuideOverlay` 把 `TutorialPresentationTrack` 的目标、当前步骤、前后步骤、提示级别和反馈映射到 `LevelGuidePanel`；观察步骤、规则问答、完成和失败使用预置的中央决策面板。
- 右栏确认区被关卡指引取代后，正式关卡使用行动按钮二次确认：`移动 → 确认移动`、`轰炸 → 确认轰炸`、`复活 → 确认复活`；右键继续承担取消职责。
- 本次正式逻辑验收范围为 T0–T10。按项目所有者决定，C1–C3 仍保留现有测试入口，不纳入本次通过结论。

## 测试交互

- `显示提示`：揭示当前步骤提示，并进入禁用态。
- `重置步骤`：恢复为第一步激活、其余步骤待完成。
- `〉/〈`：在完整右栏与 44px 收起条之间切换。

测试场景仍保留为独立布局回归入口；正式接入没有创建第二份规则状态，也没有修改联机入口或管线 Registry。
