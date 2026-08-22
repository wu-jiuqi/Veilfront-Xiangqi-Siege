# Terminal Result UI V2

正式结算页的 PNG 视觉资产。运行时引用本目录根部的透明 RGBA PNG；`source_chroma/` 仅保存可复现的纯紫幕原图。

## 生成与抠图流程

工具：OpenAI 内置 imagegen + `res://scripts/dev/art/chroma_key_ui_assets.gd`。

最终提示集摘要：

1. 主框：生成紧凑、对称的中国古代军令牌匾；黑漆与锻铁主体、旧铜和暗金包边、左暗朱右墨绿阵营带、三格统计区和按钮承托区；禁止文字、人物、场景和全屏背景。
2. 主按钮：单个约 `4.2:1` 的横向按钮牌；黑铁中心、厚实旧金边、克制云雷纹、留出中文与图标区域。
3. 次按钮：保持主按钮几何，将大面积金边降为黑化旧铜，仅保留细暗金轮廓。
4. 三张图的外部背景均要求纯色、均匀、不透明 `#FF00FF`，禁止渐变、阴影、辉光、棋盘格和紫色溢色。

抠图命令使用成对输入／输出参数：

```text
godot --headless --path . --script res://scripts/dev/art/chroma_key_ui_assets.gd -- <紫幕输入.png> <透明输出.png>
```

## 运行时资产

- `terminal_result_panel_v2.png`：`1379×881`，RGBA。
- `terminal_result_button_primary_v2.png`：`1598×372`，RGBA。
- `terminal_result_button_secondary_v2.png`：`1600×363`，RGBA。

UI 图片使用无损导入、关闭 mipmap，并保留 Fix Alpha Border。Godot 场景通过 `TextureRect` 与 `TextureButton` 缩放，不直接读取紫幕源文件。
