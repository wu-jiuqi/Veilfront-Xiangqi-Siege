# GATE-2 / Iteration 1 独立 QA 定向最终复核 v3

- 结论：`approved`
- 最终证据候选：`main@c9c566bbadc79869430d94e0a9b0b74ca5890d0c`
- 功能冻结：`47dd52ded8dbe2585d9d0f4fa93c6687624745af`
- 定向缺陷：`QA-I1-V2-001`
- Contract：`LOOP-CTR-FORMAL-FOUNDATION-GATE2-001@v1`（`approved`）
- QA instance：`inst:01M02NJ3JFHVZ5C4SP5MTJFJR6`
- Position：`pos:veilfront-xiangqi-siege:quality:qa-release-lead`
- Authority：`AUTH-VEILFRONT-QA-RELEASE`

## 1. 最终判断

`QA-I1-V2-001` 已由追加式纠错证据精确闭合。最终证据候选相对已完成完整独立功能复审的 `47dd52d...` 没有任何生产、测试、场景、Resource 或项目配置变化；新增内容且仅有技术复审、体验复审、QA v2 和纠错说明四份证据文件。因此 Iteration 1 的既有功能通过结论保持有效，证据完整性阻断解除。

最终结论为 `approved`：`TASK-ARCH-001` 与 `TASK-SHELL-001` 均可关闭。

该批准不批准 GATE-2，也不把 Iteration 1 fixture shell 解释为完整教学、正式规则迁移、互联网、AI、LAN 正式化或最终美术。

## 2. 身份、新鲜度与 clean worktree

所有定向核验均在新建 detached worktree `C:\Users\30114\AppData\Local\Temp\veilfront-i1-qa-final-c9c566b` 中完成。创建后首次检查：

| 项目 | 结果 |
|---|---|
| `git rev-parse c9c566b` | `c9c566bbadc79869430d94e0a9b0b74ca5890d0c` |
| detached HEAD | `c9c566bbadc79869430d94e0a9b0b74ca5890d0c` |
| `origin/main` | `c9c566bbadc79869430d94e0a9b0b74ca5890d0c` |
| worktree status count | `0` |
| candidate parent | `47dd52ded8dbe2585d9d0f4fa93c6687624745af` |
| candidate subject | `feat: 记录迭代一复审与证据纠错` |
| 项目实例 validator | 退出码 `0`，`state=normal`，errors=0，warnings=0 |

Contract 文件 SHA-256 为 `a26a9b3fdb0d8d06e42a06833a84455d911fea8f72bcedec59d0ae5e620cc205`；approval subject digest 为 `9beb91baa720820d0f0985019e5a77a4e0e065a8721451eedc30e0cc22bdeaef`，均未变化。

## 3. 候选差异与功能树等价

命令：

```text
git diff --name-only 47dd52ded8dbe2585d9d0f4fa93c6687624745af..c9c566bbadc79869430d94e0a9b0b74ca5890d0c
```

退出码：`0`。精确输出只有：

1. `evidence/gate2/iteration1-experience-rereview-v2.md`
2. `evidence/gate2/iteration1-independent-qa-rereview-v2.md`
3. `evidence/gate2/iteration1-remediation-technical-v1-correction.md`
4. `evidence/gate2/iteration1-technical-rereview-v2.md`

允许项 `4/4`，unexpected=`0`，missing=`0`。

生产/测试等价命令：

```text
git diff --quiet 47dd52ded8dbe2585d9d0f4fa93c6687624745af..c9c566bbadc79869430d94e0a9b0b74ca5890d0c -- scripts tests scenes resources project.godot
```

退出码：`0`。另逐项比较 Git 对象：

| 路径 | 47dd52d tree/blob | c9c566b tree/blob | 结果 |
|---|---|---|---|
| `scripts` | `db1579aa598dd3120644156e0f1753c32bf3b676` | 同左 | IDENTICAL |
| `tests` | `634e2a7223072f3676fbb264c075a3fdd7e24423` | 同左 | IDENTICAL |
| `scenes` | `67d73de79d430510971fdf861ef897c0dea26e83` | 同左 | IDENTICAL |
| `resources` | `fc9e63932642ee38399c09d9dd702058e0af6318` | 同左 | IDENTICAL |
| `project.godot` | `c63a0eb3b676950da6a024b0dfeab99bfbf2d88f` | 同左 | IDENTICAL |

候选范围 `git diff --check 47dd52d...c9c566b...` 退出码 `0`。

## 4. 纠错证据绑定

| 输入 | 期望 SHA-256 | 实算 | 结果 |
|---|---|---|---|
| `iteration1-remediation-technical-v1-correction.md` | `700e1709e3c048f02b0aed89171a58de19baa9c38a0fdcd697b524ac0bf91c3d` | 同左 | MATCH |
| 旧 `iteration1-remediation-technical-v1.md` | `c9c797641c3890696c2f68419dc07fec5b49a8f053ac69b0640ab4c0d55c3d48` | 同左 | MATCH / 未改写 |
| QA v2 | `2f4628bddefb5cd3f0cc65285c694e050ca224e29d81635a49303e355bd805c5` | 同左 | MATCH |
| 技术复审 v2 | `54490bdd999e839622daccef02fe45f53fff9a88d494def81c7a34848e3f6eed` | 同左 | MATCH / approved |
| 体验复审 v2 | `4665c0dc804734ecc1c12cc701a1522ecc1c40565ecb971c1a2bc8c13e70714e` | 同左 | MATCH / approved |

