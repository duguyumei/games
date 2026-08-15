class_name ContentValidator
extends RefCounted

## 静态内容定义校验。
##
## 负责内容文件的整体形状：顶层对象、版本、必填字段、ID 唯一性、容量上限、
## 跨内容引用。效果规格本身的校验已拆到 EffectSpecValidator，因为操作码随功法内容
## 持续增长，而这里的形状规则基本稳定。

const EffectSpecValidatorScript = preload("res://core/effect_spec_validator.gd")
const EffectHandlerRegistryScript = preload(
    "res://core/effects/effect_handler_registry.gd")
const RunEffectHandlerRegistryScript = preload(
    "res://core/run_effects/run_effect_handler_registry.gd")
const StatusBehaviorRegistryScript = preload(
    "res://core/statuses/status_behavior_registry.gd")
const CardReshapeBehaviorRegistryScript = preload(
    "res://core/card_reshapes/card_reshape_behavior_registry.gd")
const ConsumableEffectHandlerRegistryScript = preload(
    "res://core/consumables/consumable_effect_handler_registry.gd")
const ConsumableValidationContextScript = preload(
    "res://core/consumables/consumable_validation_context.gd")
const ConsumableTargetingProtocolScript = preload(
    "res://core/consumables/consumable_targeting_protocol.gd")
const NodeInteractionHandlerRegistryScript = preload(
    "res://core/node_interactions/node_interaction_handler_registry.gd")
const PassiveRuleHandlerRegistryScript = preload(
    "res://core/passives/passive_rule_handler_registry.gd")
const EnemyDeckEncodingScript = preload("res://core/enemy_deck_encoding.gd")

const CONTENT_KEYS := [
    "base_deck",
    "starter_builds",
    "battle_statuses",
    "card_states",
    "techniques",
    "inner_skills",
    "consumables",
    "items",
    "practice_shop",
    "node_rewards",
    "act_progression",
    "enemies",
    "map_rules",
    "node_content",
    "scripted_battle",
    "sequences",
]
const HAND_IDS := [
    "high_card", "pair", "two_pair", "three_kind", "straight",
    "full_house", "four_kind", "five_kind",
]
const TECHNIQUE_BRANCH_HAND_IDS := HAND_IDS
const POOL_IDS := [
    "high", "pair", "three", "straight", "bomb", "universal",
]
const EXPECTED_POOL_MEMBERSHIP := {
    "high_card": ["high"],
    "pair": ["pair"],
    "two_pair": ["pair"],
    "three_kind": ["three"],
    "straight": ["straight"],
    "full_house": ["pair", "three"],
    "four_kind": ["bomb"],
    "five_kind": ["bomb"],
}
const RETIRED_TECHNIQUE_IDS := [
    "all_sounds_listen_wind", "balance_sleeves_listen_wind",
    "borrow_fire_guard_heart", "discard_fuel_open_furnace",
    "discard_gu_exchange_breath", "double_gu_bind",
    "double_gu_exchange_breath", "double_wind_continue_form",
    "enemy_discard_returns_nest", "exchange_nest_into_enemy",
    "exchange_sea_intake_qi", "fire_sparks", "five_steps_echo",
    "five_yang_chase", "four_poles_control_top", "four_symbols_harmony",
    "full_sleeve_bind_enemy", "full_sleeve_wind", "gather_wind_faces",
    "layered_leaves_return_tide", "lethal_gu_needle",
    "listen_wind_stack_top", "long_wind_full_sleeve",
    "measure_breath_twins", "poison_nest_seek_meridian",
    "poison_wind_seek_meridian", "returning_loop_long_breath",
    "returning_wind_continue_form", "seize_qi_return_nest",
    "snake_path_order_meridian", "stagnant_gu_conceal_breath",
    "suspended_gu", "sweeping_wind_sleeve", "three_breath_turbulence",
    "three_cards_listen_tide", "three_corpses_gu", "three_ring_breathing",
    "three_ring_chaos_qi", "three_ring_ensemble",
    "triple_layer_return_armor", "twin_leaves_build_momentum",
    "twin_swallows_press_sleeve", "twin_wind_exchange", "wind_born_echo",
    "wind_deck_return_tide", "wind_path_control_top", "wind_transforms_force",
]
const TECHNIQUE_INTEGRATION_STATUSES := [
    "formal_complete", "partial_integration", "regression_fixture",
]
const FORMAL_TECHNIQUE_STATUS := "formal_complete"
const PRODUCTION_SEQUENCES_PATH := "res://data/production_sequences.json"
const ATTRIBUTE_IDS := ["wind", "forest", "fire", "mountain"]
const RESHAPE_CATEGORY_IDS := ["origin", "enhancement", "imprint", "other"]
const ANOMALY_CATEGORY_IDS := ["buff", "debuff", "state", "mark"]
const REQUIRED_ANOMALY_IDS := [
    "qi_heat", "growth", "qi_wither", "decay",
    "poison", "vulnerability", "acupoint_block", "forbidden",
    "wind_lure", "turbulence", "regroup", "burned_out",
    "purification", "return_to_origin", "void", "meridian",
]
const RETIRED_ANOMALY_IDS := [
    "lethal_poison", "stagnant_poison", "qi_dissipation",
    "wind_mark", "returning_wind", "qi_severance",
]
const REQUIRED_ORIGIN_IDS := ["attribute_change", "rank_change", "awakening"]
const REQUIRED_ENHANCEMENT_IDS := [
    "qi_boost", "momentum", "hunyuan", "void_burst", "flawless",
    "rock_solid", "hidden_gold", "opportunity",
]
const REQUIRED_IMPRINT_IDS := ["echo", "enlightenment", "alchemy", "innate"]
const RETIRED_RESHAPE_IDS := [
    "bonus", "multiplier", "wild", "glass", "steel", "stone", "gold", "lucky",
    "foil", "holographic", "polychrome", "negative", "red", "blue", "purple",
]
const ANOMALY_ON_APPLY_POLICIES := ["", "purify_combat_state"]
const MARK_LIFECYCLE_EVENTS := [
    "draw", "enter_discard", "turn_end_final", "played_response_end",
    "explicit_discard_response_end", "real_hand_departure", "battle_end", "remove"]
const CARD_STATUS_TRIGGERS := [
    "play_attempt", "played", "draw", "explicit_discard", "enter_discard",
    "enter_discard_late", "turn_end", "turn_end_final",
]
const CARD_STATUS_MODIFIER_IDS := [
    "effective_qi_add_per_layer", "effective_qi_final_value",
    "outgoing_damage_percent",
    "incoming_damage_percent",
]
const RANK_SPECS := [
    ["2", 2, 2], ["3", 3, 3], ["4", 4, 4], ["5", 5, 5],
    ["6", 6, 6], ["7", 7, 7], ["8", 8, 8], ["9", 9, 9],
    ["10", 10, 10], ["J", 11, 11], ["Q", 12, 11], ["K", 13, 11],
    ["A", 14, 12],
]
const ROUTES := ["battle", "interaction", "placeholder"]
const REWARD_KINDS := [
    "experience", "card", "technique", "inner_skill",
    "consumable", "reshape", "special",
]
## `draft` 仅供内容管线生成的未发布骨架通过批量装配；正式运行池使用前三类。
const CONSUMABLE_KINDS := ["insight", "pill", "curio", "draft"]
const FORMAL_CONTENT_STATUS := "formal"
const ITEM_STATUSES := ["candidate", "design_only", "formal"]
const PRACTICE_OFFER_KINDS := ["technique", "inner_skill", "consumable"]
const PRACTICE_CONTENT_KINDS := ["pill", "insight", "curio"]
const ENEMY_AI_NUMBER_FIELDS := [
    "damage_weight",
    "defense_weight",
    "power_weight",
    "combo_bonus",
    "card_cost",
    "failed_condition_penalty",
    "danger_life_ratio",
    "overkill_penalty",
    "retained_card_weight",
    "sequence_progress_weight",
    "combo_follow_up_weight",
    "combo_without_follow_up_penalty",
    "candidate_limit",
    "diversity_penalty",
    "future_value_discount",
]
const ENEMY_AI_DIRECTIONS := [
    "assault", "survival", "prepare", "cycle", "develop", "control",
]
const FORBIDDEN_ENEMY_ENTRY_FIELDS := [
    "life", "max_life", "owned_technique_ids", "consumable_ids",
    "permanently_removed_card_ids", "player",
]

var errors: Array[String] = []
var warnings: Array[String] = []
var _contents: Dictionary = {}
var _paths: Dictionary = {}
var _card_ids: Dictionary = {}
var _origins_by_id: Dictionary = {}
var _enhancements_by_id: Dictionary = {}
var _imprints_by_id: Dictionary = {}
var _other_reshapes_by_id: Dictionary = {}
var _anomalies_by_id: Dictionary = {}
var _techniques_by_id: Dictionary = {}
var _inner_skills_by_id: Dictionary = {}
var _consumables_by_id: Dictionary = {}
var _items_by_id: Dictionary = {}
var _effect_specs: EffectSpecValidator
var _effect_registry
var _run_effect_registry
var _card_reshape_registry
var _consumable_effect_registry
var _node_interaction_registry
var _passive_rule_registry
var _status_behavior_ids: Array[String] = []

func _init(
        effect_registry_override = null,
        run_effect_registry_override = null,
        card_reshape_registry_override = null,
        consumable_effect_registry_override = null,
        node_interaction_registry_override = null,
        passive_rule_registry_override = null) -> void:
    _status_behavior_ids = StatusBehaviorRegistryScript.new().behavior_ids()
    _effect_registry = effect_registry_override
    if _effect_registry == null:
        _effect_registry = EffectHandlerRegistryScript.new(RandomNumberGenerator.new())
    _run_effect_registry = run_effect_registry_override
    if _run_effect_registry == null:
        _run_effect_registry = RunEffectHandlerRegistryScript.new()
    _card_reshape_registry = card_reshape_registry_override
    if _card_reshape_registry == null:
        _card_reshape_registry = CardReshapeBehaviorRegistryScript.new()
    _consumable_effect_registry = consumable_effect_registry_override
    if _consumable_effect_registry == null:
        _consumable_effect_registry = ConsumableEffectHandlerRegistryScript.new()
    _node_interaction_registry = node_interaction_registry_override
    if _node_interaction_registry == null:
        _node_interaction_registry = NodeInteractionHandlerRegistryScript.new()
    _passive_rule_registry = passive_rule_registry_override
    if _passive_rule_registry == null:
        _passive_rule_registry = PassiveRuleHandlerRegistryScript.new(
            true, _effect_registry)
    _effect_specs = EffectSpecValidatorScript.new(
        Callable(self, "_error"),
        {
            "attribute_ids": ATTRIBUTE_IDS,
            "anomaly_category_ids": ANOMALY_CATEGORY_IDS,
            "reshape_category_ids": RESHAPE_CATEGORY_IDS + [
                "temporary_enhancement", "temporary_attribute", "temporary_rank"],
            "hand_ids": TECHNIQUE_BRANCH_HAND_IDS,
        },
        _effect_registry)
    ## 异状索引在校验过程中增量建立（异状先于功法校验注册）。这里传入的是
    ## 同一份字典引用，因此后续只能 clear 和写入，不能整体重新赋值。
    _effect_specs.use_indexes(_anomalies_by_id)

func validate(contents: Dictionary, paths: Dictionary = {}) -> Dictionary:
    errors.clear()
    warnings.clear()
    for message in _effect_registry.validation_errors():
        _error("effects.registry", str(message))
    for message in _run_effect_registry.registration_errors():
        _error("run_effects.registry", str(message))
    for message in _card_reshape_registry.registration_errors():
        _error(
            "card_reshapes.registry.%s" % str(message.get("behavior_id", "")),
            str(message.get("message", "重塑行为注册失败")))
    for message in _consumable_effect_registry.registration_errors():
        _error("consumables.registry", str(message))
    for message in _node_interaction_registry.registration_errors():
        _error("node_interactions.registry", str(message))
    for message in _passive_rule_registry.registration_errors():
        _error(
            "passives.registry.%s" % str(message.get("behavior_id", "")),
            str(message.get("message", "被动行为注册失败")))
    _contents = contents
    _paths = paths
    _card_ids.clear()
    _origins_by_id.clear()
    _enhancements_by_id.clear()
    _imprints_by_id.clear()
    _other_reshapes_by_id.clear()
    _anomalies_by_id.clear()
    _techniques_by_id.clear()
    _inner_skills_by_id.clear()
    _consumables_by_id.clear()
    _items_by_id.clear()
    for key in CONTENT_KEYS:
        if not _contents.has(key) or not _contents[key] is Dictionary:
            _error(key, "缺少顶层对象")
            continue
        _validate_version(key, _contents[key])
    if not _has_all_content():
        return result()
    _validate_base_deck(_contents["base_deck"])
    _validate_starter_builds(_contents["starter_builds"])
    _validate_battle_statuses(_contents["battle_statuses"])
    _validate_card_states(_contents["card_states"])
    _validate_techniques(_contents["techniques"])
    _validate_inner_skills(_contents["inner_skills"])
    _validate_consumables(_contents["consumables"])
    _validate_items(_contents["items"])
    _validate_practice_shop(_contents["practice_shop"])
    _validate_node_rewards(_contents["node_rewards"])
    _validate_act_progression(_contents["act_progression"])
    _validate_enemies(_contents["enemies"])
    _validate_sequences(_contents["sequences"], "sequences")
    _validate_scripted_battle(_contents["scripted_battle"])
    _validate_node_content(_contents["node_content"])
    _validate_map_rules(_contents["map_rules"], _contents["node_content"])
    return result()

