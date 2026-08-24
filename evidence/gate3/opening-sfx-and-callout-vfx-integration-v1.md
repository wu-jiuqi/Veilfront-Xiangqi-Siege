# GATE-3 开场 SFX、吃将弹字与特殊能力 VFX 集成证据 v1

日期：2026-08-24（Asia/Shanghai）

实现提交：`48e8141`（音效）、`27eeea4`（特殊能力与局部提示）、`064cfc5`（吃将全屏中央提示）、`0582fba`（资源收尾验证稳定化）

状态：`producer_integrated / iteration_2_active / independent_qa_pending`

## 结论

- 开场动画新增四层项目内原创 SFX：推门蓄力、城门摩擦、雾幕揭开、菜单落定；由 `AnimationPlayer` 方法轨在 0.32 / 0.72 / 1.45 / 4.65 秒精确触发。
- 跳过开场、从子界面返回菜单和 reduced-motion 快速进入均关闭开场时间轨音效，避免 `seek()` 时集中爆发。
- 新增预置 `FrontendAudioFeedback`，覆盖标题菜单、设置、关卡选择、LAN 房间和两个应用根的全局弹窗；动态关卡卡片入树后自动绑定，离树后清理记录。
- SFX Catalog 从 42 cue / 31 WAV 增至 46 cue / 35 WAV；全部为 48 kHz、16-bit、mono PCM，固定 recipe / seed / SHA-256，无第三方素材和外部支出。
- VFX Catalog 从七族扩展为九族：新增 `callout` 与 `resurrection`；炮击继续使用既有三重震环，并与吃将弹字、复活回魂军印共同进入正式预置池。
- 标准九族同时峰值为 100/100 overdraw points，reduced-motion 为 37/56 points；仍使用 9 个棋盘槽 + 3 个 global 槽，不启用 trails，不提高预算。

## 吃 / 将语义边界

- `吃`：只由新出现的公开 `capture_ghost` 触发；对应碎印冲击严格取公开吃子坐标，中央弹字本身不携带棋盘位置。
- `将`：当前 owner rule revision 5 没有传统象棋“将军中”状态；本轮只在公开被吃棋子为 `general/king` 时显示，语义是“公开将领被摧毁”。
- 不根据迷雾下棋子、隐藏攻击线或未来行动推断 `将`，因此不新增 PlayerView / VisibleEvent 字段，也不泄露隐藏信息。
- 若后续需要传统“将军预警”，必须先修订规则和可见事件合同，不能由表现层自行推断。

### 屏幕中央强提示修订

- 按项目所有者后续要求，`吃/将` 不再落在棋盘公开坐标处，而是固定投射到比赛根视口正中央；棋盘坐标仍只供同时发生的 `vfx.capture.impact` 使用。
- 新增预置 `ScreenCalloutOverlay`：232 px 主字、22 px 粗描边、全屏压暗、252 px 高横向军令带、440 px 军令印和 28 枚一次性火花；`将` 使用“主将告破”，`吃` 使用“斩获敌军”。
- `MatchFeedbackCoordinator` 从观察者安全 VfxCue batch 中分流 `vfx.callout.*` 到根视口，其余 VFX 继续进入棋盘预置池；同一 cue 去重，多吃同帧时若含公开将领则优先显示 `将`。
- reduced-motion 保留中央大字、粗描边、横幅和压暗，但禁用爆发粒子与旋转/缩放冲击，只做短淡入淡出。
- 响应式契约覆盖 960×540、1024×768、1280×720、1920×1080、2560×1080：主字中心始终等于视口中心，军令带始终覆盖完整屏宽。

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
- `SCREEN_CALLOUT_OVERLAY_PASS center=640,360 font=232 outline=22 backdrop=true band=true responsive=5 dedup=true reduced_motion=true`
- `HIDDEN_EQUIVALENCE_PASS pairs=6 checks=2723`
- `MATCH_FEEDBACK_INTEGRATION_CONTRACT_PASS screens=2 audio_observer=true vfx_observer=true local_selection=true minimap_isolation=true reset=true`
- `FORMAL_SCENE_SMOKE_PASS roots=3 components=24 inputs=11`

## Windows 候选

- 在隔离干净 worktree、Godot `4.7.1.stable.official.a13da4feb`、Intel Iris Xe / OpenGL 3.3 Compatibility 上构建通过。
- 性能：`selection_p99_ms=1.115`、`confirmation_p99_ms=14.694`、`fog_cache_p99_ms=0.067`，均低于 16.7 ms。
- `WINDOWS_LAN_EXPORT_VERIFY_PASS frames=120`。
- `WINDOWS_RUNTIME_CANDIDATE_PASS`。
- 预算：EXE `209,953,184` bytes；headroom `110,046,816` bytes；pack zip `99,504,995` bytes；展开 `100,663,464` bytes；575 entries。
- 主工作区构建目录已同步本次成功候选与日志；主编辑器旧 `.godot` 缓存导致的首次导出缺失引用未进入隔离构建，也未修改运行时源码。

## 可审样片

- `evidence/gate3/vfx/vfx-review-1280x720.png`
- `evidence/gate3/vfx/screen-callout-capture-1280x720.png`
- `evidence/gate3/vfx/screen-callout-general-1280x720.png`
- 九族 review hold：`bombardment / callout / capture / flag / move / resurrection / selection / terminal / wall`。
- 屏幕中央样片基于正式 `match_screen.tscn` 与正式 `ScreenCalloutOverlay` 预置生成；样片仅用于生产者视觉复核，不替代项目所有者审美确认。

## 来源与许可

- 用户明确允许使用开源或项目内自制 SFX；本轮选择项目内程序合成，外部支出 `0 CNY`。
- 许可、配方、seed 与 SHA-256：`docs/audio/sfx-source-license-register-v1.md`。
- VFX 使用现有项目内原创 SVG 几何、Canvas 绘制和预置中文字体资源，无新增第三方资产。

## 保留项

- 仍需项目所有者人工审听开场四层音色与确认吃将/复活视觉风格。
- 仍需独立 QA 在目标实体声卡和双机 LAN 上复现削波、长局、峰值音画与 reduced-motion。
- 本证据只更新 GATE-3 Iteration 2 的 Audio/VFX producer integration，不推进 Iteration 3，不批准 GATE-3 内容冻结或 GATE-4 发布。
