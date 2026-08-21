# 燃香回合进度条

本目录保存项目所有者确认的第 3 张燃香方案及其运行时分层资源。

## 图层

- `turn_progress_incense_preview_v1.png`：确认用组合样片，示例烟雾数字为 `12`，不直接承担动态回合显示。
- `turn_progress_holder_v1.png`：固定香座底层。
- `turn_progress_incense_body_v1.png`：满长度香身；通过右侧裁切表现从右向左燃烧。
- `turn_progress_ember_v1.png`：燃烧端，跟随香身剩余长度向左移动。
- `turn_progress_smoke_wisp_v1.png`：无固定数字的烟雾连接层。
- `turn_progress_smoke_sequence_8f_v1.png`：4×2、共 8 帧的透明烟雾序列帧，运行时循环播放。
- `smoke_digit_transition.gdshader`：中文回合数字的烟化散开与重新聚拢材质。

## 运行时合同

- 正式组件为 `res://scenes/game/ui/turn_progress_incense.tscn`，测试页为 `res://scenes/dev/ui/turn_progress_incense_lab.tscn`。
- 50 回合合同：第 `n` 回合进度为 `n / 50`，剩余香身比例为 `1.0 - n / 50`；第 50 回合完全烧完。
- 香身固定左端，只裁切右端，燃烧端位于剩余香身的右端。
- 烟雾从燃烧端向右漂移，并随着香身缩短而横向延长到固定的数字锚点。
- 实际回合数使用中文数字一至五十；常态有轻微漂浮，换回合时先由 Shader 散开，替换文字，再重新聚拢。
- 样片中固定的 `12` 只作为构图参考，运行时绝不使用烘焙数字。
- 建议设计区域为 `952×72`，来自项目所有者导出的 `1280×720` 布局。

## 来源与处理

- 生成模式：内置图像生成工具，以确认样片为编辑母版逐层隔离。
- 视觉基线：锻铁、深绿氧化青铜、少量旧金、红褐香身、橙红余烬和暖灰烟雾。
- 伪透明输出通过项目既有棋盘格移除流程转换为 RGBA；原始 RGB 文件保存在 `source_rgb/`。
