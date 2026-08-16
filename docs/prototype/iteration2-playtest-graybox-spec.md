# GATE-1 Iteration 2 可丢弃灰盒试玩交互规格

## 1. 文档状态与决定绑定

- 状态：`prototype / iteration 2 / disposable_playtest_harness`。
- 适用 Loop：`LOOP-CTR-GATE1-VERTICAL-SLICE-001` v2，当前状态 `active / iteration 2`。
- 项目所有者修订记录：`approval:veilfront-xiangqi-siege:gate-1-revision:b67377e497d8`，subject digest `b67377e497d847aed0ae61759ba590be7229141a89829906981ffdd2796a4c3b`。
- 本轮默认完整回合上限临时改为 `50`，字段状态必须继续为 `hypothesis_cli_overridable`；它是人工试玩与批量验证起点，不是正式平衡规则，不得写为 `confirmed` 或 `frozen`。
- 本规格只补齐 GATE-1 人工试玩入口，不改变 `rules-spec-v1.md`、`settlement-order-v1.md`、`information-boundary-v1.md` 的玩法和结算语义。规则核心与显示解耦仍为 `hypothesis`。
- GATE-1 尚未批准。正式功能开发、正式 UI、美术、音频、动画及任何正式资产生产仍然禁止。

## 2. 试玩目标与最小完成定义

灰盒必须让一名人类玩家与现有 PlayerView 基线 AI 从固定种子开局，经过选择、预览、确认、结算、AI 回合和反馈，完整运行到三旗、将帅实际死亡或第 50 个完整轮边界的轮上限结算。试玩的目标是判断规则逻辑、信息反馈和核心循环是否合理，不评价正式视觉品质。

一次可验收试玩至少满足：

1. 可输入或沿用一个整数种子开始新局，并显示本局种子、代码版本和 `50（可覆盖假设）`。
2. 玩家阵营在开局时确定；红方始终先手，同一种子与配置必须得到同一阵营分配、旗位和后续确定性结果。
3. 人类能仅凭界面完成合法或试探性行动、主动跳过及区域轰炸；AI 能接续完成其行动。
4. 对局能持续到规则终局，并清楚显示胜者、胜因、结束完整轮和对应玩家可见事件。
5. 同一种子重开会清空选择、事件滚动、接触情报和上一局结果，不把上一局隐藏信息带入新局。

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
- UI 只展示 `player_events[human_side]`、公开旗/墙/终局字段和规则授权的 `contact_intel`。开发者审计可另写受控文件，但不得进入画面、截图或玩家日志。

## 4. 预置场景与灰盒布局

固定界面结构优先预置在 `.tscn`，不得在运行时用 `Control.new()`、`Label.new()` 或 `add_child()` 临时拼装固定面板。允许动态更新格和棋子数据，不因此批准动态生成正式 UI。

