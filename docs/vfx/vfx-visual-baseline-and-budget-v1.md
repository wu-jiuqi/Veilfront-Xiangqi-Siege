# GATE-3 二维 VFX 视觉候选与预算 v1

状态：`review_sample_ready / aesthetic_pending_project_owner / not_content_freeze`

## 方向

在已批准的 90° 俯视二维兵马俑战场上，VFX 使用“铜金军令 + 墨尘 + 阵营印色”的低遮挡语言：信息轮廓先于粒子密度，所有效果落在棋子和交互信息周围，不以颜色作为唯一语义通道。当前色值、半径和节奏是可审候选；项目所有者未在 GATE-3 人工闸门确认前，不把它们宣称为最终审美基线或大规模产能承诺。

七族视觉：选中双层定位环、移动墨尘行迹、吃子碎印冲击、炮击固定三重震环、城墙九路符印波、旗帜军印回响、终局天幕军印。项目原创 SVG 只承担粒子形状，主轮廓由预置 `VfxEffectSlot` 自绘；没有外部素材、字体、采购或生成式图像。

## 预置结构与运行入口

```text
VfxRoot (Node2D, vfx_director.gd)
├─ WorldPool (Node2D)
│  └─ World01..World09 (预置 VfxEffectSlot)
└─ GlobalCanvas (CanvasLayer)
   └─ GlobalAnchor (Control)
      └─ GlobalPool
         └─ Global01..Global03 (预置 VfxEffectSlot)
```

- PackedScene：`scenes/game/vfx/vfx_root.tscn`
- Catalog：`resources/game/vfx/vfx_catalog.tres`
- 运行 API：`ObserverVfxPolicy.derive_batch(previous_view,current_view,visible_events,motion_profile)` → `VfxDirector.play_batch(batch)`
- 本地选中：`ObserverVfxPolicy.derive_local_selection_batch(...)` → 同一 `play_batch`
- 镜像：主棋盘切换表现方时调用 `VfxDirector.set_display_side(side)`；只改变公开位置映射。

正式共享场景建议把 `VfxRoot` 预置为 `BoardWorld` 的独立表现子场景，`WorldPool` 位于棋子/旗帜之上、输入层之下；`GlobalCanvas` 保持非交互。现阶段不修改共享 `board_world.tscn`，待项目经理接受 Cue foundation、Registry 合法进入下一迭代后，由技术负责人统一接线，避免与并行 SFX/UI 修改冲突。

## 过绘与并发预算

预算点是稳定的相对上限，不冒充 GPU 像素计数；独立 QA 仍需在 Intel Iris Xe / GL Compatibility 以高峰样片复核 `平均≥60 FPS、P99≤16.7ms`。

| 家族 | 标准点 | 减少动态点 | 标准粒子 | 降级粒子 | 并发上限 |
|---|---:|---:|---:|---:|---:|
| selection | 6 | 2 | 4 | 0 | 1 |
| move | 7 | 2 | 8 | 0 | 3 |
| capture | 12 | 4 | 14 | 2 | 3 |
| bombardment | 22 | 8 | 18 | 3 | 1 |
| wall | 18 | 6 | 12 | 2 | 2 |
| flag | 12 | 4 | 10 | 2 | 2 |
| terminal | 18 | 8 | 6 | 0 | 1 |

- 标准档同时活动总预算：100 points；减少动态：56 points。
- 预置池：9 个棋盘槽 + 3 个 global 槽；运行时不实例化粒子节点。
- 低/普通优先级先丢弃；高/关键 cue 只能替换更低优先槽，不能越过总预算。
- 不使用粒子 trails、屏幕空间模糊、后处理闪白、相机抖动或规则 RNG。

## 闪烁与遮挡

- 单一定义 `flash_hz_max≤3.0Hz`；当前最高炮击为 2.0Hz，实际样片是单次连续亮度包络，不循环闪烁。
- 全屏效果只允许终局，峰值面积记录为 18%，透明度低于 0.18；禁止全屏白闪。
- 其他单效果声明面积不高于 8%；炮击三环固定，不按命中数叠层。
- 粒子寿命不超过效果时长且不留下 trails；棋盘交点、棋子轮廓和确认反馈在峰值帧仍应可辨。

## reduced-motion

`motion_profile=reduced` 时：

- 不旋转、不扩张扫屏、不产生相机运动；
- selection/move/terminal 粒子为 0，其余最多 3；
- 效果缩短至 `0.18–0.42s`，只保留静态符号与单次淡出；
- 公开 Cue key、cue_id、顺序和位置不变，只改变本地表现参数；
- 不影响声音设置，不用“减少动态”静音 SFX。

## 可审样片

- 场景：`scenes/game/vfx/vfx_review_lab.tscn`
- 截图：`evidence/gate3/vfx/vfx-review-1280x720.png`
- 审查场景启用只对该场景生效的 `review_hold`，把七族固定在 38% 动画相位，保证截图可重复；正式 `vfx_root.tscn` 默认关闭。
- 样片同时展示七族和预算护栏；它用于审美与可读性判断，不等同正式主棋盘已完成接线，也不能替代独立 QA。
