# GATE-2 v3 正式二维基线人工决策包（RC5）

状态：`awaiting_human / decision_not_made`

本文件只整理当前冻结候选与独立证据，不构成 GATE-2 批准。旧 RC4 决策摘要已因产品、UI、教学与证据变化失效。

## 冻结对象

- Project Brief：v7 / `8e9d4285c1c7237a22f308808e944fd8571700f896b8dd8cfb118f0fe0de3d3e`
- Contract：v3 / owner approval `9d9e3cfc5e92d41d38eea336dbcca95040bb858706ffd8130a8b33a3594e7dd9`
- Registry contract digest：`9ea1fbab25b1a560b83896194099bd9b0131552d7321223622161615c1a2a205`
- 产品候选：`05ada9848c20c41b6d6cc92ce552df643c31438c`
- QA 证据提交：`d1f5482f058ec66db20087ab27b6c12539c0d176`
- QA 报告 SHA-256：`c9da0e9d0b747d65dd9a32282860f3784b8a90cdf40a53298cc1ceb45c1e7b8c`
- QA 摘要 SHA-256：`88c0f005252a164bb1db75229fde39893d59a90784f6485c8801e18995f697a0`
- EXE：`builds/windows/Veilfront_Xiangqi_Siege_Gate2_v3_05ada98.exe`
- EXE size：`363175248` bytes
- EXE SHA-256：`0841A22BA8701C30546DA7B6F66A25A74E204733B7A404A4B966D4B4DEB012E0`

## 验收结论

- Contract 十项检查：8 项 `pass`，`CHECK-REGRESSION-001=pass_with_limitation`，`CHECK-SCOPE-001=pass_with_risk`。
- 独立专业审查：`pass`；建议路由：`recommend_updated_owner_approval`。
- 当前候选 48/48 必要合同有效通过；定向镜头回归 12/12 通过。
- 三目标分辨率双方视角与新增 UI 样片通过；真实 GPU Match HUD 截图通过。
- Iris Xe：1280×720 默认运动平均 105.140 FPS、p99 14.255 ms；960×540 reduced motion 平均 162.597 FPS、p99 9.472 ms。
- embedded-PCK Windows 成品导出、直接启动与正式 LAN 全栈闭环均通过。

详细证据：`evidence/gate2/gate2-v3-independent-qa-rc5.md` 与 `evidence/gate2/v3-candidate-05ada98/`。

## 已披露限制与 Gate 3 必办风险

1. 当前 1-seed 九通道正式等价通过；3-seed 在 240 秒硬上限内无错误但未完成，20-seed 仅有历史 golden。
2. EXE 为 363,175,248 bytes；`all_resources` 仍包含概念图、漫画源图和未用资源，Gate 3 必须建立资源过滤、压缩与包体预算。
3. 项目尚无独立质量档位；当前只有 reduced-motion 低配验收配置。
4. 960×540 辅助信息密度仍偏高，列入 UI 打磨而非 Gate 2 阻断。

## GATE-2 人工问题

当前正式二维表现、教学与联机 UI、信息边界、二维样片、性能和 Windows 成品是否足够稳定，可以关闭 GATE-2 并进入 GATE-3 合同准备？

- `批准`：接受上述限制，关闭 GATE-2；允许准备 GATE-3 Contract。SFX、VFX、UI 交互与关卡批量生产仍须另行批准 Gate 3 Contract。
- `修订`：列出修改要求，返回 Gate 2 review/active。
- `拒绝`：停止当前二维基线或返回 Brief/Contract 重新定义。

## 待项目所有者决定

- 审批请求：`approval:veilfront-xiangqi-siege:gate-2:0213f500a100`
- 选择：`批准 / 修订 / 拒绝`
- 决定者：`project-owner`
- 当前 GATE-2 决策摘要：`0213f500a10070198ccdf1090ddcdd2ea519828233251e9896076ff0ced68525`

摘要输入（canonical JSON）：

```json
{"acceptance_subject_digest":"fe23c90f41e748b8a34f8f5e808023c5a358c7849ff8e028ffdbb72add4e1465","candidate_commit":"05ada9848c20c41b6d6cc92ce552df643c31438c","check_results":{"CHECK-ART-2D-001":"pass","CHECK-CONTRACT-V3-001":"pass","CHECK-COORDINATE-001":"pass","CHECK-DEPENDENCY-001":"pass","CHECK-GODOT-2D-001":"pass","CHECK-INFORMATION-2D-001":"pass","CHECK-PERFORMANCE-2D-001":"pass","CHECK-REGRESSION-001":"pass_with_limitation","CHECK-RESPONSIVE-2D-001":"pass","CHECK-SCOPE-001":"pass_with_risk"},"contract_approval_digest":"9d9e3cfc5e92d41d38eea336dbcca95040bb858706ffd8130a8b33a3594e7dd9","deliverable_digests":{"DELIVERABLE-ART-2D-001":"f57fc171e4f43971e8ed6f339f34138ab52a88c514070098f9d193ba4303944c","DELIVERABLE-PRESENTATION-2D-001":"e98b719543dbb7c82201aac6b38ae415e9959e90dce29164605b73236d36e499","DELIVERABLE-QA-2D-001":"2b2857784d248c6bea9d195b4b3b3183b2e348f7d31bece11781762bdf7a8e86"},"disclosed_risks":["current_3_seed_formal_equivalence_timed_out_at_240_seconds","current_20_seed_formal_equivalence_not_rerun","all_resources_export_includes_non_runtime_art_and_requires_gate3_filtering","independent_quality_tier_switch_not_yet_available"],"executable":{"path":"builds/windows/Veilfront_Xiangqi_Siege_Gate2_v3_05ada98.exe","sha256":"0841a22ba8701c30546da7b6f66a25a74e204733b7a404a4b966d4b4deb012e0","size_bytes":363175248},"formal_equivalence":{"one_seed":{"channels":9,"observer_replay_frames_checked":200,"seconds":25.254,"status":"pass","visible_error_checked":104},"three_seed":{"forbidden_count":0,"hard_limit_seconds":240,"status":"timeout"},"twenty_seed":{"current_run":false,"status":"historical_golden_only"}},"gate_2_decision":"not_made","loop_instance_id":"83c995ff-37b9-4df8-9e84-8417d6632187","professional_review":"pass","project_brief_digest":"8e9d4285c1c7237a22f308808e944fd8571700f896b8dd8cfb118f0fe0de3d3e","qa_evidence_commit":"d1f5482f058ec66db20087ab27b6c12539c0d176","qa_report_sha256":"c9da0e9d0b747d65dd9a32282860f3784b8a90cdf40a53298cc1ceb45c1e7b8c","qa_summary_sha256":"88c0f005252a164bb1db75229fde39893d59a90784f6485c8801e18995f697a0","registry_contract_digest":"9ea1fbab25b1a560b83896194099bd9b0131552d7321223622161615c1a2a205","registry_review":{"prior_decision_digest":"36efd026dd33a1caab9bd9d72e4a593c6853850e92904e865d29f434c4317a84","prior_request_status":"stale_not_decidable","revision":79,"sequence":79,"state":"waiting_approval"},"route_recommendation":"recommend_updated_owner_approval","subject":"GATE-2-v3-formal-2d-baseline-rc5"}
```

任一绑定输入、候选提交、QA 报告、QA 摘要或 EXE 摘要变化后必须重新生成决策包，旧摘要不得批准。
