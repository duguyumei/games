class_name BattlePassiveCommittedEventService
extends RefCounted

signal event_committed(event_kind, values, receipt)

const ContextScript = preload(
    "res://core/passives/battle_passive_committed_event_context.gd")
const ReceiptStoreScript = preload(
    "res://core/passives/battle_passive_event_receipt_store.gd")
const BattleEventCatalogScript = preload("res://core/battle_event_catalog.gd")

var execution_history: Array[Dictionary] = []
var receipt_store := ReceiptStoreScript.new()

var _runtime_ref: WeakRef
## The event service is injected into each side's CardZoneService, so retaining the
## sides here would create a RefCounted cycle (service -> side -> service).
## Battle membership is observational state; weak references are sufficient.
var _side_refs: Array[WeakRef] = []
var _scenario_error: Callable
var _battle_instance_id: String = "battle-0"
var _serial: int = 0
var _weak_listeners: Array[Dictionary] = []

func _init(passive_runtime, scenario_error_callback: Callable = Callable()) -> void:
    _runtime_ref = weakref(passive_runtime)
    _scenario_error = scenario_error_callback

func open_battle(sides: Array, battle_instance_id: String) -> void:
    _side_refs.clear()
    for side in sides:
        if side != null:
            _side_refs.append(weakref(side))
    _battle_instance_id = battle_instance_id
    _serial = 0
    receipt_store.clear()
    execution_history.clear()

func close_battle() -> void:
    receipt_store.clear()
    execution_history.clear()
    _side_refs.clear()
    _serial = 0

func register_weak_listener(target, method: String) -> bool:
    if target == null or method == "" or not target.has_method(method):
        return false
    for entry in _weak_listeners:
        if entry["target"].get_ref() == target and str(entry["method"]) == method:
            return true
    _weak_listeners.append({"target": weakref(target), "method": method})
    return true

func next_serial() -> int:
    var result := _serial
    _serial += 1
    return result

func make_token(
        event_kind: String,
        actor,
        semantic_serial,
        action_token: String = "",
        card_instance_id: String = "") -> String:
    var owner_id := str(actor.owner_id) if actor != null else "none"
    return "%s|%s|%s|%s|%s|%s" % [
        _battle_instance_id, event_kind, str(semantic_serial),
        action_token, owner_id, card_instance_id]

func commit(event_kind: String, values: Dictionary) -> Dictionary:
    if not BattleEventCatalogScript.is_committed(event_kind):
        return _fail(event_kind, "未知 committed 事件：%s" % event_kind)
    var runtime = _runtime_ref.get_ref()
    if runtime == null:
        return _fail(event_kind, "被动规则运行时已释放")
    if not runtime.registry.has_hook(event_kind):
        return _fail(event_kind, "未知细粒度事件 Hook：%s" % event_kind)
    var event_token := str(values.get("event_token", ""))
    if event_token == "":
        return _fail(event_kind, "细粒度事件缺少稳定 event_token")
    if receipt_store.has(event_token):
        return {
            "success": true,
            "reused": true,
            "event_token": event_token,
            "receipt": receipt_store.receipt(event_token),
        }
    var owners := _event_owners(values)
    var snapshots: Dictionary = {}
    var plans: Dictionary = {}
    var contexts: Dictionary = {}
    for owner in owners:
        var owner_id := str(owner.owner_id)
        snapshots[owner_id] = _capture_counters(owner)
        var context = _context(event_kind, values, owner, event_token)
        contexts[owner_id] = context
        plans[owner_id] = runtime.build_execution_plan(event_kind, context)
        if not plans[owner_id].is_valid():
            return _rollback_failure(
                event_kind, event_token, owners, snapshots,
                "；".join(plans[owner_id].errors))
    var invocation_count := 0
    for owner in owners:
        var owner_id := str(owner.owner_id)
        for invocation in plans[owner_id].invocations:
            var executed: Dictionary = runtime.execute_invocation(
                invocation, contexts[owner_id].for_invocation(invocation), "mutation")
            execution_history.append({
                "event_kind": event_kind,
                "event_token": event_token,
                "owner_id": owner_id,
                "source_instance_key": invocation.source.source_instance_key,
                "behavior_id": invocation.source.behavior_id,
                "execution_index": invocation.execution_index,
                "success": bool(executed.get("success", false)),
            })
            if not executed.get("success", false):
                return _rollback_failure(
                    event_kind, event_token, owners, snapshots,
                    str(executed.get("reason", "细粒度事件执行失败")))
            invocation_count += 1
    var receipt := {
        "event_kind": event_kind,
        "event_token": event_token,
        "owner_ids": owners.map(func(owner): return str(owner.owner_id)),
        "invocation_count": invocation_count,
    }
    return _publish(event_kind, values, receipt)

func publish_resolved_timing_event(
        event_kind: String,
        values: Dictionary) -> Dictionary:
    if not BattleEventCatalogScript.is_timing(event_kind):
        return _fail(event_kind, "未知 timing 事件：%s" % event_kind)
    var runtime = _runtime_ref.get_ref()
    if runtime == null:
        return _fail(event_kind, "被动规则运行时已释放")
    if not runtime.registry.has_hook(event_kind):
        return _fail(event_kind, "未知细粒度事件 Hook：%s" % event_kind)
    var event_token := str(values.get("event_token", ""))
    if event_token == "":
        return _fail(event_kind, "细粒度事件缺少稳定 event_token")
    if receipt_store.has(event_token):
        return {
            "success": true,
            "reused": true,
            "event_token": event_token,
            "receipt": receipt_store.receipt(event_token),
        }
    var receipt := {
        "event_kind": event_kind,
        "event_token": event_token,
        "owner_ids": _event_owners(values).map(
            func(owner): return str(owner.owner_id)),
        "invocation_count": 0,
        "timing_already_resolved": true,
    }
    return _publish(event_kind, values, receipt)

