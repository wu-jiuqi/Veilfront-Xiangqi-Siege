# Iteration 2 正式核心迁移系统/技术交叉复审 v1

- 结论：`revision_required`
- 冻结候选：`main@ba0f883c652f34a1611ed1598e0009da3e32dec6`
- Contract：`LOOP-CTR-FORMAL-FOUNDATION-GATE2-001@v1`
- 范围：`TASK-CORE-001`、`TASK-CORE-002`
- 复审身份：`pos:veilfront-xiangqi-siege:design-experience:systems-experience-lead` / `inst:01M02NJ3JENHD8VV7EKC9G198Q0`
- 独立性：本实例未参与本次正式 domain、projection、application、replay 或迁移 runner 的生产；此前只参与大本营缓冲区 successor 规格与复审。
- 报告 SHA-256：`computed_after_write`，由外部交接绑定以避免自引用

正式规则顺序、HQ successor、PlayerView 信息边界、席位拒绝、六组隐藏配对、原型兼容和 20-seed 的已实现比较均通过；golden 与生产证据摘要也匹配。但当前 runner 把未实际比较的 VisibleError 与 replay 计入“九通道通过”，ObserverReplay 不能拒绝合法字段形状的中间帧篡改，AuthoritativeReplay 又没有绑定后继规则输入摘要。这三项使 `CHECK-MIGRATION-001` 的 VisibleError/replay 零差异与可追溯性尚未成立，因此不能批准 Iteration 2 核心迁移。

## 冻结输入与摘要

| 输入 | SHA-256 |
|---|---|
| Loop Contract | `a26a9b3fdb0d8d06e42a06833a84455d911fea8f72bcedec59d0ae5e620cc205` |
| GATE-1 迁移 manifest | `0502e20a861a550e9845cfa1a10e4b5d94b97d1da884add2d0de70e9fa14daa4` |
| HQ successor | `f6b07d8cbdc7db4492c33e8b4b028aca2906cccc8baf5921273aaa012d48e19b` |
| 生产技术证据 | `e985862d21b5cec341507b33f23991c9299748d60f027ce9179c907eec8977eb` |
| 20-seed golden JSON | `e825641ca133eb9cae925d18e748660c7103fc5327120c5c48732027d6de0f4f` |
| 21 份正式/迁移 `.gd` bundle | `1af0ca4c5d1a4660b010bd8b5048f56c0a141427efdb684914f1f50ddd5ace64` |

bundle 按生产证据声明的规则独立重算：每文件 `sha256  path`，路径排序，条目间以 LF 连接且末尾不追加 LF。结果与生产证据一致。golden 文件实际摘要与 runner 硬编码的 `GOLDEN_SHA256` 一致；内部为 20 个 seed、`471001..471020`、共 2000 个行动步骤。未执行或覆盖 golden capture，既有 golden 保持不变。

## clean detached 自动复跑

在 `%TEMP%\veilfront-i2-cross-ba0f883` 创建 `ba0f883` 的 clean detached worktree，验证完成后已安全移除并执行 `git worktree prune`。

| 检查 | 结果 |
|---|---|
| 项目实例 validator | 退出 `0`；project/plugin lock `normal`，0 error，0 warning |
| Godot headless import | 退出 `0`；无脚本或资源导入错误 |
| `run_formal_architecture_checks.gd` | `FORMAL_ARCHITECTURE_CHECKS_PASSED self_tests=17 scanned_files=68` |
| `run_observer_contract_checks.gd` | `OBSERVER_CONTRACT_CHECKS_PASSED checks=30` |
| `run_hidden_equivalence.gd` | `HIDDEN_EQUIVALENCE_PASS pairs=6 checks=2707` |
| manifest 精确 20-seed 命令 | 退出 `0`；`FORMAL_EQUIVALENCE_PASS completed=20 replay_verified=20 channels=9` |
| `tests/prototype/run_all.gd` | 退出 `0`；`PROTOTYPE_BASIS_CHECKS_PASSED scaffold=9 focused_suites=15 full_gate1=false` |

