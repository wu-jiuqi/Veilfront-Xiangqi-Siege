# 联机房间 UI 资产

- `lan_lobby_board_backdrop_v1.png`：从已确认的“战场本身即棋盘”视觉样片复制出的房间背景。
- 运行时双方席位直接复用 `red_general_idle.png` 与 `black_general_idle.png`，不复制、不重绘棋子。
- 面板继续复用 `terracotta_hud_v2/hud_panel_9slice_v1.png` 的黑铁、旧金和低反射金属语言。
- 背景只承担环境识别，实际房间文字、席位状态、连接输入与按钮全部由 Godot 预置 Control 节点提供。
