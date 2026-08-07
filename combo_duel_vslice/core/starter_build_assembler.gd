class_name StarterBuildAssembler
extends RefCounted

const RunDeckScript = preload("res://core/run_deck.gd")

var _content_catalog

func _init(content_catalog = null) -> void:
    _content_catalog = content_catalog

func assemble_card_ids(definition: Dictionary) -> Dictionary:
    if definition.is_empty():
        return {"success": false, "reason": "初始构筑定义为空"}
    var card_ids = definition.get("card_ids", [])
    if not card_ids is Array or card_ids.is_empty():
        return {"success": false, "reason": "初始构筑未提供 card_ids"}
    var resolved: Array[String] = []
    var errors: Array[String] = []
    for card_id_value in card_ids:
        var card_id := str(card_id_value)
        if _content_catalog == null or not _content_catalog.has_id("card", card_id):
            errors.append("初始构筑引用未知真气：%s" % card_id)
            continue
        resolved.append(card_id)
    var expected_count := int(definition.get("card_count", resolved.size()))
    if resolved.size() != expected_count:
        errors.append("初始构筑牌数为 %d，期望 %d" % [resolved.size(), expected_count])
    if not errors.is_empty():
        return {"success": false, "reason": "；".join(errors)}
    return {"success": true, "card_ids": resolved}

func assemble_into_run_deck(definition: Dictionary, run_namespace: String):
    var check := assemble_card_ids(definition)
    if not check.get("success", false):
        return check
    var run_deck = RunDeckScript.new(_content_catalog)
    var errors: Array[String] = run_deck.reset_from_card_ids(
        check["card_ids"], run_namespace)
    if not errors.is_empty():
        return {"success": false, "reason": "；".join(errors)}
    return {"success": true, "run_deck": run_deck}
