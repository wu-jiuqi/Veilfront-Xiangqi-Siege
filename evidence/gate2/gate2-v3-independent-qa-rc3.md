# GATE-2 v3 独立 QA 报告（RC3）

- QA 实例：`inst:01M02NJ3JFHVZ5C4SP5MTJFJR6`
- 候选提交：`54ba29947bb886ffd1fc4abf751d2c3c5751d9b5`
- Contract：`LOOP-CTR-FORMAL-FOUNDATION-GATE2-001` v3
- 验收日期：2026-08-23（Asia/Shanghai）
- 独立专业结论：`revisions_required`
- GATE-2 建议：**不得进入 `awaiting_human`**。

## 候选身份与执行约束

验收开始时：

- `HEAD` 与 `origin/main` 均为 `54ba29947bb886ffd1fc4abf751d2c3c5751d9b5`；
- `git status --short` 无输出，起始 worktree clean；
- 项目实例和插件锁为 `normal`；
- Registry 为 `state=active iteration=3 sequence=61 revision=61`；
- Godot 为 `4.7.1.stable.official.a13da4feb`，项目渲染方法为 `gl_compatibility`。

所有自动 runner 单线程执行，并由宿主设置每项 360 秒硬超时。只有进程退出码 0、指定 PASS marker 存在、完整 stdout/stderr 不含 `SCRIPT ERROR:`、行首 `ERROR:` 或 `FAIL/FAILED` 才判绿。原始日志位于 `evidence/gate2/v3-candidate-54ba299/logs/`。

## 阶段 A：定向复验

| 项目 | 结果 | 时间与证据 |
|---|---|---|
| formal architecture + dependency | pass | 77.028s；同时出现 `FORMAL_ARCHITECTURE_CHECKS_PASSED` 与 `DEPENDENCY_BOUNDARY_CHECK_PASSED`，exit 0、零 forbidden。 |
| static UI theme | pass | 32.837s；exit 0、marker 存在、零 forbidden。 |
| LAN network integration | pass | 162.301s；exit 0、marker 存在、零 forbidden。 |
| LAN security/recovery | pass | 50.950s；exit 0、marker 存在、零 forbidden。 |
| LAN full-stack loopback | pass | 237.991s；出现 `FORMAL_LAN_FULL_STACK_LOOPBACK_PASS`，零 forbidden。 |
| formal equivalence/replay（3 seeds） | timeout | 合法 runner，显式参数 `-- --seeds 3 --replay-samples 3`；361.344s 后被硬超时终止，无 marker、无错误文本。 |
| formal equivalence/replay（1 seed 代表性回归） | pass_with_limitation | 同一合法 runner，显式参数 `-- --seeds 1 --replay-samples 1`；293.854s，exit 0，`FORMAL_EQUIVALENCE_PASS completed=1`，零 forbidden。 |

根据项目经理冻结的验收口径，当前提交的 1-seed 结果可与已冻结的历史 20-seed golden 证据共同支撑“代表性回归通过但有局限”。历史 golden 仅作背景，不冒充本提交 20-seed 实跑；本机未在 360 秒内完成本提交 3-seed。

## 阶段 B：当前候选视觉证据

使用真实 Windows/OpenGL 进程和精确尺寸 `SubViewport` 捕获，不使用 headless dummy renderer。捕获 marker 为 `GATE2_RC3_MATCH_CAPTURE_PASS images=6`。

| 分辨率 | 赤方 | 玄方 |
|---|---|---|
| 960×540 | `screenshots/match-960x540-red.png` | `screenshots/match-960x540-black.png` |
| 1280×720 | `screenshots/match-1280x720-red.png` | `screenshots/match-1280x720-black.png` |
| 1920×1080 | `screenshots/match-1920x1080-red.png` | `screenshots/match-1920x1080-black.png` |

路径基准：`evidence/gate2/v3-candidate-54ba299/`。人工检查六张图：棋盘九路、正式 HUD、雾、棋子、城墙、旗帜和小地图均在画面内可辨识，赤/玄视角方向可区分，未见裁切。教学布局 runner 另以当前提交执行，116.212s 输出 `TUTORIAL_LAYOUT_CONTRACT_PASS resolutions=3`，exit 0、零 forbidden。

## 阶段 C：性能与显存证据

验收机：

- CPU：13th Gen Intel Core i5-1340P（12 核、16 逻辑处理器）；
- GPU：Intel Iris Xe Graphics，驱动 `31.0.101.4146`；
- RAM：16,890,716,160 bytes（约 15.73 GiB）；
- Godot 输出：OpenGL 3.3 / Compatibility / Intel Iris Xe Graphics。

采样使用真实的非 headless Windows/OpenGL 进程，窗口移出桌面但不伪装 GPU；关闭 VSync，预热 5 秒后连续采样至少 30 秒。结果：

| 配置 | 样本 | 平均 FPS | 1% low 等价值 | p99 帧时 | 最大帧时 | 可读性 |
|---|---:|---:|---:|---:|---:|---|
| 1280×720 默认 | 30.006s / 4658 帧 | 155.238 | 89.750 FPS | 11.142 ms | 72.528 ms | 核心布局可读；按钮最小高度 44px。 |
| 960×540 + reduced motion | 30.000s / 5040 帧 | 167.999 | 109.685 FPS | 9.117 ms | 10.427 ms | reduced motion 实际启用；核心布局可读。 |

机器可读结果：`performance-1280x720-default.json`、`performance-960x540-reduced-motion.json`。

项目**没有独立质量档位开关**；“低配验收配置”只表示 `960×540 + reduced motion`，不得表述为已有独立低配模式。

