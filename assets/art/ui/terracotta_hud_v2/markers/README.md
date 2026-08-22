# 兵马俑标注 UI

本目录包含右键战术标注菜单的正式框体与图标图集。

- `marker_menu_frame_v1.png`：固定比例标注弹窗框体，运行时由预置 `TextureRect` 承载，标题和坐标文字不烘焙进图片。
- `marker_icon_atlas_v1.png`：2×2 图集，顺序为圆、叉、方、清除；菜单和棋盘标注共用同一组 `AtlasTexture`。
- `source_rgb/`：内置图像生成工具输出的紫幕 RGB 母版，由 `.gdignore` 阻止 Godot 导入。

生成提示词共同约束：front-facing orthographic、thin forged dark iron、deep green oxidized bronze、restrained aged-gold trim、muted violet tactical enamel、no text、uniform chroma-magenta background。

抠图命令：

```powershell
python tools/art/extract_generated_purple_screen.py assets/art/ui/terracotta_hud_v2/markers/source_rgb/marker_menu_frame_v1.png assets/art/ui/terracotta_hud_v2/markers/marker_menu_frame_v1.png --trim --padding 18 --max-width 1024
python tools/art/extract_generated_purple_screen.py assets/art/ui/terracotta_hud_v2/markers/source_rgb/marker_icon_atlas_v1.png assets/art/ui/terracotta_hud_v2/markers/marker_icon_atlas_v1.png --size 1024 1024
```

成品 PNG 为 RGBA；UI 贴图使用无损导入、关闭 mipmap，并启用 Fix Alpha Border。
