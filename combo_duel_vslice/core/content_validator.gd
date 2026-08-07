class_name ContentValidator
extends RefCounted

const CONTENT_KEYS := [
    "base_deck",
    "starter_builds",
    "battle_statuses",
    "card_states",
    "techniques",
    "inner_skills",
    "consumables",
    "node_rewards",
    "map_rules",
    "node_content",
    "scripted_battle",
    "sequences",
]
const HAND_IDS := [
    "high_card", "pair", "two_pair", "three_kind", "straight", "flush",
    "full_house", "four_kind", "straight_flush",
]
# 五条的固定倍率尚未确认，因此暂不进入可识别牌型；功法数据仍可先声明并测试五条分支。
const TECHNIQUE_BRANCH_HAND_IDS := HAND_IDS + ["five_kind"]
const POOL_IDS := [
    "high", "pair_two_pair", "three_full_house", "four_five", "straight", "flush",
]
const ATTRIBUTE_IDS := ["wind", "forest", "fire", "mountain"]
const RESHAPE_CATEGORY_IDS := ["enhancement", "finish", "imprint", "other"]
const ANOMALY_CATEGORY_IDS := ["mark", "poison", "state", "other"]
const CARD_STATE_CARRIER_IDS := ["card", "inner_skill"]
const REQUIRED_ENHANCEMENT_IDS := [
    "bonus", "multiplier", "wild", "glass", "steel", "stone", "gold", "lucky",
]
const REQUIRED_FINISH_IDS := ["foil", "holographic", "polychrome", "negative"]
const REQUIRED_IMPRINT_IDS := ["gold", "red", "blue", "purple"]
const REQUIRED_ANOMALY_IDS := [
    "lethal_poison", "stagnant_poison", "qi_dissipation",
    "vulnerability", "acupoint_block", "forbidden", "wind_mark", "wind_lure",
    "returning_wind", "turbulence", "qi_severance", "purification",
]
const REQUIRED_ACTOR_STATUS_IDS := [
    "gu_mark", "momentum", "qi_intake", "steal_wind", "full_sleeve", "bound_sleeve",
    "four_symbols_harmony",
]
const ANOMALY_ON_APPLY_POLICIES := ["", "suppress_existing_effects"]
const MARK_LIFECYCLE_EVENTS := ["draw", "explicit_discard", "enter_discard", "turn_end", "battle_end"]
const RANK_SPECS := [
    ["2", 2, 2], ["3", 3, 3], ["4", 4, 4], ["5", 5, 5],
    ["6", 6, 6], ["7", 7, 7], ["8", 8, 8], ["9", 9, 9],
    ["10", 10, 10], ["J", 11, 11], ["Q", 12, 11], ["K", 13, 11],
    ["A", 14, 12],
]
const BATTLE_EFFECT_OPS := [
    "damage",
    "multi_damage",
    "defense",
    "defense_from_noncontributing_qi",
    "draw",
    "draw_if_captured_attribute",
    "discard_random",
    "discard_all_hand",
    "apply_random_card_anomaly",
    "add_stack",
    "add_target_stack",
    "add_stack_per_captured_card",
    "set_stack_minimum",
    "gain_extra_action",
    "register_attack_counter_delay",
    "select_cards",
    "move_captured",
    "move_query",
    "draw_filtered",
    "draw_to_limit",
    "apply_card_anomaly_to_captured",
    "capture_metadata",
    "register_turn_end_stack",
    "register_played_return",
    "register_delayed_effects",
    "retrigger_current_hand_technique",
    "capture_query",
    "swap_hands",
]
const CONSUMABLE_EFFECT_OPS := [
    "gain_insight", "apply_enhancement", "apply_random_finish",
]
const AMOUNT_KINDS := [
    "constant", "power", "power_fraction", "n60", "hand_map", "max",
    "add", "multiply", "divide_floor", "divide_ceil", "capture_count", "capture_qi_sum", "capture_attribute_qi_sum",
    "capture_attribute_count", "capture_non_attribute_count", "hand_count",
    "target_hand_count", "hand_limit",
    "conditional",
    "power_scaled_by_zone_anomaly",
]
const ROUTES := ["battle", "placeholder"]
const REWARD_KINDS := [
    "experience", "card", "technique", "inner_skill",
    "consumable", "reshape", "special",
]
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
]

