# GATE-1 核心体验假设人工决策包

状态：`awaiting_human / decision_not_made`

本文件只整理 GATE-1 决策证据，不构成批准。项目所有者未对本文件末尾的当前摘要作出单独决定前，不得开始正式功能开发、正式 UI、美术、音频、动画或资产生产。

## 决策范围

项目所有者需要判断：当前逻辑垂直切片是否已经充分验证《雾疆：九路烽棋》的核心循环、玩家行为、胜负与反馈闭环，以及复杂结算、迷雾、确定性和公平 AI 等最大风险；其剩余技术成本与风险是否值得进入正式功能开发。

本决定不冻结单局完整轮上限、AI 搜索预算、AI 随机性或难度，也不把可丢弃原型认定为正式架构。

## 决策证据水位（生成基线）

下列 rev35/seq35 是本包生成前的完整验收水位。本包随后作为 `DELIVERABLE-GATE1-001` 追加登记时，只会增加一条指向本文件摘要的 `core.output_registered`，不会改变下列 Contract、QA、构建或验收事实，也不纳入本包自引用摘要。

- Loop：`LOOP-GATE1-001 / Iteration 1`
- 状态：`review`
- Snapshot：`record_revision=35 / last_event_sequence=35`
- Event History 尾摘要：`5fc2de832c8cc726d50819ad77ecced2cbe7c11a6bce9cc42d4df4685389bc0e`
- Loop Contract：`LOOP-CTR-GATE1-VERTICAL-SLICE-001 v2`
- Contract v2 subject digest：`7b7fcf36920109d379aa0e230cf70a378ed7ec228ff6a88bccf35cf481fcf09c`
- Pipeline Contract：`CTR-P1-001 v1`
- Pipeline Contract subject digest：`189b691e6c60b0c5c7b069081ebe34e726ff038211d60a33084eee5638499014`
- 独立 QA 提交：`83616cc6cb2e56d19b3ec401ec105baf9ef49dd4`
- 独立 QA 报告 SHA-256：`62bceb167f35bd87f3b1d996dc3635689004dc99509b824d88a2c2e7674cc7b5`
- QA 验收 subject digest：`cff3c765f16e2d7fa65af0ef704c9e0b6bb5bb4a2cf025f9c80f60e7731361c4`

## 证据索引

- 规则规格与结算顺序：`docs/prototype/rules-spec-v1.md`、`docs/prototype/settlement-order-v1.md`
- 信息边界与观测计划：`docs/prototype/information-boundary-v1.md`、`docs/prototype/gate1-observation-plan-v1.md`
- Godot 路径与可丢弃边界：`docs/prototype/godot-artifact-map-v1.md`
- 规则覆盖矩阵：`docs/prototype/rules-test-coverage-matrix-v1.md`
- 最新独立 QA：`evidence/prototype/qa/iteration-1-qa-p1-003-contract-v2-recheck.md`
- QA-P1-003 决策基线：`game-pipeline/loops/evidence/QA-P1-003-decision-package.md`
- Contract v2 迁移检查：`game-pipeline/loops/evidence/QA-P1-003-contract-v2-migration-check.md`
- 当前 Registry：`game-pipeline/loops/registry/first-production-loop/snapshot.yaml`、`event-history.yaml`

## 已观察事实

### 自动与专业检查

| 检查 | 结果 | 说明 |
|---|---|---|
| 项目实例 | PASS | exit 0，state=normal，errors/warnings 为空 |
| Pipeline Contract | PASS | CTR-P1-001 v1，exit 0 |
| Organization Registry 历史重放 | PASS | exit 0 |
| Loop 官方 CLI | **FAILED** | exit 1，恰好六项批准的模板错误；没有第七项错误 |
| QA-P1-003 | `owner-approved tooling exception` | 受控临时例外，未修复、未关闭 |
| 未修改 `validate_history()` | PASS（限定范围） | exit 0，error_count=0；不替代官方 CLI |
| Loop Registry 摘要链 | PASS | rev30 前缀、seq31 迁移、seq32-35 验收与状态事件、rev35 Snapshot 一致 |
| Godot 4.7.1 import/main/run_all | PASS | 无解析、导入或资源加载错误；`full_gate1=false` 保持 |
| 固定种子对局 | PASS | 1000/1000，failure 0 |
| 确定性 | PASS | mismatch 0；回放抽样 10/10 |
| 独立 QA | PASS WITH CONTROLLED EXCEPTION | 无 Registry 损坏、权限越界或新增缺陷 |

官方 CLI 没有通过。进入 `review` 的依据是项目所有者批准的 Contract v2 对这一精确失败集合建立了临时兼容规则，且独立 QA 重新执行并接受了该例外。

### 原型结果

- 24×9、216 格逻辑原型可从固定种子加载并运行。
- 规则、复杂结算、PlayerView、迷雾、回放、相/象显形生命周期与 AI 公平性聚合测试通过。
- 1000 个种子全部合法终止；records digest 为 `dcc6947442ee14d05636953095d07c19ebd093ff616449598612082baa03575d`。
- 批量结果：红胜 5、黑胜 9、和棋 986；14 局由轮上限旗帜判胜，986 局为轮上限和棋。
- 当前完整轮上限 8 仍为 `hypothesis_cli_overridable`，未冻结。
- 压力策略中车多目标与修墙触发数为 0，说明这些组合仍需后续针对性体验与覆盖，而不是证明机制无效。

