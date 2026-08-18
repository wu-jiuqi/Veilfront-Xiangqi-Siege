# Iteration 2 核心迁移独立 QA v1

状态：`revision_required`

日期：2026-08-18（Asia/Shanghai）

责任实例：`inst:01M02NJ3JFHVZ5C4SP5MTJFJR6`

授权边界：独立 QA；不拥有规则、实现、测试、Contract、Registry 或 approval；本报告不批准 GATE-2。

## 1. 结论

冻结候选 `main@ba0f883c652f34a1611ed1598e0009da3e32dec6` **不得作为 Iteration 2 核心迁移验收证据关闭 `TASK-CORE-002`**。结论为 `revision_required`。

20-seed 命令虽返回 `FORMAL_EQUIVALENCE_PASS ... channels=9`，但独立源码审计确认其中 `VisibleError` 与 `replay` 通道没有获得该输出所宣称的真实跨实现覆盖；同时 ObserverReplay 中间帧不受完整性链约束，AuthoritativeReplay 也未绑定已批准 successor。三个问题均直接破坏迁移等价、回放防篡改或输入可追溯性的验收含义，不能以已有绿色输出豁免。

## 2. 冻结输入与独立性

- clean detached worktree：`C:\Users\30114\AppData\Local\Temp\veilfront-iteration2-qa-ba0f883`
- `HEAD`：`ba0f883c652f34a1611ed1598e0009da3e32dec6`
- 冻结时 `origin/main`：`ba0f883c652f34a1611ed1598e0009da3e32dec6`
- 候选父提交：`b83aac98f3dbbbb2f28236c5e1bf3d40130b79a2`
- 执行基线：`2cdfc8a31cbb59ff02cb3a83fbb19f3709d2fe86`
- GATE-1 RC3 迁移源：`6253678157157091584b253470e709bad17c534f`
- 技术证据：`evidence/gate2/iteration2-core-migration-technical-v1.md`，SHA-256 `e985862d21b5cec341507b33f23991c9299748d60f027ce9179c907eec8977eb`
- golden：`tests/game/migration/golden/gate1-successor-20-seeds-v1.json`，SHA-256 `e825641ca133eb9cae925d18e748660c7103fc5327120c5c48732027d6de0f4f`
- golden 内部摘要：`15cc37e5bbec07d39604e472517c0fc475f6c9f8f673134e58069e32cfa8ca9a`
- successor 摘要：`f6b07d8cbdc7db4492c33e8b4b028aca2906cccc8baf5921273aaa012d48e19b`
- 正式脚本与测试脚本 21 文件 bundle 独立复算：`1af0ca4c5d1a4660b010bd8b5048f56c0a141427efdb684914f1f50ddd5ace64`

QA 未修改候选实现、测试、golden、旧证据、Contract、Registry 或 approval；Godot import 产生的单个未跟踪 `.uid` 已仅从临时 detached worktree 清除。

## 3. 已执行验证

| 验证 | 精确命令/入口 | 退出码 | 结果 |
|---|---|---:|---|
| 项目实例 | `python C:\Users\30114\.codex\plugins\cache\personal\game-production-pipeline\0.4.0-alpha.2\scripts\validate_project_instance.py --project-root .` | 0 | `state=normal`；plugin lock normal；0 errors / 0 warnings |
| Godot 版本 | `D:\Godot\godot.cmd --version` | 0 | `4.7.1.stable.official.a13da4feb` |
| Godot import | `D:\Godot\godot.cmd --headless --editor --path . --quit` | 0 | import 成功 |
| 正式架构 | `D:\Godot\godot.cmd --headless --path . --script res://tests/game/architecture/run_formal_architecture_checks.gd` | 0 | `self_tests=17 scanned_files=68` |
| Observer contract | `D:\Godot\godot.cmd --headless --path . --script res://tests/game/contracts/run_observer_contract_checks.gd` | 0 | `checks=30` |
| 隐藏等价 | `D:\Godot\godot.cmd --headless --path . --script res://tests/game/contracts/run_hidden_equivalence.gd` | 0 | `pairs=6 checks=2707` |
| 20-seed 九通道命令 | `D:\Godot\godot.cmd --headless --path . --script res://tests/game/migration/run_gate1_formal_equivalence.gd -- --start-seed 471001 --seeds 20 --round-limit 50 --replay-samples 20 --channels state,event,red_player_view,black_player_view,red_visible_event,black_visible_event,visible_error,action_preview,replay` | 0 | `completed=20 replay_verified=20 channels=9`；但受第 4 节覆盖盲区影响，不能作为九通道验收 |
| 1000-seed 九通道命令 | 与上一命令相同，`--seeds 1000` | 1（人工中止） | 发现确定性验收盲区后立即停止；未形成、也不得记为 1000-seed 通过证据 |
| detached 工作树检查 | `git diff --check` | 0 | detached 工作树无本地差异 |
| 候选范围检查 | `git diff --check 2cdfc8a31cbb59ff02cb3a83fbb19f3709d2fe86..HEAD` | 2 | 4 个 `new blank line at EOF`，见 I2-QA-004 |

