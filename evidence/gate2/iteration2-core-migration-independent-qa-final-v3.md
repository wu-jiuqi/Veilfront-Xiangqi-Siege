# Iteration 2 核心迁移最终独立 QA v3

状态：`revision_required`

日期：2026-08-18（Asia/Shanghai）

责任实例：`inst:01M02NJ3JFHVZ5C4SP5MTJFJR6`

授权边界：独立 QA；不拥有规则、实现、测试、Contract、Registry 或 approval；本报告不批准 GATE-2。

## 1. 结论

最终冻结候选 `main@4a2713cd85d8f61d890417c8657b37f6d337ba83` 结论为 **`revision_required`**，不得关闭 `TASK-CORE-002`。

原 `I2-QA-RR-001` 指出的结算前旧 preview/结算后 live frame 时序错误已修复：正式 submit、v3 golden 和 live runner 均调用 `FormalMatchApplication` 的 safe-frame composer，双行动席 RED/GREEN contract 也通过。精确 20-seed 对 4000 个 frame 做了 prototype 完整 previews 与 formal 完整 previews 的真实比较。

但 live 980 路径把 formal frame 的 `action_previews` 直接复制进 source frame，没有调用 prototype/source 的完整 preview 列表生成器。因而生产方声明的 199,974 个 frame 即使都经过正式 composer，也只有前 4,000 个 frame 的 ActionPreview 列表是跨实现独立输入；其余 195,974 个 frame 的该字段是同值比较。manifest 要求的 1000-seed `action_preview_canonical_bytes_and_order` 零差异与 observer live DTO 全量跨实现等价仍未成立。

## 2. 冻结输入

- clean detached worktree：`C:\Users\30114\AppData\Local\Temp\veilfront-iteration2-qa-4a2713c`
- `HEAD`：`4a2713cd85d8f61d890417c8657b37f6d337ba83`
- 冻结时 `origin/main`：`4a2713cd85d8f61d890417c8657b37f6d337ba83`
- 原 QA v2：SHA-256 `119d459365d44267b1930470cc55924dfc794ba5cae6ce8f086e45d5bf04c4bf`
- 系统/技术交叉复审 v2：SHA-256 `17bb4951d450b9488fa0ba45cea8fa991623ea09189cd7dca97fb4bbe9e9ad40`
- R2 整改证据：SHA-256 `f43bd10279bc5f8721c472a4f0546dcaf8db223a2e3452f90d1fe019add0e1d6`
- golden v1：`e825641ca133eb9cae925d18e748660c7103fc5327120c5c48732027d6de0f4f`，未变
- golden v2：`67ed6d953a756eac88e8fa8063612409b7b7de1e009c8b80e92b0c0fccf97411`，未变
- golden v3：`7c089b43667e5c0af9f4df14a2949974cb049efde34a5e9879528d99b11242ac`
- Loop Contract `LOOP-CTR-FORMAL-FOUNDATION-GATE2-001@v1`：`a26a9b3fdb0d8d06e42a06833a84455d911fea8f72bcedec59d0ae5e620cc205`

R2 证据列出的 6 个整改文件 SHA-256 均由 QA 独立复算并精确匹配。候选包含并行的新手教学提案提交；本 QA 未把其文档/PDF 作为核心迁移通过依据，也未发现其修改正式规则实现。

## 3. 自动验证

| 检查 | 命令/入口 | 退出码 | 结果 |
|---|---|---:|---|
| 项目实例 | `python C:\Users\30114\.codex\plugins\cache\personal\game-production-pipeline\0.4.0-alpha.2\scripts\validate_project_instance.py --project-root .` | 0 | `state=normal`；plugin lock normal；0 error / 0 warning |
| Godot 版本 | `D:\Godot\godot.cmd --version` | 0 | `4.7.1.stable.official.a13da4feb` |
| Godot import | `D:\Godot\godot.cmd --headless --editor --path . --quit` | 0 | 无导入错误 |
| live-frame contract | `... --script res://tests/game/migration/run_observer_live_frame_contract.gd` | 0 | `OBSERVER_LIVE_FRAME_CONTRACT_PASS` |
| 正式架构 | `... --script res://tests/game/architecture/run_formal_architecture_checks.gd` | 0 | `self_tests=17 scanned_files=68` |
| Observer contract | `... --script res://tests/game/contracts/run_observer_contract_checks.gd` | 0 | `checks=30` |
| 隐藏等价及 codec/replay/observer tamper | `... --script res://tests/game/contracts/run_hidden_equivalence.gd` | 0 | `pairs=6 checks=2723` |
| prototype | `... --script res://tests/prototype/run_all.gd` | 0 | `scaffold=9 focused_suites=15 full_gate1=false` |
| 正式场景 | `... --script res://tests/game/scenes/run_formal_scene_smoke.gd` | 0 | `roots=3 components=16 inputs=11` |
| 教学壳 | `... --script res://tests/game/scenes/run_tutorial_shell_smoke.gd` | 0 | `TUTORIAL_SHELL_SMOKE_PASS` |
| 三分辨率布局 | `... --script res://tests/game/presentation/run_board_layout_contract.gd` | 0 | `resolutions=3` |
| 棋盘观察者 fixture | `... --script res://tests/game/presentation/run_board_observer_fixture.gd` | 0 | `BOARD_OBSERVER_FIXTURE_PASS` |
| 精确 20-seed 九通道 | `D:\Godot\godot.cmd --headless --path . --script res://tests/game/migration/run_gate1_formal_equivalence.gd -- --start-seed 471001 --seeds 20 --round-limit 50 --replay-samples 20 --channels state,event,red_player_view,black_player_view,red_visible_event,black_visible_event,visible_error,action_preview,replay` | 0 | `completed=20 replay_verified=20 channels=9 visible_error_checked=2080 authoritative_replay_checked=20 observer_replay_frames_checked=4000` |
| 精确 1000-seed 九通道 | 上项命令改为 `--seeds 1000` | 1（人工中止） | 确认 live 980 ActionPreview 同值比较盲区后立即停止；未形成 1000-seed 通过证据 |
| 候选范围 diff | `git diff --check a89ebf4da4c152e4ca56b240575fc1a8737002b8..HEAD` | 0 | 通过 |
| detached 工作树 diff | `git diff --check` | 0 | 通过；import 生成的两个未跟踪 `.uid` 已仅从临时 worktree 清除 |

