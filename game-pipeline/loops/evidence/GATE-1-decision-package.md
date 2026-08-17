# GATE-1 核心体验假设人工决策包（RC3 / Contract v5）

状态：`awaiting_human / decision_not_made`

本文件只整理证据，不构成批准。项目所有者未对当前决策摘要作出选择前，不得开始正式功能开发或高成本资产生产。

## 当前冻结基线

- Loop：`LOOP-GATE1-001 / Iteration 2`
- Registry：`review / revision 60 / sequence 60`
- Registry 尾摘要：`ea497e0d9a18e83c6bb1cbbc0058426ebb231e04b8e57f431e852d9269192498`
- Project Brief：`v4 / df8deb810d8c06c8c2f5763031fde2c39f14aa81226e23ffb25636ee3f1eca0b`
- Loop Contract：`v5 / d88d9017bb30437ac480e0fcf4f7b262b5ae6b3427447946e50ec37a5d3b44ca`
- 候选提交：`6253678157157091584b253470e709bad17c534f`
- 生产修复提交：`b3bc3861b6e88e875fb991951dcdad53249bf687`
- RC3：`builds/windows/Veilfront_Xiangqi_Siege_GATE1_RC3.exe`
- RC3 size：`109740336` bytes
- RC3 SHA-256：`480273DDEAE985C0C4AA03BE449E5999FBA57CA7B296B591AC7ED36B5BC8A229`
- 独立 QA 证据提交：`7e20acbf61a42e9dcedb88dcf68b8bc8b68d9c9f`
- QA 报告 SHA-256：`41a1ebd7618bded26c2fa6fa8d72d6ef3ff33f6c4d51f6f3fe55b81801764b96`
- QA 索引 SHA-256：`be64807394e3f05ed8e1e4366a0a3f88ad2cc78bfef932b3f1f20c411e4eb650`
- QA 验收 subject digest：`5be2f49678c91f3738a8be23aa4f114bb4d314a0a7b491494efdcc89738ac337`

## 自动与独立专业结论

| 检查 | 结果 | 证据摘要 |
|---|---|---|
| Contract / Brief / Registry | PASS WITH CONTROLLED EXCEPTION | 项目实例、CTR、组织与未修改历史均 exit 0；官方 Loop CLI 仍 exit 1 且精确六项批准错误，无第七项 |
| Godot 4.7.1 / UI / LAN | PASS | import、主场景、15 套聚合回归、灰盒、LAN host/network/lobby、RC3 启动均通过 |
| 规则与信息边界 | PASS | revision 5 规则、PlayerView、旗帜记忆、阵亡记录、士献祭、相田、隐身马、墙线与镜像均通过 |
| 1000 固定种子 | PASS | 1000/1000，failure 0，determinism mismatch 0，replay 20/20 |
| AI 公平矩阵 | PASS | 100 seeds × 4 难度 = 400/400；隐藏等价、确定性、映射、提交错误均为 0 |
| QA-P1-004 | CLOSED | seed 471016 单测、诊断与完整批次全部通过，实跑/回放摘要一致 |
| 独立专业审查 | PASS | 允许 `active -> review`；QA 未代替项目所有者批准 GATE-1 |

详细证据：`evidence/prototype/qa/gate1-rc3-independent-review.md`、`gate1-rc3-evidence-index.yaml`、`gate1-rc3-command-summary.txt`。

## 真人试玩事实

项目所有者已报告 Windows 真双机局域网试玩通过，记录见 `evidence/prototype/playtest/owner-lan-dual-machine-2026-08-17.md`。该记录支持真人可连接和完成对局，但不替代独立自动 QA，也不把可丢弃 LAN 工具认定为正式联网架构。

## 仍需人工判断的风险

1. 1000 局中 590 局在 50 轮达到平局；50 轮仍是 `hypothesis_cli_overridable`，不是冻结平衡结论。
2. QA-P1-003 仍是临时工具兼容例外，官方 Loop CLI 没有通过；插件、校验器或错误集合变化会使例外失效。
3. clean source 加载仍有两个 `invalid UID` 文本路径回退 warning，编辑器强制退出仍有 `Scan thread aborted` warning；本轮未出现解析、导入或资源加载错误。
4. RC3 是可丢弃垂直切片与可信 LAN 试玩工具，不是 Steam 发布候选、正式联网架构或正式功能架构冻结。

