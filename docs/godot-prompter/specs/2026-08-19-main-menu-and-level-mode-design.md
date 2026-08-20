# 《雾疆：九路烽棋》首界面与关卡模式 Godot 设计

状态：`owner_direction_approved / specification_pending_owner_review`

日期：2026-08-19

适用版本：Godot 4.7.1，Demo 灰盒阶段

上游输入：

- `docs/design/tutorial/veilfront-ftue-formal-level-design-v2.md`
- `docs/architecture/formal-dto-and-trust-boundary-v1.md`
- `docs/architecture/gate1-to-formal-migration-manifest-v1.yaml`
- `game-pipeline/loops/contracts/loop-contract-formal-foundation-gate2-v1.yaml`
- 旧挑战关卡来源分支 `codex/level-test-playable`

## 1. 目标

建立 Demo 的正式启动路径：玩家启动游戏后先看到长城青铜城门开始界面，点击、触摸或按确认键后进入游戏菜单；游戏菜单可以进入现有局域网联机大厅，或进入关卡目录。关卡目录同时承载 T0–T10 新手教学和孤相、双相、双马三个挑战关。

本次只制作灰盒 UI、场景路由、关卡数据、正式教学流程和关卡专用规则 AI，不制作或冻结最终美术。

## 2. 已确认范围

### 包含

- 游戏首界面。
- 局域网联机入口，目标为现有 `res://scenes/prototype/network/lan_lobby.tscn`。
- 关卡选择界面。
- T0–T10 十一个新手教学章节。
- C1 孤相、C2 双相、C3 双马三个挑战关。
- 本地章节完成状态、最近进入关卡和教学检查点。
- 所有界面的返回上一级、重置和退出路径。
- 960×540、1280×720、1920×1080 三档桌面布局验证。

### 不包含

- 完整、通用或高棋力的人机对战模式。
- AI 训练、难度梯度、自由开局、排位或棋力质量承诺。
- 互联网联机、服务器、匹配、账号、重连或房主迁移。
- 最终 UI 皮肤、完整美术、动画、音效或批量资产生产。
- 复制第二套规则或由教学脚本直接修改 `FullState`。

## 3. 模式结构

```text
MainMenu
├─ 局域网联机对战
│  └─ LanLobby（现有 GATE-1 LAN 工具）
└─ 关卡模式
   └─ LevelSelect
      ├─ 新手教学
      │  ├─ T0 操作校准：棋落交点
      │  ├─ T1 兵卒训练：穿阵不伤
      │  ├─ T2 马训练：越腿入雾
      │  ├─ T3 相象训练：田字封路
      │  ├─ T4 车训练：蓝线开路
      │  ├─ T5 炮训练：一架一轰
      │  ├─ T6 士训练：以身换援
      │  ├─ T7 将帅训练：实际阵亡
      │  ├─ T8 特色机制：雾墙攻防
      │  ├─ T9 特色机制：雾中旗帜
      │  └─ T10 综合考核：第一面战旗
      └─ 挑战关卡
         ├─ C1 孤相
         ├─ C2 双相
         └─ C3 双马
```

挑战关显示名沿用项目所有者的“孤相、双相、双马”。局面中的黑方相类棋子仍使用正式棋子类型与黑方显示字“象”，不改变规则数据。

## 4. 场景设计

所有固定 UI 结构使用预置节点。运行时只动态实例化数量由关卡目录决定的关卡卡片，以及由 `PlayerView` 决定数量的棋子、旗帜、墙和虚影。

```text
scenes/game/frontend/start_screen.tscn
StartScreen (Control)
├─ UiThemeBinder (Node)
├─ Background (TextureRect)
├─ PromptArea (CenterContainer)
│  └─ EnterPrompt (Label)
└─ ErrorDialog (AcceptDialog)
```

