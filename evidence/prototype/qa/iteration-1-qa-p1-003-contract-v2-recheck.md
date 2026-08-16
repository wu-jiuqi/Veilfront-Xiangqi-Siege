# QA-P1-003 Contract v2 迁移后独立复检

- 执行日期：2026-08-16（Asia/Shanghai）
- QA Instance：`inst:01M02NJ3JFHVZ5C4SP5MTJFJR6`
- 受测提交：`10ce887839d6646a160034a182b7a32a96df8d6c`
- Loop：`LOOP-GATE1-001 / Iteration 1`
- Contract：`LOOP-CTR-GATE1-VERTICAL-SLICE-001 v2`
- v2 subject digest：`7b7fcf36920109d379aa0e230cf70a378ed7ec228ff6a88bccf35cf481fcf09c`
- 插件：`game-production-pipeline@0.4.0-alpha.2`
- 框架摘要：`3589bce5cf4388f91a08f12acb5d90679256191d5085e65687d06a635bbdcd32`
- 校验器摘要：`90804f2221af1973d099f4fc531fd39e8aaaaca7bf101922ee63c9c67f909633`

## 结论

本次独立复检满足 Contract v2 `temporary_tooling_compatibility.all_conditions_required` 的全部条件。QA 接受本次例外，但只接受其批准名称与边界：`owner-approved tooling exception`。

- 官方 `validate_loop_registry` CLI：**failed**，退出码恰好为 `1`，错误集合恰好为批准的六项；不得表述为通过。
- `QA-P1-003`：仍为 `controlled_temporary_exception_until_official_plugin_fix`，不是已修复或关闭。
- Registry：未观察到损坏、断链、水位不一致或 Contract 绑定不一致。
- 权限：未观察到越界；本 QA Instance 在 Organization Registry 中为 `active`，且启动记录明确 QA 与生产实例不同。
- 技术回归：通过。
- 新增缺陷：无。
- Loop 当前状态：仍为 `active / iteration 1 / revision 31 / sequence 31`。
- 下一状态：根据 v2 已满足 `active -> review` 的专业准入条件，**允许项目经理执行该转换**；QA 本次不修改 Registry，也不代替项目经理执行转换。
- `GATE-1`：`not_made`，仍须项目所有者人工决定。
- 正式功能与资产生产：在 GATE-1 单独批准前仍为 `forbidden`。

## Observed facts

### 治理、Contract 与 Registry

| 检查 | 命令摘要 | 退出码 | 观察结果 |
|---|---|---:|---|
| 项目实例 | `python .../validate_project_instance.py --project-root .` | 0 | `state=normal`；插件锁 `normal`；`errors=[]`、`warnings=[]`；锁定/安装版本与框架摘要一致 |
| Pipeline Contract | `python .../validate_pipeline_contract.py game-pipeline/loops/contracts/CTR-P1-001-vertical-slice.yaml` | 0 | `OK` |
| Organization Snapshot + History | `python .../validate_organization_registry.py --snapshot game-pipeline/organization/snapshot.yaml --history game-pipeline/organization/event-history.yaml` | 0 | Contract、摘要、Snapshot 与 Event History 重放一致 |
| 官方 Loop CLI（Contract v2） | `python .../validate_loop_registry.py --snapshot .../snapshot.yaml --event .../loop-registry-event.template.yaml --contract .../loop-contract-gate1-vertical-slice-v2.yaml --state-machine .../loop-state-machine.default.yaml --history .../event-history.yaml` | 1 | **failed**；恰好六项批准的模板/运行态冲突错误 |
| 未修改 `validate_history()` | `python game-pipeline/loops/tools/qa_p1_003_migration.py verify-history` | 0 | 先核对锁定校验器 SHA-256 为 `90804f...9633`，再调用其未修改 `validate_history()`；`history_error_count=0`、`errors=[]` |
| rev30/seq31 迁移链 | `python game-pipeline/loops/tools/qa_p1_003_migration.py verify-migrated` | 0 | `result=OK`；rev30 字节前缀、rev30 尾摘要、seq31 事件摘要及 Snapshot 水位一致 |

官方 CLI 的错误集合逐项为：

1. `Snapshot 模板初始状态必须等于状态机 initial_state`
2. `Snapshot 模板 current_iteration 必须从 0 开始`
3. `注册后的 Snapshot 模板必须位于 sequence=1、record_revision=1`
4. `draft 注册基线的 inputs 和 outputs 必须为空`
5. `Snapshot input_slot_id 必须完整对应 Contract required_inputs`
6. `Snapshot deliverable_id 必须完整对应 Contract required_deliverables`

没有第七项错误。

摘要链观察：

