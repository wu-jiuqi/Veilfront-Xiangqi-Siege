# 正式 LAN UX 流程与预置场景状态机 v1

状态：`producer_complete / pending_technical_binding / pending_independent_qa / no_release_approval`

适用工作项：`TASK-FORMAL-LAN-UX-001`

授权绑定：

- `EXCEPTION-FORMAL-LAN-ASSEMBLY-001@v1`
- 项目所有者批准摘要：`9e65df07d19398a083e8d024336180e37d5fc1fd998829cafc7559e7c04031b1`
- 当前 Loop：`LOOP-CTR-FORMAL-FOUNDATION-GATE2-001@v3`
- 当前实例：`inst:01M02NJ3JENHD8VV7EKC9G198Q`

本文件只细化已批准正式 LAN 范围内的 UX、焦点、状态反馈、错误恢复和信息边界，不改变规则、协议语义、结算优先级、视觉方向或发布范围。

## 1. 结论状态与裁决边界

### 1.1 `confirmed`

- 规则语义继续绑定项目所有者 revision 5；本文件不增加或删除行动、胜负或结算规则。
- 首版 Demo 需要完整人对人联机；本里程碑只完成桌面局域网双人闭环，不等于互联网完成或发布候选。
- 房主为唯一权威端，peer 1 持有权威应用；房主席位为赤方，远端客户端席位为玄方。
- 双端 Presentation 只消费各自经过正式 codec 校验的观察者安全批次；客户端不得持有 `FullState`、规则 seed、隐藏旗位或隐藏棋子。
- 正式对局必须复用 `scenes/game/match/match_screen.tscn`、正式二维棋盘、正式雾层和新版 HUD，不再以 `gate1_logic_lab` 作为比赛场。
- 红黑双方都令己方大本营位于屏幕底部；镜像只影响表现，不改变权威坐标或行动语义。
- 固定 UI 结构优先使用预置 `Control`、`Container`、场景实例和 Theme；运行时只实例化数量由观察者安全数据决定的棋子、旗帜、虚影和临时反馈。

### 1.2 `hypothesis`

- 具体正式 LAN 组合根文件名、场景持久化方式、ENet 生命周期适配器和状态快照内部结构仍属于确定性实现架构 `hypothesis`，需要技术实现与测试证明。
- 本文件中的逻辑节点名是接线合同；技术负责人可在批准根目录内调整物理路径，但不得改变玩家可见状态、焦点、错误恢复或信息边界。
- GATE-1 只证明确定性核心、PlayerView、回放和原型 LAN 的可行性，不等于当前正式 LAN 组合已经验收。

### 1.3 `unknown / open`

- 单局完整轮上限仍是开放问题。HUD 只能显示当前 `PlayerView.round_limit_public`，不得在 UX 中把默认值或测试值宣布为最终平衡决定。
- 回合计时具体值不在当前项目简报的已确认规则中。V3 大厅 `RulesPanel` 美术中烘焙的“每回合 90 秒”不能作为权威事实；正式大厅必须以预置动态文字覆盖该行，显示权威会话公开配置，未配置时显示“回合计时：以战局配置为准”。
- 动画帧数、完整音频/VFX、最终 UI 皮肤和高成本美术细节仍未获批准；本工作只复用现有成果并完成兼容接入。

## 2. 现状审计与必须修正的断点

| 区域 | 已有事实 | 正式 LAN 要求 |
|---|---|---|
| 启动 | `project.godot` 入口为 `start_screen.tscn`；点击、触摸或 `ui_accept` 播放 `opening_sequence` | 原样复用；转换期间屏蔽重复输入 |
| 主菜单 | 启动页内实例化 `start_menu_overlay.tscn`，动画结束后聚焦 `%LanButton` | 作为正式首选菜单；LAN 返回必须直接进入菜单可操作态 |
| 独立菜单 | `main_menu.tscn` 是当前原型大厅返回目标，视觉与启动页内嵌菜单并非同一流程 | 不得无条件作为正式返回目标；只有证明与正式菜单状态/视觉等价时才可替代 |
| LAN 路由 | `FrontendRoutes.LAN_LOBBY_SCENE` 仍指向 `scenes/prototype/network/lan_lobby.tscn` | 切换到正式 LAN 组合根；prototype 保留为回归基线 |
| V3 大厅 | 已有切片、地址、席位、状态和创建/加入/离开按钮 | 复用大厅视觉与预置节点；增加显式准备和房主开局门槛 |
| 原型大厅行为 | 房主和加入者被自动标为已准备；收到 PlayerView 后自动显示 `NetworkBoard` | 正式版禁止这两项自动行为 |
| 原型比赛场 | `NetworkBoard` 实例化 `gate1_logic_lab.tscn` | 不复用；由正式 `MatchScreen` 替换 |
| 正式对局 | `match_screen.tscn` 已含 HUD V2、棋盘、Marker、确认面板和 TerminalDialog | 作为唯一比赛表现壳；通过 `ApplicationHost + MatchClientPort` 驱动 |
| 正式迷雾 | `FogOverlay` 只接收 `visible_cells`、`hidden_detection_cells`、观察者 side 和 cell size | 原样维持输入边界；不得增加敌方视野源或隐藏节点 |
| 小地图 | `TacticalMinimap` 复用 BoardWorld 并只渲染传入 PlayerView | 原样维持；不能使用全图权威状态 |

