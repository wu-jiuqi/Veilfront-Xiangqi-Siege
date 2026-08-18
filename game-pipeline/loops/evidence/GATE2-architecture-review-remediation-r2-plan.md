# GATE-2 正式架构前置审阅第二次整改计划

状态：`active / loop-not-started`

登记时间：`2026-08-18`

## 触发证据

- 技术复审：`evidence/gate2/architecture-technical-rereview-v2.md`，结论 `approved`。
- 独立 QA 复审：`evidence/gate2/architecture-independent-qa-rereview-v2.md`，结论 `revision_required`。
- 唯一剩余缺陷：`QA-G2-ARCH-001-R2`。`docs/prototype/rules-spec-v1.md` 的车规则仍写“阵亡/替死”，旗帜规则仍写“替死回营”，与同文件已确认的主动献祭语义冲突。

## REM-G2-R2-001：清除规则规格最后两处被动替死残留

- Owner：`pos:veilfront-xiangqi-siege:design-experience:systems-experience-lead`
- Agent Instance：`inst:01M02NJ3JENHD8VV7EKC9G198Q0`
- 允许修改：
  - `docs/prototype/rules-spec-v1.md`
  - 新建 `evidence/gate2/rules-baseline-revision5-remediation-r2.md`
- 要求：车路径改为逐目标实际死亡登记与将帅检查，明确不触发被动替死；旗帜中断原因改为离开、死亡、主动献祭、复活导致实例离场、强制撤回或实例变化；对规则规格、结算、信息边界、覆盖矩阵执行完整残留审计。
- 边界：只修文档漂移，不改变 owner revision 5；若发现语义歧义则返回项目所有者。

## REM-G2-R2-002：更新传递摘要

- Owner：`pos:veilfront-xiangqi-siege:technology:godot-technical-lead`
- 前置：`REM-G2-R2-001` 完成。
- 允许修改：
  - `docs/architecture/post-gate1-formal-architecture-review-v2.md`
  - `docs/architecture/gate1-to-formal-migration-manifest-v1.yaml`
  - 新建 `evidence/gate2/architecture-remediation-r2.md`
- 要求：只更新规则规格与 R2 证据摘要、整改代码库水位、继承链和相应冲突/重跑绑定；DTO/信任边界不变。不得沿用旧 SHA 或宣称复审已通过。

## REM-G2-R2-003：最终双审

- 项目经理以新的 v2、manifest、DTO、规则四事实源与 R2 证据摘要创建新 assignment。
- Godot 技术负责人和独立 QA 对同一输入集从头复审。
- 两份结论均为 `approved` 前，禁止生成 satisfied input binding、登记第二循环或开始实现。

## 回退与保留

保留旧 v1/v2 审阅、首次整改和本次失败复审为历史证据。禁止修改旧审阅报告来掩盖失败；新结论只能绑定新摘要。
