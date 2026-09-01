# Windows 运行时资源与性能预算 v1

## 结论

Windows 正式局域网导出使用 `resources` 白名单，不再使用 `all_resources`。白名单只保留启动、设置、关卡选择、正式局域网、教程入口及 T0–T10 动态教学资源；HUD 布局 JSON 通过 `include_filter` 显式加入。

`concepts`、`source_chroma`、`source_rgb`、`chroma_sources`、测试场景/脚本、原型和证据目录均为硬排除项。战阵图鉴当前使用的 18 张 `diagram_v3/page_*.png` 是明确登记的运行时图片；旧 `comic_v1`、`comic_v2` 与其他未被运行时引用的源文件不得进入包。新增运行时根资源、动态 `load()` 路径或非 Resource 文件时，必须同步更新 `tools/release/windows_runtime_manifest.json` 和 `export_presets.cfg`。

## 预算

| 类别 | 上限 | 用途 |
| --- | ---: | --- |
| Windows embedded-PCK EXE | 320,000,000 bytes | GATE-3 合同硬上限 |
| 运行时包展开体积 | 160,000,000 bytes | 为并行 SFX/VFX 与后续内容预留空间 |
| 导入后运行时纹理 | 96,000,000 bytes | `.ctex` 合计 |
| 导入后运行时字体 | 48,000,000 bytes | `.fontdata` 合计，保留中文覆盖 |
| 平均帧率 | ≥ 60 FPS | Intel Iris Xe / Windows / GL Compatibility |
| P99 帧耗时 | ≤ 16.7 ms | 1280×720 默认动效与 960×540 减少动效 |

字体当前保留 Noto Sans SC、ramega 行书和教程引导使用的 Qyn 字体。现阶段不做字体子集化，以免破坏中文字符覆盖；只有字体预算接近上限时才启动字形清单与许可复核。

## 2026-08-24 基线

| 指标 | `all_resources` GATE-2 基线 | 白名单构建 | 变化 |
| --- | ---: | ---: | ---: |
| Windows EXE | 363,175,248 bytes | 192,972,760 bytes | -170,202,488 bytes（-46.86%） |
| EXE 预算余量 | 不满足 320 MB | 127,027,240 bytes | 满足 |
| ZIP 数据包 | 未建立 | 82,222,677 bytes | 399 个条目 |
| 数据包展开体积 | 未建立 | 83,854,998 bytes | 低于 160 MB |
| 导入后纹理 | 未建立 | 43,926,402 bytes | 低于 96 MB |
| 导入后字体 | 未建立 | 39,230,269 bytes | 低于 48 MB |
| 禁止路径命中 | 未验收 | 0 | 通过 |

以上数字来自本地 release embedded-PCK 构建；构建产物位于被 Git 忽略的 `builds/windows/`，正式 GATE-3 证据应由独立 QA 从冻结提交重建。

## 2026-08-27 当前内容候选

在不新增游戏内容的前提下，导出白名单补齐现有双轨教程目录、18 模块 Resource、教学抽屉、战阵图鉴、18 张图鉴运行时图片以及棋盘 Audio/VFX 预置根。当前生产者候选结果：

| 指标 | 当前候选 | 合同上限 | 结果 |
| --- | ---: | ---: | --- |
| Windows embedded-PCK EXE | 233,063,128 bytes | 320,000,000 bytes | 通过，余量 86,936,872 bytes |
| ZIP 数据包 | 121,741,569 bytes | — | 607 个条目 |
| 数据包展开体积 | 123,769,797 bytes | 160,000,000 bytes | 通过 |
| 导入后运行时纹理 | 79,470,640 bytes | 96,000,000 bytes | 通过 |
| 导入后运行时字体 | 39,230,269 bytes | 48,000,000 bytes | 通过 |

该结果已通过 120 帧成品启动冒烟，但仍属于生产者构建；独立 QA 必须从冻结提交重建后，才能形成 GATE-3 专业验收证据。

## 2026-09-01 准确性优先教程图候选

战阵图鉴将 18 张生成式 `comic_v2` 替换为确定性绘制的 `diagram_v3`。运行时图集从约 35 MB 的导入纹理下降到不足 1 MB 的源 PNG，且旧 v1/v2 图集均不再进入包。生产者候选结果：

| 指标 | v3 候选 | 合同上限 | 结果 |
| --- | ---: | ---: | --- |
| Windows embedded-PCK EXE | 197,898,280 bytes | 320,000,000 bytes | 通过，余量 122,101,720 bytes |
| ZIP 数据包 | 86,575,998 bytes | — | 607 个条目 |
| 数据包展开体积 | 88,604,919 bytes | 160,000,000 bytes | 通过 |
| 导入后运行时纹理 | 44,292,740 bytes | 96,000,000 bytes | 通过 |
| 导入后运行时字体 | 39,230,269 bytes | 48,000,000 bytes | 通过 |

包内容核对结果为 `diagram_v3/*.import = 18`、`comic_v2/*.import = 0`、`comic_v1/*.import = 0`。本结果仍是生产者构建，不能替代独立 QA 与 GATE-3 人工冻结。

## 可复现验证

```powershell
& tools/release/build_windows_runtime_candidate.ps1 `
  -GodotExecutable 'D:\Godot\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe'
```

构建脚本依次执行强制导入、交互性能合同、正式 LAN 全栈合同、ZIP manifest 导出、release embedded-PCK 导出、包内禁止项/必要项/分类预算验证，以及成品 120 帧启动冒烟。Godot 导出可能在返回码为 0 时仍打印资源错误，因此脚本同时把 `ERROR:` 和 `SCRIPT ERROR:` 视为失败。

交互性能由 `tests/game/performance/run_match_interaction_performance_contract.gd` 持续检查：选择操作只发布过滤后的行动预览；未变化迷雾命中缓存；小地图复用主棋盘遮罩；P99 上限为 16.7 ms。最终 GATE-3 仍需在指定 Iris Xe 实机上记录完整局平均 FPS 和 P99，headless 合同不能替代硬件验收。
