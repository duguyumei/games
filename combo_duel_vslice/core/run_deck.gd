class_name RunDeck
extends RefCounted

const DeckFactoryScript = preload("res://core/deck_factory.gd")
const QiCardInstanceDataScript = preload("res://core/qi_card_instance_data.gd")
const CardInstanceIdFactoryScript = preload("res://core/card_instance_id_factory.gd")
const CardOriginServiceScript = preload("res://core/card_origin_service.gd")

const VERSION := 2

var _content_catalog
var _base_deck_definition: Dictionary = {}
var _cards: Array[Dictionary] = []
var _id_factory := CardInstanceIdFactoryScript.new()

func _init(content_catalog = null, base_deck_definition: Dictionary = {}) -> void:
    _content_catalog = content_catalog
    _base_deck_definition = base_deck_definition.duplicate(true)
    if _base_deck_definition.is_empty() and _content_catalog != null:
        _base_deck_definition = _content_catalog.definition("base_deck")

func reset_standard(namespace_value: String = "run") -> void:
    var definition := _base_deck_definition
    if definition.is_empty():
        definition = DeckFactoryScript.load_definition()
    _base_deck_definition = definition.duplicate(true)
    var card_ids: Array[String] = []
    for attribute in definition.get("attributes", []):
        for rank in definition.get("ranks", []):
            card_ids.append("%s_%s" % [attribute["id"], rank["id"]])
    reset_from_card_ids(card_ids, namespace_value)

func reset_from_card_ids(card_ids: Array, namespace_value: String = "run") -> Array[String]:
    _cards.clear()
    _id_factory = CardInstanceIdFactoryScript.new(namespace_value)
    var errors: Array[String] = []
    var used_ids: Dictionary = {}
    for card_id_value in card_ids:
        var definition_id := str(card_id_value)
        var definition: Dictionary = (
            _content_catalog.get_by_id("card", definition_id)
            if _content_catalog != null
            else _definition_from_base_deck(definition_id))
        if definition.is_empty():
            errors.append("初始构筑引用未知真气：%s" % definition_id)
            continue
        var instance_id := definition_id
        if used_ids.has(definition_id):
            instance_id = _id_factory.next_id(definition_id)
        used_ids[definition_id] = true
        var card = DeckFactoryScript.create_card_instance(
            definition, instance_id, _reshape_rules())
        _cards.append(QiCardInstanceDataScript.capture(card))
    return errors

func _definition_from_base_deck(definition_id: String) -> Dictionary:
    if _base_deck_definition.is_empty():
        return {}
    for attribute in _base_deck_definition.get("attributes", []):
        for rank in _base_deck_definition.get("ranks", []):
            var candidate_id := "%s_%s" % [attribute["id"], rank["id"]]
            if candidate_id != definition_id:
                continue
            return {
                "id": candidate_id,
                "rank": str(rank["id"]),
                "order": int(rank["order"]),
                "qi": int(rank["qi"]),
                "attribute": str(attribute["id"]),
                "attribute_name": str(attribute["name"]),
            }
    return {}

func card_count() -> int:
    return _cards.size()

func has_card(instance_id: String) -> bool:
    return _find_index(instance_id) >= 0

func card_data(instance_id: String) -> Dictionary:
    var index := _find_index(instance_id)
    return {} if index < 0 else _cards[index].duplicate(true)

func cards_snapshot() -> Array:
    return _cards.duplicate(true)

func content_definition(content_type: String, content_id: String) -> Dictionary:
    if _content_catalog == null:
        return {}
    return _content_catalog.get_by_id(content_type, content_id)

func create_battle_cards() -> Array:
    var result: Array = []
    for values in _cards:
        result.append(QiCardInstanceDataScript.restore(values, _reshape_rules()))
    return result

