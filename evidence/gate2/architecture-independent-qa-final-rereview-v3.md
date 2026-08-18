# GATE-2 架构独立 QA 最终复审 v3

- 复审结论：`approved`
- 复审时间：`2026-08-18T12:48:58.6581143+08:00`
- 执行实例：`inst:01M02NJ3JFHVZ5C4SP5MTJFJR6`
- Position：`pos:veilfront-xiangqi-siege:quality:qa-release-lead`
- Authority：`AUTH-VEILFRONT-QA-RELEASE`
- Assignment：`game-pipeline/loops/evidence/GATE2-architecture-final-rereview-assignment.md`
- 审阅基线：assignment 登记的 artifact baseline `main@2a3a0d5`；本轮检查时 HEAD `b8dc30352540577d5394459eea9513bab5005ee3`

## 1. 独立性与范围

本报告从 assignment 指定的九项输入重新读取源文件、计算摘要并执行校验，不继承此前 QA 的 `blocked`、`revision_required` 或 `approved` 结论，也未将修订说明当作源文件替代品。本轮未读取或采用并行技术最终复审报告的判断。

QA 仅验证准入证据，不修改规则、架构、Contract、Registry、approval、代码或技术报告。本结论不批准 GATE-2，也不构成互联网/Steam、服务器、AI 人机对战或批量美术生产授权。

## 2. 九项受控输入与新鲜度

| # | 输入 | assignment SHA-256 | 本轮实算 | 结果 |
|---:|---|---|---|---|
| 1 | `docs/architecture/post-gate1-formal-architecture-review-v2.md` | `58e55d7e6e2fb25c04a243017fc8e0230915a36dcc09cacaf7076b10423705f4` | 同左 | PASS |
| 2 | `docs/architecture/formal-dto-and-trust-boundary-v1.md` | `6f23274810aad5d6f2515bd78b114da16684e38f9abe04e2d59dcfa87fc174f2` | 同左 | PASS |
| 3 | `docs/architecture/gate1-to-formal-migration-manifest-v1.yaml` | `0502e20a861a550e9845cfa1a10e4b5d94b97d1da884add2d0de70e9fa14daa4` | 同左 | PASS |
| 4 | `docs/prototype/rules-spec-v1.md` | `34a1d398beaee6610f3d614559a5af7a14abd464e5df4d86ac26aa3824504ddd` | 同左 | PASS |
| 5 | `docs/prototype/settlement-order-v1.md` | `7335fb20723e6a36eb961ed50739f590e9e426b927af726ca7fbbe7c6992694a` | 同左 | PASS |
| 6 | `docs/prototype/information-boundary-v1.md` | `dd76596fb4e196732ea73da9cefc33f3879b3102df345b46f55cf00fe7c17d07` | 同左 | PASS |
| 7 | `docs/prototype/rules-test-coverage-matrix-v1.md` | `5a6c277bbcb74f038953337a7634a1c4e3c7d53bc58b76dfff50d6d2e6f7199b` | 同左 | PASS |
| 8 | `evidence/gate2/rules-baseline-revision5-remediation-r2.md` | `3576aca373288cc841cb814fcee7335513bfd5632222b09f4cbc1993e1dd177a` | 同左 | PASS |
| 9 | `evidence/gate2/architecture-remediation-r2.md` | `4339243220e13f2a8e67063cbeedac71b9fcb5d063519fdc58520a46b8574048` | 同左 | PASS |

九项输入路径在写报告前无 tracked diff；摘要为 `9/9` 精确匹配。HEAD 相对 artifact baseline 的后续提交为修订收口及最终复审登记，未导致 assignment 所绑定输入发生摘要漂移。

关联治理摘要亦核对通过：Project Brief v5 `41bb82fae4f1a0294d17746f3b9caf063ee69d2bd07e0f7d15d26baad9ab89bb`、Contract approved source digest `9beb91baa720820d0f0985019e5a77a4e0e065a8721451eedc30e0cc22bdeaef`、GATE-1 approval digest `8f93c3506192b1e286bd5f1bf631054f9fb3f0dc5337f3050716a2186a383597`。

