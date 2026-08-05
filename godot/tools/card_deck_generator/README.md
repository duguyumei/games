# 分层扑克牌预览生成器

使用四张 SVG 花色图标生成风、林、火、山各 13 张低分辨率 PNG，以及 4×13 联系表。纸张、属性水墨纹样、背景母图、角标和牌面内容按图层合成；替换背景母图时不会擦除或修补任何旧像素，因此背景母图应只包含无角标的纹样。

```bash
/Users/cc/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 \
  godot/tools/card_deck_generator/generate_deck.py \
  --output /tmp/taiwu-deck-preview
```

默认读取 `godot/assets/card_system/icons/{wind,forest,fire,mountain}.svg`。也可用 `--wind-icon` 等参数传入四张 SVG；用 `--wind-background`、`--forest-background`、`--fire-background`、`--mountain-background` 分别替换四张完整背景母图。生成结果只写入 `--output`。

依赖 Python 3 和 Pillow。SVG 渲染优先使用 CairoSVG，其次使用 `rsvg-convert`；两者均不可用时使用内置的单色 SVG 路径栅格器。
