# 关卡指引面板 V1

状态：`implementation_lab / purple_keyed / not_formal_integrated`

本目录保存关卡模式右侧`关卡指引`面板资产。项目所有者已授权接入独立测试场景进行布局审批，尚未接入正式关卡入口。

## 文件

- `source_chroma/level_guide_panel_chroma_v1.png`：内置 ImageGen 生成的 `1024×1536` 紫幕 RGB 母图；由 `.gdignore` 隔离，不参与 Godot 导入。
- `level_guide_panel_v1.png`：紫幕抠图后的 `746×1413` RGBA 审批候选，四角透明、实体中心不透明、可见区域无残紫。

## 预留内容

面板从上到下预留以下 Godot 动态内容，不在 PNG 中烘焙文字或状态：

1. 标题与收起按钮。
2. 关卡目标。
3. 三行步骤清单与菱形状态槽。
4. 当前操作。
5. 上下文提示。
6. `显示提示 / 重置步骤`两个次级按钮槽。

## 紫幕抠图

```powershell
python tools/art/purple_chroma_key.py `
  assets/art/ui/level_guide_panel/source_chroma/level_guide_panel_chroma_v1.png `
  assets/art/ui/level_guide_panel/level_guide_panel_v1.png `
  --key-distance 68 `
  --despill-distance 190 `
  --feather-radius 1.1 `
  --padding 12 `
  --max-size 1536
```

当前测试接入：`res://scenes/game/ui/level_guide_panel.tscn` 与 `res://scenes/dev/ui/level_gameplay_hud_lab.tscn`。正式入口、正式关卡状态和九宫格定稿仍需项目所有者后续审批。
