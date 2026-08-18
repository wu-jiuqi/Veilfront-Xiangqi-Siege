# 正式运行时接口与信号图 v1

状态：`producer_complete / pending_iteration_1_review / no_runtime_implementation`

## 1. 核心边界

```text
Input/HUD/Tutorial
        │ observer-safe requests only
        ▼
MatchClientPort（已绑定会话，不接受 viewer 参数）
        ▼
Application（唯一 FullState owner + SeatContext/viewer）
      ├────────► Domain
      └────────► Projection
                    │
                    ▼
PlayerView / VisibleEvent / VisibleError / ActionPreview
```

Presentation、TutorialDirector 和未来 endpoint 均不得：

- 传入或切换 `viewer_side`；
- 读取 FullState、DomainEvent、DomainError、RNG、AuthoritativeReplay；
- 直接调用 projector；
- 根据隐藏原因返回不同提示、字段或时序；
- 通过全局 EventBus 广播观察者 DTO。

观察者 DTO 只由 `ApplicationHost → MatchScreen` 的实例级连接传递，避免跨会话或跨席位订阅。

## 2. MatchClientPort 公共接口

`MatchClientPort` 为每个本地会话创建一个绑定实例。Presentation 不构造 SeatContext，也不提交 actor/viewer 字段。

### 2.1 下行信号

| 信号 | 载荷 | 消费者 | 约束 |
|---|---|---|---|
| `session_state_changed` | public session state | MatchScreen/HUD | 不含 authority 状态 |
| `player_view_updated` | PlayerView v1 | MatchScreen/Board/HUD/Tutorial | 当前绑定 viewer 唯一快照 |
| `visible_events_received` | VisibleEvent v1 array | HUD/Effects/Tutorial | per-viewer 连续序号 |
| `visible_error_received` | VisibleError v1 | Confirm/HUD/Tutorial | 隐藏失败统一外形 |
| `action_previews_updated` | ActionPreview v1 array | Board/Tutorial | 只按 PlayerView 计算 |
| `prepared_action_changed` | preview_id 或空 | Confirm panel | 只引用既有 ActionPreview，不新增规则字段 |

下行提交顺序：

1. `player_view_updated`
2. `visible_events_received`
3. `visible_error_received`（若存在）
4. `action_previews_updated`
5. `prepared_action_changed`

消费者按 `action_index` 丢弃过期数据。ObserverReplay frame 使用同一批次的 canonical DTO 字节，不从 UI 状态反向生成。

### 2.2 上行方法

| 方法 | 参数 | 结果 |
|---|---|---|
| `request_action_previews(piece_id, action_type)` | 公开 piece ID、公开 action type | 异步发 `action_previews_updated` |
| `prepare_action(preview_id)` | 当前 ActionPreview ID | application 缓存待确认草案并发 `prepared_action_changed` |
| `confirm_prepared_action(preview_id)` | 当前待确认 preview ID | application 创建 confirmation token 与 NormalizedIntent，再进入 domain |
| `cancel_prepared_action()` | 无 | 清除待确认草案，不提交 Intent、不消耗行动 |
| `request_skip()` | 无 | application 创建允许的 skip Intent |
| `request_restart()` | 公开重置请求 | 仅本地/教学会话策略允许时重建会话 |

`prepare_action/confirm_prepared_action` 的设计目的：Presentation 只引用投影已授权的 preview，不自行猜测隐藏合法性，也不需要接触 confirmation token。application 内部生成的 NormalizedIntent 仍严格使用 `veilfront-intent-v1`，actor 由 SeatContext 推导。

未来远程端口可以把这些请求编码为网络消息，但本循环只实现进程内 port 和测试替身。

## 3. Application 内部接口

### 3.1 所有权

- `MatchSession` 持有唯一活动 FullState 引用。
- Domain resolver 只在 `MatchSession` 事务窗口内获得状态工作副本或受控 mutable handle。
- 成功结算后原子替换活动 state；失败且不消耗行动时丢弃工作副本。
- Projection 只接收事务完成后的深只读快照；不得保存跨回合引用。
- DTO codec 必须深复制数组/字典，Presentation 无法通过别名修改 FullState。