func add_card(card) -> Dictionary:
    if card == null:
        return {"success": false, "reason": "不能加入空真气实例"}
    if bool(card.temporary_card):
        return {"success": false, "reason": "战斗临时真气不能加入本局牌组"}
    if str(card.original_owner_id) != "":
        return {"success": false, "reason": "临时夺取的真气不能加入本局牌组"}
    if has_card(str(card.id)):
        return {"success": false, "reason": "真气实例 ID 已存在"}
    var values: Dictionary = QiCardInstanceDataScript.capture(card)
    var errors := _validate(values)
    if not errors.is_empty():
        return {"success": false, "reason": "；".join(errors)}
    _cards.append(values)
    return {"success": true, "instance_id": str(card.id)}

func add_card_by_definition(definition_id: String) -> Dictionary:
    var definition := content_definition("card", definition_id)
    if definition.is_empty():
        return {"success": false, "reason": "未知基础真气定义：%s" % definition_id}
    var serial_before := _id_factory.next_serial()
    var instance_id := _next_unique_instance_id(definition_id)
    var card = DeckFactoryScript.create_card_instance(
        definition, instance_id, _reshape_rules())
    var values: Dictionary = QiCardInstanceDataScript.capture(card)
    var errors := _validate(values)
    if not errors.is_empty():
        _id_factory.reset(serial_before)
        return {"success": false, "reason": "；".join(errors)}
    _cards.append(values)
    return {
        "success": true,
        "instance_id": instance_id,
        "definition_id": definition_id,
    }

func copy_card(instance_id: String, count: int = 1) -> Dictionary:
    if count <= 0:
        return {"success": false, "reason": "复制数量必须是正整数"}
    var source := card_data(instance_id)
    if source.is_empty():
        return {"success": false, "reason": "找不到要复制的真气"}
    var serial_before := _id_factory.next_serial()
    var copied_ids: Array[String] = []
    var candidates: Array[Dictionary] = []
    var pending_ids: Dictionary = {}
    for _index in range(count):
        var copy_values := source.duplicate(true)
        var copy_id := _next_unique_instance_id(
            str(source.get("definition_id", "card")), pending_ids)
        copy_values["instance_id"] = copy_id
        copy_values["original_owner_id"] = ""
        copy_values["temporary_card"] = false
        var errors := _validate(copy_values)
        if not errors.is_empty():
            _id_factory.reset(serial_before)
            return {"success": false, "reason": "；".join(errors)}
        candidates.append(copy_values)
        pending_ids[copy_id] = true
        copied_ids.append(copy_id)
    _cards.append_array(candidates)
    return {"success": true, "instance_ids": copied_ids}

func replace_card_definition(
        instance_id: String,
        definition_id: String,
        preserve_reshapes: bool = true) -> Dictionary:
    var index := _find_index(instance_id)
    if index < 0:
        return {"success": false, "reason": "找不到要转换的真气：%s" % instance_id}
    var definition := content_definition("card", definition_id)
    if definition.is_empty():
        return {"success": false, "reason": "未知基础真气定义：%s" % definition_id}
    var before: Dictionary = _cards[index].duplicate(true)
    var card = DeckFactoryScript.create_card_instance(
        definition, instance_id, _reshape_rules())
    if preserve_reshapes:
        var reshapes: Dictionary = before.get("reshapes", {})
        card.reshape_origin = reshapes.get("origin", {}).duplicate(true)
        card.reshape_enhancement = str(reshapes.get("enhancement", ""))
        card.reshape_imprint = str(reshapes.get("imprint", ""))
        card.reshape_others = reshapes.get("others", {}).duplicate(true)
    var after: Dictionary = QiCardInstanceDataScript.capture(card)
    var errors := _validate(after)
    if not errors.is_empty():
        return {"success": false, "reason": "；".join(errors)}
    _cards[index] = after
    return {"success": true, "before": before, "after": after.duplicate(true)}

