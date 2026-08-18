# GATE-2 正式架构前置独立 QA 审阅 v1

结论：`blocked`

审阅时间：`2026-08-18T12:05:23.8578957+08:00`

## 审阅身份与权限

- 执行实例：`inst:01M02NJ3JFHVZ5C4SP5MTJFJR6`
- Position：`pos:veilfront-xiangqi-siege:quality:qa-release-lead`
- Authority：`AUTH-VEILFRONT-QA-RELEASE`
- 审阅任务：`game-pipeline/loops/evidence/GATE2-architecture-review-assignment.md`
- 审阅范围仅限 Contract 准入证据；未修改架构、Contract、规则、代码、Registry 或技术审阅文件。
- QA 实例与 Godot 技术负责人实例 `inst:01M02NJ3JEQXKV6PT6DPX0NKQ0` 不同，Organization Registry 还明确禁止两职位共享实例，独立性满足。

本结论不是 GATE-2 人工决定，也不批准生产循环启动。它只判断 `INPUT-ARCH-REVIEW-001` 当前能否作为可靠准入输入。

## 结论摘要

Project Brief v5、Loop Contract 审批、项目实例与组织权限均可验证；Contract 对互联网、AI、高成本批量美术和 GATE-2 人工权限的边界也清楚。

当前仍不能把 `INPUT-ARCH-REVIEW-001` 标记为满足，原因不是实现尚未完成，而是它依赖的必需规则基线存在互相矛盾的生产事实源：Project Brief v5 与 `rules-spec-v1.md` 已冻结为“士主动献祭复活、取消被动替死”，但 `settlement-order-v1.md` 仍是 revision 3 的被动替死结算，`rules-test-coverage-matrix-v1.md` 也仍把多项被动替死规则作为结算覆盖项。待审架构报告同时要求把这些文档保留为行为事实源，无法确定正式迁移究竟应保持哪一种结算语义。

此外，架构报告自身仍标记为“等待 Project Brief v5 确认”，其基线提交早于 Brief 与 Contract 的正式批准；报告也没有冻结观察者可见事件、错误、行动提示和回放之间的安全 DTO 边界。若按当前报告启动迁移，存在把 FullState、隐藏相田来源、隐身马或未发现旗位通过事件、提示、教学或回放旁路泄露的风险。

因此，本次审阅为 `blocked`。必须先恢复一致、可追溯的规则输入，再修订并重新绑定架构报告；不能通过解释或口头摘要把当前输入视为已批准。

## 证据身份与新鲜度

| 证据 | 当前身份 | 新鲜度与校验结果 |
|---|---|---|
| Project Brief v5 | subject digest `41bb82fae4f1a0294d17746f3b9caf063ee69d2bd07e0f7d15d26baad9ab89bb`；approval `approval:veilfront-xiangqi-siege:project-brief:41bb82fae4f1` | `validate_project_brief.py` 退出码 0，`confirmed / ready`；文件 SHA-256 `276d777409f6218c2448e4886879216e09b4e2ea9fa2118f595dc30f14c551e9` 与 approval 的 materialized digest 一致。 |
| Loop Contract | `LOOP-CTR-FORMAL-FOUNDATION-GATE2-001@v1`；approved source digest `9beb91baa720820d0f0985019e5a77a4e0e065a8721451eedc30e0cc22bdeaef` | approval 存在；当前物化文件 SHA-256 `a26a9b3fdb0d8d06e42a06833a84455d911fea8f72bcedec59d0ae5e620cc205` 与 approval 的 materialized digest 一致。 |
| GATE-1 | approval subject digest `8f93c3506192b1e286bd5f1bf631054f9fb3f0dc5337f3050716a2186a383597` | approval 与 final handoff 存在；首循环 Registry 为 `completed / revision 63 / sequence 63`。 |
| 项目与组织 | plugin `0.4.0-alpha.2`；QA/Godot 技术职位及实例已登记 | `validate_project_instance.py` 退出码 0、state `normal`；`validate_organization_registry.py` 退出码 0。 |
| 待审架构报告 | 文件 SHA-256 `9e8d7c14aef5f5bb7e46d74fb9d3a1c1321e04967b70a14591801a78c30f60f1`；提交 `e274206ec4f4b87f1c8f0ebec1eb59bef49da419` | 该提交时间早于 Brief v5 确认和 Contract 批准；正文仍写 `draft / awaiting Project Brief v5 confirmation`，末尾仍要求先确认 Brief、再批准 Contract，与当前事实不一致。不能作为“经技术与 QA 审阅后的版本”直接绑定。 |
| 规则输入 | `rules-spec-v1.md` revision 5；`settlement-order-v1.md` revision 3；`rules-test-coverage-matrix-v1.md` revision 5 producer verification | 三者版本与士复活语义不一致。`INPUT-RULES-001` 要求 owner revision 5 的规则、结算和测试基线，但当前集合不能形成唯一结算事实。 |

