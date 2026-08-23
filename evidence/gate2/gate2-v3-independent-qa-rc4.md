# GATE-2 v3 独立 QA 报告（RC4）

- QA 实例：`inst:01M02NJ3JFHVZ5C4SP5MTJFJR6`
- 候选提交：`419e2cef5d4fac9f099c8ea487b5e6d6a5c57445`
- Contract：`LOOP-CTR-FORMAL-FOUNDATION-GATE2-001` v3
- Contract 批准摘要：`9d9e3cfc5e92d41d38eea336dbcca95040bb858706ffd8130a8b33a3594e7dd9`
- 验收日期：2026-08-23（Asia/Shanghai）
- 独立技术结论：`pass`
- GATE-2 路由建议：`recommend_awaiting_human`

本报告只证明自动条件和独立专业审查满足；GATE-2 的体验、方向与残余风险接受仍由项目所有者人工决定。

## 1. 候选身份和管线健康

验收开始时：

- `HEAD` 与 `origin/main` 均为 `419e2cef5d4fac9f099c8ea487b5e6d6a5c57445`；
- `git status --porcelain` 无输出，起始 worktree clean；
- `validate_project_instance.py` exit 0，项目与插件锁均为 `normal`，插件版本 `0.4.0-alpha.2` 和框架摘要匹配；
- `validate_formal_foundation_gate2_registry.py` exit 0，输出 `FORMAL_FOUNDATION_GATE2_REGISTRY_PASS state=active iteration=3 sequence=61 revision=61`；
- Godot 为 `4.7.1.stable.official.a13da4feb`，当前渲染方法为 `gl_compatibility`。

## 2. RC3 → RC4 影响面

审阅范围：`54ba29947bb886ffd1fc4abf751d2c3c5751d9b5..419e2cef5d4fac9f099c8ea487b5e6d6a5c57445`。

- 49 个变更路径中，47 个是 RC3 QA 报告/日志/截图/性能证据；
- 生产代码仅修改 `scripts/game/presentation/board/board_viewport_controller.gd`；
- 测试仅修改 `tests/game/presentation/run_turn_camera_visibility_contract.gd`；
- 修订引入显式相机 authority，令玩家平移/缩放/小地图位置在同阵营视图更新和延迟布局后保持；可见敌方移动拥有有界自动跟随；显式阵营切换仍重置默认锚点；
- 没有修改 domain/application、PlayerView、随机、回放、网络、教程、Theme、场景、资产、export preset 或 pipeline 事实源。

完整路径清单：`evidence/gate2/v3-candidate-419e2ce/impact-files-54ba299-to-419e2ce.txt`。

因此 architecture/dependency、static theme、LAN integration/security、tutorial 和 formal equivalence 可复用 RC3 原始证据；复用理由是这些模块和对应 runner 未受变更，且 RC4 当前打包产物另行通过 LAN full-stack。受相机/表现影响的相机、布局、隐藏等价、双方截图和性能全部在 RC4 当前提交重跑。

## 3. 当前提交自动执行结果

所有 runner 均要求 exit 0、指定 PASS marker、无超时，且完整 stdout/stderr 不含 `SCRIPT ERROR:`、行首 `ERROR:` 或 `FAIL/FAILED`。

### 3.1 相机合同严格连续五次

| 连续轮次 | 结果 | 时间 | marker / forbidden |
|---:|---|---:|---|
| 1 | pass | 22.350s | `TURN_CAMERA_VISIBILITY_CONTRACT_PASS` / 0 |
| 2 | pass | 15.250s | 同上 / 0 |
| 3 | pass | 13.459s | 同上 / 0 |
| 4 | pass | 16.918s | 同上 / 0 |
| 5 | pass | 14.870s | 同上 / 0 |

五轮均 exit 0、无超时。原始日志及 `turn-camera-visibility-5-run-summary.json` 位于 `evidence/gate2/v3-candidate-419e2ce/logs/`。

首次临时 runner 自检因 `Start-Process` 未引用含空格的项目路径而没有加载项目；修正 `.codex-temp` 编排后覆盖重跑。该基础设施自检不计入上述产品五连结果，也未修改生产源或测试。

### 3.2 关联合同

| runner | 结果 | 时间 | 证据 |
|---|---|---:|---|
| board camera layer | pass | 18.121s | exit 0、marker、零 forbidden |
| board layout | pass | 33.210s | `BOARD_LAYOUT_CONTRACT_PASS resolutions=6`、零 forbidden |
| hidden equivalence | pass | 13.508s | exit 0、marker、零 forbidden |

