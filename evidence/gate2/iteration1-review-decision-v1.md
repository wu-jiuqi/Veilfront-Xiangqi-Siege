# Iteration 1 审查裁定 v1

- 冻结候选：`main@5fb174f2400cf2d525425e34f40aa108e2a9dcca`
- Contract：`LOOP-CTR-FORMAL-FOUNDATION-GATE2-001@v1`
- 裁定：`revision_required`
- 被审任务：`TASK-ARCH-001`、`TASK-SHELL-001`

## 审查输入

| 审查 | 结论 | SHA-256 |
|---|---|---|
| Godot 技术复审 | `revision_required` | `d7814a193c912ab42994aefe3a1fcfd1ecdf0fb061d3cbfff4f7f3f2ebb7e5ac` |
| 系统与体验复核 | `revision_required` | `fb907bf172c77e318d9fac72828d40e21274735d60982854abf9d09fd87239ee` |
| 独立 QA | `approved` | `39460d68009fdb234d43d943182b7e8d0f503f71257e3739f028044b240fe0bd` |

独立 QA 证明冻结提交、现有自动测试、证据摘要和 clean-worktree 可复现性成立，但其通过范围没有覆盖技术与体验复核发现的负向语义。必要专业审查并非全数通过，因此不得以多数票或自动检查通过覆盖 `revision_required`。

## 返回生产任务

### `TASK-ARCH-001`

- `I1-TECH-001`：PlayerView 城墙状态必须接受 `INTACT/BREACHED/REPAIRING`，拒绝 `COLLAPSED`。
- `I1-TECH-002`：VisibleEvent 为公开占旗阵营/进度建立 event-type allow-list，并拒绝位置和隐藏/debug 字段。
- `I1-TECH-003`：教学跳过、重试、preview 准备/确认的授权只由 application authority Resource 决定；presentation track 不拥有权限。

### `TASK-SHELL-001`

- `EXP-I1-001`：行动确认面板在 960×540、1280×720、1920×1080 均不得裁切。
- `EXP-I1-002`：prepare-in-flight 取消必须撤销端口草案并吸收迟到 prepared 回包。
- `I1-TECH-004 / EXP-I1-003`：车只描蓝色路径；相/象只描黄色田字阻挡九点；19 点扩展侦察不生成误导边框。
- `I1-TECH-003`：移除 MatchScreen skip 直达 ApplicationHost 的旁路。

## 重审条件

1. 以上问题均有负向测试，且现有正式与 prototype 回归继续通过。
2. 形成新的冻结提交和整改证据。
3. 技术、系统体验和独立 QA 对同一新冻结提交重新审查；三者均为 `approved` 才可关闭 Iteration 1。

本裁定不修改规则事实源，不批准 GATE-2，也不授权互联网、AI、LAN 或批量美术范围。