上述受审源文件在检查开始时没有 tracked diff。工作树另有与本审阅无关的未跟踪文件，因此本次只声明“受审源未改动”，不声明整个工作树 clean；Contract 在最终独立 QA 阶段要求的 clean-worktree 复现仍须另行执行。

## 自动检查记录

| 检查 | 命令/方法 | 结果 |
|---|---|---|
| 项目实例 | `python .../validate_project_instance.py --project-root . --plugin-root .../game-production-pipeline/0.4.0-alpha.2` | PASS，退出码 0，state `normal`。 |
| Project Brief | `python .../validate_project_brief.py game-pipeline/project-definition/project-brief.yaml --project-id veilfront-xiangqi-siege --approval-dir game-pipeline/approvals` | PASS，退出码 0，subject digest 与任务基线一致。 |
| Organization Registry | `python .../validate_organization_registry.py --snapshot game-pipeline/organization/snapshot.yaml --history game-pipeline/organization/event-history.yaml` | PASS，退出码 0。 |
| Loop Contract 结构 | 只读 PyYAML 检查 Contract ID/version/status、approval digest、7 个 deliverable、5 个 required input、9 个 check 的唯一性及 task output 引用 | PASS，退出码 0。 |
| 通用 Pipeline Contract validator | `validate_pipeline_contract.py` 对当前 Loop Contract 返回“contract 根必须是映射”并退出 1 | NOT APPLICABLE：该工具验证的是 `pipeline_contract` 根结构，不支持本文件的 `loop_contract` schema；不把这一工具不兼容误记为 Contract 失败。 |
| 规则事实一致性 | 对 Project Brief、`rules-spec-v1.md`、`settlement-order-v1.md`、`rules-test-coverage-matrix-v1.md` 做逐源文本比对 | FAIL：主动献祭与被动替死同时存在于被指定保留的事实源。 |
| 补丁卫生 | 完成后执行 `git diff --check` | 见报告交付校验；不得替代上述语义缺陷。 |

## Contract 验收可执行性

| Contract 检查 | 当前评价 | 准入要求 |
|---|---|---|
| `CHECK-CONTRACT-002` | 部分可执行 | Brief、approval、Organization、Git 摘要可机器核验；`INPUT-ARCH-REVIEW-001` 仍未通过，不能启动。 |
| `CHECK-DEPENDENCY-001` | 尚不可充分执行 | 报告给出目录和单向依赖意图，但未冻结“只有 application 持有 FullState”“projection 输出 observer event/error/preview”“presentation/tutorial 只接收 PlayerView”的可扫描依赖规则与禁止导入清单。 |
| `CHECK-MIGRATION-001` | 阻断 | 旧基线文档互相矛盾；报告也未绑定精确的旧提交、固定 seed 清单、replay manifest 和 state/event/PlayerView codec 版本，无法判定何谓等价。 |
| `CHECK-INFORMATION-002` | 尚不可充分执行 | Contract 枚举了旗位、隐身马、相田来源和私有标记，但报告只明确排除 FullState、规则 RNG 和未发现旗位；缺少可见事件、统一错误、三级提示、私有标记本地存储、回放权限以及隐藏等价配对的架构落点。 |
| `CHECK-TUTORIAL-001` | 方向可执行，边界未冻结 | 固定 seed、checkpoint、合法 Intent/Event、完成/失败/重置/退出可测；但 `TutorialDirector` 被写为监听“领域 Event”，未区分 raw domain event 与 observer-visible event，可能绕开 PlayerView。 |
| `CHECK-GODOT-002` | 可在循环内执行 | 预置场景/Resource 映射合理；最终需绑定 Godot 4.7.1 导入和无头场景加载命令、场景清单与提交。 |
| `CHECK-RESPONSIVE-001` | 可在循环内执行 | 三种窗口条件明确；最终需记录精确较小窗口尺寸、截图/结构证据和无裁切判据。 |
| `CHECK-ART-001` | 可在循环内执行 | 类别与清单字段基本明确；体验与风格是否值得量产仍是项目所有者在 GATE-2 的判断。 |
| `CHECK-SCOPE-001` | 可执行 | Contract 和报告均明确禁止互联网实现、AI 交付与高成本批量资产，可通过依赖/文件/服务配置清单审计。 |

