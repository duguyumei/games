class_name CardStatusBehaviorService
extends RefCounted

const StatusBehaviorRegistryScript = preload(
    "res://core/statuses/status_behavior_registry.gd")
const StatusBehaviorContextScript = preload(
    "res://core/statuses/status_behavior_context.gd")

var content_catalog
var card_anomaly_service
var behavior_registry
var _effect_ports_ref: WeakRef
var _rng: RandomNumberGenerator = null
var _card_trigger_replay_service = null

func _init(catalog, anomaly_service) -> void:
    assert(catalog != null, "CardStatusBehaviorService requires ContentCatalog")
    assert(anomaly_service != null,
        "CardStatusBehaviorService requires CardAnomalyService")
    content_catalog = catalog
    card_anomaly_service = anomaly_service
    behavior_registry = StatusBehaviorRegistryScript.new()

func use_effect_ports(effect_ports) -> void:
    _effect_ports_ref = weakref(effect_ports) if effect_ports != null else null

func use_rng(random_source: RandomNumberGenerator) -> void:
    _rng = random_source

func use_card_trigger_replay_service(service) -> void:
    _card_trigger_replay_service = service

func can_play_card(holder, card) -> Dictionary:
    var result := dispatch("play_attempt", holder, card)
    if bool(result.get("blocked", false)):
        return {
            "allowed": false,
            "reason": str(result.get("reason", "此真气本回合不能打出")),
        }
    return {"allowed": true}

func on_card_enter_discard(holder, card) -> void:
    dispatch("enter_discard", holder, card)

func on_card_enter_discard_late(holder, card) -> void:
    dispatch("enter_discard_late", holder, card)

func on_card_drawn(holder, card) -> void:
    if not holder.hand.has(card):
        return
    dispatch("draw", holder, card)

func on_card_explicit_discard(
        holder, card, allow_void_departure: bool = false) -> void:
    if not holder.discard_pile.has(card) and not allow_void_departure:
        return
    dispatch("explicit_discard", holder, card)

func resolve_played_card_anomalies(
        holder,
        cards: Array,
        source_values: Dictionary = {}) -> Array:
    var resolutions: Array = []
    for card in cards:
        for resolution in dispatch(
                "played", holder, card, source_values).get("resolutions", []):
            resolutions.append(resolution)
    return resolutions

func on_turn_end(holder) -> void:
    for card in holder.hand.duplicate():
        dispatch("turn_end", holder, card)

func on_turn_end_final(holder) -> void:
    for card in holder.hand.duplicate():
        dispatch("turn_end_final", holder, card)

func dispatch(
        trigger: String,
        holder,
        card,
        source_values: Dictionary = {}) -> Dictionary:
    var entries: Array = []
    var snapshot: Dictionary = card.anomaly_snapshot()
    for status_id in snapshot.get("buffs", {}).keys():
        _append_card_behavior_entries(entries, trigger, "buff", str(status_id))
    for status_id in snapshot.get("debuffs", {}).keys():
        _append_card_behavior_entries(entries, trigger, "debuff", str(status_id))
    var state: Dictionary = snapshot.get("state", {})
    _append_card_behavior_entries(
        entries, trigger, "state", str(state.get("id", "")))
    for status_id in snapshot.get("marks", {}).keys():
        _append_card_behavior_entries(entries, trigger, "mark", str(status_id))
    entries.sort_custom(func(left, right):
        if int(left["priority"]) != int(right["priority"]):
            return int(left["priority"]) < int(right["priority"])
        if str(left["status_id"]) != str(right["status_id"]):
            return str(left["status_id"]) < str(right["status_id"])
        return int(left["behavior_index"]) < int(right["behavior_index"]))
    var source_trigger := _qualified_card_trigger(trigger)
    var replay_count := 0
    if source_trigger != "" and _card_trigger_replay_service != null:
        replay_count = _card_trigger_replay_service.qualified_replay_count(
            card, source_trigger, source_values)
    var normal := _execute_card_behavior_entries(
        entries,
        trigger,
        source_trigger,
        holder,
        card,
        source_values,
        0,
        0,
        true)
    var aggregate: Dictionary = normal["aggregate"]
    for replay_index in range(replay_count):
        var replayed := _execute_card_behavior_entries(
            normal["executed_entries"],
            trigger,
            source_trigger,
            holder,
            card,
            source_values,
            1,
            replay_index + 1,
            false)
        _merge_card_behavior_aggregate(aggregate, replayed["aggregate"])
    return aggregate