### 3.2 内部方法方向

```text
MatchApplication
├─ create_session(trusted_setup, SeatContext)
├─ request_previews(bound_session, public_request)
├─ prepare_action(bound_session, preview_id)
├─ submit_prepared_action(bound_session, preview_id)
└─ publish_observer_frame(bound_session)

MatchSession
├─ begin_transaction()
├─ resolve(NormalizedIntent)
├─ commit(TransitionResult)
└─ snapshot_for_projection()

ProjectionGateway（application 内部可见）
├─ project_player_view(read_only_state, ViewerContext)
├─ project_visible_events(raw_events, before/after view, ViewerContext)
├─ project_visible_error(domain_error, ViewerContext)
└─ build_action_previews(PlayerView, public_rules)
```

`ProjectionGateway` 没有公开 `get_view(side)`；ViewerContext 只能由 application 创建。

## 4. 场景信号与方法方向

遵循“子节点信号向上、父节点方法向下”。

| 发送者 | 信号 | 接收者 | 父级调用的方法 |
|---|---|---|---|
| Board/InputSurface | `point_activated(cell)` | BoardViewport/MatchScreen | `set_interaction_enabled()` |
| Board/InputSurface | `cancel_or_marker_requested(cell)` | BoardViewport/MatchScreen | `set_selection_state()` |
| Board/InputSurface | `pan_requested(delta)`、`zoom_requested(step)` | BoardViewport | `reset_camera()` |
| BoardViewport | `action_preview_selected(preview_id)` | MatchScreen | `render_player_view()` |
| MarkerMenu | `marker_selected(cell,type)` | MatchScreen | `open_for_cell()` |
| ActionConfirmationPanel | `confirm_requested()`、`cancel_requested()` | MatchScreen | `show_preview()`、`clear()` |
| MatchStatusPanel | `skip_requested()` | MatchScreen | `render_status()` |
| TutorialOverlay | `skip_requested()`、`retry_requested()` | TutorialLevel | `render_step()` |
| TerminalDialog | `restart_requested()`、`exit_requested()` | MatchScreen/GameApp | `show_result()` |

禁止 `get_parent().get_parent()`、`../../` NodePath 和跨场景直接查找。组合根缓存直接子场景引用并负责接线。

## 5. Presentation 状态机

Presentation 只保存以下本地状态：

```text
IDLE
SELECTED(piece_id, action_type)
PREVIEW_SELECTED(preview_id)
CONFIRMING(preview_id)
MARKER_MENU(cell)
LOCKED_WAITING_FOR_FRAME
TERMINAL
```

状态不保存真实合法性、隐藏阻挡、随机候选或另一 viewer DTO。

### 5.1 左键

1. `IDLE` 点击己方可操作棋子 → 请求该棋子 previews。
2. `SELECTED` 点击某目标 → 只匹配当前 ActionPreview 的 `preview_id`。
3. preview 需要确认 → `prepare_action(preview_id)` 并显示确认面板。
4. 不需确认的公开行动仍经 `confirm_prepared_action` 的 application 校验路径，不直接调用 domain。

### 5.2 右键与献祭取消

- `SELECTED/PREVIEW_SELECTED/CONFIRMING`：右键只取消当前选择或待确认献祭，不打开标记菜单。
- 取消调用 `cancel_prepared_action()`，不创建 resurrect Intent、不牺牲士、不消耗行动。
- 返回 `IDLE` 后，再次右键某交点才打开 MarkerMenu。
- `IDLE` 的圆/叉/方形标记仅写本地 MarkerRepository；不触发 port、Intent、replay 或传输。

## 6. Board 渲染接口

`BoardViewport.render_player_view(view)` 按以下顺序向子层下发方法：

1. `BoardWorld.set_public_board(view.board, view.viewer_side)`
2. `WallLayer.render(view.walls)`
3. `PieceLayer.render(view.pieces)`
4. `FogOverlay.render(view.visible_cells, view.hidden_detection_cells)`
5. `IntelLayer.render(view.flags, view.contact_intel)`
6. `CaptureGhostLayer.render(view.capture_ghosts)`
7. `TacticalOverlay.render_public_overlays(view.vision_overlays)`
8. `InteractionOverlay.render_selection(local_selection, action_previews)`

