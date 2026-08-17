class_name StructuredGameLog
extends RefCounted

const BATTLE_CHANNEL := "battle"
const RUN_CHANNEL := "run"
const SYSTEM_CHANNEL := "system"

var _entries: Array = []
var _serial: int = 0

func clear(channel: String = "") -> void:
    if channel == "":
        _entries.clear()
        _serial = 0
        return
    var retained: Array = []
    for entry in _entries:
        if str(entry.get("channel", "")) != channel:
            retained.append(entry)
    _entries = retained

func record(
        channel: String,
        severity: String,
        category: String,
        message: String,
        detail: String = "",
        context: Dictionary = {}) -> Dictionary:
    var normalized_channel := (
        channel
        if channel in [BATTLE_CHANNEL, RUN_CHANNEL, SYSTEM_CHANNEL]
        else SYSTEM_CHANNEL)
    var entry := {
        "serial": _serial,
        "channel": normalized_channel,
        "severity": severity,
        "category": category,
        "message": message,
        "detail": detail,
        "context": context.duplicate(true),
    }
    _serial += 1
    _entries.append(entry)
    return entry.duplicate(true)

func record_battle(
        timing: String,
        label: String,
        source: String,
        status: String,
        detail: String = "") -> Dictionary:
    var severity := "error" if status == "失败" else "info"
    return record(
        BATTLE_CHANNEL,
        severity,
        timing,
        label,
        detail,
        {"source": source, "status": status})

func record_system(
        severity: String,
        category: String,
        message: String,
        detail: String = "",
        context: Dictionary = {}) -> Dictionary:
    return record(SYSTEM_CHANNEL, severity, category, message, detail, context)

func record_run(
        category: String,
        message: String,
        detail: String = "",
        context: Dictionary = {}) -> Dictionary:
    return record(RUN_CHANNEL, "info", category, message, detail, context)

func entries(channel: String = "", limit: int = 0) -> Array:
    var filtered: Array = []
    for entry in _entries:
        if channel == "" or str(entry.get("channel", "")) == channel:
            filtered.append(entry.duplicate(true))
    if limit > 0 and filtered.size() > limit:
        return filtered.slice(filtered.size() - limit)
    return filtered

func latest(channel: String = "") -> Dictionary:
    for index in range(_entries.size() - 1, -1, -1):
        var entry: Dictionary = _entries[index]
        if channel == "" or str(entry.get("channel", "")) == channel:
            return entry.duplicate(true)
    return {}

func capture_runtime_state() -> Dictionary:
    return {"entries": _entries.duplicate(true), "serial": _serial}

func restore_runtime_state(state: Dictionary) -> void:
    _entries.assign(state.get("entries", []))
    _serial = int(state.get("serial", 0))
