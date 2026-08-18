# GATE-1 后正式架构审查 v2

状态：`revised / awaiting REM-G2-003 dual re-review / second loop not started`

本文是 `docs/architecture/post-gate1-formal-architecture-review-v1.md` 的修订后继。v1 及其历史技术/QA审阅保持不变，只作审计证据；Contract `INPUT-ARCH-REVIEW-001` 虽以 v1 路径描述输入，项目经理必须以本 v2 的精确 SHA-256、规则整改摘要、迁移 manifest 与新一轮双审结果重新绑定，不能沿用 v1 的审阅或摘要。

## 1. 当前已批准基线

| 基线 | 状态与精确身份 |
|---|---|
| Project Brief v5 | `confirmed`；subject digest `41bb82fae4f1a0294d17746f3b9caf063ee69d2bd07e0f7d15d26baad9ab89bb`；approval `approval:veilfront-xiangqi-siege:project-brief:41bb82fae4f1`；物化 SHA-256 `276d777409f6218c2448e4886879216e09b4e2ea9fa2118f595dc30f14c551e9` |
| Loop Contract v1 | `LOOP-CTR-FORMAL-FOUNDATION-GATE2-001@v1 / approved`；approved source digest `9beb91baa720820d0f0985019e5a77a4e0e065a8721451eedc30e0cc22bdeaef`；approval `approval:veilfront-xiangqi-siege:loop-contract:9beb91baa720`；物化 SHA-256 `a26a9b3fdb0d8d06e42a06833a84455d911fea8f72bcedec59d0ae5e620cc205` |
| GATE-1 | `approved`；approval `approval:veilfront-xiangqi-siege:gate-1:8f93c3506192`；subject digest `8f93c3506192b1e286bd5f1bf631054f9fb3f0dc5337f3050716a2186a383597` |
| GATE-1 RC3 | candidate commit `6253678157157091584b253470e709bad17c534f`；独立 QA evidence index `evidence/prototype/qa/gate1-rc3-evidence-index.yaml` SHA-256 `be64807394e3f05ed8e1e4366a0a3f88ad2cc78bfef932b3f1f20c411e4eb650` |
| Revision 5 规则规格 | `docs/prototype/rules-spec-v1.md` SHA-256 `f5158daa0e0235f9cca31ee4411ab1ae647e6ff20019c3316c8f8d35d91f61ab` |
| Revision 5 结算顺序 | `docs/prototype/settlement-order-v1.md` SHA-256 `7335fb20723e6a36eb961ed50739f590e9e426b927af726ca7fbbe7c6992694a` |
| Revision 5 信息边界 | `docs/prototype/information-boundary-v1.md` SHA-256 `dd76596fb4e196732ea73da9cefc33f3879b3102df345b46f55cf00fe7c17d07` |
| Revision 5 覆盖矩阵 | `docs/prototype/rules-test-coverage-matrix-v1.md` SHA-256 `5a6c277bbcb74f038953337a7634a1c4e3c7d53bc58b76dfff50d6d2e6f7199b` |
| 规则整改证据 | `evidence/gate2/rules-baseline-revision5-remediation.md` SHA-256 `a47a80f32b269040b4c872cdf25c9223eb57f097a74ccd7fccc1e4d13fbfaadb`；关闭 `QA-G2-ARCH-001` 与 `QA-G2-ARCH-003` 的设计侧部分 |

整改代码库水位：`main@0de8bb5e29a8a0731731f978dad6f568ff0bb51e`。本报告不把该水位声明为正式架构实现；它只绑定输入事实。

## 2. 修订结论

GATE-1 已证明 revision 5 规则核心、确定性随机、按观察者投影、回放与局域网真人验证可行；当前 `scripts/prototype/`、`scenes/prototype/` 仍只是一套不可直接晋升的验证载体。

第二生产循环技术上可行，但只有 REM-G2-003 对本 v2、`formal-dto-and-trust-boundary-v1.md` 与 `gate1-to-formal-migration-manifest-v1.yaml` 的精确摘要重新双审均为 `approved` 后，项目经理才可绑定 `INPUT-ARCH-REVIEW-001` 并登记循环。当前不得实现正式架构、推进 GATE-2、接入互联网、交付 AI 或启动高成本批量美术。