## 信息泄露风险审计

1. **Raw Event 旁路**：报告允许 `TutorialDirector` 监听正式领域 Event，却未定义按观察者过滤后的 `PlayerEvent`/`VisibleEvent`。原始事件可能携带隐藏棋身份、相田来源、未公开随机选择或精确失败原因。
2. **行动提示与错误旁路**：未把 revision 5 信息契约中的 `KNOWN_LEGAL / TENTATIVE / KNOWN_ILLEGAL`、统一模糊错误、固定字段/时序桶写入正式 DTO 边界；表现层若直接查询 domain 合法行动，可从隐身马、隐藏炮架或相田阻挡反推 FullState。
3. **Replay 权限不清**：报告把 Replay Record 列为跨边界契约，但没有区分权威审计回放与玩家可见回放。包含规则种子、FullState 或 raw events 的回放若进入表现/教学/未来客户端会直接泄露旗位与随机状态。
4. **私有标记归属不清**：Contract 要求私有标记隔离，现行信息契约要求标记只存在本机表现层；架构报告未为其指定非权威、本地且不进入 PlayerView/Replay 的存储位置。
5. **观察者身份与投影调用权未冻结**：报告说明 PlayerView 按观察者生成，但未规定只有 application 可选择 viewer 并调用 projector。表现或教学若能自选 viewer，仍可读取对方视角。

这些风险在当前循环不实现互联网时仍成立，因为正式棋盘、教学和本地回放已经是潜在泄露通道。

## 缺陷与责任返回路径

### `QA-G2-ARCH-001` — blocker

问题：`INPUT-RULES-001` 不是一致、可靠的 owner revision 5 事实源。

证据：

- Project Brief v5 与 `rules-spec-v1.md`：士主动献祭，取消被动替死。
- `settlement-order-v1.md`：阶段 6 和特殊窗口仍规定被动士替死、候选士与炮击替死。
- `rules-test-coverage-matrix-v1.md`：仍以被动替死的 `SET-RESCUE-001`、车路径逐目标替死等作为覆盖目标，并含过期 Gate 状态。
- 架构报告又把上述规则、结算、信息边界文档整体列为“保留为行为事实源”。

返回：`pos:veilfront-xiangqi-siege:design-experience:systems-experience-lead` 修订结算顺序与规则—测试覆盖矩阵，使其完整对应 owner revision 5；若发现不是文档落后而是规则仍有歧义，升级 `project-owner`，不得由 QA 选择语义。Godot 技术负责人随后重新绑定唯一规则基线。

关闭条件：规则规格、结算顺序、信息边界、测试覆盖矩阵都标明同一 owner revision，士献祭、阵亡池、复活池、炮击与车路径结算不存在被动替死残留；给出文件摘要和受影响测试清单。

### `QA-G2-ARCH-002` — high

问题：架构报告身份与审批事实过期，尚不是 Contract 所要求的“经技术与 QA 审阅后的版本”。

