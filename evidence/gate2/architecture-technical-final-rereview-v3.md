# GATE-2 正式架构技术最终复审 v3

## 1. 结论

- 结论：`approved`
- 复审日期：`2026-08-18`
- 任务：`game-pipeline/loops/evidence/GATE2-architecture-final-rereview-assignment.md`
- Agent Instance：`inst:01M02NJ3JEQXKV6PT6DPX0NKQ0`
- Position：`pos:veilfront-xiangqi-siege:technology:godot-technical-lead`
- Authority：`AUTH-VEILFRONT-GODOT-TECHNOLOGY`
- 受审 Contract：`LOOP-CTR-FORMAL-FOUNDATION-GATE2-001@v1`

本次以 assignment 列出的九项 SHA-256 输入从头复审，没有继承历史技术 `approved`。R2 规则清理完整，架构 v2、DTO/信任边界与 migration manifest 在 Godot 4.7.1 下可实施，依赖和观察者边界可自动验证，1000-seed 触发与失败回退足以保护 RC3 和隐藏信息边界。未发现需要再次整改或阻断循环启动审计的技术缺陷。

该结论只表示技术最终复审通过，不替代独立 QA、不生成 `INPUT-ARCH-REVIEW-001` binding、不启动第二生产循环，也不批准 GATE-2。

## 2. 复审基线与新鲜度

项目实例和插件锁校验为 `normal`；Project Brief v5 为 `confirmed / ready`，subject digest 为 `41bb82fae4f1a0294d17746f3b9caf063ee69d2bd07e0f7d15d26baad9ab89bb`；Contract v1 的 approved source digest 为 `9beb91baa720820d0f0985019e5a77a4e0e065a8721451eedc30e0cc22bdeaef`；GATE-1 approval subject digest 为 `8f93c3506192b1e286bd5f1bf631054f9fb3f0dc5337f3050716a2186a383597`。

assignment 声明复审水位为 `main@2a3a0d5`。复审时 HEAD 为 `b8dc30352540577d5394459eea9513bab5005ee3`，其间只有最终复审任务登记提交；九项受审输入在该区间没有 tracked diff。工作树中已有的其他未跟踪文件不属于本任务，未被读取为通过证据或修改。

Godot 版本：`4.7.1.stable.official.a13da4feb`；renderer 为 `GL Compatibility`，项目语言为 GDScript。

## 3. 九项输入摘要

| 输入 | assignment SHA-256 | 复核 |
|---|---|---|
| `docs/architecture/post-gate1-formal-architecture-review-v2.md` | `58e55d7e6e2fb25c04a243017fc8e0230915a36dcc09cacaf7076b10423705f4` | `MATCH` |
| `docs/architecture/formal-dto-and-trust-boundary-v1.md` | `6f23274810aad5d6f2515bd78b114da16684e38f9abe04e2d59dcfa87fc174f2` | `MATCH` |
| `docs/architecture/gate1-to-formal-migration-manifest-v1.yaml` | `0502e20a861a550e9845cfa1a10e4b5d94b97d1da884add2d0de70e9fa14daa4` | `MATCH` |
| `docs/prototype/rules-spec-v1.md` | `34a1d398beaee6610f3d614559a5af7a14abd464e5df4d86ac26aa3824504ddd` | `MATCH` |
| `docs/prototype/settlement-order-v1.md` | `7335fb20723e6a36eb961ed50739f590e9e426b927af726ca7fbbe7c6992694a` | `MATCH` |
| `docs/prototype/information-boundary-v1.md` | `dd76596fb4e196732ea73da9cefc33f3879b3102df345b46f55cf00fe7c17d07` | `MATCH` |
| `docs/prototype/rules-test-coverage-matrix-v1.md` | `5a6c277bbcb74f038953337a7634a1c4e3c7d53bc58b76dfff50d6d2e6f7199b` | `MATCH` |
| `evidence/gate2/rules-baseline-revision5-remediation-r2.md` | `3576aca373288cc841cb814fcee7335513bfd5632222b09f4cbc1993e1dd177a` | `MATCH` |
| `evidence/gate2/architecture-remediation-r2.md` | `4339243220e13f2a8e67063cbeedac71b9fcb5d063519fdc58520a46b8574048` | `MATCH` |

