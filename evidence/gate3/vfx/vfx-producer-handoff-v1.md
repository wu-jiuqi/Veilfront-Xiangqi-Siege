# GATE-3 VFX 生产者交接 v1

状态：`producer_checks_passed / cue_foundation_ready_for_acceptance / shared_board_mount_pending`

工作项：`TASK-CUE-CONTRACT-G3-001`（VFX 部分）、`TASK-VFX-G3-001` 候选产物。执行实例：`inst:01M0QY1VFX7SFXVFXGATE3VFX1`。本交接不批准 GATE-3，不替代独立 QA，也不把当前 Loop iteration 1 冒充 iteration 2 已完成。

## 结论

- 已先冻结观察者安全 VfxCue v1，再让七族候选资产只消费该 Cue；顺序符合 Contract 的 foundation-first 依赖。
- VfxCue 与并行 AudioCue 对齐 11 个共享 envelope 字段、`local_interaction/visible_event/visible_error/view_diff` 来源、同 key 0 基 occurrence、cues 数组顺序、`global/board_2d`、公开位置和隐藏等价语义。
- 已完成选中、移动、吃子、炮击、城墙、旗帜、终局七族，使用 9 个棋盘槽 + 3 个 global 槽的预置池；无运行时节点实例化、无 trails、无规则随机源。
- 标准七族同时峰值 95/100 points；减少动态峰值 34/56 points。减少动态保持 cue_id/key/顺序/位置不变，粒子降至 0–3，只保留短淡出或静态符号。
- 三份粒子 SVG 为项目原创手工几何，无第三方素材、字体、外部支出或署名要求；源图与运行时 Resource 分开登记。

## 运行入口与挂载建议

- 推导：`ObserverVfxPolicy.derive_batch(previous_view, current_view, visible_events, motion_profile)`。
- 本地选中：`ObserverVfxPolicy.derive_local_selection_batch(...)`。
- 播放：`VfxDirector.play_batch(batch)`；镜像时调用 `set_display_side(red|black)`。
- 预置根：`scenes/game/vfx/vfx_root.tscn`；目录：`resources/game/vfx/vfx_catalog.tres`。
- 建议挂载：Registry 接受 Cue foundation 并合法进入下一迭代后，由技术负责人把 `VfxRoot` 预置到 `BoardWorld`；WorldPool 位于棋子/旗帜上方且不拦截输入，GlobalCanvas 仅覆盖 Board SubViewport。ApplicationHost 的 observer frame 先交 policy，再把 batch 送 director。本次未修改共享 `board_world.tscn/match_screen.gd`，避免越过技术所有权与并行音频接线。

## 验证

Godot：`4.7.1.stable.official.a13da4feb`；项目：`GL Compatibility`。

1. `Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/game/vfx/run_vfx_cue_contract.gd`
   - `VFX_CUE_CONTRACT_PASS cues=7 families=7 shared_fields=11 hidden_equivalence=true`
2. `Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/game/vfx/run_vfx_scene_smoke.gd`
   - `VFX_SCENE_SMOKE_PASS pool=9+3 peak_standard=95 peak_reduced=34 dedup=true reduced_motion=true gl_compatibility=true`
   - 复跑后无 VFX 测试 Godot 残留进程。
3. `Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/game/architecture/run_formal_architecture_checks.gd`
   - `FORMAL_ARCHITECTURE_CHECKS_PASSED self_tests=19 scanned_files=201`
4. `Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/game/scenes/run_formal_scene_smoke.gd`
   - `FORMAL_SCENE_SMOKE_PASS roots=3 components=19 inputs=11`
5. `Godot_v4.7.1-stable_win64_console.exe --path . --rendering-method gl_compatibility --script res://tests/game/vfx/capture_vfx_review_sample.gd`
   - Intel Iris Xe / OpenGL 3.3 Compatibility；`VFX_REVIEW_CAPTURE_PASS active=7 families=["bombardment", "capture", "flag", "move", "selection", "terminal", "wall"] review_hold=true`。
   - 审查场景的稳定截图 hold 只在 `vfx_review_lab.tscn` 启用，正式 `vfx_root.tscn` 默认关闭；目检确认棋盘内七族均可辨识。
   - 截图：`evidence/gate3/vfx/vfx-review-1280x720.png`
   - SHA-256：`d0cb28437e0957a9ca6f004b904abdfeb717a14be0756790ac9aef2acf02a8fb`（163090 bytes）
6. 项目与 GATE-3 Registry 校验：`state=normal`；`CONTENT_INTEGRATION_GATE3_REGISTRY_PASS state=active iteration=1 sequence=15 revision=15`。

## 待接入与风险

- 当前只完成可运行候选包和独立 review lab；正式主棋盘接线必须等待 Cue foundation 接收和合法 Registry 迁移，由技术负责人处理共享文件。
- 色彩、半径、节奏和终局强度仍需项目所有者在 GATE-3 审美闸门确认；本文不冻结最终全局美术基线。
- 95/34 是预置预算合同，不是完整对局实机 P99。正式接线后 QA 仍需在 Intel Iris Xe 复现高峰音画并发、平均 60 FPS 和 P99 16.7ms。
- 未发现旗帜只产生 global 效果；炮击空位置也只进入 global。不得在接线时用棋子节点、镜头中心或隐藏命中补坐标。
- 如果正式集成需要逐格炮击次序或隐藏路径动画，应舍弃效果或另立 DTO/Contract 修订，不能扩大 v1 输入边界。
