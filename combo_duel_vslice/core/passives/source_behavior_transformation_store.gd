class_name SourceBehaviorTransformationStore
extends RefCounted

## 保存来源在当前 Run 内已经完成的永久行为替换。
##
## 本 Store 只保存稳定内容 ID、同内容副本序号和行为索引；运行时仍由
## PassiveRuleSourceResolver 投影为普通 PassiveRuleSource，并继续走唯一
## ExecutionPlan、Handler、效果端口与计数器 Store。

const SCHEMA_VERSION := 1

var _catalog
var _records: Dictionary = {}

func _init(content_catalog = null) -> void:
    _catalog = content_catalog

func record_key(source) -> String:
    if source == null or str(source.source_kind) != "inner_skill":
        return ""
    return _key(
        str(source.content_id), int(source.content_instance_ordinal))

func has_record(source) -> bool:
    var key := record_key(source)
    return key != "" and _records.has(key)

func record_for(source) -> Dictionary:
    var key := record_key(source)
    return _records.get(key, {}).duplicate(true) if key != "" else {}

func lock(source, values: Dictionary) -> Dictionary:
    var key := record_key(source)
    if key == "":
        return {"success": false, "reason": "行为替换来源缺少稳定内功身份"}
    if _records.has(key):
        return {
            "success": true,
            "reused": true,
            "record": _records[key].duplicate(true),
        }
    var record := {
        "provider_content_id": str(source.content_id),
        "provider_content_instance_ordinal": int(
            source.content_instance_ordinal),
        "target_content_id": str(values.get("target_content_id", "")),
        "target_behaviors": values.get(
            "target_behaviors", []).duplicate(true),
    }
    var errors := _record_errors(record)
    if not errors.is_empty():
        return {"success": false, "reason": "；".join(errors)}
    _records[key] = record
    return {"success": true, "reused": false, "record": record.duplicate(true)}

func clear() -> void:
    _records.clear()

func clear_unowned(learned_inner_skill_ids: Array) -> Array[Dictionary]:
    var owned_counts: Dictionary = {}
    for value in learned_inner_skill_ids:
        var content_id := str(value)
        owned_counts[content_id] = int(owned_counts.get(content_id, 0)) + 1
    var removed: Array[Dictionary] = []
    for key_value in _records.keys():
        var record: Dictionary = _records[key_value]
        var content_id := str(record.get("provider_content_id", ""))
        var ordinal := int(record.get(
            "provider_content_instance_ordinal", 0))
        if ordinal < int(owned_counts.get(content_id, 0)):
            continue
        removed.append(record.duplicate(true))
        _records.erase(key_value)
    return removed

func capture_state() -> Dictionary:
    var records: Array = []
    for value in _records.values():
        records.append(value.duplicate(true))
    records.sort_custom(func(left, right):
        if str(left.get("provider_content_id", "")) \
                != str(right.get("provider_content_id", "")):
            return str(left.get("provider_content_id", "")) \
                < str(right.get("provider_content_id", ""))
        return int(left.get("provider_content_instance_ordinal", 0)) \
            < int(right.get("provider_content_instance_ordinal", 0)))
    return {"schema_version": SCHEMA_VERSION, "records": records}

func validate_state(state) -> Array[String]:
    return _validated_records(state).get("errors", [])

func replace_state(state) -> Array[String]:
    var validated := _validated_records(state)
    var errors: Array[String] = validated.get("errors", [])
    if errors.is_empty():
        _records = validated.get("records", {})
    return errors

