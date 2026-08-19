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
var _technique_loadout_policy

func _init(growth, content_catalog, inner_skill_loadout_service) -> void:
    _growth = growth
    _content_catalog = content_catalog
    _inner_skill_loadout_service = inner_skill_loadout_service
    _technique_loadout_policy = _growth.technique_loadout_policy

func query(editable: bool, blocked_reason: String = ""):
    var reason := "" if editable else blocked_reason
    var hand_loadouts: Array = []
    for hand_id_value in _growth.HAND_IDS:
        hand_loadouts.append(_build_hand_loadout(
            str(hand_id_value), editable, reason))
    var capacity: Dictionary = _growth.effective_consumable_capacity_result()
    var effective_capacity := int(capacity.get("effective_capacity", 0)) \
        if capacity.get("success", false) else 0
    return RunBuildDTOScript.new().configure({
        "editable": editable,
        "blocked_reason": reason,
        "cards": _build_cards(),
        "consumable_limit": effective_capacity,
        "consumables": _build_consumables(effective_capacity),
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

func _build_consumables(effective_capacity: int) -> Array:
    var result: Array = []
    for slot_index in range(maxi(
            effective_capacity, _growth.consumable_ids.size())):
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
            "public_source_markers": _growth.source_marker_store.entries({
                "source_kind": "item",
                "content_id": item_id,
                "scope": "run",
                "public": true,
            }),
        })
    return result

func _build_hand_loadout(
        hand_id: String,
        editable: bool,
        blocked_reason: String):
    var techniques: Dictionary = _content_catalog.definition("techniques")
    var integration_statuses: Dictionary = techniques.get(
        "integration_statuses", {})
    var progression: Dictionary = _growth.hand_progression(hand_id)
    var sequence_ids: Array = progression.get("sequence", [])
    var sequence: Array = []
    for technique_id_value in sequence_ids:
        sequence.append(_technique_summary(
            str(technique_id_value), integration_statuses, hand_id))
    var available: Array = []
    var emitted: Dictionary = {}
    var candidate_ids: Array = _growth.learned_technique_ids.duplicate()
    for definition_value in _content_catalog.all_of("technique"):
        var definition: Dictionary = definition_value
        if bool(definition.get("built_in", false)):
            candidate_ids.append(str(definition.get("id", "")))
    candidate_ids.sort()
    for technique_id_value in candidate_ids:
        var technique_id := str(technique_id_value)
        if emitted.has(technique_id):
            continue
        emitted[technique_id] = true
        var definition: Dictionary = _content_catalog.get_by_id(
            "technique", technique_id)
        if definition.is_empty():
            continue
        if str(integration_statuses.get(technique_id, "")) \
                != "formal_complete":
            continue
        if not _technique_loadout_policy.is_eligible(
                technique_id, hand_id, _growth.learned_technique_ids):
            continue
        available.append(_technique_summary(
            technique_id, integration_statuses, hand_id))
    return HandTechniqueLoadoutDTOScript.new().configure({
        "hand_id": hand_id,
        "hand_name": str(HAND_NAMES.get(hand_id, hand_id)),
        "slot_count": int(progression.get("slot_count", 1)),
        "sequence": sequence,
        "available_techniques": available,
        "editable": editable,
        "blocked_reason": blocked_reason,
        "unused_slot_count": _technique_loadout_policy.unused_slot_count(
            sequence_ids.size(), int(progression.get("slot_count", 1))),
    })

func _technique_summary(
        technique_id: String,
        integration_statuses: Dictionary,
        hand_id: String) -> Dictionary:
    var definition: Dictionary = _content_catalog.get_by_id(
        "technique", technique_id)
    var totals: Dictionary = _technique_loadout_policy.total_counts(
        _growth.hand_technique_progression)
    var by_hand: Dictionary = _technique_loadout_policy.counts_by_hand(
        _growth.hand_technique_progression)
    var equipped_total := int(totals.get(technique_id, 0))
    var query: Dictionary = _technique_loadout_policy.resolve_limit(
        _growth, technique_id, equipped_total, by_hand, hand_id)
    var base_limit := int(definition.get("base_loadout_limit", 1))
    var effective_limit := int(query.get("effective_value", base_limit))
    var eligible: bool = _technique_loadout_policy.is_eligible(
        technique_id, hand_id, _growth.learned_technique_ids)
    var disabled_reason := ""
    if not query.get("success", false):
        disabled_reason = str(query.get("reason", "装配次数查询失败"))
    elif equipped_total >= effective_limit:
        disabled_reason = "已装配 %d/%d" % [equipped_total, effective_limit]
    return {
        "id": technique_id,
        "name": str(definition.get("name", technique_id)),
        "description": str(definition.get("description", "")),
        "pool": str(definition.get("pool", "")),
        "status": str(integration_statuses.get(
            technique_id, definition.get("status", "missing"))),
        "base_loadout_limit": base_limit,
        "effective_loadout_limit": effective_limit,
        "equipped_total_count": equipped_total,
        "remaining_count": maxi(0, effective_limit - equipped_total),
        "built_in": bool(definition.get("built_in", false)),
        "eligible": eligible,
        "disabled_reason": disabled_reason,
        "run_markers": _growth.source_marker_store.entries({
            "source_kind": "technique",
            "content_id": technique_id,
            "scope": "run",
            "public": true,
        }),
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
