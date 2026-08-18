# GATE-2 架构整改技术复审 v2

## 1. 复审结论

- 结论：`approved`
- 复审日期：`2026-08-18`
- Agent Instance：`inst:01M02NJ3JEQXKV6PT6DPX0NKQ0`
- Position：`pos:veilfront-xiangqi-siege:technology:godot-technical-lead`
- Authority：`AUTH-VEILFRONT-GODOT-TECHNOLOGY`
- 复审任务：`game-pipeline/loops/evidence/GATE2-architecture-remediation-rereview-assignment.md`
- 复审范围：REM-G2-002，以及 QA-G2-ARCH-002 / 003 / 004 的技术关闭条件

本次复审从任务指定的同一 SHA-256 输入集重新开始，没有把历史 `architecture-technical-review-v1.md` 的结论作为替代证据。受审方案在 Godot 4.7.1 下可实现；依赖边界、DTO/codec、观察者选择、投影出口、错误与预览外形、回放分级、私有标记、Input Map、动态迷雾及迁移回退均已形成可执行且可测试的约束。未发现需要退回架构或规则负责人的阻断项。

`approved` 仅代表技术岗位认可整改后的架构输入。它不替代独立 QA 复审、项目经理的精确 input binding，也不构成 GATE-2 通过。

## 2. 身份、基线与输入完整性

复审在项目实例校验为 `normal`、Project Brief v5 为 `confirmed` 且审批主题摘要匹配的前提下执行。Godot 命令行版本为 `4.7.1.stable.official.a13da4feb`。任务声明输入基线为 `main@fc22faa`；复审时 HEAD 为 `c06ad4d3864cc5ff6b8c07fac8c14f83cba1da19`，两者之间只有本次复审指派文件的登记提交，以下受审输入摘要没有变化。

| 输入 | 复核 SHA-256 |
|---|---|
| `docs/architecture/post-gate1-formal-architecture-review-v2.md` | `6320614a35dfa03398d6aae53a8b62bbc3f42199e471f98b59590e603bfbe025` |
| `docs/architecture/formal-dto-and-trust-boundary-v1.md` | `6f23274810aad5d6f2515bd78b114da16684e38f9abe04e2d59dcfa87fc174f2` |
| `docs/architecture/gate1-to-formal-migration-manifest-v1.yaml` | `69f784de94296b593d71f08b81ed96a169e61d4a00becc7f1668cfc8082822ec` |
| `evidence/gate2/architecture-remediation-v1.md` | `904b68d92f606ee18d2dcca8e75892c77229673b2d5132cd5813430f48b3db10` |
| `docs/prototype/settlement-order-v1.md` | `7335fb20723e6a36eb961ed50739f590e9e426b927af726ca7fbbe7c6992694a` |
| `docs/prototype/rules-test-coverage-matrix-v1.md` | `5a6c277bbcb74f038953337a7634a1c4e3c7d53bc58b76dfff50d6d2e6f7199b` |
| `evidence/gate2/rules-baseline-revision5-remediation.md` | `a47a80f32b269040b4c872cdf25c9223eb57f097a74ccd7fccc1e4d13fbfaadb` |

架构 v2 正确绑定以下治理事实：Project Brief v5 `confirmed`，摘要 `41bb82fae4f1a0294d17746f3b9caf063ee69d2bd07e0f7d15d26baad9ab89bb`；Contract `LOOP-CTR-FORMAL-FOUNDATION-GATE2-001@v1` 已批准，源摘要 `9beb91baa720820d0f0985019e5a77a4e0e065a8721451eedc30e0cc22bdeaef`；GATE-1 已批准，审批主题摘要 `8f93d103357d6b6b0c670742f3ee88aa1de0f4685473f485ca5a60a52e389ebb`。修订后的规则顺序和覆盖矩阵也绑定至上表的新摘要。

## 3. Godot 4.7.1 技术可行性复核

