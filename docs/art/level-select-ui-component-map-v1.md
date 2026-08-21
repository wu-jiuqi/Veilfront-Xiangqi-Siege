# 关卡模式 UI 概念拆件映射 v1

状态：`deprecated_for_level_select_runtime`

废弃原因：项目所有者已指定 `level_select_approved_master_v2.png` 为唯一视觉母版，并要求关卡模式不再复用旧 UI 组装。当前正式映射见 `docs/art/level-select-ui-component-map-v2.md`。本文件只保留为历史记录。

生成提示词：`docs/art/level-select-ui-imagegen-prompts-v1.md`

## 1. 母稿结构

- 左栏：模式切换、教学完成进度。
- 中栏：关卡军令节点与推进顺序。
- 右栏：当前关卡编号、标题、目标、状态和进入按钮。
- 背景：低对比度俯视战役地形，UI 始终高于背景层级。

母稿仅用于确定构图与材质语言。母稿内自动生成的节点编号不作为关卡事实源；正式目录仍为 T0–T10 与 C1–C3。

## 2. 位图组件映射

| 组件 | 运行时资产 | 用法 |
|---|---|---|
| 战役地图背景 | `assets/art/ui/level_select/level_campaign_map_background_v1.png` | 全屏 `TextureRect`，`KEEP_ASPECT_COVERED` |
| 关卡节点五状态 | `assets/art/ui/level_select/level_node_states_v1.png` | `AtlasTexture`：普通、焦点、选中、完成、锁定 |
| 主面板九宫格 | `assets/art/ui/terracotta_hud_v2/hud_panel_9slice_v1.png` | 左栏、中栏、右栏复用 `StyleBoxTexture` |
| 按钮状态组 | `assets/art/ui/terracotta_hud_v2/action_button_states_v1.png` | 返回、分类、进入、重置按钮复用 Theme 状态 |
| 标题与状态铭牌 | `assets/art/ui/terracotta_hud_v2/faction_status_plate_v1.png` | 关卡详情标题和进度信息框 |
| 金属分隔与角饰 | `assets/art/ui/terracotta_hud_v2/ui_decor_atlas_v1.png` | 小尺寸装饰，不承载文字语义 |
| 中文字体 | `assets/fonts/noto_sans_sc/NotoSansSC-VariableFont_wght.ttf` | 所有可变文字由 Godot `Label/Button` 渲染 |

## 3. 组合约束

- 不使用 SVG；本页面只消费 PNG 位图与字体。
- 不把中文文字烘焙进贴图，避免错字并保留本地化能力。
- 固定布局使用预置 `Control`、`Container`、`TextureRect` 与 Theme；只动态实例化目录决定数量的关卡节点。
- 960×540、1280×720、1920×1080 下保持主要按钮不裁切，交互高度不低于 44 px。
- 锁定、完成、选中除颜色外还分别使用锁链、勾印、顶端箭标表达，颜色不是唯一语义通道。

## 4. 概念图误差处理

母稿中的最后一枚教学节点被生成器误写为 T11。正式组件不含任何烘焙编号，Godot 从 `LevelCatalog` 覆盖真实编号，因此不会进入运行时内容。