所有 `render()` 输入都来自当前 PlayerView 或本地 UI 状态。子层不得读取 port、application 或 sibling 状态。

### 6.1 Preview 映射

ActionPreview 保持冻结字段，不增加 `selectable_points/move_paths/blocked_points`：

- 每个目标由一条 ActionPreview 表达。
- `classification=KNOWN_LEGAL/TENTATIVE/KNOWN_ILLEGAL` 决定点样式。
- 车条形路径、相田范围等已经授权的持续覆盖信息来自 `PlayerView.vision_overlays`。
- 若未来需要单次候选路径几何，必须升级 observer DTO/codec；Presentation 不自行读取 domain 计算。

## 7. Input Map

Iteration 1 在 `project.godot` 预置以下动作：

| Action | 默认绑定 | 处理位置 |
|---|---|---|
| `board_select` | 鼠标左键 / Enter | InputSurface `_unhandled_input/gui_input` |
| `board_cancel_or_marker` | 鼠标右键 / Esc | MatchScreen 状态机 |
| `board_confirm` | Enter / Space | ActionConfirmationPanel |
| `board_pan_up/down/left/right` | WASD / 方向键 | BoardViewportController |
| `board_zoom_in/out` | 滚轮 / `+ -` | BoardViewportController |
| `tutorial_skip` | 可重绑定按键 | TutorialOverlay |
| `ui_cancel` | Esc | Godot UI 标准链 |

离散操作使用 `_unhandled_input()` 或 Control `gui_input`，消费后 `set_input_as_handled()`；不同时在 `_input` 和 `_unhandled_input` 重复处理。纯绘制 Overlay 全部 `mouse_filter=IGNORE`。

Esc 的优先级固定为：打开的 modal/drawer 先消费 `ui_cancel`；没有 modal 时才由 MatchScreen 把同一次物理按键解释为 `board_cancel_or_marker` 的“取消选择”分支，禁止一次按键触发两次状态转换。

## 8. Tutorial 安全接口

```text
Trusted TutorialScenarioDefinition
          │ application loads and validates
          ▼
TutorialSessionPolicy ──► MatchApplication ──► normal Domain resolve
          │
          └── observer-safe current step ──► TutorialDirector
```

- Application 强制校验当前步骤允许的 preview/Intent；UI 隐藏按钮不是安全边界。
- TutorialDirector 只判断 VisibleEvent、VisibleError、PlayerView、ActionPreview 或 application 发布的公开 step completion。
- 无法从安全 DTO 判断的教学目标必须返回系统与体验负责人改写，不能增加 FullState 旁路。
- 失败、重试、重置、跳过均通过 TutorialSessionPolicy 处理，不能直接写棋子坐标。

## 9. Replay 与错误

- AuthoritativeReplay 仅由 application/QA 内部 recorder 接收 NormalizedIntent、raw event、state/event digest 和 RNG checkpoint。
- ObserverReplay recorder 订阅 port 发布前的 canonical observer frame，不订阅 SceneTree UI 信号。
- VisibleError 统一隐藏失败外形；Board/HUD 只根据 `public_code/message_key/resolution` 展示。
- UI 动画、声音、镜头不得因隐藏 blocker 类型或真实处理耗时而分叉。

## 10. 接口验收

- 递归扫描 Presentation/Tutorial 公共签名，无 FullState、DomainEvent/Error、RNG、AuthoritativeReplay、viewer 参数。
- 相同 PlayerView 输入生成字节等价且顺序等价的 ActionPreview。
- cancel resurrect 在任何确认阶段均不产生 Intent 或 action index 变化。
- 任一 observer DTO 不经全局 EventBus；同时存在两个测试会话时不能串视角。
- 黑方镜像只改变 display mapping，提交 target 仍是 authority `[x,y]`。
- ObserverReplay frame 与实时下行 DTO canonical 字节等价。
