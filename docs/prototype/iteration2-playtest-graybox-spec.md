# GATE-1 Iteration 2 可丢弃灰盒试玩交互规格

## 1. 文档状态与决定绑定

- 状态：`prototype / iteration 2 / disposable_playtest_harness`。
- 适用 Loop：`LOOP-CTR-GATE1-VERTICAL-SLICE-001` v2，当前状态 `active / iteration 2`。
- 项目所有者修订记录：`approval:veilfront-xiangqi-siege:gate-1-revision:b67377e497d8`，subject digest `b67377e497d847aed0ae61759ba590be7229141a89829906981ffdd2796a4c3b`。
- 项目所有者本轮新增要求：最终人工试玩版在简单/中等/困难之外新增“专家”公平 AI，并把本轮试玩版随机回归保持为 100 个固定种子。本轮自动证据分为同一 seed 集合上的“四档 AI 单决策矩阵”和“规则压力完整对局”，两者互补但不得互相冒充。本要求不改写 Contract v2、QA-P1-003、Registry 或既有批准记录。
- 本轮默认完整回合上限临时改为 `50`，字段状态必须继续为 `hypothesis_cli_overridable`；它是人工试玩与批量验证起点，不是正式平衡规则，不得写为 `confirmed` 或 `frozen`。
- 本规格只补齐 GATE-1 人工试玩入口，不改变 `rules-spec-v1.md`、`settlement-order-v1.md`、`information-boundary-v1.md` 的玩法和结算语义。规则核心与显示解耦仍为 `hypothesis`。
- GATE-1 尚未批准。正式功能开发、正式 UI、美术、音频、动画及任何正式资产生产仍然禁止。
- 数量边界：100 个固定种子只是 Iteration 2 试玩版回归；Contract v2 与 QA-P1-003 仍要求 1000/1000。仅完成 100/100 后 Loop 必须保持 `active`，不得推荐或执行 `active -> review`。

## 2. 试玩目标与最小完成定义

灰盒必须让一名人类玩家选择简单/中等/困难/专家四档之一，与对应的 PlayerView 公平 AI 从固定种子开局，经过选择、预览、确认、结算、AI 回合和反馈，完整运行到三旗、将帅实际死亡或第 50 个完整轮边界的轮上限结算。试玩的目标是判断规则逻辑、信息反馈、AI 体验差异和核心循环是否合理，不评价正式视觉品质。

一次可验收试玩至少满足：

1. 可输入或沿用一个整数种子开始新局，并显示本局种子、代码版本和 `50（可覆盖假设）`。
2. 玩家阵营在开局时确定；红方始终先手，同一种子与配置必须得到同一阵营分配、旗位和后续确定性结果。
3. 人类能在开局前选择简单/中等/困难/专家，四档均能仅凭各自 PlayerView 接续完成行动，并产生可审计、可体验的差异。
4. 人类能仅凭界面完成合法或试探性行动、主动跳过及区域轰炸；AI 能接续完成其行动。
5. 对局能持续到规则终局，并清楚显示胜者、胜因、结束完整轮和对应玩家可见事件。
6. 同一种子、同一难度重开会清空选择、事件滚动、接触情报和上一局结果，不把上一局隐藏信息带入新局。

## 3. 不可突破的信息边界

唯一人类显示数据流保持为：

```text
FullState -> PlayerViewProjector.project(viewer_side) -> human PlayerView -> 灰盒显示/输入
```

