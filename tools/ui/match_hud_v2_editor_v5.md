# Match HUD V5 位置尺寸调参器

## 用途

用于直接调整 `match_hud_v2_interaction_lab.tscn` 对应 HUD 的位置、尺寸、文字占位与显示状态。V5 不新增关卡信息板，关卡目标、当前步骤和操作提示统一由原“战局与行动”板承载。

入口：双击 `match_hud_v2_editor_v5.html`，使用桌面浏览器打开即可，不需要启动本地服务。

## 默认方案

- 画布：1680 × 720（21:9）。
- 游戏主体：保留原 1280 × 720 HUD 与棋盘占用范围。
- 战局与行动板：`x=1280, y=144, w=360, h=504`，独立放在主体右侧。
- 信息模式：默认“关卡需求”，可切换为“联机战局”。
- 安全检测：战局板与主体边界不足 16 px 时显示红色警告。

## 操作

- 单击节点：选中；拖动节点：移动。
- 拖动八个边角手柄：调整尺寸；按住 Shift 临时关闭网格吸附。
- 方向键：1 px 微调；Shift + 方向键：按当前吸附步长微调；Alt + 方向键：调整宽高。
- “切换 21:9 并右置放大”：一键恢复本项目推荐布局。
- 文字页：修改关卡目标、步骤、当前操作和提示的内容与字号。
- 数据页：复制、下载或导入 V5 JSON；浏览器草稿只保存在当前浏览器。

## JSON 契约

- Schema：`veilfront.match_hud_layout.v5`。
- `profile`：目标分辨率。
- `preview.objective_mode`：`tutorial` 或 `match`。
- `guides.gameplay_subject_rect`：当前主体包围框。
- `guides.objective_overlaps_subject`：战局板是否遮挡主体。
- `objects`：节点矩形、层级、可见性和文字层数据。

V5 可以导入 V4 JSON；导出始终使用 V5 Schema。网页仅提供布局数据和视觉确认，不会直接修改 Godot 场景。

## Godot 落地约束

优先在场景中调整现有预置节点及 Container 约束，不动态生成新的信息板。应用 JSON 时，应把像素矩形换算为对应 Control 的 anchors/offsets，并逐项确认不同分辨率下的安全区与文本换行。
