class_name PassiveRuleSourceResolver
extends RefCounted

const SourceScript = preload("res://core/passives/passive_rule_source.gd")
const SourceMarkerAddressResolverScript = preload(
    "res://core/source_marker_address_resolver.gd")

var _catalog
var _marker_address_resolver = SourceMarkerAddressResolverScript.new()

func _init(content_catalog = null) -> void:
    _catalog = content_catalog

func content_catalog():
    return _catalog

func collect_sources(context) -> Array:
    if context != null and context.has_source_snapshot:
        return sources_from_snapshot(context.source_snapshot)
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
        var instance_key := _marker_address_resolver.item_source_instance_key(
            owner, content_id)
        if instance_key == "":
            continue
        _append_behaviors(
            result, "item", content_id,
            instance_key,
            _catalog.get_by_id("item", content_id),
            10000 + item_index)
    result.sort_custom(func(left, right):
        if left.source_order != right.source_order:
            return left.source_order < right.source_order
        if left.source_instance_key != right.source_instance_key:
            return left.source_instance_key < right.source_instance_key
        return left.behavior_index < right.behavior_index)
    return result

func capture_source_snapshot(context) -> Array:
    var result: Array = []
    for source in collect_sources(context):
        result.append({
            "source_kind": source.source_kind,
            "content_id": source.content_id,
            "source_instance_key": source.source_instance_key,
            "behavior_id": source.behavior_id,
            "behavior_index": source.behavior_index,
            "source_order": source.source_order,
        })
    return result

func sources_from_snapshot(snapshot: Array) -> Array:
    var result: Array = []
    if _catalog == null:
        return result
    for value in snapshot:
        if not value is Dictionary:
            continue
        var source_kind := str(value.get("source_kind", ""))
        var content_id := str(value.get("content_id", ""))
        var behavior_index := int(value.get("behavior_index", -1))
        var definition: Dictionary = _catalog.get_by_id(source_kind, content_id)
        var behaviors = definition.get("behaviors", [])
        if behavior_index < 0 or behavior_index >= behaviors.size() \
                or not behaviors[behavior_index] is Dictionary:
            continue
        var behavior: Dictionary = behaviors[behavior_index]
        if str(behavior.get("id", "")) != str(value.get("behavior_id", "")):
            continue
        result.append(SourceScript.new().configure({
            "source_kind": source_kind,
            "content_id": content_id,
            "source_instance_key": str(value.get("source_instance_key", "")),
            "definition": definition,
            "behavior_id": str(behavior.get("id", "")),
            "behavior_index": behavior_index,
            "state_key": str(behavior.get("state_key", "")),
            "configuration": behavior.get("configuration", {}),
            "source_order": int(value.get("source_order", 0)),
        }))
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
            "state_key": str(behavior.get("state_key", "")),
            "configuration": behavior.get("configuration", {}),
            "source_order": source_order,
        }))