- `MatchController` 私有持有 FullState；棋盘、状态栏、小地图、候选提示、确认框和试玩记录面板只能消费当前人类 `PlayerView` 的深复制及由该投影生成的公开行动预览。
- 种子、实际轮上限、规则/实现 revision 等需要显示的对局元数据必须作为 PlayerView 的公开白名单字段投影；若现有 `player-view-v1` 尚无这些字段，按第 10 节先做最小白名单扩展，不得另开 FullState 或控制器旁路。
- UI 脚本不得引用 `MatchState` 的 state/board/rng，不得调用完整真值 `RuleEngine.list_legal_actions()` 或 `MoveRules.generate_legal_actions()`，不得读取 `full_audit_event`、AI 评分、未来随机结果或隐藏碰撞缓存。
- 行动提示必须来自 `PlayerViewProjector.generate_action_intents(player_view)` 或等价的仅 PlayerView 适配器，并保留 `KNOWN_LEGAL / TENTATIVE / KNOWN_ILLEGAL` 三类含义。界面不得把 `TENTATIVE` 伪装成确定合法。
- 两个隐藏状态只要人类 PlayerView 相同，棋盘格、棋子、候选落点、颜色、按钮可用性、排序、提示文案、事件前缀和小地图必须相同。
- AI 只接收其阵营的 `AiPlayerView`、公开规则、AI 记忆、独立 AI 种子和 hypothesis 配置；人类 UI 不得看到 AI 的候选评分或审计内部字段。
- 难度不得扩大信息权限。简单/中等/困难/专家在相同 `AiPlayerView`、公开规则和记忆下获得相同公开候选全集；档位只改变 hypothesis 候选预算、随机扰动与公开战术评估模式。隐藏等价判据按“同一难度、同一 AI 种子”分别成立，不要求不同难度彼此选择相同动作。
- UI 只展示 `player_events[human_side]`、公开旗/墙/终局字段和规则授权的 `contact_intel`。开发者审计可另写受控文件，但不得进入画面、截图或玩家日志。

## 4. 预置场景与灰盒布局

固定界面结构优先预置在 `.tscn`，不得在运行时用 `Control.new()`、`Label.new()` 或 `add_child()` 临时拼装固定面板。允许动态更新格和棋子数据，不因此批准动态生成正式 UI。

```text
Gate1LogicLab
├─ Header：种子、AI 难度、阵营、行动方、完整轮 0/50、重新开始
└─ Workspace
   ├─ BoardShell
   │  ├─ OverviewStrip：同一 PlayerView 的只读导航概览
   │  ├─ BoardScroll：九路完整可见、沿 24 线长轴滚动
│  │  └─ BoardSurface：24 × 9 可交互交点、区域底色、城墙/视野边框与本地标注
   │  └─ ActionConfirm：行动类型、公开分类、目标、确认/取消
   └─ StatusShell
      ├─ TurnAndSelection
      ├─ WallStatus
      ├─ FlagStatus
      ├─ PieceStatus
      ├─ ActionMode：普通/炮击/跳过
      └─ PlayerEventLog
```

- 主棋盘使用冻结的 1-based 坐标 `X=1..9, Y=1..24`；底层坐标不随人类阵营翻转。若为黑方提供视觉旋转，只改变显示顺序，坐标标签和提交 intent 仍映射回固定坐标。
- 主棋盘必须完整显示九路宽度，交点横纵间距保持相等，并仅沿 24 线长轴滚动。所有普通行动和炮击的最终确认只在主棋盘完成。界面随窗口缩放调整棋盘点距、边距和辅助面板；空间不足时状态栏自身滚动，不得把主页面撑出安全区。
- OverviewStrip 只显示同一 PlayerView 的可见格、公开旗、公开墙界线和公开棋子简记；它只用于滚动定位，不得选择棋子、显示额外信息或确认行动。
- 风格限定为纯色、文本、线框和系统字体；不引入正式图标、贴图、字体、特效、动画或音效。

## 5. 棋盘、迷雾与棋子表示

每个格至少具有 `normal / hover / selected_origin / KNOWN_LEGAL / TENTATIVE / KNOWN_ILLEGAL / fog / last_contact / flag` 的可区分灰盒状态。表现规则如下：