func replace_card_state_from_source(
        source_instance_id: String,
        target_instance_id: String) -> Dictionary:
    var source := card_data(source_instance_id)
    if source.is_empty():
        return {"success": false, "reason": "找不到来源真气：%s" % source_instance_id}
    var target_index := _find_index(target_instance_id)
    if target_index < 0:
        return {"success": false, "reason": "找不到目标真气：%s" % target_instance_id}
    var before: Dictionary = _cards[target_index].duplicate(true)
    var after := source.duplicate(true)
    after["instance_id"] = target_instance_id
    after["original_owner_id"] = ""
    after["temporary_card"] = false
    var errors := _validate(after)
    if not errors.is_empty():
        return {"success": false, "reason": "；".join(errors)}
    _cards[target_index] = after
    return {"success": true, "before": before, "after": after.duplicate(true)}

func apply_card_reshape(
        instance_id: String,
        category: String,
        reshape_id: String,
        payload: Dictionary = {}) -> Dictionary:
    var index := _find_index(instance_id)
    if index < 0:
        return {"success": false, "reason": "找不到要重塑的真气：%s" % instance_id}
    if category == "origin":
        var origin_result := apply_card_origin([instance_id], reshape_id, payload)
        if not origin_result.get("success", false):
            return origin_result
        var origin_change: Dictionary = origin_result["changed"][0]
        return {
            "success": true,
            "before": origin_change["before"].duplicate(true),
            "after": origin_change["after"].duplicate(true),
        }
    var content_type := _reshape_content_type(category)
    if content_type == "":
        return {"success": false, "reason": "未知重塑类别：%s" % category}
    var definition := content_definition(content_type, reshape_id)
    if definition.is_empty():
        var actual_category := _reshape_category_for_id(reshape_id)
        if actual_category != "":
            return {
                "success": false,
                "reason": "重塑 %s 属于类别 %s，不属于 %s" % [
                    reshape_id, actual_category, category],
            }
        return {
            "success": false,
            "reason": "未知%s重塑：%s" % [category, reshape_id],
        }
    if definition.has("allowed_carriers") \
            and not definition.get("allowed_carriers", []).has("card"):
        return {
            "success": false,
            "reason": "重塑 %s 不允许施加给真气" % reshape_id,
        }
    var before: Dictionary = _cards[index].duplicate(true)
    var card = QiCardInstanceDataScript.restore(before, _reshape_rules())
    match category:
        "enhancement": card.set_enhancement(reshape_id)
        "imprint": card.set_imprint(reshape_id)
        "other": card.set_other_reshape(reshape_id, payload)
    var after: Dictionary = QiCardInstanceDataScript.capture(card)
    var errors := _validate(after)
    if not errors.is_empty():
        return {"success": false, "reason": "；".join(errors)}
    _cards[index] = after
    return {"success": true, "before": before, "after": after.duplicate(true)}

func apply_card_origin(
        instance_ids: Array,
        origin_id: String,
        payload: Dictionary) -> Dictionary:
    if instance_ids.is_empty():
        return {"success": false, "reason": "instance_ids 必须是非空数组"}
    var seen: Dictionary = {}
    var candidates: Array[Dictionary] = []
    var service = CardOriginServiceScript.new(_content_catalog, _base_deck_definition)
    for instance_id_value in instance_ids:
        var instance_id := str(instance_id_value)
        if instance_id == "":
            return {"success": false, "reason": "真气实例 ID 不能为空"}
        if seen.has(instance_id):
            return {"success": false, "reason": "真气实例 ID 不能重复：%s" % instance_id}
        seen[instance_id] = true
        var index := _find_index(instance_id)
        if index < 0:
            return {"success": false, "reason": "找不到要改造本源的真气：%s" % instance_id}
        var before: Dictionary = _cards[index].duplicate(true)
        var planned: Dictionary = service.plan(before, origin_id, payload)
        if not planned.get("success", false):
            return planned
        var after: Dictionary = planned["after"]
        var errors := _validate(after)
        if not errors.is_empty():
            return {"success": false, "reason": "；".join(errors)}
        candidates.append({
            "index": index,
            "instance_id": instance_id,
            "before": before,
            "after": after,
        })
    var changed: Array[Dictionary] = []
    for candidate in candidates:
        _cards[int(candidate["index"])] = candidate["after"].duplicate(true)
        changed.append({
            "instance_id": str(candidate["instance_id"]),
            "before": candidate["before"].duplicate(true),
            "after": candidate["after"].duplicate(true),
        })
    return {"success": true, "changed": changed}

