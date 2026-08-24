# GATE-2 v3 独立 QA 报告（RC5）

- QA 实例：`inst:01M02NJ3JFHVZ5C4SP5MTJFJR6`
- 最终候选：`05ada9848c20c41b6d6cc92ce552df643c31438c`
- 产品基线：`0a8ab17cdd633ee68e604bb687c1c86f6b93e9a3`
- Contract：`LOOP-CTR-FORMAL-FOUNDATION-GATE2-001` v3
- Contract 批准摘要：`9d9e3cfc5e92d41d38eea336dbcca95040bb858706ffd8130a8b33a3594e7dd9`
- 验收日期：2026-08-24（Asia/Shanghai）
- 独立技术结论：`pass`
- GATE-2 路由建议：`recommend_updated_owner_approval`

本报告证明当前候选满足 GATE-2 v3 自动条件和独立专业审查；项目所有者仍须对更新后的候选、包体增长与已披露限制作出新的人工决定。旧候选 `419e2ce` 的审批主题不覆盖本候选。

## 1. 身份、管线与独立性

- `HEAD` 与 `origin/main` 均为 `05ada9848c20c41b6d6cc92ce552df643c31438c`。
- 验收起点 `0a8ab17` 与远端一致且产品工作区 clean；QA 只创建 `evidence/gate2/v3-candidate-0a8ab17/`、`evidence/gate2/v3-candidate-05ada98/`、本报告和最终 EXE。
- 最终候选验收时仅存在 QA 证据以及不属于 QA 的 `evidence/art-previews/red_infantry_run_cycle_v1/` 未跟踪文件；后者未读取为门禁证据、未修改、未纳入提交。
- `validate_project_instance.py` exit 0，项目、插件锁及框架摘要均为 `normal`。
- Registry validator exit 0：`waiting_approval / iteration 3 / sequence 79 / revision 79`。该状态仍绑定旧人工请求，必须由项目经理生成更新决策包。
- Godot：`4.7.1.stable.official.a13da4feb`；目标渲染：`gl_compatibility`。

原始日志：`evidence/gate2/v3-candidate-05ada98/logs/project-validator.log`、`registry-validator.log`。

## 2. 影响面与证据复用

`3c4a0ff..0a8ab17` 涉及 188 个路径、约 10,111 行新增和 688 行删除，覆盖正式 HUD、联机 HUD、关卡选择、关卡指引、教学导航/暂停/完成、棋盘输入与相机、LAN 应用与测试、Theme、中文字体，以及大量 UI/教学 PNG。它未直接修改 domain、规则、PlayerView DTO、确定性随机或回放事实源，但 presentation、tutorial、network 和测试入口均被触及，因此不能沿用 RC4 的完整结论。

QA 在 `0a8ab17` 执行 48 项严格批次：45 项直接通过；两项因新增平滑镜头后测试只等待 1–3 帧而失败；`match_hud_v3_layout_lab` 的唯一失败是 dummy renderer 无法取得截图纹理。最终候选 `05ada98` 只修改以下两个测试，产品内容与 `0a8ab17` 完全一致：

- `tests/game/tutorial/run_tutorial_board_visual_contract.gd`
- `tests/game/tutorial/run_board_hover_coordinate_contract.gd`

修订只增加最多 120 帧、以 `camera_motion_active=false` 为终点的有界等待，没有删除或降低任何产品断言。基于零产品差异，`0a8ab17` 的 45 项通过结果、六张双方视角样片和附加 UI 样片可作为最终候选的同一产品证据；两项修订测试及相机关联项在 `05ada98` 重跑。

基础批次摘要：`evidence/gate2/v3-candidate-05ada98/logs/base-0a8ab17-contract-run-summary.json`。

## 3. 自动合同与回归结果

所有计入通过的 runner 均满足 exit 0、指定 PASS marker、无超时，并且 stdout/stderr 中不存在 `SCRIPT ERROR:`、行首 `ERROR:`、失败 marker 或 `FAIL:`。

### 3.1 基础批次的 45 项直接通过

- architecture + dependency、static theme、formal scene smoke；
- board camera layer、turn camera visibility 5/5、board layout、formal board art/input、fog visual；
- hidden equivalence、observer boundary；
- frontend scene、level select、settings、start routing；
- formal LAN integration、security、public-state fail-closed、full-stack；
- tutorial all flows、rule boundary、progress、layout、pause、navigation、completion/failure、input guard、match interaction、overlay action、fixed effect、hint、T0/T1、restart、routing、first action、chapter、terminal 与其他现有教学合同；
- level gameplay HUD、online match HUD、system dialog、terracotta theme。

### 3.2 最终候选定向复验

