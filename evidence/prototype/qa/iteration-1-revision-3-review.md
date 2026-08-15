# Iteration 1 Revision 3 独立 QA 正式回归

## 结论

受测基线为 `ed8ebe1ba9b10d34680194f8630c46ad00b2f81b`，正式回归启动时生产工作树干净。Revision 3 已补齐并通过 Godot 规则核心、真实 PlayerView、AI 黑盒公平性、move oracle、回放/篡改拒绝、完整对局模拟和 1000 固定种子证据；此前“缺少真实核心及千种子入口”的 `QA-P1-001` 可以关闭，`QA-P1-002` 保持关闭。

当前提交仍不接受，`evidence_state=blocked`、`current_submission_accepted=false`、`full_gate1=false`。原因不是本轮技术回归失败，而是两项既有阻断仍存在：

1. `PENDING-OWNER-ELEPHANT-REVEAL-CELLS`：批准事实源没有枚举相/象“田字显形区域”的精确格集合。当前实现和测试只能作为可替换 hypothesis，不能反向冻结规则。
2. `QA-P1-003`：锁定插件的 Loop 官方 CLI 对运行态 snapshot 仍返回六项 registration-template 错误并以 `exit=1` 结束。相同未修改脚本的 `validate_history()` 返回零错误，只能证明历史链可重放，不能把官方 CLI 改记为通过。

因此不得宣告 GATE-1、不得转入 `review`。合法下一动作是保持同一 Loop、同一 Iteration 为 `active`，由项目经理升级 owner 裁决相/象精确格，再由规格与 Godot 责任岗位同步实现/覆盖矩阵，并由 QA 重跑受影响的规则、迷雾、AI 与回放检查；`QA-P1-003` 另由管线责任方修复、迁移或取得明确豁免。

## 自动证据结果

| 检查 | 结果 | 证据摘要 |
|---|---|---|
| 项目实例 | PASS | `exit=0`，`state=normal`，errors/warnings 均空，插件与框架摘要匹配 |
| Pipeline Contract | PASS | `CTR-P1-001` 官方 validator `exit=0 / OK` |
| Organization history | PASS | 官方 validator `exit=0`，snapshot/history 一致 |
| Loop 官方 CLI | FAIL / 已知工具缺陷 | `exit=1`，仍为六项 draft/template 与 active runtime snapshot 冲突 |
| Loop 历史重放函数 | PASS（限定范围） | 同一锁定脚本未修改 `validate_history()`：`history_error_count=0 / exit=0`；不替代 CLI |
| Godot 4.7.1 导入 | PASS WITH WARNING | `exit=0`，无解析/资源错误；强制退出时有 `Scan thread aborted` 警告 |
| 主场景 | PASS PARTIAL PROTOTYPE | `exit=0`，216 格、seed 471001、`prototype_core_revision3`；明确 `full_gate1=false` |
| `run_all` | PASS FROZEN BASELINE | `exit=0`，九套聚合测试通过；明确 `full_gate1=false` |
| AI 正控 | PASS | 真实不同 FullState 经 PlayerView 投影后产生相同 DTO、动作、输入摘要与公开审计 |
| AI `--force-failure` | PASS NEGATIVE CONTROL | 强制 sentinel 被报告并传播为预期 `exit=1` |
| Move oracle | PASS | `MOVE_RULES_SUITE_PASSED`，传统几何、阻挡、炮架、墙线及特殊资格覆盖 |
| 回放/篡改 | PASS | 正常回放一致；intent、event、summary、execution 篡改均被拒绝 |
| 1000 fixed seeds | PASS | `1000/1000` 完成，failure 0，每 seed 二跑，确定性差异 0，全部合法终止 |
| Manifest verifier | PASS | 1000 records，digest `8ee5bcc2…cce3` |
| Manifest 篡改负控 | PASS NEGATIVE CONTROL | 强制改写记录后 verifier 预期 `exit=1` |
| 无 cooldown | PASS | 生产脚本/资源无 cooldown/冷却字段或令牌；运行定向用例也通过 |
| 相/象精确显形格 | BLOCKED / PENDING OWNER | 批准 brief/spec/approval 未定义精确集合；技术 hypothesis 不计 frozen PASS |

## 1000 固定种子证据

命令使用 seeds `1..1000`，默认完整轮上限候选值为 `8`，状态明确为 `hypothesis_cli_overridable`。runner 对每个 seed 执行第二遍完整模拟，比较 winner、win reason、state digest、event digest 和 action count；同时检查生成行动不被规则核心拒绝、行动数边界、终局语义，以及终局后行动被拒绝且状态不变。

