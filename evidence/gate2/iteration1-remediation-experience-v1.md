# Iteration 1 表现与交互整改证据 v1

- 基线：`main@33212df5395c18320db03be22fa9ef084f1a1723`
- 执行身份：`pos:veilfront-xiangqi-siege:design-experience:systems-experience-lead` / `inst:01M02NJ3JENHD8VV7EKC9G198Q0`
- 范围：`TASK-SHELL-001` 的 `EXP-I1-001`、`EXP-I1-002`、`EXP-I1-003 / I1-TECH-004`
- 结论：`remediation_complete / ready_for_rereview`
- 文件 SHA-256：`computed_after_write`（最终摘要由外部交接记录绑定，避免自引用）

本整改只修复已裁定的表现与交互缺陷，不改变玩法、规则事实源、端口 Contract 或教学授权语义；完整教学与最终美术仍不在本证据的完成声明内。

## 输入绑定

| 输入 | SHA-256 |
|---|---|
| `evidence/gate2/iteration1-review-decision-v1.md` | `93ef463dc920def437bad8a6e682e252da4275e566e96cd95d7798fd966594e3` |
| `evidence/gate2/iteration1-experience-review-v1.md` | `fb907bf172c77e318d9fac72828d40e21274735d60982854abf9d09fd87239ee` |
| `evidence/gate2/iteration1-technical-review-v1.md` | `d7814a193c912ab42994aefe3a1fcfd1ecdf0fb061d3cbfff4f7f3f2ebb7e5ac` |

## RED：先补失败覆盖

在生产修复前补充以下负向覆盖，并在基线上实际观察到失败：

1. `run_board_layout_contract.gd` 把三档分辨率都切到 `CONFIRMING`，断言面板、提示、两个按钮完整位于视口内，按钮最小高度不低于 44 px。结果：`960×540` 确认面板与内部控件裁切；三档均缺少新确认态快照字段，共 15 个断言失败。
2. `run_board_observer_fixture.gd` 使用延迟 prepare fixture，在 `PREVIEW_SELECTED` 右键取消后再回放迟到 prepared 响应。结果：右键返回错误语义、端口取消计数为 0、迟到响应重新打开确认态，共 4 个交互断言失败。
3. 同一 observer fixture 改用真实 19 点相/象 reveal 与 9 点 block，并要求语义快照只报告两个可绘制组。结果：旧实现报告三个 tactical group，且没有语义快照接口，共 2 个高亮断言失败。

这些失败分别直接复现 `EXP-I1-001`、`EXP-I1-002`、`EXP-I1-003 / I1-TECH-004`，不是通过放宽断言获得的绿灯。

## 整改实现

### EXP-I1-001：响应式确认面板

- `ActionConfirmationPanel` 移除组件内部固定屏幕坐标，由 `match_screen.tscn` 在场景中以水平居中、底部锚定和固定安全偏移承载。
- 面板仍为预置 `PanelContainer + VBoxContainer + HBoxContainer`；取消与确认按钮最小尺寸均为 `120×44`，保持键鼠可达性。
- 布局快照增加确认面板、提示、两按钮的全局矩形边界与按钮最小高度字段。三档测试使用真实 `CONFIRMING` 状态，不再用非确认态截图掩盖裁切。

### EXP-I1-002：在途 prepare 可取消且迟到回包失效

- `PREVIEW_SELECTED` 与 `CONFIRMING` 的右键/取消按钮统一发送一次 `prepared_action_cancel_requested`；`SELECTED` 仍只取消本地选择，不改变原有右键优先级。
- 每次 prepare 分配单调递增的本地 generation，并记录当前在途 generation 与 preview id。
- 在 `PREVIEW_SELECTED` 取消时为该 generation 建立 tombstone；迟到的 prepared 回包先消费 tombstone，不得重开确认面板。不同 preview 的迟到回包也会被当前在途 id/generation 检查拒绝。
- 延迟 fixture 记录 prepare 回包队列并可显式 flush；断言取消请求恰好 1、确认请求 0、迟到回包后状态保持 `IDLE`。

该机制只在表现层处理回包生命周期，没有修改端口签名、codec 或 authority 状态。

### EXP-I1-003 / I1-TECH-004：高亮语义对齐

