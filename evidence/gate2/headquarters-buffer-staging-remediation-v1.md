# 大本营缓冲区前置规则整改证据 v1

状态：`producer_verified / pending_independent_review`

项目所有者裁决：`OWNER-CONFIRM-2026-08-18:HEADQUARTERS-BUFFER-STAGING`。

## 问题与结论

整改前，`MoveRules.evaluate_move()` 只在敌墙为 `INTACT` 时阻止踏入或跨越城墙线；敌墙进入 `BREACHED/REPAIRING` 后，车可以从中央战区一手进入敌方大本营并吃子，也可以先落入敌营空点绕过缓冲区。

整改后，任意移动/吃子的意图目标若位于敌方大本营，行动起点必须已经位于该敌方缓冲区（含墙线）或大本营。该规则与墙状态无关、红黑对称；从战区或其他非守方缓冲区位置一手直入敌营会返回 `enemy_buffer_staging_required`。这是一条公开的行动资格，先于隐藏阻挡解析，因此不能提交“直击敌营”后再依赖隐藏相田字格把棋子截停。

## RED / GREEN

- RED：新增红方战区直击黑营、红方战区直入黑营空点、黑方战区直击红营三个负向断言后，`run_owner_rule_revision_v5.gd` 退出码 `1`，三个用例均失败；证明原逻辑缺失。
- GREEN：统一合法性入口增加大本营缓冲区前置后，同一 runner 退出码 `0`，并继续通过红方从黑缓冲区攻击黑营、黑方从红缓冲区攻击红营两个正向断言。
- 聚合回归：Godot 4.7.1 无头导入完成；`tests/prototype/run_all.gd` 退出码 `0`，`scaffold=9 focused_suites=15`。

## 固定种子证据

命令：

```text
D:\Godot\godot.cmd --headless --path . --script res://tests/prototype/run_seeded_matches.gd -- --seeds 1000 --start-seed 471001 --round-limit 50 --replay-samples 20 --manifest-path <manifest>
```

结果：

- requested/completed：`1000/1000`
- failure：`0`
- determinism checked/mismatch：`1000/0`
- replay verified：`20/20`
- records digest：`cd73f70f0b5b2db4aa01822f218f1e92a2dc75ed1b404982fde00f52b6925341`
- manifest SHA-256：`567278537d9eb62412e0ed0b50f6ea259d0129a1f527653892f390d2ae616c08`
- 正常 manifest 校验退出码：`0`
- `--force-record-tamper` 退出码：`1`，错误为 `manifest_count_or_digest_mismatch`

原始 manifest：`evidence/prototype/qa/gate2-headquarters-buffer-staging-1000-seeds-round50.jsonl`。

## 产物摘要

| 路径 | SHA-256 |
|---|---|
| `docs/prototype/rules-spec-v1.md` | `26fd3d25e2a97a39b3cd817fd74e16442360de41b40fc4fa9e035340ae2528a9` |
| `docs/prototype/settlement-order-v1.md` | `502ac07853050038a440a894f0b80d3949bd84e173c393e2cbd46a657af57507` |
| `docs/prototype/rules-test-coverage-matrix-v1.md` | `8ce64a69a586bb4665b7e9490ce7a3aaf3369a34908d3f2c5ef53d34d66cdabe` |
| `scripts/prototype/core/move_rules.gd` | `c3f8c9e3ef377bbacf5e455fe47835ba4f265e585364890d75feb10a4e3746e4` |
| `scripts/prototype/view/player_view_projector.gd` | `97b6a37b0c489749185cbc106e0113f9fed33ba04954975ac017997b85f5c75a` |
| `tests/prototype/test_owner_rule_revision_v4.gd` | `20fd4529df4b9a56f7d3eca7922bc92f73197c7bea67fc6b5d45ec5cea5b7b23` |
| `tests/prototype/test_owner_rule_revision_v5.gd` | `d4f93cdff965fed7355e597c5b361fb7ed82ecf213e5186823a4e977c1004436` |
| `tests/prototype/run_all.gd` | `ceee04273c211b92bba77e250053be0d517eacabd4ef00e55fcee82c0fec2de6` |
| `evidence/prototype/qa/gate2-headquarters-buffer-staging-1000-seeds-round50.jsonl` | `567278537d9eb62412e0ed0b50f6ea259d0129a1f527653892f390d2ae616c08` |

## GATE-2 输入影响

本次项目所有者澄清修改了三份 revision 5 规则事实源的当前内容，因此 Iteration 1 的历史架构审查与独立 QA 仍只证明其冻结提交，不得继续被解释为与当前规则文件摘要相同。进入 Iteration 2 正式核心迁移前，项目经理必须以本证据和上述新摘要建立 successor binding，并安排技术与独立 QA 定向复审；不得改写既有历史证据。
