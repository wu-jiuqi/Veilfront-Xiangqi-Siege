# 《雾疆：九路烽棋》BGM / SFX 契约层提案 v1

状态：`draft_proposal / pending_owner_gate2_review / no_audio_production_authority`

适用版本：Godot `4.7.1`，当前二维正式表现主线，Project Brief v7，GATE-2 Contract v3。

## 1. 提案目的

本提案只冻结 BGM 与 SFX 的运行时边界、观察者安全输入、公开音频事件词表、Godot 场景资源映射和验收口径，供项目所有者检查 GATE-2 缺口。它不修改规则、不修改现有 `PlayerView` 信息边界、不批准完整音频量产，也不代表 GATE-2 已通过。

要解决的问题：

1. BGM 可以依据哪些公开状态切换，不能读取哪些隐藏事实；
2. 棋局 SFX 如何等待权威可见结果，避免把本地预览误当作结算；
3. 当前 `PlayerView / VisibleEvent / VisibleError` 如何生成可去重、可回放、观察者安全的音频提示；
4. UI、棋盘、教学、LAN 和终局需要哪些稳定 cue key；
5. Godot 中如何以预置节点和 Resource 为主完成音频组合；
6. GATE-2 当前可以审什么、还缺什么、什么必须另获批准。

## 2. 事实基线与范围边界

### 2.1 当前工程事实

- `default_bus_layout.tres` 已有 `Master / Music / SFX`。
- `SettingsManager` 已保存并应用主音量、音乐音量和音效音量。
- 正式音频文件数量为 `0`，正式场景内音频播放器节点数量为 `0`。
- 旧资产清单把对局音乐记为2条、环境声记为3条、棋子与系统音效记为18个“音效族”，尚未拆成具体 cue、变化版和触发合同。
- 正式下行顺序已冻结为 `PlayerView → VisibleEvent → VisibleError → ActionPreview → prepared_action`。
- 当前 `VisibleEvent` 主要暴露 `move_resolved / bombardment_resolved / advisor_resurrection_resolved / pass / skip / timeout` 等粗粒度结果；城墙、旗帜、显形和阵亡需要从相邻观察者快照安全推导。

### 2.2 本提案包含

- BGM状态、公开压力条件、切换和恢复策略；
- SFX逻辑事件词表、空间模式、并发、优先级和去重；
- 观察者安全的 `AudioCue v1 / AudioCueBatch v1 / MusicContext v1` 表现层合同；
- 预置场景、Resource目录、总线和播放器池方案；
- GATE-2所需自动化与人工验收；
- 初步资产数量与样片建议。

### 2.3 本提案不包含

- 音乐作曲、正式录音、采购、外包、授权签约或全量资产制作；
- 环境声完整系统；环境声应单独建立 `Ambience` 提案，不能暗中计入 BGM；
- 语音、旁白、棋子喊声或语言本地化；
- 修改 owner rule revision 5、随机消费、FullState、回放摘要和网络信任边界；
- 使用隐藏敌棋数量、隐藏旗位、未授权炮击伤亡、权威随机或敌方未提交意图驱动音乐/音效；
- 互联网重连、观战、Steam Relay 和发布级回放音频策略。

## 3. 总体边界

```text
Local UI signals ───────────────► LocalUiAudioRequest ─┐
                                                       │
Public scene/session state ─────► MusicContextPolicy ──┼─► AudioDirector
                                                       │
Previous PlayerView                                   │
Current PlayerView  ─► ObserverAudioPolicy ─► AudioCueBatch
VisibleEvent[]                                         │
VisibleError? ─────────────────────────────────────────┘

FullState / DomainEvent / RNG / hidden blocker ──X──► Audio
```

核心决定：

- `AudioDirector` 属于表现层，只播放已投影的音频命令，不判断规则。
- `ObserverAudioPolicy` 只接收当前绑定观察者的安全 DTO，不接受 `viewer_side` 参数，不读取 application/domain。
- 本地 UI 音可以立即播放；移动、吃子、炮击、破墙、占旗、献祭、胜负等棋局结算音必须等待权威观察者帧。
- 相同的观察者安全输入必须产生相同顺序、相同 cue key、相同空间模式的 `AudioCueBatch`；隐藏等价 FullState 不能造成声音差异。
- 音频变化版选择属于 cosmetic 决策，不消耗规则 RNG。v1 使用 `cue_id` 的稳定哈希选择变化版，保证重放与网络重复帧不会产生不同层数。

