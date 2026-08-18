# 正式 Godot 场景组合设计 v1

状态：`producer_complete / pending_iteration_1_review / no_runtime_implementation`

适用工作项：`ITERATION-1-ARCHITECTURE / TASK-ARCH-001 / TASK-SHELL-001`

## 1. 输入绑定与裁决顺序

本设计绑定以下正式输入：

- `docs/architecture/post-gate1-formal-architecture-review-v2.md`：`58e55d7e6e2fb25c04a243017fc8e0230915a36dcc09cacaf7076b10423705f4`
- `docs/architecture/formal-dto-and-trust-boundary-v1.md`：`6f23274810aad5d6f2515bd78b114da16684e38f9abe04e2d59dcfa87fc174f2`
- `docs/architecture/gate1-to-formal-migration-manifest-v1.yaml`：`0502e20a861a550e9845cfa1a10e4b5d94b97d1da884add2d0de70e9fa14daa4`
- `docs/prototype/rules-spec-v1.md`：`34a1d398beaee6610f3d614559a5af7a14abd464e5df4d86ac26aa3824504ddd`
- `LOOP-CTR-FORMAL-FOUNDATION-GATE2-001@v1`：`a26a9b3fdb0d8d06e42a06833a84455d911fea8f72bcedec59d0ae5e620cc205`

两份外部对话只作为设计参考，不是规则或架构事实源。冲突时按以下顺序裁决：项目所有者 revision 5 规则 → 正式 DTO/信任边界 → 迁移 manifest → 本设计 → 外部参考。

### 1.1 对美术参考方案的必要修正

- 正式棋盘为 `X=1..9, Y=1..24` 的 216 个交点，不采用旧参考中的 27×9/243 点。
- 红营 `Y=1..3`、红缓冲区 `Y=4..8`、战区 `Y=9..16`、黑缓冲区 `Y=17..21`、黑营 `Y=22..24`；红墙线 `Y=4`、黑墙线 `Y=21`。
- 旗帜不是美术 RuleSet 中的固定点。运行时只根据当前观察者 `PlayerView.flags` 创建已授权的旗帜或记忆图标。
- Presentation 不读取 domain `RuleSet`。棋盘输入为观察者安全的 `PlayerView.board` 与纯美术 `BoardTheme`。
- 地表变体不得使用规则 seed。v1 只使用 `theme_id + 逻辑坐标` 的固定外观哈希；未来若需要逐局变化，必须新增公开 cosmetic seed 合同。

## 2. 正式路径

```text
res://
├─ scenes/game/
│  ├─ app/game_app.tscn
│  ├─ match/match_screen.tscn
│  ├─ match/board/
│  │  ├─ board_viewport.tscn
│  │  ├─ board_world.tscn
│  │  ├─ fog_overlay.tscn
│  │  ├─ tactical_overlay.tscn
│  │  ├─ marker_overlay.tscn
│  │  ├─ interaction_overlay.tscn
│  │  ├─ piece_view.tscn
│  │  ├─ flag_view.tscn
│  │  ├─ capture_ghost_view.tscn
│  │  └─ wall_view.tscn
│  ├─ ui/
│  │  ├─ match_header.tscn
│  │  ├─ match_status_panel.tscn
│  │  ├─ action_confirmation_panel.tscn
│  │  ├─ marker_menu.tscn
│  │  ├─ terminal_dialog.tscn
│  │  └─ tutorial_overlay.tscn
│  └─ tutorial/tutorial_level.tscn
├─ scripts/game/
│  ├─ contracts/
│  ├─ domain/
│  ├─ application/
│  ├─ projection/
│  ├─ presentation/
│  ├─ tutorial/
│  └─ ports/
├─ resources/game/
│  ├─ ui/formal_graybox_theme.tres
│  ├─ content/boards/ancient_battlefield_board_theme.tres
│  └─ tutorials/
│     ├─ authority/
│     └─ presentation/
└─ tests/game/
   ├─ architecture/
   ├─ contracts/
   ├─ scenes/
   ├─ presentation/
   └─ migration/
```

不创建新的根级 `game/`、`data/` 或 `art/` 目录。美术运行时资源进入既有批准结构 `assets/art/` 和 `resources/game/content/`。

## 3. 应用组合根

`game_app.tscn` 是预置 `Control` 场景，只负责生命周期和依赖注入，不包含规则判断。

```text
GameApp (Control, Full Rect)
├─ Background (ColorRect, mouse_filter=IGNORE)
├─ ApplicationHost (Node)
├─ ScreenHost (Control, Full Rect)
│  └─ MatchScreen (instance)
├─ GlobalOverlayHost (Control, Full Rect, mouse_filter=IGNORE)
│  ├─ TransitionOverlay (ColorRect)
│  └─ FatalErrorDialog (AcceptDialog)
└─ AccessibilityAnnouncer (Label)
```

决定：