```text
Gate1LogicLab
├─ Header：种子、阵营、行动方、完整轮 0/50、重新开始
└─ Workspace
   ├─ BoardShell
   │  ├─ OverviewStrip：同一 PlayerView 的只读导航概览
   │  ├─ BoardScroll：九路完整可见、沿 24 线长轴滚动
   │  │  └─ BoardGrid：24 × 9 可交互格
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
- 主棋盘必须完整显示九路宽度，并仅沿 24 线长轴滚动。所有普通行动和炮击的最终确认只在主棋盘完成。
- OverviewStrip 只显示同一 PlayerView 的可见格、公开旗、公开墙界线和公开棋子简记；它只用于滚动定位，不得选择棋子、显示额外信息或确认行动。
- 风格限定为纯色、文本、线框和系统字体；不引入正式图标、贴图、字体、特效、动画或音效。

## 5. 棋盘、迷雾与棋子表示

每个格至少具有 `normal / hover / selected_origin / KNOWN_LEGAL / TENTATIVE / KNOWN_ILLEGAL / fog / last_contact / flag` 的可区分灰盒状态。表现规则如下：

- `visible_cells` 外统一显示迷雾，不显示敌棋占用、类型、资源或路径真值；己方棋子仍按 PlayerView 自有信息显示。
- 己方棋显示阵营、棋种、简短 ID；己方炮额外显示 PlayerView 中的剩余弹药。后备棋显示在状态栏队列中，不占棋盘格、不可选择。
- 敌棋仅在 PlayerView 的 `pieces` 中出现时渲染；不得保留离开视野后的持续实体。规则授权的最后接触只作为 `contact_intel` 标记，不伪装为仍在该格的敌棋。
- 己方隐身马可显示“隐”状态；敌方隐身马只在 PlayerView 已授权显形时存在于画面。相/象显形九格只在 PlayerView 提供的公开检测格范围内显示灰盒描边。
- 三面旗始终显示公开坐标、所有权、`capture_progress/3` 与 `contested`；占领者 ID 为空时不得由界面猜测隐藏占领者。
- 红黑城墙分别显示 `INTACT / BREACHED / REPAIRING`。不得根据 FullState 额外显示隐藏入侵棋数量或修复内部计时；若 PlayerView 未公开进度，只说明规则状态和可公开的下一步条件。

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
- “同种子重开”使用完全相同的 seed、默认/CLI 覆盖的 round limit、代码版本和 AI profile。重新创建 MatchState、AI Memory、两条随机流及视图，不复用上一局节点状态数据。
- 开局显示本局配置摘要。CLI `--round-limit` 或同等测试入口仍可覆盖默认 50；UI 默认值不得覆盖显式 CLI 配置。

### 9.2 每局机器记录

受控本地记录至少包含：构建/提交标识、规则/实现 revision、种子、人类阵营、`full_round_limit_hypothesis=50` 或实际 CLI 覆盖值、AI profile/seed 引用、规范化 intent 序列、公开事件摘要、最终 winner/win_reason、完整轮数、重放摘要。完整审计与玩家可见记录分开保存；玩家界面和截图只能访问后者。

### 9.3 人工观察点

试玩结束后绑定种子与行动日志，记录：

1. 是否能独立说清当前目标、墙状态、旗进度和胜负原因；
2. 移动—侦察—破城—炮击—争旗—吃将是否形成连贯选择，何处出现无意义等待；
3. 迷雾/隐身是否可推理，产生作弊感或界面故障感的具体回合；
4. 墙修复撤回、士替死、车多目标、炮击同步的先后是否能被复述；
5. 三旗与吃将是否都有可行战略，是否存在单一路径压倒其他选择；
6. 对局长度、思考负担、先手感受与随机挫败的峰值；
7. AI 公平感、挑战感及怀疑作弊时的具体可见证据；
8. 50 回合是否过短、过长或仅掩盖无进展，并给出希望调整到的候选值与理由。

以上为后续平衡证据，不自动冻结回合上限或改变规则。

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
- [ ] 旗帜、城墙、后备部署、替死、车多目标和胜负反馈遵循既有结算顺序，没有 UI 自行推断或重新排序逻辑。
- [ ] 同种子同配置重开可复现初态；完整 seed + intent 重放的最终状态和事件摘要一致。
- [ ] 构造隐藏等价 FullState 配对时，灰盒画面、候选、按钮、提示、小地图和玩家事件在授权接触点前不可区分。
- [ ] 人类可从入口完成至少一局至规则终局或 50 完整轮上限，并形成绑定种子/版本的试玩记录。
- [ ] Godot 4.7.1 导入、主场景、定向交互测试、规则/迷雾/AI 公平/重放回归、50 回合固定 1000 seeds、确定性差异 0 与独立 QA 全部另行通过后，才可重新进入 `review`。

### 明确不作为通过条件

- 正式视觉品质、正式动效/音效、手柄/移动端适配、无障碍最终方案、性能冻结、存档兼容、Steam 构建和资产完成度。
- 50 回合、AI 搜索预算、随机性或难度成为正式批准事实。
- 官方 Loop CLI 被记录为通过；QA-P1-003 仍按 Contract v2 的受控临时例外单独复检。

## 12. 回退与升级

- 若可试玩闭环要求改变玩法语义、胜负优先级、信息权限或 AI 可见信息，停止实现并返回 `TASK-SPEC-001`；由项目所有者另行决定，不得以 UI 便利为由静默修改。
- 若 PlayerView 无法安全表达必要反馈，先提交字段、可见条件和隐藏等价测试的最小变更请求。
- 若 50 回合批量或人工证据显示明显问题，只形成候选上限和理由；在项目所有者后续反馈前不继续调整。
- 灰盒通过和独立 QA 通过只允许 `active -> review` 并重建 GATE-1 决策包，不能自动批准 GATE-1，也不能开始正式生产。

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
