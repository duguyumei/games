class_name CardReshapeRuleService
extends RefCounted

const RegistryScript = preload("res://core/card_reshapes/card_reshape_behavior_registry.gd")
const ContextScript = preload("res://core/card_reshapes/card_reshape_behavior_context.gd")
const TriggerReplayServiceScript = preload(
    "res://core/card_reshapes/card_trigger_replay_service.gd")

var content_catalog_ref: WeakRef
var registry
var trigger_replay_service
var _definitions: Dictionary = {}

func _init(catalog = null, registry_override = null) -> void:
    content_catalog_ref = weakref(catalog) if catalog != null else null
    registry = registry_override if registry_override != null else RegistryScript.new()
    trigger_replay_service = TriggerReplayServiceScript.new(self)
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
        card, "effective_qi", _base_qi_value(card), calculation_context))

func dispatch_battle_event(
        card,
        trigger: String,
        values: Dictionary = {}) -> Array[Dictionary]:
    var results: Array[Dictionary] = []
    for entry in behavior_entries_for(card, trigger):
        results.append(execute_behavior_entry(entry, card, trigger, values))
    return results

func dispatch_qualified_event(
        card,
        trigger: String,
        values: Dictionary = {}) -> Array[Dictionary]:
    return trigger_replay_service.dispatch_qualified_event(card, trigger, values)

func qualified_replay_count(
        card,
        trigger: String,
        context: Dictionary = {}) -> int:
    return trigger_replay_service.qualified_replay_count(card, trigger, context)

func calculate_qualified_numeric_bundle(
        card,
        calculation_context: Dictionary = {},
        contribution_modifier: Callable = Callable()) -> Dictionary:
    return trigger_replay_service.calculate_qualified_numeric_bundle(
        card, calculation_context, contribution_modifier)

func calculate_numeric_bundle_once(
        card,
        calculation_context: Dictionary = {},
        contribution_modifier: Callable = Callable()) -> Dictionary:
    var effective_qi := maxi(0, int(calculation_context.get(
        "effective_qi_override",
        _run_numeric(
            card, "effective_qi", _base_qi_value(card), calculation_context))))
    var contribution := _run_numeric(
        card, "card_contribution", effective_qi, calculation_context)
    if contribution_modifier.is_valid():
        contribution = int(contribution_modifier.call(card, contribution))
    return {
        "effective_qi": effective_qi,
        "contribution": contribution,
        "technique_multiplier_bonus": _run_numeric(
            card, "technique_multiplier", 0, calculation_context),
        "power_amp_percent": _run_numeric(
            card, "power_amp", 0, calculation_context),
        "replay_depth": int(calculation_context.get("replay_depth", 0)),
        "trigger_sequence": int(calculation_context.get("trigger_sequence", 0)),
    }

func behavior_entries_for(card, trigger: String) -> Array:
    return _behavior_entries(card, trigger)

func execute_behavior_entry(
        entry: Dictionary,
        card,
        trigger: String,
        values: Dictionary = {}) -> Dictionary:
    var context_values := values.duplicate()
    context_values.merge({
        "card": card,
        "trigger": trigger,
    }, true)
    return registry.execute(
        entry["behavior"], ContextScript.new().configure(context_values))

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
        return true
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
    if trigger == "effective_qi":
        for anomaly_entry in _effective_qi_anomaly_entries(card, serial):
            entries.append(anomaly_entry)
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
    if card.has_method("return_to_origin_active") and card.return_to_origin_active():
        return result
    for category in ["origin", "enhancement", "imprint"]:
        var definition_value := definition(category, _reshape_id(card, category))
        if not definition_value.is_empty():
            result.append(definition_value)
    for reshape_id in card.reshape_others:
        var definition_value := definition("other", str(reshape_id))
        if not definition_value.is_empty():
            result.append(definition_value)
    var temporary_enhancement := str(card.temporary_reshapes.get("enhancement", ""))
    if temporary_enhancement != "":
        var temporary_definition := definition("enhancement", temporary_enhancement)
        if not temporary_definition.is_empty():
            result.append(temporary_definition)
    return result

func _effective_qi_anomaly_entries(card, starting_serial: int) -> Array:
    var result: Array = []
    var serial := starting_serial
    var snapshot: Dictionary = card.anomaly_snapshot()
    for pair in [["buff", "buffs"], ["debuff", "debuffs"]]:
        for anomaly_id in snapshot.get(pair[1], {}):
            var layers: int = card.anomaly_layers(pair[0], str(anomaly_id))
            var definition_value: Dictionary = definition("anomaly", str(anomaly_id))
            for modifier_value in definition_value.get("modifiers", []):
                var modifier: Dictionary = modifier_value
                var modifier_id := str(modifier.get("id", ""))
                var behavior := {}
                match modifier_id:
                    "effective_qi_add_per_layer":
                        behavior = {
                            "trigger": "effective_qi",
                            "handler": "add_effective_qi",
                            "amount": layers * int(modifier.get("value", 0)),
                        }
                    "effective_qi_multiplier":
                        behavior = {
                            "trigger": "effective_qi",
                            "handler": "multiply_effective_qi",
                            "factor": int(modifier.get("value", 1)),
                        }
                if behavior.is_empty():
                    continue
                result.append({
                    "priority": int(modifier.get("priority", 400)),
                    "serial": serial,
                    "behavior": behavior,
                })
                serial += 1
    var temporary_heat: int = card.temporary_blazing_layers_total() \
        if card.has_method("temporary_blazing_layers_total") else 0
    if temporary_heat > 0:
        result.append({
            "priority": 400,
            "serial": serial,
            "behavior": {
                "trigger": "effective_qi",
                "handler": "add_effective_qi",
                "amount": temporary_heat,
            },
        })
        serial += 1
    for pair in [["buff", "buffs"], ["debuff", "debuffs"], ["mark", "marks"]]:
        for anomaly_id in snapshot.get(pair[1], {}):
            var definition_value: Dictionary = definition("anomaly", str(anomaly_id))
            for modifier_value in definition_value.get("modifiers", []):
                var modifier: Dictionary = modifier_value
                if str(modifier.get("id", "")) != "effective_qi_final_value":
                    continue
                result.append({
                    "priority": int(modifier.get("priority", 10000)),
                    "serial": serial,
                    "behavior": {
                        "trigger": "effective_qi",
                        "handler": "set_effective_qi",
                        "value": maxi(0, int(modifier.get("value", 0))),
                    },
                })
                serial += 1
    return result

func _base_qi_value(card) -> int:
    return card.current_base_qi_value() \
        if card.has_method("current_base_qi_value") else int(card.qi_value)

func _content_type(category: String) -> String:
    if category == "other":
        return "other_reshape"
    return category

func _load_fallback_definitions() -> void:
    var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/card_states.json"))
    if not parsed is Dictionary:
        return
    for pair in [
            ["origin", "origins"], ["enhancement", "enhancements"],
            ["imprint", "imprints"], ["other", "other_reshapes"],
            ["anomaly", "anomalies"]]:
        var values: Dictionary = {}
        for value in parsed.get(pair[1], []):
            values[str(value.get("id", ""))] = value.duplicate(true)
        _definitions[pair[0]] = values
