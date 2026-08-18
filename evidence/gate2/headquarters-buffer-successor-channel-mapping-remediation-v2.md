# 大本营缓冲区后继通道映射整改 v2

## 状态

`producer_verified / pending_final_targeted_rereview`

## 返回项

技术最终复审 v2 判定 `HQ-SUCCESSOR-002` 已关闭，但 `HQ-SUCCESSOR-001` 仍缺少三项简写到正式合同的显式映射。生产规则、测试与随机消费没有变化。

## 最小整改

`docs/architecture/gate1-to-formal-migration-successor-v2.yaml` 新增 `formal_migration_delta.channel_mapping`：

- `state -> full_state`，按每次已消费行动后的 canonical state 比较；
- `event -> domain_event`，按每次已消费行动后的有序 canonical event 比较；
- `replay -> authoritative_replay + observer_replay`，前者比较最终 FullState 与 DomainEvent，后者比较实时安全 DTO 帧；
- 同表同时固化双方 PlayerView、双方 VisibleEvent、VisibleError 与 ActionPreview 的观察者和比较语义。

该整改只消除 successor 简写歧义，继续继承历史 migration manifest 的 codec、deny-list、零差异和 1000-seed 要求；不替换历史证据，不降低 `full_equivalence_rerun_required: true`。

## 复审要求

技术与独立 QA 只需定向确认映射完整、YAML 可解析、生产 Git blob 相对 `7f511f1` 未变。正式跨实现全量等价仍在 Iteration 2 执行，本文件不批准 GATE-2。
