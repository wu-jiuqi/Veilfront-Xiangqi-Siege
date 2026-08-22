# 正式结算页 UI v1

状态：`superseded 2026-08-22`。项目所有者否决了 V1 视觉，正式基线改见 `terminal-result-ui-v2.md`。

## 目标

把基础 `AcceptDialog` 替换为正式中央结算框。结算组件不提供独立战场背景或烘焙文字，保留对局结束时的观察者安全棋盘画面；固定结构使用预置 `Control` 与容器，动态内容只来自已校验的本地 `PlayerView`。

## 预置结构

```text
TerminalDialog (Control, Full Rect, input modal)
└─ SafeMargin
   └─ Center
      └─ ResultPanel (HUD V2 nine-patch)
         └─ ContentMargin
            └─ Content
               ├─ TerminalHeading
               ├─ ResultHero / VictorySeal / ResultTitle
               ├─ ReasonLabel
               ├─ FactionResults
               │  ├─ RedFactionPanel / RedResult
               │  ├─ FactionEmblem
               │  └─ BlackFactionPanel / BlackResult
               ├─ ReviewPanel
               │  └─ RoundStat / FlagStat / CasualtyStat
               └─ Actions
                  ├─ RestartButton
                  ├─ LobbyButton
                  └─ LevelSelectButton
```

面板复用 `assets/art/ui/terracotta_hud_v2/hud_panel_9slice_v1.png`、全局四态按钮和既有 SVG 图标。赤方与玄方结果条使用局部 `StyleBoxFlat` 语义色，不复制业务场景或生成带字 PNG。

## 数据映射

结算组件只读取本地 `PlayerView` 的公开字段：

- `viewer_side + winner`：本地显示“胜利 / 败北 / 和局”。
- `win_reason`：映射公开胜负原因；未知键只显示“战局结束”，不输出内部规则栈。
- `full_round_index`：完整回合数。
- `flags[].discovered + owner`：只统计当前观察者已获授权的军旗归属。
- `casualties[].side`：统计双方公开阵亡数。

组件不读取 `FullState`、seed、RNG、隐藏棋子、未发现旗位或未授权事件。

## 模式分流

| 上下文 | 重赛 | 返回大厅 | 关卡选择 | 默认焦点 |
| --- | --- | --- | --- | --- |
| LAN | 隐藏 | 显示 | 隐藏 | 返回大厅 |
| 挑战关卡 | 显示 | 隐藏 | 显示 | 重赛 |
| 组件预览 | 显示 | 显示 | 显示 | 重赛 |

LAN v1 不允许客户端本地直接重开，因此继续执行“完整清理会话后返回大厅”。挑战关卡重赛通过 `ApplicationHost.request_restart()` 与 `MatchClientPort` 重建同一固定种子局面；在新的非终局 `PlayerView` 到达前，结算框不会抢先关闭。

## 输入与响应式合同

- 全屏根节点拦截鼠标，结算显示期间 `ui_cancel` 不会穿透到棋盘或离场流程。
- 可见按钮形成左右循环焦点链；LAN 默认聚焦“返回大厅”，关卡默认聚焦“重赛”。
- 隐藏结算框时释放按钮焦点，避免焦点停留在不可见控件。
- 中央面板由 `MarginContainer + CenterContainer` 布局，并在 `960×540`、`1280×720`、`1920×1080` 内保持 18 px 安全边距；按钮高度不低于 44 px。

## 实现与证据

- 场景：`scenes/game/ui/terminal_dialog.tscn`
- 组件逻辑：`scripts/game/presentation/ui/match_terminal_dialog.gd`
- 对局接线：`scripts/game/presentation/match_screen.gd`
- LAN 路由：`scripts/game/application/formal_lan_game_app.gd`
- 挑战关卡路由：`scripts/game/tutorial/tutorial_level.gd`
- 组件合同：`tests/game/ui/run_terminal_dialog_contract.gd`
- 挑战重赛合同：`tests/game/tutorial/run_challenge_terminal_flow.gd`
- LAN 回环：`tests/game/network/run_formal_lan_full_stack_loopback.gd`
- 视觉证据：`evidence/ui/formal-terminal-dialog-v1-1280x720.png`
