class_name PassiveRuleSourceResolver
extends RefCounted

const SourceScript = preload("res://core/passives/passive_rule_source.gd")

var _catalog

func _init(content_catalog = null) -> void:
    _catalog = content_catalog

func collect_sources(context) -> Array:
    var owner = context.owner if context != null else null
    if owner == null or _catalog == null:
        return []
    var result: Array = []
    var owner_id := str(owner.get("owner_id"))
    if owner_id == "":
        owner_id = "run"
    var equipped: Array = (
        context.proposed_equipped_inner_skill_ids
        if context.has_proposed_inner_skill_ids
        else owner.get("equipped_inner_skill_ids"))
    var technique_slot := int(owner.get("technique_slot_index"))
    for slot_index in range(equipped.size()):
        var content_id := str(equipped[slot_index])
        var definition: Dictionary = _catalog.get_by_id("inner_skill", content_id)
        var source_order := slot_index if slot_index < technique_slot else slot_index + 1
        _append_behaviors(
            result, "inner_skill", content_id,
            "inner:%s:%d:%s" % [owner_id, slot_index, content_id],
            definition, source_order)
    var item_ids = owner.get("item_ids")
    if item_ids == null:
        item_ids = []
    for item_index in range(item_ids.size()):
        var content_id := str(item_ids[item_index])
        _append_behaviors(
            result, "item", content_id,
            "item:%s:%s" % [owner_id, content_id],
            _catalog.get_by_id("item", content_id),
            10000 + item_index)
    result.sort_custom(func(left, right):
        if left.source_order != right.source_order:
            return left.source_order < right.source_order
        if left.source_instance_key != right.source_instance_key:
            return left.source_instance_key < right.source_instance_key
        return left.behavior_index < right.behavior_index)
    return result

func equipped_inner_skill_entries(context) -> Array:
    var owner = context.owner if context != null else null
    if owner == null or _catalog == null:
        return []
    var owner_id := str(owner.get("owner_id"))
    if owner_id == "":
        owner_id = "run"
    var equipped: Array = (
        context.proposed_equipped_inner_skill_ids
        if context.has_proposed_inner_skill_ids
        else owner.get("equipped_inner_skill_ids"))
    var technique_slot := int(owner.get("technique_slot_index"))
    var result: Array = []
    for slot_index in range(equipped.size()):
        var content_id := str(equipped[slot_index])
        result.append({
            "slot_index": slot_index,
            "content_id": content_id,
            "source_instance_key": "inner:%s:%d:%s" % [
                owner_id, slot_index, content_id],
            "source_order": (
                slot_index if slot_index < technique_slot else slot_index + 1),
            "definition": _catalog.get_by_id("inner_skill", content_id),
        })
    return result

func _append_behaviors(
        result: Array,
        source_kind: String,
        content_id: String,
        instance_key: String,
        definition: Dictionary,
        source_order: int) -> void:
    if definition.is_empty():
        return
    var behaviors = definition.get("behaviors", [])
    if not behaviors is Array:
        return
    for behavior_index in range(behaviors.size()):
        var behavior = behaviors[behavior_index]
        if not behavior is Dictionary:
            continue
        result.append(SourceScript.new().configure({
            "source_kind": source_kind,
            "content_id": content_id,
            "source_instance_key": instance_key,
            "definition": definition,
            "behavior_id": str(behavior.get("id", "")),
            "behavior_index": behavior_index,
            "configuration": behavior.get("configuration", {}),
            "source_order": source_order,
        }))
