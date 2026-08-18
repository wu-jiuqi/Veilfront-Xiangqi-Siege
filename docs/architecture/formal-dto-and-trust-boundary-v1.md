# 正式 DTO 与信任边界 v1

状态：`frozen-for-REM-G2-002 / awaiting dual re-review / no runtime implementation`

适用范围：Project Brief v5、`LOOP-CTR-FORMAL-FOUNDATION-GATE2-001@v1`、owner rule revision 5。

本文冻结正式架构的访问权、DTO 外形、codec 与拒绝策略。它不实现运行时代码，不改变规则语义，也不授权互联网接入。

## 1. 信任域与唯一数据流

```text
                       authority-only
Intent + SeatContext ──► application ──► domain ──► FullState + DomainEvent
                              │                         │
                              │ owns FullState/viewer   │ internal only
                              ▼                         ▼
                          projection ◄──────────────────┘
                              │
                 observer-safe DTOs only
                              ▼
       presentation / tutorial / in-process test endpoint
```

| 信任域 | 允许持有 | 禁止持有 |
|---|---|---|
| `domain` | FullState、DomainCommand、DomainEvent、规则 RNG | PlayerView、场景、UI、教学、AI、LAN、未来网络适配器 |
| `application` | 唯一活跃 FullState 引用、SeatContext、viewer 绑定、domain 与 projection 内部端口 | 具体场景、具体传输、调用者提供的任意 viewer |
| `projection` | application 传入的只读 FullState 快照、绑定 ViewerContext、DomainEvent/DomainError | 修改 FullState、选择 viewer、保存跨回合权威状态、具体 UI/传输 |
| `presentation/tutorial/未来 endpoint` | PlayerView、VisibleEvent、VisibleError、ActionPreview、ObserverReplayRecord | FullState、DomainEvent、DomainError、规则 RNG、AuthoritativeReplayRecord、另一 viewer 的 DTO |
| QA 受控审计 | 不可分发的权威 replay、摘要、FullState 测试快照 | 将审计产物接入玩家表现、教学或未来 endpoint |
| 本地表现 | 当前观察者 DTO、本地私有标记 | 将私有标记写入 authority、PlayerView、replay 或传输 |

只有 application 持有正在运行的 FullState。domain 通过 application 发起的命令处理它；projection 只在 application 内部调用期间获得只读快照。任何对外 facade 都不得把 FullState 作为参数、返回值、信号参数或可取回属性。

## 2. Viewer 选择权

1. application 从受信任 `SeatContext` 绑定 viewer；本地教学的 viewer 来自经校验的预置 `TutorialScenario` Resource，由 application 在创建会话时绑定。
2. presentation、TutorialDirector 与未来 endpoint 调用公开 facade 时不传 `viewer_side`，也不能调用 `project(full_state, viewer)`。
3. projection 的内部入口接收 application 创建的 `ViewerContext`；该类型不能从玩家 DTO 反序列化。
4. 重新连接或换席属于未来独立 Contract；当前端口不得提供运行中任意切换 viewer 的方法。
5. ObserverReplayRecord 的 viewer 在生成时由 application 绑定，读取者不能通过改字段请求另一视角；字段篡改导致整个记录拒绝。

## 3. Codec 通则

正式 codec 家族使用 `veilfront-*-v1` 标识，规则如下：

- 线格式：UTF-8 JSON；对象键递归按 Unicode 字符串升序；数组保持各 schema 声明的语义顺序；`Vector2i` 编码为两个整数 `[x,y]`。
- 摘要：对无 BOM、无额外空白的 canonical JSON 字节计算 SHA-256，小写十六进制。
- 所有 root 必须包含 `schema_version`；未知版本返回 `unsupported_schema_version`，不得猜测升级或降级。
- 所有 schema 采用 allow-list；缺字段、未知字段、重复 JSON key、非有限数值、错误类型、越界坐标或非 canonical 排序均拒绝。
- 解码失败只生成固定外形的 transport/application 错误，不把 parser 路径、原值、FullState 或内部字段名发送给观察者。
- DTO 中不允许 `Object`、`NodePath`、`Callable`、RID、Resource 引用、PackedScene、任意对象实例或 SceneTree 生命周期引用。
- schema 升级必须新版本并保持旧 decoder 只读；不得在 `v1` 下改变字段含义。

## 4. 权威 DTO

### 4.1 NormalizedIntent — `veilfront-intent-v1`

允许字段：

