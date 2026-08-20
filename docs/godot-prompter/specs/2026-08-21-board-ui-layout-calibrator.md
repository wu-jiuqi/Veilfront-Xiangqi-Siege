# 正式 2D 棋盘 × HUD 布局校准工具

## 目的

`board_ui_layout_calibrator.tscn` 用于在正式 2D 棋盘接入 HUD 前确定棋盘的屏幕默认可视区域。青色框描述的是 `SubViewportContainer` 在设计画布中的位置和尺寸，不是 `1152×3072` 棋盘世界的完整尺寸；完整棋盘仍在该窗口内通过摄像机上下滚动。

## 使用方式

1. 在 Godot 中运行 `res://scenes/dev/ui/board_ui_layout_calibrator.tscn`。
2. 拖动青色框内部移动窗口，拖动八个金色控制点调整尺寸。
3. 用左侧 SpinBox 做像素级修正，并切换 16:9、21:9、16:10、4:3 逻辑画布检查布局。
4. 点击“复制布局 JSON”交付正式场景接入，或“保存本机参数”写入 `user://veilfront_board_ui_layout.json`。

## 输出合同

- `meaning` 固定为 `default_visible_board_screen_rect`。
- `explicitly_not` 固定为 `full_board_world_size`。
- `default_visible_board_rect_px` 用于当前设计画布的像素对齐。
- `default_visible_board_rect_normalized` 用于跨分辨率接入，正式实现应优先使用这一组值。
- `full_board_world_size_reference` 仅用于防止混淆，不允许由本工具修改。

## 结构说明

场景节点较多是因为工具必须在同一预览中预置七个正式 HUD 组件、八个缩放控制点、参数面板和安全区；这些节点均作为可在编辑器直接检查的 `Control` 节点保存，没有在运行时动态生成视觉层级。交互脚本只负责同步矩形、输入和 JSON 数据。
