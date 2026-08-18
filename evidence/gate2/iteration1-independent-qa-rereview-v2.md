# GATE-2 / Iteration 1 独立 QA 复审 v2

- 结论：`revision_required`
- 冻结候选：`main@47dd52ded8dbe2585d9d0f4fa93c6687624745af`
- Contract：`LOOP-CTR-FORMAL-FOUNDATION-GATE2-001@v1`（`approved`）
- QA instance：`inst:01M02NJ3JFHVZ5C4SP5MTJFJR6`
- Position：`pos:veilfront-xiangqi-siege:quality:qa-release-lead`
- Authority：`AUTH-VEILFRONT-QA-RELEASE`
- 受审任务：`TASK-ARCH-001`、`TASK-SHELL-001`

## 1. 判定摘要

冻结候选的实现、负向测试与全部指定 runner 均通过；`I1-TECH-001..004`、`EXP-I1-001..003` 在代码与运行行为层面均满足关闭条件。但冻结整改证据中有一项声明为 SHA-256 的产物摘要是 66 个十六进制字符，且与候选实物的 64 字符 SHA-256 不一致。证据错配不能被自动测试绿灯或前置专业批准覆盖，因此本轮独立 QA 结论为 `revision_required`。

返回范围仅是证据完整性纠正，不要求修改当前通过的生产或测试实现。形成追加式、不可变的纠错绑定后，可对同一候选申请定向 QA 复核；不得改写旧证据。

## 2. 输入、新鲜度与独立性

所有运行检查均在新建的 detached worktree `C:\Users\30114\AppData\Local\Temp\veilfront-i1-qa-v2-47dd52d` 中完成；创建后、首次运行前 `git status --porcelain=v1 --untracked-files=all` 计数为 `0`。

| 输入 | 实算摘要/值 | 结果 |
|---|---|---|
| 冻结候选 | `47dd52ded8dbe2585d9d0f4fa93c6687624745af` | PASS |
| detached HEAD | `47dd52ded8dbe2585d9d0f4fa93c6687624745af` | PASS |
| 本地 remote-tracking `origin/main` | `47dd52ded8dbe2585d9d0f4fa93c6687624745af` | PASS |
| 技术复审 v2 | `54490bdd999e839622daccef02fe45f53fff9a88d494def81c7a34848e3f6eed`，`approved` | PASS |
| 系统与体验复审 v2 | `4665c0dc804734ecc1c12cc701a1522ecc1c40565ecb971c1a2bc8c13e70714e`，`approved` | PASS |
| 技术整改证据 | `c9c797641c3890696c2f68419dc07fec5b49a8f053ac69b0640ab4c0d55c3d48` | 文件摘要 PASS；内部一项产物摘要 FAIL |
| 体验整改证据 | `0e7959ae6390e5cbfa785d4c79e3326eff8604a16c582fa1aca0d4bbf0b82d36` | PASS |
| Loop Contract 文件 | `a26a9b3fdb0d8d06e42a06833a84455d911fea8f72bcedec59d0ae5e620cc205` | PASS |
| Contract approval subject | `9beb91baa720820d0f0985019e5a77a4e0e065a8721451eedc30e0cc22bdeaef` | PASS |

提交链逐段为：

`5fb174f2400cf2d525425e34f40aa108e2a9dcca -> 33212df5395c18320db03be22fa9ef084f1a1723 -> a3a3b298731f1afdb0df37c3d33a99aaabb8f516 -> 47dd52ded8dbe2585d9d0f4fa93c6687624745af`

每段 parent 关系与 ancestor 关系均核对通过；`git diff --check 5fb174f2400cf2d525425e34f40aa108e2a9dcca..47dd52ded8dbe2585d9d0f4fa93c6687624745af` 退出码 `0`。

本 QA 没有把技术或体验报告的 `approved` 当作自身结论，也没有继承旧 QA 的通过判断。

## 3. 独立执行命令与退出码

下表命令的工作目录均为上述 clean detached worktree。

