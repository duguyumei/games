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

func on_turn_end(holder) -> Dictionary:
    var resolutions: Array = []
    for card in holder.hand.duplicate():
        var result := dispatch("turn_end", holder, card)
        resolutions.append_array(result.get("resolutions", []))
        if not result.get("success", true):
            return {
                "success": false,
                "reason": str(result.get("reason", "回合结束真气状态结算失败")),
                "resolutions": resolutions,
            }
    return {"success": true, "resolutions": resolutions}

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
        "success": true,
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
            var ports = _effect_ports()
            entry["behavior"]["frozen_amount"] = (
                ports.current_effective_qi(holder, card, {
                    "actor": holder,
                    "purpose": "effect_value",
                    "evaluation_mode": "runtime",
                    "action_token": str(source_values.get("action_token", "")),
                    "source_kind": str(source_values.get("source_kind", "status")),
                    "boundary": "card_status_behavior_freeze",
                }) if ports != null else card.effective_qi_value())
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
        var growth_entry: bool = str(entry.get("status_id", "")) == "growth" \
            and str(entry.get("behavior", {}).get("handler", "")) \
                == "grow_anomaly_layers"
        var growth_transaction := {}
        var ports = _effect_ports()
        if growth_entry and ports != null:
            growth_transaction = ports.begin_effect_mutation_transaction()
        var result: Dictionary = behavior_registry.execute(
            entry["behavior"], context)
        if not bool(result.get("success", false)):
            if not growth_transaction.is_empty():
                ports.rollback_effect_mutation_transaction(growth_transaction)
                aggregate["success"] = false
                aggregate["reason"] = str(result.get(
                    "reason", "成长状态提交失败"))
                aggregate["stop_card_behaviors"] = true
                break
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
        if replay_depth == 0 and growth_entry \
                and bool(result.get("applied", false)):
            var extras := _execute_growth_extra_plan(
                entry, holder, card, source_values, trigger_sequence)
            if not extras.get("success", false):
                if not growth_transaction.is_empty():
                    ports.rollback_effect_mutation_transaction(
                        growth_transaction)
                aggregate["success"] = false
                aggregate["reason"] = str(extras.get(
                    "reason", "成长额外触发计划失败"))
                aggregate["stop_card_behaviors"] = true
                break
            aggregate["resolutions"].append_array(
                extras.get("resolutions", []))
        if not growth_transaction.is_empty():
            ports.commit_effect_mutation_transaction(growth_transaction)
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

func _execute_growth_extra_plan(
        entry: Dictionary,
        holder,
        card,
        source_values: Dictionary,
        base_trigger_sequence: int) -> Dictionary:
    var runtime = holder.passive_rule_runtime \
        if holder != null else null
    if runtime == null:
        return {"success": true, "resolutions": []}
    var source_snapshot: Array = source_values.get("source_snapshot", [])
    var context_values := {
        "hook": "growth_trigger_execution_plan",
        "owner": holder,
        "actor": holder,
        "round_number": int(source_values.get("round_number", 0)),
        "payload": {
            "card_instance_id": str(card.id),
            "growth_layers": card.anomaly_layers("buff", "growth"),
            "is_leftmost_hand_card": (
                not holder.hand.is_empty() and holder.hand[0] == card),
            "extra_plan_depth": 0,
        },
    }
    if not source_snapshot.is_empty():
        context_values["source_snapshot"] = source_snapshot.duplicate(true)
    var plan = runtime.build_execution_plan(
        "growth_trigger_execution_plan", context_values)
    if not plan.is_valid():
        return {"success": false, "reason": "；".join(plan.errors)}
    var resolutions: Array = []
    var sequence := base_trigger_sequence + 1
    for invocation in plan.invocations:
        var executed: Dictionary = runtime.execute_invocation(
            invocation, null, "read")
        if not executed.get("success", false):
            return executed
        var handler_result: Dictionary = executed.get("result", {})
        var extra_count := maxi(0, int(handler_result.get(
            "additional_triggers", 0)))
        for _index in range(extra_count):
            var extra_values := source_values.duplicate()
            extra_values.merge({
                "trigger": "turn_end",
                "status_id": entry["status_id"],
                "category": entry["category"],
                "definition": entry["definition"],
                "behavior": entry["behavior"],
                "holder": holder,
                "card": card,
                "card_anomaly_service": card_anomaly_service,
                "effect_ports": _effect_ports(),
                "source_card_instance_id": str(card.id),
                "source_trigger": "turn_end",
                "action_token": str(source_values.get("action_token", "")),
                "replay_depth": 0,
                "trigger_sequence": sequence,
                "extra_trigger": true,
                "growth_source_metadata": {
                    "source_kind": invocation.source.source_kind,
                    "source_id": invocation.source.content_id,
                    "source_name": str(invocation.source.definition.get(
                        "name", invocation.source.content_id)),
                    "source_instance_key": invocation.source.source_instance_key,
                    "trigger_mode": "automatic",
                    "action_token": str(source_values.get("action_token", "")),
                },
                "rng": _rng,
            }, true)
            var extra_result: Dictionary = behavior_registry.execute(
                entry["behavior"],
                StatusBehaviorContextScript.new().configure(extra_values))
            if not extra_result.get("success", false):
                return extra_result
            if extra_result.has("resolution"):
                resolutions.append(extra_result["resolution"])
            sequence += 1
    return {"success": true, "resolutions": resolutions}

func _merge_card_behavior_aggregate(
        target: Dictionary,
        addition: Dictionary) -> void:
    target["resolutions"].append_array(addition.get("resolutions", []))
    target["success"] = bool(target.get("success", true)) \
        and bool(addition.get("success", true))
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
