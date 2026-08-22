# 加载与场景过渡页 UI 资产

本目录保存加载过渡页的高精度九路战印与失败弹窗按钮底板。运行时资产不烘焙文字或图标，由 Godot 预置节点覆盖中文、焦点与补间反馈。

## 文件

- `loading_nine_route_seal_v1.png`：加载页中央九路战印；主体保持静止，外围加载环单独补间。
- `failure_retry_button_v1.png`：重试按钮，深色锻铁、氧化青铜与克制的赤红警示内线。
- `failure_back_button_v1.png`：返回按钮，中性冷铁与旧金描边。
- `source_chroma/`：图像生成器输出的无字纯紫幕母版；由 `.gdignore` 隔离，不参与 Godot 导入。

## 可复现处理

```powershell
& 'D:\Godot\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://scripts/dev/art/chroma_key_ui_assets.gd -- res://assets/art/ui/loading_transition/source_chroma/loading_nine_route_seal_purple_v1.png res://assets/art/ui/loading_transition/loading_nine_route_seal_v1.png res://assets/art/ui/loading_transition/source_chroma/failure_retry_button_purple_v1.png res://assets/art/ui/loading_transition/failure_retry_button_v1.png res://assets/art/ui/loading_transition/source_chroma/failure_back_button_purple_v1.png res://assets/art/ui/loading_transition/failure_back_button_v1.png
```

抠图规则使用项目统一的紫色 Hue 柔边键出流程，输出自动裁边的 RGBA PNG。