1000-seed 长跑及原型/场景/棋盘/教学壳重复回归在确定性阻断成立后停止，避免用更多绿色输出掩盖同一 runner 的覆盖盲区。此前已通过的架构、observer、hidden、20-seed 结果只证明各自实际执行到的断言，不扩张为被遗漏通道的证据。

## 4. 阻断缺陷

### I2-QA-001 — `critical` — live runner 未真实比较 VisibleError 与 replay

证据：

- `tests/game/migration/gate1_channel_capture.gd:144-217` 的 `compare_live()` 比较 active PlayerView、ActionPreview、提交、FullState、DomainEvent、双方 PlayerView 和双方 VisibleEvent；没有生成或比较 source/formal `VisibleError`，也没有执行权威或观察者 replay 比较。
- 同文件 `:257` 将每步 `visible_error_digest` 固定为 `digest({})`，与实际提交结果无关。
- 同文件 `:259-261` 的 `replay_checkpoint_digest` 仅摘要 intent 前缀、state digest、event digest，不是对实际 replay capture/verify 或 observer frame 的跨实现比较。
- `tests/game/migration/run_gate1_formal_equivalence.gd:79-80` 无条件用 `EXPECTED_CHANNELS.size()` 输出 `channels=9`，并不表示九个通道均执行了断言。

影响：980 个 live seed 即使在 VisibleError 或 replay 路径发生迁移差异，也可输出九通道通过；20-seed 中的固定空错误摘要同样无法发现 VisibleError 回归。技术证据“精确 1000-seed 九通道等价”的核心声明不可审计。

关闭条件：生产责任实例须让 1000-seed 每个声明通道都执行可定位的 source/formal 比较；VisibleError 必须来自真实成功/失败动作语义；replay 必须覆盖实际 AuthoritativeReplay 与 ObserverReplay；结果按实际执行断言计数，并加入逐通道变异必失败的负向自测。

### I2-QA-002 — `critical` — ObserverReplay 中间帧可被合法外形数据替换

证据：

- `scripts/game/application/observer_replay_validator.gd:40-56` 仅逐帧校验字段、DTO codec、viewer/match/rules 与帧内 action index；没有前后帧链、每帧摘要或可验证的行动结果绑定。
- `:57` 只将根 `final_player_view_digest` 与最后一帧 PlayerView 比较。多帧记录的非末帧可以换成另一份 schema-valid、同 viewer/match/rules 的内容而不改变末帧摘要。
- 现有 hidden/tamper 用例未包含“保持最终帧不变，仅替换中间 PlayerView/VisibleEvent/VisibleError/ActionPreview”的负向场景。

影响：观察者回放不能证明历史帧完整，信息边界虽可保持外形安全，但审计、复盘和篡改拒绝要求未满足。

关闭条件：增加 canonical per-frame digest 与链式/连续 action binding，最终摘要绑定完整帧链；增加多帧中间帧四类 DTO 的定向篡改拒绝测试。

### I2-QA-003 — `critical` — AuthoritativeReplay 未绑定批准 successor

证据：

- `scripts/game/domain/authoritative_replay.gd:43-64` 的记录包含 `source_commit`、规则、codec 和 audit digest，但没有 successor 路径或摘要。
- `:68-104` 的 verify 校验 source commit、codec、规则、audit 与重演结果，但不校验 successor 摘要。
- `:112-118` exact field 集也没有 successor 字段。

影响：单独流转的权威回放只能证明 RC3 source/当前代码重演，不能证明其绑定本循环批准的大本营/缓冲区 successor `f6b07d...`。golden 顶层存在 successor 摘要不能替代每份权威回放自身的来源绑定。

关闭条件：在 replay schema、capture、audit surface 和 verify 中精确绑定批准 successor 摘要；缺失或错误摘要必须硬拒绝；增加 tamper 回归并由迁移 runner 实际执行。

### I2-QA-004 — `minor / hygiene` — 候选范围 `git diff --check` 非零

`evidence/gate2/iteration2-core-migration-technical-v1.md:108`、`scripts/game/domain/move_rules.gd:595`、`rule_engine.gd:758`、`seeded_random.gd:48` 报告 `new blank line at EOF`。这不是前三项语义阻断的替代项，但与技术证据“git diff --check：通过”不一致；整改候选应清零并重新记录命令范围。

## 5. 责任返回与下一合法动作

1. 将 I2-QA-001..004 返回 `TASK-CORE-002` 的 Godot 技术生产责任实例；QA 不参与修订。
2. 技术方提交新冻结候选，并提供逐项整改映射、更新后的 runner/tamper 证据、实际执行通道计数与干净的候选范围 `git diff --check`。
3. 独立 QA 从新冻结 SHA 定向复审三个语义阻断；在 runner 盲区关闭后再执行完整 1000-seed、20 replay、golden/codec/replay tamper 与壳回归。
4. 即使后续 QA 为 `approved`，也只授权项目经理绑定证据并推进循环；GATE-2 仍须满足完整 Gate 证据并由项目所有者人工决定。

## 6. 报告完整性

`file_sha256: computed_after_write`