正式运行候选纹理目录的保守估算：60 张纹理，解压 RGBA 为 173,473,440 bytes（165.437 MiB）；按完整 mip 链乘 `4/3` 为 220.583 MiB。1152×3072 RGBA 画布单份 13.5 MiB、双缓冲 27.0 MiB；纹理 mip 与双画布合计约 **247.583 MiB**。这是目录级保守估算，可能包含运行时未实际引用的预览纹理，不等同于驱动实测峰值。

## 阶段 D：Windows Desktop Formal LAN 成品包

- 导出 preset：`Windows Desktop Formal LAN`（未修改 preset，embedded PCK）；
- 文件：`builds/windows/Veilfront_Xiangqi_Siege_Gate2_v3_54ba299.exe`；
- 大小：286,517,800 bytes；
- SHA256：`A1666FED6324C38D8C5F0F3B857B1CC234CE8CD63F7286017C6E4B0547933FC5`；
- Godot 导出：exit 0，`savepack DONE`；
- `tools/release/verify_windows_lan_export.ps1`：通过 `pwsh` 执行，exit 0，输出 `FORMAL_LAN_FULL_STACK_LOOPBACK_PASS ux=ready-start-match-submit-disconnect` 与 `WINDOWS_LAN_EXPORT_VERIFY_PASS`，零 forbidden；
- 成品验证日志：`logs/windows-lan-export-verify.log`。

补充：Windows PowerShell 5 直接解析该 UTF-8 无 BOM 脚本会产生乱码语法错误，改用 PowerShell 7 `pwsh` 后脚本原样通过。这是 verifier 宿主编码兼容问题，不计为产品失败。

## 当前提交关键回归

为完成十项 Contract 审查，另以当前提交运行 9 项关键矩阵，结果为 **8 pass / 1 fail**：

| 项目 | 结果 | 时间/marker |
|---|---|---|
| formal scene smoke | pass | 118.555s |
| board layout | pass | 187.090s |
| formal board art/input | pass | 159.235s |
| formal fog visual | pass | 46.942s |
| hidden equivalence | pass | 92.414s |
| observer contract | pass | 7.049s |
| tutorial rule boundary | pass | 8.764s |
| tutorial progress | pass | 21.528s |
| turn camera visibility | **fail** | 78.593s；exit 1，marker 缺失，2 条 forbidden。 |

### QA-G2V3-RC3-001：玩家相机在移动事件后被重置或移动

- runner：`tests/game/presentation/run_turn_camera_visibility_contract.gd`；
- 结果：`TURN_CAMERA_VISIBILITY_CONTRACT_FAIL failures=2`；
- 失败断言：`own move reset or moved the player's camera`；
- 失败断言：`hidden enemy move reset or moved the player's camera`；
- 日志：`logs/turn_camera_visibility.stdout.log` 与 `logs/turn_camera_visibility.stderr.log`；
- 分类：真实产品/行为回归，非超时、非 runner 配置错误；
- 返回：Godot 技术/棋盘相机生产责任人。QA 不修改生产事实源。

## Contract v3 十项自动检查

| Check | RC3 判定 | 独立证据结论 |
|---|---|---|
| CHECK-CONTRACT-V3-001 | pass | 候选身份、normal 状态、Git 与 Registry 均已核验。 |
| CHECK-DEPENDENCY-001 | pass | 正确聚合入口同时输出架构与依赖 PASS marker。 |
| CHECK-INFORMATION-2D-001 | pass | hidden equivalence、observer、fog、LAN security/recovery 与 full-stack 当前提交均通过。 |
| CHECK-GODOT-2D-001 | pass | static theme、formal scene smoke、真实渲染截图及 Windows 导出均通过。 |
| CHECK-COORDINATE-001 | **fail** | board layout 与截图通过，但 turn camera visibility 出现 2 条真实失败断言。 |
| CHECK-RESPONSIVE-2D-001 | pass | 三分辨率赤/玄六图及 tutorial layout 三分辨率 runner 通过。 |
| CHECK-PERFORMANCE-2D-001 | pass | 真实 GL 两配置 30 秒采样、硬件、后端和保守 VRAM 证据齐全。 |
| CHECK-ART-2D-001 | pass | formal board art/input 与六张当前候选截图通过；正式纹理规格已汇总。 |
| CHECK-REGRESSION-001 | pass_with_limitation | LAN、隐藏信息、教学与 1-seed 等价/回放通过；本机当前 3-seed 超时，历史 20-seed golden 仅作冻结背景。 |
| CHECK-SCOPE-001 | pass | QA 未修改生产源、测试、pipeline 或 export preset；仅新增本报告、候选证据与导出产物。 |

## 独立专业审查

结论：`revisions_required`。

- 成品包已成功导出并通过 packaged LAN full-stack；视觉、响应式、性能、信息隔离、教学和大部分坐标证据可接受。
- 当前候选存在可复现的相机行为回归：己方移动和不可见敌方移动都会重置或移动玩家相机。该项属于 required `CHECK-COORDINATE-001`，因此不能建议进入 `awaiting_human`。
- formal equivalence 当前提交只完成 1-seed 代表性回归；3-seed 在本机 360 秒超时。按冻结口径记为 `pass_with_limitation`，不隐藏该限制。
- Windows 包体 286.5 MB，preset 当前会包含测试/开发资源；本 Gate 未把包体优化列为失败条件，但建议 GATE-3/发布前由技术生产岗位收敛导出过滤规则。

## 下一合法动作

Godot 技术岗位修复移动事件触发的相机重置/位移，形成新的 clean 候选；QA 在新候选上至少定向复验 `turn_camera_visibility`，并确认修订未破坏 board layout、formal board art/input、赤/玄截图与 packaged LAN full-stack。全部 required checks 转绿后，QA 才可建议项目所有者进行 GATE-2 人工体验审批。
