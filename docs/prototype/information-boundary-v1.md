# 信息边界契约 v1

状态：`prototype / iteration 2 / owner-freeze revision 5`。目标是让 UI、AI 与 LAN 客户端只能看到玩家等价信息，并支持付费于一次行动的有限接触侦察。

冻结来源：`OWNER-FREEZE-2026-08-15` = `C:/Users/30114/.codex/attachments/dd52e25b-1af0-4fb5-90d1-a5315853a81c/pasted-text.txt`。

## 变更摘要

行动提示冻结为 `KNOWN_LEGAL / TENTATIVE / KNOWN_ILLEGAL`，玩家提交行动意图；隐藏路径、腿眼、目标棋、炮架和敌方相田字阻挡的解析与最小披露已有唯一规则。旗位按观察者发现记忆投影：未发现为空，发现后永久可见；可反推未发现旗位的规则种子仍永久留在主机 FullState/审计层。

## 1. 单向投影

唯一允许的数据流为 `FullState --Project(viewer_id)--> PlayerView`。UI、主棋盘、小地图、行动提示、公开日志和 AI 均不得持有 `FullState` 引用、全量序列化、RNG 内部状态或调试旁路；从 `PlayerView` 不保证能重建 `FullState`。

`PlayerView` 至少包含：

- 公开：棋盘尺寸/区域、当前行动方、完整轮计数、双方城墙公开状态、三旗所有权与占领进度、双方完整阵亡池、终局结果；不包含规则种子。
- 观察者记忆：每面旗均带 `discovered`；未发现时 `position=[]`，发现后 `position=[x,y]` 且永久保留。被吃虚影只投影给阵亡方并按行动序号到期。
- 自有：己方全部棋子（含后备队列）状态/永久资源及可见的己方临时状态；后备棋子无位置、无视野。
- 可见棋盘：己方大本营、己方棋子当前 `3x3` 动态视野、仍有效的己方车路径视野、己方相的起点/田字格/终点视野并集，以及“敌方城墙处于 `BREACHED` 或 `REPAIRING` 时敌方缓冲区与大本营全部格子”的并集；越界裁剪。移动后旧源立即移除，敌墙恢复 `INTACT` 后立即移除对应区域视野；无其他视野源即回雾。
- 敌方实体：只包含处于可见格且未隐身的敌棋；隐身马在任一有效己方相/象田字显形区内显形。多个相/象显形源取格集合并集。
- 可见事件：只包含公开事件、己方事件，或其全部必要实体/格在投影时可见的事件。

相/象视野源的投影定义为：对本次合资格合法移动起点 `O` 和终点 `D`，输出 `center3x3(O) ∪ field3x3(O,D) ∪ center3x3(D)`，投影时裁剪棋盘边界。己方 PlayerView 可取得自己的相侦察范围、田字阻挡范围及车条形路径，用于绘制不同颜色的特殊高亮边框；敌方不得取得这些源。敌方只能从车或兵/卒实际停在首个交点这一公开结果获知本次路径受阻。该棋下次移动开始或离场、死亡、回营、入队时旧源消失；敌墙倒塌移除能力时亦消失。

城墙区域视野严格按守方区域投影：红墙倒塌向黑方加入 `X=1..9,Y=1..8`，黑墙倒塌向红方加入 `X=1..9,Y=17..24`。`REPAIRING` 仍按倒塌处理；恢复 `INTACT` 后不保留记忆视野。该视野只令格子可见，不改变棋子的 `hidden` 状态，也不创建相/象显形源。

追溯：`stmt:veilfront-xiangqi-siege:board-and-fog`、`stmt:veilfront-xiangqi-siege:horse-elephant-rules`、`stmt:veilfront-xiangqi-siege:rook-rules`、`stmt:veilfront-xiangqi-siege:victory-and-flags`、`stmt:veilfront-xiangqi-siege:single-player-ai`；`OWNER-CONFIRM-2026-08-16:ELEPHANT-REVEAL-3X3`；`OWNER-CONFIRM-2026-08-16:BREACHED-WALL-REGION-VISION`。

## 2. 必须隐藏

迷雾内敌棋及类型/位置/资源；隐身马；观察者尚未发现的旗帜位置与可反推旗位的规则种子；未被当前投影授权公开的炮架；未公开随机结果（炮击抽点、主动士复活选择、复活/撤回落点在其公开前）；RNG 状态和未来抽样；敌方不可见相视野/阻挡区/路径源的内部标识；完整合法行动真值、碰撞缓存、评估分、状态摘要和调试日志。

炮击只在行动提交并到达公开结算点后发布被规则授权的结果；查询瞄准区域不得预演抽样。随机数消费次数和耗时不得进入 UI/AI 可观察字段。

## 3. 三级提示与行动意图

`ListActionIntents(PlayerView)` 只按已知信息返回：

- `KNOWN_LEGAL`：相关路径、目标、马腿/象眼或炮架区全部可见且确认合法；
- `TENTATIVE`：几何成立，但至少一个会影响真实合法性的格处于迷雾；
- `KNOWN_ILLEGAL`：仅凭可见信息即可确认非法。

玩家提交 `{ piece_id, action_type, target_cell, skill_type }`，不提交“必然合法”。服务端以 FullState 最终解析：

