# 兵马俑对局 HUD V2

本目录是已确认概念图 `assets/art/ui/concepts/battle_hud_concept_v1.png` 的第一批可制作组件。视觉基线为薄型锻铁、深绿氧化青铜、少量旧金线与低反射深色内衬；旧版 `terracotta_metal/` 暂时保留，不覆盖也不删除。

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

## 技术约束

- 成品 PNG 均为 RGBA；外部 Alpha 为 0，实体面板中心为 255。
- `minimap_frame_v1.png` 的中央窗口 Alpha 为 0。
- `source_rgb/` 保存图像生成器输出的 RGB 母版，并通过 `.gdignore` 禁止 Godot 导入。
- UI 贴图使用无损导入、关闭 mipmap、启用 Fix Alpha Border。
- 文字、数值、阵营色、头像、目标图标和动作图标都不烘焙在贴图里。
- 既有 36 枚 SVG 功能图标继续来自 `terracotta_metal/icons/`；V2 通过主题色和按钮材质承载新视觉，不复制一套语义相同的图标。

## 生成与处理

- 模式：内置图像生成工具，逐项生成，概念图作为风格参考。
- 提示词共同约束：front-facing orthographic、thin forged dark iron、deep green oxidized bronze、restrained aged-gold accents、no text、no icons、no characters、no battlefield。
- 透明化：内置工具连续输出了烘焙棋盘格的 RGB 文件；经项目所有者明确授权后，使用 `tools/art/remove_baked_checkerboard.py` 只清除与指定背景种子连通的浅灰棋盘格，并保留 RGB 源图。
