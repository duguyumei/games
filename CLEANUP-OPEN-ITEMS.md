# 阶段 0 清理：待决项

日期：2026-08-07
清理前存档点：`63883d0`

以下 3 项无法从仓库内部证据判断，需要产品决策。每项附可复现验证命令。

## 1. `godot/docs/design-current/MIGRATION-MANIFEST.md`

24 行迁移核对表，记录旧文档行号到模块文件的映射。

`design-current/README.md:65` 写明「迁移核对完成前，原章节编号只用于审计」。

- **迁移核对已完成** → 删除本文件，同时删 `godot/docs/combo-duel-current.md` 迁移指针
- **未完成** → 保留，直到核对结束

```bash
cat godot/docs/design-current/MIGRATION-MANIFEST.md
sed -n '65p' godot/docs/design-current/README.md
```

## 2. `godot/assets/card_system/`（50M）

52 张四属性成品牌图、A 样张、概念稿、四属性 SVG 图标。

当前实现工程不引用它：`combo_duel_vslice/ui/qi_card_view.gd:187` 从
`res://assets/cards/` 加载，指向 vslice 自己的 23 文件 assets 目录，与本目录无关。

本目录是 `godot/tools/card_deck_generator/generate_deck.py` 的输出目标。

- **后续要接入 vslice 的美术资产** → 保留
- **已废弃的探索稿** → 移出仓库归档

```bash
sed -n '187p' combo_duel_vslice/ui/qi_card_view.gd
find combo_duel_vslice/assets -type f | wc -l          # 23
sed -n '11p' godot/tools/card_deck_generator/README.md
du -sh godot/assets/card_system
```

## 3. `godot/docs/combo-duel-current.md`

7 行迁移指针，正文已全部拆分到 `design-current/`。

本轮已把 3 处过时引用改为直接指向 `design-current/README.md`，所以它现在没有入站引用，
只是纯重定向。`design-current/README.md:56` 仍把它列为权威边界的一部分。

- 与第 1 项一起决定：迁移核对结束后连同 MANIFEST 一起删，并同步改 `README.md:56`

```bash
cat godot/docs/combo-duel-current.md
grep -rn 'combo-duel-current' --exclude-dir=.godot .
```

## 未列为清理项的说明

- `decompiled/`（118M）、`百晓策-原版导出`（symlink 到 CrossOver 游戏目录）：
  原版逆向参考素材，已 gitignore 或只是 symlink，零 tracked 引用。
  符合「原版仅参考」定位，留着不污染仓库。要清磁盘可另议。
