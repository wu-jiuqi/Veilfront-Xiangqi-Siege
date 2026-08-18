# Iteration 1 系统与体验复审 v2

- 结论：`approved`
- 冻结候选：`main@47dd52ded8dbe2585d9d0f4fa93c6687624745af`
- Contract：`LOOP-CTR-FORMAL-FOUNDATION-GATE2-001@v1`
- 复审身份：`pos:veilfront-xiangqi-siege:design-experience:systems-experience-lead` / `inst:01M02NJ3JENHD8VV7EKC9G198Q0`
- 复审范围：`TASK-SHELL-001` 的玩家体验整改，以及 `I1-TECH-003` authority 拒绝后的玩家状态反馈
- 报告 SHA-256：`computed_after_write`，由外部交接绑定以避免自引用

本结论只表示 Iteration 1 的系统与体验专业复审通过，不替代技术复审、独立 QA、Iteration 完成登记或项目所有者的 GATE-2 人工决定。

## 输入与新鲜度绑定

| 输入 | SHA-256 / Git |
|---|---|
| 原系统与体验复核 `evidence/gate2/iteration1-experience-review-v1.md` | `fb907bf172c77e318d9fac72828d40e21274735d60982854abf9d09fd87239ee` |
| Iteration 1 审查裁定 `evidence/gate2/iteration1-review-decision-v1.md` | `93ef463dc920def437bad8a6e682e252da4275e566e96cd95d7798fd966594e3` |
| 技术整改证据 `evidence/gate2/iteration1-remediation-technical-v1.md` | `c9c797641c3890696c2f68419dc07fec5b49a8f053ac69b0640ab4c0d55c3d48` |
| 体验整改证据 `evidence/gate2/iteration1-remediation-experience-v1.md` | `0e7959ae6390e5cbfa785d4c79e3326eff8604a16c582fa1aca0d4bbf0b82d36` |
| 技术整改提交 | `a3a3b298731f1afdb0df37c3d33a99aaabb8f516` |
| 体验整改及最终冻结提交 | `47dd52ded8dbe2585d9d0f4fa93c6687624745af` |
| Loop Contract 文件 | `a26a9b3fdb0d8d06e42a06833a84455d911fea8f72bcedec59d0ae5e620cc205` |
| Loop Registry Snapshot | `76f3d6c4afd41b4f488a33f4edfd79361b89ab0b3ea23bf1c7cff109e7ccff79` |
| Loop Registry Event History | `50c6b94517584223844de255f6aff28598a68e678a1c1c791cd483454daa9ed9` |

`HEAD` 与 `origin/main` 均指向精确冻结 SHA。整改提交顺序为 `33212df -> a3a3b29 -> 47dd52d`，两份整改证据均在冻结提交中。tracked worktree 在复审前无修改；既有无关 untracked 文件未被读取为证据、修改或删除。

## 自动验证

运行环境：Windows、Godot `4.7.1.stable.official.a13da4feb`、Compatibility renderer。

| 命令 | 退出码与结果 |
|---|---|
| `D:\Godot\godot.cmd --headless --path . --editor --quit` | `0 / PASS`，无导入或脚本错误 |
| `D:\Godot\godot.cmd --headless --path . --script res://tests/game/presentation/run_board_layout_contract.gd` | `0 / BOARD_LAYOUT_CONTRACT_PASS resolutions=3` |
| `D:\Godot\godot.cmd --headless --path . --script res://tests/game/presentation/run_board_observer_fixture.gd` | `0 / BOARD_OBSERVER_FIXTURE_PASS` |
| `D:\Godot\godot.cmd --headless --path . --script res://tests/game/scenes/run_tutorial_shell_smoke.gd` | `0 / TUTORIAL_SHELL_SMOKE_PASS` |
| `D:\Godot\godot.cmd --headless --path . --script res://tests/game/scenes/run_formal_scene_smoke.gd` | `0 / FORMAL_SCENE_SMOKE_PASS roots=3 components=16 inputs=11` |
| `D:\Godot\godot.cmd --headless --path . --script res://tests/game/architecture/run_formal_architecture_checks.gd` | `0 / FORMAL_ARCHITECTURE_CHECKS_PASSED self_tests=17 scanned_files=52` |
| `D:\Godot\godot.cmd --headless --path . --script res://tests/game/contracts/run_observer_contract_checks.gd` | `0 / OBSERVER_CONTRACT_CHECKS_PASSED checks=30` |
| `D:\Godot\godot.cmd --headless --path . --script res://tests/prototype/run_all.gd` | `0 / PROTOTYPE_BASIS_CHECKS_PASSED scaffold=9 focused_suites=15 full_gate1=false` |

