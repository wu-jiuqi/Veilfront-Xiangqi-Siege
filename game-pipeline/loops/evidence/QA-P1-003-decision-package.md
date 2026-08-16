# QA-P1-003 项目所有者决策包

状态：`blocked / owner_decision_required`

适用 Loop：`LOOP-GATE1-001 / Iteration 1`

适用 Contract：`LOOP-CTR-GATE1-VERTICAL-SLICE-001 v1`、`CTR-P1-001 v1`

锁定插件：`game-production-pipeline@0.4.0-alpha.2`

框架摘要：`3589bce5cf4388f91a08f12acb5d90679256191d5085e65687d06a635bbdcd32`

## 需要项目所有者决定的事项

选择以下一种处置；在决定前，当前 submission 不得接受，Loop 不得进入 `review`，不得作出 GATE-1 决定，也不得开始正式功能或资产生产。

1. **正式修复/升级（推荐）**：授权取得或制作包含 Loop Registry 运行态校验修复的插件版本，先执行插件迁移规划与影响检查，再由项目所有者批准具体目标版本和新框架摘要；批准后才允许迁移项目插件锁并重跑全套验证。
2. **临时豁免**：仅豁免锁定版本官方 CLI 在 active Snapshot 上产生的六项已知模板错误；不得把官方 CLI 标记为通过，不得改写历史、伪造 draft Snapshot、降低其他检查标准或用 `validate_history` 代替完整 CLI。由于当前 Contract 要求官方完整 CLI 通过，此选项只能维持 Loop 在受控例外状态，不能满足本轮“官方 CLI、历史重放和 Registry 一致性全部通过才进入 review”的准入标准；若希望豁免后进入 review，还必须由项目所有者另行批准 Contract/验收条件变更。

## 问题

锁定插件的官方完整命令对 active、`current_iteration=1`、`record_revision=30` 的运行态 Snapshot 返回退出码 1，并报告六项错误：

1. Snapshot 模板初始状态必须等于状态机 `initial_state`；
2. Snapshot 模板 `current_iteration` 必须从 0 开始；
3. 注册后的 Snapshot 模板必须位于 `sequence=1`、`record_revision=1`；
4. draft 注册基线的 inputs 和 outputs 必须为空；
5. Snapshot `input_slot_id` 必须完整对应 Contract `required_inputs`；
6. Snapshot `deliverable_id` 必须完整对应 Contract `required_deliverables`。

同一锁定脚本直接调用未修改的 `validate_history(...)`，对同一 Snapshot、Event History、Event Contract 与状态机返回 `history_error_count=0`、退出码 0。

## 根因与影响范围

`validate_loop_registry.py` 的 `main()` 在读取 `--snapshot` 后无条件执行：

```python
errors = validate_templates(*documents)
if args.history is not None:
    errors.extend(validate_history(...))
```

`validate_templates(...)` 明确要求其 Snapshot 参数是注册后的 draft 模板；`validate_history(...)` 明确要求同一个 Snapshot 参数是事件历史尾部对应的当前运行态物化视图。对已经启动并登记输入/输出的 active Loop，这两个条件互相排斥。

影响范围是该版本 CLI 的“实际 Snapshot + Event History”组合入口，而不是本项目事件链的已观察损坏。所有使用 `--history` 校验非 draft 运行实例的项目都可能触发相同类别的误报；输入/输出两项错误还取决于项目 Contract 与模板示例 ID 的差异。

## 正式修复方案（推荐）

外部框架应把“注册模板校验”和“运行态历史校验”分离为不同输入与不同阶段，例如新增 `--record-template`（或等价参数）：

- `validate_templates(record_template, event_contract, bound_contract, state_machine)`；
- `validate_history(active_snapshot, event_history, state_machine, event_contract)`；
- 完整 CLI 只有两组检查均为 0 错误才退出 0；
- README、CLI 帮助和框架测试同步覆盖 draft 模板、active Snapshot、带输入输出的 Contract、断链和水位不一致用例。

项目侧迁移必须使用插件正式迁移流程，至少包含：

1. 获取带上述修复的候选插件版本及其框架摘要；
2. 只读生成迁移计划并审查 Contract、Registry、Agent 适配器与历史兼容性；
3. 由项目所有者批准目标版本、摘要和迁移计划；
4. 迁移插件锁，不修改旧事件；如 Registry Contract/状态机绑定发生变化，只能追加正式迁移事件；
5. 重新执行项目实例、Pipeline Contract、Organization Registry 历史重放、Loop 官方完整 CLI、`validate_history`、Snapshot/事件链/摘要/revision 一致性检查；
6. 由独立 QA 对新版本和当前 submission 重新审核，通过后才允许进入 `review`。

