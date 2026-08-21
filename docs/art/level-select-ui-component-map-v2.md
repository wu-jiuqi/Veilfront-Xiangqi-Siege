# 关卡模式 UI 母版拆件映射 v2

状态：`approved_master_selected / purple_keyed / godot_integrated`

## 唯一视觉母版

- 母版：`assets/art/ui/level_select/source/level_select_approved_master_v2.png`
- 结构底板：`assets/art/ui/level_select/level_select_empty_background_v2.png`
- 紫幕拆件源：`assets/art/ui/level_select/level_select_control_atlas_v2_purple_screen.png`
- 透明图集：`assets/art/ui/level_select/level_select_control_atlas_v2.png`
- 独立拆件：`assets/art/ui/level_select/components/*_v2.png`

母版中的视觉元素是本页面唯一美术依据，不再从 `terracotta_hud_v2` 取面板或按钮进行拼装。

## 拆件清单

| 类别 | 文件 |
|---|---|
| 返回按钮 | `back_button_v2.png` |
| 进入关卡按钮 | `enter_button_v2.png` |
| 分类卡 | `category_normal_v2.png`、`category_selected_v2.png` |
| 关卡节点 | `node_available_v2.png`、`node_selected_v2.png`、`node_completed_v2.png`、`node_locked_v2.png`、`node_disabled_v2.png` |
| 进度与奖励 | `progress_ring_v2.png`、`reward_slot_v2.png` |
| 辅助控件 | `key_frame_v2.png`、`secondary_button_v2.png` |

## 组合方式

- `level_select.tscn` 使用 1280×720 预置 `Control` 母版画布，并按窗口等比缩放、居中。
- 底板承担大框架、战役地图和路线；按钮、分类卡、关卡节点以独立 PNG 覆盖到母版坐标。
- 所有编号、标题、状态和说明由 Godot `Label/Button` 渲染，不烘焙进拆件。
- 只有关卡目录决定数量的节点由脚本实例化；其余视觉与交互节点均为场景预置节点。
- 页面不包含 SVG，也不实例化 `UiThemeBinder`，并通过独立 `level_select_master_v2_theme.tres` 使用新拆件。

## 色键规则

紫幕源使用高饱和紫背景。透明交付物经过紫色与洋红溢色清除，透明像素 RGB 归零；原始紫幕源保留用于复核和后续重新拆件，不直接进入运行时。

## 废弃边界

v1 战役背景、v1 节点图集与关卡页对 `terracotta_hud_v2` 的组装引用已废弃。该废弃不影响其他场景继续使用共享 HUD 资源。
