# 棋盘与 HUD 布局工具视觉基线

- 用途：项目内部桌面浏览器布局工具，不承担游戏内品牌展示，因此不在工作区占用布局空间放置 Logo。
- UI 资产：`assets/art/ui/terracotta_hud_v2/` 下的正式 HUD V2 透明 PNG。
- 棋盘背景：`assets/art/boards/terracotta_warriors/terracotta_battlefield_board_bg_gridless_v1.png`。
- 视觉语言：薄型锻铁、深绿氧化青铜、少量旧金线、低反射暗底。
- 工具强调色：旧金表示 UI 选择与缩放手柄；青色只表示棋盘默认可视区域。
- 文字图层：沿用旧金强调色，以细虚线框区别于 HUD 外框；坐标始终相对所属 HUD 保存。
- 场景覆盖：以 `match_hud_v2_interaction_lab.tscn` 实例化的 `MatchHudV2` 为准，包含棋子信息展开栏、四个技能按钮、回合数字和回合标题。
- Container 约束：由 Godot `Container` 管理的文字节点只允许编辑文案、字号、对齐和显示状态；网页中的相对框仅用于预览，不导出为强制锚点。
- 字体：楷体用于工具标题，微软雅黑用于界面文本，Consolas 用于坐标与结构化数据。
- 间距：4/8 px 倍数；2 px 小圆角；120–180 ms 操作反馈。
- 禁止：紫粉渐变、霓虹赛博配色、Emoji 图标、伪造游戏数据、用 CSS 图形替代已有正式 HUD 贴图。
