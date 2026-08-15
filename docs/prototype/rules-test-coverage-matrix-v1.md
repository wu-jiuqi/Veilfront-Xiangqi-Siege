# 规则—测试覆盖矩阵 v1

状态：`prototype / iteration 1 / revision 3 coverage audit`。本文件只建立冻结规格到测试的追溯，不改变规则、不验收实现，也不替代独立 QA 或 GATE-1。

## 1. 审计基线与判读

- 规则基线：`rules-spec-v1.md`、`settlement-order-v1.md`、`information-boundary-v1.md`，均为 `owner-freeze revision 2`；区域轰炸最终裁决为 `OWNER-CONFIRM-2026-08-15:BOMBARD-NO-COOLDOWN`。
- 验收基线：`gate1-observation-plan-v1.md`、`CTR-P1-001 v1`、`LOOP-CTR-GATE1-VERTICAL-SLICE-001 v1`。
- 运行证据：`evidence/prototype/qa/iteration-1-revision-2-review.md` 与 `iteration-1-revision-2-command-output.txt`，审查 HEAD `c7fd75d84d171cfbe0943901cd3cd3b5c70d89e9`。
- Revision 2 的 `run_all.gd` 明示 `focused_suites=5 full_gate1=false`。因此下表的 `PASS-R2` 仅表示对应定向断言通过；`PARTIAL-R2` 表示只覆盖该需求的一部分；`PENDING` 表示必须新增自动测试；`BLOCKED-MISSING` 表示 Contract 要求的执行入口不存在。
- 下表 Test ID 是稳定追溯 ID。已有测试同时列出实际文件/函数；待新增 ID 只定义验收目标，不授权修改玩法或选择开放参数。

## 2. 棋盘、开局与传统移动几何

| Requirement ID | 冻结行为 | Test ID / 实际证据 | 状态 |
|---|---|---|---|
| GEO-BOARD-001 | `9x24=216`；红视角坐标；五/三/八/三/五区域、墙线、九宫边界精确 | `RULE-INIT-001`; `test_match_state.gd::run_suite` 只覆盖 216、红先和代表棋位；`PENDING-GEO-BOARD-001` 覆盖全部边界 | PARTIAL-R2 |
| GEO-SETUP-001 | 32 枚传统对称阵型全部坐标准确，红固定先手，几何中线没有河界语义 | `RULE-INIT-001`; `test_match_state.gd::run_suite`; `PENDING-GEO-SETUP-ALL-001` 逐枚核对 | PARTIAL-R2 |
| GEO-GENERAL-001 | 将/帅每次仅沿四正交方向 1 格且终点在己方九宫；可进入攻击范围；无将军/应将/将死/照面/飞将限制 | `PENDING-GEO-GENERAL-001` | PENDING |
| GEO-ADVISOR-001 | 士每次仅沿四对角方向 1 格且终点在己方九宫 | `PENDING-GEO-ADVISOR-001` | PENDING |
| GEO-HORSE-001 | 马目标位移仅为 `(±2,±1)/(±1,±2)`；默认规则检查对应马腿；不受河界/半场限制 | `PENDING-GEO-HORSE-001` | PENDING |
| GEO-ELEPHANT-001 | 相/象目标位移仅为 `(±2,±2)`；默认规则检查中点象眼；可跨几何中线、全棋盘行动 | `PENDING-GEO-ELEPHANT-001` | PENDING |
| GEO-ROOK-001 | 默认车仅同列/同行任意正距离；中间格必须空；空终点移动、敌终点吃子、己终点非法 | `PENDING-GEO-ROOK-001` | PENDING |
| GEO-CANNON-001 | 炮非吃子移动同默认车且路径空；精确吃子必须同线、恰一炮架并移动到可见敌目标格 | `INFO-CANNON-001` 只覆盖投影意图；`PENDING-GEO-CANNON-MOVE-001`; `PENDING-GEO-CANNON-CAPTURE-001` | PENDING |
| GEO-PAWN-001 | 兵/卒始终按已过河：只可前、左、右 1 格，可吃敌终点，不可后退，不受河界阶段影响 | `PENDING-GEO-PAWN-001` | PENDING |
| GEO-COMMON-001 | 任意普通移动：不能落在己棋格；允许规则本身支持的敌终点吃子；越界、零位移、非本方棋非法 | `PENDING-GEO-COMMON-001` | PENDING |

