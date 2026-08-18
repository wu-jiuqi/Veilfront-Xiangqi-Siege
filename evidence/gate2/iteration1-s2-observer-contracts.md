# Iteration 1 / I1-S2 观察者合同与进程内 fixture 证据

- 日期：2026-08-18
- 基线提交：`bcb157f5153cfef2b336bfb524cb8596e165ce1f`
- 对应计划：`docs/godot-prompter/plans/iteration1-formal-shell-migration-plan-v1.md` 的 I1-S2
- 结论：`passed`（仅完成 I1-S2，不代表 Iteration 1 或 GATE-2 完成）

## 交付范围

- 四个 observer-safe v1 codec：PlayerView、VisibleEvent、VisibleError、ActionPreview。
- 共用 canonical JSON/SHA-256、深复制、schema/version、类型与 allow-list 支撑。
- 无 SceneTree 的抽象 `MatchClientPort`，按 view → events → error → previews → prepared 固定顺序发布。
- 红/黑最小 canonical fixture 与测试专用进程内 port；不接规则、不计算合法性、不依赖原型、AI、LAN 或网络。

## RED / GREEN

RED：

```powershell
D:\Godot\godot.cmd --headless --path . --script res://tests/game/contracts/run_observer_contract_checks.gd
```

- 退出码：1
- 原因：四个正式 codec 与 `MatchClientPort` 尚不存在，测试入口无法编译。

GREEN：

```powershell
D:\Godot\godot.cmd --headless --path . --script res://tests/game/contracts/run_observer_contract_checks.gd
```

- 退出码：0
- 输出：`OBSERVER_CONTRACT_CHECKS_PASSED checks=18`

18 项检查覆盖：

- 红/黑 PlayerView、VisibleEvent、VisibleError、ActionPreview canonical decode/encode 字节等价；
- `seed/position/private_marker/raw_sequence` 根字段注入拒绝；
- 重复 JSON key、未知 schema 与额外空白拒绝；
- 两次 decode 无可变数组别名；
- 红黑两个 port 可同时存在且不串视角；
- 同一 port 首次发布后锁定 `viewer_side`，切换另一 fixture 被拒绝且不发信号；
- 公共方法和参数无 viewer/observer/actor_side 选择入口；
- 五类下行信号顺序固定，VisibleEvent 序号与 PlayerView cursor 一致。

## 架构、回归与环境验证

```powershell
D:\Godot\godot.cmd --headless --path . --script res://tests/game/architecture/run_formal_architecture_checks.gd
D:\Godot\godot.cmd --headless --path . --script res://tests/prototype/run_all.gd
D:\Godot\godot.cmd --headless --path . --editor --quit
python C:\Users\30114\.codex\plugins\cache\personal\game-production-pipeline\0.4.0-alpha.2\scripts\validate_project_instance.py --project-root "D:\Veilfront Xiangqi Siege"
```

- 正式依赖护栏：退出码 0，`self_tests=17 scanned_files=6`。
- 原型回归：退出码 0，`scaffold=9 focused_suites=15`。
- Godot 4.7.1 编辑器导入：退出码 0，六个正式全局类注册成功。
- 项目实例：`state=normal`，errors=0，warnings=0。
- 本切片未迁移 projection、规则、随机消费或回放，不满足 1000-seed 全量重跑触发条件。

## 代码审查

- 首轮发现：端口没有公开 viewer 参数，但未锁定首次发布的观察者身份。
- 修复：首次有效批次绑定 `viewer_side`；后续视角变化整体拒绝，不发布任何 DTO。
- Critical：0（上述问题已在提交前修复并增加回归）。
- Improvements：0。
- Positive：无 Node/Autoload/帧循环；所有载荷解码后深复制；错误只返回固定 `invalid_observer_payload`；测试替身与正式端口分离。

## 关键产物摘要

- `observer_codec_support.gd`：`dcc8b4cb14487a065236248368db08f9d27c11a8ddfd2dcef947e8e4e50769dc`
- `player_view_codec.gd`：`fb5effc7e82efe1a5eda5129e7304e60cffec39afcdf97d3d4d6206e757ac39d`
- `visible_event_codec.gd`：`92dfd4b43fa7e60511cf8adab9cc2bdca99bde1afadc6da969162eb76a2b6211`
- `visible_error_codec.gd`：`027b8b8088443a7524c82aea20090200028ffb482b7ecd521e908cda5f1d8314`
- `action_preview_codec.gd`：`0d072423c56d48c57a9395e19455927766f90be7ce5cdcc4aadc5d760cce8436`
- `match_client_port.gd`：`5a2bad5cc2e74ca41432ffa483cbdda22ccc6b28a4a2a81316857a7a8bdc60dd`
- 红 fixture：`6c69873f82c0c664a61dfbaf57c27aef8a6b4c2b35973c2b5074adcce6a8bcf2`
- 黑 fixture：`94634bca96bfb7e8787a8f28063f626155d7baa9d365eeee0df997a7c6a6f39e`

## 下一合法动作

进入 I1-S3：用预置节点建立 `GameApp/MatchScreen/BoardViewport/BoardWorld/HUD/覆盖层` 场景壳，并仅连接本切片的 fixture port。不得接 prototype projector、RuleEngine、AI 或 LAN。