| 字段 | 类型 | 规则 |
|---|---|---|
| `schema_version` | String | 固定 `veilfront-intent-v1` |
| `intent_id` | String | 当前会话内唯一，不携带 viewer 信息 |
| `expected_action_index` | int | 防止过期提交；不决定 viewer |
| `piece_id` | String | `pass` 时可为空 |
| `action_type` | String | allow-list：`move/bombard/resurrect/pass/skip/timeout`；玩家端只提交获准子集 |
| `target_cell` | Array[int,int] 或空数组 | `resurrect/pass/skip/timeout` 为空 |
| `skill_type` | String | allow-list 或空字符串 |
| `confirmation_token` | String | application 创建的待确认 token；取消时不提交 Intent |

禁止字段：`viewer_side`、`actor_side`、seed、合法性真值、隐藏碰撞、候选池、随机结果或 FullState 摘要。actor 由 application 的 SeatContext 推导。

### 4.2 FullState — `veilfront-full-state-v1`

FullState 是 authority-only 的版本化字段模型，最少包含：规则/实现版本、配置、活动方、行动与完整轮索引、棋盘、棋子、城墙、旗帜与分观察者发现记忆、公开阵亡记录、复活/后备状态、虚影、接触情报、视野源、准备中事务、终局、RNG 状态和 domain event log。

访问规则：

- 只由 application 保存；domain 处理命令；projection 只读。
- 不进入 UI signal、TutorialDirector、endpoint、PlayerView、Visible DTO 或 ObserverReplayRecord。
- 私有标记永不进入 FullState。
- FullState codec 只供权威存档、迁移测试和受控审计；正式存档兼容策略在本循环内仅冻结版本，不承诺跨版本发布兼容。

### 4.3 DomainEvent / DomainError

- `veilfront-domain-event-v1`：允许 raw 实体 ID、完整坐标、随机抽取、结算顺序、raw sequence 和审计关联；authority-only。
- `veilfront-domain-error-v1`：允许精确失败原因供规则调试；authority-only。
- 两者不得直接被 signal 到表现/教学/endpoint，也不得原样写入 ObserverReplayRecord。

## 5. 观察者安全 DTO

projection 是唯一允许读取 FullState 并产生以下 DTO 的组件。`PublicActionPreviewer` 属于 projection 子系统，但只读取已经生成的 PlayerView 与公开规则配置；它不读取 FullState。

### 5.1 PlayerView — `veilfront-player-view-v1`

允许 root 字段：

`schema_version, match_id, rules_revision, viewer_side, board, active_side, action_index, full_round_index, round_limit_public, terminal, winner, win_reason, visible_cells, hidden_detection_cells, pieces, flags, walls, casualties, capture_ghosts, vision_overlays, contact_intel, visible_event_cursor`

约束：

- `viewer_side` 来自绑定 ViewerContext，只用于证明 DTO 身份，不作为下一次投影请求参数。
- 未发现旗帜必须 `discovered=false, position=[]`；不得含 seed、RNG、未来抽样或完整旗位集合。
- 敌方相田来源、敌方私有视野源和迷雾敌棋不出现；己方专属高亮只含该 viewer 获准的信息。
- casualty 是双方公开阵亡记录；复活候选池不是 PlayerView root，士与将帅即使在 casualty 中也不能由 UI 推导为候选。
- `visible_event_cursor` 是该 viewer 的连续可见序号，不暴露 raw event sequence 的空洞。
- private marker 不在字段集合内；unknown-field decoder 会拒绝它。

### 5.2 VisibleEvent — `veilfront-visible-event-v1`

允许字段：

`schema_version, visible_sequence, action_index, event_type, actor_side_public, position_public, piece_public, message_key, public_payload, timing_bucket`

约束：

- `visible_sequence` 对每个 viewer 从 1 连续递增；不得复制 raw domain event ID/sequence。
- `public_payload` 按 `event_type` 使用字段 allow-list；没有授权的值用空值/省略 schema 规定的可选字段，不能塞入通用 debug 字典。
- 占旗进度消息可公开阵营与进度，但对尚未发现该旗的 viewer 不含位置。
- 随机复活、炮击、撤回结果只在规则授权的公开结算点发布。

### 5.3 VisibleError — `veilfront-visible-error-v1`

固定字段：

