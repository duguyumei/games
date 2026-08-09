class_name CardWorkshopService
extends RefCounted

## 本局真气改造领域服务。
##
## 只接受已解析的定义 ID 与实例 ID；事务边界由 RunMutationService 提供。

func add_run_cards(run_deck, definition_ids: Array) -> Dictionary:
    if definition_ids.is_empty():
        return {"success": false, "reason": "definition_ids 必须是非空数组"}
    for definition_id_value in definition_ids:
        var definition_id := str(definition_id_value)
        if run_deck.content_definition("card", definition_id).is_empty():
            return {
                "success": false,
                "reason": "未知基础真气定义：%s" % definition_id,
            }
    var count_before: int = run_deck.card_count()
    var added: Array[Dictionary] = []
    for definition_id_value in definition_ids:
        var result: Dictionary = run_deck.add_card_by_definition(
            str(definition_id_value))
        if not result.get("success", false):
            return result
        added.append({
            "instance_id": str(result["instance_id"]),
            "definition_id": str(result["definition_id"]),
        })
    return {
        "success": true,
        "added": added,
        "count_before": count_before,
        "count_after": run_deck.card_count(),
    }

func remove_run_cards(run_deck, instance_ids: Array) -> Dictionary:
    var id_error := _validate_unique_instance_ids(instance_ids)
    if id_error != "":
        return {"success": false, "reason": id_error}
    for instance_id_value in instance_ids:
        var instance_id := str(instance_id_value)
        if not run_deck.has_card(instance_id):
            return {"success": false, "reason": "找不到要移出的真气：%s" % instance_id}
    var count_before: int = run_deck.card_count()
    var removed: Array[Dictionary] = []
    for instance_id_value in instance_ids:
        var result: Dictionary = run_deck.remove_card(str(instance_id_value))
        if not result.get("success", false):
            return result
        removed.append(result["card"].duplicate(true))
    return {
        "success": true,
        "removed": removed,
        "count_before": count_before,
        "count_after": run_deck.card_count(),
    }

func copy_run_card(run_deck, source_instance_id: String, count: int) -> Dictionary:
    var count_before: int = run_deck.card_count()
    var result: Dictionary = run_deck.copy_card(source_instance_id, count)
    if not result.get("success", false):
        return result
    return {
        "success": true,
        "source_instance_id": source_instance_id,
        "instance_ids": result["instance_ids"].duplicate(),
        "count_before": count_before,
        "count_after": run_deck.card_count(),
    }

func transform_run_card(
        run_deck,
        instance_id: String,
        definition_id: String,
        preserve_reshapes: bool = true) -> Dictionary:
    return run_deck.replace_card_definition(
        instance_id, definition_id, preserve_reshapes)

func copy_run_card_state(
        run_deck,
        source_instance_id: String,
        target_instance_ids: Array) -> Dictionary:
    var id_error := _validate_unique_instance_ids(target_instance_ids)
    if id_error != "":
        return {"success": false, "reason": id_error}
    if not run_deck.has_card(source_instance_id):
        return {
            "success": false,
            "reason": "找不到来源真气：%s" % source_instance_id,
        }
    for target_id_value in target_instance_ids:
        var target_id := str(target_id_value)
        if target_id == source_instance_id:
            return {
                "success": false,
                "reason": "来源真气不能同时作为目标：%s" % source_instance_id,
            }
        if not run_deck.has_card(target_id):
            return {"success": false, "reason": "找不到目标真气：%s" % target_id}
    var changed: Array[Dictionary] = []
    for target_id_value in target_instance_ids:
        var result: Dictionary = run_deck.replace_card_state_from_source(
            source_instance_id, str(target_id_value))
        if not result.get("success", false):
            return result
        changed.append({
            "instance_id": str(target_id_value),
            "before": result["before"].duplicate(true),
            "after": result["after"].duplicate(true),
        })
    return {"success": true, "changed": changed}

func apply_run_card_reshape(
        run_deck,
        instance_ids: Array,
        category: String,
        reshape_id: String,
        payload: Dictionary = {}) -> Dictionary:
    var id_error := _validate_unique_instance_ids(instance_ids)
    if id_error != "":
        return {"success": false, "reason": id_error}
    for instance_id_value in instance_ids:
        var instance_id := str(instance_id_value)
        if not run_deck.has_card(instance_id):
            return {"success": false, "reason": "找不到要重塑的真气：%s" % instance_id}
    var changed: Array[Dictionary] = []
    for instance_id_value in instance_ids:
        var instance_id := str(instance_id_value)
        var result: Dictionary = run_deck.apply_card_reshape(
            instance_id, category, reshape_id, payload)
        if not result.get("success", false):
            return result
        changed.append({
            "instance_id": instance_id,
            "before": result["before"].get("reshapes", {}).duplicate(true),
            "after": result["after"].get("reshapes", {}).duplicate(true),
        })
    return {"success": true, "changed": changed}

func _validate_unique_instance_ids(instance_ids: Array) -> String:
    if instance_ids.is_empty():
        return "instance_ids 必须是非空数组"
    var seen: Dictionary = {}
    for instance_id_value in instance_ids:
        var instance_id := str(instance_id_value)
        if instance_id == "":
            return "真气实例 ID 不能为空"
        if seen.has(instance_id):
            return "真气实例 ID 不能重复：%s" % instance_id
        seen[instance_id] = true
    return ""
