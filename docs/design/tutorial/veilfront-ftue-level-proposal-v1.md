# 《雾疆：九路烽棋》新手关卡：雾门初阵

## Game Identity / Mantra
用 一场 可失败、可重试、无剧透 的 15 分钟 固定战局，让 玩家 从 会落子 走到 能独立 完成 一次 夺旗。

## Design Pillars
- 先行动后解释
- 失败可恢复
- 只教可见信息

## Genre / Story / Mechanics Summary
单个 预置场景，分为 五个 checkpoint。玩家 依次掌握 点线落子、迷雾记忆、城墙与缓冲区、车相交互、占旗与士献祭，最后完成 三到五回合 的缩短实战。全部动作 通过 正式 Intent、DomainEvent 与 PlayerView，不直接改写 FullState。

## Features
- 章节一：选择、移动、取消、右键标注 与 回合确认
- 章节二：穿透迷雾发现旗帜，并理解发现后的永久地图记忆
- 章节三：先破墙、再进缓冲区、最后攻击大本营
- 章节四：蓝色车路径、黄色相田九点、隐藏接触与停止点
- 章节五：完成一面旗帜占领，并在明确确认后使用士献祭复活
- 终局：有限棋子和固定敌方脚本下独立完成一次夺旗

## Interface
PC 键鼠。左键 选择与行动；选中时 右键先取消，未选中时 打开圆、叉、方形标注；Esc 取消；确认面板提交。蓝色只表示车路径，黄色只表示相田九点。

## Art Style
90度俯视，东方战争奇幻。棋子落在 正方点线交点；区域只用 明亮色块 和 半透明区名；黑色蒙版 表达迷雾；箭头与短标签 不遮棋盘。

## Music / Sound
低密度战鼓 与 风沙底噪。选择、未知接触、破墙、发现旗帜、占领和章节完成 使用不同短音；失败音保持克制。

## Development Roadmap / Launch Criteria
- Platform: PC / Steam Demo；键鼠优先；三档目标分辨率
- Audience: 懂象棋基础、首次接触 本作迷雾与夺旗 的玩家；也兼容 新策略玩家。
- Milestone 1: 冻结五章 Scenario、允许 Intent、提示与 checkpoint
- Milestone 2: 接入正式 application / projection，无第二套规则
- Milestone 3: 完成灰盒 与 三分辨率可读性测试
- Milestone 4: 替换首批 棋盘、棋子、旗帜、城墙、迷雾 与反馈音
- Milestone 5: 通过 12-18 分钟首通、重置、跳过、退出 与无作弊验收
- Launch Day: Iteration 3 评审通过后纳入首版 Demo