## 3. 自动与结构校验

| 检查 | 结果 | 关键证据 |
|---|---|---|
| 项目实例校验 | PASS | project state 为 `normal` |
| Project Brief 校验 | PASS | `confirmed/ready`，项目 ID 与 approval 绑定有效 |
| 组织 Registry 校验 | PASS | snapshot/history 一致 |
| Contract 只读校验 | PASS | `LOOP-CTR-FORMAL-FOUNDATION-GATE2-001@v1` 为 `approved`；当前文件 SHA-256 `a26a9b3fdb0d8d06e42a06833a84455d911fea8f72bcedec59d0ae5e620cc205` |
| 严格 YAML/摘要结构校验 | PASS | 拒绝重复键；assignment、manifest、successor、RC3、seed、Contract 绑定均一致 |

结构校验汇总为：九项 assignment hashes、1000 seeds、20 replays、已知回归种子 471016、10 个 codec channel、8 条比较命令、8 个全量重跑触发条件全部满足预期。

## 4. 四事实源术语分类审计

对四个事实源逐项执行大小写不敏感检索：`替死|救援|前两次|强制士|rescue|substitut`。

| 事实源 | 命中数 | 分类结果 |
|---|---:|---|
| `rules-spec-v1.md` | 7 | 当前规则中的显式否定/取消约束、稳定 trace ID 或历史说明；无主动被动替死语义 |
| `settlement-order-v1.md` | 5 | 显式否定/取消约束或稳定 trace ID；无主动被动替死语义 |
| `information-boundary-v1.md` | 0 | 无残留 |
| `rules-test-coverage-matrix-v1.md` | 9 | `SUPERSEDED` 历史项、否定测试 ID 或显式禁用约束；无主动被动替死语义 |

未分类命中为 `0`。当前四事实源统一为 revision 5：任何原因造成的实际阵亡均登记公开阵亡；车造成阵亡后直接进入将帅检查，不触发被动士替死；旗帜实例退出、强制回营或实例变化不再借用“替死回营”语义。

## 5. QA-G2-ARCH 缺陷复核

| 缺陷 | 最终状态 | 独立复核证据 |
|---|---|---|
| `QA-G2-ARCH-001` | CLOSED | 规则规格、结算、信息边界、覆盖矩阵统一为 revision 5；被动替死残留清零；士/将帅阵亡均进入双方同步可见的公开阵亡记录，但二者均排除出复活候选池；士的主动献祭可取消，确认后才消耗行动、登记士阵亡，并随机复活符合条件的非士、非将帅友方 |
| `QA-G2-ARCH-002` | CLOSED | v2 架构审查为当前 successor，绑定已确认 Brief、approved Contract、GATE-1 与 revision 5/R2 摘要；循环仍未启动 |
| `QA-G2-ARCH-003` | CLOSED | Application 独占 FullState 与 viewer 选择；Projection 是 FullState 到安全 DTO 的唯一出口；教学只消费 `PlayerView`、`VisibleEvent`、`VisibleError`、`ActionPreview`；不得消费 FullState、DomainEvent、authority replay、RNG 或另一 viewer；私有标记只存于本地呈现层 |
| `QA-G2-ARCH-004` | CLOSED | migration manifest 对候选构建、RC3、随机种子、回放、codec、比较命令、触发条件与失败回退均提供可审计绑定 |

未发现需返回生产岗位的新缺陷。

## 6. Successor 与 INPUT-ARCH-REVIEW-001 可审计性

Manifest 保留 v1 历史路径及摘要，并把 v2 明确声明为 successor；本 assignment 又以精确 SHA-256 同时绑定 v2、DTO/信任边界、manifest、四事实源及两份 R2 修订证据。因此 PM 可在技术最终复审与本 QA 最终复审均为 `approved` 后，创建可审计的 `INPUT-ARCH-REVIEW-001` binding，显式记录 `v1 -> v2` successor 关系和本报告核对的九项摘要。旧 QA/技术结论不得代替本轮最终复审输入。

