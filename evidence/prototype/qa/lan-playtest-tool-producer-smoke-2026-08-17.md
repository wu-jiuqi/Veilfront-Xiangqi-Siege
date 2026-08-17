# LAN-PLAYTEST-TOOL-001 生产者冒烟与代码审查

日期：2026-08-17
角色：Godot 技术实现（生产者自检）
结论范围：仅证明当前分支的技术冒烟，不替代独立 QA、双机人工试玩或 GATE-1 决定。

## 产物

- 协议与信息白名单：`scripts/prototype/network/lan_protocol.gd`
- 房主权威规则会话：`scripts/prototype/network/lan_host_session.gd`
- ENet/RPC 会话：`scripts/prototype/network/lan_network_session.gd`
- 预置大厅与网络节点：`scenes/prototype/network/lan_lobby.tscn`、`scenes/prototype/network/lan_network_session.tscn`
- 路径映射：`docs/prototype/lan-playtest-tool-map-v1.md`
- 测试：`tests/prototype/network/`

## 自动验证

Godot：`4.7.1-stable (official)`。

| 检查 | 结果 |
|---|---|
| 7 份首批网络 GDScript 静态解析 | `valid=true` |
| `run_lan_host_session.gd` | 退出码 0，`LAN_HOST_SESSION_TESTS_PASSED` |
| `run_lan_network_integration.gd` | 退出码 0，`LAN_NETWORK_INTEGRATION_PASSED` |
| `run_lan_lobby_scene.gd` | 退出码 0，`LAN_LOBBY_SCENE_TEST_PASSED` |
| 现有 `tests/prototype/run_all.gd` | 退出码 0，`PROTOTYPE_BASIS_CHECKS_PASSED scaffold=9 focused_suites=12 full_gate1=false` |

loopback 集成测试在同一 Godot 进程内创建两套独立 `MultiplayerAPI` 与两个 `ENetMultiplayerPeer`，通过 `127.0.0.1:28771` 完成：

1. 房主创建与客户端连接；
2. 红／黑固定席位及各自首个 PlayerView 下发；
3. 红方可靠 RPC 提交 `pass`，黑方收到 `action_index=1`；
4. 黑方可靠 RPC 提交 `pass`，双方收到 `action_index=2`；
5. 双方 UI 快照均不含 `board` 或 `rng`。

## 信息边界

- 房主对象是唯一持有 `_full_state`、准备 token 与规则核心引用的对象。
- 客户端下行根对象使用精确字段集合；`player_view` 也使用 `player-view-v1` 精确根字段白名单。
- 递归受禁字段包括 `board`、`rng`、`prepared_action`、`events`、`vision_sources`、`random_samples`、`state_digest` 和 `event_log_digest`。
- 客户端请求使用精确字段与类型检查，只允许 `move`、`bombard`、`pass`；服务端校验 peer 席位、行动方、action index、请求去重与公开预览后才调用 `RuleEngine.submit_action()`。

## Godot 专项代码审查

### Critical

- 无遗留 Critical。
- 审查中发现“PlayerView 仅黑名单阻断”和“请求整数宽松转换”风险，已改为双层精确白名单与严格 Variant 类型检查并新增回归。

### Improvements

- 已禁止客户端主动提交 `skip/timeout`，首版只接受玩家可直接选择的三类行动。
- 已补充连接失败与服务器断开后的 ENet peer 清理。
- Lobby 使用预置 Container 节点、复用项目 Theme，并为首个按钮设置默认焦点。
- `MultiplayerSpawner` 不适用：本工具只同步低频离散 DTO，不复制棋子节点。

### Positive

- 网络层、权威规则层、协议层和 Lobby UI 各自单一职责，无 Autoload 或现有共享场景改动。
- RPC 的 `any_peer` 入口只执行服务器侧校验；服务器下行均为 `authority + reliable`。
- 没有 `_process()` 轮询、动态 UI 树、父链查找或逐帧网络同步。

审查基线：Godot 4.3+ code review checklist，并复核 Godot 4.7.1 静态解析与运行行为。

## 剩余人工检查

1. 在两台同网段 Windows 机器上分别打开 `lan_lobby.tscn`，确认防火墙放行 UDP 27771 后可建连。
2. AI 稳定提交后，把 `LanNetworkSession` 作为会话接口接入棋盘 UI；当前大厅只验证连接和席位，不提供完整棋盘真人对战入口。
3. 接线完成后执行双机迷雾等价、试探失败、随机炮击、终局和断线体验测试。
