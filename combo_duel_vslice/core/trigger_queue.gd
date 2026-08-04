class_name VisibleTriggerQueue
extends RefCounted

var pending: Array = []
var history: Array = []
var _serial: int = 0

func clear() -> void:
    pending.clear()
    history.clear()
    _serial = 0

func enqueue(timing: String, label: String, source: String, order: int, effects: Array, context: Dictionary) -> void:
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

func process_timing(timing: String, executor) -> Array:
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
    for entry in matching:
        entry["status"] = "结算中"
        var result: Dictionary = executor.execute_all(entry["effects"], entry["context"])
        entry["status"] = "成功" if result.get("success", false) else "失败"
        add_history(timing, entry["label"], entry["source"], entry["status"], result.get("detail", ""))
        results.append({"entry": entry, "result": result})
    return results

