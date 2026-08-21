# 关卡模式 v1 资源废弃说明

状态：`deprecated / keep_for_history / do_not_reference_from_level_select`

以下资源不再允许被关卡模式正式场景引用：

- `level_campaign_map_background_v1.png`
- `level_node_states_v1.png`
- `terracotta_hud_v2` 中曾用于关卡页面板、按钮和铭牌组装的共享资源

废弃范围仅限关卡模式。`terracotta_hud_v2` 仍可能被战局 HUD 等其他页面使用，不能据此全局删除。

替代资源：`source/level_select_approved_master_v2.png`、`level_select_empty_background_v2.png`、`level_select_control_atlas_v2_purple_screen.png`、`level_select_control_atlas_v2.png` 与 `components/*_v2.png`。
