# GATE-2 v3 技术收口交接

- Contract：`LOOP-CTR-FORMAL-FOUNDATION-GATE2-001` v3
- 工作项：`TASK-PRESENTATION-2D-001`
- 生产者：Godot 技术负责人 `inst:01M02NJ3JEQXKV6PT6DPX0NKQ0`
- 引擎：Godot 4.7.1 stable
- 状态：生产者技术初审；待 QA 在干净工作树独立复现

## 相机合同退出修复

### 根因

`run_board_camera_layer_contract.gd` 会把正式 `BoardViewport` 放进额外的测试 `SubViewport`，而正式棋盘内部还有一个固定为 `1152×3072`、`UPDATE_ALWAYS` 的 `BoardSubViewport`。该合同只检查相机状态、坐标映射、层级关系和输入结果，不读取像素；但无头运行仍会在每个 `process_frame` 前光栅化完整棋盘、迷雾材质和棋子纹理。诊断阶段日志证明测试已进入 `_run()` 并在首次 `render_player_view()` 后等待下一帧，卡点发生在清理之前，不是父子节点 `queue_free()`。

测试现在只对测试实例设置 `BoardSubViewport.UPDATE_DISABLED`。正式场景和运行时渲染配置未改动，原有断言均保留。新版 HUD 已移除 `BoardFrame/BoardBorder` 时，合同以“节点不存在或 bottom patch margin 为 0”验证同一语义：地图上方没有额外底边线；这也避免空引用 `SCRIPT ERROR` 吞掉测试退出。

### 复现与严格判定

```powershell
& 'D:\Godot\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' `
  --headless --path . `
  --script res://tests/game/presentation/run_board_camera_layer_contract.gd
```

验收必须同时满足：进程在硬超时内退出、退出码为 0、输出包含 `BOARD_CAMERA_LAYER_CONTRACT_PASS`，并且完整 stdout/stderr 不含 `SCRIPT ERROR:`、`ERROR:` 或 `BOARD_CAMERA_LAYER_CONTRACT_FAIL`。不能仅凭 Godot 退出码判绿。

生产者于 2026-08-23 使用外部 180 秒硬超时复验：`HARD_TIMEOUT=0`、`EXIT_CODE=0`、完整阶段日志到达 `cleanup_complete`、输出 `BOARD_CAMERA_LAYER_CONTRACT_PASS`，stderr 为空，stdout/stderr 均未出现 `SCRIPT ERROR:`、`ERROR:` 或 FAIL 标记。

相邻回归由 QA 复现：

- `tests/game/presentation/run_board_layout_contract.gd`
- `tests/game/presentation/run_formal_board_art_input_contract.gd`
- `tests/game/scenes/run_formal_scene_smoke.gd`

由于本轮宿主机调度异常，以上相邻回归未由生产者在同一轮可靠跑完，不能据此宣称通过；根代理/QA 应在结束并行 Godot 进程后单线程复验。

## Windows 测试包导出范围

`export_presets.cfg` 仍使用 `all_resources`，以保留完整运行时资源和可执行测试，但显式排除了非运行时目录：`docs`、`evidence`、`game-pipeline`、`tmp`、`output`、旧 `builds`，以及工具临时目录 `.codex-temp`、`.tmp`、`.playwright-cli`。`tests/` 没有排除。

历史 EXE 从约 245 MB 增长到约 297 MB 与项目根出现大量可导入证据图、PDF 中间图片和旧构建相符。新的 exclude filter 防止这些内容继续进入 PCK；QA 应在同一干净提交上分别导出旧/新过滤规则或检查 PCK 清单，记录最终字节数。不能把代码签名/模板体积误判为资源压缩收益。

## CHECK-PERFORMANCE-2D-001 生产者基线

### 纹理与显存估算

- 正式棋盘逻辑画布：`1152×3072`。
- 单张未压缩 RGBA8 等价占用：`width × height × 4`；1152×3072 约 13.5 MiB。
- 含 mipmap 时使用约 `基础层 × 4/3`；GPU 实际值还取决于 S3TC/BPTC 导入与驱动对齐。
- 总纹理显存估算应从正式场景依赖闭包提取所有 Texture2D，按各自导入格式、mipmap 和重复资源去重后求和；不得用 PNG 文件大小替代显存。
- SubViewport 颜色/深度附件、迷雾 Shader 中间缓冲与主窗口 back buffer 必须单列，不能混入静态纹理总量。

### 可复现帧率采样方案

1. 使用当前 GATE-2 候选 EXE，固定 1280×720、VSync 关闭；分别采样空棋盘、14 棋子+墙旗、最大公开反馈三种状态。
2. 每种状态预热 10 秒，再记录 60 秒；保存平均 FPS、1% low、主线程 frame time、GPU frame time、draw calls、对象数和 Video RAM。
3. 红/黑双方各跑一次；视角切换、拖拽、缩放和迷雾更新都必须覆盖。
4. 另在 960×540 低配配置复现；核心棋盘、棋子、旗帜、合法落点和 HUD 文字仍须可读。
5. QA 使用独立机器/干净工作树复现，并把硬件、驱动、渲染后端和提交摘要写入证据。

### 当前低配模式事实

当前没有独立的“低配模式”开关或获批的质量档位事实。960×540 是 Contract 要求的最低响应式验收分辨率，不等同于低配渲染模式。GATE-2 决策包必须将此标为待验证/待后续 Contract 的风险，不能宣称已有低配模式。

## 剩余风险

- 生产者测试期间机器进程调度异常缓慢，连 PowerShell 原生只读命令也出现 30–90 秒启动延迟；因此最终时长与性能数据必须由 QA 单线程、干净环境重测。
- `all_resources + exclude_filter` 的最终体积收益需要以新导出的 EXE/PCK 字节数证明。
- 本交接不替代独立 QA，也不构成 GATE-2 人工批准。