## 3. 场景组合与预置节点合同

### 3.1 启动与菜单

必须复用：

- `scenes/game/frontend/start_screen.tscn`
  - `StartScreen`
  - `PromptArea/EnterPrompt`
  - `%PromptAnimation`
  - `%SequencePlayer`
  - `%MenuOverlay`
- `scenes/game/frontend/start_menu_overlay.tscn`
  - `%LanButton`
  - `%LevelModeButton`
  - `%SettingsButton`
  - `%CommunityButton`
  - `%QuitButton`
  - `%NoticeDialog`
  - `%QuitDialog`
  - `%FatalErrorDialog`

返回菜单的玩家可见结果必须是 `MAIN_MENU_READY`：菜单已显示、按钮可操作、焦点落在 `%LanButton`。不得重新显示“点击任意位置继续”或重播 4.85 秒开门动画。

实现方式属于技术 `hypothesis`，可选择持久化 Frontend 根、返回时传入公开路由状态，或使用与内嵌菜单完全等价的预置菜单场景；不可为了接线方便造成两套不一致主菜单体验。

### 3.2 正式 LAN 大厅

正式大厅固定结构必须使用预置节点。逻辑树如下；物理场景路径由技术负责人在批准根目录内确定：

```text
FormalLanLobby (Control, Full Rect)
├─ UiThemeBinder (instance)
├─ LobbyChrome (Control, Full Rect)
│  ├─ BattlefieldBackdrop (TextureRect)
│  ├─ BackdropShade (ColorRect)
│  ├─ HeaderFrame (TextureRect)
│  ├─ HeaderStatusBacking (TextureRect)
│  ├─ ConnectionBars (TextureRect)
│  ├─ ConnectionStatus (Label)
│  ├─ ReturnToMainMenuButton (BaseButton)
│  ├─ RoomInfoPanel (TextureRect)
│  ├─ RoomCodeBacking (TextureRect)
│  ├─ RoomCodeValue (Label)
│  ├─ AddressBacking (TextureRect)
│  ├─ AddressInput (LineEdit)
│  ├─ PortInput (SpinBox, hidden technical input)
│  ├─ CopyAddressButton (BaseButton)
│  ├─ VersusPanel (TextureRect)
│  ├─ RedStateBacking (TextureRect)
│  ├─ RedReadyState (Label)
│  ├─ BlackStateBacking (TextureRect)
│  ├─ BlackPlayerName (Label)
│  ├─ BlackReadyState (Label)
│  ├─ RulesPanel (TextureRect)
│  ├─ RulesTurnClockValue (Label, dynamic authority-public text)
│  ├─ StatusPanel (TextureRect)
│  ├─ StatusValue (Label)
│  ├─ SeatValue (Label, may remain visually hidden but must be inspectable)
│  ├─ ActionGroup (TextureRect)
│  ├─ DisconnectButton (BaseButton)
│  ├─ JoinButton (BaseButton)
│  ├─ HostButton (BaseButton)
│  ├─ ReadyButton (Button/BaseButton)
│  └─ StartButton (Button/BaseButton, host only)
├─ LeaveSessionDialog (ConfirmationDialog)
├─ ConnectionErrorDialog (AcceptDialog)
└─ FatalErrorDialog (AcceptDialog)
```

`ReadyButton` 和 `StartButton` 必须是场景内预置节点，不在脚本中动态创建。它们复用 `ActionGroup` 的布局、现有 Theme 和按钮状态语言；不要求新增高成本美术。若现有 V3 按钮文字已烘焙在贴图内，新节点使用 Theme 化动态文字按钮，不能把“创建房间”贴图错误复用于“确认准备/开始战局”。

正式大厅不得包含或实例化：

- `scenes/prototype/network/lan_network_session.tscn`
- `scenes/prototype/gate1_logic_lab.tscn`
- 原型 `NetworkBoard`
- 原型 `BackToLobbyButton`
- 任何规则 seed、RNG 控件或 `FullState` 调试字段

