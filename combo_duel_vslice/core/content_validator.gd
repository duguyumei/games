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
const EnemyDeckEncodingScript = preload("res://core/enemy_deck_encoding.gd")

const CONTENT_KEYS := [
    "base_deck",
    "starter_builds",
    "battle_statuses",
    "card_states",
    "techniques",
    "inner_skills",
    "consumables",
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
    "high", "pair", "three", "straight", "bomb",
]
const TECHNIQUE_INTEGRATION_STATUSES := [
    "formal_complete", "partial_integration", "regression_fixture",
]
const FORMAL_TECHNIQUE_STATUS := "formal_complete"
const PRODUCTION_SEQUENCES_PATH := "res://data/production_sequences.json"
const ATTRIBUTE_IDS := ["wind", "forest", "fire", "mountain"]
const RESHAPE_CATEGORY_IDS := ["origin", "enhancement", "imprint", "other"]
const ANOMALY_CATEGORY_IDS := ["mark", "poison", "state", "other"]
const REQUIRED_ORIGIN_IDS := ["attribute_change", "rank_change", "awakening"]
const REQUIRED_ENHANCEMENT_IDS := [
    "qi_boost", "momentum", "hunyuan", "void_burst", "flawless",
    "rock_solid", "hidden_gold", "opportunity",
]
const REQUIRED_IMPRINT_IDS := ["enlightenment", "alchemy", "innate"]
const RETIRED_RESHAPE_IDS := [
    "bonus", "multiplier", "wild", "glass", "steel", "stone", "gold", "lucky",
    "foil", "holographic", "polychrome", "negative", "red", "blue", "purple",
]
const ANOMALY_ON_APPLY_POLICIES := ["", "suppress_existing_effects"]
const MARK_LIFECYCLE_EVENTS := ["draw", "explicit_discard", "enter_discard", "turn_end", "battle_end"]
const CARD_STATUS_TRIGGERS := [
    "play_attempt", "played", "draw", "explicit_discard", "enter_discard", "turn_end",
]
const CARD_STATUS_MODIFIER_IDS := [
    "qi_contribution_percent",
    "poison_contribution_reduction_percent",
    "outgoing_damage_percent",
    "incoming_damage_percent",
]
const ACTOR_STATUS_TRIGGERS := [
    "after_normal_draw",
    "opponent_card_drawn",
    "played_card_anomaly_resolved",
    "technique_card_flow",
    "attack_segment_received",
]
const RANK_SPECS := [
    ["2", 2, 2], ["3", 3, 3], ["4", 4, 4], ["5", 5, 5],
    ["6", 6, 6], ["7", 7, 7], ["8", 8, 8], ["9", 9, 9],
    ["10", 10, 10], ["J", 11, 11], ["Q", 12, 11], ["K", 13, 11],
    ["A", 14, 12],
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
var _actor_statuses_by_id: Dictionary = {}
var _techniques_by_id: Dictionary = {}
var _inner_skills_by_id: Dictionary = {}
var _consumables_by_id: Dictionary = {}
var _effect_specs: EffectSpecValidator
var _effect_registry
var _run_effect_registry
var _card_reshape_registry
var _consumable_effect_registry
var _status_behavior_ids: Array[String] = []

func _init(
        effect_registry_override = null,
        run_effect_registry_override = null,
        card_reshape_registry_override = null,
        consumable_effect_registry_override = null) -> void:
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
    _effect_specs = EffectSpecValidatorScript.new(
        Callable(self, "_error"),
        {
            "attribute_ids": ATTRIBUTE_IDS,
            "anomaly_category_ids": ANOMALY_CATEGORY_IDS,
            "reshape_category_ids": RESHAPE_CATEGORY_IDS,
            "hand_ids": TECHNIQUE_BRANCH_HAND_IDS,
        },
        _effect_registry)
    ## 索引在校验过程中增量建立（异状先于功法校验注册）。这里传入的是同一份
    ## 字典引用，因此后续 clear 与写入都对效果校验器可见；这两个索引只允许
    ## clear 和写入，不能整体重新赋值，否则引用会断开。
    _effect_specs.use_indexes(_anomalies_by_id, _actor_statuses_by_id)

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
    _contents = contents
    _paths = paths
    _card_ids.clear()
    _origins_by_id.clear()
    _enhancements_by_id.clear()
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
        _validate_status_behaviors(value, ACTOR_STATUS_TRIGGERS, scope)
        _validate_status_modifiers(value, scope)

func _validate_card_states(definition: Dictionary) -> void:
    _validate_reshape_categories(definition.get("reshape_categories"))
    _validate_categories(
        definition.get("anomaly_categories"),
        ANOMALY_CATEGORY_IDS,
        {"mark": -1, "poison": 1, "state": 1, "other": -1},
        "card_states.anomaly_categories")
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
            var runtime_payload = value.get("runtime_payload", {})
            if not runtime_payload is Dictionary:
                _error(scope + ".runtime_payload", "必须是对象")
            else:
                for attribute_id in runtime_payload.get("attribute_aliases", []):
                    if not ATTRIBUTE_IDS.has(str(attribute_id)):
                        _error(scope + ".runtime_payload.attribute_aliases", "未知属性 %s" % str(attribute_id))
            _validate_status_behaviors(value, CARD_STATUS_TRIGGERS, scope)
            _validate_card_status_modifiers(value, scope)
        _validate_card_status_behavior_references()
        _validate_card_reshape_behavior_references()
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

func _validate_status_modifiers(definition: Dictionary, scope: String) -> void:
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
        if str(modifier.get("id", "")) == "":
            _error(modifier_scope + ".id", "必须是非空字符串")
        if not modifier.has("presence") and not modifier.has("per_stack"):
            _error(modifier_scope, "必须声明 presence 或 per_stack")
        for field in ["presence", "per_stack"]:
            if modifier.has(field) and not _is_integer(modifier[field]):
                _error(modifier_scope + "." + field, "必须是整数")
        var source_kinds = modifier.get("source_kinds", [])
        if not source_kinds is Array:
            _error(modifier_scope + ".source_kinds", "必须是数组")
        else:
            for source_kind in source_kinds:
                if not source_kind is String or str(source_kind) == "":
                    _error(modifier_scope + ".source_kinds", "必须只包含非空字符串")

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
        _effect_specs.validate_effects(value.get("effects"), "battle", scope + ".effects")

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

func _validate_practice_shop(definition: Dictionary) -> void:
    for field in ["normal_slots", "pack_slots", "coupon_slots"]:
        if not _is_integer(definition.get(field)) or int(definition.get(field, 0)) < 0:
            _error("practice_shop.%s" % field, "必须是非负整数")
    for group in ["normal_candidates", "pack_candidates", "coupon_candidates"]:
        var values = definition.get(group)
        if not values is Array:
            _error("practice_shop.%s" % group, "必须是数组")
            continue
        var seen: Dictionary = {}
        for index in range(values.size()):
            var value = values[index]
            var scope := "practice_shop.%s[%d]" % [group, index]
            if not value is Dictionary:
                _error(scope, "必须是对象")
                continue
            var content_id := str(value.get("id", ""))
            if content_id == "" or seen.has(content_id):
                _error(scope + ".id", "ID 不能为空且不得重复")
            seen[content_id] = true
            var kind := str(value.get("kind", ""))
            if kind == "technique":
                if not _techniques_by_id.has(content_id):
                    _error(scope, "引用未知功法 %s" % content_id)
                elif str(_contents["techniques"].get("integration_statuses", {}).get(content_id, "")) != FORMAL_TECHNIQUE_STATUS:
                    _error(scope, "功法 %s 不是 formal_complete" % content_id)
            elif kind == "consumable":
                if not _consumables_by_id.has(content_id):
                    _error(scope, "引用未知消耗品 %s" % content_id)
            elif kind == "insight_pack":
                var candidate_ids = value.get("candidate_ids", [])
                if not candidate_ids is Array or candidate_ids.is_empty():
                    _error(scope + ".candidate_ids", "心得包必须有候选内容")
                else:
                    for candidate_id_value in candidate_ids:
                        if not _consumables_by_id.has(str(candidate_id_value)):
                            _error(scope + ".candidate_ids", "引用未知消耗品 %s" % str(candidate_id_value))
            elif kind != "coupon":
                _error(scope + ".kind", "未知修习商品类型 %s" % kind)

func _validate_sequences(definition: Dictionary, scope: String) -> void:
    var membership: Dictionary = _contents.get("techniques", {}).get("pool_membership", {})
    var statuses: Dictionary = _contents.get("techniques", {}).get(
        "integration_statuses", {})
    var is_production_sequence := (
        scope == "sequences"
        and str(_paths.get("sequences", "")) == PRODUCTION_SEQUENCES_PATH)
    for hand_id in HAND_IDS:
        if not definition.has(hand_id) or not definition[hand_id] is Array:
            _error(scope, "缺少牌型 %s 的序列数组" % hand_id)
            continue
        if is_production_sequence \
                and hand_id != "five_kind" \
                and definition[hand_id].is_empty():
            _error(
                "%s.%s" % [scope, hand_id],
                "production 正式开局序列不能为空")
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
            if is_production_sequence:
                var status := str(statuses.get(technique_id, "missing"))
                if status != FORMAL_TECHNIQUE_STATUS:
                    _error(
                        item_scope,
                        "功法 %s 当前接入档位为 %s，production 只允许 %s" % [
                            technique_id, status, FORMAL_TECHNIQUE_STATUS])
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
    return {}

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
