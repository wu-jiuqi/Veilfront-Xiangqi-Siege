# GATE-1 Godot 原型产物映射 v1

## 文档状态

- Contract：`CTR-P1-001` v1、`LOOP-CTR-GATE1-VERTICAL-SLICE-001` v1
- 对应工作：`TASK-MAP-001`、`STEP-003`
- 引擎基线：Godot 4.7.1，GDScript，桌面单机逻辑原型
- 文档所有者：`pos:veilfront-xiangqi-siege:technology:godot-technical-lead`
- 边界：本映射只定义可丢弃的 GATE-1 探索结构，不冻结正式功能架构、存档兼容、目标操作系统或发布配置。

## 路径、类型与所有权

| 路径 | Godot/产物类型 | 用途 | 所有者 | Phase 1 状态 |
|---|---|---|---|---|
| `project.godot` | 工程设置 | Godot 4.7.1 最小工程、原型主场景、窗口与渲染器设置 | Godot 技术负责人 | 本轮创建 |
| `scenes/prototype/gate1_logic_lab.tscn` | `PackedScene` / `Control` | Iteration 2 可丢弃试玩组合根；预置种子、配置、工作区与终局反馈节点 | Godot 技术负责人 | Iteration 2 灰盒已实现 |
| `scenes/prototype/match_controller.tscn` | `PackedScene` / `Node` | 预置非 UI 对局控制器；私有隔离 FullState/prepare token，并绑定现有低/默认/高预算 PlayerView AI hypothesis 资源 | Godot 技术负责人 | Iteration 2 灰盒已实现 |
| `scenes/prototype/board_shell.tscn` | `PackedScene` / `PanelContainer` | 预置 `ScrollContainer + GridContainer + 216 Button` 的 24×9 主棋盘、只读概览与行动确认区 | Godot 技术负责人 | Iteration 2 灰盒已实现 |
| `scenes/prototype/status_shell.tscn` | `PackedScene` / `PanelContainer` | 预置行动/选择、墙、旗、棋子、模式按钮、AI 单步和玩家事件面板 | Godot 技术负责人 | Iteration 2 灰盒已实现 |
| `resources/prototype/gate1_logic_lab_theme.tres` | `Theme` | 原型壳共享颜色、字号和 `StyleBoxFlat` 样式 | Godot 技术负责人 | 本轮创建 |
| `scripts/prototype/gate1_logic_lab.gd` | GDScript / Control 场景适配器 | 只消费深复制 PlayerView 与公开候选；渲染迷雾/棋/旗/墙/事件，驱动移动、炮击、跳过、AI 单步与固定种子重开 | Godot 技术负责人 | Iteration 2 灰盒已实现；无 FullState 旁路 |
| `scripts/prototype/match_controller.gd` | GDScript / 非 UI 控制器 | 私有持有 FullState 和 prepare token；投影 human/AI PlayerView，提交人类 intent，并以确定性独立 AI seed 驱动三档公平 AI 单步；最近一次完整 decision audit 仅由返回深复制的受控非 UI 测试接口读取，action id 无法映射时 fail-closed | Godot 技术负责人 | Iteration 2 灰盒已实现；审计不进入 PlayerView/UI/玩家日志 |
| `tests/prototype/run_all.gd` | GDScript / 无头自检入口 | 验证工程入口可实例化、固定节点路径存在、216 格数据容器和种子回显一致 | Godot 技术负责人；结果由 QA 独立复核 | 本轮创建 |
| `scripts/prototype/*.gd.uid`、`tests/prototype/*.gd.uid` | Godot UID sidecar | Godot 4.7.1 首次扫描生成的脚本稳定资源标识；随对应脚本版本管理 | 对应脚本所有者 | 本轮由引擎生成 |
| `scripts/prototype/core/**` | GDScript / 纯规则探索 | `FullState`、完整行动真值生成、确定性随机、规则事务、版本化事件与状态摘要 | Godot 技术负责人 | Iteration 1 revision 3 已创建；可丢弃原型 |
| `scripts/prototype/view/player_view_projector.gd` | GDScript / 单向投影 | 白名单 `FullState -> PlayerView`、公开候选三级意图、AI DTO 导出 | Godot 技术负责人 | Iteration 1 revision 3 已创建 |
| `scripts/prototype/replay/replay_runner.gd` | GDScript / 重放入口 | 以 seed 或受控 FullState 快照 + 行动意图重建事件日志并核对最终摘要 | Godot 技术负责人 | Iteration 1 revision 3 已创建 |
| `scripts/prototype/simulation/match_simulator.gd` | GDScript / 规则压力模拟 | 仅内部 FullState 真值策略的确定性整局推进；不属于 AI 公平证据 | Godot 技术负责人 | Iteration 1 revision 3 已创建，模式固定标记为 `rules_stress_full_state_policy` |
| `tests/prototype/run_seeded_matches.gd` | GDScript / 批量入口 | `--seeds`、`--start-seed`、`--round-limit`、`--replay-samples`、`--manifest-path`；逐 seed 输出版本化 JSONL、双跑确定性、终局不变量与旗位分布 | Godot 技术负责人；QA 独立验收 | Iteration 1 revision 3 已创建 |
| `tests/prototype/run_playtest_graybox.gd` | GDScript / 程序化交互烟测 | 实例化主场景并验证 216 个预置格、50 回合元数据、PlayerView 边界、人类移动、AI 单步、跳过、炮击、同种子重开，以及 AI audit 深复制与 PlayerView/UI/事件日志隔离 | Godot 技术负责人；QA 独立复核 | Iteration 2 灰盒已创建 |
| `tests/prototype/test_ai_difficulty_profiles.gd` | GDScript / 聚焦测试 | 逐档验证真实隐藏等价 PlayerView 配对产生同动作/同完整 audit、同 seed 完整 audit 复现、128 个纯公开候选夹具下实际评估上限精确为 8/32/96，并验证 profile config/audit digest 可观察差异与无法映射 fail-closed | Godot 技术负责人；QA 独立复核 | Iteration 2 灰盒已创建 |
| `tests/prototype/run_ai_difficulty_seed_matrix.gd` | GDScript / PlayerView AI 批量入口 | 100 固定 seed × 三档直接调用 `AiDecisionEngine`；逐记录验证公开候选映射/提交、完整 audit 确定复跑、真实隐藏等价公平性和档位差异，输出可审计 JSONL manifest/summary | Godot 技术负责人；QA 可独立复核 | Iteration 2 生产者公平性矩阵已创建；不是合同 1000 seeds |
| `resources/prototype/rules/**` | `.tres` 配置 | 后续可调但需序列化的原型规则默认值 | Godot 技术负责人；规则语义由系统与体验负责人验收 | 未创建；等待规则规格 |
| `tests/prototype/test_match_state.gd`、`test_rules_core.gd` | GDScript / 行为测试 | 冻结开局、旗生命周期、炮击、士替死、后备队列、墙修复时序 | Godot 技术负责人；QA 独立验收 | Iteration 1 定向覆盖已创建 |
| `tests/prototype/test_player_view.gd`、`test_replay.gd` | GDScript / 黑盒与确定性测试 | 隐藏等价投影/查询/错误/AI DTO 与 seed+意图重放一致性 | Godot 技术负责人；QA 独立验收 | Iteration 1 定向覆盖已创建 |
| `tests/prototype/test_elephant_reveal.gd`、`run_elephant_reveal.gd` | GDScript / 冻结显形规则定向测试 | 精确九格、不裁切、隐藏马区内外、多相象并集、刷新、离场清源与 PlayerView 隐藏等价 | Godot 技术负责人；QA 独立验收 | Iteration 1 revision 25 已创建 |
| `scripts/prototype/ai/**`、`resources/prototype/ai/**` | AI 脚本与配置 | 仅接收 `PlayerView` 的基线 AI 与参数 | 单机 AI 工程师 | 本岗位禁止编辑 |
| `user://prototype/gate1/**` | 运行时 JSONL/摘要 | 后续本机行动日志、玩家视角事件、随机抽样与回放输出 | Godot 技术负责人生成；QA 消费 | 未创建；只允许运行时写入 |
| `evidence/prototype/qa/**` | QA 原始证据与索引 | 独立命令、退出码、种子、批量对局与缺陷证据 | QA 与发布负责人 | 本岗位不写生产事实 |