```text
scenes/game/frontend/main_menu.tscn
MainMenu (Control)
├─ Background (ColorRect)
├─ FrontEndNavigator (Node)
├─ SafeMargin (MarginContainer)
│  └─ Center (CenterContainer)
│     └─ MenuPanel (PanelContainer)
│        └─ MenuColumn (VBoxContainer)
│           ├─ GameTitle (Label)
│           ├─ Subtitle (Label)
│           ├─ LanButton (Button)
│           ├─ LevelModeButton (Button)
│           └─ QuitButton (Button)
└─ VersionLabel (Label)
```

```text
scenes/game/frontend/level_select.tscn
LevelSelect (Control)
├─ Background (ColorRect)
├─ FrontEndNavigator (Node)
├─ SafeMargin (MarginContainer)
│  └─ Page (VBoxContainer)
│     ├─ Header (HBoxContainer)
│     │  ├─ BackButton (Button)
│     │  ├─ Title (Label)
│     │  └─ ProgressLabel (Label)
│     ├─ CategoryTabs (TabContainer)
│     │  ├─ TutorialScroll (ScrollContainer)
│     │  │  └─ TutorialGrid (GridContainer)
│     │  └─ ChallengeScroll (ScrollContainer)
│     │     └─ ChallengeGrid (GridContainer)
│     └─ HelpText (Label)
└─ ConfirmDialog (ConfirmationDialog)
```

```text
scenes/game/frontend/level_card.tscn
LevelCard (PanelContainer)
└─ CardMargin (MarginContainer)
   └─ CardColumn (VBoxContainer)
      ├─ CodeLabel (Label)
      ├─ TitleLabel (Label)
      ├─ DescriptionLabel (Label)
      ├─ StatusLabel (Label)
      └─ PlayButton (Button)
```

运行关卡继续复用预置的 `scenes/game/tutorial/tutorial_level.tscn` 和正式 `MatchScreen`。挑战关新增独立组合根 `scenes/game/challenge/challenge_level.tscn`，但复用同一个正式 `ApplicationHost`、`MatchScreen`、规则域和观察者投影。

## 5. 路由与返回规则

`project.godot` 的 `run/main_scene` 改为 `start_screen.tscn`。开始界面只负责展示已确认的长城青铜城门背景与“点击任意位置进入”提示；提示使用瑞美加张清平硬笔行书、淡金文字与轻微字距，并由预置 `AnimationPlayer` 驱动柔和明暗循环。左键点击、触摸按下或 `ui_accept` 进入 `main_menu.tscn`，连续输入由一次性跳转锁拦截。

- 开始界面加载游戏菜单失败时显示本地错误弹窗并停留在当前界面。
- “局域网联机对战”切换到现有 LAN 大厅。
- “关卡模式”切换到 `level_select.tscn`。
- 教学或挑战关退出时统一返回 `level_select.tscn`，并恢复之前选中的分类和滚动位置。
- LAN 大厅新增“返回首界面”入口；只负责退出当前 LAN 会话并切换场景，不改变 LAN 协议。
- `Esc` 在首界面不直接退出程序，而是打开退出确认；在关卡目录返回首界面；在关卡内部优先遵守取消当前行动，再由明确按钮退出关卡。
- 场景加载失败时显示本地错误对话框并停留在当前界面，不进入空白场景。

首版使用一个窄职责的 `FrontEndNavigator` 处理已知场景路径和返回目标。每个前端场景在预置树中各自持有一个 Navigator 节点；它不是 Autoload，不跨场景保留对象状态。分类、关卡和焦点恢复信息写入本地进度后由新场景重建。Navigator 不持有规则状态、玩家视图或网络状态，也不作为全局业务服务。

## 6. 关卡数据模型

新增只读 `LevelDefinition` Resource，用于目录与启动参数：

- `level_id`：稳定 ID，取值 T0–T10 或 C1–C3。
- `category`：`tutorial` 或 `challenge`。
- `title`、`summary`、`objective_text`：灰盒显示文本。
- `scene_path`：允许加载的预置组合根。
- `authority_scenario`：教学或挑战权威局面 Resource。
- `presentation_track`：只含观察者安全提示的表现 Resource。
- `unlock_after`：前置关卡 ID；空值表示默认开放。
- `recommended_order`：目录排序值。

