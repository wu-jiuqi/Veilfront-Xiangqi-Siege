# 正式局域网联机候选构建验收记录

- 记录日期：2026-08-22（Asia/Shanghai）
- 实现范围：正式 UX 流程、正式 MatchScreen/HUD、PlayerView 动态迷雾、房主权威规则、ENet 局域网双人对战
- 授权摘要：`9e65df07d19398a083e8d024336180e37d5fc1fd998829cafc7559e7c04031b1`
- 生产代码冻结提交：`8e985b1bd3500d64748a2ea3b2b8f2c66df0f397`
- 构建预置提交：`bd92e3d1e0a6d9c4db39ecced9caae7201e45caa`
- Godot：`4.7.1.stable.official.a13da4feb`

## 可执行产物

- 文件：`builds/windows/Veilfront_Xiangqi_Siege_Formal_LAN.exe`
- 大小：`245707392` 字节
- SHA-256：`DC384462D3F94E69038A994F34DF5CE3A948E8C28953BD42B3130A3F174C59BF`
- 来源：从 `bd92e3d` 的独立 detached worktree 导入并执行 `Windows Desktop Formal LAN` release 导出；没有带入主工作树未提交的 UI、Theme 或资源改动。
- 启动冒烟：导出文件执行 `--headless --quit-after 3`，退出码 `0`。

## 已打通的玩家流程

1. 启动页进入内嵌主菜单，选择局域网对战。
2. 房主创建房间并固定为赤方；客户端输入房主局域网地址加入并固定为玄方。
3. 双方显式确认准备，只有双方都准备后房主才可开局。
4. 双方进入同一正式 MatchScreen，复用正式棋盘、新 HUD、小地图、确认面板和 PlayerView-only 动态迷雾。
5. 当前行动方可预览、准备、确认并提交；远端回合和提交中均锁定重复操作。
6. 普通移动、跳过、回合超时、士献祭复活、炮击、吃子与吃将终局均由房主规则核心结算，再向双方下发各自观察者安全视图。
7. 主动离开或任一端断线都会停止对局，清除棋子、旗帜、迷雾、小地图、预览和本地私有标记，再回到大厅恢复态；不自动重连、不迁移房主、不降级为单机。

## 冻结提交自动验证

在 `8e985b1` 的干净 detached worktree 完成以下 10 个独立 Godot runner，全部退出码 `0`：

| Runner | 结论 |
|---|---|
| `run_formal_lan_network_integration.gd` | 正式 ENet host/join、ready/start、双边普通移动、skip、timeout、复活、炮击、吃将终局、断线与再次建房通过 |
| `run_formal_lan_security_recovery_contract.gd` | 重放、回退、换席复用、压缩损坏、解压长度不符和 4 MiB 越界均被阻断 |
| `run_formal_lan_full_stack_loopback.gd` | 大厅到正式棋盘、HUD、迷雾、提交锁、终局、离开确认和断线清理全流程通过 |
| `run_formal_fog_visual_contract.gd` | `144 × 384` 动态迷雾掩码覆盖 `216` 个棋盘格 |
| `run_formal_lan_lobby_contract.gd` | 五类大厅状态与 seed 零展示合同通过 |
| `run_board_layout_contract.gd` | 六种目标分辨率通过，主要按钮满足 44 px 交互高度 |
| `run_formal_architecture_checks.gd` | 19 项自检、146 个文件的正式依赖边界通过 |
| `run_formal_scene_smoke.gd` | 3 个正式根、19 个组件、11 个输入动作通过 |
| `run_observer_contract_checks.gd` | 30 项观察者 codec 与抽象端口合同通过 |
| `run_hidden_equivalence.gd` | 6 组隐藏状态等价、2723 项检查通过 |

补充回归：`run_gate1_formal_equivalence.gd -- --seeds 1 --replay-samples 1` 通过，覆盖 9 个通道、104 个可见错误检查、200 个观察者回放帧。完整 20-seed runner 运行时间较长，本次没有把中止的长跑记作通过证据。

## 独立 QA 结论

- 审查对象：已推送提交 `8e985b1`，新建 detached worktree 在首次导入前为干净状态。
- 自动化候选：`PASS`；未发现剩余代码级 Critical。
- 正式 LAN 里程碑：`BLOCKED / awaiting_human`；发布批准未评定。
- 独立网络 runner 共 45 项通过；full-stack 共 25 项通过。QA 另行复跑了 observer live frame、board observer fixture、启动回流、HUD、旧 prototype LAN 回归和项目实例校验，结果均通过。
- 管线实例校验：`normal`，0 errors / 0 warnings；registry 为 `state=active iteration=3 sequence=61 revision=61`。
- QA 结论边界：代码自动化候选可以进入实体双机人工验收，不得据此宣称 GATE-2、GATE-3、GATE-4 或对外发布就绪。

## 信息安全与权威边界

- 只有房主持有正式规则应用、FullState、准备 token 和随机 seed；Lobby 与客户端端口不生成、不读取、不显示 seed。
- 客户端只接收经过 codec 精确白名单验证的自身 PlayerView、可见事件、可见错误与行动预览。
- 网络集成在多批次、特殊行动和终局后重复检查，双方均未收到对方视图，也未出现 `seed`、`rng`、`full_state`、`vision_sources` 或 `prepared_action`。
- 观察者批次使用 DEFLATE、4 MiB 双向边界和压缩体 SHA-256；损坏、摘要不符、声明长度不符或越界时立即终止协议会话。
- 请求按 peer 席位、行动方、`expected_action_index` 和 `request_id` 校验；重复和过期请求不会推进对局。

## 双机使用方法

1. 两台 Windows 设备使用同一份 SHA-256 一致的可执行文件，并处于同一可信局域网。
2. 在 Windows 防火墙允许本程序使用专用网络；默认使用 UDP `27771`。
3. 房主进入“局域网对战”后点击创建房间，把界面显示的 `IPv4:27771` 发给另一台设备。
4. 客户端输入该地址后加入；双方点击确认准备，随后由房主点击开局。
5. 若设备存在多个网卡，优先使用双方可互相访问的 IPv4；失败时检查防火墙、AP 隔离、VPN 和端口占用。

## 尚未替代的人工证据

- 本记录证明正式组合根、真实 ENet/RPC 回环、规则动作、信息隔离、断线恢复和可执行导出已经技术闭环。
- 现有 `evidence/prototype/playtest/owner-lan-dual-machine-2026-08-17.md` 属于旧原型构建，不能替代本次正式构建的双机验收。
- 在两台真实设备上使用本文件绑定的 SHA-256 完成建房、加入、双方准备、至少五步、特殊行动、断线和再次建房，并留下截图/日志之前，本候选不得宣称“实体双机验收通过”、GATE-2 通过或发布批准。
- 主工作树当前还有项目所有者未提交的 HUD、Theme、关卡 UI 与资源改动。QA 已在包含这些改动的主工作树复跑 full-stack、六分辨率和 HUD 并通过，说明运行兼容；但这些改动没有进入 `8e985b1`，本候选构建也明确未包含它们。在对应所有者确认冻结并提交前，不得宣称本构建复现了“全部已调整 UI”。
- Steam、Relay、NAT 穿透、互联网匹配、房主迁移、自动重连和正式发布均不在本里程碑范围内。
