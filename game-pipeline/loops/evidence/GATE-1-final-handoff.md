# GATE-1 最终交接（RC3 / Contract v5）

状态：`approved / loop_completion_authorized`

## 人工决定

- Gate：`GATE-1`
- 决定：`approved`
- 决定者：`project-owner`
- 决定时间：`2026-08-17T23:08:18.443857+08:00`
- 获批决策包摘要：`3ad999746a4942e6c9cd6986cba7a7d7e819c9f3c5ffeacaab94351d1cb589a3`
- 审批记录：`game-pipeline/approvals/gate-1-approval-8f93c3506192.yaml@subject-digest:8f93c3506192b1e286bd5f1bf631054f9fb3f0dc5337f3050716a2186a383597`
- 审批 subject digest：`8f93c3506192b1e286bd5f1bf631054f9fb3f0dc5337f3050716a2186a383597`
- 审批文件 SHA-256：`0b86972a00f33883c6358b54ca2dfc7514af648ebaa00b40bf069bc19b7f502f`

## 冻结证据

- Project Brief：`v4 / df8deb810d8c06c8c2f5763031fde2c39f14aa81226e23ffb25636ee3f1eca0b`
- Loop Contract：`v5 / d88d9017bb30437ac480e0fcf4f7b262b5ae6b3427447946e50ec37a5d3b44ca`
- RC3 候选提交：`6253678157157091584b253470e709bad17c534f`
- RC3：`builds/windows/Veilfront_Xiangqi_Siege_GATE1_RC3.exe`，`109740336` bytes，SHA-256 `480273ddeae985c0c4aa03be449e5999fba57ca7b296b591ac7ed36b5bc8a229`
- 独立 QA：`7e20acbf61a42e9dcedb88dcf68b8bc8b68d9c9f`
- QA 验收摘要：`5be2f49678c91f3738a8be23aa4f114bb4d314a0a7b491494efdcc89738ac337`
- 规则压力测试：`1000/1000`，确定性差异 `0`，回放 `20/20`
- AI 公平矩阵：`400/400`，隐藏等价、确定性、映射和提交失败均为 `0`

## 保留为正式开发输入

- `docs/prototype/rules-spec-v1.md`、结算顺序、信息边界、AI 输入契约和覆盖矩阵作为行为基线。
- `tests/prototype/`、失败 seed、回放和 QA manifests 作为后续架构迁移的回归基线。
- 玩家真双机记录、LAN 限制和 RC3 构建哈希作为体验与技术成本证据。

## 必须重审或重写

- `scripts/prototype/`、`scenes/prototype/` 和原型 UI 不自动升级为正式架构；正式功能循环开始前必须完成架构审查。
- LAN 工具缺少互联网穿透、断线重连、房主迁移和发布级反作弊；若进入产品范围必须重新立项和重写。
- AI 四档预算、50 回合上限及随机性仍是实验参数，不构成正式平衡冻结。
- RC3 不是 Steam 发布候选，不能作为 GATE-4 发布证据。

## 下一阶段准入

1. 项目经理基于 GATE-1 批准结果准备新的正式功能 Contract、范围与架构审查。
2. 优先实验 50 回合下 `590/1000` 平局的节奏和胜负反馈，不静默修改已批准规则。
3. 在 GATE-2 前只允许灰盒和可逆视觉基线工作，不得批量生产最终高成本资产。
4. 任何规则、PlayerView 或随机消费顺序变化都必须执行 Contract v5 列明的受影响回归。

## 保留风险

- QA-P1-003 仍是临时工具兼容例外；官方 Loop CLI 依旧失败且只能出现获批的固定六项错误。
- clean source 加载的两个 UID 文本回退 warning 和编辑器强制退出 scan warning 仍未消除。
- GATE-1 只确认核心体验假设值得继续，不确认正式架构、最终平衡、高成本资产或对外发布。
