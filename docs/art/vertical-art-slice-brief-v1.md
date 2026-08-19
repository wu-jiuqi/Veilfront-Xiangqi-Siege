# 45°三维棋盘首轮视觉样片任务书 v1

状态：`ready_for_preproduction / no_batch-production`

## 目标

用最小可运行样片验证新视觉基线的最大风险：24×9长棋盘构图、Sprite3D前后遮挡、三维迷雾、红黑镜像、透明排序和交点点击。

样片不是宣传截图，也不要求完成全套角色。失败结果必须保留，因为它决定镜头、比例和资产成本是否需要回退。

## 样片范围

| 编号 | 产物 | 数量 | 状态 |
|---|---|---:|---|
| VS-BOARD-01 | 战场底板材质样片 | 1 | 待制作 |
| VS-GRID-01 | 9×24精确网格覆盖 | 1 | 待制作 |
| VS-WALL-01 | 城墙完整/受损/倒塌样片 | 3状态 | 待制作 |
| VS-PIECE-01 | 红方步兵透明立绘 | 1 | 金属兵马俑概念R2；待所有者审查 |
| VS-PIECE-02 | 黑方步兵透明立绘 | 1 | 金属兵马俑概念R2；待所有者审查 |
| VS-PIECE-03 | 红方骑兵透明立绘 | 1 | 待制作 |
| VS-PIECE-04 | 黑方骑兵透明立绘 | 1 | 待制作 |
| VS-FLAG-01 | 中立旗帜与发现记忆图标 | 1组 | 待制作 |
| VS-FOG-01 | 9×24迷雾mask与边缘噪声 | 1组 | 待制作 |
| VS-FX-01 | 选择环、合法落点、攻击反馈 | 3 | 待制作 |
| VS-UI-01 | 战局侧栏皮肤局部样片 | 1 | 待制作 |

## Godot预置场景目标

```text
VisualSlice3D (Node3D)
├─ WorldEnvironment
├─ Lighting (Node3D)
│  └─ DirectionalLight3D
├─ Board3D (Node3D)
│  ├─ BoardBase (MeshInstance3D)
│  ├─ GridOverlay (MeshInstance3D)
│  ├─ FogSurface (MeshInstance3D)
│  ├─ StructureRoot (Node3D)
│  └─ HighlightRoot (MultiMeshInstance3D)
├─ PieceRoot (Node3D)
├─ EffectRoot (Node3D)
├─ CameraRig (Node3D)
│  └─ PitchPivot (Node3D)
│     └─ Camera3D
└─ UI (CanvasLayer)
```

固定结构必须在 `.tscn` 中预置。样片棋子可以从预置 `Piece3D` PackedScene 实例化；不得把整棵场景树写进脚本动态生成。

## 测试局面

- 近、中、远三段分别放置步兵和骑兵，至少形成两次前后重叠。
- Y=4放置完整墙，Y=21放置倒塌墙，观察前后遮挡与点击。
- 可见区域覆盖一枚敌棋，入雾区域保留一个未授权敌棋坐标，但不创建该棋表现节点。
- 放置一面已发现后重新入雾的旗帜记忆图标。
- 分别以红方和黑方视角运行，同一交点点击返回同一权威坐标。

## 验收记录

每次样片审查必须记录：

- Git提交、Godot版本、渲染器与运行分辨率；
- 摄像机俯角/FOV/距离、棋子世界高度与屏幕像素高度；
- 透明模式、贴图尺寸、显存估算和平均帧率；
- 三张目标分辨率截图和红黑视角对照；
- 遮挡、排序、雾泄露、点击误差和HUD裁切问题；
- 结论为 `pass / revise / blocked`，不得用“看起来还行”替代。

## 失败回退

- 遮挡失败：先在45°～55°和冻结棋子高度区间校准；仍失败再回视觉基线审查。
- 透明排序失败：比较 Opaque Pre-Pass 与 Alpha Hash，不开启 No Depth Test。
- 性能失败：先降低运行时纹理、阴影、粒子与高级后处理，不降低信息边界要求。
- 迷雾泄露：立即判定 blocked，返回 PlayerView/表现映射修复，禁止用更黑的雾遮掩。