1. 车/炮普通移动等按其当前适用规则不可穿越隐藏占用者：失败、原地、消耗行动，仅提示“路线受到未知阻挡”，不公开坐标/类型。兵卒普通一格可直接吃掉终点隐藏敌棋；特殊兵卒 2..5 格可穿敌棋但不吃子、不打开路径视野，若终点被隐藏敌棋占用则按接触规则失败。特殊车仍按其可穿敌棋的路径歼灭规则解析。
2. 默认限制生效时，隐藏马腿/象眼造成同样的消耗式失败，不公开身份。
3. 本身允许吃子的移动以隐藏敌棋为目标时执行盲吃并进入目标格，战斗公开被吃棋身份。
4. 本身不能吃子的移动以隐藏棋为目标时失败并消耗行动；目标格写入一次最后已知接触记录，不持续追踪。目标若为隐身马，同时发生接触显形。
5. 炮精确吃子目标必须当前可见且同线。中间全可见且恰一炮架为 `KNOWN_LEGAL`，已知超过一枚为 `KNOWN_ILLEGAL`，其余含迷雾且已知 0 或 1 枚为 `TENTATIVE`。FullState 恰一枚则成功，否则失败并仅提示“炮路不成立”。

不存在免费探测按钮。接触信息只能由已提交并消耗行动的意图、实际命中或特殊侦察视野产生。

追溯：`stmt:veilfront-xiangqi-siege:board-and-fog`、`stmt:veilfront-xiangqi-siege:single-player-ai`；`OWNER-FREEZE-2026-08-15 §3`。

## 4. 错误、日志与 UI

- `ListActionIntents` 的输入只能是 `PlayerView` 与公开规则配置；相同规范化投影必须产生字节等价的三级提示。不得通过落点颜色、按钮启用、鼠标形状、路径线或排序提前暴露隐藏物。
- `TENTATIVE` 失败必须使用上述统一类别消息、固定字段集合和时序桶；不得回显准确阻挡坐标、身份、数量或真实候选数。规则明确允许的最后已知目标格/战斗身份只在行动消费后的接触结算点发布。
- 对局日志分为 `player_event(viewer)` 与仅供 QA 的受控 `full_audit_event`。UI、AI 只能订阅前者；发布/截图/小地图不得包含后者。
- 主棋盘完整显示九路宽度并沿 24 线长轴移动；普通行动和炮击最终确认只在主棋盘完成。小地图只渲染同一 `PlayerView` 的降采样结果，不得独立查询 FullState，也不得用于最终确认。
- 主棋盘使用交点命中与点状行动高亮；红黑客户端均将己方大本营旋转到屏幕底部。玩家右键圆/叉/方形标注只存在本机表现层，不写入 PlayerView、不联网同步，也不得覆盖行动高亮。
- 镜头自动定位、动画/音效占位、等待时间、错误次数均只能由可见事件驱动。

追溯：`stmt:veilfront-xiangqi-siege:presentation`、`stmt:veilfront-xiangqi-siege:board-and-fog`、`stmt:veilfront-xiangqi-siege:single-player-ai`；实现架构参考 `stmt:veilfront-xiangqi-siege:implementation`，其状态仍为 `hypothesis`。

## 5. AI 边界

AI 入口只能接收 `PlayerView`、公开规则配置、AI 自身记忆和独立 AI 种子。禁止接收 FullState、全局 RNG、迷雾敌棋、隐身马、隐藏炮架或未公开随机结果。每次决策记录：规范化 PlayerView 摘要、记忆摘要、全量候选预评分数、关键保护原因、确定性 Top K、八维可见局面评价、最终随机扰动及最终动作；预算/随机性/难度值均保持 `unknown` 可配置，不在本契约冻结。

## 6. 隐藏等价配对判据

对观察者 `v`，若 `Canonical(Project(F1,v)) == Canonical(Project(F2,v))`，则 `F1 ≡v F2`。配对允许修改且仅修改投影外字段，例如迷雾敌棋、隐身马、隐藏炮架、未来随机结果。

必须满足：

1. 所有只读查询、提示、错误外形、UI/小地图输出和玩家事件前缀相同。
2. AI 记忆与 AI 种子也相同时，候选动作、输入摘要和最终动作相同。
3. FullState 审计日志可以不同，但不得进入玩家/AI通道。
4. 两个 AI 在等价输入下必须选择相同意图；FullState 解析结果可因隐藏状态不同而不同。
5. 只有已提交行动在本契约第 3 节授权的接触结算点、视野变化或随机公开点后，两状态才允许不再等价；在该点前不得提前泄露。

## 7. 状态字段

`ActionPreview { classification, piece_id, action_type, target_cell, skill_type }`；`ContactIntel { cell, revealed_identity?, created_at_action_index, persistent_tracking=false }`。FullState、PlayerView、ActionPreview、日志和 AI 输入均不得包含阵营共享轰炸冷却字段、剩余计时或重置事件。轰炸资格提示只读取敌墙 `INTACT`、炮是否在己方大本营、该炮弹药；追溯 `stmt:veilfront-xiangqi-siege:cannon-rules` 与 `OWNER-CONFIRM-2026-08-15:BOMBARD-NO-COOLDOWN`。
