# OWNER-RULE-REVISION-5 / Contract v5 迁移计划

状态：`awaiting_project_owner_approval / pre-migration`

本文件只记录待审批草案和迁移检查，不是批准记录，不注册事件，不改变当前 Loop 的 `active / iteration 2 / Contract v4` 事实。项目所有者批准前，不得把 Project Brief v4 或 Contract v5 表述为已生效，也不得用本文件替代独立 QA 或 GATE-1 人工决定。

## 待审批摘要

- Project Brief v3 已批准摘要：`b8328fd2305e90d26c7854b7a9335c54c9e6647ae049e462780132edce44ea28`
- Project Brief v4 待审批 subject digest：`df8deb810d8c06c8c2f5763031fde2c39f14aa81226e23ffb25636ee3f1eca0b`
- Project Brief v4 当前文件 SHA-256：`4f9dfaee78a72fc7e42aee8f01b320e28568d3f07c8b4c7bdbd16869d9be7654`
- Contract v4 已批准 subject digest：`a0da0eec9d6d9513dd111d406c1165bc64d3b84ce1aa1ac430a2c95c10179e6a`
- Contract v4 文件 SHA-256：`0ba98eac698ef594e1516d64d0c9b085ae411280909d962fff83bc5b60cb7fc9`
- Contract v5 待审批 subject digest：`7689efb359c806a7c56508a869833901966469bcde5bdb4a3cdfba7b6af4279f`
- Contract v5 当前文件 SHA-256：`703a280b0f8aefde6f4ffa09a10657908c7aa1e8ed1f8f9e8687a3c733a3bec0`
- 人工决定者：`project-owner`
- 待审批来源：`codex-thread://current#owner-rule-revision-5`

任何草案文件变化都会使相应文件摘要失效；任何 subject 内容变化都会使待审批 subject digest 失效，必须重新计算并重新呈交。

## v3/v4 到 revision 5 的语义差异

| 范围 | 旧基线 | v4/v5 草案 |
|---|---|---|
| 棋盘 | 文本仍称24×9格，城墙描述为格间边界 | 权威坐标为24×9交点；棋子落点线上；黑方仅做180°显示镜像 |
| 城墙 | 红Y=3/4、黑Y=21/22边界，描述为阻止进入大本营 | 红墙Y=4、黑墙Y=21；完整墙禁止敌棋踏入或跨越墙线，最深分别为Y=5/Y=20 |
| 旗帜 | 位置永不进入PlayerView/AI/LAN | 旗帜受迷雾影响；进入某方视野后只向该方永久记忆坐标；占领消息不自动公开位置 |
| 阵亡 | 简报未统一规定所有死亡来源和双方同步 | 吃子、路径接触、炮击、献祭、将帅死亡等全部进入所属方公开阵亡记录；双方同时看到双方记录 |
| 士献祭 | 主动献祭，非士非将帅为候选 | 进一步区分公开阵亡记录和复活候选池；阵亡士与帅/将有记录但永不入候选；提交前可取消 |
| 相田字 | 只阻挡敌车 | 同样阻挡敌车和敌兵卒从外部首次进入/穿过；己方车兵不受影响，格内离开不重触发 |
| 隐身马/车 | 未冻结普通车首次接触反馈 | 普通车首次接触未显形敌马时在交点吃掉并停止，不允许静默失败或无反馈路障 |
| 表现记忆 | 未冻结镜像、虚影、私人标注 | 双方己方营在底；被吃虚影只给阵亡方并到期；右键标注是本地私有表现，不覆盖行动高亮 |

## 信息边界检查

- `FullState` 持有真实旗位与双方发现集合；`PlayerView(viewer)` 只输出 viewer 已发现旗位。AI 与 LAN 客户端只使用同一侧 PlayerView。
- 公开夺旗进度或成功消息只含阵营与进度，不向未发现方附加旗坐标。
- 双方阵亡记录公开棋子身份与所属方，但不能借此附加未授权死亡坐标；被吃虚影只投影给阵亡方。
- 敌方相田字源不下发；受阻方只能通过动作在首交点结束的公开结果获知接触。
- 隐身马接触由权威规则结算；接触前的候选、错误类型、LAN下行和AI输入不得提前泄露其位置。
- 黑方镜像只变换显示与输入映射，不改变行动意图中的权威交点；本地标注不得同步给对手。
- 车路径和相侦察/阻挡覆盖层只投影给拥有该视野源的一方。

## 获批后的迁移顺序

1. 仅在项目所有者明确批准上述两个 subject digest 后，分别写入不可变 Project Brief v4 与 Contract v5 approval 记录。
2. 将 Project Brief v4 的 `review` 更新为 `confirmed` 并绑定审批记录；将 Contract v5 从 `draft` 物化为 `approved`，不得复用草案文件 SHA 作为批准后的文件 SHA。
3. 在保持既有历史字节和链摘要的前提下追加 `core.contract_migrated`，把 Registry 从 Contract v4 迁移到获批的 v5；不得改写旧事件。
4. 重新计算 Snapshot、事件与迁移证据摘要，并复检 Organization 历史、项目实例和 Pipeline Contract。
5. 在同一冻结候选提交上重跑 revision 5 规则、PlayerView隐藏等价、AI公平、LAN下行白名单、黑方镜像坐标、Godot回归、1000固定种子和确定性检查。
6. QA-P1-003 仍只能记录为官方 CLI `failed / exit 1 / 精确六项已知错误`；出现第七项错误即停止进入 review。
7. 独立 QA 接受全部当前证据后，才可准备 GATE-1 决策包并等待项目所有者人工审查。

## 本次未执行

- 未创建或修改任何 approval 文件。
- 未修改 Loop Registry Snapshot、event-history 或状态。
- 未将 LAN 例外、QA-P1-003 或 GATE-1 标记为重新批准。
- 未修改规则实现、AI、UI、测试或 QA 证据。
- 未代表项目所有者作出 Project Brief、Contract 或 GATE-1 决定。
