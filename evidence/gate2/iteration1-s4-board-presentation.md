# Iteration 1 / I1-S4 棋盘镜像与响应式灰盒证据

状态：`implementation_complete / direct_checks_passed / bound_by_containing_commit`

## 范围

本切片在 I1-S3 预置场景壳上实现 `TASK-SHELL-001` 的棋盘表现与本地交互：9×24 交点映射、红黑 180° 镜像、正方形点距、响应式宽/窄布局、区域色块和文字、墙线、单一 FogOverlay、PlayerView 驱动的棋子/旗帜记忆/虚影、车与相特殊高亮、私有标记和右键取消优先级。

没有迁移规则、随机序列或 Projection，没有接入 LAN、互联网、AI 或真实 MatchClientPort；ApplicationHost 和教学业务接线仍属于 I1-S5。

## 红灯证据

首次执行：

```powershell
D:\Godot\godot.cmd --headless --path . --script res://tests/game/presentation/run_board_layout_contract.gd
D:\Godot\godot.cmd --headless --path . --script res://tests/game/presentation/run_board_observer_fixture.gd
```

结果：`EXIT=1`。第一条因 `board_coordinate_mapper.gd` 不存在而在 preload 阶段失败；第二条因 MatchScreen 不存在 `apply_layout_for_size()` 而失败。测试先于实现证明坐标、响应式和观察者渲染合同并非空通过。

实现后的视觉检查还发现首次相机同步使用初始 SubViewport 高度，导致视野停在棋盘中部；修正为按容器实际尺寸重置到底部后，红黑双方均以己方大本营为底。

## 直接验收

### 坐标、响应式和截图

```powershell
D:\Godot\godot.cmd --headless --path . --script res://tests/game/presentation/run_board_layout_contract.gd
D:\Godot\godot.cmd --path . --audio-driver Dummy --script res://tests/game/presentation/run_board_layout_contract.gd -- --capture-screenshots
```

结果：两次均 `EXIT=0`；`BOARD_LAYOUT_CONTRACT_PASS resolutions=3`。

| 分辨率 | 模式 | BoardFrame | 屏幕点距 X/Y | 主要按钮 |
|---|---|---|---|---|
| 960×540 | compact | 928×380 | 100.2222 / 100.2222 | 未裁切，最小高 44 |
| 1280×720 | wide | 936×560 | 101.1111 / 101.1111 | 未裁切，最小高 44 |
| 1920×1080 | wide | 1576×920 | 172.2222 / 172.2222 | 未裁切，最小高 44 |

数值快照：[iteration1-s4-layout-snapshots.json](iteration1-s4-layout-snapshots.json)，SHA-256 `46ADA6243AE7956E9033248EFD4268DE2AD2D8646F677F0FD8D70E158E664D47`。

截图：

- `i1-s4-960x540.png`：960×540，SHA-256 `159C1FC6C44D8784E1900C193EBAB15E5552B4E8698CEA8A077868CAD8F69047`；
- `i1-s4-1280x720.png`：1280×720，SHA-256 `DD11D0173C86B373E64A1087EBCA0EB1B8C32D80F31263D504ABD658F93F74E5`；
- `i1-s4-1920x1080.png`：1920×1080，SHA-256 `409CD887237A44DD1EDB5D88417E505515D20FDF971E4DBC73E337D4C5844E7C`。

坐标合同逐项验证：

- authority `[x,y]` 不因显示视角改变；
- 红显示 `(x-1,24-y)`，黑显示 `(9-x,y-1)`；
- 同一 authority cell 的红黑显示坐标之和固定为 `(8,23)`；
- 两方向逆映射均回到原 authority cell；
- 红方 Y=1、黑方 Y=24 均位于显示底部；
- X/Y 世界点距及三档屏幕点距完全相同。

### 观察者安全渲染与交互

```powershell
D:\Godot\godot.cmd --headless --path . --script res://tests/game/presentation/run_board_observer_fixture.gd
```

结果：`EXIT=0`；`BOARD_OBSERVER_FIXTURE_PASS`。

覆盖内容：

- 只实例化 PlayerView 已授权的棋子；
- `discovered=false, position=[]` 的旗帜不创建节点；
- 已发现旗帜重新入雾后仍以记忆图标显示；
- capture ghost、墙段和三类 observer-safe 战术组均正确渲染；
- `Fog < Intel < Ghost < Marker < Tactical < Interaction` 顺序保持；
- Marker 刷新不清除 Interaction，Interaction 始终在 Marker 上方；
- 选中状态第一次右键只取消，返回 IDLE 后第二次右键才打开标记菜单；
- CONFIRMING 状态右键返回 `cancel_prepared_action`，隐藏确认面板且不生成 Intent。

216 个交点、216 个雾格和战术边框全部使用 custom draw，没有创建 216 个 Control；棋子、旗帜、墙和虚影因数量/生命周期可变而使用 PackedScene。

### 正式架构与原型非回归

```powershell
D:\Godot\godot.cmd --headless --path . --editor --quit
D:\Godot\godot.cmd --headless --path . --script res://tests/game/scenes/run_formal_scene_smoke.gd
D:\Godot\godot.cmd --headless --path . --script res://tests/game/architecture/run_formal_architecture_checks.gd
D:\Godot\godot.cmd --headless --path . --script res://tests/game/contracts/run_observer_contract_checks.gd
D:\Godot\godot.cmd --headless --path . --script res://tests/prototype/run_all.gd
```

结果：

- `FORMAL_SCENE_SMOKE_PASS roots=3 components=16 inputs=11`
- `FORMAL_ARCHITECTURE_CHECKS_PASSED self_tests=17 scanned_files=43`
- `OBSERVER_CONTRACT_CHECKS_PASSED checks=18`
- `PROTOTYPE_BASIS_CHECKS_PASSED scaffold=9 focused_suites=15 full_gate1=false`

## Godot 代码审查

结论：Critical 0，当前切片必须修改项 0。

审查中已修正：

- MatchScreen 的深层固定 NodePath 改为预置 `unique_name_in_owner` 引用，降低响应式 reparent 后路径脆弱性；
- 动态渲染器更新时先 `remove_child()` 再 `queue_free()`，避免同一帧旧/新棋子或旗帜重叠；
- BoardWorld 缓存 IntelLayer，不在快照方法中重复节点查询；
- SubViewportContainer 使用 stretch 自动同步尺寸，不再手动写入 SubViewport.size 产生引擎警告。

正向项：输入只使用 Input Map；离散动作在 `gui_input/_unhandled_input` 消费；子节点信号向上、父节点方法向下；无 Autoload、跨树 parent 链、热路径 load 或逐格节点；所有 custom draw 状态变化均调用 `queue_redraw()`。

## 后续行动与返回路径

下一合法切片是 I1-S5：ApplicationHost 绑定 fixture MatchClientPort、MatchScreen observer DTO 信号流、确认/取消请求与教学安全壳。I1-S4 通过不代表 Iteration 1 或 GATE-2 通过。

若 clean worktree 无法复现本证据，返回 `TASK-SHELL-001` 并保留失败分辨率、截图、数值快照和 Godot 日志；不得通过非正方形缩放、读取规则状态或放宽 observer codec 迎合测试。
