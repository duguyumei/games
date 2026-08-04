# 组合出招：第一阶段可玩纵切

这是一个全新的 Godot 4.7 工程，依据 `godot/docs/combo-duel-current.md` v0.23
（提交 `072c467`）实现。它不引用原 `godot/` 项目的场景、脚本或测试。

## 运行

在仓库根目录执行：

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --log-file /tmp/taiwu-combo-play.log \
  --path combo_duel_vslice
```

界面流程：

1. 重置战斗会按指定种子洗牌，载入 JSON 脚本化试炼对手，并让双方补至 8 张。
2. 敌方先按测试场景锁定背面出牌；点击 1～5 张手牌，预览精确牌型、参与真气、牌型基准值、功法值与循环功法。
3. 确认出招后双方同时揭示；先建立双方防御、标记与延迟记录，再缓冲并同步落地双方伤害，最后处理牌区变化。
4. 同属性行动会在每回合第一次满足时获得一次额外行动，但不会自动补牌；敌我额外行动次数分别记录。
5. 敌方生命归零时胜利；玩家生命归零或牌库与手牌均耗尽时失败。同一击双方倒下会停在“规则待确认”，不擅自判胜负。
6. 结束玩家回合可推进 `百击归烬` 等延迟记录；回合开始才正常补至手牌上限。

默认固定种子 `2308` 还提供一条三回合状态链：第一次高牌使用“一线悬蛊”建立蛊印，
第二次高牌使用“烈蛊飞针”为对手手牌中的山 3 附烈毒，第三回合对手打出山 3，
承受烈毒伤害并消耗 1 层蛊印，随后该牌续上烈毒并洗回对手牌库。

## 数据与核心边界

- `data/base_deck.json`：四属性、十三牌阶和真气值的唯一纵切数据入口。
- `data/techniques.json`：六个共用池映射与代表性功法效果描述。
- `data/vertical_slice_sequences.json`：仅供本纵切验证的调试装配，不是正式开局序列设计。
- `data/scripted_battle.json`：确定性敌方起手、逐回合锁定选牌与调试序列；只用于同步战斗测试，不是正式敌人 AI。
- `core/hand_evaluator.gd`：九种普通牌型与参与数值计算真气的选择。
- `core/effect_executor.gd`：通用效果操作解释器；支持伤害、防御、牌区、层数、延迟和随机单卡状态，不按功法名称硬编码。
- `core/trigger_queue.gd`：同一时点按顺序逐项结算并保存可见历史。
- `core/combat_engine.gd`：敌我独立序列、同步伤害缓冲、牌区、连击、延迟快照与战斗结果。
- `core/scripted_battle_scenario.gd`：加载脚本化敌方测试场景并整理确定性敌方牌库。

## 测试

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless \
  --log-file /tmp/taiwu-combo-tests.log \
  --path combo_duel_vslice \
  --script res://tests/test_runner.gd
```

测试覆盖基础 52 张牌、九种牌型、A 的两种顺子、J/Q/K 牌阶区别、参与牌选择、
基础值与功法值公式、序列成功/失败推进、代表性功法、延迟 P 快照、可见队列顺序、
脚本敌方锁定、同步防御/伤害、敌我独立序列、胜负、未决同归于尽，以及
烈蛊飞针附毒、烈毒触发、蛊印消耗、续毒和洗回牌库的完整确定性状态链。
