# GATE-2 规则基线 revision 5 整改证据

状态：`completed / awaiting REM-G2-002 binding and independent re-review`

整改项：`REM-G2-001` / `QA-G2-ARCH-001`、`QA-G2-ARCH-003` 的设计侧部分

责任身份：

- Agent Instance：`inst:01M02NJ3JENHD8VV7EKC9G198Q0`
- Position：`pos:veilfront-xiangqi-siege:design-experience:systems-experience-lead`
- Authority：`AUTH-VEILFRONT-SYSTEMS-EXPERIENCE`

## 输入绑定

| 输入 | SHA-256 / 审批标识 |
|---|---|
| `game-pipeline/project-definition/project-brief.yaml` v5 | `276d777409f6218c2448e4886879216e09b4e2ea9fa2118f595dc30f14c551e9` |
| `docs/prototype/rules-spec-v1.md` owner revision 5 | `f5158daa0e0235f9cca31ee4411ab1ae647e6ff20019c3316c8f8d35d91f61ab` |
| GATE-1 人工批准 | `approval:veilfront-xiangqi-siege:gate-1:8f93c3506192` |
| GATE-2 正式架构前置审阅整改计划 | `game-pipeline/loops/evidence/GATE2-architecture-review-remediation-plan.md` / `REM-G2-001` |

## 修正产物

| 产物 | SHA-256 | 结果 |
|---|---|---|
| `docs/prototype/settlement-order-v1.md` | `7335fb20723e6a36eb961ed50739f590e9e426b927af726ca7fbbe7c6992694a` | owner revision 3 升级为 revision 5；结算阶段不再含被动士替死 |
| `docs/prototype/rules-test-coverage-matrix-v1.md` | `5a6c277bbcb74f038953337a7634a1c4e3c7d53bc58b76dfff50d6d2e6f7199b` | 当前规则改列 `PENDING-R5`；相冲突的旧替死/旗位/区域测试只保留为历史 `SUPERSEDED` 证据 |

## 已冻结的可执行语义

1. 所有实际死亡原因统一登记：普通吃子、车路径接触、炮击、主动献祭、将帅实际死亡和其他规则原因都进入所属方公开阵亡记录；双方 `PlayerView` 同步公开双方完整记录；复活棋子立即移出。
2. 公开阵亡记录不等于复活候选池。阵亡士和帅/将保留在公开记录中，但献祭复活每次只从发动方记录筛选非士、非帅/将棋子；阵亡士永不进入随机候选池。
3. 活着且在场的士可以选择主动献祭。待确认态允许取消且不消费行动或随机数；确认后消费一次行动，发动士先死亡并登记，再随机复活一枚合资格友方到己方大本营随机空点。不存在“前两次阵亡强制替死”或任何被动士替死。
4. 车路径逐目标执行“实际死亡登记→将帅检查”；将帅死亡截断后续目标。炮击三点基于同一前快照同步结算，全部死亡先登记，双将同窗死亡平局；两者都不触发被动士替死。
5. 终局顺序冻结为：实际死亡登记先完成；随后将帅死亡最高优先；非终局时才继续城墙、三旗与完整轮上限。终局仍生成观察者安全的最终投影和公开阵亡记录。
6. 与 revision 5 直接相关的坐标和信息语义同步进入矩阵：特殊行动与炮击有效区域为 `Y=4..21`，三旗位于完整战区 `X=1..9,Y=9..16` 且受迷雾/永久发现记忆约束，相/象视野为起点 `3x3`、田字九点和终点 `3x3` 并集，田字九点只阻挡敌方车与兵/卒从格外进入或穿过。
7. GATE-1 已批准；历史 `full_gate1=false` 只保留为当时自动 runner 字段，不能覆盖后续人工批准。50 回合上限仍为 `hypothesis`，正式轮上限继续保持 `unknown`。

## 教学观察者边界确认

新手教学属于玩家侧消费者，只能消费当前指定观察者的：

- `PlayerView`
- `VisibleEvent`
- `VisibleError`
- `ActionPreview`

教学不得直接读取 raw Domain Event、`FullState`、完整旗位、规则 RNG、对手私有标记、权威 Replay 或另一观察者的投影。教学目标判断、提示、高亮、镜头和失败反馈必须能由上述观察者安全投影独立得到；若某教学步骤需要隐藏事实，应由规则侧发出已经过 viewer 过滤的可见事件，而不是给教学旁路。

## 验证与边界

- `git diff --check`：通过。
- Markdown 表格最小结构检查：通过。
- 未修改实现、测试代码、Project Brief、Contract、Registry、approval 或历史 GATE 证据。
- 未将 revision 5 的文档修正写成实现通过或独立 QA 通过。
- 未发现需要项目所有者重新裁决的规则语义歧义。完整轮上限与 AI 参数继续保持开放；正式架构仍为 `hypothesis`。

下一合法交接：Godot 技术负责人以本证据和两份精确规则摘要完成 `REM-G2-002`，随后由技术负责人和质量与发布负责人对同一修订架构摘要重新双审。在两份复审均为 `approved` 前，不得启动第二生产循环或声称 `INPUT-ARCH-REVIEW-001` 已满足。
