# GATE-3 SFX 生产者验证证据 v1

日期：2026-08-24（Asia/Shanghai）

引擎：Godot `4.7.1.stable.official.a13da4feb`，renderer `gl_compatibility`。

状态：生产者验证通过；待共享场景接线、独立 QA 与人工审听。当前 Loop 仍处于 iteration 1，本证据不推进 Registry 状态，也不批准 GATE-3。

## 自动检查结果

| 检查 | 结果 |
|---|---|
| `run_observer_audio_policy_contract.gd` | `PASS checks=30 schema=v1` |
| `run_audio_runtime_contract.gd` | `PASS checks=291 cues=42 wav=31 pools=8+8` |
| `run_settings_manager_contract.gd` | `PASS audio=3`，原 Master/Music/SFX 设置合同保持 |
| `run_formal_scene_smoke.gd` | `PASS roots=3 components=19 inputs=11` |
| 项目实例预检 | `state=normal`，无 errors/warnings |
| `git diff --check` | 通过，无空白错误 |
| WAV 来源哈希 | `wav=31 zero=0 failures=0 bytes=1409696` |
| Audio/VFX 共享字段交叉检查 | `fields=11 audio_missing=0 vfx_missing=0` |
| Audio 依赖边界扫描 | `files=6 forbidden_hits=0` |

## 关键覆盖

- 首次基线不补播，terminal 基线只播一次；
- 四类 VisibleError 音频字节等价；
- 未发现旗帜不产生 board_2d 坐标；
- 炮击无论隐藏命中/伤亡真值都固定两层、global；
- action/cursor 回退 fail-closed；
- 公开状态→终局顺序稳定；
- Catalog 42 个 cue key、至少 12 个逻辑族；
- 31 个源文件均 48 kHz、16-bit PCM、mono；
- 4 UI + 4 System + 8 Board 播放器均为场景预置；
- batch/cue 去重与 UI action max_instances 并发上限有效；
- `SFX_UI / SFX_Board / SFX_System` 均发送到 `SFX`，Master Limiter 已预置；
- 所有运行时文件均不导入 domain、FullState codec、seeded random 或 authoritative replay。

## 未覆盖/不得误读

- 没有完成现有 app/tutorial/LAN/BoardWorld 的共享组合根接线；
- 没有执行实体声卡、双机器、红黑双席人工审听；
- 没有把 Limiter 存在解释为“已证明无削波”；
- 没有生产 BGM、语音、环境声或引入外部付费来源；
- 没有独立 QA 或项目所有者 GATE-3 批准。

接入与风险见 `docs/audio/gate3-sfx-producer-handoff-v1.md`。
