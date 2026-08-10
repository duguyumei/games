class_name CardTriggerReplayService
extends RefCounted

## 单张真气合格触发包的窄重演协议。
##
## 服务只认识合格触发、重演深度和已注册的直接监听器；具体印记 ID 及内容效果
## 仍完全由 CardReshapeRuleService/Handler 数据驱动。

const DIRECT_LISTENER_METHOD := "on_qualified_card_trigger"
const QUALIFIED_TRIGGERS := [
    "numeric_bundle",
    "action_confirmed",
    "card_drawn",
    "card_entered_discard",
    "card_explicitly_discarded",
    "card_played",
    "group_resolved",
    "turn_end",
    "turn_end_final",
    "battle_victory",
]

var _rules_ref: WeakRef
var _direct_listeners: Array[Dictionary] = []

func _init(rules) -> void:
    _rules_ref = weakref(rules)

func qualified_replay_count(
        card,
        trigger: String,
        context: Dictionary = {}) -> int:
    if int(context.get("replay_depth", 0)) > 0 \
            or not QUALIFIED_TRIGGERS.has(trigger):
        return 0
    var rules = _rules()
    if rules == null:
        return 0
    var total := 0
    for entry in rules.behavior_entries_for(card, "qualified_trigger_replay"):
        var result: Dictionary = rules.execute_behavior_entry(
            entry,
            card,
            "qualified_trigger_replay",
            _source_values(card, trigger, context, 0, 0))
        if bool(result.get("success", false)):
            total += maxi(0, int(result.get("additional_replays", 0)))
    return total

func dispatch_qualified_event(
        card,
        trigger: String,
        values: Dictionary = {}) -> Array[Dictionary]:
    var rules = _rules()
    if rules == null:
        return []
    if not QUALIFIED_TRIGGERS.has(trigger):
        return rules.dispatch_battle_event(card, trigger, values)

    var replay_count := qualified_replay_count(card, trigger, values)
    var entries: Array = rules.behavior_entries_for(card, trigger)
    var normal := _execute_card_entries(
        rules, entries, card, trigger, values, 0, 0, false)
    var results: Array[Dictionary] = normal["results"]
    var applied_entries: Array = normal["applied_entries"]
    var applied_listeners := _execute_direct_listeners(
        card, trigger, values, 0, 0, _direct_listeners, results)

    for replay_index in range(replay_count):
        var replay_depth := 1
        var trigger_sequence := replay_index + 1
        var replayed := _execute_card_entries(
            rules,
            applied_entries,
            card,
            trigger,
            values,
            replay_depth,
            trigger_sequence,
            true)
        results.append_array(replayed["results"])
        _execute_direct_listeners(
            card,
            trigger,
            values,
            replay_depth,
            trigger_sequence,
            applied_listeners,
            results)
    return results

func calculate_qualified_numeric_bundle(
        card,
        calculation_context: Dictionary = {},
        contribution_modifier: Callable = Callable()) -> Dictionary:
    var rules = _rules()
    if rules == null:
        return {}
    var replay_count := qualified_replay_count(
        card, "numeric_bundle", calculation_context)
    var bundles: Array[Dictionary] = []
    for trigger_sequence in range(replay_count + 1):
        var replay_depth := 0 if trigger_sequence == 0 else 1
        var pass_context := calculation_context.duplicate(true)
        pass_context.merge(_source_values(
            card,
            "numeric_bundle",
            calculation_context,
            replay_depth,
            trigger_sequence), true)
        bundles.append(rules.calculate_numeric_bundle_once(
            card, pass_context, contribution_modifier))
    var result := {
        "source_card_instance_id": str(card.id),
        "source_trigger": "numeric_bundle",
        "replay_count": replay_count,
        "trigger_count": bundles.size(),
        "effective_qi": 0,
        "contribution": 0,
        "technique_multiplier_bonus": 0,
        "power_amp_percent": 0,
        "passes": bundles,
    }
    for bundle in bundles:
        result["effective_qi"] += int(bundle.get("effective_qi", 0))
        result["contribution"] += int(bundle.get("contribution", 0))
        result["technique_multiplier_bonus"] += int(
            bundle.get("technique_multiplier_bonus", 0))
        result["power_amp_percent"] += int(
            bundle.get("power_amp_percent", 0))
    return result