- 车仅绘制蓝色移动路径。
- 相/象仅沿黄色田字阻挡九点的外沿绘制边框。
- 19 点扩展侦察仍可作为可见性输入保留，但 `TacticalOverlay` 不为其生成边框，也不计入 rendered tactical group。
- 新增只读语义快照：车路径组数、相田组数、被忽略的 reveal 点数、实际 reveal 绘制数和每个相田的有效点数。fixture 断言为 `1 / 1 / 19 / 0 / [9]`。

## GREEN 与回归

使用 Godot `4.7.1.stable.official.a13da4feb` 从项目根目录运行：

| Runner | 结果 |
|---|---|
| `tests/game/presentation/run_board_layout_contract.gd` | `BOARD_LAYOUT_CONTRACT_PASS resolutions=3` |
| `tests/game/presentation/run_board_observer_fixture.gd` | `BOARD_OBSERVER_FIXTURE_PASS` |
| `tests/game/scenes/run_tutorial_shell_smoke.gd` | `TUTORIAL_SHELL_SMOKE_PASS` |
| `tests/game/scenes/run_formal_scene_smoke.gd` | `FORMAL_SCENE_SMOKE_PASS roots=3 components=16 inputs=11` |
| `tests/game/architecture/run_formal_architecture_checks.gd` | `FORMAL_ARCHITECTURE_CHECKS_PASSED self_tests=17 scanned_files=52` |
| `tests/game/contracts/run_observer_contract_checks.gd` | `OBSERVER_CONTRACT_CHECKS_PASSED checks=30` |
| `tests/prototype/run_all.gd` | `PROTOTYPE_BASIS_CHECKS_PASSED scaffold=9 focused_suites=15 full_gate1=false` |

正式架构检查在并行 `I1-TECH-003` 整改写入期间曾短暂命中 `scripts/game/application/tutorial_scenario_definition.gd:25` 的 `APPLICATION_VIEWER_API` 违规；该文件不在本任务权限内。本任务未修改或规避它，并在并行整改收口后重新运行，最终结果为上表所列通过。

## 输出摘要

| 文件 | SHA-256 |
|---|---|
| `scenes/game/ui/action_confirmation_panel.tscn` | `f25ac9a24e5c5c7a6c4455d847c21d2bbc666ec37b30fabf0ab5a6574cda4495` |
| `scenes/game/match/match_screen.tscn` | `9c198627aae90d3ad14e18697ebf1cc7ebc4b50ac6e0e8da4dd1e948e85a922f` |
| `scripts/game/presentation/match_screen.gd` | `09df14bd997bff5170683f88ce926f35fab7d8a7d76279bb62358788c40ab4b5` |
| `scripts/game/presentation/board/tactical_overlay.gd` | `104bb0744017c06b740c5a9ba9b258f69ff1c6aa06040d1030e2ef2160e4b131` |
| `tests/game/presentation/run_board_layout_contract.gd` | `911645342fae2ad9d16b8c88e2b3adbcce7df92819c3c52eb0e45d9942568d9b` |
| `tests/game/presentation/run_board_observer_fixture.gd` | `37efa0b110c4c1c9136f67acaaf226e06b486651bbfe03137b71f0d8c6093cfa` |
| `tests/game/contracts/fixture_match_client_port.gd` | `2cf7a041b3770434d8757f1b1d41862b2265de575dc46b0a82636b8d745d0545` |

## 限制与下一合法动作

- 当前证据证明的是 Iteration 1 场景安全壳的确认态响应式、取消竞态和战术高亮语义；不声明完整教学、最终美术或 GATE-2 已完成。
- 端口回包不携带 generation，因此本地 tombstone 按同一 preview id 的请求/回包顺序消费；若未来端口允许乱序返回同 id 的多个并发 prepare，需要在正式 Contract 中引入 request token。当前 MatchScreen 单在途模型与 fixture 的顺序响应满足冻结行为，不构成本轮规则变更。
- 无需 owner 决断的玩法歧义。本次修复严格采用已裁定表现：车蓝色路径、相/象黄色田字九点、19 点 reveal 不描边。
- 下一合法动作：等待并行 `I1-TECH-001..003` 整改完成，重新运行全套 formal architecture；随后由技术、系统体验和独立 QA 对同一新冻结提交重审。三审通过前不得关闭 Iteration 1 或开始 Iteration 2。
