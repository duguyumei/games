# 太吾组合出招

卡牌组合出招战斗系统的设计与实现仓库。

## 目录职责

| 路径 | 内容 |
|---|---|
| `godot/docs/design-current/` | 唯一权威设计源，入口是 [README.md](godot/docs/design-current/README.md) |
| `combo_duel_vslice/` | 当前 Godot 4.7 实现工程（可玩纵切） |
| `godot/assets/` | 卡牌美术资产与概念稿 |
| `godot/tools/` | 卡牌资产生成管线 |
| `scripts/` | 测试运行与运行器自检脚本 |

`godot/docs/combo-duel-current.md` 只是迁移指针，不是设计正文。

## 运行测试

```bash
./scripts/run_tests.sh quick   # 快速集
./scripts/run_tests.sh full    # 完整集
```

Godot 进程安全约束见 [AGENTS.md](AGENTS.md)。

## 待决清理项

见 [CLEANUP-OPEN-ITEMS.md](CLEANUP-OPEN-ITEMS.md)。