var errors: Array[String] = []
var warnings: Array[String] = []
var _contents: Dictionary = {}
var _paths: Dictionary = {}
var _card_ids: Dictionary = {}
var _enhancements_by_id: Dictionary = {}
var _finishes_by_id: Dictionary = {}
var _imprints_by_id: Dictionary = {}
var _other_reshapes_by_id: Dictionary = {}
var _anomalies_by_id: Dictionary = {}
var _actor_statuses_by_id: Dictionary = {}
var _techniques_by_id: Dictionary = {}
var _inner_skills_by_id: Dictionary = {}
var _consumables_by_id: Dictionary = {}

func validate(contents: Dictionary, paths: Dictionary = {}) -> Dictionary:
    errors.clear()
    warnings.clear()
    _contents = contents
    _paths = paths
    _card_ids.clear()
    _enhancements_by_id.clear()
    _finishes_by_id.clear()
    _imprints_by_id.clear()
    _other_reshapes_by_id.clear()
    _anomalies_by_id.clear()
    _actor_statuses_by_id.clear()
    _techniques_by_id.clear()
    _inner_skills_by_id.clear()
    _consumables_by_id.clear()
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
    _validate_node_rewards(_contents["node_rewards"])
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
            if str(entry.get("kind", "")) == "experience" \
                    and (not _is_integer(entry.get("amount")) or int(entry.get("amount", 0)) < 0):
                _error(scope + ".amount", "历练数量必须是非负整数")
    for spec in [["combat", 3], ["elite", 4], ["boss", 5]]:
        var entries: Array = rewards.get(spec[0], [])
        var experience := 0
        for entry in entries:
            if entry is Dictionary and str(entry.get("kind", "")) == "experience":
                experience += int(entry.get("amount", 0))
        if experience != int(spec[1]):
            _error("node_rewards.node_rewards.%s" % spec[0], "基础战斗历练必须为 %d" % int(spec[1]))

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
    for index in range(values.size()):
        var value = values[index]
        var scope := "battle_statuses.actor_statuses[%d]" % index
        if not value is Dictionary:
            _error(scope, "必须是对象")
            continue
        var status_id := _required_id(value, scope)
        _register_unique(_actor_statuses_by_id, status_id, scope, value)
        _validate_name(value, scope)
        if str(value.get("duration", "")) != "battle":
            _error(scope + ".duration", "当前角色状态必须持续一场战斗")
        if not value.get("stacking") is bool or not bool(value.get("stacking", false)):
            _error(scope + ".stacking", "当前角色状态必须允许叠层")
        if not _is_integer(value.get("maximum")) or int(value.get("maximum", 0)) == 0 \
                or int(value.get("maximum", 0)) < -1:
            _error(scope + ".maximum", "必须为 -1 或正整数")
        var clear_on = value.get("clear_on")
        if not clear_on is Array or not clear_on.has("battle_end"):
            _error(scope + ".clear_on", "必须包含 battle_end")
    _validate_required_ids(
        _actor_statuses_by_id,
        REQUIRED_ACTOR_STATUS_IDS,
        "battle_statuses.actor_statuses")

