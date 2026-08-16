# AI 可见局面评价第一阶段 Producer Smoke

状态：`producer smoke / not independent QA / hypothesis`

## 验证对象

- 候选策略：`strategic-top-k-v1`
- 局面模式：`visible-state-evaluation-v1`
- 信息边界：规范化 `AiPlayerView`、公开规则、AI 记忆、独立 AI seed
- 八维审计：Material、GeneralSafety、FlagControl、WallState、Territory、Mobility、Vision、Threat

## 结果

- 聚焦 AI 策略测试：通过。
- 灰盒试玩回归：通过；自动 AI、四档 profile、审计隔离均通过。
- 完整基础回归：通过，`scaffold=9 focused_suites=12 full_gate1=false`。
- 8 seeds × 4 profiles 单决策矩阵：32/32 记录成功。
  - determinism mismatch：0
  - hidden-equivalence mismatch：0
  - action mapping failure：0
  - submit failure：0
  - 简单/中等/困难/专家实际平均深度评价候选：8 / 32 / 96 / 243
  - 四档均选择公开合法 `move`；简单/中等/困难/专家分别出现 6 / 3 / 5 / 1 个不同最终行动 ID
- 生产管线实例校验：`normal`，errors=0，warnings=0。

## 炮棋垄断缺陷回归

- 复现：固定种子 `471001`、专家档、玩家连续公开跳过时，修复前 26 次黑方行动全部由两门炮完成。
- 根因：长程移动的 Territory 按跨越格数线性累计，Vision 按终点新增可见格线性累计；首回合炮因此得到 `32 + 45 + 4 = 81`，而同期最好兵/马/车仅为 `19 / 10 / 6`。动作重访只按完整动作 ID 计数，炮更换落点即可规避。
- 修复：单次 Territory 与 Vision 收益封顶；高价值棋子离开己方区域且无保护时计入 Threat 风险；AI 记忆增加己方行动棋子访问次数并施加节奏惩罚。
- 结果：同种子前 15 次 AI 行动已包含兵、马、车；26 次观察中炮不再垄断。新增 `test_ai_piece_diversity.gd` 固定种子回归。

## 已知限制

- 本证据不是独立 QA，也不是 Contract v2 的 1000-seed gate。
- 本阶段没有二层对手回应搜索或迷雾信念模型。
- `Mobility` 是公开局面的低成本八邻域代理。
- Godot 在受限沙箱中需要把 `APPDATA`/`LOCALAPPDATA` 临时指向工作区 `.tmp`；根证书读取告警不影响离线测试。
- 隔离副本缺少已生成 UID 缓存时会回退到文本资源路径；资源均成功加载。
