# GATE-2 大本营缓冲区规则后继独立 QA 审阅 v1

- 结论：`revision_required`
- 冻结候选：`main@95c0c9da05b94648f755083515da6072ca4d124c`
- 受审生产提交：`7f511f1947d9a9438f7fcef72547b6e839c3f754`
- Contract：`LOOP-CTR-FORMAL-FOUNDATION-GATE2-001@v1`
- QA 身份：`pos:veilfront-xiangqi-siege:quality:qa-release-lead` / `inst:01M02NJ3JFHVZ5C4SP5MTJFJR6`
- 指派：`game-pipeline/loops/evidence/GATE2-headquarters-buffer-successor-review-assignment.md`
- 报告 SHA-256：`computed_after_write`，由外部交接绑定以避免自引用

原型规则实现、revision 5 定向套件、聚合回归以及冻结 1000-seed manifest 均通过独立验证；本次拒收原因是 successor 的迁移通道与定向验收矩阵不足以约束后续正式实现。该结论不否定 `7f511f1` 的原型实现，不修改 GATE-1 历史证据，也不批准 GATE-2。

## 冻结输入与证据新鲜度

验证在 clean detached worktree `main@95c0c9da05b94648f755083515da6072ca4d124c` 执行；`HEAD` 与 `origin/main` 完全一致，生产提交 `7f511f1947d9a9438f7fcef72547b6e839c3f754` 是其直接父提交。候选相对生产提交只新增 successor overlay 与本次审阅指派，未改动生产/测试树。

| 输入 | SHA-256 |
|---|---|
| 本次审阅指派 | `943b7c360769e8bdeca7017b566fb2984997d08092f1f286114fe06814430ef1` |
| Loop Contract | `a26a9b3fdb0d8d06e42a06833a84455d911fea8f72bcedec59d0ae5e620cc205` |
| 历史迁移基线 | `0502e20a861a550e9845cfa1a10e4b5d94b97d1da884add2d0de70e9fa14daa4` |
| 受审 successor | `6c985876770a8dc6e3841b207011bc087f134df2243186970ee6a298b80f6532` |
| 生产整改证据 | `0baa7fb9879749f5d88b05d24d1339a649e5e42a44bcc39027e2f0f0d5dbc90c` |
| 1000-seed manifest | `567278537d9eb62412e0ed0b50f6ea259d0129a1f527653892f390d2ae616c08` |

四份 revision 5 规则事实源的实际摘要均与 successor 声明一致：

- `rules-spec-v1.md`：`26fd3d25e2a97a39b3cd817fd74e16442360de41b40fc4fa9e035340ae2528a9`
- `settlement-order-v1.md`：`502ac07853050038a440a894f0b80d3949bd84e173c393e2cbd46a657af57507`
- `information-boundary-v1.md`：`dd76596fb4e196732ea73da9cefc33f3879b3102df345b46f55cf00fe7c17d07`
- `rules-test-coverage-matrix-v1.md`：`8ce64a69a586bb4665b7e9490ce7a3aaf3369a34908d3f2c5ef53d34d66cdabe`

## 独立执行结果

环境为 Windows、Godot `4.7.1.stable.official.a13da4feb`、headless Compatibility。

| 命令/检查 | 结果 |
|---|---|
| `validate_project_instance.py --project-root .` | 退出 `0`；项目与 plugin lock 均为 `normal`，无 error/warning |
| `D:\Godot\godot.cmd --version` | 退出 `0`；`4.7.1.stable.official.a13da4feb` |
| `D:\Godot\godot.cmd --headless --path . --editor --quit` | 退出 `0`；导入完成，无脚本错误 |
| `... --script res://tests/prototype/run_owner_rule_revision_v5.gd` | 退出 `0`；`OWNER_RULE_REVISION_V5_PASSED` |
| `... --script res://tests/prototype/run_all.gd` | 退出 `0`；`PROTOTYPE_BASIS_CHECKS_PASSED scaffold=9 focused_suites=15 full_gate1=false` |
| `... --script res://tests/prototype/verify_seeded_manifest.gd -- --path res://evidence/prototype/qa/gate2-headquarters-buffer-staging-1000-seeds-round50.jsonl` | 退出 `0`；`records=1000`，digest=`cd73f70f0b5b2db4aa01822f218f1e92a2dc75ed1b404982fde00f52b6925341` |
| 同一 verifier 加 `--force-record-tamper` | 预期退出 `1`；`manifest_count_or_digest_mismatch` |

对 JSONL 的独立结构读取得到：总行数 `1002`，记录数与唯一 seed 数均为 `1000`，seed 范围 `471001..472000`；完成 `1000`、失败 `0`；确定性检查 `1000`、不一致 `0`；replay sample 与 verified 均为 `20`；round limit 为 `50`。header、summary、记录 digest 与 verifier 结果一致。

候选范围 `git diff --check 7f511f1..95c0c9d` 退出 `2`，仅报告审阅指派文件末尾空行；不涉及规则、实现或测试语义，列为非阻断格式问题。

## 规则实现与信息边界审计

### 通过项

