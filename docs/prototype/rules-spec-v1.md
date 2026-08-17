# 《雾疆：九路烽棋》规则规格 v1

状态：`prototype / iteration 2 / owner-freeze revision 5`。本文件规范项目简报 `confirmed` 语义及项目所有者后续冻结结论。实现架构仍为 `hypothesis`，剩余 `unknown` 不得被实现默认值冒充批准规则。

冻结来源：`OWNER-FREEZE-2026-08-15` = `C:/Users/30114/.codex/attachments/dd52e25b-1af0-4fb5-90d1-a5315853a81c/pasted-text.txt`。

## 变更摘要

- 关闭初始坐标/阵型/九宫/先手、旗帜生命周期、隐藏阻挡与行动意图、同步炮击、后备部署、城墙修复时序、炮击起源位置七组 `unknown`。
- 项目所有者再次确认区域轰炸“无冷却”，关闭附件中的共享冷却冲突：不存在阵营共享冷却字段、计时、启动或重置；资格只由敌墙、炮位置与该炮弹药决定。
- 项目所有者冻结相/象田字显形区为本次合法移动起点与终点包围的 `3x3` 九格，关闭精确格集合歧义并补齐生命周期与多源并集。
- 项目所有者确认城墙倒塌视野：一方城墙处于 `BREACHED` 或 `REPAIRING` 时，对方获得该方缓冲区与大本营全部格子的视野；恢复 `INTACT` 后该额外视野立即移除。该规则双方对称，不额外驱散隐身马。
- 项目所有者将棋盘表现重构为象棋交点；两条城墙线位于兵/卒初始点并禁止敌棋在完整墙状态下踏入或跨越。旗帜受迷雾影响，发现后向发现方永久保留位置图标。相视野扩为起点中心3x3、路径田字格和终点中心3x3并集，田字格阻挡敌方车与兵/卒首次进入；士改为主动献祭复活，阵亡士与帅/将不进入随机池。所有原因导致的阵亡统一进入双方公开阵亡池。

## 1. 坐标、区域与回合术语

- 服务端固定使用红方视角交点坐标：`X=1..9, Y=1..24`，共 216 个落子点；红方向 `+Y` 前进，黑方向 `-Y` 前进。红方界面令红营在底，黑方界面将棋盘旋转 180° 令黑营在底，但不得改变底层坐标。
- 红方大本营 `Y=1..3`、红方缓冲区 `Y=4..8`、中央战区 `Y=9..16`、黑方缓冲区 `Y=17..21`、黑方大本营 `Y=22..24`。红墙就是 `Y=4` 点线，黑墙就是 `Y=21` 点线；兵/卒初始点分别在这两条城墙线上，特殊行动区域为 `Y=4..21`。`Y=12/13` 只可称为棋盘几何中线，不恢复河界或过河规则。
- 红方九宫为 `X=4..6,Y=1..3`；黑方九宫为 `X=4..6,Y=22..24`。
- `行动`：一方完成的一次普通行动、特殊行动、主动跳过、超时跳过或无合法行动被迫跳过；两类跳过同样消耗一次行动机会。`完整轮`：红黑双方各完成一次行动。红方固定先手。
- 除将帅、士受各自九宫限制外，其他棋子不受河界或阵营半场限制。项目不存在将军、应将、将死、照面和飞将合法性检查。

### 初始阵型

| 阵营 | 坐标 | 棋子 |
|---|---|---|
| 红 | `Y=1,X=1..9` | 车、马、相、士、帅、士、相、马、车 |
| 红 | `(X,Y)=(2,3),(8,3)` | 炮、炮 |
| 红 | `(X,Y)=(1,4),(3,4),(5,4),(7,4),(9,4)` | 兵、兵、兵、兵、兵 |
| 黑 | `Y=24,X=1..9` | 车、马、象、士、将、士、象、马、车 |
| 黑 | `(X,Y)=(2,22),(8,22)` | 炮、炮 |
| 黑 | `(X,Y)=(1,21),(3,21),(5,21),(7,21),(9,21)` | 卒、卒、卒、卒、卒 |

其余大本营格初始为空。单局系统随机分配玩家/机器人红黑阵营，但始终红方先手。若运行成对公平性实验，第二局交换阵营、仍由红方先手，并使用第一局旗位的棋盘中心镜像；这只是测试编排，不扩大 GATE-1 的单机范围。

追溯：`stmt:veilfront-xiangqi-siege:board-and-fog`、`stmt:veilfront-xiangqi-siege:phase-gameplay`、`stmt:veilfront-xiangqi-siege:general-capture-rules`；`OWNER-FREEZE-2026-08-15 §1`。

