# GATE-2 正式架构整改独立 QA 复审 v2

结论：`revision_required`

复审时间：`2026-08-18T12:33:15.0220634+08:00`

## 身份、范围与权限

- Reviewer Instance：`inst:01M02NJ3JFHVZ5C4SP5MTJFJR6`
- Position：`pos:veilfront-xiangqi-siege:quality:qa-release-lead`
- Authority：`AUTH-VEILFRONT-QA-RELEASE`
- 任务：`game-pipeline/loops/evidence/GATE2-architecture-remediation-rereview-assignment.md`
- 受审 Contract：`LOOP-CTR-FORMAL-FOUNDATION-GATE2-001@v1`
- 本次从任务列明的精确摘要集重新审阅，没有沿用 v1 QA 的 `blocked` 结论，也没有参与整改。
- 本实例只创建本报告；未修改规则、架构、Contract、Registry、approval、代码或技术复审。

本结论只判断 `INPUT-ARCH-REVIEW-001` 的整改输入能否进入第二生产循环，不是 GATE-2 人工决定。

## 复审结论

`QA-G2-ARCH-002/003/004` 已具备关闭证据：v2 后继关系可审计，FullState/viewer/projection/观察者 DTO/Replay/私有标记边界明确，迁移 manifest 也完整绑定 RC3、1000 seeds、20 replay、已知回归 471016、10 个 codec 通道、命令、触发条件和失败回退。

`QA-G2-ARCH-001` 尚未完全关闭。虽然结算顺序、信息边界和覆盖矩阵已经统一到 owner revision 5，`docs/prototype/rules-spec-v1.md` 的当前冻结正文仍保留两处具有现行行为语气的被动替死残留：

1. 车规则仍写“按起点到终点顺序逐枚处理阵亡/替死”；
2. 旗帜进度仍写占领者“替死回营”时清零。

同一规则规格随后又明确“所有被动和前两次阵亡强制替死逻辑取消”，与上述现行表述冲突。该文件被 v2 和 migration manifest 以 SHA-256 `f5158daa0e0235f9cca31ee4411ab1ae647e6ff20019c3316c8f8d35d91f61ab` 绑定为 `owner_rule_revision_5` 的 gameplay rules，不能把这两处当作无关历史文字忽略。

因此本轮不能给出 `approved`。结论为 `revision_required`，第二生产循环继续保持未启动。

## 精确输入与证据新鲜度

任务列出的七项输入 SHA-256 全部与本地文件逐字节一致：

| 输入 | SHA-256 | 结果 |
|---|---|---|
| `docs/architecture/post-gate1-formal-architecture-review-v2.md` | `6320614a35dfa03398d6aae53a8b62bbc3f42199e471f98b59590e603bfbe025` | MATCH |
| `docs/architecture/formal-dto-and-trust-boundary-v1.md` | `6f23274810aad5d6f2515bd78b114da16684e38f9abe04e2d59dcfa87fc174f2` | MATCH |
| `docs/architecture/gate1-to-formal-migration-manifest-v1.yaml` | `69f784de94296b593d71f08b81ed96a169e61d4a00becc7f1668cfc8082822ec` | MATCH |
| `evidence/gate2/architecture-remediation-v1.md` | `904b68d92f606ee18d2dcca8e75892c77229673b2d5132cd5813430f48b3db10` | MATCH |
| `docs/prototype/settlement-order-v1.md` | `7335fb20723e6a36eb961ed50739f590e9e426b927af726ca7fbbe7c6992694a` | MATCH |
| `docs/prototype/rules-test-coverage-matrix-v1.md` | `5a6c277bbcb74f038953337a7634a1c4e3c7d53bc58b76dfff50d6d2e6f7199b` | MATCH |
| `evidence/gate2/rules-baseline-revision5-remediation.md` | `a47a80f32b269040b4c872cdf25c9223eb57f097a74ccd7fccc1e4d13fbfaadb` | MATCH |

任务指定的整改产物水位是 `main@fc22faae63f94129d5a93ff9f94a4b95ce0cc907`；当前 HEAD `c06ad4d3864cc5ff6b8c07fac8c14f83cba1da19` 是登记本复审任务的后续提交。受审输入及其传递绑定文件没有 tracked diff，因此后续提交没有改变本次精确输入集。

Project Brief v5 subject digest、Contract approved source digest、GATE-1 approval subject digest 分别与任务的 `41bb...89bb`、`9beb...aef`、`8f93...3597` 一致。

## `QA-G2-ARCH-001..004` 逐项复核

