class_name EffectTargetQuery
extends RefCounted

const SIDE_IDS := ["actor", "target"]
const ZONE_IDS := ["hand", "draw_pile", "staging", "discard_pile"]
const ORDER_IDS := ["zone", "top", "bottom", "random"]
const CARD_KIND_IDS := ["any", "normal"]

var side_id: String = "actor"
var zone_id: String = "hand"
var order_id: String = "zone"
var limit: int = -1
var filters: Dictionary = {}
var _filters_type_valid: bool = true

func configure(spec: Dictionary):
    side_id = str(spec.get("side", "actor"))
    zone_id = str(spec.get("zone", "hand"))
    order_id = str(spec.get("order", "zone"))
    limit = int(spec.get("limit", -1))
    var filter_values = spec.get("filters", {})
    _filters_type_valid = filter_values is Dictionary
    filters = filter_values.duplicate(true) if _filters_type_valid else {}
    return self

func validate() -> Dictionary:
    if side_id not in SIDE_IDS:
        return _invalid("未知目标阵营：%s" % side_id)
    if zone_id not in ZONE_IDS:
        return _invalid("未知目标牌区：%s" % zone_id)
    if order_id not in ORDER_IDS:
        return _invalid("未知目标顺序：%s" % order_id)
    if limit == 0 or limit < -1:
        return _invalid("目标查询 limit 必须为 -1 或正整数")
    if not _filters_type_valid:
        return _invalid("目标筛选必须是对象")
    var card_kind := str(filters.get("card_kind", "any"))
    if card_kind not in CARD_KIND_IDS:
        return _invalid("未知真气种类筛选：%s" % card_kind)
    for field in ["attributes", "rank_names", "rank_orders", "definition_ids"]:
        if filters.has(field) and not filters[field] is Array:
            return _invalid("目标筛选 %s 必须是数组" % field)
    if filters.has("anomaly"):
        var anomaly = filters["anomaly"]
        if not anomaly is Dictionary:
            return _invalid("异状筛选必须是对象")
        if str(anomaly.get("category", "")) not in ["buff", "debuff", "state", "mark"]:
            return _invalid("异状筛选缺少合法 category")
    if filters.has("reshape"):
        var reshape = filters["reshape"]
        if not reshape is Dictionary:
            return _invalid("重塑筛选必须是对象")
        if str(reshape.get("category", "")) not in [
                "origin", "enhancement", "imprint", "other",
                "temporary_enhancement", "temporary_attribute"]:
            return _invalid("重塑筛选缺少合法 category")
    return {"ok": true, "reason": ""}

func resolve(context, rng: RandomNumberGenerator = null) -> Dictionary:
    var check := validate()
    if not check["ok"]:
        return {"success": false, "reason": check["reason"], "cards": []}
    var side = context.actor if side_id == "actor" else context.target
    if side == null:
        return {"success": false, "reason": "目标查询缺少%s" % side_id, "cards": []}
    var cards: Array = _zone_cards(context, side)
    var matches: Array = []
    for card in cards:
        if _matches(card):
            matches.append(card)
    if order_id == "top":
        matches.reverse()
    elif order_id == "random":
        if rng == null:
            return {"success": false, "reason": "随机目标查询缺少随机源", "cards": []}
        _shuffle(matches, rng)
    if limit > 0 and matches.size() > limit:
        matches = matches.slice(0, limit)
    return {
        "success": true,
        "reason": "",
        "cards": matches,
        "side": side,
        "side_id": side_id,
        "zone": zone_id,
    }

func snapshot() -> Dictionary:
    return {
        "side": side_id,
        "zone": zone_id,
        "order": order_id,
        "limit": limit,
        "filters": filters.duplicate(true),
    }

func _zone_cards(context, side) -> Array:
    if context.ports != null:
        return context.ports.zone_cards(side, zone_id)
    match zone_id:
        "hand": return side.hand.duplicate()
        "draw_pile": return side.draw_pile.duplicate()
        "staging": return side.staging.duplicate()
        "discard_pile": return side.discard_pile.duplicate()
    return []