- 完成：1000；失败：0。
- 二跑确定性检查：1000；差异：0。
- manifest：1000 records，1002 行（header + records + summary）。
- 胜者：红 5、黑 9、和棋 986。
- 胜因：轮上限旗帜判胜 14、轮上限和棋 986。
- 对局长度：min/p50/p90/p95/max 均为 8 个完整轮。
- 行为统计：炮击 3793、旗帜占领 14、士替死 18、破墙 1、车多目标 0、修墙 0。
- 逐局记录摘要：`8ee5bcc23af9538ea0abc6b3c36f85f86d195f46533bb2eba811139e2c94cce3`。
- manifest 文件 SHA-256：`09ddfbe602c818308daf0ecd7b43fe61116a24b6ca1be0ac247a07f634f959a5`。

该批量结果满足本次模拟的合法终止、确定性和可验证 manifest 条件。986/1000 以轮上限和棋、且车多目标与修墙在该策略下未出现，是后续轮上限与策略质量评估的重要观测，不在本轮自动 Contract 中单独构成失败；冻结轮上限和 AI 参数仍需 owner 判断，不能由这组统计自动决定。

## 信息边界与 AI 独立审查

源审和运行证据共同确认 AI 不再使用伪投影：测试先构造真正不同的 FullState（隐藏黑卒位置/隐藏标记、规则 RNG 内部状态及未公开记录不同），再分别调用真实 `PlayerViewProjector.project` 和 `export_ai_projection_from_view`，将白名单 DTO 交给 AI。三次连续决策中，两侧 PlayerView、AI projection、动作、输入摘要及公开审计一致；AI DTO 还会拒绝注入的 `hidden_enemy_pieces` 字段。

Control 层只获得人类侧 PlayerView，controller 不公开带 side 的通用取视图入口；UI 脚本无 MatchState/FullState 旁路。该结论来自真实运行黑盒与源审结合，不以函数名或 fixture 摘要代替。

## 规则、迷雾、回放与测试可靠性

Revision 3 的冻结基线定向矩阵已覆盖：传统棋子几何、马腿/象眼、士/将帅九宫、兵卒前进与侧移、炮架、墙线、马隐身、相/象显形策略生命周期、车逐目标及路径视野、旗帜生命周期、士替死、后备部署、修墙时序、同步双将、轮上限结算、玩家事件过滤和终局后拒绝。

但相/象显形的“精确格集合”仍是规则输入缺失。测试只能证明当前策略的确定性、旧区失效、多源并集和信息过滤，不能证明未定义的格集合正确。这一边界也是 `run_all` 保持 `full_gate1=false` 的必要原因。

测试失败传播已用两个独立负控验证：AI sentinel 和 manifest record tamper 均产生非零退出。回放套件由 QA 目录的只读 runner 独立调用，若任一篡改断言失败会传播为进程 `exit=1`。

## 缺陷回归

### QA-P1-001 — CLOSED

Revision 2 的 blocker 是完整规则/迷雾/结算、完整对局模拟与 1000-seed 证据缺失。Revision 3 已提供对应实现、九套聚合测试、move oracle、完整对局 simulator、1000-seed manifest 和 verifier；缺失工件问题关闭。

相/象精确格的 owner-pending 是上游规则输入未决，不把它伪装成 `QA-P1-001` 技术工件仍缺失。

### QA-P1-002 — CLOSED（保持）

真实 FullState → PlayerView → AI 路径、隐藏等价黑盒配对、白名单 DTO 和负向传播均通过。

### QA-P1-003 — RETAINED / HIGH

官方 Loop CLI 仍 `exit=1`。历史函数零错误说明未观察到 Registry 历史腐坏，但不能满足官方 CLI 成功这一工具链证据。责任路径：项目经理/管线维护方；不得由 QA 修改锁定插件或重写历史。

### 新缺陷

没有发现新的 High 或 Blocker 技术缺陷。`PENDING-OWNER-ELEPHANT-REVEAL-CELLS` 是在 Revision 3 执行前已登记的规则输入阻断，继续保留，不计为新实现缺陷。

## 专业状态与下一动作

- `gate_decision: not_made`
- `evidence_state: blocked`
- `current_submission_accepted: false`
- `allow_continue_iteration_1: true`
- `full_gate1: false`
- `legal_next_action: remain_active_and_revise_same_loop`

下一动作：项目经理向项目所有者提交“相/象田字显形精确格集合”的窄范围裁决请求；裁决写入批准事实源后，由系统与体验、Godot 技术更新对应规格/实现/矩阵，再由当前独立 QA 实例回归受影响项。并行处理 `QA-P1-003` 的官方工具修复、迁移或显式风险处置。两项解决前不得转 `review`，也不得编制 GATE-1 决策包。

原始命令及退出状态见 `iteration-1-revision-3-command-output.txt`；完整 AI 审计见 `iteration-1-revision-3-ai-positive-output.txt`；1000-seed 原始逐局输出与 manifest 分别见 `iteration-1-revision-3-seeded-output.txt`、`iteration-1-revision-3-seeded-manifest.jsonl`。
