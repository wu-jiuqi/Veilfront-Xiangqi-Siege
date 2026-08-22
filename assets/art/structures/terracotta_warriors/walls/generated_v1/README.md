# 九路城墙 v1

`city_wall_chroma_v1.png` 是保留纯紫色 `#FF00FF` 背景的生成源图，
`city_wall_v1.png` 是经 `tools/art/purple_chroma_key.py` 抠图、去紫边和紧致裁切后的
`1536×241` RGBA 运行时资产。

## 制作记录

- 日期：2026-08-22
- 生成工具：Codex 内置 `imagegen`
- 用例：`stylized-concept`
- 构图：横向连续秦代城防阵线，九个节奏段，无城门、无断口、无场景和投影
- 材质：旧石、暗铁、克制的古金与余烬红，匹配当前兵马俑战场
- 接入：`wall_view.tscn` 的预置 `Sprite2D`，每方整墙只实例化一次

红黑阵营与 `INTACT/BREACHED/REPAIRING` 状态由预置场景脚本进行色调、透明度和高度
表现；规则、碰撞、寻路与信息判断不读取图片。
