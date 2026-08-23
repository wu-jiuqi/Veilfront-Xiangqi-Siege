# GATE-2 v3 独立 QA 报告

- QA 实例：`inst:01M02NJ3JFHVZ5C4SP5MTJFJR6`
- 候选提交：`1f15a5a3e42f29cff6592e8154d32d40d12b6d9f`
- 候选分支：`main`
- 初检日期：2026-08-23（Asia/Shanghai）
- Contract：`LOOP-CTR-FORMAL-FOUNDATION-GATE2-001` v3
- 本轮结论：`revisions_required / blocked`
- 人工闸门建议：**不得进入 `awaiting_human`**。当前候选存在必要自动检查失败与不可复现项。

## 身份与前置验证

候选开始验收时满足：

- `HEAD` 与 `origin/main` 均为 `1f15a5a3e42f29cff6592e8154d32d40d12b6d9f`；
- `git status --short` 无输出，起始 worktree clean；
- `validate_project_instance.py --project-root "D:\Veilfront Xiangqi Siege"` 退出码 0，项目及插件锁为 `normal`；
- `validate_formal_foundation_gate2_registry.py` 退出码 0，输出 `state=active iteration=3 sequence=61 revision=61`；
- Godot：4.7.1 stable，项目渲染后端为 `gl_compatibility`。

## 执行规则

每个 Godot 脚本均以独立进程、单线程顺序执行，并施加外部硬超时。只有同时满足下列条件才判绿：进程退出码 0、出现指定 PASS marker、完整 stdout/stderr 不含 `SCRIPT ERROR:`、行首 `ERROR:` 或 `FAIL/FAILED`。超时进程被强制终止并等待退出后才启动下一项。

标准命令形态：

```text
D:\Godot\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe --headless --path "D:\Veilfront Xiangqi Siege" --script res://<test.gd>
```

## 回归结果

最终独立结果为 **22 pass / 3 fail / 4 blocked**。最初 120 秒纯超时项仅按约定以 240 秒复验一次；复验通过的项目采用复验结果。

| 项目 | 最终结果 | 时间与证据 |
|---|---|---|
| formal architecture | pass | 94.942s，marker 完整 |
| dependency boundaries | blocked | 120.780s、243.675s 两次纯超时，无 marker/错误文本 |
| formal scene smoke | pass | 首次 120.960s 超时；复验 153.062s pass |
| frontend scene smoke | pass | 53.405s |
| scene transition | pass | 36.924s |
| terracotta theme | pass | 41.664s |
| static UI theme | pass | 首次 120.192s 超时；复验 211.698s pass |
| board camera layer | pass | 91.862s；runner 自检另一次 91.196s pass |
| board layout / resolutions | blocked | 121.096s、240.313s 两次纯超时，无 marker/错误文本 |
| formal board art/input | pass | 首次 120.233s 超时；复验 173.138s pass |
| piece tween | pass | 57.183s |
| wall art | pass | 56.629s |
| flag art | pass | 55.551s |
| formal fog visual | pass | 52.811s |
| turn camera visibility | fail | 83.682s；自方移动后相机位置被重置或移动 |
| hidden equivalence | pass | 75.142s |
| observer contract | pass | 40.907s |
| LAN network integration | fail | 172.718s；3 个权威回合切换断言失败 |
| LAN security/recovery | pass | 82.774s |
| LAN public-state fail-closed | pass | 63.335s |
| LAN full-stack loopback | fail | 243.866s 超时且出现 exclusive child window ERROR，未到最终 marker |
| tutorial rule boundary | pass | 67.560s |
| tutorial layout | pass | 200.597s |
| tutorial pause | pass | 99.696s |
| tutorial chapter content | pass | 55.224s |
| tutorial progress | blocked | 241.265s 纯超时，无 marker/错误文本 |
| challenge terminal | pass | 173.491s |
| match HUD v2 | pass | 132.325s |
| formal equivalence/replay | blocked | 240.089s 纯超时，无 marker/错误文本 |

原始日志位于 `evidence/gate2/v3-candidate-1f15a5a/logs/`。

## 可复现缺陷

### QA-G2V3-001：自方移动会改变相机

