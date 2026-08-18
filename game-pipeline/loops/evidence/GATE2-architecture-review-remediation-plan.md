# GATE-2 正式架构前置审阅整改计划

状态：`active / loop-not-started`

登记时间：`2026-08-18`

## 触发证据

- 技术审阅：`evidence/gate2/architecture-technical-review-v1.md`，结论 `approved`。
- 独立 QA：`evidence/gate2/architecture-independent-qa-review-v1.md`，结论 `blocked`。
- 本计划只关闭 `INPUT-ARCH-REVIEW-001` 的前置缺陷；不启动第二生产循环，不批准 GATE-2。

## 整改切片与所有权

### REM-G2-001：统一 owner revision 5 规则基线

- Owner：`pos:veilfront-xiangqi-siege:design-experience:systems-experience-lead`
- Agent Instance：`inst:01M02NJ3JENHD8VV7EKC9G198Q0`
- 允许修改：
  - `docs/prototype/settlement-order-v1.md`
  - `docs/prototype/rules-test-coverage-matrix-v1.md`
  - `evidence/gate2/rules-baseline-revision5-remediation.md`
- 要求：删除士被动替死残留；冻结主动献祭、公开阵亡记录与复活候选池的区别；士与将帅不进入复活候选池；更新炮击、车路径和终局结算措辞及对应测试清单；确认教学只消费指定观察者的安全投影。
- 边界：不得改变 Project Brief、规则实现、测试代码或所有者已确认语义；若发现真实语义歧义，立即返回项目所有者。

### REM-G2-002：冻结正式架构安全边界与迁移基线

- Owner：`pos:veilfront-xiangqi-siege:technology:godot-technical-lead`
- Agent Instance：`inst:01M02NJ3JEQXKV6PT6DPX0NKQ0`
- 前置：`REM-G2-001` 完成并提供精确摘要。
- 允许修改：
  - `docs/architecture/post-gate1-formal-architecture-review-v2.md`
  - `docs/architecture/formal-dto-and-trust-boundary-v1.md`
  - `docs/architecture/gate1-to-formal-migration-manifest-v1.yaml`
  - `evidence/gate2/architecture-remediation-v1.md`
- 要求：绑定已确认 Brief v5、已批准 Contract v1、GATE-1 approval 和修正后规则摘要；冻结 FullState、raw Domain Event、VisibleEvent、VisibleError、ActionPreview、PlayerView、权威/观察者 Replay、私有标记与 viewer 选择权；绑定 RC3 提交、固定 seed、replay 样本、codec、比较命令和 1000-seed 重跑触发条件。
- 边界：不得实现正式运行时代码、互联网、AI 或批量美术；v1 报告保留为历史证据，不覆盖。

### REM-G2-003：重新双审并决定是否启动循环

- Owner：`pos:veilfront-xiangqi-siege:root:project-manager`
- 技术复审：Godot 技术负责人重新审阅修订报告的精确 SHA-256。
- 独立复审：质量与发布负责人独立验证同一 SHA-256、规则摘要和迁移 manifest。
- 关闭条件：两份复审均为 `approved`，`QA-G2-ARCH-001..004` 全部关闭。
- 关闭前禁止：登记第二循环 Registry、宣称 `INPUT-ARCH-REVIEW-001` satisfied、开始正式实现或推进 GATE-2 状态。

## 回退点

当前合法回退点为 GATE-1 已批准、第二循环未启动。GATE-1 RC3、旧审阅和旧规则证据保持不可变；整改通过新版本和新摘要完成，不修改历史证据。
