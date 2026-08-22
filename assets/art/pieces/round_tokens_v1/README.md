# 圆形俯视棋子 v1

本目录包含两套 90° 俯视圆形棋子成品，每枚固定为 512×512 RGBA PNG：

- 红方：银白钨钢、暗红内圈，字形为 `帅 / 仕 / 相 / 马 / 车 / 炮 / 兵`。
- 黑方：墨绿青铜、旧金嵌件，字形为 `将 / 士 / 象 / 马 / 车 / 炮 / 卒`。
- `infantry` 保留长矛、阔肩方盾、方顶盔的大轮廓。
- `trebuchet` 保留长投臂、A 形架、投石兜、双轮的大轮廓。

## 小尺寸规则

- 棋子主体限制在 456×456 内，四周至少保留 20px 透明安全边。
- 运行时以 56–64px 为最低常用显示尺寸；依靠大字、粗描边、宽块面辨识。
- Godot 导入必须开启 mipmap 与 `fix_alpha_border`，避免缩小时闪烁、过度模糊或紫边。
- 64px 实际尺寸验收图位于 `evidence/gate2/art-samples/round-tokens-v1/round-tokens-64px-contact-sheet.png`。

## 可重复生成

紫幕母版位于 `evidence/gate2/art-samples/round-tokens-v1/chroma/`，统一使用 `#A100FF` 背景。透明成品由 `scripts/dev/art/chroma_key_round_tokens.gd` 批量抠图、方形居中并缩放生成。
