# 蛊毒、成长与桥接正式功法索引

> 状态：当前正式功法目录索引。详细效果正文分别由[蛊毒功法](./25-gongfa-poison-candidate-pool.md)、[成长功法](./26-gongfa-growth-candidate-pool.md)与[桥接功法](./27-gongfa-bridge-candidate-pool.md)唯一维护；本文件只记录正式池归属、稳定 ID 与数量，不复制效果正文。

## **高牌池（11 门）**

- **林·含毒**（`high_forest_contain_poison`）
- **林·埋蛊**（`high_forest_bury_poison`）
- **林·蜕壳**（`high_forest_shed_shell`）
- **林·催蛊**（`high_forest_trigger_poison`）
- **林·移栽**（`high_forest_transplant`）
- **林·落英分润**（`high_forest_fallen_bloom_share`）
- **林·木秀**（`high_forest_tall_tree`）
- **林·折枝**（`high_forest_break_branch`）
- **林·枯木逢春**（`high_forest_deadwood_spring`）
- **林·饮蛊催生**（`high_forest_drink_poison_growth`）
- **火·焚蛊催势**（`high_fire_burn_poison_momentum`）

## **对子池（18 门）**

- **林·双藏**（`pair_forest_double_cache`）
- **林·移花接蛊**（`pair_forest_transfer_poison`）
- **林·蛰蛊藏息**（`pair_forest_hide_poison`）
- **林·养蛊**（`pair_forest_raise_poison`）
- **林·群蛊护脉**（`pair_forest_swarm_guard`）
- **林·抱毒守元**（`pair_forest_embrace_poison`）
- **林·饮鸩攻心**（`pair_forest_poison_heart`）
- **林·催芽**（`pair_forest_sprout`）
- **林·分枝**（`pair_forest_branch`）
- **林·并生**（`pair_forest_co_growth`）
- **林·根深**（`pair_forest_deep_root`）
- **林·采实**（`pair_forest_harvest`）
- **林·藏荫**（`pair_forest_store_shade`）
- **林·扦插**（`pair_forest_cutting`）
- **林·毒木共荣**（`pair_forest_poison_growth`）
- **风·弃蛊逐敌**（`pair_wind_discard_poison`）
- **火·采薪成势**（`pair_fire_heat_to_momentum`）
- **山·护根留青**（`pair_mountain_guard_root`）

## **三条池（10 门）**

- **林·回蛊养根**（`three_forest_recover_poison_root`）
- **林·蛊壳**（`three_forest_poison_shell`）
- **林·百蛊侵脉**（`three_forest_hundred_poison`）
- **林·刮骨渡毒**（`three_forest_bone_poison`）
- **林·春雨**（`three_forest_spring_rain`）
- **林·接木**（`three_forest_graft`）
- **林·落叶归根**（`three_forest_fallen_leaf_return`）
- **风·春风满袖**（`three_wind_spring_hand`）
- **火·蛊焰追身**（`three_fire_poison_pursuit`）
- **林·连枝并式**（`three_forest_high_card_cooperate`）

## **顺子池（7 门）**

- **林·潜根**（`straight_forest_hidden_root`）
- **林·残蛊化甲**（`straight_forest_poison_armor`）
- **林·毒行千里**（`straight_forest_poison_march`）
- **林·五叶归蛊**（`straight_forest_five_leaf_poison`）
- **林·百木争荣**（`straight_forest_many_tree_glory`）
- **林·宿根**（`straight_forest_dormant_root`）
- **风·涸泽搜蛊**（`straight_wind_drain_poison_deck`）

## **炸弹池（6 门）**

- **林·洗脉藏蛊**（`bomb_forest_cleanse_poison`）
- **林·万蛊同寂**（`bomb_forest_all_poison`）
- **林·腐甲生蛊**（`bomb_forest_defense_poison`）
- **林·万木萌发**（`bomb_forest_all_sprout`）
- **林·万木归一**（`bomb_forest_all_wood_unite`）
- **林·四时轮转**（`bomb_forest_four_seasons`）

## 接入边界

- 52 门全部为独立 `TechniqueDefinition` 资源、`formal_complete`、普通装配上限 1。
- 池资格固定为：高牌只读 `high_card`；对子读 `pair`、`two_pair`、`full_house`；三条读 `three_kind`、`full_house`；顺子只读 `straight`；炸弹读 `four_kind`、`five_kind`。
- `production_sequences.json` 不因本批正式化改变；八种初始序列仍从内建散招开始。
- 毒伤、成长与炽气转移、牌区快照、延迟响应、协同限制和 AI 投影均通过通用接口实现，中央流程不识别本批功法 ID。
