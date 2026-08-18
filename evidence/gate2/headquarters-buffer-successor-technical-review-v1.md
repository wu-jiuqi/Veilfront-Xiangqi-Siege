# GATE-2 大本营缓冲区规则后继定向技术/体验复审 v1

- 结论：`revision_required`
- 冻结候选：`main@95c0c9da05b94648f755083515da6072ca4d124c`
- 受审生产提交：`7f511f1947d9a9438f7fcef72547b6e839c3f754`
- Contract：`LOOP-CTR-FORMAL-FOUNDATION-GATE2-001@v1`
- 复审身份：`pos:veilfront-xiangqi-siege:design-experience:systems-experience-lead` / `inst:01M02NJ3JENHD8VV7EKC9G198Q0`
- 指派：`game-pipeline/loops/evidence/GATE2-headquarters-buffer-successor-review-assignment.md`
- 报告 SHA-256：`computed_after_write`，由外部交接绑定以避免自引用

受审的原型规则实现按源码结构满足项目所有者语义，既有回归和 1000-seed 证据也有效；本次退回原因是正式迁移 successor 的受影响通道与定向验收矩阵不完整，尚不能作为 `ITERATION-2-CORE-MIGRATION` 的完整输入合同。该结论不否定生产实现，不修改 GATE-1 历史证据，也不代替独立 QA 或 GATE-2 人工决定。

## 输入绑定与新鲜度

| 输入 | SHA-256 |
|---|---|
| 本次复审指派 | `943b7c360769e8bdeca7017b566fb2984997d08092f1f286114fe06814430ef1` |
| Loop Contract | `a26a9b3fdb0d8d06e42a06833a84455d911fea8f72bcedec59d0ae5e620cc205` |
| 历史迁移基线 `gate1-to-formal-migration-manifest-v1.yaml` | `0502e20a861a550e9845cfa1a10e4b5d94b97d1da884add2d0de70e9fa14daa4` |
| 受审 successor `gate1-to-formal-migration-successor-v2.yaml` | `6c985876770a8dc6e3841b207011bc087f134df2243186970ee6a298b80f6532` |
| 生产整改证据 | `0baa7fb9879749f5d88b05d24d1339a649e5e42a44bcc39027e2f0f0d5dbc90c` |
| 1000-seed manifest | `567278537d9eb62412e0ed0b50f6ea259d0129a1f527653892f390d2ae616c08` |
| Loop Registry Snapshot | `76f3d6c4afd41b4f488a33f4edfd79361b89ab0b3ea23bf1c7cff109e7ccff79` |
| Loop Registry Event History | `50c6b94517584223844de255f6aff28598a68e678a1c1c791cd483454daa9ed9` |

`HEAD` 为精确冻结候选，`7f511f1` 是其祖先；tracked worktree 在复审前无修改。候选内规则事实源、整改证据、manifest 摘要与 successor 声明一致。

## 自动验证

环境：Godot `4.7.1.stable.official.a13da4feb`，Windows，headless Compatibility。

| 检查 | 结果 |
|---|---|
| `D:\Godot\godot.cmd --headless --path . --editor --quit` | 退出 `0`，导入无错误 |
| `... --script res://tests/prototype/run_owner_rule_revision_v5.gd` | 退出 `0`，`OWNER_RULE_REVISION_V5_PASSED` |
| `... --script res://tests/prototype/run_move_rules.gd` | 退出 `0`，`MOVE_RULES_SUITE_PASSED` |
| `... --script res://tests/prototype/run_owner_rule_revision_v4.gd` | 退出 `0`，`OWNER_RULE_REVISION_V4_PASSED` |
| `... --script res://tests/prototype/run_all.gd` | 退出 `0`，`PROTOTYPE_BASIS_CHECKS_PASSED scaffold=9 focused_suites=15 full_gate1=false` |
| `... --script res://tests/prototype/verify_seeded_manifest.gd -- --path evidence/prototype/qa/gate2-headquarters-buffer-staging-1000-seeds-round50.jsonl` | 退出 `0`，`records=1000`，records digest=`cd73f70f...25341` |
| 同一 verifier 加 `--force-record-tamper` | 预期退出 `1`，`manifest_count_or_digest_mismatch` |

独立读取 JSONL 得到：总行数 `1002`，记录 `1000`，唯一 seed `1000`，范围 `471001..472000`；`determinism_match=false` 数量 `0`，replay sample `20`，summary 的 completed/failures/replay verified 为 `1000/0/20`。

对 `7f511f1^..95c0c9d` 执行 `git diff --check` 只报告复审指派文件末尾多余空行，不涉及规则实现或证据语义；此项为非阻断格式问题。

## 技术与体验结论

### 1. 统一合法性与红黑对称：实现通过

`MoveRules.evaluate_move()` 在目标边界检查后立即调用唯一 authoritative 谓词 `_blocked_by_enemy_headquarters_staging()`。谓词使用 `MatchState.opponent(side)` 取得守方，再以同一 `is_in_base(target, enemy_side)`、`is_in_buffer(origin, enemy_side)` 和 `is_in_base(origin, enemy_side)` 组合处理红黑双方，没有阵营专用分支。

该谓词不读取目标格占位者，因此同一入口同时覆盖：

- 战区直入敌营空点；
- 战区直击敌营棋子；
- 起点已在敌方缓冲区（含墙线）后进入或攻击敌营；
- 起点已在敌方大本营内继续于营内移动/吃子。

墙状态不参与该资格判断，`INTACT/BREACHED/REPAIRING` 不会改变“两段式进入敌营”的前置规则。

### 2. PlayerView preview 与 submit：实现语义一致

