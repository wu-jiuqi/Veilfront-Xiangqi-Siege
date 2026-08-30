# 新手教程图鉴易读性重制交接 v2

状态：`producer_integrated / awaiting-independent-qa / not-gate3-frozen`

日期：2026-08-30

## 问题与决定

旧版 18 页图鉴把规则数字、箭头、路径、说明文字和多分镜都交给生成图片，存在伪文字、数量偏差和规则关系误画风险，也让新手必须同时解码图片与长段正文。

本轮冻结以下呈现原则：

1. 一页只保留一个视觉记忆焦点。
2. 生成图片不再包含文字、数字、箭头、UI、分镜或可被当成精确坐标的标注。
3. 精确规则由 Godot 预置 Control 节点分为“先记这一句 / 看懂这三步 / 容易搞错 / 看图重点”。
4. 图片不是规则事实源；规则仍追溯 `docs/prototype/rules-spec-v1.md`。
5. 所有数量敏感图片逐张人工核对；炮击页必须清楚表现 9 个候选点与恰好 3 个命中点。

## 实现与资产

- 图鉴场景：`scenes/game/ui/tutorial_codex.tscn`
- 图鉴内容与线程加载：`scripts/game/tutorial/tutorial_codex.gd`
- 18 张 v2 插图与提示规范：`assets/art/tutorial/comic_v2/`
- 内容契约：`tests/game/tutorial/run_tutorial_codex_contract.gd`
- 前端集成契约：`tests/game/frontend/run_level_select_ui_contract.gd`
- 分辨率截图工具：`tests/game/tutorial/capture_tutorial_codex_v2.gd`
- 导出白名单：`export_presets.cfg`、`tools/release/windows_runtime_manifest.json`

本轮提交：

- `268472b` — `feat: 重构战阵图鉴分层教学体验`
- `2a7941d` — `feat: 重制战阵图鉴规则插图`

## 规则准确性修正

- 将特殊行动共同资格明确限定为马、相、车、兵的特殊移动，避免玩家误以为士献祭也受敌墙和路径限制。
- 炮击步骤明确为规则随机锁定三个不同点，避免读成玩家任选三个点。
- 修墙页明确触发修复的行动不计入等待窗口，期间回到三名入侵者会中断。
- 旗帜页区分原所有权、`contested` 与 3/3 后正式翻旗。
- 胜负页明确同一炮击窗口双将阵亡为平局，动画顺序没有规则语义。

## 自动验证

- `TUTORIAL_CODEX_CONTRACT_PASS pages=18 layers=key,steps,pitfall,caption`
- `TUTORIAL_LAYOUT_CONTRACT_PASS resolutions=3 hud=match-v3 guide=approved`
- `LEVEL_SELECT_UI_CONTRACT_PASS source=approved_master_v3 modules=18 routes=2 resolutions=5`
- `FRONTEND_SCENE_SMOKE_PASS catalog=21 tutorial=18 challenge=3 routes=2`
- `ALL_TUTORIAL_FLOWS_PASS chapters=18`
- `TUTORIAL_CURRICULUM_CONTRACT_PASS modules=18 routes=2 migration=v2`
- `TUTORIAL_CONTEXT_REMINDER_CONTRACT_PASS observer_safe=true`
- `TUTORIAL_RULE_BOUNDARY_CONTRACT_PASS`
- `WINDOWS_RUNTIME_BUDGET_PASS exe_bytes=229943592 pack_expanded_bytes=120650351 texture_bytes=76338208`
- `WINDOWS_LAN_EXPORT_VERIFY_PASS ... frames=120`
- 包内容核对：`comic_v2/*.import = 18`，`comic_v1/* = 0`。

Godot：`4.7.1.stable.official.a13da4feb`。

## 视觉证据

- `evidence/ui/tutorial-codex-v2-p00-1280x720.png`
- `evidence/ui/tutorial-codex-v2-p09-1280x720.png`
- `evidence/ui/tutorial-codex-v2-p12-960x540.png`

1280×720 与 960×540 均保持图片区、四层文本和导航可见；测试页覆盖基础页、数量敏感的炮击页和长文案的修墙页。

## 代码审查结论

- 严重问题：无。
- 已修复：截图脚本在 Dummy 渲染器无法读取图像时会明确退出，不再挂起。
- 正向项：大图使用线程加载，空闲时关闭 `_process()`；UI 使用预置 Control/Container 节点；运行时不依赖图片内文字；契约遍历全部 18 页并真实加载 v2 纹理。

## 独立 QA 与试玩待办

1. 本记录只是生产者集成证据，不是独立 QA 结论。
2. 需要 QA 从冻结提交独立复核 18 张图与权威规则的一致性、键盘焦点、不同 DPI 和长文案滚动。
3. 需要至少两类新玩家试玩：完全不会象棋者与熟悉传统象棋者；记录首次复述正确率、找规则耗时和误读页。
4. GATE-3 内容冻结与发布决定仍由项目所有者保留。
