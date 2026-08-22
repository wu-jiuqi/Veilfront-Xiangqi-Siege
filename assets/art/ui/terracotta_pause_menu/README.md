# 教学暂停菜单按钮

本目录保存教学 ESC 暂停菜单的图像生成按钮底板。运行时中文、焦点和点击逻辑均由 Godot 预置 `Button` 节点承担，贴图只提供材质和边框。

## 文件

- `tutorial_pause_button_v1.png`：紫幕提取后的 RGBA 按钮底板，供 `StyleBoxTexture` 九宫格拉伸。
- `source_rgb/tutorial_pause_button_chroma_v1.png`：内置图像生成工具输出的 `#8A00FF` 紫幕母版，不由 Godot 导入。

## 生成提示词摘要

- 模式：内置图像生成工具生成紫幕母版；最终 Alpha 使用项目工具 `remove_chroma_background.py` 从紫幕母版确定性提取。
- 风格参考：`terracotta_hud_v2/action_button_states_v1.png`。
- 视觉约束：黑铁、旧铜、克制暗金线、秦式几何角饰、正视横向、中心无文字、无图标、无水印。
- 紫幕约束：按钮外部使用紫色 `#8A00FF`；生成器实际输出带轻微亮度渐变，因此运行 `--screen purple --border 16 --opaque-floor 0.08 --background-cutoff 0.30`，只移除紫色背景并保留按钮比例、轮廓和材质。
