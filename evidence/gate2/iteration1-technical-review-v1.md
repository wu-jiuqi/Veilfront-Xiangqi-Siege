# GATE-2 Iteration 1 技术复审 v1

## 1. 结论

- 结论：`revision_required`
- 复审日期：`2026-08-18`
- 冻结候选：`main@5fb174f2400cf2d525425e34f40aa108e2a9dcca`
- 受审任务：`TASK-ARCH-001`、`TASK-SHELL-001`
- Agent Instance：`inst:01M02NJ3JEQXKV6PT6DPX0NKQ0`
- Position：`pos:veilfront-xiangqi-siege:technology:godot-technical-lead`
- Authority：`AUTH-VEILFRONT-GODOT-TECHNOLOGY`
- Contract：`LOOP-CTR-FORMAL-FOUNDATION-GATE2-001@v1`，状态 `approved`

候选在 Godot 4.7.1 下可导入、可加载三个正式场景，预置场景、响应式棋盘、红黑镜像、双会话隔离、行动确认/取消、端口绑定与解绑、Input Map 以及 AI/LAN/互联网/原型运行时隔离均具有可执行证据。但本次源码复核发现四项必须返回生产任务修订的契约缺陷：合法城墙状态会被 PlayerView codec 拒绝；VisibleEvent v1 无法表达已冻结的公开占旗进度；教学权限实际由 presentation Resource 决定且存在绕过入口；相/象高亮违反冻结的信息表现规格。因此当前提交不能作为 `TASK-ARCH-001/TASK-SHELL-001` 的批准基线。

该结论只针对 Iteration 1 冻结候选，不修改规则语义，不否定后续正式核心迁移的技术可行性，也不替代独立 QA 或 GATE-2 人工决定。

## 2. 输入与新鲜度

### 2.1 精确输入摘要

| 输入 | SHA-256 / Git commit | 结果 |
|---|---|---|
| `game-pipeline/loops/contracts/loop-contract-formal-foundation-gate2-v1.yaml` | `a26a9b3fdb0d8d06e42a06833a84455d911fea8f72bcedec59d0ae5e620cc205` | `MATCH / approved` |
| `docs/godot-prompter/plans/iteration1-formal-shell-migration-plan-v1.md` | `4781b95d15bcfafa4846401c771731e7c3d80e0a3c7289812fc95bc1467ce8f7` | `MATCH` |
| `evidence/gate2/iteration1-s1-dependency-guardrails.md` | `071527ad50644695ed942fd70563334ad909557bd62881ba37165d9d8ad3e3af` | `MATCH` |
| `evidence/gate2/iteration1-s2-observer-contracts.md` | `6f02a058c4302e73a7349a0d9702a22f7cab8b2f98a70d9944c14d83f6e215b4` | `MATCH` |
| `evidence/gate2/iteration1-s3-formal-scene-shells.md` | `7c60781c9ab5606f69b8dc3e73696d1f4ea587e78aa46a42a3d990d9d9152e73` | `MATCH` |
| `evidence/gate2/iteration1-s4-board-presentation.md` | `7ae493c5db4538787c189b2a173a6a119b90ffd16c3512ff58e6efe59a723054` | `MATCH` |
| `evidence/gate2/iteration1-s4-layout-snapshots.json` | `46ada6243ae7956e9033248efd4268de2ad2d8646f677f0fd8d70e158e664d47` | `MATCH` |
| `evidence/gate2/iteration1-s5-tutorial-application-shell.md` | `48b4664bfd36725dfa37c6adb1f05cd8fd8d4d3de525355e698b72da527ad662` | `MATCH` |

### 2.2 提交链

| 切片 | 完整提交 |
|---|---|
| I1-S1 | `bcb157f5153cfef2b336bfb524cb8596e165ce1f` |
| I1-S2 | `6b837d9482f55063454c7a8323038af794975eb8` |
| I1-S3 | `0eba387fd544c98ff829905024745cd1f3049378` |
| I1-S4 | `975144e2f56c7d78d150b6a52cbfe32ef57746e5` |
| I1-S5 / 冻结候选 | `5fb174f2400cf2d525425e34f40aa108e2a9dcca` |

五个提交按上表严格互为祖先；复审时 `HEAD` 与 `origin/main` 均为冻结候选。工作树中已有的其他未跟踪文件不属于本任务，未被作为通过证据、修改或清理。

## 3. 技术复核结果

### 3.1 通过项

