# GATE-3 SFX 生产者交接 v1

状态：`producer_candidate / Loop iteration 1 foundation not yet advanced`

## 结果

已完成 AudioCue v1 技术生产者基线、31 个原创 SFX WAV、42 个 Catalog cue key、AudioRoot 与 BoardAudioEmitterPool 预置场景、三条 SFX 子总线、去重/并发/稳定变化和自动检查。没有制作 BGM、语音或环境声，没有外部支出。

## 关键决定

- 只消费观察者 DTO 和本地交互，不读规则层。
- shared Cue 的 11 个字段、顺序、位置语义与 VFX v1 对齐；VFX 的 motion profile 不进入 Audio。
- 炮击固定两层且 global；未知接触、未发现旗帜与墙体音均使用保守非定位策略。
- 31 个 WAV 全部项目内程序合成并记录 recipe/seed/hash，Godot 按 PCM 导入。
- 固定播放器全部预置；不在事件时动态创建节点。

## 产物

- 合同：`docs/audio/observer-safe-audio-cue-contract-v1.md`
- 来源：`docs/audio/sfx-source-license-register-v1.md`
- 生成器：`docs/audio/generate_original_sfx_v1.ps1`
- WAV：`assets/audio/sfx/`
- Catalog：`resources/game/audio/sfx_catalog.tres`
- 预置：`scenes/game/audio/audio_root.tscn`、`board_audio_emitter_pool.tscn`
- 运行时：`scripts/game/audio/`
- 总线：`default_bus_layout.tres`
- 自动检查：`tests/game/audio/`

## 共享接入未完成项

由于本生产者任务的文件责任范围不包含现有组合根，以下接线必须由根技术负责人统一完成后再做端到端验收：

- 全局唯一 AudioRoot 实例；
- game_app / tutorial / LAN 的三类 observer 信号连接；
- BoardWorld 内 BoardAudioEmitterPool 实例与 presentation side 同步；
- UI 的 local cue 连接。

这不是规则或合同阻塞，预置 API 已就绪；但未接线前不能宣称主流程音效已实际播放。

## 复检命令

```powershell
& 'D:\Godot\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/game/audio/run_observer_audio_policy_contract.gd
& 'D:\Godot\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/game/audio/run_audio_runtime_contract.gd
& 'D:\Godot\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/game/settings/run_settings_manager_contract.gd
```

## 风险与 QA 返回路径

- 31 个音色是零成本原创生产基线，不等于最终审美批准；不满意返回 `TASK-SFX-G3-001` 调音，不修改规则语义。
- Limiter 是保护，不是响度证明；真实声卡人工审听和削波采样仍需 QA。
- 当前 `VisibleEvent v1` 粒度不足以安全表达炮击逐格、车多目标接触顺序；保持固定骨架，不升级 DTO。
- GATE-3 最终冻结、Steam 发布与独立 QA 均未由本交付自动批准。
