# Iteration 1 Revision 4 独立 QA 正式回归

受测规则基线：`owner-freeze revision 3`；受测 HEAD：`a140015c9764f6827dfdfc647a91494585fa21a4`。

## 结论

owner-freeze revision 3 已关闭 `PENDING-OWNER-ELEPHANT-REVEAL-CELLS`。相/象显形规则、生命周期、PlayerView 边界、既有规则/AI/回放回归和正式 1000-seed 批量对局全部通过；没有发现新的 High 或 Blocker 技术缺陷。

但本轮整体证据仍为 `blocked_by_tooling`，`current_submission_accepted=false`：`QA-P1-003` 未关闭，锁定插件的 Loop 官方 CLI 仍以六项模板错误 `exit=1`。同一未修改脚本的 `validate_history()` 为零错误，只证明历史链可重放，不能替代官方 CLI。QA 无权自行豁免该失败。

`full_gate1=false`，GATE-1 决定未作出。即使技术自动证据通过，也不能替代项目所有者对核心循环、反馈闭环、风险覆盖和技术成本的人工判断。

合法下一动作：保持 Loop `active`，由项目经理/管线责任方解决 `QA-P1-003`（正式修复、迁移或取得明确风险豁免），随后复跑治理校验。治理阻断解除后，才可整理 GATE-1 人工决策包并请求项目所有者判断；QA 不记录批准。

## 结果总览

| 检查 | 结果 | 观察 |
|---|---|---|
| 项目实例 | PASS | `exit=0`，`state=normal`，errors/warnings 为空 |
| Pipeline Contract | PASS | `CTR-P1-001` validator `exit=0 / OK` |
| Organization history | PASS | 官方 validator `exit=0` |
| Loop 官方 CLI | FAIL / QA-P1-003 | `exit=1`，六项 registration-template 与 active runtime snapshot 冲突 |
| Loop `validate_history()` | PASS（限定范围） | 同一锁定脚本、同一输入，`history_error_count=0`；不替代 CLI |
| Godot 4.7.1 import | PASS WITH WARNING | `exit=0`，无解析/资源错误；强制退出产生 `Scan thread aborted` |
| 主场景 | PASS | `exit=0`，216 格、seed 471001；仍明确 `full_gate1=false` |
| 相/象冻结专测 | PASS | `ELEPHANT_REVEAL_PASS / exit=0` |
| `run_all` | PASS | 十套聚合测试通过，`focused_suites=10` |
| AI 正控 | PASS | 真实 PlayerView 黑盒公平性与公开审计一致 |
| AI 负控 | PASS NEGATIVE CONTROL | `--force-failure` 预期 `exit=1` |
| Move oracle | PASS | 生产生成器与独立 oracle 定向集合一致 |
| Replay/tamper | PASS | 正常回放一致，四类篡改被拒绝 |
| 无 cooldown | PASS | 生产脚本/资源无 cooldown/冷却字段或令牌，运行定向用例通过 |
| 1000 fixed seeds | PASS | 1000/1000，failure 0，每 seed 二跑，确定性差异 0 |
| Manifest verifier | PASS | 1000 records，摘要一致 |
| Manifest 篡改负控 | PASS NEGATIVE CONTROL | 强制篡改后预期 `exit=1` |

## 相/象九格显形独立验证

冻结定义为合法移动起点 `O` 与终点 `D` 作为包围方形对角，输出严格的 `3×3` 九格：包含起点、象眼与终点，不裁切、不扩展。

### 几何与隐藏马

- `(5,10) -> (7,12)` 的实际集合逐格等于 `X=5..7, Y=10..12`，恰好九格。
- helper 对 `(0,0) -> (2,2)` 仍输出完整九格，证明几何层不按棋盘边界裁切；合法行动边界由移动校验负责。
- 九格内隐藏马进入 PlayerView；九格外隐藏马保持隐藏；马移出全部有效源后恢复不可见。
- 两个 FullState 只在九格外隐藏马身份上不同，红方 PlayerView digest 相等。