## 4. 表现层音频合同

这些结构是表现层内部合同，不直接加入网络协议，也不替代 `PlayerView / VisibleEvent / VisibleError`。

### 4.1 `AudioCue v1`

```text
schema_version: "veilfront-audio-cue-v1"
cue_id: String                    # 会话内唯一、可去重
cue_key: String                   # 只引用批准词表
source_kind: String               # local_ui / visible_event / view_diff / public_session
action_index: int                 # 本地UI可为-1，其余>=0
occurrence_index: int             # 同一行动内同key的稳定序号
spatial_mode: String              # global / board_2d
position_public: Array[int]       # global时必须为空；board_2d时必须是公开[x,y]
priority: String                  # low / normal / high / critical
concurrency_group: String         # 资源定义中的稳定组名
late_policy: String               # drop_if_late / play_once / sustain_state
```

硬约束：

- `board_2d` 只有在 `position_public` 已存在于当前观察者 DTO 时合法。
- 不能为了定位声音重新查询棋子、旗帜、炮击伤害格或规则状态。
- `cue_id` 推荐为 `session_public_id:action_index:cue_key:occurrence_index`；本地 UI 使用独立递增序号。
- `critical` 只允许将帅阵亡、终局和断线等必须覆盖低优先级声音的事件。
- `late_policy=drop_if_late` 用于移动、按钮、命中；终局和持续音乐状态使用 `play_once/sustain_state`。

### 4.2 `AudioCueBatch v1`

```text
schema_version: "veilfront-audio-cue-batch-v1"
session_public_id: String
frame_action_index: int
visible_event_cursor: int
cues: Array[AudioCue]
batch_digest: String
```

- `cues` 顺序固定为：结算主体 → 可见伤亡 → 状态变化 → 回合变化 → 终局。
- 重复收到相同 `batch_digest` 时不得重播。
- 客户端落后超过一个已显示 action frame 时，所有 `drop_if_late` cue 丢弃；不得在重连时集中补播历史战斗声。

### 4.3 `MusicContext v1`

```text
schema_version: "veilfront-music-context-v1"
context_revision: int
scene_phase: String       # opening / menu / level_select / settings / lobby / tutorial / match / terminal
music_key: String
intensity: String         # calm / standard / pressure
viewer_result: String     # none / victory / defeat / draw
source_action_index: int  # 无棋局时为-1
transition_mode: String   # cut / short_crossfade / long_crossfade / resume_previous
```

- `MusicContextPolicy` 输入只允许公开路由、公开 session state 和当前 `PlayerView`。
- 两个隐藏等价状态若投影出相同公开输入，必须生成字节等价的 `MusicContext`。
- `viewer_result` 只在 `PlayerView.terminal=true` 后设置。

## 5. BGM 状态合同

### 5.1 P0曲目

| music key | 使用位置 | 运行时格式 | 备注 |
|---|---|---|---|
| `bgm.frontend.main` | 主菜单、关卡目录、设置 | OGG循环 | 同一曲目跨页面保持，不因路由重启 |
| `bgm.frontend.lobby` | LAN大厅 | OGG循环 | P0可复用主菜单混音，P1再独立制作 |
| `bgm.tutorial.standard` | 教学T0–T10 | OGG循环 | 低密度，不能压过提示和棋局反馈 |
| `bgm.match.standard` | 正式对局常态 | OGG循环 | 秦鼓、低弦、陶土/金属质感为待审方向 |
| `bgm.match.pressure` | 公开终局压力 | OGG循环或同步层 | 与常态保持节拍/调性兼容 |

胜利、失败、平局使用 `sfx.match.*` 短促终局提示，不在 P0 增加三条终局循环 BGM。

### 5.2 公开状态映射

| 条件 | music key / intensity | 允许输入 |
|---|---|---|
| 开场演出 | `bgm.frontend.main / calm`，可先静音后淡入 | 正式公开路由与开场阶段 |
| 主菜单、关卡、设置 | `bgm.frontend.main / calm` | 当前公开页面 |
| LAN大厅 | `bgm.frontend.lobby / calm` | public session state |
| 教学 | `bgm.tutorial.standard / standard` | 当前公开页面/教学章节 |
| 对局常态 | `bgm.match.standard / standard` | `PlayerView.terminal=false` |
| 对局压力 | `bgm.match.pressure / pressure` | 仅下列公开压力规则 |
| 终局 | 停止压力变化，压低BGM并播放终局SFX | `PlayerView.terminal/winner` |

