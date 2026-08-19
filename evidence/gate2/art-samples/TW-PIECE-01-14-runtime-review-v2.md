# “兵马俑”14枚静态棋子运行时审查 v2

状态：`passed_static_asset_review / 14_of_14 / purple_screen_alpha`

总审查页：`evidence/gate2/art-samples/review/TW-PIECE-01-14-runtime-alpha-review-v2.png`

机械报告：`evidence/gate2/art-samples/TW-PIECE-01-14-runtime-validation-v2.json`

## 结论

- 14枚运行时PNG全部为真实RGBA；8枚直立角色为512×768，6枚宽体机械/骑乘资产为768×768。
- 每张四角Alpha均为0，主体存在Alpha=255，紫边检测均为0像素。
- 银白钨钢与墨绿青铜没有再发生阵营误色；双方不仅换色，冠形、肩甲、轮辐、马具、袍甲与动作节奏均有结构差异。
- `炮`为牵引式抛石机：长端柔性吊索石袋、短端多根牵引绳；没有火炮、刚性石勺、扭力束或欧洲配重箱。
- `车/马/将`使用强化动作轮廓；车旗完整且高于主体；相为文官，士为秦侍女；所有人形面具无五官。
- 七个职位字`兵/炮/车/马/相/士/将`在当前源图和审查页中准确可读。

## 七组审查证据

- `review/vs-piece-infantry-camp-alpha-review-v2.png`
- `review/vs-piece-trebuchet-camp-alpha-review-v2.png`
- `review/vs-piece-chariot-camp-alpha-review-v2.png`
- `review/vs-piece-cavalry-camp-alpha-review-v2.png`
- `review/vs-piece-minister-camp-alpha-review-v2.png`
- `review/vs-piece-guard-camp-alpha-review-v2.png`
- `review/vs-piece-general-camp-alpha-review-v2.png`

## 保留问题

1. 正式秦小篆七字仍需可靠字源、同系列矢量重绘和授权记录；当前像素字只属于本轮静态样片。
2. 方形源实际为1254×1254，不冒充1536×1536；运行时768×768为合法等比缩小。
3. 还需在Godot预置棋盘完成96px、近中远、双方视角、透明排序、mipmap和遮挡验证。
4. 本轮没有生产动作、头像裁切、底座、假阴影、UI、特效或音频。