- `ApplicationHost` 只是 SceneTree 生命周期适配器；真正的 `MatchApplication`、projector、codec 和 port 使用 `RefCounted`/静态脚本。
- `ApplicationHost` 是唯一可创建并绑定 `MatchClientPort` 的场景节点；`MatchScreen` 不获取 domain 或 projection 实例。
- 正式组合根不 preload prototype、AI、LAN、未来网络 SDK 或权威 replay。
- `GameApp` 根应用 `formal_graybox_theme.tres`，所有 Control 继承 Theme，避免节点级重复皮肤。

## 4. 对局场景与响应式布局

```text
MatchScreen (Control, Full Rect)
├─ Backdrop (ColorRect, IGNORE)
├─ SafeMargin (MarginContainer, Full Rect)
│  └─ Page (VBoxContainer)
│     ├─ MatchHeader (instance)
│     ├─ Workspace (HSplitContainer, EXPAND_FILL)
│     │  ├─ BoardFrame (PanelContainer)
│     │  │  └─ BoardViewport (instance)
│     │  └─ WideStatusHost (PanelContainer)
│     │     └─ MatchStatusPanel (instance, runtime reparent target)
│     └─ CompactActionBar (HBoxContainer)
├─ CompactStatusDrawer (PopupPanel)
│  └─ CompactStatusHost (MarginContainer, runtime reparent target)
├─ MarkerMenu (instance)
├─ ActionConfirmationPanel (instance)
├─ TutorialOverlayHost (Control, IGNORE)
└─ TerminalDialog (instance)
```

响应式规则：

- 基准视口继续使用 `1280×720`、`canvas_items + expand`。
- `>=1100` 逻辑像素使用 `WideStatusHost`；更窄窗口把同一个预置 `MatchStatusPanel` reparent 到 `CompactStatusDrawer`。不动态创建第二套 HUD。
- `BoardFrame` 始终 `EXPAND_FILL`；棋盘摄像机按可用宽度保证九路完整显示，交点 X/Y 间距始终相同。
- HUD 使用 Container、anchor 和最小尺寸，不以绝对 `position` 排版。主要按钮最小高度 44。
- 必测 `960×540`、`1280×720`、`1920×1080`；超宽屏只增加留白和状态区，不显示额外规则信息。

## 5. 棋盘视口与世界场景

### 5.1 视口壳

```text
BoardViewport (SubViewportContainer)
└─ BoardSubViewport (SubViewport)
   └─ BoardWorld (instance)
```

- `SubViewportContainer` 负责把鼠标事件转发给棋盘，Match HUD 不受 Camera2D 变换。
- `BoardSubViewport` 使用透明背景和 2D canvas；尺寸由容器同步。
- `BoardCamera2D` 只处理表现层平移/缩放和双方底部镜像后的定位，不改变权威坐标。

### 5.2 BoardWorld 预置层级

```text
BoardWorld (Node2D)
├─ TerrainLayer (TileMapLayer)
├─ ZoneTintLayer (TileMapLayer)
├─ DecalLayer (TileMapLayer)
├─ GridRenderer (Node2D)
├─ PieceLayer (Node2D)
├─ FogOverlay (instance: Control, IGNORE)
├─ StructureLayer (Node2D, IGNORE)
│  └─ WallViews (Node2D)
├─ IntelLayer (Node2D, IGNORE)
│  ├─ FlagViews (Node2D)
│  └─ ContactViews (Node2D)
├─ CaptureGhostLayer (Node2D, IGNORE)
├─ MarkerOverlay (instance, IGNORE)
├─ TacticalOverlay (instance, IGNORE)
├─ InteractionOverlay (instance, IGNORE)
├─ EffectLayer (Node2D, IGNORE)
├─ InputSurface (Control, STOP, focusable)
└─ BoardCamera2D (Camera2D)
```

绘制顺序固定为：地表与区域色 → 装饰 → 网格 → 棋子 → 迷雾 → 公开墙线/墙状态 → 已发现情报/旗帜记忆 → 阵亡虚影 → 私有标记 → 战术预览 → 选择/确认/错误反馈 → 特效。

这样保证：

- 迷雾遮住未授权的棋子和现场事实。
- 已发现旗帜记忆、己方阵亡虚影和私人标记可在重新入雾后继续显示。
- 标记不会盖住当前选择、高亮、确认目标或错误反馈。
- TacticalOverlay 只绘制 observer-safe `ActionPreview` 与 `PlayerView.vision_overlays`，不计算路径合法性。

## 6. 交点坐标与美术尺寸

- 逻辑坐标始终使用 `[x,y]`，其中 `x=1..9, y=1..24`。
- TileMap 使用零基映射 `Vector2i(x-1,y-1)`；交点位于对应 tile 的中心。
- `BoardTheme.cell_size` v1 默认 `128×128` 世界单位；源图可以按 `256×256` 制作再导出。
- 棋盘完整色块尺寸为 `9×24` cells，即 `1152×3072` 世界单位；网格线实际连接首末交点中心。
- `BoardCoordinateMapper` 是 presentation 内的无状态 `RefCounted` 工具：
  - 红方显示：`display=(x-1,24-y)`，红营在底。
  - 黑方显示：`display=(9-x,y-1)`，黑营在底。
  - 镜像只改变显示坐标，不修改 DTO、Intent 或权威坐标。
