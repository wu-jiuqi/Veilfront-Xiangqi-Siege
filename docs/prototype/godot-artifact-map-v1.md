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
| `scripts/prototype/core/**` | GDScript / 纯规则探索 | 后续 STEP-004 的规则状态、投影、事件、摘要与回放候选实现 | Godot 技术负责人 | 未创建；等待规则与信息契约 |
| `resources/prototype/rules/**` | `.tres` 配置 | 后续可调但需序列化的原型规则默认值 | Godot 技术负责人；规则语义由系统与体验负责人验收 | 未创建；等待规则规格 |
| `tests/prototype/rules/**` | GDScript / 行为测试 | 后续规则矩阵、确定性、回放与信息边界测试 | Godot 技术负责人；QA 独立验收 | 未创建；等待规则规格与 QA 矩阵 |
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
- “确定性规则核心与显示层解耦”仍是 `hypothesis`。Phase 1 只建立一个不把 216 格状态节点化的最小接缝；必须在后续确定性、PlayerView、回放和批量对局原型中验证。
- 本轮不实现合法行动、迷雾、城墙、三旗、士替死、将帅死亡、行动日志或回放，因此也不声称 `TASK-PROTOTYPE-001`、STEP-004 或 GATE-1 验收完成。
- `.tres` Theme 和三个 `.tscn` 只服务逻辑可读性，不代表正式 UI、主棋盘/小地图 UX 或视觉基线。

## 后续接口需求

1. 系统与体验负责人提供版本化规则状态字段、合法行动与结算顺序，尤其是将帅实际死亡的最高优先级和车路径逐目标停止条件。
2. 系统与体验负责人提供 `FullState -> PlayerView` 单向投影字段表，并定义合法行动查询、错误、日志与随机结果的无泄露返回形状。
3. 单机 AI 工程师只接收不可反查 `FullState` 的 `PlayerView`、公开规则配置、自身记忆和独立 AI 种子；具体 DTO 名称与序列化摘要需双方在实现前对齐。
4. QA 提供 Phase 1 节点/加载检查的独立复核记录，并在 STEP-004 后补充规则矩阵、隐藏等价配对、确定性回放和 1000 种子入口要求。
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
