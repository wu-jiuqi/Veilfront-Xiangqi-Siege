# GATE-2 / Iteration 1 独立 QA 复审 v1

- 结论：`approved`
- 冻结候选：`main@5fb174f2400cf2d525425e34f40aa108e2a9dcca`
- Contract：`LOOP-CTR-FORMAL-FOUNDATION-GATE2-001@v1`（`approved`）
- Loop instance：`83c995ff-37b9-4df8-9e84-8417d6632187`
- QA instance：`inst:01M02NJ3JFHVZ5C4SP5MTJFJR6`
- Position：`pos:veilfront-xiangqi-siege:quality:qa-release-lead`
- Authority：`AUTH-VEILFRONT-QA-RELEASE`
- 被审任务：`TASK-ARCH-001`、`TASK-SHELL-001`

## 1. 独立性、输入与环境

本次 QA 未参与实现或修订。所有执行检查均在新建的 detached worktree `C:\Users\30114\AppData\Local\Temp\veilfront-i1-qa-5fb174f` 中完成；创建后、首次运行检查前 `git status --porcelain=v1 --untracked-files=all` 为空。

冻结身份核对：

| 项目 | 实算值 | 结果 |
|---|---|---|
| 冻结输入 SHA | `5fb174f2400cf2d525425e34f40aa108e2a9dcca` | PASS |
| detached worktree HEAD | `5fb174f2400cf2d525425e34f40aa108e2a9dcca` | PASS |
| 本地 remote-tracking `origin/main` | `5fb174f2400cf2d525425e34f40aa108e2a9dcca` | PASS |
| Godot | `4.7.1.stable.official.a13da4feb` | PASS |
| 项目实例 | `normal`，errors=0，warnings=0 | PASS |
| 插件锁 | `game-production-pipeline@0.4.0-alpha.2`，framework digest 匹配 | PASS |

Contract 的批准摘要为 `9beb91baa720820d0f0985019e5a77a4e0e065a8721451eedc30e0cc22bdeaef`；Contract 当前 materialized digest 为 `a26a9b3fdb0d8d06e42a06833a84455d911fea8f72bcedec59d0ae5e620cc205`。Registry 显示 loop 为 `active / iteration 1`，本 QA reviewer identity 与 scope 绑定有效。

## 2. S1..S5 证据与提交链

| 切片证据 | SHA-256 | 包含提交 | 父提交/链验证 | 结果 |
|---|---|---|---|---|
| `iteration1-s1-dependency-guardrails.md` | `071527ad50644695ed942fd70563334ad909557bd62881ba37165d9d8ad3e3af` | `bcb157f5153cfef2b336bfb524cb8596e165ce1f` | parent=`5b7ed092be5da1aafc9c8bc360a546e11238b354` | PASS |
| `iteration1-s2-observer-contracts.md` | `6f02a058c4302e73a7349a0d9702a22f7cab8b2f98a70d9944c14d83f6e215b4` | `6b837d9482f55063454c7a8323038af794975eb8` | parent=`bcb157f5153cfef2b336bfb524cb8596e165ce1f` | PASS |
| `iteration1-s3-formal-scene-shells.md` | `7c60781c9ab5606f69b8dc3e73696d1f4ea587e78aa46a42a3d990d9d9152e73` | `0eba387fd544c98ff829905024745cd1f3049378` | parent=`6b837d9482f55063454c7a8323038af794975eb8` | PASS |
| `iteration1-s4-board-presentation.md` | `7ae493c5db4538787c189b2a173a6a119b90ffd16c3512ff58e6efe59a723054` | `975144e2f56c7d78d150b6a52cbfe32ef57746e5` | parent=`0eba387fd544c98ff829905024745cd1f3049378` | PASS |
| `iteration1-s5-tutorial-application-shell.md` | `48b4664bfd36725dfa37c6adb1f05cd8fd8d4d3de525355e698b72da527ad662` | `5fb174f2400cf2d525425e34f40aa108e2a9dcca` | parent=`975144e2f56c7d78d150b6a52cbfe32ef57746e5` | PASS |

