# 美术资产目录约定

本目录只存放可进入 Godot 导入管线的正式或样片资产。视觉基线和资产清单位于 `docs/art/`。

```text
assets/art/
├─ board/          # 棋盘、网格、区域纹理与贴花
├─ pieces/         # 棋子透明图、图集与公共阴影
├─ structures/     # 城墙、营寨、箭塔等GLB与纹理
├─ fog/            # 迷雾mask、噪声与Shader依赖
├─ flags/          # 旗帜现场表现与记忆图标
├─ ui/             # UI图标、九宫格纹理与字体授权文件
├─ effects/        # 粒子纹理、特效图集与材质
└─ audio/          # WAV/OGG运行时源文件
```

## 命名

- 小写蛇形：`red_pawn_idle.png`、`wall_black_collapsed.glb`。
- 阵营：`red / black / neutral / shared`。
- 状态：`idle / move / attack / hurt / death / special`。
- 版本不写入运行时文件名；版本历史交给 Git。

## 导入

- 3D纹理、Sprite3D立绘和粒子纹理开启 mipmap；大纹理使用 VRAM Compressed。
- UI纹理默认不生成 mipmap；矢量源保留在外部源文件库或明确的source子目录，不用导出物覆盖源文件。
- 模型优先 `.glb`；碰撞对象在源模型使用 `-col`/`-convcol` 后缀。
- 提交原始资产及其 `.import` 设置；不得提交 `.godot/imported/`。
- 所有第三方或生成式资产必须附来源、许可证、生成参数和人工修改记录，未明确授权的素材不得进入正式清单。
