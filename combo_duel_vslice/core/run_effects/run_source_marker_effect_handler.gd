class_name RunSourceMarkerEffectHandler
extends "res://core/run_effects/run_effect_handler.gd"

const AddressResolverScript = preload(
    "res://core/source_marker_address_resolver.gd")

const OPERATIONS := ["add", "set", "subtract", "consume", "clear"]
const SOURCE_FIELDS := [
    "source_kind", "source_id", "content_id", "source_instance_key",
    "scope", "public", "display_name", "contributes_to", "forget_policy",
]

var _address_resolver = AddressResolverScript.new()


func operation_ids() -> Array[String]:
    return ["write_source_marker"]


func validate_effect(effect: Dictionary, validator, scope: String) -> void:
    for field_value in effect:
        var field := str(field_value)
        if field in SOURCE_FIELDS:
            validator.report_error(
                "%s.%s" % [scope, field],
                "来源地址与声明由当前 Invocation 注入，内容不得伪造")
            continue
        if field not in ["op", "marker_id", "operation", "amount"]:
            validator.report_error(
                "%s.%s" % [scope, field],
                "Run 来源标识效果不支持该字段")
    var marker_id := str(effect.get("marker_id", ""))
    if marker_id == "":
        validator.report_error(scope + ".marker_id", "必须是非空 snake_case")
    var operation := str(effect.get("operation", ""))
    if operation not in OPERATIONS:
        validator.report_error(scope + ".operation", "不是已登记的来源标识操作")
    var amount = effect.get("amount", 0)
    if not _is_integer(amount) or int(amount) < 0:
        validator.report_error(scope + ".amount", "必须是非负整数")
    elif operation == "add" and int(amount) <= 0:
        validator.report_error(scope + ".amount", "add 必须使用正整数")


func apply(effect: Dictionary, context) -> Dictionary:
    var source_kind := str(context.metadata.get("source_kind", ""))
    var source_id := str(context.metadata.get("source_id", ""))
    var source_instance_key := str(context.metadata.get(
        "source_instance_key", ""))
    if source_kind not in ["inner_skill", "item", "technique"] \
            or source_id == "" or source_instance_key == "":
        return {"success": false, "reason": "Run 来源标识缺少当前 Invocation 来源"}
    var marker_id := str(effect.get("marker_id", ""))
    var marker_definition := _marker_definition(
        context.metadata.get("source_marker_definitions", []), marker_id)
    if marker_definition.is_empty():
        return {
            "success": false,
            "reason": "当前来源未声明 Run marker：%s/%s" % [
                source_id, marker_id],
        }
    if str(marker_definition.get("scope", "")) != "run":
        return {"success": false, "reason": "Run 效果只能写入 run scope marker"}
    var runtime := {
        "owner": context.growth,
        "actor": context.growth,
        "source_kind": source_kind,
        "source_id": source_id,
        "source_instance_key": source_instance_key,
        "source_marker_definitions": context.metadata.get(
            "source_marker_definitions", []).duplicate(true),
    }
    var spec := marker_definition.duplicate(true)
    spec["marker_id"] = marker_id
    spec["scope"] = "run"
    var address: Dictionary = _address_resolver.resolve(spec, runtime)
    if not address.get("success", false):
        return address
    if str(address.get("source_kind", "")) != source_kind \
            or str(address.get("content_id", "")) != source_id \
            or str(address.get("source_instance_key", "")) \
                != source_instance_key:
        return {"success": false, "reason": "Run 来源标识地址与 Invocation 不一致"}
    var written: Dictionary = context.growth.source_marker_store.write(
        source_kind,
        source_instance_key,
        source_id,
        marker_id,
        "run",
        str(effect.get("operation", "")),
        int(effect.get("amount", 0)),
        address)
    if not written.get("success", false):
        return written
    var change := _change_fact(
        address, str(effect.get("operation", "")), written)
    if written.get("changed", false):
        context.record_committed_events([change])
    return {
        "success": true,
        "applied": {
            "op": "write_source_marker",
            "marker_id": marker_id,
            "operation": str(effect.get("operation", "")),
            "amount": int(effect.get("amount", 0)),
            "changed": bool(written.get("changed", false)),
            "before": int(written.get("before", 0)),
            "after": int(written.get("after", 0)),
            "source_marker_changes": [change] \
                if written.get("changed", false) else [],
        },
    }


func _marker_definition(definitions, marker_id: String) -> Dictionary:
    if not definitions is Array:
        return {}
    for value in definitions:
        if value is Dictionary and str(value.get("id", "")) == marker_id:
            return value.duplicate(true)
    return {}


func _change_fact(
        address: Dictionary,
        operation: String,
        result: Dictionary) -> Dictionary:
    return {
        "event_type": "source_marker_changed",
        "operation": operation,
        "source_kind": str(address.get("source_kind", "")),
        "source_instance_key": str(address.get("source_instance_key", "")),
        "content_id": str(address.get("content_id", "")),
        "marker_id": str(address.get("marker_id", "")),
        "scope": "run",
        "public": bool(address.get("public", true)),
        "display_name": str(address.get("display_name", "")),
        "contributes_to": str(address.get("contributes_to", "")),
        "forget_policy": str(address.get("forget_policy", "clear")),
        "before": int(result.get("before", 0)),
        "after": int(result.get("after", 0)),
        "delta": int(result.get("delta", 0)),
        "consumed": int(result.get("consumed", 0)),
        "created": bool(result.get("created", false)),
        "removed": bool(result.get("removed", false)),
        "existed_before": bool(result.get("existed_before", false)),
        "exists_after": bool(result.get("exists_after", false)),
    }


func _is_integer(value) -> bool:
    return (value is int or value is float) \
        and float(value) == floor(float(value))
