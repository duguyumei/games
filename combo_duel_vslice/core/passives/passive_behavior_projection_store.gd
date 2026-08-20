class_name PassiveBehaviorProjectionStore
extends RefCounted

## 只保存当前战斗已经锁定的被动投影选择。实时邻接投影不写入本 Store。
## 记录只包含稳定 ID、索引和整数，不保存内容 Dictionary 或运行时对象。

const SCHEMA_VERSION := 1

var _records: Dictionary = {}

func record_key(source) -> String:
    if source == null:
        return ""
    return "%s|%s|%d|%d" % [
        str(source.source_kind), str(source.content_id),
        int(source.content_instance_ordinal), int(source.behavior_index)]

func has_record(source) -> bool:
    var key := record_key(source)
    return key != "" and _records.has(key)

func record_for(source) -> Dictionary:
    var key := record_key(source)
    return _records.get(key, {}).duplicate(true) if key != "" else {}

func lock(source, values: Dictionary) -> Dictionary:
    var key := record_key(source)
    if key == "":
        return {"success": false, "reason": "投影来源缺少稳定身份"}
    if _records.has(key):
        return {
            "success": true,
            "reused": true,
            "record": _records[key].duplicate(true),
        }
    var record := {
        "mode": str(values.get("mode", "")),
        "has_target": bool(values.get("has_target", false)),
        "target_source_kind": str(values.get("target_source_kind", "")),
        "target_content_id": str(values.get("target_content_id", "")),
        "target_source_instance_key": str(values.get(
            "target_source_instance_key", "")),
        "target_source_order": int(values.get("target_source_order", 0)),
        "target_slot_index": int(values.get("target_slot_index", -1)),
        "target_content_instance_ordinal": int(values.get(
            "target_content_instance_ordinal", 0)),
        "target_behaviors": values.get("target_behaviors", []).duplicate(true),
        "additional_executions": int(values.get("additional_executions", 0)),
    }
    var errors := _record_errors(record)
    if not errors.is_empty():
        return {"success": false, "reason": "；".join(errors)}
    _records[key] = record
    return {"success": true, "reused": false, "record": record.duplicate(true)}

func clear() -> void:
    _records.clear()

func capture_state() -> Dictionary:
    return {"schema_version": SCHEMA_VERSION, "records": _records.duplicate(true)}

func replace_state(state) -> Array[String]:
    var errors: Array[String] = []
    if not state is Dictionary:
        return ["被动投影状态必须是对象"] as Array[String]
    if int(state.get("schema_version", 0)) != SCHEMA_VERSION:
        errors.append("被动投影状态版本不受支持")
    var records = state.get("records", {})
    if not records is Dictionary:
        errors.append("被动投影 records 必须是对象")
        return errors
    var restored: Dictionary = {}
    for key_value in records:
        var key := str(key_value)
        var record = records[key_value]
        if key == "" or not record is Dictionary:
            errors.append("被动投影记录无效：%s" % key)
            continue
        var record_errors := _record_errors(record)
        for message in record_errors:
            errors.append("%s：%s" % [key, message])
        if record_errors.is_empty():
            restored[key] = record.duplicate(true)
    if errors.is_empty():
        _records = restored
    return errors

func _record_errors(record: Dictionary) -> Array[String]:
    var errors: Array[String] = []
    var mode := str(record.get("mode", ""))
    if mode not in ["battle_locked_random_other", "battle_locked_leftmost_repeat"]:
        errors.append("未知锁定投影模式：%s" % mode)
    if int(record.get("additional_executions", 0)) < 0:
        errors.append("additional_executions 必须是非负整数")
    var has_target := bool(record.get("has_target", false))
    if has_target:
        for field in ["target_source_kind", "target_content_id",
                "target_source_instance_key"]:
            if str(record.get(field, "")) == "":
                errors.append("有目标的投影记录缺少 %s" % field)
        if not record.get("target_behaviors", []) is Array:
            errors.append("target_behaviors 必须是数组")
        elif record.get("target_behaviors", []).is_empty():
            errors.append("有目标的投影记录必须至少包含一个行为")
    return errors
