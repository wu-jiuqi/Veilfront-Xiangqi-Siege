# 正式运行时代码区

本目录只承载 GATE-2 第二生产循环逐切片迁移后的正式代码。现有 `scripts/prototype/` 保持可运行基线，不得直接整目录复制到这里。

保留的正式边界：

- `contracts/`：版本化 DTO 与 codec；无 SceneTree 生命周期。
- `domain/`：FullState、规则、结算、确定性随机；不依赖 Godot Node、表现、教学、AI、LAN 或网络。
- `application/`：唯一 FullState owner、SeatContext/viewer 绑定与用例。
- `projection/`：唯一 FullState → observer-safe DTO 出口。
- `presentation/`：只消费 PlayerView、VisibleEvent、VisibleError、ActionPreview 和本地 UI 状态。
- `tutorial/`：只消费绑定观察者的安全 DTO，不读取 authority 数据。
- `ports/`：application 拥有的接口与本轮进程内测试替身，不连接外部服务。

依赖规则由 `res://tests/game/architecture/run_formal_architecture_checks.gd` 自动验证。子目录在出现首个真实实现文件时创建，不使用空 GDScript 或无职责节点占位。