当前环境只有 `0.4.0-alpha.2`，未发现已安装的修复候选版本；因此本轮没有获授权、可直接实施的正式迁移目标。

## 临时豁免方案（非默认）

豁免对象必须精确绑定：

- 插件版本与框架摘要；
- `validate_loop_registry.py` 文件摘要；
- 当前 Loop Contract、Snapshot 与 Event History 摘要；
- 官方 CLI 退出码 1 且错误集合与上述六项逐字一致；
- `validate_history(...)` 退出码 0、错误数 0；
- 项目实例、Pipeline Contract 与 Organization Registry 历史重放均通过。

任一版本、摘要、错误集合、历史水位或 Contract 发生变化，豁免立即失效并重新审核。豁免不得写成“官方 CLI 通过”，不得删除 QA-P1-003，只能记录为项目所有者接受的残余工具风险。

## 已执行证据

| 检查 | 结果 | 结论 |
|---|---:|---|
| 项目实例校验 | 退出码 0，`state=normal`，errors/warnings 为空 | 插件锁、批准记录、组织 Registry 与生成 Agent 适配器预检通过 |
| Pipeline Contract 校验 | 退出码 0，`OK` | `CTR-P1-001 v1` 结构通过 |
| Organization Registry Snapshot + History | 退出码 0，`OK` | 组织历史重放通过 |
| Loop 官方完整 CLI | 退出码 1，精确六项模板错误 | QA-P1-003 仍阻塞，不能接受 submission |
| 未修改的 `validate_history(...)` | 退出码 0，`history_error_count=0` | 仅证明当前 Loop 历史链、状态与水位可重放，不替代完整 CLI |
| 独立 QA 专业复核 | `blocked` | rev30/seq30、尾事件、摘要链、状态与轮次重放一致；因官方必需自动检查失败，submission 不可接受且不得转入 `review` |

## 推荐与可逆性

推荐选择正式修复/升级。该路径保留“官方 CLI 必须通过”的既有准入标准，且不需要为工具缺陷降低项目证据门槛。迁移计划在项目所有者批准前保持只读；若候选版本影响超出预期，可以拒绝迁移并保留当前锁。

临时豁免可用于明确记录已知工具风险，但在不同时修改当前 Contract/验收条件的前提下，不能合法地把本轮 submission 转入 `review`。

## 决定记录（待项目所有者填写）

- 选择：`正式修复/升级 / 临时豁免 / 修订方案 / 拒绝`
- 是否授权取得或制作外部框架修复：`待决定`
- 是否授权插件迁移规划：`待决定`
- 若选择豁免，是否同时发起 Contract/验收条件变更：`待决定`
- 决定者：`project-owner`
- 决定时间：`待填写`
- 决定绑定摘要：`b1eef2e3b99673a5070b0aa4d73c7d27eca8b5e315796f596e07757acbc1c210`

摘要采用 UTF-8、LF 结尾的下列规范清单计算 SHA-256；决定时任一输入变化均需重新生成决策包：

```text
subject=QA-P1-003-disposition-v1
plugin_lock_sha256=260626496f7cab3e13932320409ec07fe7c7f206b3cd3bbad2aac48549491272
validator_sha256=90804f2221af1973d099f4fc531fd39e8aaaaca7bf101922ee63c9c67f909633
loop_contract_sha256=a0380db5819f9651bbb2b0fab243bb3489504b11ed808506f2ecb92a589ae1ad
snapshot_sha256=4b1c2ab9d224e4e91e076a2f7f08e42dbdafed88e6f2564b01f20461be88d291
event_history_sha256=17a75a74da3a3314353351d22dc0fb6d7f8c4b941ae8f617b4e3b7c2f97b83e8
issue_sha256=acd7316ebb245b810f19fecdbef52f7b6c91dbd1f5618ba54be7a827d1cf3007
choices=formal_fix_or_upgrade|temporary_waiver|revise|reject
```

## 下一项合法流程

保持 Iteration 1，不进入 `review`。等待项目所有者选择；选择正式修复时，下一步是取得候选插件并只读生成迁移计划；选择临时豁免时，下一步是记录不可变审批，并判断是否另行批准 Contract/验收条件变更。任何路径都不得自动作出 GATE-1 决定。
