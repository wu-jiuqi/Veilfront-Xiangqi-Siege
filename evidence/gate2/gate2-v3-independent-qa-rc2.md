# GATE-2 v3 独立 QA 报告（RC2）

- QA 实例：`inst:01M02NJ3JFHVZ5C4SP5MTJFJR6`
- 候选提交：`e0f3252bf0a90d4c329f5e6113517324266c54b7`
- Contract：`LOOP-CTR-FORMAL-FOUNDATION-GATE2-001` v3
- 验收日期：2026-08-23（Asia/Shanghai）
- 结论：`revisions_required / blocked`
- GATE-2 建议：**不得进入 `awaiting_human`**。

## 候选身份

开始验收时：

- `HEAD` 与 `origin/main` 均为 `e0f3252bf0a90d4c329f5e6113517324266c54b7`；
- `git status --short` 无输出，起始 worktree clean；
- 项目实例与插件锁为 `normal`；
- Registry 校验输出 `state=active iteration=3 sequence=61 revision=61`。

## 定向复验规则

所有有效 runner 单线程顺序运行，每项使用 360 秒外部硬超时。判绿要求：退出码 0、指定 PASS marker 存在、完整输出不含 `SCRIPT ERROR:`、行首 `ERROR:` 或 `FAIL/FAILED`。原始日志位于 `evidence/gate2/v3-candidate-e0f3252/logs/`。

## 定向复验结果

| 项目 | 结果 | 时间与说明 |
|---|---|---|
| dependency helper（配置错误） | invalid | `check_dependency_boundaries.gd` 是 `RefCounted` 扫描器，不是 SceneTree runner；360.252s 超时不计入产品结论。正确聚合入口为 `run_formal_architecture_checks.gd`。 |
| formal scene smoke | pass | 21.816s，exit 0、marker、零 forbidden。 |
| static UI theme | fail | 360.111s 后强杀；在此前已产生 `SCRIPT ERROR`：`level_select.tscn` Theme mismatch。 |
| board camera layer | pass | 65.813s。 |
| board layout | pass | 32.963s。 |
| formal board art/input | pass | 17.758s。 |
| turn camera visibility | pass | 8.985s；旧候选的自方移动相机缺陷已转绿。 |
| LAN network integration | fail | 83.083s，exit 1；3 个权威回合切换断言失败。 |
| LAN full-stack loopback | pass | 108.507s，完整 full-stack marker，零 forbidden；旧 exclusive-dialog 缺陷在此路径已转绿。 |
| tutorial progress | pass | 22.750s。该脚本已确认是带 `_init/quit` 的有效 SceneTree runner。 |
| formal equivalence/replay | blocked | 361.807s 纯超时，无 marker/错误文本。该脚本是有效 SceneTree runner，不能按 helper 配置错误撤销。 |

本阶段有效 runner 结果：**7 pass / 2 fail / 1 blocked**；另有 1 条 QA 命令配置错误，已从产品结论剔除。

## 缺陷与返回路径

### QA-G2V3-RC2-001：Level Select 未使用要求的静态 Theme

- runner：`tests/game/ui/run_ui_static_theme_contract.gd`
- 错误：`SCRIPT ERROR: Assertion failed: scene Theme mismatch: res://scenes/game/frontend/level_select.tscn`
- 回溯：测试第 49 行。
- 返回：Godot UI/前端场景责任人。

### QA-G2V3-RC2-002：正式 LAN 客户端在黑方行动阶段断线

- runner：`tests/game/network/run_formal_lan_network_integration.gd`
- 前置 29 项检查通过，随后 3 项失败：黑方移动后未切回红方；房主 skip 后未切玄方；客户端 timeout 后未切赤方。
- `BLACK_RPC_DIAGNOSTIC` 显示 server 已到 `action_index=2/active_side=red`，但 client 为 `server_disconnected`、`local_peer_id=0`、`local_seat=""`，仍停在 `action_index=1/active_side=black`。
- 返回：正式 LAN application/network 技术实现。

### QA-G2V3-RC2-003：正式等价/回放 runner 无法在 360 秒内完成

- runner：`tests/game/migration/run_gate1_formal_equivalence.gd`
- 结果：纯超时，无 PASS/FAIL marker 与错误文本；脚本自身具备 `_init`、marker 和 `quit`，属于有效 runner。
- 返回：规则/回放测试生命周期与性能责任人；需要可重复完成时间或分段证据。

## Contract v3 十项自动检查

| Check | RC2 判定 | 理由 |
|---|---|---|
| CHECK-CONTRACT-V3-001 | pass | 候选身份、normal 状态及 Registry 已核验。 |
| CHECK-DEPENDENCY-001 | blocked | 本阶段误调用 helper；需在当前或后继 clean 候选运行正确 SceneTree 聚合入口。 |
| CHECK-INFORMATION-2D-001 | not_rechecked | 定向阶段未重跑完整信息边界矩阵；因已有必要项失败，不沿用旧提交结果冒充 RC2 证据。 |
| CHECK-GODOT-2D-001 | fail | formal scene 通过，但静态 UI theme 合同失败。 |
| CHECK-COORDINATE-001 | pass | board camera/layout/art-input/turn-camera 均转绿。 |
| CHECK-RESPONSIVE-2D-001 | blocked | board layout 通过，但因第一阶段未全绿，未执行当前候选六张双方截图。 |
| CHECK-PERFORMANCE-2D-001 | blocked | 第一阶段未全绿，未执行性能/VRAM与低配验收配置采样。 |
| CHECK-ART-2D-001 | not_rechecked | 定向阶段仅复验 board art/input；完整资产清单未在 RC2 重新独立核验。 |
| CHECK-REGRESSION-001 | fail | LAN integration 失败，formal equivalence/replay 超时。 |
| CHECK-SCOPE-001 | not_rechecked | 起始候选身份有效，但本阶段因自动失败未完成完整 scope 审计。 |

## 独立专业审查

结论：`revisions_required / blocked`。

- RC2 已修复旧候选的相机、正式棋盘布局、full-stack 对话框冲突和 tutorial progress 生命周期问题。
- 当前仍有明确的 UI theme 与 LAN integration 回归失败；正式等价/回放没有可接受的完成证据。
- 因第一阶段未全绿，按既定流程未生成截图、性能证据或 Windows EXE，不能形成 GATE-2 决策包。

## 下一合法动作

1. 修复 RC2-001、RC2-002，并收敛 RC2-003 的可重复执行时间。
2. 在新 clean 候选上运行正确 dependency SceneTree runner及上述失败/blocked 项。
3. 定向项全部通过后，再开展六张双方截图、性能/VRAM、低配验收配置与 Windows embedded-PCK 导出验证。
