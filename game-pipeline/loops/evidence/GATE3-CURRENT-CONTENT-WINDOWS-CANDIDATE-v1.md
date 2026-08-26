# GATE-3 当前内容 Windows 候选证据 v1

## 状态

- 审查日期：2026-08-27
- 源提交：`fda2f5abc7a976967f5f4b03bebba250cce0616f`
- 生命周期：`producer_reviewed_runnable_candidate_awaiting_independent_qa`
- 边界：这是生产者侧可运行候选，不代表 GATE-3 冻结、专业验收通过或 GATE-4 发布批准。

## 范围约束

本轮遵守“不要新增内容”的所有者约束。没有增加关卡、玩法、规则、教程模块、美术或音频内容；仅审查现有实现，并修正现有运行时资源未进入 Windows 导出白名单的问题。

补齐的既有导出依赖包括：双轨教程模块目录与 Resource、教学抽屉、战阵图鉴、18 张图鉴运行时图片、棋盘 Audio 发射池和 VFX 预置根。

## 审查结果

- 37 个功能契约入口通过，覆盖规则与玩家视图边界、教程课程与交互、前端与设置、音频/VFX、局内反馈、正式 LAN 全栈、断线恢复及性能。
- 静态审查未发现 `FullState`/领域层绕过、运行时动态生成关键节点，或在 `_process` / `_physics_process` 内同步加载资源。
- 部分单项 headless 契约在退出时仍会报告 Godot 测试进程资源清理警告；断言与退出码均通过。该项记录为测试夹具清理债务，不据此宣称日志完全无警告。

## 可复现构建

```powershell
./tools/release/build_windows_runtime_candidate.ps1 `
  -GodotExecutable "D:/Godot/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"
```

构建链结果：

- Godot 4.7.1 导入：通过
- 交互性能契约：通过
  - 选择 p99：0.442 ms
  - 确认 p99：10.818 ms
  - 迷雾缓存 p99：0.136 ms
- 正式 LAN 全栈回环契约：通过
- Windows pack / release 导出：通过
- 运行时资源与容量预算：通过
- 成品 120 帧启动冒烟：通过

## 产物

| 产物 | 路径 | SHA-256 | 大小 |
| --- | --- | --- | ---: |
| Windows embedded-PCK EXE | `builds/windows/Veilfront_Xiangqi_Siege_Formal_LAN.exe` | `2453c62593d54c41c339ea0f8cafd66c8b7f56866083bda148bfdede2785a203` | 233,063,128 bytes |
| 可审计运行时包 | `builds/windows/Veilfront_runtime_manifest.zip` | `e695eca889b4a930dba9ac6070d222a56ab450c6d2988739c9da1b34cafa1ef1` | 121,741,569 bytes |

运行时包共 607 个条目，展开体积 123,769,797 bytes；导入后纹理 79,470,640 bytes，字体 39,230,269 bytes。清单要求的 36 个资源根、18 张图鉴运行时图片和 42 个关键包条目均存在，硬排除路径命中数为 0。

## 尚未覆盖

- EXE 未进行代码签名，仅适合作为本地开发/测试候选。
- 尚未在两台物理 Windows 设备上完成人工 LAN 联机、真实声卡、分辨率与完整新手玩家体验走查。
- 独立 QA 尚未从冻结提交重建并登记专业验收；不得据此关闭 GATE-3 或推进外部发布。
