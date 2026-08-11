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
const ACTION_WINDOW_END := "action_window_end"
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
    ACTION_WINDOW_END,
    TURN_END,
    BATTLE_END,
]

var history: Array = []
var _handlers: Dictionary = {}
var _serial: int = 0
var _registration_serial: int = 0
var _trigger_queue

func _init(trigger_queue_override = null) -> void:
    _trigger_queue = trigger_queue_override
    for timing in ORDERED_TIMINGS:
        _handlers[timing] = []

func use_trigger_queue(queue) -> void:
    _trigger_queue = queue

func reset() -> void:
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
    var all_succeeded := true
    var failure_reason := ""
    for entry in matching:
        var raw_result
        if entry["weak_target"] != null:
            var target = entry["weak_target"].get_ref()
            if target == null:
                raw_result = {
                    "success": false,
                    "detail": "处理器目标已释放",
                }
            else:
                raw_result = target.call(str(entry["method"]), event)
        else:
            raw_result = entry["callback"].call(event)
        var result: Dictionary = (
            raw_result
            if raw_result is Dictionary
            else {"success": true})
        if not result.has("success"):
            result["success"] = true
        var handler_result := {
            "handler_id": str(entry["id"]),
            "order": int(entry["order"]),
            "success": bool(result["success"]),
            "detail": str(result.get("detail", "")),
        }
        event.handler_results.append(handler_result)
        all_succeeded = all_succeeded and bool(result["success"])
        if bool(entry["visible"]) and _trigger_queue != null:
            _trigger_queue.add_history(
                timing,
                str(entry["label"]),
                str(entry["source"]),
                "成功" if result["success"] else "失败",
                str(result.get("detail", "")))
        if not bool(result["success"]):
            failure_reason = "%s order=%d handler_id=%s reason=%s" % [
                timing,
                int(entry["order"]),
                str(entry["id"]),
                str(result.get(
                    "detail", result.get("reason", "处理器执行失败"))),
            ]
            break
    var snapshot: Dictionary = event.snapshot()
    history.append(snapshot)
    return {
        "success": all_succeeded,
        "event": event,
        "results": event.handler_results.duplicate(true),
        "reason": failure_reason,
    }

func history_snapshot(limit: int = 0) -> Array:
    var copied: Array = history.duplicate(true)
    if limit > 0 and copied.size() > limit:
        return copied.slice(copied.size() - limit)
    return copied
