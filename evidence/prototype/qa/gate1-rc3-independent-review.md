# GATE-1 RC3 独立 QA 审查

- 执行日期：2026-08-17（Asia/Shanghai）
- QA Instance：`inst:01M02NJ3JFHVZ5C4SP5MTJFJR6`
- 受测提交：`6253678157157091584b253470e709bad17c534f`
- 生产修复：`b3bc3861b6e88e875fb991951dcdad53249bf687`
- Contract：`LOOP-CTR-GATE1-VERTICAL-SLICE-001 v5`
- Contract subject digest：`d88d9017bb30437ac480e0fcf4f7b262b5ae6b3427447946e50ec37a5d3b44ca`
- Project Brief：`v4 / df8deb810d8c06c8c2f5763031fde2c39f14aa81226e23ffb25636ee3f1eca0b`
- Registry 基线：`active / iteration 2 / revision 52 / sequence 52`
- RC3：`Veilfront_Xiangqi_Siege_GATE1_RC3.exe`，`109740336` bytes，SHA-256 `480273DDEAE985C0C4AA03BE449E5999FBA57CA7B296B591AC7ED36B5BC8A229`

## 结论

RC3 的全部必要自动检查与独立专业审查通过。专业结论为 **`pass`**；按当前 Contract v5，项目经理可以执行合法状态迁移 `active -> review` 并整理 GATE-1 人工决策包。

由于 `GATE-1` 是项目所有者保留的人工闸门，本次 gate-review 分类为 **`awaiting_human`**，不是 GATE-1 已批准。QA 不替代项目所有者判断核心体验、剩余风险或是否进入正式功能开发。

官方 Loop CLI 仍为 `failed / exit 1`，但错误集合精确等于项目所有者批准的 QA-P1-003 六项临时工具例外；Contract v5 的所有重新准入条件现已满足，因此例外可以用于本次 `active -> review`，不能表述为“官方 CLI 通过”。

## 验收矩阵

| 条件 | 结果 | 关键证据 |
|---|---|---|
| `CHECK-CONTRACT-001` | 通过 | 项目实例、CTR、组织历史和未修改 `validate_history()` 均退出 0；Contract v5、Brief v4、Registry rev52/seq52 一致；官方 CLI 仅有获批六错误 |
| `CHECK-GODOT-001` | 通过 | Godot 4.7.1 导入、主场景、15 套聚合回归、灰盒、三套 LAN 入口和 RC3 无头启动均退出 0 |
| `CHECK-RULES-001` | 通过 | revision v4/v5、移动、相田、隐身马、墙线、旗帜记忆、阵亡记录、士献祭确认/取消和镜像 UI 全部通过 |
| `CHECK-DETERMINISM-001` | 通过 | 1000/1000 局均进行确定性复核，差异 0；回放抽样 20/20；seed 471016 实跑/回放摘要相同 |
| `CHECK-FOG-001` | 通过 | PlayerView 隐藏等价、LAN 白名单和双方旗帜记忆边界通过；客户端/UI 禁止字段静态匹配数 0 |
| `CHECK-AI-001` | 通过 | 100 seeds × 4 档 = 400 条；失败、确定性差异、隐藏等价差异、映射和提交失败均为 0 |
| `CHECK-SIMULATION-001` | 通过 | 固定 seeds 471001..472000 完成 1000/1000；失败 0；manifest 正常验证通过且强制篡改被拒绝 |
| 独立专业审查 | 通过 | 失败历史保留、阈值未降低、规则/实现/AI/LAN 黑盒结果一致 |
| `GATE-1` 人工闸门 | 等待项目所有者 | 自动条件已满足，QA 不代替人类批准 |

## QA-P1-004 闭环

RC2 在 seed `471016` 的 action/event index 51 出现车被相田拦截后回放拒绝同一意图。RC3 进行了三层复核：

1. 单 seed 正式 runner 完成 `1/1`，失败 `0`，确定性差异 `0`，回放 `1/1`。
2. 保留的 RC2 诊断脚本在 RC3 上返回 `first_event_mismatch=-1`、`first_rejected_intent=-1`，实跑与回放均为 100 个事件。
3. seed `471016` 被包含在正式 1000-seed 批次中，整个批次 `1000/1000` 通过。