| 检查 | 精确命令 | 退出码 | 关键输出 |
|---|---|---:|---|
| Godot 版本 | `D:\Godot\godot.cmd --version` | 0 | `4.7.1.stable.official.a13da4feb` |
| 项目实例 | `python C:\Users\30114\.codex\plugins\cache\personal\game-production-pipeline\0.4.0-alpha.2\scripts\validate_project_instance.py --project-root .` | 0 | `state=normal`；errors=0；warnings=0 |
| Godot 4.7.1 import | `D:\Godot\godot.cmd --headless --path . --editor --quit` | 0 | 首次扫描和全局类注册完成，无 import/script error |
| 正式架构 | `D:\Godot\godot.cmd --headless --path . --script res://tests/game/architecture/run_formal_architecture_checks.gd` | 0 | `FORMAL_ARCHITECTURE_CHECKS_PASSED self_tests=17 scanned_files=52` |
| observer 合同 | `D:\Godot\godot.cmd --headless --path . --script res://tests/game/contracts/run_observer_contract_checks.gd` | 0 | `OBSERVER_CONTRACT_CHECKS_PASSED checks=30` |
| formal scenes | `D:\Godot\godot.cmd --headless --path . --script res://tests/game/scenes/run_formal_scene_smoke.gd` | 0 | `FORMAL_SCENE_SMOKE_PASS roots=3 components=16 inputs=11` |
| board observer | `D:\Godot\godot.cmd --headless --path . --script res://tests/game/presentation/run_board_observer_fixture.gd` | 0 | `BOARD_OBSERVER_FIXTURE_PASS` |
| 三分辨率确认态布局 | `D:\Godot\godot.cmd --headless --path . --script res://tests/game/presentation/run_board_layout_contract.gd` | 0 | `BOARD_LAYOUT_CONTRACT_PASS resolutions=3` |
| 教学 authority 拒绝 | `D:\Godot\godot.cmd --headless --path . --script res://tests/game/scenes/run_tutorial_shell_smoke.gd` | 0 | `TUTORIAL_SHELL_SMOKE_PASS` |
| prototype 回归 | `D:\Godot\godot.cmd --headless --path . --script res://tests/prototype/run_all.gd` | 0 | `PROTOTYPE_BASIS_CHECKS_PASSED scaffold=9 focused_suites=15 full_gate1=false` |

运行后没有 tracked 变更。Godot import/prototype 生成的未跟踪 UID 只存在于临时 worktree，未作为证据并随临时 worktree销毁。

## 4. `I1-TECH-001..004` 静态与负向复核

| 缺陷 | 代码/负向证据 | 功能判断 |
|---|---|---|
| `I1-TECH-001` wall 状态 | `PlayerViewCodec` 且仅接受 `INTACT/BREACHED/REPAIRING`；生产源码不含 `COLLAPSED`。observer 负向测试接受三种现行状态并拒绝 `COLLAPSED`。 | CLOSED |
| `I1-TECH-002` flag payload deny-list | `flag.capture_progress` 且仅该事件接受精确 `{capturing_side, progress}`；阵营受 side allow-list 限制，progress 为整数 `1..3`。测试拒绝 `position`、`flag_id`、`hidden_flag_position`、`debug`、跨 event-type payload 及进度 0/4。 | CLOSED |
| `I1-TECH-003` 教学 authority | 唯一权限字段位于 application 的 `TutorialScenarioDefinition`：`bound_seat/allowed_preview_ids/restart_allowed/skip_allowed`。presentation track 不含 retry/skip 权限；SessionPolicy 只管理 pending request。`ApplicationHost` 在座位验证后统一校验 prepare/confirm/restart/skip。 | CLOSED |
| `I1-TECH-004` 战术高亮 | `TacticalOverlay` 只迭代 `rook_paths` 与 `elephant_block_fields`；车色为蓝 `Color(0.2,0.64,1.0,...)`，相田为黄 `Color(1.0,0.78,0.18,...)`；`rendered_reveal_count=0`。 | CLOSED |

补充边界：VisibleEvent 的 root `position_public` 是通用 schema 字段；本轮关闭的是 flag `public_payload` allow-list。未发现旗位是否被 projection 留空仍须在 `TASK-CORE-001/002` 用隐藏等价测试验证，不能由 codec 通过推导为 projection 已完成。

## 5. `EXP-I1-001..003` 静态与负向复核