func _validate_node_rewards(definition: Dictionary) -> void:
    var declared_kinds = definition.get("reward_kinds")
    if not declared_kinds is Array:
        _error("node_rewards.reward_kinds", "必须是数组")
    else:
        for kind in REWARD_KINDS:
            if not declared_kinds.has(kind):
                _error("node_rewards.reward_kinds", "缺少奖励类型 %s" % kind)
    var rewards = definition.get("node_rewards")
    if not rewards is Dictionary:
        _error("node_rewards.node_rewards", "必须是对象")
        return
    for node_type in ["combat", "elite", "boss", "event", "rest", "treasure"]:
        if not rewards.has(node_type) or not rewards[node_type] is Array:
            _error("node_rewards.node_rewards.%s" % node_type, "必须是数组")
            continue
        for index in range(rewards[node_type].size()):
            var entry = rewards[node_type][index]
            var scope := "node_rewards.node_rewards.%s[%d]" % [node_type, index]
            if not entry is Dictionary:
                _error(scope, "必须是对象")
                continue
            if str(entry.get("kind", "")) not in REWARD_KINDS:
                _error(scope + ".kind", "引用未知奖励类型")
            _run_effect_registry.validate_effect(entry, self, scope)
    for spec in [["combat", 3], ["elite", 4], ["boss", 5]]:
        var entries: Array = rewards.get(spec[0], [])
        var experience := 0
        for entry in entries:
            if entry is Dictionary and str(entry.get("kind", "")) == "experience":
                experience += int(entry.get("amount", 0))
        if experience != int(spec[1]):
            _error("node_rewards.node_rewards.%s" % spec[0], "基础战斗历练必须为 %d" % int(spec[1]))

func _validate_act_progression(definition: Dictionary) -> void:
    var acts = definition.get("acts")
    if not acts is Array:
        _error("act_progression.acts", "必须是数组")
        return
    var acts_by_number: Dictionary = {}
    for index in range(acts.size()):
        var entry = acts[index]
        var scope := "act_progression.acts[%d]" % index
        if not entry is Dictionary:
            _error(scope, "必须是对象")
            continue
        if not _is_integer(entry.get("act")):
            _error(scope + ".act", "必须是第 1～3 层的整数")
            continue
        var act := int(entry.get("act", 0))
        if act < 1 or act > 3:
            _error(scope + ".act", "必须是第 1～3 层的整数")
            continue
        if acts_by_number.has(act):
            _error(scope + ".act", "层数重复：第 %d 层" % act)
        else:
            acts_by_number[act] = true
        _validate_life_definition(entry.get("player"), scope + ".player")
        var enemies = entry.get("enemies")
        if not enemies is Dictionary:
            _error(scope + ".enemies", "必须是对象")
            continue
        for node_type in ["combat", "elite", "boss"]:
            if not enemies.has(node_type):
                _error(scope + ".enemies.%s" % node_type, "缺少敌人生命定义")
                continue
            _validate_life_definition(
                enemies[node_type], scope + ".enemies.%s" % node_type)
    for act in range(1, 4):
        if not acts_by_number.has(act):
            _error("act_progression.acts", "缺少第 %d 层生命定义" % act)

func _validate_life_definition(value, scope: String) -> void:
    if not value is Dictionary:
        _error(scope, "必须是对象")
        return
    if not _is_integer(value.get("max_life")) \
            or int(value.get("max_life", 0)) <= 0:
        _error(scope + ".max_life", "必须是正整数")

func _validate_enemies(definition: Dictionary) -> void:
    var scope := "enemies"
    var default_ai = definition.get("default_ai")
    if not default_ai is Dictionary:
        _error(scope + ".default_ai", "必须是对象")
    else:
        _validate_enemy_ai_policy(default_ai, scope + ".default_ai")
    var values = definition.get("enemies")
    if not values is Array or values.is_empty():
        _error(scope + ".enemies", "必须是非空数组")
        return
    var seen: Dictionary = {}
    for index in range(values.size()):
        var entry = values[index]
        var entry_scope := "%s.enemies[%d]" % [scope, index]
        if not entry is Dictionary:
            _error(entry_scope, "必须是对象")
            continue
        var enemy_id := _required_id(entry, entry_scope)
        _register_unique(seen, enemy_id, entry_scope, entry)
        _validate_name(entry, entry_scope)
        for field in FORBIDDEN_ENEMY_ENTRY_FIELDS:
            if entry.has(field):
                _error(entry_scope, "正式敌人池条目不允许字段 %s" % field)
        _validate_enemy_acts(entry.get("acts"), entry_scope + ".acts")
        _validate_enemy_node_types(entry.get("node_types"), entry_scope + ".node_types")
        var deck = entry.get("deck")
        if not deck is Array or deck.is_empty():
            _error(entry_scope + ".deck", "必须是非空数组")
        else:
            var deck_report := EnemyDeckEncodingScript.validate_tokens(
                deck, _card_ids, _origins_by_id, _enhancements_by_id,
                _imprints_by_id, ATTRIBUTE_IDS)
            for deck_error in deck_report.get("errors", []):
                _error(entry_scope + ".deck", str(deck_error))
        var inner_skill_ids = entry.get("equipped_inner_skill_ids")
        if not inner_skill_ids is Array:
            _error(entry_scope + ".equipped_inner_skill_ids", "必须是数组")
        else:
            if inner_skill_ids.size() > 6:
                _error(entry_scope + ".equipped_inner_skill_ids", "内功最多装备 6 门")
            var seen_skills: Dictionary = {}
            for skill_id_value in inner_skill_ids:
                var skill_id := str(skill_id_value)
                if not _inner_skills_by_id.has(skill_id):
                    _error(entry_scope + ".equipped_inner_skill_ids", "引用未知内功 %s" % skill_id)
                elif seen_skills.has(skill_id):
                    _error(entry_scope + ".equipped_inner_skill_ids", "重复引用内功 %s" % skill_id)
                seen_skills[skill_id] = true
        var slot_index = entry.get("technique_slot_index")
        var slot_limit: int = inner_skill_ids.size() if inner_skill_ids is Array else -1
        if not _is_integer(slot_index) or int(slot_index) < 0 \
                or int(slot_index) > slot_limit:
            _error(entry_scope + ".technique_slot_index", "必须位于已装备内功之间")
        _validate_enemy_insights(
            entry.get("hand_proficiency_fixed"),
            entry_scope + ".hand_proficiency_fixed")
        _validate_enemy_sequences(entry.get("sequences"), entry_scope + ".sequences")
        if entry.has("ai"):
            if not entry["ai"] is Dictionary:
                _error(entry_scope + ".ai", "必须是对象")
            else:
                _validate_enemy_ai_policy(entry["ai"], entry_scope + ".ai")

func _validate_enemy_acts(values, scope: String) -> void:
    if not values is Array or values.is_empty():
        _error(scope, "必须是非空的层数数组")
        return
    var seen: Dictionary = {}
    for value in values:
        if not _is_integer(value) or int(value) < 1 or int(value) > 3:
            _error(scope, "层数必须是 1～3 的整数")
        elif seen.has(int(value)):
            _error(scope, "层数重复：%d" % int(value))
        seen[int(value)] = true

func _validate_enemy_node_types(values, scope: String) -> void:
    if not values is Array or values.is_empty():
        _error(scope, "必须是非空数组")
        return
    var seen: Dictionary = {}
    for value in values:
        var node_type := str(value)
        if node_type not in ["combat", "elite", "boss"]:
            _error(scope, "未知敌人节点类型 %s" % node_type)
        elif seen.has(node_type):
            _error(scope, "节点类型重复：%s" % node_type)
        seen[node_type] = true

func _validate_enemy_insights(values, scope: String) -> void:
    if not values is Dictionary:
        _error(scope, "必须是对象")
        return
    for hand_id in HAND_IDS:
        if not values.has(hand_id):
            _error(scope, "缺少精确牌型 %s" % hand_id)
        elif not _is_integer(values[hand_id]) or int(values[hand_id]) < 0:
            _error(scope + ".%s" % hand_id, "敌方固定熟练度必须是非负整数")
    for key in values:
        if not HAND_IDS.has(str(key)):
            _error(scope, "包含未知精确牌型 %s" % str(key))

func _validate_enemy_sequences(values, scope: String) -> void:
    if not values is Dictionary:
        _error(scope, "必须是对象")
        return
    _validate_sequences(values, scope)
    var statuses: Dictionary = _contents.get("techniques", {}).get("integration_statuses", {})
    for hand_id in HAND_IDS:
        for technique_id_value in values.get(hand_id, []):
            var technique_id := str(technique_id_value)
            if str(statuses.get(technique_id, "missing")) != FORMAL_TECHNIQUE_STATUS:
                _error(
                    "%s.%s" % [scope, hand_id],
                    "功法 %s 当前接入档位为 %s，敌人正式池只允许 %s" % [
                        technique_id, statuses.get(technique_id, "missing"), FORMAL_TECHNIQUE_STATUS])

func result() -> Dictionary:
    return {
        "valid": errors.is_empty(),
        "errors": errors.duplicate(),
        "warnings": warnings.duplicate(),
    }

func _has_all_content() -> bool:
    for key in CONTENT_KEYS:
        if not _contents.has(key) or not _contents[key] is Dictionary:
            return false
    return true

func _validate_version(scope: String, definition: Dictionary) -> void:
    if not definition.has("version"):
        _error(scope, "缺少版本字段 version")
    elif not _is_integer(definition["version"]) or int(definition["version"]) < 1:
        _error(scope, "version 必须是大于等于 1 的整数")

func _validate_base_deck(definition: Dictionary) -> void:
    var attributes = definition.get("attributes")
    var ranks = definition.get("ranks")
    if not attributes is Array:
        _error("base_deck.attributes", "必须是数组")
        return
    if not ranks is Array:
        _error("base_deck.ranks", "必须是数组")
        return
    var attribute_ids: Dictionary = {}
    for index in range(attributes.size()):
        var value = attributes[index]
        var scope := "base_deck.attributes[%d]" % index
        if not value is Dictionary:
            _error(scope, "必须是对象")
            continue
        var attribute_id := _required_id(value, scope)
        _register_unique(attribute_ids, attribute_id, scope, value)
        if not value.get("name") is String or str(value.get("name", "")) == "":
            _error(scope, "name 必须是非空字符串")
    if attribute_ids.keys().size() != ATTRIBUTE_IDS.size():
        _error("base_deck.attributes", "必须完整定义风林火山 4 种属性")
    for attribute_id in ATTRIBUTE_IDS:
        if not attribute_ids.has(attribute_id):
            _error("base_deck.attributes", "缺少属性 %s" % attribute_id)

    var rank_ids: Dictionary = {}
    for index in range(ranks.size()):
        var value = ranks[index]
        var scope := "base_deck.ranks[%d]" % index
        if not value is Dictionary:
            _error(scope, "必须是对象")
            continue
        var rank_id := _required_id(value, scope)
        _register_unique(rank_ids, rank_id, scope, value)
        if not _is_integer(value.get("order")):
            _error(scope, "order 必须是整数")
        if not _is_integer(value.get("qi")):
            _error(scope, "qi 必须是整数")
    if rank_ids.keys().size() != RANK_SPECS.size():
        _error("base_deck.ranks", "必须完整定义 13 个牌阶")
    for spec in RANK_SPECS:
        var rank_id: String = spec[0]
        if not rank_ids.has(rank_id):
            _error("base_deck.ranks", "缺少牌阶 %s" % rank_id)
            continue
        var rank: Dictionary = rank_ids[rank_id]
        if int(rank.get("order", -1)) != int(spec[1]) or int(rank.get("qi", -1)) != int(spec[2]):
            _error("base_deck.ranks.%s" % rank_id, "牌阶顺序或真气值不符合权威基线")
    for attribute_id in ATTRIBUTE_IDS:
        for spec in RANK_SPECS:
            _card_ids["%s_%s" % [attribute_id, spec[0]]] = true
    if _card_ids.size() != 52:
        _error("base_deck", "基础牌组必须生成 52 个唯一真气 ID")

