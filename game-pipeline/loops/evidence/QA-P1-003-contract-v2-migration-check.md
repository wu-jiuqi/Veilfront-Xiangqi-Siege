# QA-P1-003 Contract v2 迁移检查

状态：`approved / ready_to_apply`

## 迁移对象

- Loop：`LOOP-GATE1-001 / Iteration 1`
- 迁移：`LOOP-CTR-GATE1-VERTICAL-SLICE-001 v1 -> v2`
- Contract v2 subject digest：`7b7fcf36920109d379aa0e230cf70a378ed7ec228ff6a88bccf35cf481fcf09c`
- Contract v2 file digest：`5a9ed8f5854865adfecbcff808f8dc96af52abecb371dbd18bb8fd137a775e62`
- 批准记录：`approval:veilfront-xiangqi-siege:loop-contract:7b7fcf369201`

## 精确绑定基线

- 插件：`game-production-pipeline@0.4.0-alpha.2`
- 框架摘要：`3589bce5cf4388f91a08f12acb5d90679256191d5085e65687d06a635bbdcd32`
- 校验器摘要：`90804f2221af1973d099f4fc531fd39e8aaaaca7bf101922ee63c9c67f909633`
- 决策包摘要：`b1eef2e3b99673a5070b0aa4d73c7d27eca8b5e315796f596e07757acbc1c210`
- v1 subject digest：`a970c55fe068a1252251ee4d30dedff32bee9da1f8e7e7ef7dc0c501be416799`
- v1 file digest：`a0380db5819f9651bbb2b0fab243bb3489504b11ed808506f2ecb92a589ae1ad`
- rev30 Snapshot file digest：`4b1c2ab9d224e4e91e076a2f7f08e42dbdafed88e6f2564b01f20461be88d291`
- rev30 Event History file digest：`17a75a74da3a3314353351d22dc0fb6d7f8c4b941ae8f617b4e3b7c2f97b83e8`
- rev30 尾事件摘要：`1c4508c725c900959f649e6761bd0e54d3c1fcb5e14f35089b320fa43fe32e89`

## 兼容性结论

- v2 由 v1 确定性复制；除 `version`、新的批准绑定和新增 `temporary_tooling_compatibility` 外，原 Contract 语义未改变。
- 临时规则只处理 QA-P1-003 的六项已知官方 CLI 模板错误；官方 CLI 必须继续记录为 `failed`。
- 玩法、质量阈值、1000 种子、确定性、独立 QA、GATE-1 权限和正式生产边界保持不变。
- 迁移只允许追加 `core.contract_migrated`；前 30 条事件不得改写。
- 独立 QA 接受例外并确认全部条件前，Loop 保持 `active`。

## 失效与回退

任一 v2 `invalidation_conditions` 成立时，本例外立即失效；不得以本记录宣称官方 CLI 通过，也不得自动作出 GATE-1 决定。