候选提交的 `git diff --check` 只报告生产技术证据第 108 行末尾空行；不涉及实现、测试或摘要，列为非阻断格式项。

没有重复执行 1000-seed 长跑。生产证据记录的精确命令、参数和 `completed=1000 replay_verified=20 channels=9` 与 manifest 一致，但静态审计证明该 runner 没有实际覆盖其中两个声明通道。此时再次运行 1000 只会重复相同盲区，不能提升结论可信度；应先修复验收器，再执行一次可证明九通道的全量重跑。

## 通过项

### domain 规则顺序与 HQ successor

- 正式 `MoveRules.evaluate_move()` 在可见性、墙线、棋子几何和隐藏相田解析之前执行 `enemy_buffer_staging_required`；红黑使用同一 opponent/base/buffer 谓词。
- `PublicActionPreviewer` 同样先执行公开 staging，再进入墙线和隐藏相田不确定性。
- 炮击先冻结目标快照，若命中将帅则只结算将帅与同步终局；普通吃子逐枚登记实际死亡，没有被动替死路径。
- 士主动献祭、统一阵亡池、随机复活与临时视野源清理顺序保留。正式/prototype move 与 rule 文件只有 schema、projection 注入和公开分类参数等迁移差异；20-seed 状态/事件与完整原型回归通过。

### projection 与 application 席位授权

- ObserverProjector 只输出批准的 PlayerView 字段；未发现旗位、敌方隐藏棋、敌相田来源、RNG、FullState 与私有标记不进入公开 DTO。
- 六个隐藏配对全部字节等价：旗帜、马、相田、炮架、RNG、私有标记。
- FormalMatchApplication 绑定单一 viewer context；非行动席不获得行动预览，提交返回公开 `known_illegal` 且不消费行动。normalized intent codec、stale index 和 prepared token 均在权威提交前校验。
- 正式运行时目录没有 prototype、AI、LAN 或互联网依赖；原型聚合回归保持通过。正式 facade 尚未接入 ApplicationHost/MatchScreen 的限制已在生产证据中如实披露，不作为本任务阻断。

### golden 不可变性

- golden 文件摘要由 runner 硬编码校验，摘要不匹配时不能进入比较。
- golden header 同时记录 RC3 source commit 与 HQ successor digest。
- 本次未重生、覆盖或“祝福” golden；文件摘要和 21 文件 bundle 均与生产证据一致。

## 必须整改

### `I2-XREV-001` — `major`：1000/20 runner 的“九通道”声明不真实

可执行证据：

1. `gate1_channel_capture.gd::_channel_step()` 把每一步 `visible_error_digest` 固定写为 `digest({})`，不读取 source 或 formal submit 的真实结果，也不调用 VisibleError 映射。
2. 20-seed golden 的 2000 个步骤中，VisibleError 摘要只有一个唯一值：空对象摘要 `44136fa3...aff8a`。因此该通道即使正式实现完全漂移也会通过。
3. `compare_live()` 用于其余 980 个 seed，但函数体既不比较 `visible_error`，也不比较任何 replay。控制台的 `channels=9` 只来自固定 `EXPECTED_CHANNELS.size()`，不是实际检查计数。
4. `replay_checkpoint_digest` 仅包装 intent prefix、state digest 和 event digest；它不是 `veilfront-authoritative-replay-v1`，也不包含双方 ObserverReplay frame。
5. manifest 明确要求 `authorized_visible_error_semantics`、`authoritative_replay_final_state_and_event_digest` 与 `observer_replay_frames_equal_live_observer_dtos` 为零差异；当前 runner 只证明了其余通道及 state/event 的再摘要。

影响：生产报告的 `FORMAL_EQUIVALENCE_PASS ... channels=9` 不能作为九通道等价证据，1000 次通过也无法发现 VisibleError 或 replay 迁移漂移。

关闭条件：