`docs/prototype/rules-spec-v1.md`、`settlement-order-v1.md`、`information-boundary-v1.md` 与 `gate1-observation-plan-v1.md` 是实现输入，由系统与体验负责人拥有；本岗位只消费，不静默补写规则语义。

## 预置节点映射

```text
Gate1LogicLab (Control, 组合根；预置 Theme)
├─ MatchController (预置非 UI Node 场景实例；私有 FullState → PlayerView)
├─ Background (ColorRect)
├─ SafeMargin (MarginContainer)
   └─ Page (VBoxContainer)
      ├─ HeaderPanel (PanelContainer)
      │  └─ HeaderMargin (MarginContainer)
      │     └─ HeaderRow (HBoxContainer)
      │        ├─ Title (Label)
      │        ├─ SeedGroup (LineEdit / SeedValue / RestartButton)
      │        ├─ DifficultyGroup (预置简单 / 中等 / 困难 OptionButton)
      │        └─ MatchMeta (玩家 / 行动方 / 完整轮 / hypothesis)
      ├─ Workspace (HBoxContainer)
      │  ├─ BoardShell (OverviewStrip / BoardScroll / 24×9 BoardGrid / ActionConfirm)
      │  └─ StatusShell (墙 / 旗 / 选择 / 行动模式 / AI 单步 / PlayerEventLog)
      └─ Footer (Label)
└─ TerminalOverlay (胜者 / 胜因 / 完整轮 / 同种子或新种子重开)
```