### 3.3 必须复用的 V3 切片

以下运行时切片和对应正常/悬停/按下/禁用态必须保留，不得改回整屏母版：

- `header_frame.png`
- `header_status_backing.png`
- `return_button*.png`
- `connection_bars.png`
- `room_info_panel.png`
- `room_value_backing.png`
- `copy_address_button*.png`
- `versus_panel.png`
- `red_status_backing.png`
- `black_status_backing.png`
- `rules_panel.png`
- `status_panel.png`
- `action_group.png`
- `disconnect_button*.png`
- `join_button*.png`
- `host_button*.png`
- `lan_lobby_board_backdrop_v1.png`

`lan_lobby_full_plate_v2.png` 只作为离线切片母版，不得作为运行时整屏节点。

### 3.4 正式对局

必须复用：

- `scenes/game/match/match_screen.tscn`
  - `%MatchHudV2`
  - `%MarkerMenu`
  - `%ActionConfirmationPanel`
  - `TutorialOverlayHost`（LAN 中保持不接收输入）
  - `TerminalDialog`
- `scenes/game/ui/match_hud_v2.tscn`
  - `BoardFrame/BoardViewport`
  - `FactionLeft/ReturnButton`
  - `FactionRight/MirrorButton`
  - `ObjectiveEvents/SelectionStatus`
  - `ObjectiveEvents/BoardPosition`
  - `ObjectiveEvents/MessageValue`
  - `ObjectiveEvents/PassButton`
  - `PieceInfoDrawer` 及 Move/Bombard/Resurrect 按钮
  - `Minimap/TacticalMinimap`
  - `IncenseTurnClock`
- `scenes/game/match/board/fog_overlay.tscn`
- `scenes/game/ui/action_confirmation_panel.tscn`
- `scenes/game/ui/terminal_dialog.tscn`

LAN 模式覆盖：

- `ReturnButton` 必须可见，文字为“离开对局”；触发离开确认，不直接切场景。
- `MirrorButton` 必须隐藏且禁用。双端进入对局时将表现 side 固定为本地 `viewer_side`，保证己方大本营始终在底。
- `TerminalDialog/RestartButton` 必须隐藏且禁用；正式 LAN v1 不允许客户端直接调用本地重开。
- `TerminalDialog` 的确认按钮文字为“返回房间”。确认后完整清理本局网络对象并回 `LOBBY_IDLE`，再次对局需重新创建/加入，避免残留 peer、预览或权威状态。
- 切入新比赛前先清空旧 `PlayerView`、预览、选择、标记、Terminal 和 HUD 文本，再显示过渡遮罩；第一份通过 codec 且 `viewer_side` 与席位一致的批次到达后才移除遮罩。

## 4. 顶层 UX 状态枚举

状态名是表现合同，不要求网络层使用同名枚举。