### 多源、刷新和移动开始清源

- 两枚相/象分别保留自己的一个源，PlayerView 使用集合并集。
- 一枚相/象再次移动只刷新自身源，另一枚相/象的源保持有效。
- 下一次真实移动在解析前清除旧源；即使随后因隐藏象眼受阻而消耗失败，旧源也不会残留。

### 全离场与能力失效清源

- 直接死亡清源。
- 士替死救援并回营清源。
- 显式回营清源。
- 修墙撤回清源。
- 回营无空位而进入后备队列时清源。
- QA 独立黑盒补测：第三枚入侵棋触发敌墙由 `INTACT -> BREACHED`，通过公开 `submit_action` 路径清除攻击方全部相/象显形源，`REVISION4_ELEPHANT_WALL_BREACH_CLEAR_PASS / exit=0`。

生产专测没有单列“墙倒塌清源”用例名称，因此 QA 在自身证据目录增加只读 runner；它没有修改生产实现或规格。

## 1000 fixed seeds

命令运行 seeds `1..1000`，默认完整轮上限候选值 `8` 保持 `hypothesis_cli_overridable`。每个 seed 执行第二遍完整模拟，并比较 winner、win reason、state digest、event digest 和 action count；同时验证生成行动合法、终局语义、行动数边界与终局后不可变性。

- `completed_matches=1000`
- `failure_count=0`
- `determinism_checked_count=1000`
- `determinism_mismatch_count=0`
- replay 抽样 `10/10`
- winner：红 5、黑 9、和棋 986
- reason：轮上限旗帜判胜 14、轮上限和棋 986
- 对局完整轮：min/p50/p90/p95/max 均为 8
- metrics：炮击 3793、候选评估 55152、旗帜占领 14、士替死 18、车多目标 0、破墙 1、修墙 0
- records digest：`dcc6947442ee14d05636953095d07c19ebd093ff616449598612082baa03575d`
- manifest SHA-256：`df82d3b188ea2fec937ee9364d89e47a119d2d8f686e1a04a41116178517e2b5`

986/1000 以轮上限和棋、车多目标和修墙在该压力策略下未出现，仍是后续回合上限/AI 策略评估风险；这不自动冻结轮上限、AI 搜索预算、随机性或难度，也不替代人工体验判断。

## 缺陷与阻断状态

### QA-P1-001 — CLOSED（保持）

完整规则/迷雾/结算、完整对局模拟、1000 seeds 及 manifest 证据继续存在并通过。

### QA-P1-002 — CLOSED（保持）

真实 FullState → PlayerView → AI 黑盒路径、隐藏等价决策和失败传播继续通过。

### QA-P1-003 — RETAINED / HIGH

官方 Loop CLI 仍 `exit=1`；未观察到事件摘要链、sequence、revision 或 snapshot 尾部水位重放错误。责任路径为项目经理/管线维护方。QA 不修改锁定插件、不伪造 draft snapshot、不重写历史。

### PENDING-OWNER-ELEPHANT-REVEAL-CELLS — CLOSED

owner-freeze revision 3 已冻结精确九格和生命周期；实现、定向运行、PlayerView 黑盒和 QA 墙倒塌补测均与其一致。

### 新缺陷

无。

## 专业状态

- `technical_regression: pass`
- `professional_result: blocked_by_tooling`
- `evidence_state: blocked`
- `current_submission_accepted: false`
- `allow_continue_iteration_1: true`
- `full_gate1: false`
- `gate_decision: not_made`
- `transition_to_review_allowed: false`
- `legal_next_action: resolve_or_formally_waive_QA-P1-003_then_recheck`

完整命令和退出状态见 `iteration-1-revision-4-command-output.txt`；AI 原始审计见 `iteration-1-revision-4-ai-positive-output.txt`；1000-seed 原始记录和 manifest 分别见 `iteration-1-revision-4-seeded-output.txt` 与 `iteration-1-revision-4-seeded-manifest.jsonl`。
