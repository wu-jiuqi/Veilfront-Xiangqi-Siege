# 规则—测试覆盖矩阵 v1

状态：`prototype / iteration 2 / owner-freeze revision 5 / post-GATE-1 baseline remediation`。本文件只建立冻结规格到测试的追溯，不改变规则、不自行验收实现，也不替代独立 QA 或后续 Gate。

## 变更摘要

- 项目所有者 revision 5 冻结：交点棋盘和新区域坐标、完整战区隐藏旗帜、相/象三段视野及敌车/兵卒阻挡、公开阵亡记录、士主动献祭复活，以及所有被动士替死取消。
- Revision 4/RC3 的自动测试结论只作为 GATE-1 历史证据；凡与 revision 5 语义不同的旧测试均标记为 `SUPERSEDED` 或不再作为当前通过证据。
- GATE-1 已由项目所有者批准；批准记录为 `game-pipeline/approvals/gate-1-approval-8f93c3506192.yaml`。其接受的 `QA-P1-003` tooling exception、50 回合 `hypothesis` 和 prototype 可丢弃属性继续保留，不得写成正式架构或正式平衡值。
- 本次只修正规则—测试追溯，不声明 revision 5 实现或独立 QA 已通过。

## 1. 审计基线与判读

- 规则基线：`rules-spec-v1.md`、`settlement-order-v1.md`、`information-boundary-v1.md`；区域轰炸裁决为 `OWNER-CONFIRM-2026-08-15:BOMBARD-NO-COOLDOWN`，相/象显形裁决为 `OWNER-CONFIRM-2026-08-16:ELEPHANT-REVEAL-3X3`，敌墙区域视野裁决为 `OWNER-CONFIRM-2026-08-16:BREACHED-WALL-REGION-VISION`。
- 验收基线：`gate1-observation-plan-v1.md`、`CTR-P1-001 v1`、`LOOP-CTR-GATE1-VERTICAL-SLICE-001 v1`。
- Revision 4 独立 QA 证据索引：`evidence/prototype/qa/gate1-evidence-index.yaml`；复核报告：`evidence/prototype/qa/iteration-1-revision-4-review.md`；命令输出：`evidence/prototype/qa/iteration-1-revision-4-command-output.txt`。QA 证据已推送至 HEAD `459d759`。
- Revision 4 的 `run_elephant_reveal.gd`、`run_all.gd`、独立墙倒塌 runner 与 1000 fixed seeds 均实际通过；`run_all.gd` 中的 `focused_suites=10 full_gate1=false` 是当时的技术聚合字段，不覆盖后来独立发生的人工 GATE-1 批准。`PASS-R4` 只表示旧基线的自动验收证据；`PENDING-R5` 表示 revision 5 仍须补覆盖。
- 下表 Test ID 是稳定追溯 ID。已有测试同时列出实际文件/函数；待新增 ID 只定义验收目标，不授权修改玩法或选择开放参数。

## 2. 棋盘、开局与传统移动几何

