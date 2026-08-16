# Iteration 2 三档 AI 灰盒独立 QA 复检

- 执行时间：2026-08-16（Asia/Shanghai）
- QA Instance：`inst:01M02NJ3JFHVZ5C4SP5MTJFJR6`
- 受测提交：`e5963e229c05557d668316531779e406cc9e801d`
- Loop：`active / Iteration 2 / revision 38 / sequence 38`
- Contract：`LOOP-CTR-GATE1-VERTICAL-SLICE-001 v2`
- Contract subject digest：`7b7fcf36920109d379aa0e230cf70a378ed7ec228ff6a88bccf35cf481fcf09c`
- GATE-1 revise subject digest：`b67377e497d847aed0ae61759ba590be7229141a89829906981ffdd2796a4c3b`
- 官方 CLI：`failed / exit 1 / 恰好六项批准错误`

## Verdict

`playable_graybox_ready_for_owner_playtest=yes_with_scope_limit`。

当前提交的灰盒入口、三档选择、单步 AI、公平性边界、固定 seed 复现和 100-seed 试玩回归证据足以支持项目所有者开始探索性人工试玩。该结论只说明“可以试玩并收集体验反馈”，不表示 Iteration 2 Contract 全部验收，也不表示 GATE-1 通过。

`contract_review_transition=blocked`。

Loop 必须保持 `active / Iteration 2`，不得推荐或执行 `active -> review`，不得重建可提交的 GATE-1 决策包，原因有两项：

1. Contract v2 `CHECK-SIMULATION-001` 与 QA-P1-003 仍明确要求 `1000/1000`；本轮仅按项目所有者最新试玩版要求执行 `100/100`，未满足合同门槛。
2. `run_ai_difficulty_seed_matrix.gd` 是每 seed/档一次决策的 PlayerView AI 公平矩阵，不是三档各 100 局完整终局。更新规格第 7/11 节对“胜负/胜因/局长”“均完成一局”的文字可能被理解为要求 100×3 完整终局统计；当前证据不能声明这部分已满足，需由规格所有者明确口径或补充完整三档对局 runner。

`GATE-1=not_made`；项目所有者本轮人工试玩不等于 Gate 批准。正式功能、正式 UI、美术、音频、动画与资产生产仍为 `forbidden`。

## Observed facts

### 治理、Contract 与 Registry

| 检查 | 退出码 | 观察结果 |
|---|---:|---|
| 项目实例 | 0 | `state=normal`；插件锁与框架摘要匹配；`errors=[]`、`warnings=[]` |
| Pipeline Contract | 0 | `CTR-P1-001` 校验 `OK` |
| Organization Registry | 0 | Snapshot 与 Event History 重放一致；QA 正式实例保持 `active` 且与生产实例不同 |
| 未修改 `validate_history()` | 0 | validator SHA-256 `90804f...9633`；`history_error_count=0` |
| rev38 链 | 0 | `active / iteration 2 / revision 38 / sequence 38`；尾摘要 `fbc96e...af97`；rev30 前缀保持通过 |
| 官方 Loop CLI | 1 | **failed**；错误集合恰好为批准的六项，没有第七项 |

官方 CLI 六项原始逻辑错误为：

1. `Snapshot 模板初始状态必须等于状态机 initial_state`
2. `Snapshot 模板 current_iteration 必须从 0 开始`
3. `注册后的 Snapshot 模板必须位于 sequence=1、record_revision=1`
4. `draft 注册基线的 inputs 和 outputs 必须为空`
5. `Snapshot input_slot_id 必须完整对应 Contract required_inputs`
6. `Snapshot deliverable_id 必须完整对应 Contract required_deliverables`

官方 CLI 仍记录为 `failed`；本报告没有将其改写为通过。QA-P1-003 仍是 `owner-approved tooling exception / controlled_temporary_exception_until_official_plugin_fix`。由于当前提交没有执行 1000/1000，本轮不能重新认定其所有进入 review 的条件已满足。

### Godot 4.7.1 与灰盒

| 检查 | 退出码 | 观察结果 |
|---|---:|---|
| 引擎版本 | 0 | `4.7.1.stable.official.a13da4feb` |
| Import/editor | 0 | 扫描完成；记录四个缺失 UID 重建提示及短退 `Scan thread aborted` warning；没有解析/资源 ERROR；自动 sidecar 已清理 |
| 主场景 | 0 | 216 格、默认 50、`hypothesis_cli_overridable` |
| `run_playtest_graybox.gd` | 0 | 人类移动、AI 单步、跳过、炮击、重开、三档 profile、审计隔离全部通过 |
| `run_all.gd` | 0 | 11 个规则/迷雾/回放/AI 套件通过；输出仍为 `full_gate1=false` |

