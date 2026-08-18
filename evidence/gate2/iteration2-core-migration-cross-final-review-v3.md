# Iteration 2 正式核心迁移系统/技术最终定向复审 v3

- 结论：`revision_required`
- 冻结候选：`main@4a2713cd85d8f61d890417c8657b37f6d337ba83`
- Contract：`LOOP-CTR-FORMAL-FOUNDATION-GATE2-001@v1`
- 审查范围：`TASK-CORE-001/002` 的 `I2-XREV-001-R2` 最终复核；确认 `I2-XREV-002/003` 未回归
- 复审身份：`pos:veilfront-xiangqi-siege:design-experience:systems-experience-lead` / `inst:01M02NJ3JENHD8VV7EKC9G198Q0`
- 独立性：本实例未参与 R2 生产，只在 clean detached worktree 执行复核并创建本报告
- 报告 SHA-256：`computed_after_write`，由交接消息绑定以避免自引用

唯一 safe-frame composer、双行动席结算后完整 previews、旧“前一行动方单 preview”双向拒绝及 v3 golden 均已成立；但 `compare_live()` 在其余 980 seed 中没有生成或比较 prototype/source 的完整 ActionPreview 列表，而是把 formal frame 的 previews 直接复制给 source frame。两边该字段因此不可能出现差异，`observer_replay_frames_checked=199974` 不能证明 1000-seed 的 ActionPreview/observer frame 跨实现等价。`I2-XREV-001-R2` 尚未关闭，Iteration 2 核心迁移仍需修订。

## 1. 冻结输入与新鲜度

| 输入 | SHA-256 |
|---|---|
| 系统/技术交叉复审 v2 | `17bb4951d450b9488fa0ba45cea8fa991623ea09189cd7dca97fb4bbe9e9ad40` |
| 独立 QA 复审 v2 | `119d459365d44267b1930470cc55924dfc794ba5cae6ce8f086e45d5bf04c4bf` |
| R2 技术整改证据 | `f43bd10279bc5f8721c472a4f0546dcaf8db223a2e3452f90d1fe019add0e1d6` |
| 历史 golden v1 | `e825641ca133eb9cae925d18e748660c7103fc5327120c5c48732027d6de0f4f` |
| 历史 golden v2 | `67ed6d953a756eac88e8fa8063612409b7b7de1e009c8b80e92b0c0fccf97411` |
| 当前 golden v3 | `7c089b43667e5c0af9f4df14a2949974cb049efde34a5e9879528d99b11242ac` |
| Loop Contract | `a26a9b3fdb0d8d06e42a06833a84455d911fea8f72bcedec59d0ae5e620cc205` |
| HQ successor | `f6b07d8cbdc7db4492c33e8b4b028aca2906cccc8baf5921273aaa012d48e19b` |

复审开始时 HEAD、`main` 与 `origin/main` 均为 `4a2713cd85d8f61d890417c8657b37f6d337ba83`。项目实例 validator 退出 `0`：pipeline/plugin lock 为 `normal`，0 error、0 warning。R2 证据声明的 6 个实现/测试文件摘要全部独立复算匹配。

v1/v2 golden 字节保持不变。v3 为独立版本，schema 为 `veilfront-gate1-migration-golden-v3`，继续绑定 RC3 source `6253678157157091584b253470e709bad17c534f` 与 HQ successor `f6b07d8c...e19b`；包含 `471001..471020`、20 个 seed、2000 个行动。20 个红方与 20 个黑方 observer replay digest 均非空，且相对 v2 两侧均为 `20/20` 发生变化，符合从旧单 preview 切换到结算后完整 previews 的预期。

## 2. clean detached 自动证据

工作树：`%TEMP%\veilfront-i2-final-v3-4a2713c`；Godot：`4.7.1.stable.official.a13da4feb`。

