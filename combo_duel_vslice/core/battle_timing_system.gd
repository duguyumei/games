class_name BattleTimingSystem
extends RefCounted

const TimingEventScript = preload("res://core/battle_timing_event.gd")

const BATTLE_START := "battle_start"
const ROUND_START := "round_start"
const TURN_START := "turn_start"
const BEFORE_NORMAL_DRAW := "before_normal_draw"
const AFTER_NORMAL_DRAW := "after_normal_draw"
const ACTION_WINDOW_START := "action_window_start"
const GROUP_END := "group_end"
const ACTION_RESOLUTION_END := "action_resolution_end"
const ACTION_WINDOW_END := "action_window_end"
const DEFENSE_DECAY_RESOLVED := "defense_decay_resolved"
const TURN_END := "turn_end"
const BATTLE_END := "battle_end"

const ORDERED_TIMINGS := [
    BATTLE_START,
    ROUND_START,
    TURN_START,
    BEFORE_NORMAL_DRAW,
    AFTER_NORMAL_DRAW,
    ACTION_WINDOW_START,
    GROUP_END,
    ACTION_RESOLUTION_END,
    ACTION_WINDOW_END,
    DEFENSE_DECAY_RESOLVED,
    TURN_END,
    BATTLE_END,
]

var history: Array = []
var _handlers: Dictionary = {}
var _serial: int = 0
var _registration_serial: int = 0
var _trigger_queue
var _pending_timing: Dictionary = {}
var _begin_transaction: Callable
var _commit_transaction: Callable
var _rollback_transaction: Callable

func _init(trigger_queue_override = null) -> void:
    _trigger_queue = trigger_queue_override
    for timing in ORDERED_TIMINGS:
        _handlers[timing] = []

func use_trigger_queue(queue) -> void:
    _trigger_queue = queue

func use_mutation_transaction_callbacks(
        begin_callback: Callable,
        commit_callback: Callable,
        rollback_callback: Callable) -> void:
    _begin_transaction = begin_callback
    _commit_transaction = commit_callback
    _rollback_transaction = rollback_callback

func reset() -> void:
    if not _pending_timing.is_empty() and _rollback_transaction.is_valid():
        _rollback_transaction.call(_pending_timing.get("transaction", {}))
    _pending_timing.clear()
    history.clear()
    _serial = 0

func register_handler(
        timing: String,
        handler_id: String,
        order: int,
        callback: Callable,
        visible: bool = false,
        label: String = "",
        source: String = "战斗时序") -> bool:
    if timing not in ORDERED_TIMINGS \
            or handler_id == "" \
            or not callback.is_valid():
        return false
    return _register_entry(timing, handler_id, order, {
        "callback": callback,
        "weak_target": null,
        "method": "",
        "visible": visible,
        "label": label if label != "" else handler_id,
        "source": source,
    })

func register_weak_handler(
        timing: String,
        handler_id: String,
        order: int,
        target,
        method: String,
        visible: bool = false,
        label: String = "",
        source: String = "战斗时序") -> bool:
    if timing not in ORDERED_TIMINGS \
            or handler_id == "" \
            or target == null \
            or method == "" \
            or not target.has_method(method):
        return false
    return _register_entry(timing, handler_id, order, {
        "callback": Callable(),
        "weak_target": weakref(target),
        "method": method,
        "visible": visible,
        "label": label if label != "" else handler_id,
        "source": source,
    })

func _register_entry(
        timing: String,
        handler_id: String,
        order: int,
        handler_data: Dictionary) -> bool:
    for entry in _handlers[timing]:
        if str(entry["id"]) == handler_id:
            return false
    var entry := {
        "id": handler_id,
        "order": order,
        "serial": _registration_serial,
    }
    entry.merge(handler_data)
    _handlers[timing].append(entry)
    _registration_serial += 1
    return true

func unregister_handler(timing: String, handler_id: String) -> bool:
    if timing not in ORDERED_TIMINGS:
        return false
    for entry in _handlers[timing]:
        if str(entry["id"]) != handler_id:
            continue
        _handlers[timing].erase(entry)
        return true
    return false

func emit_timing(timing: String, context: Dictionary = {}) -> Dictionary:
    if not _pending_timing.is_empty():
        return {
            "success": false,
            "pending_choice": true,
            "reason": "已有等待选择的战斗时点",
            "choice_request": pending_choice_snapshot(),
            "results": [],
        }
    if timing not in ORDERED_TIMINGS:
        return {
            "success": false,
            "reason": "未知战斗时点：%s" % timing,
            "results": [],
        }
    var event = TimingEventScript.new().configure(timing, _serial, context)
    _serial += 1
    var matching: Array = _handlers[timing].duplicate()
    matching.sort_custom(func(left, right):
        if int(left["order"]) == int(right["order"]):
            return int(left["serial"]) < int(right["serial"])
        return int(left["order"]) < int(right["order"]))
    var transaction: Dictionary = _begin_transaction.call() \
        if _begin_transaction.is_valid() else {}
    return _continue_timing({
        "timing": timing,
        "event": event,
        "matching": matching,
        "index": 0,
        "transaction": transaction,
        "resume_callable": Callable(),
        "choice_request": {},
        "resolved_request_ids": [],
    })

func has_pending_choice() -> bool:
    return not _pending_timing.is_empty()

func pending_choice_snapshot() -> Dictionary:
    return _pending_timing.get("choice_request", {}).duplicate(true)

