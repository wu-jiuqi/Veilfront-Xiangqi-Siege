# GATE-1 RC2 独立 QA 审查

- 执行日期：2026-08-17（Asia/Shanghai）
- QA Instance：`inst:01M02NJ3JFHVZ5C4SP5MTJFJR6`
- 受测提交：`5a596526e4b82a6af2d9345e2f06a9fecb0028c7`
- Contract：`LOOP-CTR-GATE1-VERTICAL-SLICE-001 v5`
- Contract subject digest：`d88d9017bb30437ac480e0fcf4f7b262b5ae6b3427447946e50ec37a5d3b44ca`
- Project Brief：`v4 / df8deb810d8c06c8c2f5763031fde2c39f14aa81226e23ffb25636ee3f1eca0b`
- Registry 基线：`active / iteration 2 / revision 52 / sequence 52`
- RC2：`Veilfront_Xiangqi_Siege_GATE1_RC2.exe`，`109734624` bytes，SHA-256 `C2ACD484E99B50F53E524726C0FD944B0B46DBAD57634C20CE4DAF9152EB89CD`

## 结论

专业结论为 **`revise / revision_required`**。RC2 不能进入 `awaiting_human`，也不能执行 `active -> review`。

治理、Godot、规则、迷雾、AI 和 LAN 检查均通过，但 Contract v5 强制要求的 1000 固定种子长测在 `seed=471016` 出现稳定可复现的 `replay_divergence`：完成 `999/1000`，失败 `1`。这同时使 `CHECK-DETERMINISM-001`、`CHECK-SIMULATION-001` 以及 QA-P1-003 临时例外的 `1000/1000` 必要条件不满足。

GATE-1 仍为 `not_made`。项目所有者的双机真人试玩通过记录继续有效，但不能替代失败的自动条件。

## 验收矩阵

| 条件 | 结果 | 关键证据 |
|---|---|---|
| `CHECK-CONTRACT-001` | 通过 | 项目实例 `normal`；CTR、组织历史、未修改 `validate_history()` 均退出 0；Registry v5/v4 绑定和 rev52/seq52 一致 |
| `CHECK-GODOT-001` | 通过 | Godot `4.7.1`；导入、主场景、15 套聚合回归、灰盒和 LAN 三套入口均退出 0；RC2 可无头启动 |
| `CHECK-RULES-001` | 通过 | revision v4/v5、移动、相田、交点棋盘、墙线、隐身马、旗帜记忆、阵亡记录、士献祭确认/取消专项均通过 |
| `CHECK-DETERMINISM-001` | **失败** | `seed=471016` 同意图回放在 action/event index 51 分歧；live 与 replay 状态/事件摘要不同 |
| `CHECK-FOG-001` | 通过 | PlayerView 隐藏等价、LAN 白名单、旗帜按观察者记忆、阵亡/虚影边界和 UI 无 FullState 旁路测试通过 |
| `CHECK-AI-001` | 通过 | 100 seeds × 4 档 = 400 记录；失败、确定性差异、隐藏等价差异、映射与提交失败均为 0 |
| `CHECK-SIMULATION-001` | **失败** | 要求 1000/1000；实际 999 完成、1 个 `replay_divergence` |
| 独立专业审查 | **退回修订** | 失败未删除、阈值未降低、旧 1000-seed 证据未冒充当前 v5 证据 |
| `GATE-1` 人工闸门 | 未到达 | 自动条件未全部通过，不得提交人工批准 |

## 阻断缺陷 QA-P1-004

- 严重程度：`blocker`
- 责任返回：`pos:veilfront-xiangqi-siege:technology:godot-technical-lead`
- 最小种子：`471016`
- 最小命令：

```powershell
D:\Godot\godot.cmd --headless --path . --script res://tests/prototype/run_seeded_matches.gd -- --seeds 1 --start-seed 471016 --round-limit 50 --replay-samples 1
```

- 独立复现：连续两次退出码均为 `1`，均为 `replay_divergence`。
- 原始模拟：`100` 个 intent、`100` 个事件；状态摘要 `dea568557684bed2c3a10894bfdf14bd917186662b517942cfb945ddb9221615`；事件摘要 `1f53e1ba8a9f26522e9ca2ecfd6ce89d7732ff63f9decca84baeaede71d820a6`。
- 回放：`74` 个事件；状态摘要 `201d55728a3e25086e058ba3ecb366aa20ce0deb3259897faad2540db3501c00`；事件摘要 `9e1961fa2fc64aa4e34553211a5a4eef6b42db34fc63a7e40eb4d67c180f5bb5`。
- 首个差异：index `51`。
- Intent：`black-rook-1 / rook_standard / target=[1,3]`。
- Live：动作被消费，`elephant_field_intercepted=true`，停在 `[1,7]` 并吃掉 `red-elephant-1`。
- Replay：同 intent 返回 `known_illegal / visible_rule_rejection / consumed=false`，随后事件序列错位。

