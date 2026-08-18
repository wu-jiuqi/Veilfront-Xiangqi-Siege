# Iteration 2 Observer Live Frame 技术整改 R2 v1

状态：`candidate_complete / awaiting_independent_rereview`

日期：2026-08-18（Asia/Shanghai）

责任实例：`inst:01M02NJ3JEQXKV6PT6DPX0NKQ0`

定向缺陷：`I2-XREV-001-R2`

## 1. 输入与范围

- 最新系统/技术复审 SHA-256：`17bb4951d450b9488fa0ba45cea8fa991623ea09189cd7dca97fb4bbe9e9ad40`。
- 整改开始冻结候选：`main@a89ebf4da4c152e4ca56b240575fc1a8737002b8`。
- 整改期间共享 main 前进至：`b4f0604f2d498360d6e529ceb96878a425f58afc`；本实例未回退并行提交。
- Godot：`4.7.1.stable.official.a13da4feb`。
- 仅窄改 FormalMatchApplication 的 safe-frame 生成、migration 测试/runner 与版本化 golden；未接 ApplicationHost/MatchScreen，未改规则、Contract、Registry、approval、教程、AI、LAN 或互联网实现。

## 2. TDD RED/GREEN

### RED

先新增双行动席 live-frame contract，以结算后的正式 PlayerView 为基准检查完整 ActionPreview 列表。旧构造器结果：

`OBSERVER_LIVE_FRAME_CONTRACT_FAIL legacy_pre_action_single_preview_not_live`

退出码 `1`。该 RED 明确证明旧迁移 frame 在红方行动后仍把结算前单 preview 留给红方，并给黑方空列表；与正式 live DTO 的归属、时序和数量均不一致。

### GREEN

FormalMatchApplication 现在只有一套 frame 语义：

1. `_compose_safe_frame()` 从结算后权威状态投影 PlayerView/VisibleEvent；
2. `_action_previews_for_view()` 仅为结算后的下一行动席生成完整预览列表，非行动席或终局返回空数组；
3. `_compose_safe_frame_from_dtos()` 负责统一 safe DTO frame 外形；正式 `submit_intent()` 和 migration 都复用该 composer；
4. migration source 使用 prototype 的完整 preview 列表映射，formal 使用上述正式解析器。v3 golden 的 20 个 seed 对双方完整列表形成逐帧 digest chain；
5. live980 在先证明 source mapped FullState、红黑 PlayerView、VisibleEvent、VisibleError 均与 formal 相等后，以正式解析器产生的完整 previews 组合双方 frame 并逐字段比较。这避免重复计算同一正式完整列表，不改变 frame 语义或计数。

最终负向合同同时覆盖：

- 红行动后：红 frame previews 必为空，黑 frame 必等于黑方完整 live previews；
- 黑行动后：黑 frame previews 必为空，红 frame 必等于红方完整 live previews；
- 两个方向的“前一行动方单 preview”变异均必须不等于正式 frame。

结果：`OBSERVER_LIVE_FRAME_CONTRACT_PASS`。

## 3. Golden v3

| 文件 | SHA-256 | 状态 |
|---|---|---|
| `gate1-successor-20-seeds-v1.json` | `e825641ca133eb9cae925d18e748660c7103fc5327120c5c48732027d6de0f4f` | 历史不可变，未改 |
| `gate1-successor-20-seeds-v2.json` | `67ed6d953a756eac88e8fa8063612409b7b7de1e009c8b80e92b0c0fccf97411` | 历史整改证据，未改 |
| `gate1-successor-20-seeds-v3.json` | `7c089b43667e5c0af9f4df14a2949974cb049efde34a5e9879528d99b11242ac` | 结算后、下一行动席、完整 previews 的新基线 |

v3 schema 为 `veilfront-gate1-migration-golden-v3`，仍绑定相同 RC3 source 与 HQ successor。版本提升只修复 observer live-frame 验收语义，不代表规则变化；runner 硬绑定 v3 文件摘要，不能回退使用 v1/v2。

## 4. 最终 20/1000 结果

### 独立精确 20-seed

使用 `start=471001`、`seeds=20`、`round_limit=50`、`replay_samples=20` 和 manifest 九通道顺序：

`FORMAL_EQUIVALENCE_PASS completed=20 replay_verified=20 channels=9 visible_error_checked=2080 authoritative_replay_checked=20 observer_replay_frames_checked=4000`

### 精确 1000-seed

使用 `start=471001`、`seeds=1000`、`round_limit=50`、`replay_samples=20` 和相同九通道顺序。长跑进程自然结束，原 unified exec session 恢复到完整输出与退出码 `0`：

- `FORMAL_EQUIVALENCE_PROGRESS completed_live=980/980 workers=12`
- `FORMAL_EQUIVALENCE_PASS completed=1000 replay_verified=20 channels=9 visible_error_checked=103987 authoritative_replay_checked=1000 observer_replay_frames_checked=199974`

因此 199,974 个计数 frame 均采用正式结算后 safe DTO composer；前 4,000 个 v3 golden frame 还独立比较 prototype/formal 的完整 ActionPreview 列表。失败 seed、replay divergence、frame mismatch：均无。

## 5. 全回归

- `FORMAL_ARCHITECTURE_CHECKS_PASSED self_tests=17 scanned_files=68`
- `OBSERVER_CONTRACT_CHECKS_PASSED checks=30`
- `HIDDEN_EQUIVALENCE_PASS pairs=6 checks=2723`
- `OBSERVER_LIVE_FRAME_CONTRACT_PASS`
- `PROTOTYPE_BASIS_CHECKS_PASSED scaffold=9 focused_suites=15 full_gate1=false`
- `FORMAL_SCENE_SMOKE_PASS roots=3 components=16 inputs=11`
- `TUTORIAL_SHELL_SMOKE_PASS`
- `BOARD_LAYOUT_CONTRACT_PASS resolutions=3`
- `BOARD_OBSERVER_FIXTURE_PASS`
- `git diff --check`：通过。

## 6. 最终文件摘要

| 文件 | SHA-256 |
|---|---|
| `scripts/game/application/formal_match_application.gd` | `904911650d8a9c2344fbe8f45f6b1816780bbf596f6f1caf1d9eb369170931cb` |
| `tests/game/migration/run_observer_live_frame_contract.gd` | `f6f0699401abb0a4d4526239163375ac4e44e6bd305032eb3d4f8a1c9ac270a1` |
| `tests/game/migration/capture_gate1_golden.gd` | `c5e25c28bb1135158aa00e5221364a0b74f8e210eb394a0cbc20159cb9a8f8a5` |
| `tests/game/migration/gate1_channel_capture.gd` | `80e1e69d27e1ccdbf2984b22fae3b5934bc59e1556f50aeb022bac8c03c9909e` |
| `tests/game/migration/run_gate1_formal_equivalence.gd` | `624f718d56942c7f6d53e6603a93ec444bf099c93840236431b1b76420a17d18` |
| `tests/game/migration/source_channel_mapper.gd` | `c16692d528646dd83dbdce3bfc69760c143a626822ffcc96b5323e266160af08` |

## 7. 关闭判断与下一动作

`I2-XREV-001-R2` 候选关闭：生产 submit、migration golden 和 live runner 已共享同一结算后 frame composer；双行动席完整 preview 语义有 RED/GREEN 负向证据；20/1000 均输出实际 frame 计数。

下一合法动作是独立系统/技术与 QA 定向复审 v3 摘要、双行动席 live-frame contract、20/1000 输出和范围边界。本证据不自行批准 Iteration 2 或 GATE-2。
