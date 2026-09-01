# 全量 UI Workflow 重构生产者交接 v1

状态：`producer_integrated / awaiting-independent-qa / not-gate3-frozen`

日期：2026-09-02  
分支：`codex/ui-workflow-refactor`  
Worktree：`D:\Veilfront Xiangqi Siege-ui-refactor`

## 授权与边界

- 本轮遵循 `game-pipeline/approvals/production-scope-exception-full-ui-bb9bb74bf65b.yaml` 与 `UI-FULL-ASSET-OWNER-EXCEPTION-decision-package-v1.yaml` 的已批准九类页面范围。
- 实现没有修改 `scripts/game/domain`、规则随机、`PlayerView` / `VisibleEvent`、回放、教学 Intent/Event、联网协议、音频或第二套 Theme。
- 本记录是生产者集成证据，不是独立 QA、审美批准或 GATE-3 冻结结论；没有修改 Registry/Gate 状态。

## 重构结论

1. 正式交互统一由原生 `Button` 根节点拥有输入、焦点、信号和无障碍语义。
2. 阴影、九宫格表面、保持比例的复杂插画、图标、文字、焦点框和语义标记均为共享 `.tscn` 中的预置子节点，且全部忽略输入。
3. 页面遗留 Theme 覆盖会在运行时被透明语义壳隔离，正式美术只由独立视觉层绘制。
4. Tween 只改变视觉子树的 offset transform、调制色和透明度，不改变 Container 布局矩形；旧 Tween 在新状态前终止。
5. 状态优先级统一为 `disabled > pressed > focus+hover > focus > hover > normal`；鼠标悬停不抢夺键盘/手柄焦点。
6. 支持 `Primary / Secondary / Danger / Confirm` 四类语义、独立焦点框、禁用态和 reduced-motion；基础按钮至少 48px，高价值预置至少 56px，页面紧凑控件不得低于 44px。
7. 主菜单、设置、关卡选择、局域网大厅、对局 HUD、教学覆盖层、暂停菜单、加载/错误、终局结算与通用弹窗均已迁移；业务 NodePath 与按钮信号保持兼容。

## 生产提交

- `163636c` — `feat: 重构语义按钮视觉分层与动效基线`
- `598bdcf` — `feat: 统一重构前端页面语义按钮与美术分层`
- `aec78bc` — `feat: 统一重构对局与系统界面语义交互`
- `c83102d` — `feat: 统一重构教学界面语义交互`

上述提交均已推送至 `origin/codex/ui-workflow-refactor`；候选尚未合入 `main`。

## 自动验证

- `UI_WORKFLOW_COMPONENT_CONTRACT_PASS variants=4 visual_layers=10 semantic_root=Button`
- `FULL_UI_WORKFLOW_MIGRATION_PASS scenes=60 formal_scenes=20 semantic_buttons=121 direct_texture_buttons=0`
- `GATE3_UI_FOUNDATION_CONTRACT_PASS variants=4 roles=6 viewports=4 focus_loop=true reduced_motion=colour_only`
- `FRONTEND_SCENE_SMOKE_PASS catalog=21 tutorial=18 challenge=3 routes=2`
- `FRONTEND_INTRO_CONTRACT_PASS sequence_gate=ok menu_input_gate=ok`
- `SETTINGS_SCREEN_CONTRACT_PASS tabs=3 controls=12 ... resolutions=3 route=connected`
- `LEVEL_SELECT_UI_CONTRACT_PASS source=approved_master_v3 modules=18 routes=2 resolutions=5`
- `FORMAL_LAN_LOBBY_CONTRACT_PASS states=5 private_seed=absent`
- `MATCH_HUD_V2_CONTRACT_PASS`、`MATCH_HUD_V2_TERRACOTTA_ART_PASS`、`ONLINE_MATCH_HUD_V3_CONTRACT_PASS`
- `MATCH_HUD_V3_LAYOUT_LAB_PASS`、`LEVEL_GAMEPLAY_HUD_LAB_PASS`
- `TERMINAL_DIALOG_CONTRACT_PASS contexts=3 responsive=960x540,1280x720,1920x1080`
- `SYSTEM_DIALOG_ART_CONTRACT_PASS dialogs=11 assets=3 native=0`
- `LOADING_TRANSITION_MOTION_LAB_CONTRACT_PASS progress=67 failure_feedback=true reduced_motion=true`
- 教学暂停、图鉴、情境提醒、覆盖层动作、输入守卫、导航、完成/失败与三分辨率布局合同全部通过。
- Godot `4.7.1.stable.official.a13da4feb` 编辑器无头导入/脚本注册退出码为 0。

## 真实渲染证据

使用 Intel Iris Xe / OpenGL Compatibility 在 1280×720 重新生成并人工检查：

- `evidence/gate3/ui/gate3-ui-foundation-lab-1280x720.png`
- `evidence/ui/title-menu-settings-shield-v1-1280x720.png`
- `evidence/ui/settings-screen-functional-1280x720.png`
- `evidence/ui/level-select-approved-master-v2-1280x720.png`
- `evidence/ui/formal-lan-lobby-ui-workflow-v1-1280x720.png`
- `evidence/ui/match-hud-v3-layout-lab-1280x720.png`
- `evidence/ui/online-match-hud-v3-1280x720.png`
- `evidence/ui/level-gameplay-hud-lab-1280x720.png`
- `evidence/ui/formal-terminal-dialog-v2-1280x720.png`
- `evidence/ui/loading-transition-motion-v1-loading-1280x720.png`
- `evidence/ui/loading-transition-motion-v1-failure-1280x720.png`
- `evidence/ui/tutorial-codex-v3-p00-1280x720.png`

复查结果：复杂按钮插画保持比例，无烘焙底板拉伸；核心文字无裁切；376px 教学右栏与棋盘/行动区不重叠；焦点框与危险/确认语义可辨。

## 代码审查

- 严重问题：无。
- 固定 UI 结构继续使用预置节点与场景继承，没有新增脚本动态拼装界面。
- 节点引用均缓存于 `@onready`；没有在 `_process()` / `_physics_process()` 中查找节点或加载资源。
- 视觉状态 Tween 可中断，并由节点生命周期托管；reduced-motion 下不产生几何变化。
- 全局扫描确认正式 `scenes/game` 只在共享基类定义原生 `Button`，不存在直接 `TextureButton` 或清空 `motion_profile` 的页面实例。

## 未完成与后续

1. QA 需从冻结提交独立复现键鼠/手柄焦点、960×540、1280×720、1920×1080、2560×1080 与 21:9 背景延展。
2. QA 需检查 Windows 成品的 DPI、字体回退、暂停态 Tween、长时间多次切换状态和输入可达性。
3. `run_online_match_hud_v3_contract.gd` 与 `run_level_gameplay_hud_lab_contract.gd` 在退出时仍可能报告少量 ObjectDB/资源未释放警告；功能、布局和截图断言通过，但测试夹具清理应在冻结前复核。
4. 仍需项目所有者对九类页面做最终视觉/体验验收；本分支在得到结论前不得合入 `main` 或标记 GATE-3 完成。
