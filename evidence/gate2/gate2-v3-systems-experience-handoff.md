# GATE-2 v3 系统与体验交接——现有教学二维兼容

- Contract：`LOOP-CTR-FORMAL-FOUNDATION-GATE2-001` v3
- 工作项：`TASK-TUTORIAL-2D-COMPAT-001`
- 执行身份：`pos:veilfront-xiangqi-siege:design-experience:systems-experience-lead` / `inst:01M02NJ3JENHD8VV7EKC9G198Q`
- 授权：`AUTH-VEILFRONT-SYSTEMS-EXPERIENCE`
- 审查提交：`eae8142a3cbff44d957b52f79af1f14cc2d46f37`
- 审查日期：2026-08-23
- 结论范围：只审查既有 T0–T10 教学与挑战测试入口的 Contract v3 兼容性；不批准、实现或暗示批准 `veilfront-ftue-dual-track-complete-design-v1.md`。

## 结论

现有教学的实现边界符合 Contract v3 要求：教学复用正式二维 `MatchScreen` 表现容器；玩家行动沿正式 `NormalizedIntent -> RuleEngine -> PlayerView / VisibleEvent / VisibleError / ActionPreview` 链路执行；教程导演只消费公开 DTO 和公开交互信号，没有读取或持有隐藏 FullState。

本交接是生产者侧的系统与体验兼容审查，不能替代 QA 在 clean worktree 的独立复现，也不能批准 GATE-2。由于当前机器多代理调度严重变慢，除已完成的规则边界测试外，本轮专项测试按项目经理指令停止；未取得退出码与明确 PASS 标记的用例全部记为“证据不足”，不误报通过。

## 已验证事实

### 1. 同一 Intent / Event 链

- `scenes/game/tutorial/tutorial_level.tscn` 实例化正式 `res://scenes/game/match/match_screen.tscn` 与 `ApplicationHost`，没有复制棋盘规则实现。
- 棋盘操作通过 `MatchScreen` 的 `action_previews_requested`、`action_prepare_requested`、`action_confirm_requested` 和取消信号进入 `ApplicationHost`。
- `ApplicationHost` 仅向绑定的 `MatchClientPort` 转发；本地教学绑定 `FormalMatchClientPort`。
- `FormalMatchClientPort.confirm_prepared_action()` 从公开 ActionPreview 组装并提交规范化 Intent；`FormalLocalSession.submit_preview()` 使用 `NormalizedIntentCodec.SCHEMA_VERSION`，最终进入 `FormalMatchApplication.submit_intent()` 与正式 `RuleEngine.submit_action()`。
- 行动结果由 `FormalMatchApplication` 投影为 PlayerView、VisibleEvent、VisibleError、ActionPreview；端口再经过对应 Codec 编解码后发布给表现层和教程导演。
- 教学固定步骤效果不是表现层直接改状态：`TutorialDirector.step_effect_requested -> TutorialLevel -> FormalMatchClientPort.apply_tutorial_transition -> FormalMatchApplication.submit_trusted_tutorial_transition -> RuleEngine.resolve_tutorial_transition`，随后仍重新投影并发布公开 DTO。

### 2. 二维正式表现容器

- 教学根场景为预置 `Control`，正式棋盘/棋子/迷雾/HUD 来自 `MatchScreen` 实例；教程只叠加预置 `TutorialOverlay`、`TutorialPauseMenu` 和教学燃香槽。
- `TutorialLevel._ready()` 通过 `set_tutorial_hud_layout_sources()` 适配教学 HUD 槽位，没有创建第二套棋盘或二维坐标映射。
- `TutorialLevel.get_layout_snapshot()` 从正式 `MatchScreen.get_layout_snapshot()` 读取棋盘和 HUD 布局证据，教学层只补充自身矩形与滚动状态。

### 3. 不读取隐藏 FullState

- `TutorialDirector` 的状态输入仅为 `consume_player_view()`、`consume_visible_events()`、`consume_visible_error()`、公开 preview id、棋盘交点和 UI 请求。
- `consume_player_view()` 只读取 PlayerView 允许字段（`terminal`、`winner`、`flags`、`pieces` 等），且保存的是公开视图副本 `_latest_player_view`。
- 教程场景没有 FullState 信号连接或 FullState 引用；`ApplicationHost` 对教学座位进行 `viewer_side == bound_seat` 校验，校验失败即停止公开数据转发。
- 权威教程场景资源在 `ApplicationHost` 中只用于座位、preview、跳过与重启白名单校验；实际场景状态由 `FormalMatchApplication.create_trusted_scenario()` 在应用/领域层建立。表现层收到的数据仍必须通过观察者 Codec，隐藏权威状态不向其发布。

## GATE-2 UI 修复边界

依据 `docs/ui/ui-ux-audit-2026-08-23.md`，以下边界按 GATE-2“玩家能理解目标、路线和关键反馈”以及 Contract v3 的 960×540、1280×720、1920×1080响应式要求划分。

### GATE-2 前必须修复或提供可复现通过证据