`BoardShell` 与 `StatusShell` 各自封装一个清楚概念，含 216 个格子在内的固定结构全部写入 `.tscn`；主场景脚本只连接预置节点、更新 PlayerView 驱动的数据和样式，不调用 `Control.new()`、`Label.new()` 或 `add_child()` 生成固定 UI。

## 动态生成例外

| 动态内容 | 允许形式 | 理由与限制 |
|---|---|---|
| 24×9 共 216 格棋局状态 | `Array[int]` 或后续明确类型的数据对象 | 规则状态仍是密集运行时数据；Iteration 2 按批准灰盒规格另行预置 216 个纯显示/输入 Button，但 Button 不持有规则真值，不能进入摘要或回放事实源。 |
| 棋子、行动事件、玩家视角事件、随机消费记录 | 后续纯数据对象/值对象 | 数量、内容与生命周期由对局决定，需进入状态摘要与回放；不因数据动态而允许动态生成固定 UI。 |
| 测试中的场景实例 | 测试脚本从 `PackedScene` 临时实例化 | 无头测试必须创建并释放被测场景；这是测试生命周期，不是生产 UI 生成方案。 |
| `user://prototype/gate1/**` 输出 | 运行时按局生成日志文件 | 日志由种子与行动序列决定，不能作为预置资源；不得把未公开随机结果写入玩家可见日志。 |

目前没有批准任何程序化固定节点树、第三方 addon、正式资产、在线服务或 AI 文件动态注入例外。

## 可丢弃边界与未验证假设

- `scripts/prototype/**` 与 `scenes/prototype/**` 是 GATE-1 探索产物；进入正式功能开发前必须依据证据决定重写或保留，不能因为可运行就升级为正式架构。
- “确定性规则核心与显示层解耦”仍是 `hypothesis`。Iteration 1 revision 3 已增加传统棋子几何、特殊规则、投影白名单、完整行动真值生成、行动准备事务、整局终止模拟与抽样回放证据，仍需独立 QA 复核。
- `full_round_limit_hypothesis=50` 是项目所有者为 Iteration 2 人工试玩指定的临时默认值，仍属于 CLI 可覆盖技术假设，不是平衡建议或冻结规则；批量验证仍可通过 `--round-limit` 显式覆盖。
- 项目所有者已冻结“田字显形”为每次合法相象移动的起终点包围完整 3×3 九格（含起点、象眼、终点）；`reveal_cells_for_elephant_move` 不裁切该几何，投影对多枚相象的当前九格源取并集。
- 规则压力模拟明确使用 `rules_stress_full_state_policy`，只证明规则终止、状态不变量、统计与抽样回放，不作为 PlayerView AI 公平证据。
- `MatchController` 的 AI decision audit 含 profile/config digest、输入投影 digest、独立 AI seed、候选预算与实际评估数，只在控制器内部保留并由受控测试 getter 返回深复制；human PlayerView、Control 脚本、截图文本和玩家事件日志均无该旁路。
- 炮击采用项目所有者确认的无冷却规则。FullState、PlayerView、日志和摘要均没有共享冷却字段；资格只读取敌墙 `INTACT`、炮在己方大本营和该炮剩余弹药。
- `.tres` Theme 和三个 `.tscn` 只服务逻辑可读性，不代表正式 UI、主棋盘/小地图 UX 或视觉基线。

## 后续接口需求

