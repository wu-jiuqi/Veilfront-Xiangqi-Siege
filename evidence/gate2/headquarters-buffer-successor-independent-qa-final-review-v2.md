# GATE-2 大本营缓冲区规则后继独立 QA 最终复审 v2

- 结论：`approved`
- 冻结候选：`main@9447b63e9056e4eddc2a81f8a4d22ba384a8b44a`
- 生产规则实现提交：`7f511f1947d9a9438f7fcef72547b6e839c3f754`
- Contract：`LOOP-CTR-FORMAL-FOUNDATION-GATE2-001@v1`
- QA 身份：`pos:veilfront-xiangqi-siege:quality:qa-release-lead` / `inst:01M02NJ3JFHVZ5C4SP5MTJFJR6`
- 报告 SHA-256：`computed_after_write`，由外部交接绑定以避免自引用

本次从 clean detached worktree 对整改候选重新执行定向审阅。原 QA 的 `HQ-QA-001/002` 均已关闭，生产源码未变化，既有 1000-seed manifest 仍与生产提交匹配。该批准只接受大本营缓冲区 successor 作为后续正式迁移输入，不批准 GATE-2。

## 冻结输入与摘要

`HEAD` 与 `origin/main` 均为 `9447b63e9056e4eddc2a81f8a4d22ba384a8b44a`，验证结束时 detached tracked worktree clean。

| 输入 | SHA-256 |
|---|---|
| 原独立 QA v1 | `a70d360d9c8c54f75eb9550dd606f3a74fcaf029db1767bf6f177868848f92f4` |
| 原技术/体验复审 v1 | `55b62f7849b55ce42df42a06d51dee1d8f7f89c5e36ece341ecd433db418b11a` |
| 整改证据 v1 | `480b9fdf23709b6a960c45dac61213a686a3254030c9f45a2012519e70dc2f0c` |
| 整改后 successor v2 | `58e2ee794d852f09e389263ac33ed374cb5b697e83f8363e8ff5c74e9a0f4068` |
| 整改后 revision 5 测试 | `e2d136b2d218876216caaf0627d68d0f8767550930201d5592167fe2150d82ff` |
| 既有 1000-seed manifest | `567278537d9eb62412e0ed0b50f6ea259d0129a1f527653892f390d2ae616c08` |
| Loop Contract | `a26a9b3fdb0d8d06e42a06833a84455d911fea8f72bcedec59d0ae5e620cc205` |

`7f511f1..9447b63` 的变更仅涉及 successor、审阅/整改证据、审阅指派和 `tests/prototype/test_owner_rule_revision_v5.gd`。`scripts/`、`scenes/`、`resources/` 与 `project.godot` 对该范围执行 `git diff --quiet` 为退出 `0`；规则实现继续由以下未变摘要绑定：

- `scripts/prototype/core/move_rules.gd`：`c3f8c9e3ef377bbacf5e455fe47835ba4f265e585364890d75feb10a4e3746e4`
- `scripts/prototype/view/player_view_projector.gd`：`97b6a37b0c489749185cbc106e0113f9fed33ba04954975ac017997b85f5c75a`

## HQ-QA-001 关闭验证

整改后 `formal_migration_delta.affected_channels` 为：

`state,event,red_player_view,black_player_view,red_visible_event,black_visible_event,visible_error,action_preview,replay`

该集合与历史迁移基线的正式等价命令完全一致，已补齐红黑双方 `VisibleEvent`。successor 的 `supersedes_behavior_binding.scope=rules_input_hashes_only` 保持历史基线 codec binding，因此 `state/event/replay` 继续分别沿用 `full_state/domain_event/authoritative+observer replay` 的既有映射，无需用新定义覆盖历史清单。`full_equivalence_rerun_required` 仍为 `true`，未降低任一观察者通道或零差异标准。

结论：`HQ-QA-001 closed`。

## HQ-QA-002 关闭验证

successor 与实际 revision 5 fixture 均覆盖：