`05ada98` 共重跑 12 项，12/12 通过：

- tutorial board visual：连续 2/2；
- board hover authority coordinate：连续 2/2；
- turn camera visibility：连续 5/5；
- board camera layer、board layout、tutorial navigation：各 1 次。

完整结果：`evidence/gate2/v3-candidate-05ada98/logs/targeted-camera-regression-summary.json`。

### 3.3 Match HUD v3 真实 GPU 复核

原 runner 在 headless dummy renderer 中完成所有布局/资产断言后，仅因无法取得截图纹理失败。QA 将同一 runner 复制到证据目录，只改变截图输出路径，并以真实 Windows/OpenGL 执行：exit 0，`MATCH_HUD_V3_LAYOUT_LAB_PASS`，forbidden 0。1280×720 下三列、棋盘、底部行动区、中文和状态均在视口内，无裁切或重叠。

证据：`logs/match-hud-v3-gpu-contract.stdout.log`、`screenshots/match-hud-lab-current-candidate.png`。

综合计算：当前候选 48/48 必要合同通过。

## 4. 规则、PlayerView 与回放等价

当前候选运行 `run_gate1_formal_equivalence.gd --seeds 1 --replay-samples 1`：

- exit 0，25.254 秒；
- `FORMAL_EQUIVALENCE_PASS completed=1`；
- 9 个公开通道；
- 104 个 VisibleError 检查；
- 1 份权威回放校验；
- 200 帧 ObserverReplay 检查；
- forbidden 0。

追加 3-seed 在 240 秒硬上限内无错误、无失败 marker，但未完成并被 QA 终止，不能计为通过；当前 20-seed 仍只有历史 golden，未冒充本候选实跑。结合当前 hidden equivalence、observer boundary、LAN security/full-stack 和 architecture/dependency，代表性回归满足冻结口径，但 `CHECK-REGRESSION-001` 保留 `pass_with_limitation`。

## 5. 真实 GPU 样片与人工观察

正式对局在 Windows/OpenGL 3.3 Compatibility、Intel Iris Xe 上采集六张图：

- 960×540：赤方、玄方；
- 1280×720：赤方、玄方；
- 1920×1080：赤方、玄方。

附加样片包括：关卡选择、正式联机 HUD、T0、T3、教学暂停、关卡 HUD、Match HUD v3。逐图检查未发现阻断性裁切、区域重叠、中文异常换行或阵营状态错误。960×540 的辅助信息密度较高，但棋盘、行动按钮、迷雾、阵营和关键状态仍可读。

全部图像位于 `evidence/gate2/v3-candidate-05ada98/screenshots/`。这些图最初在产品提交 `0a8ab17` 采集；`05ada98` 与其零产品差异，因此作为最终候选的产品等价证据保留。Match HUD v3 另在 `05ada98` 当前提交真实 GPU 重拍。

## 6. 性能与资产内存

验收机沿用 RC4 同一宿主：Intel Core i5-1340P、Intel Iris Xe（驱动 31.0.101.4146）、约 16 GB RAM。VSync 关闭，每档预热 5 秒、采样至少 30 秒：

| 配置 | 平均 FPS | p99 帧时 | 1% low 等价 | 最大帧时 | 核心布局 |
|---|---:|---:|---:|---:|---|
| 1280×720 默认运动 | 105.140 | 14.255 ms | 70.151 FPS | 22.363 ms | readable |
| 960×540 reduced motion | 162.597 | 9.472 ms | 105.574 FPS | 70.581 ms | readable |

两档均满足当前可读性和 60 FPS 目标；项目仍没有独立质量档位开关。

资产保守估算：262 张 PNG 中，19 张 `source_chroma` 因 `.gdignore` 不进入资源导入；其余 243 张是 `all_resources` 导出候选。全部候选按 RGBA8 为 880.294 MiB，完整 mip 链最坏约 1,173.726 MiB。13 张本轮实际接入 UI 纹理按 RGBA8+mips 约 55.784 MiB；18 张教学漫画源图约 107.992 MiB RGBA；21 张概念图约 126.035 MiB RGBA。3 个 TTF 原始文件合计 51.670 MiB，字体 atlas 的动态 GPU 占用未计。

上述 1.17 GiB 是“所有可导出源图同时 RGBA+mips”的保守上限，不是实测同时驻留 VRAM。它揭示的是 `all_resources` 把概念图、漫画源图和未用资源一并纳入包体的风险。

证据：`performance-*.json`、`asset-memory-estimate.json`。

## 7. Windows embedded-PCK 成品包