1. 单机 AI 通过 `PlayerViewProjector.export_ai_projection_from_view()` 消费公开候选；核心为 1-based 冻结坐标，AI DTO 明确转换为 0-based。AI 整局证据由 AI 岗位独立提供。
2. QA 需要独立复核隐藏等价配对、事件/摘要重放、定向规则矩阵及固定 1000 seeds；技术岗位的 FullState 压力策略不替代 AI 公平性检查。
3. 项目经理需要继续处理 QA-P1-003 的 Loop 官方 runtime Snapshot validator 不匹配；本岗位不修改 Registry 或插件。
4. 项目所有者仍保留 GATE-1、回合上限冻结、显著长期架构取舍与平台承诺的批准权。

## Phase 1 验证记录

执行环境：`Godot Engine v4.7.1.stable.official.a13da4feb`。

| 命令 | 退出码 | Phase 1 观察结果 |
|---|---:|---|
| `godot --headless --path . --editor --quit-after 1` | 0 | 工程完成首次扫描，无解析、导入或资源加载错误；退出时出现 `Scan thread aborted` 警告，来源是 1 帧后强制结束编辑器扫描，不作为测试通过条件。 |
| `godot --headless --path . --quit-after 2` | 0 | 主场景启动并输出 `GATE1_PHASE1_READY seed=471001 cells=216 rules=not_implemented`。 |
| `godot --headless --path . --script res://tests/prototype/run_all.gd` | 0 | 主场景、预置子场景路径、接口、216 格数据和种子回显检查通过；明确输出 `rules=not_implemented`。 |
| `godot --headless --path . --check-only --script res://scripts/prototype/gate1_logic_lab.gd` | 0 | 场景适配脚本解析通过。 |
| `godot --headless --path . --check-only --script res://tests/prototype/run_all.gd` | 0 | 无头测试入口脚本解析通过。 |
| `validate_pipeline_contract.py game-pipeline/loops/contracts/CTR-P1-001-vertical-slice.yaml` | 0 | 输出 `OK`；批准 Contract 结构保持有效。 |

这些是生产者的技术自检记录，不替代 QA 独立验收，也不满足 STEP-004、CHECK-004 或 GATE-1。

## Iteration 1 revision 3 接口

- `MatchState.create(seed, configuration={})` 创建冻结 32 子阵型、红先和确定性三旗的 `full-state-v1`；默认轮上限字段显式标记为可覆盖 hypothesis。
- `RuleEngine.prepare_action(state)` 在生成行动前完成后备部署并返回绑定 `action_index/actor_side` 的 token；`submit_action(..., preparation_token)` 复用同一部署并写入事件，防止双部署或漏记。
- `MoveRules.generate_legal_actions(state, side, visibility_context)` 是内部完整真值生成器；`choose_legal_action_fast` 仅供规则压力模拟，逐候选通过同一真值校验。
- `PlayerViewProjector.project(state, side)` 对墙、旗、事件和棋子使用白名单投影；`generate_action_intents(view)` 只读 PlayerView 并返回稳定排序的三级公开候选。
- `PlayerViewProjector.export_ai_projection_from_view(view)` 输出 `player-view-ai-v1`，不传 FullState、隐藏实体或完整合法真值。
- `ReplayRunner.capture(seed, intents)`、`capture_from_state(initial_state, intents)` 与 `replay(recording)` 核对部署/随机/行动事件、版本化执行结果 digest 和最终状态摘要，并拒绝四类篡改。
- `MatchSimulator.run_match(seed, options)` 与 `run_seeded_matches.gd` 输出 `simulation_mode=rules_stress_full_state_policy`；Gate 批次对每 seed 双跑摘要确定性、对固定样本做完整行动回放，可用 `--manifest-path` 生成 QA 可保存的逐局 manifest，明确不属于 AI 公平证据。

## Iteration 1 revision 3 生产者自检

