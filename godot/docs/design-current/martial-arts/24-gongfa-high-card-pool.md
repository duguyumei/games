# 高牌正式功法目录

> 本文件记录首批25门高牌正式内容。当前完整高牌池另包含11门蛊毒、成长与桥接功法，稳定ID与池归属见[扩展正式功法索引](./28-gongfa-expanded-formal-pool-index.md)；新增功法的详细正文分别由25、26、27号文档维护。

本文件记录当前正式高牌池的 25 门功法。它们全部绑定 `high_card`，普通装配次数上限为 1；独立资源位于 `combo_duel_vslice/data/techniques/high_*.tres`。公共牌型快照、同气、P₀/P、延迟与 AI 投影规则分别由[功法框架](./20-gongfa-framework.md)、[牌型与数值](../combat/10-hand-ranking-and-values.md)、[行动结算](../combat/12-action-resolution.md)和[AI](../ai/70-enemy-ai.md)定义。

## 数值与公共边界

- 高牌默认最高一张参与牌型数值；本组其他实际打出普通真气是额外真气。
- `P₀` 是连势前最终功法值，`P` 是连势后最终功法值；所有 `floor(P/2)` 与 `floor(P₀/2)` 均向下取整且可为 0。
- 同气按全部实际打出普通真气的可视属性交集判断，混元与临时属性正常参与。
- 形成前固定修正、随机目标、选择候选和延迟来源均在确认边界冻结；预览不推进正式随机源。
- `action_resolution_end` 表示一次同步或单方行动所有效果完成后的结果时点；镇山只读取该次行动的实际生命损失。

## 正式目录

**高牌池（25 门）**

- **探风式**
- **蕴林式**
- **引火式**
- **立山式**
- **散风**
- **聚林**
- **散火**
- **聚山**
- **惊风**
- **伏林**
- **燎火**
- **镇山**
- **风·引风**
- **林·培元**
- **火·附火**
- **山·蓄势**
- **风·换流**
- **林·凝气**
- **火·蓄势**
- **山·反震**
- **风·混流**
- **林·传功**
- **火·焚虚**
- **山·坚壁**
- **风·穿云**

下表是上述正式名单的唯一效果正文与实现元数据：

