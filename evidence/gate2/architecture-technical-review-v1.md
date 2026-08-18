# GATE-2 正式架构技术审阅 v1

结论：`approved`

审阅时间：`2026-08-18T12:04:11.8696672+08:00`

## 审阅身份与边界

- 执行 Position：`pos:veilfront-xiangqi-siege:technology:godot-technical-lead`
- Agent Instance：`inst:01M02NJ3JEQXKV6PT6DPX0NKQ0`
- Authority：`AUTH-VEILFRONT-GODOT-TECHNOLOGY`
- 任务来源：`game-pipeline/loops/evidence/GATE2-architecture-review-assignment.md`
- 本结论只回答正式架构在 Godot 4.7.1 下是否技术可行、是否可以作为第二生产循环的输入；不批准 GATE-2，不批准互联网实现，也不替代独立 QA。

## 绑定基线

| 产物 | 审阅绑定 |
|---|---|
| Project Brief v5 | subject digest `41bb82fae4f1a0294d17746f3b9caf063ee69d2bd07e0f7d15d26baad9ab89bb`；approval `approval:veilfront-xiangqi-siege:project-brief:41bb82fae4f1` |
| Loop Contract | `LOOP-CTR-FORMAL-FOUNDATION-GATE2-001@v1`；approved source digest `9beb91baa720820d0f0985019e5a77a4e0e065a8721451eedc30e0cc22bdeaef`；approval `approval:veilfront-xiangqi-siege:loop-contract:9beb91baa720` |
| GATE-1 | approval subject digest `8f93c3506192b1e286bd5f1bf631054f9fb3f0dc5337f3050716a2186a383597` |
| 被审架构报告 | `docs/architecture/post-gate1-formal-architecture-review-v1.md`；文件 SHA-256 `9e8d7c14aef5f5bb7e46d74fb9d3a1c1321e04967b70a14591801a78c30f60f1` |
| 审阅仓库水位 | `main@0a544ff60f0f18c2ab7656ffd60807684c69c6a6` |

只读预检结果：项目实例与插件锁为 `normal`；Project Brief validator 返回 `valid / confirmed / ready`，摘要与审批一致；Godot 工程声明 4.7.1、GDScript、GL Compatibility，当前主场景仍为 LAN 原型入口。

## 技术结论

架构报告提出的边界与迁移策略能够在当前工程中落地，并满足本轮“不实现互联网、不交付 AI、不启动批量美术”的范围。批准的目标依赖方向应冻结为：

```text
预置场景 / 表现适配器 / 教学驱动 / 测试端点
                    │
                    ▼
             application facade
               │             │
               ▼             ▼
             domain       projection
                               │
                               ▼
                     domain 的只读状态契约
```

未来传输适配器与当前教学驱动都只能依赖 application 暴露的端口。`domain` 不依赖 `Node`、`Control`、场景、教学、AI、LAN 或未来传输；application 不依赖具体场景或传输实现。Godot 的 `RefCounted`、`Vector2i` 和容器可用于进程内实现，但所有跨边界数据必须经过版本化 codec，不能把 Godot 对象引用或 SceneTree 生命周期写入 DTO。

## 分项审阅