五个包含提交均为冻结 SHA 的祖先；每份证据从其包含提交到冻结 SHA 均无后编辑。S1 文档中的“基线提交”是其包含提交的父提交，S2 同理，提交链与 TDD 切片叙述一致。

另核对 assignment 三份设计输出、S1/S2 关键产物、S4 数值快照及三张截图，共 19 项声明摘要最终 `19/19` 匹配。S4 冻结证据为：

- layout snapshot：`46ada6243ae7956e9033248efd4268de2ad2d8646f677f0fd8d70e158e664d47`
- 960×540：`159c1fc6c44d8784e1900c193ebab15e5552b4e8698cea8a077868cad8f69047`
- 1280×720：`dd11d0173c86b373e64a1087ebca0eb1b8c32d80f31263d504abd658f93f74e5`
- 1920×1080：`409cd887237a44dd1edb5d88417e505515d20fdf971e4dbc73e337d4c5844e7c`

## 3. 独立执行命令与退出码

以下命令的工作目录均为上述 detached worktree。

| 检查 | 精确命令 | 退出码 | 关键输出 |
|---|---|---:|---|
| Godot 版本 | `D:\Godot\godot.cmd --version` | 0 | `4.7.1.stable.official.a13da4feb` |
| 项目实例 | `python C:\Users\30114\.codex\plugins\cache\personal\game-production-pipeline\0.4.0-alpha.2\scripts\validate_project_instance.py --project-root .` | 0 | `state=normal`；errors=0；warnings=0 |
| Godot import | `D:\Godot\godot.cmd --headless --path . --editor --quit` | 0 | 首次扫描、全局类注册与 editor layout 完成；无 import error |
| 正式架构 scanner | `D:\Godot\godot.cmd --headless --path . --script res://tests/game/architecture/run_formal_architecture_checks.gd` | 0 | `FORMAL_ARCHITECTURE_CHECKS_PASSED self_tests=17 scanned_files=52` |
| observer codecs | `D:\Godot\godot.cmd --headless --path . --script res://tests/game/contracts/run_observer_contract_checks.gd` | 0 | `OBSERVER_CONTRACT_CHECKS_PASSED checks=18` |
| formal scenes | `D:\Godot\godot.cmd --headless --path . --script res://tests/game/scenes/run_formal_scene_smoke.gd` | 0 | `FORMAL_SCENE_SMOKE_PASS roots=3 components=16 inputs=11` |
| board observer fixture | `D:\Godot\godot.cmd --headless --path . --script res://tests/game/presentation/run_board_observer_fixture.gd` | 0 | `BOARD_OBSERVER_FIXTURE_PASS` |
| 三分辨率 layout | `D:\Godot\godot.cmd --headless --path . --script res://tests/game/presentation/run_board_layout_contract.gd` | 0 | `BOARD_LAYOUT_CONTRACT_PASS resolutions=3` |
| tutorial shell | `D:\Godot\godot.cmd --headless --path . --script res://tests/game/scenes/run_tutorial_shell_smoke.gd` | 0 | `TUTORIAL_SHELL_SMOKE_PASS` |
| prototype regression | `D:\Godot\godot.cmd --headless --path . --script res://tests/prototype/run_all.gd` | 0 | `PROTOTYPE_BASIS_CHECKS_PASSED scaffold=9 focused_suites=15 full_gate1=false` |

自动验收未出现失败。当前切片没有迁移 projection、正式规则、随机消费或 replay，因此未触发 migration manifest 的 1000-seed 全量重跑条件；prototype 基础回归通过不能被表述为新的 full GATE-1 压测。

## 4. 静态边界复核

### TutorialDirector

对 `scripts/game/tutorial/tutorial_director.gd` 独立检索以下禁止项：`tutorials/authority`、`TutorialScenarioDefinition`、`trusted_tutorial_scenario`、`FullState`、`full_state`、`AuthoritativeReplay`、`authority_replay`，命中数为 `0`。

观察事实：

- `TutorialDirector` 仅导出 `TutorialPresentationTrack`，只消费 visible events、prepared preview id 和本地取消/重试/跳过/退出信号。
- authority Resource 只在 `TutorialLevel` 预置给 `ApplicationHost.trusted_tutorial_scenario`；没有连接或字段把该 Resource 传给 `TutorialDirector`。
- 教学展示没有读取 FullState、authority replay 或另一 viewer。

