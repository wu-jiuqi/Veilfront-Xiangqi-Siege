# GATE-2 v3 收口执行计划（2026-08-23）

状态：`active / contract-v3-bound / owner-requested-closeout`

## 目标

在不启动完整音频、全量特效、完整动画、最终 UI 皮肤或其他 GATE-2 后批量生产的前提下，完成 `LOOP-CTR-FORMAL-FOUNDATION-GATE2-001 v3` 的四项交付、独立复核、Windows 测试构建和 GATE-2 人工决策包，将循环合法推进到 `waiting_approval`，等待项目所有者试玩后的批准、拒绝或修订意见。

## 绑定输入

- Project Brief v7，subject digest `8e9d4285c1c7237a22f308808e944fd8571700f896b8dd8cfb118f0fe0de3d3e`。
- Contract v3，approval subject digest `9d9e3cfc5e92d41d38eea336dbcca95040bb858706ffd8130a8b33a3594e7dd9`。
- Registry loop `83c995ff-37b9-4df8-9e84-8417d6632187`，启动水位 `active / iteration 3 / sequence 61 / revision 61`。
- 当前二维方向、二维资产清单、保留的架构/规则/回放/教学产物和已批准正式 LAN 例外。

## 部门任务与文件边界

### 技术部

- 负责人：`inst:01M02NJ3JEQXKV6PT6DPX0NKQ0`。
- 任务：`TASK-PRESENTATION-2D-001` 收口；修复相机合同测试挂起；核对导出范围、构建体积和二维性能证据。
- 交付：`evidence/gate2/gate2-v3-technical-handoff.md`，以及经验证的必要工程改动。
- 禁止：修改规则、PlayerView、随机序列、教学语义或未授权 UI 事实源。

### 系统与体验部

- 负责人：`inst:01M02NJ3JENHD8VV7EKC9G198Q`。
- 任务：`TASK-TUTORIAL-2D-COMPAT-001` 收口；证明现有教学复用 Intent/Event 与二维表现，并划分 GATE-2 必修 UI 问题和后续打磨项。
- 交付：`evidence/gate2/gate2-v3-systems-experience-handoff.md`。
- 禁止：把待批双轨教学提案写成已实现事实，或修改正式规则/教学语义。

### 视觉制作

- 负责人：`pos:veilfront-xiangqi-siege:design-experience:visual-production-lead`。
- 任务：`TASK-ART-2D-001` 收口；校正二维资产清单并索引当前样片、三分辨率证据与成本未知项。
- 交付：`docs/art/demo-2d-asset-inventory-v1.yaml`、`evidence/gate2/gate2-v3-visual-handoff.md`。
- 禁止：把 GATE-2 后完整音频、动画、VFX 或最终 UI 标记为当前完成。

### 质量与发布

- 独立复核实例：`inst:01M02NJ3JFHVZ5C4SP5MTJFJR6`。
- 启动条件：生产文件提交并推送，工作区清洁，候选提交与构建路径冻结。
- 任务：`TASK-QA-V3-001`；在 clean worktree 复现 Contract 十项自动检查、三目标分辨率、双方视角、信息安全、性能和 Windows 导出验证。
- 交付：`DELIVERABLE-QA-2D-001` 独立报告；QA 不修改被测生产事实源。

## 交付与验收

- `DELIVERABLE-PRESENTATION-2D-001`：正式二维对局壳和技术交接。
- `DELIVERABLE-ART-2D-001`：二维视觉基线、样片与校正后的资产清单。
- `DELIVERABLE-QA-2D-001`：绑定候选提交、构建和复现命令的独立 QA 报告。
- `DELIVERABLE-GATE2-2D-001`：风险、选项、证据索引、EXE 和审批摘要组成的人工决策包。

自动检查按 Contract v3 的 `CHECK-CONTRACT-V3-001` 至 `CHECK-SCOPE-001` 全部执行；任何进程退出码非零、`SCRIPT ERROR:`、非预期 `ERROR:`、测试挂起、摘要不匹配或证据过期均不得记为通过。

## 提交、构建与闸门

1. 各部门交付由项目经理按功能拆分为中文 `feat:` 提交并推送。
2. 生产交付冻结后，从 clean worktree 启动独立 QA，不允许生产者作为唯一审查者。
3. 只从 QA 通过的候选提交导出 Windows EXE，并执行包内正式 LAN 全栈验证。
4. 自动检查和专业复核全部通过后，登记四项交付物、审批请求和 `review -> waiting_approval` 中断上下文。
5. 项目所有者试玩 EXE 后拥有 GATE-2 的 `approve / reject / revise` 决定权；任何 Agent 不得代批。

## 预算与升级

- 沿用 Registry 的 iteration limit `4`；当前无成本承诺。
- 技术问题返回技术部，教程/交互语义问题返回系统体验部，资产事实源问题返回视觉制作，证据不足返回质量与发布。
- 需要改变规则、PlayerView、二维方向、范围、成本承诺或接受残余 Gate 风险时，立即升级项目所有者。