func _validate_card_states(definition: Dictionary) -> void:
    _validate_categories(
        definition.get("reshape_categories"),
        RESHAPE_CATEGORY_IDS,
        {"enhancement": 1, "finish": 1, "imprint": 1, "other": -1},
        "card_states.reshape_categories")
    _validate_categories(
        definition.get("anomaly_categories"),
        ANOMALY_CATEGORY_IDS,
        {"mark": -1, "poison": 1, "state": 1, "other": -1},
        "card_states.anomaly_categories")
    _validate_named_definitions(
        definition.get("enhancements"),
        REQUIRED_ENHANCEMENT_IDS,
        _enhancements_by_id,
        "card_states.enhancements")
    _validate_named_definitions(
        definition.get("imprints"),
        REQUIRED_IMPRINT_IDS,
        _imprints_by_id,
        "card_states.imprints")
    _validate_named_definitions(
        definition.get("other_reshapes"),
        [],
        _other_reshapes_by_id,
        "card_states.other_reshapes")

    var finishes = definition.get("finishes")
    if not finishes is Array:
        _error("card_states.finishes", "必须是数组")
    else:
        for index in range(finishes.size()):
            var value = finishes[index]
            var scope := "card_states.finishes[%d]" % index
            if not value is Dictionary:
                _error(scope, "必须是对象")
                continue
            var content_id := _required_id(value, scope)
            _register_unique(_finishes_by_id, content_id, scope, value)
            _validate_name(value, scope)
            var carriers = value.get("allowed_carriers")
            if not carriers is Array or carriers.is_empty():
                _error(scope + ".allowed_carriers", "必须是非空数组")
            else:
                for carrier in carriers:
                    if not CARD_STATE_CARRIER_IDS.has(str(carrier)):
                        _error(scope + ".allowed_carriers", "未知载体 %s" % str(carrier))
        _validate_required_ids(_finishes_by_id, REQUIRED_FINISH_IDS, "card_states.finishes")
        if _finishes_by_id.has("negative") and _finishes_by_id["negative"].get("allowed_carriers", []).has("card"):
            _error("card_states.finishes.negative", "负片不能用于真气")

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
            _validate_name(value, scope)
            var category := str(value.get("category", ""))
            if not ANOMALY_CATEGORY_IDS.has(category):
                _error(scope, "引用未知异状类别 %s" % category)
            if not value.get("remove_on_enter_discard") is bool:
                _error(scope, "remove_on_enter_discard 必须是布尔值")
            elif category in ["poison", "state"] and not bool(value["remove_on_enter_discard"]):
                _error(scope, "毒和状态进入弃牌堆时必须默认移除")
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
            if on_apply == "suppress_existing_effects" and category != "mark":
                _error(scope, "失效既有效果策略只允许异状标记")
        _validate_required_ids(_anomalies_by_id, REQUIRED_ANOMALY_IDS, "card_states.anomalies")
    _validate_other_reshape_battle_start_anomalies()

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
        if not value.get("name") is String or str(value.get("name", "")) == "":
            _error(scope, "name 必须是非空字符串")
        var pool_id := str(value.get("pool", ""))
        if not POOL_IDS.has(pool_id):
            _error(scope, "引用未知功法池 %s" % pool_id)
        _validate_cooperation(value.get("cooperation", {}), scope + ".cooperation")
        if not value.get("special") is bool:
            _error(scope, "special 必须是布尔值")
        _validate_effects(value.get("effects"), BATTLE_EFFECT_OPS, scope + ".effects")

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
    var post_commit = value.get("post_commit", {})
    if not post_commit is Dictionary:
        _error(scope + ".post_commit", "必须是对象")
    elif str(post_commit.get("destination", "own_discard")) not in ["own_discard", "target_draw_pile_top"]:
        _error(scope + ".post_commit.destination", "引用未知协同牌提交位置")