目录使用一个只读 `LevelCatalog` Resource 引用十四个 `LevelDefinition`，不扫描任意文件夹，也不接受外部路径。Resource 只保存配置，不执行规则、场景切换或进度写入。

T0 默认开放。T1–T10 按顺序解锁，但玩家可通过“跳过本章”完成教学壳要求；C1–C3 默认全部开放，避免把挑战内容误当成新手教学强制门槛。

## 7. T0–T10 教学运行边界

教学数据分为两层：

- 权威 Scenario：初始完整状态、固定种子、允许 Intent、检查点、失败与完成条件，由 `ApplicationHost` 持有并验证。
- Presentation Track：标题、提示键、公开步骤和恢复文案，只消费 `PlayerView`、`VisibleEvent`、`VisibleError`、`ActionPreview` 和准备行动回执。

数据流：

```text
玩家输入
→ MatchScreen
→ NormalizedIntent / preview_id
→ ApplicationHost
→ 正式 RuleEngine
→ DomainEvent + 新 FullState
→ ObserverProjector
→ PlayerView / VisibleEvent / VisibleError / ActionPreview
→ MatchScreen + TutorialDirector
```

教学脚本不得直接移动棋子、设置旗帜发现、修改城墙、复活棋子或伪造规则成功。重试通过权威 Scenario 重新创建对局；跳过只记录教学进度，不伪造对局胜利。

## 8. C1–C3 关卡 AI 边界

关卡 AI 是固定挑战内容的一部分，不是完整人机模式。

- 只在 C1–C3 场景启动。
- 只读取黑方 `PlayerView` 和公开 ActionPreview，不读取红方私有状态、隐藏旗位、相田来源、随机内部状态或完整 `FullState`。
- 只能从正式应用层返回的合法行动候选中选择，不能自己判定合法性。
- 决策顺序继承旧挑战：受威胁棋优先、安全落点优先、安全吃子优先，其余合法落点按固定种子选择。
- 不提供难度选项、搜索深度、训练参数、自由布阵或通用对局入口。
- 每次决定记录关卡 ID、公开观察摘要、候选数量、选中 preview ID 和固定种子消费序号，以支持确定性回放和反作弊检查。

旧分支的 `level_scenario.gd` 可作为局面输入，`safe_random_ai.gd` 只能作为行为参考；正式实现迁移到 `scripts/game/challenge/`，不得从正式组合根 preload `scripts/prototype/` 或旧 `scripts/level_test/`。

## 9. 进度存储

本地进度保存在 `user://level_progress.cfg`，只记录：

- `schema_version`。
- 已完成关卡 ID 集合。
- 已跳过教学 ID 集合。
- 最近选择的分类和关卡 ID。
- 每个教学章节最近通过的公开检查点 ID。

不保存 `FullState`、隐藏信息、随机内部状态或未完成对局。未知关卡 ID、未知字段或版本不兼容时忽略对应条目并保留可识别进度；文件无法读取时以空进度启动，并在界面显示一次非阻断提示。

“清空教学进度”只清除 T0–T10；“清空全部关卡进度”需要二次确认并清除教学和挑战完成状态。这两个操作不影响 LAN 设置。

## 10. 响应式与输入

- 根节点使用 Full Rect，页面外层使用 `MarginContainer`，布局只依赖 Container、锚点和最小尺寸。
- 设计基准为 1920×1080，最低验证窗口为 960×540。
- 关卡卡片在宽屏使用多列 Grid，在窄屏减少列数并通过 ScrollContainer 垂直滚动。
- 所有按钮最小高度 44 px，支持鼠标、键盘和手柄焦点。
- 每个界面打开时把焦点交给第一个主要操作按钮；返回后恢复此前焦点。
- 灰盒主题集中使用 `formal_graybox_theme.tres`，不得在每个按钮复制 Theme。

