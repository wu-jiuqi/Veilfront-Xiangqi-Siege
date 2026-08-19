# Iteration 2 核心迁移 R3 整改生产者证据

状态：`producer_verified_with_owner_sampling_exception_pending_independent_review`

日期：2026-08-19（Asia/Shanghai）

责任范围：`TASK-CORE-002` 的 ActionPreview 全量跨实现输入独立性；本报告不是独立 QA，不批准 Iteration 2 或 GATE-2。

## 1. 候选与冻结输入

- 当前候选父提交：`712a7033ffb6636a5fed307f7cb109183010f9b5`。
- R3 代码最初冻结于：`ec99fe3f62fa182bbb8e1f2aaa80d078963b9efd`。
- `ec99fe3..712a703` 仅包含教学设计、HTML、首界面/关卡模式设计与实施计划文档；`scripts/`、`tests/`、`scenes/`、`resources/`、`project.godot` 在该区间没有已提交差异。
- successor SHA-256：`f6b07d8cbdc7db4492c33e8b4b028aca2906cccc8baf5921273aaa012d48e19b`。

| 文件 | SHA-256 |
| --- | --- |
| `tests/game/migration/gate1_channel_capture.gd` | `b07b5f61925acc007950d61eb1e3b876dff06cef27793ed271712d6221405bcd` |
| `tests/game/migration/source_channel_mapper.gd` | `9967a361bbb5c84d3cf13de565a2ccb31ae8b56432c08e10d1e0bc31ee7fdd3e` |
| `tests/game/migration/run_source_preview_independence_contract.gd` | `9679d51e8233c39cb42838a64e220ba1337872dc78a4d2c136466683a27cda8d` |
| golden v1 | `e825641ca133eb9cae925d18e748660c7103fc5327120c5c48732027d6de0f4f` |
| golden v2 | `67ed6d953a756eac88e8fa8063612409b7b7de1e009c8b80e92b0c0fccf97411` |
| golden v3 | `7c089b43667e5c0af9f4df14a2949974cb049efde34a5e9879528d99b11242ac` |

## 2. 缺陷与整改

历史 live980 比较把 formal frame 的 `action_previews` 同值复用到 source frame，导致观察者回放帧的完整 ActionPreview 列表在 980 个非 golden seed 上没有跨实现检错能力。

整改后：

1. `SourceChannelMapper.player_view_with_action_previews()` 从原型 PlayerView 独立生成原型侧完整、有序 ActionPreview；
2. `Gate1ChannelCapture.compare_live()` 分别使用原型和正式实现的预览列表组合观察者安全帧；
3. `drop_first` 负向注入只删除原型侧第一条预览，比较器必须在 `observer_replay_frame` 通道拒绝；
4. 合法性继续由各自既有 projector/preview 入口产生，本整改没有修改正式规则、随机消费、正式 projector 或生产运行时代码。

## 3. 自然完成的验收结果

### 3.1 Source ActionPreview 独立性负向合同

命令：

```powershell
D:\Godot\godot.cmd --headless --path . --script res://tests/game/migration/run_source_preview_independence_contract.gd
```

- 开始：`2026-08-19T14:30:33.9126636+08:00`
- 结束：`2026-08-19T14:30:35.5105069+08:00`
- 退出码：`0`
- 汇总：`SOURCE_PREVIEW_INDEPENDENCE_PASS seed=471021 mutation=drop_first`

### 3.2 精确 20-seed 九通道等价

命令：

```powershell
D:\Godot\godot.cmd --headless --path . --script res://tests/game/migration/run_gate1_formal_equivalence.gd -- --start-seed 471001 --seeds 20 --round-limit 50 --replay-samples 20 --channels state,event,red_player_view,black_player_view,red_visible_event,black_visible_event,visible_error,action_preview,replay
```

- 开始：`2026-08-19T14:30:47.8080531+08:00`
- 结束：`2026-08-19T14:36:04.6645825+08:00`
- 退出码：`0`
- 汇总：`FORMAL_EQUIVALENCE_PASS completed=20 replay_verified=20 channels=9 visible_error_checked=2080 authoritative_replay_checked=20 observer_replay_frames_checked=4000`

## 4. 项目所有者批准的 1000-seed 采样例外

精确 1000-seed 命令于 `2026-08-19T14:36:25.0570252+08:00` 启动，使用与 20-seed 相同的冻结 R3 文件和九通道参数。运行期间没有出现失败输出。项目所有者随后明确指示：“取消1000-seed测试，用目前已经测试完成的结果作为结果就行了”。生产者向进程发送中断并确认系统中无残留 Godot 进程。

该运行：

- 状态仅为 `cancelled_by_project_owner`；
- 不提供、也不声称 `completed_live=980/980` 或 `completed=1000`；
- 不计入通过证据；
- 不覆盖历史 1000-seed 证据；
- 本轮按项目所有者决定，以自然完成的 source-preview 负向合同、精确 20-seed golden 样本和完整回归作为生产者验收结果；
- 独立技术复审或 QA 若认定批准 Contract 仍强制要求本轮完整 1000-seed，可返回 `revision_required`，本报告不预先替代其专业判断。

更早的中断与恢复上下文保存在 `evidence/gate2/iteration2-core-migration-r3-interruption-recovery.md`，该文件不构成通过证据。

## 5. 完整回归

Godot：`4.7.1.stable.official.a13da4feb`。

| 检查 | 结果 |
| --- | --- |
| `run_formal_architecture_checks.gd` | exit 0；`self_tests=17 scanned_files=68` |
| `run_observer_contract_checks.gd` | exit 0；`checks=30` |
| `run_hidden_equivalence.gd` | exit 0；`pairs=6 checks=2723` |
| `run_observer_live_frame_contract.gd` | exit 0；`OBSERVER_LIVE_FRAME_CONTRACT_PASS` |
| `run_source_preview_independence_contract.gd` | exit 0；负向注入被拒绝 |
| `run_formal_scene_smoke.gd` | exit 0；`roots=3 components=16 inputs=11` |
| `run_tutorial_shell_smoke.gd` | exit 0 |
| `run_board_layout_contract.gd` | exit 0；`resolutions=3` |
| `run_board_observer_fixture.gd` | exit 0 |
| `tests/prototype/run_all.gd` | exit 0；`scaffold=9 focused_suites=15` |
| `git diff --check` | exit 0 |

执行计划最初误把 `test_observer_codec_allow_lists.gd`（被预加载的测试模块）当作 `--script` 入口，Godot 以“未继承 SceneTree/MainLoop”退出 1。仓库既有 runner 与历史证据均确认正确入口为 `run_observer_contract_checks.gd`；修正计划后该 runner 以 `checks=30` 通过。此项是命令入口错误，不是 codec 或项目导入失败。

布局测试没有改变 `evidence/gate2/iteration1-s4-layout-snapshots.json`。

## 6. 生产者结论与下一合法动作

R3 候选已证明前 20 个冻结 golden seed 的九通道逐行动等价，且原型侧 ActionPreview 负向变异能够被观察者回放帧比较器检出；全部定向与回归检查通过。结论限定为 `producer_verified_with_owner_sampling_exception_pending_independent_review`。

下一合法动作：提交并推送 R3 候选，由批准的技术复审角色和独立 QA 在 clean detached worktree 复核相同摘要、20-seed 结果、负向合同、完整回归与项目所有者采样例外。双审前不得把 Iteration 2 记录为完成，也不得启动 Iteration 3 生产代码。