- 棋盘各区域使用较亮的纯色块区分，不绘制普通区域分割线；区域内以不越界的半透明大字标注“大本营 / 缓冲区 / 战区”。城墙仍以加粗功能线表示。
- `visible_cells` 外统一覆盖黑色半透明格状蒙版，不显示敌棋占用、类型、资源或路径真值；可见格穿透蒙版，己方棋子仍按 PlayerView 自有信息显示。
- 己方棋显示阵营、棋种、简短 ID；己方炮额外显示 PlayerView 中的剩余弹药。后备棋显示在状态栏队列中，不占棋盘格、不可选择。
- 敌棋仅在 PlayerView 的 `pieces` 中出现时渲染；不得保留离开视野后的持续实体。规则授权的最后接触只作为 `contact_intel` 标记，不伪装为仍在该格的敌棋。
- 己方隐身马可显示“隐”状态；敌方隐身马只在 PlayerView 已授权显形时存在于画面。相/象显形九格只在 PlayerView 提供的公开检测格范围内显示灰盒描边。
- 特殊视野使用贴合交点网格线的战术描边：车仅以蓝色粗线标出从起点到终点的移动路径；相/象仅以黄色边框圈出起终点组成的田字格九点范围，不再为起点/终点中心 `3x3` 侦察并集另画边框。
- 旗帜只在进入观察者视野后显示；发现后以本方永久记忆图标保留在主棋盘和小地图。旗的所有权、`capture_progress/3` 与 `contested` 按信息边界公开，占领者 ID 为空时不得由界面猜测隐藏占领者。
- 红黑城墙分别显示 `INTACT / BREACHED / REPAIRING`。不得根据 FullState 额外显示隐藏入侵棋数量或修复内部计时；若 PlayerView 未公开进度，只说明规则状态和可公开的下一步条件。
- 未选中棋子时，右键交点打开圆形、叉形、方形本地标注；已选中棋子时，第一次右键只取消选中并消费该输入，下一次右键才可创建标注。标注不得覆盖行动高亮。

## 6. 人类行动闭环

### 6.1 行动开始与准备

每个行动开始先由控制器执行现有 `RuleEngine.prepare_action(state)`，完成 FIFO 后备自动部署，再投影并推送新的 human PlayerView。UI 只能收到更新后的投影；准备 token 保留在控制器私有边界内。界面不得在后备部署前缓存候选。

人类不是当前行动方、AI 正在结算或对局已终局时，所有棋盘提交控件禁用；滚动、查看公开状态和事件仍可用。

### 6.2 选择与候选

1. 单击当前 PlayerView 中己方、在场、存活且非后备的棋子，设为 `selected_origin`。
2. 只针对该棋子过滤稳定排序的公开 `ActionPreview`。`KNOWN_LEGAL` 与 `TENTATIVE` 均可进入确认；`KNOWN_ILLEGAL` 不可提交，但可用统一灰色表示几何候选，不显示真实失败原因。
3. 再次单击原棋或按取消清除选择；改选另一己棋直接替换选择。
4. 不提供免费探测、敌棋详情查询、全局合法真值列表或会因隐藏状态变化的鼠标/按钮反馈。

### 6.3 普通移动与特殊移动

- 玩家选择目标格后，确认框显示棋子、起点、终点、行动类型和公开分类。
- 特殊马、相/象、车、兵/卒不新增独立“技能按钮”；其是否按特殊规则解析由既有规则依据敌墙状态及起点/路径/终点区域决定，避免界面制造新的规则分支。
- 对 `TENTATIVE` 必须显示固定提示：“该行动受迷雾信息影响，提交后可能失败并消耗本次行动。”
- 提交 intent 形状保持 `{ piece_id, action_type: "move", target_cell, skill_type }`。FullState 解析后，以新的 PlayerView 和玩家事件刷新画面。
- 隐藏阻挡、马腿/象眼或炮路失败只显示既有统一类别结果，如“路线受到未知阻挡”或“炮路不成立”；不显示准确阻挡坐标、身份、数量或真实候选数。

### 6.4 区域轰炸

