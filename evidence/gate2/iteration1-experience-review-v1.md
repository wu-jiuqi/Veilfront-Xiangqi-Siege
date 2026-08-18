# GATE-2 Iteration 1 系统与体验复核 v1

结论：`revision_required`

复核对象：冻结候选 `main@5fb174f2400cf2d525425e34f40aa108e2a9dcca`

复核身份：`pos:veilfront-xiangqi-siege:design-experience:systems-experience-lead` / `inst:01M02NJ3JENHD8VV7EKC9G198Q0`

范围：仅复核 Iteration 1 正式场景安全壳的交互、信息表达、镜像、响应式与教学观察者边界；不验收完整教学关卡、最终美术、规则迁移、互联网、AI 或 GATE-2。

## 输入绑定

### 计划与切片证据

| 输入 | SHA-256 |
|---|---|
| `game-pipeline/loops/evidence/GATE2-iteration1-implementation-design-assignment.md` | `b39144c679d291f6e4339572580a64455af1f22b687b0813cd50063aef13755a` |
| `docs/godot-prompter/plans/iteration1-formal-shell-migration-plan-v1.md` | `4781b95d15bcfafa4846401c771731e7c3d80e0a3c7289812fc95bc1467ce8f7` |
| `evidence/gate2/iteration1-s1-dependency-guardrails.md` | `071527ad50644695ed942fd70563334ad909557bd62881ba37165d9d8ad3e3af` |
| `evidence/gate2/iteration1-s2-observer-contracts.md` | `6f02a058c4302e73a7349a0d9702a22f7cab8b2f98a70d9944c14d83f6e215b4` |
| `evidence/gate2/iteration1-s3-formal-scene-shells.md` | `7c60781c9ab5606f69b8dc3e73696d1f4ea587e78aa46a42a3d990d9d9152e73` |
| `evidence/gate2/iteration1-s4-board-presentation.md` | `7ae493c5db4538787c189b2a173a6a119b90ffd16c3512ff58e6efe59a723054` |
| `evidence/gate2/iteration1-s5-tutorial-application-shell.md` | `48b4664bfd36725dfa37c6adb1f05cd8fd8d4d3de525355e698b72da527ad662` |

### 三分辨率视觉证据

| 输入 | SHA-256 |
|---|---|
| `evidence/gate2/iteration1-s4-layout-snapshots.json` | `46ada6243ae7956e9033248efd4268de2ad2d8646f677f0fd8d70e158e664d47` |
| `evidence/gate2/i1-s4-960x540.png` | `159c1fc6c44d8784e1900c193ebab15e5552b4e8698cea8a077868cad8f69047` |
| `evidence/gate2/i1-s4-1280x720.png` | `dd11d0173c86b373e64a1087ebca0eb1b8c32d80f31263d504abd658f93f74e5` |
| `evidence/gate2/i1-s4-1920x1080.png` | `409cd887237a44dd1edb5d88417e505515d20fdf971e4dbc73e337d4c5844e7c` |

### 直接复核的正式实现与测试

