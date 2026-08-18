# Iteration 1 / I1-S3 正式预置场景壳证据

状态：`implementation_complete / direct_checks_passed / bound_by_containing_commit`

## 范围

本切片只实现 `TASK-SHELL-001` 下的 Input Map、灰盒 Theme、BoardTheme 美术资源映射与预置场景树。没有迁移规则，没有接入 LAN、互联网或 AI，也没有实现属于 I1-S4/I1-S5 的棋盘映射、响应式行为和 ApplicationHost 业务接线。

固定 UI、棋盘层、Fog、Marker、Tactical、Interaction 与 InputSurface 均由 `.tscn` 预置；没有在 `_ready()` 动态创建 HUD、蒙版、标记层或 216 个格点节点。

## 红灯证据

首次执行：

```powershell
D:\Godot\godot.cmd --headless --path . --script res://tests/game/scenes/run_formal_scene_smoke.gd
```

结果：`EXIT=1`。三个正式根场景、BoardTheme 和十个新增 Input Map action 均不存在，测试明确返回 `FORMAL_SCENE_SMOKE_FAIL failures=14`。

扩充键盘绑定检查后，测试还识别出左右方向键代码不匹配；修正为 Godot `KEY_LEFT` / `KEY_RIGHT` 后再转绿。

## 直接验收

### Godot 导入与场景壳

```powershell
D:\Godot\godot.cmd --headless --path . --editor --quit
D:\Godot\godot.cmd --headless --path . --script res://tests/game/scenes/run_formal_scene_smoke.gd
```

结果：`EXIT=0`；`FORMAL_SCENE_SMOKE_PASS roots=3 components=16 inputs=11`。

覆盖内容：

- `GameApp`、`MatchScreen`、`TutorialLevel` 完成 load、instantiate、进入树和 queue_free；
- 16 个棋盘/UI 组件场景单独 load 与 instantiate；
- BoardWorld 恰有一个 `FogOverlay` 和一个 `InputSurface`；
- 四个纯绘制 Overlay 的 `mouse_filter=IGNORE`；
- `InputSurface` 使用 `MOUSE_FILTER_STOP` 且可获取键盘焦点；
- 预置树节点数小于 100，未把 216 个格点做成节点；
- 11 个 Input Map action 及鼠标、WASD、方向键、Enter、Esc、Space、滚轮、加减号、教学跳过默认键逐项检查；
- BoardTheme 不含 seed、RNG、viewer、FullState 或规则字段，并映射墙、棋子、旗帜、虚影 PackedScene。

### 架构与观察者边界

```powershell
D:\Godot\godot.cmd --headless --path . --script res://tests/game/architecture/run_formal_architecture_checks.gd
D:\Godot\godot.cmd --headless --path . --script res://tests/game/contracts/run_observer_contract_checks.gd
```

结果：

- `FORMAL_ARCHITECTURE_CHECKS_PASSED self_tests=17 scanned_files=28`
- `OBSERVER_CONTRACT_CHECKS_PASSED checks=18`

正式组合根没有 preload prototype、AI、LAN/network；BoardTheme 仅承担美术资源映射。

### 原型非回归

```powershell
D:\Godot\godot.cmd --headless --path . --script res://tests/prototype/run_all.gd
```

结果：`EXIT=0`；`PROTOTYPE_BASIS_CHECKS_PASSED scaffold=9 focused_suites=15 full_gate1=false`。

## Godot 代码审查

审查结论：Critical 0，当前切片必须修改项 0。

正向项：

- 场景职责单一，以组合和 PackedScene 复用为主；
- 没有新增 Autoload、跨树 `get_parent()` 链或每帧资源加载；
- 输入名称集中在 Input Map，未在运行时代码硬编码按键；
- 所有导出的 BoardTheme 字段均显式类型化；
- 现阶段不添加空壳行为脚本，避免提前制造 S4/S5 耦合。

已知后续工作：BoardViewport 的方格映射、红黑镜像、动态 Fog 穿透、响应式断点和交互状态机由 I1-S4 实现；ApplicationHost 与 Tutorial 安全接线由 I1-S5 实现。它们不是本切片缺陷，也不得通过本提交提前实现。

## 失败返回

若后续 clean worktree 无法复现上述直接检查，返回 `TASK-SHELL-001`，保留失败场景路径与 Godot import 日志；不得修改规则、observer codec 或 GATE-1 原型来迎合场景测试。
