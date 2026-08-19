# GATE-2视觉方向Contract v2迁移计划

状态：`applied / registry_revision_39`

Contract v2待确认主题摘要：`ce2d6174f82af003b023f80e2ae3676510df541f4a6ac129bfcf69847361b20d`

摘要算法：`canonical-json-sort-keys-without-approval-binding-v1`

## 迁移原因

Project Brief v6已经以摘要`54520517ac26859c24459accb2d7672d12d0224ef69a766f883eda7b2b523289`获项目所有者批准。当前GATE-2 Contract v1仍绑定Brief v5和二维表现映射，不能继续授权受新方向影响的生产工作。

## 保留

- 当前Registry全部23条事件及摘要链。
- 已接受的正式规则/DTO/PlayerView/Replay架构边界。
- Iteration 2正式核心迁移、回归和项目所有者采样例外记录。
- 现有教学Intent/Event、固定局面和交互成果。
- 旧二维表现、截图和复核作为历史灰盒证据。

## 取代

- `DELIVERABLE-PRESENTATION-001@iteration1`不删除，但不再代表最终美术场景结构。
- 新增`DELIVERABLE-PRESENTATION-3D-001`，取代Node2D/Camera2D/TileMapLayer的最终表现映射。
- `TASK-ART-001`改为绑定已经冻结的视觉基线、资产清单和首轮样片任务书。

## Contract批准后的Registry动作

1. 校验当前snapshot revision、last event digest和v1 Contract文件摘要。
2. 追加`contract_revision_proposed`和`contract_revision_approved`证据引用，不重写历史。
3. 更新Contract binding为同一Contract ID的version 2及其物化文件摘要。
4. 绑定Brief v6、视觉基线、资产清单和v1保留产物输入。
5. 当前迭代迁移为`ITERATION-3R-OBLIQUE-3D-VISUAL`，登记三项任务责任和回退路径。
6. 运行`validate_loop_registry.py`，通过后才允许制作样片或修改正式表现层。

## 应用结果

- 项目所有者于`2026-08-19T20:01:59.1988259+08:00`批准Contract v2主题摘要。
- 不可变批准记录：`approval:veilfront-xiangqi-siege:loop-contract:ce2d6174f82a`。
- Contract v2物化文件摘要：`bf2d09e7117960de4b178d827dc2c123ab4b83777175e5b1b0c9cca6eabe561d`。
- Registry在保留原23条事件的基础上追加16条类型化事件，当前revision/sequence为39。
- 当前状态保持`active / iteration 3`，Contract binding更新为version 2。
- Brief v6、迁移前Registry、视觉基线、资产清单和v1已接受产物已绑定为v2输入。
- 技术、系统体验、视觉与QA职责范围已更新到v2任务和检查项。
- `validate_formal_foundation_gate2_registry.py`通过。

## 仍然禁止

- 不批准GATE-2，不启动批量资产生产。
- 不接入互联网服务或AI交付，不修改规则、PlayerView、教学语义和随机消费顺序。
- 参考图只能作为风格输入，不得将其文字、标识或具体角色造型直接作为项目交付资产。