1. 选中己方炮后，仅当 PlayerView 公开条件满足“敌墙 `INTACT`、炮在己方大本营、该炮弹药大于 0”时启用“炮击”模式。
2. 炮击中心只能选 `X=2..8, Y=7..18`，保证完整 `3×3` 位于 `Y=6..19`。
3. 确认框只显示炮、中心和将消耗 1 发弹药；不得预览三个随机命中格、随机消费或隐藏目标。
4. 提交 `{ piece_id, action_type: "bombard", target_cell, skill_type: "area_bombardment" }`。三格命中与将帅/替死等结果只在规则结算并投影后显示。
5. 界面不得出现共享冷却、冷却倒计时或回营补弹。炮击与普通行动互斥。

### 6.5 跳过与确认保护

- “跳过”始终为公开可用行动，但必须二次确认，提交 `action_type: "pass"`；它消耗一次行动机会并参与城墙修复、旗进度及完整轮计数。
- 终局后拒绝任何新提交。提交期间锁定输入，避免双击产生重复行动；收到结算结果后才解除或进入 AI 回合。

## 7. AI 回合与节奏

- 最终人工试玩版必须提供四个开局前可选、局内锁定的 hypothesis profile：

| 试玩标签 | `profile_id` | 候选上限 | 随机分幅度 | 公开评分权重（侦察/旗/墙/重访惩罚） | 预期可观察差异 |
|---|---|---:|---:|---|---|
| 简单 | `prototype-low-budget-hypothesis` | 8 | ±12 | 2 / 16 / 6 / 1；可见局面评价 | 策略 Top K 较窄、最终动作扰动更明显 |
| 中等 | `prototype-default-hypothesis` | 32 | ±4 | 3 / 20 / 8 / 2；可见局面评价 | 候选覆盖与扰动居中 |
| 困难 | `prototype-high-budget-hypothesis` | 96 | ±1 | 4 / 24 / 10 / 3；可见局面评价 | 候选更宽、动作更接近局面评价排序 |
| 专家 | `prototype-expert-tactical-hypothesis` | 512 | 0 | 5 / 32 / 16 / 4；可见局面评价 | 覆盖最宽公开候选，规避可见送子并保护将帅 |

  以上标签只服务本轮人工试玩，不冻结正式难度曲线，也不保证胜率严格单调。时间预算仍只是审计提示，不能用墙钟截止改变确定性结果。
- “具可观察差异”的自动证据来自第 9.4 节 A 矩阵：四份配置摘要各不相同；在候选数足以触发预算差异的同一公开输入中，全部公开行动先完成预评分，关键动作受保护，实际深度评价候选通常符合 8/32/96/512 上限，并报告四档单次决策的 Top K 轨迹、八维局面评价与最终动作差异。A 矩阵不是完整对局，不报告也不推断胜负、胜因或局长。不得通过泄露隐藏状态为高难度制造差异。
- AI 回合开始时，控制器先完成同样的行动准备，再从 AI 自身 PlayerView 构造严格白名单输入并用独立 AI 种子决策。
- 人类界面显示“AI 行动中”，但只根据当前/后续 human PlayerView 更新；不得显示 AI 可见棋盘、候选数量、评分、搜索轨迹或 audit digest。
- 灰盒可提供“执行 AI 行动”按钮以便人工控制观察节奏；按钮只触发已确定权限内的一次 AI 决策，不提供探测或改写结果能力。默认也可自动执行一次，但不得使用墙钟差异改变确定性候选预算。
- AI 完成后先发布人类玩家视角事件与新 PlayerView，再开放人类输入。AI 无可提交候选时按既有跳过语义完成一次行动。

## 8. 状态、事件与终局反馈

状态栏始终由当前 human PlayerView 刷新：

- 当前行动方、玩家阵营、`action_index`、`full_round_index / 50`，并在 50 后附“试玩假设，可覆盖”。
- 双方墙状态；三旗所有权、争夺状态与进度；己方后备队列；当前选中棋与公开资源。
- 事件日志按 PlayerView 的 `player_events` 顺序追加，至少区分移动成功、消耗式失败、吃子/替死公开结果、炮击公开结果、墙状态变化、旗进度/易主、后备部署、跳过及终局。
- 事件文案可以解释公开结算顺序，但不得补全 PlayerView 中不存在的参与者、格或随机原因。
- 终局遮罩显示 `winner`、`win_reason`、结束完整轮、双方公开旗数，并提供“同种子重开”和“输入新种子”两项。将帅死亡、三旗和轮上限胜负文案必须互相可区分；双将帅同窗死亡显示平局。