| 检查 | 结果 |
|---|---|
| Godot headless import | 退出 `0`；无脚本或资源导入错误 |
| live-frame contract | `OBSERVER_LIVE_FRAME_CONTRACT_PASS` |
| 正式架构 | `FORMAL_ARCHITECTURE_CHECKS_PASSED self_tests=17 scanned_files=68` |
| Observer contract | `OBSERVER_CONTRACT_CHECKS_PASSED checks=30` |
| 六隐藏配对与 tamper | `HIDDEN_EQUIVALENCE_PASS pairs=6 checks=2723` |
| 精确 20-seed、九通道、`round_limit=50`、`replay_samples=20` | `FORMAL_EQUIVALENCE_PASS completed=20 replay_verified=20 channels=9 visible_error_checked=2080 authoritative_replay_checked=20 observer_replay_frames_checked=4000` |
| 非 golden live 抽查 `471021..471024` | `completed_live=4/4 workers=4`；`visible_error_checked=416 authoritative_replay_checked=4 observer_replay_frames_checked=800` |
| prototype 聚合回归 | `PROTOTYPE_BASIS_CHECKS_PASSED scaffold=9 focused_suites=15 full_gate1=false` |
| `git diff --check a89ebf4..4a2713c` | 退出 `0` |

Godot import 在临时工作树生成两个未跟踪 `.gd.uid`，不属于候选提交、实现或证据；tracked diff 保持为空。本复审未修改或重新生成 golden。

## 3. `I2-XREV-001-R2` 关闭证据

### 唯一 safe-frame composer

正式运行时不再在 `submit_intent()` 内手写 frame。行动结算和下一回合准备完成后，它调用 `_compose_safe_frame()`；该函数投影结算后的 PlayerView/VisibleEvent，调用 `_action_previews_for_view()`，最后唯一落入 `_compose_safe_frame_from_dtos()` 形成 frame 外形。

全正式脚本与 migration 测试的检索结果中，`frame_sequence` 字典只在 `FormalMatchApplication._compose_safe_frame_from_dtos()` 定义一次。golden capture 使用 `_compose_safe_frame()`；live runner 明确调用 `_compose_safe_frame_from_dtos()` 与 `_action_previews_for_view()`，没有保留旧 `_observer_frame()` 复制实现。因此生产 submit 与验收器不会各自漂移出第二套 frame 结构。

### 双行动席完整 previews 与旧模型拒绝

`_action_previews_for_view()` 的语义是：终局或非当前行动席返回空数组；当前行动席调用 `PublicActionPreviewer.generate_action_intents()` 返回完整、有序列表。

定向合同连续结算红、黑各一个行动并断言：

1. 红行动后红 frame previews 为空，黑 frame 等于黑方结算后完整 previews；
2. 黑行动后黑 frame previews 为空，红 frame 等于红方结算后完整 previews；
3. 两个方向的旧“前一行动方单 preview、下一方空列表”均与正式 frame 不相等。

合同在 clean 候选上退出 `0`。此外，既有 hidden contract 仍把正式 `submit_intent()` 返回的四类安全 DTO 与其 ObserverReplay frame 做字节比较，并保留合法形状篡改拒绝；因此共享 composer 不削弱 `I2-XREV-002` 的完整性结论。

### golden 已修复，但 live980 仍有盲区

前 20 个 golden seed 中，prototype 侧从结算后状态调用 `SourceMapper.action_previews()` 映射当前行动席完整 preview 列表，formal 侧调用正式 composer；红黑逐帧摘要链进入 v3 golden 和 `compare_records()`。独立 20-seed 的 4000 个 frame 全部匹配。这部分正确关闭了旧 v2 golden 的单 preview 语义。

其余 live 分支虽然先逐项证明 source/formal 的 FullState、双方 PlayerView、双方 VisibleEvent 与 VisibleError 相等，也实际调用唯一 composer，但 previews 字段的比较无效：

1. formal 红黑 frame 分别使用 `FormalMatchApplication._action_previews_for_view(formal_red/formal_black)`；
2. source 红黑 frame 没有调用现成的 `SourceMapper.action_previews(source_state, side)`，而是分别直接传入 `formal_red_frame["action_previews"]` 与 `formal_black_frame["action_previews"]`；
3. 随后的完整字典比较只能检查其他 source DTO 字段，无法发现 prototype 与 formal 完整 preview 列表的内容、顺序或数量漂移。

