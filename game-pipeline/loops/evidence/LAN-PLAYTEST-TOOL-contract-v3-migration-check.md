# LAN-PLAYTEST-TOOL-001 Contract v3 迁移检查

状态：`approved scope migration / pre-implementation`
检查时间：2026-08-17
责任角色：项目经理、Godot 技术负责人
人工决定者：项目所有者

## 问题

当前 `LOOP-CTR-GATE1-VERTICAL-SLICE-001@v2` 明确排除在线联机，无法授权已确认的局域网真人测试工具。项目所有者已批准将其限定为 GATE-1 内可丢弃的测试工具，不形成正式联网架构或发布承诺。

## 迁移结论

- Contract 从 v2 迁移到 v3，Contract ID、状态机、输入槽、必需交付项、责任角色、当前状态和迭代水位均不变化。
- 局域网工具并入 `DELIVERABLE-GODOT-001` 与 `TASK-PROTOTYPE-001`，不新增长期岗位、部门、Agent Preset 或 Child Loop。
- 当前 `active / iteration 2 / revision 48 / sequence 48` 可原位迁移；迁移本身不增加 iteration。
- Contract v2 的 QA-P1-003 工具兼容例外继续保留，插件版本、框架摘要、校验器摘要与历史 rev48 基线不变；其 Contract 失效条件重新绑定 v3。

## 允许范围

- 手动输入局域网 IP；一个房主和一个客户端。
- Godot `ENetMultiplayerPeer`，可靠离散消息。
- 房主独占 FullState、规则 RNG、准备 token 和完整审计。
- 客户端仅提交规范化 intent，并仅接收自身 PlayerView、公开反馈和连接状态。
- 独立 Git worktree 并行开发；AI 稳定提交后再串行接入共享 UI。

## 禁止范围

- 正式联网架构、互联网联机、匹配、NAT 穿透、观战、聊天、重连、房主迁移或专用服务器。
- 客户端持有 FullState、RNG 内部状态、未来随机结果、对手不可见信息或完整审计日志。
- 以局域网工具替代独立 QA、GATE-1 人工决定或首版单机核心证据。

## 迁移前基线

- v2 subject digest：`7b7fcf36920109d379aa0e230cf70a378ed7ec228ff6a88bccf35cf481fcf09c`
- v2 file digest：`5a9ed8f5854865adfecbcff808f8dc96af52abecb371dbd18bb8fd137a775e62`
- Snapshot rev48 file digest：`6f9648f514be14b5b777b7b38f0d79c9ec34848e99cb6cac36db572f807545e5`
- Event History rev48 file digest：`7ab40f1d81fadf706f55e956a6fe85adbf35850cff3f86eaebe0e98d2db1c5c9`
- Loop Registry validator digest：`90804f2221af1973d099f4fc531fd39e8aaaaca7bf101922ee63c9c67f909633`

## 迁移后绑定

- v3 subject digest：`ce51fe2b91220a618cc81d22e7685f9bb06caa2fc15fa36b2cca83d51a235410`
- v3 file digest：`2a0dd3487aa46504244dc420d495ae0ae7b30da180034f3242a3b5f793b16706`
- approval：`approval:veilfront-xiangqi-siege:loop-contract:ce51fe2b9122`

## 后续验证

1. 追加 `core.contract_migrated`，原子更新 Snapshot 到 revision 49 / sequence 49。
2. 运行项目实例校验、Organization Registry 历史重放、Loop History 重放和官方 CLI 观察。
3. 官方 CLI 若仍返回 QA-P1-003 的精确六项模板错误，只记录为既有受控例外，不得表述为通过；若出现第七项错误则停止实现。
4. 校验通过后创建独立 worktree，并在实现前记录 Godot 路径映射。

## 执行结果

- `validate_project_instance.py`：退出码 0，`state=normal`，错误 0，警告 0。
- 未修改的 `validate_history(...)`：退出码 0，`history_error_count=0`；revision 49 / sequence 49 / Contract v3 绑定可完整重放。
- 官方 `validate_loop_registry.py`：退出码 1，仍为 QA-P1-003 已批准的精确六项模板错误；未出现第七项错误，不记录为通过。
- 迁移结论：Contract v3 与 Registry 绑定有效，可按批准范围进入局域网测试工具实现；GATE-1 权限和正式生产禁令保持不变。
