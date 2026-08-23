# GATE-2 v3 UI 可读性修整交接

- Contract：`LOOP-CTR-FORMAL-FOUNDATION-GATE2-001` v3
- 工作项：`TASK-PRESENTATION-2D-001`
- 生产者：Godot 技术负责人 `inst:01M02NJ3JEQXKV6PT6DPX0NKQ0`
- 引擎：Godot 4.7.1 stable
- 状态：生产者合同通过；待 QA 在干净工作树独立复现和人工视觉检查

## 修整结果

### 正式 HUD

- JSON 布局的阵营名称、单位名称和面板标题为 16px。
- 阵营数据、选择状态、旗帜/阵亡/坐标和棋子说明为 15px。
- 小地图标题、单位立绘占位和回合辅助标题为 14px。
- 棋子操作按钮文字为 16px。
- 1280×720 正式棋盘可见矩形由 600px 调整为 552px：右缘为 892px，为右侧教程面板保留不重叠区域；权威棋盘世界坐标和 PlayerView 未改动。

### 教学面板

- 教学面板继续使用预置 `Control`、`FoldableContainer`、`ScrollContainer` 和 `VBoxContainer`，没有动态创建固定 UI。
- 1280×720 下外框从 x=900 开始、宽 376px；棋盘右缘为 892px，保留 8px 间隔。
- 根面板使用归一化锚点，在 960×540、1280×720 和 1920×1080 下均保持屏内；长内容由既有 `ScrollContainer` 承载。
- 章节标题为 20px、步骤标题 18px；目标、说明、反馈和总结为 16px；进度、章节码、标签、步骤计数和公开行动记录为 14px。
- 所有教程选项、继续、章节完成、提示、重置、跳过和返回按钮的最小高度均为 44px，按钮文字为 16px。

### 棋子操作按钮

- `PieceInfoDrawer` 的内容上边距从 10px 调整为 6px，在现有 56px 高抽屉内提供 44px 可用高度。
- `SkillButtons` 及移动、轰炸、复活、无技能四个按钮的实际最小高度由 40px 提升到 44px。
- 未修改按钮语义、信号、可见性规则或玩法行为。

## 合同覆盖

`run_tutorial_layout_contract.gd` 现在断言：

- 三目标分辨率的面板四边均在屏内；
- 1280×720 面板宽度为 360–400px；
- 教程面板不覆盖棋盘；
- 正文不低于 16px、辅助文本不低于 14px；
- 全部教程按钮最小高度不低于 44px、按钮文字不低于 16px；
- 操作按钮位于屏内或可由滚动容器访问。

`run_match_hud_v2_contract.gd` 现在断言：

- JSON 正文/核心信息不低于 15px、辅助信息不低于 14px；
- 正式 HUD 实际字体与 JSON 一致；
- 返回、镜像、跳过及四个棋子操作按钮的最小触达高度不低于 44px。

两个合同都仅在测试实例中禁用正式棋盘 `SubViewport` 的像素刷新；相机、布局、字体、输入和 PlayerView 逻辑不变。这避免无头软件渲染完整 1152×3072 棋盘导致假挂起。

## 严格验证

命令：

```powershell
& 'D:\Godot\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' `
  --headless --path . `
  --script res://tests/game/tutorial/run_tutorial_layout_contract.gd

& 'D:\Godot\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' `
  --headless --path . `
  --script res://tests/game/ui/run_match_hud_v2_contract.gd
```

生产者使用每项 180 秒外部硬超时执行：

- 教程布局：`HARD_TIMEOUT=0`、`EXIT_CODE=0`、`TUTORIAL_LAYOUT_CONTRACT_PASS resolutions=3`。
- 正式 HUD：`HARD_TIMEOUT=0`、`EXIT_CODE=0`、`MATCH_HUD_V2_CONTRACT_PASS catalog=10 profile=1280x720 deletions=true`。
- 两项 stderr 均为空；完整 stdout/stderr 未出现 `SCRIPT ERROR:`、`ERROR:`、`*_FAIL`。

## 未修改边界

- 未修改玩法规则、Intent/Event、PlayerView、回放或信息边界。
- 未实现双轨教学。
- 未触碰用户已有 dirty 的 frontend/theme 文件。
- 未提交或推送。

## 剩余风险与 QA 检查

- 合同证明结构、字号、触达面积和矩形不越界，但不能替代不同 DPI/字体栅格下的人工可读性判断。
- 1920×1080 下教程面板随归一化锚点扩展，虽不裁切和不遮挡棋盘，但 QA 应检查视觉密度是否显得过宽。
- QA 应在 960×540 实际操作所有滚动区和按钮，确认键盘、手柄与鼠标都能到达滚动内容。
- 当前用户主题文件有未提交修改；最终字体颜色/对比度须以冻结后的主题和候选 EXE 再验。
