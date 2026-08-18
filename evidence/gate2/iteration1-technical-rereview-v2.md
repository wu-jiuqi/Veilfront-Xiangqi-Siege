# GATE-2 Iteration 1 技术复审 v2

## 1. 结论

- 结论：`approved`
- 复审日期：`2026-08-18`
- 冻结候选：`main@47dd52ded8dbe2585d9d0f4fa93c6687624745af`
- 受审任务：`TASK-ARCH-001`、`TASK-SHELL-001`
- 原裁定：`revision_required`
- Agent Instance：`inst:01M02NJ3JEQXKV6PT6DPX0NKQ0`
- Position：`pos:veilfront-xiangqi-siege:technology:godot-technical-lead`
- Authority：`AUTH-VEILFRONT-GODOT-TECHNOLOGY`
- Contract：`LOOP-CTR-FORMAL-FOUNDATION-GATE2-001@v1`，状态 `approved`

本次没有继承原技术审查的判断，而是对新冻结候选重新核对输入、提交链、源码、负向测试与 Godot 4.7.1 运行结果。`I1-TECH-001..004` 均已按裁定关闭；`EXP-I1-001..003` 的整改没有破坏 DTO、authority、端口生命周期或正式壳范围。候选可以作为 Iteration 1 的技术批准基线。

该批准只证明 Iteration 1 fixture-only 正式壳与本轮整改满足 Contract，不等于 Iteration 1 已被三方审查共同关闭，不批准 GATE-2，也不声明正式规则核心、projection、完整教学、美术、AI、LAN 或互联网能力已经交付。

## 2. 输入绑定与新鲜度

### 2.1 审查与整改证据

| 输入 | SHA-256 / Git commit | 核对结果 |
|---|---|---|
| `evidence/gate2/iteration1-technical-review-v1.md` | `d7814a193c912ab42994aefe3a1fcfd1ecdf0fb061d3cbfff4f7f3f2ebb7e5ac` | `MATCH / revision_required` |
| `evidence/gate2/iteration1-review-decision-v1.md` | `93ef463dc920def437bad8a6e682e252da4275e566e96cd95d7798fd966594e3` | `MATCH / revision_required` |
| `evidence/gate2/iteration1-remediation-technical-v1.md` | `c9c797641c3890696c2f68419dc07fec5b49a8f053ac69b0640ab4c0d55c3d48` | `MATCH / remediated_pending_rereview` |
| `evidence/gate2/iteration1-remediation-experience-v1.md` | `0e7959ae6390e5cbfa785d4c79e3326eff8604a16c582fa1aca0d4bbf0b82d36` | `MATCH / ready_for_rereview` |
| 技术整改提交 | `a3a3b298731f1afdb0df37c3d33a99aaabb8f516` | `MATCH` |
| 新冻结候选 | `47dd52ded8dbe2585d9d0f4fa93c6687624745af` | `MATCH / HEAD = origin/main` |

补充核对：原系统体验审查 `fb907bf172c77e318d9fac72828d40e21274735d60982854abf9d09fd87239ee`，原独立 QA `39460d68009fdb234d43d943182b7e8d0f503f71257e3739f028044b240fe0bd`。原 QA 的通过不被当作本次技术批准的替代证据。

### 2.2 Contract、计划与原切片

| 输入 | SHA-256 | 核对结果 |
|---|---|---|
| `game-pipeline/loops/contracts/loop-contract-formal-foundation-gate2-v1.yaml` | `a26a9b3fdb0d8d06e42a06833a84455d911fea8f72bcedec59d0ae5e620cc205` | `MATCH / approved` |
| `docs/godot-prompter/plans/iteration1-formal-shell-migration-plan-v1.md` | `4781b95d15bcfafa4846401c771731e7c3d80e0a3c7289812fc95bc1467ce8f7` | `MATCH` |
| `iteration1-s1-dependency-guardrails.md` | `071527ad50644695ed942fd70563334ad909557bd62881ba37165d9d8ad3e3af` | `MATCH` |
| `iteration1-s2-observer-contracts.md` | `6f02a058c4302e73a7349a0d9702a22f7cab8b2f98a70d9944c14d83f6e215b4` | `MATCH` |
| `iteration1-s3-formal-scene-shells.md` | `7c60781c9ab5606f69b8dc3e73696d1f4ea587e78aa46a42a3d990d9d9152e73` | `MATCH` |
| `iteration1-s4-board-presentation.md` | `7ae493c5db4538787c189b2a173a6a119b90ffd16c3512ff58e6efe59a723054` | `MATCH` |
| `iteration1-s4-layout-snapshots.json` | `46ada6243ae7956e9033248efd4268de2ad2d8646f677f0fd8d70e158e664d47` | `MATCH / 测试后未改写` |
| `iteration1-s5-tutorial-application-shell.md` | `48b4664bfd36725dfa37c6adb1f05cd8fd8d4d3de525355e698b72da527ad662` | `MATCH` |

