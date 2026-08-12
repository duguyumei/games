class_name PassiveRuleHandlerRegistry
extends RefCounted

const HandlerScript = preload("res://core/passives/passive_rule_handler.gd")
const OnPlayEffectsHandlerScript = preload(
    "res://core/passives/on_play_effects_passive_handler.gd")
const CounterDefinitionScript = preload(
    "res://core/passives/passive_counter_definition.gd")
const BattleCounterDefinitionScript = preload(
    "res://core/passives/battle_passive_counter_definition.gd")

const BATTLE_TIMING_HOOKS := [
    "battle_start",
    "round_start",
    "turn_start",
    "before_normal_draw",
    "after_normal_draw",
    "action_window_start",
    "group_end",
    "action_window_end",
    "turn_end",
    "battle_end",
]

const BATTLE_COMMITTED_EVENT_HOOKS := [
    "action_confirmed",
    "action_resolved",
    "card_drawn",
    "card_entered_discard",
    "card_explicitly_discarded",
    "damage_resolved",
    "defense_gained",
]

const BATTLE_INT_QUERY_HOOKS := [
    "hand_limit_query",
    "power_base_fixed_query",
    "power_multiplier_bonus_query",
    "power_fixed_query",
    "power_amp_percent_query",
    "outgoing_damage_query",
    "incoming_damage_query",
    "defense_gain_query",
    "defense_retention_percent_query",
]

const BATTLE_POLICY_QUERY_HOOKS := [
    "hand_evaluation_options_query",
    "card_identity_query",
    "card_play_permission_query",
    "explicit_discard_permission_query",
    "technique_activation_permission_query",
    "cooperation_permission_query",
]

const HOOKS := [
    "action_preview",
    "action_resolve",
    "battle_start",
    "round_start",
    "turn_start",
    "before_normal_draw",
    "after_normal_draw",
    "action_window_start",
    "group_end",
    "action_window_end",
    "turn_end",
    "battle_end",
    "inner_skill_capacity_query",
    "passive_invocation_plan_query",
    "practice_price_query",
    "inner_skill_forget_value_query",
    "meditation_cost_query",
    "pack_offer_count_query",
    "pack_choose_count_query",
    "technique_loadout_copy_limit_query",
    "practice_opened",
    "practice_purchase_committed",
    "practice_pack_opened",
    "meditation_committed",
    "inner_skill_forgotten",
    "battle_completed",
    "node_completed",
    "action_confirmed",
    "action_resolved",
    "card_drawn",
    "card_entered_discard",
    "card_explicitly_discarded",
    "damage_resolved",
    "defense_gained",
    "hand_limit_query",
    "power_base_fixed_query",
    "power_multiplier_bonus_query",
    "power_fixed_query",
    "power_amp_percent_query",
    "outgoing_damage_query",
    "incoming_damage_query",
    "defense_gain_query",
    "defense_retention_percent_query",
    "hand_evaluation_options_query",
    "card_identity_query",
    "card_play_permission_query",
    "explicit_discard_permission_query",
    "technique_activation_permission_query",
    "cooperation_permission_query",
]

var _handlers: Dictionary = {}
var _known_hooks: Dictionary = {}
var _registration_errors: Array[Dictionary] = []
var _id_pattern := RegEx.new()

func _init(register_defaults: bool = true, effect_registry = null) -> void:
    _id_pattern.compile("^[a-z][a-z0-9_]*$")
    for hook in HOOKS:
        _known_hooks[str(hook)] = true
    if register_defaults:
        register_handler(OnPlayEffectsHandlerScript.new(effect_registry))

