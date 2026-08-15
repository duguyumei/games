class_name SourceMarkerStore
extends RefCounted

const SCHEMA_VERSION := 1
const SOURCE_KINDS := ["technique", "inner_skill"]
const SCOPES := ["battle", "run"]

var _entries: Dictionary = {}

func write(
        source_kind: String,
        source_instance_key: String,
        content_id: String,
        marker_id: String,
        scope: String,
        operation: String,
        amount: int,
        metadata: Dictionary = {}) -> Dictionary:
    if source_kind not in SOURCE_KINDS or source_instance_key == "" \
            or marker_id == "" or scope not in SCOPES:
        return {"success": false, "reason": "来源标识键无效"}
    var key := _key(source_kind, source_instance_key, marker_id, scope)
    var before := int(_entries.get(key, {}).get("value", 0))
    var after := before
    match operation:
        "add":
            after = before + amount
        "set":
            after = amount
        "subtract", "consume":
            after = maxi(0, before - maxi(0, amount))
        "clear":
            after = 0
        _:
            return {"success": false, "reason": "未知来源标识操作：%s" % operation}
    var consumed := maxi(0, before - after) if operation in ["subtract", "consume", "clear"] else 0
    var entry := {
        "source_kind": source_kind,
        "source_instance_key": source_instance_key,
        "content_id": content_id,
        "marker_id": marker_id,
        "scope": scope,
        "value": after,
        "public": bool(metadata.get("public", true)),
        "display_name": str(metadata.get("display_name", marker_id)),
        "contributes_to": str(metadata.get("contributes_to", "")),
        "forget_policy": str(metadata.get("forget_policy", "clear")),
    }
    if after == 0 and bool(metadata.get("remove_zero", operation == "clear")):
        _entries.erase(key)
    else:
        _entries[key] = entry
    return {
        "success": true,
        "changed": before != after,
        "before": before,
        "after": after,
        "delta": after - before,
        "consumed": consumed,
        "entry": entry.duplicate(true),
    }

func value(
        source_kind: String,
        source_instance_key: String,
        marker_id: String,
        scope: String = "") -> int:
    var total := 0
    for entry_value in _entries.values():
        var entry: Dictionary = entry_value
        if str(entry.get("source_kind", "")) != source_kind \
                or str(entry.get("source_instance_key", "")) != source_instance_key \
                or str(entry.get("marker_id", "")) != marker_id:
            continue
        if scope != "" and str(entry.get("scope", "")) != scope:
            continue
        total += int(entry.get("value", 0))
    return total

func sum(filters: Dictionary = {}) -> int:
    var total := 0
    for entry_value in entries(filters):
        total += int(entry_value.get("value", 0))
    return total

func entries(filters: Dictionary = {}) -> Array:
    var result: Array = []
    for entry_value in _entries.values():
        var entry: Dictionary = entry_value
        var matched := true
        for field in [
                "source_kind", "source_instance_key", "content_id",
                "marker_id", "scope", "contributes_to"]:
            if filters.has(field) and str(filters[field]) != str(entry.get(field, "")):
                matched = false
                break
        if matched and filters.has("public") \
                and bool(filters["public"]) != bool(entry.get("public", false)):
            matched = false
        if matched:
            result.append(entry.duplicate(true))
    result.sort_custom(func(left, right):
        return _sort_key(left) < _sort_key(right))
    return result

func transfer(
        from_filters: Dictionary,
        target: Dictionary,
        amount: int) -> Dictionary:
    var sources := entries(from_filters)
    if sources.is_empty() or amount <= 0:
        return {"success": true, "transferred": 0}
    var source: Dictionary = sources[0]
    var available := int(source.get("value", 0))
    var moved := mini(available, amount)
    if moved <= 0:
        return {"success": true, "transferred": 0}
    var removed := write(
        str(source["source_kind"]), str(source["source_instance_key"]),
        str(source["content_id"]), str(source["marker_id"]),
        str(source["scope"]), "consume", moved, source)
    if not removed.get("success", false):
        return removed
    var added := write(
        str(target.get("source_kind", source["source_kind"])),
        str(target.get("source_instance_key", "")),
        str(target.get("content_id", "")),
        str(target.get("marker_id", source["marker_id"])),
        str(target.get("scope", source["scope"])), "add", moved, target)
    if not added.get("success", false):
        write(
            str(source["source_kind"]), str(source["source_instance_key"]),
            str(source["content_id"]), str(source["marker_id"]),
            str(source["scope"]), "add", moved, source)
        return added
    return {"success": true, "transferred": moved, "source": removed, "target": added}

func clear_scope(scope: String) -> void:
    for key in _entries.keys():
        if str(_entries[key].get("scope", "")) == scope:
            _entries.erase(key)

func remove_entries(filters: Dictionary, preserve_retained: bool = false) -> Array:
    var removed: Array = []
    for key in _entries.keys():
        var entry: Dictionary = _entries[key]
        var matched := true
        for field in [
                "source_kind", "source_instance_key", "content_id",
                "marker_id", "scope", "contributes_to"]:
            if filters.has(field) and str(filters[field]) != str(entry.get(field, "")):
                matched = false
                break
        if not matched or (preserve_retained \
                and str(entry.get("forget_policy", "clear")) == "retain"):
            continue
        removed.append(entry.duplicate(true))
        _entries.erase(key)
    return removed

func snapshot(scope: String = "") -> Dictionary:
    return {
        "schema_version": SCHEMA_VERSION,
        "entries": entries({"scope": scope}) if scope != "" else entries(),
    }

func restore_snapshot(value: Dictionary, replace: bool = true) -> Array[String]:
    var errors: Array[String] = []
    if replace:
        _entries.clear()
    if int(value.get("schema_version", SCHEMA_VERSION)) != SCHEMA_VERSION:
        errors.append("来源标识存档版本不受支持")
        return errors
    var seen: Dictionary = {}
    for index in range(value.get("entries", []).size()):
        var entry = value["entries"][index]
        if not entry is Dictionary:
            errors.append("来源标识条目必须是对象")
            continue
        var key := _key(
            str(entry.get("source_kind", "")),
            str(entry.get("source_instance_key", "")),
            str(entry.get("marker_id", "")),
            str(entry.get("scope", "")))
        if key in seen or str(entry.get("source_kind", "")) not in SOURCE_KINDS \
                or str(entry.get("scope", "")) not in SCOPES \
                or str(entry.get("source_instance_key", "")) == "" \
                or str(entry.get("marker_id", "")) == "" \
                or not entry.get("value", 0) is int:
            errors.append("来源标识条目键、值或范围无效：%d" % index)
            continue
        seen[key] = true
        _entries[key] = entry.duplicate(true)
    return errors

func public_projection() -> Array:
    return entries({"public": true})

func _key(source_kind: String, source_instance_key: String, marker_id: String, scope: String) -> String:
    return "%s|%s|%s|%s" % [source_kind, source_instance_key, marker_id, scope]

func _sort_key(entry: Dictionary) -> String:
    return "%s|%s|%s|%s" % [
        str(entry.get("source_kind", "")),
        str(entry.get("source_instance_key", "")),
        str(entry.get("scope", "")),
        str(entry.get("marker_id", "")),
    ]