- 给 source/formal 同一意图语料加入公开非法、stale/invalid、隐藏接触消费等可产生 VisibleError 的确定性样本，比较双方映射后的公开错误语义与隐藏配对字节；
- replay 通道直接比较 prototype/formal authoritative replay 的 intents、execution results、events、最终状态摘要，并对红黑 ObserverReplay frame 与对应 live DTO 做逐帧比较；
- `compare_live` 必须实际执行或明确分层引用这两个通道，输出检查计数不得由常量伪装；
- 保留当前 golden v1 为不可变历史；若需要新增覆盖，使用经复审的补充 fixture 或版本化 golden，不得静默重生 v1；
- 修复后按 manifest 精确命令重新执行 20/1000、20 replay、六隐藏配对和原型回归，并保留可审计输出。

### `I2-XREV-002` — `major`：ObserverReplay 可接受合法形状的中间帧篡改

观察事实：`ObserverReplayValidator` 只校验 root/frame exact fields、各 DTO codec、viewer/match/rules 绑定和**最终** PlayerView 摘要。record 没有整体 audit digest或逐帧摘要；validator 也不把 `visible_events`、`visible_error`、`action_previews` 与生成时的 live DTO 或 PlayerView cursor 建立一致性关系。空事件数组、空预览数组和空 VisibleError 都是合法形状。

由源码可直接推断：对多帧 record 修改任一非最终帧的公开 DTO，或在现有单帧 record 中把 `visible_events`/`action_previews` 替换为合法但错误的数组，仍可通过当前 validator，只要最终 PlayerView 不变。现有测试只覆盖 viewer、最终 digest、未知 root 字段和 raw domain event 字段篡改，没有覆盖“允许字段内的合法形状篡改”。

影响：`observer replay frame 与实时 DTO 等价` 只在记录刚生成的内存对象上检查一次，序列化后的回放记录不能证明逐帧完整性，生产证据所称“frame 篡改整体拒绝”不成立。

关闭条件：为 ObserverReplay 增加覆盖全部 frame 的整体 audit digest或可重放的逐帧摘要链，并校验 action index、visible sequence/cursor 与 frame 顺序；增加合法字段内篡改的负向测试。若 schema 变化，必须更新 codec 版本并纳入修复后的 replay 等价重跑。

### `I2-XREV-003` — `major`：AuthoritativeReplay 未绑定实际后继规则输入

AuthoritativeReplay 只写入 `SOURCE_COMMIT=6253678...` 和 `rules_revision=owner-confirm-2026-08-17-gate1-rule-v5`。RC3 source commit 早于 8 月 18 日追加的大本营缓冲区后继；该后继没有提升现有 rules revision。runtime replay record 不包含 successor digest `f6b07d8c...e19b`、正式规则 bundle 或组合后的 rules-input digest。

golden header 正确同时绑定 RC3 与 successor，但这不能替代每份 runtime authoritative replay 的来源绑定。当前 verifier 能拒绝伪造的 RC3 commit 字段，却无法区分“同一 RC3/v5 标签、不同后继规则输入”的记录。

关闭条件：AuthoritativeReplay exact schema 与 audit surface 加入不可歧义的规则输入绑定，至少覆盖 RC3 source commit、HQ successor digest 与正式实现/codec revision；对每一字段做篡改拒绝测试，并把更新后的 authoritative replay 纳入真正的 replay 通道等价和 20/1000 重跑。

## 结论与返回路径

结论为 `revision_required`。规则迁移主体和信息隔离没有发现行为差异，现有 20-seed、六隐藏配对、架构和原型测试均为有效的部分证据；问题集中在 replay 产品完整性与 migration runner 对九通道覆盖的错误声明。

返回 `TASK-CORE-002`，由 Godot 技术负责人修复迁移验收器及两类 replay 绑定/完整性，再形成新的冻结候选。独立 QA 应重点复核合法字段形状篡改、真实 VisibleError 语料、authoritative/observer replay 等价和修复后的 1000 命令。本报告不修改 Registry，不批准 Iteration 2，也不批准 GATE-2。
