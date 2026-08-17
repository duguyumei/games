class_name VisibleTriggerQueue
extends RefCounted

var pending: Array = []
var history: Array = []
var _serial: int = 0
var _game_log
var _choice_state: Dictionary = {}

func _init(game_log_override = null) -> void:
    _game_log = game_log_override

func clear() -> void:
    pending.clear()
    history.clear()
    _choice_state.clear()
    _serial = 0
    if _game_log != null:
        _game_log.clear("battle")

func capture_runtime_state() -> Dictionary:
    return {
        "pending": pending.duplicate(true),
        "history": history.duplicate(true),
        "serial": _serial,
        "choice_state": _choice_state.duplicate(true),
        "game_log": _game_log.capture_runtime_state() \
            if _game_log != null and _game_log.has_method(
                "capture_runtime_state") else {},
    }

func restore_runtime_state(state: Dictionary) -> void:
    pending.assign(state.get("pending", []))
    history.assign(state.get("history", []))
    _serial = int(state.get("serial", 0))
    _choice_state = state.get("choice_state", {}).duplicate(true)
    if _game_log != null and _game_log.has_method("restore_runtime_state"):
        _game_log.restore_runtime_state(state.get("game_log", {}))

func enqueue(timing: String, label: String, source: String, order: int, effects: Array, context) -> void:
    pending.append({
        "timing": timing,
        "label": label,
        "source": source,
        "order": order,
        "serial": _serial,
        "effects": effects.duplicate(true),
        "context": context,
        "status": "等待",
    })
    _serial += 1

func add_history(timing: String, label: String, source: String, status: String, detail: String = "") -> void:
    history.append({
        "timing": timing,
        "label": label,
        "source": source,
        "status": status,
        "detail": detail,
    })
    if _game_log != null:
        _game_log.record_battle(timing, label, source, status, detail)

func process_timing(timing: String, executor) -> Array:
    if not _choice_state.is_empty():
        return [{
            "pending_choice": true,
            "result": {
                "status": "pending_choice",
                "success": false,
                "pending_choice": true,
                "choice_request": pending_choice_snapshot(),
            },
        }]
    var matching: Array = []
    var remaining: Array = []
    for entry in pending:
        if entry["timing"] == timing:
            matching.append(entry)
        else:
            remaining.append(entry)
    pending = remaining
    matching.sort_custom(func(left, right):
        if left["order"] == right["order"]:
            return left["serial"] < right["serial"]
        return left["order"] < right["order"])
    var results: Array = []
    for index in range(matching.size()):
        var entry: Dictionary = matching[index]
        entry["status"] = "结算中"
        var result: Dictionary = executor.execute_all(entry["effects"], entry["context"])
        if result.get("pending_choice", false):
            entry["status"] = "等待选择"
            _choice_state = {
                "timing": timing,
                "matching": matching,
                "index": index,
                "entry": entry,
                "executor": executor,
                "results": results.duplicate(),
                "continuation": result.get("_continuation"),
                "pending_result": result,
            }
            results.append({"entry": entry, "result": result, "pending_choice": true})
            return results
        _finish_entry(entry, result, timing)
        results.append({"entry": entry, "result": result})
    return results

func has_pending_choice() -> bool:
    return not _choice_state.is_empty()

func pending_choice_snapshot() -> Dictionary:
    if _choice_state.is_empty():
        return {}
    var entry: Dictionary = _choice_state.get("entry", {})
    var continuation = _choice_state.get("continuation")
    if continuation != null and continuation.has_method("choice_snapshot"):
        return continuation.choice_snapshot()
    var result: Dictionary = _choice_state.get("pending_result", {})
    return result.get("choice_request", {}).duplicate(true)

func resolve_choice(request_id: String, selected_ids: Array) -> Array:
    if _choice_state.is_empty():
        return [{
            "pending_choice": false,
            "result": {"success": false, "detail": "当前没有等待中的选择"},
        }]
    var executor = _choice_state.get("executor")
    var entry: Dictionary = _choice_state["entry"]
    var continuation = _choice_state.get("continuation")
    if continuation == null:
        var pending_result: Dictionary = _choice_state.get("pending_result", {})
        continuation = pending_result.get("_continuation")
    if continuation == null:
        return [{
            "pending_choice": false,
            "result": {"success": false, "detail": "等待中的结算缺少 continuation"},
        }]
    var result: Dictionary = executor.resume(continuation, request_id, selected_ids)
    if result.get("pending_choice", false):
        entry["status"] = "等待选择"
        _choice_state["entry"] = entry
        _choice_state["continuation"] = result.get("_continuation")
        _choice_state["pending_result"] = result
        return [{"entry": entry, "result": result, "pending_choice": true}]

    var results: Array = _choice_state.get("results", []).duplicate()
    _finish_entry(entry, result, str(_choice_state["timing"]))
    results.append({"entry": entry, "result": result})
    var matching: Array = _choice_state["matching"]
    var next_index: int = int(_choice_state["index"]) + 1
    var timing: String = str(_choice_state["timing"])
    _choice_state.clear()
    for index in range(next_index, matching.size()):
        var next_entry: Dictionary = matching[index]
        next_entry["status"] = "结算中"
        var next_result: Dictionary = executor.execute_all(
            next_entry["effects"], next_entry["context"])
        if next_result.get("pending_choice", false):
            next_entry["status"] = "等待选择"
            _choice_state = {
                "timing": timing,
                "matching": matching,
                "index": index,
                "entry": next_entry,
                "executor": executor,
                "results": results.duplicate(),
                "continuation": next_result.get("_continuation"),
                "pending_result": next_result,
            }
            results.append({
                "entry": next_entry,
                "result": next_result,
                "pending_choice": true,
            })
            return results
        _finish_entry(next_entry, next_result, timing)
        results.append({"entry": next_entry, "result": next_result})
    return results

func _finish_entry(entry: Dictionary, result: Dictionary, timing: String) -> void:
    entry["status"] = "成功" if result.get("success", false) else "失败"
    add_history(
        timing,
        entry["label"],
        entry["source"],
        entry["status"],
        result.get("detail", ""))
