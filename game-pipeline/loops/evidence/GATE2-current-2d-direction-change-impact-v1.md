# GATE-2 当前二维方向变更影响记录 v1

状态：`project_brief_v7_confirmed / awaiting_contract_v3_approval`

## 决定

项目所有者要求将斜俯视三渲二方案放到项目后期作为进阶可选项，现阶段正式实现改用 2D。

## 对当前循环的影响

- Contract v2 的 `TASK-PRESENTATION-3D-001`、`TASK-TUTORIAL-3D-COMPAT-001`、三维视觉检查与 GATE-2 问题不再符合当前项目方向。
- 当前循环必须进入 `waiting_approval`，保存 `active / iteration 3` 为恢复状态；在 Brief v7 与 Contract v3 获得精确摘要批准并迁移 Registry 前，不得继续按旧3D目标生产。
- 旧 Contract v2、Registry 事件、失败记录、已接受规则/迁移/教学产物和既有3D研究资产全部保留，不重写历史。

## 保留与降级

- 继续保留：确定性规则核心、DTO/依赖护栏、PlayerView、回放、教学 Intent/Event、二维正式场景与历史灰盒行为基线。
- 降级为后期可选研究资产：Node3D/Sprite3D正式化方案、14枚兵马俑静态棋子、三维美术测试场、镜头、三维旗帜与相关证据。
- 既有有限追认审批继续只证明历史资产可有限留存与验证，不授权当前主线继续三维生产。

## 新目标

以预置 Control/Node2D、Sprite2D/AnimatedSprite2D、二维观察者安全迷雾和响应式 HUD 建立正式二维对局壳，补齐二维视觉基线与教学兼容证据，经过独立 QA 后形成修订版 GATE-2 人工决策包。

## 恢复生产的前置条件

1. Project Brief v7 摘要由项目所有者明确确认并物化合规审批；
2. 绑定 Brief v7 的 Contract v3 摘要另行确认并批准；
3. Registry 合法迁移到 Contract v3，更新输入、任务、Reviewer 检查与保留产物映射；
4. 项目实例、Registry 与工作区复检通过。