func _validate_starter_builds(definition: Dictionary) -> void:
    var values = definition.get("starter_builds")
    if not values is Array or values.is_empty():
        _error("starter_builds.starter_builds", "必须是非空数组")
        return
    var build_ids: Dictionary = {}
    for index in range(values.size()):
        var value = values[index]
        var scope := "starter_builds.starter_builds[%d]" % index
        if not value is Dictionary:
            _error(scope, "必须是对象")
            continue
        var build_id := _required_id(value, scope)
        _register_unique(build_ids, build_id, scope, value)
        _validate_name(value, scope)
        if not value.get("description") is String \
                or str(value.get("description", "")) == "":
            _error(scope + ".description", "必须是非空字符串")
        if str(value.get("deck_kind", "")) != "standard_52":
            _error(scope + ".deck_kind", "当前只支持 standard_52")
        if not _is_integer(value.get("card_count")) \
                or int(value.get("card_count", 0)) != 52:
            _error(scope + ".card_count", "标准初始牌组必须为 52 张")
        if not value.get("available") is bool:
            _error(scope + ".available", "必须是布尔值")
        var card_ids = value.get("card_ids")
        if not card_ids is Array or card_ids.is_empty():
            _error(scope + ".card_ids", "必须提供非空真气 ID 数组")
        else:
            var unique_card_ids: Dictionary = {}
            for card_index in range(card_ids.size()):
                var card_id := str(card_ids[card_index])
                if card_id == "" or not _card_ids.has(card_id):
                    _error("%s.card_ids[%d]" % [scope, card_index], "引用未知基础真气：%s" % card_id)
                elif unique_card_ids.has(card_id):
                    _error("%s.card_ids" % scope, "不能重复引用真气：%s" % card_id)
                unique_card_ids[card_id] = true
            if _is_integer(value.get("card_count")) \
                    and int(value.get("card_count", 0)) != card_ids.size():
                _error(scope + ".card_count", "必须等于 card_ids 数量")
    if not build_ids.has("standard_52"):
        _error("starter_builds.starter_builds", "必须提供 standard_52 初始构筑")
    elif not bool(build_ids["standard_52"].get("available", false)):
        _error("starter_builds.standard_52", "当前唯一标准构筑必须可选择")

func _validate_battle_statuses(definition: Dictionary) -> void:
    var values = definition.get("actor_statuses")
    if not values is Array:
        _error("battle_statuses.actor_statuses", "必须是数组")
        return
    if not values.is_empty():
        _error(
            "battle_statuses.actor_statuses",
            "旧命名角色层数已退役，兼容占位数组必须为空")

func _validate_card_states(definition: Dictionary) -> void:
    _validate_reshape_categories(definition.get("reshape_categories"))
    _validate_categories(
        definition.get("anomaly_categories"),
        ANOMALY_CATEGORY_IDS,
        {"buff": -1, "debuff": -1, "state": 1, "mark": -1},
        "card_states.anomaly_categories")
    _validate_temporary_reshape_subslots(
        definition.get("temporary_reshape_subslots"))
    _validate_named_definitions(
        definition.get("origins"),
        REQUIRED_ORIGIN_IDS,
        _origins_by_id,
        "card_states.origins")
    _validate_only_ids(
        _origins_by_id, REQUIRED_ORIGIN_IDS, "card_states.origins")
    _validate_card_reshape_behaviors(
        definition.get("origins"), "card_states.origins")
    _validate_named_definitions(
        definition.get("enhancements"),
        REQUIRED_ENHANCEMENT_IDS,
        _enhancements_by_id,
        "card_states.enhancements")
    _validate_only_ids(
        _enhancements_by_id, REQUIRED_ENHANCEMENT_IDS, "card_states.enhancements")
    _validate_card_reshape_behaviors(
        definition.get("enhancements"), "card_states.enhancements")
    _validate_named_definitions(
        definition.get("imprints"),
        REQUIRED_IMPRINT_IDS,
        _imprints_by_id,
        "card_states.imprints")
    _validate_only_ids(
        _imprints_by_id, REQUIRED_IMPRINT_IDS, "card_states.imprints")
    _validate_named_definitions(
        definition.get("other_reshapes"),
        [],
        _other_reshapes_by_id,
        "card_states.other_reshapes")
    _validate_card_reshape_behaviors(
        definition.get("other_reshapes"), "card_states.other_reshapes")
    _validate_card_reshape_behaviors(
        definition.get("imprints"), "card_states.imprints")
    _validate_echo_imprint()

    if definition.has("finishes"):
        _error("card_states.finishes", "旧品相字段已废弃，正式内容必须使用本源/强化/印记/其他")
    _validate_no_retired_reshape_ids(definition)

    var anomalies = definition.get("anomalies")
    if not anomalies is Array:
        _error("card_states.anomalies", "必须是数组")
    else:
        for index in range(anomalies.size()):
            var value = anomalies[index]
            var scope := "card_states.anomalies[%d]" % index
            if not value is Dictionary:
                _error(scope, "必须是对象")
                continue
            var content_id := _required_id(value, scope)
            _register_unique(_anomalies_by_id, content_id, scope, value)
            if RETIRED_ANOMALY_IDS.has(content_id):
                _error(scope + ".id", "旧异状 ID 已废弃：%s" % content_id)
            _validate_name(value, scope)
            var category := str(value.get("category", ""))
            if not ANOMALY_CATEGORY_IDS.has(category):
                _error(scope, "引用未知异状类别 %s" % category)
            if not value.get("remove_on_enter_discard") is bool:
                _error(scope, "remove_on_enter_discard 必须是布尔值")
            elif category == "state" and not bool(value["remove_on_enter_discard"]):
                _error(scope, "状态进入弃牌堆时必须默认移除")
            elif content_id in ["growth", "decay"] \
                    and not bool(value["remove_on_enter_discard"]):
                _error(scope, "成长与衰败进入弃牌堆时必须移除")
            if not value.get("remove_on_battle_end") is bool or not bool(value.get("remove_on_battle_end", false)):
                _error(scope, "异状必须在战斗结束前移除")
            if category == "mark":
                var lifecycle = value.get("lifecycle")
                if not lifecycle is Array or lifecycle.is_empty():
                    _error(scope + ".lifecycle", "标记必须定义非空生命周期")
                else:
                    for event in lifecycle:
                        if not MARK_LIFECYCLE_EVENTS.has(str(event)):
                            _error(scope + ".lifecycle", "未知标记生命周期 %s" % str(event))
            var on_apply := str(value.get("on_apply", ""))
            if not ANOMALY_ON_APPLY_POLICIES.has(on_apply):
                _error(scope, "未知异状获得策略 %s" % on_apply)
            if on_apply == "purify_combat_state" and content_id != "purification":
                _error(scope, "净化清理策略只允许 purification")
            var runtime_payload = value.get("runtime_payload", {})
            if not runtime_payload is Dictionary:
                _error(scope + ".runtime_payload", "必须是对象")
            else:
                for attribute_id in runtime_payload.get("attribute_aliases", []):
                    if not ATTRIBUTE_IDS.has(str(attribute_id)):
                        _error(scope + ".runtime_payload.attribute_aliases", "未知属性 %s" % str(attribute_id))
            _validate_status_behaviors(value, CARD_STATUS_TRIGGERS, scope)
            _validate_card_status_modifiers(value, scope)
            if category in ["buff", "debuff"] \
                    and not bool(value.get("stackable", false)):
                _error(scope + ".stackable", "buff/debuff 必须声明可叠层")
            if category == "state" \
                    and str(value.get("same_id", "")) not in ["keep", "stack"]:
                _error(scope + ".same_id", "state 必须声明同名 keep 或 stack 策略")
        _validate_card_status_behavior_references()
        _validate_card_reshape_behavior_references()
        _validate_required_ids(
            _anomalies_by_id, REQUIRED_ANOMALY_IDS, "card_states.anomalies")
        _validate_only_ids(
            _anomalies_by_id, REQUIRED_ANOMALY_IDS, "card_states.anomalies")
        if str(_anomalies_by_id.get("forbidden", {}).get("same_id", "")) != "stack":
            _error("card_states.anomalies.forbidden.same_id", "封禁必须累加层数")
        if str(_anomalies_by_id.get("purification", {}).get("same_id", "reject")) != "reject":
            _error("card_states.anomalies.purification.same_id", "净化必须拒绝重复施加")
        _validate_void_burst_contract()
    _validate_other_reshape_battle_start_anomalies()

func _validate_card_reshape_behaviors(values, scope: String) -> void:
    if not values is Array:
        return
    for index in range(values.size()):
        var definition = values[index]
        if not definition is Dictionary:
            continue
        var definition_scope := "%s[%d]" % [scope, index]
        var behaviors = definition.get("behaviors", [])
        if not behaviors is Array:
            _error(definition_scope + ".behaviors", "必须是数组")
            continue
        for behavior_index in range(behaviors.size()):
            var behavior = behaviors[behavior_index]
            var behavior_scope := "%s.behaviors[%d]" % [definition_scope, behavior_index]
            if not behavior is Dictionary:
                _error(behavior_scope, "必须是对象")
                continue
            var trigger := str(behavior.get("trigger", ""))
            if not CardReshapeBehaviorRegistryScript.TRIGGERS.has(trigger):
                _error(behavior_scope + ".trigger", "未知重塑行为触发时点 %s" % trigger)
                continue
            _card_reshape_registry.validate_behavior(behavior, self, behavior_scope)

func _validate_echo_imprint() -> void:
    var echo: Dictionary = _imprints_by_id.get("echo", {})
    if echo.is_empty():
        return
    var replay_behaviors: Array = []
    for behavior_value in echo.get("behaviors", []):
        if not behavior_value is Dictionary:
            continue
        var behavior: Dictionary = behavior_value
        if str(behavior.get("handler", "")) == \
                "replay_qualified_card_trigger":
            replay_behaviors.append(behavior)
    if replay_behaviors.size() != 1:
        _error(
            "card_states.imprints.echo.behaviors",
            "回响印必须且只能声明一个合格触发重演 Handler")
        return
    if str(replay_behaviors[0].get("trigger", "")) != \
            "qualified_trigger_replay":
        _error(
            "card_states.imprints.echo.behaviors",
            "回响重演 Handler 只能绑定 qualified_trigger_replay")

func _validate_card_reshape_behavior_references() -> void:
    for source in [
        [_contents["card_states"].get("origins", []), "card_states.origins"],
        [_contents["card_states"].get("enhancements", []), "card_states.enhancements"],
        [_contents["card_states"].get("imprints", []), "card_states.imprints"],
        [_contents["card_states"].get("other_reshapes", []), "card_states.other_reshapes"],
    ]:
        var definitions: Array = source[0]
        for definition_index in range(definitions.size()):
            var definition = definitions[definition_index]
            if not definition is Dictionary:
                continue
            for behavior_index in range(definition.get("behaviors", []).size()):
                var behavior = definition.get("behaviors", [])[behavior_index]
                if not behavior is Dictionary:
                    continue
                var scope := "%s[%d].behaviors[%d]" % [
                    str(source[1]), definition_index, behavior_index]
                if str(behavior.get("handler", "")) == "block_anomaly_application":
                    for category in behavior.get("categories", []):
                        if str(category) not in ANOMALY_CATEGORY_IDS:
                            _error(scope + ".categories", "引用未知异状类别 %s" % category)
                    for blocked_id in behavior.get("anomaly_ids", []):
                        if not _anomalies_by_id.has(str(blocked_id)):
                            _error(
                                scope + ".anomaly_ids",
                                "引用未知真气异状 %s" % blocked_id)
                    continue
                if str(behavior.get("handler", "")) != "apply_anomaly":
                    continue
                var anomaly_id := str(behavior.get("anomaly", ""))
                var anomaly: Dictionary = _anomalies_by_id.get(anomaly_id, {})
                if anomaly.is_empty():
                    _error(scope + ".anomaly", "引用未知真气异状 %s" % anomaly_id)
                elif str(anomaly.get("category", "")) != str(behavior.get("category", "")):
                    _error(scope + ".category", "异状 %s 的类别不匹配" % anomaly_id)

