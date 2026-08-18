# Iteration 1 技术整改证据 v1 纠错说明

## 1. 纠错结论

- QA 缺陷：`QA-I1-V2-001`
- 结论：`evidence_transcription_corrected`
- 日期：`2026-08-18`
- 冻结候选：`main@47dd52ded8dbe2585d9d0f4fa93c6687624745af`
- 被纠正证据：`evidence/gate2/iteration1-remediation-technical-v1.md`
- 被纠正证据 SHA-256：`c9c797641c3890696c2f68419dc07fec5b49a8f053ac69b0640ab4c0d55c3d48`
- Agent Instance：`inst:01M02NJ3JEQXKV6PT6DPX0NKQ0`
- Position：`pos:veilfront-xiangqi-siege:technology:godot-technical-lead`
- Authority：`AUTH-VEILFRONT-GODOT-TECHNOLOGY`

旧技术整改报告第 4 节的 `tutorial_smoke_track.tres` 摘要多转录了末尾两个字符。该问题只影响证据表的一行文本，不改变受审文件、提交、测试结果、整改功能或原报告的技术结论。旧报告保持不可变；本文件是该单行摘要的附加纠错绑定。

## 2. 精确纠正

文件：`resources/game/tutorials/presentation/tutorial_smoke_track.tres`

| 项目 | 值 | 长度 | 判断 |
|---|---|---:|---|
| 旧报告错误声明 | `51ad930000b271104468f81b34749bc415c40dc06cf52f4c4f45c872023912a5b3` | 66 | `INVALID_SHA256_LENGTH` |
| 冻结候选重新计算 | `51ad930000b271104468f81b34749bc415c40dc06cf52f4c4f45c872023912a5` | 64 | `CORRECT` |

纠错规则：读取旧报告时，仅以本文件中的 64 字符值替代旧报告第 92 行对应摘要；旧报告的其他文本、范围、RED/GREEN 记录和结论均不变。

## 3. 旧报告其余产物摘要复算

以下 10 条摘要均在冻结候选 `47dd52d...` 上重新计算，并与旧报告声明逐字匹配：

| 文件 | 旧报告声明 / 实算 SHA-256 | 结果 |
|---|---|---|
| `scripts/game/contracts/player_view_codec.gd` | `a9c91d2747414d088eb4bb9eba59f15d5f9110815268322b51c693440238d3fd` | `MATCH` |
| `scripts/game/contracts/visible_event_codec.gd` | `3549c66e389eaa20e58ebf3ae86d6e044e1e69b1631192295efe0cdf053f541c` | `MATCH` |
| `scripts/game/application/application_host.gd` | `0d483a6cb84bdc40a0f8e08fa8813e2360d2caad36ca5d47f99f3ae1e46e675c` | `MATCH` |
| `scripts/game/application/tutorial_scenario_definition.gd` | `c402ce0620733478a470b2827fa2396a742b899ef3b57ab9baa690c30b77b20d` | `MATCH` |
| `scripts/game/tutorial/tutorial_presentation_track.gd` | `20d562868afd1483528c84d2c0f5b88df6718f750d02b8244630149c45c2a5b3` | `MATCH` |
| `scripts/game/tutorial/tutorial_session_policy.gd` | `a7c888f87cd1d70d428fab2d41b31e9161e4d2f42cf08ab2d08a940b2c2959a8` | `MATCH` |
| `scripts/game/tutorial/tutorial_director.gd` | `fe3f38c09fe526e1055c117d7b7d2a649caff94050336fbd0a9596386b7f3083` | `MATCH` |
| `scenes/game/tutorial/tutorial_level.tscn` | `4a17ddba8642b0086c46609323fe53d7a1730367d5125ea2369156f98dfc56a3` | `MATCH` |
| `tests/game/contracts/test_observer_codec_allow_lists.gd` | `9892b82259d10b96250fd5233c55260ec67fd01918eabb14afa060d4fe4d0db2` | `MATCH` |
| `tests/game/scenes/run_tutorial_shell_smoke.gd` | `cbced53cafbbc80afe1bee83e7a0aa8966af95601111e2b8b1bcd460f4d72923` | `MATCH` |

复算汇总：`10 MATCH / 0 additional mismatch`。连同第 2 节纠正后的目标文件，旧报告第 4 节全部 11 个产物均可绑定到冻结候选。

## 4. 影响与后续绑定

1. 本纠错不修改生产代码、测试、Resource、场景、旧证据、Contract、Registry、approval 或 Git 历史。
2. `I1-TECH-001/002/003` 的整改实现、RED/GREEN 结果、限制与下一合法动作不变；不需要重新实现或重跑功能测试来修复这项纯转录错误。
3. 后续 QA 和决策包引用旧技术整改报告时，必须同时绑定：
   - 原报告 SHA-256 `c9c797641c3890696c2f68419dc07fec5b49a8f053ac69b0640ab4c0d55c3d48`；
   - 本纠错说明的外部 SHA-256；
   - 冻结候选 `47dd52ded8dbe2585d9d0f4fa93c6687624745af`。
4. 本纠错只关闭 `QA-I1-V2-001` 的摘要一致性问题，不代替技术、系统体验或独立 QA 对冻结候选的专业结论。

## 5. 完整性

- `HEAD` 与 `origin/main` 在复算时均为 `47dd52ded8dbe2585d9d0f4fa93c6687624745af`。
- 旧报告摘要已重新计算并与任务输入匹配。
- `git diff --check` 与本文件 no-index whitespace check：定稿后执行。
- `file_sha256: computed_after_write`；最终 SHA-256 在外部交接消息中记录，避免自引用。
