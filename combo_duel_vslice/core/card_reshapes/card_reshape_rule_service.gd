class_name CardReshapeRuleService
extends RefCounted

const RegistryScript = preload("res://core/card_reshapes/card_reshape_behavior_registry.gd")
const ContextScript = preload("res://core/card_reshapes/card_reshape_behavior_context.gd")

var content_catalog_ref: WeakRef
var registry
var _definitions: Dictionary = {}

func _init(catalog = null, registry_override = null) -> void:
    content_catalog_ref = weakref(catalog) if catalog != null else null
    registry = registry_override if registry_override != null else RegistryScript.new()
    if catalog == null:
        _load_fallback_definitions()

static func fallback():
    return new()

func bind_card(card) -> void:
    if card == null:
        return
    card.reshape_rule_service = self

func definition(category: String, reshape_id: String) -> Dictionary:
    var catalog = content_catalog_ref.get_ref() if content_catalog_ref != null else null
    if catalog != null:
        return catalog.get_by_id(_content_type(category), reshape_id)
    return _definitions.get(category, {}).get(reshape_id, {}).duplicate(true)

func apply_reshape(card, category: String, reshape_id: String, payload: Dictionary = {}) -> Dictionary:
    var definition_value := definition(category, reshape_id)
    if definition_value.is_empty():
        return {"success": true, "results": []}
    bind_card(card)
    var results: Array[Dictionary] = []
    for behavior_value in definition_value.get("behaviors", []):
        var behavior: Dictionary = behavior_value
        if str(behavior.get("trigger", "")) != "reshape_applied":
            continue
        results.append(_execute(behavior, card, 0, "", payload))
    for result in results:
        if not bool(result.get("success", false)):
            return {"success": false, "results": results, "reason": str(result.get("reason", "重塑行为执行失败"))}
    return {"success": true, "results": results}

func card_contribution(card, base_value: int) -> int:
    return _run_numeric(card, "card_contribution", base_value)

func technique_multiplier_bonus(card) -> int:
    return _run_numeric(card, "technique_multiplier", 0)

func power_amp_percent(card) -> int:
    return _run_numeric(card, "power_amp", 0)

func effective_qi_value(card, calculation_context: Dictionary = {}) -> int:
    return maxi(0, _run_numeric(
        card, "effective_qi", int(card.qi_value), calculation_context))

func dispatch_battle_event(
        card,
        trigger: String,
        values: Dictionary = {}) -> Array[Dictionary]:
    var results: Array[Dictionary] = []
    for entry in _behavior_entries(card, trigger):
        var context_values := values.duplicate()
        context_values.merge({
            "card": card,
            "trigger": trigger,
        }, true)
        results.append(registry.execute(
            entry["behavior"], ContextScript.new().configure(context_values)))
    return results

func matches_attribute(card, attribute_id: String) -> bool:
    for definition_value in _active_definitions(card):
        for behavior_value in definition_value.get("behaviors", []):
            var behavior: Dictionary = behavior_value
            if str(behavior.get("trigger", "")) != "attribute_check":
                continue
            var result := _execute(behavior, card, 0, attribute_id)
            if bool(result.get("matches", false)):
                return true
    return false

func can_apply_anomaly(
        card,
        anomaly_category: String = "",
        anomaly_id: String = "") -> Dictionary:
    for definition_value in _active_definitions(card):
        for behavior_value in definition_value.get("behaviors", []):
            var behavior: Dictionary = behavior_value
            if str(behavior.get("trigger", "")) != "anomaly_apply":
                continue
            var result: Dictionary = registry.execute(
                behavior,
                ContextScript.new().configure({
                    "card": card,
                    "anomaly_category": anomaly_category,
                    "anomaly_id": anomaly_id,
                }))
            if bool(result.get("blocked", false)):
                result["allowed"] = false
                return result
    return {"allowed": true}

func can_explicit_discard(card) -> Dictionary:
    for result in dispatch_battle_event(card, "explicit_discard_attempt"):
        if bool(result.get("blocked", false)):
            return {
                "allowed": false,
                "reason": str(result.get("reason", "此真气不能被明确弃掉")),
            }
    return {"allowed": true}

func has_card_kind(card, kind: String) -> bool:
    if kind == "normal":
        return effective_qi_value(card) != 0
    return true

func _run_numeric(
        card,
        trigger: String,
        initial: int,
        calculation_context: Dictionary = {}) -> int:
    var value := initial
    for entry in _behavior_entries(card, trigger):
        var behavior: Dictionary = entry["behavior"]
        value = int(_execute(
            behavior, card, value, "", {}, calculation_context).get("value", value))
    return value

func _execute(
        behavior: Dictionary,
        card,
        value: int = 0,
        attribute_id: String = "",
        payload: Dictionary = {},
        calculation_context: Dictionary = {}) -> Dictionary:
    var context := ContextScript.new().configure({
        "card": card,
        "value": value,
        "attribute_id": attribute_id,
        "payload": payload,
        "calculation_context": calculation_context,
    })
    return registry.execute(behavior, context)

func _behavior_entries(card, trigger: String) -> Array:
    var entries: Array = []
    var serial := 0
    for definition_value in _active_definitions(card):
        for behavior_value in definition_value.get("behaviors", []):
            var behavior: Dictionary = behavior_value
            if str(behavior.get("trigger", "")) == trigger:
                entries.append({
                    "priority": int(behavior.get("priority", 500)),
                    "serial": serial,
                    "behavior": behavior,
                })
            serial += 1
    entries.sort_custom(func(left, right):
        if int(left["priority"]) != int(right["priority"]):
            return int(left["priority"]) < int(right["priority"])
        return int(left["serial"]) < int(right["serial"]))
    return entries

func _reshape_id(card, category: String) -> String:
    match category:
        "origin": return str(card.reshape_origin.get("id", ""))
        "enhancement": return str(card.reshape_enhancement)
        "imprint": return str(card.reshape_imprint)
        "other": return ""
    return ""

func _active_definitions(card) -> Array:
    var result: Array = []
    for category in ["origin", "enhancement", "imprint"]:
        var definition_value := definition(category, _reshape_id(card, category))
        if not definition_value.is_empty():
            result.append(definition_value)
    for reshape_id in card.reshape_others:
        var suppressed_others: Dictionary = card.suppressed_reshapes.get("others", {})
        if suppressed_others.has(str(reshape_id)):
            continue
        var definition_value := definition("other", str(reshape_id))
        if not definition_value.is_empty():
            result.append(definition_value)
    return result

func _content_type(category: String) -> String:
    return "other_reshape" if category == "other" else category

func _load_fallback_definitions() -> void:
    var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/card_states.json"))
    if not parsed is Dictionary:
        return
    for pair in [["origin", "origins"], ["enhancement", "enhancements"], ["imprint", "imprints"], ["other", "other_reshapes"]]:
        var values: Dictionary = {}
        for value in parsed.get(pair[1], []):
            values[str(value.get("id", ""))] = value.duplicate(true)
        _definitions[pair[0]] = values
