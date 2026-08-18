# GATE-2 正式架构整改复审任务

状态：`active / REM-G2-003 / loop-not-started`

登记时间：`2026-08-18`

## 复审水位

- Git：`main@fc22faa`
- Project Brief v5 subject digest：`41bb82fae4f1a0294d17746f3b9caf063ee69d2bd07e0f7d15d26baad9ab89bb`
- Contract approved source digest：`9beb91baa720820d0f0985019e5a77a4e0e065a8721451eedc30e0cc22bdeaef`
- GATE-1 approval subject digest：`8f93c3506192b1e286bd5f1bf631054f9fb3f0dc5337f3050716a2186a383597`

## 不可歧义输入集

| 产物 | SHA-256 |
|---|---|
| `docs/architecture/post-gate1-formal-architecture-review-v2.md` | `6320614a35dfa03398d6aae53a8b62bbc3f42199e471f98b59590e603bfbe025` |
| `docs/architecture/formal-dto-and-trust-boundary-v1.md` | `6f23274810aad5d6f2515bd78b114da16684e38f9abe04e2d59dcfa87fc174f2` |
| `docs/architecture/gate1-to-formal-migration-manifest-v1.yaml` | `69f784de94296b593d71f08b81ed96a169e61d4a00becc7f1668cfc8082822ec` |
| `evidence/gate2/architecture-remediation-v1.md` | `904b68d92f606ee18d2dcca8e75892c77229673b2d5132cd5813430f48b3db10` |
| `docs/prototype/settlement-order-v1.md` | `7335fb20723e6a36eb961ed50739f590e9e426b927af726ca7fbbe7c6992694a` |
| `docs/prototype/rules-test-coverage-matrix-v1.md` | `5a6c277bbcb74f038953337a7634a1c4e3c7d53bc58b76dfff50d6d2e6f7199b` |
| `evidence/gate2/rules-baseline-revision5-remediation.md` | `a47a80f32b269040b4c872cdf25c9223eb57f097a74ccd7fccc1e4d13fbfaadb` |

## 技术复审

- Reviewer：`pos:veilfront-xiangqi-siege:technology:godot-technical-lead`
- Agent Instance：`inst:01M02NJ3JEQXKV6PT6DPX0NKQ0`
- 唯一产物：`evidence/gate2/architecture-technical-rereview-v2.md`
- 必须验证：Godot 4.7.1 可行性、依赖方向、DTO/codec、viewer 与 projection 权限、Replay 分级、Input Map/迷雾 ADR、迁移 manifest 命令和失败回退；不得沿用 v1 技术结论代替本次复审。

## 独立 QA 复审

- Reviewer：`pos:veilfront-xiangqi-siege:quality:qa-release-lead`
- Agent Instance：`inst:01M02NJ3JFHVZ5C4SP5MTJFJR6`
- 唯一产物：`evidence/gate2/architecture-independent-qa-rereview-v2.md`
- 必须验证：`QA-G2-ARCH-001..004` 逐项关闭、规则源无被动替死残留、v2 successor 的 Contract input 绑定可审计、manifest 摘要/seed/replay/codec 完整、防泄露 deny list 可执行；不得修改任何生产事实源。

## 判定与权限

- 两份复审必须针对上表同一摘要集合独立得出结论。
- 任一结论不是 `approved`，返回其精确责任路径，保持循环未启动。
- 两份结论均为 `approved` 后，只授权项目经理生成 `INPUT-ARCH-REVIEW-001` 绑定并执行循环启动审计；不批准 GATE-2，不授权互联网、AI 或批量美术。