| Requirement ID | 冻结行为 | Test ID / 实际证据 | 状态 |
|---|---|---|---|
| GEO-BOARD-001 | `9x24=216` 交点；红视角坐标；红营 `Y=1..3`、红缓冲 `4..8`、战区 `9..16`、黑缓冲 `17..21`、黑营 `22..24`；红/黑墙线为 `Y=4/21` | `RULE-INIT-001`; `PENDING-R5-GEO-BOARD-001` 覆盖全部边界、交点落子和双方 180° 显示镜像 | PENDING-R5 |
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
| SPC-QUALIFY-001 | 除炮击外，特殊行动要求敌墙 `INTACT` 且起点/全部经过交点/终点均在 `Y=4..21`；任一条件不满足时回默认规则 | `PENDING-R5-SPC-QUALIFY-001`（覆盖 `3/4,8/9,16/17,21/22` 与三种墙状态） | PENDING-R5 |
| SPC-HORSE-001 | 合资格马无视马腿并在行动后隐身；处于任一有效显形区时显形，离开全部显形区且无其他批准原因时重新隐身；敌墙倒塌/默认区恢复马腿限制及移除特殊能力 | `PENDING-SPC-HORSE-001`; `PENDING-SPC-HORSE-REHIDE-001` | PENDING |
| SPC-ELEPHANT-001 | 合资格相/象无视象眼；视野为起点中心 `3x3`、田字格九点、终点中心 `3x3` 的并集；田字格九点只截停敌方车和兵/卒从格外进入或穿过到首个交点；同阵营不受阻；下次移动开始或离场/死亡/回营/入队/敌墙倒塌时清源 | Revision 4 九点显形测试仅作历史子集；`PENDING-R5-SPC-ELEPHANT-VISION-001`; `PENDING-R5-SPC-ELEPHANT-BLOCK-001`; `PENDING-R5-SPC-ELEPHANT-SAME-SIDE-001`; `PENDING-R5-SPC-ELEPHANT-EXIT-001` | PENDING-R5 |
| SPC-ROOK-001 | 特殊车可穿敌不可穿己；按路径顺序逐目标实际死亡并登记公开阵亡记录，不触发被动替死；将帅实际死亡立即停止；路径视野持续到该车下一次移动开始；普通车首次接触未显形敌马时吃掉该马并停在接触点 | `PENDING-R5-SPC-ROOK-PATH-001`; `PENDING-R5-SPC-ROOK-CASUALTY-001`; `PENDING-R5-SPC-ROOK-HIDDEN-HORSE-001`; `PENDING-R5-SPC-ROOK-VISION-001` | PENDING-R5 |
| SPC-PAWN-001 | 普通兵/卒前左/右一格可吃终点敌棋；特殊兵/卒可横纵 2..5 格，可穿一个或多个敌棋、不可穿己棋、终点空；穿越不伤害且不打开路径视野 | `test_revision3_rules.gd::_test_pawn_public_candidates_and_special_contact` | PASS-R6（生产者自检；待独立 QA） |
| SPC-BOMB-ELIG-001 | 区域轰炸资格且仅有敌墙 `INTACT`、炮在己方大本营、该炮有弹药；中心完整 `3x3` 九点全部位于 `Y=4..21` | 旧 `RULE-CANNON-ORIGIN-001` 仅作历史子集；`PENDING-R5-SPC-BOMB-CENTER-001` | PENDING-R5 |
| SPC-BOMB-NOCD-001 | 每炮初始两发、只减不增；无阵营共享冷却字段/计时/重置，前次轰炸不锁另一炮或后续资格 | `RULE-CANNON-COOLDOWN-001`; `test_match_state.gd::run_suite`; `test_rules_core.gd::_test_bombardment_origin_and_no_cooldown`; 尚需 `PENDING-SPC-BOMB-NOCD-CROSS-CANNON-001` 与 `PENDING-INFO-NOCD-FIELDS-001` | PARTIAL-R2 |
| SPC-BOMB-WINDOW-001 | 锁定三个不同点和前快照；三点逻辑同步、动画顺序无语义；允许友伤；全部实际死亡登记双方公开阵亡记录；炮击不生成虚影且不触发任何被动士替死 | 旧炮击替死用例 `test_rules_core.gd::_test_bombardment_rescue_uses_impact_order_and_excludes_hit_advisor` 已 `SUPERSEDED`；`PENDING-R5-SPC-BOMB-SNAPSHOT-001`; `PENDING-R5-SPC-BOMB-CASUALTY-001`; `PENDING-R5-SPC-BOMB-NO-GHOST-001` | PENDING-R5 |
| WALL-COLLAPSE-001 | 双方墙独立；完整墙阻止敌棋踏入或跨越守方墙线（红方敌棋最多到 `Y=5`，黑方最多到 `Y=20`）；守方缓冲区同时至少 3 敌棋时倒塌 | `PENDING-R5-WALL-INDEPENDENT-001`; `PENDING-R5-WALL-COLLAPSE-001`; `PENDING-R5-WALL-BLOCK-001` | PENDING-R5 |
| WALL-REPAIR-001 | 行动后 `<3` 启动且触发行动不计；之后双方各行动一次；中途 `>=3` 清零；`REPAIRING` 仍按倒塌；完成才恢复 | `RULE-WALL-001`; `test_rules_core.gd::_test_wall_repair_counts_actions_after_trigger`; `PENDING-WALL-CANCEL-001`; `PENDING-WALL-SEMANTICS-001` | PARTIAL-R2 |
| WALL-RETURN-001 | 恢复只撤回守方大本营入侵者；缓冲区不撤；随机唯一分配各自大本营空格；清临时状态、不回资源、不罚行动 | `PENDING-WALL-RETURN-001` | PENDING |
| FLAG-SPAWN-001 | 三旗随机生成在完整战区 `X=1..9,Y=9..16` 的三个不同交点；旗位受迷雾影响，某方发现后为该方永久保留图标，未发现方不得从投影、种子或消息反推坐标 | 旧三行带/公开旗位测试已 `SUPERSEDED`；`PENDING-R5-FLAG-SPAWN-001`; `PENDING-R5-FLAG-DISCOVERY-001`; `PENDING-R5-FLAG-HIDDEN-EQUIV-001` | PENDING-R5 |
| FLAG-CAPTURE-001 | 具体棋踏入旗点后从 `1/3` 开始；每次敌方行动机会（含三类跳过）加 1；第三次行动先结算死亡/离位；换子不继承；进度消息不向未发现方公开旗位 | 旧 `RULE-FLAG-001/002` 只作历史子集；`PENDING-R5-FLAG-PROGRESS-001`; `PENDING-R5-FLAG-SKIP-TYPES-001`; `PENDING-R5-FLAG-SWAP-001`; `PENDING-R5-FLAG-MESSAGE-NO-COORD-001` | PENDING-R5 |
| FLAG-OWNER-001 | 完成后永久持有；敌重占期间原所有权保持、`contested=true`；中断恢复安全；争夺旗轮上限计原方但不计即时三旗 | `RULE-FLAG-003`; `test_rules_core.gd::_test_flag_lifecycle`; `PENDING-FLAG-TRANSFER-001`; `PENDING-FLAG-CONTEST-SCORING-001` | PARTIAL-R2 |
| ADVISOR-SACRIFICE-001 | 存活在场士可选择主动献祭并在提交前确认或取消；确认后消耗一次行动，士先死亡并进入公开阵亡记录，再从己方记录随机选择非士、非帅/将并随机复活到己方大本营空点；复活不恢复永久资源 | 旧 `RESCUE-001` 与全部“前两次强制替死”测试已 `SUPERSEDED`；`PENDING-R5-ADVISOR-SACRIFICE-CONFIRM-001`; `PENDING-R5-ADVISOR-SACRIFICE-CANCEL-001`; `PENDING-R5-ADVISOR-SACRIFICE-RANDOM-001`; `PENDING-R5-ADVISOR-SACRIFICE-RESOURCE-001` | PENDING-R5 |
| CASUALTY-001 | 吃子、车路径、炮击、主动献祭、将帅实际死亡及其他原因都进入所属方公开阵亡记录；双方 PlayerView 同步完整两方记录；复活立即移出；士和帅/将虽在公开记录中，但永不进入献祭复活候选池 | `PENDING-R5-CASUALTY-ALL-CAUSES-001`; `PENDING-R5-CASUALTY-BOTH-VIEWS-001`; `PENDING-R5-CASUALTY-REVIVE-REMOVE-001`; `PENDING-R5-CASUALTY-FILTER-001` | PENDING-R5 |
| CAPTURE-GHOST-001 | 只有被吃棋子在原交点为阵亡方留下虚影；持续到对方下一次行动完成；炮击和主动献祭不生成；虚影不影响规则、高亮或另一方投影 | `PENDING-R5-CAPTURE-GHOST-LIFETIME-001`; `PENDING-R5-CAPTURE-GHOST-CAUSE-001`; `PENDING-R5-CAPTURE-GHOST-PRIVATE-001`; `PENDING-R5-CAPTURE-GHOST-NONINTERACTION-001` | PENDING-R5 |
| RESERVE-001 | 无空格则 FIFO 后备；不在场/不可交互/无视野；己方行动开始前随机部署，不耗行动且可立即选择 | `RULE-RESERVE-001`; `test_rules_core.gd::_test_reserve_queue_and_free_deployment`; `PENDING-RESERVE-NONINTERACTION-001`; `PENDING-RESERVE-FIFO-MULTI-001` | PARTIAL-R2 |

