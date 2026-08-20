class_name RunPassiveCounterStore
extends RefCounted

const DefinitionScript = preload(
    "res://core/passives/passive_counter_definition.gd")
const KeyScript = preload("res://core/passives/passive_counter_key.gd")

const SCHEMA_VERSION := 1

var _catalog
var _values: Dictionary = {}

func _init(content_catalog = null) -> void:
    _catalog = content_catalog

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
        }
    return {"success": true, "value": resolved, "capped": capped}

func reset_value(key, definition) -> Dictionary:
    return set_value(key, definition, int(definition.default_value))

func clear() -> void:
    _values.clear()

func capture_state() -> Dictionary:
    var entries: Array = []
    for stored in _values.values():
        var entry: Dictionary = stored["key"].duplicate(true)
        entry["value"] = int(stored["value"])
        entries.append(entry)
    entries.sort_custom(func(left, right):
        for field in [
                "source_kind", "content_id", "counter_instance_key",
                "state_key", "counter_id"]:
            var left_value := str(left.get(field, ""))
            var right_value := str(right.get(field, ""))
            if left_value != right_value:
                return left_value < right_value
        return false)
    return {"version": SCHEMA_VERSION, "entries": entries}

func validate_state(state) -> Array[String]:
    return _validated_values(state).get("errors", [])

func replace_state(state) -> Array[String]:
    var validated := _validated_values(state)
    var errors: Array[String] = validated["errors"]
    if not errors.is_empty():
        return errors
    _values = validated["values"]
    return []

func clear_unowned(learned_inner_skill_ids: Array, item_ids: Array) -> Array[Dictionary]:
    var removed: Array[Dictionary] = []
    for storage_id in _values.keys():
        var stored: Dictionary = _values[storage_id]
        var key = KeyScript.new().configure(stored["key"])
        var resolved := resolve_definition(key)
        if not resolved.get("success", false):
            continue
        var definition = resolved["definition"]
        if definition.retention_policy != DefinitionScript.RETENTION_WHILE_OWNED:
            continue
        var owned := (
            learned_inner_skill_ids.has(key.content_id)
            if key.source_kind == "inner_skill"
            else item_ids.has(key.content_id))
        if owned:
            continue
        var entry: Dictionary = key.to_dict()
        entry["value"] = int(stored["value"])
        removed.append(entry)
        _values.erase(storage_id)
    return removed

func resolve_definition(key) -> Dictionary:
    var key_errors: Array[String] = key.validation_errors()
    if not key_errors.is_empty():
        return {"success": false, "reason": "；".join(key_errors)}
    if _catalog == null:
        return {"success": false, "reason": "计数器存储缺少内容目录"}
    var definition_source_kind: String = (
        key.definition_source_kind
        if key.definition_behavior_index >= 0 else key.source_kind)
    var definition_content_id: String = (
        key.definition_content_id
        if key.definition_behavior_index >= 0 else key.content_id)
    var definition: Dictionary = _catalog.get_by_id(
        definition_source_kind, definition_content_id)
    if definition.is_empty():
        return {
            "success": false,
            "reason": "未知内容：%s:%s" % [
                definition_source_kind, definition_content_id],
        }
    var registry = _catalog.get("passive_rule_registry")
    if registry == null:
        return {"success": false, "reason": "内容目录缺少被动 Registry"}
    var behaviors: Array = definition.get("behaviors", [])
    for behavior_index in range(behaviors.size()):
        var behavior_value = behaviors[behavior_index]
        if not behavior_value is Dictionary:
            continue
        var behavior: Dictionary = behavior_value
        if key.definition_behavior_index >= 0 and (
                behavior_index != key.definition_behavior_index \
                or str(behavior.get("id", "")) != key.definition_behavior_id):
            continue
        if str(behavior.get("state_key", "")) != key.state_key:
            continue
        var behavior_id := str(behavior.get("id", ""))
        for counter_definition in registry.counter_definitions(
                behavior_id, behavior.get("configuration", {})):
            if counter_definition.counter_id == key.counter_id:
                return {
                    "success": true,
                    "definition": counter_definition,
                    "behavior_id": behavior_id,
                }
    return {
        "success": false,
        "reason": "未知计数器定义：%s:%s:%s:%s" % [
            key.source_kind, key.content_id, key.state_key, key.counter_id],
    }

func _validated_values(state) -> Dictionary:
    var errors: Array[String] = []
    var result: Dictionary = {}
    if not state is Dictionary:
        return {"errors": ["passive_counter_state 必须是对象"] as Array[String], "values": result}
    if not state.get("version") is int \
            or int(state.get("version", 0)) != SCHEMA_VERSION:
        errors.append("passive_counter_state.version 不受支持")
    var entries = state.get("entries", [])
    if not entries is Array:
        errors.append("passive_counter_state.entries 必须是数组")
        return {"errors": errors, "values": result}
    for index in range(entries.size()):
        var entry = entries[index]
        if not entry is Dictionary:
            errors.append("passive_counter_state.entries[%d] 必须是对象" % index)
            continue
        for forbidden_field in [
                "definition", "configuration", "handler", "callable", "object"]:
            if entry.has(forbidden_field):
                errors.append(
                    "passive_counter_state.entries[%d] 不得保存 %s" % [
                        index, forbidden_field])
        var key = KeyScript.new().configure(entry)
        var key_errors: Array[String] = key.validation_errors()
        if not key_errors.is_empty():
            errors.append("entries[%d]：%s" % [index, "；".join(key_errors)])
            continue
        var storage_id: String = key.storage_key()
        if result.has(storage_id):
            errors.append("passive_counter_state 包含重复键：%s" % storage_id)
            continue
        if not entry.get("value") is int:
            errors.append("entries[%d].value 必须是整数" % index)
            continue
        var resolved := resolve_definition(key)
        if not resolved.get("success", false):
            errors.append("entries[%d]：%s" % [index, str(resolved.get("reason", ""))])
            continue
        var definition = resolved["definition"]
        var value := int(entry["value"])
        if value < int(definition.minimum) \
                or (definition.maximum is int and value > int(definition.maximum)):
            errors.append(
                "entries[%d].value 超出已声明范围：%d" % [index, value])
            continue
        if value == int(definition.default_value):
            continue
        result[storage_id] = {"key": key.to_dict(), "value": value}
    return {"errors": errors, "values": result}
