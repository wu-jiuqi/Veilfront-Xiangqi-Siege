# Iteration 1 Revision 2 独立 QA 回归

结论：**允许继续同一 Iteration 1，但当前提交仍不被专业验收接受，证据状态为 `blocked`，合法后续动作为 `revise_same_loop`。** 不得转入 GATE-1；本文不作人工 Gate 决定。

审查 HEAD 为 `c7fd75d84d171cfbe0943901cd3cd3b5c70d89e9`，覆盖 owner-freeze revision 2（`5b2c807`）、可回放 partial core（`8a60abe`）和真实 PlayerView AI（`c7fd75d`）。

## 缺陷回归

| 缺陷 | Revision 2 状态 | 结论 |
|---|---|---|
| QA-P1-001 | 保留，部分缓解，Blocker | 真实规则状态、投影、事件、摘要和定向回放已存在；但完整规则/迷雾/结算/整局模拟及 1000-seed runner 仍缺失。 |
| QA-P1-002 | 关闭 | 测试现由两个真实且不同的 FullState 经 `PlayerViewProjector.project` 和 `export_ai_projection` 进入 AI；动作与公开审计完全一致，且强制失败能传播为 exit 1。 |
| QA-P1-003 | 保留，High | 官方 Loop CLI 仍 exit 1；错误是 active runtime Snapshot 被按 draft 注册模板检查，未观察到历史哈希链或重建损坏报告。 |

未发现新的 High/Blocker 缺陷。

## 已通过的 Revision 2 定向证据

- 项目实例、Pipeline Contract 和 Organization 历史校验 exit 0。
- Godot 4.7.1 导入、主场景与 `run_all` exit 0；输出明确为 `prototype_core_revision2`、`focused_suites=5`、`full_gate1=false`。
- 冻结规则定向矩阵覆盖初始 32 棋、红先、确定性旗帜、无冷却字段、旗生命周期、炮击起源、同步双将平局、士替死顺序、后备 FIFO 和修墙时序。
- 三行动回放的行动事件摘要与最终状态摘要一致。
- 真实隐藏等价配对改变了 FullState 中黑卒位置/隐藏状态及规则 RNG 未公开记录，但 PlayerView、行动提示、AI DTO、AI 动作和全部公开审计保持一致。
- AI 种子由对局 AI 种子与公开 decision ID 派生，不接收规则 RNG；`--force-failure` 负向控制 exit 1。

## 仍阻断 GATE-1 的范围

当前核心仍是 partial prototype。以下 Contract 必要范围未完成或无完整运行证据：

- 全部传统棋子几何与限制；
- 马腿、象眼、隐身/显形区；
- 特殊车逐目标与路径视野；
- 兵卒特殊行军、炮架和精确炮击完整解析；
- 完整 `3x3` 视野、旧视野回雾、所有玩家事件/错误/UI 投影；
- 完整结算优先级组合与完整轮上限出口；
- 完整合法行动生成、整局终止模拟和统计；
- `tests/prototype/run_seeded_matches.gd` 不存在，因此 1000 fixed seeds 为 `not_run/blocked_by_missing_artifact`。

所以 `run_all` 的 exit 0 只能证明 owner-freeze revision 2 的定向风险基线，不能满足 CTR-P1-001 CHECK-004；三行动回放不能替代完整对局回放；单个真实隐藏等价配对也不能替代完整迷雾矩阵。

## Loop 校验区分

Organization Event History 完整重放通过。Loop 命令确实带 `--history` 执行，但总体 exit 1 的六项错误均要求注册模板的 `draft / iteration=0 / revision=1 / empty inputs`，而当前是 `active / iteration=1 / revision=14`。输出没有报告事件 sequence、digest 链或从历史重建 Snapshot 不一致。

因此当前证据支持“模板 CLI 不适用于 active runtime Snapshot”的判定，不支持“Loop 历史已损坏”的判定；然而官方命令非零仍使该自动条件不能记通过，需由项目经理/管线维护方处理，QA 不修改 Registry 或插件。

## 下一合法动作

继续本 Loop 的 Iteration 1：技术岗位补完整规则、视野、结算、合法行动与整局模拟，并提供可运行的 1000-seed runner；项目经理解决或明确 active runtime Snapshot 的官方 Loop 验证方式。完成后由独立 QA 重跑全部规则、迷雾、AI、回放和 1000-seed 检查。

完整命令、时间、环境与退出码见 `evidence/prototype/qa/iteration-1-revision-2-command-output.txt`，机器可读结果见 `evidence/prototype/qa/gate1-evidence-index.yaml`。