结果：`9/9 MATCH`。旧规则摘要 `f5158daa...` 不存在于当前九项输入；manifest 的 v2 successor、DTO、四事实源和当前 R2 证据摘要均与实际文件一致。

## 4. R2 规则清理复核

### 4.1 现行四事实源

对规则规格、结算顺序、信息边界和覆盖矩阵重新扫描 `替死|救援|前两次|强制士|rescue|substitut`，并逐条按现行行为、否定约束、稳定追溯 ID 和 `SUPERSEDED` 历史测试分类。

复核结果：

- 规则规格不再含“逐枚处理阵亡/替死”“替死回营”或旧章节名。车路径现行语义为“逐目标实际死亡登记→将帅检查”，明确不触发被动士替死。
- 旗帜进度绑定具体棋子实例；离开、死亡、主动献祭、复活导致实例离场、强制撤回或实例变化时清零。
- 任何原因造成的实际死亡都进入所属方公开阵亡记录，双方 PlayerView 同步；复活后立即移出。
- 士献祭可在确认前取消。确认后发动士先死亡登记，再从非士、非帅/将子集中随机复活；阵亡士与帅/将留在公开记录但永不进入随机池。
- 信息边界文件对上述残留关键词为零命中，没有投影或回放旁路。
- 覆盖矩阵中的旧 rescue 名称均被明确标为 `SUPERSEDED`、历史证据或否定性测试目标，不能作为现行实现授权。

R2 整改证据引用旧句是为了记录“从旧句修订为新语义”的历史差异，并明确未分类现行冲突为零；这不是现行规则残留。

### 4.2 规则与结算一致性

规则规格、结算顺序和覆盖矩阵对车路径、炮击、献祭、阵亡记录、候选过滤、旗帜实例生命周期与将帅终局顺序一致。完整轮上限和 AI 参数继续保持开放，不被架构默认值冻结。未发现需要返回项目所有者裁决的新语义歧义。

## 5. Godot 4.7.1 可实施性

| 项目 | 复核结论 |
|---|---|
| 正式目录与核心 | `scripts/game/domain` 可用无 SceneTree 的 GDScript 数据/服务实现；application 保存唯一活动 FullState；contracts/projection 使用 `RefCounted` 或静态 codec。Godot 4.7.1 支持该结构。 |
| 预置节点优先 | 应用根、对局、HUD、棋盘覆盖层和教学根均落为 `.tscn`；规则、教学数据和 Theme 落为 `.tres`。仅棋子、旗帜、虚影和临时轨迹因运行时数量/生命周期使用 PackedScene 实例化，符合预置节点原则。 |
| Input Map | `ADR-GODOT-INPUT-001` 已冻结正式 action 名称和右键状态机边界，要求 ITERATION-1 写入 `project.godot`；当前未把待实施配置冒充完成。 |
| 迷雾 | `ADR-GODOT-FOG-001` 使用一个预置 `FogOverlay: Control` 根据 PlayerView 绘制遮罩，不动态生成 216 个固定 Control；镜像只转换绘制坐标。该方案适合 Godot CanvasItem。 |
| DTO/codec | UTF-8 canonical JSON、排序键、语义数组顺序、`Vector2i -> [x,y]` 和 SHA-256 可由 GDScript 稳定实现；DTO 明确禁止 Node、Resource、RID、Callable、PackedScene 等对象引用。 |
| 教学与未来端口 | 教学场景只通过 application facade 提交 Intent 并消费绑定 viewer 的安全 DTO；未来 endpoint 位于端口外侧，不迫使 domain/application 依赖传输。 |

当前原型中的 rule_engine/projector 回环、AI/LAN 预加载和 UI/规则混合已被列为必须拆除的耦合，并有明确迁移顺序。可实施性结论仍需后续等价 runner 和独立 QA 证明，不把“文档可行”解释为运行时已经完成。

