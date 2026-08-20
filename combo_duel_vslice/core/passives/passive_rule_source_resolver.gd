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
    var inner_ordinals: Dictionary = {}
    for slot_index in range(equipped.size()):
        var content_id := str(equipped[slot_index])
        var content_ordinal := int(inner_ordinals.get(content_id, 0))
        inner_ordinals[content_id] = content_ordinal + 1
        var definition: Dictionary = _catalog.get_by_id("inner_skill", content_id)
        var source_order := slot_index if slot_index < technique_slot else slot_index + 1
        _append_behaviors(
            result, "inner_skill", content_id,
            "inner:%s:%d:%s" % [owner_id, slot_index, content_id],
            definition, source_order, slot_index, content_ordinal)
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
    return _apply_source_behavior_transformations(result, owner)

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
            "slot_index": source.slot_index,
            "content_instance_ordinal": source.content_instance_ordinal,
            "behavior_copyable": source.behavior_copyable,
            "projection": source.projection.duplicate(true),
        })
    return result

func sources_from_snapshot(snapshot: Array) -> Array:
    var result: Array = []
    if _catalog == null:
        return result
    for value in snapshot:
        if not value is Dictionary:
            continue
        var projection = value.get("projection", {})
        if projection is Dictionary \
                and str(projection.get("projection_kind", "")) \
                    == "source_behavior_transformation":
            var transformed = _transformed_source_from_snapshot(value)
            if transformed != null:
                result.append(transformed)
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
            "slot_index": int(value.get("slot_index", -1)),
            "content_instance_ordinal": int(value.get(
                "content_instance_ordinal", 0)),
            "behavior_copyable": bool(value.get(
                "behavior_copyable",
                definition.get("copyable", true) \
                    and behavior.get("copyable", true))),
            "source_marker_definitions": definition.get(
                "marker_definitions",
                definition.get("source_marker_definitions", [])),
        }))
    result.sort_custom(func(left, right):
        if left.source_order != right.source_order:
            return left.source_order < right.source_order
        if left.source_instance_key != right.source_instance_key:
            return left.source_instance_key < right.source_instance_key
        return left.behavior_index < right.behavior_index)
    return result

func _apply_source_behavior_transformations(
        sources: Array,
        owner) -> Array:
    var store = _property_value(
        owner, "source_behavior_transformation_store")
    if store == null:
        return sources
    var groups: Dictionary = {}
    for source in sources:
        if source.source_kind != "inner_skill" or source.is_projected():
            continue
        if not groups.has(source.source_instance_key):
            groups[source.source_instance_key] = []
        groups[source.source_instance_key].append(source)
    var transformed_instances: Dictionary = {}
    var additions: Array = []
    for group_value in groups.values():
        var group: Array = group_value
        if group.is_empty():
            continue
        var provider = group[0]
        var record: Dictionary = store.record_for(provider)
        if record.is_empty():
            continue
        var projected: Array = []
        for descriptor_value in record.get("target_behaviors", []):
            if not descriptor_value is Dictionary:
                continue
            var descriptor: Dictionary = descriptor_value.duplicate(true)
            descriptor["source_kind"] = "inner_skill"
            descriptor["content_id"] = str(record.get(
                "target_content_id", ""))
            var target_source = source_from_descriptor(descriptor)
            if target_source != null:
                projected.append(_transformed_source(provider, target_source))
        if projected.is_empty():
            continue
        transformed_instances[provider.source_instance_key] = true
        additions.append_array(projected)
    var result: Array = []
    for source in sources:
        if not transformed_instances.has(source.source_instance_key):
            result.append(source)
    result.append_array(additions)
    result.sort_custom(func(left, right):
        if left.source_order != right.source_order:
            return left.source_order < right.source_order
        if left.source_instance_key != right.source_instance_key:
            return left.source_instance_key < right.source_instance_key
        return left.behavior_index < right.behavior_index)
    return result

func _transformed_source(provider, target_source):
    var projection_key := "transformation|%s|%d|%s|%d" % [
        provider.source_instance_key,
        int(provider.content_instance_ordinal),
        target_source.content_id,
        int(target_source.behavior_index),
    ]
    return SourceScript.new().configure({
        "source_kind": provider.source_kind,
        "content_id": provider.content_id,
        "source_instance_key": provider.source_instance_key,
        "definition": provider.definition,
        "behavior_id": target_source.behavior_id,
        "behavior_index": target_source.behavior_index,
        "state_key": target_source.state_key,
        "configuration": target_source.configuration,
        "source_order": provider.source_order,
        "slot_index": provider.slot_index,
        "content_instance_ordinal": provider.content_instance_ordinal,
        "behavior_copyable": false,
        "projection": {
            "projection_kind": "source_behavior_transformation",
            "projection_key": projection_key,
            "provider_content_id": str(provider.content_id),
            "provider_content_instance_ordinal": int(
                provider.content_instance_ordinal),
            "target_content_id": str(target_source.content_id),
            "target_behavior_id": str(target_source.behavior_id),
            "target_behavior_index": int(target_source.behavior_index),
        },
        "counter_instance_key": "transform_%d_%s_%d" % [
            maxi(0, int(provider.content_instance_ordinal)),
            str(target_source.content_id),
            int(target_source.behavior_index),
        ],
        "counter_definition_source_kind": target_source.source_kind,
        "counter_definition_content_id": target_source.content_id,
        "counter_definition_behavior_id": target_source.behavior_id,
        "counter_definition_behavior_index": target_source.behavior_index,
        "source_marker_definitions": target_source.source_marker_definitions,
    })

