class_name BattlePassiveTimingBridge
extends RefCounted

const MANAGED_CHOICE_HOOKS := [
    "battle_start", "round_start", "turn_start", "before_normal_draw",
    "after_normal_draw", "action_window_start",
]

const EventContextScript = preload(
    "res://core/passives/battle_passive_event_context.gd")
const RegistryScript = preload(
    "res://core/passives/passive_rule_handler_registry.gd")
const BattleCounterDefinitionScript = preload(
    "res://core/passives/battle_passive_counter_definition.gd")

const BEGIN_ORDER := -2147483648
const END_ORDER := 2147483647

var execution_history: Array[Dictionary] = []

var _runtime_ref: WeakRef
var _timing_system
var _sides: Array = []
var _bindings: Dictionary = {}
var _registered_ids: Array[Dictionary] = []
var _pending_events: Dictionary = {}
var _reset_tokens: Dictionary = {}
var _assembled: bool = false

func _init(passive_runtime, timing_system) -> void:
    _runtime_ref = weakref(passive_runtime)
    _timing_system = timing_system

func assemble(sides: Array) -> Dictionary:
    close_battle()
    _sides = sides.duplicate()
    for side in _sides:
        if side != null and side.battle_passive_counter_store != null:
            side.battle_passive_counter_store.clear()
    var collected := _collect_bindings()
    if not collected.get("success", false):
        return collected
    var gate := _cross_side_gate_all_hooks(0)
    if not gate.get("success", false):
        _bindings.clear()
        return gate
    for hook in RegistryScript.BATTLE_TIMING_HOOKS:
        if not _register(
                hook,
                "passives.%s.begin" % hook,
                BEGIN_ORDER,
                Callable(self, "_on_timing_begin").bind(hook)):
            close_battle()
            return {
                "success": false,
                "reason": "无法注册被动战斗时点 begin：%s" % hook,
            }
    for hook in RegistryScript.BATTLE_TIMING_HOOKS:
        var orders: Array = _bindings.get(hook, {}).keys()
        orders.sort()
        for order_value in orders:
            var order := int(order_value)
            if not _register(
                    hook,
                    "passives.%s.%d" % [hook, order],
                    order,
                    Callable(self, "_on_timing_binding").bind(hook, order)):
                close_battle()
                return {
                    "success": false,
                    "reason": "无法注册被动战斗时点：%s order=%d" % [
                        hook, order],
                }
    for hook in RegistryScript.BATTLE_TIMING_HOOKS:
        if not _register(
                hook,
                "passives.%s.end" % hook,
                END_ORDER,
                Callable(self, "_on_timing_end").bind(hook)):
            close_battle()
            return {
                "success": false,
                "reason": "无法注册被动战斗时点 end：%s" % hook,
            }
    _assembled = true
    return {
        "success": true,
        "bindings": registered_binding_snapshot(),
    }

func is_assembled() -> bool:
    return _assembled

func close_battle() -> void:
    for registered in _registered_ids:
        _timing_system.unregister_handler(
            str(registered["hook"]), str(registered["handler_id"]))
    _registered_ids.clear()
    for side in _sides:
        if side != null and side.battle_passive_counter_store != null:
            side.battle_passive_counter_store.clear()
    _bindings.clear()
    _pending_events.clear()
    _reset_tokens.clear()
    execution_history.clear()
    _assembled = false

func registered_binding_snapshot() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for hook in RegistryScript.BATTLE_TIMING_HOOKS:
        var orders: Array = _bindings.get(hook, {}).keys()
        orders.sort()
        for order_value in orders:
            var order := int(order_value)
            var owner_ids: Array[String] = []
            for owner_id in _bindings[hook][order]:
                owner_ids.append(str(owner_id))
            owner_ids.sort()
            result.append({
                "hook": hook,
                "order": order,
                "handler_id": "passives.%s.%d" % [hook, order],
                "owner_ids": owner_ids,
            })
    return result

func capture_transaction_state() -> Dictionary:
    return {
        "pending_events": _pending_events.duplicate(true),
        "reset_tokens": _reset_tokens.duplicate(true),
        "execution_history": execution_history.duplicate(true),
    }

func restore_transaction_state(state: Dictionary) -> void:
    _pending_events = state.get("pending_events", {}).duplicate(true)
    _reset_tokens = state.get("reset_tokens", {}).duplicate(true)
    execution_history.assign(state.get("execution_history", []))