| 检查项 | 结果 | 技术判断与证据 |
|---|---|---|
| 依赖方向 | 通过，带实施护栏 | 当前原型确有 `rule_engine.gd -> player_view_projector.gd -> move_rules.gd/match_state.gd` 的回环；报告没有把它误认成正式结构，并要求正式 domain 不反向依赖 projection。该回环必须先由 ITERATION-1 的架构决定拆解，不能机械搬运。 |
| DTO 边界 | 通过，待 ITERATION-1 冻结 | Intent、Domain Event、PlayerView、Replay Record 和 FullState 已被识别为独立边界，Dictionary 只能由集中工厂/codec 创建和校验。正式基线仍需补齐 schema version、必填字段、未知字段策略、失败码、canonical 编码和兼容矩阵，这是已批准 `TASK-ARCH-001` 的工作而非循环外前置。 |
| 规则 / 投影分层 | 通过 | 规则域独占 FullState、结算和随机消费；projection 只生成观察者视图及可见输出。与 Brief v5 的“权威端独占 FullState 与随机消费”一致。 |
| 教学分层 | 通过，带信息边界护栏 | Resource 驱动固定局面、步骤和 checkpoint，脚本行动仍提交正式 Intent，方向正确。教学表现不得订阅含隐藏事实的原始 Domain Event；必须消费观察者过滤后的 `VisibleEvent`/PlayerView，教学编排器如需权威事件推进也不得将其字段直接转交 UI。 |
| Godot 预置映射 | 通过，需 ADR 补全 | 正式应用、对局、棋盘/HUD、教学和覆盖层均映射为 `.tscn`，规则、教学和主题映射为 `.tres`，符合预置节点优先。棋子、旗帜、虚影和临时轨迹按运行时生命周期动态实例化合理；迷雾采用固定预置节点还是单一绘制层，须在 ITERATION-1 记录性能与可维护性理由。正式输入动作还必须进入 `project.godot` Input Map，不能仅在脚本中硬编码鼠标/按键。 |
| 迁移顺序 | 通过，需细化一个断环步骤 | 先迁移 canonical、确定性随机和 codec，再以固定 seed 做摘要等价，随后逐模块迁移规则与投影，风险顺序正确。实际执行时须先从原型 projector 中提取 domain 所需的可见性/接触判定策略，或把它改写为 domain 纯函数，再迁移 `rule_engine.gd`；否则会把现有回环带入正式目录。 |
| 回归策略 | 通过 | 当前仓库有 16 个 `test_*.gd`、14 个 `run_*.gd`、固定 seed manifest、回放测试及 1000-seed GATE-1 证据。Contract 已要求新旧 canonical state/event/PlayerView 摘要等价，并在触及规则或随机消费时重跑 1000-seed 与 manifest 篡改拒绝，足以作为迁移行为锁。 |
| 未来网络端口隔离 | 通过，带契约护栏 | 本轮只允许端口和测试替身，禁止 SDK、外部服务与互联网适配器。未来 MatchEndpoint 入站只接受规范化 Intent，出站只暴露对应观察者的 PlayerView、VisibleEvent 和无秘密的错误；不得输出 FullState、权威 replay、规则 RNG 状态或可反推旗位的 seed。 |
| 原型处置 | 通过 | AI 与 LAN 冻结、原型保留并逐模块提取而非原地改名，能保持已通过双机测试与 GATE-1 回归基线。正式组合根不再预加载 AI profile 或 LAN session。 |

## 缺陷、责任返回路径与重检要求

以下均为循环内必须关闭的技术缺陷；它们不阻止启动第二生产循环，但会阻止对应交付物完成或进入 GATE-2。

### TECH-ARCH-001：原型规则与投影存在反向依赖

- 严重度：`major / non-blocking-at-entry`
- 证据：`scripts/prototype/core/rule_engine.gd` 预加载并调用 `PlayerViewProjector`；projector 又预加载 `MatchState` 与 `MoveRules`。
- 风险：若直接复制，正式 domain 会依赖 projection，破坏权威规则边界，并使未来无头权威端与测试难以隔离。
- 责任：`pos:veilfront-xiangqi-siege:technology:godot-technical-lead`
- 返回路径：`ITERATION-1-ARCHITECTURE / TASK-ARCH-001`；若断环要求改变规则语义或信息边界，返回系统与体验负责人并升级项目经理，不能由技术实现静默决定。
- 重检：静态依赖检查证明 `scripts/game/domain/` 不引用 projection、presentation、tutorial、AI、LAN、network 或场景路径；domain 单测可无 SceneTree 运行。

### TECH-ARCH-002：教程事件出口必须区分权威事件与观察者可见事件

- 严重度：`major / non-blocking-at-entry`
- 证据：报告写明 `TutorialDirector` 监听正式领域 Event，但未明确 UI/提示接收的是过滤后事件；Brief 与 Contract 禁止通过提示、允许行动、音效或镜头泄露隐藏状态。
- 风险：原始 Domain Event 可能包含未发现旗位、隐身马、相田来源或其他仅权威端可见字段。
- 责任：技术负责人冻结 DTO 与投影出口；系统与体验负责人只使用批准的教学端口。
- 返回路径：先回 `TASK-ARCH-001` 定义 `VisibleEvent`/教学读取能力，再进入 `TASK-TUTORIAL-001/002`；若教学必须读取隐藏事实才能成立，按 Contract blocking condition 返回项目经理。
- 重检：对红、黑观察者分别运行事件投影与教学步骤测试，证明文案、提示键、允许 Intent 集、镜头和音效均不能反推未授权字段。

### TECH-ARCH-003：Replay 必须分权威记录与可分发记录