## 推论

- 技术证据支持“复杂规则、战争迷雾、确定性随机与只读取 PlayerView 的公平 AI 可以在 Godot 4.7.1 中共同运行”。
- 1000/1000 与零确定性差异降低了规则核心、回放和批量验证的主要技术风险，但不能回答核心循环是否足够有趣、反馈是否易懂或长期参数是否合适。
- 高比例轮上限和棋表明当前批量 AI/轮上限组合不是正式平衡结论；它不阻止 GATE-1 验证技术可行性，但应成为正式开发前期的优先实验。
- 当前原型仍是可丢弃切片；批准 GATE-1 也不等于批准沿用其架构或表现层。

## 未解决风险

1. QA-P1-003 依赖临时兼容规则；插件、框架、校验器、错误集合、rev30 前缀或 Contract v2 变化都会使例外失效。
2. `full_gate1=false` 保持，人工仍需判断核心循环、胜负反馈、恢复与技术成本。
3. 986/1000 轮上限和棋，轮上限、AI 搜索预算、随机性与难度需要后续实验。
4. 批量策略未覆盖车多目标和修墙的自然触发频率，需要正式测试计划继续补足。
5. Godot editor 首次扫描后的强制退出出现 `Scan thread aborted` warning；本次 exit 0 且无解析/资源错误。

## 可逆决策选项

### A. 批准 GATE-1（推荐，附条件）

批准当前 subject digest 进入正式功能规划，同时明确：

- QA-P1-003 继续保留为受控临时例外，官方 CLI 仍为 failed；
- 正式功能架构需重新审查，不默认继承可丢弃原型；
- 轮上限、AI 预算、随机性与难度继续作为假设实验；
- 视觉与资产生产仍须遵循后续 GATE-2/GATE-3，不能因 GATE-1 批准直接批量生产最终资产。

推荐理由：当前证据已经覆盖本切片的主要技术风险，剩余问题更适合在正式功能早期以受控实验处理；批准仍可通过后续 Gate 回退。

### B. 要求修订

将 Loop 从 `review -> active`，进入 Iteration 2，明确要求补充人工试玩、反馈闭环或和棋/策略覆盖。该转换会增加 iteration，必须把具体修订项写入新的审查反馈。

### C. 拒绝或返回 P1

若项目所有者认为核心循环、表达闭环或剩余成本不可接受，则返回 P1 修订；若问题改变项目范围，则返回 P0。保留所有失败种子、回放、规格与技术探索证据。

## 项目所有者需要回答

1. 移动、侦察、破城、炮击、三旗争夺与实际吃掉将帅是否构成值得继续的核心循环？
2. 胜利、失败、恢复、视野变化与行动反馈是否形成可理解、可测试的闭环？
3. 当前切片是否实际验证了复杂结算、迷雾泄露与 AI 公平性等最大风险？
4. Godot 技术可行性、需要重写的原型范围和后续成本是否可接受？
5. 是否批准进入正式功能开发，并允许后续按 Gate 启动视觉基线与资产生产准备？

## 决定记录（待项目所有者单独填写）

- 选择：`批准 / 修订 / 拒绝`
- 决定者：`project-owner`
- 决定时间：`待填写`
- 条件或修订要求：`待填写`
- GATE-1 决策摘要：`336402912f73349ed06c8d44c31e1211a480fabad4e4136339e0c26af8ca90e8`

摘要采用 canonical JSON（UTF-8、对象键排序、无额外空白）计算 SHA-256，输入为：

```json
{"exception_status":"owner-approved tooling exception","gate_1_decision":"not_made","last_event_digest":"5fc2de832c8cc726d50819ad77ecced2cbe7c11a6bce9cc42d4df4685389bc0e","last_event_sequence":35,"loop_contract_digest":"7b7fcf36920109d379aa0e230cf70a378ed7ec228ff6a88bccf35cf481fcf09c","loop_instance_id":"4cbb03b6-dd5a-41c5-a624-895c4b884bcb","official_cli":{"error_count":6,"exit_code":1,"result":"failed"},"pipeline_contract_digest":"189b691e6c60b0c5c7b069081ebe34e726ff038211d60a33084eee5638499014","qa_acceptance_subject_digest":"cff3c765f16e2d7fa65af0ef704c9e0b6bb5bb4a2cf025f9c80f60e7731361c4","qa_report_commit":"83616cc6cb2e56d19b3ec401ec105baf9ef49dd4","qa_report_sha256":"62bceb167f35bd87f3b1d996dc3635689004dc99509b824d88a2c2e7674cc7b5","registry_revision":35,"subject":"GATE-1-decision-package-v1"}
```

任一绑定输入变化后，本决策包必须重新生成，旧摘要不得批准。
