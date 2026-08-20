# 棋子美术测试场景映射 v1

状态：`implemented_for_sample_testing / not_formal_match-integration`

绑定：`LOOP-CTR-FORMAL-FOUNDATION-GATE2-001@v2 / TASK-PRESENTATION-3D-001`

## 产物映射

| Contract/美术输入 | Godot 产物 | 用途 |
|---|---|---|
| 通用棋子节点基线 | `res://scenes/game/match/board_3d/piece_3d.tscn` | 预置 `Node3D → VisualPivot → Sprite3D`、假阴影、脚底锚点、Area3D点击体和选择环 |
| 棋子透明运行时纹理 | `Piece3D/VisualPivot/Sprite3D.texture` | 美术交付后逐实例替换；默认占位图只用于确认画幅和锚点 |
| 斜俯视游戏内样片 | `res://scenes/dev/art/piece_art_test_3d.tscn` | 预置棋盘、网格、墙线、近中远重叠位、环境、灯光、30° FOV相机和说明UI |
| 美术测试镜头导航 | `res://scripts/dev/art/piece_art_test_camera_rig.gd` | 中键拖拽受限旋转、WASD棋盘平面移动、棋盘范围与俯仰角限位 |
| 结构与参数复查 | `res://tests/game/presentation/run_piece_art_test_3d_contract.gd` | 无头验证节点层级、Sprite3D透明/深度参数、棋盘尺度、镜头校准带和六个测试位 |
| 镜头行为复查 | `res://tests/game/presentation/run_piece_art_camera_navigation_contract.gd` | 无头验证拖拽状态、俯仰/水平角限制、WASD移动方向与棋盘边界限制 |

## 使用约定

- 直立棋子默认按 `512×768`、脚底锚点 `(0.50, 0.94)`、完整画布世界高度 `1.60` 预设。
- 骑兵 `768×768`、锚点 `(0.50, 0.92)` 时，需要在实例上把 `pixel_size`、`offset` 和碰撞盒调到骑兵规格；待首张骑兵运行时图完成后再冻结专用变体。
- `Sprite3D` 固定使用 Fixed-Y Billboard、Opaque Pre-Pass、深度测试开启、不受实时灯光、不投实时阴影、不固定屏幕尺寸。
- `FogSurface` 默认关闭，只供排序检查；正式迷雾仍必须绑定单一观察者安全 `9×24` mask。
- 测试镜头的移动目标限制在棋盘底座范围内：X `[-5.7, 5.7]`、Z `[-14.7, 14.7]`；俯仰角仅允许向下 `35°–80°`，水平转角限制为 `±75°`，避免看到棋盘底部或完全背离测试对象。
- WASD 复用 `project.godot` 已预置的 `board_pan_up/down/left/right` 动作；中键拖拽属于鼠标指针手势，不新增硬编码键盘分支。
- 本测试场不接规则、PlayerView或主场景，不会创建任何未授权棋子；正式三维对局集成属于后续同一Contract任务。

## 编辑器操作

打开 `piece_art_test_3d.tscn`，在 `PieceRoot` 下选中目标实例，启用“可编辑子项”，然后将运行时透明PNG拖到 `VisualPivot/Sprite3D.texture`。可分别替换近、中、远的前后两个槽位，直接运行当前场景检查透明边缘、脚底线、遮挡和阵营轮廓。