实跑与回放状态摘要均为 `dea568557684bed2c3a10894bfdf14bd917186662b517942cfb945ddb9221615`，事件摘要均为 `1f53e1ba8a9f26522e9ca2ecfd6ce89d7732ff63f9decca84baeaede71d820a6`。因此 `QA-P1-004` 状态为 **closed**。

RC2 的失败报告、999 条完成局 manifest 和诊断脚本仍保留在仓库中，没有被 RC3 证据覆盖或删除。

## 1000-seed 正式批次

- requested / completed：`1000 / 1000`
- seed 范围：`471001..472000`，唯一 seed 数 `1000`
- failure：`0`
- determinism checked / mismatch：`1000 / 0`
- replay verified：`20/20`
- 终止原因：轮上限平局 `590`、轮上限旗数判胜 `408`、三旗 `2`
- winner：红 `183`、黑 `227`、平局 `590`
- 旗帜：全部位于 `X=1..9,Y=9..16`，每局三点唯一，72 个合法点均有观测
- records digest：`25c40f9467a7c4d4ad45162e3aef7f5f95b1948a76757bd2808b4eb6fc906064`

独立 Python 重算记录数、seed 集合、终止/胜负统计和 records digest 均一致。Godot verifier 正常验证退出 `0`；对同一 manifest 强制模拟单条记录篡改时退出 `1`，错误为 `manifest_count_or_digest_mismatch`。

## AI 公平性与信息边界

- seeds：`471001..471100`
- easy / medium / hard / expert：各 `100` 条，共 `400` 条
- failure / determinism mismatch / hidden-equivalence mismatch：`0 / 0 / 0`
- mapping failure / submit failure：`0 / 0`
- records digest：`879b1e381944c0183fb49cd7c5975b4d0303c24627e0b4ff9742b99942abcc20`

独立重算 400 条记录、四档分布和 records digest 完全一致。LAN 双实例测试证明两侧只接收各自 PlayerView，不接收 FullState、RNG、可反推旗位的 seed 或另一侧发现记忆。客户端/UI 表现脚本对禁止状态访问模式的静态匹配数为 0；网络协议显式拒绝 11 个敏感下行字段。

## 治理与构建

- 项目实例、Pipeline Contract、Organization Registry 和未修改历史验证全部退出 `0`。
- Registry 保持 `active / iteration 2 / revision 52 / sequence 52`，事件链尾摘要一致。
- 官方 CLI 恰好退出 `1` 且只有批准的六项错误；本报告继续将其记录为失败。
- RC3 文件大小、SHA-256 和无头启动由 QA 独立复核，均与冻结信息一致。
- 候选提交的父提交正是生产修复 `b3bc386`；其后只合入 RC2 独立失败证据，没有额外生产变动。

## 残余观察与人工判断

- clean source 加载仍有两个 `invalid UID` 的文本路径回退 warning，编辑器强制退出时仍有 `Scan thread aborted` warning；没有解析、导入或资源加载错误，不阻断本次原型 Gate。
- 1000 局中有 `590` 局在 50 轮达到平局。50 轮仍为 `hypothesis_cli_overridable`，本次 QA 只报告数据，不冻结节奏参数；是否符合体验目标由项目所有者在 GATE-1 判断。
- 本构建是 GATE-1 可丢弃垂直切片与 LAN 试玩工具，不是正式联网架构、Steam 发布候选或正式功能架构冻结。
- 项目所有者此前的真实双机试玩通过记录继续有效，并与本轮自动 LAN 证据共同进入人工决策包。

## 下一合法动作

1. 项目经理将本轮证据登记到 Registry，并执行 `active -> review`。
2. 项目经理绑定 Contract v5、Brief v4、候选提交、RC3 SHA-256 和本证据摘要，重新整理 GATE-1 人工决策包。
3. 项目所有者选择批准、拒绝或要求修订；在人工批准前，正式功能开发与高成本资产生产仍然禁止。

完整命令与退出码见 `gate1-rc3-command-summary.txt`；逐 seed、AI 压缩记录和独立摘要见同目录证据文件。
