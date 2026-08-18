class_name GrantItemsRunEffectHandler
extends "res://core/run_effects/run_effect_handler.gd"

func operation_ids() -> Array[String]:
    return ["grant_items", "remove_items"]

func validate_effect(effect: Dictionary, validator, scope: String) -> void:
    var ids := _validate_ids(
        effect.get("item_ids"), validator, scope + ".item_ids")
    for index in range(ids.size()):
        var content_id := str(ids[index])
        if validator.has_method("has_content_id") \
                and not validator.has_content_id("item", content_id):
            validator.report_error(
                "%s.item_ids[%d]" % [scope, index],
                "引用未知物品：%s" % content_id)
        elif str(effect.get("op", "")) == "grant_items" \
                and validator.has_method("is_formally_obtainable") \
                and not validator.is_formally_obtainable("item", content_id):
            validator.report_error(
                "%s.item_ids[%d]" % [scope, index],
                "物品未达到正式可获得状态：%s" % content_id)

func apply(effect: Dictionary, context) -> Dictionary:
    var ids: Array = effect["item_ids"]
    var operation := str(effect.get("op", ""))
    if operation == "remove_items":
        return _remove(ids, context)
    for content_id_value in ids:
        var content_id := str(content_id_value)
        if context.content_catalog == null:
            return {"success": false, "reason": "本局效果缺少内容目录"}
        if not context.content_catalog.has_id("item", content_id):
            return {"success": false, "reason": "引用未知物品：%s" % content_id}
        if not context.content_catalog.is_formally_obtainable("item", content_id):
            return {"success": false, "reason": "物品未达到正式可获得状态：%s" % content_id}
        if context.growth.item_ids.has(content_id):
            return {"success": false, "reason": "物品已持有，不能重复发放：%s" % content_id}
    var marker_changes: Array = []
    for content_id_value in ids:
        var granted: Dictionary = context.growth.grant_item(str(content_id_value))
        if not granted.get("success", false):
            return granted
        marker_changes.append_array(granted.get("marker_changes", []))
    context.record_committed_events(marker_changes)
    return {
        "success": true,
        "applied": {
            "op": "grant_items",
            "item_ids": ids.duplicate(),
            "item_count": context.growth.item_ids.size(),
            "source_marker_changes": marker_changes,
            "max_life": int(context.growth.max_life),
        },
    }

func _remove(ids: Array, context) -> Dictionary:
    for content_id_value in ids:
        var content_id := str(content_id_value)
        if context.content_catalog == null \
                or not context.content_catalog.has_id("item", content_id):
            return {"success": false, "reason": "引用未知物品：%s" % content_id}
        if not context.growth.item_ids.has(content_id):
            return {"success": false, "reason": "物品未持有：%s" % content_id}
    var marker_changes: Array = []
    for content_id_value in ids:
        var removed: Dictionary = context.growth.remove_item(str(content_id_value))
        if not removed.get("success", false):
            return removed
        marker_changes.append_array(removed.get("removed_markers", []))
    context.record_committed_events(marker_changes)
    return {
        "success": true,
        "applied": {
            "op": "remove_items",
            "item_ids": ids.duplicate(),
            "item_count": context.growth.item_ids.size(),
            "source_marker_changes": marker_changes,
            "max_life": int(context.growth.max_life),
        },
    }

func _validate_ids(value, validator, scope: String) -> Array:
    if not value is Array or value.is_empty():
        validator.report_error(scope, "必须是非空 ID 数组")
        return []
    var result: Array = []
    var seen: Dictionary = {}
    for index in range(value.size()):
        if not value[index] is String or str(value[index]) == "":
            validator.report_error("%s[%d]" % [scope, index], "必须是非空字符串")
            continue
        var content_id := str(value[index])
        if seen.has(content_id):
            validator.report_error(scope, "不能包含重复 ID：%s" % content_id)
        seen[content_id] = true
        result.append(content_id)
    return result
