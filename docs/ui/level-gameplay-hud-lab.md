# 关卡场景 HUD 测试场景

日期：2026-08-23
状态：`implementation_lab / not_formal_integrated`

## 运行入口

- 测试场景：`res://scenes/dev/ui/level_gameplay_hud_lab.tscn`
- 关卡指引组件：`res://scenes/game/ui/level_guide_panel.tscn`
- 结构测试：`res://tests/game/ui/run_level_gameplay_hud_lab_contract.gd`
- 审批截图：`res://evidence/ui/level-gameplay-hud-lab-1280x720.png`

## 复用边界

测试场景直接实例化正式联机场景 `online_match_screen.tscn`，因此顶部军势、回合条、左侧小地图与单位卡、中部棋盘、底部行动规则全部继续使用正式 `MatchHudV3`。正式 `RightRail` 容器继续保留 `284px` 布局占位，只隐藏其内部的 `ObjectiveEvents / Confirmation` 内容，再在相同容器坐标覆盖独立 `LevelGuidePanel`。不能隐藏 `RightRail` 本身，否则 `HBoxContainer` 会释放右栏宽度并让棋盘扩张到关卡指引下方。

`LevelGuidePanel` 的背景使用已审批的 `level_guide_panel_v1.png`，标题、目标、三步状态、当前操作、提示和按钮文字均由预置 `Label/Button` 节点承载，没有烘焙进图片。

## 测试交互

- `显示提示`：揭示当前步骤提示，并进入禁用态。
- `重置步骤`：恢复为第一步激活、其余步骤待完成。
- `〉/〈`：在完整右栏与 44px 收起条之间切换。

本测试不接入主菜单或正式关卡入口，不创建第二份规则状态，也不改变联机 HUD 或管线 Registry。
