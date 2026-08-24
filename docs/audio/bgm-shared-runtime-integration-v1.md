# 共用常态 BGM 运行时接入 v1

## 决定

- 按项目所有者 2026-08-24 的指示，`bgm_match_standard_loop_v01` 作为当前共用 BGM。
- `res://scenes/game/frontend/start_screen.tscn`（开场与开始菜单）保持静音。
- 设置、关卡选择、LAN 大厅、教学、挑战和正式对局共用同一播放进度，跨这些场景不重启。
- 当前实现覆盖单曲循环；未来如果恢复前端、教学、常态和压力分轨，需要另行替换路由策略。

## 资产与处理

| 项目 | 值 |
|---|---|
| 作曲源 | `assets/audio/bgm/source/bgm_match_standard_loop_v01.beepbox.json` |
| 输入导出 | BeepBox WAV，48 kHz、16-bit、stereo |
| 制作母版 | `assets/audio/bgm/master/bgm_match_standard_loop_v01.wav`，48 kHz、24-bit、stereo |
| 运行时资产 | `assets/audio/bgm/bgm_match_standard_loop_v01.ogg`，OGG Vorbis quality 7 |
| 音高 / 速度 | D 小调五声音阶 / 92 BPM |
| 节拍网格 | 每小节 8 拍，16 个循环小节 |
| 循环范围 | sample `0..4006957`，83.478270833 秒 |
| 边界处理 | 首尾各 5 ms 安全淡化，循环边界最大采样跳变约 0.000766 |
| 母版响度 | -17.93 LUFS-I / -1.25 dBTP |
| 运行时响度 | -17.88 LUFS-I / -1.25 dBTP |
| 母版 SHA-256 | `9009824d3570aa0ab9f38c8725bda60956ccc84950de384f0ae4790842e18706` |
| OGG SHA-256 | `a8023d3b4496527b53a6a88e0fe8e98b8eb3f0430e908db038325e526f29b8ca` |

母版目录包含 `.gdignore`，避免 24-bit WAV 被 Godot 导入或进入运行时包；运行时只引用 OGG。音源来自项目内 BeepBox 作曲源，没有引入外部录音采样或曲库资产。

## Godot 接入

- `MusicManager` 使用预置场景与预置 `AudioStreamPlayer`，注册为 Autoload。
- 播放器固定发送到现有 `Music` 总线，因此沿用设置页的音乐音量与静音逻辑。
- 循环由 `AudioStreamOggVorbis.loop` 导入属性承担，不用脚本监听 `finished` 重播。
- 管理器监听 `SceneTree.scene_changed`：进入开始菜单停止；进入其他场景时仅在尚未播放时启动，因此跨场景保持时间位置。

## 验收

- 音频格式、时长、响度、true peak、解码帧数与首尾采样跳变由 FFmpeg/FFprobe 检查。
- `tests/game/audio/run_music_manager_contract.gd` 检查 OGG、循环、Music 总线、开始菜单静音，以及其他区域切换不重启。