- 严重度：`major / non-blocking-at-entry`
- 证据：报告将 Replay Record 列为跨边界 DTO，但未区分用于确定性复现的权威日志与未来可交给玩家/客户端的观察者回放。
- 风险：权威 replay 通常含 seed、完整事件或隐藏状态；若直接复用为端口输出会突破 PlayerView 边界。
- 责任：`pos:veilfront-xiangqi-siege:technology:godot-technical-lead`
- 返回路径：`TASK-ARCH-001` 冻结 `AuthoritativeReplayRecord` 与 `ObserverReplayRecord` 的用途、codec 和访问权；`TASK-CORE-001/002` 实现并验证。
- 重检：权威 replay 保持 canonical 复现；观察者 replay 逐字段通过与实时 PlayerView 相同的信息边界检查，未来网络端口测试拒绝权威 replay 与 seed 下发。

### TECH-ARCH-004：Godot 输入与动态表现决策尚未进入正式映射

- 严重度：`minor / non-blocking-at-entry`
- 证据：报告已列 `.tscn/.tres` 映射，但未列 Input Map；“迷雾单元允许动态实例化”尚未记录固定 24×9 棋盘下采用动态节点、对象池或单一绘制层的理由。
- 风险：输入硬编码降低可测试性与可重绑定性；大量动态 Control 节点可能造成维护和绘制开销。
- 责任：`pos:veilfront-xiangqi-siege:technology:godot-technical-lead`
- 返回路径：`TASK-ARCH-001` 的 Godot artifact map/ADR 与 `TASK-SHELL-001`。
- 重检：Input Map 包含选择、取消/标记、镜头/滚动等正式动作；固定 UI 树来自预置场景；动态节点清单逐项有数量或生命周期理由，并通过场景树检查。

### TECH-ARCH-005：被审报告的状态文字已过时

- 严重度：`minor / administrative`
- 证据：报告头仍为 `draft / awaiting Project Brief v5 confirmation`，末尾下一动作仍要求确认 Brief 和批准 Contract；两项现已有不可变 approval。
- 风险：不影响技术方案，但若不绑定精确文件摘要，后续可能误判审阅对象或重复审批。
- 责任：`pos:veilfront-xiangqi-siege:root:project-manager`
- 返回路径：生产循环启动审计与 `INPUT-ARCH-REVIEW-001` 绑定记录。
- 重检：Registry/输入绑定同时记录本报告 SHA-256、本技术审阅和独立 QA 审阅；不得在不重检的情况下修改被审报告后仍沿用本结论。若要修正文案，应生成新版本并重新绑定审阅。

## 必须保留的实施护栏

1. `ITERATION-1-ARCHITECTURE` 必须先完成 DTO、依赖、端口、回放分级、Input Map 和 Godot artifact map 冻结，再开始规则主体迁移或教学接线。
2. 原型目录在迁移等价和 GATE-2 证据完成前保持可运行；不得原地移动、批量改名或让新正式测试只验证新实现自身。
3. 正式应用组合根不得预加载 AI profile、AI controller、LAN session 或网络协议；本轮端口只能连接进程内测试替身。
4. FullState 与权威随机状态只存在于 domain/application 权威侧。presentation、教学 UI 和未来客户端均只接收观察者 DTO。
5. 每个迁移切片至少比较相同 Intent 序列下的 FullState digest、Domain Event digest、红黑双方 PlayerView/VisibleEvent digest 与 replay 结果；任何不等价先回退该切片。
6. `project.godot` 的主场景切换只能在正式应用壳可无头加载且原型入口仍可显式运行后进行，不用入口替换掩盖迁移缺口。

## 下一合法动作

1. 等待 `pos:veilfront-xiangqi-siege:quality:qa-release-lead` 对同一 SHA-256 的架构报告完成独立 QA 审阅。
2. 若独立 QA 也是 `approved` 且没有阻断缺陷，由项目经理将被审报告摘要、两份审阅和现有 approval 绑定到 `INPUT-ARCH-REVIEW-001`，完成循环启动审计与 Registry 合法状态迁移。
3. 循环进入 `active` 后，技术负责人先执行 `ITERATION-1-ARCHITECTURE / TASK-ARCH-001`，并把 `TECH-ARCH-001` 至 `TECH-ARCH-004` 写入架构决定和重检矩阵；在这些护栏冻结前不进入核心迁移或教学接线。
4. 如果独立 QA 给出 `revision_required` 或发现信息边界不可验证，停止启动并按其责任返回路径修订；不得以本技术批准覆盖 QA 结论。

## 最终判定

`approved`：被审方案在 Godot 4.7.1、当前 GDScript 工程和已批准范围内技术可行，能够作为第二生产循环输入。上述缺陷均已有本循环内责任人、返回路径和可执行重检，不需要改变 Project Brief、Contract、规则或接入互联网即可关闭；因此没有技术阻断项。该结论不表示架构迁移、教学灰盒、视觉基线或 GATE-2 已完成。