func _validate_status_behaviors(
        definition: Dictionary,
        allowed_triggers: Array,
        scope: String) -> void:
    var behaviors = definition.get("behaviors", [])
    if not behaviors is Array:
        _error(scope + ".behaviors", "必须是数组")
        return
    for index in range(behaviors.size()):
        var behavior = behaviors[index]
        var behavior_scope := "%s.behaviors[%d]" % [scope, index]
        if not behavior is Dictionary:
            _error(behavior_scope, "必须是对象")
            continue
        var trigger := str(behavior.get("trigger", ""))
        if not allowed_triggers.has(trigger):
            _error(behavior_scope + ".trigger", "未知状态触发时点 %s" % trigger)
        var handler_id := str(behavior.get("handler", ""))
        if not _status_behavior_ids.has(handler_id):
            _error(behavior_scope + ".handler", "未注册的状态处理器 %s" % handler_id)
        if behavior.has("priority") and not _is_integer(behavior["priority"]):
            _error(behavior_scope + ".priority", "必须是整数")
        if behavior.has("count") and (
                not _is_integer(behavior["count"]) or int(behavior["count"]) < 0):
            _error(behavior_scope + ".count", "必须是非负整数")
        if behavior.has("amount") and (
                not _is_integer(behavior["amount"]) or int(behavior["amount"]) < 0):
            _error(behavior_scope + ".amount", "必须是非负整数")
        if behavior.has("attribute") and not ATTRIBUTE_IDS.has(str(behavior["attribute"])):
            _error(behavior_scope + ".attribute", "未知属性 %s" % str(behavior["attribute"]))
        if behavior.has("category") \
                and not ANOMALY_CATEGORY_IDS.has(str(behavior["category"])):
            _error(behavior_scope + ".category", "未知异状类别 %s" % str(behavior["category"]))
        if behavior.has("effects_by_flow") and not behavior["effects_by_flow"] is Dictionary:
            _error(behavior_scope + ".effects_by_flow", "必须是对象")

func _validate_card_status_modifiers(definition: Dictionary, scope: String) -> void:
    var modifiers = definition.get("modifiers", [])
    if not modifiers is Array:
        _error(scope + ".modifiers", "必须是数组")
        return
    for index in range(modifiers.size()):
        var modifier = modifiers[index]
        var modifier_scope := "%s.modifiers[%d]" % [scope, index]
        if not modifier is Dictionary:
            _error(modifier_scope, "必须是对象")
            continue
        var modifier_id := str(modifier.get("id", ""))
        if not CARD_STATUS_MODIFIER_IDS.has(modifier_id):
            _error(modifier_scope + ".id", "未知真气状态数值修正 %s" % modifier_id)
        if not _is_integer(modifier.get("value")):
            _error(modifier_scope + ".value", "必须是整数")

func _validate_card_status_behavior_references() -> void:
    for status_id in _anomalies_by_id:
        var definition: Dictionary = _anomalies_by_id[status_id]
        for index in range(definition.get("behaviors", []).size()):
            var behavior: Dictionary = definition["behaviors"][index]
            if behavior.has("anomaly"):
                var direct_id := str(behavior.get("anomaly", ""))
                var direct_category := str(behavior.get("category", ""))
                var direct_scope := "card_states.anomalies.%s.behaviors[%d]" % [
                    status_id, index]
                if not _anomalies_by_id.has(direct_id):
                    _error(direct_scope + ".anomaly", "引用未知真气异状 %s" % direct_id)
                elif str(_anomalies_by_id[direct_id].get("category", "")) != direct_category:
                    _error(direct_scope + ".category", "异状 %s 不属于类别 %s" % [direct_id, direct_category])
            if not behavior.has("apply_anomaly"):
                continue
            var scope := "card_states.anomalies.%s.behaviors[%d].apply_anomaly" % [
                status_id, index]
            var applied = behavior["apply_anomaly"]
            if not applied is Dictionary:
                _error(scope, "必须是对象")
                continue
            var applied_id := str(applied.get("id", ""))
            var category := str(applied.get("category", ""))
            if not _anomalies_by_id.has(applied_id):
                _error(scope, "引用未知真气异状 %s" % applied_id)
            elif str(_anomalies_by_id[applied_id].get("category", "")) != category:
                _error(scope, "异状 %s 不属于类别 %s" % [applied_id, category])
            if applied.has("payload") and not applied["payload"] is Dictionary:
                _error(scope + ".payload", "必须是对象")

func _validate_other_reshape_battle_start_anomalies() -> void:
    for reshape_id in _other_reshapes_by_id:
        var definition: Dictionary = _other_reshapes_by_id[reshape_id]
        var effects = definition.get("battle_start_anomalies", [])
        var scope := "card_states.other_reshapes.%s.battle_start_anomalies" % str(reshape_id)
        if not effects is Array:
            _error(scope, "必须是数组")
            continue
        for index in range(effects.size()):
            var effect = effects[index]
            var effect_scope := "%s[%d]" % [scope, index]
            if not effect is Dictionary:
                _error(effect_scope, "必须是对象")
                continue
            var anomaly_id := str(effect.get("anomaly", ""))
            var category := str(effect.get("category", ""))
            if not _anomalies_by_id.has(anomaly_id):
                _error(effect_scope, "引用未知真气异状 %s" % anomaly_id)
            elif str(_anomalies_by_id[anomaly_id].get("category", "")) != category:
                _error(effect_scope, "异状 %s 不属于类别 %s" % [anomaly_id, category])
            if effect.has("payload") and not effect["payload"] is Dictionary:
                _error(effect_scope + ".payload", "必须是对象")

func _validate_techniques(definition: Dictionary) -> void:
    var membership = definition.get("pool_membership")
    var techniques = definition.get("techniques")
    var integration_statuses = definition.get("integration_statuses")
    if not membership is Dictionary:
        _error("techniques.pool_membership", "必须是对象")
        return
    for hand_id in HAND_IDS:
        if not membership.has(hand_id) or not membership[hand_id] is Array:
            _error("techniques.pool_membership", "缺少牌型 %s 的功法池数组" % hand_id)
            continue
        if membership[hand_id].is_empty():
            _error("techniques.pool_membership.%s" % hand_id, "合格池不能为空")
        for pool_id in membership[hand_id]:
            if not pool_id is String or not POOL_IDS.has(str(pool_id)):
                _error("techniques.pool_membership.%s" % hand_id, "引用未知功法池 %s" % str(pool_id))
        if membership[hand_id] != EXPECTED_POOL_MEMBERSHIP[hand_id]:
            _error(
                "techniques.pool_membership.%s" % hand_id,
                "必须精确为 %s" % str(EXPECTED_POOL_MEMBERSHIP[hand_id]))
    for hand_id in membership:
        if not HAND_IDS.has(str(hand_id)):
            _error("techniques.pool_membership", "包含未知精确牌型 %s" % str(hand_id))
    if not techniques is Array:
        _error("techniques.techniques", "必须是数组")
        return
    for index in range(techniques.size()):
        var value = techniques[index]
        var scope := "techniques.techniques[%d]" % index
        if not value is Dictionary:
            _error(scope, "必须是对象")
            continue
        var technique_id := _required_id(value, scope)
        _register_unique(_techniques_by_id, technique_id, scope, value)
        if RETIRED_TECHNIQUE_IDS.has(technique_id):
            _error(scope + ".id", "归档功法不得恢复到正式运行数据：%s" % technique_id)
        if not value.get("name") is String or str(value.get("name", "")) == "":
            _error(scope, "name 必须是非空字符串")
        var pool_id := str(value.get("pool", ""))
        if not POOL_IDS.has(pool_id):
            _error(scope, "引用未知功法池 %s" % pool_id)
        _validate_cooperation(value.get("cooperation", {}), scope + ".cooperation")
        if not value.get("special") is bool:
            _error(scope, "special 必须是布尔值")
        if not value.get("built_in", false) is bool:
            _error(scope + ".built_in", "必须是布尔值")
        if bool(value.get("built_in", false)) \
                and not bool(value.get("special", false)):
            _error(scope + ".built_in", "内建功法必须标记 special")
        if not _is_integer(value.get("base_loadout_limit", 1)) \
                or int(value.get("base_loadout_limit", 1)) <= 0:
            _error(scope + ".base_loadout_limit", "必须是正整数")
        var eligible_hand_ids = value.get("eligible_hand_ids", [])
        if not eligible_hand_ids is Array:
            _error(scope + ".eligible_hand_ids", "必须是数组")
        else:
            for eligible_hand_id in eligible_hand_ids:
                if str(eligible_hand_id) not in HAND_IDS:
                    _error(scope + ".eligible_hand_ids", "引用未知精确牌型 %s" % str(eligible_hand_id))
        _effect_specs.validate_effects(value.get("effects"), "battle", scope + ".effects")
    _validate_technique_integration_statuses(
        integration_statuses,
        definition.get("resource_paths", []))

func _validate_technique_integration_statuses(value, resource_paths) -> void:
    var scope := "techniques.integration_statuses"
    if not value is Dictionary:
        _error(scope, "必须是按功法 ID 声明接入档位的对象")
        return
    var resource_ids: Dictionary = {}
    if not resource_paths is Array:
        _error("techniques.resource_paths", "必须是数组")
        return
    for path_value in resource_paths:
        var file_name := str(path_value).get_file()
        var technique_id := file_name.trim_suffix(".tres")
        resource_ids[technique_id] = true
        if not value.has(technique_id):
            _error(scope, "功法 %s 缺少显式接入档位" % technique_id)
            continue
        var status := str(value[technique_id])
        if not TECHNIQUE_INTEGRATION_STATUSES.has(status):
            _error(
                "%s.%s" % [scope, technique_id],
                "未知接入档位 %s" % status)
    for technique_id_value in value:
        var technique_id := str(technique_id_value)
        if not resource_ids.has(technique_id):
            _error(scope, "接入档位引用未知功法 %s" % technique_id)

func _validate_cooperation(value, scope: String) -> void:
    if value == null or (value is Dictionary and value.is_empty()):
        return
    if not value is Dictionary:
        _error(scope, "必须是对象")
        return
    if str(value.get("hand_id", "")) not in HAND_IDS:
        _error(scope + ".hand_id", "引用未知协同牌型")
    if not _is_integer(value.get("max_groups")) or int(value.get("max_groups", 0)) <= 0:
        _error(scope + ".max_groups", "必须是正整数")
    if str(value.get("power_rule", "shared_half")) != "shared_half":
        _error(scope + ".power_rule", "当前只支持 shared_half")
    if value.has("exact_card_count") \
            and (not _is_integer(value["exact_card_count"]) \
            or int(value["exact_card_count"]) < 1 \
            or int(value["exact_card_count"]) > 5):
        _error(scope + ".exact_card_count", "必须为1～5")
    if value.has("card_has_any_anomaly"):
        if not value["card_has_any_anomaly"] is Array \
                or value["card_has_any_anomaly"].is_empty():
            _error(scope + ".card_has_any_anomaly", "必须是非空数组")
        else:
            for index in range(value["card_has_any_anomaly"].size()):
                var anomaly = value["card_has_any_anomaly"][index]
                if not anomaly is Dictionary:
                    _error(scope + ".card_has_any_anomaly[%d]" % index, "必须是对象")
                    continue
                if str(anomaly.get("category", "")) not in ANOMALY_CATEGORY_IDS:
                    _error(scope + ".card_has_any_anomaly[%d].category" % index, "引用未知异状类别")
    if value.has("shares_attribute_with_main") \
            and not value["shares_attribute_with_main"] is bool:
        _error(scope + ".shares_attribute_with_main", "必须是布尔值")
    var post_commit = value.get("post_commit", {})
    if not post_commit is Dictionary:
        _error(scope + ".post_commit", "必须是对象")
    elif str(post_commit.get("destination", "own_discard")) not in ["own_discard", "target_draw_pile_top"]:
        _error(scope + ".post_commit.destination", "引用未知协同牌提交位置")

func _validate_inner_skills(definition: Dictionary) -> void:
    # production 的空池仍是旧 v1 兼容占位；一旦声明任何内容即必须采用 v2。
    # 正式主数据 inner_skills.json 已迁移为 v2。
    if int(definition.get("version", 0)) != 2 \
            and not (int(definition.get("version", 0)) == 1 \
            and definition.get("inner_skills", []) is Array \
            and definition.get("inner_skills", []).is_empty()):
        _error("inner_skills.version", "当前被动行为结构必须为 version 2")
    var values = definition.get("inner_skills")
    if not values is Array:
        _error("inner_skills.inner_skills", "必须是数组")
        return
    for index in range(values.size()):
        var value = values[index]
        var scope := "inner_skills.inner_skills[%d]" % index
        if not value is Dictionary:
            _error(scope, "必须是对象")
            continue
        var content_id := _required_id(value, scope)
        _register_unique(_inner_skills_by_id, content_id, scope, value)
        if not value.get("name") is String or str(value.get("name", "")) == "":
            _error(scope, "name 必须是非空字符串")
        var status := str(value.get("status", ""))
        if status not in ITEM_STATUSES:
            _error(scope + ".status", "必须为 candidate、design_only 或 formal")
        if value.has("forget_value") \
                and (not _is_integer(value.get("forget_value")) \
                or int(value.get("forget_value", -1)) < 0):
            _error(scope + ".forget_value", "必须是非负整数")
        if status == FORMAL_CONTENT_STATUS and not value.has("forget_value"):
            _error(scope + ".forget_value", "正式内功必须配置非负整数遗忘所得")
        _validate_passive_behaviors(value, status, scope, "内功")

