class_name StatusHistoryService
extends RefCounted

const StatusChangeScript = preload("res://core/status_change.gd")

var content_catalog
var history: Array = []
var _serial: int = 0
var _game_log = null

func _init(catalog, game_log = null) -> void:
    content_catalog = catalog
    use_game_log(game_log)

func record_change(
        change_type: String,
        target_kind: String,
        target_id: String,
        status_id: String,
        before_value,
        after_value,
        source: String,
        metadata: Dictionary = {}) -> Dictionary:
    var change = StatusChangeScript.new().configure({
        "serial": _serial,
        "change_type": change_type,
        "target_kind": target_kind,
        "target_id": target_id,
        "status_id": status_id,
        "before_value": before_value,
        "after_value": after_value,
        "source": source,
        "metadata": metadata,
    })
    _serial += 1
    var snapshot: Dictionary = change.snapshot()
    history.append(snapshot)
    if _game_log != null:
        _game_log.record_battle(
            "status_change",
            "%s·%s" % [target_id, _status_name(status_id)],
            source,
            "成功",
            "%s → %s" % [str(before_value), str(after_value)])
    return snapshot

func history_snapshot(limit: int = 0) -> Array:
    var copied: Array = history.duplicate(true)
    if limit > 0 and copied.size() > limit:
        return copied.slice(copied.size() - limit)
    return copied

func reset() -> void:
    history.clear()
    _serial = 0

func use_game_log(game_log) -> void:
    _game_log = game_log

func replace_history(entries: Array) -> void:
    var restored_entries := entries.duplicate(true)
    history.assign(restored_entries)
    var maximum_serial := -1
    for entry_value in history:
        if entry_value is Dictionary and entry_value.has("serial"):
            maximum_serial = maxi(
                maximum_serial, int(entry_value.get("serial", -1)))
    _serial = maximum_serial + 1

func history_entries() -> Array:
    return history

func _status_name(status_id: String) -> String:
    var anomaly: Dictionary = content_catalog.get_by_id("anomaly", status_id)
    return str(anomaly.get("name", status_id)) \
        if not anomaly.is_empty() else status_id
