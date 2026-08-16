# Iteration 2 三档 AI 证据口径澄清附录

- QA Instance：`inst:01M02NJ3JFHVZ5C4SP5MTJFJR6`
- 原受测代码提交：`e5963e229c05557d668316531779e406cc9e801d`
- 原独立 QA 证据提交：`5bbb38a09fc90456c605b0034957e4216f53f16b`
- 规格澄清提交 / 当前 HEAD：`002bff459c0d13135d9be8d0a68d2f6ac2193f5a`
- 澄清规格：`docs/prototype/iteration2-playtest-graybox-spec.md`
- 规格 Git blob：`d3b33443db39b72e5c043f5f9bbb3dd01f296147`
- 规格文件 SHA-256：`d266bf50b339bf448e5eb05ce6566295af7703d67ddd3c02400010f3d817bab0`
- Loop：`active / Iteration 2 / revision 38 / sequence 38`

## 增量复核结论

`spec_scope_blocker_2=resolved_by_002bff4`。

规格提交 `002bff4` 已明确关闭原独立 QA 报告中的第二项口径歧义：

- A 是同一组 100 固定 seed × easy/medium/hard 的 `300` 条 PlayerView AI **单决策**公平/差异 records；它不推进完整对局，不报告或推断胜负、胜因、完整轮数或局长。
- B 是同一组 100 固定 seed 的 `100` 局、50 回合上限 `rules_stress_full_state_policy` **完整规则压力对局**；它报告合法终止、胜负、胜因、局长、确定性与重放，但不冒充三档 PlayerView AI 公平性或强度证据。
- 人工试玩负责完整“人类 vs AI”体验，每档至少完成可形成有效反馈的一局；本轮不新增“三档各 100 局完整对局”的自动数量门槛。
- A、B 与人工试玩三者互补，不得互相替代，不得把 300 records、100 场规则压力或两者相加冒充 1000 seeds。

因此，`e5963e2` 上已独立执行并提交于 `5bbb38a` 的原始证据与澄清后规格准确对应：

- A：`iteration-2-ai-difficulty-seed-matrix-100x3.jsonl`，300 records，四类失败与确定性/隐藏等价差异均为 0，实际预算为 8/32/96。
- B：`iteration-2-rules-stress-100-seeds-round50.jsonl`，100/100 完成，失败 0、确定性差异 0、回放 10/10。
- 原执行证据无需重复耗时矩阵；本附录不改变其受测代码绑定、records digest 或 manifest SHA-256。

`playable_graybox_ready_for_owner_playtest=yes_with_scope_limit`。

项目所有者可以开始人工试玩，并分别对简单/中等/困难至少完成一局可形成有效反馈的完整人类对局。该结论只表示试玩版具备收集人工体验证据的条件，不表示 GATE-1 通过。

## 只读完整性观察

| 检查 | 退出码 | 结果 |
|---|---:|---|
| `git merge-base --is-ancestor e5963e2 5bbb38a` | 0 | QA 证据提交基于原受测代码提交 |
| `git merge-base --is-ancestor 5bbb38a 002bff4` | 0 | 规格澄清提交基于 QA 证据提交 |
| `git diff --exit-code e5963e2..002bff4 -- project.godot scripts scenes tests resources game-pipeline` | 0 | 原受测代码、测试、资源、Contract 与 Registry 均未变化 |
| `git diff --name-status 5bbb38a..002bff4` | 0 | 只有 `docs/prototype/iteration2-playtest-graybox-spec.md` 被修改 |
| `validate_project_instance.py --project-root .` | 0 | `state=normal`；插件与框架摘要匹配；无 errors/warnings |
| `iteration2_playtest.py verify-active` | 0 | `active / iteration 2 / revision 38 / sequence 38`；尾摘要仍为 `fbc96e54...af97` |

未变化的治理文件摘要：

- Contract v2 文件 SHA-256：`5a9ed8f5854865adfecbcff808f8dc96af52abecb371dbd18bb8fd137a775e62`
- Loop Snapshot SHA-256：`c41c1ee1025d9f19a76adee1a980aad1d63d2cb65fda1827683788abb7d65337`
- Event History SHA-256：`4f28ea0899b9644f2abaa85f143df3739dfc265fc8d08314727d14842ff7f35f`

规格澄清没有修改代码、测试、Contract、QA-P1-003、Registry 或 GATE 权限，因此本次只读增量复核复用 `5bbb38a` 中绑定 `e5963e2` 的原始执行证据，没有重跑 Godot、100×3 矩阵或 100 局规则压力。

## 仍然存在的唯一状态转换阻断

`contract_review_transition=blocked_by_1000_seed_requirement`。

Contract v2 `CHECK-SIMULATION-001` 与 QA-P1-003 仍明确要求 `1000/1000`；规格澄清明确没有改变这一门槛。当前证据只覆盖试玩版的同一组 100 固定 seeds，因此：

- Loop 必须保持 `active / Iteration 2`；
- 不得推荐或执行 `active -> review`；
- 不得重建可提交的 GATE-1 决策包；
- 官方 CLI 仍沿用原独立证据记录为 `failed / exit 1 / 恰好六项批准错误`，不得写为通过；
- `GATE-1=not_made`，正式功能与资产生产仍为 `forbidden`。

若要重新评估进入 `review`，仍须在当前 Contract v2 下补足 1000/1000 与全部 QA-P1-003 条件，或由项目所有者另行批准 Contract 修订并完成追加迁移、回归和新的独立 QA。

## 对原报告的解释范围

本附录不修改 `iteration-2-independent-review.md`。它仅以规格提交 `002bff4` 关闭该报告的第二项“是否要求三档各 100 局完整终局”的待澄清事项；原报告关于 1000 seeds、官方 CLI、50 回合高比例轮限平局、Import warning、hypothesis 边界、人工 Gate 与正式生产边界的其他事实和风险继续有效。
