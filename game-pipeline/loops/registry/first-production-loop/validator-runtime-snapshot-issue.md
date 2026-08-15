# Loop 运行态 Snapshot 校验器缺陷证据

状态：`open / tooling / non-registry-corruption`

## 适用基线

- 项目：`veilfront-xiangqi-siege`
- Loop：`LOOP-GATE1-001`
- 锁定插件：`game-production-pipeline@0.4.0-alpha.2`
- 框架摘要：`3589bce5cf4388f91a08f12acb5d90679256191d5085e65687d06a635bbdcd32`
- 复现 Snapshot：`active / current_iteration=1 / record_revision=20 / last_event_sequence=20`
- 复现日期：`2026-08-15`

## 官方命令与实际结果

按锁定插件 `contracts/README.md` 的“校验实际 Snapshot 与 Event History”命令运行：

```powershell
python "$env:USERPROFILE/.codex/plugins/cache/personal/game-production-pipeline/0.4.0-alpha.2/scripts/validate_loop_registry.py" `
  --snapshot game-pipeline/loops/registry/first-production-loop/snapshot.yaml `
  --history game-pipeline/loops/registry/first-production-loop/event-history.yaml `
  --event "$env:USERPROFILE/.codex/plugins/cache/personal/game-production-pipeline/0.4.0-alpha.2/contracts/loop-registry-event.template.yaml" `
  --contract game-pipeline/loops/contracts/loop-contract-gate1-vertical-slice.yaml `
  --state-machine "$env:USERPROFILE/.codex/plugins/cache/personal/game-production-pipeline/0.4.0-alpha.2/contracts/loop-state-machine.default.yaml"
```

进程退出码为 `1`，六项错误全部来自注册模板不变量：要求 `draft`、`current_iteration=0`、`sequence=1`、`record_revision=1`、空 inputs/outputs，以及示例 ID 完整匹配 Contract。它们与当前合法运行态 Snapshot 的字段必然冲突。

## 根因定位

锁定脚本的 `main()` 无条件先调用 `validate_templates(...)`，之后才在提供 `--history` 时调用 `validate_history(...)`。因此，即使历史链完全有效，运行态 Snapshot 也会先被注册模板规则判为失败。

同一锁定脚本、同一 Snapshot、同一 Event History、同一 Event Contract 和状态机，直接调用其未修改的 `validate_history(...)`，结果为：

```text
history_error_count=0
exit_code=0
```

该检查覆盖事件摘要重算、`previous_event_digest` 链、`sequence`、`mutation_id`、`record_revision`、状态/轮次重放，以及 Snapshot 尾部水位核对。

## 处置边界

- 不修改锁定插件缓存，不创建伪造的 draft Snapshot，不重写不可变事件历史。
- 官方 CLI 的非零结果继续如实记为工具缺陷，不能标记为自动检查通过。
- `validate_history(...)` 的零错误只证明当前历史链可重放，不替代官方 CLI 的整体通过状态。
- QA-P1-003 保持开放，直到插件提供区分模板校验与运行态历史校验的正式入口，或项目所有者批准对应的管线迁移/豁免。