返回：`pos:veilfront-xiangqi-siege:technology:godot-technical-lead` 更新报告基线、状态和下一合法动作；`pos:veilfront-xiangqi-siege:root:project-manager` 用修订后的精确文件摘要重新发起双审，不得沿用当前 SHA-256。

关闭条件：报告绑定 confirmed Brief v5、approved Contract v1、GATE-1 approval 与修正后的 rules baseline 摘要，状态不再声称等待已经完成的批准。

### `QA-G2-ARCH-003` — high

问题：FullState、raw Event、observer-visible Event/Error/ActionPreview、PlayerView 与 Replay 的信任边界未冻结，教学可能绕过投影。

返回：`pos:veilfront-xiangqi-siege:technology:godot-technical-lead` 定义 DTO、调用权和依赖禁止项；`pos:veilfront-xiangqi-siege:design-experience:systems-experience-lead` 确认教学只消费指定观察者的 PlayerView 与可见事件，不直接监听 raw domain event。

关闭条件：至少明确 application 独占 FullState/viewer 选择权；projection 是唯一 FullState→PlayerView/VisibleEvent/VisibleError 出口；表现、教学和未来 endpoint 不可访问 FullState、raw audit/replay 或自选观察者；私有标记保持本地非权威；提供隐藏等价与错误外形的可执行测试设计。

### `QA-G2-ARCH-004` — high

问题：迁移等价基线未冻结到不可歧义的测试资产。

返回：`pos:veilfront-xiangqi-siege:technology:godot-technical-lead` 建立迁移 manifest；`pos:veilfront-xiangqi-siege:quality:qa-release-lead` 在下一次独立审阅中验证，不参与生产 manifest 的编写。

关闭条件：manifest 至少绑定 GATE-1 候选提交 `6253678157157091584b253470e709bad17c534f`、规则/信息源摘要、固定 seed 列表、replay 样本、canonical state/event/PlayerView codec 版本、比较命令与“何时必须重跑 1000 seed”的触发条件。

## 失败回退与权限边界

- 当前回退点是“循环未启动”；不创建第二循环 Registry，不写入 `INPUT-ARCH-REVIEW-001` satisfied，不实施正式架构。
- 保留 GATE-1 RC3、固定 seed、回放、manifest 和独立 QA 证据，不通过修改旧证据消除冲突。
- 规则事实修正返回系统与体验负责人；技术边界和迁移 manifest 返回 Godot 技术负责人；审批绑定和重审登记返回项目经理；QA 只复核。
- 若修订引入新的规则语义而非修正文档漂移，必须返回 Project Brief/规则变更人工确认，并评估 Contract approval 是否失效。
- 即使后续两份架构前置审阅均为 `approved`，也只授权登记和启动第二生产循环。
- GATE-2 只能在正式灰盒、教学、视觉样片、资产清单和独立 QA 完成后进入 `awaiting_human`，最终批准权仅属于 `project-owner`。
- GATE-2 前仍禁止互联网/Steam 网络实现、服务器采购、AI 交付和高成本批量美术；人工偏好不能覆盖失败的自动检查。

## 下一合法动作

1. 系统与体验负责人关闭 `QA-G2-ARCH-001`，提供一致的 revision 5 规则、结算与覆盖矩阵摘要。
2. Godot 技术负责人关闭 `QA-G2-ARCH-002/003/004`，提交修订架构报告和迁移 manifest。
3. 项目经理按修订报告的精确摘要重新发起技术与独立 QA 双审。
4. 只有两份审阅均为 `approved`、全部 blocker/high 缺陷关闭，才可把 `INPUT-ARCH-REVIEW-001` 标记为满足并登记第二生产循环。

在此之前，任何实现、Registry 启动或 GATE-2 状态推进都不是合法下一步。

## 报告交付校验

- `git diff --check -- evidence/gate2/architecture-independent-qa-review-v1.md`：PASS，退出码 0。
- 本实例只创建 `evidence/gate2/architecture-independent-qa-review-v1.md`，未提交、未推送。
