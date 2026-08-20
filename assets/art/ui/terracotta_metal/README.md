# 兵马俑 UI 共享矢量资源

本目录仅保留仍在使用的兵马俑 UI 共享矢量资源。旧版面板、按钮、焦点框、页面背景和首界面废案已经由 `assets/art/ui/terracotta_hud_v2/` 取代；运行时 Theme 不再引用本目录中的位图。

## 当前资产

- `icons/`：36 个 `64×64` 金属线性语义图标，分为兵种、行动、状态、标记、系统五组。
- `cursors/`：6 个 `64×64` 交互光标。
- `patterns/`：4 个 `128×128` 秦式几何与金属底纹。

V2 位图、透明通道契约、九宫格建议与 RGB 母版说明见 `assets/art/ui/terracotta_hud_v2/README.md`。

## 制作与接入约束

- 贴图无文字、无阵营符号；按钮文字和图标继续由统一 UI 场景提供。
- SVG 源文件由 `scripts/dev/ui/generate_terracotta_ui_vectors.gd` 可复现生成；禁止手工加入未经字源校对的秦小篆字形。
- 危险按钮复用 V2 中立金属按钮贴图并在 Theme 中施加暗朱语义调制，不建立第二套材质。
- 小地图 12 个语义元素复用图标、状态标记和面板边框，不额外复制矢量源文件。

参考源：

- `assets/art/pieces/terracotta_warriors/red_guard_idle.png`
- `assets/art/pieces/terracotta_warriors/black_guard_idle.png`
