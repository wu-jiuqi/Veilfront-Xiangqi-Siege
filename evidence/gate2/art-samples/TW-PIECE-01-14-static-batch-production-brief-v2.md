# “兵马俑”14枚静态棋子生产任务书 v2

状态：`completed_historical_output / approved_limited_retrospective_exception / pending_godot_board_readability`

治理说明：此前记录不符合 `game-production-approval/v1`，且没有绑定项目所有者确认的精确摘要，已从有效审批目录移除。项目所有者随后按摘要`95214ab75a156a4570e561f2780e9e9e9bb442291085cfd41cd13be793a90c5f`批准追认与有限继续使用例外，正式记录为`game-pipeline/approvals/production-scope-exception-static-14-piece-95214ab75a15.yaml`。本文件仍只记录已经发生的生产事实，不主张存在事前授权，也不表示GATE-2通过。

## 生产范围

仅生产`(兵、炮、车、马、相、士、将) × 银白钨钢/墨绿青铜`共14枚静态单体棋子。不包含动作序列、正式小篆矢量母版、UI、VFX、音频或其他GATE-2批量项。

| 角色 | 银白钨钢 | 墨绿青铜 | 源画幅 | 运行时画幅 | 识别锚点 |
|---|---|---|---:|---:|---|
| 兵 | `01-red-infantry` | `02-black-infantry` | 1024×1536 | 512×768 | 盾、矛、金色`兵` |
| 炮 | `05-red-trebuchet` | `06-black-trebuchet` | 1254×1254 | 768×768 | 牵引式抛石机、金色`炮` |
| 车 | `07-red-chariot` | `08-black-chariot` | 1254×1254 | 768×768 | 三马战车、高旗、金色`车` |
| 马 | `03-red-cavalry` | `04-black-cavalry` | 1254×1254 | 768×768 | 半扬蹄骑兵、金色`马` |
| 相 | `09-red-minister` | `10-black-minister` | 1024×1536 | 512×768 | 文官、笏板、金色`相` |
| 士 | `11-red-guard` | `12-black-guard` | 1024×1536 | 512×768 | 秦侍女、礼牌、金色`士` |
| 将 | `13-red-general` | `14-black-general` | 1024×1536 | 512×768 | 举剑号令、金色`将` |

## 统一管线

1. 图像生成/编辑阶段只输出纯紫幕RGB源，目标色`#FF00FF`；禁止灰底直抠、烘焙棋盘格、地面和投影。
2. `tools/art/remove_chroma_background.py`从图像边界估算实际紫幕色与最低紫色纯度，生成真实RGBA，并对半透明边缘反算去除紫边。
3. `tools/art/prepare_runtime_texture.py`以预乘Alpha缩小，避免Godot纹理过滤产生亮边。
4. 直立角色输出512×768；宽体机械、战车和骑兵输出768×768。禁止非等比拉伸和把1254源冒充1536原生细节。
5. `tools/art/validate_piece_batch.py`检查数量、尺寸、模式、四角Alpha、紫边与SHA-256。

## 阵营与结构

- 银白方：高明度冷银白钨钢、方冠/方肩/锐边、小面积暗朱系绳。
- 墨绿方：近黑墨绿青铜、弯钩冠/圆弧叠层/厚暖铜边、不同轮辐与马具。
- 所有人形均使用光滑无五官金属面具，无眼孔、鼻、嘴、皮肤或人脸反射。
- 金色职位字是当前生成式概念像素结果，可用于静态样片识别，不能替代后续逐字校对的正式秦小篆矢量母版。

## 输出

- 纯紫幕源：`evidence/gate2/art-samples/sources/chroma/`
- RGBA源：`evidence/gate2/art-samples/sources/*-source-alpha-v2.png`
- 运行时纹理：`evidence/gate2/art-samples/runtime/`
- 七组双阵营审查页与总审查页：`evidence/gate2/art-samples/review/`
- 机械校验：`evidence/gate2/art-samples/TW-PIECE-01-14-runtime-validation-v2.json`

## 后续边界

静态资产已经完成，但尚未因此自动通过96px盘内可读性、遮挡、双方视角、mipmap导入和显存检查。上述内容需在预置Godot棋盘中另行验证；不得把本次静态审查等同于GATE-2整体批准。