func _validate_inner_skills(definition: Dictionary) -> void:
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
        _validate_effects(value.get("effects"), BATTLE_EFFECT_OPS, scope + ".effects")

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
        if not value.get("kind") is String or str(value.get("kind", "")) == "":
            _error(scope, "kind 必须是非空字符串")
        if not _is_integer(value.get("price")) or int(value.get("price", -1)) < 0:
            _error(scope, "price 必须是非负整数")
        var targeting = value.get("targeting")
        if not targeting is Dictionary:
            _error(scope + ".targeting", "必须是对象")
        else:
            if not targeting.get("zone") is String:
                _error(scope + ".targeting", "zone 必须是字符串")
            if not _is_integer(targeting.get("minimum")) or not _is_integer(targeting.get("maximum")):
                _error(scope + ".targeting", "minimum/maximum 必须是整数")
            elif int(targeting["minimum"]) < 0 or int(targeting["maximum"]) < int(targeting["minimum"]):
                _error(scope + ".targeting", "目标数量范围无效")
        _validate_effects(value.get("effects"), CONSUMABLE_EFFECT_OPS, scope + ".effects")
        if value.get("effects") is Array:
            for effect_index in range(value["effects"].size()):
                var effect = value["effects"][effect_index]
                if not effect is Dictionary:
                    continue
                if effect.get("op") == "gain_insight":
                    var hand_id := str(effect.get("hand", ""))
                    if not HAND_IDS.has(hand_id):
                        _error("%s.effects[%d]" % [scope, effect_index], "引用未知精确牌型 %s" % hand_id)
                    var pools = effect.get("pools")
                    if not pools is Array:
                        _error("%s.effects[%d]" % [scope, effect_index], "pools 必须是数组")
                    else:
                        for pool_id in pools:
                            if not POOL_IDS.has(str(pool_id)):
                                _error("%s.effects[%d]" % [scope, effect_index], "引用未知功法池 %s" % str(pool_id))
                elif effect.get("op") == "apply_enhancement":
                    var enhancement_id := str(effect.get("enhancement", ""))
                    if not _enhancements_by_id.has(enhancement_id):
                        _error("%s.effects[%d]" % [scope, effect_index], "引用未知强化 %s" % enhancement_id)
                elif effect.get("op") == "apply_random_finish":
                    var finish_ids = effect.get("finishes")
                    if not finish_ids is Array or finish_ids.is_empty():
                        _error("%s.effects[%d]" % [scope, effect_index], "finishes 必须是非空数组")
                    else:
                        for finish_id_value in finish_ids:
                            var finish_id := str(finish_id_value)
                            if not _finishes_by_id.has(finish_id):
                                _error("%s.effects[%d]" % [scope, effect_index], "引用未知品相 %s" % finish_id)
                            elif not _finishes_by_id[finish_id].get("allowed_carriers", []).has("card"):
                                _error("%s.effects[%d]" % [scope, effect_index], "品相 %s 不能用于真气" % finish_id)

func _validate_sequences(definition: Dictionary, scope: String) -> void:
    var membership: Dictionary = _contents.get("techniques", {}).get("pool_membership", {})
    for hand_id in HAND_IDS:
        if not definition.has(hand_id) or not definition[hand_id] is Array:
            _error(scope, "缺少牌型 %s 的序列数组" % hand_id)
            continue
        var seen: Dictionary = {}
        for index in range(definition[hand_id].size()):
            var technique_id := str(definition[hand_id][index])
            var item_scope := "%s.%s[%d]" % [scope, hand_id, index]
            if technique_id == "":
                _error(item_scope, "功法 ID 不能为空")
                continue
            if seen.has(technique_id):
                _error(item_scope, "同一序列重复引用功法 %s" % technique_id)
            seen[technique_id] = true
            if not _techniques_by_id.has(technique_id):
                _error(item_scope, "引用未知功法 %s" % technique_id)
                continue
            var technique: Dictionary = _techniques_by_id[technique_id]
            if not membership.get(hand_id, []).has(technique.get("pool", "")):
                _error(item_scope, "功法 %s 不属于 %s 的合格共用池" % [technique_id, hand_id])
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

func _validate_effects(values, allowed_ops: Array, scope: String) -> void:
    if not values is Array or values.is_empty():
        _error(scope, "必须是非空效果数组")
        return
    var choice_ids: Dictionary = {}
    for index in range(values.size()):
        var effect = values[index]
        var effect_scope := "%s[%d]" % [scope, index]
        if not effect is Dictionary:
            _error(effect_scope, "必须是对象")
            continue
        var op := str(effect.get("op", ""))
        if not allowed_ops.has(op):
            _error(effect_scope, "未知效果操作码 %s" % op)
        for field in ["amount", "count", "damage"]:
            if effect.has(field) and effect[field] is Dictionary:
                _validate_amount_spec(effect[field], effect_scope + "." + field)
        if op == "multi_damage" and (not _is_integer(effect.get("segments")) or int(effect.get("segments", 0)) <= 0):
            _error(effect_scope, "segments 必须是正整数")
        if op == "select_cards":
            _validate_choice_effect(effect, effect_scope)
            var choice_id := str(effect.get("choice_id", ""))
            if choice_id != "" and choice_ids.has(choice_id):
                _error(effect_scope + ".choice_id", "同一效果链中的 choice_id 不能重复")
            choice_ids[choice_id] = true
        if op == "register_delayed_effects":
            _validate_effects(
                effect.get("effects"),
                BATTLE_EFFECT_OPS,
                effect_scope + ".effects")
        if op in ["apply_random_card_anomaly", "apply_card_anomaly_to_captured"] \
                and not effect.has("random_options"):
            var anomaly_id := str(effect.get("anomaly", ""))
            var category := str(effect.get("category", ""))
            if not _anomalies_by_id.has(anomaly_id):
                _error(effect_scope, "引用未知真气异状 %s" % anomaly_id)
            elif str(_anomalies_by_id[anomaly_id].get("category", "")) != category:
                _error(effect_scope, "异状 %s 不属于类别 %s" % [anomaly_id, category])
        if op in ["add_stack", "add_target_stack", "add_stack_per_captured_card", "set_stack_minimum", "register_turn_end_stack"]:
            _validate_actor_status_reference(
                effect.get("stack"),
                effect_scope + ".stack")
        var after_each_stack = effect.get("after_each_stack")
        if after_each_stack is Dictionary and not after_each_stack.is_empty():
            _validate_actor_status_reference(
                after_each_stack.get("stack"),
                effect_scope + ".after_each_stack.stack")
        var condition = effect.get("when", {})
        if condition is Dictionary and condition.has("pure_attribute") and not ATTRIBUTE_IDS.has(str(condition["pure_attribute"])):
            _error(effect_scope + ".when", "引用未知属性 %s" % str(condition["pure_attribute"]))

