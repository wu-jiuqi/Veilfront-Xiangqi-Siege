# GATE-1 后正式架构审查 v1

状态：`draft / awaiting Project Brief v5 confirmation`

审查基线：`main@b6c8d85`、GATE-1 approval `8f93c3506192b1e286bd5f1bf631054f9fb3f0dc5337f3050716a2186a383597`

## 结论

GATE-1 已经证明复杂规则、确定性随机、按观察者过滤的 PlayerView、回放以及双机真人测试可行；但当前 `scripts/prototype/` 和 `scenes/prototype/` 仍是验证载体，不能直接认定为正式架构。

下一生产循环应先建立“规则域—对局用例—观察者投影—表现层—教学脚本—未来传输端口”的边界，并用一个可运行的新手教学灰盒证明这些边界能共同工作。互联网传输、服务器、Steam 网络接入和高成本批量美术不在该循环内。

## 已观察到的工程事实

- Godot 版本为 4.7.1，GDScript，GL Compatibility；当前主场景仍是 `scenes/prototype/network/lan_lobby.tscn`。
- 核心规则集中在 `scripts/prototype/core/`，已经具备种子化状态、合法行动、结算和 canonical digest。
- `player_view_projector.gd` 约 869 行，同时负责可见性、PlayerView、预览与 AI 投影，职责过宽。
- `rule_engine.gd` 约 755 行，`move_rules.gd` 约 580 行；规则已可测试，但状态仍主要通过通用 Dictionary 在模块间传递，正式演进时容易出现字段漂移。
- `gate1_logic_lab.gd` 约 859 行，兼有 UI 接线、选择/确认、AI 回合、联网模式和状态文本，是典型原型组合根。
- `match_controller.gd` 直接预加载 AI 模块并持有四档 AI Resource；这与“首版 Demo 不含 AI 人机对战”的新范围不一致。
- 场景已遵守一部分预置节点原则：大厅、棋盘壳、状态壳、确认框和网络会话均有 `.tscn`；但棋盘绘制和大量表现状态仍集中在单个 `Control` 脚本。
- `tests/prototype/`、1000-seed manifest、回放和独立 QA 证据具有正式迁移价值，应作为行为锁，而不是随目录重构一起丢弃。

## 资产处置决定

| 当前资产 | 决定 | 理由 |
|---|---|---|
| 规则、结算、信息边界文档 | 保留为行为事实源 | 已经绑定 GATE-1 与 owner rule revision 5 |
| `tests/prototype/` 与固定 seed | 保留并包装为迁移回归 | 能防止正式重构静默改变规则或随机消费顺序 |
| `core/`、`replay/`、`view/` | 逐模块提取，不原地改名 | 已验证但耦合和 DTO 边界尚未正式冻结 |
| `simulation/` | 保留为测试基础设施 | 适合批量回归，不属于玩家运行时 |
| `ai/` 与四档 AI 资源 | 冻结为研究资产 | 首版 Demo 不交付 AI，不再让它进入正式组合根 |
| `network/` LAN 工具 | 冻结为双机回归工具 | 不具备互联网会话、重连、部署或发布安全语义 |
| 原型大厅、逻辑实验室和状态 UI | 视觉参考后重做 | 文案、布局和入口都带有 GATE-1/AI/LAN 假设 |
| `board_surface.gd` | 拆为棋盘渲染、覆盖层和输入适配器 | 当前单脚本同时处理绘制、标记、镜像、迷雾与输入 |

## 建议的正式边界

```text
res://
├─ assets/
│  ├─ art/                    # 原始与导入后的游戏美术
│  └─ audio/
├─ resources/game/
│  ├─ rules/                  # 版本化规则配置 Resource
│  ├─ tutorials/              # 固定局面、步骤、提示与完成条件
│  ├─ ui/                     # Theme、样式和表现参数
│  └─ content/                # 棋子与反馈定义
├─ scenes/game/
│  ├─ app/                    # 正式启动与组合根
│  ├─ match/                  # 对局、棋盘、HUD 预置场景
│  ├─ tutorial/               # 教学关卡预置场景
│  └─ ui/                     # 菜单、弹窗、覆盖层子场景
├─ scripts/game/
│  ├─ domain/                 # FullState、规则、结算、确定性随机；不依赖 Node/UI/网络
│  ├─ application/            # 开局、提交 Intent、推进回合、重置与回放用例
│  ├─ projection/             # 按观察者生成 PlayerView 与可见事件
│  ├─ tutorial/               # 只编排正式 Intent/事件的脚本化教学
│  ├─ presentation/           # 场景控制器、输入和 ViewModel 适配
│  └─ ports/                  # MatchEndpoint、存档和未来传输接口；本轮不实现互联网适配器
├─ tests/game/                # 正式单元、契约、场景和迁移回归
└─ prototype/                 # GATE-1 只读参考，迁移完成前保留
```

### 依赖方向