追溯：`rules-spec-v1.md §1, §3`；`stmt:veilfront-xiangqi-siege:board-and-fog`、`general-capture-rules`、`pawn-rules`。

## 3. 项目特殊规则与状态机

| Requirement ID | 冻结行为 | Test ID / 实际证据 | 状态 |
|---|---|---|---|
| SPC-QUALIFY-001 | 除炮击外，特殊行动要求敌墙 `INTACT` 且起点/全部经过格/终点均在 `Y=6..19`；边界外回默认规则 | `PENDING-SPC-QUALIFY-001`（覆盖 `5/6,8/9,16/17,19/20` 与三种墙状态） | PENDING |
| SPC-HORSE-001 | 合资格马无视马腿并在行动后隐身；处于任一有效显形区时显形，离开全部显形区且无其他批准原因时重新隐身；敌墙倒塌/默认区恢复马腿限制及移除特殊能力 | `PENDING-SPC-HORSE-001`; `PENDING-SPC-HORSE-REHIDE-001` | PENDING |
| SPC-ELEPHANT-001 | 合资格相/象无视象眼并刷新该棋独立田字显形区；该棋旧区失效，多源并集仍有效；敌墙倒塌移除能力。简报/冻结附件未定义显形区的精确格集合 | `PENDING-OWNER-ELEPHANT-REVEAL-CELLS`（先裁决格集合）；裁决后 `PENDING-SPC-ELEPHANT-001` | PENDING-OWNER |
| SPC-ROOK-001 | 特殊车可穿敌不可穿己；按路径顺序逐目标；逐目标替死；将帅实际死亡立即停止；路径视野持续到该车下次移动开始 | `PENDING-SPC-ROOK-PATH-001`; `PENDING-SPC-ROOK-VISION-001` | PENDING |
| SPC-PAWN-001 | 特殊兵/卒可横纵 1..5 格；可穿一个或多个敌棋、不可穿己棋、终点空；穿越不伤害 | `PENDING-SPC-PAWN-001` | PENDING |
| SPC-BOMB-ELIG-001 | 区域轰炸资格且仅有敌墙 `INTACT`、炮在己方大本营、该炮有弹药；中心完整 `3x3` 位于 `Y=6..19` | `RULE-CANNON-ORIGIN-001`; `test_rules_core.gd::_test_bombardment_origin_and_no_cooldown`; `PENDING-SPC-BOMB-CENTER-001` | PARTIAL-R2 |
| SPC-BOMB-NOCD-001 | 每炮初始两发、只减不增；无阵营共享冷却字段/计时/重置，前次轰炸不锁另一炮或后续资格 | `RULE-CANNON-COOLDOWN-001`; `test_match_state.gd::run_suite`; `test_rules_core.gd::_test_bombardment_origin_and_no_cooldown`; 尚需 `PENDING-SPC-BOMB-NOCD-CROSS-CANNON-001` 与 `PENDING-INFO-NOCD-FIELDS-001` | PARTIAL-R2 |
| SPC-BOMB-WINDOW-001 | 锁定三个不同格和前快照；三格逻辑同步、动画顺序无语义；允许友伤；落点编号仅排替死 | `RULE-BOMB-001`; `test_replay.gd::run_suite` 覆盖三抽样；`test_rules_core.gd::_test_bombardment_rescue_uses_impact_order_and_excludes_hit_advisor`; `PENDING-SPC-BOMB-SNAPSHOT-001` | PARTIAL-R2 |
| WALL-COLLAPSE-001 | 双方墙独立；完整墙阻止敌棋从缓冲区入营；己方缓冲区同时至少 3 敌棋时该墙倒塌 | `PENDING-WALL-INDEPENDENT-001`; `PENDING-WALL-COLLAPSE-001`; `PENDING-WALL-BLOCK-001` | PENDING |
| WALL-REPAIR-001 | 行动后 `<3` 启动且触发行动不计；之后双方各行动一次；中途 `>=3` 清零；`REPAIRING` 仍按倒塌；完成才恢复 | `RULE-WALL-001`; `test_rules_core.gd::_test_wall_repair_counts_actions_after_trigger`; `PENDING-WALL-CANCEL-001`; `PENDING-WALL-SEMANTICS-001` | PARTIAL-R2 |
| WALL-RETURN-001 | 恢复只撤回守方大本营入侵者；缓冲区不撤；随机唯一分配各自大本营空格；清临时状态、不回资源、不罚行动 | `PENDING-WALL-RETURN-001` | PENDING |
| FLAG-SPAWN-001 | 等概率选 `Y=11..13` 或 `12..14` 三行带，抽三个不同格，公开且不要求镜像 | `test_match_state.gd::run_suite` 覆盖范围/唯一/确定性；`PENDING-FLAG-SPAWN-DISTRIBUTION-001` 仅统计等概率，不设平衡阈值 | PARTIAL-R2 |
| FLAG-CAPTURE-001 | 具体棋从 `0/3` 开始；每次敌方行动机会含三类跳过加 1；第三次行动先结算死亡/离位；换子不继承 | `RULE-FLAG-001/002`; `test_rules_core.gd::_test_flag_lifecycle`; `_test_flag_third_opportunity_resolves_death_first`; `PENDING-FLAG-SKIP-TYPES-001`; `PENDING-FLAG-SWAP-001` | PARTIAL-R2 |
| FLAG-OWNER-001 | 完成后永久持有；敌重占期间原所有权保持、`contested=true`；中断恢复安全；争夺旗轮上限计原方但不计即时三旗 | `RULE-FLAG-003`; `test_rules_core.gd::_test_flag_lifecycle`; `PENDING-FLAG-TRANSFER-001`; `PENDING-FLAG-CONTEST-SCORING-001` | PARTIAL-R2 |
| RESCUE-001 | 每方最先两次合资格非将帅/非士阵亡事件；随机移除存活未消费士；无士正常死亡；永久资源不恢复 | 炮击子集：`test_rules_core.gd::_test_bombardment_rescue_uses_impact_order_and_excludes_hit_advisor`; `PENDING-RESCUE-QUOTA-001`; `PENDING-RESCUE-NO-ADVISOR-001`; `PENDING-RESCUE-RESOURCE-001` | PARTIAL-R2 |
| RESERVE-001 | 无空格则 FIFO 后备；不在场/不可交互/无视野；己方行动开始前随机部署，不耗行动且可立即选择 | `RULE-RESERVE-001`; `test_rules_core.gd::_test_reserve_queue_and_free_deployment`; `PENDING-RESERVE-NONINTERACTION-001`; `PENDING-RESERVE-FIFO-MULTI-001` | PARTIAL-R2 |

