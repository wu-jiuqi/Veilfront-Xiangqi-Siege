# GATE-2 规则基线 revision 5 第二次整改证据

状态：`completed / awaiting REM-G2-R2-002 binding and final independent re-review`

整改项：`REM-G2-R2-001` / `QA-G2-ARCH-001-R2`

责任身份：

- Agent Instance：`inst:01M02NJ3JENHD8VV7EKC9G198Q0`
- Position：`pos:veilfront-xiangqi-siege:design-experience:systems-experience-lead`
- Authority：`AUTH-VEILFRONT-SYSTEMS-EXPERIENCE`

## 精确修订

1. `docs/prototype/rules-spec-v1.md` 的车特殊规则已从“逐枚处理阵亡/替死”改为逐目标执行“实际死亡登记到所属方公开阵亡记录→将帅检查”，并明确不触发任何被动士替死；将帅实际死亡仍立即终局并截断后续目标。
2. 旗帜占领中断原因已从“替死回营”改为 revision 5 的真实生命周期：占领者离开、死亡、主动献祭、复活流程导致占领实例离场、强制撤回或棋子实例变化时立即清零。
3. 章节名由“迷雾、旗帜、替死与胜负”改为“迷雾、旗帜、献祭复活与胜负”，只清除已取消机制的主题残留，不改变 owner revision 5 语义。

## 四事实源摘要

| 事实源 | SHA-256 | 本次状态 |
|---|---|---|
| `docs/prototype/rules-spec-v1.md` | `34a1d398beaee6610f3d614559a5af7a14abd464e5df4d86ac26aa3824504ddd` | 已修订 |
| `docs/prototype/settlement-order-v1.md` | `7335fb20723e6a36eb961ed50739f590e9e426b927af726ca7fbbe7c6992694a` | 只读审计，未修改 |
| `docs/prototype/information-boundary-v1.md` | `dd76596fb4e196732ea73da9cefc33f3879b3102df345b46f55cf00fe7c17d07` | 只读审计，未修改 |
| `docs/prototype/rules-test-coverage-matrix-v1.md` | `5a6c277bbcb74f038953337a7634a1c4e3c7d53bc58b76dfff50d6d2e6f7199b` | 只读审计，未修改 |

## “替死 / 救援 / 前两次”全量残留审计

审计范围为上述四份完整文件，关键词为：`替死|救援|前两次|强制士|rescue|substitut`，不区分英文大小写。

### A. 现行规则中的明确否定、取消或迁移约束：允许

- `rules-spec-v1.md`：车路径明确“不触发任何被动士替死”；士规则明确所有被动及“前两次阵亡强制替死”取消；炮击明确不触发被动士替死。
- `settlement-order-v1.md`：变更摘要明确删除旧机制；伤亡窗口、车路径与炮击窗口均明确不存在被动士替死。
- `rules-test-coverage-matrix-v1.md`：现行车、炮击、结算与胜负条目都以“不触发 / 无 / 不存在”约束被动替死；`CHECK-RUNALL-001` 要求 revision 5 移除或改写旧被动替死断言。

这些命中只禁止旧机制，不构成现行被动替死行为。

### B. 历史追溯、稳定标识或 `SUPERSEDED` 说明：允许

- `stmt:veilfront-xiangqi-siege:piece-rescue` 是 Project Brief 的稳定 statement ID，仅作为追溯标识，不描述运行时行为。
- 覆盖矩阵中的旧 `RESCUE-001`、旧炮击 rescue 测试函数、`...NO-PASSIVE-RESCUE...` Test ID 与旧“替死”统计均被明确标为 `SUPERSEDED`、历史证据或否定性覆盖目标。

这些命中不得被正式实现、测试或架构文档解释为当前规则授权。

### C. 信息边界命中：零

`docs/prototype/information-boundary-v1.md` 对上述关键词无命中；未发现投影、事件、错误、提示或回放侧暗含被动替死旁路。

### D. 未分类或冲突的现行行为：零

未发现仍把被动替死、前两次强制替死或被动救援描述为现行行为的文本。`QA-G2-ARCH-001-R2` 指出的车路径和旗帜生命周期两处冲突均已关闭。

## 规则一致性结论

- 车路径、炮击、普通吃子、主动献祭和将帅实际死亡造成的死亡均进入所属方公开阵亡记录；双方 PlayerView 同步双方记录。
- 士只能主动选择、确认或取消献祭复活；确认后发动士先死亡并登记，再从己方记录筛选非士、非帅/将候选。阵亡士与帅/将虽然保留在公开记录中，但永不进入复活候选池。
- 旗帜占领进度绑定具体棋子实例；任何使该占领实例离开旗点或生命周期失效的 revision 5 原因都会立即清零。
- 未发现需要项目所有者重新裁决的语义歧义。完整轮上限和 AI 参数继续保持开放；正式架构仍为 `hypothesis`。

## 验证与边界

- `git diff --check -- docs/prototype/rules-spec-v1.md evidence/gate2/rules-baseline-revision5-remediation-r2.md`：通过。
- 未修改结算表、信息边界、覆盖矩阵、架构、代码、测试、Project Brief、Contract、Registry、approval 或其他文件。
- 未提交或推送。
- 本证据只关闭规则文档漂移，不声明最终复审、第二生产循环、正式架构或 GATE-2 已通过。

下一合法交接：Godot 技术负责人以新的规则规格 SHA-256 和本 R2 证据完成 `REM-G2-R2-002`，随后项目经理创建最终双审 assignment。技术与独立 QA 对同一输入集均给出 `approved` 前，不得生成 satisfied input binding、登记第二循环或开始实现。
