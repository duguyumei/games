class_name BattleIntQueryCatalog
extends RefCounted

## 战斗整数查询 Hook 的唯一正式目录。
##
## 查询服务、被动 Handler Registry 与内容校验只能引用此目录，避免各自维护
## 名单后产生协议漂移。

const HOOKS := [
    "hand_limit_query",
    "power_base_fixed_query",
    "power_multiplier_bonus_query",
    "power_fixed_query",
    "power_amp_percent_query",
    "outgoing_damage_query",
    "incoming_damage_query",
    "poison_defense_intervention_query",
    "defense_gain_query",
    "defense_retention_percent_query",
    "defense_decay_max_loss_query",
    "defense_decay_minimum_remaining_query",
    "same_qi_capacity_query",
    "life_recovery_query",
    "effective_qi_query",
    "pre_life_loss_query",
]