| ID | 名称 | 正文效果 | AI 标签 | 类别 |
|---|---|---|---|---|
| `high_wind_scout` | 探风式 | `floor(P/2)` 普通伤害；检视牌库顶 3 张，选择 1 张置顶，其余任意排序置底；风同气抽 1 张。 | damage, deck_control, draw, same_qi_payoff | B |
| `high_forest_nurture` | 蕴林式 | `floor(P/2)` 防御；按 P 上限随机回收弃牌，林同气优先带永久重塑牌。 | defense, recover, same_qi_payoff | B |
| `high_fire_kindling` | 引火式 | P 普通伤害；随机或火同气底向上燃尽非火牌；燃尽成功后按被燃尽牌基础值一半给手牌炽气。 | damage, anomaly_apply, same_qi_payoff | B |
| `high_mountain_stance` | 立山式 | P 防御；记录本回合自然防御实际损失，下一完整回合开始逐份返还。 | defense, delayed_defense | C |
| `high_wind_scatter` | 散风 | `floor(P/2)` 普通伤害；额外风牌数 N 点真伤；N>2 抽 2 张。 | damage, true_damage, draw, extra_card_commitment | A |
| `high_forest_gather` | 聚林 | `floor(P/2)` 防御；额外林牌获得重聚；林同气时牌库重聚牌获得 1 成长。 | defense, anomaly_apply, same_qi_payoff, extra_card_commitment | B |
| `high_fire_scatter` | 散火 | P 普通伤害；额外火牌 N 点真伤，火同气改为 2N。 | damage, true_damage, same_qi_payoff | A |
| `high_mountain_gather` | 聚山 | P 防御；额外山牌每张 +2N 防御，山同气改为 +3N。 | defense, same_qi_payoff, extra_card_commitment | A |
| `high_wind_startle` | 惊风 | `floor(P/2)` 普通伤害；敌方随机明确弃 1 张合法手牌。 | damage, discard, enemy_disruption | A |
| `high_forest_ambush` | 伏林 | `floor(P/2)` 防御；敌方牌库随机普通真气获得毒。 | defense, anomaly_apply, enemy_disruption | A |
| `high_fire_scorch` | 燎火 | P 普通伤害；实际造成生命损失时，敌方牌库顶合法牌获得 1 封禁。 | damage, anomaly_apply, enemy_disruption | B |
| `high_mountain_suppress` | 镇山 | P 防御；本次行动完成且敌方未使我方损失生命时，敌方手牌随机合法牌获得破绽。 | defense, anomaly_apply, enemy_disruption | C |
| `high_wind_lure` | 风·引风 | `floor(P/2)` 普通伤害；牌库随机至多 3 张不能视为风且可获得风引的牌获得风引。 | damage, anomaly_apply, deck_control | A |
| `high_forest_cultivate` | 林·培元 | `floor(P/2)` 防御；选择手牌 1 张获得 1 成长。 | defense, anomaly_apply | A |
| `high_fire_ignite` | 火·附火 | P 普通伤害；我方弃牌堆随机火牌燃尽；实际成功后敌方牌库随机合法牌燃尽。 | damage, anomaly_apply, enemy_disruption | B |
| `high_mountain_momentum` | 山·蓄势 | P 防御；获得 `floor(P₀/2)` 连势。 | defense, momentum | A |
| `high_wind_exchange` | 风·换流 | `floor(P/2)` 普通伤害；抽 2 张，再弃掉至多 2 张可明确弃掉的手牌。 | damage, draw, discard, extra_card_commitment | A |
| `high_forest_condense` | 林·凝气 | `floor(P/2)` 防御；生成与计值真气基础属性相同的随机牌阶临时普通真气。 | defense, temporary_card | B |
| `high_fire_momentum` | 火·蓄势 | P 普通伤害；获得 `floor(P₀/2)` 连势。 | damage, momentum | A |
| `high_mountain_reflection` | 山·反震 | P 防御；反震设为 50%，持续至本完整回合结束，来源覆盖安全到期。 | defense, reflection | C |
| `high_wind_mixed_flow` | 风·混流 | 形成前从额外真气随机选择至少具一种非风身份者，以当前有效值增加直接固定修正；目标成功且风同气时夺敌方牌库普通牌；造成 `floor(P/2)` 普通伤害。 | damage, same_qi_payoff, enemy_disruption, extra_card_commitment, retrigger_sensitive | B |
| `high_forest_transmission` | 林·传功 | `floor(P/2)` 防御；最靠左的当前有效值高于基础值的手牌获得 1 成长。 | defense, anomaly_apply | A |
| `high_fire_burn_void` | 火·焚虚 | P 普通伤害；按稳定顺序逐张移除虚无，成功各得 1 历练，得历练后燃尽；失败不阻塞后续牌。 | damage, anomaly_apply, economic_gain, retrigger_sensitive | B |
| `high_mountain_rampart` | 山·坚壁 | P 防御；从本次实际成功触发自身打出时效果的真气中随机 1 张获得重聚。 | defense, anomaly_apply, retrigger_sensitive | B |
| `high_wind_piercing_cloud` | 风·穿云 | 令 S 为全部打出普通真气冻结基础值总和；P₀>S 时仅造成 `floor(P/2)` 真伤，否则仅造成同值普通伤害。 | damage, true_damage, retrigger_sensitive | A |

## 实现分类

- A：由既有即时伤害／防御、牌区、层数和条件组合完成。
- B：使用新增公共快照、捕获集合、目标查询、条件伤害、临时牌或成功结果 Handler。
- C：使用公共战斗时点或来源安全的延迟记录。

以上 25 门均已进入高牌正式候选池；未实现或未验证的其他功法不在本目录。