## 可逆决策选项

- `批准`：认可核心循环值得进入正式功能规划；保留上述风险与后续 Gate，不默认继承原型架构。
- `修订`：指定体验、规则、反馈或技术补证项，Loop 返回 active 开启下一轮。
- `拒绝`：停止当前方向或返回 P0/P1 重新定义；保留全部失败与通过证据。

## 项目所有者需要回答

1. 移动、侦察、破城、炮击、三旗争夺与将帅死亡是否形成值得继续的核心循环？
2. 迷雾、占旗、阵亡、复活、截停与胜负反馈是否足够可理解？
3. 590/1000 的 50 轮平局是否可接受为后续平衡实验，而不是当前阻断？
4. 是否接受可丢弃原型边界与正式开发前需重新审查架构的成本？

## 待项目所有者决定

- 选择：`批准 / 修订 / 拒绝`
- 决定者：`project-owner`
- 决定时间：`待填写`
- 条件或修订要求：`待填写`
- 当前 GATE-1 决策摘要：`3ad999746a4942e6c9cd6986cba7a7d7e819c9f3c5ffeacaab94351d1cb589a3`

摘要输入（canonical JSON）：

```json
{"candidate_commit":"6253678157157091584b253470e709bad17c534f","deliverable_digests":{"DELIVERABLE-AI-001":"19c51002f2dfc9a8d8f2f5081307cfd8cafedce3143eea4b120ab641b8dc5847","DELIVERABLE-GODOT-001":"82a6e1bfeead8cd9a4afe33fb7d5b5e85a8617047b36560d36f02c0f27883890","DELIVERABLE-INFO-001":"9162803992343e9bbdfdb45ccdfbf5e4eb1d6c09e7bf68d046d34cfe18ae170d","DELIVERABLE-QA-001":"3f822f760bf6eec592448bb692d7ce3280df3393eda17469bf6dbe7e9c0974f7","DELIVERABLE-RULES-001":"8733e29e66582b3882b4b2663cf78ce783925be89cd40fe06a0b14c7d5d033f7"},"exception_status":"owner-approved tooling exception","gate_1_decision":"not_made","last_event_digest":"ea497e0d9a18e83c6bb1cbbc0058426ebb231e04b8e57f431e852d9269192498","last_event_sequence":60,"loop_contract_digest":"d88d9017bb30437ac480e0fcf4f7b262b5ae6b3427447946e50ec37a5d3b44ca","loop_instance_id":"4cbb03b6-dd5a-41c5-a624-895c4b884bcb","official_cli":{"error_count":6,"exit_code":1,"result":"failed"},"production_fix_commit":"b3bc3861b6e88e875fb991951dcdad53249bf687","project_brief_digest":"df8deb810d8c06c8c2f5763031fde2c39f14aa81226e23ffb25636ee3f1eca0b","qa_acceptance_subject_digest":"5be2f49678c91f3738a8be23aa4f114bb4d314a0a7b491494efdcc89738ac337","qa_evidence_commit":"7e20acbf61a42e9dcedb88dcf68b8bc8b68d9c9f","qa_index_sha256":"be64807394e3f05ed8e1e4366a0a3f88ad2cc78bfef932b3f1f20c411e4eb650","qa_report_sha256":"41a1ebd7618bded26c2fa6fa8d72d6ef3ff33f6c4d51f6f3fe55b81801764b96","rc3":{"path":"builds/windows/Veilfront_Xiangqi_Siege_GATE1_RC3.exe","sha256":"480273ddeae985c0c4aa03be449e5999fba57ca7b296b591ac7ed36b5bc8a229","size_bytes":109740336},"registry_revision":60,"subject":"GATE-1-decision-package-rc3-v5"}
```

任一绑定输入变化后必须重新生成决策包，旧摘要不得批准。