func resolve_choice(request_id: String, selected_ids: Array) -> Dictionary:
    if _pending_timing.is_empty():
        return {"success": false, "pending_choice": false,
            "reason": "当前没有等待中的生命周期选择"}
    var expected := str(_pending_timing.get(
        "choice_request", {}).get("request_id", ""))
    if request_id == "" or request_id != expected:
        return _pending_failure("选择 request_id 与当前生命周期请求不匹配")
    if _pending_timing.get("resolved_request_ids", []).has(request_id):
        return _pending_failure("生命周期选择请求已经成功提交")
    var resume_callable: Callable = _pending_timing.get("resume_callable")
    if not resume_callable.is_valid():
        return _fail_pending_timing("生命周期选择缺少恢复入口")
    var resumed = resume_callable.call(request_id, selected_ids)
    var result: Dictionary = resumed if resumed is Dictionary else {
        "success": false, "detail": "生命周期选择恢复结果无效"}
    if result.get("pending_choice", false):
        var next_request: Dictionary = result.get(
            "choice_request", {}).duplicate(true)
        var same_request := str(next_request.get("request_id", "")) == request_id
        if not same_request:
            _pending_timing["resolved_request_ids"].append(request_id)
        _pending_timing["choice_request"] = next_request
        _pending_timing["resume_callable"] = result.get(
            "_resume_callable", resume_callable)
        return {
            "success": not same_request,
            "pending_choice": true,
            "choice_request": next_request,
            "reason": str(result.get("detail", "")) if same_request else "",
            "detail": str(result.get("detail", "等待生命周期选择")),
        }
    if not result.get("success", false):
        return _fail_pending_timing(str(result.get(
            "detail", result.get("reason", "生命周期选择恢复失败"))))
    _pending_timing["resolved_request_ids"].append(request_id)
    var entry: Dictionary = _pending_timing["matching"][int(
        _pending_timing["index"])]
    _record_handler_result(_pending_timing, entry, result)
    _pending_timing["index"] = int(_pending_timing["index"]) + 1
    _pending_timing["resume_callable"] = Callable()
    _pending_timing["choice_request"] = {}
    return _continue_timing(_pending_timing)

func _continue_timing(state: Dictionary) -> Dictionary:
    var matching: Array = state["matching"]
    while int(state["index"]) < matching.size():
        var entry: Dictionary = matching[int(state["index"])]
        var result := _invoke_entry(entry, state["event"])
        if result.get("pending_choice", false):
            var request: Dictionary = result.get(
                "choice_request", {}).duplicate(true)
            if str(request.get("request_id", "")) == "" \
                    or not result.get("_resume_callable") is Callable \
                    or not result.get("_resume_callable").is_valid():
                return _fail_timing_state(
                    state, "生命周期 pending_choice 缺少稳定请求或恢复入口")
            state["choice_request"] = request
            state["resume_callable"] = result["_resume_callable"]
            _pending_timing = state
            return {
                "success": true,
                "pending_choice": true,
                "choice_request": request,
                "event": state["event"],
                "results": state["event"].handler_results.duplicate(true),
                "reason": "",
            }
        _record_handler_result(state, entry, result)
        if not result.get("success", false):
            return _fail_timing_state(state, "%s order=%d handler_id=%s reason=%s" % [
                str(state["timing"]), int(entry["order"]), str(entry["id"]),
                str(result.get(
                    "detail", result.get("reason", "处理器执行失败")))])
        state["index"] = int(state["index"]) + 1
    if _commit_transaction.is_valid():
        _commit_transaction.call(state.get("transaction", {}))
    history.append(state["event"].snapshot())
    var completed := {
        "success": true,
        "pending_choice": false,
        "event": state["event"],
        "results": state["event"].handler_results.duplicate(true),
        "reason": "",
    }
    _pending_timing = {}
    return completed

func _invoke_entry(entry: Dictionary, event) -> Dictionary:
    var raw_result
    if entry["weak_target"] != null:
        var target = entry["weak_target"].get_ref()
        raw_result = target.call(str(entry["method"]), event) \
            if target != null else {
                "success": false, "detail": "处理器目标已释放"}
    else:
        raw_result = entry["callback"].call(event)
    var result: Dictionary = raw_result if raw_result is Dictionary else {
        "success": true}
    if not result.has("success"):
        result["success"] = true
    return result

func _record_handler_result(
        state: Dictionary, entry: Dictionary, result: Dictionary) -> void:
    var handler_result := {
        "handler_id": str(entry["id"]),
        "order": int(entry["order"]),
        "success": bool(result.get("success", false)),
        "detail": str(result.get("detail", "")),
    }
    state["event"].handler_results.append(handler_result)
    if bool(entry["visible"]) and _trigger_queue != null:
        _trigger_queue.add_history(
            str(state["timing"]), str(entry["label"]), str(entry["source"]),
            "成功" if result.get("success", false) else "失败",
            str(result.get("detail", "")))

func _fail_timing_state(state: Dictionary, reason: String) -> Dictionary:
    if _rollback_transaction.is_valid():
        _rollback_transaction.call(state.get("transaction", {}))
    var failed := {
        "success": false,
        "pending_choice": false,
        "event": state.get("event"),
        "results": state.get("event").handler_results.duplicate(true) \
            if state.get("event") != null else [],
        "reason": reason,
    }
    _pending_timing = {}
    return failed

func _fail_pending_timing(reason: String) -> Dictionary:
    return _fail_timing_state(_pending_timing, reason)

func _pending_failure(reason: String) -> Dictionary:
    return {
        "success": false,
        "pending_choice": true,
        "choice_request": pending_choice_snapshot(),
        "reason": reason,
    }

func history_snapshot(limit: int = 0) -> Array:
    var copied: Array = history.duplicate(true)
    if limit > 0 and copied.size() > limit:
        return copied.slice(copied.size() - limit)
    return copied
