# 《雾疆：九路烽棋》观察者安全 VfxCue 合同 v1

状态：`producer_frozen / foundation_first / awaiting_cross_line_integration`

适用：`TASK-CUE-CONTRACT-G3-001` 的 VFX 部分、`TASK-VFX-G3-001` 候选资产。当前 Loop 仍在 `ITERATION-1-BUDGET-AND-CUE-FOUNDATION`；本文件先冻结共享 Cue 语义，后续预置场景只能按该合同接入，不能把候选资产存在解释为 Iteration 2 已完成。

## 1. 输入边界

`ObserverVfxPolicy` 只接受：

- 前一帧与当前帧、均通过 `veilfront-player-view-v1` codec 的 `PlayerView`；
- 当前观察者已收到、均通过 `veilfront-visible-event-v1` codec 的 `VisibleEvent[]`；
- 本地选中操作明确提交的公开交点；
- 客户端设置 `motion_profile=standard|reduced`。

不得提供、读取或间接查询权威状态、权威事件、规则随机源、另一席位 DTO、隐藏棋子节点或未发现旗位。VFX 不改变规则状态、回放摘要、事件顺序、相机位置或输入判定。

## 2. 共享 Cue envelope

VfxCue 与 AudioCue 对齐以下字段和语义：

| 字段 | 规则 |
|---|---|
| `schema_version` | `veilfront-vfx-cue-v1` |
| `cue_id` | 由公开 session、cursor、key、来源、action、occurrence、公开位置和本地单调 token 计算；不使用随机数 |
| `cue_key` | `vfx.<family>.<variant>` |
| `source_kind` | `local_interaction / visible_event / visible_error / view_diff`；VFX v1 当前不从 error 生成效果 |
| `action_index` | 当前公开行动序号 |
| `occurrence_index` | 当前 batch 内按同一 `cue_key` 从 0 连续递增；执行顺序由 cues 数组固定 |
| `spatial_mode` | 仅 `global / board_2d` |
| `position_public` | `board_2d` 必须为 `[x,y]` 且 `x=1..9,y=1..24`；`global` 必须为空数组 |
| `priority` | `low / normal / high / critical` |
| `concurrency_group` | 预置池并发组 |
| `late_policy` | `drop_if_late / replace_group / play_once` |

VFX 专属追加：

- `actor_side_public`：只能为空、`red` 或 `black`，只用于已公开阵营着色；
- `motion_profile`：只能由客户端设置产生，不能从棋局事实推导。

`cue_id` 不包含 `motion_profile`。同一公开事件在切换减少动态前后仍是同一 cue，网络重发不能借切档重播；VFX Batch 摘要包含 profile，便于审计实际降级结果。

Batch 字段为：`schema_version, session_public_id, frame_action_index, visible_event_cursor, motion_profile, cues, batch_digest`。摘要为固定字段 JSON 的 SHA-256；相同观察者输入和相同 profile 必须字节等价。

## 3. 固定推导顺序

一个完整公开帧按以下顺序生成，cues 数组即最终顺序：

1. 结算主体：可见 `bombardment_resolved`，随后按公开棋子 ID 排序的位置变化；
2. 可见伤亡：按 `capture_ghosts[].piece_id` 排序的新公开残影；
3. 状态变化：红墙、黑墙，再按旗 ID 排序的发现/进度/占领/取消；
4. 终局：胜利、失败或和局，永远最后。

本地 `selection` 使用独立即时 batch，不与权威结算混排。首次建立非终局 PlayerView 只建基线，不补播历史移动、吃子、城墙或旗帜；首次建立的终局视图可产生一次 `play_once` 终局提示。

## 4. 七族词表与公开位置

| 家族 | cue key | 来源 | 位置规则 |
|---|---|---|---|
| 选中 | `vfx.selection.focus` | 本地公开选中 | 选中交点 `board_2d` |
| 移动 | `vfx.move.step` | 前后 PlayerView 同 ID 公开位置变化 | 当前公开终点；不存在公开终点则不生成 |
| 吃子 | `vfx.capture.impact` | 新增公开 `capture_ghost` | ghost 的公开位置 |
| 炮击 | `vfx.bombardment.resolve` | 可见事件 | 有 `position_public` 则棋盘定位，否则 global；层数不随隐藏伤亡变化 |
| 城墙 | `vfx.wall.breached/repairing/repaired` | `walls[].status` 边沿 | 公开固定墙线中心：红 `[5,4]`、黑 `[5,21]` |
| 旗帜 | `vfx.flag.discovered/progress/captured/cancelled` | `flags[]` 公开边沿 | 已发现用公开位置；未发现而状态仍为公开时仅 global |
| 终局 | `vfx.terminal.victory/defeat/draw` | `PlayerView.terminal/winner` 边沿 | global |

黑方显示映射只改变渲染坐标：`display=(9-x,y-1)`；红方为 `display=(x-1,24-y)`。Cue 永远保留一基权威公开坐标，禁止调用节点搜索或棋子碰撞来“补位置”。

## 5. 去重、迟到与并发

- `VfxDirector` 保存最近 256 个 `cue_id`；重复 batch、网络重发和重复 render 不重播。
- `selection/wall/flag` 使用 `replace_group`；同组达到上限时替换该组低优先效果。
- `move` 使用 `drop_if_late`；低优先 cue 在池或过绘预算不足时丢弃。
- `capture/bombardment/terminal` 使用 `play_once`；高/关键优先级允许替换较低优先槽，但不能突破当前预算。
- 终局不触发相机震动、缩放或规则输入锁；终局 UI 的权威显示顺序仍由现有 MatchScreen 控制。

## 6. 隐藏等价

若两份权威棋局对当前观察者投影后的 `previous PlayerView / current PlayerView / VisibleEvent[]` 完全相同，则在相同 `motion_profile` 下：

- VfxCue 数量、key、位置、阵营、顺序、优先级与 ID 完全相同；
- VfxCueBatch 与 `batch_digest` 完全相同；
- 空位置永远保持 global，不允许填入棋盘中心伪装定位；
- 炮击粒子层数固定，不按不可见命中、伤亡、炮架或随机结果追加；
- 未发现旗位状态变化只能触发 global，不能生成地图坐标。

任何需要额外事实才能达到的效果直接舍弃，不升级 DTO、不猜测位置。

## 7. 交叉合同证据

AudioCue 与 VfxCue v1 共享：字段名、`source_kind`、0 基 occurrence、`global/board_2d` 空间语义、公开位置约束、公开帧排序、去重原则和隐藏等价条件。差异仅是 VFX 追加本地 `motion_profile/actor_side_public`；`reduce_motion` 不改变 SFX。

自动交叉检查位于 `tests/game/vfx/run_vfx_cue_contract.gd`，它校验共享字段集合、顺序、公开位置、同 ID 降级、重复 batch 与依赖禁止项。音频线的正式合同由 `docs/audio/**` 单独拥有，本文件不修改音频事实源。