追溯：`rules-spec-v1.md §4-§8`；`settlement-order-v1.md`；`OWNER-FREEZE-2026-08-15`；`OWNER-CONFIRM-2026-08-15:BOMBARD-NO-COOLDOWN`。

## 4. 信息边界、意图与 AI

| Requirement ID | 冻结行为 | Test ID / 实际证据 | 状态 |
|---|---|---|---|
| INFO-PROJECT-001 | 唯一流向 `FullState -> PlayerView`；UI/小地图/提示/公开日志/AI 无 FullState、完整棋盘、规则 RNG 或调试旁路 | `INFO-PAIR-001`; `test_player_view.gd::run_suite`; `test_ai_fairness.gd::_test_real_hidden_equivalent_pair`; `PENDING-INFO-CONSUMER-BOUNDARY-001` | PARTIAL-R2 |
| INFO-VISION-001 | 己营公开；每枚己棋当前中心 `3x3` 裁边并集；移动后旧区无其他源即回雾 | `PENDING-INFO-VISION-3X3-001`; `PENDING-INFO-OLD-FOG-001`; `PENDING-INFO-VISION-UNION-001` | PENDING |
| INFO-SPECIAL-VISION-001 | 车路径视野生命周期；隐身马在普通视野中仍隐藏；相/象田字区显形及多源/旧区失效。相/象精确显形格未冻结 | `PENDING-INFO-ROOK-VISION-001`; `PENDING-INFO-HIDDEN-HORSE-001`; `PENDING-OWNER-ELEPHANT-REVEAL-CELLS`，裁决后 `PENDING-INFO-ELEPHANT-REVEAL-001` | PENDING / PENDING-OWNER |
| INFO-RANDOM-001 | 未公开炮击格、士/回营选择、RNG 状态和未来抽样在公开点前不可见 | 规则 RNG/未公开记录配对：`test_ai_fairness.gd::_test_real_hidden_equivalent_pair`; `PENDING-INFO-RANDOM-EACH-001` | PARTIAL-R2 |
| INFO-PREVIEW-001 | 仅凭 PlayerView 分类 `KNOWN_LEGAL/TENTATIVE/KNOWN_ILLEGAL`；等价投影提示字节等价 | `INFO-INTENT-001`; `test_player_view.gd::run_suite`; `PENDING-INFO-PREVIEW-LEG-EYE-001`; `PENDING-INFO-PREVIEW-CANNON-001` | PARTIAL-R2 |
| INFO-CONTACT-PATH-001 | 隐藏阻挡失败原地且耗行动，只给模糊路线信息；可见非法免费拒绝；不公开阻挡坐标/身份 | `INFO-INTENT-001`; `test_player_view.gd::run_suite` | PASS-R2 |
| INFO-CONTACT-LEYE-001 | 隐藏马腿/象眼为 `TENTATIVE`；真实阻挡失败耗行动且不公开身份 | `PENDING-INFO-CONTACT-LEG-001`; `PENDING-INFO-CONTACT-EYE-001` | PENDING |
| INFO-CONTACT-TARGET-001 | 允许吃子的移动盲吃隐藏敌目标并公开战斗身份；不可吃子的行动失败、记录一次目标格、不持续追踪；隐身马接触显形 | `PENDING-INFO-BLIND-CAPTURE-001`; `PENDING-INFO-NONCAPTURE-CONTACT-001`; `PENDING-INFO-CONTACT-HORSE-001` | PENDING |
| INFO-CANNON-SCREEN-001 | 可见目标同线；迷雾中间格为 `TENTATIVE`；FullState 恰一架成功，否则耗行动并统一“炮路不成立” | `INFO-CANNON-001`; `PENDING-INFO-CANNON-SCREEN-001` | PENDING |
| INFO-EVENT-001 | 公开前玩家事件/错误字段/时序桶一致；接触/视野/随机公开点后才可分叉；full audit 不进入玩家通道 | 前缀/DTO子集：`test_player_view.gd::run_suite`; `test_ai_fairness.gd::_test_real_hidden_equivalent_pair`; `PENDING-INFO-EVENT-MATRIX-001` | PARTIAL-R2 |
| INFO-UI-001 | 主棋盘显示九路并沿长轴移动，行动最终确认只在主棋盘；小地图只消费同一 PlayerView；镜头/反馈仅由可见事件驱动 | `PENDING-INFO-MAINBOARD-001`; `PENDING-INFO-MINIMAP-001`; `PENDING-INFO-FEEDBACK-001` | PENDING |
| AI-BOUNDARY-001 | AI 仅收 PlayerView、公开规则、自身记忆、独立 AI 种子；白名单拒绝额外字段；不收规则 RNG | `test_ai_fairness.gd::_test_real_projection_unknown_field_is_rejected`; `_test_seed_derivation_is_independent_from_rule_rng` | PASS-R2 |
| AI-EQUIV-001 | 等价 PlayerView+记忆+AI种子产生相同候选、摘要、审计和动作；集合顺序不影响决定 | `INFO-PAIR-001`; `test_ai_fairness.gd::_test_real_hidden_equivalent_pair`; `_test_real_projection_collection_order_is_canonical`；负控 `--force-failure` exit 1 | PASS-R2（单一配对） |
| AI-MATRIX-001 | 隐藏马、炮架、路径阻挡、未公开随机等多类等价配对均满足 AI 公平 | `PENDING-AI-EQUIV-HORSE-001`; `PENDING-AI-EQUIV-SCREEN-001`; `PENDING-AI-EQUIV-RANDOM-001` | PENDING |