| 命令 | 退出码 | 结果 |
|---|---:|---|
| `godot --headless --path . --script res://tests/prototype/run_move_rules.gd` | 0 | 全量己方棋子×216 格移动/炮击 oracle 与生成器规范 ID 集合全等；代表动作提交与四类 fast-policy 状态通过；Godot 内耗时约 7.8 秒。 |
| `godot --headless --path . --script res://tests/prototype/run_all.gd` | 0 | 主场景、UI/FullState 边界、规则、投影、回放、整局、准备事务与 AI 套件通过；无 `SCRIPT ERROR/ERROR`；仍输出 `full_gate1=false`。 |
| `godot --headless --path . --script res://tests/prototype/run_seeded_matches.gd -- --seeds 10 --replay-samples 2 --manifest-path user://prototype/test-output/seeded_manifest_smoke_v3.jsonl` | 0 | 10/10 完成，逐 seed 双跑确定性 10/10、差异 0，完整回放样本 2/2；准确旗带计数 11:5 / 12:5；输出 10 条版本化记录。 |
| `godot --headless --path . --script res://tests/prototype/verify_seeded_manifest.gd -- --path user://prototype/test-output/seeded_manifest_smoke_v3.jsonl` | 0 | manifest 记录数 10，writer/verifier 使用同一 canonical record-lines digest。 |
| 上述 verifier 加 `--force-record-tamper` | 1 | 单条记录篡改负控被 `manifest_count_or_digest_mismatch` 拒绝。 |
| `godot --headless --path . --editor --quit-after 1` | 0 | Godot 4.7.1 编辑器导入通过；仅出现强制短退时既有 `Scan thread aborted` 警告。 |
| `godot --headless --path . --quit-after 2` | 0 | 主场景输出 `core=prototype_core_revision3 full_gate1=false`。 |

这些仅是技术生产者自检，不替代 QA 固定 1000 seeds、最终 manifest 保存或 GATE 决定。

## Iteration 1 revision 25 田字显形修订自检

| 命令 | 退出码 | 结果 |
|---|---:|---|
| `godot --headless --path . --script res://tests/prototype/run_elephant_reveal.gd`（修订前） | 1 | 定向红灯确认旧实现会裁切九格，且普通相象移动、多源并集与刷新未满足冻结语义；失败由进程退出码传播。 |
| 同上（修订后） | 0 | 精确九格、不裁切、区内/区外隐藏马、多相象并集、移动刷新、受阻移动开始清旧源、死亡/救援/回营/撤回/入队清源及隐藏 FullState 投影等价通过。 |
| `godot --headless --path . --check-only --script res://scripts/prototype/core/move_rules.gd`、`rule_engine.gd`、`run_elephant_reveal.gd`、`run_all.gd` | 0 | 所有本轮变更脚本在 Godot 4.7.1 下解析通过。 |
| `godot --headless --path . --script res://tests/prototype/run_all.gd` | 0 | 10 个 focused suites 全部通过；含规则、PlayerView、重放、显形、模拟、prepared action 与 AI 公平套件，无 `SCRIPT ERROR`。 |
| `godot --headless --path . --script res://tests/prototype/test_ai_fairness.gd` | 0 | 真实 PlayerView 隐藏等价、多决策公开审计与小轮上限整局复核通过。 |
| `godot --headless --path . --script res://tests/prototype/run_seeded_matches.gd -- --seeds 10 --replay-samples 2 --manifest-path user://prototype/test-output/elephant_reveal_revision25_smoke.jsonl` | 0 | 10/10 完成且双跑确定性 10/10、差异 0；完整行动重放样本 2/2，`records_digest=e6f8dfccdccb68f12733368c47fc5ef18c37396d5e2f555c8323c6f179b0703e`。 |

本轮按授权暂不运行 1000 seeds；固定批次和最终证据仍由独立 QA 执行并保存，不将上述小样本升级为 GATE 结论。

## Iteration 2 可丢弃试玩灰盒生产者自检

三档只映射既有公平 AI hypothesis 资源，不增加 FullState 输入或墙钟预算：

| 灰盒档位 | 资源 profile | 候选上限 hypothesis | 随机分跨度 hypothesis |
|---|---|---:|---:|
| 简单 | `prototype-low-budget-hypothesis` | 8 | 12 |
| 中等 | `prototype-default-hypothesis` | 32 | 4 |
| 困难 | `prototype-high-budget-hypothesis` | 96 | 1 |

三档共用严格白名单 `AiPlayerView`、公开规则、各局重置的 AI memory 和由固定 match seed + decision id 派生的独立 AI seed。同一 seed、档位和行动序列可确定复现；档位差异仍是试玩 hypothesis，不代表正式难度或平衡冻结。