func _validated_records(state) -> Dictionary:
    var errors: Array[String] = []
    var restored: Dictionary = {}
    if not state is Dictionary:
        return {
            "errors": ["source_behavior_transformation_state 必须是对象"] \
                as Array[String],
            "records": restored,
        }
    if int(state.get("schema_version", 0)) != SCHEMA_VERSION:
        errors.append("来源行为替换状态版本不受支持")
    var records = state.get("records", [])
    if not records is Array:
        errors.append("来源行为替换 records 必须是数组")
        return {"errors": errors, "records": restored}
    for index in range(records.size()):
        var value = records[index]
        if not value is Dictionary:
            errors.append("来源行为替换 records[%d] 必须是对象" % index)
            continue
        var record: Dictionary = value
        var record_errors := _record_errors(record)
        for message in record_errors:
            errors.append("records[%d]：%s" % [index, message])
        var key := _key(
            str(record.get("provider_content_id", "")),
            int(record.get("provider_content_instance_ordinal", -1)))
        if key != "" and restored.has(key):
            errors.append("来源行为替换包含重复来源：%s" % key)
        if record_errors.is_empty() and not restored.has(key):
            restored[key] = record.duplicate(true)
    return {"errors": errors, "records": restored}

func _record_errors(record: Dictionary) -> Array[String]:
    var errors: Array[String] = []
    for forbidden_field in [
            "definition", "configuration", "handler", "callable", "object"]:
        if record.has(forbidden_field):
            errors.append("不得保存 %s" % forbidden_field)
    var provider_id := str(record.get("provider_content_id", ""))
    var ordinal_value = record.get("provider_content_instance_ordinal")
    if provider_id == "":
        errors.append("provider_content_id 不能为空")
    if not ordinal_value is int or int(ordinal_value) < 0:
        errors.append("provider_content_instance_ordinal 必须是非负整数")
    var target_id := str(record.get("target_content_id", ""))
    if target_id == "":
        errors.append("target_content_id 不能为空")
    var behaviors = record.get("target_behaviors", [])
    if not behaviors is Array or behaviors.is_empty():
        errors.append("target_behaviors 必须是非空数组")
        return errors
    var provider_definition := _definition(provider_id)
    if _catalog != null and provider_definition.is_empty():
        errors.append("未知替换来源内功：%s" % provider_id)
    var target_definition := _definition(target_id)
    if _catalog != null and target_definition.is_empty():
        errors.append("未知替换目标内功：%s" % target_id)
        return errors
    var registry = _registry()
    var seen: Dictionary = {}
    for index in range(behaviors.size()):
        var descriptor = behaviors[index]
        if not descriptor is Dictionary:
            errors.append("target_behaviors[%d] 必须是对象" % index)
            continue
        var behavior_id := str(descriptor.get("behavior_id", ""))
        var behavior_index_value = descriptor.get("behavior_index")
        if behavior_id == "" or not behavior_index_value is int \
                or int(behavior_index_value) < 0:
            errors.append("target_behaviors[%d] 稳定行为字段无效" % index)
            continue
        var behavior_index := int(behavior_index_value)
        var identity := "%s|%d" % [behavior_id, behavior_index]
        if seen.has(identity):
            errors.append("target_behaviors 包含重复行为：%s" % identity)
        seen[identity] = true
        if target_definition.is_empty():
            continue
        var target_behaviors = target_definition.get("behaviors", [])
        if behavior_index >= target_behaviors.size() \
                or not target_behaviors[behavior_index] is Dictionary:
            errors.append("target_behaviors[%d] 索引超出当前目标正文" % index)
            continue
        var behavior: Dictionary = target_behaviors[behavior_index]
        if str(behavior.get("id", "")) != behavior_id:
            errors.append("target_behaviors[%d] 与当前目标正文不一致" % index)
            continue
        if not bool(target_definition.get("copyable", true)) \
                or not bool(behavior.get("copyable", true)) \
                or registry == null \
                or not registry.allows_behavior_copy(
                    behavior_id, behavior.get("configuration", {})):
            errors.append("target_behaviors[%d] 当前不可复制" % index)
    return errors

func _definition(content_id: String) -> Dictionary:
    if _catalog == null or not _catalog.has_method("get_by_id"):
        return {}
    return _catalog.get_by_id("inner_skill", content_id)

func _registry():
    if _catalog == null:
        return null
    return _catalog.get("passive_rule_registry")

func _key(content_id: String, ordinal: int) -> String:
    if content_id == "" or ordinal < 0:
        return ""
    return "inner_skill|%s|%d" % [content_id, ordinal]