提交链 `5fb174f2400cf2d525425e34f40aa108e2a9dcca → 33212df5395c18320db03be22fa9ef084f1a1723 → a3a3b298731f1afdb0df37c3d33a99aaabb8f516 → 47dd52ded8dbe2585d9d0f4fa93c6687624745af` 逐段通过 ancestor 检查。共享工作树原有未跟踪文件不属于本任务，未作为通过依据、修改或清理。

## 3. 原技术缺陷重检

| 缺陷 | 结论 | 从头复核证据 |
|---|---|---|
| `I1-TECH-001` wall allow-list | `CLOSED` | `PlayerViewCodec` 现在且仅接受 `INTACT/BREACHED/REPAIRING`；负向测试逐一接受三种现行状态并拒绝 `COLLAPSED`。observer runner 从原 18 项增至 30 项并通过。 |
| `I1-TECH-002` VisibleEvent payload | `CLOSED` | `flag.capture_progress` 使用精确 `{capturing_side, progress}` allow-list；阵营限红/黑，进度限整数 `1..3`。非该事件只允许空 payload；测试拒绝 `position/flag_id/hidden_flag_position/debug`、跨事件复用及越界进度。codec 只验证观察者 DTO 外形，不伪造 projection。 |
| `I1-TECH-003` 教学授权边界 | `CLOSED` | 权限事实只在 application authority `TutorialScenarioDefinition`：`bound_seat`、preview allow-list、restart/skip boolean。presentation track 已删除 retry/skip 权限；Director/SessionPolicy 不读取 authority。prepare/confirm、restart/skip 都在 `ApplicationHost` 经座位验证和 authority 条件校验，MatchScreen skip 只经 Director 进入同一授权点。错误座位、非法 preview、authority=false 和直达旁路均有拒绝测试。 |
| `I1-TECH-004` 特殊高亮 | `CLOSED` | `TacticalOverlay` 只绘制蓝色车路径和黄色相/象田字九点外沿；19 点 reveal 输入保留但绘制计数固定为 0。fixture 使用真实 19 点/9 点数据并断言 `1 / 1 / 19 / 0 / [9]`；坐标 mapper 的红黑 180° 镜像及逆映射另有执行断言。 |

## 4. EXP 整改对技术契约的影响

### 4.1 `EXP-I1-001` 响应式确认面板

- `ActionConfirmationPanel` 仍是 `.tscn` 预置的 `PanelContainer/VBoxContainer/HBoxContainer`，没有以运行时脚本生成固定 UI。
- `MatchScreen` 以底部居中锚点承载组件；960×540、1280×720、1920×1080 均在真实 `CONFIRMING` 状态检查面板、提示和按钮边界，两个确认按钮最小高度为 44 px。
- 棋盘点距保持正方形，9 路未横向裁切；整改没有把点距拉成长方形换取适配。

结论：`CLOSED / 无技术契约回归`。

### 4.2 `EXP-I1-002` prepare-in-flight 取消竞态

- MatchScreen 对每次 prepare 分配本地单调 generation；`PREVIEW_SELECTED` 取消会发送一次端口 cancel，并为该 preview/generation 留下 tombstone。
- 空 cancel 回包不会删除 tombstone；随后到达的旧 prepared 回包先消费 tombstone，不会重开确认面板。
- 负向 fixture 实际延迟 prepared 回包，验证取消后保持 `IDLE`、cancel 恰好一次、confirm 为零。

结论：`CLOSED`。当前 MatchClientPort 没有 request token，因此实现依赖本轮单在途模型以及同一 preview ID 的有序回包；这在当前进程内 fixture 范围成立，未来若端口允许同 ID 并发或乱序，必须先在独立 Contract 中加入 request token，不能沿用 tombstone 假设。

### 4.3 `EXP-I1-003` 高亮语义

语义整改与 `I1-TECH-004` 使用同一生产实现和负向 fixture；没有扩大 PlayerView 字段、读取隐藏事实或把 reveal 误画为阻挡。结论：`CLOSED / 无信息边界回归`。

## 5. 技术边界与 Godot 映射

