# Iteration 2 正式核心迁移系统/技术最终复审 v2

- 结论：`revision_required`
- 冻结候选：`main@a89ebf4da4c152e4ca56b240575fc1a8737002b8`
- Contract：`LOOP-CTR-FORMAL-FOUNDATION-GATE2-001@v1`
- 范围：`TASK-CORE-001`、`TASK-CORE-002`，定向复核 `I2-XREV-001/002/003`
- 复审身份：`pos:veilfront-xiangqi-siege:design-experience:systems-experience-lead` / `inst:01M02NJ3JENHD8VV7EKC9G198Q0`
- 独立性：本实例未参与本次整改生产；只在 clean detached worktree 复跑、审计并创建本报告
- 报告 SHA-256：`computed_after_write`，由交接消息绑定以避免自引用

`I2-XREV-002` 与 `I2-XREV-003` 已关闭；`I2-XREV-001` 的 VisibleError、权威 replay 与计数盲区已实质修复，但 observer replay 的迁移比较仍未使用正式运行时产生的 live ActionPreview DTO。当前 20/1000 runner 比较的是自行构造、且时序相反的 preview 数组，因此不能把 `observer_replay_frames_checked` 解释为“逐帧等于 live observer DTO”。在该唯一剩余阻断关闭前，不能批准 Iteration 2 核心迁移。

## 1. 冻结输入与摘要

| 输入 | SHA-256 |
|---|---|
| 原系统/技术交叉复审 v1 | `b9813e1907aee2d7fd73f6fcdb5b90e7720bac21831d58163c75a8b70142eb64` |
| 整改证据 v1 | `2b827ac901bbcd75832881c3e83ac60aa9c4e788dd2b0d27ebb5340e6a64caef` |
| 原独立 QA v1 | `1739e561cdfe8929926a5556e87b78fe9056c0604586fc28a873bd04215f247e` |
| Loop Contract | `a26a9b3fdb0d8d06e42a06833a84455d911fea8f72bcedec59d0ae5e620cc205` |
| HQ successor | `f6b07d8cbdc7db4492c33e8b4b028aca2906cccc8baf5921273aaa012d48e19b` |
| 历史 golden v1 | `e825641ca133eb9cae925d18e748660c7103fc5327120c5c48732027d6de0f4f` |
| 整改 golden v2 | `67ed6d953a756eac88e8fa8063612409b7b7de1e009c8b80e92b0c0fccf97411` |

候选 HEAD、`main` 与 `origin/main` 在复审开始时均为 `a89ebf4da4c152e4ca56b240575fc1a8737002b8`。项目实例 validator 返回 pipeline/plugin lock `normal`、0 error、0 warning。v1 golden 字节摘要保持不变；v2 golden 顶层实际绑定 RC3 source `6253678157157091584b253470e709bad17c534f` 与 successor `f6b07d8c...e19b`，包含 `471001..471020` 共 20 个 seed、2000 个行动。

v2 每 seed 均有四项实际错误语料：`known_illegal`、`stale_intent`、`invalid_request` 与一次隐藏马腿接触的已消费结果；前三项产生公开 VisibleError，后者按现行公开语义产生空错误对象并由 DomainEvent 表达结果。20 个 seed 合计 80 项语料，三类非空错误各 20 次、已消费空错误 20 次；20 份权威 replay 语义摘要及红黑 observer 摘要均非空。

## 2. clean detached 复跑

工作树：`%TEMP%\veilfront-i2-rereview-a89ebf4`，Godot `4.7.1.stable.official.a13da4feb`。

| 检查 | 结果 |
|---|---|
| Godot headless import | 退出 `0`；无脚本/资源导入错误 |
| 正式架构 | `FORMAL_ARCHITECTURE_CHECKS_PASSED self_tests=17 scanned_files=68` |
| Observer contract | `OBSERVER_CONTRACT_CHECKS_PASSED checks=30` |
| 六隐藏配对 | `HIDDEN_EQUIVALENCE_PASS pairs=6 checks=2723` |
| 精确 20-seed，默认九通道、`round_limit=50`、`replay_samples=20` | `FORMAL_EQUIVALENCE_PASS completed=20 replay_verified=20 channels=9 visible_error_checked=2080 authoritative_replay_checked=20 observer_replay_frames_checked=4000` |
| 非 golden live 路径抽查 `471021..471024` | `completed_live=4/4 workers=4`；`visible_error_checked=416 authoritative_replay_checked=4 observer_replay_frames_checked=800` |
| prototype 聚合回归 | `PROTOTYPE_BASIS_CHECKS_PASSED scaffold=9 focused_suites=15 full_gate1=false` |
| 候选提交 `git diff --check a89ebf4^..a89ebf4` | 退出 `0` |

本次没有重复执行 1000-seed 长跑。整改证据记录的 `completed_live=980/980` 与最终计数内部一致：`199974 / 2 = 99987` 个行动，`99987 + 4 * 1000 = 103987` 个 VisibleError 检查，权威 replay 为 1000 份。源码也确实按每 seed 实际返回值累加，不再以 `EXPECTED_CHANNELS.size()` 代替执行计数；4 个非 golden seed 的独立抽查已进入同一线程化 live 分支。剩余问题是 observer frame 构造语义本身错误，重复 1000 次不会提高其有效性，因此停止在定向复审并返回生产整改。

## 3. 已关闭项

### `I2-XREV-002` — closed：ObserverReplay 全帧完整性