- rev30 Event History 字节前缀 SHA-256：`17a75a74da3a3314353351d22dc0fb6d7f8c4b941ae8f617b4e3b7c2f97b83e8`
- rev30 尾事件摘要：`1c4508c725c900959f649e6761bd0e54d3c1fcb5e14f35089b320fa43fe32e89`
- seq31 事件：`core.contract_migrated`
- seq31 事件 ID：`27bb2cdc-9abb-4848-9ff8-1a4f3724d6a1`
- seq31 事件摘要：`ddd6c352ee46f1bded259f1467db697e7dc9bf7739bd3eb65ba89997a55cd579`
- Snapshot：`contract_version=2`、`contract_digest=7b7fcf...f09c`、`record_revision=31`、`last_event_sequence=31`、`current_state=active`、`current_iteration=1`
- v2 文件 SHA-256：`5a9ed8f5854865adfecbcff808f8dc96af52abecb371dbd18bb8fd137a775e62`

### Godot 4.7.1 与全量原型回归

| 检查 | 命令摘要 | 退出码 | 观察结果 |
|---|---|---:|---|
| 引擎版本 | `godot --version` | 0 | `4.7.1.stable.official.a13da4feb` |
| Import/editor | `godot --headless --path . --editor --quit-after 1` | 0 | 首次文件扫描完成；无解析、导入或资源加载错误；强制退出记录 `Scan thread aborted` warning |
| 主场景 | `godot --headless --path . --quit-after 2` | 0 | `GATE1_PROTOTYPE_READY seed=471001 cells=216 core=prototype_core_revision3 full_gate1=false` |
| 全量原型测试 | `godot --headless --path . --script res://tests/prototype/run_all.gd` | 0 | `PROTOTYPE_BASIS_CHECKS_PASSED scaffold=9 focused_suites=10 full_gate1=false`；规则、结算、迷雾、回放、相/象九格、PlayerView 与 AI 公平性聚合套件全部通过 |

Import 产生的四个临时 `.uid` 文件已在本次执行中删除；没有保留任何生产代码、测试代码或 Registry 越界改动。

### 1000 固定种子与确定性

命令：`godot --headless --path . --script res://tests/prototype/run_seeded_matches.gd -- --seeds 1000`

退出码：`0`

- `requested_seeds=1000`
- `completed_matches=1000`
- `failure_count=0`
- `determinism_checked_count=1000`
- `determinism_mismatch_count=0`
- `replay_sample_count=10`
- `replay_verified_count=10`
- `records_count=1000`
- `records_digest=dcc6947442ee14d05636953095d07c19ebd093ff616449598612082baa03575d`
- winner：red `5`、black `9`、draw `986`
- reason：`round_limit_flags=14`、`round_limit_draw=986`
- rounds：min/p50/p90/p95/max 均为 `8`
- metrics：bombardments `3793`、candidate evaluations `55152`、flag captures `14`、rescues `18`、rook multi-targets `0`、wall breaches `1`、wall repairs `0`
- `full_round_limit_hypothesis=8`；状态仍是 `hypothesis_cli_overridable`，未被 QA 冻结为正式规则

## Verdict

`professional_review=pass_with_owner_approved_tooling_exception`；`GATE-1=awaiting_human`

专业判定如下：

1. 接受 QA-P1-003 的受控临时例外，因为 v2 精确绑定的版本、摘要、六项错误集合、历史重放、摘要链、Godot 回归、1000 种子与确定性条件全部满足。
2. 官方 CLI 结果仍是 **failed**；本判定不把失败转换成通过，也不关闭 QA-P1-003。
3. 未发现 Registry 损坏、权限越界或新增缺陷。
4. 允许 `active -> review`；该许可只用于整理并提交 GATE-1 决策包，不构成 GATE-1 批准。
5. `GATE-1` 未决定；正式生产仍禁止。

## Unresolved risks

- 锁定插件官方 CLI 仍无法对 active 运行态 Snapshot 给出整体通过；例外会在插件/框架/校验器摘要变化、错误集合变化、rev30 前缀变化、v2 被替换/撤销、正式修复可用或出现新一致性问题时立即失效。
- Godot editor 的 `--quit-after 1` 在首次扫描完成后仍产生 `Scan thread aborted` warning；本次退出码为 0 且没有解析、导入或资源错误。
- 批量策略下 `986/1000` 为轮上限和棋，且车多目标与修墙指标为 0；这是回合上限、AI 策略与体验判断风险，不是本次自动验收新增缺陷，也不得由 QA 自动冻结参数。
- `full_gate1=false` 保持不变；核心循环、反馈闭环、技术成本与残余风险是否值得继续，必须由项目所有者在 GATE-1 单独判断。

## 下一合法动作

项目经理可在不改变本报告事实的前提下执行 `active -> review`，并仅整理/提交绑定当前 Contract、构建和证据摘要的 GATE-1 决策包。项目所有者作出 GATE-1 决定前，不得启动正式功能开发或资产生产。