为避免改写仓库内旧截图，另将 `47dd52d` 用 `git archive` 导出到系统临时目录，先执行无头 editor import，再以 Compatibility renderer 运行：

```text
D:\Godot\godot.cmd --path <temporary-47dd52d-export> --script res://tests/game/presentation/run_board_layout_contract.gd -- --capture-screenshots
```

结果为 `BOARD_LAYOUT_CONTRACT_PASS resolutions=3`。本次候选即时生成的确认态视觉复核摘要为：

| 分辨率 | PNG SHA-256 | 观察 |
|---|---|---|
| `960×540` | `0c6162c031857f2e6eaaa561db06fa82fabf80c0c4d2e80f7b91642c8601a7d1` | 提示与取消/确认按钮完整，紧凑模式下不越出视口 |
| `1280×720` | `29307aa02a25dd12a4e45a025080d59c6f1880b44731f9db04e8c275c10cd34a` | 面板与右侧战局信息、底部操作栏层级清楚 |
| `1920×1080` | `18853f522255092efdc9981585382058b528e9e3db4983c955dceb65b3822daa` | 面板保持居中且按钮可读，没有随宽屏拉伸 |

对应临时数值快照 SHA-256 为 `4bb322ad9470123db76d9ca09d6552cb069fa62cbf54d3dc556e7f64724d4fd9`；三档的 `confirmation_panel_inside`、`confirmation_prompt_inside`、`confirmation_buttons_inside` 均为 `true`，按钮最小高度均为 `44`。无头 dummy renderer 不提供可用 ViewportTexture，因此视觉截图使用上述非无头 Compatibility renderer 结果，自动矩形断言仍使用无头 runner 独立复现。

## 缺陷关闭复核

### `EXP-I1-001` — 关闭

- 确认面板不再携带组件内部绝对屏幕坐标；正式场景使用水平中心、底部锚点和安全偏移。
- 三档数值矩形与即时截图均证明提示、取消、确认按钮没有裁切；两个确认控件均满足 44 px 最小高度。
- 960×540 下确认面板会覆盖一小部分棋盘，这是模态确认的可接受层级；棋盘仍可辨认，主取消/确认动作没有被遮挡或混淆。

### `EXP-I1-002` — 关闭

- `SELECTED` 的第一次右键仍只取消选择；`PREVIEW_SELECTED` 和 `CONFIRMING` 的第一次右键均取消 prepared action，不打开标记菜单。
- 延迟 fixture 证明 prepare 回包未到时，取消请求到达端口恰好一次，确认请求为零；随后 flush 的迟到 prepared 回包被本地 generation/tombstone 吸收，状态保持 `IDLE`，确认面板不重开。
- 取消后再次右键才进入私有标记菜单，符合玩家已有操作心智。

### `EXP-I1-003 / I1-TECH-004` — 关闭

- 即时三档画面中车仅使用蓝色双线表达移动路径，相/象仅使用黄色边框表达田字阻挡范围；颜色与红色墙线、黑色棋盘线可区分。
- observer fixture 使用真实 19 点 reveal 与 9 点 block，语义快照为：车路径组 `1`、相田组 `1`、忽略 reveal 点 `19`、reveal 绘制组 `0`、相田有效点 `[9]`。
- 19 点扩展侦察继续服务可见性，但没有生成误导性的外接边框；玩家只会把黄色九点框理解为特殊阻挡区。

