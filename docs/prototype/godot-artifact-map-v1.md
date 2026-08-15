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
| `scenes/prototype/board_shell.tscn` | `PackedScene` / `PanelContainer` | 棋盘逻辑占位区；固定标题、尺寸与说明，不预置 216 个数据格节点 | Godot 技术负责人 | 本轮创建 |
| `scenes/prototype/status_shell.tscn` | `PackedScene` / `PanelContainer` | 阶段、状态、旗帜、城墙和事件日志的固定占位 UI | Godot 技术负责人 | 本轮创建 |
| `resources/prototype/gate1_logic_lab_theme.tres` | `Theme` | 原型壳共享颜色、字号和 `StyleBoxFlat` 样式 | Godot 技术负责人 | 本轮创建 |
| `scripts/prototype/gate1_logic_lab.gd` | GDScript / 场景适配器 | 承载 216 格空白运行时数据并把已公开的种子/状态摘要写入预置 Label | Godot 技术负责人 | 本轮创建 |
| `tests/prototype/run_all.gd` | GDScript / 无头自检入口 | 验证工程入口可实例化、固定节点路径存在、216 格数据容器和种子回显一致 | Godot 技术负责人；结果由 QA 独立复核 | 本轮创建 |
| `scripts/prototype/*.gd.uid`、`tests/prototype/*.gd.uid` | Godot UID sidecar | Godot 4.7.1 首次扫描生成的脚本稳定资源标识；随对应脚本版本管理 | 对应脚本所有者 | 本轮由引擎生成 |
| `scripts/prototype/core/**` | GDScript / 纯规则探索 | `FullState`、确定性随机、规则事务、版本化事件与状态摘要 | Godot 技术负责人 | Iteration 1 revision 2 已创建；可丢弃基础，不是完整规则核心 |
| `scripts/prototype/view/player_view_projector.gd` | GDScript / 单向投影 | `FullState -> PlayerView`、三级意图、AI 白名单 DTO 导出 | Godot 技术负责人 | Iteration 1 revision 2 已创建 |
| `scripts/prototype/replay/replay_runner.gd` | GDScript / 重放入口 | 以 seed + 行动意图重建事件日志并核对最终摘要 | Godot 技术负责人 | Iteration 1 revision 2 已创建 |
| `resources/prototype/rules/**` | `.tres` 配置 | 后续可调但需序列化的原型规则默认值 | Godot 技术负责人；规则语义由系统与体验负责人验收 | 未创建；等待规则规格 |
| `tests/prototype/test_match_state.gd`、`test_rules_core.gd` | GDScript / 行为测试 | 冻结开局、旗生命周期、炮击、士替死、后备队列、墙修复时序 | Godot 技术负责人；QA 独立验收 | Iteration 1 定向覆盖已创建 |
| `tests/prototype/test_player_view.gd`、`test_replay.gd` | GDScript / 黑盒与确定性测试 | 隐藏等价投影/查询/错误/AI DTO 与 seed+意图重放一致性 | Godot 技术负责人；QA 独立验收 | Iteration 1 定向覆盖已创建 |
| `scripts/prototype/ai/**`、`resources/prototype/ai/**` | AI 脚本与配置 | 仅接收 `PlayerView` 的基线 AI 与参数 | 单机 AI 工程师 | 本岗位禁止编辑 |
| `user://prototype/gate1/**` | 运行时 JSONL/摘要 | 后续本机行动日志、玩家视角事件、随机抽样与回放输出 | Godot 技术负责人生成；QA 消费 | 未创建；只允许运行时写入 |
| `evidence/prototype/qa/**` | QA 原始证据与索引 | 独立命令、退出码、种子、批量对局与缺陷证据 | QA 与发布负责人 | 本岗位不写生产事实 |

`docs/prototype/rules-spec-v1.md`、`settlement-order-v1.md`、`information-boundary-v1.md` 与 `gate1-observation-plan-v1.md` 是实现输入，由系统与体验负责人拥有；本岗位只消费，不静默补写规则语义。

## 预置节点映射

```text
Gate1LogicLab (Control, 组合根；预置 Theme)
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
- “确定性规则核心与显示层解耦”仍是 `hypothesis`。Iteration 1 revision 2 已用真实 FullState、PlayerView、行动事件和回放定向测试形成正向证据，但尚未经过完整棋子几何、全部结算组合、1000 完整对局与独立 QA 复核。
- 当前只实现冻结开局、正交移动探索接缝、三级意图中的路径阻挡、旗生命周期、同步炮击/将帅与士替死窗口、后备队列、墙修复计数、状态摘要和重放基础；不得据此声称完整 STEP-004、CHECK-004、CHECK-005 或 GATE-1 完成。
- 炮击采用项目所有者确认的无冷却规则。FullState、PlayerView、日志和摘要均没有共享冷却字段；资格只读取敌墙 `INTACT`、炮在己方大本营和该炮剩余弹药。
- `.tres` Theme 和三个 `.tscn` 只服务逻辑可读性，不代表正式 UI、主棋盘/小地图 UX 或视觉基线。

## 后续接口需求

1. 系统与体验负责人继续补充完整棋子几何、车路径逐目标、马/象限制与显形、炮精确吃子、普通士替死及轮上限配置输入；现有实现不得填充未知数值。
2. 单机 AI 通过 `PlayerViewProjector.export_ai_projection()` 消费真实投影；核心为 1-based 冻结坐标，AI 白名单适配层明确转换为 0-based。
3. QA 需要独立复核隐藏等价配对、事件/摘要重放以及本轮定向规则矩阵；1000 seeds 仍阻塞于完整合法行动生成器和完整对局模拟器。
4. 项目经理需要继续处理 QA-P1-003 的 Loop 官方 runtime Snapshot validator 不匹配；本岗位不修改 Registry 或插件。
5. 项目所有者仍保留 GATE-1、回合上限冻结、显著长期架构取舍与平台承诺的批准权。

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

## Iteration 1 revision 2 接口

- `MatchState.create(seed)` 创建冻结 32 子阵型、红先和确定性三旗的 `full-state-v1`。
- `RuleEngine.submit_action(state, intent)` 输出 `action-event-v1` 与 `state-summary-v1`；受控全量日志仅在 `state.events`，玩家通道仅在 `state.player_events[side]`。
- `PlayerViewProjector.project(state, side)` 是单向投影；`list_action_intents(view, intents)` 只读 `PlayerView` 并返回 `KNOWN_LEGAL / TENTATIVE / KNOWN_ILLEGAL`。
- `PlayerViewProjector.export_ai_projection(view, intents)` 输出现有 AI 白名单接受的 `player-view-ai-v1`，不传 FullState 或完整合法真值。
- `ReplayRunner.capture(seed, intents)` 与 `replay(recording)` 核对事件摘要和最终状态摘要。