纠错说明明确绑定旧错误值 `51ad930000b271104468f81b34749bc415c40dc06cf52f4c4f45c872023912a5b3`（66 字符）、旧报告摘要、功能冻结 SHA 和正确目标摘要；旧证据保持不可变。

## 5. 11 项产物复算

目标文件 `resources/game/tutorials/presentation/tutorial_smoke_track.tres` 的实算 SHA-256 为：

`51ad930000b271104468f81b34749bc415c40dc06cf52f4c4f45c872023912a5`

长度为 64，和纠错说明匹配。

其余 10 项复算结果：

| 文件 | SHA-256 | 结果 |
|---|---|---|
| `scripts/game/contracts/player_view_codec.gd` | `a9c91d2747414d088eb4bb9eba59f15d5f9110815268322b51c693440238d3fd` | MATCH |
| `scripts/game/contracts/visible_event_codec.gd` | `3549c66e389eaa20e58ebf3ae86d6e044e1e69b1631192295efe0cdf053f541c` | MATCH |
| `scripts/game/application/application_host.gd` | `0d483a6cb84bdc40a0f8e08fa8813e2360d2caad36ca5d47f99f3ae1e46e675c` | MATCH |
| `scripts/game/application/tutorial_scenario_definition.gd` | `c402ce0620733478a470b2827fa2396a742b899ef3b57ab9baa690c30b77b20d` | MATCH |
| `scripts/game/tutorial/tutorial_presentation_track.gd` | `20d562868afd1483528c84d2c0f5b88df6718f750d02b8244630149c45c2a5b3` | MATCH |
| `scripts/game/tutorial/tutorial_session_policy.gd` | `a7c888f87cd1d70d428fab2d41b31e9161e4d2f42cf08ab2d08a940b2c2959a8` | MATCH |
| `scripts/game/tutorial/tutorial_director.gd` | `fe3f38c09fe526e1055c117d7b7d2a649caff94050336fbd0a9596386b7f3083` | MATCH |
| `scenes/game/tutorial/tutorial_level.tscn` | `4a17ddba8642b0086c46609323fe53d7a1730367d5125ea2369156f98dfc56a3` | MATCH |
| `tests/game/contracts/test_observer_codec_allow_lists.gd` | `9892b82259d10b96250fd5233c55260ec67fd01918eabb14afa060d4fe4d0db2` | MATCH |
| `tests/game/scenes/run_tutorial_shell_smoke.gd` | `cbced53cafbbc80afe1bee83e7a0aa8966af95601111e2b8b1bcd460f4d72923` | MATCH |

汇总：目标纠错 `1/1 MATCH`，其余 `10/10 MATCH`，additional mismatch=`0`。`QA-I1-V2-001` 关闭。

## 6. 为什么不重跑完整功能套件

QA v2 已在功能冻结 `47dd52d...` 的 clean detached worktree 中执行并通过项目 normal、Godot 4.7.1 import、architecture 17/52、observer 30、formal scenes 3/16/11、board observer、三分辨率 CONFIRMING layout、tutorial authority rejection 和 prototype run_all；该报告摘要在本候选中精确匹配。

本次候选的 `scripts/tests/scenes/resources/project.godot` Git 对象与 `47dd52d...` 逐项完全一致，新增提交只包含审查报告和转录纠错证据。重复运行同一二进制输入和同一测试代码不会验证纠错文本的新事实，反而超出本次定向缺陷范围。因此本次仅重跑项目实例 validator、候选差异/树等价、摘要复算和 whitespace 检查；若任一功能树对象发生变化，则此复用立即失效并必须恢复完整功能复审。

## 7. 任务关闭、残余风险与下一合法动作

`TASK-ARCH-001`：可关闭。`TASK-SHELL-001`：可关闭。

残余风险沿用且不扩大 QA v2 已记录的非阻断边界：prepared 回包尚无 request token；projection 的隐藏旗位等价仍属 Iteration 2；完整教学、拒绝反馈和最终美术仍未交付；后续命中 migration manifest 触发器时必须执行 1000-seed 与回放验证。

下一合法动作：项目经理绑定最终证据候选 SHA、技术/体验/本 QA 三份 approved 报告及纠错说明摘要，按 Registry/state machine 记录 Iteration 1 完成，并在既有 Contract 范围内进入 Iteration 2 `TASK-CORE-001/TASK-CORE-002`。若绑定时任一摘要或 HEAD 漂移，停止并重新审计。

本报告不批准 GATE-2。GATE-2 仍由项目所有者保留，也不授权互联网/Steam、服务器、AI、LAN 正式化或批量美术。

`file_sha256: computed_after_write`；最终 SHA-256 由交接消息提供，避免自引用改变文件摘要。
