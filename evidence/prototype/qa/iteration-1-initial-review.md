# Iteration 1 独立 QA 初审

结论：**允许继续 Iteration 1 修订，但当前提交不满足专业验收，也不得进入 Loop review、`waiting_approval` 或 GATE-1 决策包。** 这是本轮执行建议，不是 GATE-1 人工决定。

审查实例为 `inst:01M02NJ3JFHVZ5C4SP5MTJFJR6`，与规则、Godot 和 AI 生产实例分离；审查 HEAD 为 `be8370a1784d0a636336c0718413316b11655a10`，覆盖 `cbc89f5`、`a46468d`、`737e90d`、`be8370a`。

## 关键发现

### Blocker — QA-P1-001：必要可执行制品缺失

`scripts/prototype/core/`、真实 `FullState -> PlayerView`、版本化行动/玩家事件、状态摘要、回放入口、`tests/prototype/run_seeded_matches.gd` 和 1000-seed 模拟器均不存在。现有主场景与 `run_all.gd` 明确输出 `rules=not_implemented`。

影响：CHECK-RULES-001、CHECK-DETERMINISM-001、CHECK-FOG-001、CHECK-AI-001、CHECK-005 均只能记为 `not_run / blocked_by_missing_artifact`；不得用壳层 exit 0 替代。

复现：

```powershell
Test-Path scripts/prototype/core
Test-Path tests/prototype/run_seeded_matches.gd
Test-Path scripts/prototype/player_view.gd
godot --headless --path . --script res://tests/prototype/run_all.gd
```

责任返回：Godot 技术负责人；涉及已列明 `unknown` 的语义必须先由系统与体验负责人/项目所有者补齐，技术岗位不得静默默认。

### High — QA-P1-002：AI 公平测试未经过真实信息边界

`test_ai_fairness.gd` 的隐藏配对把两个隐藏状态的 `public_projection` 直接复制出来再构造 AI DTO。它验证了 AI 白名单、规范化、同种子确定性和审计形状，但没有调用真实规则核心的投影，也无法证明合法动作、错误、事件或 UI 不受隐藏状态影响。

复现：

```powershell
godot --headless --path . --script res://tests/prototype/test_ai_fairness.gd
Select-String tests/prototype/test_ai_fairness.gd -Pattern '_test_projection_boundary|public_projection'
```

责任返回：Godot 技术负责人提供真实单向投影与黑盒适配；AI 工程师基于该接口补运行时审计配对。代码静态审查未发现 AI 目录引用 `FullState` 或场景树查询，且 `decide` 参数已限制为 `PlayerView`、公开规则、AI 记忆、独立种子和 hypothesis 配置；这只是静态正向证据，不是反作弊运行时通过。

### High — QA-P1-003：Loop 官方重放命令退出 1

项目实例、Pipeline Contract 和 Organization Event History 重放均 exit 0；Loop 官方 validator 对当前 `active / iteration=1 / revision=8` Snapshot 报六项注册模板错误并 exit 1。错误均要求 `draft / iteration=0 / revision=1 / empty inputs`，输出未报告事件摘要链断裂或 Snapshot 无法由历史重建。

复现命令见 `iteration-1-command-output.txt` 的 `LOOP EVENT HISTORY REPLAY`。在官方命令能无歧义验证运行时 Snapshot 前，CHECK-CONTRACT-001 的 Loop 部分不能记通过。

责任返回：项目经理补齐 Gate 命令定义或协调管线校验器；QA 不修改 Registry 或插件代码。

## 已通过或受限通过的证据

- Godot `4.7.1.stable.official.a13da4feb` 可导入工程，主场景可无头加载；一帧强制退出产生 `Scan thread aborted` 警告，但没有解析/资源 ERROR。
- 固定原型壳由三个 `.tscn` 中 34 个预置节点构成；场景适配脚本未动态创建固定 UI。216 格仅作为运行时数据，符合 Contract 已批准例外。
- AI 三份 `.tres` 和配置快照均保留 `conclusion_status=hypothesis`；候选预算、时间提示、随机幅度和难度没有被写成 confirmed/frozen。
- 规则、结算与信息规格能追溯 confirmed 简报，并把初始阵型、旗帜完整生命周期、同窗炮击/双将死亡、空位不足、恢复边界、隐藏阻挡交互、回合上限和 AI 参数明确留在 `unknown`。这些边界静态审查通过，但未知项仍阻塞对应实现用例。
- Phase 1 scaffold 的九项节点/数据检查 exit 0；该结果仅说明壳层成立。

## 当前验收状态

| 检查 | 状态 | 说明 |
|---|---|---|
| 项目实例 / Pipeline Contract / Organization 重放 | pass | exit 0 |
| Loop 官方重放 | fail | exit 1，运行时 Snapshot 被按注册模板检查 |
| Godot 导入 / 主场景 | pass / scaffold-only | 规则明确未实现 |
| `run_all` | fail_acceptance_coverage | exit 0 但仅 9 项壳层检查 |
| AI 原型自测 | pass_limited_fixture | 未经过真实 PlayerView |
| 规则矩阵 / 确定性 / 回放 | not_run | blocked_by_missing_artifact |
| 迷雾黑盒 / AI 黑盒公平 | not_run | blocked_by_missing_artifact |
| 1000 fixed seeds | not_run | runner 与完整模拟器缺失 |
| 性能 / 存档兼容 / Steam 构建 | out_of_scope | 当前 Loop Contract 明确排除发布向工作 |

## 下一合法动作

继续同一 Loop 的 Iteration 1：先补真实规则核心、PlayerView、事件/摘要/回放与 seeded runner；将 `run_all` 扩展到 Contract 所列必要用例；用真实投影执行隐藏等价配对和 AI 审计；解决 Loop 官方运行时重放命令的非零结果。随后由独立 QA 重跑全部受影响检查。

原始命令、时间、退出码、环境与缺失制品记录见 `evidence/prototype/qa/iteration-1-command-output.txt`；机器可读状态见 `evidence/prototype/qa/gate1-evidence-index.yaml`。
