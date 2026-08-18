# Iteration 2 正式核心迁移技术证据 v1

状态：`candidate_complete / awaiting_independent_technical_and_QA_review`

日期：2026-08-18（Asia/Shanghai）

责任实例：`inst:01M02NJ3JEQXKV6PT6DPX0NKQ0`

授权任务：`TASK-CORE-001`、`TASK-CORE-002`

## 1. 冻结输入

- 执行基线：`main@2cdfc8a31cbb59ff02cb3a83fbb19f3709d2fe86`
- GATE-1 RC3 迁移源提交：`6253678157157091584b253470e709bad17c534f`
- 正式架构 v2 SHA-256：`58e55d7e6e2fb25c04a243017fc8e0230915a36dcc09cacaf7076b10423705f4`
- DTO 与信任边界 SHA-256：`6f23274810aad5d6f2515bd78b114da16684e38f9abe04e2d59dcfa87fc174f2`
- 迁移 manifest SHA-256：`0502e20a861a550e9845cfa1a10e4b5d94b97d1da884add2d0de70e9fa14daa4`
- 大本营/缓冲区规则后继绑定 SHA-256：`f6b07d8cbdc7db4492c33e8b4b028aca2906cccc8baf5921273aaa012d48e19b`
- Godot：`4.7.1.stable.official.a13da4feb`，renderer 保持 GL Compatibility。
- 项目实例验证：`state=normal`、plugin lock 错误 0、警告 0。

本证据不修改上述输入、Contract、Registry、approval、教程、表现场景、原型运行时、AI、LAN 或互联网实现。

## 2. Godot 产物映射

| 产物 | 正式落点 | 实现结果 |
|---|---|---|
| canonical / 可复现 RNG / FullState | `scripts/game/domain/` | 纯 `RefCounted`；无 Node、场景、表现、网络或原型依赖 |
| FullState / DomainEvent / NormalizedIntent codec | `scripts/game/domain/*_codec.gd` | exact-root 拒绝；canonical JSON；超 JSON 安全范围的 64 位 RNG 数字无损解码 |
| 规则与结算 | `scripts/game/domain/rule_engine.gd`、`move_rules.gd` | 从已批准 successor 原型逐模块迁移，保留准备 token、随机抽取顺序和结算顺序 |
| 权威回放 | `scripts/game/domain/authoritative_replay.gd` | authority-only；规则/source/codec/audit/checkpoint 篡改整体拒绝 |
| 观察者投影 | `scripts/game/projection/` | `ViewerContext` 由 application 创建；PlayerView、VisibleEvent、VisibleError、ActionPreview 为唯一公开投影 |
| application 组合根 | `scripts/game/application/formal_match_application.gd` | 独占活跃 FullState 和绑定席位；非行动席不能预览或消费回合 |
| 观察者回放校验 | `scripts/game/application/observer_replay_validator.gd` | viewer、digest、未知字段、raw event/seed 篡改整体拒绝；frame 与实时 DTO 等价 |
| 迁移适配与 runner | `tests/game/migration/` | 原型只在测试适配器内读取；正式运行时没有 prototype 引用 |
| 隐藏等价 | `tests/game/contracts/run_hidden_equivalence.gd` | 六个批准配对、公开错误外形、codec 和 replay 信任边界 |

正式脚本与测试脚本（不含 `.uid` 和 golden JSON）共 21 份，按“`sha256  path`、路径排序、LF 连接后再 SHA-256”的 bundle 摘要为：

`1af0ca4c5d1a4660b010bd8b5048f56c0a141427efdb684914f1f50ddd5ace64`

## 3. Golden snapshot

- 文件：`tests/game/migration/golden/gate1-successor-20-seeds-v1.json`
- SHA-256：`e825641ca133eb9cae925d18e748660c7103fc5327120c5c48732027d6de0f4f`
- 内部 canonical document digest：`15cc37e5bbec07d39604e472517c0fc475f6c9f8f673134e58069e32cfa8ca9a`
- seed：`471001..471020`；round limit：50；源为未修改 prototype 加 successor 映射。
- 每行动记录 normalized intent、FullState、DomainEvent 前缀、红/黑 PlayerView、红/黑 VisibleEvent、VisibleError、同一提交的 ActionPreview 与 replay checkpoint 摘要。
- golden header 同时绑定 RC3 源提交和后继文件完整 SHA-256；生成后 runner 以文件 SHA-256 硬拒绝漂移。
- 更新策略：未获得规则/Contract 变更复审时禁止重生或祝福新摘要。