以上只陈述可重复观察。`trusted_generated_action` 与 ReplayRunner 非 trusted 提交路径是优先调查方向，但根因和修复方案由 Godot 技术负责人负责，QA 不修改被测实现。

## 通过项摘要

### 治理与 QA-P1-003

- 项目实例、Pipeline Contract 和 Organization Registry 校验全部退出 `0`。
- 未修改的 `validate_history()`：`history_error_count=0`。
- 官方 Loop CLI 仍退出 `1`，且错误集合精确等于批准的六项，没有第七项错误。它必须记录为 `failed`，不能表述为通过。
- 因本次 1000-seed 条件失败，QA-P1-003 的临时例外没有完成本轮重新准入，不能据此进入 review。

### Godot、规则、迷雾与 LAN

- `run_all.gd`：`PROTOTYPE_BASIS_CHECKS_PASSED scaffold=9 focused_suites=15 full_gate1=false`。
- `run_playtest_graybox.gd`：交点坐标、正方形网格、双侧底部镜像、迷雾蒙版、区域显示、特殊高亮、右键标注、阵亡列表和士献祭确认/取消全部通过。
- LAN host、loopback 双实例和 lobby 场景测试全部退出 `0`；两侧只接收各自 PlayerView，未收到 FullState、RNG、可反推旗位的种子或另一侧发现记忆。
- 项目所有者的真实双机试玩已经通过；该证据只证明人工试玩路径，不覆盖本次回放失败。

### AI 公平性

- 种子：`471001..471100`。
- 难度：easy / medium / hard / expert，各 `100` 条，共 `400` 条。
- `failure_count=0`
- `determinism_mismatch_count=0`
- `hidden_equivalence_mismatch_count=0`
- `mapping_failure_count=0`
- `submit_failure_count=0`
- records digest：`06211a09c80727b850878e675ec25e540a3bf72ec9c9c8657ca9fd03b99cd23b`
- 独立重算记录数、种子范围、四档分布和 records digest 均一致。

## 1000-seed 批次事实

- requested：`1000`
- completed：`999`
- failure：`1`
- determinism checked：`999`
- determinism mismatch：`0`
- replay verified：`19/20`
- failed seed：`471016 / replay_divergence`
- 已完成局终止原因：三旗 `2`、轮上限旗数判胜 `407`、轮上限平局 `590`
- winner：红 `182`、黑 `227`、平局 `590`
- records digest：`430d6c9acc83cdb5dea68207c7d303f547160c41d3b51c3096eab25d80080378`

Manifest 自身的 999 条记录数量与摘要校验通过；这只证明失败证据没有损坏，不会把 `999/1000` 改写成验收通过。

## 构建与残余观察

- 主线 RC2 的大小、SHA-256 和无头启动已独立复核。
- QA 从同一 clean commit 重新导出成功且文件大小相同，但 SHA-256 为 `B1ED51E8A748151D5D373F10DE2354777279E39687646EE943661C9F755DD3FB`，与主线 RC2 不同。当前 Windows 导出不是字节级可复现；后续决策包必须绑定既定 RC2 SHA，而不能只绑定文件名。
- clean source headless 加载会记录两个 `invalid UID` 路径回退 warning 和强制退出时的 `Scan thread aborted` warning；均无解析、导入或资源加载 ERROR，导出和运行通过。建议后续正式架构阶段消除，但不是本次回放阻断的替代解释。
- 已完成的 999 局中 `590` 局达到 50 轮平局。回合上限仍是 `hypothesis_cli_overridable`，QA 不冻结该参数；节奏是否可接受保留给后续人工体验判断。

## 失败历史未隐藏

RC1 `56d819a` 曾暴露两个前置失败：Project Brief 摘要不匹配，以及旧 seed runner 仍读取已移除的 `initial_flag_band_start`。生产侧在 RC2 前完成 Brief v4/Contract v5 迁移和 runner 修订；RC2 的 1/2/5-seed 快速复检通过。本报告保留这段历史，不使用旧证据替代 RC2 的正式 1000-seed 失败。

## 下一合法动作

1. Loop 保持 `active / iteration 2`，不得进入 `review` 或 `awaiting_human`。
2. Godot 技术负责人修复 QA-P1-004，并用 `seed=471016` 增加回归。
3. 冻结新提交和新构建后，由独立 QA 重跑完整治理、规则、迷雾、AI、LAN 和 1000 固定种子；不能只重跑单个失败种子。
4. 只有新候选满足 `1000/1000`、确定性差异 `0`、全部自动条件和独立专业审查后，项目经理才能整理 GATE-1 人工决策包。

完整命令与退出码见 `gate1-rc2-command-summary.txt`；逐 seed 和 AI 记录见同目录 manifest。