| 缺陷 | 复核结果 | 证据 |
|---|---|---|
| `QA-G2-ARCH-001` | **未关闭** | settlement、information、coverage 已为 revision 5；士与将帅公开阵亡但排除复活池的语义也一致。但 rules spec 现行车规则和旗帜规则仍含被动替死语义残留，违反原关闭条件“规则规格/结算/信息边界/覆盖矩阵统一且无被动替死残留”。 |
| `QA-G2-ARCH-002` | **关闭** | v2 明确是 v1 的修订后继，绑定 confirmed Brief、approved Contract、GATE-1、revision 5 摘要并声明循环未启动；不再沿用过期状态。 |
| `QA-G2-ARCH-003` | **关闭** | application 独占 FullState 与 viewer 选择；projection 是唯一观察者出口；教学只消费 PlayerView、VisibleEvent、VisibleError、ActionPreview；Replay 分级、私有标记隔离、隐藏等价和 deny list 均已冻结。 |
| `QA-G2-ARCH-004` | **关闭** | manifest 绑定 RC3 和不可变证据，明确 seed/replay/codec、比较命令、全量触发、tamper rejection、失败保存与责任回退；不存在把未实现 runner 冒充已通过。 |

### 规则、阵亡记录与复活池

已通过的部分：

- `settlement-order-v1.md` 明确所有实际死亡先进入所属方公开阵亡记录，双方后续 PlayerView 同步。
- 阵亡士和帅/将保留在公开阵亡记录中，但士献祭候选只实时筛选非士、非帅/将。
- 士献祭可在确认前取消；确认后发动士先死亡登记，再随机复活合资格棋子并将其移出阵亡记录。
- 车路径与炮击明确不触发被动士替死；覆盖矩阵把旧 rescue 测试标为 `SUPERSEDED`，当前行为改列 `PENDING-R5`。

未通过的部分：

- `rules-spec-v1.md` 第 4 节车表格仍保留“逐枚处理阵亡/替死”。
- 同文件第 6 节仍保留“替死回营”作为占旗中断原因。
- 这些不是标注为 historical/superseded 的证据描述，而是冻结行为正文，和 revision 5 的主动献祭语义冲突。

### 教学观察者安全 DTO

复核通过：

- viewer 由 application 从 `SeatContext` 或经校验的 `TutorialScenario` 绑定；消费者不能传 viewer。
- TutorialDirector 只消费当前观察者的 PlayerView、VisibleEvent、VisibleError、ActionPreview，脚本敌方动作也提交 NormalizedIntent。
- 教学禁止 raw DomainEvent/DomainError、FullState、权威 Replay、规则 RNG、另一视角 DTO 和隐藏事实。
- 无法从安全 DTO 判断的教学步骤必须退回系统与体验负责人，不允许建立旁路。

### v2 successor 与 `INPUT-ARCH-REVIEW-001`

复核通过且可审计：

- v2 明确声明是历史 v1 的修订后继；v1 SHA-256 保留在 manifest 的 `historical_review`。
- manifest 的 `successor_binding` 同时记录 v1、v2、DTO 文档和“不得沿用历史审阅”的约束。
- 本次 assignment 又以精确 SHA-256 绑定 v2、DTO、manifest、整改证据与规则输入。
- 若复审最终通过，项目经理可以在不改写历史的前提下生成一个 `INPUT-ARCH-REVIEW-001` binding，记录 v1→v2 successor、精确摘要与两份新复审；不能仅写“已审阅”或沿用 v1 结论。

本次因为 `QA-G2-ARCH-001` 未关闭，项目经理现在仍不得生成 satisfied binding。

### Migration manifest

只读 YAML/摘要结构校验通过：

- manifest root/schema/ID 正确，无重复 key；受审与传递依赖摘要均匹配。
- RC3 candidate `6253678157157091584b253470e709bad17c534f`、Windows RC3 大小与 SHA-256、GATE-1 evidence/build 摘要均匹配实际文件。
- 全量 seed 为闭区间 `471001..472000`，共 1000；预期 failures/determinism mismatch 为 0，replay 为 `20/20`。
- Replay 样本精确为 `471001..471020`，包括已知回归 `471016`；诊断证据摘要匹配。
- 10 个唯一 codec 通道完整覆盖 FullState、DomainEvent、红/黑 PlayerView、红/黑 VisibleEvent、VisibleError、ActionPreview、AuthoritativeReplay、ObserverReplay。
- 8 项命令区分 RC3 已存在命令和循环内必须实现的 formal runner；8 个 full-rerun trigger 覆盖规则、随机、codec、projection、replay、基线摘要和任一预检不等价。
- 任一不等价必须停止当前切片、禁止进入下一迭代、保留最小复现；禁止修改 RC3 历史证据或只祝福新 digest。

## 防泄露边界与 deny list 可执行性

本部分复核通过：

