# GATE3 alpha.3 Registry CLI 兼容性记录 v1

日期：2026-09-01

状态：`known-preexisting-contract-extension-drift / non-blocking-for-v3-producer-update / requires-separate-contract-governance`

## 结论

升级到 `game-production-pipeline@0.4.0-alpha.3` 后，项目本地的运行态 Event History 重放函数通过：

`CONTENT_INTEGRATION_GATE3_REGISTRY_PASS state=active iteration=2 sequence=38 revision=38`

alpha.3 官方 `validate_loop_registry.py` CLI 仍报告 8 项 Contract/Registry 扩展差异：

1. Contract 缺少三条新版拓扑规则文本：父 ID 不得等于当前 Loop、父图无环、`blocking=true` 依赖图无环。
2. Registry 中已经项目所有者批准并绑定的 `INPUT-ORG-G3-001` 未列入原始不可变 Contract v1 输入槽。
3. Registry 中已经项目所有者批准并绑定的 `INPUT-FTUE-DUAL-TRACK-EXCEPTION-001` 未列入原始不可变 Contract v1 输入槽。
4. 对应历史事件因此重复报告未知输入槽。

## 影响判断

- 这些差异在本次教程 v3 图片更新前已经存在，不是 sequence 37–38 引入。
- 当前 Snapshot 与 Event History 的摘要链、sequence、revision 和重放状态一致。
- 项目实例校验为 `normal`；教程生产者更新不修改 Contract、输入槽或人类审批事实。
- 不得为了让 CLI 变绿而静默改写已批准 Contract。应另立 Contract 修订/迁移并由项目所有者批准。

## 后续行动

在进入 GATE3 独立 QA 或人工冻结前，准备一份 alpha.3 Contract 兼容性修订计划，明确新增拓扑规则与两个既有批准输入槽；在精确摘要获批后再迁移 Contract 与 Registry 绑定。