func register_handler(handler) -> bool:
    if not (handler is HandlerScript):
        _record_error("invalid_handler", "被动行为处理器必须继承 PassiveRuleHandler", "")
        return false
    var id := str(handler.behavior_id())
    if id == "":
        _record_error("empty_id", "被动行为 ID 不能为空", "")
        return false
    if _id_pattern.search(id) == null:
        _record_error("invalid_id", "被动行为 ID 必须使用稳定 snake_case：%s" % id, id)
        return false
    if _handlers.has(id):
        _record_error("duplicate_id", "被动行为 ID 重复注册：%s" % id, id)
        return false
    var hooks: Array = handler.supported_hooks()
    if hooks.is_empty():
        _record_error("empty_hooks", "被动行为必须声明至少一个 hook：%s" % id, id)
        return false
    var seen: Dictionary = {}
    for hook_value in hooks:
        var hook := str(hook_value)
        if _id_pattern.search(hook) == null:
            _record_error("invalid_hook", "被动行为 %s 的 hook 必须使用稳定 snake_case：%s" % [id, hook], id)
            return false
        if seen.has(hook):
            _record_error("duplicate_hook", "被动行为 %s 重复声明 hook：%s" % [id, hook], id)
            return false
        seen[hook] = true
    for hook in seen:
        _known_hooks[str(hook)] = true
    _handlers[id] = handler
    return true

func has_handler(behavior_id: String) -> bool:
    return _handlers.has(behavior_id)

func handler(behavior_id: String):
    return _handlers.get(behavior_id)

func handler_ids() -> Array[String]:
    var result: Array[String] = []
    for id in _handlers:
        result.append(str(id))
    result.sort()
    return result

func has_hook(hook: String) -> bool:
    return _known_hooks.has(hook)

func hook_ids() -> Array[String]:
    var result: Array[String] = []
    for hook in _known_hooks:
        result.append(str(hook))
    result.sort()
    return result

func registration_errors() -> Array[Dictionary]:
    return _registration_errors.duplicate(true)

func validate_configuration(behavior_id: String, configuration: Dictionary) -> Array[String]:
    var current = handler(behavior_id)
    if current == null:
        return ["未注册的被动行为：%s" % behavior_id] as Array[String]
    return current.validate_configuration(configuration)

func counter_definitions(
        behavior_id: String,
        configuration: Dictionary) -> Array:
    var current = handler(behavior_id)
    if current == null:
        return []
    var result: Array = []
    var values = current.counter_definitions(configuration)
    if not values is Array:
        return result
    for value in values:
        if value is CounterDefinitionScript:
            result.append(value)
        elif value is Dictionary:
            result.append(CounterDefinitionScript.new().configure(value))
    return result

func validate_counter_definitions(
        behavior_id: String,
        configuration: Dictionary) -> Array[String]:
    var current = handler(behavior_id)
    if current == null:
        return ["未注册的被动行为：%s" % behavior_id] as Array[String]
    var values = current.counter_definitions(configuration)
    if not values is Array:
        return ["counter_definitions 必须返回数组"] as Array[String]
    var errors: Array[String] = []
    var seen: Dictionary = {}
    for index in range(values.size()):
        var value = values[index]
        if not value is Dictionary and not value is CounterDefinitionScript:
            errors.append("counter_definitions[%d] 必须是对象或 PassiveCounterDefinition" % index)
            continue
        if value is Dictionary:
            for required_field in ["counter_id", "default_value", "minimum", "retention_policy"]:
                if not value.has(required_field):
                    errors.append("counter_definitions[%d] 缺少 %s" % [index, required_field])
            if value.has("default_value") and not value["default_value"] is int:
                errors.append("counter_definitions[%d].default_value 必须是整数" % index)
            if value.has("minimum") and not value["minimum"] is int:
                errors.append("counter_definitions[%d].minimum 必须是整数" % index)
            if value.has("maximum") and not value["maximum"] is int:
                errors.append("counter_definitions[%d].maximum 必须是整数" % index)
        var definition = (
            value
            if value is CounterDefinitionScript
            else CounterDefinitionScript.new().configure(value))
        for message in definition.validation_errors():
            errors.append("counter_definitions[%d]：%s" % [index, message])
        if seen.has(definition.counter_id):
            errors.append("重复声明 counter_id：%s" % definition.counter_id)
        seen[definition.counter_id] = true
    return errors

func battle_timing_bindings(
        behavior_id: String,
        configuration: Dictionary) -> Array[Dictionary]:
    var current = handler(behavior_id)
    if current == null:
        return []
    var values = current.battle_timing_bindings(configuration)
    if not values is Array:
        return []
    var result: Array[Dictionary] = []
    for value in values:
        if value is Dictionary:
            result.append({
                "hook": str(value.get("hook", "")),
                "order": value.get("order"),
            })
    return result

