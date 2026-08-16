class_name TechniqueInvocationService
extends RefCounted

const EffectContextScript = preload(
    "res://core/effects/battle_effect_context.gd")

var _resolution_service
var _ports
var _rng: RandomNumberGenerator
var _value_resolver
var _stack: Array[String] = []
var _invocation_serial: int = 0
var _receipts: Dictionary = {}
var _deferred_by_root: Dictionary = {}
var _deferred_by_timing: Dictionary = {}

func _init(resolution_service, executor, ports,
        rng: RandomNumberGenerator) -> void:
    _resolution_service = resolution_service
    _ports = ports
    _rng = rng
    _value_resolver = executor.registry.value_resolver

func invoke(effect: Dictionary, context) -> Dictionary:
    var runtime = EffectContextScript.coerce(context)
    if _resolution_service.has_pending_invocation(runtime):
        var pending_slot: String = \
            _resolution_service.pending_slot_instance_id(runtime)
        var resumed: Dictionary = _resolution_service.resolve_invocation({}, runtime)
        if not resumed.get("pending_choice", false):
            _stack.erase(pending_slot)
            if resumed.get("success", false):
                _receipts[str(resumed.get("invocation_token", ""))] = \
                    resumed.duplicate(true)
        return resumed
    var frozen := _freeze_request(effect, runtime)
    if not frozen.get("success", false) \
            or not frozen.get("triggered", true):
        return frozen
    var timing := str(effect.get("timing", "immediate"))
    if timing == "after_caller_advance":
        var root := _root_token(runtime)
        if not _deferred_by_root.has(root):
            _deferred_by_root[root] = []
        _deferred_by_root[root].append(frozen)
        return {
            "success": true, "deferred": true,
            "invocation_token": frozen["invocation_token"],
            "detail": "功法调用已冻结并等待调用者推进",
        }
    if timing in ["action_end", "round_end"]:
        if not _deferred_by_timing.has(timing):
            _deferred_by_timing[timing] = []
        _deferred_by_timing[timing].append(frozen)
        return {
            "success": true, "deferred": true,
            "invocation_token": frozen["invocation_token"],
            "detail": "功法调用已冻结并等待%s" % timing,
        }
    return _resolve_frozen(frozen)

func resolve_after_caller_advance(root_action_token: String) -> Dictionary:
    var requests: Array = _deferred_by_root.get(root_action_token, [])
    _deferred_by_root.erase(root_action_token)
    return _resolve_requests(requests)

func resolve_timing(timing: String, root_action_token: String = "") -> Dictionary:
    var queued: Array = _deferred_by_timing.get(timing, [])
    var selected: Array = []
    var remaining: Array = []
    for request_value in queued:
        var request: Dictionary = request_value
        if root_action_token == "" \
                or str(request.get("root_action_token", "")) == root_action_token:
            selected.append(request)
        else:
            remaining.append(request)
    if remaining.is_empty():
        _deferred_by_timing.erase(timing)
    else:
        _deferred_by_timing[timing] = remaining
    return _resolve_requests(selected)

func stack_slot_ids() -> Array[String]:
    return _stack.duplicate()

func enter_resolution_slot(slot_instance_id: String) -> bool:
    if slot_instance_id == "" or _stack.has(slot_instance_id):
        return false
    _stack.append(slot_instance_id)
    return true

func exit_resolution_slot(slot_instance_id: String, entered: bool) -> void:
    if entered:
        _stack.erase(slot_instance_id)

func reset() -> void:
    _stack.clear()
    _receipts.clear()
    _deferred_by_root.clear()
    _deferred_by_timing.clear()
    _invocation_serial = 0

func _resolve_requests(requests: Array) -> Dictionary:
    var results: Array = []
    for request_value in requests:
        var result := _resolve_frozen(request_value)
        results.append(result)
        if result.get("pending_choice", false):
            return {
                "success": false, "pending_choice": true,
                "choice_request": result.get("choice_request", {}),
                "_choice_request_object": result.get(
                    "_choice_request_object"),
                "results": results,
            }
        if not result.get("success", false):
            return {
                "success": false, "results": results,
                "reason": result.get("reason", "延后调用失败"),
            }
    return {"success": true, "results": results}

