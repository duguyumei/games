class_name BattlePassiveCounterStore
extends RefCounted

var _values: Dictionary = {}

func get_value(key, definition) -> int:
    var stored = _values.get(key.storage_key())
    if stored is Dictionary:
        return int(stored.get("value", definition.default_value))
    return int(definition.default_value)

func has_non_default_value(key, definition) -> bool:
    return get_value(key, definition) != int(definition.default_value)

func set_value(key, definition, value) -> Dictionary:
    if not value is int:
        return {"success": false, "reason": "计数器值必须是整数"}
    var resolved := int(value)
    if resolved < int(definition.minimum):
        return {
            "success": false,
            "reason": "计数器值 %d 低于 minimum %d" % [
                resolved, int(definition.minimum)],
        }
    var capped := false
    if definition.maximum is int and resolved > int(definition.maximum):
        resolved = int(definition.maximum)
        capped = true
    if resolved == int(definition.default_value):
        _values.erase(key.storage_key())
    else:
        _values[key.storage_key()] = {
            "key": key.to_dict(),
            "value": resolved,
            "reset_scope": definition.reset_scope,
            "default_value": int(definition.default_value),
        }
    return {"success": true, "value": resolved, "capped": capped}

func reset_scope(scope: String, owner_id: String) -> int:
    var removed := 0
    for storage_id in _values.keys():
        var stored: Dictionary = _values[storage_id]
        if str(stored.get("reset_scope", "")) != scope \
                or str(stored.get("key", {}).get("owner_id", "")) != owner_id:
            continue
        _values.erase(storage_id)
        removed += 1
    return removed

func clear() -> void:
    _values.clear()

func is_empty() -> bool:
    return _values.is_empty()

## 仅用于战斗内事务；这个结构不进入 RunProgressSnapshot 或存档。
func capture_state() -> Dictionary:
    return {"entries": _values.duplicate(true)}

func replace_state(state) -> Array[String]:
    if not state is Dictionary or not state.get("entries") is Dictionary:
        return ["战斗临时计数器事务状态无效"] as Array[String]
    _values = state["entries"].duplicate(true)
    return []
