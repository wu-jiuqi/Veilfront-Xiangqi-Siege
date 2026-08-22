# 圆形旗帜 v1

本目录保存中立、红方、黑方三枚圆形夺旗标记。运行时成品为 `768×768` RGBA，
以棋盘交点为圆心，显示直径为单格的 `98%`，略大于棋子的 `84%` 安全直径。

| 状态 | 紫幕源图 | 运行时成品 |
|---|---|---|
| 中立 | `neutral_flag_round_chroma_v1.png` | `neutral_flag_round_v1.png` |
| 红方 | `red_flag_round_chroma_v1.png` | `red_flag_round_v1.png` |
| 黑方 | `black_flag_round_chroma_v1.png` | `black_flag_round_v1.png` |

## 制作记录

- 日期：2026-08-22
- 生成工具：Codex 内置 `imagegen`
- 参考：同阵营竖旗与 `round_tokens_v1` 圆形棋子
- 紫幕：生成稿使用纯紫色 `#FF00FF` 背景，不直接请求透明图
- 抠图：`tools/art/purple_chroma_key.py`，包含色差判定、内向羽化、紫边抑制、
  紧致裁切与透明方形画布归一化
- 共同约束：单体、圆形、无场景、无外部投影、无水印；旗杆和流苏不得越出圆框

运行时只引用无 `_chroma_` 后缀的 RGBA 文件；紫幕原稿保留用于复现和抠图审计。
