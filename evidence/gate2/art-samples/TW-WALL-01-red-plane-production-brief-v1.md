# TW-WALL-01 红方平面城防阵线样片 v1

状态：`producer_sample_completed / pending_godot_runtime_and_independent_QA`

任务：`TASK-ART-001`

方向依据：`docs/art/veilfront-wall-plane-visual-amendment-v1.md`

## 已完成

- 红方 `INTACT / BREACHED / REPAIRING` 三张 `2048×192` 透明SVG。
- 3D纹理导入参数：VRAM Compressed、mipmap、Fix Alpha Border、最大2048。
- 预置 `RedWallPlane3D` 场景，三个状态节点全部预建；脚本只切换节点可见性。
- 完整阵型测试场已移除旧BoxMesh墙，Y=4接入红方平面样片；黑方状态留作审查后制作。
- 静态三状态审查页：`evidence/gate2/art-samples/review/TW-WALL-01-red-three-state-review-v1.png`。

## 状态语义

- `INTACT`：连续双线与九路菱形节点。
- `BREACHED`：全线分散断裂，避免误导成单一缺口。
- `REPAIRING`：保持断裂，叠加旧金重组箭纹；不表达进度值。
- “受损”不作为状态资产，后续单独制作瞬时反馈。

## 技术边界

- 根节点锚定Y=4墙线，PlaneMesh尺寸 `10.6×0.72`，高度 `0.018`。
- 无碰撞体，不参与棋盘点击、合法性或路径判定。
- 运行时只允许从观察者安全 `PlayerView.walls[].status` 驱动。
- 源文件、导入设置、预置场景和测试场变更均纳入Git；不提交`.godot/imported/`。

## 当前验证限制

当前Windows环境没有可用Godot 4.7.1可执行文件，`gda`返回`binary_not_found`，因此本轮只能完成SVG渲染、资源尺寸、导入侧车和TSCN静态检查。以下证据仍待补齐：

- Godot真实导入与脚本编译；
- 完整阵型下三状态截图；
- 三分辨率、双方视角、Z-fighting与棋子/高亮层级；
- 独立QA与GATE-2审美判断。

本文件不把静态源图完成解释为运行时验收通过。