func _publish(
        event_kind: String,
        values: Dictionary,
        receipt: Dictionary) -> Dictionary:
    var event_token := str(receipt.get("event_token", values.get(
        "event_token", "")))
    receipt_store.record(event_token, receipt)
    event_committed.emit(event_kind, values.duplicate(false), receipt.duplicate(true))
    for listener in _weak_listeners.duplicate():
        var target = listener["target"].get_ref()
        if target == null:
            _weak_listeners.erase(listener)
            continue
        target.call(str(listener["method"]), event_kind, values.duplicate(false), receipt.duplicate(true))
    return {
        "success": true,
        "reused": false,
        "event_token": event_token,
        "receipt": receipt,
    }

func _context(
        event_kind: String,
        values: Dictionary,
        owner,
        event_token: String):
    var payload: Dictionary = values.get("payload", {}).duplicate(false)
    for field in BattleEventCatalogScript.PUBLIC_FIELDS + [
            "true_damage", "synchronized"]:
        if values.has(field):
            payload[field] = values[field]
    return ContextScript.new().configure({
        "hook": event_kind,
        "event_kind": event_kind,
        "event_token": event_token,
        "event_serial": int(values.get("event_serial", -1)),
        "action_token": str(values.get("action_token", "")),
        "actor": values.get("actor"),
        "target": values.get("target"),
        "owner": owner,
        "owner_id": str(owner.owner_id),
        "round_number": int(values.get("round_number", 0)),
        "card": values.get("card"),
        "card_instance_id": str(values.get("card_instance_id", "")),
        "source_kind": str(values.get("source_kind", "")),
        "source_id": str(values.get("source_id", "")),
        "source_name": str(values.get("source_name", "")),
        "source_instance_key": str(values.get("source_instance_key", "")),
        "trigger_mode": str(values.get("trigger_mode", "")),
        "requested_amount": int(values.get("requested_amount", 0)),
        "final_amount": int(values.get("final_amount", 0)),
        "metadata": values.get("metadata", {}),
        "technique_triggered": bool(values.get("technique_triggered", false)),
        "action_succeeded": bool(values.get("action_succeeded", false)),
        "draw_reason": str(values.get("draw_reason", "")),
        "from_zone": str(values.get("from_zone", "")),
        "reason": str(values.get("reason", "")),
        "explicit_discard": bool(values.get("explicit_discard", false)),
        "normal_play": bool(values.get("normal_play", false)),
        "defense_lost": int(values.get("defense_lost", 0)),
        "life_lost": int(values.get("life_lost", 0)),
        "true_damage": bool(values.get("true_damage", false)),
        "damage_type": str(values.get("damage_type", "normal")),
        "synchronized": bool(values.get("synchronized", false)),
        "effective_amount": int(values.get("effective_amount", 0)),
        "defense_before": int(values.get("defense_before", 0)),
        "defense_after": int(values.get("defense_after", 0)),
        "frozen_amount": int(values.get("frozen_amount", 0)),
        "actual_life_loss": int(values.get("actual_life_loss", values.get("life_lost", 0))),
        "source_card_instance_id": str(values.get("source_card_instance_id", "")),
        "pre_move_snapshot": values.get("pre_move_snapshot", {}),
        "payload": payload,
    })

func _event_owners(values: Dictionary) -> Array:
    var result: Array = []
    var sides := _battle_sides()
    var actor = values.get("actor")
    var target = values.get("target")
    if actor != null and sides.has(actor):
        result.append(actor)
    if bool(values.get("include_target_owner", false)) \
            and target != null and target != actor and sides.has(target):
        result.append(target)
    if result.is_empty() and values.get("owner") != null:
        result.append(values["owner"])
    return result

func _battle_sides() -> Array:
    var result: Array = []
    for side_ref in _side_refs:
        var side = side_ref.get_ref()
        if side != null:
            result.append(side)
    return result

func _capture_counters(owner) -> Dictionary:
    return {
        "persistent": owner.passive_counter_store.capture_state(),
        "battle": owner.battle_passive_counter_store.capture_state(),
    }

func _rollback_failure(
        event_kind: String,
        event_token: String,
        owners: Array,
        snapshots: Dictionary,
        reason: String) -> Dictionary:
    var rollback_errors: Array[String] = []
    for owner in owners:
        var snapshot: Dictionary = snapshots.get(str(owner.owner_id), {})
        if snapshot.is_empty():
            continue
        rollback_errors.append_array(owner.passive_counter_store.replace_state(
            snapshot["persistent"]))
        rollback_errors.append_array(owner.battle_passive_counter_store.replace_state(
            snapshot["battle"]))
    if not rollback_errors.is_empty():
        reason += "；计数器回滚失败：%s" % "；".join(rollback_errors)
    return _fail(
        event_kind,
        "event_token=%s reason=%s" % [event_token, reason])

func _fail(event_kind: String, reason: String) -> Dictionary:
    var detail := "细粒度被动事件失败 hook=%s %s" % [event_kind, reason]
    if _scenario_error.is_valid():
        _scenario_error.call(detail)
    return {"success": false, "reused": false, "reason": detail}
