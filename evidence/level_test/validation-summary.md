# 三关试玩版验证摘要

- 验证日期：2026-08-18（Asia/Shanghai）
- Godot：4.7.1-stable official
- 分支：`codex/level-test-playable`
- 关卡主体提交：`45fe5d3`

## 自动检查

- `tests/level_test/run_level_test_checks.gd`：退出码 0，`LEVEL_TEST_CHECKS_PASSED`。
- `tests/prototype/run_all.gd`：退出码 0，`PROTOTYPE_BASIS_CHECKS_PASSED`。
- `tests/prototype/run_owner_rule_revision_v5.gd`：退出码 0，`OWNER_RULE_REVISION_V5_PASSED`。
- `tests/prototype/run_playtest_graybox.gd`：退出码 0，`PLAYTEST_GRAYBOX_SMOKE_PASSED`。
- 新增及改动 GDScript 均通过 `gda script validate --json`，关卡主场景通过 `gda scene get --json` 加载。

## 覆盖结论

- 三关敌军数量、类型和 Y=16 初始位置正确。
- 我方 11 枚非兵棋子位于大本营 Y=1–3；五个兵位于红方城墙线 Y=4 的标准兵位。
- 试玩界面与行动候选均限制为 Y=1–16，共 144 个交互点。
- 敌军初始受迷雾遮蔽；敌方 AI 审计确认只依赖 PlayerView。
- 单枚受威胁时始终优先移动该棋；即使另一枚未受威胁棋子存在安全吃子也不抢占优先级。
- 双枚同时受威胁时只会移动受威胁棋子，并在 64 个固定种子中随机覆盖两枚棋子。
- 落点决策在固定种子下保持“安全吃子 > 安全空移 > 无安全落点兜底”，危险吃子不会压过安全空移。
- 消灭全部敌棋判胜；50 完整回合仍有敌军时判负。
- 窗口化截图确认首屏显示我方大本营、完整初始棋子、城墙和关卡状态。

## Windows 构建

- 文件：`builds/windows/Veilfront_Xiangqi_Siege_Level_Test.exe`
- 版本：`0.1.1.0`（威胁优先 AI）
- 大小：110,085,664 字节
- SHA-256：`87222F7BCD8200A1FE8214D53FA87513B1B29DBBE6C95CF5DF0CFD40CECAFCD5`
- 导出：Godot release，嵌入 PCK，单文件。
- 进程冒烟：导出程序启动 5 秒后仍正常运行，通过。
- 签名：未签名；Windows SmartScreen 可能提示。

## 人工判断边界

以上是客观功能与运行证据，不替代项目所有者对难度、节奏和体验质量的人工试玩结论。
