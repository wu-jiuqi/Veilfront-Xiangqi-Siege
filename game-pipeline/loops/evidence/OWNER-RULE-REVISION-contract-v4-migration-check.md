# OWNER-RULE-REVISION Contract v4 迁移检查

状态：`approved rule and information-boundary migration / pre-implementation`
检查时间：2026-08-17T17:28:12.061633+08:00
人工决定者：项目所有者

## 确认规则

- 墙线移至红 `Y=3/4`、黑 `Y=21/22`；兵卒位于缓冲区第一线，战区保持完整 `8x9`。
- 相的视野为起点中心 `3x3`、移动田字九格与终点中心 `3x3` 的并集；田字区域只阻挡从外部进入的敌方车。
- 三旗从整个战区抽取且位置永不进入 PlayerView、AI 或 LAN 下行；仅公开夺旗进度和成功消息。
- 士改为主动献祭复活；随机池只含已阵亡的非将帅、非士友军，阵亡士明确不入池。

## 迁移与边界

- Contract v3 subject digest：`ce51fe2b91220a618cc81d22e7685f9bb06caa2fc15fa36b2cca83d51a235410`
- Contract v4 subject digest：`a0da0eec9d6d9513dd111d406c1165bc64d3b84ce1aa1ac430a2c95c10179e6a`
- Contract v4 file digest：`0ba98eac698ef594e1516d64d0c9b085ae411280909d962fff83bc5b60cb7fc9`
- approval：`approval:veilfront-xiangqi-siege:loop-contract:a0da0eec9d6d`
- Loop 保持 `active / iteration 2`，迁移不增加 iteration，不批准 GATE-1。
- 原 LAN 例外因规则与信息边界变化失效；项目所有者在本修订中明确要求继续 LAN UI 与双机测试，因此以 v4 重新批准，并要求重跑下行白名单和隐藏等价测试。
- QA-P1-003 官方 CLI 仍必须记录为 `failed / exit 1 / 精确六项已知错误`；若出现第七项错误则停止进入 review。

## 执行结果

- `validate_project_instance.py`：退出码 0，`state=normal`，错误 0，警告 0。
- 未修改的 `validate_history(...)`：退出码 0，`history_error_count=0`；revision 50 / sequence 50 / Contract v4 可完整重放。
- 官方 `validate_loop_registry.py`：退出码 1，错误集合仍恰好为 QA-P1-003 批准的六项模板错误，没有第七项；继续记录为 `failed`，不得表述为通过。
- 迁移结论：可以在 Contract v4 的批准范围内修改规则、AI、LAN UI 与测试构建；Loop 仍为 `active / iteration 2`，GATE-1 尚未决定。
