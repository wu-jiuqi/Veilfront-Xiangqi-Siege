# Iteration 1 正式壳与首批迁移计划 v1

状态：`review_approved / iteration_complete`

完成绑定：功能冻结 `47dd52ded8dbe2585d9d0f4fa93c6687624745af`；证据冻结 `c9c566bbadc79869430d94e0a9b0b74ca5890d0c`；技术、系统体验与独立 QA 最终复审均为 `approved`。本状态只关闭 `TASK-ARCH-001/TASK-SHELL-001`，不表示完整教学、规则迁移或 GATE-2 已完成。

## 1. 目标

在不迁移完整规则、不接入 LAN/互联网、不交付 AI、不生产全套美术的前提下，建立正式目录、依赖护栏、observer-safe 进程内接口、Input Map 和可 headless 加载的预置应用/对局/教学场景壳，为 Iteration 2 行为等价迁移提供稳定落点。

## 2. 本批范围

包含：

- `scripts/game/`、`scenes/game/`、`resources/game/`、`tests/game/` 正式骨架；
- DTO/依赖边界的编译级或扫描级占位；
- 预置 GameApp、MatchScreen、BoardViewport/BoardWorld、HUD、Fog/Marker/Tactical/Interaction Overlay 和 TutorialLevel；
- 固定 observer-safe fixture port，只用于场景和布局测试；
- Input Map 与响应式布局测试；
- 本设计文档和实现交接证据。

不包含：

- 从 prototype 复制 RuleEngine、MatchState、PlayerView projector 或 LAN controller；
- Internet/Steam/Relay/server；
- AI preload 或 AI 回归以外的任何交付；
- 正式 shader、全套 TileSet、棋子动画、音频、批量特效；
- 改动 owner revision 5、50 回合实验参数、随机消费或现有 GATE-1 原型行为。

## 3. 切片顺序

### I1-S1：正式目录与依赖护栏

新增：

```text
scripts/game/{contracts,domain,application,projection,presentation,tutorial,ports}/
tests/game/architecture/check_dependency_boundaries.gd
tests/game/architecture/run_formal_architecture_checks.gd
```

实现要求：

- 先建立 deny-list 扫描器，再写任何正式运行时代码。
- 扫描正式 GDScript 的 preload/load/extends/类型名/公开方法签名。
- 无目录占位 `.gd` 为制造结构而制造结构；只在有明确接口时创建文件。

完成条件：

- domain 无 Node/Control/SceneTree/AI/LAN/tutorial/network/prototype。
- presentation/tutorial 无 domain/projection/FullState/raw event/RNG/AuthoritativeReplay。
- application 公开 API 无 FullState 返回值和 viewer 参数。
- 正式组合根无 AI、LAN、prototype preload。

失败返回：`TASK-ARCH-001`，修改边界设计；禁止用扫描例外掩盖真实耦合。

### I1-S2：版本化观察者合同与 fixture

新增：

```text
scripts/game/contracts/{player_view,visible_event,visible_error,action_preview}_codec.gd
scripts/game/ports/match_client_port.gd
tests/game/contracts/test_observer_codec_allow_lists.gd
tests/game/contracts/fixtures/red_player_view_minimal_v1.json
tests/game/contracts/fixtures/black_player_view_minimal_v1.json
```

实现要求：

- codec 使用 allow-list、unknown-field rejection 和 canonical JSON；不接触原型 projector。
- fixture 必须显式不含 seed、RNG、未发现旗位、敌方私有相田来源和 private marker。
- 测试替身只发送 fixture DTO，不模拟规则合法性。

完成条件：

- 合法 fixture decode/encode 往返字节等价。
- 强制加入 `seed/position/private_marker/raw_sequence` 等禁止字段时 decoder 非零失败。
- 红/黑 fixture 可同时存在且不能通过参数请求另一视角。

失败返回：`TASK-ARCH-001` 或正式 DTO 文档；不得改 fixture 绕过 decoder。

### I1-S3：Input Map、Theme 与预置场景壳

新增：

```text
project.godot Input Map entries
resources/game/ui/formal_graybox_theme.tres
resources/game/content/boards/ancient_battlefield_board_theme.tres
scenes/game/app/game_app.tscn
scenes/game/match/match_screen.tscn
scenes/game/match/board/*.tscn
scenes/game/ui/*.tscn
scenes/game/tutorial/tutorial_level.tscn
```

实现要求：

- 所有固定节点由 `.tscn` 预置；不在 `_ready()` 创建 HUD、Fog、Marker 或 216 个格子。
- `BoardTheme` 只含美术字段；Presentation 使用 `PlayerView.board + BoardTheme`。
- 棋子/旗帜/墙/虚影以 PackedScene 实例化，但 fixture 场景可只放少量代表样片。
- 场景默认使用 graybox Theme，便于后续视觉替换。

完成条件：

- GameApp、MatchScreen、TutorialLevel headless load/instantiate/queue_free 无错误。
- 预置树中只有一个 FogOverlay、一个 InputSurface；纯绘制层 mouse ignore。
- 无 prototype/AI/LAN preload。

失败返回：`TASK-SHELL-001`；保留失败 scene path 和 Godot import 日志。

