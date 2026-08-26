# 双轨新手教程生产者集成交接 v1

状态：`producer_integrated / awaiting-independent-qa / not-gate3-frozen`

日期：2026-08-26

## 授权与边界

- 项目所有者批准摘要：`6e2d0f83914ed58ee053f082325503f0136e672ee392b9639ba03961d42a080e`
- 批准记录：`game-pipeline/approvals/production-scope-exception-ftue-dual-track-6e2d0f83914e.yaml`
- 实现没有修改 `scripts/game/domain`、正式规则、规则随机、PlayerView/VisibleEvent 权限或回放摘要。
- 新增 P0、B1、B2、B3、T8-R、T9-C、T10-E 均未登记 `step_effects`；原 T0-T10 兼容效果没有扩展为新的规则旁路。
- 教程不写死正式轮上限；T10-E 只解释结算原则。

## 已集成内容

1. 两条玩家路线：`foundation` 与 `xiangqi_experienced`，共享 18 个模块和同一能力图谱。
2. 五态进度：`UNSEEN / ASSUMED / COMPLETED / SKIPPED / NEEDS_REVIEW`；旧 `progress.completed_ids` 自动迁移到 schema v2。
3. 核心就绪与完整毕业分离；熟练路线只在当前路线批准的 B-01..B-08 上接受 `ASSUMED`。
4. P0 首次行动、B1-B3 普通走法、T8-R 城墙余波、T9-C 旗帜争夺、T10-E 终局推演。
5. T0 补充镜像、小地图、预览安全、完整轮、Demo 模式和轮上限原则辨析。
6. T10 隐藏接触目标提供 3 个正式合法远端命令，满足多解行动链，不新增直接效果。
7. 关卡目录可选路线、切换路线、诚实显示跳过/自报掌握/建议复习；重置教学时保留挑战进度。
8. 正式 Match HUD 上的 376px 教学抽屉：目标常驻、原因折叠、提示与步骤重置；960/1280/1920 均通过布局合同。
9. 18 页战阵图鉴使用独立文本层和线程图片加载，可从目录和教学暂停菜单进入。
10. 首局情境提醒只消费公开事件、公开错误和本地能力状态，同类默认只显示一次。

## 生产提交

- `cbd4eff` — `feat: 实现双轨教程课程与能力进度`
- `c6150b7` — `feat: 完善新手教程目录与复习体验`
- `ed40fb2` — `feat: 支持综合考核多解路径`

上述提交均已推送至 `origin/main`。

## 自动验证

- `ALL_TUTORIAL_FLOWS_PASS chapters=18`
- `TUTORIAL_CURRICULUM_CONTRACT_PASS modules=18 routes=2 migration=v2`
- `TUTORIAL_CONTEXT_REMINDER_CONTRACT_PASS observer_safe=true`
- `TUTORIAL_CODEX_CONTRACT_PASS pages=18 text_layer=true`
- `TUTORIAL_T10_SOLUTION_VARIANTS_CONTRACT_PASS variants=3`
- `TUTORIAL_LAYOUT_CONTRACT_PASS resolutions=3 hud=match-v3 guide=approved`
- `TUTORIAL_PROGRESS_CONTRACT_PASS level=T0`
- `TUTORIAL_NAVIGATION_CONTRACT_PASS`
- `TUTORIAL_PAUSE_MENU_CONTRACT_PASS buttons=4 codex=true`
- `TUTORIAL_CHAPTER_CONTENT_CONTRACT_PASS chapters=18`
- `TUTORIAL_FIXED_EFFECT_CONTRACT_PASS chapters=18`
- `TUTORIAL_FIRST_ACTION_CONTRACT_PASS chapters=18`
- `LEVEL_SELECT_UI_CONTRACT_PASS source=approved_master_v3 modules=18 routes=2 resolutions=3`
- `FRONTEND_SCENE_SMOKE_PASS catalog=21 tutorial=18 challenge=3 routes=2`
- `MATCH_FEEDBACK_INTEGRATION_CONTRACT_PASS ... minimap_isolation=true reset=true`

Godot 版本：`4.7.1.stable.official.a13da4feb`。

## 视觉检查

- 1280×720 关卡目录：18 节点、双路线条、核心进度环和详情区无裁切。
- 1280×720 教学 HUD：376px 抽屉与正式棋盘不重叠，折叠原因和底部操作可达。
- 1280×720 战阵图鉴：漫画、独立标题/正文、上一页/下一页/关闭均可读。

## 未完成与后续

1. 本记录是生产者集成证据，不是独立 QA 结论。
2. 仍需 QA 从冻结构建独立复现双路线、迁移、隐藏等价、分辨率、长流程与性能。
3. 仍需两类真实玩家试玩验证首次有意义行动、核心考核通过率和理解偏差。
4. GATE-3 内容冻结与任何发布决定仍由项目所有者保留。