追溯：`information-boundary-v1.md §1-§7`；`stmt:veilfront-xiangqi-siege:board-and-fog`、`single-player-ai`、`presentation`。

## 5. 结算组合与终止

| Requirement ID | 冻结行为 | Test ID / 实际证据 | 状态 |
|---|---|---|---|
| SET-ACTION-001 | 已知非法不消费；合法/不确定提交；终局拒绝后续行动；随机只在提交事件消费 | 已知非法/不确定：`test_player_view.gd::run_suite`; `PENDING-SET-TERMINAL-REJECT-001`; `PENDING-SET-RNG-CONSUMPTION-001` | PARTIAL-R2 |
| SET-ROOK-001 | 特殊车每个目标完整执行阵亡候选/替死/将帅检查；将帅死亡停止后续目标 | `PENDING-SET-ROOK-RESCUE-001`; `PENDING-SET-ROOK-GENERAL-STOP-001` | PENDING |
| SET-BOMB-001 | 同一前快照三格同步；双方将帅同窗死亡平局；单方死亡对方胜且停止替死/墙/旗/轮上限 | `RULE-BOMB-002`; `test_rules_core.gd::_test_simultaneous_generals_draw`; `PENDING-SET-BOMB-ONE-GENERAL-001`; `PENDING-SET-BOMB-PRIORITY-001` | PARTIAL-R2 |
| SET-RESCUE-001 | 非将帅窗口：炮落点编号排替死，被同窗命中的士不可救；回营失败入后备 | `RULE-BOMB-001`; `test_rules_core.gd::_test_bombardment_rescue_uses_impact_order_and_excludes_hit_advisor`; `PENDING-SET-RESCUE-RESERVE-001` | PARTIAL-R2 |
| SET-WALL-FLAG-001 | 位置/死亡/替死后检查墙；恢复撤回后再累计旗进度；第三次防守行动杀死占领者时不先占旗 | `RULE-FLAG-002`; `test_rules_core.gd::_test_flag_third_opportunity_resolves_death_first`; `PENDING-SET-WALL-BEFORE-FLAG-001` | PARTIAL-R2 |
| SET-VICTORY-001 | 将帅死亡（同窗双亡平局）`>` 非将帅替死 `>` 墙 `>` 三个非争夺旗即时胜利 `>` 完整轮上限旗数/平局 | `PENDING-SET-PRIORITY-CROSS-001` | PENDING |
| SET-ROUND-CAP-001 | 只在完整轮边界，以运行配置的上限检查；争夺旗计原所有者；同数平局。测试可注入候选值，但不得把值写成 confirmed | `PENDING-SET-ROUND-CAP-SCORE-001`; `PENDING-SET-ROUND-CAP-DRAW-001` | PENDING（参数开放） |
| SET-PASS-001 | 主动、超时、无合法行动三类跳过都消耗行动机会、推进修墙/占旗与完整轮 | 普通 pass 子集：`test_rules_core.gd::_test_flag_lifecycle`, `_test_wall_repair_counts_actions_after_trigger`; `PENDING-SET-PASS-TYPES-001` | PARTIAL-R2 |

