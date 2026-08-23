# 联机对局 HUD 效果图 V2：去香盘与三项军势信息

日期：2026-08-23
状态：`effect_mockup / pending_owner_review / purple_screen_not_started`

效果图：`assets/art/ui/concepts/multiplayer_match_hud_ux_reference_v2_no_incense.png`

## 本轮目标

先使用已确认的十区抽象图和上一版联机对局 UI 重新制作整屏效果图。项目所有者确认效果图后，才进入逐区 ImageGen 紫幕源图、抠图、九宫格和 Godot 预置节点接入。

## V2 硬约束

- 完整保留十区比例和职责，不合并、不跨区装饰。
- 删除香盘、计时香、回合香、香炉、竖香、灰盘及其所有计时语义。
- 区域 02 `TurnStatusBar` 是唯一回合／行动方／剩余时间入口。
- 区域 01 与 03 的头像区下方各显示三项公开信息：`已占旗帜`、`损失棋子`、`正在占旗 0/3`。
- 区域 07 的第四行显示当前选中棋子的公开坐标，V2 示例为`当前坐标：(5,7)`；第五行保留为空槽。
- 旧版`兵 / 炮 / 旗 / 损`紧凑统计行不再使用。
- 面板轮廓必须闭合、互不重叠，装饰与阴影不得跨出区域边界，为紫幕拆分保留干净轮廓。

## 效果图参数

| 区域 | V2 示例状态 |
|---|---|
| 01 赤方军势 | `已占旗帜 1/3`、`损失棋子 1`、`正在占旗 0/3` |
| 02 回合状态 | `第 18 回合`、`赤方行动`、`剩余 72 秒` |
| 03 玄方军势 | `已占旗帜 0/3`、`损失棋子 1`、`正在占旗 0/3` |
| 04 战场态势 | 观察者安全标记、镜头框、纵向小地图 |
| 05 单位信息 | `兵`、`兵力 10/10`、`士气 80/100` |
| 06 主棋盘 | 精确感 `9×24` 棋盘、红兵选中、一步路径与合法点 |
| 07 战局与行动 | 已发现旗帜、双方阵亡三条公开事件、`当前坐标：(5,7)`，另留一个空槽 |
| 08 标记工具 | 本地私有`标记`入口 |
| 09 行动模式 | `移动 / 炮击 / 士献祭 / 标记 / 跳过`与单位说明 |
| 10 确认区 | 主操作`确认行动`与次操作`取消` |

## 确认后的紫幕生产计划

本轮未执行以下工作：

1. 分别为军势框、回合栏、小地图框、单位卡、战局抽屉、行动栏、确认区和按钮状态生成纯紫背景源图。
2. 将紫幕源图抠成透明 PNG，并检查边缘残紫、孔洞、半透明阴影和连通域碎片。
3. 面板框制作九宫格；按钮至少产出 Normal / Hover / Pressed / Disabled / Focus 状态。
4. 头像、图标、面板框、按钮底板分开生产；区域 06 的棋盘继续由正式运行时场景渲染，不作为 HUD 紫幕贴图生成。
5. 所有动态文字、数值、进度和事件内容继续使用 Godot 预置 `Label / ProgressBar / TextureRect` 组合，不烘焙进面板 PNG。

建议紫幕源统一使用项目既有高饱和纯紫背景规范，并为每个资产留足安全边距；实际色值、抠图阈值和输出目录在效果图获批后再绑定到现有美术脚本与 manifest。

## ImageGen 最终提示词摘要

```text
Use case: ui-mockup
Asset type: one standalone 16:9 LAN match HUD approval mockup
Input images: Image 1 is the strict ten-region geometry; Image 2 is the visual and gameplay-parameter reference.
Primary request: rebuild the full-screen match HUD with Image 1 geometry and Image 2 dark iron / oxidized bronze / terracotta-warrior style.
Critical removal invariant: remove every incense tray, plate, stick, turn incense, timing incense, burner, vertical incense and ash ornament. Turn and timing information exists only in the top TurnStatusBar.
Force summaries: under each faction portrait show exactly three public cells: captured flags, lost pieces, and current capture progress 0/3. Remove the old soldier/cannon/flag/loss summary.
Preserve: round 18, red turn, 72 seconds, observer-safe minimap, selected infantry 10/10 and morale 80/100, three public event rows, current-coordinate row “当前坐标：(5,7)”, five action modes, infantry movement description, confirm and cancel.
Production readiness: all panel silhouettes closed, opaque and confined to their regions; no cross-region shadow or ornament; no purple background in this approval mockup.
```
