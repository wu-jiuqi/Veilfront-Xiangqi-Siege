# 局域网真人测试工具 Godot 产物映射 v2

状态：`approved disposable tooling / board-integration-ready`
Contract：`LOOP-CTR-GATE1-VERTICAL-SLICE-001@v4`
范围例外：`LAN-PLAYTEST-TOOL-001`

## 目标

在不修改当前 AI 目录、现有灰盒场景、`match_controller.gd` 或 `player_view_projector.gd` 的前提下，实现一个可丢弃的双人局域网测试适配器。房主独占 FullState 与规则随机流，加入者只接收黑方 PlayerView。

## Godot 路径映射

| 产物 | Godot 类型 | 路径 | 责任 |
|---|---|---|---|
| 协议白名单与消息校验 | `RefCounted` GDScript | `scripts/prototype/network/lan_protocol.gd` | 规范化 intent、构造网络专用 PlayerView、隐藏旗位和规则种子、检测下行受禁字段 |
| 房主权威棋局会话 | `RefCounted` GDScript | `scripts/prototype/network/lan_host_session.gd` | 持有 FullState、席位、准备 token、去重表并调用规则核心 |
| ENet 网络会话 | `Node` GDScript | `scripts/prototype/network/lan_network_session.gd` | 创建/加入 ENet、RPC、连接状态、按 peer 下发 PlayerView |
| 联网会话预置节点 | PackedScene | `scenes/prototype/network/lan_network_session.tscn` | 预置端口、最大客户端数和脚本绑定 |
| 局域网大厅逻辑 | `Control` GDScript | `scripts/prototype/network/lan_lobby.gd` | 把预置按钮和输入框连接到网络会话，不持有 FullState |
| 局域网大厅 | PackedScene | `scenes/prototype/network/lan_lobby.tscn` | 预置创建、IP、端口、加入、断开、席位与状态控件 |
| 权威会话测试 | `RefCounted` 测试套件 | `tests/prototype/network/test_lan_host_session.gd` | 席位、回合、过期/重复请求、双侧投影和受禁字段 |
| 双 peer 集成测试 | `SceneTree` 无头入口 | `tests/prototype/network/run_lan_network_integration.gd` | 同一进程内两套 MultiplayerAPI + ENet loopback 建连和双方行动 |
| 大厅场景测试 | `SceneTree` 无头入口 | `tests/prototype/network/run_lan_lobby_scene.gd` | 实例化预置大厅并检查节点、默认值、焦点与信息边界 |

## 预置节点与动态例外

- Lobby 的 `Control`、Container、Label、LineEdit、SpinBox、Button 和 `LanNetworkSession` 节点全部预置在 `.tscn`。
- `ENetMultiplayerPeer`、自定义 `MultiplayerAPI` 和 RPC 消息只能在运行时根据“创建／加入”操作生成，属于网络生命周期必需的动态对象，不适合预置为节点或资源。
- 棋子、棋盘和状态 UI 不在本阶段复制或动态生成；最终共享 UI 接线等待 AI 稳定提交。

## 信息边界

- 服务器下行只允许 `schema_version`、`protocol_version`、`seat`、网络专用 `player_view` 与公开反馈。
- 网络专用 PlayerView 使用 `lan-player-view-v2`：旗帜只包含 `owner / capturing_side / capture_progress / contested` 等公开状态，不包含位置或可间接定位的占领棋子 ID。
- 网络快照不下发 `match_seed`。种子会决定隐藏旗位与后续规则随机结果，不能作为客户端可见重放参数。
- 客户端不得接收 `board`、`rng`、`prepared_action`、`events`、`vision_sources`、`state_digest`、`event_log_digest` 或完整 FullState。
- 服务端只接受规范化的 `{piece_id, action_type, target_cell, skill_type}`，其中动作类型包含 `move / bombard / pass / resurrect`；房主额外校验席位、当前行动方、`action_index`、请求 ID 与公开候选，并独占田字阻车和士复活随机裁决。

## 棋盘 UI 接口

- 监听 `player_view_received(player_view)`：每次收到后用该网络 PlayerView 刷新棋盘、回合、夺旗进度和终局状态。
- 监听 `connection_state_changed(snapshot)`、`seat_assigned(seat)` 与 `action_feedback(feedback)`：刷新联网状态、红黑视角和动作失败/成功提示。
- 使用 `get_player_view_snapshot()` 获取当前不可变副本，使用 `get_action_previews()` 或 `preview_intent(intent)` 生成本地公开预览。
- 使用 `can_submit_intents()` 控制棋盘交互；确认动作后只调用 `submit_intent(intent)`，不得在客户端直接调用 RuleEngine。
- `get_session_role()` 返回 `host / client`，`get_local_seat()` 返回 `red / black`。房主 UI 同样只消费红方网络 PlayerView，不直接读取 FullState。

## 首版固定假设

- 房主固定红方，加入者固定黑方，红方仍按既有规则先手。
- 只允许一个远端客户端；不自动发现、不重连、不迁移房主。远端掉线后旧局拒绝新 peer，双方需重新开房。
- 使用可靠 RPC；不使用 `MultiplayerSpawner`，因为棋局只同步低频离散 DTO，不复制运行时棋子节点。

## 验收

1. Godot 4.7.1 可解析新增脚本并无头加载两份新增场景。
2. 权威会话测试验证错误席位、错误回合、过期 action index、重复请求和已知非法行动均不消费行动。
3. loopback 双 peer 建连后，红黑双方各提交一次 `pass`，双方收到的 PlayerView 推进到同一 action index。
4. 每次下行递归检查受禁字段；双方快照不包含 FullState、RNG、`match_seed`、旗位或完整审计。
5. 现有全量原型测试保持通过；当前 AI 工作树不被修改。
