# 《雾疆：九路烽棋》观察者安全 AudioCue 合同 v1

状态：`technical_producer_freeze / pending_registry_registration_and_independent_QA`

适用范围：GATE-3 `TASK-CUE-CONTRACT-G3-001` 的共享 Cue 技术合同部分，以及 `TASK-SFX-G3-001`。本文件冻结生产者接口，不代表 GATE-3 人工内容冻结已经通过。

## 1. 执行顺序与边界

本轮严格按“共享 Cue v1 先冻结，正式资产后接入”执行：

1. 先冻结公开输入、共享字段、顺序、位置、去重与隐藏等价规则；
2. 再实现 `ObserverAudioPolicy`、Catalog、预置播放器池和总线；
3. 最后生成并登记项目原创 WAV，执行导入与自动检查；
4. 独立 QA 与人工审听仍由后续 Gate 流程完成。

音频层只允许消费当前席位已经收到的 `PlayerView v1`、`VisibleEvent v1`、`VisibleError v1`、公开 session state 和本地 UI 信号。禁止导入或查询 `FullState`、`DomainEvent`、权威回放、隐藏位置、隐藏伤亡、规则 seed 或规则 RNG。音色变化只由 `cue_id` 稳定哈希选择，不消耗规则随机数。

## 2. AudioCue v1

Schema：`veilfront-audio-cue-v1`

| 字段 | 类型 | 约束 |
|---|---|---|
| `schema_version` | String | 固定 Schema |
| `cue_id` | String | 会话内唯一、可去重；权威帧为 `session:frame_action:key:occurrence`，不推进 action 的拒绝追加公开 intent 摘要 |
| `cue_key` | String | 必须存在于 `sfx_catalog.tres` |
| `source_kind` | String | `local_interaction / visible_event / visible_error / view_diff` |
| `action_index` | int | 观察者帧不小于 0；本地 UI 可为 -1 |
| `occurrence_index` | int | 同一批次内按相同 `cue_key` 从 0 计数 |
| `spatial_mode` | String | `global / board_2d` |
| `position_public` | Array[int] | `board_2d` 时必须为 DTO 已公开的 `[x,y]`；global 时为空 |
| `priority` | String | `low / normal / high / critical` |
| `concurrency_group` | String | 必须与 Catalog 定义一致 |
| `late_policy` | String | `drop_if_late / play_once / sustain_state` |

VFX v1 与 Audio v1 共享上述 11 个字段、source kind 枚举、0 基 occurrence、global/board_2d 语义和优先级语义。VFX 可附加 `actor_side_public` 与 `motion_profile`；这些不是 Audio 字段。Audio 不因 `reduce_motion` 自动静音或改变 cue，避免把视觉可访问性开关错误复用于声音。

`cue_id` 是媒体内部实现：Audio 使用可读稳定 ID，VFX 使用摘要式 ID。两者不要求字节相同，但必须对相同公开输入确定、可抗重发，且不得含隐藏事实。

## 3. AudioCueBatch v1

Schema：`veilfront-audio-cue-batch-v1`

```text
schema_version
session_public_id
frame_action_index
visible_event_cursor
cues[]
batch_digest
```

一个完整观察者帧内的稳定顺序为：

1. 公开结算主体：pass/timeout/bombard/advisor；
2. 当前 DTO 可见的移动、显形与伤亡；
3. 公开状态变化：雾、接触、相田、墙、旗；
4. 回合变化；
5. 终局。

本地 selection/prepare/modal 等 `local_interaction` 独立即时提交，不伪装为权威结算。`batch_digest` 对不含自身的规范 JSON 计算 SHA-256；重复 batch 或 cue 均拒绝重播。首次进入/恢复只有当前快照时只建立基线，不补播历史战斗声；若当前已经 terminal，只产生一次终局 cue。

## 4. 观察者安全推导

- `VisibleError` 的四个公开代码统一生成同一个 global `sfx.ui.reject`；音频不表达原因差异。
- 移动只比较前后 `PlayerView.pieces` 中同 ID、当前仍公开且终点公开的记录；不能寻找棋子节点补坐标。
- 新伤亡只有匹配当前公开 `capture_ghosts` 时才使用 board_2d；否则降为 global `sfx.casualty.public`。
- 未发现旗帜即使进度公开，位置为空时也只能 global 播放。
- 炮击固定为 launch + impact_bed 两个 global cue；隐藏命中格和伤亡数不增加层数。
- 未知接触即使 DTO 含公开 cell，v1 仍保守使用 global，避免声音成为额外定位器。
- 墙体音 v1 使用 global，不从规则状态或棋盘节点猜测线段。
- 终局到达后由 critical cue 抢占低/普通 global 播放器；Master Limiter 作为削波安全网。