func remove_card(instance_id: String) -> Dictionary:
    var index := _find_index(instance_id)
    if index < 0:
        return {"success": false, "reason": "找不到要永久移出的真气"}
    var removed: Dictionary = _cards.pop_at(index)
    return {"success": true, "card": removed.duplicate(true)}

func sync_from_battle_cards(cards: Array, permanently_removed_ids: Array = []) -> Dictionary:
    var updated := 0
    var added := 0
    var rejected: Array[String] = []
    var seen: Dictionary = {}
    for card in cards:
        if card == null or seen.has(str(card.id)):
            continue
        seen[str(card.id)] = true
        if bool(card.temporary_card) or str(card.original_owner_id) != "":
            continue
        var values: Dictionary = QiCardInstanceDataScript.capture(card)
        var errors := _validate(values)
        if not errors.is_empty():
            rejected.append_array(errors)
            continue
        var index := _find_index(str(card.id))
        if index >= 0:
            _cards[index] = values
            updated += 1
        else:
            var add_result := add_card(card)
            if add_result.get("success", false):
                added += 1
    var removed := 0
    for instance_id in permanently_removed_ids:
        if remove_card(str(instance_id)).get("success", false):
            removed += 1
    return {
        "updated": updated,
        "added": added,
        "removed": removed,
        "rejected": rejected,
    }

func to_snapshot() -> Dictionary:
    return {
        "version": VERSION,
        "namespace": _id_factory.id_namespace,
        "next_serial": _id_factory.next_serial(),
        "cards": cards_snapshot(),
    }

func restore_snapshot(values: Dictionary) -> Array[String]:
    var errors: Array[String] = []
    if int(values.get("version", 0)) != VERSION:
        errors.append("本局牌组版本不受支持：%s" % str(values.get("version", "")))
        return errors
    var incoming = values.get("cards", [])
    if not incoming is Array:
        errors.append("本局牌组 cards 必须是数组")
        return errors
    var unique_ids: Dictionary = {}
    var restored_cards: Array[Dictionary] = []
    for item in incoming:
        if not item is Dictionary:
            errors.append("本局牌组包含非对象真气实例")
            continue
        var card_values: Dictionary = item
        var instance_id := str(card_values.get("instance_id", ""))
        if unique_ids.has(instance_id):
            errors.append("本局牌组包含重复实例 ID：%s" % instance_id)
            continue
        unique_ids[instance_id] = true
        errors.append_array(_validate(card_values))
        restored_cards.append(card_values.duplicate(true))
    if not errors.is_empty():
        return errors
    _cards = restored_cards
    _id_factory = CardInstanceIdFactoryScript.new(str(values.get("namespace", "run")))
    _id_factory.reset(int(values.get("next_serial", 1)))
    return errors

func _validate(values: Dictionary) -> Array[String]:
    if _content_catalog == null:
        return []
    return QiCardInstanceDataScript.validate(values, _content_catalog)

func _reshape_rules():
    return _content_catalog.card_reshape_rules if _content_catalog != null else null

func _find_index(instance_id: String) -> int:
    for index in range(_cards.size()):
        if str(_cards[index].get("instance_id", "")) == instance_id:
            return index
    return -1

func _next_unique_instance_id(
        definition_id: String,
        pending_ids: Dictionary = {}) -> String:
    var instance_id := _id_factory.next_id(definition_id)
    while has_card(instance_id) or pending_ids.has(instance_id):
        instance_id = _id_factory.next_id(definition_id)
    return instance_id

func _reshape_content_type(category: String) -> String:
    match category:
        "origin": return "origin"
        "enhancement": return "enhancement"
        "imprint": return "imprint"
        "other": return "other_reshape"
    return ""

func _reshape_category_for_id(reshape_id: String) -> String:
    for category in ["origin", "enhancement", "imprint", "other"]:
        if not content_definition(
                _reshape_content_type(category), reshape_id).is_empty():
            return category
    return ""
