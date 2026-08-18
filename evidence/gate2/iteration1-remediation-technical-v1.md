# GATE-2 Iteration 1 技术边界整改证据 v1

## 1. 整改结论

- 结论：`remediated_pending_rereview`
- 日期：`2026-08-18`
- 整改基线：`main@33212df5395c18320db03be22fa9ef084f1a1723`
- 原受审生产水位：`5fb174f2400cf2d525425e34f40aa108e2a9dcca`
- 返回任务：`TASK-ARCH-001 + TASK-SHELL-001`
- 关闭候选：`I1-TECH-001`、`I1-TECH-002`、`I1-TECH-003`
- 不在本证据范围：`I1-TECH-004` 棋盘特殊高亮，由其独立文件所有者整改
- Agent Instance：`inst:01M02NJ3JEQXKV6PT6DPX0NKQ0`
- Position：`pos:veilfront-xiangqi-siege:technology:godot-technical-lead`
- Authority：`AUTH-VEILFRONT-GODOT-TECHNOLOGY`

三项技术边界缺陷均先建立负向测试并获得可信 RED，再用最小实现转为 GREEN。整改没有引入正式规则核心、真实 domain event 生产、AI、LAN 或互联网能力；当前仍是 fixture-only 的正式壳。是否正式关闭缺陷须由新的技术复审和独立 QA 对同一候选重新判断。

## 2. RED 证据

### 2.1 Observer codec RED

命令：

```text
D:\Godot\godot.cmd --headless --path . --script tests/game/contracts/run_observer_contract_checks.gd
```

在只修改测试、尚未修改生产实现时，可信 RED 为 `checks=30, failures=4`：

1. `flag capture progress VisibleEvent decode 失败: invalid_payload`；
2. 合法城墙状态 `BREACHED` 被拒绝；
3. 合法城墙状态 `REPAIRING` 被拒绝；
4. 非现行城墙状态 `COLLAPSED` 未被拒绝。

首次 RED 中曾因 parse/stringify 改变 canonical JSON 而误报 `INTACT`；该测试构造已在实现前改为对冻结 canonical fixture 做定点字符串替换，并重新取得上面的四项可信 RED。该修正没有接触生产代码。

### 2.2 Tutorial authority RED

命令：

```text
D:\Godot\godot.cmd --headless --path . --script tests/game/scenes/run_tutorial_shell_smoke.gd
```

在只修改测试、尚未修改生产实现时得到 `failures=16`，覆盖：

- 非 allow-list preview 的 prepare/confirm 被转发；
- authority=false 的 restart/skip 仍被转发且改变 Director 状态；
- MatchScreen skip 仍直达 ApplicationHost，没有经过统一路径；
- `bound_seat=black` 的 Scenario 接收了 red PlayerView 并可提交请求；
- presentation track 仍拥有 `retry_allowed/skip_allowed`。

## 3. 实现映射

### 3.1 `I1-TECH-001` — wall 状态

- `PlayerViewCodec` 的 wall allow-list 改为且仅为 `INTACT/BREACHED/REPAIRING`。
- `COLLAPSED` 与其他未授权值通过现有 exact-field/canonical decoder 拒绝。
- observer test 对三个合法状态分别做 canonical decode，并显式验证 `COLLAPSED` 拒绝。

### 3.2 `I1-TECH-002` — VisibleEvent 最小事件级 payload allow-list

- `fixture.ready` 等非夺旗事件仍只允许空 `public_payload`。
- `flag.capture_progress` 且仅该事件允许精确字段 `{capturing_side, progress}`。
- `capturing_side` 必须为红或黑；`progress` 必须是 `1..3` 的整数。
- exact-field 校验拒绝 `position`、`flag_id`、`hidden_flag_position`、`debug` 以及任何其他越权字段；把同一 payload 挂到其他 event type 也会拒绝。
- 事件 DTO 不含旗坐标；是否向某 viewer 发布该事件仍归后续 projection，不在 fixture codec 中伪造规则。

### 3.3 `I1-TECH-003` — application 独占教学授权

- `TutorialScenarioDefinition` 保留唯一 authority 字段：`bound_seat`、`allowed_preview_ids`、`restart_allowed`、`skip_allowed`；校验空/重复 preview ID。
- `TutorialPresentationTrack` 和对应 `.tres` 删除 retry/skip 权限字段，只保留 track、步骤、文案 key 和可见事件触发 key。
- `ApplicationHost` 在 tutorial Scenario 存在时：
  - 只在首个 PlayerView 的 `viewer_side` 等于 `bound_seat` 后开放该会话；不匹配时不向表现/教学转发 PlayerView、VisibleEvent、VisibleError、ActionPreview 或 prepared state；
  - prepare/confirm 仅转发 authority allow-list 中的 preview ID；
  - restart/skip 仅在 seat 已验证且 authority boolean 为 true 时转发；
  - 普通 `GameApp` 没有 TutorialScenario，保持原端口行为，不把教学策略施加到普通对局壳。
- `TutorialDirector` 只发出重试/跳过请求；收到 ApplicationHost 的 `tutorial_request_resolved(request, accepted)` 后才改变公开教学状态。`TutorialSessionPolicy` 只跟踪未决表现请求，不读取或拥有权限。
- `TutorialLevel` 将 MatchScreen 与 Overlay 的 skip 都路由到 Director，再进入 ApplicationHost 的同一授权点；已移除 MatchScreen→ApplicationHost 的直达旁路。