func _collect_bindings() -> Dictionary:
    var runtime = _runtime_ref.get_ref()
    if runtime == null:
        return {"success": false, "reason": "被动规则运行时已释放"}
    _bindings.clear()
    for side in _sides:
        if side == null:
            continue
        for source in runtime.collect_sources({"owner": side}):
            var errors: Array[String] = (
                runtime.registry.validate_battle_timing_bindings(
                    source.behavior_id, source.configuration))
            if not errors.is_empty():
                return {
                    "success": false,
                    "reason": "%s · %s：%s" % [
                        source.source_instance_key,
                        source.behavior_id,
                        "；".join(errors)],
                }
            for binding in runtime.registry.battle_timing_bindings(
                    source.behavior_id, source.configuration):
                var hook := str(binding["hook"])
                var order := int(binding["order"])
                if not _bindings.has(hook):
                    _bindings[hook] = {}
                if not _bindings[hook].has(order):
                    _bindings[hook][order] = {}
                if not _bindings[hook][order].has(side.owner_id):
                    _bindings[hook][order][side.owner_id] = {}
                _bindings[hook][order][side.owner_id][
                    _source_identity(source)] = true
    return {"success": true}

func _register(
        hook: String,
        handler_id: String,
        order: int,
        callback: Callable) -> bool:
    if not _timing_system.register_handler(
            hook, handler_id, order, callback, false, "", "被动规则"):
        return false
    _registered_ids.append({"hook": hook, "handler_id": handler_id})
    return true

func _on_timing_begin(event, expected_hook: String) -> Dictionary:
    if event.timing != expected_hook:
        return {"success": false, "detail": "被动时点 begin 收到错误 hook"}
    var gate := _cross_side_gate(expected_hook, event.round_number)
    if not gate.get("success", false):
        return {"success": false, "detail": str(gate["reason"])}
    var owners := _event_owners(event)
    var snapshots: Dictionary = {}
    var plans: Dictionary = {}
    for owner in owners:
        snapshots[owner.owner_id] = _capture_owner_counters(owner)
        var context = _event_context(event, owner)
        var runtime = _runtime_ref.get_ref()
        plans[owner.owner_id] = runtime.build_execution_plan(
            expected_hook, context)
        if not plans[owner.owner_id].is_valid():
            return {
                "success": false,
                "detail": "%s：%s" % [
                    expected_hook, "；".join(plans[owner.owner_id].errors)],
            }
    _pending_events[event.serial] = {
        "hook": expected_hook,
        "owners": owners,
        "snapshots": snapshots,
        "plans": plans,
        "execution_history_size": execution_history.size(),
        "active_binding": {},
    }
    _reset_for_timing(event, expected_hook)
    return {"success": true, "detail": "被动时点事务已建立"}

func _on_timing_binding(
        event,
        expected_hook: String,
        expected_order: int) -> Dictionary:
    var pending: Dictionary = _pending_events.get(event.serial, {})
    if pending.is_empty() or str(pending.get("hook", "")) != expected_hook:
        return {
            "success": false,
            "detail": "%s order=%d 缺少被动时点事务" % [
                expected_hook, expected_order],
        }
    var invocation_entries: Array = []
    for owner in pending["owners"]:
        var allowed: Dictionary = _bindings.get(
            expected_hook, {}).get(expected_order, {}).get(
                owner.owner_id, {})
        if allowed.is_empty():
            continue
        var plan = pending["plans"][owner.owner_id]
        for invocation in plan.invocations:
            if not allowed.has(_source_identity(invocation.source)):
                continue
            invocation_entries.append({"owner": owner, "invocation": invocation})
    pending["active_binding"] = {
        "hook": expected_hook,
        "order": expected_order,
        "entries": invocation_entries,
        "index": 0,
        "executed": 0,
        "continuation": null,
        "invocation_context": null,
        "receipt_token": "",
        "handler_result": {},
    }
    return _continue_timing_binding(event.serial)

func _continue_timing_binding(event_serial: int) -> Dictionary:
    var pending: Dictionary = _pending_events.get(event_serial, {})
    var binding: Dictionary = pending.get("active_binding", {})
    if pending.is_empty() or binding.is_empty():
        return {"success": false, "detail": "生命周期选择恢复位置已经失效"}
    var runtime = _runtime_ref.get_ref()
    var entries: Array = binding.get("entries", [])
    while int(binding.get("index", 0)) < entries.size():
        var entry: Dictionary = entries[int(binding["index"])]
        var owner = entry["owner"]
        var invocation = entry["invocation"]
        var invocation_context = invocation.context.for_invocation(invocation)
        invocation_context.payload = invocation_context.payload.duplicate(false)
        invocation_context.payload["lifecycle_choice_managed"] = \
            str(binding.get("hook", "")) in MANAGED_CHOICE_HOOKS
        var result: Dictionary = runtime.execute_invocation(
            invocation, invocation_context, "mutation")
        if result.get("success", false) \
                and result.get("result", {}).get("pending_choice", false):
            var managed: Dictionary = result["result"]
            binding["continuation"] = managed.get("effect_continuation")
            binding["invocation_context"] = invocation_context
            binding["receipt_token"] = str(managed.get("receipt_token", ""))
            binding["handler_result"] = managed.get(
                "handler_result", {}).duplicate(true)
            pending["active_binding"] = binding
            return _pending_choice_result(event_serial, managed)
        _record_invocation_result(
            str(binding["hook"]), int(binding["order"]), owner, invocation, result)
        if not result.get("success", false):
            return _binding_failure(pending, binding, invocation, result)
        binding["executed"] = int(binding.get("executed", 0)) + 1
        binding["index"] = int(binding["index"]) + 1
    pending["active_binding"] = {}
    return {
        "success": true,
        "detail": "%s order=%d 执行 %d 个 Invocation" % [
            str(binding["hook"]), int(binding["order"]),
            int(binding.get("executed", 0))],
    }