func _validate_consumables(definition: Dictionary) -> void:
    var values = definition.get("consumables")
    if not values is Array:
        _error("consumables.consumables", "必须是数组")
        return
    for index in range(values.size()):
        var value = values[index]
        var scope := "consumables.consumables[%d]" % index
        if not value is Dictionary:
            _error(scope, "必须是对象")
            continue
        var content_id := _required_id(value, scope)
        _register_unique(_consumables_by_id, content_id, scope, value)
        if content_id != "" and not _is_snake_case(content_id):
            _error(scope + ".id", "必须使用稳定 snake_case")
        _validate_name(value, scope)
        if not value.get("description") is String \
                or str(value.get("description", "")) == "":
            _error(scope + ".description", "必须是非空字符串")
        if not value.get("kind") is String \
                or str(value.get("kind", "")) not in CONSUMABLE_KINDS:
            _error(scope + ".kind", "只能为 insight、pill、curio 或内容骨架 draft")
        if not _is_integer(value.get("price")) or int(value.get("price", -1)) < 0:
            _error(scope, "price 必须是非负整数")
        if value.has("record_last_used") \
                and not value.get("record_last_used") is bool:
            _error(scope + ".record_last_used", "必须是布尔值")
        if value.has("unique") and not value.get("unique") is bool:
            _error(scope + ".unique", "必须是布尔值")
        if value.has("requires_preparation") and not value.get("requires_preparation") is bool:
            _error(scope + ".requires_preparation", "必须是布尔值")
        if value.has("choice_schema") and not value.get("choice_schema") is Dictionary:
            _error(scope + ".choice_schema", "必须是对象")
        elif value.has("choice_schema"):
            var choice_schema: Dictionary = value.get("choice_schema", {})
            var choice_type := str(choice_schema.get("type", ""))
            if choice_type not in ["enum", "technique_sequence_removals"]:
                _error(scope + ".choice_schema.type", "未知结构化选择类型 %s" % choice_type)
            if not choice_schema.get("field") is String \
                    or str(choice_schema.get("field", "")) == "":
                _error(scope + ".choice_schema.field", "必须是非空字符串")
            if choice_type == "enum":
                var options = choice_schema.get("options", [])
                if not options is Array or options.is_empty():
                    _error(scope + ".choice_schema.options", "必须是非空数组")
            elif choice_type == "technique_sequence_removals" \
                    and (not _is_integer(choice_schema.get("slot_delta")) \
                    or int(choice_schema.get("slot_delta", 0)) >= 0):
                _error(scope + ".choice_schema.slot_delta", "必须是负整数")
        var targeting = value.get("targeting")
        if not targeting is Dictionary:
            _error(scope + ".targeting", "必须是对象")
        else:
            var targeting_scope := scope + ".targeting"
            var zone = targeting.get("zone")
            if not zone is String:
                _error(scope + ".targeting", "zone 必须是字符串")
            elif not ConsumableTargetingProtocolScript.TARGET_ZONES.has(zone):
                _error(targeting_scope + ".zone", "未知目标区域 %s" % zone)
            var selection = targeting.get("selection")
            if not selection is String \
                    or not ConsumableTargetingProtocolScript.TARGET_SELECTIONS.has(selection):
                _error(targeting_scope + ".selection", "未知目标选择方式 %s" % selection)
            elif zone == "none" and selection == "player_selected":
                _error(
                    targeting_scope + ".selection",
                    "player_selected 只能用于有目标区域")
            var minimum_valid := _is_integer(targeting.get("minimum"))
            var maximum_valid := _is_integer(targeting.get("maximum"))
            if not minimum_valid or not maximum_valid:
                _error(targeting_scope, "minimum/maximum 必须是整数")
            elif zone is String and ConsumableTargetingProtocolScript.TARGET_ZONES.has(zone):
                var minimum := int(targeting["minimum"])
                var maximum := int(targeting["maximum"])
                if zone == "none":
                    if minimum != 0:
                        _error(targeting_scope + ".minimum", "none 区域 minimum 必须为 0")
                    if maximum != 0:
                        _error(targeting_scope + ".maximum", "none 区域 maximum 必须为 0")
                elif minimum < 0 or maximum < minimum:
                    _error(targeting_scope, "目标数量范围无效")
            if targeting.has("maximum_source") \
                    and str(targeting.get("maximum_source", "")) != "base_hand_limit":
                _error(targeting_scope + ".maximum_source", "未知 maximum_source")
            if targeting.has("count_mode") \
                    and str(targeting.get("count_mode", "")) not in ["random", "maximum"]:
                _error(targeting_scope + ".count_mode", "未知 count_mode")
            if targeting.has("choice_field") and not targeting.get("choice_field") is String:
                _error(targeting_scope + ".choice_field", "必须是字符串")
        var effects = value.get("effects")
        if not effects is Array or effects.is_empty():
            _error(scope + ".effects", "必须是非空效果数组")
        else:
            var validation_context = ConsumableValidationContextScript.new(
                self,
                HAND_IDS,
                POOL_IDS,
                _contents.get("techniques", {}).get("pool_membership", {}))
            for effect_index in range(effects.size()):
                var effect = effects[effect_index]
                var effect_scope := "%s.effects[%d]" % [scope, effect_index]
                if not effect is Dictionary:
                    _error(effect_scope, "必须是对象")
                    continue
                _consumable_effect_registry.validate_effect(
                    effect, validation_context, effect_scope)
    if not _consumables_by_id.has("zengyuan_pill"):
        _error("consumables.consumables", "必须保留旧存档 ID zengyuan_pill")
    var practice_offer_ids = definition.get("practice_offer_ids")
    if not practice_offer_ids is Array or practice_offer_ids.is_empty():
        _error("consumables.practice_offer_ids", "必须是非空数组")
    else:
        var seen_offers: Dictionary = {}
        for index in range(practice_offer_ids.size()):
            var consumable_id := str(practice_offer_ids[index])
            var scope := "consumables.practice_offer_ids[%d]" % index
            if not _consumables_by_id.has(consumable_id):
                _error(scope, "引用未知消耗品 %s" % consumable_id)
            elif seen_offers.has(consumable_id):
                _error(scope, "重复引用消耗品 %s" % consumable_id)
            seen_offers[consumable_id] = true

func _validate_items(definition: Dictionary) -> void:
    if int(definition.get("version", 0)) != 2:
        _error("items.version", "当前被动行为结构必须为 version 2")
    var values = definition.get("items")
    if not values is Array:
        _error("items.items", "必须是数组")
        return
    for index in range(values.size()):
        var value = values[index]
        var scope := "items.items[%d]" % index
        if not value is Dictionary:
            _error(scope, "必须是对象")
            continue
        var content_id := _required_id(value, scope)
        _register_unique(_items_by_id, content_id, scope, value)
        if content_id != "" and not _is_snake_case(content_id):
            _error(scope + ".id", "必须使用稳定 snake_case")
        _validate_name(value, scope)
        if str(value.get("kind", "")) != "item":
            _error(scope + ".kind", "必须为 item")
        var status := str(value.get("status", ""))
        if status not in ITEM_STATUSES:
            _error(scope + ".status", "必须为 candidate、design_only 或 formal")
        if not value.get("unique", true) is bool:
            _error(scope + ".unique", "必须是布尔值")
        if not value.get("description") is String \
                or str(value.get("description", "")) == "":
            _error(scope + ".description", "必须是非空字符串")
        if status == FORMAL_CONTENT_STATUS \
                and (not _is_integer(value.get("price")) \
                or int(value.get("price", -1)) < 0):
            _error(scope + ".price", "正式物品必须有非负整数价格")
        _validate_passive_behaviors(value, status, scope, "物品")

func _validate_passive_behaviors(
        definition: Dictionary,
        status: String,
        scope: String,
        kind_name: String) -> void:
    for retired_field in ["timing", "effects"]:
        if definition.has(retired_field):
            _error(
                scope + "." + retired_field,
                "旧式顶层 %s 已停用，必须迁移到 behaviors" % retired_field)
    var behaviors = definition.get("behaviors", [])
    if not behaviors is Array:
        _error(scope + ".behaviors", "必须是数组")
        return
    if status == FORMAL_CONTENT_STATUS and behaviors.is_empty():
        _error(scope + ".behaviors", "正式%s必须至少声明一个被动行为" % kind_name)
    var seen: Dictionary = {}
    var state_counters: Dictionary = {}
    var battle_state_counters: Dictionary = {}
    for behavior_index in range(behaviors.size()):
        var behavior = behaviors[behavior_index]
        var behavior_scope := "%s.behaviors[%d]" % [scope, behavior_index]
        if not behavior is Dictionary:
            _error(behavior_scope, "必须是对象")
            continue
        var behavior_id = behavior.get("id")
        if not behavior_id is String or str(behavior_id) == "":
            _error(behavior_scope + ".id", "必须是非空稳定 behavior ID")
            continue
        var normalized_id := str(behavior_id)
        if not _is_snake_case(normalized_id):
            _error(behavior_scope + ".id", "必须使用稳定 snake_case")
        if seen.has(normalized_id):
            _error(behavior_scope + ".id", "同一内容不能重复声明 behavior %s" % normalized_id)
            continue
        seen[normalized_id] = true
        if not _passive_rule_registry.has_handler(normalized_id):
            _error(behavior_scope + ".id", "未注册的被动行为：%s" % normalized_id)
            continue
        var configuration = behavior.get("configuration", {})
        if not configuration is Dictionary:
            _error(behavior_scope + ".configuration", "必须是对象")
            continue
        for message in _passive_rule_registry.validate_configuration(
                normalized_id, configuration):
            _error(behavior_scope + ".configuration", str(message))
        for message in _passive_rule_registry.validate_battle_timing_bindings(
                normalized_id, configuration):
            _error(behavior_scope + ".configuration", str(message))
        var counter_errors: Array[String] = (
            _passive_rule_registry.validate_counter_definitions(
                normalized_id, configuration))
        for message in counter_errors:
            _error(behavior_scope + ".configuration", str(message))
        var definitions: Array = _passive_rule_registry.counter_definitions(
            normalized_id, configuration)
        var battle_counter_errors: Array[String] = (
            _passive_rule_registry.validate_battle_counter_definitions(
                normalized_id, configuration))
        for message in battle_counter_errors:
            _error(behavior_scope + ".configuration", str(message))
        var battle_definitions: Array = (
            _passive_rule_registry.battle_counter_definitions(
                normalized_id, configuration))
        var state_key := str(behavior.get("state_key", ""))
        if behavior.has("state_key") and not _is_snake_case(state_key):
            _error(behavior_scope + ".state_key", "必须使用稳定 snake_case")
        if (not definitions.is_empty() or not battle_definitions.is_empty()) \
                and state_key == "":
            _error(
                behavior_scope + ".state_key",
                "声明计数器的 behavior 必须提供稳定 state_key")
            continue
        if state_key == "":
            continue
        if not state_counters.has(state_key):
            state_counters[state_key] = {}
        for counter_definition in definitions:
            if state_counters[state_key].has(counter_definition.counter_id):
                _error(
                    behavior_scope + ".state_key",
                    "状态命名空间 %s 重复声明 counter_id %s" % [
                        state_key, counter_definition.counter_id])
            state_counters[state_key][counter_definition.counter_id] = true
        if not battle_state_counters.has(state_key):
            battle_state_counters[state_key] = {}
        for counter_definition in battle_definitions:
            if battle_state_counters[state_key].has(counter_definition.counter_id):
                _error(
                    behavior_scope + ".state_key",
                    "战斗状态命名空间 %s 重复声明 counter_id %s" % [
                        state_key, counter_definition.counter_id])
            battle_state_counters[state_key][counter_definition.counter_id] = true

func _validate_practice_shop(definition: Dictionary) -> void:
    if int(definition.get("version", 0)) != 2:
        _error("practice_shop.version", "当前正式结构必须为 version 2")
    for retired_field in [
            "normal_slots", "pack_slots", "coupon_slots",
            "normal_candidates", "pack_candidates", "coupon_candidates",
            "coupons"]:
        if definition.has(retired_field):
            _error("practice_shop.%s" % retired_field, "v2 正式数据不得写入旧字段")
    var normal = definition.get("normal")
    var packs = definition.get("packs")
    var items = definition.get("items")
    if not normal is Dictionary:
        _error("practice_shop.normal", "必须是对象")
    else:
        _validate_practice_normal(normal)
    if not packs is Dictionary:
        _error("practice_shop.packs", "必须是对象")
    else:
        _validate_practice_packs(packs)
    if not items is Dictionary:
        _error("practice_shop.items", "必须是对象")
    else:
        _validate_practice_items(items)
    if normal is Dictionary and packs is Dictionary and items is Dictionary:
        _validate_practice_cross_area_ids(normal, packs, items)

