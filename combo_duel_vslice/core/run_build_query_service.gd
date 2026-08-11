class_name RunBuildQueryService
extends RefCounted

## 本局构筑页面的只读查询服务。
##
## 它组合成长库存、统一内容目录与现有内功配装查询，产出深复制 DTO；
## 不修改领域状态，也不把 RunDeck、GrowthInventory 或 ContentCatalog 暴露给 UI。

const RunBuildDTOScript = preload("res://core/run_build_dto.gd")
const HandTechniqueLoadoutDTOScript = preload(
    "res://core/hand_technique_loadout_dto.gd")

const HAND_NAMES := {
    "high_card": "高牌",
    "pair": "一对",
    "two_pair": "两对",
    "three_kind": "三条",
    "straight": "顺子",
    "full_house": "葫芦",
    "four_kind": "四条",
    "five_kind": "五条",
}

var _growth
var _content_catalog
var _inner_skill_loadout_service

func _init(growth, content_catalog, inner_skill_loadout_service) -> void:
    _growth = growth
    _content_catalog = content_catalog
    _inner_skill_loadout_service = inner_skill_loadout_service

func query(editable: bool, blocked_reason: String = ""):
    var reason := "" if editable else blocked_reason
    var hand_loadouts: Array = []
    for hand_id_value in _growth.HAND_IDS:
        hand_loadouts.append(_build_hand_loadout(
            str(hand_id_value), editable, reason))
    return RunBuildDTOScript.new().configure({
        "editable": editable,
        "blocked_reason": reason,
        "cards": _build_cards(),
        "consumable_limit": _growth.CONSUMABLE_LIMIT,
        "consumables": _build_consumables(),
        "items": _build_items(),
        "hand_loadouts": hand_loadouts.map(
            func(value): return value.to_dict()),
        "inner_skill_loadout": _inner_skill_loadout_service.get_loadout(
            editable, reason),
        "experience": int(_growth.experience),
    })

func _build_cards() -> Array:
    var result: Array = []
    for values_value in _growth.run_deck.cards_snapshot():
        var values: Dictionary = values_value
        var reshapes: Dictionary = values.get("reshapes", {})
        var origin: Dictionary = reshapes.get("origin", {})
        var origin_id := str(origin.get("id", ""))
        var enhancement_id := str(reshapes.get("enhancement", ""))
        var imprint_id := str(reshapes.get("imprint", ""))
        var others: Dictionary = reshapes.get("others", {})
        result.append({
            "instance_id": str(values.get("instance_id", "")),
            "definition_id": str(values.get("definition_id", "")),
            "display_name": "%s·%s" % [
                str(values.get("attribute_name", "")),
                str(values.get("rank_name", ""))],
            "attribute": str(values.get("attribute", "")),
            "attribute_name": str(values.get("attribute_name", "")),
            "rank": str(values.get("rank_name", "")),
            "rank_order": int(values.get("rank_order", 0)),
            "qi_value": int(values.get("qi_value", 0)),
            "origin": origin.duplicate(true),
            "origin_name": _definition_name("origin", origin_id),
            "enhancement": enhancement_id,
            "enhancement_name": _definition_name(
                "enhancement", enhancement_id),
            "imprint": imprint_id,
            "imprint_name": _definition_name("imprint", imprint_id),
            "others": others.duplicate(true),
            "other_names": _other_names(others),
        })
    return result

func _build_consumables() -> Array:
    var result: Array = []
    for slot_index in range(_growth.CONSUMABLE_LIMIT):
        if slot_index >= _growth.consumable_ids.size():
            result.append({
                "slot_index": slot_index,
                "id": "",
                "name": "空槽",
                "kind": "",
                "description": "",
                "status": "empty",
            })
            continue
        var content_id := str(_growth.consumable_ids[slot_index])
        var definition: Dictionary = _content_catalog.get_by_id(
            "consumable", content_id)
        result.append({
            "slot_index": slot_index,
            "id": content_id,
            "name": str(definition.get("name", content_id)),
            "kind": str(definition.get("kind", "")),
            "description": str(definition.get("description", "")),
            "status": str(definition.get("status", "")),
        })
    return result

func _build_items() -> Array:
    var counts: Dictionary = {}
    var ordered_ids: Array[String] = []
    for item_id_value in _growth.item_ids:
        var item_id := str(item_id_value)
        if not counts.has(item_id):
            ordered_ids.append(item_id)
        counts[item_id] = int(counts.get(item_id, 0)) + 1
    var result: Array = []
    for item_id in ordered_ids:
        var definition: Dictionary = _content_catalog.get_by_id(
            "item", item_id)
        result.append({
            "id": item_id,
            "name": str(definition.get("name", item_id)),
            "description": str(definition.get("description", "")),
            "status": str(definition.get("status", "")),
            "count": int(counts[item_id]),
        })
    return result

func _build_hand_loadout(
        hand_id: String,
        editable: bool,
        blocked_reason: String):
    var techniques: Dictionary = _content_catalog.definition("techniques")
    var integration_statuses: Dictionary = techniques.get(
        "integration_statuses", {})
    var permitted_pools: Array = techniques.get(
        "pool_membership", {}).get(hand_id, [])
    var progression: Dictionary = _growth.hand_progression(hand_id)
    var sequence_ids: Array = progression.get("sequence", [])
    var sequence: Array = []
    for technique_id_value in sequence_ids:
        sequence.append(_technique_summary(
            str(technique_id_value), integration_statuses))
    var available: Array = []
    var emitted: Dictionary = {}
    for technique_id_value in _growth.learned_technique_ids:
        var technique_id := str(technique_id_value)
        if emitted.has(technique_id) or sequence_ids.has(technique_id):
            continue
        emitted[technique_id] = true
        var definition: Dictionary = _content_catalog.get_by_id(
            "technique", technique_id)
        if definition.is_empty():
            continue
        if str(integration_statuses.get(technique_id, "")) \
                != "formal_complete":
            continue
        if not permitted_pools.has(str(definition.get("pool", ""))):
            continue
        available.append(_technique_summary(
            technique_id, integration_statuses))
    return HandTechniqueLoadoutDTOScript.new().configure({
        "hand_id": hand_id,
        "hand_name": str(HAND_NAMES.get(hand_id, hand_id)),
        "slot_count": int(progression.get("slot_count", 1)),
        "sequence": sequence,
        "available_techniques": available,
        "editable": editable,
        "blocked_reason": blocked_reason,
    })

func _technique_summary(
        technique_id: String,
        integration_statuses: Dictionary) -> Dictionary:
    var definition: Dictionary = _content_catalog.get_by_id(
        "technique", technique_id)
    return {
        "id": technique_id,
        "name": str(definition.get("name", technique_id)),
        "description": str(definition.get("description", "")),
        "pool": str(definition.get("pool", "")),
        "status": str(integration_statuses.get(
            technique_id, definition.get("status", "missing"))),
    }

func _definition_name(content_type: String, content_id: String) -> String:
    if content_id == "":
        return ""
    var definition: Dictionary = _content_catalog.get_by_id(
        content_type, content_id)
    return str(definition.get("name", content_id))

func _other_names(others: Dictionary) -> Array[String]:
    var result: Array[String] = []
    for other_id_value in others:
        result.append(_definition_name("other_reshape", str(other_id_value)))
    return result