| 命令 | 退出码 | 结果 |
|---|---:|---|
| `godot --headless --path . --quit-after 3` | 0 | 主场景加载并报告 216 个预置交互格、默认回合上限 50、`hypothesis_cli_overridable`。 |
| `godot --headless --path . --editor --quit-after 3` | 0 | Godot 4.7.1 首次扫描完成；短退仍报告既有 `Scan thread aborted`，并为四个既有脚本提示/重建缺失 UID 缓存。自动生成且不属本任务的 sidecar 已移除，不将警告记为无警告通过。 |
| `godot --headless --path . --script res://tests/prototype/run_playtest_graybox.gd` | 0 | PlayerView 元数据/信息边界、人类移动、AI 单步、主动跳过、区域炮击、同种子重开及三档 UI 绑定/单步均通过；逐档验证 audit 上下文/预算、测试 getter 深复制，以及 audit 未进入 human PlayerView、玩家事件日志或 UI 脚本。 |
| `godot --headless --path . --script res://tests/prototype/run_all.gd` | 0 | 11 个规则、迷雾、重放、模拟、准备事务、公平 AI 与三档聚焦套件全部通过；三档套件含真实隐藏等价配对、完整 audit 复现和 8/32/96 实际评估上限。 |
| `godot --headless --path . --script res://tests/prototype/run_ai_difficulty_seed_matrix.gd -- --seeds 3 --start-seed 471001 --manifest-path user://prototype/test-output/player_view_ai_seed_matrix_smoke_3x3.jsonl` | 0 | 3 seed × 三档小样本共 9 条记录，非法映射、提交失败、确定性差异和隐藏等价差异均为 0；实际评估平均/最小/最大精确为 8/32/96。 |
| `godot --headless --path . --script res://tests/prototype/run_ai_difficulty_seed_matrix.gd -- --seeds 100 --start-seed 471001 --manifest-path user://prototype/test-output/player_view_ai_seed_matrix_100x3.jsonl` | 0 | 100 固定 seed × 三档共 300 条 PlayerView AI 单决策记录；非法映射、提交失败、完整 audit 确定性差异、隐藏等价动作/audit 差异均为 0。三档实际评估总数为 800/3200/9600，easy/medium/hard 动作两两差异 seed 数为 84/92/86，`records_digest=a5d4f6235a8652cd86eb7d303f568a50409a8b83f07e600fc4da275073f9e02a`。这是生产者公平性矩阵，不是独立 QA、完整对局回归或合同 1000 seeds。 |
| `godot --headless --path . --script res://tests/prototype/run_seeded_matches.gd -- --seeds 3 --start-seed 471001 --round-limit 50 --replay-samples 1 --manifest-path user://prototype/test-output/iteration2_graybox_smoke_50.jsonl` | 0 | 3/3 完成，确定性差异 0，1/1 完整重放；这是生产者小样本，不是 1000 seeds 门禁证据。 |
| `godot --headless --path . --script res://tests/prototype/run_seeded_matches.gd -- --seeds 100 --start-seed 471001 --round-limit 50 --replay-samples 10 --manifest-path user://prototype/test-output/iteration2_playtest_100_seed_smoke.jsonl` | 0 | Iteration 2 试玩回归 100/100 完成、失败 0、确定性差异 0、重放 10/10；红胜 6、黑胜 6、轮限平局 88，`records_digest=68c6a92f7fad4091b0e5353a04fa08b3617950dad3958cdcbff754546f85b2e8`。仅为 `rules_stress_full_state_policy`，不替代 AI 公平测试或合同 1000 seeds。 |
| 同一批量入口使用 `--seeds 1 --round-limit 2 --replay-samples 0` | 0 | 输出实际 `full_round_limit_hypothesis=2` 且在第 2 完整轮终止，证明 CLI 覆盖仍有效。 |

项目所有者现将最终人工试玩版的随机回归工作目标调整为 `100` 个固定种子；这不修改 LOOP Contract v2 和 QA-P1-003 仍明确要求的 `1000` seeds。因此，即使后续 100/100 且确定性差异为 0，也只能形成 Iteration 2 试玩回归证据，不能声称满足合同、不能据此返回 `review`，更不能批准 GATE-1。Contract 修订或继续执行 1000 seeds 仍需另行处理。

当前生产者侧已完成 100 固定种子规则压力回归和 100×三档 PlayerView AI 单决策公平性矩阵。剩余必须项仍包括项目所有者人工试玩与独立 QA；若目标仍是按现有 Contract v2 返回 `review`，还必须补齐合同要求的 1000 seeds、确定性差异 0 等全部证据。灰盒自检不允许自动返回 `review` 或批准 GATE-1。