func _transformed_source_from_snapshot(value: Dictionary):
    var provider_definition: Dictionary = _catalog.get_by_id(
        str(value.get("source_kind", "")),
        str(value.get("content_id", "")))
    if provider_definition.is_empty():
        return null
    var projection: Dictionary = value.get("projection", {})
    var target_source = source_from_descriptor({
        "source_kind": "inner_skill",
        "content_id": str(projection.get("target_content_id", "")),
        "behavior_id": str(projection.get("target_behavior_id", "")),
        "behavior_index": int(projection.get("target_behavior_index", -1)),
    })
    if target_source == null:
        return null
    var provider = SourceScript.new().configure({
        "source_kind": str(value.get("source_kind", "")),
        "content_id": str(value.get("content_id", "")),
        "source_instance_key": str(value.get("source_instance_key", "")),
        "definition": provider_definition,
        "behavior_id": "source_behavior_transformation",
        "behavior_index": 0,
        "source_order": int(value.get("source_order", 0)),
        "slot_index": int(value.get("slot_index", -1)),
        "content_instance_ordinal": int(value.get(
            "content_instance_ordinal", 0)),
        "behavior_copyable": false,
    })
    return _transformed_source(provider, target_source)

func _property_value(owner, property_name: String):
    if owner == null or not owner.has_method("get_property_list"):
        return null
    for property in owner.get_property_list():
        if str(property.get("name", "")) == property_name:
            return owner.get(property_name)
    return null

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
    var inner_ordinals: Dictionary = {}
    for slot_index in range(equipped.size()):
        var content_id := str(equipped[slot_index])
        var content_ordinal := int(inner_ordinals.get(content_id, 0))
        inner_ordinals[content_id] = content_ordinal + 1
        result.append({
            "slot_index": slot_index,
            "content_id": content_id,
            "source_instance_key": "inner:%s:%d:%s" % [
                owner_id, slot_index, content_id],
            "source_order": (
                slot_index if slot_index < technique_slot else slot_index + 1),
            "content_instance_ordinal": content_ordinal,
            "definition": _catalog.get_by_id("inner_skill", content_id),
        })
    return result

func _append_behaviors(
        result: Array,
        source_kind: String,
        content_id: String,
        instance_key: String,
        definition: Dictionary,
        source_order: int,
        slot_index: int = -1,
        content_instance_ordinal: int = 0) -> void:
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
            "slot_index": slot_index,
            "content_instance_ordinal": content_instance_ordinal,
            "behavior_copyable": bool(
                definition.get("copyable", true) \
                and behavior.get("copyable", true)),
            "source_marker_definitions": definition.get(
                "marker_definitions",
                definition.get("source_marker_definitions", [])),
        }))

func source_from_descriptor(value: Dictionary):
    if _catalog == null:
        return null
    var source_kind := str(value.get("source_kind", ""))
    var content_id := str(value.get("content_id", ""))
    var behavior_index := int(value.get("behavior_index", -1))
    var definition: Dictionary = _catalog.get_by_id(source_kind, content_id)
    var behaviors = definition.get("behaviors", [])
    if behavior_index < 0 or behavior_index >= behaviors.size() \
            or not behaviors[behavior_index] is Dictionary:
        return null
    var behavior: Dictionary = behaviors[behavior_index]
    if value.has("behavior_id") and str(value.get("behavior_id", "")) \
            != str(behavior.get("id", "")):
        return null
    return SourceScript.new().configure({
        "source_kind": source_kind,
        "content_id": content_id,
        "source_instance_key": str(value.get("source_instance_key", "")),
        "definition": definition,
        "behavior_id": str(behavior.get("id", "")),
        "behavior_index": behavior_index,
        "state_key": str(behavior.get("state_key", "")),
        "configuration": behavior.get("configuration", {}),
        "source_order": int(value.get("source_order", 0)),
        "slot_index": int(value.get("slot_index", -1)),
        "content_instance_ordinal": int(value.get(
            "content_instance_ordinal", 0)),
        "behavior_copyable": bool(
            definition.get("copyable", true) \
            and behavior.get("copyable", true)),
        "source_marker_definitions": definition.get(
            "marker_definitions",
            definition.get("source_marker_definitions", [])),
    })
