# GATE-3 内容与集成 Contract v1 人工决策包

状态：`awaiting_human / contract_not_approved / production_not_started`

本决策包不批准 GATE-3 冻结，也不代表 SFX、VFX、UI 交互和关卡生产已经开工。它只请求批准第三生产循环的范围、预算、责任、验收和回退规则。

## 前置状态

- GATE-2：`approved / completed`
- GATE-2 approval：`approval:veilfront-xiangqi-siege:gate-2:0213f500a100`
- GATE-2 Registry：`sequence 102 / revision 102`
- Contract 草案：`game-pipeline/loops/contracts/loop-contract-content-integration-gate3-v1.yaml`
- Contract SHA-256：`7c735748becb46c0834f2935863e0576be07aa8a48868df9655c06a362f6206d`

## 批准后允许的工作

1. P0先行：导出资源过滤、纹理/字体/包体预算、公开AudioCue/VfxCue合同、UI动效与响应式基线。
2. 并行启动四条线：观察者安全SFX、观察者安全VFX、UI交互手感、T0-T10教学与C1-C3闯关补全。
3. 进入统一集成、试玩、独立QA，再提交最终GATE-3内容冻结人工判断。

## 本次明确冻结的范围选择

- 第一波内容固定为现有 `T0-T10 + C1-C3`，不自动新增C4+。
- SFX不少于12个核心cue族；BGM正式作曲、语音和完整环境声延期。
- VFX覆盖选中、移动、吃子、炮击、城墙、旗帜、终局七类核心效果族。
- 双轨教学提案中的P0/B1/B2/B3与能力状态迁移延期，需另行批准附录或Contract修订。
- Windows EXE目标不超过320,000,000 bytes；超出必须取得项目所有者例外。
- 本Contract不授权外部支出；正式SFX文件必须有项目所有者提供、许可清晰的来源，或另获临时音频制作授权。

## 项目所有者选择

- `批准`：接受上述范围、延期项、0元外部支出、音频所有权条件和验收阈值；允许物化Contract并登记新Loop。
- `修订`：指出需要改变的内容数量、BGM/双轨教学范围、包体阈值、音频来源或其他条款。
- `拒绝`：不启动当前GATE-3生产循环。

## 待决定

- 审批请求：`approval:veilfront-xiangqi-siege:loop-contract:6a6fe0208e7b`
- Contract 决策摘要：`6a6fe0208e7bad655b39ce112dcaa40b2caa24425bbbd93cc2bf68cffccf1851`

摘要输入（canonical JSON）：

```json
{"approved_scope_if_confirmed":{"content_wave":["T0-T10","C1-C3"],"core_sfx_cue_families_min":12,"core_vfx_families":["selection","move","capture","bombardment","wall","flag","terminal"],"external_spend_cny":0,"p0":"export_filtering_texture_font_budget_public_cue_contracts","parallel_lines":["observer_safe_sfx","observer_safe_vfx","ui_interaction","tutorial_and_challenge_content"],"windows_exe_max_bytes":320000000},"audio_ownership_condition":"formal_sfx_files_require_owner_supplied_or_license_cleared_source_or_separate_temporary_audio_authorization","contract":{"path":"game-pipeline/loops/contracts/loop-contract-content-integration-gate3-v1.yaml","sha256":"7c735748becb46c0834f2935863e0576be07aa8a48868df9655c06a362f6206d"},"decision":"not_made","explicit_deferrals":["formal_bgm_production","voice_and_ambience","dual_track_P0_B1_B2_B3_modules","challenge_levels_C4_plus","internet_services_and_ai_delivery","toon_rendered_3d_mainline","external_release"],"gate_2_approval_id":"approval:veilfront-xiangqi-siege:gate-2:0213f500a100","gate_2_handoff_sha256":"7c7753727d278e71be1fcb4a5e5a526a8f3665fefa5d325d1a9de9413e0a6a37","gate_2_registry":{"last_event_digest":"57f76274c2d78da4bc0732f125c8861ea794ddf347f45605068a786a9ca79204","revision":102,"sequence":102,"state":"completed"},"gate_2_subject_digest":"0213f500a10070198ccdf1090ddcdd2ea519828233251e9896076ff0ced68525","project_brief_digest":"8e9d4285c1c7237a22f308808e944fd8571700f896b8dd8cfb118f0fe0de3d3e","requested_action":"approve_gate3_content_integration_contract_v1","source_digests":{"audio_proposal":"daca983aab87cb13c2f70368443770daad5f6319ea0339cdd7298a141a438896","content_catalog":"760f27b926bf66f7c97141e877c73f5320114f597ead42c6ea5e34a4407bb1e5","tutorial_design_proposal":"51dc2f3508e970d9032c21180c8071b36c1155ec25fd4ab2a9a3a158faf389b4","ui_audit":"95f1cc899bba8bf0c39461283c073af9b5d42b7e18a3c2866604cd0d929af3ea"},"subject":"LOOP-CTR-CONTENT-INTEGRATION-GATE3-001@v1"}
```

任一Contract条款、GATE-2绑定或源提案内容变化后必须重算摘要，旧摘要不得批准。
