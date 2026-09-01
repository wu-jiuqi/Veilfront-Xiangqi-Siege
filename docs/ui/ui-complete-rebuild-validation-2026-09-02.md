# 《雾疆：九路烽棋》全量 UI 重构验收记录

日期：2026-09-02  
分支：`codex/ui-complete-rebuild`  
工作树：`D:\Veilfront Xiangqi Siege-ui-complete-rebuild`

## 验收结论

正式生产路径中的设置、关卡选择、正式局域网大厅、加载页、对局 HUD、教程、图鉴、暂停、引导、标记菜单、确认框和终局面板已经完成 v3 UX 与视觉清晰度修订。开始菜单按项目所有者要求锁定为原版，不参与改造。页面只保留一个高识别九宫格外框，普通任务区、栏目和正文区改用安静玄铁平面；布局继续由预置 `Control` / `Container` 节点承担，不依赖固定尺寸整页贴图确定控件位置。

本轮仅重构表现层与 UI 测试事实源，没有改变规则、PlayerView、教程语义、网络协议、随机消费或音频事件语义。历史 prototype 场景仍作为测试事实源保留，不属于正式页面入口。

## 页面与组件覆盖

- 前台：设置、关卡选择、关卡卡片、加载页、正式局域网大厅；主菜单作为保护边界完成回归锁定。
- 对局：顶部阵营条、回合状态、战况侧栏、棋盘框、目标与教学侧栏、行动抽屉、小地图、终局面板。
- 教程：关卡引导、上下文提醒、暂停菜单、图鉴、旧教程兼容层。
- 全局交互：确认/危险/错误模态框、标记菜单、焦点态、悬停态、按下态与减少动态效果。
- UX 基础：按“当前状态 → 下一步行动 → 决策上下文 → 参考信息 → 装饰”组织阅读顺序，每屏只保留一个主操作。
- 视觉基础：玄铁负责承载，旧青铜负责层级和焦点，玉绿只用于安全推进，朱砂只用于风险；复杂纹样集中在页面外框和军令模态。
- 字体基础：行书只用于页面题签与终局结果，Noto Sans SC Semibold 用于栏目、按钮与数字，Noto Sans SC Regular 用于正文和帮助信息。

## 响应式矩阵

| 画布 | 结果 | 关键行为 |
|---|---|---|
| 960×540 | 通过 | 进入紧凑布局，按钮不低于 44 px，冗余顶部统计收起 |
| 1280×720 | 通过 | 基准布局，页面安全区与对局三栏比例稳定 |
| 1920×1080 | 通过 | 功能区保持可读宽度，背景与留白弹性扩展 |
| 1680×720（21:9） | 通过 | 超宽区域用于背景延展，核心交互区不被拉散 |

## 自动化回归

- UI 基础合约：`UI_COMPLETE_REBUILD_FOUNDATION_PASS surfaces=9 buttons=6 labels=6 viewports=4 hierarchy=v3`，包含正文/辅助文字 4.5:1 对比度验证。
- 静态主题合约：`UI_STATIC_THEME_CONTRACT_PASS roots=18 production_scenes=13 theme=v2 menu_locked=true`。
- 系统模态合约：`SYSTEM_DIALOG_THEME_CONTRACT_PASS dialogs=11 scalable=true native=0`。
- 正式场景冒烟：`FORMAL_SCENE_SMOKE_PASS roots=3 components=24 inputs=11`。
- 前台主流程：原版主菜单保护、设置、关卡选择、加载和正式局域网大厅通过。
- 对局主流程：HUD V2/V3、在线对局、终局、迷雾、行动抽屉和四种画布布局通过。
- 教程主流程：18 个教程流程、成功/失败、暂停、图鉴、上下文提醒、输入保护和四种画布布局通过。
- 局域网协议：网络集成、公开状态 fail-closed、安全恢复和完整 loopback 主流程通过。
- Godot 4.7.1 无界面编辑器导入通过，没有脚本解析或资源导入错误。

## 视觉证据

- `evidence/ui/ui-rebuild-start-menu-1280x720.png`
- `evidence/ui/ui-rebuild-settings-1280x720.png`
- `evidence/ui/ui-rebuild-level-select-1280x720.png`
- `evidence/ui/ui-rebuild-lan-lobby-1280x720.png`
- `evidence/ui/ui-rebuild-online-match-1280x720.png`
- `evidence/ui/ui-rebuild-terminal-dialog-1280x720.png`
- `evidence/ui/ui-rebuild-level-guide-1280x720.png`
- `evidence/ui/ui-rebuild-tutorial-t0-hud-1280x720.png`
- `evidence/ui/ui-rebuild-tutorial-t0-pause-1280x720.png`
- `evidence/ui/ui-rebuild-tutorial-codex-1280x720.png`

## 后续边界

- 合并前仍建议由项目所有者在实际桌面窗口完成一次鼠标、键盘和手柄主流程目视验收。
- 后续新增正式页面必须复用 V2 Theme、按钮预置场景和现有表面角色；允许使用带有效 patch margin 的九宫格材质边框，但不得以固定尺寸整页 PNG 决定控件布局。
- 开始菜单是明确的保护区域；除非项目所有者再次批准，不得把 V2 Theme 或非原版按钮资产接入开始菜单。