func register_direct_listener(listener_id: String, listener) -> bool:
    if listener_id == "" or not _valid_listener(listener):
        return false
    for entry in _direct_listeners:
        if str(entry["id"]) == listener_id:
            return false
    _direct_listeners.append({"id": listener_id, "listener": listener})
    return true

func unregister_direct_listener(listener_id: String) -> bool:
    for index in range(_direct_listeners.size()):
        if str(_direct_listeners[index]["id"]) != listener_id:
            continue
        _direct_listeners.remove_at(index)
        return true
    return false

func clear_direct_listeners() -> void:
    _direct_listeners.clear()

func _execute_card_entries(
        rules,
        entries: Array,
        card,
        trigger: String,
        values: Dictionary,
        replay_depth: int,
        trigger_sequence: int,
        replay_only: bool) -> Dictionary:
    var results: Array[Dictionary] = []
    var applied_entries: Array = []
    for entry in entries:
        var result: Dictionary = rules.execute_behavior_entry(
            entry,
            card,
            trigger,
            _source_values(
                card, trigger, values, replay_depth, trigger_sequence))
        result.merge(_source_metadata(
            card, trigger, values, replay_depth, trigger_sequence), false)
        results.append(result)
        if not replay_only and bool(result.get(
                "applied", result.get("success", false))):
            applied_entries.append(entry)
    return {"results": results, "applied_entries": applied_entries}

func _execute_direct_listeners(
        card,
        trigger: String,
        values: Dictionary,
        replay_depth: int,
        trigger_sequence: int,
        listeners: Array,
        results: Array[Dictionary]) -> Array:
    var applied_listeners: Array = []
    for entry in listeners:
        var source := _source_values(
            card, trigger, values, replay_depth, trigger_sequence)
        source["listener_id"] = str(entry["id"])
        var result: Variant = _call_listener(entry["listener"], source)
        if not result is Dictionary:
            continue
        var typed_result: Dictionary = result
        typed_result["direct_listener_id"] = str(entry["id"])
        typed_result.merge(_source_metadata(
            card, trigger, values, replay_depth, trigger_sequence), false)
        results.append(typed_result)
        if replay_depth == 0 and bool(typed_result.get(
                "applied", typed_result.get("success", false))):
            applied_listeners.append(entry)
    return applied_listeners

func _source_values(
        card,
        trigger: String,
        values: Dictionary,
        replay_depth: int,
        trigger_sequence: int) -> Dictionary:
    var source := values.duplicate()
    source.merge({
        "card": card,
        "source_card": card,
        "qualified_trigger": trigger,
        "source_card_instance_id": str(card.id),
        "source_trigger": trigger,
        "action_token": str(values.get("action_token", "")),
        "replay_depth": replay_depth,
        "trigger_sequence": trigger_sequence,
    }, true)
    return source

func _source_metadata(
        card,
        trigger: String,
        values: Dictionary,
        replay_depth: int,
        trigger_sequence: int) -> Dictionary:
    return {
        "source_card_instance_id": str(card.id),
        "source_trigger": trigger,
        "action_token": str(values.get("action_token", "")),
        "replay_depth": replay_depth,
        "trigger_sequence": trigger_sequence,
    }

func _valid_listener(listener) -> bool:
    if listener is Callable:
        return listener.is_valid()
    return listener != null and listener.has_method(DIRECT_LISTENER_METHOD)

func _call_listener(listener, source: Dictionary):
    if listener is Callable:
        return listener.call(source) if listener.is_valid() else {}
    if listener != null and listener.has_method(DIRECT_LISTENER_METHOD):
        return listener.call(DIRECT_LISTENER_METHOD, source)
    return {}

func _rules():
    return _rules_ref.get_ref() if _rules_ref != null else null