- `PlayerView`、`VisibleEvent`、`VisibleError`、`ActionPreview` 均为 allow-list codec，unknown field、错误类型、错误版本和篡改整体拒绝。
- `VisibleError` 对隐身马腿/象眼、未知路径、隐藏终点、炮架和敌相田阻挡使用相同字段、`intent_unresolved`、message key、consumed 和 timing bucket。
- VisibleEvent 使用 per-viewer 连续序号，不暴露 raw event sequence 空洞；未发现旗帜的占旗消息不含坐标。
- AuthoritativeReplay 永不进入玩家通道；ObserverReplay frame 必须与实时观察者 DTO 字节等价，viewer/digest/codec 篡改整体拒绝。
- 私有标记只在本地 presentation repository，不进入 authority、PlayerView、replay、摘要或传输。
- deny list 对 domain/application/projection/presentation/tutorial/未来 endpoint 分目录列明禁止引用和公开签名，并要求 ITERATION-1 建立递归扫描器，任一命中非零退出；不是以人工 grep 代替测试。
- 六组隐藏等价配对覆盖未发现旗、隐身马/腿、敌相田来源、隐藏炮架、未来 RNG 和私有标记。

## 自动检查记录

| 检查 | 结果 |
|---|---|
| `validate_project_instance.py --project-root . --plugin-root .../0.4.0-alpha.2` | PASS，退出码 0，state `normal`。 |
| `validate_project_brief.py ... --approval-dir game-pipeline/approvals` | PASS，退出码 0，Brief `confirmed / ready`，subject digest 匹配。 |
| `validate_organization_registry.py` | PASS，退出码 0；QA 与 Godot 技术负责人为不同已登记实例。 |
| Contract 只读结构检查 | PASS；ID/version/status/approval、必需 `INPUT-ARCH-REVIEW-001` 和 GATE-2 人工权限均正确。 |
| 七项 assignment 输入 SHA-256 | PASS，`7/7` 匹配。 |
| Manifest duplicate-key/YAML/摘要与文件结构检查 | PASS；1000 seeds、20 replay、471016、10 codec、8 commands、8 triggers 均符合。 |
| Revision 5 被动替死残留审计 | **FAIL**；rules spec 两处现行行为残留。 |
| 受审源 tracked diff | PASS，无 tracked diff。 |
| 本报告 `git diff --check` | 完成后复核，必须为退出码 0。 |

## 精确缺陷与返回路径

### `QA-G2-ARCH-001-R2` — high

责任返回：`pos:veilfront-xiangqi-siege:design-experience:systems-experience-lead`

需要修订：

1. 把 `rules-spec-v1.md` 的车规则“逐枚处理阵亡/替死”改为 revision 5 的“逐枚实际死亡登记并检查将帅，不触发被动替死”。
2. 把旗帜规则中的“替死回营”删除或替换成真实存在的 revision 5 生命周期原因；主动献祭的发动士死亡、被复活棋子入场与占领者离位分别按当前结算语义表达。
3. 对规则规格、结算顺序、信息边界和覆盖矩阵重新执行被动替死残留审计。允许出现“已取消”“不存在”和 `SUPERSEDED` 的历史/否定说明，但现行行为正文不能再描述被动替死。

如果修订只是消除文档漂移，不需要 QA 代替 owner 选择规则；若发现语义并非文案残留，必须升级项目经理与项目所有者。

由于 rules spec SHA-256 会变化，Godot 技术负责人必须更新 v2 的规则摘要、migration manifest 的 baseline/hash、相关整改证据和 assignment 输入摘要；项目经理随后重新发起针对新摘要集的双审。本次复审不能自动继承到新文件。

关闭条件：四份 revision 5 事实源没有现行被动替死语义；所有新摘要一致；技术与独立 QA 对同一新摘要集均为 `approved`。

## 失败回退与下一合法动作

- 第二生产循环保持 `not_started`；不得把 `INPUT-ARCH-REVIEW-001` 标记为 satisfied，不登记或启动 Loop Registry。
- 保留 RC3、历史 manifest、v1 审阅与本次失败报告；禁止通过改历史证据或忽略 rules spec 冲突来通过。
- 下一合法动作只有：系统与体验负责人修正规则规格残留，Godot 技术负责人重算并更新所有传递摘要，项目经理登记新的精确双审任务。
- 即使下一次双审都为 `approved`，也只授权项目经理绑定 input、执行循环启动审计和启动已批准循环。
- GATE-2 仍只能在正式灰盒、教学、视觉基线和独立 QA 完成后由 `project-owner` 人工决定。
- 当前继续禁止互联网/Steam 网络实现、服务器采购、AI 交付和高成本批量美术。

## 报告交付校验

- `git diff --check -- evidence/gate2/architecture-independent-qa-rereview-v2.md`：PASS，退出码 0。
- 未提交、未推送。
