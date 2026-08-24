# GATE-3 开场 SFX、吃将弹字与特殊能力 VFX 集成证据 v1

日期：2026-08-24（Asia/Shanghai）

实现提交：`48e8141`（音效）、`27eeea4`（特效）

状态：`producer_integrated / iteration_2_active / independent_qa_pending`

## 结论

- 开场动画新增四层项目内原创 SFX：推门蓄力、城门摩擦、雾幕揭开、菜单落定；由 `AnimationPlayer` 方法轨在 0.32 / 0.72 / 1.45 / 4.65 秒精确触发。
- 跳过开场、从子界面返回菜单和 reduced-motion 快速进入均关闭开场时间轨音效，避免 `seek()` 时集中爆发。
- 新增预置 `FrontendAudioFeedback`，覆盖标题菜单、设置、关卡选择、LAN 房间和两个应用根的全局弹窗；动态关卡卡片入树后自动绑定，离树后清理记录。
- SFX Catalog 从 42 cue / 31 WAV 增至 46 cue / 35 WAV；全部为 48 kHz、16-bit、mono PCM，固定 recipe / seed / SHA-256，无第三方素材和外部支出。
- VFX Catalog 从七族扩展为九族：新增 `callout` 与 `resurrection`；炮击继续使用既有三重震环，并与吃将弹字、复活回魂军印共同进入正式预置池。
- 标准九族同时峰值为 100/100 overdraw points，reduced-motion 为 37/56 points；仍使用 9 个棋盘槽 + 3 个 global 槽，不启用 trails，不提高预算。

## 吃 / 将语义边界

- `吃`：只由新出现的公开 `capture_ghost` 触发，位置严格取公开吃子坐标。
- `将`：当前 owner rule revision 5 没有传统象棋“将军中”状态；本轮只在公开被吃棋子为 `general/king` 时显示，语义是“公开将领被摧毁”。
- 不根据迷雾下棋子、隐藏攻击线或未来行动推断 `将`，因此不新增 PlayerView / VisibleEvent 字段，也不泄露隐藏信息。
- 若后续需要传统“将军预警”，必须先修订规则和可见事件合同，不能由表现层自行推断。

## 特殊能力

- 炮轰：`bombardment_resolved` 继续固定映射 `vfx.bombardment.resolve`；有公开坐标时落棋盘，否则只进入 global 层，隐藏命中数不改变表现骨架。
- 士复活：当同一公开棋子从 `dead/reserve` 变为 `alive/not-in-reserve` 且具有公开坐标时，触发 `vfx.resurrection.revive`；复活差分不会再被误判为普通移动。
- Audio 既有炮击两层和士牺牲/复活两层保持不变，与新增 VFX 同帧消费观察者安全输入。

## 自动验证

- `FRONTEND_AUDIO_FEEDBACK_PASS scenes=6 opening_cues=4 dynamic_buttons=true modal_edges=true skip_guard=true`
- `AUDIO_RUNTIME_CONTRACT_PASS checks=327 cues=46 wav=35 pools=8+8`
- `OBSERVER_AUDIO_POLICY_CONTRACT_PASS checks=30 schema=v1`
- `VFX_CUE_CONTRACT_PASS cues=8 families=9 shared_fields=11 hidden_equivalence=true`
- `VFX_SCENE_SMOKE_PASS pool=9+3 peak_standard=100 peak_reduced=37 dedup=true reduced_motion=true gl_compatibility=true`
- `HIDDEN_EQUIVALENCE_PASS pairs=6 checks=2723`
- `MATCH_FEEDBACK_INTEGRATION_CONTRACT_PASS screens=2 audio_observer=true vfx_observer=true local_selection=true minimap_isolation=true reset=true`
- `FORMAL_SCENE_SMOKE_PASS roots=3 components=24 inputs=11`

## Windows 候选

- 在隔离干净 worktree、Godot `4.7.1.stable.official.a13da4feb`、Intel Iris Xe / OpenGL 3.3 Compatibility 上构建通过。
- 性能：`selection_p99_ms=0.566`、`confirmation_p99_ms=9.199`、`fog_cache_p99_ms=0.088`，均低于 16.7 ms。
- `WINDOWS_LAN_EXPORT_VERIFY_PASS frames=120`。
- `WINDOWS_RUNTIME_CANDIDATE_PASS`。
- 预算：EXE `209,904,808` bytes；headroom `110,095,192` bytes；pack zip `99,467,886` bytes；展开 `100,615,667` bytes；570 entries。
- 主工作区构建目录已同步本次成功候选与日志；主编辑器旧 `.godot` 缓存导致的首次导出缺失引用未进入隔离构建，也未修改运行时源码。

## 可审样片

- `evidence/gate3/vfx/vfx-review-1280x720.png`
- 九族 review hold：`bombardment / callout / capture / flag / move / resurrection / selection / terminal / wall`。
- 样片仅用于生产者视觉复核，不替代项目所有者审美确认。

## 来源与许可

- 用户明确允许使用开源或项目内自制 SFX；本轮选择项目内程序合成，外部支出 `0 CNY`。
- 许可、配方、seed 与 SHA-256：`docs/audio/sfx-source-license-register-v1.md`。
- VFX 使用现有项目内原创 SVG 几何、Canvas 绘制和预置中文字体资源，无新增第三方资产。

## 保留项

- 仍需项目所有者人工审听开场四层音色与确认吃将/复活视觉风格。
- 仍需独立 QA 在目标实体声卡和双机 LAN 上复现削波、长局、峰值音画与 reduced-motion。
- 本证据只更新 GATE-3 Iteration 2 的 Audio/VFX producer integration，不推进 Iteration 3，不批准 GATE-3 内容冻结或 GATE-4 发布。