func _validate_practice_normal(definition: Dictionary) -> void:
    _validate_practice_slot_count(definition, "practice_shop.normal", 2)
    var categories = definition.get("categories")
    if not categories is Array or categories.is_empty():
        _error("practice_shop.normal.categories", "必须是非空数组")
        return
    var seen_categories: Dictionary = {}
    var seen_content: Dictionary = {}
    for index in range(categories.size()):
        var category = categories[index]
        var scope := "practice_shop.normal.categories[%d]" % index
        if not category is Dictionary:
            _error(scope, "必须是对象")
            continue
        var category_id := str(category.get("id", ""))
        if category_id == "" or seen_categories.has(category_id):
            _error(scope + ".id", "ID 不能为空且不得重复")
        seen_categories[category_id] = true
        if not _is_integer(category.get("weight")) \
                or int(category.get("weight", 0)) <= 0:
            _error(scope + ".weight", "必须是正整数")
        var offer_kind := str(category.get("offer_kind", ""))
        if offer_kind not in PRACTICE_OFFER_KINDS:
            _error(scope + ".offer_kind", "未知普通商品类型 %s" % offer_kind)
        var content_kind := str(category.get("content_kind", ""))
        if offer_kind == "consumable" and content_kind not in PRACTICE_CONTENT_KINDS:
            _error(scope + ".content_kind", "消耗品分类必须声明 pill、insight 或 curio")
        elif offer_kind != "consumable" and category.has("content_kind"):
            _error(scope + ".content_kind", "非消耗品分类不得声明 content_kind")
        if offer_kind == "technique":
            if int(category.get("fixed_price", -1)) != 3:
                _error(scope + ".fixed_price", "正式功法统一价格必须为 3")
        elif category.has("fixed_price"):
            _error(scope + ".fixed_price", "非功法价格必须从内容定义读取")
        var candidate_ids = category.get("candidate_ids")
        if not candidate_ids is Array:
            _error(scope + ".candidate_ids", "必须是数组")
            continue
        var category_seen: Dictionary = {}
        for candidate_index in range(candidate_ids.size()):
            var content_id := str(candidate_ids[candidate_index])
            var candidate_scope := "%s.candidate_ids[%d]" % [scope, candidate_index]
            if content_id == "" or category_seen.has(content_id):
                _error(candidate_scope, "ID 不能为空且不得重复")
            if seen_content.has(content_id):
                _error(candidate_scope, "普通商品白名单跨分类重复 ID %s" % content_id)
            category_seen[content_id] = true
            seen_content[content_id] = true
            _validate_practice_normal_candidate(
                content_id, offer_kind, content_kind, candidate_scope)
    _validate_practice_normal_completeness(categories)

func _validate_practice_normal_completeness(categories: Array) -> void:
    var requirements: Array = [
        ["technique", ""],
        ["inner_skill", ""],
        ["consumable", "pill"],
        ["consumable", "insight"],
        ["consumable", "curio"],
    ]
    for requirement in requirements:
        var offer_kind := str(requirement[0])
        var content_kind := str(requirement[1])
        var actual: Array[String] = []
        for category in categories:
            if category is Dictionary \
                    and str(category.get("offer_kind", "")) == offer_kind \
                    and str(category.get("content_kind", "")) == content_kind:
                for value in category.get("candidate_ids", []):
                    actual.append(str(value))
        var expected: Array[String] = []
        if offer_kind == "technique":
            for content_id in _contents["techniques"].get("integration_statuses", {}):
                if str(_contents["techniques"]["integration_statuses"][content_id]) \
                        == FORMAL_TECHNIQUE_STATUS \
                        and not bool(_techniques_by_id.get(
                            str(content_id), {}).get("built_in", false)):
                    expected.append(str(content_id))
        elif offer_kind == "inner_skill":
            for content_id in _inner_skills_by_id:
                var definition: Dictionary = _inner_skills_by_id[content_id]
                if str(definition.get("status", "")) == FORMAL_CONTENT_STATUS \
                        and _is_integer(definition.get("price")):
                    expected.append(str(content_id))
        else:
            for content_id in _consumables_by_id:
                var definition: Dictionary = _consumables_by_id[content_id]
                if str(definition.get("status", "")) == FORMAL_CONTENT_STATUS \
                        and str(definition.get("kind", "")) == content_kind:
                    expected.append(str(content_id))
        actual.sort()
        expected.sort()
        if actual != expected:
            var label := offer_kind if content_kind == "" else content_kind
            _error(
                "practice_shop.normal.categories",
                "%s 白名单必须覆盖全部且仅覆盖正式内容" % label)

func _validate_practice_normal_candidate(
        content_id: String,
        offer_kind: String,
        content_kind: String,
        scope: String) -> void:
    if offer_kind == "technique":
        if not _techniques_by_id.has(content_id):
            _error(scope, "引用未知功法 %s" % content_id)
        elif bool(_techniques_by_id[content_id].get("built_in", false)):
            _error(scope, "内建功法 %s 不进入修习商店" % content_id)
        elif str(_contents["techniques"].get(
                "integration_statuses", {}).get(content_id, "")) \
                != FORMAL_TECHNIQUE_STATUS:
            _error(scope, "功法 %s 不是 formal_complete" % content_id)
        return
    if offer_kind == "inner_skill":
        if not _inner_skills_by_id.has(content_id):
            _error(scope, "引用未知内功 %s" % content_id)
        else:
            var inner_skill: Dictionary = _inner_skills_by_id[content_id]
            if str(inner_skill.get("status", "")) != FORMAL_CONTENT_STATUS:
                _error(scope, "内功 %s 不是 formal" % content_id)
            if not _is_integer(inner_skill.get("price")):
                _error(scope, "内功 %s 缺少正式价格" % content_id)
        return
    if not _consumables_by_id.has(content_id):
        _error(scope, "引用未知消耗品 %s" % content_id)
        return
    var consumable: Dictionary = _consumables_by_id[content_id]
    if str(consumable.get("kind", "")) != content_kind:
        _error(scope, "消耗品 %s 不属于 %s" % [content_id, content_kind])
    if str(consumable.get("status", "")) != FORMAL_CONTENT_STATUS:
        _error(scope, "消耗品 %s 不是 formal" % content_id)
    if not _is_integer(consumable.get("price")):
        _error(scope, "消耗品 %s 缺少正式价格" % content_id)

func _validate_practice_packs(definition: Dictionary) -> void:
    _validate_practice_slot_count(definition, "practice_shop.packs", 2)
    var candidates = definition.get("candidates")
    if not candidates is Array or candidates.size() != 9:
        _error("practice_shop.packs.candidates", "必须恰好包含九种正式补充包")
        return
    var seen: Dictionary = {}
    var tiers_by_kind: Dictionary = {}
    for index in range(candidates.size()):
        var pack = candidates[index]
        var scope := "practice_shop.packs.candidates[%d]" % index
        if not pack is Dictionary:
            _error(scope, "必须是对象")
            continue
        var pack_id := str(pack.get("id", ""))
        if pack_id == "" or seen.has(pack_id):
            _error(scope + ".id", "ID 不能为空且不得重复")
        seen[pack_id] = true
        if str(pack.get("name", "")) == "":
            _error(scope + ".name", "必须是非空字符串")
        if str(pack.get("kind", "")) != "consumable_pack":
            _error(scope + ".kind", "必须为 consumable_pack")
        var content_kind := str(pack.get("content_kind", ""))
        if content_kind not in PRACTICE_CONTENT_KINDS:
            _error(scope + ".content_kind", "必须为 pill、insight 或 curio")
        var price := int(pack.get("price", -1))
        var offer_count := int(pack.get("offer_count", -1))
        var choose_count := int(pack.get("choose_count", -1))
        if not _is_integer(pack.get("price")) or price not in [4, 6, 8]:
            _error(scope + ".price", "必须为 4、6 或 8")
        if not _is_integer(pack.get("offer_count")) or offer_count <= 0:
            _error(scope + ".offer_count", "必须是正整数")
        if not _is_integer(pack.get("choose_count")) \
                or choose_count <= 0 or choose_count > offer_count:
            _error(scope + ".choose_count", "必须在 1～offer_count 之间")
        _validate_pack_tier(content_kind, price, offer_count, choose_count, scope)
        var tier_key := "%s:%d" % [content_kind, price]
        if tiers_by_kind.has(tier_key):
            _error(scope, "同类补充包价格档重复：%s" % tier_key)
        tiers_by_kind[tier_key] = true
        var candidate_ids = pack.get("candidate_ids")
        if not candidate_ids is Array or candidate_ids.is_empty():
            _error(scope + ".candidate_ids", "必须是非空数组")
            continue
        var candidate_seen: Dictionary = {}
        for candidate_index in range(candidate_ids.size()):
            var content_id := str(candidate_ids[candidate_index])
            var candidate_scope := "%s.candidate_ids[%d]" % [scope, candidate_index]
            if content_id == "" or candidate_seen.has(content_id):
                _error(candidate_scope, "ID 不能为空且不得重复")
            candidate_seen[content_id] = true
            _validate_practice_normal_candidate(
                content_id, "consumable", content_kind, candidate_scope)
        var expected_ids: Array[String] = []
        for content_id in _consumables_by_id:
            var consumable: Dictionary = _consumables_by_id[content_id]
            if str(consumable.get("kind", "")) == content_kind \
                    and str(consumable.get("status", "")) == FORMAL_CONTENT_STATUS:
                expected_ids.append(str(content_id))
        expected_ids.sort()
        var actual_ids: Array[String] = []
        for value in candidate_ids:
            actual_ids.append(str(value))
        actual_ids.sort()
        if actual_ids != expected_ids:
            _error(scope + ".candidate_ids", "必须覆盖该类全部正式消耗品")
    for content_kind in PRACTICE_CONTENT_KINDS:
        for price in [4, 6, 8]:
            if not tiers_by_kind.has("%s:%d" % [content_kind, price]):
                _error("practice_shop.packs.candidates", "缺少 %s 的 %d 点档" % [content_kind, price])

func _validate_pack_tier(
        content_kind: String,
        price: int,
        offer_count: int,
        choose_count: int,
        scope: String) -> void:
    var expected_offer := 0
    var expected_choose := 1
    if content_kind in ["pill", "insight"]:
        expected_offer = 3 if price == 4 else 5
    elif content_kind == "curio":
        expected_offer = 2 if price == 4 else 4
    if price == 8:
        expected_choose = 2
    if offer_count != expected_offer or choose_count != expected_choose:
        _error(scope, "展示／选择数量不符合 %s 的 %d 点档" % [content_kind, price])

func _validate_practice_items(definition: Dictionary) -> void:
    _validate_practice_slot_count(definition, "practice_shop.items", 1)
    var candidate_ids = definition.get("candidate_ids")
    if not candidate_ids is Array:
        _error("practice_shop.items.candidate_ids", "必须是数组")
        return
    var seen: Dictionary = {}
    for index in range(candidate_ids.size()):
        var item_id := str(candidate_ids[index])
        var scope := "practice_shop.items.candidate_ids[%d]" % index
        if item_id == "" or seen.has(item_id):
            _error(scope, "ID 不能为空且不得重复")
        seen[item_id] = true
        if not _items_by_id.has(item_id):
            _error(scope, "引用未知物品 %s" % item_id)
            continue
        var item: Dictionary = _items_by_id[item_id]
        if str(item.get("status", "")) != FORMAL_CONTENT_STATUS:
            _error(scope, "candidate/design_only 物品不得进入正式商店：%s" % item_id)
        if not _is_integer(item.get("price")):
            _error(scope, "物品 %s 缺少正式价格" % item_id)
    var expected: Array[String] = []
    for item_id in _items_by_id:
        var item: Dictionary = _items_by_id[item_id]
        if str(item.get("status", "")) == FORMAL_CONTENT_STATUS \
                and _is_integer(item.get("price")):
            expected.append(str(item_id))
    var actual: Array[String] = []
    for item_id in candidate_ids:
        actual.append(str(item_id))
    expected.sort()
    actual.sort()
    if actual != expected:
        _error(
            "practice_shop.items.candidate_ids",
            "必须覆盖全部且仅覆盖具有正式价格的 formal 物品")