## 3. 正式架构边界

```text
res://
├─ assets/{art,audio}/
├─ resources/game/{rules,tutorials,ui,content}/
├─ scenes/game/{app,match,tutorial,ui}/
├─ scripts/game/
│  ├─ contracts/       # 版本化 codec 与观察者 DTO；无场景引用
│  ├─ domain/          # FullState、DomainCommand/Event、规则、结算、规则 RNG
│  ├─ application/     # 唯一 FullState owner、SeatContext/viewer、用例与内部端口
│  ├─ projection/      # 唯一 FullState→观察者 DTO 出口
│  ├─ tutorial/        # 只调用绑定 viewer 的 application facade
│  ├─ presentation/    # Control 场景适配与本地私有标记
│  └─ ports/           # application 拥有的接口与本轮进程内测试替身
└─ tests/game/{domain,contracts,migration,scenes,architecture}/
```

现有 `scripts/prototype/`、`scenes/prototype/`、`resources/prototype/` 与 `tests/prototype/` 保持原路径和可运行状态，不创建含糊的根级 `prototype/` 迁移目录。

### 3.1 依赖方向

```text
presentation / tutorial / in-process endpoint
                    │
                    ▼
             application facade
               │             │
               ▼             ▼
             domain       projection
                               │
                               ▼
                    domain read-only contracts
```

- application 独占活跃 FullState 和 viewer 选择。调用者不传 viewer；application 从 SeatContext 或受信任 TutorialScenario 绑定。
- projection 是唯一允许读取 FullState 并产生 PlayerView、VisibleEvent、VisibleError 与 ActionPreview 的出口。ActionPreview 子组件只读取 PlayerView 和公开规则配置。
- domain 不依赖 application、projection、场景、表现、教学、AI、LAN 或未来网络。
- presentation、教学与未来 endpoint 禁止 FullState、raw DomainEvent/DomainError、full audit、AuthoritativeReplay、规则 RNG、任意 viewer 选择和另一观察者 DTO。
- 私有圆/叉/方形标记只存在本地 presentation repository；不进入 authority、PlayerView、replay、摘要或传输。

具体 DTO 字段、codec、访问权、拒绝策略、Replay 分级、隐藏等价测试与可扫描禁止清单冻结在 `docs/architecture/formal-dto-and-trust-boundary-v1.md`。

## 4. 原型事实与必须拆除的耦合

- `scripts/prototype/core/rule_engine.gd` 当前反向预加载 `player_view_projector.gd`，projector 又依赖 `MatchState/MoveRules`。正式迁移必须先把权威可见性/接触判定提取为 domain 纯规则，禁止把回环复制到 `scripts/game/`。
- `player_view_projector.gd` 同时承担视野、PlayerView、preview 与 AI export；正式结构拆为 authority-side visibility policy、observer projector、visible outcome projector 与 PlayerView-only previewer。
- `match_controller.gd` 直接依赖 AI 与四档 AI Resource；正式 application 组合根不得引用它们。
- `gate1_logic_lab.gd` 和 `board_surface.gd` 混合 UI 接线、规则调用、镜像、迷雾、标记与网络模式；正式场景只消费观察者 DTO，不复制规则判断。
- LAN 目录冻结为回归工具，不进入正式 `ports` 实现；本轮未来 endpoint 只有接口与进程内替身。

## 5. DTO、事件与 Replay 决定

| 类型 | 所有者/访问 | 正式决定 |
|---|---|---|
| FullState | application 持有；domain 处理；projection 只读 | `veilfront-full-state-v1`，永不对外 |
| DomainEvent/Error | domain/application/受控审计 | raw 字段允许精确结算，但禁止玩家通道 |
| PlayerView | projection→绑定 viewer | allow-list decoder；未发现旗位为空；无 seed/RNG/敌方私有源 |
| VisibleEvent | projection→绑定 viewer | per-viewer 连续序号，不复制 raw sequence |
| VisibleError | projection→绑定 viewer | 隐藏失败固定字段、统一 code/message/timing bucket |
| ActionPreview | PlayerView-only previewer→绑定 viewer | `KNOWN_LEGAL/TENTATIVE/KNOWN_ILLEGAL`；相同 view 字节等价 |
| AuthoritativeReplay | authority/迁移 harness/QA 审计 | 含 seed、FullState/raw event/RNG 时永久不可分发 |
| ObserverReplay | application 为绑定 viewer 生成 | 仅实时已见 DTO 的字节等价 frame，篡改 viewer 或 digest 整体拒绝 |

