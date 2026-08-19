# 45°三维棋盘视觉方向变更影响记录 v1

状态：`direction_confirmed / project-brief-v6-approved / loop-contract-v1-stale`

记录时间：2026-08-19（Asia/Shanghai）

决定者：`project-owner`

来源：`codex-thread://current#owner-freeze-oblique-3d-board-art-direction`

## 1. 项目所有者决定

- 棋盘继续使用原定 24×9 交点，不采用外部方案中的 9×27 示例。
- 新的斜俯视三维棋盘方案替换原先冻结的 90° top-down 2D 俯视方向。
- 在确认方案无结构性缺陷后固定方案并准备美术资源制作。

## 2. 已冻结的新方向

新基线见 `docs/art/veilfront-visual-baseline-v1.md`：一基二维规则坐标、三维棋盘、Sprite3D二维角色、锁定旋转的低FOV斜俯视摄像机、PlayerView信息边界和CanvasLayer界面。

为解决评审发现的问题，基线同时收口：

- 24×9与一基坐标映射；
- 名义50°、30°FOV的可校准镜头带；
- Fixed-Y Billboard与降低后的棋子高度；
- 单一9×24迷雾mask和“未授权节点不创建”；
- Forward+目标、Compatibility样片期保留；
- 源图与运行时纹理分辨率分离；
- 正确的Area3D/StaticBody3D碰撞层级。

## 3. 不受影响的事实

- owner rule revision 5、结算顺序、确定性随机和回放摘要；
- 24×9交点、区域Y范围、城墙线、旗帜与胜负规则；
- FullState/Intent/Event/PlayerView/Replay信任边界；
- 首版Demo不包含AI人机对战；
- GATE-2前不启动高成本批量美术；
- UI右键取消/标记、确认流程和教学必须复用正式规则管线。

## 4. 失效或待修订的输入/产物

| 对象 | 当前状态 | 影响 |
|---|---|---|
| `project-brief.yaml@v5` | 已批准但视觉方向陈旧 | `visual-direction`仍写90° top-down 2D，需要v6重确认 |
| `LOOP-CTR-FORMAL-FOUNDATION-GATE2-001@v1` | 已批准但绑定Brief v5摘要 | 新方向实施前需要Contract修订与项目所有者批准 |
| `formal-godot-scene-composition-v1.md` | Iteration 1已接受 | BoardWorld/Camera2D/TileMapLayer表现映射需要3D successor，旧证据保留 |
| `DELIVERABLE-PRESENTATION-001@iteration1` | accepted_for_iteration_progression | 仍是规则/UI灰盒证据，不再代表最终美术场景结构 |
| I1-S4三分辨率截图 | 有效历史证据 | 仅证明旧2D响应式与信息层，不证明新3D可读性 |

禁止删除或重写以上历史证据；后续 successor 必须显式引用和取代。

## 5. 闸门判定

结果：`revise`

Project Brief v6已确认摘要：`54520517ac26859c24459accb2d7672d12d0224ef69a766f883eda7b2b523289`

Project Brief v6批准：`approval:veilfront-xiangqi-siege:project-brief:54520517ac26`

已满足：

- 项目实例和插件锁为normal；
- 项目所有者已明确新的方向决定；
- 新视觉基线、资产清单和首轮样片任务书已准备。

尚未满足：

- 修订后的Loop Contract批准；
- 45°三维棋盘游戏内样片；
- 960×540、1280×720、1920×1080证据；
- 独立QA对遮挡、透明排序、信息泄露、场景预置和性能的复核；
- GATE-2项目所有者批准。

## 6. 下一合法行动

1. 修订GATE-2 Contract，使架构successor与TASK-ART-001重新绑定，并按精确摘要获得项目所有者批准。
2. 在新Contract范围内制作 `vertical-art-slice-brief-v1.md` 所列少量样片。
3. 由技术负责人复核三维场景映射，独立QA复现三分辨率与信息边界证据。
4. 汇总新的GATE-2决策包；只有项目所有者批准后才能启动批量美术。
