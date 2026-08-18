# GATE-2 大本营缓冲区规则后继最小整改证据 v1

## 结论

- 状态：`remediation_complete_pending_independent_rereview`
- 冻结候选：`main@95c0c9da05b94648f755083515da6072ca4d124c`
- 受审生产提交：`7f511f1947d9a9438f7fcef72547b6e839c3f754`
- 整改范围：仅迁移后继叠加层、revision 5 原型回归和本证据；未修改生产实现、Registry、Contract 或 approval。
- 关闭结论：`HQ-SUCCESSOR-001` 与 `HQ-SUCCESSOR-002` 的文档/回归覆盖缺口均已补齐。本结论不代替独立 QA，也不批准 GATE-2。

执行身份：`inst:01M02NJ3JENHD8VV7EKC9G198Q0` / `pos:veilfront-xiangqi-siege:design-experience:systems-experience-lead` / `AUTH-VEILFRONT-SYSTEMS-EXPERIENCE`。

## 整改内容

### HQ-SUCCESSOR-001

`docs/architecture/gate1-to-formal-migration-successor-v2.yaml` 的正式迁移受影响通道已补充：

- `red_visible_event`
- `black_visible_event`

原有 `state`、`event`、双方 `player_view`、`visible_error`、`action_preview`、`replay` 继续保留。

### HQ-SUCCESSOR-002

后继叠加层和 `tests/prototype/test_owner_rule_revision_v5.gd` 现明确覆盖以下完整矩阵：

| 行动方 | 起点资格 | 目标 | PlayerView preview | submit |
|---|---|---|---|---|
| 红 | 战区 | 黑方大本营敌子 | `KNOWN_ILLEGAL` | 拒绝、不消费、棋盘不变 |
| 红 | 战区 | 黑方大本营空点 | `KNOWN_ILLEGAL` | 拒绝、不消费、棋盘不变 |
| 黑 | 战区 | 红方大本营敌子 | `KNOWN_ILLEGAL` | 拒绝、不消费、棋盘不变 |
| 黑 | 战区 | 红方大本营空点 | `KNOWN_ILLEGAL` | 拒绝、不消费、棋盘不变 |
| 红 | 黑方缓冲区 | 黑方大本营敌子 | 非 `KNOWN_ILLEGAL` | 接受并完成吃子 |
| 红 | 黑方缓冲区 | 黑方大本营空点 | 非 `KNOWN_ILLEGAL` | 接受并完成落子 |
| 黑 | 红方缓冲区 | 红方大本营敌子 | 非 `KNOWN_ILLEGAL` | 接受并完成吃子 |
| 黑 | 红方缓冲区 | 红方大本营空点 | 非 `KNOWN_ILLEGAL` | 接受并完成落子 |

“preview/submit 同语义”在这里精确定义为两者对**公开缓冲区前置资格**一致：不合资格时 preview 明确拒绝且 submit 不消费；已合资格时 preview 不得以该公开条件拒绝，submit 可以进入权威结算。路径仍含未探明位置时，preview 按现有信息边界可保留 `TENTATIVE`，这不是资格冲突，也不应强行提升为 `KNOWN_LEGAL`。

另新增隐藏相田字格顺序回归：红车从战区直指黑方大本营且路径同时穿过未公开的黑相田字格时，统一合法性入口必须先返回 `enemy_buffer_staging_required`；preview 必须保持 `KNOWN_ILLEGAL`，submit 不消费，且不得先产生 `elephant_field_intercepted`。这证明公开 staging 判定不会被隐藏阻挡绕过或降级为 `TENTATIVE`。

## 验证记录

环境：Godot `4.7.1.stable.official.a13da4feb`，Windows，headless Compatibility。

| 命令 | 结果 |
|---|---|
| `D:\Godot\godot.cmd --headless --path . --editor --quit` | 退出 `0`，导入无错误 |
| `... --script res://tests/prototype/run_owner_rule_revision_v5.gd` | `OWNER_RULE_REVISION_V5_PASSED` |
| `... --script res://tests/prototype/run_move_rules.gd` | `MOVE_RULES_SUITE_PASSED` |
| `... --script res://tests/prototype/run_owner_rule_revision_v4.gd` | `OWNER_RULE_REVISION_V4_PASSED` |
| `... --script res://tests/prototype/run_all.gd` | 退出 `0`，`PROTOTYPE_BASIS_CHECKS_PASSED scaffold=9 focused_suites=15 full_gate1=false` |
| `... --script res://tests/prototype/verify_seeded_manifest.gd -- --path evidence/prototype/qa/gate2-headquarters-buffer-staging-1000-seeds-round50.jsonl` | `SEEDED_MANIFEST_VERIFIED records=1000`，records digest=`cd73f70f...25341` |
| `git diff --check` | 通过 |

测试编写期间，正例最初被过度约束为必须 `KNOWN_LEGAL`，定向运行暴露四个正例在路径含未探明位置时按既有契约返回 `TENTATIVE`。断言随后收敛为“非 `KNOWN_ILLEGAL` 且 submit 接受”，没有为此修改生产代码或玩法。

## 摘要绑定

| 输入/产物 | SHA-256 |
|---|---|
| 原技术复审 `evidence/gate2/headquarters-buffer-successor-technical-review-v1.md` | `55b62f7849b55ce42df42a06d51dee1d8f7f89c5e36ece341ecd433db418b11a` |
| `docs/architecture/gate1-to-formal-migration-successor-v2.yaml` | `58e2ee794d852f09e389263ac33ed374cb5b697e83f8363e8ff5c74e9a0f4068` |
| `tests/prototype/test_owner_rule_revision_v5.gd` | `e2d136b2d218876216caaf0627d68d0f8767550930201d5592167fe2150d82ff` |
| 既有 1000-seed manifest | `567278537d9eb62412e0ed0b50f6ea259d0129a1f527653892f390d2ae616c08` |
| 本文件 | `computed_after_write` |

## 剩余边界与下一合法动作

- 无需项目所有者补充规则歧义；本次仅把已确认规则的迁移与回归证据补完整。
- 既有 1000-seed manifest 未被修改并已重新验证；本次无生产语义变更，因此未重新生成压力样本。
- `full_equivalence_rerun_required: true` 仍是正式迁移阶段要求，不能由本次原型整改视为完成。
- 下一合法动作：由独立 QA 从冻结候选复审本整改及完整正负矩阵，给出 `approved` 或 `revision_required`；之后再由项目经理汇总 GATE-2 状态。
