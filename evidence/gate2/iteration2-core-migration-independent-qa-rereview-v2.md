# Iteration 2 核心迁移独立 QA 复审 v2

状态：`revision_required`

日期：2026-08-18（Asia/Shanghai）

责任实例：`inst:01M02NJ3JFHVZ5C4SP5MTJFJR6`

授权边界：独立 QA；不拥有规则、实现、测试、Contract、Registry 或 approval；本报告不批准 GATE-2。

## 1. 结论

整改冻结候选 `main@a89ebf4da4c152e4ca56b240575fc1a8737002b8` 结论为 **`revision_required`**，暂不能关闭 `TASK-CORE-002`。

原 QA 的权威回放 successor 绑定缺口和 ObserverReplay 合法形状篡改缺口已关闭；VisibleError 也已进入真实语料比较。但所谓“observer replay frame 等于实时 observer DTO”的迁移证明仍是自构造 source frame 与自构造 formal frame 的比较，没有比较 `FormalMatchApplication` 实际返回和记录的 live frame。更严重的是，两者的 ActionPreview 时点与内容并不相同：runner 把结算前提交意图的单个 preview 放进结算后、原行动方 frame；正式 application 在结算后按下一行动席生成完整 previews。现有 `4000 / 199974` 计数因此不能证明 manifest 要求的 live DTO 等价。

## 2. 冻结输入与摘要

- clean detached worktree：`C:\Users\30114\AppData\Local\Temp\veilfront-iteration2-qa-a89ebf4`
- `HEAD`：`a89ebf4da4c152e4ca56b240575fc1a8737002b8`
- 冻结时 `origin/main`：`a89ebf4da4c152e4ca56b240575fc1a8737002b8`
- 原 QA：`evidence/gate2/iteration2-core-migration-independent-qa-v1.md`，SHA-256 `1739e561cdfe8929926a5556e87b78fe9056c0604586fc28a873bd04215f247e`
- 系统/技术交叉复审：`evidence/gate2/iteration2-core-migration-cross-review-v1.md`，SHA-256 `b9813e1907aee2d7fd73f6fcdb5b90e7720bac21831d58163c75a8b70142eb64`
- 整改证据：`evidence/gate2/iteration2-core-migration-remediation-v1.md`，SHA-256 `2b827ac901bbcd75832881c3e83ac60aa9c4e788dd2b0d27ebb5340e6a64caef`
- 历史 golden v1：SHA-256 `e825641ca133eb9cae925d18e748660c7103fc5327120c5c48732027d6de0f4f`，保持不变
- 新 golden v2：SHA-256 `67ed6d953a756eac88e8fa8063612409b7b7de1e009c8b80e92b0c0fccf97411`
- Loop Contract `LOOP-CTR-FORMAL-FOUNDATION-GATE2-001@v1`：SHA-256 `a26a9b3fdb0d8d06e42a06833a84455d911fea8f72bcedec59d0ae5e620cc205`
- HQ successor：`f6b07d8cbdc7db4492c33e8b4b028aca2906cccc8baf5921273aaa012d48e19b`

整改证据列出的 8 个文件 SHA-256 均由 QA 独立复算并精确匹配。候选提交链为：

1. `5dc9871 feat: 记录正式核心迁移复审问题`
2. `9f66207 feat: 强化权威与观察者回放审计`
3. `a89ebf4 feat: 补全九通道真实等价验证`

## 3. 自动验证结果