func _validate_actor_status_reference(value, scope: String) -> void:
    var status_id := str(value)
    if not _actor_statuses_by_id.has(status_id):
        _error(scope, "引用未知角色状态 %s" % status_id)

func _validate_choice_effect(effect: Dictionary, scope: String) -> void:
    if not effect.get("choice_id") is String or str(effect.get("choice_id", "")) == "":
        _error(scope + ".choice_id", "必须是非空字符串")
    if not effect.get("query") is Dictionary:
        _error(scope + ".query", "必须是对象")
    else:
        _validate_target_query(effect["query"], scope + ".query")
    for field in ["minimum", "maximum"]:
        var value = effect.get(field)
        if value is Dictionary:
            _validate_amount_spec(value, scope + "." + field)
        elif not _is_integer(value) or int(value) < 0:
            _error(scope + "." + field, "必须是非负整数或数值规格")
    if _is_integer(effect.get("minimum")) and _is_integer(effect.get("maximum")) \
            and int(effect.get("maximum")) < int(effect.get("minimum")):
        _error(scope, "maximum 不能小于 minimum")
    if str(effect.get("insufficient_policy", "")) not in ["use_available", "skip", "fail"]:
        _error(scope + ".insufficient_policy", "必须明确为 use_available、skip 或 fail")
    if effect.has("chooser") and str(effect.get("chooser")) not in ["actor", "target"]:
        _error(scope + ".chooser", "必须为 actor 或 target")

func _validate_target_query(query: Dictionary, scope: String) -> void:
    if str(query.get("side", "actor")) not in ["actor", "target"]:
        _error(scope + ".side", "必须为 actor 或 target")
    if str(query.get("zone", "hand")) not in ["hand", "draw_pile", "staging", "discard_pile"]:
        _error(scope + ".zone", "引用未知牌区")
    if str(query.get("order", "zone")) not in ["zone", "top", "bottom", "random"]:
        _error(scope + ".order", "必须为 zone、top、bottom 或 random")
    if query.has("limit"):
        if query["limit"] is Dictionary:
            _validate_amount_spec(query["limit"], scope + ".limit")
        elif not _is_integer(query["limit"]) \
                or int(query["limit"]) == 0 \
                or int(query["limit"]) < -1:
            _error(scope + ".limit", "必须为 -1、正整数或数值规格")
    var filters = query.get("filters", {})
    if not filters is Dictionary:
        _error(scope + ".filters", "必须是对象")
        return
    if str(filters.get("card_kind", "any")) not in ["any", "normal", "stone"]:
        _error(scope + ".filters.card_kind", "必须为 any、normal 或 stone")
    for field in ["attributes", "exclude_attributes", "rank_names", "rank_orders", "definition_ids"]:
        if filters.has(field) and not filters[field] is Array:
            _error(scope + ".filters." + field, "必须是数组")
    for attribute_field in ["attributes", "exclude_attributes"]:
        if not filters.has(attribute_field):
            continue
        for attribute in filters[attribute_field]:
            if str(attribute) not in ATTRIBUTE_IDS:
                _error(scope + ".filters." + attribute_field, "引用未知属性 %s" % str(attribute))
    if filters.has("temporary") and not filters["temporary"] is bool:
        _error(scope + ".filters.temporary", "必须是布尔值")
    if filters.has("has_any_reshape") and not filters["has_any_reshape"] is bool:
        _error(scope + ".filters.has_any_reshape", "必须是布尔值")
    if filters.has("anomaly"):
        _validate_target_state_filter(
            filters["anomaly"],
            ANOMALY_CATEGORY_IDS,
            scope + ".filters.anomaly")
    if filters.has("reshape"):
        _validate_target_state_filter(
            filters["reshape"],
            RESHAPE_CATEGORY_IDS,
            scope + ".filters.reshape")

