# Iteration 1 Revision 3 独立 QA 回归清单

## 当前状态

- 状态：`preparation / waiting_for_final_head`
- QA Agent Instance：`inst:01M02NJ3JFHVZ5C4SP5MTJFJR6`
- Loop：`first-production-loop`，`active`，`current_iteration=1`
- 预检基线时间：`2026-08-15T22:47:32.6759578+08:00`
- 预检时 HEAD：`93d6e810c576a22978352f5f848758d9f596f55b`
- 预检时工作树正在由技术岗位落盘；该 HEAD 不是 Revision 3 正式受测基线。
- 项目实例预检：`exit=0`，`state=normal`，插件与框架摘要匹配。
- 相/象“田字显形区域”精确格集合：`blocked/pending-owner`。在 owner 裁决进入批准事实源之前，技术 hypothesis 和相应测试均不得作为 frozen 规则证据。
- Loop validator：官方 CLI 的 `exit=1` 必须如实保留；同一未修改脚本的历史重放函数可单独复核，但其 `0` 错误不得替代或冒充官方 CLI 通过。

## 正式基线绑定

收到根协调器“技术与 AI 已完成”的明确通知后，先记录以下信息，再运行任何正式回归：

1. `git rev-parse HEAD`
2. `git status --short --branch`
3. `git show -s --format=fuller HEAD`
4. 操作系统、时区、Godot 版本、Python 版本。
5. 受测 Contract、Loop Contract、owner-freeze 规格、测试入口及关键脚本的路径与哈希。
6. 每项证据均记录：命令、开始/结束时间、退出码、环境、提交和工作树状态。

若正式测试期间生产工作树再次变化，停止接受该轮结果，重新绑定最终 HEAD/工作树后重跑受影响检查。

## 治理与历史校验

1. 项目实例校验：
   `python "$env:USERPROFILE/.codex/plugins/cache/personal/game-production-pipeline/0.4.0-alpha.2/scripts/validate_project_instance.py" --project-root .`
2. Pipeline Contract 校验：使用锁定插件的官方 validator 与批准 Contract，记录完整命令和退出码。
3. Organization 历史校验：使用批准 snapshot/history 的官方命令，确认 QA 实例授权、隔离与生命周期。
4. Loop 官方 CLI：使用批准 snapshot/history/event template/contract/state machine 运行官方命令；当前已知模板/runtime-snapshot 兼容问题若仍存在，记录 `exit=1` 和全部错误，不降级为通过。
5. Loop 历史重放函数：从同一份未修改 `validate_loop_registry.py` 调用 `validate_history(...)`，单独记录错误数与退出码。该结果只说明历史链重放，不说明官方 CLI 通过。

## Godot 与入口检查

1. `godot --version`，必须为项目要求的 Godot 4.7.1。
2. 无头导入：`godot --headless --path . --editor --quit-after 1`
3. 主场景启动：`godot --headless --path . --quit-after 2`
4. 聚合测试：`godot --headless --path . --script res://tests/prototype/run_all.gd`
5. AI 正控：`godot --headless --path . --script res://tests/prototype/test_ai_fairness.gd`
6. AI 负控：`godot --headless --path . --script res://tests/prototype/test_ai_fairness.gd -- --force-failure`，预期非零退出；若返回零则判测试传播失效。
7. 完整规则、迷雾、PlayerView、回放与结算定向测试：以最终测试入口为准，逐项映射覆盖矩阵中的 Test ID 和原始输出，不用单一“全绿”摘要替代。
8. 千种子入口存在时运行：
   `godot --headless --path . --script res://tests/prototype/run_seeded_matches.gd -- --seeds 1000`
   若入口、完整对局模拟或所需规则工件缺失，标记 `not_run/blocked_by_missing_artifact`，不得伪造通过。

## 源审与黑盒检查

1. 真实信息路径必须是 `FullState -> PlayerView -> AI`；AI 不得直接读取 FullState、隐藏棋子、对手隐藏行动或可推导隐藏状态的旁路。
2. 黑盒对比同一 PlayerView、不同隐藏 FullState 的 AI 输入与决策可观察量；不得仅检查函数名或伪投影 fixture。
3. 回放验证同 seed、同初始状态、同动作序列得到相同状态哈希、事件序列和结算；篡改输入必须可检测并非零失败。
4. 冻结规则定向矩阵必须覆盖传统棋子几何、阻挡/炮架、特殊能力、视野/显形、结算优先级、轮上限和边界状态；未冻结项与未实现项分别标记，不互相替代。
5. 无 cooldown 独立检查：
   - 源码与资源中不得引入 cooldown/冷却字段、计时器或回合倒计时状态；
   - FullState、PlayerView、事件与回放中不得泄露或持久化 cooldown 状态；
   - 冻结的能力可用性只由批准规则决定；运行时连续合法使用定向用例不得被隐藏冷却拦截。
6. 相/象精确显形格集合若仍无 owner 决议：对应实现与测试只记录 `blocked/pending-owner`，不得因代码与自写测试一致而接受。

## 测试可靠性判据

1. 所有正式入口必须在断言失败时返回非零退出码；只有日志中的 `FAIL` 而进程返回零，视为测试基础设施缺陷。
2. AI `--force-failure` 是独立负控，必须稳定返回非零并由上层命令观察到。
3. `run_all.gd` 必须实际执行声明的完整套件；输出中的 suite 数、Test ID 和覆盖矩阵应一致。
4. 千种子 runner 必须校验 `--seeds` 参数、实际执行数量、每 seed 的完整对局/终止条件与不变量；仅循环随机函数或局部投影不构成 1000 seeds 证据。
5. 测试不得把 hypothesis、默认值或 fixture 常量提升为 owner-frozen 规则。

## Revision 3 交付物

- `iteration-1-revision-3-command-output.txt`：原始命令、时间、环境、提交、退出码与输出。
- `iteration-1-revision-3-review.md`：缺陷关闭/保留/新增、证据状态、`current_submission_accepted` 与合法下一动作。
- `gate1-evidence-index.yaml`：Revision 3 索引；不写 GATE-1 人工决定。

正式结论只判断当前提交是否足以继续/接受本次 Iteration 修订，不代替项目所有者的 Gate 判断。