| 检查 | 精确命令/入口 | 退出码 | 结果 |
|---|---|---:|---|
| 项目实例 | `python C:\Users\30114\.codex\plugins\cache\personal\game-production-pipeline\0.4.0-alpha.2\scripts\validate_project_instance.py --project-root .` | 0 | `state=normal`；plugin lock normal；0 error / 0 warning |
| Godot 版本 | `D:\Godot\godot.cmd --version` | 0 | `4.7.1.stable.official.a13da4feb` |
| Godot import | `D:\Godot\godot.cmd --headless --editor --path . --quit` | 0 | 无导入错误 |
| 正式架构 | `D:\Godot\godot.cmd --headless --path . --script res://tests/game/architecture/run_formal_architecture_checks.gd` | 0 | `self_tests=17 scanned_files=68` |
| Observer contract | `... --script res://tests/game/contracts/run_observer_contract_checks.gd` | 0 | `checks=30` |
| 隐藏等价及 tamper | `... --script res://tests/game/contracts/run_hidden_equivalence.gd` | 0 | `pairs=6 checks=2723` |
| 原型聚合回归 | `... --script res://tests/prototype/run_all.gd` | 0 | `scaffold=9 focused_suites=15 full_gate1=false` |
| 正式场景 | `... --script res://tests/game/scenes/run_formal_scene_smoke.gd` | 0 | `roots=3 components=16 inputs=11` |
| 教学壳 | `... --script res://tests/game/scenes/run_tutorial_shell_smoke.gd` | 0 | `TUTORIAL_SHELL_SMOKE_PASS` |
| 三分辨率布局 | `... --script res://tests/game/presentation/run_board_layout_contract.gd` | 0 | `resolutions=3` |
| 棋盘观察者 fixture | `... --script res://tests/game/presentation/run_board_observer_fixture.gd` | 0 | `BOARD_OBSERVER_FIXTURE_PASS` |
| 1-seed 定向 runner | 与下项相同，`--seeds 1 --replay-samples 1` | 0 | `visible_error_checked=104 authoritative_replay_checked=1 observer_replay_frames_checked=200` |
| 精确 20-seed 九通道 | `D:\Godot\godot.cmd --headless --path . --script res://tests/game/migration/run_gate1_formal_equivalence.gd -- --start-seed 471001 --seeds 20 --round-limit 50 --replay-samples 20 --channels state,event,red_player_view,black_player_view,red_visible_event,black_visible_event,visible_error,action_preview,replay` | 0 | `completed=20 replay_verified=20 channels=9 visible_error_checked=2080 authoritative_replay_checked=20 observer_replay_frames_checked=4000`；受第 5 节盲区影响，不构成 live observer DTO 通过证据 |
| 精确 1000-seed 九通道 | 上项命令改为 `--seeds 1000` | 1（人工中止） | 新确定性验收盲区成立后立即停止；未形成 1000-seed 验收证据 |
| 候选范围 diff | `git diff --check ba0f883c652f34a1611ed1598e0009da3e32dec6..HEAD` | 0 | 通过 |
| detached 工作树 diff | `git diff --check` | 0 | 通过；Godot import 产生的单个未跟踪 `.uid` 已仅从临时 worktree 清除 |

第一次 20-seed 直跑曾以 exit 1 且无诊断输出结束；同一冻结 SHA 使用保留 stderr/退出码的 PowerShell 调用复跑后 exit 0，并得到与整改证据完全相同的计数。该环境异常不作为缺陷；真正阻断来自可重复的源码路径审计。

## 4. 原缺陷关闭状态

### I2-QA-002 / I2-XREV-002 — `closed`

ObserverReplay 已升级为 v2，根 `audit_digest` 覆盖全部 frame；validator 校验 frame sequence、action index、VisibleEvent cursor/前缀和 DTO codec。`run_hidden_equivalence.gd` 对合法外形的 VisibleEvent、VisibleError、ActionPreview 篡改均有拒绝断言，2723 checks 通过。

### I2-QA-003 / I2-XREV-003 — `closed`

AuthoritativeReplay v2 exact schema 已绑定 source commit、HQ successor、formal rules bundle、implementation/canonical revision 与 codec；verify 先比较完整 binding，再校验 audit 和重演。逐字段 binding tamper 与 codec/rules tamper 负向断言通过。

### I2-QA-001 / I2-XREV-001 — `not_closed`