## 4. 已确认关闭的内容

- `FormalMatchApplication.submit_intent()` 通过 `_compose_safe_frame()` 从结算后状态生成 PlayerView、VisibleEvent、VisibleError 和下一行动席完整 previews；返回 DTO 与记录 frame 来自同一对象。
- `run_observer_live_frame_contract.gd` 同时覆盖红到黑、黑到红两种行动席切换；前一行动方单 preview 的旧变异在两个方向均必须不等于正式 frame。
- golden v3 保留 v1/v2 历史文件，runner 硬绑定 v3 schema 和 SHA-256；精确 20-seed 的 4000 个红黑 frame 由 source 完整列表与 formal composer 独立形成后比较。
- ObserverReplay v2 全帧 audit、合法形状篡改拒绝、AuthoritativeReplay successor/rules bundle 绑定及逐字段 tamper 保持通过。
- 因此原时序缺陷本身已关闭；剩余问题是 full-1000 跨实现覆盖不足，而非正式 composer 的运行时语义仍错误。

## 5. 阻断缺陷

### I2-QA-FINAL-001 — `major` — live 980 的 source ActionPreview 列表复用 formal 值

验收基线：迁移 manifest `comparison_acceptance.required_zero_mismatches` 明确要求 `action_preview_canonical_bytes_and_order` 与 `observer_replay_frames_equal_live_observer_dtos`；本轮修改 projection/action preview 与 replay 路径，触发精确 1000-seed 全量重跑。

源码证据：

1. `tests/game/migration/gate1_channel_capture.gd:283-290` 用 `FormalMatchApplication._action_previews_for_view(formal_red/formal_black)` 生成 formal frame 的完整 previews。
2. 同文件 `:291-297` 构造 source frame 时，没有调用 `SourceMapper.action_previews(source_state, side)`；而是直接传入 `formal_red_frame["action_previews"]` 和 `formal_black_frame["action_previews"]`。
3. 因而 `:299` 的 frame equality 无法发现 prototype `ProtoProjector.generate_action_intents()` 与 formal `PublicActionPreviewer.generate_action_intents()` 在列表成员、顺序或任一非当前选中行动上发生差异。
4. live 路径 `:233-236` 只比较当前策略选中的单个 preview，不等价于完整 ActionPreview 数组的 canonical bytes/order。
5. golden v3 的前 20 seed 确实在 `capture_source()` 中调用 `SourceMapper.action_previews()`，但 1000-seed 触发条件要求全量，而非以 20 seed 推定其余 980。

影响：199,974 的计数可证明这些 frame 经过正式 composer 并比较了独立的 PlayerView、VisibleEvent 和 VisibleError；不能证明 199,974 个 frame 的完整 ActionPreview 字段均为 prototype/formal 独立输入。当前 1000-seed “九通道”证据会漏报仅影响非选中 preview 或列表顺序的迁移漂移。

关闭条件：

- live 980 source 红黑 frame 必须从 `SourceMapper.action_previews(source_state, side)` 获得各自结算后完整列表；formal frame继续使用正式 composer/previewer，二者独立生成后逐字段比较。
- 增加负向断言：删除、重排或修改 source 完整 preview 列表中一个非当前选中项，live runner 必须失败；不得以 formal 列表回填 source DTO。
- 计数应明确区分实际独立比较的 full ActionPreview frame 数；修复后在新冻结 SHA 自然完成精确 20 与 1000、20 replay、live-frame contract、hidden/tamper 和全壳回归。

## 6. 返回路径与下一合法动作

1. 返回 `TASK-CORE-002` 的 Godot 技术生产责任实例，仅修复 live 980 source preview 独立生成及对应负向合同；QA 不参与修订。
2. 保留 v1/v2/v3 golden 为历史证据；若 20-seed canonical 内容不变，无需重生 v3，但必须由整改证据说明并复算其 SHA。
3. 新冻结候选先由独立 QA 静态确认 source/formal preview 列表来源不同，再运行完整 1000，避免重复盲区长跑。
4. 后续 QA 即使 `approved`，也只授权项目经理绑定 Iteration 2 证据；GATE-2 仍由项目所有者人工决定。

## 7. 报告完整性

`file_sha256: computed_after_write`
