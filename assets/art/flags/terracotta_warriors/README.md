# 兵马俑管线夺旗旗帜

本目录保存三面 `1024×1536` RGBA 透明旗帜源图，面向斜俯视棋盘中的 `Sprite3D` 表现。

| 文件 | 状态 | 设计口径 |
|---|---|---|
| `neutral_flag.png` | 中立 | 灰黑织物、暗铁旗杆、少量旧金目标强调；无文字 |
| `black_flag_captured.png` | 黑方占领 | 深墨绿青铜、凹面铜绿、旧金边；中央单字篆书风格“秦” |
| `red_flag_captured.png` | 红方占领 | 银白钨钢、蓝灰反射、暗朱流苏；中央单字篆书风格“秦” |

## 生成记录

- 日期：2026-08-20
- 工具：Codex 内置 `imagegen`
- 用例：`stylized-concept`、`precise-object-edit`、`text-localization`、`background-extraction`
- 风格参考：`assets/art/pieces/terracotta_warriors/black_infantry_idle.png`、`assets/art/pieces/terracotta_warriors/red_infantry_idle.png`
- 生成口径：先生成统一中立母版，再仅替换两方材质；两方占领态中央各加入一次准确文字“秦”（U+79E6）；最后单独提取真实 Alpha。
- 共同约束：单体完整入框、固定脚底线、无场景/阴影/水印、无额外文字、保留透明安全边距。
- 人工修改：未进行像素级重绘；只做文件命名、Alpha/尺寸审计与项目归档。

## 使用与验收限制

- 三张图已经通过 RGBA、四角透明、非透明内容包围盒检查；Godot 导入时应开启 mipmap、`fix_alpha_border` 与 VRAM Compression，并将运行时长边限制为不高于 `768px`。
- 当前“秦”字为生成式篆书风格样片，字义可读但不是经过字源校对的正式秦小篆矢量母版。若进入最终商用资产，必须以授权明确、经人工校对的矢量字形替换。
- 生成式输出的最终发行使用权需由项目所有者按所用账户条款完成资产合规复核。