func resume_timing_choice(
        request_id: String,
        selected_ids: Array,
        event_serial: int) -> Dictionary:
    var pending: Dictionary = _pending_events.get(event_serial, {})
    var binding: Dictionary = pending.get("active_binding", {})
    if pending.is_empty() or binding.is_empty() \
            or binding.get("continuation") == null:
        return {"success": false, "detail": "当前没有可恢复的生命周期选择"}
    var entries: Array = binding.get("entries", [])
    var index := int(binding.get("index", -1))
    if index < 0 or index >= entries.size():
        return {"success": false, "detail": "生命周期 Invocation 游标无效"}
    var entry: Dictionary = entries[index]
    var invocation = entry["invocation"]
    var runtime = _runtime_ref.get_ref()
    var resumed: Dictionary = runtime.resume_managed_invocation_effects(
        invocation,
        binding.get("invocation_context"),
        binding.get("continuation"),
        request_id,
        selected_ids,
        str(binding.get("receipt_token", "")),
        binding.get("handler_result", {}))
    if resumed.get("success", false) and resumed.get("pending_choice", false):
        binding["continuation"] = resumed.get("effect_continuation")
        binding["receipt_token"] = str(resumed.get("receipt_token", ""))
        binding["handler_result"] = resumed.get(
            "handler_result", {}).duplicate(true)
        pending["active_binding"] = binding
        return _pending_choice_result(event_serial, resumed)
    _record_invocation_result(
        str(binding["hook"]), int(binding["order"]), entry["owner"],
        invocation, {"success": resumed.get("success", false), "result": resumed})
    if not resumed.get("success", false):
        return _binding_failure(
            pending, binding, invocation,
            {"success": false, "reason": resumed.get(
                "reason", "被动选择恢复失败")})
    binding["executed"] = int(binding.get("executed", 0)) + 1
    binding["index"] = index + 1
    binding["continuation"] = null
    binding["invocation_context"] = null
    pending["active_binding"] = binding
    return _continue_timing_binding(event_serial)

func _pending_choice_result(event_serial: int, managed: Dictionary) -> Dictionary:
    return {
        "success": true,
        "pending_choice": true,
        "choice_request": managed.get("choice_request", {}).duplicate(true),
        "detail": str(managed.get(
            "effect_result", {}).get("detail", "等待生命周期选择")),
        "_resume_callable": Callable(self, "resume_timing_choice").bind(
            event_serial),
    }

func _record_invocation_result(
        hook: String, order: int, owner, invocation, result: Dictionary) -> void:
    execution_history.append({
        "hook": hook,
        "order": order,
        "owner_id": owner.owner_id,
        "source_instance_key": invocation.source.source_instance_key,
        "behavior_id": invocation.source.behavior_id,
        "execution_index": invocation.execution_index,
        "success": bool(result.get("success", false)),
        "result": result.get("result", {}).duplicate(true),
    })

func _binding_failure(
        pending: Dictionary,
        binding: Dictionary,
        invocation,
        result: Dictionary) -> Dictionary:
    var rollback_errors := _rollback_pending(pending)
    execution_history.resize(int(pending.get(
        "execution_history_size", execution_history.size())))
    var reason := str(result.get("reason", "被动行为执行失败"))
    if not rollback_errors.is_empty():
        reason += "；计数器回滚失败：%s" % "；".join(rollback_errors)
    return {
        "success": false,
        "detail": "hook=%s order=%d source_instance_key=%s behavior_id=%s reason=%s" % [
            str(binding.get("hook", "")), int(binding.get("order", 0)),
            invocation.source.source_instance_key,
            invocation.source.behavior_id,
            reason],
    }

