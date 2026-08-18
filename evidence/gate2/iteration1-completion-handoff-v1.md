# GATE-2 Iteration 1 完成交接 v1

## 状态

- Contract：`LOOP-CTR-FORMAL-FOUNDATION-GATE2-001@v1`
- 关闭任务：`TASK-ARCH-001`、`TASK-SHELL-001`
- 功能冻结：`47dd52ded8dbe2585d9d0f4fa93c6687624745af`
- 证据冻结：`c9c566bbadc79869430d94e0a9b0b74ca5890d0c`
- 结论：`iteration_complete / ready_for_iteration_2_planning`

Iteration 1 已建立正式依赖护栏、观察者安全合同、预置 GameApp/MatchScreen/TutorialLevel、响应式镜像棋盘、ApplicationHost 与 fixture port 接线，以及 authority/presentation 分离的教学安全壳。该结论不把安全壳描述为完整教学关，也不表示正式规则核心、Projection、Replay、最终美术或 GATE-2 已完成。

## 审查链

| 证据 | 结论 | SHA-256 |
|---|---|---|
| `iteration1-review-decision-v1.md` | 首轮 `revision_required` | `93ef463dc920def437bad8a6e682e252da4275e566e96cd95d7798fd966594e3` |
| `iteration1-remediation-technical-v1.md` | 技术整改完成 | `c9c797641c3890696c2f68419dc07fec5b49a8f053ac69b0640ab4c0d55c3d48` |
| `iteration1-remediation-technical-v1-correction.md` | 不可变摘要纠错 | `700e1709e3c048f02b0aed89171a58de19baa9c38a0fdcd697b524ac0bf91c3d` |
| `iteration1-remediation-experience-v1.md` | 体验整改完成 | `0e7959ae6390e5cbfa785d4c79e3326eff8604a16c582fa1aca0d4bbf0b82d36` |
| `iteration1-technical-rereview-v2.md` | `approved` | `54490bdd999e839622daccef02fe45f53fff9a88d494def81c7a34848e3f6eed` |
| `iteration1-experience-rereview-v2.md` | `approved` | `4665c0dc804734ecc1c12cc701a1522ecc1c40565ecb971c1a2bc8c13e70714e` |
| `iteration1-independent-qa-rereview-v2.md` | 仅证据笔误 `revision_required` | `2f4628bddefb5cd3f0cc65285c694e050ca224e29d81635a49303e355bd805c5` |
| `iteration1-independent-qa-final-review-v3.md` | `approved` | `2c66f6cdf59d397a63a2e2eec143b6d76f2414f56819d7edd1b91619054df4dc` |

最终 QA 证明证据冻结相对功能冻结只增加审查/纠错文件，`scripts/tests/scenes/resources/project.godot` 的 Git 对象未改变；因此复用 QA v2 已通过的功能套件结果合法。

## 最终自动证据

- Godot 4.7.1 无头导入：通过。
- 正式架构：`17` 项扫描自测、`52` 个正式文件通过。
- Observer 合同：`30` 项通过。
- 正式场景：`3` 个根场景、`16` 个组件、`11` 个 Input Map action 通过。
- 棋盘：observer fixture、三分辨率 `CONFIRMING` 布局与正方形点距通过。
- 教学：进入、提示、取消、重试、跳过、退出与 authority 拒绝通过。
- 原型保护：`15` 个聚焦套件通过，`full_gate1=false`；本迭代未触发新的 1000-seed 压测。

## 已关闭的整改

- 城墙 DTO 只接受 `INTACT/BREACHED/REPAIRING`。
- `flag.capture_progress` 仅允许公开 `{capturing_side, progress}`，拒绝位置与隐藏/debug 字段。
- 教学跳过、重试、preview 准备/确认只由 application authority Resource 授权。
- 三分辨率确认面板不裁切。
- prepare-in-flight 可取消，迟到 prepared 回包不会重开确认。
- 车只描蓝色路径；相/象只描黄色田字九点；19 点扩展侦察不描边。

## 保留风险与下一步

1. 当前端口仍是单在途/FIFO 语义；未来允许同 preview ID 并发乱序时，需要新 Contract 引入 request token。
2. authority 拒绝的玩家可见禁用态/错误反馈应在完整教学 UI 中实现。
3. Iteration 2 必须先从 RC3 migration manifest 生成 golden snapshot pack，再迁移 canonical JSON/SHA-256、seeded random、FullState codec 与 AuthoritativeReplay。
4. 任何 state/event/PlayerView/VisibleEvent/VisibleError/ActionPreview/replay 摘要不等价，都返回当前迁移切片；不得修改 golden 迎合新实现。
5. 本交接不批准互联网、AI、LAN 正式化、批量美术或 GATE-2。
