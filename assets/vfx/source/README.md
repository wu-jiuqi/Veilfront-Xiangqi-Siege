# VFX 原创源图

本目录保存 GATE-3 VFX v1 的项目原创 SVG 粒子源图。三份图形均由本次制作以基础几何路径手工编写，没有引用外部图片、字体、纹样或生成式素材，也没有外部支出。

- `brush_spark_v1.svg`：金色四向火花，用于选中、吃子与炮击亮点。
- `ink_dust_v1.svg`：低对比墨尘，用于移动与城墙状态过渡。
- `seal_shard_v1.svg`：菱形符印碎片，用于旗帜、城墙与终局符号。

Godot 运行时直接导入 SVG 为 `Texture2D`；原始 SVG 与 `.tres/.tscn` 运行时参数分开维护。许可与分发范围见 `docs/vfx/vfx-asset-license-manifest-v1.yaml`。