`PlayerViewProjector._preview_move()` 在墙线、路径、目标占位和所有隐藏不确定性前调用同构公开谓词，直入敌营统一返回 `KNOWN_ILLEGAL`。`RuleEngine.submit_action()` 的普通玩家路径先投影同一 PlayerView 并执行 `preview_intent()`；`KNOWN_ILLEGAL` 返回 `visible_rule_rejection`、不消费行动。受审红方吃子 fixture 对 submit 断言了不消费、进攻棋不移动、目标棋仍存活，因此不是把公开非法错误处理成隐藏接触消耗。

authoritative 与 public helper 目前是两份同构实现，现阶段结果一致；正式迁移不得只迁移其中一份，必须由 action-preview/visible-error 等价通道同时约束。

### 3. 隐藏阻挡顺序：实现通过

authoritative staging 检查位于 `visible_set` 构造、棋子几何分派、车/兵相田字拦截和墙线解析之前；PlayerView staging 检查同样位于 `_public_wall_blocks()`、隐藏相田不确定性和目标占位解析之前。

因此玩家从战区指定敌营目标时会在公开资格层得到 `KNOWN_ILLEGAL`，不能用路径上的隐藏相田字格把非法直击转换成 `TENTATIVE`，也不能提交后在缓冲区首交点截停并绕过“两次行动”要求。这一顺序没有泄露相田来源。

## 必须整改的问题

### `HQ-SUCCESSOR-001` — `major`：successor 漏列双方 VisibleEvent 迁移通道

`docs/architecture/gate1-to-formal-migration-successor-v2.yaml:41-48` 的 `affected_channels` 只有：

```text
state,event,red_player_view,black_player_view,visible_error,action_preview,replay
```

但其明确 supersede 的基线在 `codec_bindings.channels` 中分别冻结 `red_visible_event` 与 `black_visible_event`，正式等价命令也使用九通道：

```text
state,event,red_player_view,black_player_view,
red_visible_event,black_visible_event,visible_error,action_preview,replay
```

合法的缓冲区→大本营移动/吃子会产生领域事件并进入双方各自的可见事件前缀；非法直入则影响 visible error 而不产生动作事件。用一个未定义的 `event` 不能证明两个观察者 VisibleEvent 通道均被纳入后继迁移。

关闭条件：successor 使用与基线 comparison command 一致的精确通道集合，至少补入 `red_visible_event`、`black_visible_event`，并明确 `state/event/replay` 分别映射 `full_state/domain_event/authoritative+observer replay`，继续要求全量等价重跑。

### `HQ-SUCCESSOR-002` — `major`：红黑 × 吃子/空点 × preview/submit 最小矩阵不完整

successor 的 `required_negative_cases` 有红方吃子、红方空点、黑方吃子，但缺少：

```text
black_war_zone_to_red_headquarters_empty_cell
```

现有 `test_owner_rule_revision_v5.gd` 同样只执行黑方吃子负例。红方 submit 通过 RuleEngine 内部 preview 间接证明公开拒绝且不消费，但没有对黑方 submit、双方空点 submit 或公开 `preview_intent()` 输出建立显式断言；两个正例只直接检查缓冲区→敌营吃子，没有检查空点进入。

源码的共享谓词足以支持“实现大概率正确”的判断，但不能替代 successor 要求的可迁移验收矩阵。1000-seed 压测也不保证覆盖这些精确边界组合。

关闭条件：

1. successor 补齐黑方空点负例，并把正例明确拆为双方的缓冲区→敌营吃子与缓冲区→敌营空点；
2. 定向测试对红黑双方、吃子/空点至少显式断言 `PlayerViewProjector.preview_intent()==KNOWN_ILLEGAL` 与 `RuleEngine.submit_action()` 不消费且不变更棋盘；
3. 正例显式证明 preview 可提交且 submit 实际落点/伤亡正确；
4. 增加一条路径穿过隐藏敌相田字、目标位于敌营的负例，证明结果仍是公开 `KNOWN_ILLEGAL`、不消费行动，而不是 `TENTATIVE` 或隐藏接触截停。

若只补 successor 与测试而不修改生产规则/投影/随机代码，既有 1000-seed manifest 可继续绑定 `7f511f1`，但必须重跑定向套件、聚合回归和 manifest verifier；若生产代码变化，则按 successor 的 `full_equivalence_rerun_required` 重新生成并验证 1000-seed/20 replay 证据。

## 非阻断观察

- `information-boundary-v1.md` 的通用定义允许“仅凭公开规则确认非法”归入 `KNOWN_ILLEGAL`，而规则规格与结算顺序已把大本营缓冲前置放在公开预览/校验阶段；当前没有语义冲突。为减少 Iteration 2 误读，可在 successor 中明确本规则是 observer-independent public eligibility，而不必改写历史信息边界证据。
- 当前 authoritative/public helper 为重复的小型谓词。正式核心迁移应只保留一份纯公开资格定义或加入逐组合等价测试，避免后续单边漂移。
- 本裁决没有发现需要项目所有者再次选择的玩法歧义；问题均为已确认语义的迁移清单与证据覆盖不足。

## 结论与返回路径

结论为 `revision_required`：规则实现、红黑结构对称、吃子/空点统一判断、公开 preview/submit 顺序和隐藏阻挡优先级均通过源码审计，revision 4/5、move、聚合与 manifest 验证也通过；但 `HQ-SUCCESSOR-001/002` 使后继迁移合同不能完整约束正式实现。

返回 `TASK-ARCH-001 / pos:veilfront-xiangqi-siege:technology:godot-technical-lead` 补齐 successor 与定向测试，由项目经理形成新的冻结候选并重新指派技术与独立 QA 复审。在两份定向复审均为 `approved` 前，不得把该 successor 绑定为 `ITERATION-2-CORE-MIGRATION` 输入；本报告不批准 GATE-2，也不改变当前 Loop Registry。