公开压力规则 v1：满足任一条件即进入 `pressure`；全部解除后回到 `standard`。

1. `round_limit_public - full_round_index <= 10`；
2. 当前 `PlayerView.flags` 中任一方公开已拥有旗帜数量达到2。

v1明确不使用：

- 当前可见敌棋数量、估算战力、隐藏马、炮弹余量、敌方视野；
- 未发现旗帜坐标或内部占旗者 ID；
- 炮击实际命中/伤亡数量；
- 某方即将破墙但尚未反映在公开墙状态中的内部计数；
- action preview、隐藏拒绝原因、网络包到达时差。

### 5.3 切换口径

- 页面之间复用同一 `music_key` 时不中断、不重播。
- 前端↔大厅建议 `1.0–1.5s` 短交叉淡化。
- 前端/教学↔对局建议 `2.0–3.0s` 长交叉淡化。
- 对局常态↔压力建议在音乐资源支持时使用同步切换；不支持时使用 `2.0s` 交叉淡化。
- 终局先在 `0.25s` 内把 BGM duck 到约 `-12dB`，再播放胜负 cue；禁止在权威终局到达前预演。
- 返回前端时允许 `resume_previous`；是否恢复旧播放位置由预置资源决定，不从脚本猜测。

## 6. SFX 稳定词表

### 6.1 本地交互 cue

这些 cue 不表示规则已经结算，可以由当前场景的本地 UI 信号立即触发。

| cue key | 触发 | 空间 | 优先级 |
|---|---|---|---|
| `sfx.ui.focus` | 键盘/手柄焦点进入主要控件 | global | low |
| `sfx.ui.activate` | 普通按钮激活 | global | normal |
| `sfx.ui.confirm` | 危险/最终确认按钮激活 | global | high |
| `sfx.ui.cancel` | 返回、关闭、取消准备 | global | normal |
| `sfx.ui.reject` | 公开非法、隐藏未决、教学拒绝 | global | normal |
| `sfx.ui.modal_open` | 弹窗、抽屉、暂停菜单打开 | global | low |
| `sfx.ui.modal_close` | 弹窗、抽屉、暂停菜单关闭 | global | low |
| `sfx.board.select` | 选择公开己方棋子 | board_2d或global | normal |
| `sfx.board.selection_cancel` | 取消选棋 | global | low |
| `sfx.board.preview_select` | 选择公开预览目标 | board_2d或global | low |
| `sfx.board.prepare` | 进入确认态 | global | normal |
| `sfx.board.prepare_cancel` | 取消确认态 | global | normal |
| `sfx.marker.set` | 设置圆/叉/方标记 | board_2d | low |
| `sfx.marker.clear` | 清除本地标记 | board_2d | low |

`sfx.ui.reject` 必须对 `known_illegal / intent_unresolved / stale_intent / invalid_request` 使用同一个音色族、相同时长档和非定位播放；文案可以按既有 `public_code` 区分，但音效不能增加隐藏信息。

### 6.2 权威棋局 cue