func _matches(card) -> bool:
    var card_kind := str(filters.get("card_kind", "any"))
    if card_kind == "normal" and not card.is_card_kind("normal"):
        return false
    if filters.has("attributes"):
        var matches_attribute := false
        for attribute in filters["attributes"]:
            if card.is_attribute(str(attribute)):
                matches_attribute = true
                break
        if not matches_attribute:
            return false
    if filters.has("exclude_attributes"):
        for attribute in filters["exclude_attributes"]:
            if card.is_attribute(str(attribute)):
                return false
    var rank_name: String = card.current_rank_name() \
        if card.has_method("current_rank_name") else str(card.rank_name)
    var rank_order: int = card.current_rank_order() \
        if card.has_method("current_rank_order") else int(card.rank_order)
    var definition_id: String = card.current_definition_id() \
        if card.has_method("current_definition_id") else str(card.definition_id)
    if filters.has("rank_names") and not filters["rank_names"].has(rank_name):
        return false
    if filters.has("rank_orders") and not filters["rank_orders"].has(rank_order):
        return false
    if filters.has("definition_ids") and not filters["definition_ids"].has(definition_id):
        return false
    if filters.has("temporary") and bool(filters["temporary"]) != bool(card.temporary_card):
        return false
    if filters.has("has_any_reshape"):
        var has_reshape: bool = card.has_any_reshape_storage() \
            if card.has_method("has_any_reshape_storage") else (
                not card.reshape_origin.is_empty()
                or card.reshape_enhancement != ""
                or card.reshape_imprint != ""
                or not card.reshape_others.is_empty())
        if has_reshape != bool(filters["has_any_reshape"]):
            return false
    if filters.has("anomaly") and not _matches_anomaly(card, filters["anomaly"]):
        return false
    if filters.has("reshape") and not _matches_reshape(card, filters["reshape"]):
        return false
    return true

func _matches_anomaly(card, spec: Dictionary) -> bool:
    var present: bool = bool(spec.get("present", true))
    var actual: bool = card.has_anomaly(
        str(spec.get("category", "")),
        str(spec.get("id", "")))
    return actual == present

func _matches_reshape(card, spec: Dictionary) -> bool:
    var category: String = str(spec.get("category", ""))
    var reshape_id: String = str(spec.get("id", ""))
    var actual: bool = false
    match category:
        "origin":
            actual = not card.reshape_origin.is_empty() \
                and (reshape_id == "" or str(card.reshape_origin.get("id", "")) == reshape_id)
        "enhancement":
            actual = card.reshape_enhancement != "" \
                and (reshape_id == "" or card.reshape_enhancement == reshape_id)
        "imprint":
            actual = card.reshape_imprint != "" \
                and (reshape_id == "" or card.reshape_imprint == reshape_id)
        "other":
            actual = not card.reshape_others.is_empty() \
                if reshape_id == "" else card.reshape_others.has(reshape_id)
        "temporary_enhancement":
            var temporary_enhancement := str(card.temporary_reshapes.get("enhancement", ""))
            actual = temporary_enhancement != "" \
                and (reshape_id == "" or temporary_enhancement == reshape_id)
        "temporary_attribute":
            var temporary_attribute := str(card.temporary_reshapes.get("attribute", ""))
            actual = temporary_attribute != "" \
                and (reshape_id == "" or temporary_attribute == reshape_id)
    return actual == bool(spec.get("present", true))

func _shuffle(cards: Array, rng: RandomNumberGenerator) -> void:
    for index in range(cards.size() - 1, 0, -1):
        var other := rng.randi_range(0, index)
        var temporary = cards[index]
        cards[index] = cards[other]
        cards[other] = temporary

func _invalid(reason: String) -> Dictionary:
    return {"ok": false, "reason": reason}
