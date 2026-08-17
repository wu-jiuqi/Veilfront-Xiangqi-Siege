# AI 可见局面评价第一阶段实现计划

## 已批准边界

- 将 AI 从随机候选抽样改为全量快速预评分、关键行动保护和确定性 Top K。
- 新增只读取 `AiPlayerView`、公开规则和公开记忆的可见局面评价器。
- 本阶段不读取 `FullState`，不推断未公开棋子，不加入二层搜索或迷雾信念模型。
- 随机性只参与最终候选的微小分差，不再决定哪些行动有资格被策略评价。

## 数据流

```text
AiPlayerView 合法行动
    -> 全量快速预评分
    -> 关键行动保护 + actor/kind 分层 Top K
    -> 模拟可见行动结果
    -> 八维可见局面评价
    -> 最终微小随机扰动与确定性同分裁决
```

## 任务

- [x] 新增状态评价和候选保护行为测试。
  - Skills: `godot-prompter:godot-testing`
- [x] 新增可见局面评价器，输出 Material、GeneralSafety、FlagControl、WallState、Territory、Mobility、Vision、Threat 八维审计。
  - Skills: `godot-prompter:gdscript-advanced`
- [x] 将决策引擎候选策略替换为 `strategic-top-k-v1`。
  - Skills: `godot-prompter:gdscript-advanced`
- [x] 更新四档假设配置和审计契约。
  - Skills: `godot-prompter:resource-pattern`, `godot-prompter:godot-testing`
- [x] 运行聚焦测试、全量测试、种子矩阵和生产管线校验。
  - Skills: `godot-prompter:godot-testing`

## 验收标准

- 评分前不再随机丢弃合法行动。
- 解将、吃将、高价值可见吃子、占旗与守旗行动不会因候选预算丢失。
- 炮击密集局面仍保留多个棋子和行动类型。
- 同一 PlayerView、配置和 AI seed 的行动与审计完全一致。
- 隐藏等价的 FullState 仍产生相同 PlayerView AI 决策。

## 实现备注

- `Mobility` 第一阶段使用目标格周围八邻域的可用空间增量作为低成本代理，不声称等于完整下一回合合法行动数。
- 旗帜增量按“开始占领”的阶段收益估计，不把落点直接误判为已经完成三段占领。
- 八维评价采用“每次决策构建一次公开基线、每个候选只计算动作增量”，避免重复全盘扫描。
