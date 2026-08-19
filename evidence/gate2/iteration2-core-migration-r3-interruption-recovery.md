# Iteration 2 R3 中断恢复记录

状态：`producer_verification_interrupted / resume_required`

日期：2026-08-19（Asia/Shanghai）

责任范围：`TASK-CORE-002` 的 ActionPreview 全量跨实现等价整改；本记录不是独立 QA，也不批准 Iteration 2 或 GATE-2。

## 1. 冻结输入

- 基线提交：`ec99fe3f62fa182bbb8e1f2aaa80d078963b9efd`
- `tests/game/migration/gate1_channel_capture.gd`：`b07b5f61925acc007950d61eb1e3b876dff06cef27793ed271712d6221405bcd`
- `tests/game/migration/source_channel_mapper.gd`：`9967a361bbb5c84d3cf13de565a2ccb31ae8b56432c08e10d1e0bc31ee7fdd3e`
- `tests/game/migration/run_source_preview_independence_contract.gd`：`9679d51e8233c39cb42838a64e220ba1337872dc78a4d2c136466683a27cda8d`
- golden v3：`7c089b43667e5c0af9f4df14a2949974cb049efde34a5e9879528d99b11242ac`

## 2. 已取得的新鲜证据

### 独立预览负向合同

在本次环境权限切换前，定向合同退出码为 `0`：

`SOURCE_PREVIEW_INDEPENDENCE_PASS seed=471021 mutation=drop_first`

该合同会从原型侧完整 ActionPreview 列表删除第一项；比较器必须在 `observer_replay_frame` 通道拒绝，证明 live source 不再复用 formal previews。

### 精确 20-seed

同一冻结代码自然结束，退出码为 `0`：

`FORMAL_EQUIVALENCE_PASS completed=20 replay_verified=20 channels=9 visible_error_checked=2080 authoritative_replay_checked=20 observer_replay_frames_checked=4000`

## 3. 未完成证据

精确 1000-seed 在统一执行会话中运行超过四小时，但 Codex turn 被中断后会话句柄失效，后台不再有 Godot 进程，最终 stdout 与退出码未保留。因此该运行不得作为通过证据。

随后尝试以隐藏后台包装器持久化 stdout/stderr。Godot 在测试逻辑开始前约两秒发生引擎级 `CrashHandlerException: Program crashed with signal 11`。清理所有已确认的包装器/Godot 遗留 PID 后，快速定向合同仍在相同引擎地址 signal 11。此时运行环境已切换为受限沙箱；外部 `D:\Godot` 原生进程不能形成有效测试证据，`.git` 也为只读，无法提交或推送。

这不是规则或等价比较失败；当前缺少的是一轮可审计、自然结束的精确 1000-seed 输出。

## 4. 精确恢复命令

在允许正常执行 `D:\Godot\godot.cmd` 且 `.git` 可写的环境中，先运行：

```powershell
D:\Godot\godot.cmd --headless --path . --script res://tests/game/migration/run_source_preview_independence_contract.gd
```

然后运行精确 1000-seed：

```powershell
D:\Godot\godot.cmd --headless --path . --script res://tests/game/migration/run_gate1_formal_equivalence.gd -- --start-seed 471001 --seeds 1000 --round-limit 50 --replay-samples 20 --channels state,event,red_player_view,black_player_view,red_visible_event,black_visible_event,visible_error,action_preview,replay
```

期望最终汇总必须同时包含：

- `FORMAL_EQUIVALENCE_PROGRESS completed_live=980/980 workers=12`
- `FORMAL_EQUIVALENCE_PASS completed=1000 replay_verified=20 channels=9`
- 非零 `visible_error_checked`、`authoritative_replay_checked=1000`、`observer_replay_frames_checked`
- 进程退出码 `0`

## 5. 恢复后的剩余动作

1. 运行精确 1000-seed 并保存完整 stdout、stderr、开始/结束时间和退出码。
2. 运行正式架构、observer、hidden、live-frame、source-preview、prototype、scene、tutorial、layout、fixture 全回归及 `git diff --check`。
3. 编写 R3 正式整改证据，提交并推送测试实现与证据，提交信息使用中文 `feat: ...`。
4. 由独立 QA 在 clean worktree 复核；通过后才能登记 `DELIVERABLE-MIGRATION-001` / `DELIVERABLE-QA-002` 并进入 Iteration 3。