| cue key | 安全触发来源 | 空间规则 |
|---|---|---|
| `sfx.turn.local_start` | `active_side` 从对手变为当前viewer | global |
| `sfx.turn.warning` | 公开本地计时器首次越过预置阈值 | global，每回合一次 |
| `sfx.turn.timeout` | 可见 `timeout` 或权威超时结果 | global |
| `sfx.action.pass` | 可见 `pass/skip` | global |
| `sfx.move.foot` | 公开步行类棋子位置变化 | 有公开终点时board_2d，否则不播放 |
| `sfx.move.cavalry` | 公开马位置变化 | 同上 |
| `sfx.move.chariot` | 公开车位置变化 | 同上 |
| `sfx.move.cannon` | 公开炮位置变化 | 同上 |
| `sfx.capture.impact` | 新增公开阵亡且结算位置公开 | board_2d |
| `sfx.casualty.public` | 新增公开阵亡但位置不公开 | global，不表达坐标/棋种 |
| `sfx.general.destroyed` | 公开将帅阵亡/终局原因 | global，critical |
| `sfx.fog.reveal` | 当前观察者可见区域显著新增 | global或公开焦点位置 |
| `sfx.contact.unknown` | `contact_intel` 新增且身份仍未知 | global，禁止按真实身份变化 |
| `sfx.reveal.piece` | 新出现且当前DTO公开身份的敌棋 | 公开位置board_2d |
| `sfx.special.pawn_march` | 公开兵卒长距离位置变化 | 公开终点board_2d |
| `sfx.special.horse_leap` | 当前观察者可安全识别的马特殊行动 | 公开终点board_2d |
| `sfx.special.elephant_field` | 公开相田overlay新增/刷新 | 公开可见区域中心或global |
| `sfx.special.rook_charge` | 当前观察者可安全识别的车长路径行动 | 公开终点board_2d |
| `sfx.bombard.launch` | 可见 `bombardment_resolved` | global；不按隐藏炮位置定位 |
| `sfx.bombard.impact_bed` | 同一炮击固定一次复合三击 | global或已公开中心；层数固定 |
| `sfx.advisor.sacrifice` | 可见 `advisor_resurrection_resolved` | 献祭位置公开时board_2d，否则global |
| `sfx.advisor.resurrect` | 复活结果对当前观察者公开 | 复活点公开时board_2d，否则global |
| `sfx.wall.breached` | 墙状态 `INTACT→BREACHED` | global |
| `sfx.wall.repairing` | `BREACHED→REPAIRING` | global |
| `sfx.wall.repaired` | `REPAIRING→INTACT` | global |
| `sfx.wall.withdrawal` | 公开强制撤回导致公开棋子变化 | global；不逐个播放隐藏位置 |
| `sfx.flag.discovered` | `discovered false→true` | 新公开旗位可board_2d |
| `sfx.flag.capture_progress` | 公开进度增加 | 旗位公开时board_2d，否则global |
| `sfx.flag.captured` | 公开owner变化 | 旗位公开时board_2d，否则global |
| `sfx.flag.capture_cancelled` | 公开进度归零且未完成 | 旗位公开时board_2d，否则global |
| `sfx.match.victory` | terminal且viewer为winner | global，critical |
| `sfx.match.defeat` | terminal且viewer为loser | global，critical |
| `sfx.match.draw` | terminal且winner=draw | global，critical |

### 6.3 教学与LAN cue

| cue key | 公开触发 |
|---|---|
| `sfx.tutorial.hint` | 玩家请求并实际显示提示 |
| `sfx.tutorial.step_success` | 公开教学步骤完成 |
| `sfx.tutorial.chapter_complete` | 公开章节完成，棋盘结果已显示 |
| `sfx.tutorial.reset` | 步骤或章节重置成功 |
| `sfx.tutorial.assessment_failed` | 综合考核公开失败 |
| `sfx.network.peer_joined` | public session首次出现同伴 |
| `sfx.network.ready_on` | 本地或公开席位进入准备 |
| `sfx.network.ready_off` | 本地或公开席位取消准备 |
| `sfx.network.all_ready` | 双方首次同时准备完成 |
| `sfx.network.match_start` | public session进入starting/match |
| `sfx.network.disconnected` | 连接中断或同伴离开 |
| `sfx.network.error` | 公开连接/协议错误 |

连接、验证和状态刷新期间不得循环播放提示；每次实际状态边沿最多产生一个 cue。

## 7. `ObserverAudioPolicy` 推导顺序

每个完整观察者帧按以下顺序处理：

1. 校验 `session_public_id/action_index/visible_event_cursor` 单调性；
2. 从 `VisibleError` 生成统一 `sfx.ui.reject`；
3. 从 `VisibleEvent` 识别行动主体：pass、move、bombard、resurrection、timeout；
4. 比较 previous/current `PlayerView.pieces`，只对当前DTO可识别的棋子生成移动和显形 cue；
5. 比较公开 casualties/contact_intel/vision_overlays，生成可见伤亡、未知接触、相田等 cue；
6. 比较 flags/walls，生成目标和城墙状态 cue；
7. 比较 active_side/terminal，生成回合与终局 cue；
8. 排序、赋 occurrence、计算 `cue_id/batch_digest`；
9. 交给 `AudioDirector` 去重和播放。

禁止从单个当前快照推断“刚发生了什么”；必须有前后快照和当前可见事件边界。首次加入/恢复会话没有可信 previous view 时，只建立基线，不补播历史移动、阵亡、破墙或占旗声；如果当前已经 terminal，可以按 `play_once` 播放当前终局提示。

### 7.1 现有合同能支持的P0

不升级网络/observer DTO即可安全支持：

