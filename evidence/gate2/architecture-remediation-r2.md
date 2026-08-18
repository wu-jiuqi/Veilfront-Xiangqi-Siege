# GATE-2 架构前置第二次整改证据

状态：`REM-G2-R2-002 completed / awaiting REM-G2-R2-003 final dual re-review / loop not started`

整改项：`REM-G2-R2-002`，传递 `REM-G2-R2-001` 对 `QA-G2-ARCH-001-R2` 的修订结果。

责任身份：

- Agent Instance：`inst:01M02NJ3JEQXKV6PT6DPX0NKQ0`
- Position：`pos:veilfront-xiangqi-siege:technology:godot-technical-lead`
- Authority：`AUTH-VEILFRONT-GODOT-TECHNOLOGY`
- 任务源：`game-pipeline/loops/evidence/GATE2-architecture-review-remediation-r2-plan.md`

本整改只更新架构 v2 与迁移 manifest 的传递摘要、冲突/回归绑定和预复审状态，并创建本证据。`formal-dto-and-trust-boundary-v1.md` 保持逐字节不变；未修改规则、旧审阅、首次整改证据、Contract、Registry、approval、代码或测试。

## 1. 触发与历史继承链

首次 REM-G2-002 已形成架构 v2、DTO/信任边界和迁移 manifest。随后技术复审为 `approved`，独立 QA 复审为 `revision_required`，且唯一剩余缺陷为 `QA-G2-ARCH-001-R2`：规则规格正文中车路径和旗帜生命周期仍有现行被动替死残留。

`REM-G2-R2-001` 已在 `main@e9c5e9812a14a733d39595215022dd83d9538eb9` 修订规则规格并完成四事实源残留审计。首次整改及其双审继续作为历史证据，不能替代本轮最终输入或结论；本轮也不改写历史失败报告。

## 2. 最终输入摘要绑定

| 当前输入 | SHA-256 | 绑定用途 |
|---|---|---|
| `docs/architecture/post-gate1-formal-architecture-review-v2.md` | `58e55d7e6e2fb25c04a243017fc8e0230915a36dcc09cacaf7076b10423705f4` | R2 后的正式架构后继、规则链、水位与缺陷状态 |
| `docs/architecture/gate1-to-formal-migration-manifest-v1.yaml` | `0502e20a861a550e9845cfa1a10e4b5d94b97d1da884add2d0de70e9fa14daa4` | R2 规则基线、successor、冲突、全量回归与失败回退 |
| `docs/architecture/formal-dto-and-trust-boundary-v1.md` | `6f23274810aad5d6f2515bd78b114da16684e38f9abe04e2d59dcfa87fc174f2` | 未修改的 DTO、观察者与信任边界 |
| `docs/prototype/rules-spec-v1.md` | `34a1d398beaee6610f3d614559a5af7a14abd464e5df4d86ac26aa3824504ddd` | 当前 gameplay rules |
| `docs/prototype/settlement-order-v1.md` | `7335fb20723e6a36eb961ed50739f590e9e426b927af726ca7fbbe7c6992694a` | 当前结算顺序 |
| `docs/prototype/information-boundary-v1.md` | `dd76596fb4e196732ea73da9cefc33f3879b3102df345b46f55cf00fe7c17d07` | 当前观察者信息边界 |
| `docs/prototype/rules-test-coverage-matrix-v1.md` | `5a6c277bbcb74f038953337a7634a1c4e3c7d53bc58b76dfff50d6d2e6f7199b` | 当前规则覆盖与历史否定性测试 |
| `evidence/gate2/rules-baseline-revision5-remediation-r2.md` | `3576aca373288cc841cb814fcee7335513bfd5632222b09f4cbc1993e1dd177a` | `QA-G2-ARCH-001-R2` 当前整改证据 |

以上八项构成 REM-G2-R2-003 必须共同复审的当前输入。任一文件变化都会使本证据和后续 assignment 摘要失效，必须重新生成传递绑定。

## 3. 架构 v2 更新

- 规则规格摘要已更新为 `34a1d398...04ddd`，不再绑定被独立 QA 判定有冲突的旧规则版本。
- 首次规则整改证据保留为历史链并明确不是当前关闭输入；R2 规则证据被标为当前输入。
- 整改代码库水位更新为 `main@e9c5e9812a14a733d39595215022dd83d9538eb9`。
- `QA-G2-ARCH-001-R2` 状态为“规则整改完成、关闭等待最终双审”，没有写成已经由 QA 关闭。
- `QA-G2-ARCH-002/003/004` 保留此前复审关闭事实，但必须随最终精确输入集重新绑定；旧技术或 QA 结论不得自动继承。
- 下一合法动作统一为 `REM-G2-R2-003` 最终双审；第二生产循环继续为 `not started`。

