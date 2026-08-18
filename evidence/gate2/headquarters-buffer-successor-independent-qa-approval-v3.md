# 大本营缓冲区 successor 纯映射独立 QA 批准 v3

- 结论：`approved`
- 冻结候选：`main@3144a0a0e260603fe1ae38891e5c3006b251ee7c`
- 生产规则实现提交：`7f511f1947d9a9438f7fcef72547b6e839c3f754`
- Contract：`LOOP-CTR-FORMAL-FOUNDATION-GATE2-001@v1`
- QA 身份：`pos:veilfront-xiangqi-siege:quality:qa-release-lead` / `inst:01M02NJ3JFHVZ5C4SP5MTJFJR6`
- 报告 SHA-256：`computed_after_write`，由外部交接绑定以避免自引用

本次只复核 `channel_mapping` 与生产 Git blob，不重跑规则、聚合或 1000-seed simulation。前一份独立 QA v2 的功能、矩阵、manifest 正常/篡改证据继续有效；本批准只关闭最后的通道简写映射问题，不批准 GATE-2。

## 冻结与输入绑定

验证在 clean detached worktree 执行。`HEAD` 与 `origin/main` 均为 `3144a0a0e260603fe1ae38891e5c3006b251ee7c`，验证结束时 tracked worktree clean。

| 输入 | SHA-256 |
|---|---|
| successor v2 | `f6b07d8cbdc7db4492c33e8b4b028aca2906cccc8baf5921273aaa012d48e19b` |
| 历史 migration manifest | `0502e20a861a550e9845cfa1a10e4b5d94b97d1da884add2d0de70e9fa14daa4` |
| 通道映射整改 v2 | `1cb8a49e7ca963bbfcdb4760fd5227e8fbd1af2dea7467a3fab0afe593b10719` |
| 技术最终复审 v2 | `91d2c2a8b2ee14179486a54e600f047f59eae3d67f734b3b3bb14fd4c6e7339d` |
| 独立 QA approved v2 | `ac4ce00b11b12369314bf387c9d6898cdaf5c734949522bba64bcbd9278cb6a0` |
| 1000-seed manifest | `567278537d9eb62412e0ed0b50f6ea259d0129a1f527653892f390d2ae616c08` |
| Loop Contract | `a26a9b3fdb0d8d06e42a06833a84455d911fea8f72bcedec59d0ae5e620cc205` |

项目实例 validator 退出 `0`，项目和 plugin lock 状态均为 `normal`，无 error/warning。

## Channel mapping 复核

successor YAML 可解析，`affected_channels` 与 `channel_mapping` 均恰有九个同名入口。独立断言得到：

| successor alias | 正式合同映射 | 观察者/说明 |
|---|---|---|
| `state` | `full_state` | 每个已消费行动后的 canonical state |
| `event` | `domain_event` | 每个已消费行动后的有序 canonical events |
| `red_player_view` | `player_view` | `red` |
| `black_player_view` | `player_view` | `black` |
| `red_visible_event` | `visible_event` | `red` |
| `black_visible_event` | `visible_event` | `black` |
| `visible_error` | `visible_error` | 公开 code/payload |
| `action_preview` | `action_preview` | canonical order |
| `replay` | `authoritative_replay` + `observer_replay` | 权威最终状态/事件与实时安全 DTO 帧 |

`supersedes_behavior_binding.scope` 仍为 `rules_input_hashes_only`，并精确绑定历史 manifest SHA `0502e20a...14daa4`。因此该表只消除 alias 歧义，不替换历史 manifest 中更严格的 codec、canonical bytes、隐藏等价、deny-list 与零差异比较定义。`full_equivalence_rerun_required` 保持 `true`，`gate2_approval_implied` 保持 `false`。

映射结构断言输出 `MAPPING_VALID`，退出 `0`。最后未关闭的 `HQ-SUCCESSOR-001 / HQ-QA-001` 映射条件现已满足。

## 生产 blob 与既有证据复用

`7f511f1` 与本候选的 Git blob 完全相同：

| 生产文件 | 两端 Git blob |
|---|---|
| `scripts/prototype/core/move_rules.gd` | `3eeb8102ef68d782c1ffada98be397c11e0d5403` |
| `scripts/prototype/core/rule_engine.gd` | `d2c918d86263df2c4c12d298f62e27766e7a05b0` |
| `scripts/prototype/view/player_view_projector.gd` | `12349bc781dec2070300e31af5f3291ad5a1fc01` |

整个 `scripts/prototype` tree 在两端均为 `cffc2c4721bdb17f1b51af45ed4aad63237a83a2`。revision 5 fixture 相对已批准候选 `9447b63` 的 blob 也未变化：`0a29828bdeb2575bd01059fe5d060e4db566f774`。

因此本提交只增加文档映射与证据，不触及规则、投影、随机消费或测试语义。独立 QA v2 已记录：revision 5 与聚合回归退出 `0`；manifest 正常 verifier 退出 `0`、`records=1000`、records digest=`cd73f70f0b5b2db4aa01822f218f1e92a2dc75ed1b404982fde00f52b6925341`；强制篡改按预期退出 `1`、`manifest_count_or_digest_mismatch`。本候选的 v2 报告与 manifest 摘要均未变化，故按本次纯映射范围直接复用，不重跑 1000 simulation。

## 格式、权限与下一动作

- `git diff --check HEAD^..HEAD` 退出 `0`。
- QA 未修改 successor、生产、测试、Contract、Registry、approval 或旧证据；唯一新增产物是本报告。
- 项目经理可以把该 successor 作为 `ITERATION-2-CORE-MIGRATION` 当前规则后继输入；正式迁移仍须按历史基线定义的九通道完成全量等价验证。
- 本报告不批准 GATE-2。GATE-2 仍由项目所有者依据完整 Contract 证据与人工体验判断决定。
