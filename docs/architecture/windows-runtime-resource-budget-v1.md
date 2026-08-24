# Windows 运行时资源与性能预算 v1

## 结论

Windows 正式局域网导出使用 `resources` 白名单，不再使用 `all_resources`。白名单只保留启动、设置、关卡选择、正式局域网、教程入口及 T0–T10 动态教学资源；HUD 布局 JSON 通过 `include_filter` 显式加入。

`concepts`、`source_chroma`、`source_rgb`、`chroma_sources`、非运行时漫画源图、测试场景/脚本、原型和证据目录均为硬排除项。新增运行时根资源、动态 `load()` 路径或非 Resource 文件时，必须同步更新 `tools/release/windows_runtime_manifest.json` 和 `export_presets.cfg`。

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

## 可复现验证

```powershell
& tools/release/build_windows_runtime_candidate.ps1 `
  -GodotExecutable 'D:\Godot\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe'
```

构建脚本依次执行强制导入、交互性能合同、正式 LAN 全栈合同、ZIP manifest 导出、release embedded-PCK 导出、包内禁止项/必要项/分类预算验证，以及成品 120 帧启动冒烟。Godot 导出可能在返回码为 0 时仍打印资源错误，因此脚本同时把 `ERROR:` 和 `SCRIPT ERROR:` 视为失败。

交互性能由 `tests/game/performance/run_match_interaction_performance_contract.gd` 持续检查：选择操作只发布过滤后的行动预览；未变化迷雾命中缓存；小地图复用主棋盘遮罩；P99 上限为 16.7 ms。最终 GATE-3 仍需在指定 Iris Xe 实机上记录完整局平均 FPS 和 P99，headless 合同不能替代硬件验收。