## 2. 最小状态模型

`FullState` 至少包含：

- `MatchState { active_side, action_index, full_round_index, terminal, winner, win_reason }`；
- `PieceState { piece_id, side, type, lifecycle: BOARD|RESERVE|DEAD, position?, reserve_queue_index?, hidden, bombard_ammo, permanent_resources, temporary_effects }`；
- `WallState { status: INTACT|BREACHED|REPAIRING, repair_start_action_index?, acted_sides_since_start, invading_piece_count }`；
- `FlagState { owner: NEUTRAL|RED|BLACK, occupier_piece_id?, capturing_side?, capture_progress: 0..3, contested }`；
- `FlagDiscoveries { red: flag_id[], black: flag_id[] }`、双方统一 `CasualtyPool` 与仅阵亡方可见的一回合 `CaptureGhost`；
- 各车路径视野源、相视野源与敌车/兵卒阻挡源、随机种子/消费序号，以及按阵营 FIFO 的后备部署队列；
- `BombardmentResult { random_seed_ref, target_center, impact_cells[3], impact_order[3], simultaneous_resolution_id }`。

必须保持以下不变量：一个交点最多一枚棋子；`DEAD/RESERVE` 棋子不在棋盘；任何原因造成的 `DEAD` 都登记到所属方阵亡池，复活后立即移出；后备棋子不可行动、被攻击、提供视野、充当炮架/阻挡或计入墙/旗；炮区域弹药每门初始 2、只减不增；FullState 不得存在阵营共享轰炸冷却字段、计时或重置；士复活动作必定先牺牲发动者，阵亡士与帅/将不得进入复活随机池；双方城墙独立；终局后不再接受行动。

追溯：`stmt:veilfront-xiangqi-siege:cannon-rules`、`stmt:veilfront-xiangqi-siege:wall-cycle`、`stmt:veilfront-xiangqi-siege:victory-and-flags`、`stmt:veilfront-xiangqi-siege:piece-rescue`。

## 3. 普通行动

- 车、马、相/象、士、将/帅、炮采用传统象棋移动/吃子规则，并应用本规格明确覆盖项：马与相/象可在全棋盘行动；士、将帅仍限九宫；炮精确吃子必须隔恰好一枚炮架并移动到目标格。
- 兵/卒始终按“已过河”处理：可向前、左、右一格，不可后退。
- 任意大本营内使用默认规则：马受蹩马腿、相/象受堵象眼；车不得穿子；炮普通移动和精确吃子不变。
- 将帅可以进入攻击范围；只有实际被吃掉才失败。

追溯：`stmt:veilfront-xiangqi-siege:board-and-fog`、`stmt:veilfront-xiangqi-siege:phase-gameplay`、`stmt:veilfront-xiangqi-siege:horse-elephant-rules`、`stmt:veilfront-xiangqi-siege:cannon-rules`、`stmt:veilfront-xiangqi-siege:pawn-rules`、`stmt:veilfront-xiangqi-siege:general-capture-rules`。

## 4. 特殊行动资格与效果

除炮击外，特殊行动必须同时满足：敌方城墙完整；起点、每个经过格、终点都在 `Y=4..21`。任一条件不满足即只可按普通规则生成行动。

| 棋子 | 特殊规则 |
|---|---|
| 马 | 合资格移动无视蹩马腿；完成后处于隐身，除非落在任一有效相/象田字显形区或存在其他公开显形原因。离开全部显形区且无其他原因时恢复隐身。 |
| 相/象 | 合资格移动无视堵象眼；视野为起点中心 `3x3`、起终点组成的田字格九点、终点中心 `3x3` 的并集，投影时裁剪到棋盘。田字格九点形成敌方车与兵/卒阻挡源：它们从田字格外试图进入或穿过时，只移动到路径首个交点；下一次从田字格内离开时恢复正常。该源不阻挡己方车或兵/卒。 |
| 车 | 可沿同一直线路径穿过敌棋并按起点到终点顺序逐枚处理阵亡/替死；不可穿过己棋。若路径目标将帅实际死亡，立即终局并停止后续目标。该次路径形成视野，持续到此车下一次移动开始。 |
| 兵/卒 | 普通行动仍为前/左/右一格且可吃终点敌棋；特殊行动可横向或纵向移动 2..5 格，可穿过一枚或多枚敌棋，不可穿己棋，终点必须为空，穿越不伤害、不吃子，也不产生路径视野。 |
| 炮 | 区域轰炸不需要炮架、不移动炮，与普通行动互斥；资格条件且仅有：敌方墙为 `INTACT`、炮在己方大本营、该炮弹药至少 1。中心完整 `3x3` 必须全在 `Y=4..21`，从九格随机抽三个不同伤害格，允许友军伤害，消耗该炮 1 发且无冷却。炮离营即不可轰炸，回营且三项条件满足即可再次轰炸；弹药不恢复。不存在阵营共享冷却、等待轮数或墙/回营冷却重置。 |