func _execute_card_behavior_entries(
        entries: Array,
        trigger: String,
        source_trigger: String,
        holder,
        card,
        source_values: Dictionary,
        replay_depth: int,
        trigger_sequence: int,
        require_current_anomaly: bool) -> Dictionary:
    var aggregate := {
        "resolutions": [],
        "stop_card_behaviors": false,
        "blocked": false,
        "reason": "",
    }
    var executed_entries: Array = []
    for entry_value in entries:
        var entry: Dictionary = entry_value.duplicate(true)
        if require_current_anomaly and not card.has_anomaly(
                str(entry["category"]), str(entry["status_id"])):
            continue
        if replay_depth == 0 \
                and str(entry.get("behavior", {}).get("handler", "")) \
                    == "damage_holder_by_current_qi":
            entry["behavior"]["frozen_amount"] = (
                card_anomaly_service.effective_qi_value(card))
        var context_values := source_values.duplicate()
        context_values.merge({
            "trigger": trigger,
            "status_id": entry["status_id"],
            "category": entry["category"],
            "definition": entry["definition"],
            "behavior": entry["behavior"],
            "holder": holder,
            "card": card,
            "card_anomaly_service": card_anomaly_service,
            "effect_ports": _effect_ports(),
            "source_card_instance_id": str(card.id),
            "source_trigger": source_trigger,
            "action_token": str(source_values.get("action_token", "")),
            "replay_depth": replay_depth,
            "trigger_sequence": trigger_sequence,
            "rng": _rng,
        }, true)
        var context = StatusBehaviorContextScript.new().configure(
            context_values)
        var result: Dictionary = behavior_registry.execute(
            entry["behavior"], context)
        if not bool(result.get("success", false)):
            continue
        executed_entries.append(entry)
        if result.has("resolution"):
            var resolution: Dictionary = result["resolution"]
            resolution.merge({
                "source_card_instance_id": str(card.id),
                "source_trigger": source_trigger,
                "action_token": str(source_values.get("action_token", "")),
                "replay_depth": replay_depth,
                "trigger_sequence": trigger_sequence,
            }, false)
            aggregate["resolutions"].append(resolution)
        if bool(result.get("blocked", false)):
            aggregate["blocked"] = true
            aggregate["reason"] = str(result.get("reason", ""))
        if bool(result.get("stop_card_behaviors", false)):
            aggregate["stop_card_behaviors"] = true
            break
    return {
        "aggregate": aggregate,
        "executed_entries": executed_entries,
    }

func _merge_card_behavior_aggregate(
        target: Dictionary,
        addition: Dictionary) -> void:
    target["resolutions"].append_array(addition.get("resolutions", []))
    target["stop_card_behaviors"] = (
        bool(target.get("stop_card_behaviors", false))
        or bool(addition.get("stop_card_behaviors", false)))
    target["blocked"] = (
        bool(target.get("blocked", false))
        or bool(addition.get("blocked", false)))
    if str(target.get("reason", "")) == "":
        target["reason"] = str(addition.get("reason", ""))

func _qualified_card_trigger(status_trigger: String) -> String:
    match status_trigger:
        "played": return "card_played"
        "draw": return "card_drawn"
        "explicit_discard": return "card_explicitly_discarded"
        "enter_discard": return "card_entered_discard"
        "turn_end": return "turn_end"
    return ""

func _append_card_behavior_entries(
        entries: Array,
        trigger: String,
        category: String,
        status_id: String) -> void:
    if status_id == "":
        return
    var definition: Dictionary = content_catalog.get_by_id(
        "anomaly", status_id)
    for behavior_index in range(definition.get("behaviors", []).size()):
        var behavior_value = definition.get("behaviors", [])[behavior_index]
        var behavior: Dictionary = behavior_value
        if str(behavior.get("trigger", "")) != trigger:
            continue
        entries.append({
            "priority": int(behavior.get("priority", 500)),
            "category": category,
            "status_id": status_id,
            "definition": definition,
            "behavior": behavior,
            "behavior_index": behavior_index,
        })

func _effect_ports():
    return _effect_ports_ref.get_ref() \
        if _effect_ports_ref != null else null