静态和运行时泄漏观察：

- UI 脚本禁用字段命中数为 `0`；未引用 `MatchState`、`FullState`、受控 audit getter 或 audit 内部字段。
- 玩家事件日志只读取 `player_view.player_events`。
- 三档 AI 共用 PlayerView 白名单和公开候选权限；难度只改变 hypothesis profile。
- audit 测试 getter 返回深复制，audit 未进入 human PlayerView、UI 文本或玩家事件日志。

### 三档 PlayerView AI 单决策矩阵

同一组 seed `471001..471100` 分别执行 easy/medium/hard，共 `300` 条 profile-record：

| 项 | 结果 |
|---|---:|
| records | 300 |
| failures | 0 |
| determinism mismatches | 0 |
| hidden-equivalence mismatches | 0 |
| action-id mapping failures | 0 |
| submit failures | 0 |
| easy 实际评估 | 8 / 8 / 8（min/avg/max） |
| medium 实际评估 | 32 / 32 / 32 |
| hard 实际评估 | 96 / 96 / 96 |
| easy vs medium 动作不同 seed | 84 |
| medium vs hard 动作不同 seed | 86 |
| easy vs hard 动作不同 seed | 92 |

- records digest：`a5d4f6235a8652cd86eb7d303f568a50409a8b83f07e600fc4da275073f9e02a`
- manifest SHA-256：`ed54d426ad22bf6332c513dec78ec3bfdfb7becd85ebd9dd2ee2e566a00bfefa`
- 口径：这是单决策公平矩阵，不是完整对局；不能从中报告三档胜率、胜因或局长。

### 50 回合、100 seed 完整规则压力

| 项 | 结果 |
|---|---:|
| completed | 100/100 |
| failures | 0 |
| determinism mismatches | 0 |
| replay | 10/10 |
| red / black / draw | 6 / 6 / 88 |
| round-limit flags / draw | 12 / 88 |
| rounds min/p50/p90/p95/max | 50 / 50 / 50 / 50 / 50 |

- records digest：`68c6a92f7fad4091b0e5353a04fa08b3617950dad3958cdcbff754546f85b2e8`
- manifest SHA-256：`b958d68191134a8a5c02122f8028a9417b67675dced1de5a905a176c3ac1ee18`
- 口径：`rules_stress_full_state_policy` 只证明规则终止、不变量、确定性和抽样回放；不作为三档 AI 公平或完整对局体验证据。

## Inferences

- 三档的预算与动作分布确实产生了可观察差异，且没有观察到通过额外隐藏信息制造差异。
- 当前灰盒足以开始人工判断操作可理解性、AI 公平感和 50 回合体感。
- `88/100` 规则压力局以轮限平局结束，说明 50 回合并未自动消除低进展风险；该结果是人工试玩重点，不是由 QA 冻结新回合数的依据。

## Unresolved risks / blockers

1. Contract v2 的 `1000/1000` 未执行，因此 `active -> review` 的必要自动门槛明确未满足。
2. 三档 AI 的批量证据只覆盖一次决策；是否必须补齐三档完整对局胜负/胜因/局长统计，规格文字需要明确。
3. 50 回合规则压力仍有 88% 轮限平局；需由项目所有者人工试玩判断这是策略深度、AI 策略不足还是回合值仍不合理。
4. Import 短退 warning 仍存在；本轮退出码 0 且无解析/资源 ERROR，但不得表述为“无 warning”。
5. 50 回合与三档预算/扰动仍是 `hypothesis`，未被冻结为正式平衡结论。

## Next legal action

项目所有者可以开始人工试玩，并按 seed、档位和可见证据记录体验反馈。Loop 与 Registry 不变，继续保持 `active / Iteration 2 / rev38`。

若要进入 `review`，必须先选择并完成合法前置：

- 在当前 Contract v2 下补足 `1000/1000` 及全部 QA-P1-003 条件，并解决三档完整对局口径；或
- 由项目所有者另行批准 Contract 修订，完成绑定新 Contract 的追加迁移、全量回归与新的独立 QA。

任何路径都不能由 QA 自动批准 GATE-1；GATE-1 仍须项目所有者在完整决策包上单独决定。

## Evidence index

- `evidence/prototype/qa/iteration-2-command-output.txt`
- `evidence/prototype/qa/iteration-2-ai-difficulty-seed-matrix-100x3.jsonl`
- `evidence/prototype/qa/iteration-2-ai-difficulty-seed-matrix-summary.json`
- `evidence/prototype/qa/iteration-2-rules-stress-100-seeds-round50.jsonl`
- `evidence/prototype/qa/iteration-2-rules-stress-100-seeds-round50-summary.json`