1. `MoveRules.evaluate_move()` 在棋子类型分派、墙状态、路径占位和隐藏阻挡解析前调用统一的 `_blocked_by_enemy_headquarters_staging()`。谓词以 `opponent(side)`、敌方 `is_in_base(target)`、敌方 `is_in_buffer(origin)`/`is_in_base(origin)` 组合处理双方，没有红黑专用分支，也不依赖目标格是否有棋子。
2. 因此规则本身覆盖空点与吃子、`BREACHED/REPAIRING` 及双方镜像；起点已在守方缓冲区或大本营时不触发该拒绝。
3. `PlayerViewProjector._preview_move()` 在墙线和所有隐藏不确定性前执行同构公开资格判断，公开直入敌营为 `KNOWN_ILLEGAL`。`RuleEngine.submit_action()` 先执行该 PlayerView preview，公开非法动作不消费行动；规则不会因路径上的隐藏相田阻挡而降级为 `TENTATIVE` 或隐藏接触失败。
4. 既有 revision 5 fixture 已覆盖红方战区直入黑营吃子、红方战区直入黑营空点、黑方战区直入红营吃子，以及双方缓冲区进入敌营吃子；对应 suite 与聚合回归均通过。

这些通过项说明原型实现没有发现规则语义错误或新增信息泄露，但不能替代 successor 对正式迁移的完整、可执行验收约束。

## 必须整改的缺陷

### `HQ-QA-001` — `major`：successor 遗漏双方 VisibleEvent 通道

受审 successor 的 `affected_channels` 仅列出：

`state,event,red_player_view,black_player_view,visible_error,action_preview,replay`

历史迁移基线的 codec binding 与正式等价命令则明确区分 `red_visible_event` 和 `black_visible_event`，并要求两个观察者的可见事件前缀逐行动 canonical bytes 零差异。合法的缓冲区进入/吃子会产生 domain event，并分别投影到两方 VisibleEvent；用未定义的单一 `event` 无法证明这两个观察者通道都被迁移和比较。

关闭条件：successor 使用与基线等价命令一致的精确通道集合，至少补入 `red_visible_event`、`black_visible_event`，并明确 `state/event/replay` 分别对应 `full_state/domain_event/authoritative+observer replay`；继续保留全量等价重跑要求，不得跳过任一观察者通道。

### `HQ-QA-002` — `major`：定向正负矩阵无法完整验收声明的对称语义与顺序

successor 与现有 fixture 的负例缺少 `black_war_zone_to_red_headquarters_empty_cell`。此外：

- 红方 submit 只间接触发内部 preview，未直接断言外部 `PlayerViewProjector.preview_intent()` 的 `KNOWN_ILLEGAL` 输出；黑方 submit、双方空点 submit 均无显式断言；
- 两个正例只做 `MoveRules.evaluate_move()` 的缓冲区到敌营吃子判定，未覆盖双方缓冲区到敌营空点，也未验证 preview 可提交、submit 后位置/伤亡正确；
- 没有“路径经过隐藏敌相田字阻挡但目标在敌营”的负例来证明公开 staging 拒绝始终先于隐藏阻挡，且不消费行动。

1000-seed 压测证明总体稳定、确定性与 replay 完整，但随机对局不能替代这些边界组合的显式断言。

关闭条件：

1. 补齐红黑双方 × 敌营空点/敌营棋子负例；对每例显式断言 public preview 为 `KNOWN_ILLEGAL`、submit 不消费且棋盘不变。
2. 补齐红黑双方 × 缓冲区进入敌营空点/吃子正例；显式断言 preview 可提交、submit 的最终位置与伤亡符合规则。
3. 增加隐藏相田阻挡路径与敌营目标重叠的负例，断言仍为公开 `KNOWN_ILLEGAL`、不消费行动且不泄露隐藏阻挡源。
4. 新冻结候选须重跑 revision 5 定向套件、聚合回归、manifest 正常/篡改 verifier。若仅修改 successor 与测试而未改变生产规则/投影/RNG，可继续绑定当前 1000-seed manifest；若生产代码或随机/投影语义变化，必须重新生成 1000-seed/20 replay 证据并完成正式全通道等价验证。

## 独立性、回退与权限边界

- 本 QA 未参与规则、实现、successor 或测试生产，未修改任何生产事实源、Contract、Registry、approval 或历史证据。
- 两项缺陷都属于已确认语义的迁移清单/可执行验收不足，不需要项目所有者重新裁决玩法。返回 `TASK-ARCH-001 / pos:veilfront-xiangqi-siege:technology:godot-technical-lead` 补齐 successor 与定向测试；若整改改变规则含义，再返回 `pos:veilfront-xiangqi-siege:design-experience:systems-experience-lead` 并由项目经理升级给项目所有者。
- 在 successor 与定向矩阵形成新冻结候选、技术复审和独立 QA 均为 `approved` 前，不得将其绑定为 `ITERATION-2-CORE-MIGRATION` 的当前输入。
- 本报告只阻止该后继输入进入正式迁移，不回退已通过的 GATE-1 原型实现和历史证据；禁止通过修改历史 manifest、只更新 digest、删除红/黑观察者通道或放宽零差异标准来关闭缺陷。
- 本结论不批准 GATE-2。GATE-2 仍须由项目所有者在完整 Contract 证据与人工验收条件满足后决定。