| 检查面 | 结论 | 证据与判断 |
|---|---|---|
| 依赖方向 | `PASS` | 递归架构扫描自测 17 项、扫描 52 文件通过；formal runtime 无 prototype、AI、LAN、互联网、具体网络传输或反向层依赖。 |
| DTO/codec | `PASS` | canonical、exact-field、unknown-field rejection 继续成立；wall 与占旗公开进度合法值域已补齐，越权位置/debug 有负向拒绝。 |
| application/viewer/authority | `PASS` | 调用者不传 viewer；教学只在收到与预置 `bound_seat` 相符的 PlayerView 后开放安全 DTO 和受保护请求。错误 seat 不接收 PlayerView，也不能 prepare/confirm/restart/skip。 |
| VisibleError/ActionPreview | `PASS` | 仍由 observer codec/port 边界承载，ApplicationHost 只转发绑定会话的深复制 DTO；本整改没有引入 raw error/event 或自选 viewer。 |
| 端口生命周期 | `PASS` | rebind 前完整断开旧 port 六路信号；显式 unbind 与 `_exit_tree()` 复用同一断开路径并清除座位验证；双 `GameApp` 同时运行时 PlayerView 和请求日志不串线。 |
| 预置节点优先 | `PASS` | GameApp、MatchScreen、TutorialLevel、确认面板及固定覆盖层均保留为 `.tscn/.tres`；仅棋子、旗帜、墙段、虚影等按运行时数量实例化 PackedScene。 |
| 响应式/镜像/输入 | `PASS` | 三分辨率、正方形点距、红黑 180° 镜像、11 个 Input Map action、单 FogOverlay 均通过。 |
| Godot 4.7.1 | `PASS` | `4.7.1.stable.official.a13da4feb` 可导入；现有 Resource、PackedScene、Control 锚点、CanvasItem 自绘、信号连接/断开均为该版本可实施方案。 |
| 范围诚实性 | `PASS` | 新提交只修 observer contract、教学授权、确认交互与战术高亮；没有改规则事实源，没有接入 prototype runtime、AI、LAN、互联网、服务器或完整教学内容。 |

## 6. 独立执行命令与结果

从 `HEAD=origin/main=47dd52ded8dbe2585d9d0f4fa93c6687624745af` 执行：

| 命令 | 结果 |
|---|---|
| `D:\Godot\godot.cmd --version` | `4.7.1.stable.official.a13da4feb` |
| `D:\Godot\godot.cmd --headless --path . --editor --quit` | `PASS` |
| `--script tests/game/architecture/run_formal_architecture_checks.gd` | `PASS; self_tests=17, scanned_files=52` |
| `--script tests/game/contracts/run_observer_contract_checks.gd` | `PASS; checks=30` |
| `--script tests/game/scenes/run_tutorial_shell_smoke.gd` | `PASS` |
| `--script tests/game/presentation/run_board_layout_contract.gd` | `PASS; resolutions=3` |
| `--script tests/game/presentation/run_board_observer_fixture.gd` | `PASS` |
| `--script tests/game/scenes/run_formal_scene_smoke.gd` | `PASS; roots=3, components=16, inputs=11` |
| `--script tests/prototype/run_all.gd` | `PASS; scaffold=9, focused_suites=15, full_gate1=false` |
| `git diff --check 5fb174f..47dd52d` | `PASS` |

本次只在新候选上复现 GREEN；RED 的时点和结果通过两份冻结整改证据绑定，并进一步对当前负向测试源码和断言逐项复核，没有把当前绿灯伪称为重新运行了历史 RED。

## 7. 剩余风险与下一合法动作

1. **非阻断——端口关联 ID：** 当前 prepare 回包只含 preview ID。单在途、有序 fixture 已被测试覆盖；任何未来并发、同 ID 重试乱序或真实传输重排都必须先扩展 Contract/request token，并增加乱序测试。
2. **非阻断——projection 尚未实现：** codec 通过只证明 DTO 外形；占旗事件何时对哪个 viewer 发布、未发现旗位置隐藏、红黑隐藏等价仍属于 `TASK-CORE-001/002`，不得把本报告解释为 projection 已完成。
3. **非阻断——教学仍是 smoke 壳：** 固定 preview ID 只验证授权路径；完整 Intent、checkpoint、失败/完成条件与正式教程内容属于后续教学任务。
4. **非阻断——表现验证深度：** 本轮用源码常量、语义快照、三分辨率布局和 mapper 镜像组合验证高亮；最终美术、字体本地化和真实玩家可读性仍需后续系统体验审查与构建实机证据。
5. 下一合法动作：系统与体验负责人、独立 QA 必须对同一 `47dd52d...` 候选和本轮摘要重新审查。只有三方均为 `approved`，项目经理才可关闭 Iteration 1 并按 Contract 启动 Iteration 2；本技术批准本身不授权进入 GATE-2 或扩大范围。

## 8. 完整性

- 本次只新建本报告；没有修改生产、测试、旧证据、Contract、Registry、approval 或规则事实源。
- 报告定稿后运行 YAML parse（Contract）、摘要复核和 `git diff --check`。
- `file_sha256: computed_after_write`（最终摘要在交接消息给出，避免自引用）。