- schema 已升为 `veilfront-observer-replay-v2`；root `audit_digest` 覆盖整个记录及全部 frame，任一允许字段变化但未重新签名都会被拒绝。
- validator 校验 `frame_sequence`、action index 单调与 PlayerView action index 一致、VisibleEvent sequence/cursor 前缀连续，并对五类公开 DTO 使用 exact codec。
- hidden 回归覆盖 VisibleEvent、VisibleError、ActionPreview 的合法字段形状篡改，以及 viewer、最终视图摘要、未知根字段、raw DomainEvent 字段篡改；全部拒绝。基线 frame 的 PlayerView、VisibleEvent、VisibleError、ActionPreview 也逐项与同次 `FormalMatchApplication.submit_intent()` 返回值进行字节比较。

这关闭的是正式 ObserverReplay 产品自身的完整性与防篡改问题；不豁免第 4 节指出的迁移 runner live-frame 语义问题。

### `I2-XREV-003` — closed：AuthoritativeReplay 规则输入绑定

- `veilfront-authoritative-replay-v2` exact schema、audit surface 与 verifier 均绑定 RC3 source、HQ successor、正式规则 bundle、实现 revision、canonical revision 及 FullState/DomainEvent codec revision；逐字段篡改均被拒绝。
- 正式规则 bundle 的 8 个输入为 `canonical.gd`、`domain_event_codec.gd`、`full_state_codec.gd`、`match_state.gd`、`move_rules.gd`、`rule_engine.gd`、`seeded_random.gd`、`visibility_policy.gd`。按路径排序，以 `sha256  path`、LF 连接且末尾无 LF独立重算为 `f3d09bca73a4e074d698fab29acceb425cc5374b080666af3fddfdb81e1a29a8`，与运行时常量一致。
- 精确 20-seed 对 20 份实际 `AuthoritativeReplay.capture()/verify()` 均验证成功；live980 侧比较 normalized intents、execution results、DomainEvents 与 final state summary，计数路径不再为空。

### `I2-XREV-001` 的已关闭部分

- 成功行动的实际 VisibleError 由 source mapper 与 formal projector 分别生成后比较；四项固定错误语料也分别调用 prototype/formal 的实际 application/rule 路径，不再固定摘要空对象。
- v2 golden 不覆盖 v1，runner 硬绑定 v2 SHA `67ed6d...7411`；20-seed 计数与内容均独立复算。
- live runner 每 seed 比较权威 replay 语义，并从真实 action count、错误语料数与红黑 frame 数累加计数；4-seed live 抽查证明该分支实际执行。

## 4. 剩余阻断

### `I2-XREV-001-R2` — `major`：迁移 runner 的 observer ActionPreview 不是 live DTO

manifest 对 replay 的要求是 `authoritative_final_state_and_events_plus_live_safe_dto_frames`；原复审关闭条件也明确要求红黑 ObserverReplay frame 与对应 live DTO 逐帧比较。当前实现不满足该条件：

1. `FormalMatchApplication.submit_intent()` 在行动结算后生成 frame；`action_previews` 是**结算后下一行动方**的 `current_action_previews()`。若红方行动后轮到黑方，红方 live frame 必为 `[]`，黑方 live frame 为黑方当前所有合法预览。
2. `gate1_channel_capture.gd::compare_live()` 并不调用 FormalMatchApplication，也不读取其 observer record。它用 `_observer_frame()` 自行构造 frame，并把**结算前刚执行意图的单个 preview**放入原行动方：红方行动时红 frame 为 `[source/formal_preview]`，黑 frame 为 `[]`。
3. 因而当前 frame 的 preview 时序、观察者归属和数量均与正式 live DTO 相反。source/formal 仍会彼此相等，只因为两边使用了同一错误构造器；`observer_replay_frames_checked=199974` 证明该构造器被执行了 199974 次，不能证明任何一帧等于正式运行时 DTO。
4. v2 golden 的 `red_observer_frame_digest` / `black_observer_frame_digest` 及 replay digest chain 也来自该构造器，故不能作为此项的正确基线。hidden 测试只证明单个正式应用 frame 与其自身 live 返回一致，没有把 20/980 迁移 frame 与该产品输出连接起来。

影响：state、event、双方 PlayerView/VisibleEvent、VisibleError 与独立 ActionPreview 通道仍有有效跨实现证据；ObserverReplay 产品自身也已防篡改。但 manifest 所要求的“回放 frame 等于 live 安全 DTO”没有在迁移等价中成立，不能关闭 replay 九通道验收。

关闭条件：

1. 用与 `FormalMatchApplication.submit_intent()` 完全相同的结算后 DTO 规则构造双方 frame，至少对 action index、PlayerView、VisibleEvent、VisibleError 与**下一行动席完整 ActionPreview 列表**逐字段比较；更优方案是让测试调用正式的单一 frame builder，避免测试复制运行时语义。
2. 增加最小负向断言：红方行动后红 frame preview 为空、黑 frame preview 等于黑方 live preview；黑方行动后反向成立。把当前“前一行动方单 preview”变异为必失败。
3. 保留 v1/v2 golden 为不可变历史；正确覆盖使用版本化 v3 golden 或独立补充 fixture，不得原地重生 v2。
4. 修复后重跑精确 20/1000、20 份实际权威 replay、六隐藏配对、Observer tamper、架构、observer contract 与 prototype，并继续输出实际计数。

## 5. 结论与下一合法动作

最终结论为 `revision_required`：`I2-XREV-002/003` 关闭，`I2-XREV-001` 因 `I2-XREV-001-R2` 仍未完全关闭。返回 `TASK-CORE-002` 的 Godot 技术生产责任实例，仅修复迁移 observer frame/live DTO 绑定与版本化 golden；无需修改已确认玩法规则、Project Brief、Contract、Registry 或 approval。

该问题是验收器对既定运行时 DTO 的客观不一致，不需要项目所有者决定规则语义。修复并形成新冻结候选后，应由未参与生产的系统/技术与独立 QA 定向复审；本报告不批准 Iteration 2，也不批准 GATE-2。