| 字段 | 类型 | 说明 |
|---|---|---|
| `schema_version` | String | 固定 `veilfront-visible-error-v1` |
| `intent_id` | String | 回应公开请求；不含 raw command ID |
| `action_index` | int | 公开行动索引 |
| `resolution` | String | `rejected_without_consumption` 或 `consumed_without_effect` |
| `public_code` | String | allow-list：`known_illegal`, `intent_unresolved`, `stale_intent`, `invalid_request` |
| `message_key` | String | 固定本地化 key；隐藏失败统一 `action.intent_unresolved` |
| `consumed` | bool | 与 resolution 一致 |
| `timing_bucket` | String | 固定桶，不公开精确处理耗时 |

隐藏马腿/象眼、未知路径阻挡、隐藏终点占用、炮架不成立和敌相田阻挡等 `TENTATIVE` 失败，在未触发已授权接触公开点时统一为 `public_code=intent_unresolved`，字段集合、message key 与 timing bucket 必须相同。禁止 `details, raw_code, blocker_id, blocker_type, blocker_count, blocker_cell, candidate_count, rng_draws, stack, debug`。

### 5.4 ActionPreview — `veilfront-action-preview-v1`

允许字段：

`schema_version, preview_id, piece_id, action_type, target_cell, skill_type, classification, confirmation_required, public_cost, message_key`

`classification` 只能为 `KNOWN_LEGAL/TENTATIVE/KNOWN_ILLEGAL`。相同 canonical PlayerView 与公开规则配置必须生成字节等价、顺序等价的 preview 列表。Preview 不含真实合法性、隐藏阻挡原因、准确随机候选数或另一 viewer 的信息。

## 6. Replay 分级

### 6.1 AuthoritativeReplayRecord — `veilfront-authoritative-replay-v1`

允许字段：

`schema_version, rules_revision, source_commit, initial_full_state_or_seed, configuration, normalized_intents, execution_results, domain_events, state_digests, event_digests, rng_checkpoints, final_state_digest, codec_versions, audit_digest`

访问：仅 application 权威回放器、迁移 harness 和 QA 受控审计。禁止 presentation、教学、未来 endpoint、截图工具或玩家导出读取。记录包含任一 seed、FullState、raw event、RNG checkpoint 或精确错误即必须保持 authority-only。

拒绝策略：schema/规则摘要/source commit/codec 不匹配、未知字段、digest 错误、篡改或重放产生差异时整体拒绝；不得“尽量播放”。

### 6.2 ObserverReplayRecord — `veilfront-observer-replay-v1`

允许 root 字段：

`schema_version, match_id, rules_revision, viewer_side, initial_player_view, frames, final_player_view_digest, codec_versions`

每个 frame 只允许：`action_index, player_view_or_digest, visible_events, visible_error, action_previews`。frame 内容必须与该 viewer 实时收到的 DTO 字节等价；不得含 Intent 的隐藏字段、FullState、DomainEvent、DomainError、seed、RNG、raw sequence、权威 digest 或另一 viewer 的 frame。

访问：application 为已绑定 viewer 生成；presentation/教学仅能读取本 viewer 版本。修改 `viewer_side`、frame、digest 或 codec 后整体拒绝，不允许通过 ObserverReplay 请求重新投影另一视角。

## 7. 私有标记

圆/叉/方形标记属于本机表现状态：

- 存储在当前本地 profile/session 的 presentation repository，键只使用屏幕映射后的权威交点坐标和标记类型。
- 不写 FullState、PlayerView、Visible DTO、ActionPreview、任一 replay、canonical 对局摘要或未来传输。
- 不产生 domain/application Intent，不影响合法行动、视野、高亮排序或回放确定性。
- 对局退出时的保留策略属于本地偏好；无论是否保留，都不能跨席位或跨机器同步。

## 8. 可扫描依赖禁止清单

| 扫描范围 | 禁止引用/模式 |
|---|---|
| `scripts/game/domain/**` | `Node`, `Control`, `SceneTree`, `PackedScene`, `scenes/`, `/application/`, `/projection/`, `/presentation/`, `/tutorial/`, `/ports/`, `/network/`, `/ai/`, `/prototype/` |
| `scripts/game/application/**` | `scenes/`, `/presentation/`, `/tutorial/`, `/network/`, `/ai/`, `/prototype/`；公开 API 出现 `FullState` 参数/返回值 |
| `scripts/game/projection/**` | 修改 FullState；`/presentation/`, `/tutorial/`, `/network/`, `/ai/`, `/prototype/`；公开 viewer 字符串入口 |
| `scripts/game/presentation/**`、`scripts/game/tutorial/**` | `/domain/`, `/projection/`, `FullState`, `DomainEvent`, `DomainError`, `AuthoritativeReplay`, `rng_state`, `initial_flag_positions`, `full_audit` |
| 未来 endpoint adapter | 上述全部权威类型；额外禁止规则 seed、任意 viewer 参数和 raw replay |