func _on_timing_end(event, expected_hook: String) -> Dictionary:
    _pending_events.erase(event.serial)
    if expected_hook == "battle_end":
        for side in _sides:
            if side != null and side.battle_passive_counter_store != null:
                side.battle_passive_counter_store.clear()
    return {"success": true, "detail": "被动时点事务完成"}

func _cross_side_gate_all_hooks(round_number: int) -> Dictionary:
    for hook in RegistryScript.BATTLE_TIMING_HOOKS:
        var gate := _cross_side_gate(hook, round_number)
        if not gate.get("success", false):
            return gate
    return {"success": true}

func _cross_side_gate(hook: String, round_number: int) -> Dictionary:
    if not _bindings.has(hook):
        return {"success": true}
    var owner_ids: Array[String] = []
    var runtime = _runtime_ref.get_ref()
    for side in _sides:
        if side == null:
            continue
        var context = EventContextScript.new().configure({
            "hook": hook,
            "owner": side,
            "owner_id": side.owner_id,
            "actor": side,
            "actors": _sides,
            "round_number": round_number,
        })
        var plan = runtime.build_execution_plan(hook, context)
        if not plan.is_valid():
            return {"success": false, "reason": "；".join(plan.errors)}
        if _has_bound_invocation(hook, side.owner_id, plan):
            owner_ids.append(str(side.owner_id))
    if owner_ids.size() < 2:
        return {"success": true}
    owner_ids.sort()
    return {
        "success": false,
        "code": "unconfirmed_cross_side_passive_order",
        "reason": "unconfirmed_cross_side_passive_order hook=%s owner_ids=%s" % [
            hook, ",".join(owner_ids)],
        "hook": hook,
        "owner_ids": owner_ids,
    }

func _has_bound_invocation(hook: String, owner_id: String, plan) -> bool:
    for invocation in plan.invocations:
        var identity := _source_identity(invocation.source)
        for order in _bindings.get(hook, {}):
            if _bindings[hook][order].get(owner_id, {}).has(identity):
                return true
    return false

func _event_owners(event) -> Array:
    var result: Array = []
    if event.actor != null and _sides.has(event.actor):
        result.append(event.actor)
        return result
    for actor in event.actors:
        if _sides.has(actor) and not result.has(actor):
            result.append(actor)
    if result.is_empty():
        result.append_array(_sides)
    return result

func _event_context(event, owner):
    var metadata: Dictionary = event.context.get("metadata", {}).duplicate(false)
    var target = event.context.get("target")
    if target == null and event.actor != null:
        target = _opposing_side(event.actor)
    return EventContextScript.new().configure({
        "hook": event.timing,
        "actor": event.actor,
        "actors": event.actors,
        "target": target,
        "owner": owner,
        "owner_id": owner.owner_id,
        "round_number": event.round_number,
        "timing_serial": event.serial,
        "winner": event.context.get("winner"),
        "battle_state": str(event.context.get(
            "battle_state", metadata.get("battle_state", ""))),
        "drawn_cards": event.context.get("drawn_cards", []),
        "metadata": metadata,
        "payload": event.context.duplicate(false),
    })

func _opposing_side(actor):
    for side in _sides:
        if side != actor:
            return side
    return null

func _reset_for_timing(event, hook: String) -> void:
    var scope := ""
    var reset_owners: Array = []
    if hook == "turn_start" and event.actor != null:
        scope = BattleCounterDefinitionScript.RESET_TURN
        reset_owners = [event.actor]
    elif hook == "action_window_start":
        scope = BattleCounterDefinitionScript.RESET_ACTION_WINDOW
        reset_owners = _event_owners(event)
    if scope == "":
        return
    for owner in reset_owners:
        var token := "%s|%d|%s" % [hook, event.serial, owner.owner_id]
        if _reset_tokens.has(token):
            continue
        _reset_tokens[token] = true
        owner.battle_passive_counter_store.reset_scope(scope, owner.owner_id)

func _capture_owner_counters(owner) -> Dictionary:
    return {
        "persistent": owner.passive_counter_store.capture_state(),
        "battle": owner.battle_passive_counter_store.capture_state(),
    }

func _rollback_pending(pending: Dictionary) -> Array[String]:
    var errors: Array[String] = []
    for owner in pending.get("owners", []):
        var snapshot: Dictionary = pending["snapshots"].get(owner.owner_id, {})
        if snapshot.is_empty():
            continue
        errors.append_array(owner.passive_counter_store.replace_state(
            snapshot["persistent"]))
        errors.append_array(owner.battle_passive_counter_store.replace_state(
            snapshot["battle"]))
    return errors

func _source_identity(source) -> String:
    return "%s|%d" % [source.source_instance_key, source.behavior_index]
