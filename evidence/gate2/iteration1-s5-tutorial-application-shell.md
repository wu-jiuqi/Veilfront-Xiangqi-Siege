# Iteration 1 S5：ApplicationHost 与教学安全场景壳证据

- 生产循环：`LOOP-CTR-FORMAL-FOUNDATION-GATE2-001`
- 迭代/任务：`ITERATION-1-ARCHITECTURE` / `TASK-SHELL-001`
- Godot：4.7.1 stable
- 范围：正式应用端口接线、玩家可见 DTO 展示、行动准备/确认/取消、教学安全壳；不迁移规则、不实现互联网、不接入 AI 或 LAN。

## 实现结论

1. `ApplicationHost` 仅绑定抽象 `MatchClientPort`，将观察者安全信号复制后转发，并在换绑和退出场景时解除旧连接。
2. `GameApp` 与 `TutorialLevel` 通过预置场景连接完成双向接线；没有 Autoload、服务定位器、远亲节点查找或运行时生成组合根。
3. `MatchScreen` 仅消费 `PlayerView`、`VisibleEvent`、`VisibleError` 与 `ActionPreview`，确认只提交已准备的 `preview_id`；取消为独立端口请求，取消后不会误确认。
4. 教学权威配置与显示轨道物理分离：权威 Resource 只注入 `ApplicationHost`，`TutorialDirector` 只持有展示轨道，并仅由玩家可见事件推动提示状态。
5. 教学壳支持进入、提示、取消、重试、跳过和退出；本切片不伪造规则完成条件，完整合法 Intent/Event 教学章节留给 `TASK-TUTORIAL-001/002`。

## TDD 证据

RED：首次执行 `run_tutorial_shell_smoke.gd` 退出码 1，精确缺口为未实现 ApplicationHost、缺少预置 TutorialDirector、缺少权威/展示双 Resource。

GREEN：

```text
TUTORIAL_SHELL_SMOKE_PASS
FORMAL_ARCHITECTURE_CHECKS_PASSED self_tests=17 scanned_files=52
OBSERVER_CONTRACT_CHECKS_PASSED checks=18
FORMAL_SCENE_SMOKE_PASS roots=3 components=16 inputs=11
BOARD_OBSERVER_FIXTURE_PASS
BOARD_LAYOUT_CONTRACT_PASS resolutions=3
PROTOTYPE_BASIS_CHECKS_PASSED scaffold=9 focused_suites=15 full_gate1=false
```

测试同时证明：

- 红/黑两个 GameApp 会话的 PlayerView、ActionPreview 和请求日志不串线；
- 已准备行动可取消，取消计数为 1、确认计数为 0；再次准备后可确认；
- 教学重试与跳过分别走 `request_restart()` 与 `request_skip()`；
- `TutorialDirector` 源文件不引用权威 Resource 路径、类型或 ApplicationHost 的权威字段。

## Godot 专项审查

- Critical：0。
- 已修正：ApplicationHost 在 `_exit_tree()` 主动解绑 RefCounted port，避免信号连接延长端口/场景生命周期。
- 保持：只读 Resource 不复制；枚举 FSM 状态少于 8；按钮和覆盖层均为预置节点；固定场景连接代替运行时节点拼装。

## 下一步

Iteration 1 的实现切片完成后，进入技术复审与独立 QA；通过前不得把本壳描述为完整教学关卡，也不得提前进入 GATE-2。