## 9. 固定种子重开与试玩记录点

### 9.1 重开

- 种子输入只接受整数；空值或非法值不得开始。
- “同种子重开”使用完全相同的 seed、默认/CLI 覆盖的 round limit、代码版本和已选 AI profile。重新创建 MatchState、AI Memory、两条随机流及视图，不复用上一局节点状态数据。
- 切换难度必须开始新局；不能在同一对局中途改变候选预算或随机扰动。
- 开局显示本局配置摘要。CLI `--round-limit` 或同等测试入口仍可覆盖默认 50；UI 默认值不得覆盖显式 CLI 配置。

### 9.2 每局人工试玩记录

每场完整“人类 vs AI”试玩的受控本地记录至少包含：构建/提交标识、规则/实现 revision、种子、人类阵营、`full_round_limit_hypothesis=50` 或实际 CLI 覆盖值、AI 试玩标签、profile digest、候选预算、随机扰动范围、AI seed 引用、规范化 intent 序列、公开事件摘要、最终 winner/win_reason、完整轮数、重放摘要。完整审计与玩家可见记录分开保存；玩家界面和截图只能访问后者。

人工试玩负责形成完整人类对阵简单/中等/困难/专家四档 AI 的体验反馈。每档至少应完成可形成有效反馈的一局，但本轮不新增“四档各 100 局完整对局”之类的自动数量门槛；人工结果不得用来替代 A/B 自动证据。

### 9.3 人工观察点

试玩结束后绑定种子与行动日志，记录：

1. 是否能独立说清当前目标、墙状态、旗进度和胜负原因；
2. 移动—侦察—破城—炮击—争旗—吃将是否形成连贯选择，何处出现无意义等待；
3. 迷雾/隐身是否可推理，产生作弊感或界面故障感的具体回合；
4. 墙修复撤回、士替死、车多目标、炮击同步的先后是否能被复述；
5. 三旗与吃将是否都有可行战略，是否存在单一路径压倒其他选择；
6. 对局长度、思考负担、先手感受与随机挫败的峰值；
7. 分别记录简单/中等/困难/专家的公平感、挑战感、可感知差异及怀疑作弊时的具体可见证据；
8. 50 回合是否过短、过长或仅掩盖无进展，并给出希望调整到的候选值与理由。

以上为后续平衡证据，不自动冻结回合上限或改变规则。

### 9.4 本轮 100 固定种子自动证据口径

两条证据使用同一组 100 个固定种子，但测试对象、记录单位和允许结论不同。它们不得相加为 200 seeds，也不得把 A 的 400 records 当作 400 局完整对局。

#### A. PlayerView AI 单决策公平/差异矩阵

- 对同一组 100 seeds，分别运行简单/中等/困难/专家四个 profile，形成 `100 × 4 = 400` 条 seed-profile 单决策 records。
- 每条 record 使用规范化的公开 `AiPlayerView`、公开规则、AI 记忆、对应 profile 和派生 AI seed；隐藏等价配对可封装在同一条 record 中，验证同 profile、同输入、同 AI seed 时输入摘要、全量预评分、关键保护、Top K、局面评价和最终动作完全一致。
- 跨 profile 比较只用于证明候选预算、随机扰动、公开评分权重和最终动作存在可审计差异；不同档位不要求选择相同动作。
- A 是单决策矩阵，不推进完整对局，不要求合法终局，也不报告胜负、胜因、完整轮数或局长。它只支持四档 AI 的 PlayerView 公平性、确定性与参数差异结论。

#### B. 50 回合规则压力完整对局

