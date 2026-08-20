# LAN兵马俑棋子视觉接入验证 v1

## 范围

- 批准：`approval:veilfront-xiangqi-siege:production-scope-exception:228910adda53`
- 入口：`scenes/prototype/network/lan_lobby.tscn`
- 渲染：`scripts/prototype/board_surface.gd`
- 资产：既有红方银白钨钢、黑方深墨绿青铜14张RGBA棋子纹理。
- 本轮只替换当前LAN原型的棋子表现；未修改规则、GameState、PlayerView投影、RPC、协议或网络会话。

## 实现结果

- `BoardSurface`预加载并映射`red/black × pawn/cannon/rook/horse/elephant/advisor/general`共14张纹理。
- 只有`schema_version=lan-player-view-v3`时启用兵马俑贴图；单机灰盒及未知版本继续使用原圆形字棋回退。
- 贴图只从`PlayerView.pieces`建立绘制规格，并过滤`alive=false`、`in_reserve=true`和无有效`position`的条目。
- 人形纹理使用`anchor_y=0.94`，炮、车、马方形纹理使用`anchor_y=0.92`；统一等比缩放并以脚底落在权威交点。
- 选择框、行动高亮、标注、旗帜与捕获残影改在棋子之后绘制，保持交互反馈可读。
- 未创建棋子节点、未读取FullState；未知接触和捕获残影仍使用原降级表达。

## 自动验证

- Godot 4.7.1 / GDA静态分析：`scripts/prototype/board_surface.gd`有效，零诊断。
- `tests/prototype/network/run_lan_terracotta_piece_visual_contract.gd`：通过。
  - 14纹理映射完整。
  - 标准全显夹具双方各16枚、合计32枚。
  - 双方均为5兵、2炮、2车、2马、2相、2士、1将。
  - 全部绘制规格等比缩放并按脚底锚定。
  - 受限PlayerView只产生其中两枚可见在场棋子的绘制项；隐藏、阵亡和reserve条目不产生贴图项。
  - 非LAN PlayerView保持字棋回退。
- `tests/prototype/run_playtest_graybox.gd`：通过。
- `tests/prototype/network/run_lan_network_integration.gd`：通过；loopback主客双方继续收到各自`lan-player-view-v3`，行动权和可靠RPC推进未回归。

## 实机效果证据

- 房主红方，1280×720：`evidence/prototype/qa/lan-terracotta-piece-host-red-1280x720-v1.png`
  - SHA-256：`DFF3B36B3B534E0D5884C303F8081E3AC94FD2DE3FE4ECA95201212E42E381D2`
- 客户端黑方，1280×720：`evidence/prototype/qa/lan-terracotta-piece-client-black-1280x720-v1.png`
  - SHA-256：`93A93C68C3BA1B7B0B0684A9FD60114ACFC542741E9DC6B5EF9340DEA63F59E4`

截图由正式LAN大厅中的`NetworkBoard`预置生成，分别注入红、黑观察者安全的全显测试PlayerView；真实ENet传输由独立loopback集成测试验证。截图夹具用于审查阵营、尺寸、锚点和双方置底视角，不把全显状态解释为实际迷雾对局。

## 已知问题与后续

- 当前24×9长棋盘仍通过滚动查看，截图只展示己方阵地近景；这符合现有LAN灰盒，不代表最终全盘构图。
- 顶部联机灰盒控件在1280×720较拥挤，属于后续UI范围，本例外没有授权修改。
- 当前效果只在LAN原型启用；正式比赛场、Steam/互联网联机和GATE-2仍未获本批准覆盖。