### I1-S4：棋盘映射、镜像与响应式灰盒

新增：

```text
scripts/game/presentation/board/board_coordinate_mapper.gd
scripts/game/presentation/board/board_viewport_controller.gd
scripts/game/presentation/board/*_renderer.gd
tests/game/presentation/run_board_layout_contract.gd
tests/game/presentation/run_board_observer_fixture.gd
```

实现要求：

- 9×24 交点、正方形点距、墙线 Y=4/21、区域色块和不越界透明大字。
- 红黑镜像只在 mapper；DTO 和 Intent 坐标不变。
- Fog、已发现旗帜记忆、Ghost、Marker、Tactical、Interaction 顺序按场景设计冻结。
- 右键状态机覆盖：选中先取消、献祭可取消、空闲才标记。

完成条件：

- `960×540 / 1280×720 / 1920×1080` 三档截图和数值快照通过。
- X/Y point spacing 相等；9 路不横向裁切；主要按钮不裁切。
- 两视角同一 authority cell 映射互为 180°，逆映射回原坐标。
- 未发现旗帜无节点，已发现旗帜重新入雾后仍有记忆图标。
- Marker 不遮挡 Interaction；Fog 不遮挡授权的记忆标记。

失败返回：`TASK-SHELL-001`；不通过缩放成长方形格子换取适配。

### I1-S5：接口接线与教学安全壳

新增：

```text
scripts/game/application/application_host.gd
scripts/game/presentation/match_screen_presenter.gd
scripts/game/tutorial/tutorial_director.gd
scripts/game/tutorial/tutorial_session_policy.gd
resources/game/tutorials/authority/tutorial_smoke_authority.tres
resources/game/tutorials/presentation/tutorial_smoke_track.tres
tests/game/scenes/run_tutorial_shell_smoke.gd
```

实现要求：

- 本切片 ApplicationHost 只绑定 fixture port，不持有 prototype FullState。
- Tutorial authority/presentation Resource 物理分离；Director 不 preload authority Resource。
- 脚本只验证信号流、取消/确认和 DTO 消费，不伪造规则完成。

完成条件：

- TutorialLevel 从 fixture 完成进入、提示、取消、重试、跳过和退出壳流程。
- 依赖扫描证明 TutorialDirector 无 authority 类型。
- 两个并行测试会话的 PlayerView 信号不串线。

失败返回：`TASK-SHELL-001` 或 `TASK-ARCH-001`；若安全 DTO 无法表达教学提示，升级系统与体验负责人，不建立旁路。

## 4. Iteration 1 汇总验收命令（计划路径）

```powershell
D:\Godot\godot.cmd --headless --path . --editor --quit
D:\Godot\godot.cmd --headless --path . --script res://tests/game/architecture/run_formal_architecture_checks.gd
D:\Godot\godot.cmd --headless --path . --script res://tests/game/contracts/test_observer_codec_allow_lists.gd
D:\Godot\godot.cmd --headless --path . --script res://tests/game/scenes/run_formal_scene_smoke.gd
D:\Godot\godot.cmd --headless --path . --script res://tests/game/presentation/run_board_layout_contract.gd
D:\Godot\godot.cmd --headless --path . --script res://tests/game/scenes/run_tutorial_shell_smoke.gd
```

这些是后续实现应创建的正式入口；当前设计阶段不伪造其通过结果。

## 5. Iteration 2 首个迁移交接点

Iteration 1 审查通过后，才进入以下顺序：

1. 从 RC3 按 manifest 生成 golden snapshot pack。
2. 迁移 canonical JSON/SHA-256。
3. 迁移 seeded random 与 RNG checkpoint。
4. 迁移 FullState codec 和 AuthoritativeReplay runner。
5. 建立 state/event digest 等价后，再拆 rule_engine→projector 回环。
6. 最后迁移 PlayerView/VisibleEvent/VisibleError/ActionPreview 和 ObserverReplay。

任一 state/event/红黑 PlayerView/VisibleEvent/error/preview/replay 不等价都返回当前切片；不得修改 golden 迎合新实现。触及 manifest 的 full rerun trigger 时执行 1000 seeds、20 replay 和 tamper rejection。

## 6. 提交拆分建议

1. `feat: 建立正式架构依赖护栏`
2. `feat: 建立观察者安全合同与测试替身`
3. `feat: 建立正式对局与棋盘预置场景壳`
4. `feat: 实现棋盘镜像与响应式灰盒`
5. `feat: 接入教学安全场景壳`

每个提交必须只包含对应切片，运行该切片直接检查后推送；不得把 prototype 清理、AI/LAN 修改或批量美术混入。

## 7. 审查请求

Iteration 1 完成后提交：

- Godot 技术初审：场景/资源映射、依赖、接口、headless 和分辨率证据。
- 系统与体验复核：右键/取消/确认、迷雾、旗帜记忆、特殊高亮和教学提示不泄露。
- 独立 QA：从 clean worktree 复现所有命令、三分辨率、双观察者隔离和禁止字段拒绝。

上述审查通过只允许进入 Iteration 2，不等于 GATE-2 批准。