- 对同一组 100 seeds，各运行一局 `rules_stress_full_state_policy` 的 50 回合上限完整对局，并执行确定性复跑与规定的 seed+intent 重放核对。
- B 报告 100/100 合法终止、胜负、胜因、完整轮数/局长分布、失败数、确定性差异和重放结果。
- `rules_stress_full_state_policy` 明确可读取 FullState 真值，只用于规则状态机、结算、终止、确定性和回放压力验证；它不是简单/中等/困难/专家任一 PlayerView AI，不得作为四档 AI 公平性、强度、胜率或体验差异证据。

#### 两条证据与人工试玩的关系

- A 回答“四档是否只看等价 PlayerView，且参数/单次决策差异是否可审计”。
- B 回答“规则核心在 100 个固定种子、50 回合假设下能否完整、确定、可重放地终止”。
- 人工试玩回答“完整人类 vs 四档 AI 是否形成可感知、公平且合理的体验”。人工试玩、A、B 互相补充，任何一条都不得代替另外两条。

## 10. 实现对接接口

沿用现有接口，不让 UI 跨过控制器边界：

| 目的 | 既有接口/约束 |
|---|---|
| 新建对局 | `MatchState.create(seed, {"full_round_limit_hypothesis": value})`，默认值改 50、状态仍为 `hypothesis_cli_overridable` |
| 人类投影 | `PlayerViewProjector.project(full_state, human_side)`；控制器经 `human_view_updated` 发深复制 |
| 公开试玩元数据 | 在 PlayerView 最小白名单中加入 seed 引用、实际 round limit、其 hypothesis 状态和规则/实现 revision；不投影 RNG 状态、未来抽样或完整 state digest |
| 公开候选 | `PlayerViewProjector.generate_action_intents(human_player_view)`，UI 仅过滤/呈现返回值 |
| 行动准备 | `RuleEngine.prepare_action(full_state)`，部署后必须重新投影 |
| 行动提交 | `RuleEngine.submit_action(full_state, intent, options)`；FullState 与 state summary 不返回 UI |
| AI 输入 | `PlayerViewProjector.export_ai_projection_from_view(ai_player_view)` |
| AI 难度 | 沿用三份 hypothesis 配置资源；档位选择只传配置，不改变投影、公开规则或候选生成权限 |
| 重放/证据 | 沿用 seed + 规范化 intent、事件与状态摘要链；玩家显示通道不接收 full audit |

若现有 PlayerView 缺少安全展示某项反馈所需的公开字段，应由技术负责人提出最小白名单扩展并增加隐藏等价配对测试；不得让 UI 直接读 FullState 作为临时捷径。

## 11. 验收清单

### 必须通过

- [ ] 默认新局显示并使用 `full_round_limit_hypothesis=50`，状态仍为 `hypothesis_cli_overridable`；CLI 覆盖仍有效。
- [ ] 24×9 主棋盘、固定坐标、迷雾、己/敌棋、旗、墙、回合、事件与终局均可由 human PlayerView 驱动显示。
- [ ] 人类可完成选棋、公开三级候选、确认/取消、普通与特殊移动、区域轰炸及主动跳过。
- [ ] `TENTATIVE` 成败都消耗行动；失败反馈固定且不泄露隐藏阻挡细节。
- [ ] 炮击不预演三格、不显示冷却；三个命中仍由既有同步结算窗口处理。
- [ ] AI 只用 AI PlayerView，AI 回合期间人类不能提交；回合结束只发布 human PlayerView 可见结果。
- [ ] 简单/中等/困难/专家四档均可从开局选取并完成一局；局内不可切换，四档使用同一 PlayerView 白名单和公开候选权限。
- [ ] 四档配置摘要不同，候选预算/随机扰动与 8/±12、32/±4、96/±1、512/0 的 hypothesis profile 一致，并由 A 单决策矩阵证明 PlayerView 公平性及差异可观察。
- [ ] 旗帜、城墙、后备部署、替死、车多目标和胜负反馈遵循既有结算顺序，没有 UI 自行推断或重新排序逻辑。
- [ ] 同种子同配置重开可复现初态；完整 seed + intent 重放的最终状态和事件摘要一致。
- [ ] 构造隐藏等价 FullState 配对时，灰盒画面、候选、按钮、提示、小地图和玩家事件在授权接触点前不可区分。
- [ ] 人工试玩分别对简单/中等/困难/专家形成完整人类对局与体验反馈，并绑定种子/版本；不要求四档各 100 局完整对局。
- [ ] A：同 100 seeds × 四档形成 400 条 PlayerView AI 单决策 records，完成隐藏等价公平性、同配置确定性及跨配置差异检查；不写胜负、胜因或局长。
- [ ] B：同 100 seeds 各完成一局 50 回合上限 `rules_stress_full_state_policy` 完整对局，100/100 合法终止，失败数 0、确定性差异 0，并报告胜负、胜因、局长和重放核对；不写成四档 AI 公平或强度证据。
- [ ] A 的 400 records 不是 400 场完整对局，B 的 100 场也不是四档 AI 对局；A、B 共用的固定 seed 门槛口径仍为 100，不能相加或冒充 1000。该结果不满足 Contract v2 门槛。