追溯：`settlement-order-v1.md` 全表；`rules-spec-v1.md §5-§9`。

## 6. 整局、确定性、统计与 Gate

| Requirement ID | 冻结行为 | Test ID / 实际证据 | 状态 |
|---|---|---|---|
| MATCH-REPLAY-001 | 同版本、初态、规则种子、行动序列产生相同事件/最终摘要 | `test_replay.gd::run_suite` 仅三行动；`PENDING-MATCH-FULL-REPLAY-001` 覆盖完整对局及全部随机种类 | PARTIAL-R2 |
| MATCH-GENERAL-END-001 | 完整对局可因将帅实际死亡合法终止 | `PENDING-MATCH-GENERAL-END-001` | PENDING |
| MATCH-FLAG-END-001 | 完整对局可因三个非争夺旗合法终止 | `PENDING-MATCH-FLAG-END-001` | PENDING |
| MATCH-CAP-END-001 | 任意原型候选上限配置可进入旗数胜/负/平局出口；最终上限仍由项目所有者决定 | `PENDING-MATCH-CAP-END-001` | PENDING（参数开放） |
| MATCH-LEGALITY-001 | 完整合法行动生成与执行无非法状态、非终止结算或终局后行动 | `PENDING-MATCH-LEGALITY-001` | PENDING |
| MATCH-1000-001 | 至少 1000 个固定种子完整对局均合法终止且可复现 | Contract `CHECK-005`; `tests/prototype/run_seeded_matches.gd` | BLOCKED-MISSING |
| MATCH-STATS-001 | 输出长度、胜因、先后手、旗分布、墙/炮/车/替死统计；只报告，不冻结平衡阈值 | `PENDING-MATCH-STATS-001`（由 `run_seeded_matches.gd` 产出） | BLOCKED-MISSING |
| CHECK-RUNALL-001 | `run_all.gd` 必须覆盖完整规则、迷雾、回放和 AI 必要用例，并报告 `full_gate1=true` | 当前输出 `focused_suites=5 full_gate1=false`; `PENDING-RUNALL-FULL-GATE1-001` | PENDING / 当前不满足 CHECK-004 |
| GATE-HUMAN-001 | 自动与 QA 证据完成后，由项目所有者判断核心循环/反馈/成本，自动结果不得代批 | `GATE-1` | HUMAN-PENDING |