1. 正式战局 HUD 的核心目标、阵营统计和单位关键状态在 1280×720 下不得继续以 10–14 px 低对比正文承载；核心正文应达到 15–16 px，次级信息不低于 14 px，并保证纹理背景上的对比度。
2. 教学目标、当前步骤、提示、成功/失败和恢复说明不得以 9–12 px 正文作为主要阅读层；1280×720 下正文应达到 16 px、辅助信息不低于 14 px。
3. 教学右栏必须消除目标、步骤、滚动区和燃香组件互相挤压或造成“内容被截断”的视觉误导。采用 360–400 px 独立教学抽屉是现有审计建议，但具体实现由技术/UI责任人决定；本审查不批准具体场景改法。
4. 960×540、1280×720、1920×1080 三档必须证明棋盘、教程正文、关键按钮、目标反馈不裁切、不重叠且可完成继续、重试、跳过、返回、下一章闭环。Contract 已明确 960×540，不能在本轮静默改成更高最小分辨率。
5. 教程失败与误操作恢复必须持续可见、可操作：公开错误、分级提示、本步骤重置、本章重置和退出路径不能被布局或低对比度削弱。

返回路径：字号、对比度、教学抽屉和三分辨率布局问题返回 `TASK-PRESENTATION-2D-001`；若为了修 UI 必须改变教学步骤语义、规则或 PlayerView，则停止修改并升级项目经理/项目所有者。

### 可延后到 GATE-2 之后的打磨

- 主菜单剑形按钮出鞘补间、跨页面 Primary/Secondary/Danger/Confirm 按钮预制体统一。
- 设置页空白重排、`motion_profile = null` 清理和 Confirm/Danger 动效分组。
- 关卡节点 180 ms 路线点亮、键帽美化、超宽屏背景延展。
- 行书/Noto 的完整字体角色统一、空单位面板折叠、非关键按钮手感统一。
- 21:9 装饰延展及不影响 Contract 三目标分辨率和教学闭环的视觉润色。
- 双轨教学、新 P0/B1–B3 模块、路线选择与新增教学语义；它们属于待项目所有者审批的新提案，不得作为本 GATE-2 的完成事实。

显式键盘/手柄焦点链若现状导致教程主路径无法完成，则升级为 GATE-2 必修缺陷；若鼠标、键盘和手柄均已有可复现闭环，仅是焦点顺序与动效一致性问题，可进入 GATE-2 后统一打磨。

## 测试证据

统一命令形式：

`Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://<test>`

| 覆盖 | 测试 | 结果 | 证据 |
|---|---|---|---|
| 教学规则/信息边界 | `tests/game/tutorial/run_tutorial_rule_boundary_contract.gd` | PASS | 退出码 0；`TUTORIAL_RULE_BOUNDARY_CONTRACT_PASS` |
| 教学初始正式会话 | `tests/game/scenes/run_tutorial_initial_session_smoke.gd` | 证据不足 | 已启动但在产生结果前按项目经理指令中止；无退出码/无 PASS 标记 |
| 教学路由 | `tests/game/tutorial/run_tutorial_level_routing_contract.gd` | 证据不足 | 未执行；机器调度严重变慢后停止批次 |
| 教学进度 | `tests/game/tutorial/run_tutorial_progress_contract.gd` | 证据不足 | 未执行；机器调度严重变慢后停止批次 |
| 教学布局 | `tests/game/tutorial/run_tutorial_layout_contract.gd` | 证据不足 | 未执行；机器调度严重变慢后停止批次 |
| 教学暂停 | `tests/game/tutorial/run_tutorial_pause_menu_contract.gd` | 证据不足 | 未执行；机器调度严重变慢后停止批次 |
| 教学章节 | `tests/game/tutorial/run_tutorial_chapter_content_contract.gd` | 证据不足 | 未执行；机器调度严重变慢后停止批次 |
| 挑战终局 | `tests/game/tutorial/run_challenge_terminal_flow.gd` | 证据不足 | 未执行；机器调度严重变慢后停止批次 |
| 挑战入口 | `tests/game/challenge/run_challenge_test_entry_contract.gd` | 证据不足 | 未执行；机器调度严重变慢后停止批次 |
| 隐藏信息等价 | `tests/game/contracts/run_hidden_equivalence.gd` | 证据不足 | 未执行；机器调度严重变慢后停止批次 |
| 观察者契约 | `tests/game/contracts/run_observer_contract_checks.gd` | 证据不足 | 未执行；机器调度严重变慢后停止批次 |
| 正式对局交互链 | `tests/game/tutorial/run_tutorial_match_interaction_contract.gd` | 证据不足 | 未执行；机器调度严重变慢后停止批次 |

任何没有退出码和明确 PASS 标记的用例均不得记为通过；超时项记为“证据不足”，交由 QA 在 clean worktree 复现。

## 未满足项与风险

- 本审查不拥有独立 QA 身份；`DELIVERABLE-QA-2D-001` 仍需 QA 从 clean worktree 复现。
- UI 审计已经给出核心正文过小、教学右栏拥挤的直接证据；即使布局结构测试通过，也不能用“无裁切”替代人工可读性和对比度验收。
- 本文绑定审查提交。若后续 UI、教学场景、教程资源、ApplicationHost、端口、投影或 Codec 发生修改，相关结论需要按变更范围重跑。

## 交接与下一合法动作

1. 技术/UI责任人处理 GATE-2 必修的可读性、教学布局和三分辨率证据，保持本文确认的 Intent/Event 与 PlayerView 边界不变。
2. QA 从干净工作树复现本表测试，并追加三目标分辨率、双方视角和观察者泄露检查。
3. 项目经理仅在全部自动检查和独立专业复核通过后，将 GATE-2 决策包置为 `awaiting_human`；本交接不产生人工批准。
