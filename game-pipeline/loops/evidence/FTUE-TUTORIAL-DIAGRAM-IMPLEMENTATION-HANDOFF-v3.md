# 新手教程准确性优先示意图重制交接 v3

状态：`producer_integrated / awaiting-independent-qa / not-gate3-frozen`

日期：2026-09-01

## 问题与项目所有者决定

项目所有者确认现有新手教程仍难懂，旧图片的规则准确性不足，并明确要求：不强求与项目画风一致，但必须准确表达教学内容。

本轮据此冻结以下生产原则：

1. 教程插图准确性优先于美术风格一致性。
2. 棋盘坐标、数量、方向、路径和状态机关系不得交给生成模型猜测。
3. 18 张图片由 `tools/art/build_tutorial_diagrams_v3.py` 确定性绘制，可重复生成和摘要校验。
4. 精确规则仍追溯 `docs/prototype/rules-spec-v1.md` owner-freeze revision 5；图片不是独立规则事实源。
5. 图中允许使用短状态标签帮助读图，但完整条件、步骤和例外仍由 Godot 文本层呈现。

`imagegen` 技能明确排除简单、确定性的规则图与代码原生矢量/图表输出，因此本轮未使用生成模型生产最终规则图。

## 实现与资产

- 图集生成器：`tools/art/build_tutorial_diagrams_v3.py`
- 规则映射与视觉语法：`assets/art/tutorial/diagram_v3/README.md`
- 摘要清单：`assets/art/tutorial/diagram_v3/manifest.json`
- 18 张 1200×800 RGB PNG：`assets/art/tutorial/diagram_v3/page_*.png`
- 图鉴运行时：`scripts/game/tutorial/tutorial_codex.gd`
- 图鉴场景：`scenes/game/ui/tutorial_codex.tscn`
- 图鉴合同：`tests/game/tutorial/run_tutorial_codex_contract.gd`
- v3 截图工具：`tests/game/tutorial/capture_tutorial_codex_v3.gd`
- 图文 PDF 构建入口：`tools/docs/build_comic_tutorial_pdf.py`
- 导出白名单：`export_presets.cfg`、`tools/release/windows_runtime_manifest.json`

核心提交：

- `3408f5f` — `feat: 迁移游戏生产管线至alpha3`
- `912f915` — `feat: 重制准确优先的新手教程示意图`

## 规则准确性硬约束

- 炮击页固定为 9 个候选点、3 个不同命中点、同一结算窗口。
- 破墙页固定为缓冲区 3 枚入侵棋，并明确进营还需要下一次行动。
- 修墙页固定为入侵棋少于 3 枚，触发行动不计时，之后赤玄各行动一次。
- 炮吃子页固定为炮与目标之间恰好 1 枚炮架。
- 占领页固定为同一枚棋子的 `1/3 → 2/3 → 3/3`。
- 反占页明确争夺期间原所有权仍在，完成 `3/3` 后才翻旗。
- 胜负页区分斩将、三面非争夺旗与同窗双将阵亡平局。
- 预览页明确公开信息相同必须得到相同预览，不允许试探隐藏状态。

## 自动验证

- `TUTORIAL_DIAGRAM_V3_CHECK_PASS pages=18 size=1200x800 policy=deterministic_accuracy_first`
- `TUTORIAL_CODEX_CONTRACT_PASS pages=18 layers=key,steps,pitfall,caption`
- `TUTORIAL_LAYOUT_CONTRACT_PASS resolutions=3 hud=match-v3 guide=approved`
- `LEVEL_SELECT_UI_CONTRACT_PASS source=approved_master_v3 modules=18 routes=2 resolutions=5`
- `FRONTEND_SCENE_SMOKE_PASS catalog=21 tutorial=18 challenge=3 routes=2`
- `ALL_TUTORIAL_FLOWS_PASS chapters=18`
- `TUTORIAL_CURRICULUM_CONTRACT_PASS modules=18 routes=2 migration=v2`
- `TUTORIAL_T10_SOLUTION_VARIANTS_CONTRACT_PASS variants=3`
- `TUTORIAL_CONTEXT_REMINDER_CONTRACT_PASS observer_safe=true`
- `TUTORIAL_RULE_BOUNDARY_CONTRACT_PASS`
- `WINDOWS_RUNTIME_BUDGET_PASS exe_bytes=197898280 pack_expanded_bytes=88604919 texture_bytes=44292740 font_bytes=39230269 entries=607`
- `WINDOWS_LAN_EXPORT_VERIFY_PASS ... frames=120`
- 包内容：`diagram_v3/*.import = 18`，`comic_v2/*.import = 0`，`comic_v1/*.import = 0`。

Godot：`4.7.1.stable.official.a13da4feb`；参考设备：Intel Iris Xe / GL Compatibility。

## 视觉证据

- `evidence/ui/tutorial-codex-v3-p00-1280x720.png`
- `evidence/ui/tutorial-codex-v3-p09-1280x720.png`
- `evidence/ui/tutorial-codex-v3-p12-960x540.png`

基础页、数量敏感的炮击页和长文案修墙页均保持图片区、四层文本与导航完整可见。960×540 下图内标签仍可辨识，无核心裁切。

## 代码审查结论

- 严重问题：无。
- 图鉴继续使用 `ResourceLoader.load_threaded_request()`，图片加载完成后关闭 `_process()`。
- 生成器只在制作阶段运行；运行时不依赖 Python、Pillow 或图片 manifest。
- 场景仍使用已有预置 Control/Container，没有新增脚本动态 UI 节点。
- 导出 manifest 与 `export_presets.cfg` 已同步，旧图集不进入运行时包。

## 独立 QA 与试玩待办

1. QA 需要从冻结提交独立复核 18 张图与权威规则的一致性，重点检查第 02、05、07、10、11、12、14、15、17 页。
2. QA 需要复核键盘焦点、不同 DPI、960×540 和长文案滚动。
3. 仍需至少两类新玩家试玩：完全不会象棋者与熟悉传统象棋者；记录首次复述正确率、找规则耗时和误读页。
4. 本记录只是生产者集成证据；GATE-3 内容冻结与发布决定仍由项目所有者保留。