## 其他玩家体验回归

1. **迷雾、旗帜记忆与虚影**：未发现旗帜不会创建表现节点；已发现旗帜重新入雾后仍显示永久记忆图标，且 Intel 层位于 Fog 上方。被吃虚影从指定观察者 PlayerView 渲染，不读取 raw FullState。
2. **私有标记与交互层级**：未选中时右键打开圆/叉/方标记；选中时优先取消。标记刷新后保留，Interaction 层位于 Marker 层上方，不遮蔽合法行动提示。
3. **双方底部镜像**：红方总部 `Y=1` 与黑方总部 `Y=24` 均映射到各自显示底部；红黑显示坐标互为 180°，逆映射恢复 authority 坐标；X/Y 点距保持正方形。
4. **确认与献祭取消**：`CONFIRMING` 中右键或取消按钮返回 `IDLE` 并发出取消，不提交 Intent；士献祭确认继续使用同一可取消通道。

## 教学 authority 与状态反馈

- authority Resource 是唯一允许 preview、重试和跳过的事实源；presentation track 已不拥有权限。MatchScreen 与教学 Overlay 的跳过都先进入 TutorialDirector，再由 ApplicationHost 统一裁决。
- authority 拒绝重试/跳过时，端口请求数保持零，Director 不会伪造 `RETRYING/SKIPPED` 成功状态，而是留在原 `PROMPTING`；policy 会清除未决请求，玩家可以继续当前提示或再次操作。
- 当前正式 smoke authority 明确允许重试与跳过，所以正常候选中可见按钮都有有效结果；成功时只有 authority resolution 返回 accepted 后才显示 `RETRYING/SKIPPED`。
- 对 synthetic `restart_allowed=false/skip_allowed=false` 或 seat 不匹配，当前壳不会显示专门的“操作被拒绝”提示。由于该拒绝配置不在当前玩家可达 smoke 路径，且本轮只验安全壳、不是完整教学，此项记录为后续教学制作风险，不阻断 Iteration 1；完整教学必须隐藏/禁用不可用按钮或用 `VisibleError/公开状态` 给出可理解反馈，不能沿用静默拒绝。

## 范围判定与剩余风险

本次 `approved` 认可的是 **Iteration 1 正式场景安全壳**：预置主场景能加载，观察者安全 DTO 可驱动棋盘/迷雾/反馈，确认竞态关闭，教学授权点统一。它不表示以下内容已经完成：

- 完整教学章节、玩家文案、checkpoint、失败解释、真正的退出导航；当前 `tutorial.*` key 和固定 smoke step 仍是灰盒。
- 最终棋子、棋盘、UI、动画、特效、音频或 Demo 全量美术；当前图片只证明布局与信息表达，不是最终审美批准。
- 正式规则核心迁移、真实 domain event 生产、互联网联机或 AI 交付。

仍保留两项非阻断风险：

1. `prepared_action_changed` 端口当前不携带 generation；本地 tombstone 依赖 MatchScreen 单在途与同 preview FIFO 回包。未来若允许同 preview 多并发或乱序，必须在正式 Contract 中引入 request token。
2. 完整教学若出现 authority=false 的可见操作，必须在 `TASK-TUTORIAL-001/002` 提供禁用态或拒绝反馈，并加入玩家可见状态断言。

## 结论与下一合法动作

`EXP-I1-001..003` 与 `I1-TECH-004` 在精确冻结候选上均满足关闭条件；迷雾旗帜记忆、虚影、右键标记、红黑镜像和教学观察者/授权边界没有回归，因此系统与体验复审结论为 `approved`。

下一合法动作是由 Godot 技术负责人和独立 QA 分别对同一 `47dd52d` 候选完成复审。只有所有必需专业复审均通过，项目经理才能登记 Iteration 1 完成并按已批准 Contract 进入 Iteration 2；本报告本身不批准 Iteration 2，也不触发 GATE-2。完整教学与最终美术仍须在后续获准迭代中交付。