func _freeze_request(effect: Dictionary, runtime) -> Dictionary:
    var selection: Dictionary = effect.get("selection", {})
    var hand_id := str(selection.get("hand_id", runtime.actual_hand_id))
    if hand_id == "current":
        hand_id = runtime.actual_hand_id
    var candidates := _candidates(selection, runtime, hand_id)
    if candidates.is_empty():
        return {
            "success": true, "triggered": false,
            "detail": "没有合法调用目标",
        }
    var selected: Dictionary = candidates[0]
    if str(selection.get("mode", "next")) == "random":
        selected = candidates[_rng.randi_range(0, candidates.size() - 1)]
    _invocation_serial += 1
    var token := "%s:invoke:%06d:%s" % [
        _root_token(runtime), _invocation_serial,
        str(selected.get("slot_instance_id", "")),
    ]
    return {
        "success": true, "triggered": true,
        "invocation_token": token,
        "root_action_token": _root_token(runtime),
        "effect": effect.duplicate(true),
        "runtime": runtime,
        "hand_id": hand_id,
        "slot": selected.duplicate(true),
        "sequence_before": runtime.sequence_book.ordered_slots(hand_id),
        "hand_result": effect.get(
            "_hand_result_override", runtime.hand_result).duplicate(false),
        "consumed_marker_value": int(effect.get(
            "_consumed_marker_value", runtime.consumed_marker_value)),
        "captures": effect.get("_captures_override", {}).duplicate(true),
        "p0": int(effect.get(
            "_p0_override", _resolve_p0(effect.get("p0", {}), runtime))),
    }

func _candidates(selection: Dictionary, runtime, hand_id: String) -> Array:
    var mode := str(selection.get("mode", "next"))
    var candidates: Array = []
    match mode:
        "self":
            for slot in runtime.sequence_book.find_slots({"hand_id": hand_id}):
                if str(slot.get("slot_instance_id", "")) == runtime.slot_instance_id:
                    candidates = [slot]
                    break
        "by_id":
            candidates = runtime.sequence_book.find_slots({
                "hand_id": hand_id,
                "technique_id": str(selection.get("technique_id", "")),
            })
        "by_slot":
            for slot in runtime.sequence_book.find_slots({"hand_id": hand_id}):
                if str(slot.get("slot_instance_id", "")) == str(
                        selection.get("slot_instance_id", "")):
                    candidates = [slot]
                    break
        "next":
            var ordered: Array = runtime.sequence_book.ordered_slots(hand_id)
            candidates = [ordered[1]] if ordered.size() > 1 else []
        "random":
            candidates = runtime.sequence_book.ordered_slots(hand_id)
        _:
            return []
    var filters: Dictionary = selection.get("filters", {})
    return candidates.filter(func(slot):
        var slot_id := str(slot.get("slot_instance_id", ""))
        if slot_id == "" or _stack.has(slot_id):
            return false
        if filters.has("temporary") \
                and bool(filters["temporary"]) != bool(
                    slot.get("temporary", false)):
            return false
        if filters.has("exclude_technique_ids") \
                and filters["exclude_technique_ids"].has(str(
                    slot.get("technique_id", ""))):
            return false
        return true)

func _resolve_frozen(request: Dictionary) -> Dictionary:
    var token := str(request.get("invocation_token", ""))
    if _receipts.has(token):
        var reused: Dictionary = _receipts[token].duplicate(true)
        reused["reused"] = true
        return reused
    var runtime = request["runtime"]
    var slot: Dictionary = request["slot"]
    var slot_id := str(slot.get("slot_instance_id", ""))
    if _stack.has(slot_id):
        return {
            "success": true, "triggered": false,
            "detail": "结算栈中的槽位不能递归调用",
        }
    var preflight: Dictionary = _resolution_service.prepare_invocation(
        request, runtime)
    if not preflight.get("success", false) \
            or not preflight.get("triggered", true):
        return preflight
    request["_resolution_preflight"] = preflight
    var moved: Dictionary = runtime.sequence_book.move_slot_to_current(
        str(request.get("hand_id", "")), slot_id)
    if not moved.get("success", false):
        return moved
    _stack.append(slot_id)
    _ports.emit_technique_sequence_changed(
        runtime.actor, str(request.get("root_action_token", "")),
        "invoke_move", [slot])
    var result: Dictionary = _resolution_service.resolve_invocation(
        request, runtime)
    if result.get("pending_choice", false):
        return result
    _stack.erase(slot_id)
    if result.get("success", false):
        _receipts[token] = result.duplicate(true)
    return result

func _resolve_p0(p0_spec: Dictionary, runtime) -> int:
    match str(p0_spec.get("mode", "reuse_caller")):
        "fixed":
            return int(p0_spec.get("value", 0))
        "value_spec":
            return _value_resolver.resolve(p0_spec.get("value", 0), runtime)
        "recalculate":
            return int(runtime.initial_power)
    return int(runtime.initial_power)

func _root_token(runtime) -> String:
    return runtime.root_action_token \
        if runtime.root_action_token != "" else runtime.action_token
