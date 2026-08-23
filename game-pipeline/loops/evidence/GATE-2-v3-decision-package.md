# GATE-2 v3 正式二维基线人工决策包（RC4）

状态：`awaiting_human / decision_not_made`

本文件只整理当前候选证据，不构成 GATE-2 批准。项目所有者完成 EXE 测试并对当前决策摘要作出选择前，不得把 Demo 级二维批量资产、完整 SFX/VFX、最终 UI 或教学扩展视为已获批准。

## 冻结对象

- Project Brief：v7 / `8e9d4285c1c7237a22f308808e944fd8571700f896b8dd8cfb118f0fe0de3d3e`
- Contract：v3 / owner approval `9d9e3cfc5e92d41d38eea336dbcca95040bb858706ffd8130a8b33a3594e7dd9`
- Registry contract digest：`9ea1fbab25b1a560b83896194099bd9b0131552d7321223622161615c1a2a205`
- 产品候选：`419e2cef5d4fac9f099c8ea487b5e6d6a5c57445`
- QA 证据提交：`7404d78`
- QA 报告 SHA-256：`6f32e0afc786d39aaa7d1bc63ffefbfc00ef588242473bd90258936ecaec6339`
- EXE：`builds/windows/Veilfront_Xiangqi_Siege_Gate2_v3_419e2ce.exe`
- EXE size：`286523048` bytes
- EXE SHA-256：`EA008CF1B6F68DBD2598DBCF4981F8CD40F065D0F995F69878F543D38DD84130`

## 验收结论

- Contract 十项检查：9 项 `pass`，`CHECK-REGRESSION-001` 为 `pass_with_limitation`。
- 独立专业审查：`pass`；建议路由：`recommend_awaiting_human`。
- 相机合同严格连续 5/5 通过；棋盘相机层、六分辨率布局、隐藏等价均通过。
- 960×540、1280×720、1920×1080 × 赤/玄六张真实 GPU 样片通过。
- Iris Xe / OpenGL：1280×720 默认运动平均 158.569 FPS、p99 10.016 ms；960×540 reduced motion 平均 154.343 FPS、p99 9.775 ms。
- embedded-PCK Windows 成品通过正式 LAN 全栈验证，覆盖 ready → start → match → submit → disconnect。

详细证据：`evidence/gate2/gate2-v3-independent-qa-rc4.md` 与 `evidence/gate2/v3-candidate-419e2ce/`。

## 已知但不阻断的风险

1. 当前正式等价证据为同代码 1-seed PASS；本机未重跑当前 3/20 seed，历史 20-seed golden 只作背景。
2. 960×540 reduced-motion 样本出现单帧 196.833 ms 尾部尖峰，但平均、p99、1% low 和连续可读性均稳定。
3. EXE 约 286.5 MB，当前 preset 仍含开发/测试资源；GATE-3/发布前需收敛导出过滤。
4. 项目没有独立质量档；目前只有低配验收配置。
5. 960×540 下辅助战况与棋子说明密度偏高、对比偏弱，属于 UI 打磨而非当前核心可读性阻断。

## GATE-2 人工问题

正式二维表现、教学灰盒、信息边界与二维视觉样片是否足够稳定，值得进入 Demo 级二维批量资产生产？

可逆选择：

- `批准`：允许进入 GATE-3 细节生产与补全，但不等于发布批准。
- `修订`：项目所有者列出测试发现与修改要求，Loop 恢复 review 后返回 active 修订。
- `拒绝`：停止当前二维基线或返回 Brief/Contract 重新定义。

## 待项目所有者决定

- 选择：`批准 / 修订 / 拒绝`
- 决定者：`project-owner`
- 决定时间：`待填写`
- 条件或修订要求：`待填写`
- 当前 GATE-2 决策摘要：`36efd026dd33a1caab9bd9d72e4a593c6853850e92904e865d29f434c4317a84`

摘要输入（canonical JSON）：

```json
{"acceptance_subject_digest":"6ef1550efb53444cdcebbf61a17ce9aee36a6ce73de69797e4fefe9270f14931","candidate_commit":"419e2cef5d4fac9f099c8ea487b5e6d6a5c57445","check_results":{"CHECK-ART-2D-001":"pass","CHECK-CONTRACT-V3-001":"pass","CHECK-COORDINATE-001":"pass","CHECK-DEPENDENCY-001":"pass","CHECK-GODOT-2D-001":"pass","CHECK-INFORMATION-2D-001":"pass","CHECK-PERFORMANCE-2D-001":"pass","CHECK-REGRESSION-001":"pass_with_limitation","CHECK-RESPONSIVE-2D-001":"pass","CHECK-SCOPE-001":"pass"},"contract_approval_digest":"9d9e3cfc5e92d41d38eea336dbcca95040bb858706ffd8130a8b33a3594e7dd9","deliverable_digests":{"DELIVERABLE-ART-2D-001":"8970adea9d4f9967ed1964022736c0e7dca9a99c1e0c392cde0ed3c4a44ff423","DELIVERABLE-PRESENTATION-2D-001":"fb3b985d6e590e5225fdebde5abed69da1a961b5ee3d8b3fe0be3bb72243f000","DELIVERABLE-QA-2D-001":"e59f1d0a1e466b94e33b5405de6b843b6f4228c5ec8380b9b17f3391bb4346d1"},"executable":{"path":"builds/windows/Veilfront_Xiangqi_Siege_Gate2_v3_419e2ce.exe","sha256":"ea008cf1b6f68dbd2598dbcf4981f8cd40f065d0f995f69878f543d38dd84130","size_bytes":286523048},"formal_equivalence":{"current_3_or_20_seed":"not_rerun","current_evidence":"1-seed-pass","historical_20_seed":"background_only"},"gate_2_decision":"not_made","loop_instance_id":"83c995ff-37b9-4df8-9e84-8417d6632187","professional_review":"pass","project_brief_digest":"8e9d4285c1c7237a22f308808e944fd8571700f896b8dd8cfb118f0fe0de3d3e","qa_evidence_commit":"7404d78","qa_report_sha256":"6f32e0afc786d39aaa7d1bc63ffefbfc00ef588242473bd90258936ecaec6339","registry_contract_digest":"9ea1fbab25b1a560b83896194099bd9b0131552d7321223622161615c1a2a205","registry_review":{"last_event_digest":"908377484c44c8bc8d3739a6362ad43bf1c102b4d1fe72d9dec169b7decccb07","revision":76,"sequence":76},"subject":"GATE-2-v3-formal-2d-baseline-rc4"}
```

任一绑定输入、候选提交、QA 报告或 EXE 摘要变化后必须重新生成决策包，旧摘要不得批准。