| 检查项 | 复核结果 | 技术判断 |
|---|---|---|
| 场景与资源映射 | 主界面、棋盘、HUD、迷雾覆盖层和教学覆盖层优先定义为 `.tscn`；规则配置、教学步骤与 Theme 优先定义为 `.tres`。棋子、旗帜、阵亡虚影和临时轨迹允许由预置 `PackedScene` 按运行态数据实例化。 | `approved`；符合预置节点优先原则，动态实例化范围有明确理由。 |
| 确定性规则核心 | 规则域为无 SceneTree 依赖的纯数据/服务；Godot 适配层负责把输入转换为命令，把投影 DTO 转换为表现。 | `approved`；可在 GDScript `RefCounted`/静态服务中实现，并可脱离帧率重跑。该结论仍须由迁移等价测试验证，而非被当作未经验证的冻结事实。 |
| Input Map | ADR 已列出正式 action 名称、鼠标/键盘绑定原则和 UI 输入消费顺序；要求在 Iteration 1 实体化到 `project.godot`。 | `approved`；当前是有责任人和落点的实施义务，不是已完成实现。 |
| 动态迷雾 | ADR 采用一个预置 `FogOverlay: Control`，根据当前 `PlayerView` 在 `_draw()` 中绘制遮罩和穿透区；不为 216 个交点动态创建 Control。 | `approved`；Godot 4.7.1 CanvasItem 绘制模型可行，且避免大量节点和隐藏信息复制。 |
| UI/教学分层 | presentation 和 tutorial 只读取公开投影；教学通过受信 `TutorialScenario` 请求 application 选择观察席位，不自行读取规则私态。 | `approved`；教学引导不成为第二套规则或泄露通道。 |
| 未来网络端口 | endpoint 仅允许提交命令并消费 viewer-scoped DTO；不得接收 FullState、权威回放、raw event/audit 或自选 viewer。 | `approved`；首版不实现互联网服务，但端口隔离不会迫使规则域依赖传输层。 |

## 4. 依赖方向与 deny list

允许方向可扫描为：

`presentation/tutorial/future_endpoint -> application ports -> domain`，以及 `application -> projection -> DTO`。`projection` 是唯一允许从 `FullState` 产生 `PlayerView`、`VisibleEvent`、`VisibleError`、`ActionPreview` 的出口。

受审文档明确禁止：

- presentation、tutorial、future endpoint 直接依赖 domain 的 `FullState`、RNG 或内部规则服务；
- presentation、tutorial、future endpoint 重放 raw event、完整 audit 或 authoritative replay；
- 公开调用方传入任意 viewer，或取得另一席位的投影；
- projection 反向依赖 presentation、tutorial、transport 或具体 Godot 场景；
- ActionPreviewer 读取 FullState，或借预览接口执行隐藏合法性探测；
- 私有标记进入权威状态、状态摘要、回放、投影 codec 或传输消息。

该清单适合用 `tests/game/architecture/check_dependency_boundaries.gd` 自动扫描。扫描器尚未实现，但 manifest 明确把它归入后续任务，不把未来命令冒充为当前通过项；因此不阻断本次架构批准。对应实现任务在验收前必须使扫描器真实存在并通过。

## 5. DTO、权限与信息边界

### 5.1 Codec 基线

codec 采用 UTF-8 canonical JSON：对象键递归排序，数组保持语义顺序，`Vector2i` 编码为 `[x, y]`，摘要为 SHA-256；输入对未知版本、未知字段、重复键、错误类型和越界坐标采用拒绝策略。DTO 不携带 Node、Resource、Callable 或其他 Godot 对象引用。该外形足以支持跨 Godot 进程、测试夹具和未来传输适配器的一致比较。

manifest 冻结 10 个版本化通道：state、event、红/黑 `PlayerView`、红/黑 `VisibleEvent`、`VisibleError`、`ActionPreview`、`AuthoritativeReplay`、`ObserverReplay`。红黑输出分通道固定，避免把 viewer 参数暴露给表现层。

### 5.2 Application / viewer / projection