## 7. Manifest 可执行验收与失败回退

- 候选提交：`6253678157157091584b253470e709bad17c534f`。
- RC3 EXE：109,740,336 bytes，SHA-256 `480273ddeae985c0c4aa03be449e5999fba57ca7b296b591ac7ed36b5bc8a229`；manifest 所列证据摘要和实物摘要校验通过。
- 随机性：471001..472000 共 1000 seeds；历史结果 1000 完成、0 failure、0 determinism mismatch。
- 回放：471001..471020 共 20 条，`20/20`；已知回归种子 `471016` 有专属诊断证据。
- Codec：10 个唯一通道，覆盖 FullState、DomainEvent、红/黑 PlayerView、红/黑 VisibleEvent、VisibleError、ActionPreview、AuthoritativeReplay、ObserverReplay。
- 可执行接口：4 条既有 RC3 比较命令和 4 条下一循环必须落地的 runner/scanner 命令；8 个触发任一即全量重跑 1000 seeds 的条件。
- 失败回退：停止当前 slice 且不得开始下一迭代；保留 seed、intent prefix、mismatch channel、canonical bytes、双方/观察者回放及 hidden-pair 证据；规则/信息问题退回系统与体验负责人，codec/架构问题退回 Godot 技术负责人。不得改写历史证据、私自认可新摘要、跳过任一 viewer 或暴露 authority 数据。

下一循环 runner/scanner 尚未实现是 `loop-not-started` 状态下的计划内工作，不是本次输入准入失败；它们必须按 manifest 命令与触发规则在对应 Iteration 内落地并接受 QA 验证，不能以当前批准豁免。

## 8. 观察者安全边界与泄露 deny list

- FullState 仅限 authority；调用方不得自行选择 viewer。
- DTO codec 使用 allow-list；未知字段、重复字段和非法字段必须拒绝。
- `VisibleError` 使用固定结构，并统一隐藏信息相关错误的 code、message 与 timing。
- `VisibleEvent` 采用每 viewer 连续序号，不能通过原始事件序号缺口泄露隐藏事件。
- AuthoritativeReplay 永不面向玩家；ObserverReplay 必须等于现场 observer DTO，viewer/digest 篡改必须拒绝。
- 私有右键标记仅存在于本地 presentation，不进入 authority、对局同步、回放或对方/观察者 DTO。
- Deny list 覆盖 domain、application、projection、presentation、tutorial 与未来 endpoint；Iteration 1 必须提供递归 scanner，任一命中返回非零。
- 隐藏等价对覆盖旗帜、马、相、炮、RNG、私有标记六类；同一 viewer 的安全 DTO、可见错误、预览和观察者回放不得因隐藏状态差异产生可观测差异。

据此，当前规格层信息泄露边界可执行且具备失败判定；实现层仍须由后续 runner/scanner 和 hidden-pair 测试给出实际证据。

## 9. 结论、权限边界与返回路径

最终结论为 `approved`。证据新鲜度、可执行验收、独立性、信息边界、失败回退及 GATE-2 权限分离均满足本次架构输入准入要求。

本批准仅授权项目经理在技术最终复审同样为 `approved` 后：

1. 绑定 `INPUT-ARCH-REVIEW-001`，记录 v1 到 v2 successor 及精确摘要；
2. 执行启动前审计，并在 Contract 既有范围内启动正式基础循环。

本报告不批准 GATE-2。GATE-2 仍只能由项目所有者依据后续循环实证人工批准；也不扩大 Contract 范围。若 PM 无法形成精确 input binding，返回 PM 补齐；若后续规则/信息测试失败，返回系统与体验负责人；若 codec、projection、replay、runner/scanner 或架构实现失败，返回 Godot 技术负责人；QA 保持独立复验，不代改生产事实源。
