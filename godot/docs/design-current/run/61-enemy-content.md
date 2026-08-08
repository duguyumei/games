# 正式敌人内容（S2 第 1 层）

> 本文件是当前 v0.30 模块化权威设计源的一部分。
> 敌人运行数据位于 `combo_duel_vslice/data/enemies.json`，但本文件拥有第 1 层正式精英与 Boss
> 的身份、构筑和 AI 覆盖规则；运行数据不得反向定义设计。

## 1. 内容范围与通用约束

本轮内部试玩确认第 1 层使用两名精英和三名 Boss。敌人牌组允许任意非空张数，不受 52 张完整
基础牌组数量限制；52 张仍是玩家标准初始构筑与战斗规则核的基线。敌人牌组只使用基础真气和
已确认的预置重塑语法，不预置战斗异状。

所有第 1 层精英使用 `150` 基础生命，所有第 1 层 Boss 使用 `200` 基础生命；生命值来自
[分层基础生命成长](./60-map-run-and-health.md#31-分层基础生命成长)，不在敌人内容条目中重复声明。

所有敌人：

- `acts` 为 `[1]`，`node_types` 分别为 `["elite"]` 或 `["boss"]`；
- `equipped_inner_skill_ids` 为空数组，`technique_slot_index` 为 `0`；
- 完整列出八种精确牌型的 `insight_multipliers`；
- 功法序列只允许 8 门正式语义完整功法：
  `balance_sleeves_listen_wind`、`double_gu_exchange_breath`、
  `three_ring_ensemble`、`three_ring_chaos_qi`、`seize_qi_return_nest`、
  `five_steps_echo`、`stagnant_gu_conceal_breath`、`borrow_fire_guard_heart`；
- 五条在未改造基础牌组中不可能自然形成，因此本轮所有敌人的 `five_kind` 序列为空。

Boss 必须覆盖至少六种可自然形成的精确牌型。本轮三个 Boss 均覆盖七种（除五条外）牌型。

## 2. 第 1 层精英

### 丹风逐影客 `act1_cinnabar_wind_hunter`

定位为风属性牌区压力与高牌启动。牌组 26 张：风 12、林 6、火 4、山 4。

```text
wind_2*2 wind_3*2 wind_4*2 wind_5*2 wind_6*2 wind_7 wind_8
forest_3*2 forest_5*2 forest_7*2
fire_4*2 fire_8*2
mountain_5*2 mountain_9*2
```

序列为：高牌 `[borrow_fire_guard_heart, stagnant_gu_conceal_breath]`；一对
`[double_gu_exchange_breath]`；两对 `[balance_sleeves_listen_wind]`；三条
`[three_ring_ensemble]`；顺子 `[five_steps_echo]`；葫芦为空；四条
`[seize_qi_return_nest]`；五条为空。

心得倍率：高牌 1、一对 1、两对 1、三条 0、顺子 1、葫芦 0、四条 0、五条 0。
AI 覆盖：`damage_weight=1.15`、`sequence_progress_weight=1.2`、`overkill_penalty=0.5`。

### 山灯守关人 `act1_mountain_lantern_warden`

定位为山林结构、防御与葫芦路线。牌组 28 张：风 4、林 8、火 4、山 12。

```text
mountain_2*2 mountain_3*2 mountain_4*2 mountain_5*2 mountain_6*2 mountain_7*2
forest_2*2 forest_4*2 forest_6*2 forest_8*2
wind_5*2 wind_9*2 fire_3*2 fire_7*2
```

序列为：高牌 `[stagnant_gu_conceal_breath]`；一对 `[double_gu_exchange_breath]`；
两对 `[balance_sleeves_listen_wind]`；三条 `[three_ring_ensemble]`；顺子为空；
葫芦 `[three_ring_chaos_qi]`；四条 `[seize_qi_return_nest]`；五条为空。

心得倍率：高牌 0、一对 1、两对 1、三条 1、顺子 0、葫芦 1、四条 0、五条 0。
AI 覆盖：`defense_weight=0.95`、`retained_card_weight=0.35`、`danger_life_ratio=0.4`。

## 3. 第 1 层 Boss

### 裂风掌门 `act1_wind_sect_chief`

定位为风属性高频进攻与连击追续。牌组 40 张：风 18、林 10、火 6、山 6。

```text
wind_2*2 wind_3*2 wind_4*2 wind_5*2 wind_6*2 wind_7*2 wind_8*2 wind_9*2 wind_10*2
forest_2*2 forest_3*2 forest_4*2 forest_5*2 forest_6*2
fire_4*2 fire_6*2 fire_8*2 mountain_5*2 mountain_7*2 mountain_9*2
```

序列为：高牌 `[borrow_fire_guard_heart, stagnant_gu_conceal_breath]`；一对
`[double_gu_exchange_breath]`；两对 `[balance_sleeves_listen_wind]`；三条
`[three_ring_ensemble]`；顺子 `[five_steps_echo]`；葫芦 `[three_ring_chaos_qi]`；四条
`[seize_qi_return_nest]`；五条为空。
心得倍率为 `2/2/2/1/1/1/1/0`（按高牌、一对、两对、三条、顺子、葫芦、四条、五条）。
AI 覆盖：`damage_weight=1.25`、`combo_bonus=10.0`、`combo_follow_up_weight=0.45`、
`overkill_penalty=0.2`。

### 百蛊夫人 `act1_gu_matriarch`

定位为林属性牌区控制与防守。牌组 39 张：风 8、林 18、火 7、山 6。

```text
forest_2*2 forest_3*2 forest_4*2 forest_5*2 forest_6*2 forest_7*2 forest_8*2 forest_9*2 forest_10*2
wind_3*2 wind_5*2 wind_7*2 wind_9*2
mountain_4*2 mountain_6*2 mountain_8*2
fire_5*2 fire_7*2 fire_9*3
```

序列为：高牌 `[stagnant_gu_conceal_breath, borrow_fire_guard_heart]`；一对
`[double_gu_exchange_breath]`；两对 `[balance_sleeves_listen_wind]`；三条
`[three_ring_ensemble]`；顺子 `[five_steps_echo]`；葫芦 `[three_ring_chaos_qi]`；四条
`[seize_qi_return_nest]`；五条为空。
心得倍率为 `1/1/1/1/1/2/1/0`。AI 覆盖：`defense_weight=1.15`、
`danger_life_ratio=0.45`、`retained_card_weight=0.4`、`combo_without_follow_up_penalty=8.0`。

### 五岳魁首 `act1_five_mountain_lord`

定位为山火结构成型与功法序列推进。牌组 42 张：风 8、林 6、火 10、山 18。

```text
mountain_2*2 mountain_3*2 mountain_4*2 mountain_5*2 mountain_6*2 mountain_7*2 mountain_8*2 mountain_9*2 mountain_10*2
fire_2*2 fire_4*2 fire_6*2 fire_8*2 fire_10*2
wind_3*2 wind_6*2 wind_9*2 forest_4*2 forest_7*2 forest_10*2 wind_A*2
```

序列为：高牌 `[borrow_fire_guard_heart]`；一对 `[double_gu_exchange_breath]`；两对
`[balance_sleeves_listen_wind]`；三条 `[three_ring_ensemble]`；顺子 `[five_steps_echo]`；
葫芦 `[three_ring_chaos_qi]`；四条 `[seize_qi_return_nest]`；五条为空。
心得倍率为 `1/1/1/2/1/2/2/0`。AI 覆盖：`damage_weight=1.1`、`power_weight=0.08`、
`sequence_progress_weight=1.35`、`card_cost=0.35`。

## 4. Boss 候选与过渡占位

第 1 层 Boss 候选按 ID 排序后由 `content_seed` 选定起点，`boss_variant=0/1/2` 在候选数组上
执行循环偏移。因此相同 seed 与相同 variant 必须稳定，相同 seed 的三个 variant 必须得到三个
不同 Boss；variant 不绑定跨 seed 的固定姓名。

`transitional_elite_boss_placeholder` 仅覆盖第 2、3 层的 `elite` 与 `boss`，名称为
“第 2/3 层过渡占位精英首领”。第 1 层不得抽到该条目。
