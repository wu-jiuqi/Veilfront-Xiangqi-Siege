# GATE-2 架构前置整改证据 v1

状态：`REM-G2-002 completed / awaiting REM-G2-003 dual re-review / loop not started`

整改项：`REM-G2-002`，目标关闭 `QA-G2-ARCH-002/003/004`。

责任身份：

- Agent Instance：`inst:01M02NJ3JEQXKV6PT6DPX0NKQ0`
- Position：`pos:veilfront-xiangqi-siege:technology:godot-technical-lead`
- Authority：`AUTH-VEILFRONT-GODOT-TECHNOLOGY`
- 任务源：`game-pipeline/loops/evidence/GATE2-architecture-review-remediation-plan.md`

本整改只生成架构事实源、DTO/信任边界、迁移 manifest 与证据；未实现正式运行时代码，未修改 v1 报告、Contract、Registry、approval、规则、测试或其他文件。

## 输入绑定

| 输入 | 精确身份 |
|---|---|
| Project Brief v5 | `confirmed`；subject digest `41bb82fae4f1a0294d17746f3b9caf063ee69d2bd07e0f7d15d26baad9ab89bb`；approval `approval:veilfront-xiangqi-siege:project-brief:41bb82fae4f1` |
| Loop Contract | `LOOP-CTR-FORMAL-FOUNDATION-GATE2-001@v1 / approved`；source digest `9beb91baa720820d0f0985019e5a77a4e0e065a8721451eedc30e0cc22bdeaef`；approval `approval:veilfront-xiangqi-siege:loop-contract:9beb91baa720` |
| GATE-1 | `approved`；subject digest `8f93c3506192b1e286bd5f1bf631054f9fb3f0dc5337f3050716a2186a383597`；approval `approval:veilfront-xiangqi-siege:gate-1:8f93c3506192` |
| RC3 | candidate commit `6253678157157091584b253470e709bad17c534f`；evidence index SHA-256 `be64807394e3f05ed8e1e4366a0a3f88ad2cc78bfef932b3f1f20c411e4eb650` |
| REM-G2-001 | main `0de8bb5e29a8a0731731f978dad6f568ff0bb51e`；整改证据 SHA-256 `a47a80f32b269040b4c872cdf25c9223eb57f097a74ccd7fccc1e4d13fbfaadb` |
| Revision 5 规则 | rules `f5158daa0e0235f9cca31ee4411ab1ae647e6ff20019c3316c8f8d35d91f61ab`；settlement `7335fb20723e6a36eb961ed50739f590e9e426b927af726ca7fbbe7c6992694a`；information `dd76596fb4e196732ea73da9cefc33f3879b3102df345b46f55cf00fe7c17d07`；coverage `5a6c277bbcb74f038953337a7634a1c4e3c7d53bc58b76dfff50d6d2e6f7199b` |

## 整改产物

| 产物 | SHA-256 | 用途 |
|---|---|---|
| `docs/architecture/post-gate1-formal-architecture-review-v2.md` | `6320614a35dfa03398d6aae53a8b62bbc3f42199e471f98b59590e603bfbe025` | v1 的修订后继；更新审批事实、规则摘要、正式依赖、Godot 映射、迁移顺序与重新绑定要求 |
| `docs/architecture/formal-dto-and-trust-boundary-v1.md` | `6f23274810aad5d6f2515bd78b114da16684e38f9abe04e2d59dcfa87fc174f2` | 冻结 FullState/viewer、唯一 projection 出口、Visible DTO、Replay 分级、私有标记、deny list 与安全测试 |
| `docs/architecture/gate1-to-formal-migration-manifest-v1.yaml` | `69f784de94296b593d71f08b81ed96a169e61d4a00becc7f1668cfc8082822ec` | 冻结 RC3、规则源、471001..472000、20 replay、471016、codec、命令、1000-seed 触发和失败回退 |
| `evidence/gate2/architecture-remediation-v1.md` | `由交接在文件完成后计算并绑定` | 本整改的范围、缺陷关闭、验证与下一合法动作 |

任一前三项文件变化都会使本文中的摘要和后续复审失效，必须重新计算并重新发起 REM-G2-003。

## 缺陷关闭说明

### `QA-G2-ARCH-002` — ready for independent closure

- v2 状态明确为 Brief v5 已确认、Contract v1 已批准、GATE-1 已批准、第二循环未启动。
- v2 绑定全部 approval/digest、RC3 和 revision 5 修订后规则摘要，不再声称等待已经完成的审批。
- v1 与历史审阅保持不改。v2 明确为 v1 的修订后继；由于 Contract input 文案仍指向 v1，项目经理必须以 v2 新摘要和 REM-G2-003 新双审完成 input binding，不能沿用旧技术 `approved` 或旧 QA `blocked`。