| 输入 | SHA-256 |
|---|---|
| `scripts/game/presentation/match_screen.gd` | `9eff068671bc0fba1f980e9ad9f046281ff236151a32f4c8fcfe5e41669abf00` |
| `scripts/game/presentation/board/board_coordinate_mapper.gd` | `bfea0ef01ef26eadc6606c3ad381f925e33f517132aa1cdaa3ae497f54d2f2a3` |
| `scripts/game/presentation/board/board_world.gd` | `7337278a9befb7ef92df1ea37a61c119cbfd7a20c0e6c7d3a5d621b49095c28a` |
| `scripts/game/presentation/board/fog_overlay.gd` | `9a4fd63726d0ae80434730370564c879c7d7c10a2bb2bafa8cdec892939245e4` |
| `scripts/game/presentation/board/flag_renderer.gd` | `6665345bcf979c18be677458ac93f066cc0d9f39f29f6487a581064b9b9bcae9` |
| `scripts/game/presentation/board/capture_ghost_renderer.gd` | `b6ffa807a3378fe46ac8b859c10924ec0ac15afff710458f741700c672d1d0b6` |
| `scripts/game/presentation/board/marker_overlay.gd` | `7c96ef49168f6560cb28d125e4fff6d98a770332c0f4d96802e1e23891569a4c` |
| `scripts/game/presentation/board/tactical_overlay.gd` | `f51d2ebeedac9d4583cb3e8528ab2f8784f070eb42363097465f6ac87383e930` |
| `scripts/game/presentation/board/interaction_overlay.gd` | `690f5ba56574acc6e479ccebc8b020ddc90095580fa58b080b3faf9d5246f11b` |
| `scripts/game/application/application_host.gd` | `7e9cfedc082d18fc062fc86ad6e4989367517412650a5963a19fd9509e2f4e77` |
| `scripts/game/ports/match_client_port.gd` | `5a2bad5cc2e74ca41432ffa483cbdda22ccc6b28a4a2a81316857a7a8bdc60dd` |
| `scripts/game/tutorial/tutorial_director.gd` | `6b21765f9be9f57c60a897f40b70ff7752f73b88a61a8c4c794dc859d5881e79` |
| `scripts/game/tutorial/tutorial_overlay.gd` | `5f01b9eb99eaf3f003f57affc23dd8d0beaf0ddf1982dda321e4e8e70af365ac` |
| `resources/game/tutorials/presentation/tutorial_smoke_track.tres` | `ae4384c48fe863b28cb917300c5285d38b9d4be928aa11734b4cf80c4b7c8759` |
| `scenes/game/match/match_screen.tscn` | `621b115bbe5415466fa4fc703905eb30775a57fa0d4e46eb0c58e154f7ec8f79` |
| `scenes/game/ui/action_confirmation_panel.tscn` | `c93b556c3ac31b8398b3bef3f443ccb993cd5da50f8cb31229c0e7096c32627a` |
| `scenes/game/tutorial/tutorial_level.tscn` | `3e292ad0571de12ad4599407169d4ce2b85cf8436419865a889382771f6c1ed7` |
| `tests/game/presentation/run_board_layout_contract.gd` | `9ab59302f657c13a1d32fea359cf59244d714210df771d70c23c502432c3812f` |
| `tests/game/presentation/run_board_observer_fixture.gd` | `a9b97da88e130dacf323b272b1fb0fa96c18e1f8707cc6e21955453fdb583fed` |
| `tests/game/scenes/run_tutorial_shell_smoke.gd` | `78c484e957d6fc622a862a13827cfc0022a465b59b716cc2bcee55c68fd99654` |

## 复跑结果

在候选提交上复跑：

- `BOARD_LAYOUT_CONTRACT_PASS resolutions=3`
- `BOARD_OBSERVER_FIXTURE_PASS`
- `TUTORIAL_SHELL_SMOKE_PASS`
- `FORMAL_ARCHITECTURE_CHECKS_PASSED self_tests=17 scanned_files=52`
- `OBSERVER_CONTRACT_CHECKS_PASSED checks=18`
- 项目实例校验：`state=normal`，errors=0，warnings=0。

复跑 `run_board_layout_contract.gd` 的 headless 路径会把快照中的截图字段暂写为 `pending_capture`；复核结束前已精确恢复到冻结 SHA `46ada624...`，未把该副作用留在工作树。

自动检查通过只能证明当前 fixture 覆盖项，不替代以下玩家体验判断。

## 已通过的体验边界

1. **右键基本优先级**：`SELECTED` 首次右键只取消选择且不放标记；`CONFIRMING` 右键清除本地待确认态、调用端口取消，fixture 证明取消计数 1、确认计数 0。返回 `IDLE` 后第二次右键才打开圆/叉/方形标记。
2. **迷雾与情报层级**：未发现旗帜不创建节点；已发现旗帜重新入雾仍以永久记忆图标显示在 Fog 上方；虚影只按当前 PlayerView 渲染；私有标记只写本地 Overlay，不进入 port/DTO。场景顺序为 `Fog < Intel < Ghost < Marker < Tactical < Interaction`，交互提示不会被标记遮挡。
3. **基础高亮辨识**：车路径的蓝色双线和相田黄色边框在三档截图中能与红色墙线、格线和棋子占位区分；高亮沿交点线绘制，没有改成长方形格子。
4. **双方底部镜像**：authority 坐标未改写；红方 `Y=1`、黑方 `Y=24` 映射到显示底部，红黑显示坐标互为 180°，逆映射回原 authority 交点。三档数值快照均为 X/Y 等点距。
5. **教学安全边界**：TutorialDirector 不引用 authority Resource、FullState、raw Domain Event、规则 seed 或 viewer 选择权；正式连接只把 `VisibleEvent` 和本地已知的准备/取消操作送入 Director。可见事件按 presentation track 的公开 `message_key` 推动提示；重试与跳过走 MatchClientPort，请求不会直接写棋盘状态。

## 必须修订的问题

### EXP-I1-001 — `high`：960×540 的行动确认提示不可见且不可读

- `action_confirmation_panel.tscn` 使用固定 `offset_top=520`、`offset_bottom=648` 和 `360×128` 最小尺寸。
- 在 960×540 模式下，确认面板只有顶部约 20 像素落在视口内，提示和面板内“取消/确认行动”按钮位于屏幕之外。底部通用操作栏虽仍存在，但无法向玩家展示正在确认的具体行动和确认文案。
- 当前响应式测试只检查通用主按钮，不会把确认面板切到可见状态，也没有断言提示矩形在视口内；三张截图同样都在非确认态，因此没有暴露该问题。
- 这违反 Iteration 1 的“主要按钮、提示不裁切且可读”，属于场景安全壳缺陷，不是最终美术延期项。