- 本地UI、选棋、准备和取消；
- 公开移动的四套基础音色；
- 公开阵亡数量变化；
- 炮击固定骨架；
- 士献祭复活；
- 城墙状态变化；
- 旗帜发现、进度和owner变化；
- 新contact、新可见棋子、回合与终局；
- 教学公开反馈和LAN公开状态。

### 7.2 需要未来 `VisibleEvent v2` 才能精确支持的内容

- 炮击三个伤害格的逐格可见命中次序；
- 车多目标路径中每次公开接触的严格先后与停点；
- 同一行动内多个公开状态变化的精确演出时间轴；
- 对未完整可见路径进行安全的空间运动声像；
- 回放中逐子事件的完全确定性音画对齐。

建议：GATE-2先批准 `ObserverAudioPolicy v1` 的安全差分方案，不在当前 v3 Contract 内升级 `VisibleEvent`。若音频样片证明精确子事件对体验必不可少，再另立 DTO 升级提案与隐藏等价测试。

## 8. Godot 4.7.1 预置节点与资源映射

### 8.1 全局音频场景

建议新增预置场景，不在事件发生时动态创建播放器：

```text
AudioRoot (Node, autoload PackedScene)
├─ MusicDirector (Node)
│  ├─ MusicA (AudioStreamPlayer, bus=Music)
│  └─ MusicB (AudioStreamPlayer, bus=Music)
├─ GlobalSfxPool (Node)
│  ├─ Ui01..Ui06 (AudioStreamPlayer, bus=SFX_UI)
│  └─ System01..System04 (AudioStreamPlayer, bus=SFX_System)
└─ AudioCueDeduplicator (Node)
```

棋盘定位音留在棋盘世界，避免 Autoload 中的2D播放器脱离 Board Camera：

```text
BoardWorld
└─ BoardAudioEmitterPool (Node2D, preset scene)
   └─ Board01..Board08 (AudioStreamPlayer2D, bus=SFX_Board)
```

- `BoardAudioEmitterPool` 只接受已经生成的 `AudioCue(position_public)`，再调用既有坐标映射；它不能读取 `PlayerView` 或寻找棋子节点。
- 初始 `max_polyphony`/池大小是预算值，需由炮击、车多目标和UI连点压力测试校准。
- Godot 4.7.1 的2D播放器 `area_mask` 默认0；v1不使用Area音频总线覆盖。如未来启用Area override，必须在预置节点显式设置mask并加迁移测试。

### 8.2 Resource合同

建议路径：

```text
resources/game/audio/
├─ music_catalog.tres
├─ sfx_catalog.tres
├─ music/
│  └─ *.tres
└─ sfx/
   └─ *.tres
```

`AudioCueDefinition` 只允许表现字段：

```text
cue_key
streams[]
bus
volume_db_min / volume_db_max
pitch_scale_min / pitch_scale_max
priority
concurrency_group
max_instances
cooldown_ms
spatial_modes_allowed[]
```

禁止字段：FullState路径、规则条件、旗位、隐藏棋子、伤害真值、viewer选择、规则seed或RNG引用。

`MusicStateDefinition` 只允许：

```text
music_key
stream
loop_enabled
default_volume_db
crossfade_seconds
resume_policy
```

### 8.3 总线

```text
Master
├─ Music
└─ SFX
   ├─ SFX_UI
   ├─ SFX_Board
   └─ SFX_System
```

- 设置页继续只显示“音乐/音效”，`SFX_UI/SFX_Board/SFX_System` 都由 `SFX` 父总线控制。
- Master可加Limiter防止炮击和终局叠层削波；是否启用及参数需样片响度测试后冻结。
- v1不新增玩家可见“环境音”滑杆；环境声另案决定是进入SFX父总线还是新增Ambience设置。

## 9. 音频文件规格

### 9.1 BGM

- 制作母版：48kHz、24-bit WAV、立体声；
- 运行时：OGG Vorbis，建议quality 6–8；
- 必须记录循环起止、BPM和拍号；循环点无爆音、无明显节拍跳变；
- 建议暂定响度范围 `-18 ± 2 LUFS-I`，true peak不高于 `-1 dBTP`，最终以游戏内混音复核为准；
- 文件名：`bgm_<context>_<state>_loop_v01.ogg`。

### 9.2 SFX