| 检查面 | 技术判断 | 证据 |
|---|---|---|
| 依赖方向与范围 | `PASS` | 递归扫描 52 个正式文件，17 个扫描器自测通过；正式资产未引用 prototype、AI 或 network；domain/application/projection/presentation/tutorial/ports 的禁止方向已物化。 |
| DTO/port 基础护栏 | `PARTIAL PASS` | canonical JSON、unknown-field 拒绝、观察者绑定、双端口不串线和公开 API 无 viewer selector 可执行；具体合法值域存在第 4.1、4.2 节缺陷。 |
| ApplicationHost 生命周期 | `PASS` | 绑定前先解绑旧 port；六路信号均在 `_exit_tree()`/显式解绑时断开；下行 DTO 深复制；未持有 prototype FullState。 |
| 预置节点优先 | `PASS` | `GameApp`、`MatchScreen`、`TutorialLevel` 及固定 UI、Fog、Marker、Tactical、Interaction 覆盖层均为 `.tscn` 预置；仅棋子、旗帜、墙段、虚影等运行时数量/状态对象使用 PackedScene 实例化。 |
| 响应式棋盘与镜像 | `PASS` | 960×540、1280×720、1920×1080 三档布局测试通过；统一缩放保持正方形交点间距；红黑坐标互为 180° 且 authority 坐标不变。 |
| 会话与交互 | `PASS` | 红黑两个 `GameApp` 同时存在时 PlayerView 和请求日志不串线；确认只在 `CONFIRMING` 状态提交；右键/取消可撤销选中或准备中的献祭且不误确认。 |
| Input Map 与迷雾 | `PASS` | 11 个正式 action 已配置；单一预置 `FogOverlay` 自绘遮罩，没有生成 216 个固定 Control；已发现旗记忆位于迷雾上层。 |
| 范围诚实性 | `PASS` | 当前产物明确为 fixture 驱动的正式壳，不冒充完整规则核心或完整教学；未接入 AI、GATE-1 LAN、互联网 SDK、服务器或 prototype 运行时。 |
| Godot 可行性 | `PASS` | 使用 `Godot 4.7.1.stable.official.a13da4feb` 完成无头导入和全部相关 runner；现有节点、Resource、CanvasItem 自绘与信号方案均受该版本支持。 |

## 4. 必须修订的发现

### 4.1 `I1-TECH-001`：PlayerView wall codec 的合法状态值域错误

- 严重度：`blocking`
- 返回：`TASK-ARCH-001 / I1-S2 observer contracts`
- 证据：`scripts/game/contracts/player_view_codec.gd:113` 只接受 `INTACT|COLLAPSED`；冻结规则 `docs/prototype/rules-spec-v1.md:44,83-90` 定义的是 `INTACT|BREACHED|REPAIRING`，不存在现行 `COLLAPSED`。
- 影响：正式投影一旦发布倒塌或修复中城墙，`veilfront-player-view-v1` 会返回 `INVALID_PAYLOAD`；UI 无法显示城墙状态和破墙区域视野。反之 codec 接受了非现行状态，破坏 DTO 与规则事实源的一致性。
- 覆盖缺口：红黑 fixtures 只包含 `INTACT`，所以 18 项 observer tests 无法发现该问题。
- 重检要求：分别对红黑 PlayerView 以 `INTACT/BREACHED/REPAIRING` 做 canonical round-trip；显式拒绝 `COLLAPSED` 和其他 unknown 状态，并重新运行 observer、board fixture 与 prototype 回归。

### 4.2 `I1-TECH-002`：VisibleEvent v1 禁止了规则已授权的公开 payload

- 严重度：`blocking`
- 返回：`TASK-ARCH-001 / I1-S2 observer contracts`
- 证据：`scripts/game/contracts/visible_event_codec.gd:37-38` 强制 `public_payload` 必须为空；冻结 DTO 文档 `docs/architecture/formal-dto-and-trust-boundary-v1.md:114-121` 要求按 `event_type` 使用字段 allow-list，并明确占旗进度可公开阵营与进度。
- 影响：诸如“红方/黑方正在夺旗 (1/3)”所需的公开进度无法由 `veilfront-visible-event-v1` 表达。后续实现只能拒绝合法事件、改 schema 或绕过 codec；三者都不符合已冻结边界。
- 覆盖缺口：唯一 VisibleEvent fixture 使用空 payload，测试只证明空载荷可往返，没有测试事件级 allow-list、合法非空载荷或越权字段拒绝。
- 重检要求：冻结最小 event-type allow-list；至少覆盖占旗阵营/进度的合法 round-trip、未发现旗不含位置、跨事件字段和 debug/隐藏字段拒绝，以及红黑隐藏等价外形。

### 4.3 `I1-TECH-003`：教学 authority/presentation 物理分文件但未形成实际授权边界

- 严重度：`blocking`
- 返回：`TASK-ARCH-001 + TASK-SHELL-001 / I1-S5`
- 证据：
  - authority Resource 的 `bound_seat`、`allowed_preview_ids`、`restart_allowed`、`skip_allowed` 定义于 `scripts/game/application/tutorial_scenario_definition.gd:4-9`，但 `ApplicationHost` 除了 `has_trusted_tutorial_scenario()` 外未使用这些字段；`request_skip()`/`request_restart()` 在 `scripts/game/application/application_host.gd:69-76` 无条件转发。
  - `scripts/game/tutorial/tutorial_presentation_track.gd:9-10` 又定义 `retry_allowed/skip_allowed`；`scripts/game/tutorial/tutorial_session_policy.gd:8-10` 从 presentation track 取得授权，导致改变表现 Resource 即可改变是否允许重试/跳过。
  - `scenes/game/tutorial/tutorial_level.tscn:46` 将 `MatchScreen.skip_requested` 直接连接到 `ApplicationHost.request_skip`，绕过 `TutorialDirector` 的 presentation policy；同一场景的 overlay skip 则经 Director，形成两条授权路径。
  - 架构基线 `docs/architecture/post-gate1-formal-architecture-review-v2.md:118-120` 要求 `TutorialScenario` 描述绑定 viewer、允许 Intent、重置/跳过条件，由 application 校验；presentation/Director 只能消费安全 DTO。
