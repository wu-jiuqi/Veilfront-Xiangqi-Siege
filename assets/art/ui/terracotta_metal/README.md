# 兵马俑金属 UI 贴图样片

本目录存放首批可由 Godot 直接导入的兵马俑 UI 金属贴图。材质参考红方银白钨钢与黑方深墨绿青铜棋子，通用控件采用中立暗金属与旧金包边，避免把阵营颜色写入基础 UI。

## 当前资产

- `metal_panel_frame_v1.png`：`1254×1254`，透明内外区域，用于 `StyleBoxTexture` 九宫格面板。
- `metal_button_states_v1.png`：`2172×724`，从左到右依次为普通、悬停、按下、禁用状态，用于 `AtlasTexture + StyleBoxTexture`。
- `metal_focus_frame_v1.png`：`1254×1254`，透明内外区域，用于键盘／手柄焦点九宫格。

三张 PNG 均已机械检查为 RGBA，Alpha 范围为 `0–255`。Godot 导入使用无损压缩、关闭 mipmap，并启用 Alpha 边缘修正。

## 制作与接入约束

- 贴图无文字、无阵营符号；按钮文字和图标继续由统一 UI 场景提供。
- 当前为风格样片，不替代最终 UI 皮肤验收。
- 接入 Theme 前需要在实际 `52 px` 按钮和不同窗口尺寸下确定 Atlas 区域、九宫格边距和最小尺寸。
- 危险按钮的朱红金属图集尚未通过真实 Alpha 检查，未纳入本目录。

参考源：

- `assets/art/pieces/terracotta_warriors/red_guard_idle.png`
- `assets/art/pieces/terracotta_warriors/black_guard_idle.png`