`presentation/tutorial/未来网络适配器 → application → domain`，`application → projection`。`domain` 不得反向依赖 Godot 场景、AI、网络或教学；PlayerView 不得包含 FullState、规则 RNG、未发现旗位或可反推隐藏状态的种子。

### 数据和行动契约

- 运行时权威状态采用有版本的明确字段模型；跨边界只传规范化 Intent、领域 Event、PlayerView DTO 和 Replay Record。
- Dictionary 可以继续作为序列化 DTO，但创建和校验必须集中在工厂/codec，不能由 UI、教学或未来网络代码随意拼字段。
- 随机消费只发生在规则域的已命名结算点；教学脚本不得直接设置随机结果或写 FullState。
- 任何规则行为变化继续触发 GATE-1 的受影响回归；纯目录迁移必须保持 canonical state/event digest 等价。

## Godot 预置资产映射

| Contract 产物 | Godot 形式 | 建议路径 |
|---|---|---|
| 正式应用组合根 | 预置 `Control` 场景 | `scenes/game/app/game_app.tscn` |
| 对局棋盘与 HUD | 组合式预置场景 | `scenes/game/match/match_screen.tscn` |
| 棋盘、迷雾、特殊高亮、标记 | 独立子场景/覆盖层 | `scenes/game/match/board/*.tscn` |
| 教学关卡 | 预置教学场景 + Resource 数据 | `scenes/game/tutorial/tutorial_level.tscn`、`resources/game/tutorials/*.tres` |
| 规则与内容参数 | 自定义 Resource | `resources/game/rules/`、`resources/game/content/` |
| 运行时棋子与旗帜 | PackedScene 动态实例 | 数量和状态由权威对局数据决定，允许动态生成 |
| 视觉基线 | Theme、样片场景、资产清单 | `resources/game/ui/`、`scenes/review/`、`docs/art/` |

固定 UI 结构、弹窗、容器、相机和教学步骤展示必须预置；只有由对局状态决定数量和生命周期的棋子、虚影、迷雾单元及临时轨迹允许动态实例化。

## 教学架构

教学由 `TutorialScenario` Resource 描述初始快照、观察者、步骤、允许的 Intent 集、完成条件、提示键和重置点。`TutorialDirector` 监听正式领域 Event 并开放或关闭玩家意图，但不调用内部吃子、揭雾或夺旗函数。

第一版灰盒建议覆盖：

1. 交点选择、移动、确认与取消；
2. 迷雾、旗帜发现记忆与私人标注；
3. 城墙禁入、缓冲区和破墙；
4. 车路径视野、相田阻挡和隐身马接触；
5. 炮击、夺旗进度与士献祭复活；
6. 胜负、失败、重置和退出。

每一步必须可以从固定 seed 重放，失败后回到已声明的 checkpoint；脚本化敌方行动也必须提交规范化 Intent。

## 视觉生产边界

下一循环只生产视觉基线、Demo 资产清单、规格模板和少量游戏内样片，用于确认角色比例、棋盘可读性、迷雾层次、阵营颜色、特效强度、UI 字体与目标分辨率。GATE-2 前不批准全套棋子动画、完整音频、批量特效或外包订单。

资产清单必须至少记录：资产 ID、用途、尺寸/帧率、变体数、源文件、导入设置、依赖、占位状态、验收截图和负责人。

## 本轮明确不做

- 不选择或接入 Steam Networking、SDR、NAT 穿透、Relay 或专用服务器。
- 不设计匹配、账号、排行榜、观战、聊天、房主迁移和发布级反作弊。
- 不提升、训练或交付 AI 对手。
- 不批量生产最终高成本美术。
- 不静默修改规则、50 回合实验参数或已批准的信息边界。

## 下一循环迁移顺序

1. 冻结架构决定、正式 DTO 与目录所有权；建立不依赖 AI/LAN 的应用组合根。
2. 先迁移 canonical、seeded random、状态与 replay codec，并用旧测试做 digest 等价。
3. 按棋子/结算窗口拆分规则域，再迁移 PlayerView 投影；每一步保持旧原型可运行。
4. 创建正式棋盘/HUD 预置场景和表现适配器，不复制规则判断。
5. 以 Resource 驱动教学灰盒，验证脚本只走正式 Intent/Event 管线。
6. 制作视觉样片与完整 Demo 资产清单，形成 GATE-2 人工决策包。

## GATE-2 前必须回答

- 正式 DTO、回放和存档的版本策略是否足够支持后续联网适配？
- 教学灰盒是否覆盖高认知成本规则，且没有第二套规则或信息泄露？
- 棋盘/迷雾/特殊高亮在目标窗口尺寸下是否可读？
- Demo 美术清单是否可估算，样片是否值得启动批量生产？
- 若后续开始互联网循环，Steam 生态、权威服务器、重连和部署成本需要哪组独立技术 spike？

## 审查状态与下一合法动作

本报告不批准实现。先由项目所有者确认 Project Brief v5；再把该摘要绑定到下一循环 Contract，单独批准 Contract 后才能启动正式迁移。互联网实现仍需更晚的独立 Contract。