func _validate_target_state_filter(value, category_ids: Array, scope: String) -> void:
    if not value is Dictionary:
        _error(scope, "必须是对象")
        return
    if str(value.get("category", "")) not in category_ids:
        _error(scope + ".category", "引用未知类别")
    if value.has("present") and not value["present"] is bool:
        _error(scope + ".present", "必须是布尔值")

func _validate_amount_spec(spec: Dictionary, scope: String) -> void:
    var kind := str(spec.get("kind", ""))
    if not AMOUNT_KINDS.has(kind):
        _error(scope, "未知数值规格 kind %s" % kind)
        return
    match kind:
        "constant":
            if not _is_number(spec.get("value")):
                _error(scope, "constant.value 必须是数值")
        "power_fraction":
            if not _is_number(spec.get("numerator")):
                _error(scope, "power_fraction.numerator 必须是数值")
            if not _is_number(spec.get("denominator")) or float(spec.get("denominator", 0)) <= 0:
                _error(scope, "power_fraction.denominator 必须是正数")
            if spec.has("minimum") and not _is_number(spec["minimum"]):
                _error(scope, "power_fraction.minimum 必须是数值")
        "hand_map":
            var values = spec.get("values")
            if not values is Dictionary:
                _error(scope, "hand_map.values 必须是对象")
            else:
                for hand_id in values:
                    if not TECHNIQUE_BRANCH_HAND_IDS.has(str(hand_id)):
                        _error(scope, "hand_map 引用未知精确牌型 %s" % str(hand_id))
                    if not _is_number(values[hand_id]):
                        _error(scope, "hand_map.%s 必须是数值" % str(hand_id))
        "max", "add", "multiply":
            var values = spec.get("values")
            if not values is Array or values.is_empty():
                _error(scope, "max.values 必须是非空数组")
            else:
                for index in range(values.size()):
                    if not values[index] is Dictionary:
                        _error("%s.values[%d]" % [scope, index], "必须是数值规格对象")
                    else:
                        _validate_amount_spec(values[index], "%s.values[%d]" % [scope, index])
        "divide_floor", "divide_ceil":
            for field in ["value", "divisor"]:
                if not spec.get(field) is Dictionary:
                    _error(scope + "." + field, "必须是数值规格对象")
                else:
                    _validate_amount_spec(spec[field], scope + "." + field)
        "capture_count", "capture_qi_sum", "capture_attribute_qi_sum", "capture_attribute_count", "capture_non_attribute_count":
            if not spec.get("capture") is String or str(spec.get("capture", "")) == "":
                _error(scope + ".capture", "必须是非空捕获键")
            if kind in ["capture_attribute_qi_sum", "capture_attribute_count", "capture_non_attribute_count"] \
                    and str(spec.get("attribute", "")) not in ATTRIBUTE_IDS:
                _error(scope + ".attribute", "引用未知属性")
        "conditional":
            for field in ["then", "else"]:
                if not spec.get(field) is Dictionary:
                    _error(scope + "." + field, "必须是数值规格对象")
                else:
                    _validate_amount_spec(spec[field], scope + "." + field)
        "power_scaled_by_zone_anomaly":
            if str(spec.get("category", "")) not in ANOMALY_CATEGORY_IDS:
                _error(scope + ".category", "引用未知异状类别")

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

func _error(scope: String, message: String) -> void:
    errors.append("%s: %s" % [scope, message])
