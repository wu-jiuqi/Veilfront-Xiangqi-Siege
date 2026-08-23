# Match HUD V3 紫幕组件

本目录是已确认的去香盘联机对局 HUD V3 测试组件。只提供 UI 框体与按钮底板，不包含棋盘、棋盘网格、棋子、棋子立绘、动态图标、文字、数字或进度。

## 目录

- `source_chroma/`：ImageGen 生成的高饱和紫幕母版，保留复抠与边缘修订能力；该目录通过 `.gdignore` 排除 Godot 导入。
- 根目录 `*_v1.png`：由项目紫幕工具抠出的透明运行时 PNG，均使用无损导入。

## 组件

| 运行时 PNG | 用途 |
|---|---|
| `turn_status_bar_v1.png` | 顶部唯一回合、行动方、倒计时栏 |
| `faction_summary_plate_v1.png` | 左右军势头像框与三项公开摘要槽 |
| `minimap_frame_v1.png` | 战场态势小地图外框 |
| `unit_info_card_v1.png` | 名称、全身立绘、定位简介单位卡；无兵力、士气、放大按钮 |
| `objective_events_panel_v1.png` | 五行战局／行动／坐标面板 |
| `action_rules_panel_v1.png` | 左侧规则与技能说明、右侧两个模式槽 |
| `button_plate_v1.png` | 通用按钮底板，由 Godot 样式控制悬停、按下、禁用、焦点 |
| `panel_9slice_v1.png` | 确认区等通用九宫格面板 |

## 生成与抠图约束

ImageGen 使用 `ui-asset` 生产模式。公共提示要求正视图、暗铁／氧化青铜／旧金兵马俑风格、闭合轮廓、无文字、无数字、无图标、无角色、无香炉与燃香；背景为均匀高饱和紫幕，目标色接近 `#FF00FF`。每次只生成一个独立组件，再按上述组件职责约束内部开孔或槽位。

抠图使用项目已有脚本：

```powershell
python tools/art/extract_generated_purple_screen.py `
  --input <source_chroma_png> `
  --output <runtime_png> `
  --trim `
  --padding 12
```

测试会检查母版四角为高饱和紫、透明成品四角 alpha、实体面板中心 alpha，以及头像窗／小地图窗的透明开孔，避免将残紫或错误孔洞带入运行时。

## 运行时接入边界

- 测试场景：`res://scenes/dev/ui/match_hud_v3_layout_lab.tscn`。
- 组件由预置 `Control / Container / Label / TextureRect / Button` 装配，动态信息不进入贴图。
- 主棋盘继续实例化正式 `board_viewport.tscn`，小地图继续实例化正式 `tactical_minimap.tscn`。
- 棋盘地图、网格、棋盘棋子与单位卡立绘继续使用项目现有资源。
- 当前只完成实验场景，不替换正式 `match_hud_v2.tscn`；待项目所有者审阅实验画面后再迁移数据接口与正式入口。
