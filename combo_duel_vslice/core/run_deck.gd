class_name RunDeck
extends RefCounted

const DeckFactoryScript = preload("res://core/deck_factory.gd")
const QiCardInstanceDataScript = preload("res://core/qi_card_instance_data.gd")
const CardInstanceIdFactoryScript = preload("res://core/card_instance_id_factory.gd")

const VERSION := 1

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
        var card = DeckFactoryScript.create_card_instance(definition, instance_id)
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

func create_battle_cards() -> Array:
    var result: Array = []
    for values in _cards:
        result.append(QiCardInstanceDataScript.restore(values))
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

func copy_card(instance_id: String, count: int = 1) -> Dictionary:
    var source := card_data(instance_id)
    if source.is_empty():
        return {"success": false, "reason": "找不到要复制的真气"}
    var copied_ids: Array[String] = []
    for _index in range(maxi(0, count)):
        var copy_values := source.duplicate(true)
        var copy_id := _id_factory.next_id(str(source.get("definition_id", "card")))
        while has_card(copy_id):
            copy_id = _id_factory.next_id(str(source.get("definition_id", "card")))
        copy_values["instance_id"] = copy_id
        copy_values["original_owner_id"] = ""
        copy_values["temporary_card"] = false
        _cards.append(copy_values)
        copied_ids.append(copy_id)
    return {"success": true, "instance_ids": copied_ids}

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

func _find_index(instance_id: String) -> int:
    for index in range(_cards.size()):
        if str(_cards[index].get("instance_id", "")) == instance_id:
            return index
    return -1
