# Iteration 1 / I1-S1 正式架构依赖护栏证据

- 日期：2026-08-18
- 基线提交：`5b7ed092be5da1aafc9c8bc360a546e11238b354`
- 对应计划：`docs/godot-prompter/plans/iteration1-formal-shell-migration-plan-v1.md` 的 I1-S1
- 结论：`passed`（仅完成 I1-S1，不代表 Iteration 1 或 GATE-2 完成）

## 交付范围

- `scripts/game/README.md`：冻结 contracts/domain/application/projection/presentation/tutorial/ports 的正式职责边界；不使用空 GDScript 制造目录结构。
- `tests/game/architecture/check_dependency_boundaries.gd`：递归扫描正式 GDScript、场景、资源和 shader；检查路径引用、extends/类型名、公开函数签名及 projection 对权威状态的直接写入。
- `tests/game/architecture/test_dependency_boundaries.gd`：17 个正反例，直接覆盖 `preload()`、`load()`、`extends`、禁止类型、公开签名、状态写入、prototype/AI/network 引用和安全样例误报。
- `tests/game/architecture/run_formal_architecture_checks.gd`：统一 headless 入口；自检或正式扫描任一失败均以非零退出。

当前正式运行时代码尚未进入 `scripts/game/`，因此项目实扫文件数为 0；17 个内存 fixture 用于先证明 deny-list 能拒绝越界，并避免为了提高计数而建立无职责占位脚本。

## RED / GREEN 证据

RED（先运行测试入口，扫描器尚不存在）：

```powershell
D:\Godot\godot.cmd --headless --path . --script res://tests/game/architecture/run_formal_architecture_checks.gd
```

- 退出码：1
- 关键输出：`Parse Error: Preload file res://tests/game/architecture/check_dependency_boundaries.gd does not exist.`

GREEN（实现扫描器并补齐显式 `load()` 反例后）：

```powershell
D:\Godot\godot.cmd --headless --path . --script res://tests/game/architecture/run_formal_architecture_checks.gd
```

- 退出码：0
- 关键输出：`FORMAL_ARCHITECTURE_CHECKS_PASSED self_tests=17 scanned_files=0`

## 回归与环境验证

```powershell
D:\Godot\godot.cmd --headless --path . --script res://tests/prototype/run_all.gd
D:\Godot\godot.cmd --headless --path . --editor --quit
python C:\Users\30114\.codex\plugins\cache\personal\game-production-pipeline\0.4.0-alpha.2\scripts\validate_project_instance.py --project-root "D:\Veilfront Xiangqi Siege"
```

- 原型回归：退出码 0，`PROTOTYPE_BASIS_CHECKS_PASSED scaffold=9 focused_suites=15 full_gate1=false`
- Godot 4.7.1 编辑器导入：退出码 0
- 项目实例：`state=normal`，errors=0，warnings=0

## 代码审查

- Critical：0
- Improvements：0（补齐 `load()` 显式测试后收口）
- Positive：检查器为无节点 `RefCounted`，无帧循环/场景副作用；规则 ID 稳定；失败输出含路径、行号和规则；不加载或执行被扫描的正式脚本。

## 产物摘要

- `scripts/game/README.md`：`c5712d5634c974ff822acd89e4c79cc319c49b49cc3b63d67726649bf0bc5a51`
- `tests/game/architecture/check_dependency_boundaries.gd`：`42b8b41dcc633ce9d01673b3610bf87537fc52fb78d11ae4e75a7f20743314f1`
- `tests/game/architecture/test_dependency_boundaries.gd`：`9df7b05c76cfb4e343a13906567294d0225ab4e9772ab9cf04ad8f420c2d06ea`
- `tests/game/architecture/run_formal_architecture_checks.gd`：`40fe5bb47c230de07610a0eb472a0f14563883ef58250e091062c3664784a388`

## 下一合法动作

进入 I1-S2：建立 observer-safe DTO、codec 和进程内 fixture port。首个正式文件落位后，本扫描入口必须从 `scanned_files=0` 变为非零并持续通过；不得接入 prototype RuleEngine、AI 或 LAN。