若 `match_id/viewer_side` 改变，或 action/cursor 回退，投影失败关闭并要求上层 `reset_session()`，不得跨席位复用基线。

## 5. Godot 4.7.1 物化

| 合同产物 | Godot 路径/类型 |
|---|---|
| AudioCue 投影 | `scripts/game/audio/observer_audio_policy.gd` / `RefCounted` |
| Cue Definition | `scripts/game/audio/audio_cue_definition.gd` / `Resource` |
| SFX Catalog | `resources/game/audio/sfx_catalog.tres` / 42 个 cue key |
| 全局播放器池 | `scenes/game/audio/audio_root.tscn` / 4 UI + 4 System 预置播放器 |
| 棋盘播放器池 | `scenes/game/audio/board_audio_emitter_pool.tscn` / 8 个预置 `AudioStreamPlayer2D` |
| 去重器 | AudioRoot 内预置 `AudioCueDeduplicator` 节点 |
| 总线 | `default_bus_layout.tres` / Master→Music、Master→SFX→三子总线 |
| 原创源 | `assets/audio/sfx/*.wav` / 31 个 48 kHz、16-bit、mono WAV |

固定节点全部预置为 `.tscn`；运行时只选择已有播放器和播放流，不动态创建播放器。Board pool 只接收已经投影的 `AudioCue(position_public)`，使用已有 `BoardCoordinateMapper` 映射，不读取 PlayerView 或棋子节点。

## 6. 运行时 API 与接入点

`AudioRoot` 提供：

- `consume_player_view(view)` → 缓存当前安全视图；
- `consume_visible_events(events)` → 用缓存视图形成完整 frame 并提交；
- `consume_visible_error(error)` → 分信号端口的统一拒绝适配；
- `process_observer_frame(current_view, visible_events, visible_error={})` → 推荐的完整帧 API；
- `play_local_cue(cue_key, position_public=[], session_public_id="local")`；
- `register_board_emitter(pool)` / `unregister_board_emitter(pool)`；
- `reset_session()`。

现有正式端口按 `PlayerView → VisibleEvent → VisibleError` 发射，因此兼容 `consume_*`。最终共享场景接入需要由组合根完成：

1. 将 `audio_root.tscn` 作为唯一全局 AudioRoot 实例（可由组合根或 Autoload PackedScene 持有）；
2. 将 `board_audio_emitter_pool.tscn` 实例化到主 BoardWorld 的 EffectLayer 附近，使 2D 声像跟随 Board Camera；
3. 将 ApplicationHost 三个公开信号连接到 AudioRoot 的三个 `consume_*`；
4. 棋盘翻面时用当前公开 presentation side 调 `BoardAudioEmitterPool.set_presentation_side()`；
5. UI 控件只调用 `play_local_cue`，不能播放 move/capture/bombard/wall/flag/terminal。

本轮生产者文件所有权不包含 `project.godot`、现有 app/tutorial/LAN 组合根与 BoardWorld，因此这些共享接线留给根技术负责人统一整合，避免与 VFX 并行修改冲突。未完成该接线前，不得宣称主流程已经可听。

## 7. 混音与设置

总线路由：`SFX_UI / SFX_Board / SFX_System → SFX → Master`。现有 `SettingsManager` 继续只操作 `Master / Music / SFX`，所以新增子总线自动受原有 SFX 滑杆和 0 值静音控制。Master 预置 ceiling `-1 dB`、threshold `-6 dB` 的 Limiter 作为安全护栏；它不能替代后续人工响度和削波审听。

Catalog 定义 `max_instances` 与 `cooldown_ms`；AudioRoot 记录实际 concurrency group，不按 priority 字段误计组。炮击两层上限 2，board move 上限 3，impact 上限 4，wall/flag 上限 2，terminal 上限 1。旗帜完成 cue 会覆盖同帧较低价值的进度 tick，避免挤占完成提示。

## 8. 验收与仍需人工项

自动检查覆盖：隐藏等价、拒绝等价、未发现旗帜、炮击固定层、首次基线、回退 fail-closed、排序、Catalog、WAV 规格、预置池、去重、并发、总线、父总线设置和依赖扫描。

仍需后续独立 QA / 人工审听：

- 真实 Windows 声卡下的削波、响度、声像和长流程疲劳度；
- 红黑两席完整教学与 LAN 对局；
- 主流程共享场景接线后的端到端时序；
- 与 VFX 的主观音画节奏调优。

## 9. 关联

- `docs/audio/veilfront-bgm-sfx-contract-proposal-v1.md`（保留的历史提案）
- `docs/audio/sfx-source-license-register-v1.md`
- `docs/vfx/observer-safe-vfx-cue-contract-v1.md`
- `tests/game/audio/run_observer_audio_policy_contract.gd`
- `tests/game/audio/run_audio_runtime_contract.gd`