| 状态 | 进入条件 | 玩家可见结果 | 合法下一状态 |
|---|---|---|---|
| `START_PROMPT` | 应用启动 | 显示“点击任意位置继续” | `START_OPENING` |
| `START_OPENING` | 点击/触摸/`ui_accept` | 播放开门；重复输入无效 | `MAIN_MENU_ENTERING` |
| `MAIN_MENU_ENTERING` | 开门完成并 reveal menu | 菜单淡入，所有菜单按钮暂禁用 | `MAIN_MENU_READY` |
| `MAIN_MENU_READY` | 菜单动画完成或从 LAN 返回 | 菜单可操作，聚焦联机入口 | `LOBBY_IDLE` 或其他既有菜单路由 |
| `LOBBY_IDLE` | 进入正式大厅或完整清理会话 | 可编辑地址，可创建或加入 | `HOST_OPENING` / `JOIN_CONNECTING` / `MAIN_MENU_READY` |
| `HOST_OPENING` | 点击创建 | 建立本地 ENet 房主，锁定地址 | `HOST_WAITING_PEER` / `CONNECTION_ERROR` |
| `HOST_WAITING_PEER` | 房主建立成功 | 赤方已入席，等待玄方 | `ROOM_SEATED` / `PEER_DISCONNECTED` / `LOBBY_IDLE` |
| `JOIN_CONNECTING` | 点击加入 | 连接并验证协议，锁定重复操作 | `ROOM_SEATED` / `CONNECTION_ERROR` / `LOBBY_IDLE` |
| `ROOM_SEATED` | 双方席位和协议均确认 | 双方显示未准备 | `ROOM_READY_PARTIAL` / `ROOM_READY_BOTH` / `PEER_DISCONNECTED` |
| `ROOM_READY_PARTIAL` | 仅一方准备 | 明确显示谁已准备 | `ROOM_SEATED` / `ROOM_READY_BOTH` / `PEER_DISCONNECTED` |
| `ROOM_READY_BOTH` | 红玄均显式准备 | 房主可开局；客户端等待房主 | `MATCH_STARTING` / `ROOM_READY_PARTIAL` / `PEER_DISCONNECTED` |
| `MATCH_STARTING` | 房主点击开始且权威端接受 | 全部大厅动作锁定，显示开局进度 | `MATCH_LOCAL_TURN` / `MATCH_REMOTE_TURN` / `CONNECTION_ERROR` |
| `MATCH_LOCAL_TURN` | 本地 side 等于 `active_side` | 正式行动控件按 PlayerView 开放 | `MATCH_PREPARING` / `MATCH_REMOTE_TURN` / `MATCH_TERMINAL` |
| `MATCH_REMOTE_TURN` | 本地 side 不等于 `active_side` | 行动控件禁用，仍可浏览和私有标记 | `MATCH_LOCAL_TURN` / `MATCH_TERMINAL` / `PEER_DISCONNECTED` |
| `MATCH_PREPARING` | 已请求公开预览或准备动作 | 显示安全预览，允许取消 | `MATCH_CONFIRMING` / `MATCH_LOCAL_TURN` / `PEER_DISCONNECTED` |
| `MATCH_CONFIRMING` | 权威端确认 prepared preview | 显示确认面板，焦点在取消 | `MATCH_SUBMITTING` / `MATCH_LOCAL_TURN` / `PEER_DISCONNECTED` |
| `MATCH_SUBMITTING` | 玩家确认并发送规范化意图 | 锁定重复提交，等待权威批次 | `MATCH_LOCAL_TURN` / `MATCH_REMOTE_TURN` / `MATCH_TERMINAL` / `PEER_DISCONNECTED` |
| `MATCH_TERMINAL` | 本地合法 PlayerView 的 `terminal=true` | 结算对话框显示 winner/reason | `LOBBY_IDLE` |
| `CONNECTION_ERROR` | 建房/连接/协议/codec/场景绑定失败 | 阻断错误反馈；先清理再恢复 | `LOBBY_IDLE` / `MAIN_MENU_READY` |
| `PEER_DISCONNECTED` | 任一方在房间或比赛中失联 | 本局立即中止，不转单机 | `LOBBY_IDLE` |

不得存在从 `HOST_WAITING_PEER`、`ROOM_SEATED` 或 `ROOM_READY_PARTIAL` 自动进入 `MATCH_STARTING` 的路径。收到首份 PlayerView 也不能绕过双方准备与房主开局。

## 5. 大厅按钮、焦点与状态文本矩阵

符号：`E` 可用，`D` 可见但禁用，`H` 隐藏且禁用，`L` 锁定只读。

| 状态 | 地址 | 复制 | 创建 | 加入 | 离开/取消 | 准备 | 房主开局 | 返回菜单 | 首选焦点 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| `LOBBY_IDLE` | E | E | E | E | D | H | H | E | `HostButton` |
| `HOST_OPENING` | L | E | H | H | E | H | H | E | `DisconnectButton` |
| `HOST_WAITING_PEER` | L | E | H | H | E | H | H | E | `CopyAddressButton` |
| `JOIN_CONNECTING` | L | D | H | H | E | H | H | E | `DisconnectButton` |
| `ROOM_SEATED` | L | 房主 E / 客户端 D | H | H | E | E | 房主 D / 客户端 H | E | `ReadyButton` |
| `ROOM_READY_PARTIAL` | L | 房主 E / 客户端 D | H | H | E | E | 房主 D / 客户端 H | E | `ReadyButton` |
| `ROOM_READY_BOTH` | L | 房主 E / 客户端 D | H | H | E | E | 房主 E / 客户端 H | E | 房主 `StartButton` / 客户端 `ReadyButton` |
| `MATCH_STARTING` | L | D | H | H | D | D | D/H | D | 无；保持进度播报 |

补充约束：

- `%HostButton`、`%JoinButton` 是互斥入口。一旦开始建房或加入，二者必须隐藏，而不只是保持可见禁用。
- `%ReadyButton` 是显式 toggle：未准备显示“确认准备”，已准备显示“取消准备”。每次请求发出后先禁用，直到权威大厅快照确认，防止本地 UI 假定成功。
- `%StartButton` 只在房主端、双方已入席时可见；只在双方权威准备状态均为 true 时可用。
- `%ReturnToMainMenuButton` 在大厅期间保持可用，但联网状态点击后必须先弹 `LeaveSessionDialog`。默认焦点在“取消”，确认才清理 peer 并返回。
- 连接失败恢复到 `LOBBY_IDLE` 时，聚焦 `%AddressInput` 并全选地址，便于修正；建房端口占用错误则聚焦 `%HostButton`。
- TextureButton 必须有可见键盘焦点态；如果切片没有焦点贴图，使用 Theme outline，不以鼠标悬停态冒充焦点态。