- 制作母版：48kHz、24-bit WAV；
- 运行时短SFX：48kHz、16-bit PCM WAV；
- 需要棋盘2D定位的文件导入为mono；UI/系统音使用非定位播放器；
- 文件首尾保留2–5ms安全淡化，禁止DC offset、爆音和MP3编码前置空白；
- 高频事件至少2个变化版；核心移动/冲击建议3个变化版；
- 文件名：`sfx_<family>_<event>_<variant-02>.wav`。

### 9.3 授权与元数据

每个正式音频必须记录来源、作者/供应商、许可证、可商用范围、是否允许修改、采购凭证位置和署名要求。无法证明Steam商业发布权限的资产只能作为本地样片，不得进入发布构建。

## 10. 并发、优先级与混音护栏

初始建议，需样片实测：

| 组 | 同时上限 | 策略 |
|---|---:|---|
| UI focus | 1 | 30–50ms cooldown，旧音可截断 |
| UI action | 2 | confirm高于普通activate |
| board move | 3 | 同一棋子/同一行动只保留一个主体移动音 |
| impact/casualty | 4 | 车多目标和炮击使用节奏化合并，禁止无限叠层 |
| bombard | 1组 | 固定复合骨架，不按隐藏命中追加层 |
| wall/flag/system | 2 | critical终局可以压低其他组 |
| tutorial/network | 1 | 同类状态边沿去抖 |

- 终局到达后停止新移动/命中cue，完成当前critical cue后清空低优先队列。
- BGM pressure切换、炮击、破墙和终局不能在同一瞬间都以满响度播放；由固定duck规则维持可读性。
- `reduce_motion` 不自动关闭声音；如未来提供“减少强烈反馈”，必须是独立可访问性设置，不复用视觉开关。

## 11. 验收合同

### 11.1 自动化

1. **依赖扫描**：audio/presentation脚本不得preload或调用domain、FullState、RNG、AuthoritativeReplay。
2. **隐藏等价**：两份不同FullState投影成相同 observer frame 时，`AudioCueBatch`和`MusicContext`字节等价。
3. **拒绝等价**：四种 `VisibleError.public_code` 使用相同 `sfx.ui.reject`、global空间和timing bucket。
4. **未发现旗位**：进度可公开但位置为空时，只生成global旗帜cue，不出现board_2d坐标。
5. **炮击不泄露**：隐藏伤亡数量不同但观察者DTO相同时，炮击cue数量、层级和位置完全一致。
6. **不可乐观结算**：ActionPreview/prepare/cancel只能产生本地交互cue，不产生move/capture/bombard/wall/flag/terminal cue。
7. **去重**：相同batch重复投递、网络重发或UI重复render不重播。
8. **首次基线**：无previous view时不补播历史战斗声；当前terminal只播放一次终局cue。
9. **BGM公开压力**：仅round余量和公开旗帜owner影响pressure；隐藏棋子/炮击/旗位变化不能影响music context。
10. **场景加载**：AudioRoot、BoardAudioEmitterPool、正式前端、对局和教学场景可在Godot 4.7.1 headless加载。
11. **总线设置**：现有Music/SFX滑杆继续正确控制新增子总线，0值静音且无`-inf`异常传播。
12. **资源合法性**：cue key唯一，路径存在，总线存在，变化版数量、格式、mono要求和许可证元数据通过校验。

### 11.2 人工审听

- 960×540、1280×720、1920×1080下以红黑两席分别走完整教学代表流程和LAN对局。
- 连续移动、车多目标、炮击、破墙、占旗、献祭、终局叠加时不削波、不掩盖关键提示。
- 低音量下仍能区分确认、拒绝、回合、炮击、破墙、旗帜和终局。
- 盲听不能从未知接触/隐藏失败音推断棋种、位置或内部原因。
- BGM常态/压力转换不突兀、不因页面切换重启，不压过教学文字操作节奏。
- 两台实体机器验证同一公开结果的cue顺序一致，隐藏信息差异不造成额外声音。

## 12. 初步资产量与分期

### 12.1 P0代表样片包（若获得单独范围例外）

建议只做12个方向样片，不等于完整音频：

1. 前端BGM循环1条；
2. 对局常态/压力兼容片段各1条；
3. UI确认/取消/统一拒绝3个；
4. 步行/马/车/炮移动各1组；
5. 吃子/阵亡1组；
6. 炮击复合骨架1组；
7. 破墙/修复1组；
8. 旗帜发现/进度/完成1组；
9. 献祭/复活1组；
10. 未知接触1个；
11. 教学步骤成功/章节完成1组；
12. 胜利/失败1组。

