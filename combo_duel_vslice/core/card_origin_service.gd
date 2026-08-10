class_name CardOriginService
extends RefCounted

## 本源改造的纯领域规划器。
##
## 牌阶、真气值与属性名称全部从 base_deck 定义读取。调用方先取得完整 after
## 候选，再决定事务提交，因此这里不直接持有 RunDeck 或战斗中央流程。

const ORIGIN_IDS := ["attribute_change", "rank_change"]
const RANK_DIRECTIONS := ["up", "down"]

var _content_catalog
var _base_deck: Dictionary = {}

func _init(content_catalog = null, base_deck_definition: Dictionary = {}) -> void:
    _content_catalog = content_catalog
    _base_deck = base_deck_definition.duplicate(true)
    if _base_deck.is_empty() and _content_catalog != null:
        _base_deck = _content_catalog.definition("base_deck")

func plan(values: Dictionary, origin_id: String, payload: Dictionary) -> Dictionary:
    var reshapes_value = values.get("reshapes", {})
    if not reshapes_value is Dictionary:
        return _failure("真气重塑快照必须是对象")
    var reshapes: Dictionary = reshapes_value
    var current_origin = reshapes.get("origin", {})
    if not current_origin is Dictionary:
        return _failure("本源槽必须是对象")
    if not current_origin.is_empty():
        return _failure("该真气已经接受过本源改造，本源不可替换")
    var payload_error := validate_payload(origin_id, payload)
    if payload_error != "":
        return _failure(payload_error)

    var after := values.duplicate(true)
    match origin_id:
        "attribute_change":
            var attribute_id := str(payload["attribute"])
            var attribute := _attribute_definition(attribute_id)
            var rank := _rank_definition(str(values.get("rank_name", "")))
            if attribute.is_empty():
                return _failure("转属引用未知基础属性：%s" % attribute_id)
            if rank.is_empty():
                return _failure("真气当前牌阶不在 base_deck 中：%s" % str(values.get("rank_name", "")))
            _apply_base_identity(after, attribute, rank)
        "rank_change":
            var ranks: Array = _base_deck.get("ranks", [])
            var rank_index := _rank_index(str(values.get("rank_name", "")))
            if rank_index < 0:
                return _failure("真气当前牌阶不在 base_deck 中：%s" % str(values.get("rank_name", "")))
            var direction := str(payload["direction"])
            var target_index := rank_index + (1 if direction == "up" else -1)
            if target_index < 0:
                return _failure("2 不能继续降阶")
            if target_index >= ranks.size():
                return _failure("A 不能继续升阶")
            var attribute := _attribute_definition(str(values.get("attribute", "")))
            if attribute.is_empty():
                return _failure("真气当前属性不在 base_deck 中：%s" % str(values.get("attribute", "")))
            _apply_base_identity(after, attribute, ranks[target_index])

    var after_reshapes: Dictionary = after.get("reshapes", {}).duplicate(true)
    after_reshapes["origin"] = {
        "id": origin_id,
        "payload": payload.duplicate(true),
    }
    after["reshapes"] = after_reshapes
    return {"success": true, "after": after}

func apply_to_card(card, origin_id: String, payload: Dictionary) -> Dictionary:
    if card == null:
        return _failure("不能对空真气施加本源")
    var values := {
        "instance_id": str(card.id),
        "definition_id": str(card.definition_id),
        "rank_name": str(card.rank_name),
        "rank_order": int(card.rank_order),
        "qi_value": int(card.qi_value),
        "attribute": str(card.attribute),
        "attribute_name": str(card.attribute_name),
        "reshapes": card.persistent_reshape_state(),
    }
    var result := plan(values, origin_id, payload)
    if not result.get("success", false):
        return result
    var after: Dictionary = result["after"]
    card.definition_id = str(after["definition_id"])
    card.rank_name = str(after["rank_name"])
    card.rank_order = int(after["rank_order"])
    card.qi_value = int(after["qi_value"])
    card.attribute = str(after["attribute"])
    card.attribute_name = str(after["attribute_name"])
    card.reshape_origin = after["reshapes"]["origin"].duplicate(true)
    return {"success": true, "after": after}

func validate_payload(origin_id: String, payload: Dictionary) -> String:
    if not ORIGIN_IDS.has(origin_id):
        return "未知本源：%s" % origin_id
    if _content_catalog != null and not _content_catalog.has_id("origin", origin_id):
        return "内容目录未定义本源：%s" % origin_id
    match origin_id:
        "attribute_change":
            if payload.size() != 1 or not payload.get("attribute") is String:
                return "转属 payload 必须且只能包含字符串 attribute"
            var attribute_id := str(payload.get("attribute", ""))
            if _attribute_definition(attribute_id).is_empty():
                return "转属引用未知基础属性：%s" % attribute_id
        "rank_change":
            if payload.size() != 1 or not payload.get("direction") is String:
                return "易阶 payload 必须且只能包含字符串 direction"
            var direction := str(payload.get("direction", ""))
            if not RANK_DIRECTIONS.has(direction):
                return "易阶 direction 只能为 up 或 down"
    return ""

func _apply_base_identity(values: Dictionary, attribute: Dictionary, rank: Dictionary) -> void:
    var definition_id := "%s_%s" % [str(attribute["id"]), str(rank["id"])]
    if _content_catalog != null and not _content_catalog.has_id("card", definition_id):
        return
    values["definition_id"] = definition_id
    values["attribute"] = str(attribute["id"])
    values["attribute_name"] = str(attribute["name"])
    values["rank_name"] = str(rank["id"])
    values["rank_order"] = int(rank["order"])
    values["qi_value"] = int(rank["qi"])

func _attribute_definition(attribute_id: String) -> Dictionary:
    for value in _base_deck.get("attributes", []):
        if str(value.get("id", "")) == attribute_id:
            return value.duplicate(true)
    return {}

func _rank_definition(rank_name: String) -> Dictionary:
    var index := _rank_index(rank_name)
    return {} if index < 0 else _base_deck.get("ranks", [])[index].duplicate(true)

func _rank_index(rank_name: String) -> int:
    var ranks: Array = _base_deck.get("ranks", [])
    for index in range(ranks.size()):
        if str(ranks[index].get("id", "")) == rank_name:
            return index
    return -1

func _failure(reason: String) -> Dictionary:
    return {"success": false, "reason": reason}