### 5.1 精确状态文案

| 状态 | 顶部状态 | 主状态栏 | 席位文案 |
|---|---|---|---|
| `LOBBY_IDLE` | 等待联机 | 等待创建或加入房间 | 赤方 · 等待入席 / 玄方 · 等待入席 |
| `HOST_OPENING` | 创建中 | 正在创建局域网房间… | 赤方房主 · 建立中 |
| `HOST_WAITING_PEER` | 房间开放 | 房间已创建，等待同袍加入 | 赤方 · 未准备 / 玄方 · 等待入席 |
| `JOIN_CONNECTING` | 连接中 | 正在连接房主… | 赤方房主 · 验证中 / 玄方 · 连接中 |
| 协议验证 | 验证中 | 已连接，正在验证房间协议… | 不提前显示已准备 |
| `ROOM_SEATED` | 整备中 | 双方已入席，请确认准备状态 | 赤方 · 未准备 / 玄方 · 未准备 |
| `ROOM_READY_PARTIAL` | 整备中 | 等待另一方确认准备 | 分别显示已准备/未准备 |
| `ROOM_READY_BOTH` 房主 | 可以开局 | 双方已准备，可以开始战局 | 双方均显示已准备 |
| `ROOM_READY_BOTH` 客户端 | 等待开局 | 双方已准备，等待房主开局 | 双方均显示已准备 |
| `MATCH_STARTING` | 开局中 | 正在创建正式战局… | 保留席位，不显示规则 seed |

状态栏不得显示 peer ID、规则 seed、隐藏旗位、敌方视野源或任何内部错误堆栈。

## 6. 双端差异

| 项目 | 房主（赤方） | 客户端（玄方） |
|---|---|---|
| 权威职责 | peer 1 独占正式权威应用 | 只持有远端 MatchClientPort 与观察者安全批次 |
| 大厅地址 | 显示并可复制本机 `IPv4:port` | 输入房主地址；入席后锁定，不提供复制为房主邀请 |
| 席位 | `赤方（房主）` | `玄方（加入者）` |
| 准备 | 显式准备/取消准备 | 显式准备/取消准备 |
| 开局 | 双方准备后唯一可点击 `StartButton` | 从不显示开局按钮，只显示等待房主 |
| 对局视角 | 赤方大本营在底 | 玄方大本营在底 |
| 对局数据 | UI 仍必须通过赤方自己的 codec 批次，不得直读权威对象 | 只接收玄方批次 |
| 对手掉线 | 本局中止，关闭权威应用并回空大厅 | 房主掉线，本局中止并回空大厅 |

同进程房主的 UI 不能因为与权威应用共处一个进程就获得额外字段。房主和客户端必须走同一种 PlayerView/VisibleEvent/VisibleError/ActionPreview 解码与发布边界。

## 7. 正式对局交互状态

### 7.1 本地回合

进入 `MATCH_LOCAL_TURN` 时：

- `MoveButton`、`BombardButton`、`ResurrectButton`、`PassButton` 是否可用只由当前 PlayerView 和正式 ActionPreview 决定。
- 默认行动模式为普通移动；焦点不强制抢离棋盘，键盘用户可从行动栏进入。
- 选择己方棋子后进入 `SELECTED`，请求当前模式的公开预览。
- 选择目标后进入 `PREVIEW_SELECTED`，等待 port 确认 prepared preview。
- prepared preview 确认后显示 `%ActionConfirmationPanel` 并进入 `MATCH_CONFIRMING`。
- 确认面板打开时焦点默认落在 `%CancelButton`；`ui_cancel` 等价于取消，只有显式激活 `%ConfirmButton` 才提交。
- 普通移动、炮击、士献祭、主动跳过都经过同一准备/确认/提交链。不得为 LAN 绕过正式 MatchScreen 确认语义。
- 确认后进入 `MATCH_SUBMITTING`，清除可重复激活的本地确认控件，显示“行动已送达房主，等待权威确认…”。

### 7.2 对手回合

进入 `MATCH_REMOTE_TURN` 时：