## 4. 修改文件与最终摘要

| 文件 | SHA-256 |
|---|---|
| `scripts/game/contracts/player_view_codec.gd` | `a9c91d2747414d088eb4bb9eba59f15d5f9110815268322b51c693440238d3fd` |
| `scripts/game/contracts/visible_event_codec.gd` | `3549c66e389eaa20e58ebf3ae86d6e044e1e69b1631192295efe0cdf053f541c` |
| `scripts/game/application/application_host.gd` | `0d483a6cb84bdc40a0f8e08fa8813e2360d2caad36ca5d47f99f3ae1e46e675c` |
| `scripts/game/application/tutorial_scenario_definition.gd` | `c402ce0620733478a470b2827fa2396a742b899ef3b57ab9baa690c30b77b20d` |
| `scripts/game/tutorial/tutorial_presentation_track.gd` | `20d562868afd1483528c84d2c0f5b88df6718f750d02b8244630149c45c2a5b3` |
| `scripts/game/tutorial/tutorial_session_policy.gd` | `a7c888f87cd1d70d428fab2d41b31e9161e4d2f42cf08ab2d08a940b2c2959a8` |
| `scripts/game/tutorial/tutorial_director.gd` | `fe3f38c09fe526e1055c117d7b7d2a649caff94050336fbd0a9596386b7f3083` |
| `resources/game/tutorials/presentation/tutorial_smoke_track.tres` | `51ad930000b271104468f81b34749bc415c40dc06cf52f4c4f45c872023912a5b3` |
| `scenes/game/tutorial/tutorial_level.tscn` | `4a17ddba8642b0086c46609323fe53d7a1730367d5125ea2369156f98dfc56a3` |
| `tests/game/contracts/test_observer_codec_allow_lists.gd` | `9892b82259d10b96250fd5233c55260ec67fd01918eabb14afa060d4fe4d0db2` |
| `tests/game/scenes/run_tutorial_shell_smoke.gd` | `cbced53cafbbc80afe1bee83e7a0aa8966af95601111e2b8b1bcd460f4d72923` |

`resources/game/tutorials/authority/tutorial_smoke_authority.tres`、两个 runner、fixture port 和棋盘表现文件无需由本整改修改。共享工作树同时存在其他已授权整改者对 MatchScreen、棋盘高亮与其测试替身的并行变更；本 Agent 没有回退、覆盖或将这些文件计入自身产物。

## 5. GREEN 与回归

运行环境：`Godot 4.7.1.stable.official.a13da4feb`，GL Compatibility，GDScript。

| 检查 | 结果 |
|---|---|
| 无头 editor import | `PASS` |
| `tests/game/architecture/run_formal_architecture_checks.gd` | `PASS; self_tests=17, scanned_files=52` |
| `tests/game/contracts/run_observer_contract_checks.gd` | `PASS; checks=30` |
| `tests/game/scenes/run_formal_scene_smoke.gd` | `PASS; roots=3, components=16, inputs=11` |
| `tests/game/presentation/run_board_layout_contract.gd` | `PASS; resolutions=3` |
| `tests/game/presentation/run_board_observer_fixture.gd` | `PASS` |
| `tests/game/scenes/run_tutorial_shell_smoke.gd` | `PASS` |
| `tests/prototype/run_all.gd` | `PASS; scaffold=9, focused_suites=15, full_gate1=false` |

架构扫描曾在自审中拒绝公开 `matches_bound_seat(viewer_side)` 签名；最终实现删除该公开 viewer 参数入口，由 ApplicationHost 对已接收 PlayerView 与 authority `bound_seat` 内部比较。重跑后依赖扫描为 0 违规。

棋盘布局 runner 运行后，`evidence/gate2/iteration1-s4-layout-snapshots.json` 摘要仍为 `46ada6243ae7956e9033248efd4268de2ad2d8646f677f0fd8d70e158e664d47`，没有留下 tracked 测试副作用。

## 6. 限制与下一合法动作

1. 本整改只冻结 DTO allow-list 和 fixture tutorial authority 壳；没有实现正式 projection、domain event 产生器、完整教程章节或真实对局规则迁移。
2. `flag.capture_progress` 的投影条件、可见序号和未发现旗位置隐藏仍须在 `TASK-CORE-001/002` 使用隐藏等价测试验证；不得把 codec 通过解释为 projection 已完成。
3. authority Scenario 当前以固定 preview ID 驱动 smoke；完整允许 Intent、checkpoint、失败/完成条件属于后续 `TASK-TUTORIAL-001/002`。
4. 下一合法动作是把本整改与并行的 I1-TECH-004/QA 整改组合为新的冻结候选，核对本表摘要后进行技术复审与独立 QA；未经复审不得把 Iteration 1 标记为完成。
5. 未提交、未推送；未修改 Contract、Registry、approval、规则事实源或范围外文件。

## 7. 完整性

- `git diff --check` 与本报告 no-index whitespace check：定稿后执行。
- 本报告 SHA-256：定稿后由交接给出，避免自引用改变文件。