func _validate_practice_cross_area_ids(
        normal: Dictionary,
        packs: Dictionary,
        items: Dictionary) -> void:
    var seen: Dictionary = {}
    for category in normal.get("categories", []):
        if not category is Dictionary:
            continue
        for value in category.get("candidate_ids", []):
            seen[str(value)] = "normal"
    for pack in packs.get("candidates", []):
        if not pack is Dictionary:
            continue
        var pack_id := str(pack.get("id", ""))
        if pack_id != "" and seen.has(pack_id):
            _error(
                "practice_shop.packs.candidates",
                "跨区域重复展示 ID %s" % pack_id)
        seen[pack_id] = "packs"
    for value in items.get("candidate_ids", []):
        var item_id := str(value)
        if item_id != "" and seen.has(item_id):
            _error(
                "practice_shop.items.candidate_ids",
                "跨区域重复展示 ID %s" % item_id)
        seen[item_id] = "items"

func _validate_practice_slot_count(
        definition: Dictionary,
        scope: String,
        expected: int) -> void:
    if not _is_integer(definition.get("slot_count")) \
            or int(definition.get("slot_count", -1)) != expected:
        _error(scope + ".slot_count", "必须为 %d" % expected)

func _validate_sequences(definition: Dictionary, scope: String) -> void:
    var membership: Dictionary = _contents.get("techniques", {}).get("pool_membership", {})
    var statuses: Dictionary = _contents.get("techniques", {}).get(
        "integration_statuses", {})
    var is_production_sequence := (
        scope == "sequences"
        and str(_paths.get("sequences", "")) == PRODUCTION_SEQUENCES_PATH)
    var total_counts: Dictionary = {}
    for hand_id in HAND_IDS:
        if not definition.has(hand_id) or not definition[hand_id] is Array:
            _error(scope, "缺少牌型 %s 的序列数组" % hand_id)
            continue
        if is_production_sequence \
                and _techniques_by_id.is_empty() \
                and not definition[hand_id].is_empty():
            _error(
                "%s.%s" % [scope, hand_id],
                "正式功法为 0 时 production 序列必须为空")
        for index in range(definition[hand_id].size()):
            var technique_id := str(definition[hand_id][index])
            var item_scope := "%s.%s[%d]" % [scope, hand_id, index]
            if technique_id == "":
                _error(item_scope, "功法 ID 不能为空")
                continue
            if not _techniques_by_id.has(technique_id):
                _error(item_scope, "引用未知功法 %s" % technique_id)
                continue
            var technique: Dictionary = _techniques_by_id[technique_id]
            total_counts[technique_id] = int(total_counts.get(
                technique_id, 0)) + 1
            var exact_hands: Array = technique.get("eligible_hand_ids", [])
            if (not exact_hands.is_empty() and not exact_hands.has(hand_id)) \
                    or (exact_hands.is_empty() and not membership.get(
                        hand_id, []).has(technique.get("pool", ""))):
                _error(item_scope, "功法 %s 不属于 %s 的合格共用池" % [technique_id, hand_id])
            if is_production_sequence:
                var status := str(statuses.get(technique_id, "missing"))
                if status != FORMAL_TECHNIQUE_STATUS:
                    _error(
                        item_scope,
                        "功法 %s 当前接入档位为 %s，production 只允许 %s" % [
                            technique_id, status, FORMAL_TECHNIQUE_STATUS])
    for technique_id_value in total_counts:
        var technique_id := str(technique_id_value)
        var technique: Dictionary = _techniques_by_id.get(technique_id, {})
        var limit = technique.get("base_loadout_limit", 1)
        if limit is int and int(total_counts[technique_id]) > int(limit):
            _error(
                scope,
                "功法 %s 全局装配 %d 次，超过基础上限 %d" % [
                    technique_id, int(total_counts[technique_id]), int(limit)])
    for key in definition:
        if str(key) != "version" and not HAND_IDS.has(str(key)):
            _error(scope, "包含未知精确牌型 %s" % str(key))

func _validate_scripted_battle(definition: Dictionary) -> void:
    var scope := "scripted_battle"
    _required_id(definition, scope)
    if not definition.get("name") is String or str(definition.get("name", "")) == "":
        _error(scope, "name 必须是非空字符串")
    var player = definition.get("player")
    var enemy = definition.get("enemy")
    if not player is Dictionary:
        _error(scope + ".player", "必须是对象")
    else:
        _validate_loadout_references(player, scope + ".player")
    if not enemy is Dictionary:
        _error(scope + ".enemy", "必须是对象")
    else:
        _validate_loadout_references(enemy, scope + ".enemy")
        if not _is_integer(enemy.get("life")) or int(enemy.get("life", 0)) <= 0:
            _error(scope + ".enemy", "life 必须是正整数")
        _validate_card_references(enemy.get("opening_hand"), scope + ".enemy.opening_hand")
        _validate_card_references(enemy.get("draw_order"), scope + ".enemy.draw_order")
        var scenario_sequences = enemy.get("sequences")
        if not scenario_sequences is Dictionary:
            _error(scope + ".enemy.sequences", "必须是对象")
        else:
            _validate_sequences(scenario_sequences, scope + ".enemy.sequences")
        _validate_enemy_ai_policy(enemy.get("ai"), scope + ".enemy.ai")
    var rounds = definition.get("rounds")
    if not rounds is Array:
        _error(scope + ".rounds", "必须是数组")
    else:
        for round_index in range(rounds.size()):
            var round_value = rounds[round_index]
            var round_scope := "%s.rounds[%d]" % [scope, round_index]
            if not round_value is Dictionary or not round_value.get("actions") is Array:
                _error(round_scope, "必须包含 actions 数组")
                continue
            for action_index in range(round_value["actions"].size()):
                _validate_card_references(
                    round_value["actions"][action_index],
                    "%s.actions[%d]" % [round_scope, action_index])

func _validate_enemy_ai_policy(value, scope: String) -> void:
    if not value is Dictionary:
        _error(scope, "必须是对象")
        return
    for field in value:
        var field_name := str(field)
        if field_name == "direction_weights":
            var weights = value[field]
            if not weights is Dictionary:
                _error(scope + ".direction_weights", "必须是对象")
                continue
            for direction_value in weights:
                var direction := str(direction_value)
                if direction not in ENEMY_AI_DIRECTIONS:
                    _error(scope + ".direction_weights", "未知战略方向 %s" % direction)
                elif not _is_number(weights[direction_value]) \
                        or float(weights[direction_value]) < 0.0:
                    _error(
                        "%s.direction_weights.%s" % [scope, direction],
                        "必须是非负数值")
            continue
        if field_name == "next_technique_bias":
            var biases = value[field]
            if not biases is Dictionary:
                _error(scope + ".next_technique_bias", "必须是对象")
                continue
            for technique_id_value in biases:
                var technique_id := str(technique_id_value)
                if not _techniques_by_id.has(technique_id):
                    _error(
                        scope + ".next_technique_bias",
                        "引用未知功法 %s" % technique_id)
                if not _is_number(biases[technique_id_value]):
                    _error(
                        "%s.next_technique_bias.%s" % [scope, technique_id],
                        "必须是数值")
            continue
        if not ENEMY_AI_NUMBER_FIELDS.has(field_name):
            _error(scope, "未知 AI 策略字段 %s" % field_name)
        elif not _is_number(value[field]):
            _error("%s.%s" % [scope, field_name], "必须是数值")
    if value.has("danger_life_ratio"):
        var ratio := float(value["danger_life_ratio"])
        if ratio < 0.0 or ratio > 1.0:
            _error(scope + ".danger_life_ratio", "必须位于 0～1")
    if value.has("candidate_limit"):
        if not value["candidate_limit"] is int \
                or int(value["candidate_limit"]) < 1 \
                or int(value["candidate_limit"]) > 5:
            _error(scope + ".candidate_limit", "必须是 1～5 的整数")
    for ratio_field in ["diversity_penalty", "future_value_discount"]:
        if value.has(ratio_field):
            var ratio := float(value[ratio_field])
            if ratio < 0.0 or ratio > 1.0:
                _error(scope + "." + ratio_field, "必须位于 0～1")

func _validate_loadout_references(loadout: Dictionary, scope: String) -> void:
    var inner_skill_ids = loadout.get("inner_skills", [])
    if not inner_skill_ids is Array:
        _error(scope + ".inner_skills", "必须是数组")
    else:
        for value in inner_skill_ids:
            if not _inner_skills_by_id.has(str(value)):
                _error(scope + ".inner_skills", "引用未知内功 %s" % str(value))
    var consumable_ids = loadout.get("consumables", [])
    if not consumable_ids is Array:
        _error(scope + ".consumables", "必须是数组")
    else:
        for value in consumable_ids:
            if not _consumables_by_id.has(str(value)):
                _error(scope + ".consumables", "引用未知消耗品 %s" % str(value))

func _validate_card_references(values, scope: String) -> void:
    if not values is Array:
        _error(scope, "必须是卡牌 ID 数组")
        return
    for index in range(values.size()):
        var card_id := str(values[index])
        if not _card_ids.has(card_id):
            _error("%s[%d]" % [scope, index], "引用未知真气 %s" % card_id)

func _validate_node_content(definition: Dictionary) -> void:
    var node_types = definition.get("node_types")
    if not node_types is Dictionary:
        _error("node_content.node_types", "必须是对象")
        return
    var content_ids: Dictionary = {}
    for node_type in node_types:
        var value = node_types[node_type]
        var scope := "node_content.node_types.%s" % str(node_type)
        if not value is Dictionary:
            _error(scope, "必须是对象")
            continue
        var route := str(value.get("route", ""))
        if not ROUTES.has(route):
            _error(scope, "未知调度路由 %s" % route)
        var content_id := str(value.get("content_id", ""))
        if content_id == "":
            _error(scope, "content_id 必须是非空字符串")
        elif content_ids.has(content_id):
            _error(scope, "content_id 重复：%s" % content_id)
        else:
            content_ids[content_id] = true
        if not value.get("title") is String or str(value.get("title", "")) == "":
            _error(scope, "title 必须是非空字符串")
        if route == "battle":
            if value.has("interaction"):
                _error(scope + ".interaction", "battle 路由不得携带 interaction 配置")
            var battle = value.get("battle")
            if not battle is Dictionary:
                _error(scope + ".battle", "战斗路由必须包含 battle 对象")
                continue
            var scenario_path := str(battle.get("scenario_path", ""))
            var entry_kind := str(battle.get("entry_kind", "scripted"))
            if entry_kind not in ["formal", "scripted"]:
                _error(scope + ".battle", "entry_kind 必须是 formal 或 scripted")
            if scenario_path == "":
                _error(scope + ".battle", "scenario_path 不能为空")
            elif not FileAccess.file_exists(scenario_path):
                _error(scope + ".battle", "场景数据文件不存在：%s" % scenario_path)
            var catalog_scenario_path := str(_paths.get("scripted_battle", ""))
            if catalog_scenario_path != "" and scenario_path != catalog_scenario_path:
                _error(scope + ".battle", "场景路径未纳入统一内容目录：%s" % scenario_path)
            if not battle.get("use_enemy_ai") is bool:
                _error(scope + ".battle", "use_enemy_ai 必须是布尔值")
        elif route == "interaction":
            if value.has("battle"):
                _error(scope + ".battle", "interaction 路由不得携带 battle 配置")
            var interaction = value.get("interaction")
            if not interaction is Dictionary:
                _error(scope + ".interaction", "interaction 路由必须包含 interaction 对象")
                continue
            var kind := str(interaction.get("kind", ""))
            if kind == "" or not _is_snake_case(kind):
                _error(scope + ".interaction.kind", "必须是非空稳定 snake_case ID")
            elif not _node_interaction_registry.has_handler(kind):
                _error(scope + ".interaction.kind", "未注册的节点交互 kind：%s" % kind)
            var configuration = interaction.get("configuration")
            if not configuration is Dictionary:
                _error(scope + ".interaction.configuration", "必须是对象")
            elif _node_interaction_registry.has_handler(kind):
                _node_interaction_registry.handler_for(kind).validate_configuration(
                    configuration.duplicate(true), self)
        elif route == "placeholder":
            if value.has("interaction"):
                _error(scope + ".interaction", "placeholder 路由不得携带 interaction 执行配置")

