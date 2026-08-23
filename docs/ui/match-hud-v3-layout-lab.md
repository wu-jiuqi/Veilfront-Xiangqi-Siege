# 联机对局 HUD V3 紫幕拆分与测试场景

日期：2026-08-23

状态：`owner_approved_mockup / purple_assets_ready / lab_ready / formal_online_integrated`

预览场景：`res://scenes/dev/ui/match_hud_v3_layout_lab.tscn`

验收脚本：`res://tests/game/ui/run_match_hud_v3_layout_lab_contract.gd`、`res://tests/game/ui/run_online_match_hud_v3_contract.gd`

证据截图：`res://evidence/ui/match-hud-v3-layout-lab-1280x720.png`、`res://evidence/ui/online-match-hud-v3-1280x720.png`

## 已实现

- 删除香盘、计时香、回合香及其节点；顶部 `TurnStatus` 是唯一回合与倒计时入口。
- 双方头像下各保留三项公开信息：已占旗帜、损失棋子、正在占旗进度。
- 左侧单位卡只显示棋子名称、现有全身立绘、身份定位与一句介绍；不显示兵力、士气、数值条或放大按钮。
- 右侧战局板固定为五行：发现旗帜、我方损失、敌方损失、当前坐标、当前操作状态。
- 底部左侧仅显示当前棋子的行动规则与技能说明；右侧只有上下排列的`移动 / 技能`模式按钮。
- 屏幕标记按钮已删除，继续使用棋盘右键私有标记菜单；确认行动与取消保持独立区域。

## 项目内容复用

测试场景只调整 HUD。以下内容未重新生成，也未改写正式表现逻辑：

- `res://scenes/game/match/board/board_viewport.tscn`
- `res://scenes/game/ui/tactical_minimap.tscn`
- `res://resources/game/content/boards/terracotta_battlefield_v3_map_option.tres`
- `res://resources/dev/ui/match_hud_v2_terracotta_lab_theme.tres`
- `res://assets/art/pieces/terracotta_warriors/*_idle.png`

因此测试画面中的棋盘地图、精确网格、棋盘棋子与单位立绘均来自现有项目资产；ImageGen 只生产 UI 空框和按钮底板。

## 参数绑定

紫幕 PNG 不含任何动态文案。实验脚本从 `PlayerView` 形态的数据刷新：

| UI | 数据 |
|---|---|
| 顶部栏 | `full_round_index`、`active_side`、本地倒计时 |
| 军势摘要 | `flags.owner`、`flags.capturing_side / capture_progress`、`casualties.side` |
| 战局板 | 已发现旗帜数、双方损失类型与数量、棋盘当前坐标、交互状态 |
| 单位卡 | 选中棋子的 `side / piece_type / position` 与现有立绘路径 |
| 行动区 | 当前棋子行动规则、技能说明、技能可用性与当前模式 |

实验场景中的`确认行动`只循环演示占旗进度，不会写入正式规则核心。正式联机场景已由对局控制器提交规范化意图，再用服务端返回的观察者安全 `PlayerView` 刷新 HUD。

## 正式联机接入

- `res://scenes/game/match/online_match_screen.tscn` 作为联机专用组合根，实例化 `res://scenes/game/ui/match_hud_v3.tscn`。
- `formal_lan_game_app.tscn` 已切换到联机专用组合根；教程和本地旧入口继续使用 V2，避免香盘教学布局被连带替换。
- `match_screen.gd` 通过导出的 `hud_root_path` 一次性绑定预置节点，同时兼容 V2 和 V3，不在运行时生成 UI。
- 顶部回合栏、双方三项摘要、战局五行、单位介绍、行动规则和技能按钮全部使用真实 `PlayerView` 动态刷新。
- 正式 V3 Theme 使用项目所有者提供的`檎风黑体 Alt CHS Regular`单字体面；字体授权随资源保留。
- 空闲态确认按钮动态显示`跳过回合`，预提交态显示`确认行动`；炮／士的技能按钮动态显示`轰炸 / 复活`。

## 验收

已通过：

- GDScript 语法验证。
- 32 枚正式开局棋子、正式棋盘地图与网格复用检查。
- 紫幕母版／透明抠图 alpha 合同。
- 无香类节点、无兵力／士气节点、双侧各三项摘要、右侧坐标行、两个纵向行动按钮检查。
- 占旗进度、损失数量、回合、倒计时与战局事件动态刷新检查。
- `1024×576`、`1280×720`、`1600×900`、`1680×720` 布局边界与非重叠检查。
- 正式联机大厅到对局、红黑视角、行动提交、右键私有标记、终局和断线清理全链路检查。
- 旧 V2 HUD 兼容与正式场景冒烟检查。

## 尚未完成

- V3 目前只接入正式联机入口；教程／关卡模式尚未迁移。
- 尚未将按钮状态拆为独立手绘贴图；实验场景使用同一底板的 Godot 样式调色完成交互态。
- 关卡闯关界面会复用同一骨架，但右侧五行内容需要改为关卡目标、步骤、当前操作和提示；本次没有把两个界面合成一张图或一个场景。