- 所有行动模式、跳过和确认控件禁用。
- 仍允许平移、缩放、浏览小地图和使用玩家本地私有标记。
- 状态栏显示“等待对方行动”，不能显示对手正在选择的棋子、目标、预览、确认状态或输入时机。
- 不播放由未授权对手行动推导的局部音效、碰撞反馈或路径高亮。

### 7.3 权威拒绝与恢复

- `stale_intent`、`invalid_request`、重复 request ID 或过期 `action_index` 不得重复结算。
- 收到合法 `VisibleError` 后，关闭提交锁，清理过期预览，依据最新 PlayerView 回到 `MATCH_LOCAL_TURN` 或 `MATCH_REMOTE_TURN`。
- 对 `TENTATIVE` 预览被拒绝，只显示观察者安全的通用原因；不得通过颜色、延迟、音效或文案透露隐藏阻挡棋子身份与位置。
- codec 失败、viewer side 不匹配、action index 回退或批次不相干属于会话安全错误，进入 `CONNECTION_ERROR` 并中止本局，不能继续使用旧视图。

## 8. 终局、主动返回与断线

### 8.1 正常终局

只有本地 codec 验证后的 PlayerView 同时满足 `terminal=true` 才显示 `TerminalDialog`。文案只使用本地 PlayerView 的 `winner` 与 `win_reason`：

- 本地 side 等于 winner：`胜利`
- 对手 side 等于 winner：`败北`
- winner 为 `draw`：`和局`
- 详细原因使用公开 message key 映射，不显示内部规则栈或 seed

终局时关闭行动、确认、MarkerMenu 和倒计时提交；保留棋盘最终观察者安全画面。`RestartButton` 隐藏。点击“返回房间”后完整关闭本局 peer/权威应用并回 `LOBBY_IDLE`，双方需要重新创建和加入才能再次开局。

### 8.2 主动离开大厅

- `LOBBY_IDLE` 点击返回：直接回 `MAIN_MENU_READY`。
- 已建房、连接中或已入席点击返回：弹确认“离开将关闭当前局域网会话”。默认焦点为取消。
- 确认后先标记为本地主动离开，再清 client port、权威应用、MultiplayerPeer、准备状态和席位，最后返回菜单。
- 本地主动离开不再向本地显示“服务器断开”错误；远端按 peer/server disconnected 处理。

### 8.3 主动离开对局

- HUD `ReturnButton` 点击后弹确认“离开将中止本局，且当前版本不支持断线重连”。默认焦点为取消。
- 确认后关闭 ActionConfirmationPanel、MarkerMenu、TerminalDialog、计时提交和所有本地预览；再断开网络。
- 房主离开：客户端显示“房主已离开，战局已中止”。
- 客户端离开：房主显示“同袍已离开，战局已中止”。
- 双端最终均回 `LOBBY_IDLE`；不继续单机、不自动补位、不自动重连、不迁移房主。

### 8.4 意外断线

处理顺序固定为：

1. 立即禁用全部可提交控件，拒绝新 Intent。
2. 关闭 ActionConfirmationPanel、MarkerMenu、TerminalDialog 和倒计时提交。
3. 清空 prepared preview、ActionPreview、本地选择、旧 PlayerView 引用和 MatchClientPort 绑定。
4. 关闭/清理 MultiplayerPeer；房主同时销毁本局权威应用。
5. 切回 LobbyChrome，不显示旧比赛画面。
6. 显示 `ConnectionErrorDialog`，文案区分房主离开、同袍离开、协议错误或连接失败。
7. 确认错误对话后进入 `LOBBY_IDLE`，恢复创建/加入；房主默认焦点 `HostButton`，客户端默认焦点 `AddressInput`。

任何端在清理完成前不得再次建房或加入。连接事件晚到时必须被旧会话 generation/request ID 丢弃，不能使已返回菜单的 UI 重新进入比赛。

## 9. 错误恢复矩阵

| 错误 | 玩家文案 | 是否保留输入 | 恢复目标 |
|---|---|---|---|
| 地址为空/端口格式错误 | 地址或端口无效，请检查后重试 | 保留并全选地址 | `LOBBY_IDLE` |
| 房主端口占用 | 创建失败：端口已被占用 | 保留端口 | `LOBBY_IDLE` |
| 连接超时/不可达 | 无法连接房主，请检查局域网地址 | 保留地址 | `LOBBY_IDLE` |
| 房间满/席位占用 | 房间拒绝加入：席位已满 | 保留地址 | `LOBBY_IDLE` |
| 协议版本不匹配 | 联机版本不一致，连接已关闭 | 保留地址，不显示内部 schema 内容 | `LOBBY_IDLE` |
| viewer side/codec 批次无效 | 收到无效战局数据，连接已安全关闭 | 不保留对局数据 | `LOBBY_IDLE` |
| 开局前对手离开 | 对方已离开，房间已关闭 | 地址可保留 | `LOBBY_IDLE` |
| 对局中远端离开 | 对方已离开，本局已中止 | 不保留本局状态 | `LOBBY_IDLE` |
| 正式场景加载失败 | 无法打开正式战局，请返回主菜单 | 不创建/继续权威局 | `MAIN_MENU_READY` |
| 过期/重复行动请求 | 行动状态已更新，请重新选择 | 保留最新 PlayerView | 当前合法回合态 |