## 4. TDD 记录

### RED

1. 初始 golden capture 编译失败：`PublicActionPreviewer` 的移动路径依赖未显式绑定；补正式 `MoveRules` preload 后通过编译。
2. 首个 seed 首行动 intent 摘要不等：JSON golden 读回把整型坐标变成浮点；迁移输入在边界规范化为整型后等价。
3. 首次隐藏等价运行：9 项失败，定位到 PlayerView 公开回合从 0 开始、FullState 大整数 JSON round-trip 和 ObserverReplay 校验三类问题。

### GREEN

- PlayerView 公开回合改为 1-based，FullState 内部时钟仍保持原型 0-based，不改规则状态。
- codec 编码保持 manifest 的 canonical JSON；解码前只保护超过 `2^53-1` 的 JSON integer token，恢复后校验 canonical 字节和 exact root。
- ObserverReplay 增加绑定席位、codec、frame、最终 digest 和禁止字段校验；inactive seat 不能消费 active seat 的 pass。
- 六隐藏配对与 tamper 负向测试全部通过。

## 5. 验证结果

### 正式迁移

- manifest 精确 1000-seed 命令：退出码 0。
- 汇总：`FORMAL_EQUIVALENCE_PASS completed=1000 replay_verified=20 channels=9`。
- 工作线程汇总：`completed_live=980/980 workers=4`；前 20 个 seed 来自固定 golden 并逐行动复核。
- 跨实现差异：0；失败 seed：无；replay 失败：0。
- 已知回归 seed 471016：`state_digest_matches=true`、`event_digest_matches=true`、`first_rejected_intent=-1`。

### 信息安全与 codec

- `FORMAL_ARCHITECTURE_CHECKS_PASSED self_tests=17 scanned_files=68`
- `OBSERVER_CONTRACT_CHECKS_PASSED checks=30`
- `HIDDEN_EQUIVALENCE_PASS pairs=6 checks=2707`
- 配对：`HIDDEN-FLAG-PAIR`、`HIDDEN-HORSE-PAIR`、`HIDDEN-ELEPHANT-PAIR`、`HIDDEN-CANNON-PAIR`、`HIDDEN-RNG-PAIR`、`PRIVATE-MARKER-PAIR`。
- RC3 manifest 正常校验：退出码 0，1000 records，digest `25c40f9467a7c4d4ad45162e3aef7f5f95b1948a76757bd2808b4eb6fc906064`。
- RC3 manifest 强制篡改：退出码 1，`manifest_count_or_digest_mismatch`，符合预期拒绝策略。

### 兼容与壳回归

- `PROTOTYPE_BASIS_CHECKS_PASSED scaffold=9 focused_suites=15 full_gate1=false`
- `FORMAL_SCENE_SMOKE_PASS roots=3 components=16 inputs=11`
- `BOARD_OBSERVER_FIXTURE_PASS`
- `BOARD_LAYOUT_CONTRACT_PASS resolutions=3`
- `TUTORIAL_SHELL_SMOKE_PASS`
- `git diff --check`：通过。

## 6. 范围诚实性与剩余风险

- 本任务完成正式核心、投影、application facade 与迁移证明；尚未把正式 facade 接入现有 `ApplicationHost`/MatchScreen。该集成应由后续获授权任务完成，不能把当前结果表述为正式可玩闭环。
- 旧 prototype 保持可运行，仅作为迁移 oracle；正式运行时目录没有 prototype、AI、LAN、互联网或教学耦合。
- 首版跨发布存档兼容仍未承诺；当前 codec 只冻结本循环 v1 字节与拒绝策略。
- 1000-seed runner 的 980 个非 golden seed 使用流式深比较以控制证据体积；失败时保留首个 seed、行动索引、通道和双摘要。20 个 replay seed 保留逐行动九通道 golden。
- 本证据是生产方技术候选，不替代独立 QA、技术复审或 Gate 决定。

## 7. 下一合法动作

1. 独立技术复审从冻结候选重新运行 architecture、20/1000 equivalence、replay/tamper 和范围扫描。
2. 独立 QA 复核六隐藏配对、codec unknown-field 拒绝、原型兼容和失败回退信息。
3. 双审通过后由项目经理绑定本证据与产物摘要并推进 Iteration 2 状态；任何 mismatch 返回 `TASK-CORE-001/002` 技术责任实例，不得修改 golden 使测试通过。

