# 兵马俑对局 HUD V2

本目录是已确认概念图 `assets/art/ui/concepts/battle_hud_concept_v1.png` 的正式 V2 组件包。视觉基线为薄型锻铁、深绿氧化青铜、少量旧金线与低反射深色内衬；V2 已替换 Theme 中的旧版通用位图，`terracotta_metal/` 仅保留共享 SVG、光标和纹样。

## 组件

| 文件 | 用途 | Godot 用法 |
| --- | --- | --- |
| `hud_panel_9slice_v1.png` | 通用面板 | `NinePatchRect`，建议初始边距 72 px，再按实际控件调整 |
| `turn_status_bar_v1.png` | 顶部回合/局势条 | `TextureRect`，保持宽高比 |
| `faction_status_plate_v1.png` | 阵营状态条 | 左侧直接使用；右侧水平翻转，头像与文本由子节点覆盖 |
| `unit_info_card_v1.png` | 选中棋子信息卡 | `TextureRect` 底板，头像、属性行使用预置 `Control` 子节点 |
| `objective_event_panel_v1.png` | 目标/事件列表 | 五行预置列表容器覆盖到底板上 |
| `action_bar_frame_v1.png` | 五槽动作栏底框 | `TextureRect`，五个按钮按槽位预置布局 |
| `action_button_states_v1.png` | 动作按钮四态图集 | 横向四等分：normal / hover / pressed / disabled |
| `minimap_frame_v1.png` | 小地图边框 | 叠放在小地图 `SubViewportTexture` 上方，中央为真实透明 |
| `ui_decor_atlas_v1.png` | 菱形节点、铆钉、分隔线、选择角 | 4×2 图集；缺失的左下角由右下角水平翻转复用 |
| `turn_progress_incense/` | 燃香回合进度条分层与动画资源 | 香身从右向左裁短，8 帧烟雾循环并随进度延长，中文烟字散开后重聚 |

## 技术约束

- 成品 PNG 均为 RGBA；外部 Alpha 为 0，实体面板中心为 255。
- `minimap_frame_v1.png` 的中央窗口 Alpha 为 0。
- `source_rgb/` 保存图像生成器输出的 RGB 母版，并通过 `.gdignore` 禁止 Godot 导入。
- `turn_progress_incense/source_rgb/` 保存燃香方案的伪透明母版；运行时图层均已转换为 RGBA。
- UI 贴图使用无损导入、关闭 mipmap、启用 Fix Alpha Border。
- 文字、数值、阵营色、头像、目标图标和动作图标都不烘焙在贴图里。
- 既有 36 枚 SVG 功能图标继续来自 `terracotta_metal/icons/`；V2 通过主题色和按钮材质承载新视觉，不复制一套语义相同的图标。

## 运行时接入

- `resources/game/ui/themes/terracotta_ui_theme.tres` 已使用本目录的通用面板、四态按钮、小地图框与回合状态条。
- `scenes/game/ui/match_header.tscn` 通过 `TurnStatusPanel` 主题变体使用 V2 回合状态条。
- `scenes/game/ui/match_header.tscn` 已预置 `turn_progress_incense.tscn`，旧阿拉伯数字回合 Label 仅保留为隐藏兼容节点。
- `scenes/dev/ui/turn_progress_incense_lab.tscn` 可逐回合拖动、跳转关键回合或自动播放 1—50，专门验收燃烧、烟雾和数字动效。
- 页面全屏背景和焦点框改用轻量 `StyleBoxFlat`，不再加载旧废案背景与焦点位图。
- `scenes/dev/ui/ui_button_motion_lab.tscn` 启动时会打开完整组件预览；关闭预览后可继续测试按钮悬停、按压、焦点、禁用、页签与结果反馈动效。

## 生成与处理

- 模式：内置图像生成工具，逐项生成，概念图作为风格参考。
- 提示词共同约束：front-facing orthographic、thin forged dark iron、deep green oxidized bronze、restrained aged-gold accents、no text、no icons、no characters、no battlefield。
- 透明化：内置工具连续输出了烘焙棋盘格的 RGB 文件；原始 RGB 母版永久保存在 `source_rgb/`。
- 紫幕重抠：运行 `python tools/art/remove_baked_checkerboard.py assets/art/ui/terracotta_hud_v2 --chroma-repair --apply`。工具先生成精确 `#FF00FF` 中间层，只保留预先登记的 UI 主体，再由紫幕键出 Alpha；该流程不会重绘或调色金属纹理。
- 质量检查：运行同一工具并追加 `--validate`，会检查 RGBA、透明中心、四态按钮实体中心，以及所有可见像素均归属于登记的 UI 主体。需要人工复核时可加 `--preview-dir <目录>` 输出紫幕与深色背景合成图，中间图不进入 Godot 资源目录。