追溯：`rules-spec-v1.md §4-§8`；`settlement-order-v1.md`；`OWNER-FREEZE-2026-08-15`；`OWNER-CONFIRM-2026-08-15:BOMBARD-NO-COOLDOWN`。

## 4. 信息边界、意图与 AI

| Requirement ID | 冻结行为 | Test ID / 实际证据 | 状态 |
|---|---|---|---|
| INFO-PROJECT-001 | 唯一流向 `FullState -> PlayerView`；UI/小地图/提示/公开日志/AI 无 FullState、完整棋盘、规则 RNG 或调试旁路 | `INFO-PAIR-001`; `test_player_view.gd::run_suite`; `test_ai_fairness.gd::_test_real_hidden_equivalent_pair`; `PENDING-INFO-CONSUMER-BOUNDARY-001` | PARTIAL-R2 |
| INFO-VISION-001 | 己营公开；每枚己棋当前中心 `3x3` 裁边并集；移动后旧区无其他源即回雾 | `PENDING-INFO-VISION-3X3-001`; `PENDING-INFO-OLD-FOG-001`; `PENDING-INFO-VISION-UNION-001` | PENDING |
| INFO-WALL-VISION-001 | 敌墙为 `BREACHED` 或 `REPAIRING` 时，本方获得敌方缓冲区与大本营全部格子视野；恢复 `INTACT` 后立即移除；双方对称；该格子视野不自动驱散隐身马 | `test_player_view.gd::_test_breached_wall_region_visibility`; `tests/prototype/run_all.gd` | PASS-R5（生产者自检；待独立 QA） |
| INFO-SPECIAL-VISION-001 | 车完整移动路径视野持续到该车下一次移动开始；隐身马在普通视野中仍隐藏；相/象视野为起点 `3x3`、田字九点、终点 `3x3` 并集，多源取并集且旧源按生命周期失效 | Revision 4 九点显形测试只作历史子集；`PENDING-R5-INFO-ROOK-VISION-001`; `PENDING-R5-INFO-ELEPHANT-VISION-001`; `PENDING-R5-INFO-ELEPHANT-MULTISOURCE-001` | PENDING-R5 |
| INFO-RANDOM-001 | 未公开旗位、炮击格、士复活候选/落点、回营选择、规则 RNG 状态和未来抽样在公开点前不可见 | 规则 RNG/未公开记录旧配对只作历史子集；`PENDING-R5-INFO-RANDOM-FLAG-001`; `PENDING-R5-INFO-RANDOM-BOMB-001`; `PENDING-R5-INFO-RANDOM-REVIVE-001`; `PENDING-R5-INFO-RANDOM-RETURN-001` | PENDING-R5 |
| INFO-PREVIEW-001 | 仅凭 PlayerView 分类 `KNOWN_LEGAL/TENTATIVE/KNOWN_ILLEGAL`；等价投影提示字节等价 | `INFO-INTENT-001`; `test_player_view.gd::run_suite`; `PENDING-INFO-PREVIEW-LEG-EYE-001`; `PENDING-INFO-PREVIEW-CANNON-001` | PARTIAL-R2 |
| INFO-CONTACT-PATH-001 | 隐藏阻挡失败原地且耗行动，只给模糊路线信息；可见非法免费拒绝；不公开阻挡坐标/身份 | `INFO-INTENT-001`; `test_player_view.gd::run_suite` | PASS-R2 |
| INFO-CONTACT-LEYE-001 | 隐藏马腿/象眼为 `TENTATIVE`；真实阻挡失败耗行动且不公开身份 | `PENDING-INFO-CONTACT-LEG-001`; `PENDING-INFO-CONTACT-EYE-001` | PENDING |
| INFO-CONTACT-TARGET-001 | 允许吃子的移动盲吃隐藏敌目标并公开战斗身份；不可吃子的行动失败、记录一次目标格、不持续追踪；隐身马接触显形 | `PENDING-INFO-BLIND-CAPTURE-001`; `PENDING-INFO-NONCAPTURE-CONTACT-001`; `PENDING-INFO-CONTACT-HORSE-001` | PENDING |
| INFO-CANNON-SCREEN-001 | 可见目标同线；迷雾中间格为 `TENTATIVE`；FullState 恰一架成功，否则耗行动并统一“炮路不成立” | `INFO-CANNON-001`; `PENDING-INFO-CANNON-SCREEN-001` | PENDING |
| INFO-EVENT-001 | 公开前玩家事件/错误字段/时序桶一致；接触/视野/随机公开点后才可分叉；full audit 不进入玩家通道 | 前缀/DTO子集：`test_player_view.gd::run_suite`; `test_ai_fairness.gd::_test_real_hidden_equivalent_pair`; `PENDING-INFO-EVENT-MATRIX-001` | PARTIAL-R2 |
| INFO-UI-001 | 主棋盘显示九路并沿长轴移动，行动最终确认/取消只在主棋盘；小地图只消费同一 PlayerView；镜头、反馈与教学只消费指定观察者的 `PlayerView`、`VisibleEvent`、`VisibleError`、`ActionPreview`，不得读取 raw Domain Event 或 `FullState` | `PENDING-R5-INFO-MAINBOARD-001`; `PENDING-R5-INFO-MINIMAP-001`; `PENDING-R5-INFO-FEEDBACK-001`; `PENDING-R5-INFO-TUTORIAL-BOUNDARY-001` | PENDING-R5 |
| AI-BOUNDARY-001 | AI 仅收 PlayerView、公开规则、自身记忆、独立 AI 种子；白名单拒绝额外字段；不收规则 RNG | `test_ai_fairness.gd::_test_real_projection_unknown_field_is_rejected`; `_test_seed_derivation_is_independent_from_rule_rng` | PASS-R2 |
| AI-EQUIV-001 | 等价 PlayerView+记忆+AI种子产生相同候选、摘要、审计和动作；集合顺序不影响决定 | `INFO-PAIR-001`; `test_ai_fairness.gd::_test_real_hidden_equivalent_pair`; `_test_real_projection_collection_order_is_canonical`；负控 `--force-failure` exit 1 | PASS-R2（单一配对） |
| AI-MATRIX-001 | 隐藏马、炮架、路径阻挡、未公开随机等多类等价配对均满足 AI 公平 | `PENDING-AI-EQUIV-HORSE-001`; `PENDING-AI-EQUIV-SCREEN-001`; `PENDING-AI-EQUIV-RANDOM-001` | PENDING |
| AI-EXPERT-001 | 专家档仍只消费 PlayerView；覆盖全部公开候选，在可见信息上做一层战术风险/支援/将帅安全评估，随机调整为 0，并保持确定性与隐藏等价 | `test_ai_difficulty_profiles.gd::_expert_tactical_fixture_decision`; `run_ai_difficulty_seed_matrix.gd` 3 seed × 4 档生产者烟测 | PASS-R5（生产者自检；待独立 QA） |