每枚相/象至多维护一个自己的田字显形区。该棋子下次移动开始时先清除旧区；该棋子任何离场、死亡、回营或进入后备队列时立即清除旧区。敌方城墙倒塌使其特殊能力失效时也清除旧区。多个仍有效相/象源取格集合并集；某源清除后，仍被其他源覆盖的格继续有效。

敌方城墙倒塌时，针对该敌方的马、相/象、车、兵/卒特殊能力立即失效并恢复对应默认限制；墙恢复后只影响后续行动资格，不恢复旧视野/显形区或永久资源。

追溯：`stmt:veilfront-xiangqi-siege:phase-gameplay`、`stmt:veilfront-xiangqi-siege:horse-elephant-rules`、`stmt:veilfront-xiangqi-siege:cannon-rules`、`stmt:veilfront-xiangqi-siege:rook-rules`、`stmt:veilfront-xiangqi-siege:pawn-rules`；`OWNER-FREEZE-2026-08-15 §6.5`；`OWNER-CONFIRM-2026-08-15:BOMBARD-NO-COOLDOWN`；`OWNER-CONFIRM-2026-08-16:ELEPHANT-REVEAL-3X3`；`OWNER-CONFIRM-2026-08-16:BREACHED-WALL-REGION-VISION`；`OWNER-CONFIRM-2026-08-16:PAWN-MOVE-SPLIT`。

## 5. 城墙状态机

每方城墙独立为 `INTACT -> BREACHED -> REPAIRING -> INTACT`：

1. `INTACT` 阻止敌棋踏入或跨越该方城墙点线。红方敌棋最深只能到 `Y=5`，黑方敌棋最深只能到 `Y=20`；墙已倒塌或修复中才可进入 `Y=4` / `Y=21` 及其后的守方区域。
2. 该方缓冲区内同时存在至少 3 枚敌棋时，墙立即 `BREACHED`。
3. 仅在一次完整行动结算结束后检查恢复条件。墙已倒塌且该方缓冲区与大本营内敌棋总数少于 3 时进入 `REPAIRING`；触发该状态的行动不计时。
4. `REPAIRING` 仍按倒塌墙处理。之后对方与己方必须各完成一次行动；每次行动后若入侵数回到至少 3，立即退回 `BREACHED` 并清零进度。双方均行动且条件仍成立时恢复 `INTACT`。
5. 恢复时，仅把该方大本营内的入侵棋子随机撤回各自大本营；缓冲区敌棋不撤回。先移除整批待撤棋子，随机打乱真实空格，再按确定的结算顺序分配；清除位置临时状态，不恢复永久消耗，不附加行动惩罚。无空格者进入后备部署队列。
6. 城墙处于 `BREACHED` 或 `REPAIRING` 时，对方获得该方缓冲区与大本营全部格子的视野；双方城墙独立、规则对称。城墙恢复 `INTACT` 后，该区域额外视野从下一次 PlayerView 投影起立即移除，无其他视野源覆盖的格重新入雾。区域全视野只解除战争迷雾，不等同于反隐，隐身马仍须由既有显形原因公开。

追溯：`stmt:veilfront-xiangqi-siege:wall-cycle`、`stmt:veilfront-xiangqi-siege:phase-gameplay`；`OWNER-FREEZE-2026-08-15 §5-6.4`；`OWNER-CONFIRM-2026-08-16:BREACHED-WALL-REGION-VISION`。

## 6. 迷雾、旗帜、替死与胜负