错误文案必须是观察者安全的白名单文案，不能直接显示内部异常、路径、RPC 参数、seed、FullState 摘要或隐藏事实。

## 10. 无信息泄露合同

### 10.1 UI 可消费字段

正式对局 UI 只可消费：

- codec 校验后的 `PlayerView`
- codec 校验后的 `VisibleEvent[]`
- codec 校验后的 `VisibleError`
- codec 校验后的 `ActionPreview[]`
- 公开大厅状态：协议兼容、角色、local seat、双方在席/准备、can_start、公开 endpoint
- 本地纯表现状态：焦点、摄像机、缩放、私有 marker、当前本地选择、对话框可见性

`PlayerView` 内的 `round_limit_public` 是显示值，不是 UX 固定规则；`hidden_detection_cells` 只能驱动当前观察者获授权的雾中探测提示，不得生成敌棋轮廓或身份。

### 10.2 禁止进入 UI、节点或下行批次的信息

- `FullState` 或其摘要
- match seed、规则 seed、RNG 状态、随机消费次数或可反推随机结果的数据
- 未发现旗帜坐标、隐藏棋子、隐藏马、敌方视野源、敌方合法行动集合
- 对手正在选中的棋子、目标、prepared preview、鼠标位置或私有 marker
- 可由音效、粒子、碰撞体、导航、tooltip、合法落点、加载时序或节点数量反推的隐藏事实
- 未经 PlayerView 授权的旗帜、棋子、接触情报或虚影节点；不是“创建后隐藏”，而是不得创建

### 10.3 主棋盘、雾层与小地图

- `BoardWorld`、`FogOverlay` 和 `TacticalMinimap` 必须接收同一端、同一 action index 的 PlayerView。
- 主棋盘和小地图不得分别请求不同权限的数据源。
- FogOverlay 只使用 `visible_cells` 和 `hidden_detection_cells` 构建 mask；视觉噪声不得使用规则 seed。
- 未授权棋子和旗位在 PieceLayer、FlagViews、小地图、tooltip、碰撞/输入节点和无障碍文本中均不存在。
- 已发现旗帜记忆、双方公开阵亡记录和经授权 capture ghost 可以按 PlayerView 显示；不得因为“迷雾安全”错误删除正式规则已授权的公开信息。
- 私有 marker 永不发送给对手或权威规则核心；断线或新局开始时清空。
- 切换局、切换席位或重新绑定 port 时先清空旧观察者表现，避免一帧跨观察者泄露。

### 10.4 预览与错误

- 只绘制 ActionPreview 白名单字段提供的目标、分类和公开 message key。
- `KNOWN_ILLEGAL` 是否显示遵守正式 MatchScreen 配置；不得为调试在正式 LAN 中启用泄露性预览。
- `TENTATIVE` 必须使用统一“待权威确认”表现，不因隐藏阻挡原因产生不同颜色、时长、音效或文案。
- VisibleError 只显示 `public_code/message_key` 的本地化白名单结果。

## 11. 焦点与输入验收

- 所有状态转换后必须存在一个可见、可用且有清晰焦点样式的控件；隐藏或禁用控件不能保留焦点。
- 启动页支持鼠标、触摸和 `ui_accept`；转换期间输入不重复触发。
- 菜单淡入完成和从 LAN 返回时焦点为 `%LanButton`。
- 大厅初始焦点为 `%HostButton`；Tab 顺序为地址 → 复制 → 创建 → 加入 → 返回，按状态跳过隐藏项。
- 席位确认后焦点为 `%ReadyButton`；双方准备后房主焦点移至 `%StartButton`，客户端不抢焦点。
- 连接/开局进度期间不允许焦点落到被禁用的提交按钮。
- 确认行动对话框默认焦点为“取消”；离开会话/对局的破坏性确认也默认焦点为“取消”。
- TerminalDialog 默认焦点为“返回房间”。
- `ui_cancel` 优先级：关闭 MarkerMenu → 取消 prepared/selection → 关闭非破坏性弹窗 → 打开离开对局确认；不能一次按键直接断线。

## 12. 技术接线清单