## 6. Godot 产物映射

| Contract 产物 | Godot 类型 | 正式路径/决定 |
|---|---|---|
| 应用组合根 | 预置 `Control` 场景 | `scenes/game/app/game_app.tscn`；注入 application/projection，不预加载 AI/LAN |
| 对局与 HUD | 组合式预置场景 | `scenes/game/match/match_screen.tscn` |
| 棋盘与覆盖层 | 独立预置子场景 | `scenes/game/match/board/*.tscn`；输入、迷雾、标记、特殊高亮分层 |
| 教学 | 预置场景 + `.tres` | `scenes/game/tutorial/tutorial_level.tscn`、`resources/game/tutorials/*.tres` |
| 规则/内容/UI | 自定义 `.tres` + Theme | `resources/game/{rules,content,ui}/`；不把 mutable FullState 当 Resource |
| DTO/codec | `RefCounted`/静态脚本 | `scripts/game/contracts/`；无 Node/SceneTree 引用 |
| 棋子/旗帜/虚影/临时轨迹 | PackedScene 运行时实例 | 数量/生命周期由对局决定，允许动态实例化 |
| 迷雾 | 一个预置 `FogOverlay` Control | `ADR-GODOT-FOG-001`：单一绘制层按 PlayerView 更新，不生成固定 216 个 Control |
| 玩家输入 | `project.godot` Input Map | `ADR-GODOT-INPUT-001`：正式动作集中配置，不以硬编码按键为唯一入口 |

### 6.1 `ADR-GODOT-INPUT-001`

ITERATION-1 必须把以下逻辑动作物化到 Input Map：`board_select`、`board_cancel_or_marker`、`board_confirm`、`board_pan_up/down/left/right`、`board_zoom_in/out`、`tutorial_skip`、`ui_cancel`。鼠标、键盘或未来手柄只是绑定；表现代码只监听动作。右键的“先取消选中、再次打开标记”由 presentation 状态机处理，不提交 domain Intent。

### 6.2 `ADR-GODOT-FOG-001`

24×9 棋盘格数固定，动态生成 216 个 Control 没有数量优势。正式灰盒使用预置 `FogOverlay` 单一 Control/绘制层，输入为 PlayerView 的可见格与棋盘变换；镜像只改变绘制坐标，不改变 authority 坐标。若性能证据要求改用缓存纹理或 MultiMesh-like canvas 方案，必须新 ADR，不能用运行时生成整套固定 UI 树规避预置原则。

## 7. 教学边界

`TutorialScenario` Resource 描述固定初始局面引用、绑定 viewer、步骤、允许 Intent、提示 key、checkpoint、完成/失败/重置/跳过条件。application 校验并绑定 viewer；TutorialDirector 不得自选观察者。

教学只能消费指定观察者的 PlayerView、VisibleEvent、VisibleError 与 ActionPreview。脚本化敌方行动也提交 NormalizedIntent；教学目标不能读取 raw DomainEvent、FullState、权威 replay 或隐藏事实。若某步骤无法从安全 DTO 判断，返回系统与体验负责人重写步骤或要求规则侧产生经 viewer 过滤的公开事件，不建立教学旁路。

## 8. 迁移顺序与行为锁

1. REM-G2-003 对 v2、DTO 文档、manifest 的精确摘要完成双审；项目经理绑定 `INPUT-ARCH-REVIEW-001` 后才可启动循环。
2. ITERATION-1 冻结 codec、依赖扫描、Input Map、场景 map 与上述 ADR，建立不依赖 AI/LAN 的预置壳。
3. 在任何正式代码迁移前，由 RC3 `6253678...` 生成 manifest 指定的 golden snapshot pack。
4. 迁移 canonical、seeded random、FullState codec 与权威 replay；比较 state/event digest。
5. 先拆除 rule_engine→projector 回环，再按结算窗口迁移 domain/application。
6. 迁移 projection，同时比较红/黑 PlayerView、VisibleEvent、VisibleError 与 ActionPreview；隐藏等价配对必须通过。
7. 接入正式预置棋盘/HUD 与教学，只走 application facade。
8. 若触发 manifest 的全量条件，重跑 1000 seeds、20 replay、tamper rejection；独立 QA 从 clean worktree 复现。