- 影响：当前文件路径虽然分成 authority 与 presentation，但权限事实源仍可被表现资源控制，且 application 不校验 authority 条件。`allowed_preview_ids` 与 `bound_seat` 也没有形成可执行保护，不能证明教学组合根不会越权提交或切换观察者。
- 覆盖缺口：tutorial smoke 只断言 Director 源码不含 authority 名称，并使用两个 Resource 都为 `true` 的 happy path；它没有构造 authority=false/presentation=true、非法 preview、错误 seat 或直接 MatchScreen skip 的拒绝测试。
- 重检要求：只有 application 侧受信 Scenario/会话策略拥有授权决定；presentation track 只保留文案/步骤显示字段。加入上述四类负向测试，并验证所有跳过、重试、预览准备/确认入口都经过同一 application 授权点。

### 4.4 `I1-TECH-004`：相/象特殊高亮与冻结表现规格相反

- 严重度：`major`
- 返回：`TASK-SHELL-001 / I1-S4 board presentation`
- 证据：冻结信息边界 `docs/prototype/information-boundary-v1.md:62` 要求车完整移动路径为蓝色网格线，相/象只沿田字阻挡九点外沿绘制黄色网格线，扩展侦察并集不单独描边。`scripts/game/presentation/board/tactical_overlay.gd:40-43` 却以黄色粗线绘制 `elephant_reveal_zones`，并以青色细线绘制 `elephant_block_fields`。
- 影响：玩家会把扩展侦察范围误认成田字阻挡范围；真正阻挡范围又没有使用约定黄色，改变了已冻结的信息表达。
- 覆盖缺口：board observer fixture 只检查三个 tactical group 被接收，没有验证颜色、线宽、哪一组应实际绘制或扩展 reveal 必须不描边。
- 重检要求：车路径仅以蓝色沿交点网格线绘制；相/象只描黄色田字阻挡九点外沿；expanded reveal 只参与 Fog/visibility，不生成独立轮廓。为绘制命令或可审查快照增加语义断言，并在三档分辨率和红黑镜像下复核。

## 5. 测试复现

以下命令均从冻结候选使用 Godot 4.7.1 只读执行；结果全部为 0，但不覆盖第 4 节的负向语义：

| Runner | 结果 |
|---|---|
| `--headless --path . --editor --quit` | `PASS` |
| `tests/game/architecture/run_formal_architecture_checks.gd` | `PASS; self_tests=17, scanned_files=52` |
| `tests/game/contracts/run_observer_contract_checks.gd` | `PASS; checks=18` |
| `tests/game/scenes/run_formal_scene_smoke.gd` | `PASS; roots=3, components=16, inputs=11` |
| `tests/game/presentation/run_board_layout_contract.gd` | `PASS; resolutions=3` |
| `tests/game/presentation/run_board_observer_fixture.gd` | `PASS` |
| `tests/game/scenes/run_tutorial_shell_smoke.gd` | `PASS` |
| `tests/prototype/run_all.gd` | `PASS` |

布局 runner 没有留下 tracked 快照变更；复审结束前再次核对冻结快照摘要为 `46ada624...e664d47`。

## 6. 下一合法动作

1. Godot 技术负责人将 `I1-TECH-001/002` 返回 `TASK-ARCH-001`，将 `I1-TECH-003` 返回 `TASK-ARCH-001 + TASK-SHELL-001`，将 `I1-TECH-004` 返回 `TASK-SHELL-001`；在新的功能拆分提交中修订实现与相应负向测试，不修改规则事实源来迎合当前实现。
2. 重新执行本报告第 5 节全部 runner，并补充第 4 节列出的 wall 三状态、非空 VisibleEvent allow-list、教学权限拒绝和高亮语义测试。
3. 生成新的冻结候选和证据摘要后，由技术负责人从头复审；只有技术复审为 `approved`，才交给独立 QA 对同一提交和摘要复现。
4. 当前候选不得登记为 Iteration 1 技术完成，也不得据此启动 `TASK-CORE-001/002` 的行为迁移。互联网、AI 和 LAN 仍保持范围外，不以本次整改为由扩张 Contract。

## 7. 完整性说明

- 本次只新建本报告，没有修改生产代码、测试、Contract、Registry、approval 或历史证据。
- `git diff --check` 与本报告 whitespace check 在定稿后执行。
- 本报告 SHA-256：定稿后在交接中给出，避免自引用改变文件。