- 严重度：阻断 GATE-2 坐标/视角稳定性验收。
- 测试：`tests/game/presentation/run_turn_camera_visibility_contract.gd`
- 结果：exit 1；`TURN_CAMERA_VISIBILITY_CONTRACT_FAIL failures=1`。
- 首错：`ERROR: own move reset or moved the player's camera`，测试回溯第 36 行。
- 返回责任：`TASK-PRESENTATION-2D-001` / Godot 技术负责人。

### QA-G2V3-002：正式 LAN 后续权威回合未按期切换

- 严重度：阻断正式回归与 Windows 包 full-stack 验证。
- 测试：`tests/game/network/run_formal_lan_network_integration.gd`
- 结果：exit 1；前 29 个前置检查通过，最终 `FORMAL_LAN_NETWORK_INTEGRATION_FAILED count=3`。
- 失败断言：黑方移动后未切回红方；房主 skip 后未切玄方；客户端 timeout 后未切赤方。
- 返回责任：正式 LAN application/network 技术实现。

### QA-G2V3-003：同进程 full-stack 的错误对话框互斥冲突

- 严重度：阻断导出包指定 full-stack marker 验证。
- 测试：`tests/game/network/run_formal_lan_full_stack_loopback.gd`
- 结果：240 秒超时，未出现最终 marker。
- 首错：两个 app 根同时创建 exclusive `ConnectionErrorDialog`，Godot 报父窗口已有 exclusive child；回溯 `formal_lan_game_app.gd:171`、`:115` 与 `formal_lan_session.gd:614`、`:587`、`:826`。
- 返回责任：正式 LAN app/错误恢复 UI 技术实现。

## Contract v3 自动检查判定

| Check | 判定 | 独立理由 |
|---|---|---|
| CHECK-CONTRACT-V3-001 | pass | Brief/Contract approval、项目 normal、Git 候选与 Registry 状态均验证通过。 |
| CHECK-DEPENDENCY-001 | blocked | formal architecture 通过，但独立 dependency-boundaries 脚本连续两次无 marker 超时。 |
| CHECK-INFORMATION-2D-001 | pass | hidden equivalence、observer、fog、LAN public-state fail-closed 均通过；未见本候选新增隐藏状态泄露证据。 |
| CHECK-GODOT-2D-001 | pass | 正式场景、前端场景、主题、相机与二维固定资产脚本均在独立进程通过；Godot 4.7.1 可加载。 |
| CHECK-COORDINATE-001 | fail | turn-camera visibility 明确失败；board-layout 亦未能在 240 秒内提供 PASS。 |
| CHECK-RESPONSIVE-2D-001 | blocked | tutorial 三分辨率布局通过，但正式 board-layout 两次超时，且未形成当前候选三分辨率双方截图。 |
| CHECK-PERFORMANCE-2D-001 | blocked | 当前候选已失败，按项目经理指令暂停性能采样；没有可接受的帧率/VRAM/低配验收证据。 |
| CHECK-ART-2D-001 | pass | 棋盘输入、美术、墙、旗、雾、棋子 tween 与 UI 主题代表性检查通过；资产清单由生产交接覆盖。 |
| CHECK-REGRESSION-001 | fail | LAN integration/full-stack 失败，formal equivalence/replay 与 tutorial progress 240 秒无 marker。 |
| CHECK-SCOPE-001 | pass | 验收范围内未观察到把三渲二、互联网 SDK、服务器、AI 或批量高成本资产纳入当前候选的证据。 |

## 独立专业审查

结论：`revisions_required / blocked`。

- 生产者与本 QA 实例分离，起始候选为 clean worktree，独立性成立。
- 信息边界相关代表性检查通过，但二维相机行为与正式 LAN 回归有可复现失败。
- 响应式正式棋盘、性能、双方视角截图及 Windows 导出验证尚无合格证据。
- 旧三维方向仍仅作为后期可选研究资产，不构成本轮自动失败原因。

## 下一合法动作

1. 技术负责人修复 QA-G2V3-001～003，并收敛 dependency、board layout、tutorial progress、formal equivalence 的退出生命周期。
2. 形成新的 clean、已提交候选；不得在 `1f15a5a` 上追加证据并冒充同一构建。
3. QA 对失败/blocked 项定向复验，再执行三分辨率双方截图、性能/VRAM/低配配置证据和 Windows embedded-PCK 导出验证。
4. 所有必要自动检查通过后，才可建议 `awaiting_human`；GATE-2 决定仍仅属于项目所有者。