技术负责人实现时需要明确以下边界：

1. `FrontendRoutes.lan_lobby_scene()` 从 prototype 路由切到正式 LAN 组合根。
2. 正式 Lobby 只发公开用户意图：建房端口、加入 endpoint、准备 toggle、房主开局、断开和返回。Lobby 不生成、不接收、不记录 match seed。
3. 规则 seed 必须由房主 authority/application 内部生成和持有；不能作为 `host_requested(seed, port)` 一类 Presentation 信号参数。
4. 大厅快照必须区分 transport connected、协议验证、席位确认、双方准备和 can_start；不能用单一 connected 代替全部 UX 状态。
5. 双方准备是显式权威大厅状态；本地按钮按请求禁用，收到快照后再反映成功。
6. 房主点击开始后，权威应用只创建一次；客户端不创建权威 FormalMatchApplication。
7. 房主和客户端分别建立绑定 red/black 的 MatchClientPort，并通过各自 codec 批次驱动同一个正式 MatchScreen 接口。
8. MatchScreen 的提交链增加网络 `MATCH_SUBMITTING` 锁，直到相干批次或 VisibleError 返回。
9. `MatchScreen.render_player_view()` 观察到 terminal 时需要正式连接 TerminalDialog；当前场景虽预置对话框，但既有脚本没有完成终局显示接线。
10. `MatchScreen.return_requested` 需要连接 LAN 离开确认；当前 `game_app.tscn` 未连接该信号。
11. LAN 模式强制隐藏 MirrorButton、显示 ReturnButton、隐藏 Terminal RestartButton。
12. 所有返回和错误路径都先 unbind port、关闭 MultiplayerPeer、清理 authority/application，再切状态或场景。

## 13. 黑盒验收清单

### 13.1 UX 闭环

- [ ] 冷启动可完成 `START_PROMPT → MAIN_MENU_READY → LOBBY_IDLE`。
- [ ] 房主创建后仍停在大厅，不因自己的初始 PlayerView 提前进比赛。
- [ ] 客户端加入后双方均显示准确席位，但初始均为未准备。
- [ ] 任何一方未准备时房主不能开局。
- [ ] 双方准备后只有房主出现可用开始按钮；客户端明确显示等待。
- [ ] 双端在第一份合法本地 PlayerView 到达后进入正式 MatchScreen。
- [ ] 双端各至少五个有效动作，回合权、提交锁和焦点反馈明确。
- [ ] 普通移动、普通吃子、炮击、士献祭、跳过、超时和终局都走正式动作/确认链。
- [ ] 至少一次取消确认不会发送动作，也不会残留 prepared preview。
- [ ] 终局返回后可以重新创建、加入、准备和开局。

### 13.2 断线与返回

- [ ] 大厅返回菜单不重播启动开门，焦点回到联机入口。
- [ ] 连接失败可修改原地址后重试，无需重启应用。
- [ ] 房主在大厅离开，客户端得到明确反馈并回空大厅。
- [ ] 客户端在对局离开，房主本局立即中止且不能继续单机。
- [ ] 房主在对局离开，客户端本局立即中止。
- [ ] 断线后 MatchScreen、端口、peer、准备、预览、marker 和权威应用均已清理。
- [ ] 不存在自动重连、房主迁移或断线恢复入口。

### 13.3 双端表现与信息安全

- [ ] 房主赤方、客户端玄方均令己方大本营在底，权威坐标一致。
- [ ] 双端主棋盘和小地图只显示各自 PlayerView；隐藏等价输入产生等价可见表现。
- [ ] 未发现旗位、隐藏棋子、seed、RNG、FullState 和敌方视野源零泄露。
- [ ] 对手回合不显示对方选择、预览、目标或私有 marker。
- [ ] codec/viewer side/action index 异常会中止会话，不继续显示旧画面。
- [ ] 960×540、1280×720、1920×1080 的正式 MatchScreen 中 HUD、雾层、确认面板和返回控件不裁切。
- [ ] 1280×720 下 V3 大厅切片、动态状态、准备和开局按钮保持可读；其他桌面窗口尺寸至少保证关键操作不离屏。

## 14. 不构成的批准

本规格完成不表示：

- 正式 LAN 技术实现已经完成或通过独立 QA；
- GATE-2、GATE-3、GATE-4 或发布批准已经通过；
- Steam Networking、SDR、Relay、NAT 穿透、互联网匹配、账号、聊天、观战、重连、房主迁移或专用服务器获准；
- 回合上限、回合计时、AI 搜索预算或最终美术细节已经冻结；
- 当前工作区内未提交 UI/资源改动可被回退、覆盖或重做。