### 两个 GameApp 会话隔离

静态检查 `game_app.tscn`：6 条下行连接均从该实例本地 `ApplicationHost` 指向本地 `ScreenHost/MatchScreen`，5 条请求连接反向回到同一个本地 `ApplicationHost`；没有 `/root/`、Autoload 或绝对远端 NodePath。`ApplicationHost` 的 `_client_port` 为实例字段，换绑和 `_exit_tree()` 都解除旧信号。

运行检查同时创建红/黑两个 `GameApp`：红方发布不改变黑方视图，黑方发布不改变红方视图；红方 ActionPreview/prepare/cancel/confirm 请求计数不会进入黑方 port。由静态接线和运行证据共同确认两个 GameApp 不串线。

## 5. 任务关闭判断

| 任务 | 判断 | 依据 |
|---|---|---|
| `TASK-ARCH-001` | 可关闭 | 依赖 scanner 17 项自检、52 个正式文件扫描通过；四类 observer-safe codec/固定 viewer port 合同 18 项通过；设计输出及摘要链完整；未发现 prototype、AI、LAN/network 或 authority 数据旁路 |
| `TASK-SHELL-001` | 可关闭 | 3 个根场景、16 个组件、11 个输入的预置场景 smoke 通过；棋盘 observer fixture、三分辨率正方形 layout、教学安全壳和双 GameApp 隔离通过；实现保持 fixture port，不绑定 AI、LAN 或互联网 |

这里关闭的是 Iteration 1 的“正式边界和最小组合根/场景壳”，不是完整教学关卡、正式规则迁移、GATE-2 或可发布 Demo。

## 6. 已知非阻断项

1. `run_board_layout_contract.gd` 的 headless 模式会把 detached worktree 中已冻结的 layout snapshot 的三个 `screenshot` 字段暂时写成 `pending_capture`。测试退出码与三档数值检查均通过；QA 已把临时 worktree 文件恢复到冻结 HEAD，并复算原 SHA-256。该副作用未污染共享主工作树，也不改变本次验收结果。建议 Godot 技术负责人后续让测试输出写入 `user://` 或临时路径，避免自动检查污染 evidence 路径。
2. Godot import/prototype 检查在临时 worktree 生成未跟踪的 `gate1_rc2_seed_471016_diagnostic.gd.uid`。它不是冻结输入或测试结果，随临时 worktree 一并销毁；建议后续确认该 UID 是否应受版本控制。
3. `tutorial shell` 当前使用 fixture port，只证明安全接线、取消/重试/跳过/退出与玩家可见 DTO 流；完整合法 Intent/Event 教学章节属于 `TASK-TUTORIAL-001/002`，不在本次任务关闭范围。
4. `prototype run_all` 明示 `full_gate1=false`。因为本切片未命中规则、随机、projection 或 replay 的全量重跑触发器，此项不阻断 Iteration 1；若后续 Iteration 2 命中触发器，必须执行 manifest 规定的 1000-seed 与回放验证。

## 7. 结论、权限边界与下一合法动作

专业结论为 `approved`：冻结候选满足本次 `TASK-ARCH-001` 与 `TASK-SHELL-001` 的既定自动验收和独立 QA 条件，两项任务可关闭。

下一合法动作：项目经理绑定本报告的外部 SHA-256 与冻结候选 SHA，按 Registry/state machine 记录 Iteration 1 完成，并在不扩大 Contract 范围的前提下进入 Iteration 2 `TASK-CORE-001/TASK-CORE-002`。上述已知测试副作用返回 Godot 技术负责人作为非阻断工具卫生项；若绑定摘要、冻结 SHA 或 Registry 并发版本不一致，则停止并返回项目经理重新审计。

本批准不批准 GATE-2，不授权互联网/Steam、服务器采购、AI 交付或批量美术，也不提前批准 Iteration 2/3 的产物。GATE-2 仍由项目所有者保留。

报告自身 SHA-256 在文件冻结后由交付端外部计算并随交付消息提供；SHA 值不内嵌本文，以避免自引用改变文件摘要。
