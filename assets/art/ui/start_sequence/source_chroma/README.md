# 标题页设置盾牌来源

- 形状参考：`res://assets/art/pieces/terracotta_warriors/black_infantry_idle.png` 中青铜方兵手持长方竖盾。
- 紫幕源图：`settings_infantry_shield_gear_purple_v1.png`。
- 运行时透明图：`../settings_infantry_shield_gear_v1.png`。
- 生成方式：OpenAI 内置 imagegen；保留方兵盾牌轮廓，删除“兵”字，中央改为金色齿轮，背景使用均匀紫幕。
- 抠图命令：

```powershell
godot --headless --path . --script res://scripts/dev/art/chroma_key_ui_assets.gd -- res://assets/art/ui/start_sequence/source_chroma/settings_infantry_shield_gear_purple_v1.png res://assets/art/ui/start_sequence/settings_infantry_shield_gear_v1.png
```