关闭条件：确认面板由响应式容器/锚点承载，960×540、1280×720、1920×1080 三档在 `CONFIRMING` 状态均完整显示行动提示与取消/确认控件；截图和数值断言同时覆盖可见矩形。

### EXP-I1-002 — `high`：`PREVIEW_SELECTED` 的右键取消只清本地状态，未撤销端口侧 prepare

- `prepare_action()` 先把状态设为 `PREVIEW_SELECTED`，再调用异步接口 `prepare_action(preview_id)`。
- `handle_cancel_or_marker()` 只有 `CONFIRMING` 分支发出 `prepared_action_cancel_requested`；`PREVIEW_SELECTED` 与 `SELECTED` 共用仅清本地状态的分支。
- 当前 fixture port 同步回发 `prepared_action_changed`，因此测试几乎不会停留在 `PREVIEW_SELECTED`，也没有覆盖延迟响应。真实异步端口若在 prepare 请求返回前收到右键，UI 会显示已经取消，但稍后到达的 prepared frame 可再次打开确认面板，端口草案也未被撤销。
- 这不一定自动提交 Intent，但破坏“第一次右键只取消且确认流程可预测”，并与冻结接口中 `PREVIEW_SELECTED/CONFIRMING` 取消不得产生 Intent 的语义不完整匹配。

关闭条件：为 prepare-in-flight 建立可审计取消语义；右键/取消按钮必须撤销端口侧草案，并拒绝或吸收迟到的 prepared 响应。新增延迟 fixture，证明取消后状态保持 `IDLE`、取消请求恰一次、确认请求为零、迟到回包不重开面板。

### EXP-I1-003 — `high`：相田高亮 fixture 与真实 19/9 点语义不一致，边框会夸大范围

- revision 5 的相视野源是起点 `3×3`、田字九点、终点 `3×3` 的 19 点并集；相田阻挡源只有田字九点。当前 `TacticalOverlay` 同时绘制 `elephant_reveal_zones` 与 `elephant_block_fields`，并把任意 cells 集合压成 `min/max` 外接矩形。
- 19 点并集不是完整 5×5 方形；用外接矩形会把不存在的角点/边点视觉上包进“有效范围”。系统体验冻结要求特殊相高亮只表达田字格范围，不能用更大的矩形暗示规则作用域。
- 当前 observer fixture 给 reveal 与 block 完全相同的九点集合，所以两条边框重叠；三张截图只能证明一个黄色 3×3 框可见，既没有证明真实 19/9 点输入，也没有证明侦察/阻挡重叠时仍可区分。

关闭条件：特殊边框按已确认体验只精确圈出相田九点；若仍需表达 19 点可见并集，必须使用不误包围缺失点的表达，并与田字阻挡明确分层。fixture 改用真实 19 点 reveal + 9 点 block，截图和断言验证不会夸大、重叠时仍可读。

## 教学与美术范围判定

Iteration 1 已证明的是**场景安全壳**：预置 TutorialLevel 能进入，公开事件能触发 presentation track，取消/重试/跳过/退出状态可达，且没有隐藏状态旁路。此项边界通过。

以下仍是已计划的后续交付，不作为本次 `revision_required` 的理由：

- `tutorial.entered`、`tutorial.observe_board` 等目前仍直接显示资源 key；退出只进入壳状态。它们不能冒充可面向新玩家交付的完整教学文案、章节、合法 Intent/Event 流、checkpoint、失败解释或真正的场景退出。
- 棋子红色方块、灰盒面板、区域底色和基础线条只是布局/可读性占位，不是最终棋子、棋盘、特效、动画、音频或完整 Demo 美术。

也就是说：本报告认可 observer-safe 教学和表现组合方式，但不认可把安全壳称为“完整教学已完成”或“最终美术已完成”。

## 结论与下一合法动作

结论为 `revision_required`。已通过的迷雾、旗帜记忆、虚影、私有标记、基本右键优先级、红黑镜像和教学观察者边界可以保留；`EXP-I1-001..003` 必须返回 `TASK-SHELL-001`，由 Godot 技术负责人做局部修订并补定向证据。

修订后重新提交同一 Iteration 1 系统与体验复核，至少复跑现有五项检查，并新增：三分辨率确认态截图/矩形断言、延迟 prepare 取消测试、真实 19/9 点相田高亮 fixture。系统体验复核与独立 QA 都通过前，不得把 Iteration 1 标记为完成或进入 Iteration 2；本报告不作 GATE-2 决定。

报告文件 SHA-256 由写入完成后的外部交接记录绑定；文件自身不能在不改变摘要的情况下内嵌自己的最终摘要。
