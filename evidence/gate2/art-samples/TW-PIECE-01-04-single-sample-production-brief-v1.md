# “兵马俑”红黑步兵/骑兵单体样片生产任务书 v1

状态：`authorized_sample_work / task_art_001 / no_batch_production`

Contract：`LOOP-CTR-FORMAL-FOUNDATION-GATE2-001 v2`

工作项：`ITERATION-3R-OBLIQUE-3D-VISUAL / TASK-ART-001 / DELIVERABLE-ART-001`

责任角色：`pos:veilfront-xiangqi-siege:design-experience:visual-production-lead`

升级路径：涉及14套正式母版、动作批量、正式字体授权、预算或风格方向变化时，升级到项目所有者/GATE-2，不在本任务内自行扩大范围。

## 目标

制作四个Contract允许的单体视觉样片：

1. `VS-PIECE-01` 红方银白钨钢步兵；
2. `VS-PIECE-02` 黑方深墨绿青铜步兵；
3. `VS-PIECE-03` 红方银白钨钢骑兵；
4. `VS-PIECE-04` 黑方深墨绿青铜骑兵。

产物用于验证透明边缘、统一画幅、脚底/马蹄锚点、阵营差异、96px轮廓和斜俯视棋盘可读性，不是最终发行母版。

## 输入

- 已由项目所有者确认的14棋子轮廓审查页V2；
- 红方银白钨钢步兵风格锚点R3；
- 黑方墨绿青铜步兵风格锚点R2；
- “兵马俑”专属管线v1和斜俯视视觉基线v1。

## 统一画幅与锚点

| 类型 | 源画幅目标 | 运行时目标 | 内容安全框 | 底部锚点 | 构图中心 |
|---|---:|---:|---|---|---|
| 步兵 | 1024×1536 RGBA | 512×768 RGBA | 左右各≥6%，顶部≥4%，底部≥4% | 脚底中点`(0.50, 0.94)` | 胸盾区域约`(0.50, 0.47)` |
| 骑兵 | 1536×1536 RGBA | 768×768 RGBA | 左右各≥5%，顶部≥5%，底部≥5% | 前后马蹄包围盒底边中点`(0.50, 0.92)` | 骑手躯干约`(0.53, 0.39)` |

若内置生成器不能直接达到目标源尺寸，必须保留实际尺寸和差异记录，不得把插值放大冒充原生细节。运行时版本只允许从经确认的源图等比缩小，不允许非等比拉伸。

## 统一视觉参数

- 视角：角色正面偏右的三分之四视角，适配名义50°俯角的Fixed-Y Sprite3D；两方朝向一致，阵营切换不镜像文字。
- 光照：相同中性工作室三点布光；左前上方主光、右后方窄轮廓光、弱正面补光；背景透明，不烘入地面、投影或环境色块。
- 金属：红方高明度冷银白钨钢，清晰冷色镜面高光但不得成为铬；黑方近黑墨绿青铜，青铜磨边高光和少量凹部铜绿，暗部不能糊成纯黑。
- 形状：红方方正冠形、方肩、锐利盾缘和小面积暗朱系绳；黑方弯钩冠形、圆弧叠甲、厚重青铜边和不同盾缘/马具。
- 面具：完整光滑无五官曲面，禁止眼孔、鼻、嘴、表情、裸露皮肤和人脸反射。
- 职位字：步兵盾面只出现一个金色`兵`，骑兵马胸牌/鞍侧牌只出现一个金色`马`；概念像素字必须准确可读，但不得作为正式SVG字形母版。
- 细节分级：先保证头冠、肩甲、盾/马头、武器和四肢一级轮廓；铆钉、甲片、绳结为二级细节；细纹不得依赖96px显示。

## 输出与命名

源样片：

- `evidence/gate2/art-samples/sources/vs-piece-01-red-infantry-source-v1.png`
- `evidence/gate2/art-samples/sources/vs-piece-02-black-infantry-source-v1.png`
- `evidence/gate2/art-samples/sources/vs-piece-03-red-cavalry-source-v1.png`
- `evidence/gate2/art-samples/sources/vs-piece-04-black-cavalry-source-v1.png`

运行时候选：

- `evidence/gate2/art-samples/runtime/vs-piece-01-red-infantry-512x768-v1.png`
- `evidence/gate2/art-samples/runtime/vs-piece-02-black-infantry-512x768-v1.png`
- `evidence/gate2/art-samples/runtime/vs-piece-03-red-cavalry-768x768-v1.png`
- `evidence/gate2/art-samples/runtime/vs-piece-04-black-cavalry-768x768-v1.png`

运行时目录只有在源图真实Alpha、构图和锚点通过后才可写入；不合格输出保留在`sources/`并标记`revise`，不得伪装成运行时资产。

## 验收检查

- 文件像素尺寸、颜色模式和Alpha通道逐项记录；透明背景必须是真实Alpha，不接受烘焙棋盘格、白底或灰底。
- 武器、头冠、马耳、马蹄、盾缘均不裁切；透明边缘无明显白边、黑边或锯齿污染。
- 同类型两方脚底线/马蹄线误差≤2%画布高度，主体包围盒面积差≤10%。
- 红黑双方在灰度下仍可通过冠形、肩甲、盾缘、马具与轮廓区分。
- 96px高度下能先辨识兵/马类别，再辨识阵营；金字不作为唯一识别条件。
- 本轮只允许生产四张静态样片与验证证据，不生成动作序列、其余10角色或最终发行资源。

## 失败返回

- Alpha失败：返回单体背景提取，不进入运行时目录。
- 构图/锚点失败：只修正画布占比和位置，不重设角色设计。
- 材质失败：只修正明度、粗糙度和边缘高光，不改变阵营结构语言。
- 96px识别失败：优先简化二级细节、放大一级轮廓；仍失败才返回轮廓审查页。