迁移事实源与命令冻结在 `docs/architecture/gate1-to-formal-migration-manifest-v1.yaml`。任何不等价都返回当前迁移切片，保留 RC3 和失败证据，不修改 golden 使其“通过”。

## 9. 可扫描禁止规则

正式 ITERATION-1 必须建立递归扫描器并至少执行以下断言：

- `domain/**` 不含 Node/Control/SceneTree/scenes/application/projection/presentation/tutorial/ports/network/AI/prototype 引用。
- `application/**` 不含具体场景、presentation、tutorial、network、AI、prototype；公开签名不暴露 FullState/viewer 参数。
- `projection/**` 不修改 FullState，不引用消费者或具体传输，不暴露公开 viewer 选择入口。
- `presentation/**`、`tutorial/**` 与未来 endpoint 不含 domain/projection/raw event/FullState/AuthoritativeReplay/RNG/full audit 引用。
- 正式组合根不预加载原型 AI Resource、LAN session 或 protocol。

精确 deny list 与失败标准见 DTO 文档第 8 节；目标扫描器为 `tests/game/architecture/check_dependency_boundaries.gd` 或等价工具，任一命中退出非零。

## 10. 回归与信息安全重检

- 同一 Intent 序列逐行动比较 FullState digest、DomainEvent digest、红/黑 PlayerView digest、红/黑 VisibleEvent digest；VisibleError/ActionPreview 按发生时比较 canonical 字节。
- 固定隐藏配对覆盖未发现旗位、隐身马/腿、敌相田来源、隐藏炮架、未来 RNG 和私有标记。
- 隐藏失败的 VisibleError 必须具有相同字段、public code、message key、consumed 与 timing bucket。
- ObserverReplay frame 必须与实时观察者 DTO 字节等价；AuthoritativeReplay 和 seed 下发必须被 public decoder/endpoint 拒绝。
- 触及规则、结算、随机消费、codec 字段/顺序、projection 或 replay 时，按 manifest 重跑 1000-seed；manifest 正常验证为 0，强制篡改必须非 0。

## 11. 本轮仍明确不做

- 不接入 Steam Networking、SDR、NAT、Relay、专用服务器、匹配、账号、重连、观战、聊天或部署。
- 不提升、训练或交付 AI 人机对战。
- 不启动全套棋子动画、完整音频、最终 UI 或批量特效生产。
- 不修改 owner revision 5、50 回合实验参数或随机序列来适配架构。
- 不把文档整改、双审或循环启动解释为 GATE-2 完成。

## 12. 缺陷关闭映射与下一合法动作

| QA 缺陷 | v2 关闭产物 | 当前状态 |
|---|---|---|
| `QA-G2-ARCH-002` | 本报告绑定 confirmed Brief、approved Contract、GATE-1 与修订规则摘要；声明 v2 successor 与重新 binding | `ready_for_re-review` |
| `QA-G2-ARCH-003` | `formal-dto-and-trust-boundary-v1.md` 冻结 FullState/viewer/projection/Visible DTO/replay/私有标记/测试 | `ready_for_re-review` |
| `QA-G2-ARCH-004` | `gate1-to-formal-migration-manifest-v1.yaml` 绑定 RC3、seed/replay/codec/命令/触发与回退 | `ready_for_re-review` |

下一合法动作只有 REM-G2-003：计算本 v2 及关联两份架构产物摘要，由 Godot 技术负责人和独立 QA 对同一组摘要重新审阅。两份复审均为 `approved` 后，项目经理以 v2 新摘要满足 `INPUT-ARCH-REVIEW-001`，再登记第二生产循环；不得沿用 v1 技术审阅的 `approved` 或 v1 QA 的 `blocked` 作为 v2 结论。