追溯：`information-boundary-v1.md §1-§7`；`stmt:veilfront-xiangqi-siege:board-and-fog`、`single-player-ai`、`presentation`；`OWNER-CONFIRM-2026-08-16:BREACHED-WALL-REGION-VISION`。

## 5. 结算组合与终止

| Requirement ID | 冻结行为 | Test ID / 实际证据 | 状态 |
|---|---|---|---|
| SET-ACTION-001 | 已知非法不消费；合法/不确定提交；终局拒绝后续行动；随机只在提交事件消费 | 已知非法/不确定：`test_player_view.gd::run_suite`; `PENDING-SET-TERMINAL-REJECT-001`; `PENDING-SET-RNG-CONSUMPTION-001` | PARTIAL-R2 |
| SET-ROOK-001 | 特殊车逐目标执行“实际死亡并登记公开阵亡记录→将帅检查”；不触发被动士替死；将帅死亡立即截断后续目标 | `PENDING-R5-SET-ROOK-CASUALTY-001`; `PENDING-R5-SET-ROOK-GENERAL-STOP-001`; `PENDING-R5-SET-ROOK-NO-PASSIVE-RESCUE-001` | PENDING-R5 |
| SET-BOMB-001 | 同一前快照三点同步；全部死亡先登记；双方将帅同窗死亡平局，单方死亡对方胜；无被动士替死；终局停止墙、旗与轮上限但保留安全终局投影 | 旧 `RULE-BOMB-002` 双将子集只作历史证据；`PENDING-R5-SET-BOMB-ALL-CASUALTIES-001`; `PENDING-R5-SET-BOMB-ONE-GENERAL-001`; `PENDING-R5-SET-BOMB-DUAL-GENERAL-001`; `PENDING-R5-SET-BOMB-NO-PASSIVE-RESCUE-001` | PENDING-R5 |
| SET-SACRIFICE-001 | 献祭待确认时可取消且不消费；确认后士死亡登记，随后随机复活合资格棋子并从阵亡记录移出；无候选或牺牲后无营内空点时动作不可提交 | `PENDING-R5-SET-SACRIFICE-CANCEL-001`; `PENDING-R5-SET-SACRIFICE-COMMIT-001`; `PENDING-R5-SET-SACRIFICE-NO-CANDIDATE-001`; `PENDING-R5-SET-SACRIFICE-NO-SPACE-001` | PENDING-R5 |
| SET-WALL-FLAG-001 | 位置与死亡登记、主动献祭/复活后检查墙；恢复撤回后再累计旗进度；第三次防守行动杀死占领者时不先占旗 | 旧 `RULE-FLAG-002` 只作历史子集；`PENDING-R5-SET-WALL-BEFORE-FLAG-001`; `PENDING-R5-SET-SACRIFICE-BEFORE-WALL-001` | PENDING-R5 |
| SET-VICTORY-001 | 实际死亡先登记；随后将帅死亡（炮击同窗双亡平局）`>` 城墙 `>` 三个非争夺旗即时胜利 `>` 完整轮上限旗数/平局；不存在“非将帅替死”优先级 | `PENDING-R5-SET-PRIORITY-CROSS-001`; `PENDING-R5-SET-GENERAL-CASUALTY-BEFORE-END-001` | PENDING-R5 |
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
| MATCH-1000-001 | 至少 1000 个固定种子完整对局均合法终止且可复现 | Contract `CHECK-005`; `tests/prototype/run_seeded_matches.gd`; `evidence/prototype/qa/iteration-1-revision-4-seeded-output.txt`; `evidence/prototype/qa/iteration-1-revision-4-seeded-manifest.jsonl`; 索引项 `CHECK-1000-SEEDED-MATCHES`：`1000/1000`、失败 `0`、确定性不一致 `0`、抽样回放 `10/10` | PASS-R4（独立 QA；轮上限 8 仅为可覆盖 hypothesis） |
| MATCH-STATS-001 | 输出长度、胜因、先后手、旗分布、墙/炮/车、主动献祭/复活与各原因阵亡统计；只报告，不冻结平衡阈值 | Revision 4 旧“替死”统计仅作历史证据；`PENDING-R5-MATCH-STATS-001` | PENDING-R5 |
| CHECK-RUNALL-001 | `run_all.gd` 聚合规则、迷雾、回放和必要用例；revision 5 必须移除或改写被动替死断言，且聚合测试结果与人工 Gate 状态分开报告 | Revision 4 输出 `focused_suites=10 full_gate1=false` 仅为历史技术字段；`PENDING-R5-CHECK-RUNALL-001` | PENDING-R5 |
| GATE-HUMAN-001 | 项目所有者已基于 RC3 决策包批准 GATE-1；该批准允许在新获批 Contract 下进行正式功能规划与架构审查，但不冻结正式架构、不批准 GATE-2 或对外发布 | `game-pipeline/approvals/gate-1-approval-8f93c3506192.yaml` | APPROVED（2026-08-17） |

