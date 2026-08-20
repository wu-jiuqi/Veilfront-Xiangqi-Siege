# GATE-2 Contract v3 Registry 迁移计划

状态：`applied / registry_revision_56 / active_iteration_3`

## 迁移对象

- Loop：`83c995ff-37b9-4df8-9e84-8417d6632187`
- 起点：Contract v2，Registry `waiting_approval / iteration 3 / revision 41`
- 目标：Contract v3，保留 iteration 3 并在完整复检通过后恢复 `active`
- 审批：`approval:veilfront-xiangqi-siege:loop-contract:9d9e3cfc5e92`

## 保留

- 全部 Registry 事件历史、中断现场、规则核心、PlayerView、回放与教学语义；
- 已登记的架构、迁移、旧表现和QA产物，继续作为历史或回归证据；
- 既有三维与三渲二资产作为后期可选研究资产，不计入当前验收。

## 替换

- Contract 绑定由 v2 替换为 v3；
- Brief v6、旧三维视觉基线、旧三维资产清单与墙面修订输入退出当前有效输入；
- 绑定 Brief v7、当前二维方向、二维资产清单和 revision 41 保留产物集合；
- Executor task scope 与 Reviewer check scope 全部改为 Contract v3 的二维 ID。

## 恢复复检

恢复前必须逐项通过：Contract、输入、依赖、授权、预算和转换证据。复检只允许返回首次保存的 `resume_state=active`，不得增加 iteration，不得解释为 GATE-2 通过。