### 状态转换限制

- 当前 Contract v2 的 `CHECK-SIMULATION-001` 要求至少 1000 个固定种子；QA-P1-003 临时兼容条件也明确要求 1000/1000、失败数 0、确定性差异 0。
- 因此即使本规格所有灰盒检查、人工四档试玩、A 的 400 条单决策 records、B 的 100/100 规则压力完整对局和独立 QA 都通过，本轮状态仍为 `active`，结论只能写“Iteration 2 试玩版回归完成，Contract 门槛未满足”。
- 不得推荐进入 `review`，不得追加 `active -> review`，不得重建可提交的 GATE-1 决策包。
- 只有以下任一前置条件完成后，才可重新评估进入 `review`：
  1. 在当前 Contract v2 下补跑并通过 1000/1000 固定种子及其全部 QA-P1-003 条件；或
  2. 项目所有者另行批准 Contract 修订，明确改变种子门槛，并完成绑定新合同的迁移、回归与独立 QA。

### 明确不作为通过条件

- 正式视觉品质、正式动效/音效、手柄/移动端适配、无障碍最终方案、性能冻结、存档兼容、Steam 构建和资产完成度。
- 50 回合、AI 搜索预算、随机性或难度成为正式批准事实。
- 官方 Loop CLI 被记录为通过；QA-P1-003 仍按 Contract v2 的受控临时例外单独复检。

## 12. 回退与升级

- 若可试玩闭环要求改变玩法语义、胜负优先级、信息权限或 AI 可见信息，停止实现并返回 `TASK-SPEC-001`；由项目所有者另行决定，不得以 UI 便利为由静默修改。
- 若 PlayerView 无法安全表达必要反馈，先提交字段、可见条件和隐藏等价测试的最小变更请求。
- 若 50 回合批量或人工证据显示明显问题，只形成候选上限和理由；在项目所有者后续反馈前不继续调整。
- 灰盒、人工四档试玩、A 单决策矩阵、B 的 100/100 规则压力完整对局和独立 QA 通过后仍保持 `active`。只有补足当前 Contract v2 的 1000/1000，或完成项目所有者另行批准的 Contract 修订及迁移后，才可考虑 `active -> review`；任何路径都不能自动批准 GATE-1 或开始正式生产。

## 关联事实源

- `game-pipeline/approvals/gate-1-revision-b67377e497d8.yaml`
- `game-pipeline/loops/contracts/loop-contract-gate1-vertical-slice-v2.yaml`
- `docs/prototype/rules-spec-v1.md`
- `docs/prototype/settlement-order-v1.md`
- `docs/prototype/information-boundary-v1.md`
- `docs/prototype/gate1-observation-plan-v1.md`
- `docs/prototype/ai-input-contract-v1.md`
- `docs/prototype/godot-artifact-map-v1.md`
- `scripts/prototype/core/match_state.gd`
- `scripts/prototype/core/rule_engine.gd`
- `scripts/prototype/view/player_view_projector.gd`
- `scripts/prototype/match_controller.gd`
