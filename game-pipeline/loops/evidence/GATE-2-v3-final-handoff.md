# GATE-2 v3 最终交接（RC5）

状态：`approved / completed`

## 结论

项目所有者已确认决策摘要 `0213f500a10070198ccdf1090ddcdd2ea519828233251e9896076ff0ced68525`。正式二维表现、教学与联机 UI、PlayerView 信息边界、性能样片和 Windows 成品满足 GATE-2 灰盒冻结要求，允许关闭当前循环并准备 GATE-3 内容与集成 Contract。

## 冻结输入与产物

- Project Brief：v7 / `8e9d4285c1c7237a22f308808e944fd8571700f896b8dd8cfb118f0fe0de3d3e`
- Loop Contract：`LOOP-CTR-FORMAL-FOUNDATION-GATE2-001@v3`
- Contract approval：`9d9e3cfc5e92d41d38eea336dbcca95040bb858706ffd8130a8b33a3594e7dd9`
- 产品候选：`05ada9848c20c41b6d6cc92ce552df643c31438c`
- QA 证据提交：`d1f5482f058ec66db20087ab27b6c12539c0d176`
- QA 报告：`evidence/gate2/gate2-v3-independent-qa-rc5.md`
- 人工批准：`game-pipeline/approvals/gate-2-approval-0213f500a100.yaml`
- Windows EXE：`builds/windows/Veilfront_Xiangqi_Siege_Gate2_v3_05ada98.exe`
- EXE SHA-256：`0841A22BA8701C30546DA7B6F66A25A74E204733B7A404A4B966D4B4DEB012E0`

## 已完成验收

- 48/48 当前必要合同有效通过；独立 QA verdict 为 `pass`。
- 规则依赖、PlayerView、迷雾、Observer、LAN public-state fail-closed 与正式 LAN 全栈边界通过。
- 960×540、1280×720、1920×1080双方视角样片及当前 UI 样片通过。
- 1280×720 默认运动平均 105.140 FPS、p99 14.255 ms；960×540 reduced motion 平均 162.597 FPS、p99 9.472 ms。
- Windows embedded-PCK 导出、直接启动和 packaged LAN verifier 通过。

## 保留事实与约束

- 当前正式主线为 2D；斜俯视三渲二仅保留为项目后期可选研究资产。
- owner rule revision 5、确定性随机消费、PlayerView、公开事件、回放和教学 Intent/Event 语义不因 Gate 2 关闭而改变。
- Godot 固定 UI 与场景结构继续遵守预置节点优先；脚本动态生成只用于确有必要且优于预置方案的部分。
- GATE-2 批准不是发布批准，也不是 GATE-3 内容生产 Contract 的自动批准。

## 已接受残余风险

1. 当前 1-seed 九通道等价通过；3-seed 在 240 秒内未完成，20-seed 仅历史 golden。
2. EXE 为 363,175,248 bytes；当前 `all_resources` 导出包含概念图、漫画源图和未用资源。
3. 项目尚无独立质量档位开关；reduced-motion 只覆盖减少动态，不等同完整低配档。
4. 960×540 辅助信息区密度仍偏高。

## GATE-3 必须承接的工作

- P0：建立导出资源白名单/过滤、纹理压缩和包体预算，移除非运行时概念图与源图。
- SFX：只消费观察者可见 Cue/Event，覆盖 UI、选中、移动、攻击、城墙、旗帜、回合和结算，禁止以声音泄露迷雾信息。
- VFX：只绑定 PlayerView/公开事件，建立粒子数量、过绘、闪烁和 reduced-motion 降级预算。
- UI 交互：统一按钮状态、焦点链、键鼠/手柄反馈、动效节奏、960×540布局与无障碍反馈。
- 闯关/教学：补齐关卡目标、失败恢复、提示升级、通关节奏与固定回归，不复制规则实现。
- QA：继续保持独立，覆盖信息泄露、帧率、包体、输入、长流程、导出和回归矩阵。

## 下一合法动作

项目经理起草 GATE-3 内容与集成 Contract，绑定以上范围、责任、产物、性能预算、信息安全和失败回退；由项目所有者对其精确摘要另行批准后，才可并行启动正式 SFX、VFX、UI 交互和关卡生产。