- application 独占活动 `FullState`，并且只从受信 `SeatContext` 或 `TutorialScenario` 决定 viewer；公开消费者不能覆盖该选择。
- projection 是所有 FullState 到可见 DTO 的唯一出口；表现、教学和未来 endpoint 只消费 DTO。
- `VisibleEvent` 对每个 viewer 使用连续可见序号，不暴露 raw event sequence、被过滤事件数量或隐藏事件间隔。
- 同一 `PlayerView` 和同一公开输入必须得到字节级、顺序级一致的 `ActionPreview`；预览器仅依赖 PlayerView 和公开规则。

### 5.3 VisibleError 与 ActionPreview

`VisibleError` 具有固定字段集合，并把隐藏原因归并到统一错误码、统一消息外形与统一时序桶。`ActionPreview` 具有固定 allowlist 和分类；不得返回隐藏棋子、旗帜、墙体私态、候选总量或隐藏合法性原因。文档给出的六组隐藏等价测试覆盖相同可见状态但不同隐藏状态的事件、错误、预览与序列差异；失败条件包含字段、字节、顺序、数量、错误外形或时序桶不等价。

### 5.4 Replay 分级

| 类型 | 字段与访问 | 拒绝策略 |
|---|---|---|
| `AuthoritativeReplay` | 包含规则状态推进所需命令、权威事件、RNG/seed 与校验摘要；仅规则验证、QA 和受信迁移工具可读取。 | presentation、tutorial、future endpoint 或普通玩家请求时拒绝，不降级返回部分权威内容。 |
| `ObserverReplay` | 仅包含指定席位当时在线可见的 `PlayerView`、`VisibleEvent`、`VisibleError`/`ActionPreview` 帧及公开元数据；每帧必须与实时投影 codec 一致。 | viewer 不匹配、codec 不支持或字段越权时拒绝，不从权威回放在客户端临时过滤。 |

分级消除了通过回放旁路读取 raw event、audit、RNG 或敌方视野的路径。

### 5.5 私有标记

右键圆形、叉形、方形标记是玩家设备上的本地非权威表现状态。它们不进入 FullState、PlayerView、规则 hash、权威/观察者回放或网络消息；因此既不影响确定性，也不能用于向另一方同步隐藏推断。

## 6. 迁移 manifest 可执行性

YAML 使用安全解析并额外检查重复键，结构校验通过。深层复核结果如下：

- RC3 候选提交：`6253678157157091584b253470e709bad17c534f`，对象存在；
- RC3 Windows 构建存在，大小 `109740336` 字节，SHA-256 为 `480273ddeae985c0c4aa03be449e5999fba57ca7b296b591ac7ed36b5bc8a229`；
- manifest 引用的架构、规则、整改证据及固定 seed 资产摘要均与实际文件一致；
- 压测记录为 1000 条，seed 范围严格为 `471001..472000`，无失败和确定性不匹配；
- replay 样本严格为前 20 个 seed：`471001..471020`，并绑定已知回归 seed `471016`；
- state/event、红黑 PlayerView/VisibleEvent、VisibleError、ActionPreview 和两级 replay codec 版本均已列入比较合同；
- 现有 RC3 基线命令引用的候选提交文件均存在；未来迁移比较、隐藏等价与依赖扫描命令明确标记为对应 TASK 必须实现，不被计作当前已通过；
- 共 8 类触发条件要求完整重跑 1000 seeds，覆盖规则、RNG、序列化/codec、投影、错误/预览、回放、迁移适配及依赖边界变化；
- 失败时停止受影响切片，保留 RC3 与失败产物，回退到最近通过的适配层/切片，不覆写 golden，也不得继续扩大迁移。

因此 manifest 已满足 RC3 固定点、seed 清单、replay 样本、codec 比较、命令落点、全量重跑触发和失败回退的最低可复现要求。

## 7. v2 successor binding

