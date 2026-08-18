# GATE-2 Iteration 1 实现设计工作绑定

状态：`producer_complete / pending_handoff_review`

## 工作身份

- Work item：`G2-I1-DESIGN-001`
- Loop instance：`83c995ff-37b9-4df8-9e84-8417d6632187`
- Loop state：`active / iteration 1`
- Contract：`LOOP-CTR-FORMAL-FOUNDATION-GATE2-001@v1`
- 对应任务：`TASK-ARCH-001`、`TASK-SHELL-001`
- Owner/producer：`pos:veilfront-xiangqi-siege:technology:godot-technical-lead`
- Active instance：`inst:01M02NJ3JEQXKV6PT6DPX0NKQ0`
- Authority：`AUTH-VEILFRONT-GODOT-TECHNOLOGY`
- Reviewer：`pos:veilfront-xiangqi-siege:quality:qa-release-lead`；涉及交互/教学部分另交系统与体验负责人复核。

本工作使用已登记的正式 Position Instance，没有创建新的 Agent Instance，因此无需新增临时实例 Registry start event。

## 目标

把已批准的正式架构边界和两份用户提供的参考方案收敛为可施工的 Godot 预置场景树、运行时接口/信号图和首批迁移切片，同时修正参考方案中的旧 27×9 棋盘、Presentation 读取 RuleSet、固定旗位和 Tutorial seed 暴露问题。

## 输入

- 正式架构 v2：`58e55d7e6e2fb25c04a243017fc8e0230915a36dcc09cacaf7076b10423705f4`
- DTO/信任边界 v1：`6f23274810aad5d6f2515bd78b114da16684e38f9abe04e2d59dcfa87fc174f2`
- 迁移 manifest v1：`0502e20a861a550e9845cfa1a10e4b5d94b97d1da884add2d0de70e9fa14daa4`
- revision 5 规则：`34a1d398beaee6610f3d614559a5af7a14abd464e5df4d86ac26aa3824504ddd`
- 用户参考：`chatgpt-conversation://6a83c9cb-b020-83ec-9834-6c70d798ee3d`、`chatgpt-conversation://6a83e882-771c-83ec-a200-d329cef749fa`；均标记为非权威参考。

## 输出

- `docs/godot-prompter/specs/formal-godot-scene-composition-v1.md`：SHA-256 `26532200c5af5bda899e5b8eb1048e89d352a5713bb2c3d1ed839d63d6c9e488`
- `docs/godot-prompter/specs/formal-runtime-interface-and-signal-map-v1.md`：SHA-256 `936fca4e83e62d68639e7d5546d878484f549bb59318c0189fba31b2c3f83b09`
- `docs/godot-prompter/plans/iteration1-formal-shell-migration-plan-v1.md`：SHA-256 `4781b95d15bcfafa4846401c771731e7c3d80e0a3c7289812fc95bc1467ce8f7`

## 验收

- 明确 9×24/216 交点、区域/墙线、镜像和正方形点距。
- 场景固定树以 `.tscn/.tres` 预置为先，动态实例均有数量/生命周期理由。
- Presentation 只消费 PlayerView/VisibleEvent/VisibleError/ActionPreview，不读取 RuleSet/FullState/raw event。
- Fog 使用单一预置 Control；不生成 216 个雾格 Control。
- 教学 authority/presentation Resource 分离，TutorialDirector 不读取 seed、FullState 或 authority replay。
- 定义 960×540、1280×720、1920×1080 响应式验收和 headless 场景入口。
- 定义切片失败返回、Iteration 2 交接和 manifest 全量重跑条件。

## 预算与边界

- 使用当前 Iteration 1，不新增循环或临时 Agent。
- 不采购、不连接外部服务；不实现互联网、LAN 正式化、AI 或批量美术。
- 不修改规则事实源、正式 DTO 合同、prototype 运行时或 GATE-1 证据。

## 升级与失败返回

- 需要改变 revision 5、DTO 字段、Demo 范围或互联网承诺：停止并升级项目经理/项目所有者。
- 教学无法用 observer-safe DTO 表达：返回系统与体验负责人改写步骤。
- 场景必须读取 FullState 或 raw event 才能工作：返回 `TASK-ARCH-001`，不建立旁路。
- 本工作只完成生产者设计交付，不把文档完成解释为 Iteration 1、独立 QA 或 GATE-2 完成。
