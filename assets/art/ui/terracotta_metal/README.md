# 兵马俑金属 UI 美术资源包

本目录存放可由 Godot 直接导入的兵马俑 UI 金属贴图与矢量资源。材质参考红方银白钨钢与黑方深墨绿青铜棋子，通用控件采用中立暗金属与旧金包边，避免把阵营颜色写入基础 UI。

## 当前资产

- `metal_panel_frame_v1.png`：`1254×1254`，透明内外区域，用于 `StyleBoxTexture` 九宫格面板。
- `metal_button_states_v1.png`：`2172×724`，从左到右依次为普通、悬停、按下、禁用状态，用于 `AtlasTexture + StyleBoxTexture`。
- `metal_focus_frame_v1.png`：`1254×1254`，透明内外区域，用于键盘／手柄焦点九宫格。
- `metal_screen_background_v1.png`：`1254×1254`，不透明低对比锻打金属背景，用于页面底板。
- `main_menu_concept_v1.png`：`1672×941`，首界面兵马俑皮肤示意图，仅供布局、氛围与风格评审，不作为可直接接入的最终 UI 贴图。
- `icons/`：36 个 `64×64` 金属线性语义图标，分为兵种、行动、状态、标记、系统五组。
- `cursors/`：6 个 `64×64` 交互光标。
- `patterns/`：4 个 `128×128` 秦式几何与金属底纹。

三张框体／按钮运行时 UI PNG 均已机械检查为 RGBA，Alpha 范围为 `0–255`；背景和首界面示意图为 RGB，不要求透明通道。Godot 导入使用无损压缩、关闭 mipmap，并启用 Alpha 边缘修正。

## 制作与接入约束

- 贴图无文字、无阵营符号；按钮文字和图标继续由统一 UI 场景提供。
- SVG 源文件由 `scripts/dev/ui/generate_terracotta_ui_vectors.gd` 可复现生成；禁止手工加入未经字源校对的秦小篆字形。
- 首界面示意图遵循现有三个入口：`局域网联机对战 / 关卡模式 / 退出游戏`；图中文字、棋盘网格与装饰纹样不得拆出作为生产母版。
- 危险按钮复用中立金属按钮贴图并在 Theme 中施加暗朱语义调制，不建立第二套材质。
- 小地图 12 个语义元素复用图标、状态标记和面板边框，不额外复制矢量源文件。

参考源：

- `assets/art/pieces/terracotta_warriors/red_guard_idle.png`
- `assets/art/pieces/terracotta_warriors/black_guard_idle.png`