## 4. 三分辨率双方视角

使用真实 Windows/OpenGL 进程、Intel Iris Xe 和精确尺寸 `SubViewport` 重拍；不是 headless dummy renderer。捕获 exit 0，输出 `GATE2_RC4_MATCH_CAPTURE_PASS images=6`。

| 分辨率 | 赤方 | 玄方 |
|---|---|---|
| 960×540 | `screenshots/match-960x540-red.png` | `screenshots/match-960x540-black.png` |
| 1280×720 | `screenshots/match-1280x720-red.png` | `screenshots/match-1280x720-black.png` |
| 1920×1080 | `screenshots/match-1920x1080-red.png` | `screenshots/match-1920x1080-black.png` |

路径基准：`evidence/gate2/v3-candidate-419e2ce/`。逐图检查结果：HUD、棋盘框、棋子、城墙、旗帜、雾和小地图均在画面内，赤/玄阵营可辨，无 UI 裁切。当前默认最大缩放按既有合同显示棋盘局部并由小地图提供九路/全盘导航；`board_layout` 当前提交验证六种分辨率、九路权威坐标映射和这一最大缩放语义。

## 5. 当前提交性能与保守显存

验收机：13th Gen Intel Core i5-1340P（12 核/16 逻辑处理器）、Intel Iris Xe Graphics（驱动 `31.0.101.4146`）、16,890,716,160 bytes RAM（约 15.73 GiB）。Godot 输出为 OpenGL 3.3 / Compatibility / Intel Iris Xe。

使用真实非 headless Windows/OpenGL 进程，关闭 VSync；每档预热 5 秒后采样至少 30 秒：

| 配置 | 帧数/时长 | 平均 FPS | p99 帧时 | 1% low 等价 | 最大帧时 | readable |
|---|---:|---:|---:|---:|---:|---|
| 1280×720 默认运动 | 4758 / 30.006s | 158.569 | 10.016 ms | 99.840 FPS | 87.515 ms | true |
| 960×540 + reduced motion | 4631 / 30.005s | 154.343 | 9.775 ms | 102.302 FPS | 196.833 ms | true |

低配样本出现单帧 196.833 ms 尾部尖峰，但 p99、1% low、平均值和连续 30 秒可读性均稳定；Contract 未规定单帧最大阈值，因此记录为宿主调度/尾部风险观察，不构成自动失败。

项目**没有独立质量档位开关**；“低配验收配置”只指 `960×540 + reduced motion`，不是已有低配模式。

RC4 没有资产改动，因此沿用并重新适用 RC3 的目录级保守估算：60 张运行候选纹理解压 RGBA 为 173,473,440 bytes（165.437 MiB）；完整 mip 链按 `4/3` 为 220.583 MiB；1152×3072 RGBA 画布单份 13.5 MiB、双缓冲 27.0 MiB；合计约 **247.583 MiB**。该值可能包含运行时未引用预览纹理，不等同于驱动实测峰值。

机器可读性能文件：`performance-1280x720-default.json`、`performance-960x540-reduced-motion.json`。

## 6. Windows Desktop Formal LAN 成品包

- 导出 preset：`Windows Desktop Formal LAN`，embedded PCK；未修改 preset；
- 文件：`builds/windows/Veilfront_Xiangqi_Siege_Gate2_v3_419e2ce.exe`；
- 大小：286,523,048 bytes；
- SHA256：`EA008CF1B6F68DBD2598DBCF4981F8CD40F065D0F995F69878F543D38DD84130`；
- 导出 exit 0，`savepack DONE`，零 forbidden；
- `pwsh tools/release/verify_windows_lan_export.ps1` 对 embedded PCK 运行，exit 0；
- marker：`FORMAL_LAN_FULL_STACK_LOOPBACK_PASS ux=ready-start-match-submit-disconnect`；
- marker：`WINDOWS_LAN_EXPORT_VERIFY_PASS`；
- 日志：`logs/windows-export.log`、`logs/windows-lan-export-verify.log`。

## 7. Contract v3 十项检查矩阵