## 6. 信任、DTO 与依赖边界

### 6.1 权限与唯一出口

- application 独占活动 FullState 和 viewer 选择，并从受信 `SeatContext` 或经验证的 `TutorialScenario` 绑定席位；公开消费者不能传入 viewer。
- projection 是 FullState 到 PlayerView、VisibleEvent、VisibleError 和 ActionPreview 的唯一出口。`PublicActionPreviewer` 只读 PlayerView 与公开规则。
- presentation、tutorial 和未来 endpoint 禁止 FullState、raw DomainEvent/DomainError、规则 RNG、full audit、AuthoritativeReplay、另一 viewer DTO 或自选观察者。
- 本地圆/叉/方形标记不进入 authority、PlayerView、任一 replay、canonical 摘要或传输。

### 6.2 可见错误、预览与回放

- VisibleError 对隐藏马腿/象眼、路径、终点、炮架和敌相田阻挡采用固定字段、统一 `intent_unresolved`、message key 与 timing bucket。
- ActionPreview 只有 `KNOWN_LEGAL/TENTATIVE/KNOWN_ILLEGAL`；同一 canonical PlayerView 必须产生字节及顺序等价的预览。
- VisibleEvent 使用 per-viewer 连续序号，不暴露 raw sequence 空洞。
- AuthoritativeReplay 含 seed、FullState、raw event、RNG checkpoint，只供 authority/迁移 harness/受控 QA；ObserverReplay 只含实时该 viewer 已见 DTO 的字节等价 frame，viewer/digest/codec 篡改整体拒绝。
- 六组隐藏等价配对覆盖未发现旗、隐身马、敌相田、隐藏炮架、未来 RNG 和私有标记。

### 6.3 可扫描 deny list

domain、application、projection、presentation/tutorial 和未来 endpoint 分别具有明确的禁止引用、类型名和公开签名规则。ITERATION-1 必须实现 `tests/game/architecture/check_dependency_boundaries.gd` 或等价递归扫描器，任一命中非零退出。该 runner 当前不存在，manifest 正确标为 `must_be_implemented_by_TASK-ARCH-001`，没有伪造已通过证据。

## 7. Migration manifest、1000 seeds 与失败回退

YAML 使用 safe loader 并拒绝重复 key，解析通过；带路径的 SHA-256 引用 `16/16 MATCH`。RC3 commit `6253678157157091584b253470e709bad17c534f` 与 R2 commit `e9c5e9812a14a733d39595215022dd83d9538eb9` 均存在。

### 7.1 RC3 与固定样本

- RC3 Windows 构建存在，大小 `109740336` 字节，SHA-256 `480273ddeae985c0c4aa03be449e5999fba57ca7b296b591ac7ed36b5bc8a229`。
- stress JSONL 含 1000 条对局记录，seed 严格为闭区间 `471001..472000`；failure 为 0，determinism mismatch 为 0。
- replay 样本严格为 `471001..471020`，验证 `20/20`；已知回归 `471016` 单独绑定诊断证据。
- records digest 为 `25c40f9467a7c4d4ad45162e3aef7f5f95b1948a76757bd2808b4eb6fc906064`，与 manifest 和 JSONL summary 一致。
- Godot 4.7.1 实际执行 manifest 正常验证返回 0；`--force-record-tamper` 返回 1 并报告 digest mismatch。

### 7.2 Codec、命令与触发

10 个唯一比较通道完整覆盖 FullState、DomainEvent、红黑 PlayerView、红黑 VisibleEvent、VisibleError、ActionPreview、AuthoritativeReplay 和 ObserverReplay。8 个命令中 4 个 RC3 命令及其源文件在候选提交存在，4 个正式迁移/隐藏等价/依赖命令明确归属后续 TASK，没有冒充当前实现。

8 个“任一即全量”触发条件覆盖：domain/结算、seeded RNG 状态与消费顺序、初始化/旗位、state/event/canonical codec、replay、projection/Visible DTO、四规则源或 R2 证据摘要，以及 smoke/replay/471016/隐藏等价的任一失败。触发后的强制结果为 1000 完成、0 失败、0 确定性不匹配、20 replay、0 跨实现不匹配、正常 manifest 返回 0、强制篡改非零。