ITERATION-1 必须建立 `tests/game/architecture/check_dependency_boundaries.gd` 或等价只读扫描器。扫描器按上述目录递归检查 preload/load、extends、类型名和公开方法签名；任一命中退出非零。人工 grep 只用于补充，不能替代正式测试。

## 9. 隐藏等价与错误外形测试设计

### 9.1 配对模型

对 viewer `v` 构造 `(F1,F2)`，只改变投影外事实；若 `PlayerView(F1,v)` 与 `PlayerView(F2,v)` canonical 字节相同，则在授权公开点之前必须同时满足：

- PlayerView 字节等价；
- ActionPreview 数组字节和顺序等价；
- VisibleEvent 前缀字节等价；
- 同一提交的 VisibleError 字段集合、public code、message key、consumed 与 timing bucket 等价；
- ObserverReplayRecord 对应 frame 字节等价。

FullState、DomainEvent 和 AuthoritativeReplay 可以不同，但不得进入断言的观察者通道。

### 9.2 必测配对

| 配对 ID | 仅允许变化的隐藏事实 | 公开前必须等价 | 允许分叉点 |
|---|---|---|---|
| `HIDDEN-FLAG-PAIR` | 未发现旗位与未来旗相关 RNG | 全部观察者 DTO | 该 viewer 合法发现旗帜 |
| `HIDDEN-HORSE-PAIR` | 迷雾/隐身马位置或马腿占用 | view/preview/event/error 外形 | 已提交行动触发授权接触或显形 |
| `HIDDEN-ELEPHANT-PAIR` | 敌方相田来源内部 ID/阻挡来源 | view/preview/event/error 外形 | 规则授权的首交点公开结果 |
| `HIDDEN-CANNON-PAIR` | 迷雾炮架 0/1/2 的真实数量 | `TENTATIVE` preview 与失败外形 | 炮击/精确吃子授权结算结果 |
| `HIDDEN-RNG-PAIR` | RNG 内部 state、未来炮击/复活抽样 | 所有观察者 DTO 与 timing bucket | 随机结果被规则公开 |
| `PRIVATE-MARKER-PAIR` | 对手本机标记或本机标记布局 | authority digest 和对方 DTO | 永不进入权威/对方通道 |

### 9.3 失败标准

以下任一项立即失败：unknown 字段被 decoder 接受；raw sequence 产生可见空洞；不同隐藏原因返回不同 code/message/字段/时序桶；presentation/tutorial 可传 viewer；ObserverReplay 包含 seed、raw event 或 authority digest；私有标记改变任一权威或 PlayerView digest。

## 10. Godot 落点

- DTO/codec：`scripts/game/contracts/`，使用无 SceneTree 生命周期的 `RefCounted`/静态 codec；运行时对局数据不写成共享 Resource。
- authority/application：`scripts/game/domain/`、`scripts/game/application/`。
- projection：`scripts/game/projection/`，内部端口由 application 组合根注入。
- 观察者消费者：`scripts/game/presentation/`、`scripts/game/tutorial/`；固定树在 `.tscn`，教学数据在 `.tres`。
- Input Map ADR：`ADR-GODOT-INPUT-001`，在 ITERATION-1 物化到 `project.godot`，禁止脚本硬编码作为唯一输入。
- 迷雾 ADR：`ADR-GODOT-FOG-001`，固定预置 `FogOverlay` Control，单一绘制层依据 PlayerView 更新；不动态生成 216 个固定 Control。棋子、旗帜、虚影与临时轨迹仍可按对局生命周期实例化 PackedScene。

## 11. 责任与回退

- DTO、codec、projection、replay 与依赖扫描：Godot 技术负责人。
- 教学只消费指定 viewer 安全 DTO：系统与体验负责人；任何隐藏事实需求返回规则/体验审查。
- 独立重检：质量与发布负责人。
- 若实现必须让表现/教学读取 raw event 或 FullState，立即停止并返回 `TASK-ARCH-001`；若因此需要改变规则/范围，升级项目经理与项目所有者。