## 7. 未覆盖项、歧义与交接结论

### 当前未覆盖的 Contract 必要范围

1. 全部传统棋子几何、九宫与公共占用边界。
2. 马腿、象眼、马隐身、相/象田字显形和特殊车路径视野。
3. 特殊车逐目标、特殊兵卒、完整炮架/精确吃子与炮击中心边界。
4. 完整 `3x3` 视野、旧视野回雾、事件/错误/UI/小地图投影矩阵。
5. 墙倒塌/阻挡/修复中断/撤回、士替死配额及无士、旗转移/争夺计分等组合。
6. 跨窗口胜负优先级、三种跳过、终局拒绝、完整轮上限出口。
7. 完整对局生成、三类合法终止、全局回放、统计和 1000 fixed seeds；`run_seeded_matches.gd` 当前不存在。

### 规则歧义审计

发现一项真实规则歧义：`PENDING-OWNER-ELEPHANT-REVEAL-CELLS`——项目简报与项目所有者冻结附件都只写“田字显形区域”，没有定义以相/象当前位置或移动轨迹为基准的精确格集合。该项必须等待项目所有者裁决；实现和测试不得自行选取格集合并反向写成 frozen。除此之外未发现实现与规格相反的证据。其余真实开放项仍为单局完整轮上限最终值，以及 AI 搜索预算、决策随机性与难度；上表只要求可注入候选配置并验证语义，不冻结数值。Revision 2 QA 报告的是实现/证据缺失，不是已实现行为与冻结规则冲突。

### 下一交接

技术岗位应优先建立 `test_piece_geometry.gd`、`test_special_rules.gd`、`test_information_boundary.gd`、`test_settlement_combinations.gd`、`test_match_termination.gd` 与 `run_seeded_matches.gd`，并在输出中采用本矩阵的 Test ID。完成后由独立 QA 重跑 Contract CHECK-004/005；本矩阵不能将 `full_gate1=false` 或缺失 runner 解释为通过。

非规则阻塞另行保留：Revision 2 的 `QA-P1-003`（官方 Loop CLI 将 active runtime Snapshot 按 draft 注册模板检查并 exit 1）属于项目经理/管线维护范围，本矩阵不将其改写为规则缺陷，也不修改 Registry。