manifest 的 ObserverReplay source codec 虽为 `none_new_formal_projection`，但同一 manifest 仍要求 `action_preview_canonical_bytes_and_order`，且原 QA 关闭条件明确要求同一时点 source live DTO 与 formal frame 比较。安全 frame 外形可合法复用正式 composer，source previews 数据却不能直接复用被测 formal 结果。独立 4-seed 抽查证明这一盲区路径确实执行并累计 800 个 frame，不能把它转化为跨实现通过证据。

## 4. 1000-seed 证据审计

本次按任务约束未重复执行完整 1000。R2 生产证据记录同一冻结实现自然退出 `0`：

- `FORMAL_EQUIVALENCE_PROGRESS completed_live=980/980 workers=12`
- `FORMAL_EQUIVALENCE_PASS completed=1000 replay_verified=20 channels=9 visible_error_checked=103987 authoritative_replay_checked=1000 observer_replay_frames_checked=199974`

源码审计确认计数确实来自实际控制流：每个 live 行动在红黑 frame 字典比较后增加 action count；每 seed 终局后再比较四项 VisibleError 语料与一份权威 replay 语义；`compare_live_range()` 和 runner 只累加各线程实际返回值。当前机器为 16 逻辑处理器，worker 公式 `processor_count - 4` 得到 12，与生产输出一致。

计数可逆核对：`199974 / 2 = 99987` 个总行动；其中 v3 golden 为 2000，live980 为 97987；`99987 + 4 * 1000 = 103987` 个 VisibleError 检查；每 seed 一份权威 replay 共 1000。没有固定常量冒充执行或跳过 live980，但 195,974 个 live980 frame 的 source previews 均来自 formal frame 本身。因此计数只能证明盲区比较器运行了相应次数，不能恢复 `CHECK-MIGRATION-001` 的九通道含义。

## 5. 范围边界

整改生产提交范围清晰：

- `04da51b` 只修改 `formal_match_application.gd`，统一 safe-frame 与完整 preview 生成；
- `4a2713c` 只修改 migration runner/mapper/capture，新增 live-frame contract、v3 golden 与 R2 证据；
- 未修改 domain 规则、随机消费、projection 信息边界、规则事实源、Contract、Registry、approval、ApplicationHost/MatchScreen、网络、LAN 或 AI。

冻结候选还包含并行提交 `79d1b36` 的 FTUE 方案文档与 PDF，以及 `b4f0604` 的两份失败复审报告；它们与本整改生产文件分离，不改变正式运行时或测试语义，也未引入互联网、AI 或批量美术实现。没有发现以本次整改扩大 Iteration 2 范围的情况。

## 6. 阻断、最终判定与下一合法动作

- `I2-XREV-001-R2`：`not_closed`
- `I2-XREV-002`：维持 `closed`
- `I2-XREV-003`：维持 `closed`
- `TASK-CORE-001/002` 系统/技术定向结论：`revision_required`

剩余缺陷记为 `I2-XREV-001-R3 / major`。返回 `TASK-CORE-002` 的 Godot 技术生产责任实例，最小关闭条件是：

1. live runner 对每一行动分别计算 `SourceMapper.action_previews(source_state, "red"/"black")` 与 `FormalMatchApplication._action_previews_for_view(formal_red/formal_black)`，先按完整内容和顺序比较，再把各自结果传入同一个 safe-frame composer；
2. 增加 live 路径负向断言，证明只改变 source 完整 preview 列表的内容、顺序或数量会让 runner 失败，而不是仅证明旧单 preview 与一个 formal frame 不相等；
3. v3 golden 可保持不可变，因为前 20 seed 的 source/formal 完整列表已经正确比较；修复后必须从新冻结 SHA 重跑 live-frame contract、20-seed、非 golden live 抽查及完整 1000-seed，并保留实际计数。

此缺陷不需要改变规则、safe-frame schema、Contract、Registry 或 approval。修复并经独立系统/技术与 QA 复审后，项目经理才可把 Iteration 2 证据纳入 GATE-2 决策包。GATE-2 仍由项目所有者人工决定；本报告不是 GATE-2 approval。