| Check | RC4 判定 | 当前候选证据与影响理由 |
|---|---|---|
| CHECK-CONTRACT-V3-001 | pass | HEAD/origin、起始 clean、Brief/Contract approval、project/Registry validator 均匹配。 |
| CHECK-DEPENDENCY-001 | pass | RC3 architecture/dependency 原始证据通过；RC4 仅改 presentation 相机状态，没有新增反向依赖。 |
| CHECK-INFORMATION-2D-001 | pass | RC4 hidden equivalence 当前重跑通过；PlayerView/fog/LAN security 未改，当前打包 full-stack 亦通过。 |
| CHECK-GODOT-2D-001 | pass | Godot 4.7.1 当前提交完成合同、真实 GPU 场景捕获、性能运行和 Windows 导出，零 forbidden。 |
| CHECK-COORDINATE-001 | pass | 相机 5/5、board camera layer、board layout 当前提交均通过；赤/玄方向截图可辨。 |
| CHECK-RESPONSIVE-2D-001 | pass | RC4 960×540、1280×720、1920×1080 × 赤/玄六张截图无 UI 裁切，核心可读。 |
| CHECK-PERFORMANCE-2D-001 | pass | 两档真实 GL 30 秒采样、硬件/后端、可读性和 247.583 MiB 保守 VRAM 证据齐全。 |
| CHECK-ART-2D-001 | pass | RC4 无资产/清单变更；RC3 资产清单和 art/input 证据仍适用，六张当前截图确认表现未失效。 |
| CHECK-REGRESSION-001 | pass_with_limitation | RC4 相机/布局/隐藏等价和 packaged LAN 通过；规则、教程、随机、回放未改。当前候选沿用 RC3 同一代码的 1-seed 等价 PASS；本机当前提交未重跑 3/20 seed，历史 20-seed golden 仅作冻结背景，不冒充当前证据。该限制满足本轮已冻结的代表性回归口径。 |
| CHECK-SCOPE-001 | pass | RC4 生产差异仅二维相机控制器；未引入三渲二正式化、互联网 SDK、服务器、AI 交付或批量资产。 |

十项必要检查均满足当前冻结口径；`CHECK-REGRESSION-001` 的 1-seed 局限已显式保留，不降低或伪造证据。

## 8. 独立专业审查

结论：`pass`。

- QA 与生产实例独立，并从 clean worktree 复现相机、布局、隐藏信息、真实 GPU、性能和成品包证据；
- RC3 的相机失败已由当前候选严格连续五次转绿，且关联布局/隐藏等价未回归；
- 差异未静默修改规则、教学语义、PlayerView、随机序列或回放；
- 当前二维样片仍是 Demo/灰盒视觉基线，没有冒充完整美术；旧三维内容仍只作为后期可选研究资产；
- EXE 当前候选可追溯并通过 packaged LAN full-stack；
- 没有未满足的必要自动条件。下一合法状态是由项目经理整理人工决策包并请求项目所有者 GATE-2 判断。

## 9. 人工决定范围、风险与审批摘要

项目所有者仍需判断：正式二维表现、教学灰盒、信息边界与视觉样片是否足够稳定，值得进入 Demo 级二维批量资产生产。

已知但不阻断的风险：

- 当前候选只保留 1-seed 等价代表性回归，未在本机完成当前 3/20-seed 实跑；
- 960×540 reduced-motion 样本有一次 196.833 ms 最大帧时尖峰；
- EXE 约 286.5 MB，当前 preset 仍包含开发/测试资源；应在 GATE-3/发布前收敛导出过滤规则。

可逆选择：批准进入下一阶段、要求针对上述风险追加证据，或退回相机/二维表现继续修订。QA 建议 `awaiting_human`，不替代批准。

审批建议 canonical string：

`candidate=419e2cef5d4fac9f099c8ea487b5e6d6a5c57445|contract_digest=9d9e3cfc5e92d41d38eea336dbcca95040bb858706ffd8130a8b33a3594e7dd9|exe_sha256=EA008CF1B6F68DBD2598DBCF4981F8CD40F065D0F995F69878F543D38DD84130|qa_instance=inst:01M02NJ3JFHVZ5C4SP5MTJFJR6|technical_verdict=pass`

审批建议摘要：`4d347f8cb18b5d081b37e9dbeb37cab7d4a06d7c7270171468c428deb39ed0da`

## 10. 进程与工作区收口

- `OWN_GODOT_PROCESS_COUNT=0`；
- QA 启动的 Godot/导出/验证进程均已退出；
- 仅观察到 PID 20532、开始时间 2026-08-23 07:00:28 的既有 Godot 编辑器，未触碰；
- QA 未修改产品代码、测试、pipeline 或 export preset；未提交、未推送。