- 点击命中以交点为中心的正方形区域判断；X/Y 阈值相同，不再出现长方形格。

## 7. 区域、网格与建筑表现

- `ZoneTintLayer` 仅依据 `PlayerView.board` 的公开区域描述着色，不直接读取规则 Resource。
- 区域之间不画分割线；用亮度、色相与地表材质区分大本营、缓冲区、战区。
- `GridRenderer` 在每个区域内绘制透明大字“大本营 / 缓冲区 / 战区”，字号按区域高度和文字宽度取较小值，禁止越界。
- `Y=4/Y=21` 墙线属于 Structure，不是区域分割线；完整时加粗，倒塌/修复以墙体场景状态表现。
- 城墙、棋子、旗帜、虚影和临时特效使用 PackedScene 运行时实例，因为数量或生命周期取决于 PlayerView；固定 216 点不生成 216 个 Control。

## 8. 迷雾与可见情报

`FogOverlay` 始终是一份预置 Control：

- 灰盒阶段由 `_draw()` 基于 `PlayerView.visible_cells` 绘制黑色遮罩块和柔化边缘。
- 视觉样片阶段可替换为 `9×24` mask texture + CanvasItem Shader；节点和输入合同不变。
- revision 5 没有通用“已探索地形”状态；v1 mask 只区分当前可见与当前入雾。旗帜记忆、阵亡虚影和接触情报由各自经过授权的 PlayerView 字段单独绘制，不能从雾层推导。
- 不创建 216 个雾格 Control，不读取敌方视野源、隐藏马、旗位或规则 seed。
- 可见敌棋由 PlayerView 出现而“穿透”蒙版；未出现在 PlayerView 的棋子不创建对应 PieceView。

## 9. BoardTheme 与资源边界

`BoardTheme` 是只读自定义 Resource，只允许美术字段：

```text
theme_id
cell_size
terrain_tileset
zone_tileset
decal_tileset
grid_palette
region_label_style
wall_scene_set
piece_scene_set
flag_scene
ghost_scene
marker_assets
fog_material
effect_scenes
```

禁止字段：旗位、墙合法性、可行动点、视野真值、阵亡池、复活候选、seed/RNG、actor/viewer 选择或 FullState 引用。

Presentation 组合公式为：

```text
BoardPresentation = current observer PlayerView + read-only BoardTheme + local UI state
```

不是 `RuleSet + BoardTheme`。

## 10. 教学场景

```text
TutorialLevel (Control, Full Rect)
├─ ApplicationHost (Node, tutorial session mode)
├─ MatchScreen (instance)
└─ TutorialOverlay (instance)
```

教学 Resource 物理拆分：

- `resources/game/tutorials/authority/*.tres`：固定初始局面引用、规则 seed、绑定 viewer、允许 Intent 策略和脚本化行动；只由 application 加载。
- `resources/game/tutorials/presentation/*.tres`：步骤 ID、提示 key、公开高亮、可跳过/重试文案；只含观察者安全信息。

`TutorialDirector` 不持有 authority Resource，只接收 application 发布的当前安全步骤、PlayerView、VisibleEvent、VisibleError 和 ActionPreview。脚本化敌方行动仍由 application 生成 NormalizedIntent 并经 domain 结算。

## 11. 预置与动态实例边界

| 对象 | 方式 | 理由 |
|---|---|---|
| GameApp、MatchScreen、BoardViewport、BoardWorld、HUD、Overlay | `.tscn` 预置 | 固定结构、需 Inspector 审查和 headless load |
| Theme、BoardTheme、教学定义 | `.tres` 预置 | 只读配置、可审查 |
| 棋子、已授权旗帜、墙段、虚影、临时轨迹、特效 | PackedScene 实例 | 数量/生命周期来自当前 PlayerView |
| 216 个交点、216 个雾格 | 不创建节点 | 由 TileMap/custom draw/mask 表达 |
| FullState、DTO、codec、application/domain/projection | RefCounted/静态脚本 | 不需要 SceneTree 生命周期 |

## 12. 场景级验收

- 三个正式场景 `game_app.tscn`、`match_screen.tscn`、`tutorial_level.tscn` 可由 Godot 4.7.1 headless 加载。
- 正式 `.tscn/.gd` 不 preload prototype、AI、LAN 或网络 SDK。
- 黑/红视角均保持己方大本营在底，权威坐标摘要不因镜像变化。
- 9×24 交点 X/Y 屏幕间距相等；三个必测分辨率无 HUD、按钮、提示、迷雾或高亮裁切。
- 未发现旗帜不创建节点；发现后即使重新入雾仍显示记忆图标。
- Marker 位于 Fog 之上、Interaction 之下；选中状态右键先取消，未选中状态右键才打开 MarkerMenu。
- FogOverlay 只有一个预置绘制节点；固定 UI 树无 216 节点展开。
