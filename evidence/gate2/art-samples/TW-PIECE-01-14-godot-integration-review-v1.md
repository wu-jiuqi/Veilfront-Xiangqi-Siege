# 兵马俑14母版 / 32实例 Godot 接入审查 V1

日期：2026-08-20
目标场景：`scenes/dev/art/piece_art_test_3d.tscn`

## 接入结果

- 14 张已验证 RGBA 运行时纹理复制到 `assets/art/pieces/terracotta_warriors/`，不再从被 `.gdignore` 排除的 `evidence/` 目录加载。
- 14 个可复用 `Piece3D` 预置变体位于 `scenes/dev/art/terracotta_warriors/pieces/`。
- 测试场实例化 32 枚棋子：红方银白钨钢 16 枚、黑方墨绿青铜 16 枚。
- 双方底线均为 `车马相士将士相马车`；炮位为第2、8路；兵位为第1、3、5、7、9路。
- 红方占用 `Y=1/3/4`，黑方占用 `Y=24/22/21`；每枚实例保留一基 `authority_cell` 元数据。
- 全盘、红方、黑方三个镜头预置保持 55°俯角与30° FOV，通过 `Space/2`、`Home/1`、`End/3` 切换。
- 通用硬矩形假阴影已替换为柔边椭圆透明纹理。

## 运行时规格

- 人形棋子：512×768，锚点 `(0.50, 0.94)`。
- 骑兵：768×768，显示高度约2.00世界单位，锚点 `(0.50, 0.92)`。
- 战车与牵引式抛石机：768×768，显示高度约2.10世界单位，锚点 `(0.50, 0.92)`。
- 14 张纹理均启用 VRAM Compressed、mipmap 与 Fix Alpha Border。
- Sprite3D 保持 Fixed-Y Billboard、Opaque Pre-Pass、关闭实时投影并使用假阴影接地。

## 验证

- Godot：4.7.1 stable，Compatibility/OpenGL 3.3 实机截图。
- GDA：目标场景及14个外部预置全部解析为 `instance_status=resolved`。
- 场景运行：headless加载3帧，无解析或运行时错误。
- 计数：32实例，红方16，黑方16。
- 导入：14/14 mipmap开启，14/14 Fix Alpha Border开启，14/14 VRAM纹理。
- 相机与截图脚本均通过 GDScript 静态校验。

## 审查图

- `evidence/gate2/art-samples/review/piece-art-test-3d-full-formation-v1.png`
- `evidence/gate2/art-samples/review/piece-art-test-3d-red-camp-v1.png`
- `evidence/gate2/art-samples/review/piece-art-test-3d-black-camp-v1.png`

## 仍待验证

- 全盘概览只用于空间核对，棋子细节需使用红/黑阵营近景预置；这再次证明24线长棋盘不适合用单一固定镜头同时承担细节阅读。
- 尚未在正式对局场景接入规则状态、PlayerView、点击、移动或双方180°视角切换。
- 正式96px盘内可读性、多个目标分辨率、遮挡和色觉弱化仍需独立QA。
- 金色职位字仍是生成式静态图的一部分，不替代经字源校对和授权的秦小篆矢量母版。