## 7. 未覆盖项、歧义与交接结论

### 当前未覆盖的 Contract 必要范围

1. 全部传统棋子几何、九宫与公共占用边界。
2. 马腿、象眼、马隐身、相/象三段视野与田字格敌车/兵卒阻挡、特殊车路径视野。
3. 特殊车逐目标阵亡登记与将帅截断、特殊兵卒、完整炮架/精确吃子与炮击中心边界。
4. 完整 `3x3` 视野、旧视野回雾、事件/错误/UI/小地图投影矩阵。
5. 墙倒塌/阻挡/修复中断/撤回、士主动献祭确认/取消/随机复活、公开阵亡记录与候选池过滤、旗转移/争夺计分等组合。
6. 跨窗口胜负优先级、三种跳过、终局拒绝、完整轮上限出口。
7. Revision 4 已覆盖旧基线的 1000 fixed seeds、确定性抽样回放与统计输出；revision 5 语义进入正式实现后必须按迁移清单的触发条件重跑，旧证据不得冒充新规则覆盖。

### 规则歧义审计

`PENDING-OWNER-ELEPHANT-REVEAL-CELLS` 已由项目所有者关闭：精确集合为合法移动起终点包围方形的九格。Revision 4 独立 QA 未发现新的 frozen 规则歧义或实现与规格相反的证据。其余真实开放项仍为单局完整轮上限最终值，以及 AI 搜索预算、决策随机性与难度；上表只要求可注入候选配置并验证语义，不冻结数值。

### 下一交接

GATE-1 已由项目所有者批准，RC3 和 Revision 4 证据保持历史不可变。当前交接目标不是重开 GATE-1，而是让正式架构前置审阅绑定本 revision 5 规则基线，并由后续实现与独立 QA 逐项关闭所有 `PENDING-R5`。

Revision 4 的 `QA-P1-003` 官方 Loop CLI 失败被项目所有者作为 GATE-1 残余风险接受；它仍然是工具事实，不能改写成 CLI 通过，也不阻止本文件记录独立的人工 GATE-1 批准。正式架构、GATE-2、高成本资产批量生产与外部发布仍未获本矩阵批准。
