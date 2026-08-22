# 正式结算页 UI v2

状态：`implemented / owner-requested visual rework 2026-08-22`

## 视觉结论

V2 放弃 V1 的“九宫格框 + StyleBox 表格”表现，改用一张紫幕抠图得到的透明 PNG 军令牌匾承载完整视觉层级。牌匾只覆盖战场中央，不附带全屏背景或遮罩；Godot 继续叠加真实文字、状态和输入节点。

## 预置结构

```text
TerminalDialog (Control, Full Rect, input modal)
└─ SafeMargin
   └─ Center
      └─ ResultPanel (AspectRatioContainer)
         ├─ PanelArt (transparent PNG)
         └─ ContentOverlay
            ├─ TerminalHeading
            ├─ ResultTitle
            ├─ ReasonLabel
            ├─ RedResult / BlackResult
            ├─ Stats (HBoxContainer)
            └─ Actions (HBoxContainer)
               ├─ RestartButton (TextureButton)
               ├─ LobbyButton (TextureButton)
               └─ LevelSelectButton (TextureButton)
```

## PNG 资产

- `terminal_result_panel_v2.png`：完整透明牌匾，包含兽首、赤玄阵营带、三格统计槽和按钮承托区。
- `terminal_result_button_primary_v2.png`：金色主行动按钮底图。
- `terminal_result_button_secondary_v2.png`：黑铁次行动按钮底图。
- `source_chroma/`：保留 imagegen 的纯紫底原图，供抠图复现。

按钮使用 `TextureButton.texture_normal / texture_hover / texture_pressed / texture_focused` 切换 PNG。中文文案不烘焙进图片，而是使用鼠标穿透的子 `Label`，从而保持本地化、字体和无障碍能力。

## 紫幕抠图

使用项目既有 `scripts/dev/art/chroma_key_ui_assets.gd`：

1. imagegen 输出纯色 `#FF00FF` 背景的面板和按钮源图。
2. 脚本按紫色 hue 与饱和度计算 Alpha，清理低 Alpha 像素。
3. 自动按有效像素边界裁切，并保留 4 px 安全边缘。
4. 运行时只引用抠图后的 RGBA PNG，绝不引用紫幕源图。

## 逻辑与信息安全

数据映射、LAN／挑战关卡模式分流、重赛等待新 `PlayerView`、输入阻断和焦点循环沿用 V1；视觉重做不改变规则或观察者安全边界。

## 响应式合同

- 面板保持原始 `1379:881` 比例。
- `960×540` 最小目标为约 `760×486`。
- `1280×720` 目标宽度约为视口的 72%。
- 桌面大分辨率最大宽度为 940 px，避免再次变成接近全屏的表格。
- 所有按钮高度为 58 px，保持键鼠和手柄可操作性。

## 证据

- 组件合同：`tests/game/ui/run_terminal_dialog_contract.gd`
- LAN 回环：`tests/game/network/run_formal_lan_full_stack_loopback.gd`
- V2 截图：`evidence/ui/formal-terminal-dialog-v2-1280x720.png`