VisibleError 四类语料与权威 replay 语义已进入 source/formal 比较；但 observer replay 子要求仍未连接实际 application live DTO，详见 I2-QA-RR-001。

## 5. 阻断缺陷

### I2-QA-RR-001 — `major` — observer frame 等价比较的是共同自构造模型，不是实际 live DTO

验收基线：`docs/architecture/gate1-to-formal-migration-manifest-v1.yaml:305` 要求 `observer_replay_frames_equal_live_observer_dtos`；正式架构 v2 也要求 ObserverReplay frame 与实时观察者 DTO 字节等价。

观察证据：

1. `tests/game/migration/gate1_channel_capture.gd:220-223` 在提交行动前从 active PlayerView 生成 `source_preview` 和 `formal_preview`。
2. 行动结算后，runner 在 `:270-284` 调用自己的 `_observer_frame()`：把这一个**结算前、已提交行动的 preview** 放进原行动方 frame，另一方 previews 固定为空。
3. source 与 formal 两边都调用相同测试 helper，`:286-290` 只比较这两个共同自构造 frame；整个正常对局比较路径没有调用 `FormalMatchApplication.submit_intent()`、其返回 DTO 或 `observer_replay_record().frames`。`FormalMatchApplication` 在 runner 中只被 VisibleError corpus 使用。
4. 实际 `scripts/game/application/formal_match_application.gd:69-71` 的结算前 preview 仅用于提交分类；`:81-86` 在行动消费、准备下一回合后重新取得 PlayerView、VisibleEvent 和 `current_action_previews()`，再于 `:87-95` 记录 frame。
5. 因此实际 application 的 frame previews 属于**结算后当前行动席**：上一行动方通常为空，下一行动方应是完整的 `generate_action_intents()` 列表；终局则双方为空。runner 则记录上一行动方单个旧 preview。两者在时点、所属席位和集合基数上均不等价。
6. golden v2 的红黑 observer digest 同样来自该 `_observer_frame()` helper，所以 golden 与 formal capture 一致只证明测试模型自洽，不能证明 application live DTO 等价。

影响：`observer_replay_frames_checked=4000`（以及生产方声明的 `199974`）是自构造 frame 比较次数，不是实时 DTO 比较次数。runner 即使与正式 application 的 frame 语义漂移也会绿色；`CHECK-MIGRATION-001`、ObserverReplay 可审计等价及整改证据第 2/4/7 节的相应声明均未成立。

关闭条件：

- 迁移 runner 必须取得 `FormalMatchApplication` 实际 `submit_intent()` 输出及 `observer_replay_record().frames`，逐 frame 与同一时点、同一 viewer 的 source live DTO 比较；不得由 source/formal 两边共用 helper 代替被测 application。
- 明确并断言结算后 preview 的席位、时点、完整集合和终局行为；红黑 viewer 分开验证。
- 检查计数只能累计实际 application frame 比较，并增加负向自测：改变 application frame 的 PlayerView、VisibleEvent、VisibleError 或 ActionPreview 任一内容时 runner 必须失败。
- 修复后从新冻结 SHA 重跑 v2 golden/hash、20/1000 九通道、20 replay、hidden/tamper 与全壳回归；不得用当前 golden v2 静默接受新语义。

## 6. 责任返回与下一合法动作

1. 将 `I2-QA-RR-001` 返回 `TASK-CORE-002` 的 Godot 技术生产责任实例；QA 不参与修订。
2. 生产方应提交新的冻结候选、可审计的 actual-vs-live frame 证据、版本化 golden 处理说明及负向自测。
3. 独立 QA 在新 SHA 上先定向证明计数来自实际 application，再执行完整 1000-seed；本次人工中止的长跑不能复用为通过证据。
4. 即使下一次独立 QA 通过，也只授权项目经理绑定 Iteration 2 证据；GATE-2 仍由项目所有者人工决定。

## 7. 报告完整性

`file_sha256: computed_after_write`
