# TASK-AI-001：AI 输入与审计契约 v1

状态：`prototype / hypothesis-bearing`
适用：GATE-1 可丢弃逻辑原型
事实依据：CTR-P1-001 v1、`stmt:veilfront-xiangqi-siege:single-player-ai`、`stmt:veilfront-xiangqi-siege:board-and-fog`

## 1. 结论与边界

AI 决策入口固定为：

```text
decide(AiPlayerView, AiPublicRules, AiMemory, ai_seed, AiDifficultyConfig) -> DecisionResult
```

入口不得增加完整棋局状态、规则随机流、场景树、规则核心节点、调试后门或任意状态查询回调。`AiPlayerView` 是技术负责人所拥有的单向玩家投影经 AI 白名单校验后的不可变副本；AI 层不实现、持有或反向查询完整状态。`AiPublicRules` 只含公开棋盘尺寸、公开棋子估值与公开行动类型偏置。`AiMemory` 只含该 AI 先前已知的行动 ID、行动访问次数和曾经可见棋子的观测回合。

机器学习、在线服务以及读取迷雾内敌棋、隐身马、隐藏炮架、未公开炮击格、未公开撤回格或规则随机流，均不在接口可达范围内。

## 2. `AiPlayerView` v1 白名单

根字段只有：`schema_version`、`decision_id`、`viewer_side`、`turn_index`、`visible_pieces`、`public_flags`、`public_walls`、`legal_actions`、`public_events`。任何额外字段使输入失效，决策器返回 `invalid_ai_input`，不会尝试忽略或透传。

- 可见棋子：公开 ID、阵营、类型、坐标、公开状态标签。
- 旗帜：公开 ID、坐标、归属、公开占领进度。
- 城墙：阵营与公开状态。
- 公开事件：事件 ID、类型、行动阵营与公开坐标，不允许自由载荷。
- 合法动作：公开动作 ID、类型、行动棋子、起终点、可见吃子、可见侦察格数量、是否占旗、是否攻击城墙、公开路径长度。

合法动作集合由信息边界层产生，必须已经满足“隐藏等价状态不可区分”的查询契约。AI 不自行向规则核心询问“某个试探动作是否合法”，从而避免以合法性差异探测隐藏炮架或隐身单位。

所有数组在构造时按公开稳定 ID 排序，字典按键规范化并深拷贝。输入投影摘要使用规范 JSON 的 SHA-256；调用者后续修改原始字典不会改变已构造视图。

## 3. 决策基线与专家档

首轮基线是人工编写的有界单层规则评分，不预测不可见单位：

1. 只在 `legal_actions` 白名单内选动作；候选超过预算时用独立 AI 种子确定性抽样。
2. 评分只使用可见吃子公开估值、公开侦察格数、公开占旗、公开攻墙、公开动作类型和 AI 自身行动访问次数。
3. 使用独立 AI 随机流加入可配置整数扰动；同分时以公开动作 ID 稳定决胜。
4. 不用墙钟截止驱动候选数量。墙钟时间在不同机器上会改变动作，本原型只审计时间预算提示，实际硬边界使用候选数。

规则随机种子和 AI 种子必须是不同随机流。建议技术集成层从“对局 AI 主种子 + 决策序号”派生本次 `ai_seed`，并把派生结果写入对局日志；不得把规则系统下一次随机结果或 RNG 对象传给 AI。

专家档仍使用完全相同的 `AiPlayerView` 白名单，不增加真值查询。它在完整公开候选集合上执行确定性的“可见战术一层评估”：模拟己方候选落点与已公开吃子，依据当前可见棋子估算落点攻击者/保护者、将帅暴露变化、前进与中心控制、旗点紧迫度，以及敌墙倒塌后的可见区域施压。不可见棋子不进入局面模型；因此该评估是公平的公开信息策略增强，不声称拥有完整信息极小化搜索。

## 4. 审计记录

每次成功决策返回 `ai-decision-audit-v1`：

- `input_projection_summary`：投影视角、回合、公开对象计数、合法动作数、投影 SHA-256；
- `public_rules_digest`、`memory_summary`、`decision_input_digest`；
- `budget`：候选预算、时间预算提示、可用数、实际评估数与策略模式；
- `candidate_sampling`：AI 种子与候选抽样记录；
- `candidates`：动作 ID、基础分、可见战术调整/分解、随机调整和最终分；
- `random_sampling`：随机扰动范围与抽样次数；
- `final_action`：最终动作 ID 和得分；
- `profile`：完整原型配置快照与 `conclusion_status=hypothesis`。

审计日志不得补录完整状态或隐藏真值。QA 如需配对比较，应在测试夹具侧保存隐藏真值，并只比较 AI 返回的输入摘要、动作和抽样记录。

## 5. 公平性不变量

必要不变量：隐藏状态 A 与 B 可以有不同的迷雾内敌棋和未公开随机结果；只要传给 AI 的 `AiPlayerView`、公开规则配置、AI 记忆、AI 种子和原型配置相同，则：

- `input_projection_summary` 完全相同；
- `decision_input_digest` 完全相同；
- 候选抽样、逐候选评分与随机抽样完全相同；
- 最终动作完全相同。

对应首轮内置断言位于 `tests/prototype/test_ai_fairness.gd`。独立 QA 仍须从真实规则核心构造隐藏等价配对黑盒测试，本测试不能替代 QA 验收。

## 6. 原型参数（非项目事实）

四个 `.tres` 仅为采证起点：

| 配置 | 候选上限 | 时间提示 | 随机分幅度 | 状态 |
|---|---:|---:|---:|---|
| low-budget | 8 | 8 ms | ±12 | hypothesis |
| default | 32 | 25 ms | ±4 | hypothesis |
| high-budget | 96 | 80 ms | ±1 | hypothesis |
| expert-tactical | 512 | 200 ms | 0 | hypothesis |

`expert-tactical` 额外启用 `visible-tactical-one-ply`，评估完整公开候选并记录每个候选的战术分解。四档均不是已冻结难度曲线；搜索预算、随机性、权重和难度命名必须由批量对局、性能证据、系统与体验负责人评审及 GATE-1 决策后另行确定。

## 7. 技术对接要求

技术负责人需要提供：

1. 从其 `PlayerView` 导出上述严格白名单字典的单向适配器；适配器位于信息边界/技术层，不位于 AI 层。
2. 每回合公开合法动作的稳定 ID，以及所有评分字段的公开来源说明。
3. 对局日志接收 AI 审计字典的入口；日志层只追加，不回传状态查询能力。
4. 决策后把已公开观测写入新的 `AiMemory` 快照；不要让 AI 记忆对象持有规则节点或完整状态引用。
5. 使用 Godot 4.7.1 执行：

```powershell
godot --headless --path . --script res://tests/prototype/test_ai_fairness.gd
```

若真实 `PlayerView` 无法在不泄露隐藏信息的情况下提供合法动作集合或某个评分字段，应移除该字段/评分项并提交配对证据，不得扩大 AI 信息权限。
