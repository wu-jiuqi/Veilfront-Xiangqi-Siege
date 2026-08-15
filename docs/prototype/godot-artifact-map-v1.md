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
| `scenes/prototype/gate1_logic_lab.tscn` | `PackedScene` / `Control` | 逻辑实验室组合根；只连接预置 UI 壳和最小运行时状态适配脚本 | Godot 技术负责人 | 本轮创建 |
| `scenes/prototype/match_controller.tscn` | `PackedScene` / `Node` | 预置非 UI 对局控制器；隔离 FullState，向 Control 仅返回深复制 PlayerView | Godot 技术负责人 | Iteration 1 revision 3 已创建 |
| `scenes/prototype/board_shell.tscn` | `PackedScene` / `PanelContainer` | 棋盘逻辑占位区；固定标题、尺寸与说明，不预置 216 个数据格节点 | Godot 技术负责人 | 本轮创建 |
| `scenes/prototype/status_shell.tscn` | `PackedScene` / `PanelContainer` | 阶段、状态、旗帜、城墙和事件日志的固定占位 UI | Godot 技术负责人 | 本轮创建 |
| `resources/prototype/gate1_logic_lab_theme.tres` | `Theme` | 原型壳共享颜色、字号和 `StyleBoxFlat` 样式 | Godot 技术负责人 | 本轮创建 |
| `scripts/prototype/gate1_logic_lab.gd` | GDScript / Control 场景适配器 | 承载 216 格空白运行时数据并只消费 PlayerView；不引用 MatchState、board 或 rng | Godot 技术负责人 | Iteration 1 revision 3 信息边界已收紧 |
| `scripts/prototype/match_controller.gd` | GDScript / 非 UI 控制器 | 私有持有 FullState，绑定预置 `human_side=red`，通过预置信号推送深复制 PlayerView；UI 无 side 选择入口 | Godot 技术负责人 | Iteration 1 revision 3 已创建 |
| `tests/prototype/run_all.gd` | GDScript / 无头自检入口 | 验证工程入口可实例化、固定节点路径存在、216 格数据容器和种子回显一致 | Godot 技术负责人；结果由 QA 独立复核 | 本轮创建 |
| `scripts/prototype/*.gd.uid`、`tests/prototype/*.gd.uid` | Godot UID sidecar | Godot 4.7.1 首次扫描生成的脚本稳定资源标识；随对应脚本版本管理 | 对应脚本所有者 | 本轮由引擎生成 |
| `scripts/prototype/core/**` | GDScript / 纯规则探索 | `FullState`、完整行动真值生成、确定性随机、规则事务、版本化事件与状态摘要 | Godot 技术负责人 | Iteration 1 revision 3 已创建；可丢弃原型 |
| `scripts/prototype/view/player_view_projector.gd` | GDScript / 单向投影 | 白名单 `FullState -> PlayerView`、公开候选三级意图、AI DTO 导出 | Godot 技术负责人 | Iteration 1 revision 3 已创建 |
| `scripts/prototype/replay/replay_runner.gd` | GDScript / 重放入口 | 以 seed 或受控 FullState 快照 + 行动意图重建事件日志并核对最终摘要 | Godot 技术负责人 | Iteration 1 revision 3 已创建 |
| `scripts/prototype/simulation/match_simulator.gd` | GDScript / 规则压力模拟 | 仅内部 FullState 真值策略的确定性整局推进；不属于 AI 公平证据 | Godot 技术负责人 | Iteration 1 revision 3 已创建，模式固定标记为 `rules_stress_full_state_policy` |
| `tests/prototype/run_seeded_matches.gd` | GDScript / 批量入口 | `--seeds`、`--start-seed`、`--round-limit`、`--replay-samples`、`--manifest-path`；逐 seed 输出版本化 JSONL、双跑确定性、终局不变量与旗位分布 | Godot 技术负责人；QA 独立验收 | Iteration 1 revision 3 已创建 |
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
└─ SafeMargin (MarginContainer)
   └─ Page (VBoxContainer)
      ├─ HeaderPanel (PanelContainer)
      │  └─ HeaderMargin (MarginContainer)
      │     └─ HeaderRow (HBoxContainer)
      │        ├─ Title (Label)
      │        └─ SeedGroup (HBoxContainer)
      │           ├─ SeedCaption (Label)
      │           └─ SeedValue (Label)
      ├─ Workspace (HBoxContainer)
      │  ├─ BoardShell (预置场景实例)
      │  └─ StatusShell (预置场景实例)
      └─ Footer (Label)
```

`BoardShell` 与 `StatusShell` 各自封装一个清楚概念，固定结构全部写入 `.tscn`；主场景脚本不得调用 `Control.new()`、`Label.new()` 或 `add_child()` 生成固定 UI。

## 动态生成例外

| 动态内容 | 允许形式 | 理由与限制 |
|---|---|---|
| 24×9 共 216 格棋局状态 | `Array[int]` 或后续明确类型的数据对象 | 格状态是密集运行时数据，也是无头批量模拟输入；预置 216 个 UI 节点会把规则状态和显示树耦合，增加回放与测试风险。本轮只验证数据承载，不证明解耦架构已成立。 |
| 棋子、行动事件、玩家视角事件、随机消费记录 | 后续纯数据对象/值对象 | 数量、内容与生命周期由对局决定，需进入状态摘要与回放；不因数据动态而允许动态生成固定 UI。 |
| 测试中的场景实例 | 测试脚本从 `PackedScene` 临时实例化 | 无头测试必须创建并释放被测场景；这是测试生命周期，不是生产 UI 生成方案。 |
| `user://prototype/gate1/**` 输出 | 运行时按局生成日志文件 | 日志由种子与行动序列决定，不能作为预置资源；不得把未公开随机结果写入玩家可见日志。 |

目前没有批准任何程序化固定节点树、第三方 addon、正式资产、在线服务或 AI 文件动态注入例外。

## 可丢弃边界与未验证假设

- `scripts/prototype/**` 与 `scenes/prototype/**` 是 GATE-1 探索产物；进入正式功能开发前必须依据证据决定重写或保留，不能因为可运行就升级为正式架构。
- “确定性规则核心与显示层解耦”仍是 `hypothesis`。Iteration 1 revision 3 已增加传统棋子几何、特殊规则、投影白名单、完整行动真值生成、行动准备事务、整局终止模拟与抽样回放证据，仍需独立 QA 复核。
- `full_round_limit_hypothesis=8` 只是为了让固定批量命令在原型预算内终止的 CLI 可覆盖技术假设，不是平衡建议或冻结规则。
- 项目所有者已冻结“田字显形”为每次合法相象移动的起终点包围完整 3×3 九格（含起点、象眼、终点）；`reveal_cells_for_elephant_move` 不裁切该几何，投影对多枚相象的当前九格源取并集。
- 规则压力模拟明确使用 `rules_stress_full_state_policy`，只证明规则终止、状态不变量、统计与抽样回放，不作为 PlayerView AI 公平证据。
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