func validate_battle_timing_bindings(
        behavior_id: String,
        configuration: Dictionary) -> Array[String]:
    var current = handler(behavior_id)
    if current == null:
        return ["未注册的被动行为：%s" % behavior_id] as Array[String]
    var values = current.battle_timing_bindings(configuration)
    if not values is Array:
        return ["battle_timing_bindings 必须返回数组"] as Array[String]
    var errors: Array[String] = []
    var seen: Dictionary = {}
    var supported: Array[String] = current.supported_hooks()
    for index in range(values.size()):
        var value = values[index]
        if not value is Dictionary:
            errors.append("battle_timing_bindings[%d] 必须是对象" % index)
            continue
        var hook := str(value.get("hook", ""))
        if hook not in BATTLE_TIMING_HOOKS:
            errors.append(
                "battle_timing_bindings[%d].hook 不是正式战斗时点：%s" % [
                    index, hook])
        elif not supported.has(hook):
            errors.append(
                "battle_timing_bindings[%d].hook 未在 supported_hooks 声明：%s" % [
                    index, hook])
        if not value.get("order") is int:
            errors.append("battle_timing_bindings[%d].order 必须是整数" % index)
            continue
        var binding_key := "%s|%d" % [hook, int(value["order"])]
        if seen.has(binding_key):
            errors.append("重复声明战斗时点绑定：%s" % binding_key)
        seen[binding_key] = true
    return errors

func battle_counter_definitions(
        behavior_id: String,
        configuration: Dictionary) -> Array:
    var current = handler(behavior_id)
    if current == null:
        return []
    var result: Array = []
    var values = current.battle_counter_definitions(configuration)
    if not values is Array:
        return result
    for value in values:
        if value is BattleCounterDefinitionScript:
            result.append(value)
        elif value is Dictionary:
            result.append(BattleCounterDefinitionScript.new().configure(value))
    return result

func validate_battle_counter_definitions(
        behavior_id: String,
        configuration: Dictionary) -> Array[String]:
    var current = handler(behavior_id)
    if current == null:
        return ["未注册的被动行为：%s" % behavior_id] as Array[String]
    var values = current.battle_counter_definitions(configuration)
    if not values is Array:
        return ["battle_counter_definitions 必须返回数组"] as Array[String]
    var errors: Array[String] = []
    var seen: Dictionary = {}
    for index in range(values.size()):
        var value = values[index]
        if not value is Dictionary and not value is BattleCounterDefinitionScript:
            errors.append(
                "battle_counter_definitions[%d] 必须是对象或 BattlePassiveCounterDefinition" % index)
            continue
        if value is Dictionary:
            for required_field in [
                    "counter_id", "default_value", "minimum", "reset_scope"]:
                if not value.has(required_field):
                    errors.append(
                        "battle_counter_definitions[%d] 缺少 %s" % [
                            index, required_field])
            if value.has("default_value") and not value["default_value"] is int:
                errors.append(
                    "battle_counter_definitions[%d].default_value 必须是整数" % index)
            if value.has("minimum") and not value["minimum"] is int:
                errors.append(
                    "battle_counter_definitions[%d].minimum 必须是整数" % index)
            if value.has("maximum") and not value["maximum"] is int:
                errors.append(
                    "battle_counter_definitions[%d].maximum 必须是整数" % index)
        var definition = (
            value
            if value is BattleCounterDefinitionScript
            else BattleCounterDefinitionScript.new().configure(value))
        for message in definition.validation_errors():
            errors.append("battle_counter_definitions[%d]：%s" % [index, message])
        if seen.has(definition.counter_id):
            errors.append("重复声明 battle counter_id：%s" % definition.counter_id)
        seen[definition.counter_id] = true
    return errors

func execute(behavior_id: String, hook: String, context, configuration: Dictionary) -> Dictionary:
    var current = handler(behavior_id)
    if current == null:
        return {"success": false, "reason": "未注册的被动行为：%s" % behavior_id}
    if not current.supported_hooks().has(hook):
        return {
            "success": false,
            "reason": "被动行为 %s 不支持 hook %s" % [behavior_id, hook],
        }
    return current.handle(hook, context, configuration)

func _record_error(code: String, message: String, behavior_id: String) -> void:
    _registration_errors.append({
        "code": code,
        "behavior_id": behavior_id,
        "message": message,
    })
