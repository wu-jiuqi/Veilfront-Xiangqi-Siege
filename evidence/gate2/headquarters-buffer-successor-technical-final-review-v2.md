# GATE-2 大本营缓冲区规则后继技术最终复审 v2

- 结论：`revision_required`
- 冻结候选：`main@9447b63e9056e4eddc2a81f8a4d22ba384a8b44a`
- 受审生产提交：`7f511f1947d9a9438f7fcef72547b6e839c3f754`
- Contract：`LOOP-CTR-FORMAL-FOUNDATION-GATE2-001@v1`
- 复审身份：`pos:veilfront-xiangqi-siege:design-experience:systems-experience-lead` / `inst:01M02NJ3JENHD8VV7EKC9G198Q0`
- 报告 SHA-256：`computed_after_write`，由外部交接绑定以避免自引用

候选的规则生产逻辑未变化，完整定向矩阵、聚合回归和 manifest 正常/篡改校验均通过；`HQ-SUCCESSOR-002` 已关闭，`HQ-SUCCESSOR-001` 的双方 VisibleEvent 缺项已补，但原关闭条件要求的 `state/event/replay` 显式语义映射仍未写入 successor。因此本次技术最终复审不能批准该 successor 作为正式迁移输入。本结论不否定生产规则，也不代替独立 QA 或 GATE-2 人工决定。

## 输入与摘要绑定

| 输入 | SHA-256 / Git blob |
|---|---|
| successor | `58e2ee794d852f09e389263ac33ed374cb5b697e83f8363e8ff5c74e9a0f4068` |
| revision 5 fixture | `e2d136b2d218876216caaf0627d68d0f8767550930201d5592167fe2150d82ff` |
| 整改证据 | `480b9fdf23709b6a960c45dac61213a686a3254030c9f45a2012519e70dc2f0c` |
| 原技术复审 | `55b62f7849b55ce42df42a06d51dee1d8f7f89c5e36ece341ecd433db418b11a` |
| 原独立 QA 审阅 | `a70d360d9c8c54f75eb9550dd606f3a74fcaf029db1767bf6f177868848f92f4` |
| 既有 1000-seed manifest | `567278537d9eb62412e0ed0b50f6ea259d0129a1f527653892f390d2ae616c08` |
| `move_rules.gd` | SHA-256 `c3f8c9e3...746e4`；`7f511f1` 与 `HEAD` Git blob 均为 `3eeb8102ef68d782c1ffada98be397c11e0d5403` |
| `rule_engine.gd` | SHA-256 `f2e791a9...204`；`7f511f1` 与 `HEAD` Git blob 均为 `d2c918d86263df2c4c12d298f62e27766e7a05b0` |
| `player_view_projector.gd` | SHA-256 `97b6a37b...75a`；`7f511f1` 与 `HEAD` Git blob 均为 `12349bc781dec2070300e31af5f3291ad5a1fc01` |

项目实例 validator 退出 `0`、插件锁状态为 `normal`，`HEAD` 与 `origin/main` 均为精确冻结候选。候选相对 `95c0c9d` 只修改 successor 与 revision 5 fixture，并加入整改/复审证据；相对 `7f511f1` 的上述三份原型规则生产文件无差异。

## 自动验证

环境：Godot `4.7.1.stable.official.a13da4feb`，Windows，headless Compatibility。

| 检查 | 结果 |
|---|---|
| successor YAML 解析与矩阵计数 | `channels=9 negative=4 positive=4 consistency=2` |
| `... --script res://tests/prototype/run_owner_rule_revision_v5.gd` | 退出 `0`，`OWNER_RULE_REVISION_V5_PASSED` |
| `... --script res://tests/prototype/run_move_rules.gd` | 退出 `0`，`MOVE_RULES_SUITE_PASSED` |
| `... --script res://tests/prototype/run_owner_rule_revision_v4.gd` | 退出 `0`，`OWNER_RULE_REVISION_V4_PASSED` |
| `... --script res://tests/prototype/run_all.gd` | 退出 `0`，`PROTOTYPE_BASIS_CHECKS_PASSED scaffold=9 focused_suites=15 full_gate1=false` |
| manifest verifier 正常路径 | 退出 `0`，`SEEDED_MANIFEST_VERIFIED records=1000`，records digest=`cd73f70f...25341` |
| manifest verifier `--force-record-tamper` | 预期退出 `1`，`manifest_count_or_digest_mismatch` |
| 当前 tracked worktree `git diff --check` | 通过 |

`git diff --check 95c0c9d..9447b63` 仅报告原独立 QA 报告末尾多余空行；该格式问题不涉及 successor、测试、摘要或生产逻辑，列为非阻断观察。

## 缺陷关闭复核

### `HQ-SUCCESSOR-002`：已关闭

successor 已明确列出红黑双方的四个战区直入负例、四个缓冲区前置正例，并增加 preview/submit 资格一致与公开 staging 优先隐藏相田的检查。

revision 5 fixture 逐项执行：

1. 红/黑 × 敌方大本营敌子/空点的四个负例；每例都直接断言 authoritative reason 为 `enemy_buffer_staging_required`、public preview 为 `KNOWN_ILLEGAL`、submit 不消费且棋盘不变。
2. 红/黑 × 从敌方缓冲区进入敌营敌子/空点的四个正例；每例都断言 authoritative legal、preview 非 `KNOWN_ILLEGAL`，以及 submit 后最终位置和伤亡正确。路径仍含未探明位置时保留 `TENTATIVE` 符合既有信息边界，不是公开资格冲突。
3. 红车战区直指黑营且路径穿过隐藏黑相田字格的重叠负例；断言公开 staging 先返回、preview 仍为 `KNOWN_ILLEGAL`、submit 不消费，且未先产生 `elephant_field_intercepted`。

定向套件、聚合回归与 manifest 正常/篡改验证全部通过，生产实现和随机消费未改，因此既有 1000-seed manifest 可以继续绑定。

### `HQ-SUCCESSOR-001`：部分关闭，仍阻断

successor 的 `affected_channels` 已从七项补为九项，新增：

- `red_visible_event`
- `black_visible_event`

但原技术复审与独立 QA 的关闭条件不仅要求补两项，还要求 successor 明确：

- `state` 对应历史迁移基线的 `full_state`；
- `event` 对应 `domain_event`；
- `replay` 同时覆盖 authoritative replay 与 observer replay。

当前 successor 仍只列出未定义的简写 `state`、`event`、`replay`。被其引用的历史基线确实保存了完整 codec 与 comparison 定义，因此不存在当下玩法歧义；但 successor 作为 Iteration 2 的后继迁移输入，尚未把三项简写与基线精确通道建立显式绑定。若现在批准，会在原关闭条件未完全满足的情况下静默放宽验收标准。

## 返回路径与下一合法动作

返回 successor 生产者做一次纯文档最小修订：在 `formal_migration_delta` 中增加不可歧义的 channel mapping，或直接使用历史基线的精确通道名称，并明确 replay 包含 authoritative 与 observer 两类比较；保留九通道、完整矩阵和 `full_equivalence_rerun_required: true`。

该修订不需要改生产代码或测试语义，也不需要重新生成 1000-seed manifest；但 successor 摘要变化后必须更新整改证据绑定，形成新的冻结候选，再进行技术与独立 QA 定向复审。两份复审均通过前，不得把该 successor 绑定为 `ITERATION-2-CORE-MIGRATION` 输入；本报告不批准 GATE-2。