- preset：`Windows Desktop Formal LAN`；
- 文件：`builds/windows/Veilfront_Xiangqi_Siege_Gate2_v3_05ada98.exe`；
- 大小：363,175,248 bytes；
- SHA-256：`0841A22BA8701C30546DA7B6F66A25A74E204733B7A404A4B966D4B4DEB012E0`；
- 相较 RC4 增长 76,652,200 bytes（73.101 MiB，26.75%）；
- 导出 exit 0、`[ DONE ] savepack`、forbidden 0；
- 直接运行 EXE 的 headless 启动检查 exit 0、forbidden 0；
- `verify_windows_lan_export.ps1` 对 embedded PCK 执行，exit 0；
- marker：`FORMAL_LAN_FULL_STACK_LOOPBACK_PASS ux=ready-start-match-submit-disconnect`；
- marker：`WINDOWS_LAN_EXPORT_VERIFY_PASS`。

## 8. Contract v3 十项矩阵

| Check | 判定 | 当前候选证据 |
|---|---|---|
| CHECK-CONTRACT-V3-001 | pass | HEAD/origin、Contract approval、project/Registry validator 与候选身份匹配；旧人工请求已标记 stale。 |
| CHECK-DEPENDENCY-001 | pass | architecture/dependency 当前产品基线通过；最终提交只改变测试等待，没有反向依赖。 |
| CHECK-INFORMATION-2D-001 | pass | hidden equivalence、observer、fog、LAN security/public fail-closed/full-stack 全通过；无隐藏 FullState 读取证据。 |
| CHECK-GODOT-2D-001 | pass | Godot 4.7.1 场景、48 项合同、真实 GPU、性能、导出和 EXE 启动均无禁用错误。 |
| CHECK-COORDINATE-001 | pass | authority hover 2/2、turn camera 5/5、board camera/layout 与双方截图通过。 |
| CHECK-RESPONSIVE-2D-001 | pass | 六张三分辨率双方样片、tutorial layout 和多个 1280×720 当前 UI 样片通过。 |
| CHECK-PERFORMANCE-2D-001 | pass | 两档当前候选 30 秒实测均超过 60 FPS 且 core readable；资产估算与限制齐全。 |
| CHECK-ART-2D-001 | pass | 新 UI/字体/教学资产可导入，真实样片可审；字体附 OFL，未冒充小篆。 |
| CHECK-REGRESSION-001 | pass_with_limitation | 48/48 合同与当前 1-seed 等价通过；3-seed 超时，20-seed 仅历史 golden。 |
| CHECK-SCOPE-001 | pass_with_risk | 未引入 SFX、VFX、棋子动画、互联网 SDK、服务器、AI 或外包费用；UI 落在既有全 UI 例外方向。概念/漫画源图被 `all_resources` 打包是 GATE-3 瘦身风险。 |

## 9. 独立专业审查与下一合法动作

专业结论：`pass`。

- QA 没有修改产品代码、测试事实源、Contract、Registry 或 export preset；
- 两项失败通过有界等待修正测试时序，产品平滑镜头和断言均未削弱；
- PlayerView、迷雾、公开事件、回放和 LAN 边界具有当前可复现证据；
- UI、教学与联机场景达到 GATE-2 灰盒/正式二维基线所需的可读和可运行水平；
- 包体和 export-candidate 资源明显增长，但属于可在 GATE-3 通过资源过滤、压缩与质量档调优解决的残余风险，不要求推翻当前灰盒结构。

下一合法动作：项目经理必须基于 `05ada98`、本 QA 报告和新 EXE 生成新的 GATE-2 决策主题并请求项目所有者批准。任何旧候选摘要均不可复用；QA 不代替项目所有者批准进入 GATE-3。

推荐 canonical string：

`candidate=05ada9848c20c41b6d6cc92ce552df643c31438c|contract_digest=9d9e3cfc5e92d41d38eea336dbcca95040bb858706ffd8130a8b33a3594e7dd9|exe_sha256=0841A22BA8701C30546DA7B6F66A25A74E204733B7A404A4B966D4B4DEB012E0|qa_instance=inst:01M02NJ3JFHVZ5C4SP5MTJFJR6|technical_verdict=pass`

推荐摘要：`0a04ec17f07f6b55211475ac76d96462edb812caac4b8ff176d0f41f2934b895`

## 10. 进程与工作区收口

- QA 启动的 Godot、性能、导出、EXE 启动和 packaged verifier 进程均已退出；
- 仅保留 PID 13816、开始时间 2026-08-24 15:00:11 的既有 Godot 编辑器，未触碰；
- `evidence/art-previews/red_infantry_run_cycle_v1/` 属于其他工作，未纳入 QA 提交；
- 报告的机器可读摘要：`evidence/gate2/v3-candidate-05ada98/qa-evidence-summary.json`。