上述“组”允许2–3个极少量变化文件，总文件量应在另批的样片预算中明确，不得自动扩张为全量生产。

### 12.2 完整Demo初估

- BGM：P0为4个独立循环状态，前端大厅可暂复用；目标版5–6条/层。
- SFX：约32个P0逻辑提示；完整Demo约50–60个逻辑提示。
- 含变化版后的短WAV：初估约70–90个。
- 环境声、语音、旁白不计入上述数字。

这些数字只用于 GATE-2 后的成本评估，不构成人力、预算或周期承诺。

## 13. GATE-2 问题映射

### 13.1 当前 Contract v3 已覆盖但证据不足

- `CHECK-INFORMATION-2D-001` 已要求音效不得泄露隐藏信息，但没有音频事件词表、差分规则和隐藏等价音频测试。
- `CHECK-ART-2D-001` 已要求资产清单覆盖音频，但当前二维清单没有具体BGM/SFX数量、依赖、样片和验收字段。
- Project Brief v7 要求首版Demo包含完整音频，但 Contract v3 把完整音频列为范围外；这意味着 GATE-2 只能判断“是否值得进入后续音频生产”，不能把“音频已经完成”作为本轮事实。

### 13.2 需要项目所有者在 GATE-2 明确的决定

1. 是否接受本提案作为后续音频生产的契约基线，而不是当前完成证据；
2. GATE-2前是否允许12组代表音频样片。若允许，必须另立精确范围例外；
3. 是否批准BGM的5个P0状态，以及pressure只由公开回合余量/公开两旗状态驱动；
4. 是否接受“约32个P0 cue、50–60个完整逻辑cue、70–90个变化文件”的估算口径；
5. 是否继续采用秦鼓、低弦、陶土/金属战争质感作为正式音频方向；
6. 旗帜进度在旗位未发现时是否播放居中非定位提示，还是只显示文字；
7. 环境声是否另立Ambience合同，以及玩家设置中是否需要独立环境音滑杆；
8. 当前GATE-2通过后，是先启动音频子循环，还是与VFX/动画共同进入下一生产循环。

### 13.3 推荐裁决

- 当前 GATE-2：接受契约提案和资产估算作为“后续可生产性输入”，不宣称音频完成。
- 样片：只有项目所有者希望在GATE-2判断音频风格时，才另批12组以内的精确例外。
- 全量：GATE-2通过后创建独立音频生产Contract，绑定资产表、预算、授权、实现、混音和独立QA。
- DTO：先采用现有observer DTO的安全差分策略；`VisibleEvent v2` 延后到样片证明必要时再立项。

## 14. 后续落地顺序

1. 项目所有者审查本提案与GATE-2问题；
2. 系统体验负责人确认声音语义、教学反馈和旗帜未发现方策略；
3. 技术负责人确认 `ObserverAudioPolicy`、预置AudioRoot、BoardAudioEmitterPool和测试边界；
4. 视觉/音频制作责任确认声音风格、样片规格、授权与成本；
5. QA先写隐藏等价、拒绝等价、炮击不泄露和去重合同；
6. 若有样片例外，只制作批准的代表样片并进行游戏内审听；
7. GATE-2通过后另立完整音频生产Contract，不直接把本提案当执行授权。

## 15. 关联事实源

- `game-pipeline/project-definition/project-brief.yaml`
- `game-pipeline/loops/contracts/loop-contract-formal-foundation-gate2-v3.yaml`
- `docs/godot-prompter/specs/formal-runtime-interface-and-signal-map-v1.md`
- `docs/godot-prompter/specs/formal-godot-scene-composition-v1.md`
- `docs/architecture/formal-dto-and-trust-boundary-v1.md`
- `docs/art/demo-asset-inventory-v1.yaml`
- `docs/art/demo-2d-asset-inventory-v1.yaml`
- `docs/art/veilfront-visual-baseline-v1.md`
- `docs/design/tutorial/veilfront-ftue-dual-track-complete-design-v1.md`
- `scripts/game/contracts/player_view_codec.gd`
- `scripts/game/contracts/visible_event_codec.gd`
- `scripts/game/contracts/visible_error_codec.gd`
- `scripts/game/projection/visible_outcome_projector.gd`
- `default_bus_layout.tres`
- `scripts/game/settings/settings_manager.gd`
