# GATE-3 SFX / VFX 正式主线接入证据 v1

日期：2026-08-24（Asia/Shanghai）

冻结提交：`1dd8e09`（核心接入 `1b11ce3`，发布白名单 `991d26d`）

状态：`producer_integrated / iteration_2_active / independent_qa_pending`

## 结论

- SFX 与 VFX 已同时接入本地/教学 `MatchScreen` 和 LAN `OnlineMatchScreen` 的正式对局主线。
- 每个正式对局屏幕只有一个 `MatchFeedbackCoordinator` 与一个屏幕级 `AudioRoot`；主棋盘 `BoardSubViewport` 内只有一个预置 `BoardFeedbackLayer`，其中包含 `BoardAudioEmitterPool` 与 `VfxRoot`。
- 小地图继续只复用 `BoardWorld`，不实例化反馈层，因此不会重复播放音效或特效。
- 本轮仍处于 GATE-3 Iteration 2；只登记 Audio/VFX 为 producer integrated，不推进 Iteration 3，不宣称 UIUX、内容、独立 QA 或 GATE-3 完成。

## 观察者安全与时序

- 协调器只消费 `PlayerView`、`VisibleEvent`、`VisibleError` 和本地公开交互坐标，不读取 `FullState`、隐藏行动、隐藏目标、规则 RNG 或权威回放内部状态。
- Audio 与 VFX policy 必须对同一帧都验证成功，协调器才原子推进公开帧游标；`match_id`、观察方或时间线回退时先清空旧 session，避免跨局串播。
- 同一公开事件 occurrence 只触发一次；回放同一帧不会补播。超时只由可见事件产生，删除本地重复 timeout cue。
- 红黑镜像和棋盘 cell size 同步到空间音频与棋盘特效；reduced motion 只降低 VFX 表现预算，不改变 cue identity 或 SFX。

## 预置场景接入

- `scenes/game/presentation/match_feedback_coordinator.tscn`
- `scenes/game/presentation/board_feedback_layer.tscn`
- `scenes/game/audio/audio_root.tscn`
- `scenes/game/audio/board_audio_emitter_pool.tscn`
- `scenes/game/vfx/vfx_root.tscn`
- `scenes/game/match/match_screen.tscn`
- `scenes/game/match/online_match_screen.tscn`
- `scenes/game/match/board/board_viewport.tscn`

## 自动验证

- `MATCH_FEEDBACK_INTEGRATION_CONTRACT_PASS screens=2 audio_observer=true vfx_observer=true local_selection=true minimap_isolation=true reset=true`
- `BOARD_FEEDBACK_LAYER_CONTRACT_PASS audio_pool=8 vfx_pool=9+3 side_sync=true cell_size_sync=true minimap_isolation=true`
- `BOARD_CAMERA_LAYER_CONTRACT_PASS`
- `FORMAL_SCENE_SMOKE_PASS roots=3 components=24 inputs=11`
- `FORMAL_ARCHITECTURE_CHECKS_PASSED self_tests=19 scanned_files=208`
- `AUDIO_RUNTIME_CONTRACT_PASS checks=299 cues=42 wav=31 pools=8+8`
- `VFX_SCENE_SMOKE_PASS pool=9+3 peak_standard=95 peak_reduced=34 dedup=true reduced_motion=true gl_compatibility=true`
- `FORMAL_LAN_FULL_STACK_LOOPBACK_PASS ux=ready-start-match-submit-disconnect`
- 隔离构建性能：`selection_p99_ms=0.865 confirmation_p99_ms=9.111 fog_cache_p99_ms=0.052`，均低于 16.7 ms。
- Windows 候选：`WINDOWS_RUNTIME_CANDIDATE_PASS`；`WINDOWS_LAN_EXPORT_VERIFY_PASS frames=120`。
- 预算：`exe_bytes=206708888 exe_headroom_bytes=113291112 pack_zip_bytes=96473614 pack_expanded_bytes=97573705 texture_bytes=56068436 font_bytes=39230269 entries=553`。

## 独立代码复核后的修订

1. 删除本地 timeout 音效，只保留观察者可见 timeout 事件，避免同一事实双播。
2. 在 match/viewer 切换与时间线回退时重置协调器，并让 Audio/VFX policy 共同通过后再推进帧游标，避免两条线状态分叉。
3. 炮击集成测试改为非终局、无伤亡的最小帧，精确断言两条 SFX、一条 VFX，并断言重放零新增，消除终局 cue 带来的假阳性。
4. LAN 全栈退出时显式断线、释放两个应用根并等待两帧，消除音画资源异步清理警告。

## 来源与许可

- 31 个 WAV 与 VFX 几何源均为项目内原创、可复现资产；外部素材、采购、订阅与支出为零。
- 来源与分发登记：`docs/audio/sfx-source-license-register-v1.md`。

## 保留项

- 仍需项目所有者人工审听与视觉审美确认。
- 仍需 QA 在 Intel Iris Xe 目标机独立复现音画高峰、实体声卡削波、长局与双机 LAN；当前自动构建不替代独立 QA。
- `TASK-UIUX-G3-001` 与 `TASK-CONTENT-G3-001` 尚未完成，不能推进 Iteration 3 或提交 GATE-3。

## 关联证据

- `evidence/gate3/audio-vfx-producer-candidate-handoff-v1.md`
- `evidence/gate3/audio/sfx-producer-validation-v1.md`
- `evidence/gate3/vfx/vfx-producer-handoff-v1.md`
- `evidence/gate3/iteration1-foundation-handoff-v1.md`