- 四个负例：红/黑双方从战区直入敌营，分别覆盖吃子与空点；
- 四个正例：红/黑双方从敌方缓冲区进入敌营，分别覆盖吃子与空点；
- public staging preview 与 submit 的一致性；
- 路径同时存在未公开敌相田字格时，公开 staging 必须先于隐藏拦截。

负例逐项断言 authoritative reason 为 `enemy_buffer_staging_required`、public preview 为 `KNOWN_ILLEGAL`、submit 返回 `visible_rule_rejection`、不消费行动且棋盘不变。正例逐项断言 authoritative 允许、preview 不得因公开 staging 判为 `KNOWN_ILLEGAL`、submit 完成落点与吃子结算。正例在路径含未探明位置时允许 `TENTATIVE`，符合既有信息边界，不把未知状态错误提升为 `KNOWN_LEGAL`。

隐藏相田用例同时断言：不产生 `elephant_field_intercepted`、preview 保持 `KNOWN_ILLEGAL`、submit 不消费。因此该公开规则不能被隐藏阻挡绕过，也不会泄露隐藏相田来源。

结论：`HQ-QA-002 closed`。

## 独立运行证据

环境：Windows，Godot `4.7.1.stable.official.a13da4feb`，headless Compatibility。

| 命令/检查 | 结果 |
|---|---|
| `validate_project_instance.py --project-root .` | 退出 `0`；项目及 plugin lock 为 `normal`，无 error/warning |
| `D:\Godot\godot.cmd --version` | 退出 `0`；`4.7.1.stable.official.a13da4feb` |
| `D:\Godot\godot.cmd --headless --path . --editor --quit` | 退出 `0`；导入完成，无脚本错误 |
| `... --script res://tests/prototype/run_owner_rule_revision_v5.gd` | 退出 `0`；`OWNER_RULE_REVISION_V5_PASSED` |
| `... --script res://tests/prototype/run_all.gd` | 退出 `0`；`PROTOTYPE_BASIS_CHECKS_PASSED scaffold=9 focused_suites=15 full_gate1=false` |
| `... --script res://tests/prototype/verify_seeded_manifest.gd -- --path res://evidence/prototype/qa/gate2-headquarters-buffer-staging-1000-seeds-round50.jsonl` | 退出 `0`；`records=1000`，digest=`cd73f70f0b5b2db4aa01822f218f1e92a2dc75ed1b404982fde00f52b6925341` |
| 同一 verifier 加 `--force-record-tamper` | 预期退出 `1`；`manifest_count_or_digest_mismatch` |

独立解析 manifest 得到 `1002` 行、`1000` 条记录、`1000` 个唯一 seed，范围 `471001..472000`；completed/failure=`1000/0`，determinism checked/mismatch=`1000/0`，replay sample/verified=`20/20`。本次没有改变生产规则、投影或 RNG，因此无需重新生成该压力样本；正常 verifier 与篡改拒绝足以确认其完整性和继续绑定资格。

## 非阻断项与权限边界

- `git diff --check HEAD^..HEAD` 会在被一并纳入候选的旧 QA v1 第 98 行报告文件末尾空行。单独对整改 successor、revision 5 测试、技术报告与整改证据执行相同检查退出 `0`。该空行不改变摘要、规则、测试或执行证据，列为非阻断证据格式项，不修改历史 QA 文件。
- `full_equivalence_rerun_required: true` 仍是正式迁移阶段的未完成要求；本次通过不把原型回归冒充跨实现等价结果。
- QA 未参与整改生产，未修改规则、实现、测试、successor、Contract、Registry、approval 或旧证据。
- 下一合法动作：项目经理可记录本 successor 的技术与独立 QA 闭环，并将其绑定为 `ITERATION-2-CORE-MIGRATION` 的当前输入；正式迁移仍须按九通道完成全量等价验证。
- 本报告不批准 GATE-2。GATE-2 仍由项目所有者依据完整 Contract 证据与人工体验判断决定。