| 缺陷 | 代码/负向证据 | 功能判断 |
|---|---|---|
| `EXP-I1-001` CONFIRMING 响应式 | layout runner 明确对 960×540、1280×720、1920×1080 三档调用 `set_local_interaction_state("CONFIRMING", ...)`；逐档断言 panel、prompt、buttons 均在屏内，按钮最小高度 `>=44` 且提示非空。 | CLOSED |
| `EXP-I1-002` prepare 迟到 | MatchScreen 为在途 prepare 分配 generation，取消时记录 preview tombstone、发送一次 cancel 并清本地状态；延迟 fixture flush 迟到 prepared 回包后仍为 `IDLE`，cancel=1、confirm=0。 | CLOSED |
| `EXP-I1-003` 19/9 高亮语义 | observer fixture 使用真实 19 点 reveal 与 9 点 block；断言车组 1、相田组 1、ignored reveal=19、rendered reveal=0、block cell counts=`[9]`。 | CLOSED |

`TutorialLevel` 的 MatchScreen skip 与 Overlay skip 都先连接到 `TutorialDirector`，再由 Director 请求 `ApplicationHost`；不存在 MatchScreen→ApplicationHost 的 skip 直达连接。教学负向测试还覆盖：

- forbidden preview 的 prepare/confirm 均不进入端口；
- authority 允许的 preview 可进入端口；
- `restart_allowed=false/skip_allowed=false` 时请求计数保持 0，Director 不伪造成功状态；
- `bound_seat=black` 与 red PlayerView 不匹配时，PlayerView 不进入表现层，prepare/confirm/restart/skip 全部拒绝。

## 6. 阻断性证据缺陷

缺陷 ID：`QA-I1-V2-001`

- 严重度：`blocking evidence-integrity`
- 返回：Godot 技术负责人（证据生产者）与项目经理（输入绑定所有者）
- 位置：`evidence/gate2/iteration1-remediation-technical-v1.md` 的 `tutorial_smoke_track.tres` 产物摘要行
- 声明值：`51ad930000b271104468f81b34749bc415c40dc06cf52f4c4f45c872023912a5b3`
- 声明长度：66 个十六进制字符，不是合法 SHA-256
- 冻结候选实算：`51ad930000b271104468f81b34749bc415c40dc06cf52f4c4f45c872023912a5`
- 实算长度：64，且该文件的静态内容满足“presentation 不拥有 retry/skip 授权”要求
- 影响：整改证据无法按其声明摘要精确复现该 Resource；前置专业报告的通过不能把错配证据变成匹配。

同一整改表其余 17 项产物摘要均与冻结候选匹配。这证明缺陷高度局限于证据绑定，但在补正前仍不满足独立 QA 的证据完整性门槛。

关闭条件：新增不可变纠错证据，明确绑定旧错误值、正确 64 字符 SHA-256、文件路径、冻结候选 SHA、错误性质与不修改历史证据的声明；项目经理以该纠错证据更新本轮审查输入索引。若候选代码、测试、Contract 或其他输入摘要发生变化，则必须重新执行受影响的完整复审，不能只做摘要纠错。

## 7. 残余风险

1. MatchClientPort 的 prepared 回包仍不含 request token；当前 tombstone 只在单在途、同 preview FIFO 条件下受证。未来并发或传输乱序必须先扩展 Contract 和测试。
2. codec 只验证 flag 公开 payload 外形；投影是否仅对有权 viewer 发布事件、是否让未发现旗的 `position_public` 为空，仍属于 Iteration 2。
3. authority=false 或 seat 不匹配在当前 synthetic 负向路径是静默拒绝。完整教学必须提供禁用态或 observer-safe 拒绝反馈。
4. 当前教学仍为 fixture smoke 壳，不是完整 Intent/Event 教学章节；当前灰盒也不是最终美术。
5. prototype runner 明示 `full_gate1=false`。本切片未修改规则、projection、随机消费或 replay，未触发 1000-seed 全量重跑；后续 Iteration 2 命中 manifest 触发器时必须执行全量验证。

## 8. 下一合法动作与权限边界

当前不得关闭 Iteration 1，也不得登记进入 Iteration 2。下一合法动作是：技术负责人和项目经理提供 `QA-I1-V2-001` 的追加式纠错绑定；随后由独立 QA 对同一冻结候选和新增绑定做定向复核。当前功能缺陷无需重开，除非输入发生变化。

本报告不批准 GATE-2，不授权互联网/Steam、服务器、AI、LAN 正式化或批量美术。GATE-2 仍由项目所有者保留。

`file_sha256: computed_after_write`；最终报告 SHA-256 由交接消息提供，避免自引用改变文件摘要。