### 7.3 失败回退

任一不等价必须停止当前切片并禁止进入下一迭代，同时保留 RC3/历史 manifest、失败 seed 与规范 Intent 前缀、首个差异通道/行动索引、旧新 canonical 字节/摘要、replay/隐藏配对最小复现。规则或信息差异返回系统与体验负责人；codec 或架构差异返回 Godot 技术负责人。禁止修改历史 RC3、只祝福新 digest、跳过任一观察者通道或向消费者暴露权威数据。

## 8. `QA-G2-ARCH-001..004` 最终技术判断

| 缺陷 | 技术判断 | 依据 |
|---|---|---|
| `QA-G2-ARCH-001`（含 `QA-G2-ARCH-001-R2`） | `approved / technical closure supported` | 四事实源已清除现行被动替死冲突；车、旗、主动献祭、公开阵亡记录和候选池语义一致；历史命中均已分类。 |
| `QA-G2-ARCH-002` | `approved / technical closure supported` | v2 正确绑定 confirmed Brief、approved Contract、GATE-1、新规则摘要和 R2 水位；v1/旧审阅仅为历史，successor input 必须使用最终新摘要。 |
| `QA-G2-ARCH-003` | `approved / technical closure supported` | FullState/viewer/projection 权限、Visible DTO、错误/预览外形、Replay 分级、私有标记、隐藏等价与 deny list 完整且可实现。 |
| `QA-G2-ARCH-004` | `approved / technical closure supported` | manifest 精确绑定 RC3、1000 seeds、20 replay、10 codec、8 commands、8 triggers、tamper rejection 与失败保存/返回路径。 |

最终缺陷关闭仍由独立 QA 对同一九项摘要作出；本技术报告不替 QA 登记关闭状态。

## 9. 实施阶段必须重检的非阻断义务

1. `TASK-ARCH-001` 物化 Input Map、预置场景根、FogOverlay、codec 和依赖扫描器。
2. `TASK-CORE-001/002` 在迁移前生成不可回写的 RC3 golden snapshot pack，实现 20-replay smoke、隐藏等价和 1000-seed 正式等价 runner。
3. 任一规则摘要、RNG、codec、projection 或 replay 变化按 manifest 全量重跑，不能只替换预期摘要。
4. 独立 QA 从 clean worktree 复现依赖、等价、场景加载、分辨率和信息泄露检查。
5. 首版范围继续排除互联网/Steam、服务器采购、AI 交付和高成本批量美术。

## 10. 下一合法动作

质量与发布负责人对 assignment 的同一九项 SHA-256 输入完成独立最终复审。只有技术与独立 QA 两份最终报告都为 `approved`，项目经理才可生成精确的 `INPUT-ARCH-REVIEW-001` satisfied binding 并执行第二生产循环启动审计。

即使双审都批准，也不等于循环已启动，更不等于 GATE-2 已批准。若独立 QA 发现规则残留，返回系统与体验负责人；发现摘要、manifest、DTO 或依赖缺陷，返回相应 R2 架构/技术责任路径，不得由下游静默绕过。

## 11. 验证记录

- Project instance / Project Brief / Contract 前置：`PASS`。
- assignment 九项 SHA-256：`9/9 MATCH`。
- R2 现行四事实源残留审计：`PASS`；历史引用分类明确。
- YAML safe parse、duplicate-key rejection、路径引用摘要：`PASS / 16/16 MATCH`。
- RC3 JSONL：`records=1000 / seeds=471001..472000 / replay=471001..471020 / failures=0 / determinism_mismatches=0`。
- codec / commands / full-rerun triggers：`10 / 8 / 8`。
- Godot manifest 正常验证 / 篡改拒绝：`exit 0 / exit 1`。
- 报告 no-index whitespace check 与 workspace `git diff --check`：`PASS`。
- 本报告 SHA-256：定稿后由交接给出，避免自引用改变文件。