## 11. 错误与恢复

- 缺失或无效 LevelDefinition：卡片显示“内容不可用”，禁止启动并记录错误路径。
- 权威 Scenario 与关卡 ID 不匹配：拒绝绑定，返回关卡目录。
- 教学步骤无法由公开事件推进：停在当前步骤，显示可重试反馈，不建立隐藏状态旁路。
- 关卡 AI 没有合法行动：由正式规则判断跳过、终局或失败；AI 不伪造行动。
- LAN 返回首界面前先调用现有断开流程；失败时仍释放本地会话并显示提示。

## 12. 测试与验收

### 首界面与路由

- 主场景 headless 加载无错误。
- 开始界面使用确认的降噪版长城青铜城门背景，并显示“点击任意位置进入”。
- 进入提示为淡金色且持续柔和闪烁；动画中间帧透明度应低于明亮帧，并始终保持可读。
- 进入提示字体必须包含完整文案字形；当前硬笔行书作为效果验证资产，商业构建前需保留可核验的游戏嵌入授权凭证。
- 左键、触摸和确认键均可进入游戏菜单，连续输入不会触发重复场景切换。
- 两个模式按钮分别进入 LAN 大厅和关卡目录。
- LAN、关卡目录、教学关、挑战关都有可工作的返回路径。
- 不存在重复点击导致的双场景切换。

### 关卡目录

- 精确列出 T0–T10 和 C1–C3，无重复或缺失 ID。
- 教学顺序解锁，挑战关默认开放。
- 进度损坏、未知 ID 和版本升级不会阻止启动。

### 教学

- 每章可完成、失败、重试、跳过和退出。
- T6 献祭取消不消耗行动，主动继续后才能进入确认步骤。
- 所有脚本行动都形成合法 Intent 和 DomainEvent。
- 隐藏等价输入不会通过提示或允许行动集合泄露信息。

### 挑战

- C1、C2、C3 初始局面分别只有一相、两相、两马作为黑方敌军。
- 同一关卡与种子产生相同 AI preview 选择序列。
- AI 只消费黑方 PlayerView 和正式合法候选。
- 50 完整回合、红帅阵亡和敌军清空的终局条件保持旧挑战意图。

### 布局

- 960×540、1280×720、1920×1080 无主要按钮裁切。
- 键盘和手柄焦点可以遍历所有可用关卡并返回。
- 关卡卡片文本不会覆盖状态或开始按钮。

## 13. 实施依赖与顺序

正式实现必须等待 Iteration 2 的 ActionPreview 全量等价缺口通过生产复核和独立 QA，并由 Registry 合法进入 Iteration 3。

进入 Iteration 3 后按以下顺序实施：

1. 首界面、导航器、关卡目录预置场景和路由测试。
2. LevelDefinition、LevelCatalog 和本地进度边界。
3. T0–T10 权威 Scenario 与 Presentation Track。
4. 教学 Director 与正式 Intent/Event 管线接线。
5. C1–C3 正式局面迁移和关卡 AI。
6. 全流程、隐藏信息、确定性和三分辨率回归。

任何一步若要求修改 owner rule revision 5、正式 DTO、随机消费顺序或 LAN 协议，必须停止并返回对应事实源审查，不在关卡层静默兼容。

## 14. 完成定义

- 游戏从首界面进入 LAN 或关卡模式。
- 关卡目录完整展示十四关，并能进入、退出和恢复进度。
- T0–T10 使用正式规则与观察者安全 DTO 完成教学流程。
- C1–C3 使用关卡专用规则 AI 完成固定挑战，不形成完整人机模式入口。
- 所有必要 Godot headless、规则、信息边界、确定性和响应式测试通过。
- 产物经过技术复核与独立 QA；这不代替 GATE-2 人工批准。