`post-gate1-formal-architecture-review-v2.md` 明确声明自己是 v1 的修订后继，v1 只保留为历史证据。由于 Contract 的 `INPUT-ARCH-REVIEW-001` 文字仍指向 v1，项目经理不得沿用旧 input binding 或旧技术审阅；必须在独立 QA 对同一摘要集完成复审后，以本次 v2、DTO/信任边界、migration manifest、整改证据和两份新复审的精确摘要重新登记输入绑定。该受控后继关系可以审计，无需在此次整改中修改已批准 Contract。

## 8. QA 缺陷关闭判断

| 缺陷 | 技术复审判断 | 依据与剩余责任 |
|---|---|---|
| `QA-G2-ARCH-002` | 技术条件可关闭 | v2 已正确绑定 Brief v5、Contract v1、GATE-1 和新规则摘要，并明确 v1 历史化与 successor binding。最终缺陷关闭仍由独立 QA 复审和 PM 精确绑定确认。 |
| `QA-G2-ARCH-003` | 技术条件可关闭 | application/viewer/projection 权限、DTO/codec、VisibleError、ActionPreview、Replay 分级、私有标记和隐藏等价测试外形已完整冻结且可实现。自动扫描与测试实现属于后续 TASK 的验收义务。 |
| `QA-G2-ARCH-004` | 技术条件可关闭 | manifest 已绑定 RC3、1000 seeds、20 replay 样本、10 codec 通道、比较命令、8 类重跑触发和明确回退策略；未来 runner 被如实标为待实现，没有伪造执行证据。 |

本报告不替独立 QA 作最终关闭决定，也不重新裁定不在本次任务范围内的其他缺陷。

## 9. 非阻断实施义务与责任返回路径

以下事项是架构批准后的任务验收条件，不是本次文档复审的阻断：

1. `TASK-ARCH-001` 实现依赖扫描器、正式目录边界、DTO codec、SeatContext 与 projection 单一出口；若出现越层依赖或调用方可自选 viewer，退回 Godot 技术负责人修正，不得由表现层补过滤。
2. `TASK-CORE-001/002` 实现迁移等价 runner、隐藏等价测试及 1000-seed 重跑；任一 state/event/view/error/preview/replay 比较失败时停止该切片，保留 RC3/golden 和失败证据，退回对应规则/投影实现任务。
3. 若差异表明规则语义而非实现不一致，退回系统与体验负责人解释，并由 PM/项目所有者处理范围或规则变更；技术岗位不得静默改写玩法。
4. Iteration 1 将 Input Map 写入项目配置，将 FogOverlay 和正式 UI 根节点落为预置场景；若需偏离预置节点原则，应提交技术证据重新审查。
5. 首版不扩展互联网服务、排位、专用服务器、AI 人机对战或大批量正式美术生产；未来 endpoint 只能在当前端口边界外适配。

## 10. 需要重检项与下一合法动作

需要在实现阶段重检：依赖 deny list 自动扫描、红黑隐藏等价、VisibleError 时序桶、ActionPreview 字节/顺序等价、ObserverReplay 与实时 viewer DTO 一致、codec 拒绝策略、1000-seed 全量回归、Input Map 冲突、FogOverlay 不读取 FullState。

下一合法动作是：独立 QA 使用本报告相同的七份输入摘要完成整改复审；若 QA 同样批准，项目经理记录 v2 successor 的精确输入绑定并执行 loop-start audit。只有 audit 和所需治理条件均通过后才能开始正式生产循环；本报告本身不授权实现，也不批准 GATE-2。

## 11. 验证记录

- Project instance / brief / approval 校验：通过；状态 `normal`、Brief v5 `confirmed`。
- Godot 版本校验：`4.7.1.stable.official.a13da4feb`。
- YAML safe parse、重复键、引用摘要与 manifest 深层结构检查：通过。
- manifest 统计：`records=1000`，`seeds=471001..472000`，`replay=471001..471020`，`codec_channels=10`，`rerun_triggers=8`。
- `git diff --check`：在报告定稿后执行并记录于交接。
- 本报告 SHA-256：定稿后由交接信息给出，避免文档自引用导致摘要变化。
