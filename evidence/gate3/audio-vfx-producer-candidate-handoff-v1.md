# GATE-3 SFX / VFX 并行生产候选交接 v1

日期：2026-08-24（Asia/Shanghai）

状态：`producer_candidates_verified / shared_scene_mount_blocked_by_iteration_dependency`

## 问题

项目所有者要求启动 SFX 接入，并允许使用开源或项目内自制资产，同时与 VFX 并行协调。当前 GATE-3 Contract 要求先完成迭代 1 的预算、公开 Cue 与 UI 动效基础，再进入内容生产和统一集成。

## 结论

- 选择项目内原创路线，外部素材、订阅、采购和支出均为零。
- AudioCue v1 与 VfxCue v1 已按 11 个共享字段、来源枚举、公开位置、同 key occurrence、固定顺序和隐藏等价语义对齐。
- SFX producer candidate 已完成：42 个 cue key、31 个可复现原创 WAV、8 个棋盘声源、8 个全局播放器、三条 SFX 子总线和 Master Limiter。
- VFX producer candidate 已完成：选中、移动、吃子、炮击、城墙、旗帜、终局七族；9 个棋盘槽、3 个 global 槽；标准/减少动态峰值为 95/100 与 34/56 points。
- 候选包当前未挂到 `MatchScreen` 或 `BoardWorld`，正式对局主流程仍不可宣称可听或可见。

## 关键理由与决定

1. 所有运行时推导仅接受 `PlayerView / VisibleEvent / VisibleError / local_interaction`，禁止读取 FullState、隐藏节点、规则 RNG 或权威回放。
2. 固定池均使用预置 Godot 场景，事件发生时不动态创建播放器或特效节点。
3. 未发现旗位和未知接触保持 global；炮击在现有 DTO 下使用固定公开骨架，不从隐藏命中补位置或层数。
4. `reduce_motion` 只改变 VFX 表现预算，不改变 cue identity、SFX 或规则状态。
5. 复核时修复了 SFX 并发组计数错误，以及 VFX review batch 的 occurrence 校验/空白截图问题。
6. 共享场景挂载曾在本地草拟，但发现 GATE-3 仍处于迭代 1 且 `TASK-UI-FOUNDATION-G3-001` 未完成后已完整撤回，避免越过 Contract 依赖。

## 自动复核

- `OBSERVER_AUDIO_POLICY_CONTRACT_PASS checks=30 schema=v1`
- `AUDIO_RUNTIME_CONTRACT_PASS checks=299 cues=42 wav=31 pools=8+8`（根复核追加 session reset 停播覆盖）
- `VFX_CUE_CONTRACT_PASS cues=7 families=7 shared_fields=11 hidden_equivalence=true`
- `VFX_SCENE_SMOKE_PASS pool=9+3 peak_standard=95 peak_reduced=34 dedup=true reduced_motion=true gl_compatibility=true`
- `SETTINGS_MANAGER_CONTRACT_PASS`
- `WAV_SIGNAL_SCAN_PASS files=31 max_peak=0.745361 max_dc=0.003426`（仅证明源 WAV 无样本削波，不替代混音/声卡验收）
- `FORMAL_ARCHITECTURE_CHECKS_PASSED self_tests=19 scanned_files=201`
- `FORMAL_SCENE_SMOKE_PASS roots=3 components=19 inputs=11`
- `git diff --check` 通过。

## 后续行动

1. 完成并登记 `TASK-UI-FOUNDATION-G3-001`，由 Loop owner 复核迭代 1 的预算、Cue 与 UI 基础齐备。
2. 合法迁移至迭代 2 后，把当前 SFX/VFX 从 producer candidate 登记为内容生产交付物。
3. 进入迭代 3 时，由 Godot 技术负责人统一挂载：屏幕级唯一 `AudioRoot`、`BoardAudioEmitterPool`、`VfxRoot` 和 observer-frame coordinator。
4. 挂载后补做本地/教程/LAN/挑战四路径、红黑镜像、双席长局、音画高峰 P99、实体声卡削波与人工审美验收。

## 未解决问题

- 31 个音色与七族视觉只达到生产候选质量，尚无项目所有者最终听感/审美批准。
- Limiter 存在不等于已证明实体输出无削波。
- Intel Iris Xe 上的正式对局音画并发 60 FPS / P99 16.7ms 尚待集成后独立 QA。
- 当前 Loop 必须保持 `active / iteration=1`，不能把候选资产解释为 GATE-3 已完成。

## 关联项目文件

- `docs/audio/gate3-sfx-producer-handoff-v1.md`
- `docs/audio/observer-safe-audio-cue-contract-v1.md`
- `docs/audio/sfx-source-license-register-v1.md`
- `evidence/gate3/audio/sfx-producer-validation-v1.md`
- `evidence/gate3/vfx/vfx-producer-handoff-v1.md`
- `evidence/gate3/vfx/vfx-review-1280x720.png`
- `game-pipeline/loops/contracts/loop-contract-content-integration-gate3-v1.yaml`