### `QA-G2-ARCH-003` — ready for independent closure

- application 是唯一 FullState owner 和 viewer 选择者；外部 facade 不接收 viewer 参数。
- projection 是唯一 FullState 到 PlayerView、VisibleEvent、VisibleError、ActionPreview 的出口；previewer 只读 PlayerView。
- presentation、教学与未来 endpoint 禁止 raw DomainEvent/DomainError、full audit、AuthoritativeReplay、规则 RNG、另一 viewer 或自选 viewer。
- VisibleError 冻结固定字段/公开 code/message/timing bucket；VisibleEvent 使用 per-viewer 连续序号，不暴露 raw sequence。
- AuthoritativeReplay 与 ObserverReplay 字段、访问、codec 和整体拒绝策略已分开；后者 frame 必须与实时观察者 DTO 字节等价。
- 私有标记冻结为本机非权威状态，不进入 FullState、PlayerView、任一 replay、摘要或传输。
- 提供六组隐藏等价配对与错误外形失败标准，以及递归可扫描依赖禁止清单。

### `QA-G2-ARCH-004` — ready for independent closure

- manifest 绑定 GATE-1 RC3 `6253678157157091584b253470e709bad17c534f`、GATE-1 approval、RC3 evidence/build 和全部 revision 5 规则/信息源摘要。
- 固定全量 seed 是闭区间 `471001..472000` 共 1000；stress manifest SHA-256 与 records digest 已绑定。
- replay 样本明确为 runner 的前 20 个 seed `471001..471020`；已知回归 seed `471016` 单列并绑定诊断证据。
- state、event、red/black PlayerView、red/black VisibleEvent、VisibleError、ActionPreview、权威/观察者 replay 均绑定 source/target codec 版本和比较语义。
- 现有 RC3 复现/manifest/tamper/471016 命令与循环内待实现的等价、隐藏等价和依赖扫描命令分开标记，未把不存在的 runner 冒充已通过。
- 任一规则、结算、随机、codec、projection、replay 或基线摘要变化均触发 1000-seed；失败必须停止切片、保留最小复现并返回责任任务，禁止修改历史 golden 迎合新结果。

## Godot 生产决定

- 固定应用、棋盘/HUD、教学与覆盖层继续以 `.tscn` 预置；规则、教学、Theme 以 `.tres`。
- `ADR-GODOT-INPUT-001` 把选择、取消/标记、确认、平移、缩放、教学跳过与 UI 取消物化到 `project.godot` Input Map；硬编码不能作为唯一入口。
- `ADR-GODOT-FOG-001` 使用预置单一 `FogOverlay` Control 绘制 24×9 迷雾，不动态生成 216 个固定 Control；棋子、旗帜、虚影和临时轨迹仍可因运行时生命周期动态实例化。
- DTO/codec 使用无 SceneTree 生命周期的 `RefCounted`/静态脚本；mutable FullState 不作为共享 Resource。

## 验证边界

- 本任务是 pre-loop 文档整改，没有运行正式核心、教学场景或比较 runner；manifest 将尚不存在的命令明确标记为 `must_be_implemented_by_TASK-*`。
- YAML safe loader 与重复 key 检查：`PASS`；root 为 `migration_manifest`，schema/ID 正确，seed `471001..472000` 共 1000，replay 20，必需 codec channel 10 个且唯一。
- 四个授权文件的 no-index whitespace 检查与 workspace `git diff --check`：`PASS`；未跟踪的其他用户文件不属于本整改。
- 最终摘要由本实例在文件完成后计算并交给项目经理；本文不嵌入自身摘要，避免自引用改变文件。
- 本证据不替代独立 QA，也不把 `ready_for_re_review` 写成缺陷已由 QA 关闭。

## 下一合法动作

1. 项目经理记录四份产物的最终 SHA-256，并以 v2、DTO 文档、manifest 和本文为 REM-G2-003 的不可歧义输入集。
2. Godot 技术负责人复审该精确输入集；质量与发布负责人独立验证同一输入集、revision 5 摘要、manifest 结构和安全边界。
3. 只有两份复审均为 `approved` 且 `QA-G2-ARCH-001..004` 全部关闭，项目经理才可把 `INPUT-ARCH-REVIEW-001` 绑定为满足并登记第二生产循环。
4. 在此之前继续禁止正式实现、Registry 启动、GATE-2 状态推进、互联网/Steam、AI 交付和批量美术。