- 开局除己方大本营外均受迷雾。普通棋子以当前位置为中心提供裁剪到棋盘内的 `3x3` 动态视野，移动后旧区域重新入雾；车路径视野和相/象显形按第 4 节叠加；敌墙倒塌期间按第 5 节叠加敌方缓冲区与大本营全域视野。具体投影见 `information-boundary-v1.md`。
- 开局从完整中央战区 `X=1..9,Y=9..16` 抽取三个不同点。旗帜受正常迷雾视野影响；进入某方视野后，该方将该 `flag_id` 记入永久发现记录，此后即使该点重新入雾，也继续在该方地图显示旗帜图标。另一方未发现时仍只得到空位置，规则种子也不得下发到可据此反推旗位的客户端。
- 棋子行动后停在中立旗或敌方所有旗上时，以该 `piece_id` 开始 `1/3` 占领，并公开“红方/黑方正在夺旗(n/3)”进度；完成后公开“红方/黑方成功夺得一面旗帜”。旗位是否显示仍严格取决于各自发现记忆，不因占领消息自动公开。之后每当对方完成一次行动机会（含三类跳过），若该棋子仍在旗点，进度加 1。
- 占领进度绑定具体棋子，不可换子继承。占领者离开、死亡、替死回营、强制撤回或棋子实例变化时立即清零。
- 占领完成后，所有权永久保持，棋子可以离开，直至敌方完成重新占领。敌方开始重占时，原所有权在进度期间仍保持但 `contested=true`：轮上限仍计给原所有者，却不计入三旗即时胜利；争夺中断则原所有权安全保留。单格旗同时最多一枚棋子，邻格不影响进度。
- 同一阵营拥有三旗且三旗均非 `contested` 时立即获胜。
- 士可主动消耗一次行动，以自己阵亡为代价，从己方阵亡区随机选择一枚非士、非帅/将棋子，并随机复活到己方大本营空格。阵亡士与帅/将明确不进入随机池；无合资格阵亡棋子或牺牲后仍无大本营空格时，该动作不可提交。所有被动和“前两次阵亡强制替死”逻辑取消。
- 无论吃子、区域轰炸、主动献祭或其他结算原因，阵亡棋子都进入规范阵亡池；双方 PlayerView 同步公开两边阵亡池。棋子被吃时，仅向阵亡方在原交点显示半透明虚影，持续到对方完成下一次行动后消失；轰炸或主动献祭不生成该虚影。
- 将帅实际死亡是同一结算窗口最高优先级：仅一方将帅死亡则该方失败；同一个同步伤害窗口内双方将帅均死亡则平局。否则依次检查三旗胜利；达到尚未冻结的完整轮上限时，以旗所有权数量判胜（`contested` 仍计原所有者），同数平局。

追溯：`stmt:veilfront-xiangqi-siege:board-and-fog`、`stmt:veilfront-xiangqi-siege:rook-rules`、`stmt:veilfront-xiangqi-siege:victory-and-flags`、`stmt:veilfront-xiangqi-siege:piece-rescue`、`stmt:veilfront-xiangqi-siege:general-capture-rules`；`OWNER-FREEZE-2026-08-15 §2, §4`。

## 7. 后备部署队列

复活或撤回时，先把待返回棋子移出原位置，再以随机打乱的己方大本营真实空格按结算顺序分配。无法放置者进入本方 FIFO 后备队列：不视为死亡，保留永久消耗，清除隐身、占旗进度和临时视野。

在该阵营每次行动开始、生成可选行动之前，按入队顺序检查后备棋子；有空格时随机部署，重新计算视野。自动部署不消耗行动、不附加惩罚，刚部署棋子可在本次行动被选择。每次分配的空格列表、顺序与随机消费必须记入审计/回放。

追溯：`stmt:veilfront-xiangqi-siege:wall-cycle`、`stmt:veilfront-xiangqi-siege:piece-rescue`；`OWNER-FREEZE-2026-08-15 §5`。

## 8. 区域轰炸同步窗口

提交轰炸后一次性锁定三个不同落点和抽取编号，读取轰炸开始前快照，三个格逻辑同时受击。动画可以按编号依次播放，但不得改变命中、墙、位置或后续落点。

先基于同一快照判定将帅：一方死亡则对方胜，双方同窗死亡则平局，终止后续墙/旗。若无将帅死亡，再处理其他伤亡；炮击不触发任何被动士替死。抽取编号只决定伤害记录顺序，不把同步伤害改为顺序伤害。

追溯：`stmt:veilfront-xiangqi-siege:cannon-rules`、`stmt:veilfront-xiangqi-siege:piece-rescue`、`stmt:veilfront-xiangqi-siege:general-capture-rules`；`OWNER-FREEZE-2026-08-15 §4`。

## 9. 剩余 `unknown`

仍未冻结：单局完整轮上限；AI 搜索预算、决策随机性与难度。区域轰炸无冷却与相/象显形九格均已经项目所有者确认，不再属于开放项。

`stmt:veilfront-xiangqi-siege:implementation` 保持 `hypothesis`：规则核心/显示解耦、可复现种子、玩家投影与回放日志是待原型验证架构，不是正式架构批准。