func _validate_map_rules(definition: Dictionary, node_content: Dictionary) -> void:
    var positive_fields := [
        "width", "route_rows", "path_count", "common_ancestor_search_depth",
        "minimum_remerge_gap", "boss_variant_count", "acts",
    ]
    for field in positive_fields:
        if not _is_integer(definition.get(field)) or int(definition.get(field, 0)) <= 0:
            _error("map_rules.%s" % field, "必须是正整数")
    if not _is_integer(definition.get("boss_column")):
        _error("map_rules.boss_column", "必须是整数")
    elif int(definition.get("boss_column", -1)) < 0 or int(definition.get("boss_column", -1)) >= int(definition.get("width", 0)):
        _error("map_rules.boss_column", "必须位于地图宽度范围内")
    for field in ["visual_jitter_x", "visual_jitter_y"]:
        if not _is_number(definition.get(field)) or float(definition.get(field, -1)) < 0:
            _error("map_rules.%s" % field, "必须是非负数值")
    for field in ["sibling_types_must_differ", "legacy_common_ancestor_comparison"]:
        if not definition.get(field) is bool:
            _error("map_rules.%s" % field, "必须是布尔值")
    var node_types: Dictionary = node_content.get("node_types", {})
    var weights = definition.get("weights")
    if not weights is Dictionary:
        _error("map_rules.weights", "必须是对象")
    else:
        var total := 0
        for node_type in weights:
            if not _is_integer(weights[node_type]) or int(weights[node_type]) < 0:
                _error("map_rules.weights.%s" % str(node_type), "权重必须是非负整数")
            total += int(weights[node_type])
        if total != 100:
            _error("map_rules.weights", "权重总和必须为 100")
    var display_types = definition.get("display_types")
    if not display_types is Dictionary:
        _error("map_rules.display_types", "必须是对象")
    else:
        for source_type in display_types:
            if weights is Dictionary and not weights.has(source_type):
                _error("map_rules.display_types", "源类型未在 weights 中定义：%s" % str(source_type))
            if not node_types.has(str(display_types[source_type])):
                _error("map_rules.display_types", "显示节点类型未配置：%s" % str(display_types[source_type]))
    var fixed_rows = definition.get("fixed_rows")
    if not fixed_rows is Dictionary:
        _error("map_rules.fixed_rows", "必须是对象")
    else:
        for row in fixed_rows:
            if not str(row).is_valid_int():
                _error("map_rules.fixed_rows", "楼层键必须是整数文本：%s" % str(row))
            elif int(row) < 0 or int(row) >= int(definition.get("route_rows", 0)):
                _error("map_rules.fixed_rows", "固定楼层越界：%s" % str(row))
            if not node_types.has(str(fixed_rows[row])):
                _error("map_rules.fixed_rows", "固定楼层引用未知节点类型 %s" % str(fixed_rows[row]))
    for field in ["pool_order", "no_direct_repeat"]:
        var values = definition.get(field)
        if not values is Array:
            _error("map_rules.%s" % field, "必须是数组")
            continue
        for node_type in values:
            if weights is Dictionary and not weights.has(str(node_type)):
                _error("map_rules.%s" % field, "引用未定义权重类型 %s" % str(node_type))
    for field in ["minimum_random_row", "maximum_random_row"]:
        var limits = definition.get(field)
        if not limits is Dictionary:
            _error("map_rules.%s" % field, "必须是对象")
            continue
        for node_type in limits:
            if weights is Dictionary and not weights.has(str(node_type)):
                _error("map_rules.%s" % field, "引用未定义权重类型 %s" % str(node_type))
            if not _is_integer(limits[node_type]):
                _error("map_rules.%s.%s" % [field, str(node_type)], "必须是整数")
    var offsets = definition.get("act_seed_offsets")
    if not offsets is Array or offsets.size() != int(definition.get("acts", 0)):
        _error("map_rules.act_seed_offsets", "数量必须与 acts 相同")
    var chest_acts = definition.get("boss_chest_acts")
    if not chest_acts is Array:
        _error("map_rules.boss_chest_acts", "必须是数组")
    else:
        for act in chest_acts:
            if not _is_integer(act) or int(act) < 1 or int(act) >= int(definition.get("acts", 0)):
                _error("map_rules.boss_chest_acts", "Boss 宝箱层数越界：%s" % str(act))
    for required_type in ["combat", "event", "elite", "rest", "treasure", "boss"]:
        if not node_types.has(required_type):
            _error("node_content.node_types", "地图引用所需节点类型未配置：%s" % required_type)

func _required_id(value: Dictionary, scope: String) -> String:
    if not value.get("id") is String or str(value.get("id", "")) == "":
        _error(scope, "id 必须是非空字符串")
        return ""
    return str(value["id"])

func _validate_name(value: Dictionary, scope: String) -> void:
    if not value.get("name") is String or str(value.get("name", "")) == "":
        _error(scope, "name 必须是非空字符串")

func _validate_categories(values, required_ids: Array, capacities: Dictionary, scope: String) -> void:
    if not values is Array:
        _error(scope, "必须是数组")
        return
    var seen: Dictionary = {}
    for index in range(values.size()):
        var value = values[index]
        var item_scope := "%s[%d]" % [scope, index]
        if not value is Dictionary:
            _error(item_scope, "必须是对象")
            continue
        var category_id := _required_id(value, item_scope)
        _register_unique(seen, category_id, item_scope, value)
        if not required_ids.has(category_id):
            _error(item_scope, "未知类别 %s" % category_id)
            continue
        if not _is_integer(value.get("capacity")) or int(value.get("capacity", 0)) != int(capacities[category_id]):
            _error(item_scope, "capacity 必须为 %d" % int(capacities[category_id]))
    _validate_required_ids(seen, required_ids, scope)

func _validate_reshape_categories(values) -> void:
    var scope := "card_states.reshape_categories"
    var capacities := {"origin": 1, "enhancement": 1, "imprint": 1, "other": -1}
    var replaceable := {"origin": false, "enhancement": true, "imprint": true, "other": true}
    _validate_categories(values, RESHAPE_CATEGORY_IDS, capacities, scope)
    if not values is Array:
        return
    for index in range(values.size()):
        var value = values[index]
        if not value is Dictionary:
            continue
        var category_id := str(value.get("id", ""))
        if not replaceable.has(category_id):
            continue
        if not value.get("replaceable") is bool \
                or bool(value.get("replaceable", false)) != bool(replaceable[category_id]):
            _error(
                "%s[%d].replaceable" % [scope, index],
                "必须为 %s" % str(replaceable[category_id]))

func _validate_temporary_reshape_subslots(values) -> void:
    var required := ["enhancement", "attribute", "rank"]
    _validate_categories(
        values,
        required,
        {"enhancement": 1, "attribute": 1, "rank": 1},
        "card_states.temporary_reshape_subslots")
    if not values is Array:
        return
    for index in range(values.size()):
        var value = values[index]
        if not value is Dictionary:
            continue
        if not value.get("replaceable") is bool \
                or not bool(value.get("replaceable", false)):
            _error(
                "card_states.temporary_reshape_subslots[%d].replaceable" % index,
                "临时重塑子槽必须允许替换")

func _validate_void_burst_contract() -> void:
    var void_burst: Dictionary = _enhancements_by_id.get("void_burst", {})
    var battle_start_void := 0
    for behavior_value in void_burst.get("behaviors", []):
        var behavior: Dictionary = behavior_value
        if str(behavior.get("trigger", "")) == "turn_end_final" \
                or str(behavior.get("handler", "")) == "temporarily_remove_if_in_hand":
            _error(
                "card_states.enhancements.void_burst.behaviors",
                "虚暴不得直接在回合结束消散")
        if str(behavior.get("trigger", "")) == "battle_start" \
                and str(behavior.get("handler", "")) == "apply_anomaly" \
                and str(behavior.get("category", "")) == "mark" \
                and str(behavior.get("anomaly", "")) == "void":
            battle_start_void += 1
    if battle_start_void != 1:
        _error(
            "card_states.enhancements.void_burst.behaviors",
            "虚暴必须且只能声明一次战斗开始施加虚无")
    var flawless: Dictionary = _enhancements_by_id.get("flawless", {})
    var blocked_ids: Array = []
    for behavior_value in flawless.get("behaviors", []):
        var behavior: Dictionary = behavior_value
        if str(behavior.get("handler", "")) == "block_anomaly_application":
            blocked_ids.assign(behavior.get("anomaly_ids", []))
            if not behavior.get("categories", []).is_empty():
                _error(
                    "card_states.enhancements.flawless.behaviors",
                    "无漏不得按整个异状类别阻止")
    blocked_ids.sort()
    if blocked_ids != ["acupoint_block", "poison", "vulnerability"]:
        _error(
            "card_states.enhancements.flawless.behaviors",
            "无漏阻止名单必须精确为 poison/vulnerability/acupoint_block")

func _validate_named_definitions(values, required_ids: Array, index: Dictionary, scope: String) -> void:
    if not values is Array:
        _error(scope, "必须是数组")
        return
    for value_index in range(values.size()):
        var value = values[value_index]
        var item_scope := "%s[%d]" % [scope, value_index]
        if not value is Dictionary:
            _error(item_scope, "必须是对象")
            continue
        var content_id := _required_id(value, item_scope)
        _register_unique(index, content_id, item_scope, value)
        _validate_name(value, item_scope)
    _validate_required_ids(index, required_ids, scope)

func _validate_only_ids(index: Dictionary, allowed_ids: Array, scope: String) -> void:
    for content_id in index:
        if not allowed_ids.has(str(content_id)):
            _error(scope, "当前批次不允许未实现定义 %s" % str(content_id))

func _validate_no_retired_reshape_ids(definition: Dictionary) -> void:
    for field in ["origins", "enhancements", "imprints", "other_reshapes"]:
        var values = definition.get(field, [])
        if not values is Array:
            continue
        for index in range(values.size()):
            var value = values[index]
            if value is Dictionary and RETIRED_RESHAPE_IDS.has(str(value.get("id", ""))):
                _error(
                    "card_states.%s[%d].id" % [field, index],
                    "旧重塑 ID 已废弃：%s" % str(value.get("id", "")))

func _validate_required_ids(index: Dictionary, required_ids: Array, scope: String) -> void:
    for content_id in required_ids:
        if not index.has(content_id):
            _error(scope, "缺少定义 %s" % content_id)

func _validate_id_list(values, required_ids: Array, scope: String) -> void:
    if not values is Array:
        _error(scope, "必须是数组")
        return
    var seen: Dictionary = {}
    for value in values:
        var content_id := str(value)
        if not required_ids.has(content_id):
            _error(scope, "包含未知 ID %s" % content_id)
        elif seen.has(content_id):
            _error(scope, "ID 重复：%s" % content_id)
        seen[content_id] = true
    _validate_required_ids(seen, required_ids, scope)

func _register_unique(index: Dictionary, content_id: String, scope: String, definition) -> void:
    if content_id == "":
        return
    if index.has(content_id):
        _error(scope, "ID 重复：%s" % content_id)
        return
    index[content_id] = definition

func _is_number(value) -> bool:
    return value is int or value is float

func _is_integer(value) -> bool:
    return _is_number(value) and float(value) == floor(float(value))

func _is_snake_case(value: String) -> bool:
    var pattern := RegEx.new()
    pattern.compile("^[a-z][a-z0-9_]*$")
    return pattern.search(value) != null

func _error(scope: String, message: String) -> void:
    errors.append("%s: %s" % [scope, message])

func report_error(scope: String, message: String) -> void:
    _error(scope, message)

func has_content_id(content_type: String, content_id: String) -> bool:
    return not content_definition(content_type, content_id).is_empty()

func content_definition(content_type: String, content_id: String) -> Dictionary:
    match content_type:
        "card":
            return {"id": content_id} if _card_ids.has(content_id) else {}
        "origin":
            return _origins_by_id.get(content_id, {}).duplicate(true)
        "enhancement":
            return _enhancements_by_id.get(content_id, {}).duplicate(true)
        "imprint":
            return _imprints_by_id.get(content_id, {}).duplicate(true)
        "other_reshape":
            return _other_reshapes_by_id.get(content_id, {}).duplicate(true)
        "consumable":
            if _consumables_by_id.has(content_id):
                return _consumables_by_id[content_id].duplicate(true)
            for value in _contents.get("consumables", {}).get("consumables", []):
                if value is Dictionary and str(value.get("id", "")) == content_id:
                    return value.duplicate(true)
        "technique":
            return _techniques_by_id.get(content_id, {}).duplicate(true)
        "inner_skill":
            return _inner_skills_by_id.get(content_id, {}).duplicate(true)
        "item":
            return _items_by_id.get(content_id, {}).duplicate(true)
    return {}

func is_formally_obtainable(content_type: String, content_id: String) -> bool:
    match content_type:
        "technique":
            return not bool(content_definition("technique", content_id).get(
                "built_in", false)) and str(_contents.get("techniques", {}).get(
                "integration_statuses", {}).get(content_id, "")) \
                == FORMAL_TECHNIQUE_STATUS
        "inner_skill", "consumable", "item":
            return str(content_definition(content_type, content_id).get(
                "status", "")) == FORMAL_CONTENT_STATUS
    return false

func content_ids_by_kind(content_type: String, kind: String) -> Array[String]:
    var result: Array[String] = []
    if content_type != "consumable":
        return result
    for value in _contents.get("consumables", {}).get("consumables", []):
        if value is Dictionary and str(value.get("kind", "")) == kind:
            result.append(str(value.get("id", "")))
    result.sort()
    return result

func base_deck_definition() -> Dictionary:
    return _contents.get("base_deck", {}).duplicate(true)