## 4. Migration manifest 更新

- `successor_binding.revised_review.sha256_at_manifest_creation` 精确绑定修改后 v2：`58e55d7e6e2fb25c04a243017fc8e0230915a36dcc09cacaf7076b10423705f4`。
- `rules_and_information_baseline.files` 只列四份当前规则/信息事实源，并绑定新的规则规格摘要；首次与 R2 整改证据在 `remediation_chain` 中分级，当前关闭输入无歧义。
- `conflict_policy` 要求四事实源或 R2 证据任一摘要变化、或再次出现现行被动替死残留时停止迁移并返回系统与体验负责人；禁止技术实现回退首次摘要或自行选择规则语义。
- 既有八项 `full_1000_seed_rerun_triggers` 数量不变，其中规则触发项已改为覆盖四事实源与 R2 整改证据摘要。任何触发仍要求 1000 seeds、20 replay、零确定性/跨实现不匹配及 tamper rejection。
- scope guard 与下一合法动作已更新到 `REM-G2-R2-002/003`；没有宣称未来比较 runner 已存在或已通过。

## 5. `QA-G2-ARCH-001-R2` 预关闭判断

R2 规则证据显示：

1. 车路径按每个目标的实际死亡登记与将帅检查结算，并明确不触发被动士替死；
2. 旗帜占领中断改为离开、死亡、主动献祭、复活导致实例离场、强制撤回或实例变化等 revision 5 真实生命周期；
3. 四事实源对 `替死|救援|前两次|强制士|rescue|substitut` 的剩余命中均属于明确否定、取消、稳定追溯 ID 或 `SUPERSEDED` 历史测试；没有未分类的现行被动替死行为。

因此技术传递条件已满足，`QA-G2-ARCH-001-R2` 可以进入最终复审，但尚不能在本证据中声明关闭。关闭条件仍是 Godot 技术负责人和独立 QA 对上表同一摘要集分别从头复审且都给出 `approved`。

## 6. Godot 与回归影响

本次是规则文档漂移修复，不改变已审查的 Godot 4.7.1 目录、预置场景/资源映射、application 独占 FullState/viewer、projection 单一观察者出口、DTO codec、两级 replay、Input Map 或单一 FogOverlay ADR。

规则规格摘要属于 migration manifest 的强制全量重跑触发源。正式迁移一旦开始，不能只更新 golden 摘要；必须按 manifest 比较 FullState、DomainEvent、红黑 PlayerView/VisibleEvent、VisibleError、ActionPreview 与两级 replay，并在触发时执行完整 1000-seed 回归。任一不等价停止当前切片并保留 RC3、失败 seed、首个差异通道与 canonical 字节。

## 7. 验证记录

- `validate_project_instance.py --project-root .`：`PASS`，项目实例与插件锁为 `normal`。
- R2 规则提交与水位：`main@e9c5e9812a14a733d39595215022dd83d9538eb9`，匹配任务前置。
- YAML safe parse + duplicate-key rejection：`PASS`。
- manifest 路径型 SHA-256 引用：`16/16 MATCH`；v2 successor 摘要匹配。
- manifest 结构：四份当前规则事实源、两段整改历史链、8 个全量回归触发、下一动作 `REM-G2-R2-003`。
- 当前 v2 与 manifest 中旧规则摘要残留：`0`。
- `git diff --check` 与三份授权文件 no-index whitespace check：`PASS`。
- 本文件 SHA-256 由交接在定稿后计算，避免自引用改变摘要。

## 8. 下一合法动作与禁止项

项目经理只能以第 2 节八项摘要和本证据的最终摘要创建 `REM-G2-R2-003` assignment。Godot 技术负责人和质量与发布负责人必须对同一输入集从头复审；只有两份结论都为 `approved`，项目经理才可生成 satisfied `INPUT-ARCH-REVIEW-001` binding 并执行第二生产循环启动审计。

在此之前继续禁止正式运行时实现、Registry 循环启动、GATE-2 状态推进、互联网/Steam 联网、服务器采购、AI 交付与高成本批量美术。本整改不构成 GATE-2 或任何人工闸门批准。
